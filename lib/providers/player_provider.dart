import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import '../models/audio_item.dart';
import '../models/sentence.dart';
import '../models/playback_settings.dart';
import '../services/storage_service.dart';
import 'player/player_state.dart' as ps;
import 'player/playback_controller.dart';
import 'player/playback_mode_handler.dart';
import 'player/bookmark_manager.dart';
import 'player/audio_loader.dart';
import 'player/sentence_tracker.dart';
import 'player/playback_state_storage.dart';

// Re-export PlaylistMode for backward compatibility
export 'player/player_state.dart' show PlaylistMode;

/// 播放器Provider - 协调各个模块
/// 采用委托模式，将职责分散到各个专门的模块中
class PlayerProvider extends ChangeNotifier {
  // 核心组件
  final AudioPlayer _audioPlayer = AudioPlayer();
  late final ps.PlayerState _state;
  late final PlaybackController _controller;
  late final PlaybackModeHandler _modeHandler;

  // 监听器
  StreamSubscription? _positionSubscription;
  StreamSubscription? _playerStateSubscription;
  bool _isDisposed = false;

  // Getters - 委托给状态管理器
  AudioPlayer get audioPlayer => _audioPlayer;
  AudioItem? get currentAudioItem => _state.currentAudioItem;
  List<Sentence> get sentences => _state.sentences;
  List<Sentence> get bookmarkedSentences => _state.bookmarkedSentences;
  int? get currentFullIndex => _state.currentFullIndex;
  int? get currentBookmarkIndex => _state.currentBookmarkIndex;
  Sentence? get currentSentence => _state.currentSentence;
  PlaybackSettings get settings => _state.settings;
  Set<int> get bookmarkedIndices => _state.bookmarkedIndices;
  bool get isLoading => _state.isLoading;
  bool get isPlaying => _audioPlayer.playing;
  Duration get currentPosition => _audioPlayer.position;
  Duration? get totalDuration => _state.totalDuration;
  bool get hasAudio => _state.hasAudio;
  bool get hasSentences => _state.hasSentences;
  bool get autoScrollEnabled => _state.autoScrollEnabled;
  ps.PlaylistMode get playlistMode => _state.playlistMode;

  // 绝对位置流：将 clip 相对位置映射到完整音频的绝对位置
  Stream<Duration> get absolutePositionStream =>
      _audioPlayer.positionStream.map((relativePosition) {
        return _state.clipStart + relativePosition;
      });

  PlayerProvider() {
    _state = ps.PlayerState();
    _controller = PlaybackController(audioPlayer: _audioPlayer, state: _state);
    _modeHandler = PlaybackModeHandler(
      audioPlayer: _audioPlayer,
      state: _state,
      controller: _controller,
    );

    // 同步状态变化
    _state.addListener(() {
      notifyListeners();
    });

    _loadSettings();
    _setupListeners();
  }

  Future<void> _loadSettings() async {
    final settings = await StorageService.loadSettings();
    _state.setSettings(settings);
  }

  void _setupListeners() {
    _positionSubscription = _audioPlayer.positionStream.listen(
      _onPositionChanged,
    );
    _playerStateSubscription = _audioPlayer.playerStateStream.listen(
      _onPlayerStateChanged,
    );
  }

  void _onPositionChanged(Duration position) {
    final absolute = _state.clipStart + position;
    _updateCurrentSentence(absolute);
  }

  void _onPlayerStateChanged(PlayerState playerState) {
    // 处理播放完成（用于Continuous模式的音频循环）
    if (playerState.processingState == ProcessingState.completed) {
      _handlePlaybackCompleted();
    }
    notifyListeners();
  }

  /// 处理Continuous模式下的播放完成
  void _handlePlaybackCompleted() {
    if (_isDisposed) return;
    _modeHandler.handlePlaybackCompleted();
  }

  void _updateCurrentSentence(Duration position) {
    // 只在 Continuous 模式下才根据播放进度自动选中句子
    if (!_modeHandler.shouldUseContinuousMode() || !_audioPlayer.playing) {
      return;
    }

    if (_state.sentences.isEmpty) return;

    // 使用二分查找快速定位当前播放的句子
    int newIndex = SentenceTracker.findSentenceIndexByPosition(
      _state.sentences,
      position,
    );

    // 只在索引真正改变时才更新，避免不必要的UI刷新
    if (newIndex != -1 && newIndex != _state.currentFullIndex) {
      _state.setCurrentFullIndex(newIndex);
    }
  }

  /// 加载音频
  Future<void> loadAudio(AudioItem audioItem) async {
    print("loadAudio: ${audioItem.name}");
    _state.setAutoScrollEnabled(true);

    if (_state.currentAudioItem?.id == audioItem.id) return;

    _state.setLoading(true);

    try {
      // Stop current playback
      await stop();

      _state.setCurrentAudioItem(audioItem);
      _state.setSentences([]);
      _state.resetIndices();

      // Load audio
      try {
        final duration = await AudioLoader.loadAudioFile(
          _audioPlayer,
          audioItem,
          _state.settings.playbackSpeed,
        );
        _state.setFullDuration(duration);
        _state.setClipStart(Duration.zero);
      } catch (e) {
        print('Error loading audio file: $e');
        _state.setCurrentAudioItem(null);
        rethrow;
      }

      // Load transcript if available
      final sentences = await AudioLoader.loadTranscript(audioItem);

      // Load bookmarks
      final storedBookmarks = await BookmarkManager.loadBookmarks(audioItem.id);
      _state.setBookmarkedIndices(Set.from(storedBookmarks));

      // 首次加载时自动添加 [] 包裹的句子为书签
      final isFirstLoad = storedBookmarks.isEmpty;
      if (isFirstLoad) {
        final autoBookmarks = BookmarkManager.autoAddBracketBookmarks(
          sentences,
        );
        _state.setBookmarkedIndices(
          Set.from(_state.bookmarkedIndices)..addAll(autoBookmarks),
        );

        // 保存首次加载的自动书签
        if (autoBookmarks.isNotEmpty) {
          await BookmarkManager.saveBookmarks(
            audioItem.id,
            _state.bookmarkedIndices,
          );
        }
      }

      // 清理所有带有 [] 的句子文本（识别书签后）
      for (int i = 0; i < sentences.length; i++) {
        final text = sentences[i].text.trim();
        if (text.startsWith('[') && text.endsWith(']') && text.length > 2) {
          sentences[i] = sentences[i].copyWith(
            text: text.substring(1, text.length - 1).trim(),
          );
        }
      }

      // 设置清理后的句子列表
      _state.setSentences(sentences);

      // Update sentence bookmark status
      BookmarkManager.updateSentenceBookmarkStatus(
        _state.sentences,
        _state.bookmarkedIndices,
      );

      // 恢复之前保存的播放状态，如果没有则初始化为第一个句子
      await PlaybackStateStorage.restorePlaybackState(
        audioItem,
        _audioPlayer,
        _state,
      );

      // 如果没有恢复到有效状态，设置初始句子
      if (_state.sentences.isNotEmpty && _state.currentFullIndex == null) {
        _state.setCurrentFullIndex(0);
        await _audioPlayer.seek(_state.sentences[0].startTime);
      }
    } catch (e) {
      print('Error loading audio: $e');
      _state.setCurrentAudioItem(null);
    } finally {
      _state.setLoading(false);
    }
  }

  /// 播放
  Future<void> play() async {
    print('play');
    if (_state.currentAudioItem == null) return;

    if (_state.sentences.isEmpty) {
      // 没有字幕，直接播放
      await _audioPlayer.play();
      return;
    }

    // 确保初始索引存在
    if (_state.playlistMode == ps.PlaylistMode.bookmarks) {
      final bookmarked = _state.bookmarkedSentences;
      if (bookmarked.isEmpty) {
        notifyListeners();
        return;
      }
      // 只有当前索引无效时才初始化
      if (_state.currentBookmarkIndex == null ||
          !_state.bookmarkedIndices.contains(_state.currentBookmarkIndex)) {
        _state.setCurrentBookmarkIndex(bookmarked.first.index);
      }
    } else {
      // Full Text 模式：只有当前索引无效时才初始化为0
      if (_state.currentFullIndex == null ||
          _state.currentFullIndex! >= _state.sentences.length) {
        _state.setCurrentFullIndex(0);
      }
    }

    if (_modeHandler.shouldUseContinuousMode()) {
      await _modeHandler.playContinuous();
    } else {
      // 准备播放列表和起始位置
      List<Sentence> playList;
      int startIndex;

      if (_state.playlistMode == ps.PlaylistMode.bookmarks) {
        playList = _state.bookmarkedSentences;
        // 找到当前书签的位置
        if (_state.currentBookmarkIndex != null) {
          startIndex = playList.indexWhere(
            (s) => s.index == _state.currentBookmarkIndex,
          );
          if (startIndex == -1) startIndex = 0;
        } else {
          startIndex = 0;
        }
      } else {
        playList = _state.sentences;
        startIndex = _state.currentFullIndex ?? 0;
      }

      await _modeHandler.playSubtitleDriven(playList, startIndex);
    }
  }

  Future<void> pause() async {
    await _controller.pause();
  }

  Future<void> stop() async {
    await _controller.stop();
  }

  Future<void> seek(Duration position) async {
    await _controller.seek(position);
  }

  /// 绝对位置的 seek（用于进度条拖动）
  Future<void> seekAbsolute(Duration absolutePosition) async {
    final wasPlaying = _audioPlayer.playing;
    if (wasPlaying) {
      await pause();
    }

    // 启用自动滚动，确保选中的句子可见
    _state.setAutoScrollEnabled(true);

    // 清除 clip 状态，确保进度条显示正确
    _state.setClipStart(Duration.zero);
    await _audioPlayer.seek(absolutePosition);

    // 根据新位置更新当前句子索引
    int? snappedBookmarkIndex;
    if (_state.sentences.isNotEmpty) {
      final newIndex = SentenceTracker.findSentenceIndexByPosition(
        _state.sentences,
        absolutePosition,
      );

      if (newIndex != -1) {
        if (_state.playlistMode == ps.PlaylistMode.bookmarks) {
          // 在书签模式下，检查找到的句子是否是书签
          if (_state.bookmarkedIndices.contains(newIndex)) {
            _state.setCurrentBookmarkIndex(newIndex);
            snappedBookmarkIndex = newIndex;
          } else {
            // 如果不是书签，找最近的书签
            final closestIdx = SentenceTracker.findClosestBookmark(
              _state.bookmarkedSentences,
              absolutePosition,
            );
            if (closestIdx != null) {
              _state.setCurrentBookmarkIndex(closestIdx);
              snappedBookmarkIndex = closestIdx;
            }
          }
        } else {
          // 全文模式直接使用找到的索引
          _state.setCurrentFullIndex(newIndex);
        }
      }
    }

    // 书签模式下，拖动后将进度条对齐到目标句子的开始时间
    if (snappedBookmarkIndex != null) {
      final s = _state.sentences[snappedBookmarkIndex];
      await _audioPlayer.seek(s.startTime);
    }

    if (wasPlaying) {
      await play();
    }
  }

  Future<void> selectFullSentence(int index, {bool autoPlay = true}) async {
    if (index < 0 || index >= _state.sentences.length) return;

    final shouldResume = autoPlay && _audioPlayer.playing;
    if (shouldResume) {
      await pause();
    }

    _state.setCurrentFullIndex(index);
    _state.setLastPlayedFullIndex(index);

    // 点击item选中，移动进度条到该位置
    if (_state.currentAudioItem != null) {
      _state.setClipStart(Duration.zero);
      await _audioPlayer.seek(_state.sentences[index].startTime);
    }

    // 点击item时执行与主播放/暂停按钮相同的动作
    if (autoPlay) {
      await play();
    }
  }

  Future<void> selectBookmarkedSentence(
    int index, {
    bool autoPlay = true,
  }) async {
    if (index < 0 || index >= _state.sentences.length) return;

    final shouldResume = autoPlay && _audioPlayer.playing;
    if (shouldResume) {
      await pause();
    }

    _state.setCurrentBookmarkIndex(index);
    _state.setLastPlayedBookmarkIndex(index);

    // 点击item选中，移动进度条到该位置
    if (_state.currentAudioItem != null) {
      _state.setClipStart(Duration.zero);
      await _audioPlayer.seek(_state.sentences[index].startTime);
    }

    // 点击item时执行与主播放/暂停按钮相同的动作
    if (autoPlay) {
      await play();
    }
  }

  /// 重播上一次手动选择的句子（快捷键 'r'）
  Future<void> replayCurrentSentence() async {
    if (_state.sentences.isEmpty) return;

    // 获取上一次手动选择的句子索引
    int? lastPlayedIndex;
    if (_state.playlistMode == ps.PlaylistMode.bookmarks) {
      lastPlayedIndex = _state.lastPlayedBookmarkIndex;
    } else {
      lastPlayedIndex = _state.lastPlayedFullIndex;
    }

    if (lastPlayedIndex == null) return;

    // 暂停当前播放
    if (_audioPlayer.playing) {
      await pause();
    }

    // 重新播放该句子
    if (_state.playlistMode == ps.PlaylistMode.bookmarks) {
      await selectBookmarkedSentence(lastPlayedIndex, autoPlay: true);
    } else {
      await selectFullSentence(lastPlayedIndex, autoPlay: true);
    }
  }

  Future<void> nextSentence() async {
    if (_state.sentences.isEmpty) return;

    late int newIndex;
    if (_state.playlistMode == ps.PlaylistMode.bookmarks) {
      final bookmarked = _state.bookmarkedSentences;
      if (bookmarked.isEmpty) return;

      int pos = bookmarked.indexWhere(
        (s) => s.index == _state.currentBookmarkIndex,
      );
      if (pos == -1) {
        pos = 0;
      } else if (pos >= bookmarked.length - 1) {
        return; // 到达最后一句
      } else {
        pos++;
      }
      newIndex = bookmarked[pos].index;
      print('next bookmark Sentence: $newIndex , sentence: ${bookmarked[pos]}');
    } else {
      if (_state.currentFullIndex == null) {
        newIndex = 0;
      } else if (_state.currentFullIndex! >= _state.sentences.length - 1) {
        return; // 到达最后一句
      } else {
        newIndex = _state.currentFullIndex! + 1;
      }
    }

    final shouldResume = _audioPlayer.playing;
    if (shouldResume) await pause();

    if (_state.playlistMode == ps.PlaylistMode.bookmarks) {
      _state.setCurrentBookmarkIndex(newIndex);
      _state.setLastPlayedBookmarkIndex(newIndex);
    } else {
      _state.setCurrentFullIndex(newIndex);
      _state.setLastPlayedFullIndex(newIndex);
    }

    // 启用自动滚动，确保选中的 item 可见
    _state.setAutoScrollEnabled(true);

    // 清除 clip 状态，确保进度条显示正确的绝对位置
    _state.setClipStart(Duration.zero);
    await _audioPlayer.seek(_state.sentences[newIndex].startTime);

    // 如果原本正在播放，则从新的句子重新开始主播放
    if (shouldResume) {
      await play();
    }
  }

  Future<void> previousSentence() async {
    if (_state.sentences.isEmpty) return;

    late int newIndex;
    if (_state.playlistMode == ps.PlaylistMode.bookmarks) {
      final bookmarked = _state.bookmarkedSentences;
      if (bookmarked.isEmpty) return;

      int pos = bookmarked.indexWhere(
        (s) => s.index == _state.currentBookmarkIndex,
      );
      if (pos <= 0) return; // 到达第一句
      pos--;
      newIndex = bookmarked[pos].index;
      print(
        'previous bookmark Sentence: $newIndex, sentence: ${bookmarked[pos]}',
      );
    } else {
      if (_state.currentFullIndex == null) {
        newIndex = 0;
      } else if (_state.currentFullIndex! <= 0) {
        return; // 到达第一句
      } else {
        newIndex = _state.currentFullIndex! - 1;
      }
    }

    final shouldResume = _audioPlayer.playing;
    if (shouldResume) await pause();

    if (_state.playlistMode == ps.PlaylistMode.bookmarks) {
      _state.setCurrentBookmarkIndex(newIndex);
      _state.setLastPlayedBookmarkIndex(newIndex);
    } else {
      _state.setCurrentFullIndex(newIndex);
      _state.setLastPlayedFullIndex(newIndex);
    }

    // 启用自动滚动，确保选中的 item 可见
    _state.setAutoScrollEnabled(true);

    // 清除 clip 状态，确保进度条显示正确的绝对位置
    _state.setClipStart(Duration.zero);
    await _audioPlayer.seek(_state.sentences[newIndex].startTime);

    // 如果原本正在播放，则从新的句子重新开始播放
    if (shouldResume) {
      await play();
    }
  }

  Future<void> toggleBookmark(int index) async {
    final (
      isRemoving,
      indicesToRemove,
      nextIndex,
    ) = BookmarkManager.toggleBookmark(
      index,
      _state.sentences,
      _state.bookmarkedIndices,
      _state.playlistMode == ps.PlaylistMode.bookmarks,
    );

    // 记住播放状态：仅在书签页才需要恢复，并且如果句子列表为空，就停止播放，不需要恢复
    final inBookmarksMode = _state.playlistMode == ps.PlaylistMode.bookmarks;
    final shouldResume =
        inBookmarksMode && _audioPlayer.playing && nextIndex != null;

    // 仅在书签页执行"取消收藏"时需要立即暂停
    if (inBookmarksMode && isRemoving && _audioPlayer.playing) {
      await pause();
    }

    if (isRemoving) {
      // 移除收藏（包括所有同文本的收藏）
      final toRemove = indicesToRemove.isEmpty ? {index} : indicesToRemove;
      for (final idx in toRemove) {
        _state.bookmarkedIndices.remove(idx);
        if (idx >= 0 && idx < _state.sentences.length) {
          _state.sentences[idx].isBookmarked = false;
        }
      }

      if (inBookmarksMode) {
        // 更新当前选中到"下一个"书签
        _state.setCurrentBookmarkIndex(nextIndex);

        if (nextIndex != null && nextIndex < _state.sentences.length) {
          // 定位并设置 clip 至该句子
          final s = _state.sentences[nextIndex];
          await _controller.setClip(s.startTime, s.endTime);
        } else {
          // 列表为空：停止播放并重置 clip
          await _controller.clearClip();
          _state.setCurrentBookmarkIndex(null);
          await stop();
        }
      }
    } else {
      // 添加收藏：无论在哪个页面，都不影响播放状态
      _state.bookmarkedIndices.add(index);
      _state.sentences[index].isBookmarked = true;
    }

    if (_state.currentAudioItem != null) {
      await BookmarkManager.saveBookmarks(
        _state.currentAudioItem!.id,
        _state.bookmarkedIndices,
      );
    }

    notifyListeners();

    // 恢复播放：仅在书签页、之前处于播放状态且仍有书签可播时
    if (inBookmarksMode &&
        shouldResume &&
        _state.bookmarkedSentences.isNotEmpty) {
      await play();
    }
  }

  Future<void> updateSettings(PlaybackSettings newSettings) async {
    // 保存旧设置，用于检测播放模式是否改变
    final oldSettings = _state.settings;
    final wasPlaying = _audioPlayer.playing;

    // 检查播放模式是否会改变
    final oldContinuousMode =
        _state.playlistMode == ps.PlaylistMode.full &&
        oldSettings.autoPlayNextSentenceEnabled &&
        !oldSettings.loopEnabled;
    final newContinuousMode =
        _state.playlistMode == ps.PlaylistMode.full &&
        newSettings.autoPlayNextSentenceEnabled &&
        !newSettings.loopEnabled;
    final modeWillChange = oldContinuousMode != newContinuousMode;

    _state.setSettings(newSettings);
    await _audioPlayer.setSpeed(newSettings.playbackSpeed);
    await StorageService.saveSettings(newSettings);

    // 如果正在播放且播放模式改变，重新开始播放以应用新模式
    if (wasPlaying && modeWillChange) {
      await pause();
      await play();
    }
  }

  void setAutoScroll(bool enabled) {
    _state.setAutoScrollEnabled(enabled);
  }

  /// 切换播放列表模式
  Future<void> setPlaylistMode(ps.PlaylistMode mode) async {
    if (_state.playlistMode == mode) return;

    // 1. 暂停当前播放
    await pause();

    // 2. 切换模式
    _state.setPlaylistMode(mode);

    // 3. 清除 clip 状态，确保进度条显示正确
    _state.setClipStart(Duration.zero);

    // 4. 根据新模式恢复播放位置
    if (mode == ps.PlaylistMode.full) {
      // 切换到 full text 模式
      if (_state.currentFullIndex != null &&
          _state.currentFullIndex! < _state.sentences.length) {
        await _audioPlayer.seek(
          _state.sentences[_state.currentFullIndex!].startTime,
        );
      } else if (_state.sentences.isNotEmpty) {
        // 确保有有效的索引
        _state.setCurrentFullIndex(0);
        await _audioPlayer.seek(_state.sentences[0].startTime);
      }
    } else {
      // 切换到 bookmark 模式
      final bookmarked = _state.bookmarkedSentences;
      if (bookmarked.isEmpty) {
        // 书签为空，保持当前状态但不播放
        return;
      }

      if (_state.currentBookmarkIndex != null &&
          _state.currentBookmarkIndex! < _state.sentences.length &&
          _state.bookmarkedIndices.contains(_state.currentBookmarkIndex)) {
        await _audioPlayer.seek(
          _state.sentences[_state.currentBookmarkIndex!].startTime,
        );
      } else {
        // 如果当前没有选中的 bookmark，选择第一个
        _state.setCurrentBookmarkIndex(bookmarked.first.index);
        await _audioPlayer.seek(bookmarked.first.startTime);
      }
    }
  }

  /// 保存当前音频的播放状态
  Future<void> saveCurrentPlaybackState() async {
    if (_state.currentAudioItem == null) return;

    await PlaybackStateStorage.savePlaybackState(
      _state.currentAudioItem!,
      _audioPlayer,
      _state,
    );
  }

  @override
  void dispose() {
    _isDisposed = true;
    _positionSubscription?.cancel();
    _playerStateSubscription?.cancel();
    _audioPlayer.dispose();
    _state.dispose();
    super.dispose();
  }
}
