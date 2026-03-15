/// 同步状态枚举
/// 用于标记数据的同步状态，为未来服务器同步做准备
enum SyncStatus {
  /// 已同步
  synced(0),

  /// 等待上传
  pendingUpload(1),

  /// 等待删除
  pendingDelete(2);

  const SyncStatus(this.value);
  final int value;

  static SyncStatus fromValue(int value) {
    return SyncStatus.values.firstWhere(
      (e) => e.value == value,
      orElse: () => SyncStatus.synced,
    );
  }
}

/// 学习子步骤类型
///
/// 定义所有可能的子步骤。每个 [LearningStage] 通过 [subStages] 列表
/// 组合不同的子步骤，解耦存储与枚举顺序。
enum SubStageType {
  /// 全文盲听
  blindListen('blindListen'),

  /// 逐句精听
  intensiveListen('intensiveListen'),

  /// 跟读
  listenAndRepeat('listenAndRepeat'),

  /// 段落复述
  retell('retell'),

  /// 复习：难句补练（盲听听不懂后进入跟读/精听式补练）
  reviewDifficultPractice('reviewDifficultPractice'),

  /// 复习：段落复述
  reviewRetellParagraph('reviewRetellParagraph'),

  /// 复习：全文总结复述（3-5句话概述大意）
  reviewRetellSummary('reviewRetellSummary');

  const SubStageType(this.key);

  /// DB 存储用字符串键
  final String key;

  /// 中文 UI 标签
  String get label => switch (this) {
    blindListen => '全文盲听',
    intensiveListen => '逐句精听',
    listenAndRepeat => '跟读',
    retell => '段落复述',
    reviewDifficultPractice => '难句补练',
    reviewRetellParagraph => '段落复述',
    reviewRetellSummary => '全文总结复述',
  };

  /// 从字符串键创建枚举
  static SubStageType fromKey(String key) {
    return SubStageType.values.firstWhere(
      (e) => e.key == key,
      orElse: () => SubStageType.blindListen,
    );
  }
}

/// 学习大阶段枚举
///
/// 定义音频学习的完整流程：首次学习 → 7 轮间隔复习 → 完成。
/// 学习流程严格线性，必须按顺序完成。
/// DB 存储字符串 [key]，排序使用 Dart 枚举的 [index]。
enum LearningStage {
  /// 首次学习阶段（4 个子步骤：盲听、精听、跟读、复述）
  firstLearn('firstLearn'),

  /// 首轮复习（6 小时后）
  review0('review0'),

  /// 第二轮复习（1 天后）
  review1('review1'),

  /// 第三轮复习（2 天后）
  review2('review2'),

  /// 第四轮复习（4 天后）
  review4('review4'),

  /// 第五轮复习（7 天后）
  review7('review7'),

  /// 第六轮复习（14 天后）
  review14('review14'),

  /// 第七轮复习（28 天后）
  review28('review28'),

  /// 已完成
  completed('completed');

  const LearningStage(this.key);

  /// DB 存储用字符串键
  final String key;

  /// 该阶段包含的子步骤（有序列表）
  List<SubStageType> get subStages => switch (this) {
    firstLearn => [
      SubStageType.blindListen,
      SubStageType.intensiveListen,
      SubStageType.listenAndRepeat,
      SubStageType.retell,
    ],
    review0 => [
      SubStageType.reviewDifficultPractice,
      SubStageType.reviewRetellParagraph,
    ],
    review28 => [
      SubStageType.blindListen,
      SubStageType.reviewDifficultPractice,
      SubStageType.reviewRetellSummary,
    ],
    completed => [],
    _ => [
      SubStageType.blindListen,
      SubStageType.reviewDifficultPractice,
      SubStageType.reviewRetellParagraph,
    ],
  };

  /// 该阶段的子步骤数量（从 subStages 列表推导）
  int get subStageCount => subStages.length;

  /// 复习间隔（小时）
  int get intervalHours => switch (this) {
    firstLearn => 0,
    review0 => 6,
    review1 => 24,
    review2 => 48,
    review4 => 96,
    review7 => 168,
    review14 => 336,
    review28 => 672,
    completed => 0,
  };

  /// 中文 UI 标签
  String get label => switch (this) {
    firstLearn => '首次学习',
    review0 => '首轮复习',
    review1 => '第二轮复习',
    review2 => '第三轮复习',
    review4 => '第四轮复习',
    review7 => '第五轮复习',
    review14 => '第六轮复习',
    review28 => '第七轮复习',
    completed => '已完成',
  };

  /// 从字符串键创建枚举
  static LearningStage fromKey(String key) {
    return LearningStage.values.firstWhere(
      (e) => e.key == key,
      orElse: () => LearningStage.firstLearn,
    );
  }
}

/// 难度等级枚举（5 档）
///
/// 影响复习遍数和间隔调整。盲听完成后由用户选择。
enum DifficultyLevel {
  /// 很轻松
  veryEasy(0),

  /// 偏轻松
  easy(1),

  /// 还可以
  medium(2),

  /// 偏难
  hard(3),

  /// 很难
  veryHard(4);

  const DifficultyLevel(this.value);
  final int value;

  /// 中文 UI 标签
  String get label => switch (this) {
    veryEasy => '很轻松',
    easy => '偏轻松',
    medium => '还可以',
    hard => '偏难',
    veryHard => '很难',
  };

  /// 从整数值创建枚举
  static DifficultyLevel fromValue(int value) {
    return DifficultyLevel.values.firstWhere(
      (e) => e.value == value,
      orElse: () => DifficultyLevel.medium,
    );
  }
}
