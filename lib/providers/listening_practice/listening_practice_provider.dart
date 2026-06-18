import 'dart:async';
import 'package:just_audio/just_audio.dart' as ja;
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../analytics/analytics_providers.dart';
import '../../analytics/models/event_names.dart';
import '../../features/usage/usage_event.dart';
import '../../features/usage/usage_providers.dart';
import '../../database/providers.dart';
import '../../models/audio_item.dart';
import '../../models/sentence.dart';
import '../../models/playback_settings.dart';
import '../../models/listening_practice_state.dart';
import '../../services/app_logger.dart';
import '../../services/storage_service.dart';
import '../audio_engine/audio_engine_provider.dart';
import '../notification_permission_provider.dart';
import 'bookmark_manager.dart';
import 'playback_reducer.dart';
import 'playback_state_storage.dart';
import 'sentence_tracker.dart';

export '../../models/listening_practice_state.dart'
    show PlaylistMode, ListeningPracticeState;

part 'listening_practice_provider.g.dart';

/// 自由练习播放器的状态与业务编排。
///
/// 播放推进采用单一的「事件驱动」模型：底层 [AudioEngine]（多个功能共享的
/// 单实例 just_audio）只在「一句/整段播放完成」时回调 [_onPlayerStateChanged]，
/// 由纯函数 [decideNext] 决定下一步（重播 / 进下一句 / 回卷 / 停止）。
/// 不再有跨多次 await 持有状态的长协程，避免索引乱跳。
///
/// 真相源是 [ListeningPracticeState.currentFullIndex] /
/// [ListeningPracticeState.currentBookmarkIndex]，只在以下入口被修改：
/// 用户显式选句/上下句、连播时位置流推进（仅 gapless 模式）、完成事件归约器。
@Riverpod(keepAlive: true)
class ListeningPractice extends _$ListeningPractice {
  StreamSubscription? _positionSub;
  StreamSubscription? _playerStateSub;

  /// 追踪正在进行的音频加载，避免重复调用时跳过未完成的加载
  Completer<void>? _loadingCompleter;

  /// 当前句已完成播放的次数（含刚结束这次）。进新句时归零。
  int _sentenceRepeatsDone = 0;

  /// 整篇已完成的遍数。换音频/重新起播时归零。
  ///
  /// gapless 整段自然播完即 +1；监听句尾模式下走到末尾并回到第 0 句时 +1。
  int _wholeLoopsDone = 0;

  /// 当前监听句在 [_playable] 中的位置（0-based）。null=不监听句尾。
  ///
  /// 永不 setClip 的 gapless 模式下，单句循环/收藏跳播靠监听 positionStream，
  /// 当播放头越过 [_watchEndTime] 时触发推进。
  int? _watchPos;

  /// 当前监听句的 endTime（绝对时间）。播放头越过即触发边界处理。
  ///
  /// 缓存为字段而非每次从 state 重算：pause→seek→resume 期间真相源 index 可能尚未
  /// 更新，用缓存值判断「是否已离开旧边界」更确定。
  Duration? _watchEndTime;

  /// 边界处理代际计数器。每次新边界/新起播 +1；在途处理协程跨 await 校验代际，
  /// 被顶掉则丢弃，避免旧协程错误地推进或重置闸门。
  int _boundaryGen = 0;

  /// 边界处理单飞闸门：position 流约 200ms 一帧，处理期间丢弃后续位置事件，
  /// 避免一次越界触发多次推进。也用于隔离整段 completed 与边界路径的竞争。
  bool _handlingBoundary = false;

  /// LP 自己发起播放时持有的 AudioEngine sessionId。
  ///
  /// engine 的 position/playerState 流是全局共享的：句子讲解页等组件会旁路
  /// 驱动同一个 engine（`playRangeOnce`），并通过 `newSession()` 顶掉当前 session。
  /// 监听回调只处理「属于 LP 当前播放 session」的事件，外来 session 的事件一律
  /// 忽略——否则讲解页试听单句时，位置流会把 `currentFullIndex` 改成被试听的句子，
  /// 返回后主播放按钮就从那一句（常表现为第一句）重新开始。
  int _playbackSessionId = -1;

  @override
  ListeningPracticeState build() {
    _setupListeners();
    ref.onDispose(_disposeListeners);
    _loadSettings();
    return const ListeningPracticeState();
  }

  // --- 获取 AudioEngine ---
  AudioEngine get _engine => ref.read(audioEngineProvider.notifier);

  void _setupListeners() {
    // defer listener setup to after first build
    Future.microtask(() {
      _positionSub = _engine.absolutePositionStream.listen(_onPositionChanged);
      _playerStateSub = _engine.playerStateStream.listen(_onPlayerStateChanged);
    });
  }

  void _disposeListeners() {
    _positionSub?.cancel();
    _playerStateSub?.cancel();
  }

  /// 暂停 stream 监听（学习模式期间调用，避免 LP 接管共享引擎）。
  void suspendListeners() {
    _positionSub?.cancel();
    _playerStateSub?.cancel();
    _positionSub = null;
    _playerStateSub = null;
  }

  /// 恢复 stream 监听（退出学习模式时调用）
  void resumeListeners() {
    _setupListeners();
  }

  /// 外部标注后同步书签状态（精听退出时调用）
  Future<void> syncBookmarks() async {
    if (state.currentAudioItem == null) return;
    final bookmarkDao = ref.read(bookmarkDaoProvider);
    final bookmarkedIndices = await BookmarkManager.loadBookmarks(
      state.currentAudioItem!.id,
      dao: bookmarkDao,
    );
    BookmarkManager.updateSentenceBookmarkStatus(
      state.sentences,
      bookmarkedIndices,
    );
    state = state.copyWith(bookmarkedIndices: bookmarkedIndices);
  }

  Future<void> _loadSettings() async {
    final settings = await StorageService.loadSettings();
    state = state.copyWith(settings: settings);
  }

  // ===========================================================================
  // 播放模型辅助：播放列表 / 当前序号 / clip 形态
  // ===========================================================================

  /// 当前播放列表：全文模式=全部句子；收藏模式=收藏句子。
  List<Sentence> get _playable => state.playlistMode == PlaylistMode.bookmarks
      ? state.bookmarkedSentences
      : state.sentences;

  /// 是否需要监听句尾边界。
  ///
  /// 永不 setClip，全部 gapless 播放；但以下两种情形需要监听 positionStream、
  /// 在句尾处停下/跳转：
  /// - 单句循环（[PlaybackSettings.loopSentence]）：每句重复够再进下一句；
  /// - 收藏模式：收藏句不连续，播完一句需跳过中间非收藏句到下一收藏句。
  /// 其余（全文 + 仅整篇循环/不循环）整段连续播放，靠整段 completed 推进。
  bool get _watchBoundaries =>
      state.playlistMode == PlaylistMode.bookmarks ||
      state.settings.loopSentence;

  /// 设置当前监听句（仅在 [_watchBoundaries] 为真时生效，否则清空）。
  void _setWatch(int pos) {
    final playable = _playable;
    if (!_watchBoundaries || pos < 0 || pos >= playable.length) {
      _clearWatch();
      return;
    }
    _watchPos = pos;
    _watchEndTime = playable[pos].endTime;
  }

  void _clearWatch() {
    _watchPos = null;
    _watchEndTime = null;
  }

  /// 当前句在播放列表中的序号（0-based）。列表为空返回 null。
  int? get _currentPos {
    final playable = _playable;
    if (playable.isEmpty) return null;
    if (state.playlistMode == PlaylistMode.bookmarks) {
      final ci = state.currentBookmarkIndex;
      if (ci == null) return 0;
      final p = playable.indexWhere((s) => s.index == ci);
      return p == -1 ? 0 : p;
    } else {
      final ci = state.currentFullIndex;
      if (ci == null || ci < 0 || ci >= playable.length) return 0;
      return ci;
    }
  }

  // ===========================================================================
  // 引擎事件监听
  // ===========================================================================

  void _onPositionChanged(Duration absolutePosition) {
    if (!_engine.isActiveSession(_playbackSessionId)) return;
    if (!_engine.isPlaying) return;
    // 先检测越界：越界时 _handlingBoundary 同步置位，随后跳过高亮更新，避免高亮在
    // 句尾瞬间跳到下一句又被回卷拉回。
    _maybeCrossBoundary(absolutePosition);
    if (_handlingBoundary) return;
    _updateHighlight(absolutePosition);
  }

  /// 按实际播放位置刷新当前句高亮（gapless 下连续）。
  ///
  /// 全文模式直接按位置二分查找更新 currentFullIndex。收藏模式只在落点正好是收藏句
  /// 时更新 currentBookmarkIndex；落在非收藏区间（跳播 overshoot）保持当前高亮，
  /// 避免滑过非收藏间隙时高亮闪烁。
  void _updateHighlight(Duration position) {
    if (state.sentences.isEmpty) return;
    final idx = SentenceTracker.findSentenceIndexByPosition(
      state.sentences,
      position,
    );
    if (idx == -1) return;

    if (state.playlistMode == PlaylistMode.bookmarks) {
      if (state.bookmarkedIndices.contains(idx) &&
          idx != state.currentBookmarkIndex) {
        state = state.copyWith(currentBookmarkIndex: idx);
      }
    } else {
      if (idx != state.currentFullIndex) {
        state = state.copyWith(currentFullIndex: idx);
      }
    }
  }

  /// 检测播放头是否越过当前监听句尾，越过则触发边界处理。
  ///
  /// 防竞态四道闸：[_handlingBoundary] 单飞、[_boundaryGen] 代际、
  /// session 校验（在 [_advance] 内）、调用方 [_onPositionChanged] 已校验 isPlaying。
  void _maybeCrossBoundary(Duration absolutePosition) {
    final end = _watchEndTime;
    if (end == null || _handlingBoundary || absolutePosition < end) return;
    _handlingBoundary = true;
    final gen = ++_boundaryGen;
    final sid = _playbackSessionId;
    unawaited(
      _advance(gen, sid, sentenceBoundary: true).whenComplete(() {
        if (gen == _boundaryGen) _handlingBoundary = false;
      }),
    );
  }

  void _onPlayerStateChanged(ja.PlayerState playerState) {
    if (playerState.processingState == ja.ProcessingState.completed) {
      // 仅处理 LP 自己 session 的完成事件；与边界路径互斥（单飞）。
      if (_engine.isActiveSession(_playbackSessionId) && !_handlingBoundary) {
        _handlingBoundary = true;
        final gen = ++_boundaryGen;
        final sid = _playbackSessionId;
        // 监听句尾时整段 completed 是「末句 endTime 超出轨道」的兜底，当作越过末句尾；
        // 否则是 gapless 整段自然播完，按整篇循环判定。
        final sentenceBoundary = _watchBoundaries;
        unawaited(
          _advance(gen, sid, sentenceBoundary: sentenceBoundary).whenComplete(
            () {
              if (gen == _boundaryGen) _handlingBoundary = false;
            },
          ),
        );
      }
    }
    // 触发 isPlaying 变化的重建
    state = state.copyWith();
  }

  /// 越过监听句尾 / 整段播完后的推进：先停下播放头，再调用纯函数决策驱动引擎。
  ///
  /// [sentenceBoundary] 为 true 表示「越过当前句尾」（单句循环/收藏跳播）；false 表示
  /// 「gapless 整段自然播完」（仅整篇循环判定）。[gen]/[sid] 用于跨 await 校验本次
  /// 处理未被新边界或外来 session 顶掉。
  Future<void> _advance(
    int gen,
    int sid, {
    required bool sentenceBoundary,
  }) async {
    // 越界时音频仍在播；先停下播放头，避免越界后继续漂入下一句。
    await _engine.pauseKeepSession();
    if (gen != _boundaryGen || !_engine.isActiveSession(sid)) return;

    final playable = _playable;
    if (playable.isEmpty) return;
    final pos = _watchPos ?? _currentPos;
    if (pos == null) return;

    final s = state.settings;
    final NextAction action;
    if (sentenceBoundary) {
      _sentenceRepeatsDone += 1;
      action = decideNext(
        loopSentence: s.loopSentence,
        sentenceLoopCount: s.sentenceLoopCount,
        sentenceInterval: s.sentenceInterval,
        loopWhole: s.loopWhole,
        wholeLoopCount: s.wholeLoopCount,
        wholeInterval: s.wholeInterval,
        sentenceRepeatsDone: _sentenceRepeatsDone,
        wholeLoopsDone: _wholeLoopsDone,
        currentPos: pos,
        playableCount: playable.length,
      );
    } else {
      // gapless 整段自然播完 = 完成一遍整篇。
      _wholeLoopsDone += 1;
      action = shouldLoopWhole(s.loopWhole, s.wholeLoopCount, _wholeLoopsDone)
          ? GoToPosition(0, pauseBefore: s.wholeInterval)
          : const StopPlayback();
    }

    switch (action) {
      case StopPlayback():
        await _engine.stop();
      case ReplayCurrent(:final pauseBefore):
        await _delayInterval(pauseBefore);
        if (gen != _boundaryGen || !_engine.isActiveSession(sid)) return;
        await _resumeAt(pos);
      case GoToPosition(:final position, :final pauseBefore):
        await _delayInterval(pauseBefore);
        if (gen != _boundaryGen || !_engine.isActiveSession(sid)) return;
        // 监听句尾下从末尾回卷到第 0 句意味着完成了一遍整篇。
        final wasLast = pos >= playable.length - 1;
        if (sentenceBoundary && wasLast && position == 0) {
          _wholeLoopsDone += 1;
        }
        _sentenceRepeatsDone = 0;
        await _resumeAt(position);
    }
  }

  /// 从播放列表第 [pos] 条起播（gapless）：更新真相源 index + 监听句，seek 到句首后播放。
  Future<void> _resumeAt(int pos) async {
    final playable = _playable;
    if (pos < 0 || pos >= playable.length) return;
    final target = playable[pos];
    if (state.playlistMode == PlaylistMode.bookmarks) {
      state = state.copyWith(
        currentBookmarkIndex: target.index,
        lastPlayedBookmarkIndex: target.index,
      );
    } else {
      state = state.copyWith(
        currentFullIndex: target.index,
        lastPlayedFullIndex: target.index,
      );
    }
    _setWatch(pos);
    await _engine.seek(target.startTime);
    await _engine.play();
  }

  /// 按给定间隔停顿（来自 reducer 的决策，区分单句/整篇间隔）。
  Future<void> _delayInterval(Duration interval) async {
    if (interval > Duration.zero) {
      await Future.delayed(interval);
    }
  }

  // ===========================================================================
  // 加载音频
  // ===========================================================================

  Future<void> loadAudio(
    AudioItem audioItem, {
    bool forceTranscriptReload = false,
  }) async {
    // 同一音频且字幕未变化时跳过。
    if (!forceTranscriptReload &&
        state.currentAudioItem?.id == audioItem.id &&
        state.currentAudioItem?.transcriptPath == audioItem.transcriptPath &&
        state.currentAudioItem?.transcriptSource ==
            audioItem.transcriptSource) {
      if (_loadingCompleter != null && !_loadingCompleter!.isCompleted) {
        return _loadingCompleter!.future;
      }
      return;
    }

    _loadingCompleter = Completer<void>();
    state = state.copyWith(isLoading: true);

    try {
      await stop();
      // 换音频：清空监听句与循环计数，作废在途边界处理。
      _clearWatch();
      _sentenceRepeatsDone = 0;
      _wholeLoopsDone = 0;
      _boundaryGen++;
      _handlingBoundary = false;

      state = state.copyWith(
        currentAudioItem: audioItem,
        sentences: [],
        clearCurrentFullIndex: true,
        clearCurrentBookmarkIndex: true,
        // 循环开关是「现在想刷这条」的临时意图，加载新音频时一律重置为关
        // （仅改内存，不持久化）；循环参数作为偏好保留。
        settings: state.settings.copyWith(
          loopWhole: false,
          loopSentence: false,
        ),
      );

      try {
        await _engine.loadAudio(audioItem, state.settings.playbackSpeed);
      } catch (e) {
        AppLogger.log('Player', '✗ 音频文件加载失败: $e');
        state = state.copyWith(clearCurrentAudioItem: true);
        rethrow;
      }

      final sentences = await _engine.loadTranscript(audioItem);

      final bookmarkDao = ref.read(bookmarkDaoProvider);
      final storedBookmarks = await BookmarkManager.loadBookmarks(
        audioItem.id,
        dao: bookmarkDao,
      );
      var bookmarkedIndices = Set<int>.from(storedBookmarks);

      final isFirstLoad = storedBookmarks.isEmpty;
      if (isFirstLoad) {
        final autoBookmarks = BookmarkManager.autoAddBracketBookmarks(
          sentences,
        );
        bookmarkedIndices = {...bookmarkedIndices, ...autoBookmarks};

        if (autoBookmarks.isNotEmpty) {
          for (final idx in autoBookmarks) {
            await BookmarkManager.addBookmarkToDb(
              audioItem.id,
              sentences[idx],
              dao: bookmarkDao,
            );
          }
        }
      }

      // 清理 [] 包裹的句子文本
      final cleanedSentences = <Sentence>[];
      for (int i = 0; i < sentences.length; i++) {
        final text = sentences[i].text.trim();
        if (text.startsWith('[') && text.endsWith(']') && text.length > 2) {
          cleanedSentences.add(
            sentences[i].copyWith(
              text: text.substring(1, text.length - 1).trim(),
            ),
          );
        } else {
          cleanedSentences.add(sentences[i]);
        }
      }

      for (var sentence in cleanedSentences) {
        sentence.isBookmarked = bookmarkedIndices.contains(sentence.index);
      }

      state = state.copyWith(
        sentences: cleanedSentences,
        bookmarkedIndices: bookmarkedIndices,
        currentFullIndex: 0,
      );

      await _restorePlaybackState(audioItem);

      if (state.sentences.isNotEmpty && state.currentFullIndex == null) {
        state = state.copyWith(currentFullIndex: 0);
        await _engine.seek(state.sentences[0].startTime);
      }
    } catch (e) {
      AppLogger.log('Player', '✗ loadAudio 失败: $e');
      state = state.copyWith(clearCurrentAudioItem: true);
    } finally {
      state = state.copyWith(isLoading: false);
      if (_loadingCompleter != null && !_loadingCompleter!.isCompleted) {
        _loadingCompleter!.complete();
      }
    }
  }

  Future<void> _restorePlaybackState(AudioItem audioItem) async {
    final playbackStateDao = ref.read(playbackStateDaoProvider);
    final result = await PlaybackStateStorage.loadPlaybackState(
      audioItem.id,
      dao: playbackStateDao,
    );
    if (result == null) return;

    try {
      if (result.playlistMode != null) {
        state = state.copyWith(playlistMode: result.playlistMode);
      }
      if (result.position != null) {
        await _engine.seek(result.position!);
        // 从恢复位置反推当前句高亮
        final idx = SentenceTracker.findSentenceIndexByPosition(
          state.sentences,
          result.position!,
        );
        if (idx != -1) {
          state = state.copyWith(currentFullIndex: idx);
        }
      }
      AppLogger.log('Player', '✓ 恢复播放状态: ${audioItem.name}');
    } catch (e) {
      AppLogger.log('Player', '⚠ 恢复播放状态失败: $e');
    }
  }

  // ===========================================================================
  // 播放控制
  // ===========================================================================

  /// 主播放按钮：暂停后从精确位置续播（仅 gapless），否则按真相源 index 起播。
  Future<void> play() async {
    if (state.currentAudioItem == null) return;

    if (state.sentences.isEmpty) {
      await _engine.play();
      return;
    }

    _ensureValidIndex();
    if (state.playlistMode == PlaylistMode.bookmarks &&
        state.bookmarkedSentences.isEmpty) {
      return;
    }

    // 暂停后恢复：引擎仍停在 LP 自己的 session、未播完、且有非零位置 → 从精确暂停
    // 位置续播（监听句已在起播时设好，循环/跳播继续生效）。若期间被讲解页等外来
    // session 顶掉（position 已被改写或已 stop），或需监听句尾却尚未设监听句（如刚
    // 恢复播放状态），认领失效，按真相源 index 重新起播。
    if (_engine.isActiveSession(_playbackSessionId) &&
        (!_watchBoundaries || _watchPos != null)) {
      final ps = _engine.audioPlayer.processingState;
      final resumable =
          ps != ja.ProcessingState.completed &&
          ps != ja.ProcessingState.idle &&
          _engine.currentPosition > Duration.zero;
      if (resumable) {
        await _engine.play();
        return;
      }
    }

    await _startCurrent();
  }

  /// 从当前真相源 index 起播（全新 session，gapless）。
  Future<void> _startCurrent() async {
    final playable = _playable;
    if (playable.isEmpty) return;

    _handlingBoundary = false;
    _boundaryGen++; // 作废在途边界处理
    _sentenceRepeatsDone = 0;
    _wholeLoopsDone = 0;
    _playbackSessionId = _engine.newSession();

    await _engine.clearClip();
    await _resumeAt(_currentPos ?? 0);
  }

  void _ensureValidIndex() {
    if (state.playlistMode == PlaylistMode.bookmarks) {
      final bookmarked = state.bookmarkedSentences;
      if (bookmarked.isEmpty) return;
      if (state.currentBookmarkIndex == null ||
          !state.bookmarkedIndices.contains(state.currentBookmarkIndex)) {
        state = state.copyWith(currentBookmarkIndex: bookmarked.first.index);
      }
    } else {
      if (state.currentFullIndex == null ||
          state.currentFullIndex! >= state.sentences.length) {
        state = state.copyWith(currentFullIndex: 0);
      }
    }
  }

  Future<void> pause() async {
    await _engine.pause();
    // 引擎 pause 会自增 session 以失效在途回调；LP 仍是这个「已暂停引擎」的拥有者，
    // 故认领当前 session，使随后的 play() 能从精确暂停位置续播。若期间被讲解页等
    // 外来 session 顶掉，认领失效，play() 会按真相源 index 重新起播。
    _playbackSessionId = _engine.currentSessionId;
  }

  Future<void> stop() async {
    await _engine.stop();
  }

  Future<void> seek(Duration position) async {
    await _engine.seek(position);
  }

  /// 离开讲解页返回后，把共享引擎显式对齐回当前句起点。
  ///
  /// 讲解页旁路驱动并 stop 了引擎，会改写 clip/position。返回后调用本方法清除
  /// clip、seek 回当前句起点并认领 session，使主播放按钮从「原来的句子」继续，
  /// 而不依赖对引擎残留位置的启发式判断。
  Future<void> restorePosition() async {
    if (state.currentAudioItem == null) return;
    if (_currentPos == null) return;
    await _alignEngineToCurrent();
    _wholeLoopsDone = 0;
  }

  /// 进度条任意位置拖动：seek 到任意时间并从落点继续（业界标准）。
  ///
  /// gapless 永不 setClip，直接绝对 seek。监听句尾的模式（单句循环/收藏）下重设监听句：
  /// 全文模式监听落点所在句；收藏模式若落点在收藏句内则监听该句，落在非收藏区间则吸附
  /// 到最近收藏句并从其句首播放（收藏模式无法播放非收藏内容）。
  Future<void> seekAbsolute(Duration absolutePosition) async {
    if (state.sentences.isEmpty) {
      await _engine.clearClip();
      await _engine.seek(absolutePosition);
      return;
    }

    final wasPlaying = _engine.isPlaying;
    if (wasPlaying) await _engine.pauseKeepSession();
    await _engine.clearClip();

    // 计算最终落点 target 与监听句 pos（不监听句尾的模式 target=落点、不设监听句）。
    Duration target = absolutePosition;
    if (_watchBoundaries) {
      final playable = _playable;
      if (playable.isNotEmpty) {
        int pos;
        if (state.playlistMode == PlaylistMode.bookmarks) {
          final globalIdx = SentenceTracker.findSentenceIndexByPosition(
            state.sentences,
            absolutePosition,
          );
          pos = playable.indexWhere((s) => s.index == globalIdx);
          if (pos == -1) {
            // 落在非收藏区间：吸附到最近收藏句并从其句首播放。
            final closest = SentenceTracker.findClosestBookmark(
              playable,
              absolutePosition,
            );
            pos = closest == null
                ? 0
                : playable.indexWhere((s) => s.index == closest);
            if (pos < 0) pos = 0;
            target = playable[pos].startTime;
          }
        } else {
          pos = SentenceTracker.findSentenceIndexByPosition(
            state.sentences,
            absolutePosition,
          );
          if (pos < 0) pos = 0;
        }
        _setWatch(pos);
      }
    } else {
      _clearWatch();
    }

    await _engine.seek(target);
    _updateHighlight(target);
    _sentenceRepeatsDone = 0;

    if (wasPlaying) {
      // 作废在途边界处理，全新 session 从落点继续连续播放（不吸附句首）。
      _boundaryGen++;
      _handlingBoundary = false;
      _playbackSessionId = _engine.newSession();
      await _engine.play();
    } else {
      _playbackSessionId = _engine.currentSessionId;
    }
  }

  /// 未播放时把引擎对齐到当前真相源句的起点，并设好监听句（gapless），使随后
  /// [play] 能从该句正确续播（监听句尾的模式下也能立即生效）。
  Future<void> _alignEngineToCurrent() async {
    _handlingBoundary = false;
    _boundaryGen++;
    _sentenceRepeatsDone = 0;
    final pos = _currentPos;
    await _engine.clearClip();
    _setWatch(pos ?? 0);
    if (pos != null) {
      await _engine.seek(_playable[pos].startTime);
    }
    _playbackSessionId = _engine.currentSessionId;
  }

  Future<void> selectFullSentence(int index, {bool autoPlay = true}) async {
    if (index < 0 || index >= state.sentences.length) return;

    state = state.copyWith(currentFullIndex: index, lastPlayedFullIndex: index);

    if (autoPlay) {
      await _startCurrent();
    } else {
      await _alignEngineToCurrent();
    }
  }

  Future<void> selectBookmarkedSentence(
    int index, {
    bool autoPlay = true,
  }) async {
    if (index < 0 || index >= state.sentences.length) return;

    state = state.copyWith(
      currentBookmarkIndex: index,
      lastPlayedBookmarkIndex: index,
    );

    if (autoPlay) {
      await _startCurrent();
    } else {
      await _alignEngineToCurrent();
    }
  }

  Future<void> replayCurrentSentence() async {
    if (state.sentences.isEmpty) return;

    final int? lastPlayedIndex = state.playlistMode == PlaylistMode.bookmarks
        ? state.lastPlayedBookmarkIndex
        : state.lastPlayedFullIndex;
    if (lastPlayedIndex == null) return;

    if (state.playlistMode == PlaylistMode.bookmarks) {
      state = state.copyWith(currentBookmarkIndex: lastPlayedIndex);
    } else {
      state = state.copyWith(currentFullIndex: lastPlayedIndex);
    }
    await _startCurrent();
  }

  Future<void> nextSentence() async {
    if (state.sentences.isEmpty) return;

    late int newIndex;
    if (state.playlistMode == PlaylistMode.bookmarks) {
      final bookmarked = state.bookmarkedSentences;
      if (bookmarked.isEmpty) return;

      int pos = bookmarked.indexWhere(
        (s) => s.index == state.currentBookmarkIndex,
      );
      if (pos == -1) {
        pos = 0;
      } else if (pos >= bookmarked.length - 1) {
        return;
      } else {
        pos++;
      }
      newIndex = bookmarked[pos].index;
    } else {
      if (state.currentFullIndex == null) {
        newIndex = 0;
      } else if (state.currentFullIndex! >= state.sentences.length - 1) {
        return;
      } else {
        newIndex = state.currentFullIndex! + 1;
      }
    }

    await _moveToIndex(newIndex);
  }

  Future<void> previousSentence() async {
    if (state.sentences.isEmpty) return;

    late int newIndex;
    if (state.playlistMode == PlaylistMode.bookmarks) {
      final bookmarked = state.bookmarkedSentences;
      if (bookmarked.isEmpty) return;

      int pos = bookmarked.indexWhere(
        (s) => s.index == state.currentBookmarkIndex,
      );
      if (pos <= 0) return;
      pos--;
      newIndex = bookmarked[pos].index;
    } else {
      if (state.currentFullIndex == null) {
        newIndex = 0;
      } else if (state.currentFullIndex! <= 0) {
        return;
      } else {
        newIndex = state.currentFullIndex! - 1;
      }
    }

    await _moveToIndex(newIndex);
  }

  /// 上/下一句的公共落地：更新真相源 index，播放中则起播该句，否则对齐引擎。
  Future<void> _moveToIndex(int newIndex) async {
    final wasPlaying = _engine.isPlaying;

    if (state.playlistMode == PlaylistMode.bookmarks) {
      state = state.copyWith(
        currentBookmarkIndex: newIndex,
        lastPlayedBookmarkIndex: newIndex,
      );
    } else {
      state = state.copyWith(
        currentFullIndex: newIndex,
        lastPlayedFullIndex: newIndex,
      );
    }

    if (wasPlaying) {
      await _startCurrent();
    } else {
      await _alignEngineToCurrent();
    }
  }

  Future<void> toggleBookmark(int index) async {
    final (
      isRemoving,
      indicesToRemove,
      nextIndex,
    ) = BookmarkManager.toggleBookmark(
      index,
      state.sentences,
      state.bookmarkedIndices,
      state.playlistMode == PlaylistMode.bookmarks,
    );

    // 埋点：收藏/取消收藏句子
    if (state.currentAudioItem != null) {
      final item = state.currentAudioItem!;
      final analyticsParams = {
        EventParams.audioId: item.id,
        EventParams.audioName: item.name,
        EventParams.sentenceIndex: index,
        EventParams.action: isRemoving ? 'remove' : 'add',
      };
      if (!isRemoving) {
        await ref
            .read(usageTrackerProvider)
            .record(
              UsageEvent.bookmarkSentenceSaved,
              analyticsParams: analyticsParams,
            );
      } else {
        ref
            .read(analyticsServiceProvider)
            .track(Events.bookmarkToggle, analyticsParams);
      }
    }

    // 价值锚点：只在「添加收藏」时尝试触发通知权限 pre-prompt
    if (!isRemoving) {
      unawaited(
        ref.read(notificationPermissionServiceProvider).maybeTriggerPrompt(),
      );
    }

    final inBookmarksMode = state.playlistMode == PlaylistMode.bookmarks;
    final shouldResume =
        inBookmarksMode && _engine.isPlaying && nextIndex != null;

    if (inBookmarksMode && isRemoving && _engine.isPlaying) {
      await pause();
    }

    var newBookmarks = Set<int>.from(state.bookmarkedIndices);
    var newSentences = List<Sentence>.from(state.sentences);

    if (isRemoving) {
      final toRemove = indicesToRemove.isEmpty ? {index} : indicesToRemove;
      for (final idx in toRemove) {
        newBookmarks.remove(idx);
        if (idx >= 0 && idx < newSentences.length) {
          newSentences[idx] = newSentences[idx].copyWith(isBookmarked: false);
        }
      }

      if (inBookmarksMode) {
        if (nextIndex != null && nextIndex < newSentences.length) {
          state = state.copyWith(
            bookmarkedIndices: newBookmarks,
            sentences: newSentences,
            currentBookmarkIndex: nextIndex,
          );
        } else {
          state = state.copyWith(
            bookmarkedIndices: newBookmarks,
            sentences: newSentences,
            clearCurrentBookmarkIndex: true,
          );
          await _engine.clearClip();
          await stop();
        }
      } else {
        state = state.copyWith(
          bookmarkedIndices: newBookmarks,
          sentences: newSentences,
        );
      }
    } else {
      newBookmarks.add(index);
      newSentences[index] = newSentences[index].copyWith(isBookmarked: true);
      state = state.copyWith(
        bookmarkedIndices: newBookmarks,
        sentences: newSentences,
      );
    }

    if (state.currentAudioItem != null) {
      final bookmarkDao = ref.read(bookmarkDaoProvider);
      if (isRemoving) {
        await BookmarkManager.removeBookmarksFromDb(
          state.currentAudioItem!.id,
          indicesToRemove,
          dao: bookmarkDao,
        );
      } else {
        await BookmarkManager.addBookmarkToDb(
          state.currentAudioItem!.id,
          state.sentences[index],
          dao: bookmarkDao,
        );
      }
    }

    // 收藏模式下移除当前句后，从下一收藏句继续播放
    if (inBookmarksMode &&
        shouldResume &&
        state.bookmarkedSentences.isNotEmpty) {
      await _startCurrent();
    }
  }

  Future<void> updateSettings(PlaybackSettings newSettings) async {
    final wasPlaying = _engine.isPlaying;
    final wasWatch = _watchBoundaries;

    state = state.copyWith(settings: newSettings);
    await _engine.setSpeed(newSettings.playbackSpeed);
    await StorageService.saveSettings(newSettings);

    // 句尾监听需求切换（开/关单句循环）需要从当前句重新起播以设/清监听句；
    // 仅速度/次数/间隔等不改变监听需求的设置无需打断播放（在下次边界生效）。
    if (wasPlaying && wasWatch != _watchBoundaries) {
      await _startCurrent();
    }
  }

  Future<void> setPlaylistMode(PlaylistMode mode) async {
    if (state.playlistMode == mode) return;

    final wasPlaying = _engine.isPlaying;
    await pause();

    state = state.copyWith(playlistMode: mode);

    if (mode == PlaylistMode.full) {
      if (state.currentFullIndex == null ||
          state.currentFullIndex! >= state.sentences.length) {
        if (state.sentences.isNotEmpty) {
          state = state.copyWith(currentFullIndex: 0);
        }
      }
    } else {
      final bookmarked = state.bookmarkedSentences;
      if (bookmarked.isEmpty) {
        await _engine.clearClip();
        return;
      }
      if (state.currentBookmarkIndex == null ||
          !state.bookmarkedIndices.contains(state.currentBookmarkIndex)) {
        state = state.copyWith(currentBookmarkIndex: bookmarked.first.index);
      }
    }

    if (wasPlaying) {
      await _startCurrent();
    } else {
      await _alignEngineToCurrent();
    }
  }

  /// 重置播放位置到开头（供外部学习流程调用）
  void resetToBeginning() {
    if (state.sentences.isNotEmpty) {
      state = state.copyWith(currentFullIndex: 0);
    }
  }

  Future<void> saveCurrentPlaybackState() async {
    if (state.currentAudioItem == null) return;

    final playbackStateDao = ref.read(playbackStateDaoProvider);
    await PlaybackStateStorage.savePlaybackState(
      state.currentAudioItem!,
      _engine.audioPlayer,
      state,
      dao: playbackStateDao,
    );
  }
}
