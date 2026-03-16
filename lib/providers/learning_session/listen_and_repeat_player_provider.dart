/// 跟读专用播放器 Provider
///
/// 难句跟读播放器，与 IntensiveListenPlayer 同层级，直接操作 AudioEngine。
/// 核心功能：
/// - 逐句播放（遍数根据难度调整：veryEasy/easy=2, medium=3, hard=4, veryHard=5）
/// - 遍间停顿时间：max(句长×2, 2000ms)，给用户跟读时间
/// - 取消难句收藏（从播放列表移除该句）
/// - 手动上一句/下一句
///
/// 使用 SentencePlaybackEngine 的 sessionId 守护防止异步竞态。
library;

import 'dart:async';
import 'dart:math' as math;
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../models/intensive_listen_settings.dart';
import '../../services/app_logger.dart';
import '../../models/sentence.dart';
import '../../utils/word_counter.dart';
import '../audio_engine/audio_engine_provider.dart';
import '../learning_progress_provider.dart';
import 'learning_session_provider.dart';
import 'sentence_playback_engine.dart';

part 'listen_and_repeat_player_provider.g.dart';

/// 跟读播放器状态
class ListenAndRepeatPlayerState {
  /// 当前句子索引（0-based，在过滤后的难句列表中的索引）
  final int currentSentenceIndex;

  /// 难句总数
  final int totalSentences;

  /// 当前遍数（1-based，"第N遍"）
  final int currentPlayCount;

  /// 目标播放遍数（根据难度动态计算，已弃用，由 settings.repeatCount 代替）
  final int targetPlayCount;

  /// 跟读设置（循环次数 + 停顿模式）
  final IntensiveListenSettings settings;

  /// 是否正在播放
  final bool isPlaying;

  /// 是否处于遍间停顿中（跟读时间）
  final bool isPauseBetweenPlays;

  /// 是否处于句间停顿中
  final bool isPauseBetweenSentences;

  /// 停顿剩余时间
  final Duration pauseRemaining;

  /// 停顿总时长
  final Duration pauseDuration;

  /// 是否已完成所有句子
  final bool isCompleted;

  /// 倒计时是否暂停中
  final bool isCountdownPaused;

  /// 倒计时是否快进中（10 倍速）
  final bool isCountdownFastForward;

  const ListenAndRepeatPlayerState({
    this.currentSentenceIndex = 0,
    this.totalSentences = 0,
    this.currentPlayCount = 1,
    this.targetPlayCount = 3,
    this.settings = const IntensiveListenSettings(),
    this.isPlaying = false,
    this.isPauseBetweenPlays = false,
    this.isPauseBetweenSentences = false,
    this.pauseRemaining = Duration.zero,
    this.pauseDuration = Duration.zero,
    this.isCompleted = false,
    this.isCountdownPaused = false,
    this.isCountdownFastForward = false,
  });

  ListenAndRepeatPlayerState copyWith({
    int? currentSentenceIndex,
    int? totalSentences,
    int? currentPlayCount,
    int? targetPlayCount,
    IntensiveListenSettings? settings,
    bool? isPlaying,
    bool? isPauseBetweenPlays,
    bool? isPauseBetweenSentences,
    Duration? pauseRemaining,
    Duration? pauseDuration,
    bool? isCompleted,
    bool? isCountdownPaused,
    bool? isCountdownFastForward,
  }) {
    return ListenAndRepeatPlayerState(
      currentSentenceIndex: currentSentenceIndex ?? this.currentSentenceIndex,
      totalSentences: totalSentences ?? this.totalSentences,
      currentPlayCount: currentPlayCount ?? this.currentPlayCount,
      targetPlayCount: targetPlayCount ?? this.targetPlayCount,
      settings: settings ?? this.settings,
      isPlaying: isPlaying ?? this.isPlaying,
      isPauseBetweenPlays: isPauseBetweenPlays ?? this.isPauseBetweenPlays,
      isPauseBetweenSentences:
          isPauseBetweenSentences ?? this.isPauseBetweenSentences,
      pauseRemaining: pauseRemaining ?? this.pauseRemaining,
      pauseDuration: pauseDuration ?? this.pauseDuration,
      isCompleted: isCompleted ?? this.isCompleted,
      isCountdownPaused: isCountdownPaused ?? this.isCountdownPaused,
      isCountdownFastForward:
          isCountdownFastForward ?? this.isCountdownFastForward,
    );
  }
}

/// 跟读专用播放器 Provider
///
/// 组合 SentencePlaybackEngine 实现逐句跟读播放循环。
/// 句子列表来自精听阶段标记的难句。
@Riverpod(keepAlive: true)
class ListenAndRepeatPlayer extends _$ListenAndRepeatPlayer {
  /// 难句列表（可变，取消收藏时会移除）
  List<Sentence> _sentences = [];

  /// 播放引擎
  late SentencePlaybackEngine _engine;

  @override
  ListenAndRepeatPlayerState build() {
    _engine = SentencePlaybackEngine(
      getEngine: () => ref.read(audioEngineProvider.notifier),
    );
    ref.onDispose(() => _engine.cleanup());
    return const ListenAndRepeatPlayerState();
  }

  /// 初始化跟读播放器
  ///
  /// [sentences] 难句列表（会深拷贝）
  /// [startIndex] 起始句子索引（断点续学）
  /// [targetPlayCount] 目标播放遍数（根据难度计算）
  Future<void> initialize(
    List<Sentence> sentences, {
    int startIndex = 0,
    int targetPlayCount = 3,
  }) async {
    _engine.cleanup();
    _sentences = sentences.map((s) => s.copyWith()).toList();

    final safeIndex = _sentences.isEmpty
        ? 0
        : startIndex.clamp(0, _sentences.length - 1);

    state = ListenAndRepeatPlayerState(
      currentSentenceIndex: safeIndex,
      totalSentences: _sentences.length,
      targetPlayCount: targetPlayCount,
      settings: IntensiveListenSettings(repeatCount: targetPlayCount),
    );
  }

  /// 获取当前句子
  Sentence? get currentSentence =>
      _sentences.isNotEmpty && state.currentSentenceIndex < _sentences.length
      ? _sentences[state.currentSentenceIndex]
      : null;

  /// 获取句子列表（只读）
  List<Sentence> get sentences => List.unmodifiable(_sentences);

  /// 获取当前句子索引（供外部保存断点用）
  int get currentIndex => state.currentSentenceIndex;

  /// 异步保存跟读断点，不阻塞当前句开始播放。
  void _persistCurrentSentenceIndexAsync() {
    final session = ref.read(learningSessionProvider);
    final audioItemId = session.audioItemId;
    if (audioItemId == null) return;

    unawaited(
      ref
          .read(learningProgressNotifierProvider.notifier)
          .saveShadowingSentenceIndex(audioItemId, state.currentSentenceIndex),
    );
  }

  /// 开始播放当前句子
  Future<void> startPlaying() async {
    if (_sentences.isEmpty) {
      state = state.copyWith(isCompleted: true);
      return;
    }
    await _startSentence();
  }

  /// 暂停播放
  Future<void> pause() async {
    _engine.invalidateSession();
    state = state.copyWith(
      isPlaying: false,
      isPauseBetweenPlays: false,
      isPauseBetweenSentences: false,
      isCountdownPaused: false,
      isCountdownFastForward: false,
    );
  }

  /// 恢复播放（从当前句子重新开始播放循环）
  Future<void> resume() async {
    await _startSentence();
  }

  /// 跳转到下一句
  Future<void> goToNext() async {
    if (state.currentSentenceIndex >= state.totalSentences - 1) return;

    _engine.invalidateSession();

    state = state.copyWith(
      currentSentenceIndex: state.currentSentenceIndex + 1,
      currentPlayCount: 1,
      isPauseBetweenPlays: false,
      isPauseBetweenSentences: false,
      isCountdownPaused: false,
      isCountdownFastForward: false,
    );

    await _startSentence();
  }

  /// 跳转到上一句
  Future<void> goToPrevious() async {
    if (state.currentSentenceIndex <= 0) return;

    _engine.invalidateSession();

    state = state.copyWith(
      currentSentenceIndex: state.currentSentenceIndex - 1,
      currentPlayCount: 1,
      isPauseBetweenPlays: false,
      isPauseBetweenSentences: false,
      isCountdownPaused: false,
      isCountdownFastForward: false,
    );

    await _startSentence();
  }

  /// 取消当前句子的难句收藏
  ///
  /// 从播放列表移除当前句子，返回被移除的句子（供外部删除书签）。
  /// 若列表为空→标记完成；否则自动调整索引。
  Sentence? removeDifficultMark() {
    if (_sentences.isEmpty) return null;

    _engine.invalidateSession();

    final removedIndex = state.currentSentenceIndex;
    final removed = _sentences[removedIndex];
    _sentences.removeAt(removedIndex);

    if (_sentences.isEmpty) {
      state = state.copyWith(
        isCompleted: true,
        isPlaying: false,
        totalSentences: 0,
        isPauseBetweenPlays: false,
        isPauseBetweenSentences: false,
      );
      return removed;
    }

    // 调整索引：如果移除的是最后一句，回退一格
    final newIndex = removedIndex >= _sentences.length
        ? _sentences.length - 1
        : removedIndex;

    state = state.copyWith(
      currentSentenceIndex: newIndex,
      totalSentences: _sentences.length,
      currentPlayCount: 1,
      isPlaying: false,
      isPauseBetweenPlays: false,
      isPauseBetweenSentences: false,
    );

    return removed;
  }

  /// 更新跟读设置（即时生效，仅本次会话）
  ///
  /// 当 repeatCount 调小时，clamp currentPlayCount 避免越界显示（如"第3/1遍"），
  /// 并中断当前播放循环、以新设置重新开始当前句子。
  void updateSettings(IntensiveListenSettings newSettings) {
    var clampedPlayCount = state.currentPlayCount;
    if (clampedPlayCount > newSettings.repeatCount) {
      clampedPlayCount = newSettings.repeatCount;
    }

    final needRestart = newSettings.repeatCount != state.settings.repeatCount;

    state = state.copyWith(
      settings: newSettings,
      currentPlayCount: clampedPlayCount,
    );

    // repeatCount 变化时中断当前循环，以新设置重新开始
    if (needRestart && state.isPlaying) {
      _engine.invalidateSession();
      _startSentence();
    }
  }

  /// 暂停倒计时
  void pauseCountdown() {
    _engine.pauseCountdown();
    state = state.copyWith(isCountdownPaused: true);
  }

  /// 恢复倒计时
  void resumeCountdown() {
    _engine.resumeCountdown();
    state = state.copyWith(isCountdownPaused: false);
  }

  /// 切换倒计时快进（10 倍速/正常速）
  ///
  /// 如果当前暂停中，快进会同时恢复倒计时。
  void toggleCountdownFastForward() {
    final isFF = !state.isCountdownFastForward;
    _engine.setCountdownSpeed(isFF ? 10.0 : 1.0);
    if (state.isCountdownPaused) {
      _engine.resumeCountdown();
    }
    state = state.copyWith(
      isCountdownFastForward: isFF,
      isCountdownPaused: false,
    );
  }

  /// 倒计时期间重播当前句子
  Future<void> replayDuringCountdown() async {
    _engine.invalidateSession();
    state = state.copyWith(
      isPauseBetweenPlays: false,
      isPauseBetweenSentences: false,
      isCountdownPaused: false,
      isCountdownFastForward: false,
    );
    await _startSentence();
  }

  /// 立即完成当前停顿回合，继续后续播放流程。
  Future<void> completePausedTurn() async {
    AppLogger.log('Player', 'completePausedTurn: '
        'isPause=${state.isPauseBetweenPlays}, '
        'isSentencePause=${state.isPauseBetweenSentences}, '
        'play=${state.currentPlayCount}/${state.settings.repeatCount}, '
        'sentence=${state.currentSentenceIndex + 1}/${state.totalSentences}');
    if (!state.isPauseBetweenPlays) {
      AppLogger.log('Player', 'completePausedTurn 跳过：不在停顿中');
      return;
    }

    final isSentencePause = state.isPauseBetweenSentences;
    _engine.invalidateSession();
    state = state.copyWith(
      isPauseBetweenPlays: false,
      isPauseBetweenSentences: false,
      isCountdownPaused: false,
      isCountdownFastForward: false,
      pauseRemaining: Duration.zero,
    );

    if (isSentencePause) {
      final isLastSentence =
          state.currentSentenceIndex >= state.totalSentences - 1;
      if (isLastSentence) {
        AppLogger.log('Player', '→ 完成（最后一句）');
        state = state.copyWith(isCompleted: true, isPlaying: false);
        return;
      }

      AppLogger.log('Player', '→ 下一句 #${state.currentSentenceIndex + 2}');
      state = state.copyWith(
        currentSentenceIndex: state.currentSentenceIndex + 1,
        currentPlayCount: 1,
      );
      await _startSentence();
      return;
    }

    final nextPlayCount = state.currentPlayCount + 1;
    if (nextPlayCount > state.settings.repeatCount) {
      AppLogger.log('Player', '→ autoAdvance（${state.settings.repeatCount}遍已满）');
      await _autoAdvance();
      return;
    }

    AppLogger.log('Player', '→ 第$nextPlayCount/${state.settings.repeatCount}遍');
    await _startSentence(startPlayCount: nextPlayCount);
  }

  /// 强制完成（用户在最后一句主动点击完成按钮）
  void forceComplete() {
    _engine.invalidateSession();
    state = state.copyWith(
      isCompleted: true,
      isPlaying: false,
      isPauseBetweenPlays: false,
      isPauseBetweenSentences: false,
    );
  }

  /// 释放资源
  void disposePlayer() {
    _engine.cleanup();
    _sentences = [];
    state = const ListenAndRepeatPlayerState();
  }

  // ========== 内部方法 ==========

  /// 开始播放当前句子的循环
  Future<void> _startSentence({int startPlayCount = 1}) async {
    final sentence = currentSentence;
    if (sentence == null) return;

    // 跳过零时长句子
    if (sentence.duration <= Duration.zero) {
      await _autoAdvance();
      return;
    }

    state = state.copyWith(
      isPlaying: true,
      currentPlayCount: startPlayCount,
      isPauseBetweenPlays: false,
      isPauseBetweenSentences: false,
    );
    _persistCurrentSentenceIndexAsync();

    final wordCount = countWords(sentence.text);
    final session = ref.read(learningSessionProvider.notifier);

    // 手动模式：只播一遍，不循环
    final effectiveRepeatCount =
        state.settings.isManualMode ? 1 : state.settings.repeatCount;

    await _engine.playSentenceLoop(
      sentence: sentence,
      repeatCount: effectiveRepeatCount,
      startPlayCount: startPlayCount,
      pauseCalculator: _buildPauseCalculator(),
      onPlayCountChanged: (playCount) {
        state = state.copyWith(currentPlayCount: playCount, isPlaying: true);
      },
      onPauseStarted: (pauseDur) {
        // 播放完成 = 输入，停顿开始 = 用户跟读 = 输出
        session.addInputWords(wordCount);
        session.recordLearnedSentence(sentence.text);
        session.addOutputWords(wordCount);
        session.startOutputTimer();
        state = state.copyWith(
          isPauseBetweenPlays: true,
          isPlaying: false,
          isCountdownPaused: false,
          isCountdownFastForward: false,
          pauseDuration: pauseDur,
          pauseRemaining: pauseDur,
        );
      },
      onPauseEnded: () {
        session.stopOutputTimer();
        state = state.copyWith(
          isPauseBetweenPlays: false,
          isCountdownPaused: false,
          isCountdownFastForward: false,
        );
      },
      onTick: (remaining) {
        state = state.copyWith(pauseRemaining: remaining);
      },
      onAllPlaysCompleted: () async {
        // 最后一遍只有输入，没有跟读停顿
        session.addInputWords(wordCount);
        session.recordLearnedSentence(sentence.text);
        await _autoAdvance();
      },
    );
  }

  /// 自动推进到下一句（最后一句也走停顿流程）
  Future<void> _autoAdvance() async {
    final isLastSentence =
        state.currentSentenceIndex >= state.totalSentences - 1;

    // 所有句子（包括最后一句）都走停顿，给用户跟读时间
    final sentence = currentSentence;
    final calculator = _buildPauseCalculator();
    final pauseDur = sentence != null
        ? calculator(sentence.duration)
        : const Duration(seconds: 2);

    await _engine.autoAdvance(
      pauseDuration: pauseDur,
      onPauseStarted: (dur) {
        state = state.copyWith(
          isPlaying: false,
          isPauseBetweenPlays: true,
          isPauseBetweenSentences: true,
          isCountdownPaused: false,
          isCountdownFastForward: false,
          pauseDuration: dur,
          pauseRemaining: dur,
        );
      },
      onTick: (remaining) {
        state = state.copyWith(pauseRemaining: remaining);
      },
      onAdvance: () async {
        if (isLastSentence) {
          // 最后一句停顿结束 → 标记完成
          state = state.copyWith(
            isCompleted: true,
            isPlaying: false,
            isPauseBetweenPlays: false,
            isPauseBetweenSentences: false,
          );
        } else {
          // 非最后一句 → 推进到下一句
          state = state.copyWith(
            currentSentenceIndex: state.currentSentenceIndex + 1,
            currentPlayCount: 1,
            isPauseBetweenPlays: false,
            isPauseBetweenSentences: false,
          );
          _startSentence();
        }
      },
    );
  }

  /// 重置到第一句并重新开始播放（供"再来一遍"使用）
  Future<void> resetToStart() async {
    _engine.invalidateSession();
    state = state.copyWith(
      currentSentenceIndex: 0,
      currentPlayCount: 1,
      isCompleted: false,
      isPlaying: false,
      isPauseBetweenPlays: false,
      isPauseBetweenSentences: false,
      isCountdownPaused: false,
      isCountdownFastForward: false,
    );
    await startPlaying();
  }

  /// 根据当前设置构建停顿计算器
  ///
  /// 返回的 lambda 在每次调用时读取最新 `state.settings`，
  /// 确保用户在播放中途修改停顿设置后能即时生效。
  /// - smart: max(句长×2, 2000ms)（跟读专用，给用户足够跟读时间）
  /// - fixed / multiplier: 复用精听的 calculatePauseDuration 逻辑
  PauseCalculator _buildPauseCalculator() {
    return (Duration sentenceDuration) {
      final settings = state.settings;
      return switch (settings.pauseMode) {
        PauseMode.smart => listenAndRepeatPauseCalculator(sentenceDuration),
        PauseMode.fixed => Duration(seconds: settings.fixedPauseSeconds),
        PauseMode.multiplier => Duration(
          milliseconds: math.max(
            (sentenceDuration.inMilliseconds * settings.pauseMultiplier)
                .round(),
            1000,
          ),
        ),
      };
    };
  }
}
