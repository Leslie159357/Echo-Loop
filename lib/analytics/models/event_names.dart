/// 埋点事件名常量
///
/// 集中管理所有事件名和参数名，编译时检查、IDE 自动补全、重命名安全。
/// 命名规范：`<对象>_<动作>`，全部小写下划线连接。
library;

/// 事件名常量
abstract class Events {
  // ── 生命周期 ──
  /// App 启动（冷启动/热启动）
  static const appOpen = 'app_open';

  /// App 进入后台
  static const appBackground = 'app_background';

  // ── 页面浏览 ──
  /// 页面切换
  static const screenView = 'screen_view';

  // ── 学习会话 ──
  /// 进入学习页面
  static const sessionStart = 'session_start';

  /// 离开学习页面
  static const sessionEnd = 'session_end';

  // ── 盲听 ──
  /// 开始全文盲听
  static const blindListenStart = 'blind_listen_start';

  /// 盲听一遍完成
  static const blindListenComplete = 'blind_listen_complete';

  /// 盲听后设置难度
  static const blindListenDifficultySet = 'blind_listen_difficulty_set';

  // ── 精听 ──
  /// 开始逐句精听
  static const intensiveListenStart = 'intensive_listen_start';

  /// 精听完成全部句子
  static const intensiveListenComplete = 'intensive_listen_complete';

  // ── 跟读 ──
  /// 开始跟读
  static const shadowingStart = 'shadowing_start';

  /// 跟读完成全部句子
  static const shadowingComplete = 'shadowing_complete';

  // ── 复述 ──
  /// 开始段落复述
  static const retellStart = 'retell_start';

  /// 复述完成全部段落
  static const retellComplete = 'retell_complete';

  // ── 难句补练 ──
  /// 开始难句补练
  static const difficultPracticeStart = 'difficult_practice_start';

  /// 难句补练完成
  static const difficultPracticeComplete = 'difficult_practice_complete';

  // ── 学习进度 ──
  /// 首次学习四步骤全部完成
  static const firstLearnComplete = 'first_learn_complete';

  /// 学习阶段推进
  static const stageAdvance = 'stage_advance';
}

/// 事件参数名常量
abstract class EventParams {
  // ── 通用 ──
  static const audioId = 'audio_id';
  static const stage = 'stage';
  static const durationMs = 'duration_ms';
  static const completed = 'completed';

  // ── 生命周期 ──
  static const isFirstLaunch = 'is_first_launch';
  static const launchType = 'launch_type';
  static const foregroundDurationMs = 'foreground_duration_ms';

  // ── 页面浏览 ──
  static const screenName = 'screen_name';
  static const previousScreen = 'previous_screen';

  // ── 学习会话 ──
  static const isFreePractice = 'is_free_practice';

  // ── 盲听 ──
  static const difficulty = 'difficulty';
  static const passNumber = 'pass_number';

  // ── 精听 ──
  static const totalSentences = 'total_sentences';
  static const difficultCount = 'difficult_count';

  // ── 跟读/复述 ──
  static const avgRating = 'avg_rating';
  static const totalParagraphs = 'total_paragraphs';

  // ── 学习进度 ──
  static const totalDurationMs = 'total_duration_ms';
  static const fromStage = 'from_stage';
  static const toStage = 'to_stage';
}
