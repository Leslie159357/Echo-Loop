import 'package:drift/drift.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../database/enums.dart';
import '../database/providers.dart';
import '../database/app_database.dart' as db;
import '../models/learning_progress.dart';
import 'time_provider.dart';

part 'learning_progress_provider.g.dart';

/// 学习进度状态
///
/// 使用 Map 存储所有音频的学习进度，支持 O(1) 查找。
class LearningProgressState {
  /// 按音频 ID 索引的进度 Map
  final Map<String, LearningProgress> progressMap;

  /// 是否正在加载
  final bool isLoading;

  const LearningProgressState({
    this.progressMap = const {},
    this.isLoading = false,
  });

  LearningProgressState copyWith({
    Map<String, LearningProgress>? progressMap,
    bool? isLoading,
  }) {
    return LearningProgressState(
      progressMap: progressMap ?? this.progressMap,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

/// 学习进度管理 Provider
///
/// 管理所有音频的学习进度，提供加载、创建、推进、设置难度等操作。
/// 推进子步骤时同时写入 stage_completions 历史记录。
@Riverpod(keepAlive: true)
class LearningProgressNotifier extends _$LearningProgressNotifier {
  @override
  LearningProgressState build() {
    return const LearningProgressState();
  }

  /// 启动时加载所有学习进度
  Future<void> loadAll() async {
    state = state.copyWith(isLoading: true);
    final dao = ref.read(learningProgressDaoProvider);
    final rows = await dao.getAll();

    final map = <String, LearningProgress>{};
    for (final row in rows) {
      map[row.audioItemId] = _fromDbRow(row);
    }

    state = LearningProgressState(progressMap: map, isLoading: false);
  }

  /// O(1) 查找指定音频的学习进度
  LearningProgress? getByAudioId(String audioItemId) {
    return state.progressMap[audioItemId];
  }

  /// 获取指定音频的最新学习进度
  ///
  /// 优先返回数据库中的最新记录，并在内存态缺失或落后时回填 state。
  Future<LearningProgress?> getLatestByAudioId(String audioItemId) async {
    final dao = ref.read(learningProgressDaoProvider);
    final row = await dao.getByAudioId(audioItemId);
    if (row == null) {
      return state.progressMap[audioItemId];
    }

    final latest = _fromDbRow(row);
    final current = state.progressMap[audioItemId];
    if (current != latest) {
      final newMap = Map<String, LearningProgress>.from(state.progressMap);
      newMap[audioItemId] = latest;
      state = state.copyWith(progressMap: newMap);
    }
    return latest;
  }

  /// 获取指定音频的最新学习进度；若不存在则创建默认进度。
  ///
  /// 进入播放器前统一调用该方法，避免命中陈旧内存态。
  Future<LearningProgress> getLatestOrEnsureProgress(String audioItemId) async {
    final latest = await getLatestByAudioId(audioItemId);
    if (latest != null) return latest;
    return ensureProgress(audioItemId);
  }

  /// 确保音频有学习进度记录（首次打开时自动创建）
  Future<LearningProgress> ensureProgress(String audioItemId) async {
    final existing = state.progressMap[audioItemId];
    if (existing != null) return existing;

    final dao = ref.read(learningProgressDaoProvider);
    final row = await dao.getByAudioId(audioItemId);
    if (row != null) {
      final persisted = _fromDbRow(row);
      final newMap = Map<String, LearningProgress>.from(state.progressMap);
      newMap[audioItemId] = persisted;
      state = state.copyWith(progressMap: newMap);
      return persisted;
    }

    // 持久化时间始终用真实时间
    final now = DateTime.now();
    final progress = LearningProgress(
      audioItemId: audioItemId,
      currentStageStartedAt: now,
      updatedAt: now,
    );

    await dao.upsert(
      db.LearningProgressesCompanion(
        audioItemId: Value(audioItemId),
        currentStage: Value(LearningStage.firstLearn.key),
        currentSubStage: Value(SubStageType.blindListen.key),
        difficulty: const Value(2),
        firstLearnCompletedAt: const Value(null),
        lastStageCompletedAt: const Value(null),
        currentStageStartedAt: Value(now),
        totalStudyDurationMs: const Value(0),
        updatedAt: Value(now),
      ),
    );

    final newMap = Map<String, LearningProgress>.from(state.progressMap);
    newMap[audioItemId] = progress;
    state = state.copyWith(progressMap: newMap);

    return progress;
  }

  /// 完成当前子步骤，自动推进到下一步
  ///
  /// 同时写入 stage_completions 历史记录，计算耗时并累加总学习时长。
  Future<void> completeCurrentSubStage(String audioItemId) async {
    final progress = state.progressMap[audioItemId];
    if (progress == null || progress.isCompleted) return;
    final checkNow = ref.read(nowProvider)();
    if (progress.isReviewLockedAt(checkNow)) return;

    // 持久化时间始终用真实时间，避免 debug 偏移导致复习链断裂
    final now = DateTime.now();

    final stage = progress.currentStage;
    final subStages = stage.subStages;
    final currentIdx = subStages.indexOf(progress.currentSubStage);

    // 计算本步耗时
    final durationMs = progress.currentStageStartedAt != null
        ? now.difference(progress.currentStageStartedAt!).inMilliseconds
        : 0;

    // 写入 stage_completions 历史记录
    final stageCompletionDao = ref.read(stageCompletionDaoProvider);
    await stageCompletionDao.insertRecord(
      db.StageCompletionsCompanion(
        audioItemId: Value(audioItemId),
        stage: Value(progress.currentStage.key),
        subStage: Value(progress.currentSubStage.key),
        completedAt: Value(now),
        durationMs: Value(durationMs),
      ),
    );

    final newTotalDuration = progress.totalStudyDurationMs + durationMs;

    LearningProgress updated;

    if (currentIdx + 1 < subStages.length) {
      // 同阶段内推进子步骤
      updated = progress.copyWith(
        currentSubStage: subStages[currentIdx + 1],
        currentStageStartedAt: now,
        totalStudyDurationMs: newTotalDuration,
        updatedAt: now,
      );
    } else {
      // 进入下一个大阶段
      final nextStage = LearningStage.values[stage.index + 1];
      updated = progress.copyWith(
        currentStage: nextStage,
        currentSubStage: nextStage.subStages.isNotEmpty
            ? nextStage.subStages.first
            : SubStageType.blindListen,
        lastStageCompletedAt: now,
        currentStageStartedAt: now,
        totalStudyDurationMs: newTotalDuration,
        updatedAt: now,
        firstLearnCompletedAt: stage == LearningStage.firstLearn
            ? now
            : progress.firstLearnCompletedAt,
      );
    }

    await _persistProgress(updated);

    final newMap = Map<String, LearningProgress>.from(state.progressMap);
    newMap[audioItemId] = updated;
    state = state.copyWith(progressMap: newMap);
  }

  /// 设置难度等级
  Future<void> setDifficulty(
    String audioItemId,
    DifficultyLevel difficulty,
  ) async {
    final progress = state.progressMap[audioItemId];
    if (progress == null) return;

    final updated = progress.copyWith(
      difficulty: difficulty,
      updatedAt: DateTime.now(),
    );

    await _persistProgress(updated);

    final newMap = Map<String, LearningProgress>.from(state.progressMap);
    newMap[audioItemId] = updated;
    state = state.copyWith(progressMap: newMap);
  }

  /// 增加盲听完成遍数并持久化
  Future<void> incrementBlindListenPassCount(String audioItemId) async {
    final progress = state.progressMap[audioItemId];
    if (progress == null) return;

    final updated = progress.copyWith(
      blindListenPassCount: progress.blindListenPassCount + 1,
      updatedAt: DateTime.now(),
    );

    await _persistProgress(updated);

    final newMap = Map<String, LearningProgress>.from(state.progressMap);
    newMap[audioItemId] = updated;
    state = state.copyWith(progressMap: newMap);
  }

  /// 保存难句数快照（可多次调用，用于中途退出/自由练习时保存）
  Future<void> saveDifficultCount(String audioItemId, int count) async {
    final progress = state.progressMap[audioItemId];
    if (progress == null) return;

    final updated = progress.copyWith(
      intensiveListenDifficultCount: count,
      updatedAt: DateTime.now(),
    );

    await _persistProgress(updated);

    final newMap = Map<String, LearningProgress>.from(state.progressMap);
    newMap[audioItemId] = updated;
    state = state.copyWith(progressMap: newMap);
  }

  /// 精听完成时递增总遍数（+1）
  Future<void> incrementIntensiveListenPassCount(String audioItemId) async {
    final progress = state.progressMap[audioItemId];
    if (progress == null) return;

    final updated = progress.copyWith(
      intensiveListenPassCount: (progress.intensiveListenPassCount ?? 0) + 1,
      updatedAt: DateTime.now(),
    );

    await _persistProgress(updated);

    final newMap = Map<String, LearningProgress>.from(state.progressMap);
    newMap[audioItemId] = updated;
    state = state.copyWith(progressMap: newMap);
  }

  /// 跟读完成时递增总遍数（+1）
  Future<void> incrementShadowingPassCount(String audioItemId) async {
    final progress = state.progressMap[audioItemId];
    if (progress == null) return;

    final updated = progress.copyWith(
      shadowingPassCount: (progress.shadowingPassCount ?? 0) + 1,
      updatedAt: DateTime.now(),
    );

    await _persistProgress(updated);

    final newMap = Map<String, LearningProgress>.from(state.progressMap);
    newMap[audioItemId] = updated;
    state = state.copyWith(progressMap: newMap);
  }

  /// 删除指定音频的学习进度（音频删除时调用）
  Future<void> deleteProgress(String audioItemId) async {
    final dao = ref.read(learningProgressDaoProvider);
    await dao.deleteByAudioId(audioItemId);

    // stage_completions 会被外键级联删除

    final newMap = Map<String, LearningProgress>.from(state.progressMap);
    newMap.remove(audioItemId);
    state = state.copyWith(progressMap: newMap);
  }

  /// 保存跟读断点句子索引
  Future<void> saveShadowingSentenceIndex(
    String audioItemId,
    int? sentenceIndex,
  ) async {
    final progress = await ensureProgress(audioItemId);

    final updated = progress.copyWith(
      shadowingSentenceIndex: sentenceIndex,
      clearShadowingSentenceIndex: sentenceIndex == null,
      updatedAt: DateTime.now(),
    );

    await _persistProgress(updated);

    final newMap = Map<String, LearningProgress>.from(state.progressMap);
    newMap[audioItemId] = updated;
    state = state.copyWith(progressMap: newMap);
  }

  /// 保存难句补练断点句子索引
  Future<void> saveDifficultPracticeSentenceIndex(
    String audioItemId,
    int? sentenceIndex,
  ) async {
    final progress = await ensureProgress(audioItemId);

    final updated = progress.copyWith(
      difficultPracticeSentenceIndex: sentenceIndex,
      clearDifficultPracticeSentenceIndex: sentenceIndex == null,
      updatedAt: DateTime.now(),
    );

    await _persistProgress(updated);

    final newMap = Map<String, LearningProgress>.from(state.progressMap);
    newMap[audioItemId] = updated;
    state = state.copyWith(progressMap: newMap);
  }

  /// 保存复述断点段落索引
  Future<void> saveRetellParagraphIndex(
    String audioItemId,
    int? paragraphIndex,
  ) async {
    final progress = await ensureProgress(audioItemId);

    final updated = progress.copyWith(
      retellParagraphIndex: paragraphIndex,
      clearRetellParagraphIndex: paragraphIndex == null,
      updatedAt: DateTime.now(),
    );

    await _persistProgress(updated);

    final newMap = Map<String, LearningProgress>.from(state.progressMap);
    newMap[audioItemId] = updated;
    state = state.copyWith(progressMap: newMap);
  }

  /// 复述完成时递增总遍数（+1）
  Future<void> incrementRetellPassCount(String audioItemId) async {
    final progress = state.progressMap[audioItemId];
    if (progress == null) return;

    final updated = progress.copyWith(
      retellPassCount: (progress.retellPassCount ?? 0) + 1,
      updatedAt: DateTime.now(),
    );

    await _persistProgress(updated);

    final newMap = Map<String, LearningProgress>.from(state.progressMap);
    newMap[audioItemId] = updated;
    state = state.copyWith(progressMap: newMap);
  }

  /// 保存精听断点句子索引
  Future<void> saveIntensiveListenSentenceIndex(
    String audioItemId,
    int? sentenceIndex,
  ) async {
    final progress = await ensureProgress(audioItemId);

    final updated = progress.copyWith(
      intensiveListenSentenceIndex: sentenceIndex,
      clearIntensiveListenSentenceIndex: sentenceIndex == null,
      updatedAt: DateTime.now(),
    );

    await _persistProgress(updated);

    final newMap = Map<String, LearningProgress>.from(state.progressMap);
    newMap[audioItemId] = updated;
    state = state.copyWith(progressMap: newMap);
  }

  /// 将进度持久化到数据库
  Future<void> _persistProgress(LearningProgress progress) async {
    final dao = ref.read(learningProgressDaoProvider);
    await dao.upsert(
      db.LearningProgressesCompanion(
        audioItemId: Value(progress.audioItemId),
        currentStage: Value(progress.currentStage.key),
        currentSubStage: Value(progress.currentSubStage.key),
        difficulty: Value(progress.difficulty.value),
        firstLearnCompletedAt: Value(progress.firstLearnCompletedAt),
        lastStageCompletedAt: Value(progress.lastStageCompletedAt),
        currentStageStartedAt: Value(progress.currentStageStartedAt),
        totalStudyDurationMs: Value(progress.totalStudyDurationMs),
        blindListenPassCount: Value(progress.blindListenPassCount),
        intensiveListenDifficultCount: Value(
          progress.intensiveListenDifficultCount,
        ),
        intensiveListenPassCount: Value(progress.intensiveListenPassCount),
        shadowingPassCount: Value(progress.shadowingPassCount),
        intensiveListenSentenceIndex: Value(
          progress.intensiveListenSentenceIndex,
        ),
        shadowingSentenceIndex: Value(progress.shadowingSentenceIndex),
        difficultPracticeSentenceIndex: Value(
          progress.difficultPracticeSentenceIndex,
        ),
        retellParagraphIndex: Value(progress.retellParagraphIndex),
        retellPassCount: Value(progress.retellPassCount),
        updatedAt: Value(progress.updatedAt),
      ),
    );
  }

  /// 从数据库行转换为模型
  LearningProgress _fromDbRow(db.LearningProgressesData row) {
    final stage = LearningStage.fromKey(row.currentStage);
    final normalizedSubStage = _normalizeSubStageForStage(
      stage: stage,
      rawSubStageKey: row.currentSubStage,
    );

    return LearningProgress(
      audioItemId: row.audioItemId,
      currentStage: stage,
      currentSubStage: normalizedSubStage,
      difficulty: DifficultyLevel.fromValue(row.difficulty),
      firstLearnCompletedAt: row.firstLearnCompletedAt,
      lastStageCompletedAt: row.lastStageCompletedAt,
      currentStageStartedAt: row.currentStageStartedAt,
      totalStudyDurationMs: row.totalStudyDurationMs,
      blindListenPassCount: row.blindListenPassCount,
      intensiveListenDifficultCount: row.intensiveListenDifficultCount,
      intensiveListenPassCount: row.intensiveListenPassCount,
      shadowingPassCount: row.shadowingPassCount,
      intensiveListenSentenceIndex: row.intensiveListenSentenceIndex,
      shadowingSentenceIndex: row.shadowingSentenceIndex,
      difficultPracticeSentenceIndex: row.difficultPracticeSentenceIndex,
      retellParagraphIndex: row.retellParagraphIndex,
      retellPassCount: row.retellPassCount,
      updatedAt: row.updatedAt,
    );
  }

  /// 复习阶段兼容旧子步骤键，避免枚举扩展后旧数据无法推进。
  ///
  /// 兼容规则：
  /// - 首次学习阶段：保留原有子步骤；
  /// - review0：旧 blindListen/listenAndRepeat/retell 都归一到难句补练或段落复述；
  /// - 中间轮：旧 listenAndRepeat -> 难句补练，旧 retell -> 段落复述；
  /// - 末轮 review28：旧 retell -> 全文总结复述。
  SubStageType _normalizeSubStageForStage({
    required LearningStage stage,
    required String rawSubStageKey,
  }) {
    final raw = SubStageType.fromKey(rawSubStageKey);
    if (stage == LearningStage.firstLearn || stage == LearningStage.completed) {
      return raw;
    }

    if (stage == LearningStage.review0) {
      return switch (raw) {
        SubStageType.reviewDifficultPractice =>
          SubStageType.reviewDifficultPractice,
        SubStageType.reviewRetellParagraph =>
          SubStageType.reviewRetellParagraph,
        SubStageType.reviewRetellSummary => SubStageType.reviewRetellParagraph,
        SubStageType.retell => SubStageType.reviewRetellParagraph,
        _ => SubStageType.reviewDifficultPractice,
      };
    }

    if (stage == LearningStage.review28) {
      return switch (raw) {
        SubStageType.reviewDifficultPractice =>
          SubStageType.reviewDifficultPractice,
        SubStageType.reviewRetellSummary => SubStageType.reviewRetellSummary,
        SubStageType.reviewRetellParagraph => SubStageType.reviewRetellSummary,
        SubStageType.listenAndRepeat => SubStageType.reviewDifficultPractice,
        SubStageType.retell => SubStageType.reviewRetellSummary,
        _ => SubStageType.blindListen,
      };
    }

    return switch (raw) {
      SubStageType.reviewDifficultPractice =>
        SubStageType.reviewDifficultPractice,
      SubStageType.reviewRetellParagraph => SubStageType.reviewRetellParagraph,
      SubStageType.reviewRetellSummary => SubStageType.reviewRetellParagraph,
      SubStageType.listenAndRepeat => SubStageType.reviewDifficultPractice,
      SubStageType.retell => SubStageType.reviewRetellParagraph,
      _ => SubStageType.blindListen,
    };
  }
}
