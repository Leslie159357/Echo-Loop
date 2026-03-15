/// 复述设置模型
///
/// 控制段落复述播放器的重复次数、停顿模式和文本显示模式。
/// 仅在会话内生效，不持久化。
library;

import 'intensive_listen_settings.dart';

/// 可见词生成方式
enum KeywordMethod {
  /// 关闭（不显示可见词提示）
  off,

  /// 随机选择
  random,

  /// AI 智能选择（暂未实现）
  ai,
}

/// 可见词比例
///
/// 控制可见词占总词数的比例。
enum KeywordRatio {
  /// 1/2
  half(1, 2),

  /// 1/3
  oneThird(1, 3),

  /// 1/5
  oneFifth(1, 5),

  /// 1/10
  oneTenth(1, 10);

  /// 分子
  final int numerator;

  /// 分母
  final int denominator;

  const KeywordRatio(this.numerator, this.denominator);

  /// 比例值
  double get value => numerator / denominator;
}

/// 复述文本显示模式
enum RetellDisplayMode {
  /// 仅显示关键词，其余灰色矩形遮盖
  keywordsOnly,

  /// 全部正常显示
  showAll,

  /// 全部灰色矩形遮盖
  hideAll,
}

/// 复述设置（会话内临时生效）
class RetellSettings {
  /// 每段重复次数（1-5，默认 1）
  ///
  /// 播放→复述为一遍，达到遍数后推进下一段。
  final int repeatCount;

  /// 停顿模式（默认 smart）
  final PauseMode pauseMode;

  /// 固定间隔秒数（5-60，默认 15）
  final int fixedPauseSeconds;

  /// 段长倍数（1.0-3.0，默认 1.5）
  final double pauseMultiplier;

  /// 可见词生成方式（默认 random）
  final KeywordMethod keywordMethod;

  /// 可见词比例（默认 1/3）
  final KeywordRatio keywordRatio;

  /// 固定间隔可选值
  static const List<int> fixedPauseOptions = [
    5, 10, 15, 20, 25, 30, 35, 40, 45, 50, 55, 60,
  ];

  /// 倍数可选值
  static const List<double> multiplierOptions = [
    1.0, 1.5, 2.0, 2.5, 3.0,
  ];

  const RetellSettings({
    this.repeatCount = 1,
    this.pauseMode = PauseMode.smart,
    this.fixedPauseSeconds = 15,
    this.pauseMultiplier = 1.5,
    this.keywordMethod = KeywordMethod.random,
    this.keywordRatio = KeywordRatio.oneThird,
  });

  RetellSettings copyWith({
    int? repeatCount,
    PauseMode? pauseMode,
    int? fixedPauseSeconds,
    double? pauseMultiplier,
    KeywordMethod? keywordMethod,
    KeywordRatio? keywordRatio,
  }) {
    return RetellSettings(
      repeatCount: repeatCount ?? this.repeatCount,
      pauseMode: pauseMode ?? this.pauseMode,
      fixedPauseSeconds: fixedPauseSeconds ?? this.fixedPauseSeconds,
      pauseMultiplier: pauseMultiplier ?? this.pauseMultiplier,
      keywordMethod: keywordMethod ?? this.keywordMethod,
      keywordRatio: keywordRatio ?? this.keywordRatio,
    );
  }

  /// 根据段落时长计算复述停顿时间
  Duration calculatePauseDuration(Duration paragraphDuration) {
    return switch (pauseMode) {
      PauseMode.smart => Duration(
          milliseconds: (2000 + paragraphDuration.inMilliseconds * 3)
              .clamp(5000, 300000),
        ),
      PauseMode.fixed => Duration(seconds: fixedPauseSeconds),
      PauseMode.multiplier => Duration(
          milliseconds:
              (paragraphDuration.inMilliseconds * pauseMultiplier).round(),
        ),
    };
  }
}
