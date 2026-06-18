/// ListeningPractice 播放编排回归测试
///
/// 覆盖三类历史 bug：
/// 1. 讲解页旁路驱动共享引擎（newSession + 位置流）不应污染 LP 的 currentFullIndex；
/// 2. 讲解页返回后 restorePosition() 把引擎对齐回当前句，主播放从原句继续（不跳第一句）；
/// 3. 单句循环重复当前句、不跳到第一句。
library;

import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:just_audio/just_audio.dart' as ja;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:echo_loop/models/playback_settings.dart';
import 'package:echo_loop/models/sentence.dart';
import 'package:echo_loop/providers/audio_engine/audio_engine_provider.dart';
import 'package:echo_loop/providers/listening_practice/listening_practice_provider.dart';
import '../../helpers/mock_providers.dart';

/// 测试用 AudioEngine：真实 session 计数 + 可控位置/状态流 + clip 记录。
class _SessionAudioEngine extends TestAudioEngine {
  int _sessionId = 0;
  final _positionController = StreamController<Duration>.broadcast();
  final _playerStateController = StreamController<ja.PlayerState>.broadcast();

  /// 模拟引擎当前播放位置
  Duration position = Duration.zero;

  /// 记录最后一次 seek 的目标位置
  Duration? lastSeek;

  /// 记录最后一次 setClip 的起点
  Duration? lastClipStart;

  @override
  Duration get currentPosition => position;

  @override
  Future<void> seek(Duration pos) async {
    lastSeek = pos;
  }

  @override
  Future<void> setClip(Duration start, Duration end) async {
    lastClipStart = start;
  }

  @override
  int newSession() {
    _sessionId += 1;
    return _sessionId;
  }

  @override
  int get currentSessionId => _sessionId;

  @override
  bool isActiveSession(int id) => id == _sessionId;

  @override
  Stream<Duration> get absolutePositionStream => _positionController.stream;

  @override
  Stream<ja.PlayerState> get playerStateStream => _playerStateController.stream;

  void emitPosition(Duration position) => _positionController.add(position);

  void emitPlayerState(ja.PlayerState playerState) =>
      _playerStateController.add(playerState);

  void closeStreams() {
    _positionController.close();
    _playerStateController.close();
  }
}

/// 可注入 state 的 ListeningPractice 子类（复用真实业务逻辑，仅暴露 seed 入口）。
class _TestableListeningPractice extends ListeningPractice {
  void seed({
    required List<Sentence> sentences,
    required PlaybackSettings settings,
    required int currentFullIndex,
  }) {
    state = state.copyWith(
      currentAudioItem: createTestAudioItem(),
      sentences: sentences,
      settings: settings,
      currentFullIndex: currentFullIndex,
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  // 连播（gapless）：两个循环都关，走整段无缝
  const continuousSettings = PlaybackSettings();

  final sentences = [
    Sentence(
      index: 0,
      text: 'First.',
      startTime: Duration.zero,
      endTime: const Duration(seconds: 3),
    ),
    Sentence(
      index: 1,
      text: 'Second.',
      startTime: const Duration(seconds: 3),
      endTime: const Duration(seconds: 6),
    ),
    Sentence(
      index: 2,
      text: 'Third.',
      startTime: const Duration(seconds: 6),
      endTime: const Duration(seconds: 9),
    ),
  ];

  late ProviderContainer container;
  late _SessionAudioEngine engine;
  late _TestableListeningPractice lp;

  setUp(() async {
    engine = _SessionAudioEngine();
    container = ProviderContainer(
      overrides: [
        audioEngineProvider.overrideWith(() => engine),
        listeningPracticeProvider.overrideWith(
          () => _TestableListeningPractice(),
        ),
      ],
    );
    lp =
        container.read(listeningPracticeProvider.notifier)
            as _TestableListeningPractice;
    // 等待 build 内 _setupListeners 的 microtask 完成订阅
    await Future<void>.delayed(Duration.zero);
  });

  tearDown(() {
    container.dispose();
    engine.closeStreams();
  });

  test('外来 session 的位置事件不改 currentFullIndex（讲解页试听场景）', () async {
    lp.seed(
      sentences: sentences,
      settings: continuousSettings,
      currentFullIndex: 2,
    );
    // 模拟讲解页：bump session（顶掉 LP 的 session）+ 正在播放
    engine.newSession();
    engine.isPlaying = true;

    // 讲解页试听第 1 句时，位置流推送的位置落在第 0 句
    engine.emitPosition(Duration.zero);
    await Future<void>.delayed(Duration.zero);

    // LP 未发起本次播放（_playbackSessionId 仍为初值），事件应被忽略
    expect(container.read(listeningPracticeProvider).currentFullIndex, 2);
  });

  test('LP 自己 session 的位置事件正常推进 currentFullIndex', () async {
    lp.seed(
      sentences: sentences,
      settings: continuousSettings,
      currentFullIndex: 0,
    );
    // play() 进入 gapless 起播：newSession 后把 _playbackSessionId 设为当前 session
    unawaited(container.read(listeningPracticeProvider.notifier).play());
    await Future<void>.delayed(Duration.zero);
    engine.isPlaying = true;

    // LP 自己的 session 处于活动态，位置落在第 1 句应推进高亮
    engine.emitPosition(const Duration(seconds: 3));
    await Future<void>.delayed(Duration.zero);

    expect(container.read(listeningPracticeProvider).currentFullIndex, 1);
  });

  test('讲解页驱动后 restorePosition 把引擎对齐回当前句起点', () async {
    lp.seed(
      sentences: sentences,
      settings: continuousSettings,
      currentFullIndex: 2,
    );
    // 正常暂停后进讲解页：讲解页 bump session + 改写引擎位置
    await container.read(listeningPracticeProvider.notifier).pause();
    engine.newSession();
    engine.position = const Duration(seconds: 1);
    engine.lastSeek = null;

    // 返回后显式恢复：应 seek 回第 2 句起点（6s），不续播被污染的 1s
    await container.read(listeningPracticeProvider.notifier).restorePosition();

    expect(engine.lastSeek, const Duration(seconds: 6));
  });

  test('单句循环重复当前句，完成后不跳到第一句', () async {
    lp.seed(
      sentences: sentences,
      settings: const PlaybackSettings(
        loopSentence: true,
        sentenceLoopCount: 0, // ∞ 无限重复当前句
        sentenceInterval: Duration.zero,
      ),
      currentFullIndex: 2,
    );

    // 起播：gapless 永不 setClip，应 seek 到第 2 句句首（6s）并监听其句尾。
    unawaited(container.read(listeningPracticeProvider.notifier).play());
    await Future<void>.delayed(Duration.zero);
    expect(engine.lastSeek, const Duration(seconds: 6));
    expect(engine.lastClipStart, isNull); // 不再 setClip

    // 模拟越过句尾（completed 兜底）→ 单句循环应重播当前句，而非跳到第 0 句。
    engine.lastSeek = null;
    engine.emitPlayerState(ja.PlayerState(false, ja.ProcessingState.completed));
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);

    expect(container.read(listeningPracticeProvider).currentFullIndex, 2);
    expect(engine.lastSeek, const Duration(seconds: 6)); // 重播回句首
  });

  test('单句循环：越过句尾（位置流）重播当前句', () async {
    lp.seed(
      sentences: sentences,
      settings: const PlaybackSettings(
        loopSentence: true,
        sentenceLoopCount: 0,
        sentenceInterval: Duration.zero,
      ),
      currentFullIndex: 1, // 第 1 句 3-6s
    );

    unawaited(container.read(listeningPracticeProvider.notifier).play());
    await Future<void>.delayed(Duration.zero);
    expect(engine.lastSeek, const Duration(seconds: 3));
    engine.isPlaying = true;

    // 播放头越过第 1 句句尾（6s）→ 应 seek 回句首 3s 重播，不进第 2 句。
    engine.lastSeek = null;
    engine.emitPosition(const Duration(seconds: 6));
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);

    expect(container.read(listeningPracticeProvider).currentFullIndex, 1);
    expect(engine.lastSeek, const Duration(seconds: 3));
  });

  test('进度条任意位置拖动：从落点续播，不吸附句首', () async {
    lp.seed(
      sentences: sentences,
      settings: continuousSettings, // gapless，不监听句尾
      currentFullIndex: 0,
    );
    // 起播建立 LP 自己的 session
    unawaited(container.read(listeningPracticeProvider.notifier).play());
    await Future<void>.delayed(Duration.zero);
    engine.isPlaying = true;

    // 拖到 7.5s（落在第 2 句 6-9s 内的任意位置）
    engine.lastSeek = null;
    await container
        .read(listeningPracticeProvider.notifier)
        .seekAbsolute(const Duration(milliseconds: 7500));

    // seek 到落点本身（不是句首 6s），高亮更新到第 2 句
    expect(engine.lastSeek, const Duration(milliseconds: 7500));
    expect(container.read(listeningPracticeProvider).currentFullIndex, 2);
  });
}
