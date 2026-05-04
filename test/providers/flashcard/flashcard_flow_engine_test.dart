/// FlashcardFlowEngine 单元测试
///
/// 验证闪卡状态机的核心行为：自动流程、用户中断、恢复、
/// 后台切换、手动模式等场景。
library;

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:echo_loop/providers/flashcard/flashcard_flow_engine.dart';
import 'package:echo_loop/providers/flashcard/flashcard_flow_phase.dart';
import 'package:echo_loop/providers/flashcard/flashcard_flow_state.dart';

// ========== 测试辅助 ==========

/// 可控的 mock TTS：调用 [completeSpeaking] 手动完成 TTS
class _MockTts {
  Completer<void>? _completer;
  int callCount = 0;
  String? lastWord;

  Future<void> speak(String word, int token) {
    callCount++;
    lastWord = word;
    _completer = Completer<void>();
    return _completer!.future;
  }

  void completeSpeaking() {
    _completer?.complete();
    _completer = null;
  }

  bool get isSpeaking => _completer != null && !_completer!.isCompleted;
}

/// 可控的 mock 句子播放
class _MockSentencePlayer {
  Completer<void>? _completer;
  int callCount = 0;

  Future<void> play(int token) {
    callCount++;
    _completer = Completer<void>();
    return _completer!.future;
  }

  void completePlayback() {
    _completer?.complete();
    _completer = null;
  }

  bool get isPlaying => _completer != null && !_completer!.isCompleted;
}

/// 测试用 Engine 封装
class _TestHarness {
  final _MockTts tts = _MockTts();
  final _MockSentencePlayer sentencePlayer = _MockSentencePlayer();
  int stopCallCount = 0;
  int autoFlipCount = 0;
  int autoNextCount = 0;

  bool manualMode = false;
  bool autoPlayWord = true;
  bool autoPlaySentence = true;
  int frontTimerSeconds = 5;
  int backTimerSeconds = 8;

  late final FlashcardFlowEngine engine;

  /// 记录所有状态变化
  final List<FlashcardFlowState> stateHistory = [];

  _TestHarness() {
    engine = FlashcardFlowEngine(
      onStateChanged: (s) => stateHistory.add(s),
      callbacks: _buildCallbacks(),
      config: _buildConfig(),
    );
  }

  FlashcardFlowCallbacks _buildCallbacks() {
    return FlashcardFlowCallbacks(
      speakWord: tts.speak,
      playSentence: sentencePlayer.play,
      stopAllPlayback: () => stopCallCount++,
      onAutoFlip: () => autoFlipCount++,
      onAutoNext: () => autoNextCount++,
    );
  }

  FlashcardFlowConfig _buildConfig() {
    return FlashcardFlowConfig(
      getTimerSeconds: ({required bool isBack}) =>
          isBack ? backTimerSeconds : frontTimerSeconds,
      isManualMode: () => manualMode,
      isAutoPlayWord: () => autoPlayWord,
      isAutoPlaySentence: () => autoPlaySentence,
    );
  }

  /// 更新配置后同步到引擎
  void syncConfig() {
    engine.updateConfig(_buildConfig());
  }

  FlashcardFlowState get state => engine.state;
  FlashcardFlowPhase get phase => state.phase;

  void dispose() => engine.dispose();
}

void main() {
  late _TestHarness h;

  setUp(() {
    h = _TestHarness();
  });

  tearDown(() {
    h.dispose();
  });

  // ========== 自动流程（正面） ==========

  group('正面自动流程', () {
    test('autoPlayWord=true → PlayingTts → TTS完成 → Countdown', () async {
      // 启动卡片（不 await，因为 TTS 会阻塞）
      unawaited(h.engine.startCard(word: 'hello', hasSentence: false));
      await Future<void>.delayed(Duration.zero);

      // 应该在 PlayingTts 阶段
      expect(h.phase, isA<FlashcardPlayingTts>());
      expect(h.tts.callCount, 1);
      expect(h.tts.lastWord, 'hello');

      // TTS 完成 → 进入 Countdown
      h.tts.completeSpeaking();
      await Future<void>.delayed(Duration.zero);

      expect(h.phase, isA<FlashcardCountdown>());
      final countdown = h.phase as FlashcardCountdown;
      expect(countdown.total, const Duration(seconds: 5));
    });

    test('autoPlayWord=false → 直接 Countdown', () async {
      h.autoPlayWord = false;
      h.syncConfig();

      unawaited(h.engine.startCard(word: 'hello', hasSentence: false));
      await Future<void>.delayed(Duration.zero);

      // 跳过 TTS，直接倒计时
      expect(h.tts.callCount, 0);
      expect(h.phase, isA<FlashcardCountdown>());
    });

    test('正面倒计时到期 → 调用 onAutoFlip', () async {
      h.frontTimerSeconds = 1; // 1 秒快速到期
      h.autoPlayWord = false;
      h.syncConfig();

      unawaited(h.engine.startCard(word: 'hello', hasSentence: false));
      // 等待倒计时完成（1 秒 + 余量）
      await Future<void>.delayed(const Duration(milliseconds: 1200));

      expect(h.autoFlipCount, 1);
    });
  });

  // ========== 自动流程（背面） ==========

  group('背面自动流程', () {
    test('TTS + Sentence → Countdown', () async {
      unawaited(h.engine.startBackAutoPlay(word: 'hello', hasSentence: true));
      await Future<void>.delayed(Duration.zero);

      // TTS 播放中
      expect(h.phase, isA<FlashcardPlayingTts>());
      expect(h.state.isShowingBack, true);

      // TTS 完成 → 句子播放
      h.tts.completeSpeaking();
      await Future<void>.delayed(Duration.zero);
      expect(h.phase, isA<FlashcardPlayingSentence>());

      // 句子完成 → Countdown
      h.sentencePlayer.completePlayback();
      await Future<void>.delayed(Duration.zero);
      expect(h.phase, isA<FlashcardCountdown>());
      final countdown = h.phase as FlashcardCountdown;
      expect(countdown.total, const Duration(seconds: 8));
    });

    test('无例句 → TTS → Countdown（跳过 PlayingSentence）', () async {
      unawaited(h.engine.startBackAutoPlay(word: 'hello', hasSentence: false));
      await Future<void>.delayed(Duration.zero);

      // TTS
      h.tts.completeSpeaking();
      await Future<void>.delayed(Duration.zero);

      // 直接 Countdown，无 PlayingSentence
      expect(h.phase, isA<FlashcardCountdown>());
      expect(h.sentencePlayer.callCount, 0);
    });

    test('autoPlaySentence=false → TTS → Countdown（跳过句子）', () async {
      h.autoPlaySentence = false;
      h.syncConfig();

      unawaited(h.engine.startBackAutoPlay(word: 'hello', hasSentence: true));
      await Future<void>.delayed(Duration.zero);

      h.tts.completeSpeaking();
      await Future<void>.delayed(Duration.zero);

      expect(h.phase, isA<FlashcardCountdown>());
      expect(h.sentencePlayer.callCount, 0);
    });

    test('背面倒计时到期 → 调用 onAutoNext', () async {
      h.backTimerSeconds = 1;
      h.autoPlayWord = false;
      h.autoPlaySentence = false;
      h.syncConfig();

      unawaited(h.engine.startBackAutoPlay(word: 'hello', hasSentence: false));
      await Future<void>.delayed(const Duration(milliseconds: 1200));

      expect(h.autoNextCount, 1);
    });
  });

  // ========== 用户中断 → WaitingForUser ==========

  group('用户中断', () {
    test('Countdown 中 enterWaitingForUser → WaitingForUser', () async {
      h.autoPlayWord = false;
      h.syncConfig();

      unawaited(h.engine.startCard(word: 'hello', hasSentence: false));
      await Future<void>.delayed(Duration.zero);
      expect(h.phase, isA<FlashcardCountdown>());

      h.engine.enterWaitingForUser(FlashcardWaitingReason.userFlippedCard);

      expect(h.phase, isA<FlashcardWaitingForUser>());
      final waiting = h.phase as FlashcardWaitingForUser;
      expect(waiting.reason, FlashcardWaitingReason.userFlippedCard);
    });

    test('PlayingTts 中 enterWaitingForUser → WaitingForUser', () async {
      unawaited(h.engine.startCard(word: 'hello', hasSentence: false));
      await Future<void>.delayed(Duration.zero);
      expect(h.phase, isA<FlashcardPlayingTts>());

      h.engine.enterWaitingForUser(FlashcardWaitingReason.userOpenedSettings);

      expect(h.phase, isA<FlashcardWaitingForUser>());
      expect(h.stopCallCount, greaterThan(0));
    });

    test('PlayingSentence 中 enterWaitingForUser → WaitingForUser', () async {
      unawaited(h.engine.startBackAutoPlay(word: 'hello', hasSentence: true));
      await Future<void>.delayed(Duration.zero);
      h.tts.completeSpeaking();
      await Future<void>.delayed(Duration.zero);
      expect(h.phase, isA<FlashcardPlayingSentence>());

      h.engine.enterWaitingForUser(FlashcardWaitingReason.appBackgrounded);

      expect(h.phase, isA<FlashcardWaitingForUser>());
    });

    test('已在 WaitingForUser 中再次调用 enterWaitingForUser → 无效', () async {
      h.autoPlayWord = false;
      h.syncConfig();

      unawaited(h.engine.startCard(word: 'hello', hasSentence: false));
      await Future<void>.delayed(Duration.zero);
      h.engine.enterWaitingForUser(FlashcardWaitingReason.userFlippedCard);

      final historyBefore = h.stateHistory.length;
      h.engine.enterWaitingForUser(FlashcardWaitingReason.appBackgrounded);
      // 状态不变
      expect(h.stateHistory.length, historyBefore);
    });

    test('SessionCompleted 中 enterWaitingForUser → 无效', () {
      h.engine.markCompleted();
      final historyBefore = h.stateHistory.length;
      h.engine.enterWaitingForUser(FlashcardWaitingReason.userFlippedCard);
      expect(h.stateHistory.length, historyBefore);
    });
  });

  // ========== 用户手动播放 ==========

  group('用户手动播放', () {
    test('userPlayWord → WaitingForUser + TTS', () async {
      h.autoPlayWord = false;
      h.syncConfig();

      unawaited(h.engine.startCard(word: 'hello', hasSentence: false));
      await Future<void>.delayed(Duration.zero);
      expect(h.phase, isA<FlashcardCountdown>());

      unawaited(h.engine.userPlayWord('hello'));
      await Future<void>.delayed(Duration.zero);

      expect(h.phase, isA<FlashcardWaitingForUser>());
      expect(h.tts.callCount, 1);

      // TTS 完成后仍保持 WaitingForUser
      h.tts.completeSpeaking();
      await Future<void>.delayed(Duration.zero);
      expect(h.phase, isA<FlashcardWaitingForUser>());
    });

    test('userToggleSentence → WaitingForUser + 播放', () async {
      h.autoPlayWord = false;
      h.syncConfig();

      unawaited(h.engine.startCard(word: 'hello', hasSentence: true));
      await Future<void>.delayed(Duration.zero);

      unawaited(h.engine.userToggleSentence());
      await Future<void>.delayed(Duration.zero);

      expect(h.phase, isA<FlashcardWaitingForUser>());
      expect(h.state.isSentencePlaying, true);

      // 播放完成
      h.sentencePlayer.completePlayback();
      await Future<void>.delayed(Duration.zero);
      expect(h.state.isSentencePlaying, false);
      expect(h.phase, isA<FlashcardWaitingForUser>());
    });

    test('userToggleSentence 播放中再次调用 → 停止', () async {
      h.autoPlayWord = false;
      h.syncConfig();

      unawaited(h.engine.startCard(word: 'hello', hasSentence: true));
      await Future<void>.delayed(Duration.zero);

      // 开始播放
      unawaited(h.engine.userToggleSentence());
      await Future<void>.delayed(Duration.zero);
      expect(h.state.isSentencePlaying, true);

      // 再次点击 → 停止
      unawaited(h.engine.userToggleSentence());
      await Future<void>.delayed(Duration.zero);
      expect(h.state.isSentencePlaying, false);
      expect(
        (h.phase as FlashcardWaitingForUser).reason,
        FlashcardWaitingReason.userStoppedPlayback,
      );
    });
  });

  // ========== 恢复自动流程 ==========

  group('恢复自动流程', () {
    test('WaitingForUser → startCard → 恢复正面自动', () async {
      h.autoPlayWord = false;
      h.syncConfig();

      unawaited(h.engine.startCard(word: 'hello', hasSentence: false));
      await Future<void>.delayed(Duration.zero);
      h.engine.enterWaitingForUser(FlashcardWaitingReason.userFlippedCard);
      expect(h.phase, isA<FlashcardWaitingForUser>());

      // next card → 新卡片恢复自动
      unawaited(h.engine.startCard(word: 'world', hasSentence: false));
      await Future<void>.delayed(Duration.zero);
      expect(h.phase, isA<FlashcardCountdown>());
      expect(h.state.isShowingBack, false);
    });
  });

  // ========== 后台切换 ==========

  group('后台切换', () {
    test('后台 → WaitingForUser，回前台保持', () async {
      h.autoPlayWord = false;
      h.syncConfig();

      unawaited(h.engine.startCard(word: 'hello', hasSentence: false));
      await Future<void>.delayed(Duration.zero);
      expect(h.phase, isA<FlashcardCountdown>());

      // 切到后台
      h.engine.enterWaitingForUser(FlashcardWaitingReason.appBackgrounded);
      expect(h.phase, isA<FlashcardWaitingForUser>());
      expect(
        (h.phase as FlashcardWaitingForUser).reason,
        FlashcardWaitingReason.appBackgrounded,
      );

      // "回前台"不调用任何方法 → 保持 WaitingForUser
      expect(h.phase, isA<FlashcardWaitingForUser>());
    });
  });

  // ========== 手动模式 ==========

  group('手动模式', () {
    test('手动模式 → 正面直接 WaitingForUser', () async {
      h.manualMode = true;
      h.autoPlayWord = false;
      h.syncConfig();

      unawaited(h.engine.startCard(word: 'hello', hasSentence: false));
      await Future<void>.delayed(Duration.zero);

      expect(h.phase, isA<FlashcardWaitingForUser>());
      expect(
        (h.phase as FlashcardWaitingForUser).reason,
        FlashcardWaitingReason.manualMode,
      );
    });

    test('手动模式 + autoPlayWord → TTS 播完后 WaitingForUser', () async {
      h.manualMode = true;
      h.syncConfig();

      unawaited(h.engine.startCard(word: 'hello', hasSentence: false));
      await Future<void>.delayed(Duration.zero);

      // 手动模式下 autoPlayWord 仍然播放 TTS
      expect(h.phase, isA<FlashcardPlayingTts>());
      expect(h.tts.callCount, 1);

      // TTS 完成后进入 WaitingForUser
      h.tts.completeSpeaking();
      await Future<void>.delayed(Duration.zero);
      expect(h.phase, isA<FlashcardWaitingForUser>());
      expect(
        (h.phase as FlashcardWaitingForUser).reason,
        FlashcardWaitingReason.manualMode,
      );
    });

    test('手动模式 → 背面 TTS+句子播完后 WaitingForUser', () async {
      h.manualMode = true;
      h.syncConfig();

      unawaited(h.engine.startBackAutoPlay(word: 'hello', hasSentence: true));
      await Future<void>.delayed(Duration.zero);

      // TTS 播放
      expect(h.phase, isA<FlashcardPlayingTts>());
      h.tts.completeSpeaking();
      await Future<void>.delayed(Duration.zero);

      // 句子播放
      expect(h.phase, isA<FlashcardPlayingSentence>());
      h.sentencePlayer.completePlayback();
      await Future<void>.delayed(Duration.zero);

      // 播完后进入等待
      expect(h.phase, isA<FlashcardWaitingForUser>());
    });
  });

  // ========== userFlipCard ==========

  group('userFlipCard', () {
    test('翻转改变 isShowingBack + 进入 WaitingForUser', () async {
      h.autoPlayWord = false;
      h.syncConfig();

      unawaited(h.engine.startCard(word: 'hello', hasSentence: false));
      await Future<void>.delayed(Duration.zero);
      expect(h.state.isShowingBack, false);
      expect(h.phase, isA<FlashcardCountdown>());

      // 一次翻转：取消倒计时 + 翻转 + WaitingForUser
      h.engine.userFlipCard();
      expect(h.state.isShowingBack, true);
      expect(h.phase, isA<FlashcardWaitingForUser>());

      // 再翻回来
      h.engine.userFlipCard();
      expect(h.state.isShowingBack, false);
      expect(h.phase, isA<FlashcardWaitingForUser>());
    });

    test('TTS 播放中翻转不中断播放', () async {
      unawaited(h.engine.startCard(word: 'hello', hasSentence: false));
      await Future<void>.delayed(Duration.zero);
      expect(h.phase, isA<FlashcardPlayingTts>());
      expect(h.tts.isSpeaking, true);

      final stopBefore = h.stopCallCount;
      h.engine.userFlipCard();

      // 不调用 stopAllPlayback
      expect(h.stopCallCount, stopBefore);
      expect(h.state.isShowingBack, true);
      expect(h.phase, isA<FlashcardWaitingForUser>());
    });

    test('句子播放中翻转不中断播放', () async {
      unawaited(h.engine.startBackAutoPlay(word: 'hello', hasSentence: true));
      await Future<void>.delayed(Duration.zero);
      h.tts.completeSpeaking();
      await Future<void>.delayed(Duration.zero);
      expect(h.phase, isA<FlashcardPlayingSentence>());

      final stopBefore = h.stopCallCount;
      h.engine.userFlipCard();

      expect(h.stopCallCount, stopBefore);
      expect(h.phase, isA<FlashcardWaitingForUser>());
    });

    test('SessionCompleted 中翻转无效', () {
      h.engine.markCompleted();
      final historyBefore = h.stateHistory.length;
      h.engine.userFlipCard();
      expect(h.stateHistory.length, historyBefore);
    });
  });

  // ========== 会话完成 ==========

  group('会话完成', () {
    test('markCompleted → SessionCompleted', () {
      h.engine.markCompleted();
      expect(h.phase, isA<FlashcardSessionCompleted>());
    });
  });

  // ========== flowToken 防竞态 ==========

  group('flowToken 防竞态', () {
    test('startCard 使旧 TTS 回调失效', () async {
      unawaited(h.engine.startCard(word: 'hello', hasSentence: false));
      await Future<void>.delayed(Duration.zero);
      expect(h.phase, isA<FlashcardPlayingTts>());

      // 切到第二张（第一张 TTS 还没完成）
      unawaited(h.engine.startCard(word: 'world', hasSentence: false));
      await Future<void>.delayed(Duration.zero);

      h.tts.completeSpeaking();
      await Future<void>.delayed(Duration.zero);

      expect(h.tts.lastWord, 'world');
    });

    test('userFlipCard 使正面自动流程的后续步骤失效', () async {
      // 正面 TTS 播放中
      unawaited(h.engine.startCard(word: 'hello', hasSentence: false));
      await Future<void>.delayed(Duration.zero);
      expect(h.phase, isA<FlashcardPlayingTts>());

      // 用户翻转 → flowToken 递增
      h.engine.userFlipCard();
      expect(h.phase, isA<FlashcardWaitingForUser>());

      // 旧 TTS 完成 → 不应启动倒计时
      h.tts.completeSpeaking();
      await Future<void>.delayed(Duration.zero);
      expect(h.phase, isA<FlashcardWaitingForUser>());
    });

    test('userFlipCard 使背面自动流程的后续步骤失效', () async {
      // 背面 TTS 播放中
      unawaited(h.engine.startBackAutoPlay(word: 'hello', hasSentence: true));
      await Future<void>.delayed(Duration.zero);
      expect(h.phase, isA<FlashcardPlayingTts>());

      // 用户翻转
      h.engine.userFlipCard();
      expect(h.phase, isA<FlashcardWaitingForUser>());

      // 旧 TTS 完成 → 不应进入 PlayingSentence 或 Countdown
      h.tts.completeSpeaking();
      await Future<void>.delayed(Duration.zero);
      expect(h.phase, isA<FlashcardWaitingForUser>());
      expect(h.sentencePlayer.callCount, 0);
    });

    test('userFlipCard 使背面句子播放后的倒计时失效', () async {
      // 背面句子播放中
      unawaited(h.engine.startBackAutoPlay(word: 'hello', hasSentence: true));
      await Future<void>.delayed(Duration.zero);
      h.tts.completeSpeaking();
      await Future<void>.delayed(Duration.zero);
      expect(h.phase, isA<FlashcardPlayingSentence>());

      // 用户翻转
      h.engine.userFlipCard();
      expect(h.phase, isA<FlashcardWaitingForUser>());

      // 旧句子播放完成 → 不应启动倒计时
      h.sentencePlayer.completePlayback();
      await Future<void>.delayed(Duration.zero);
      expect(h.phase, isA<FlashcardWaitingForUser>());
    });
  });

  // ========== 设置组合覆盖 ==========

  group('设置组合', () {
    test('autoPlayWord=false + autoPlaySentence=true 背面 → 只播句子', () async {
      h.autoPlayWord = false;
      h.syncConfig();

      unawaited(h.engine.startBackAutoPlay(word: 'hello', hasSentence: true));
      await Future<void>.delayed(Duration.zero);

      // 跳过 TTS，直接句子
      expect(h.tts.callCount, 0);
      expect(h.phase, isA<FlashcardPlayingSentence>());

      h.sentencePlayer.completePlayback();
      await Future<void>.delayed(Duration.zero);
      expect(h.phase, isA<FlashcardCountdown>());
    });

    test('autoPlayWord=true 正面不播放句子', () async {
      // 正面即使有句子也不播放
      unawaited(h.engine.startCard(word: 'hello', hasSentence: true));
      await Future<void>.delayed(Duration.zero);

      // TTS
      h.tts.completeSpeaking();
      await Future<void>.delayed(Duration.zero);

      // 直接 Countdown，不播句子
      expect(h.phase, isA<FlashcardCountdown>());
      expect(h.sentencePlayer.callCount, 0);
    });

    test('手动模式 + autoPlayWord=false + autoPlaySentence=false → 直接等待', () async {
      h.manualMode = true;
      h.autoPlayWord = false;
      h.autoPlaySentence = false;
      h.syncConfig();

      unawaited(h.engine.startBackAutoPlay(word: 'hello', hasSentence: true));
      await Future<void>.delayed(Duration.zero);

      // 什么都不播，直接等待
      expect(h.tts.callCount, 0);
      expect(h.sentencePlayer.callCount, 0);
      expect(h.phase, isA<FlashcardWaitingForUser>());
    });

    test('手动模式下 userPlayWord 仍可手动播放', () async {
      h.manualMode = true;
      h.autoPlayWord = false;
      h.syncConfig();

      unawaited(h.engine.startCard(word: 'hello', hasSentence: false));
      await Future<void>.delayed(Duration.zero);
      expect(h.phase, isA<FlashcardWaitingForUser>());

      unawaited(h.engine.userPlayWord('hello'));
      await Future<void>.delayed(Duration.zero);
      expect(h.tts.callCount, 1);
      expect(h.phase, isA<FlashcardWaitingForUser>());
    });

    test('手动模式下 userToggleSentence 仍可手动播放', () async {
      h.manualMode = true;
      h.autoPlayWord = false;
      h.syncConfig();

      unawaited(h.engine.startCard(word: 'hello', hasSentence: true));
      await Future<void>.delayed(Duration.zero);
      expect(h.phase, isA<FlashcardWaitingForUser>());

      unawaited(h.engine.userToggleSentence());
      await Future<void>.delayed(Duration.zero);
      expect(h.sentencePlayer.callCount, 1);
      expect(h.state.isSentencePlaying, true);
    });
  });

  // ========== startBackAutoPlay 状态重置 ==========

  group('startBackAutoPlay 状态重置', () {
    test('startBackAutoPlay 重置 isSentencePlaying', () async {
      h.autoPlayWord = false;
      h.syncConfig();

      // 先手动播放句子使 isSentencePlaying=true
      unawaited(h.engine.startCard(word: 'hello', hasSentence: true));
      await Future<void>.delayed(Duration.zero);
      unawaited(h.engine.userToggleSentence());
      await Future<void>.delayed(Duration.zero);
      expect(h.state.isSentencePlaying, true);

      // startBackAutoPlay 应重置 isSentencePlaying
      h.autoPlayWord = false;
      h.autoPlaySentence = false;
      h.syncConfig();
      unawaited(h.engine.startBackAutoPlay(word: 'hello', hasSentence: false));
      await Future<void>.delayed(Duration.zero);
      expect(h.state.isSentencePlaying, false);
    });
  });

  // ========== enterWaitingForUser 从 Idle ==========

  group('边界情况', () {
    test('Idle 状态调用 enterWaitingForUser', () {
      // engine 初始在 Idle
      expect(h.phase, isA<FlashcardIdle>());

      h.engine.enterWaitingForUser(FlashcardWaitingReason.appBackgrounded);
      expect(h.phase, isA<FlashcardWaitingForUser>());
    });

    test('dispose 后所有操作无效', () async {
      h.dispose();

      // 所有操作都应无效，不抛异常
      await h.engine.startCard(word: 'hello', hasSentence: false);
      h.engine.userFlipCard();
      h.engine.enterWaitingForUser(FlashcardWaitingReason.userFlippedCard);
      await h.engine.userPlayWord('hello');
      await h.engine.userToggleSentence();
      h.engine.markCompleted();

      expect(h.tts.callCount, 0);
    });

    test('userFlipCard 从 WaitingForUser 可再次翻转', () async {
      h.autoPlayWord = false;
      h.syncConfig();

      unawaited(h.engine.startCard(word: 'hello', hasSentence: false));
      await Future<void>.delayed(Duration.zero);

      // 进入 WaitingForUser
      h.engine.enterWaitingForUser(FlashcardWaitingReason.userTappedCountdown);
      expect(h.state.isShowingBack, false);

      // 翻转到背面
      h.engine.userFlipCard();
      expect(h.state.isShowingBack, true);
      expect(h.phase, isA<FlashcardWaitingForUser>());

      // 再翻回正面
      h.engine.userFlipCard();
      expect(h.state.isShowingBack, false);
      expect(h.phase, isA<FlashcardWaitingForUser>());
    });
  });

  // ========== 卡片切换状态隔离 ==========

  group('卡片切换状态隔离', () {
    test('TTS 播放中切卡 → 新卡片 phase 不残留旧 TTS 状态', () async {
      // 卡片 A：TTS 播放中
      unawaited(h.engine.startCard(word: 'apple', hasSentence: false));
      await Future<void>.delayed(Duration.zero);
      expect(h.phase, isA<FlashcardPlayingTts>());
      expect(h.tts.lastWord, 'apple');

      // 立即切到卡片 B（A 的 TTS 还没完成）
      unawaited(h.engine.startCard(word: 'banana', hasSentence: false));
      await Future<void>.delayed(Duration.zero);

      // B 应该在 PlayingTts，不是 A 的 PlayingTts
      expect(h.phase, isA<FlashcardPlayingTts>());
      expect(h.tts.lastWord, 'banana');

      // A 的 TTS 回调返回 → 不应影响 B 的状态
      h.tts.completeSpeaking();
      await Future<void>.delayed(Duration.zero);

      // B 的流程正常继续：TTS 完成 → Countdown
      expect(h.phase, isA<FlashcardCountdown>());
    });

    test('倒计时中切卡 → 新卡片不显示旧倒计时', () async {
      h.autoPlayWord = false;
      h.syncConfig();

      // 卡片 A：直接进入倒计时
      unawaited(h.engine.startCard(word: 'apple', hasSentence: false));
      await Future<void>.delayed(Duration.zero);
      expect(h.phase, isA<FlashcardCountdown>());

      // 切到卡片 B
      unawaited(h.engine.startCard(word: 'banana', hasSentence: false));
      await Future<void>.delayed(Duration.zero);

      // B 应该有自己的倒计时，不是 A 的残留
      expect(h.phase, isA<FlashcardCountdown>());
      // flowToken 已递增，旧回调不会干扰
      expect(h.state.flowToken, greaterThan(1));
    });

    test('倒计时中切卡 → 旧倒计时 tick 不更新新卡片 phase', () async {
      h.autoPlayWord = false;
      h.frontTimerSeconds = 3;
      h.syncConfig();

      // 卡片 A：进入倒计时（autoPlayWord=false → 直接倒计时）
      unawaited(h.engine.startCard(word: 'apple', hasSentence: false));
      await Future<void>.delayed(const Duration(milliseconds: 200));
      expect(h.phase, isA<FlashcardCountdown>());
      final tokenA = h.state.flowToken;

      // 切到卡片 B（开启 autoPlayWord，B 会走 TTS 流程）
      h.autoPlayWord = true;
      h.syncConfig();
      unawaited(h.engine.startCard(word: 'banana', hasSentence: false));
      await Future<void>.delayed(Duration.zero);
      expect(h.state.flowToken, greaterThan(tokenA));

      // 等待足够时间，确保 A 的旧 tick（如果有残留）不会干扰
      await Future<void>.delayed(const Duration(milliseconds: 300));

      // B 仍在 PlayingTts（TTS 还没完成），不应被 A 的倒计时干扰
      expect(h.phase, isA<FlashcardPlayingTts>());
      expect(h.tts.lastWord, 'banana');
    });

    test('背面句子播放中切卡 → 新卡片 phase 干净', () async {
      // 卡片 A 背面：句子播放中
      unawaited(h.engine.startBackAutoPlay(word: 'apple', hasSentence: true));
      await Future<void>.delayed(Duration.zero);
      h.tts.completeSpeaking();
      await Future<void>.delayed(Duration.zero);
      expect(h.phase, isA<FlashcardPlayingSentence>());

      // 切到卡片 B
      unawaited(h.engine.startCard(word: 'banana', hasSentence: false));
      await Future<void>.delayed(Duration.zero);

      // B 应该在自己的 TTS 阶段
      expect(h.phase, isA<FlashcardPlayingTts>());
      expect(h.tts.lastWord, 'banana');
      expect(h.state.isShowingBack, false);
      expect(h.state.isSentencePlaying, false);

      // A 的句子播放完成 → 不应影响 B
      h.sentencePlayer.completePlayback();
      await Future<void>.delayed(Duration.zero);
      expect(h.phase, isA<FlashcardPlayingTts>());
    });

    test('正面倒计时到期后 → phase 立即清除为 Idle', () async {
      h.autoPlayWord = false;
      h.frontTimerSeconds = 1;
      h.syncConfig();

      unawaited(h.engine.startCard(word: 'apple', hasSentence: false));
      await Future<void>.delayed(Duration.zero);
      expect(h.phase, isA<FlashcardCountdown>());

      // 等待倒计时到期
      await Future<void>.delayed(const Duration(milliseconds: 1200));

      // 到期后 phase 应为 Idle（不再是 FlashcardCountdown）
      expect(h.phase, isA<FlashcardIdle>());
      expect(h.autoFlipCount, 1);
    });

    test('背面倒计时到期后 → phase 立即清除为 Idle', () async {
      h.autoPlayWord = false;
      h.autoPlaySentence = false;
      h.backTimerSeconds = 1;
      h.syncConfig();

      unawaited(h.engine.startBackAutoPlay(word: 'apple', hasSentence: false));
      await Future<void>.delayed(Duration.zero);
      expect(h.phase, isA<FlashcardCountdown>());

      // 等待倒计时到期
      await Future<void>.delayed(const Duration(milliseconds: 1200));

      // 到期后 phase 应为 Idle
      expect(h.phase, isA<FlashcardIdle>());
      expect(h.autoNextCount, 1);
    });

    test('快速连续切卡 → 只有最后一张卡的流程在运行', () async {
      // 快速切 3 张卡
      unawaited(h.engine.startCard(word: 'a', hasSentence: false));
      await Future<void>.delayed(Duration.zero);
      unawaited(h.engine.startCard(word: 'b', hasSentence: false));
      await Future<void>.delayed(Duration.zero);
      unawaited(h.engine.startCard(word: 'c', hasSentence: false));
      await Future<void>.delayed(Duration.zero);

      // 只有最后一张的 TTS 应该生效
      expect(h.tts.lastWord, 'c');
      expect(h.phase, isA<FlashcardPlayingTts>());

      // 完成 TTS → 应该进入 C 的倒计时
      h.tts.completeSpeaking();
      await Future<void>.delayed(Duration.zero);
      expect(h.phase, isA<FlashcardCountdown>());
    });

    test('切卡时 flowToken 递增 → 旧自动流程全部失效', () async {
      unawaited(h.engine.startCard(word: 'apple', hasSentence: false));
      await Future<void>.delayed(Duration.zero);
      final tokenA = h.state.flowToken;

      unawaited(h.engine.startCard(word: 'banana', hasSentence: false));
      await Future<void>.delayed(Duration.zero);
      final tokenB = h.state.flowToken;

      expect(tokenB, greaterThan(tokenA));
    });

    test('WaitingForUser 中切卡 → 新卡片正常启动', () async {
      // 卡片 A：进入 WaitingForUser
      unawaited(h.engine.startCard(word: 'apple', hasSentence: false));
      await Future<void>.delayed(Duration.zero);
      h.engine.enterWaitingForUser(FlashcardWaitingReason.userTappedCountdown);
      expect(h.phase, isA<FlashcardWaitingForUser>());

      // 切到卡片 B
      unawaited(h.engine.startCard(word: 'banana', hasSentence: false));
      await Future<void>.delayed(Duration.zero);

      // B 正常启动，不残留 WaitingForUser
      expect(h.phase, isA<FlashcardPlayingTts>());
      expect(h.tts.lastWord, 'banana');
      expect(h.state.isShowingBack, false);
    });

    test('userFlipCard 中切卡 → 翻转状态重置', () async {
      h.autoPlayWord = false;
      h.syncConfig();

      // 卡片 A：翻到背面
      unawaited(h.engine.startCard(word: 'apple', hasSentence: false));
      await Future<void>.delayed(Duration.zero);
      h.engine.userFlipCard();
      expect(h.state.isShowingBack, true);

      // 切到卡片 B
      unawaited(h.engine.startCard(word: 'banana', hasSentence: false));
      await Future<void>.delayed(Duration.zero);

      // B 应该显示正面
      expect(h.state.isShowingBack, false);
      expect(h.phase, isA<FlashcardCountdown>());
    });

    test('isSentencePlaying 在切卡后重置', () async {
      h.autoPlayWord = false;
      h.syncConfig();

      // 通过手动播放使 isSentencePlaying=true
      unawaited(h.engine.startCard(word: 'apple', hasSentence: true));
      await Future<void>.delayed(Duration.zero);
      unawaited(h.engine.userToggleSentence());
      await Future<void>.delayed(Duration.zero);
      expect(h.state.isSentencePlaying, true);

      // 切到卡片 B
      unawaited(h.engine.startCard(word: 'banana', hasSentence: false));
      await Future<void>.delayed(Duration.zero);

      // isSentencePlaying 必须为 false
      expect(h.state.isSentencePlaying, false);
    });
  });
}
