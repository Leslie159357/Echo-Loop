import '../database/enums.dart';

/// 学习进度模型
///
/// 封装单个音频的学习进度数据。学习流程严格线性，
/// 完成状态由 [currentStage] + [currentSubStage] 推导。
/// 总子步骤数动态计算，从各阶段的 subStages 列表推导。
class LearningProgress {
  /// 关联的音频 ID
  final String audioItemId;

  /// 当前大阶段
  final LearningStage currentStage;

  /// 当前子步骤
  final SubStageType currentSubStage;

  /// 难度等级
  final DifficultyLevel difficulty;

  /// 首次学习完成时间（复习间隔计算基准）
  final DateTime? firstLearnCompletedAt;

  /// 上一阶段完成时间（复习调度核心字段）
  final DateTime? lastStageCompletedAt;

  /// 当前阶段开始时间（断点续学 + 耗时计算）
  final DateTime? currentStageStartedAt;

  /// 累计学习时长（毫秒）
  final int totalStudyDurationMs;

  /// 盲听已完成遍数
  final int blindListenPassCount;

  /// 精听标记的难句数量
  final int? intensiveListenDifficultCount;

  /// 精听总完成遍数（每次完成精听 +1）
  final int? intensiveListenPassCount;

  /// 跟读总完成遍数（每次完成跟读 +1）
  final int? shadowingPassCount;

  /// 精听断点续学句子索引（null 表示从头开始）
  final int? intensiveListenSentenceIndex;

  /// 跟读断点续学句子索引（null 表示从头开始）
  final int? shadowingSentenceIndex;

  /// 难句补练断点续学句子索引（null 表示从头开始）
  final int? difficultPracticeSentenceIndex;

  /// 复述断点续学段落索引（null 表示从头开始）
  final int? retellParagraphIndex;

  /// 复述总完成遍数（每次完成复述 +1）
  final int? retellPassCount;

  /// 最后更新时间
  final DateTime updatedAt;

  const LearningProgress({
    required this.audioItemId,
    this.currentStage = LearningStage.firstLearn,
    this.currentSubStage = SubStageType.blindListen,
    this.difficulty = DifficultyLevel.medium,
    this.firstLearnCompletedAt,
    this.lastStageCompletedAt,
    this.currentStageStartedAt,
    this.totalStudyDurationMs = 0,
    this.blindListenPassCount = 0,
    this.intensiveListenDifficultCount,
    this.intensiveListenPassCount,
    this.shadowingPassCount,
    this.intensiveListenSentenceIndex,
    this.shadowingSentenceIndex,
    this.difficultPracticeSentenceIndex,
    this.retellParagraphIndex,
    this.retellPassCount,
    required this.updatedAt,
  });

  /// 所有阶段的总子步骤数（动态计算）
  static int get totalSubStages =>
      LearningStage.values.fold(0, (sum, s) => sum + s.subStageCount);

  /// 当前子步骤在所属阶段中的索引
  int get currentSubStageIndex =>
      currentStage.subStages.indexOf(currentSubStage);

  /// 是否已开始学习
  bool get isStarted =>
      currentStage != LearningStage.firstLearn ||
      currentSubStage != SubStageType.blindListen;

  /// 是否已完成全部学习
  bool get isCompleted => currentStage == LearningStage.completed;

  /// 下次复习可用时间（仅复习阶段有意义）
  ///
  /// 基于 [lastStageCompletedAt] + 当前阶段的 [intervalHours] 计算。
  /// 首次学习阶段或缺少完成时间时返回 null。
  DateTime? get nextReviewAt {
    if (lastStageCompletedAt == null) return null;
    if (currentStage.intervalHours <= 0) return null;
    return lastStageCompletedAt!.add(
      Duration(hours: currentStage.intervalHours),
    );
  }

  /// 复习可学习窗口时长（仅复习阶段有意义）。
  ///
  /// - review0：到点后 6 小时内不算逾期
  /// - review1~review28：到点后 24 小时内不算逾期
  Duration? get reviewWindowDuration {
    if (!isInReviewStage) return null;
    if (currentStage == LearningStage.review0) {
      return const Duration(hours: 6);
    }
    return const Duration(hours: 24);
  }

  /// 复习可学习窗口结束时间。
  DateTime? get reviewWindowEndAt {
    final reviewAt = nextReviewAt;
    final window = reviewWindowDuration;
    if (reviewAt == null || window == null) return null;
    return reviewAt.add(window);
  }

  /// 当前是否可以开始复习
  bool get isReviewReady {
    return isReviewReadyAt(DateTime.now());
  }

  /// 指定时间点是否可以开始复习。
  ///
  /// 规则：`now >= nextReviewAt` 即可复习；无复习时间时视为可复习。
  bool isReviewReadyAt(DateTime now) {
    final reviewAt = nextReviewAt;
    if (reviewAt == null) return true;
    return now.isAfter(reviewAt) || now.isAtSameMomentAs(reviewAt);
  }

  /// 当前是否处于复习阶段（review0 ~ review28）
  bool get isInReviewStage =>
      currentStage.index >= LearningStage.review0.index &&
      currentStage.index <= LearningStage.review28.index;

  /// 复习是否未解锁（处于复习阶段且未到时间）
  bool get isReviewLocked => isReviewLockedAt(DateTime.now());

  /// 指定时间点的复习锁定状态。
  bool isReviewLockedAt(DateTime now) =>
      isInReviewStage && !isReviewReadyAt(now);

  /// 当前是否已逾期（超过可学习窗口结束时间）。
  bool get isReviewOverdue => isReviewOverdueAt(DateTime.now());

  /// 指定时间点是否已逾期。
  ///
  /// 规则：`now > reviewWindowEndAt` 才算逾期。
  bool isReviewOverdueAt(DateTime now) {
    final windowEnd = reviewWindowEndAt;
    if (windowEnd == null) return false;
    return now.isAfter(windowEnd);
  }

  /// 指定时间点的逾期时长（未逾期返回 null）。
  Duration? overdueDurationAt(DateTime now) {
    final windowEnd = reviewWindowEndAt;
    if (windowEnd == null || !isReviewOverdueAt(now)) return null;
    return now.difference(windowEnd);
  }

  /// 总完成进度（0.0 ~ 1.0）
  double get progressPercent {
    if (isCompleted) return 1.0;
    int completed = 0;
    for (int s = 0; s < currentStage.index; s++) {
      completed += LearningStage.values[s].subStageCount;
    }
    completed += currentSubStageIndex.clamp(0, currentStage.subStageCount);
    return completed / totalSubStages;
  }

  /// 指定阶段是否已完成
  bool isStageCompleted(LearningStage stage) =>
      stage.index < currentStage.index;

  /// 指定子步骤是否已完成
  bool isSubStageCompleted(LearningStage stage, SubStageType subStage) {
    if (stage.index < currentStage.index) return true;
    if (stage.index == currentStage.index) {
      return stage.subStages.indexOf(subStage) < currentSubStageIndex;
    }
    return false;
  }

  /// 指定阶段是否为当前活跃阶段
  bool isCurrentStage(LearningStage stage) => stage.index == currentStage.index;

  /// 指定子步骤是否为当前活跃子步骤
  bool isCurrentSubStage(LearningStage stage, SubStageType subStage) =>
      stage == currentStage && subStage == currentSubStage;

  /// 已完成的首次学习步骤数
  int get completedFirstStudySteps {
    if (currentStage == LearningStage.firstLearn) {
      return currentSubStageIndex.clamp(0, currentStage.subStageCount);
    }
    return LearningStage.firstLearn.subStageCount;
  }

  /// 已完成的复习阶段数（review0 ~ review28 共 7 个）
  int get completedReviewStages {
    if (currentStage.index <= LearningStage.firstLearn.index) return 0;
    if (isCompleted) return 7;
    // currentStage.index - 1 = 已完成的复习阶段数
    // （因为 review0 的 index 是 1，firstLearn 是 0）
    return currentStage.index - 1;
  }

  LearningProgress copyWith({
    String? audioItemId,
    LearningStage? currentStage,
    SubStageType? currentSubStage,
    DifficultyLevel? difficulty,
    DateTime? firstLearnCompletedAt,
    DateTime? lastStageCompletedAt,
    DateTime? currentStageStartedAt,
    int? totalStudyDurationMs,
    int? blindListenPassCount,
    int? intensiveListenDifficultCount,
    int? intensiveListenPassCount,
    int? shadowingPassCount,
    int? intensiveListenSentenceIndex,
    int? shadowingSentenceIndex,
    int? difficultPracticeSentenceIndex,
    int? retellParagraphIndex,
    int? retellPassCount,
    DateTime? updatedAt,
    bool clearIntensiveListenSentenceIndex = false,
    bool clearShadowingSentenceIndex = false,
    bool clearDifficultPracticeSentenceIndex = false,
    bool clearRetellParagraphIndex = false,
  }) {
    return LearningProgress(
      audioItemId: audioItemId ?? this.audioItemId,
      currentStage: currentStage ?? this.currentStage,
      currentSubStage: currentSubStage ?? this.currentSubStage,
      difficulty: difficulty ?? this.difficulty,
      firstLearnCompletedAt:
          firstLearnCompletedAt ?? this.firstLearnCompletedAt,
      lastStageCompletedAt: lastStageCompletedAt ?? this.lastStageCompletedAt,
      currentStageStartedAt:
          currentStageStartedAt ?? this.currentStageStartedAt,
      totalStudyDurationMs: totalStudyDurationMs ?? this.totalStudyDurationMs,
      blindListenPassCount: blindListenPassCount ?? this.blindListenPassCount,
      intensiveListenDifficultCount:
          intensiveListenDifficultCount ?? this.intensiveListenDifficultCount,
      intensiveListenPassCount:
          intensiveListenPassCount ?? this.intensiveListenPassCount,
      shadowingPassCount: shadowingPassCount ?? this.shadowingPassCount,
      intensiveListenSentenceIndex: clearIntensiveListenSentenceIndex
          ? null
          : (intensiveListenSentenceIndex ?? this.intensiveListenSentenceIndex),
      shadowingSentenceIndex: clearShadowingSentenceIndex
          ? null
          : (shadowingSentenceIndex ?? this.shadowingSentenceIndex),
      difficultPracticeSentenceIndex: clearDifficultPracticeSentenceIndex
          ? null
          : (difficultPracticeSentenceIndex ??
              this.difficultPracticeSentenceIndex),
      retellParagraphIndex: clearRetellParagraphIndex
          ? null
          : (retellParagraphIndex ?? this.retellParagraphIndex),
      retellPassCount: retellPassCount ?? this.retellPassCount,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
