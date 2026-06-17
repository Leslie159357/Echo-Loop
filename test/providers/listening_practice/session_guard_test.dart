/// ListeningPractice 监听器 session 守卫测试
///
/// 回归用例：句子讲解页等组件会旁路驱动同一个 AudioEngine（playRangeOnce），
/// 并通过 newSession() 顶掉当前 session。LP 的位置/状态监听只应处理「属于 LP
/// 自己播放 session」的事件，外来 session 的事件必须忽略，否则讲解页试听单句时
/// 位置流会把 currentFullIndex 改成被试听的句子，返回后主播放按钮就从那一句
/// （常表现为第一句）重新开始。
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

/// 测试用 AudioEngine：真实 session 计数 + 可控位置/状态流。
class _SessionAudioEngine extends TestAudioEngine {
  int _sessionId = 0;
  final _positionController = StreamController<Duration>.broadcast();
  final _playerStateController = StreamController<ja.PlayerState>.broadcast();

  /// 模拟引擎当前播放位置（用于 isResume 判定）
  Duration position = Duration.zero;

  /// 记录最后一次 seek 的目标位置
  Duration? lastSeek;

  @override
  Duration get currentPosition => position;

  @override
  Future<void> seek(Duration pos) async {
    lastSeek = pos;
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
  Stream<ja.PlayerState> get playerStateStream =>
      _playerStateController.stream;

  /// 模拟引擎推送一个绝对位置
  void emitPosition(Duration position) => _positionController.add(position);

  /// 模拟引擎推送一个播放状态
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

  // 连续播放模式（默认）：autoPlayNext=true 且 loopEnabled=false
  const continuousSettings = PlaybackSettings(
    autoPlayNextSentenceEnabled: true,
    loopEnabled: false,
  );

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
    lp = container.read(listeningPracticeProvider.notifier)
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
    // 不 await：play 会停在等待 playerStateStream 的 await 点，
    // 但此前已 newSession() 并把 _playbackSessionId 设为当前 session
    unawaited(container.read(listeningPracticeProvider.notifier).play());
    await Future<void>.delayed(Duration.zero);
    engine.isPlaying = true;

    // LP 自己的 session 处于活动态，位置落在第 1 句应推进高亮
    engine.emitPosition(const Duration(seconds: 3));
    await Future<void>.delayed(Duration.zero);

    expect(container.read(listeningPracticeProvider).currentFullIndex, 1);

    // 推送完成态，让 _playContinuous 的 firstWhere 正常结束，避免悬挂
    engine.emitPlayerState(
      ja.PlayerState(false, ja.ProcessingState.completed),
    );
    await Future<void>.delayed(Duration.zero);
  });

  test('外来 session 驱动后再播放，按 currentFullIndex 重新定位而非续播引擎位置', () async {
    lp.seed(
      sentences: sentences,
      settings: continuousSettings,
      currentFullIndex: 2,
    );
    // LP 暂停：把当前 session 记为自己持有（模拟正常「暂停→继续」前置）
    await container.read(listeningPracticeProvider.notifier).pause();
    // 模拟讲解页旁路驱动：bump session + 引擎位置被改写到非零（若不校验 session，
    // 这个非零位置会让 play() 误判为「续播」从而从被污染的位置播放）
    engine.newSession();
    engine.position = const Duration(seconds: 1);
    engine.lastSeek = null;

    unawaited(container.read(listeningPracticeProvider.notifier).play());
    await Future<void>.delayed(Duration.zero);

    // 应重新 seek 到第 2 句起点（6s），而不是续播引擎当前的 1s
    expect(engine.lastSeek, const Duration(seconds: 6));

    engine.emitPlayerState(
      ja.PlayerState(false, ja.ProcessingState.completed),
    );
    await Future<void>.delayed(Duration.zero);
  });
}
