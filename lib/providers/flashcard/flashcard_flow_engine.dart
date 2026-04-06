/// 闪卡流程引擎
///
/// 封装闪卡复习核心流程：TTS → countdown → flip → TTS → sentence → countdown → next。
/// 纯 Dart 类，不依赖 Riverpod，通过回调与外部交互。
///
/// [FlashcardNotifier] 组合此引擎，桥接 TTS / AudioEngine / DAO。
library;

import 'dart:async';

import '../../services/app_logger.dart';
import '../learning_session/countdown_controller.dart';
import 'flashcard_flow_phase.dart';
import 'flashcard_flow_state.dart';

/// 闪卡流程配置
///
/// 通过函数引用获取运行时参数，避免引擎依赖外部状态对象。
class FlashcardFlowConfig {
  /// 获取当前卡片的倒计时秒数（正面/背面由引擎内部判断）
  final int Function({required bool isBack}) getTimerSeconds;

  /// 是否手动模式
  final bool Function() isManualMode;

  /// 是否自动 TTS 朗读单词
  final bool Function() isAutoPlayWord;

  /// 是否自动播放例句
  final bool Function() isAutoPlaySentence;

  const FlashcardFlowConfig({
    required this.getTimerSeconds,
    required this.isManualMode,
    required this.isAutoPlayWord,
    required this.isAutoPlaySentence,
  });
}

/// 闪卡流程引擎回调
///
/// 副作用（TTS、音频播放）通过回调注入，引擎内部不直接调用。
class FlashcardFlowCallbacks {
  /// TTS 朗读单词，返回 Future 在朗读完成时 complete
  final Future<void> Function(String word, int token) speakWord;

  /// 播放例句音频，返回 Future 在播放完成时 complete
  final Future<void> Function(int token) playSentence;

  /// 停止所有播放（TTS + 音频引擎）
  final void Function() stopAllPlayback;

  /// 当前卡片完成后的回调（通知 Notifier 自动翻转/切卡）
  final void Function() onAutoFlip;

  /// 自动切到下一张的回调
  final void Function() onAutoNext;

  const FlashcardFlowCallbacks({
    required this.speakWord,
    required this.playSentence,
    required this.stopAllPlayback,
    required this.onAutoFlip,
    required this.onAutoNext,
  });
}

/// 闪卡流程引擎
///
/// 管理单张卡片的自动流程（TTS → countdown → flip/next），
/// 以及用户操作导致的状态切换（→ WaitingForUser）。
///
/// 通过 [startCard] 进入新卡片的正面自动流程，
/// 通过 [flipToBack] 进入背面自动流程。
class FlashcardFlowEngine {
  /// 状态变化回调
  final void Function(FlashcardFlowState state) onStateChanged;

  /// 外部交互回调
  FlashcardFlowCallbacks _callbacks;

  /// 流程配置
  FlashcardFlowConfig _config;

  /// 日志标签
  final String logTag;

  /// 倒计时控制器
  final CountdownController _countdown = CountdownController();

  /// 当前状态
  FlashcardFlowState _state = const FlashcardFlowState();

  /// 是否已释放
  bool _disposed = false;

  FlashcardFlowEngine({
    required this.onStateChanged,
    required FlashcardFlowCallbacks callbacks,
    required FlashcardFlowConfig config,
    this.logTag = 'FlashcardFlow',
  }) : _callbacks = callbacks,
       _config = config;

  /// 当前状态（只读）
  FlashcardFlowState get state => _state;

  // ========== 配置更新 ==========

  /// 更新回调（设置变更后重新绑定）
  void updateCallbacks(FlashcardFlowCallbacks callbacks) {
    _callbacks = callbacks;
  }

  /// 更新配置（设置变更后重新绑定）
  void updateConfig(FlashcardFlowConfig config) {
    _config = config;
  }

  // ========== 卡片生命周期 ==========

  /// 进入新卡片正面，启动自动流程
  ///
  /// [word] 当前卡片的显示文本（用于 TTS）
  /// [hasSentence] 当前卡片是否有来源例句
  Future<void> startCard({
    required String word,
    required bool hasSentence,
  }) async {
    if (_disposed) return;

    _stopActiveResources();
    _updateState(
      FlashcardFlowState(
        phase: const FlashcardIdle(),
        isShowingBack: false,
        flowToken: _state.flowToken + 1,
      ),
    );

    await _runFrontAutoPlay(word);
  }

  /// 自动翻转到背面后启动背面自动流程
  ///
  /// 由 Notifier 在处理 [onAutoFlip] 回调后调用。
  /// [word] 当前卡片的显示文本
  /// [hasSentence] 当前卡片是否有来源例句
  Future<void> startBackAutoPlay({
    required String word,
    required bool hasSentence,
  }) async {
    if (_disposed) return;

    _stopActiveResources();
    _updateState(
      _state.copyWith(
        phase: const FlashcardIdle(),
        isShowingBack: true,
        isSentencePlaying: false,
        flowToken: _state.flowToken + 1,
      ),
    );

    await _runBackAutoPlaySequence(word, hasSentence);
  }

  // ========== 用户操作 ==========

  /// 进入等待用户状态
  ///
  /// 从任何 Playing / Countdown 阶段均可调用。
  /// 停止所有播放和倒计时，切换 phase。
  void enterWaitingForUser(FlashcardWaitingReason reason) {
    if (_disposed) return;
    final phase = _state.phase;
    if (phase is FlashcardWaitingForUser ||
        phase is FlashcardSessionCompleted) {
      return;
    }

    _stopActiveResources();
    _updateState(
      _state.copyWith(
        phase: FlashcardWaitingForUser(reason),
        isSentencePlaying: false,
      ),
    );
    AppLogger.log(
      logTag,
      '→ WaitingForUser($reason) '
      '(从 ${phase.runtimeType})',
    );
  }

  /// 用户手动翻转卡片
  ///
  /// 原子性翻转 + 进入 WaitingForUser。
  /// 只取消倒计时，不中断 TTS/句子播放。
  void userFlipCard() {
    if (_disposed) return;
    if (_state.phase is FlashcardSessionCompleted) return;

    _countdown.cancel(); // 只取消倒计时，不停止播放
    _updateState(
      _state.copyWith(
        phase: const FlashcardWaitingForUser(
          FlashcardWaitingReason.userFlippedCard,
        ),
        isShowingBack: !_state.isShowingBack,
        flowToken: _state.flowToken + 1, // 使进行中的自动流程失效
      ),
    );
    AppLogger.log(logTag, '→ userFlipCard (now back=${!_state.isShowingBack})');
  }

  /// 用户手动播放单词 TTS（在任何状态下）
  ///
  /// 进入 WaitingForUser，播放完成后保持 WaitingForUser。
  Future<void> userPlayWord(String word) async {
    if (_disposed) return;

    enterWaitingForUser(FlashcardWaitingReason.userPlayedWord);
    final token = _state.flowToken;

    await _callbacks.speakWord(word, token);
    // 播完后保持 WaitingForUser，不启动倒计时
  }

  /// 用户手动播放例句
  ///
  /// 如果正在播放则停止，否则开始播放。
  /// 进入 WaitingForUser，播放完成后保持 WaitingForUser。
  Future<void> userToggleSentence() async {
    if (_disposed) return;

    if (_state.isSentencePlaying) {
      // 停止播放
      _callbacks.stopAllPlayback();
      _updateState(
        _state.copyWith(
          phase: const FlashcardWaitingForUser(
            FlashcardWaitingReason.userStoppedPlayback,
          ),
          isSentencePlaying: false,
        ),
      );
      return;
    }

    // 开始播放
    enterWaitingForUser(FlashcardWaitingReason.userPlayedSentence);
    _updateState(_state.copyWith(isSentencePlaying: true));
    final token = _state.flowToken;

    await _callbacks.playSentence(token);

    if (_disposed || token != _state.flowToken) return;
    _updateState(_state.copyWith(isSentencePlaying: false));
    // 播完后保持 WaitingForUser
  }

  /// 标记会话完成
  void markCompleted() {
    if (_disposed) return;
    _stopActiveResources();
    _updateState(
      _state.copyWith(
        phase: const FlashcardSessionCompleted(),
        isSentencePlaying: false,
      ),
    );
  }

  /// 释放资源
  void dispose() {
    _disposed = true;
    _countdown.cancel();
    _state = _state.copyWith(flowToken: _state.flowToken + 1);
  }

  // ========== 内部方法 ==========

  /// 正面自动流程：TTS → Countdown（手动模式下 TTS 后进入等待）
  Future<void> _runFrontAutoPlay(String word) async {
    if (_disposed) return;
    final token = _state.flowToken;

    // 自动 TTS（手动模式下也播放）
    if (_config.isAutoPlayWord()) {
      _updateState(_state.copyWith(phase: const FlashcardPlayingTts()));
      await _callbacks.speakWord(word, token);
      if (_disposed || token != _state.flowToken) return;
    }

    // 手动模式：TTS 播完后进入等待，不启动倒计时
    if (_config.isManualMode()) {
      _updateState(
        _state.copyWith(
          phase: const FlashcardWaitingForUser(
            FlashcardWaitingReason.manualMode,
          ),
        ),
      );
      return;
    }

    // 启动正面倒计时
    await _startCountdown(isBack: false);
  }

  /// 背面自动流程：TTS → Sentence → Countdown（手动模式下播完后进入等待）
  Future<void> _runBackAutoPlaySequence(String word, bool hasSentence) async {
    if (_disposed) return;
    final token = _state.flowToken;

    // 自动 TTS（手动模式下也播放）
    if (_config.isAutoPlayWord()) {
      _updateState(_state.copyWith(phase: const FlashcardPlayingTts()));
      await _callbacks.speakWord(word, token);
      if (_disposed || token != _state.flowToken) return;
    }

    // 自动播放例句（手动模式下也播放）
    if (_config.isAutoPlaySentence() && hasSentence) {
      _updateState(_state.copyWith(phase: const FlashcardPlayingSentence()));
      await _callbacks.playSentence(token);
      if (_disposed || token != _state.flowToken) return;
    }

    // 手动模式：播完后进入等待，不启动倒计时
    if (_config.isManualMode()) {
      _updateState(
        _state.copyWith(
          phase: const FlashcardWaitingForUser(
            FlashcardWaitingReason.manualMode,
          ),
        ),
      );
      return;
    }

    // 启动背面倒计时
    await _startCountdown(isBack: true);
  }

  /// 启动倒计时
  Future<void> _startCountdown({required bool isBack}) async {
    if (_disposed) return;

    final seconds = _config.getTimerSeconds(isBack: isBack);
    final total = Duration(seconds: seconds);
    _updateState(
      _state.copyWith(
        phase: FlashcardCountdown(remaining: total, total: total),
      ),
    );

    final token = _state.flowToken;
    await _countdown.start(total, (remaining) {
      if (_disposed || token != _state.flowToken) return;
      if (_state.phase is! FlashcardCountdown) return;
      _updateState(
        _state.copyWith(
          phase: FlashcardCountdown(remaining: remaining, total: total),
        ),
      );
    });

    // 倒计时自然结束
    if (_disposed || token != _state.flowToken) return;
    if (_state.phase is! FlashcardCountdown) return;
    _onCountdownExpired(isBack);
  }

  /// 倒计时到期
  void _onCountdownExpired(bool isBack) {
    if (isBack) {
      // 背面到期 → 通知自动下一张
      AppLogger.log(logTag, '背面倒计时到期 → autoNext');
      _callbacks.onAutoNext();
    } else {
      // 正面到期 → 通知自动翻转
      AppLogger.log(logTag, '正面倒计时到期 → autoFlip');
      _callbacks.onAutoFlip();
    }
  }

  /// 停止所有活跃资源（播放 + 倒计时）
  void _stopActiveResources() {
    _callbacks.stopAllPlayback();
    _countdown.cancel();
  }

  /// 更新状态并通知外部
  void _updateState(FlashcardFlowState newState) {
    if (_disposed) return;
    _state = newState;
    onStateChanged(newState);
  }
}
