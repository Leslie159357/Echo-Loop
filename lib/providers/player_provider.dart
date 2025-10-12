import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import '../models/audio_item.dart';
import '../models/sentence.dart';
import '../models/playback_settings.dart';
import '../services/subtitle_parser.dart';
import '../services/storage_service.dart';

enum PlaylistMode { full, bookmarks }

class PlayerProvider extends ChangeNotifier {
  final AudioPlayer _audioPlayer = AudioPlayer();

  AudioItem? _currentAudioItem;
  List<Sentence> _sentences = [];
  int? _currentFullIndex;
  int? _currentBookmarkIndex;
  PlaybackSettings _settings = PlaybackSettings();
  Set<int> _bookmarkedIndices = {};

  bool _isLoading = false;
  StreamSubscription? _positionSubscription;
  StreamSubscription? _playerStateSubscription;
  bool _isDisposed = false;
  bool _autoScrollEnabled = true;
  PlaylistMode _playlistMode = PlaylistMode.full;

  // 播放控制 - 简化的状态管理
  int _playbackSessionId = 0; // 用于取消旧的播放会话
  int? _itemPlaybackSentenceIndex; // 标记哪个句子正在通过item按钮播放
  bool _isMainPlaybackPlaying = false; // 标记主播放控制的播放状态

  // 进度条相关 - 用于显示绝对位置
  Duration? _fullDuration; // 完整音频时长
  Duration _clipStart = Duration.zero; // 当前 clip 的起始位置

  // Getters
  AudioPlayer get audioPlayer => _audioPlayer;
  AudioItem? get currentAudioItem => _currentAudioItem;
  List<Sentence> get sentences => _sentences;
  List<Sentence> get bookmarkedSentences =>
      _sentences.where((s) => _bookmarkedIndices.contains(s.index)).toList();
  int? get currentFullIndex => _currentFullIndex;
  int? get currentBookmarkIndex => _currentBookmarkIndex;
  Sentence? get currentSentence =>
      _currentFullIndex != null && _currentFullIndex! < _sentences.length
      ? _sentences[_currentFullIndex!]
      : null;
  PlaybackSettings get settings => _settings;
  Set<int> get bookmarkedIndices => _bookmarkedIndices;
  bool get isLoading => _isLoading;
  bool get isPlaying => _audioPlayer.playing;
  bool get isMainPlaybackPlaying => _isMainPlaybackPlaying; // 主播放控制的播放状态
  Duration get currentPosition => _audioPlayer.position;
  Duration? get totalDuration => _fullDuration; // 返回完整音频时长
  bool get hasAudio => _currentAudioItem != null;
  bool get hasSentences => _sentences.isNotEmpty;
  bool get autoScrollEnabled => _autoScrollEnabled;
  int? get itemPlaybackSentenceIndex => _itemPlaybackSentenceIndex;

  // 绝对位置流：将 clip 相对位置映射到完整音频的绝对位置
  Stream<Duration> get absolutePositionStream =>
      _audioPlayer.positionStream.map((relativePosition) {
        return _clipStart + relativePosition;
      });

  void setPlaylistMode(PlaylistMode mode) {
    _playlistMode = mode;
  }

  PlayerProvider() {
    _loadSettings();
    _setupListeners();
  }

  Future<void> _loadSettings() async {
    _settings = await StorageService.loadSettings();
    notifyListeners();
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
    _updateCurrentSentence(position);
  }

  void _onPlayerStateChanged(PlayerState state) {
    // 处理播放完成（用于Continuous模式的音频循环）
    if (state.processingState == ProcessingState.completed) {
      _handlePlaybackCompleted();
    }
    notifyListeners();
  }

  /// 处理Continuous模式下的播放完成
  void _handlePlaybackCompleted() {
    if (_isDisposed) return;

    // 只在Continuous模式下处理音频循环
    if (!_shouldUseContinuousMode()) return;

    if (_settings.loopAudioEnabled) {
      final shouldLoop = _settings.loopAudio == 0 || true; // 简单处理
      if (shouldLoop && _sentences.isNotEmpty) {
        // 重新从头播放
        Future.microtask(() async {
          if (_playlistMode == PlaylistMode.bookmarks) {
            final bookmarked = bookmarkedSentences;
            if (bookmarked.isNotEmpty) {
              _currentBookmarkIndex = bookmarked.first.index;
            }
          } else {
            _currentFullIndex = 0;
          }
          notifyListeners();
          await _playContinuous();
        });
      } else {
        // 不循环，清除主播放状态
        _isMainPlaybackPlaying = false;
        notifyListeners();
      }
    } else {
      // 不循环，清除主播放状态
      _isMainPlaybackPlaying = false;
      notifyListeners();
    }
  }

  void _updateCurrentSentence(Duration position) {
    if (_sentences.isEmpty) return;

    final index = _sentences.indexWhere(
      (s) => position >= s.startTime && position < s.endTime,
    );

    if (index != -1) {
      if (_playlistMode == PlaylistMode.bookmarks) {
        if (_bookmarkedIndices.contains(index) &&
            index != _currentBookmarkIndex) {
          _currentBookmarkIndex = index;
          notifyListeners();
        }
      } else {
        if (index != _currentFullIndex) {
          _currentFullIndex = index;
          notifyListeners();
        }
      }
    }
  }

  Future<void> loadAudio(AudioItem audioItem) async {
    if (_currentAudioItem?.id == audioItem.id) return;

    _isLoading = true;
    notifyListeners();

    try {
      // Stop current playback
      await stop();

      _currentAudioItem = audioItem;
      _sentences = [];
      _currentFullIndex = null;
      _currentBookmarkIndex = null;

      // Load audio
      try {
        await _audioPlayer.setFilePath(audioItem.audioPath);
        await _audioPlayer.setSpeed(_settings.playbackSpeed);

        // 获取完整音频时长
        _fullDuration = _audioPlayer.duration;
        // 等待时长加载完成
        if (_fullDuration == null) {
          await _audioPlayer.durationStream.first;
          _fullDuration = _audioPlayer.duration;
        }
        _clipStart = Duration.zero;
      } catch (e) {
        print('Error loading audio file: $e');
        _currentAudioItem = null;
        rethrow;
      }

      // Load transcript if available
      if (audioItem.hasTranscript) {
        try {
          _sentences = await SubtitleParser.parseSubtitle(
            audioItem.transcriptPath!,
          );
        } catch (e) {
          print('Error loading transcript: $e');
        }
      }

      // Load bookmarks
      try {
        _bookmarkedIndices = await StorageService.loadBookmarks(audioItem.id);
      } catch (e) {
        print('Error loading bookmarks: $e');
        _bookmarkedIndices = {};
      }

      // Auto-bookmark sentences wrapped in []
      for (var sentence in _sentences) {
        final text = sentence.text.trim();
        if (text.startsWith('[') && text.endsWith(']')) {
          _bookmarkedIndices.add(sentence.index);
        }
      }

      // Update sentence bookmark status
      for (var sentence in _sentences) {
        sentence.isBookmarked = _bookmarkedIndices.contains(sentence.index);
      }

      // Save auto-bookmarked sentences
      if (_bookmarkedIndices.isNotEmpty) {
        await StorageService.saveBookmarks(audioItem.id, _bookmarkedIndices);
      }

      // Set initial sentence to first sentence if available
      if (_sentences.isNotEmpty) {
        _currentFullIndex = 0;
        await _audioPlayer.seek(_sentences[0].startTime);
      }
    } catch (e) {
      print('Error loading audio: $e');
      _currentAudioItem = null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ============================================================================
  // 播放逻辑：两种模式
  // ============================================================================

  /// 决定使用哪种播放模式
  bool _shouldUseContinuousMode() {
    // 书签模式：永远使用 Subtitle-Driven
    if (_playlistMode == PlaylistMode.bookmarks) return false;

    // 全文模式：autoPlayNextSentence开启 且 sentenceRepeat关闭 => Continuous
    if (_settings.autoPlayNextSentenceEnabled && !_settings.loopEnabled) {
      return true;
    }

    // 其他情况：Subtitle-Driven
    return false;
  }

  /// 主播放方法 - 整体播放模式
  Future<void> play() async {
    if (_currentAudioItem == null) return;

    // 停止item播放（如果正在播放）
    if (_itemPlaybackSentenceIndex != null) {
      _playbackSessionId++; // 取消item播放会话
      _itemPlaybackSentenceIndex = null;
    }

    // 标记为主播放模式
    _isMainPlaybackPlaying = true;

    if (_sentences.isEmpty) {
      // 没有字幕，直接播放
      await _audioPlayer.play();
      return;
    }

    // 确保初始索引存在
    if (_playlistMode == PlaylistMode.bookmarks) {
      final bookmarked = bookmarkedSentences;
      if (bookmarked.isEmpty) return;
      if (_currentBookmarkIndex == null ||
          !_bookmarkedIndices.contains(_currentBookmarkIndex)) {
        _currentBookmarkIndex = bookmarked.first.index;
      }
    } else {
      if (_currentFullIndex == null) {
        _currentFullIndex = 0;
      }
    }

    if (_shouldUseContinuousMode()) {
      await _playContinuous();
    } else {
      // 准备播放列表和起始位置
      List<Sentence> playList;
      int startIndex;

      if (_playlistMode == PlaylistMode.bookmarks) {
        playList = bookmarkedSentences;
        // 找到当前书签的位置
        if (_currentBookmarkIndex != null) {
          startIndex = playList.indexWhere(
            (s) => s.index == _currentBookmarkIndex,
          );
          if (startIndex == -1) startIndex = 0;
        } else {
          startIndex = 0;
        }
      } else {
        playList = _sentences;
        startIndex = _currentFullIndex ?? 0;
      }

      await _playSubtitleDriven(playList, startIndex);
    }
  }

  /// 模式1：全程连续播放
  Future<void> _playContinuous() async {
    final sessionId = ++_playbackSessionId;

    // 确定要 seek 的目标位置
    final startIndex = _playlistMode == PlaylistMode.bookmarks
        ? _currentBookmarkIndex
        : _currentFullIndex;

    Duration? targetPosition;
    if (startIndex != null && startIndex < _sentences.length) {
      targetPosition = _sentences[startIndex].startTime;
    }

    // 只在有 clip 的情况下才清除，避免不必要的重置
    if (_clipStart != Duration.zero) {
      await _audioPlayer.setClip(start: null, end: null);
      _clipStart = Duration.zero;
    }

    // seek 到目标位置
    if (targetPosition != null) {
      await _audioPlayer.seek(targetPosition);
    }

    await _audioPlayer.play();
  }

  /// 模式2：Subtitle-Driven播放（异步for循环）
  /// [playList] 要播放的句子列表
  /// [startIndex] 起始位置（在playList中的索引）
  Future<void> _playSubtitleDriven(
    List<Sentence> playList,
    int startIndex,
  ) async {
    final sessionId = ++_playbackSessionId;

    if (playList.isEmpty) return;

    // 音频循环计数
    int audioLoopCount = 0;

    while (true) {
      // 检查音频循环条件
      if (audioLoopCount > 0) {
        if (!_settings.loopAudioEnabled) break;
        final shouldLoop =
            _settings.loopAudio == 0 || audioLoopCount < _settings.loopAudio;
        if (!shouldLoop) break;
      }

      // 确定起始位置：第一轮使用传入的startIndex，后续循环从0开始
      final int loopStartIdx = audioLoopCount == 0 ? startIndex : 0;

      // 使用异步for循环逐句播放
      for (int i = loopStartIdx; i < playList.length; i++) {
        // print('playList: ${playList.length}, startIndex: $startIndex, i: $i');
        // 检查会话是否被取消
        if (sessionId != _playbackSessionId || _isDisposed) {
          _isMainPlaybackPlaying = false;
          return;
        }

        final sentence = playList[i];

        // 更新当前索引（使用句子的原始索引）
        if (_playlistMode == PlaylistMode.bookmarks) {
          _currentBookmarkIndex = sentence.index;
        } else {
          _currentFullIndex = sentence.index;
        }
        notifyListeners();

        // 播放当前句子
        await _playSingleSentenceWithLoop(sentence, sessionId);

        // 检查会话是否被取消
        if (sessionId != _playbackSessionId || _isDisposed) {
          _isMainPlaybackPlaying = false;
          return;
        }

        // 如果不是自动播放下一句，退出循环
        if (!_settings.autoPlayNextSentenceEnabled) {
          _isMainPlaybackPlaying = false;
          notifyListeners();
          return;
        }
      }

      // 一轮播放完成
      audioLoopCount++;

      // 如果没有开启音频循环，退出
      if (!_settings.loopAudioEnabled) break;
    }

    // 播放完成，清除主播放状态
    _isMainPlaybackPlaying = false;
    notifyListeners();
  }

  /// 播放单个句子一次（基础方法）
  Future<void> _playSingleSentenceOnce(Sentence sentence, int sessionId) async {
    if (_currentAudioItem == null) return;
    if (sessionId != _playbackSessionId || _isDisposed) return;

    // 使用 setClip 限定播放范围
    _clipStart = sentence.startTime;
    await _audioPlayer.setClip(
      start: sentence.startTime,
      end: sentence.endTime,
    );
    // 立即通知 UI 更新，让进度条显示正确的位置
    notifyListeners();

    await _audioPlayer.seek(Duration.zero);
    await _audioPlayer.play();

    // 等待播放完成（监听播放状态）
    await for (final state in _audioPlayer.playerStateStream) {
      if (sessionId != _playbackSessionId || _isDisposed) {
        await _audioPlayer.pause();
        return;
      }
      if (state.processingState == ProcessingState.completed) {
        break;
      }
    }
  }

  /// 播放单个句子（带循环和间隔）- 用于整体播放中的逐句播放
  Future<void> _playSingleSentenceWithLoop(
    Sentence sentence,
    int sessionId,
  ) async {
    if (_currentAudioItem == null) return;

    final loopCount = _settings.loopEnabled ? _settings.loopCount : 1;
    final pauseInterval = _settings.pauseInterval;

    // 循环播放当前句子
    for (int loop = 0; loop < loopCount; loop++) {
      if (sessionId != _playbackSessionId || _isDisposed) return;

      await _playSingleSentenceOnce(sentence, sessionId);

      if (sessionId != _playbackSessionId || _isDisposed) return;

      // 循环间隔
      if (loop < loopCount - 1 && pauseInterval > Duration.zero) {
        await Future.delayed(pauseInterval);
      }
    }

    // 句子播放完成后的间隔
    if (_settings.autoPlayNextSentenceEnabled &&
        _settings.loopEnabled &&
        pauseInterval > Duration.zero) {
      await Future.delayed(pauseInterval);
    }
  }

  /// 单次播放句子（用于item按钮点击）
  Future<void> playSingleSentenceOnce(int index) async {
    if (index < 0 || index >= _sentences.length) return;

    final sentence = _sentences[index];
    final sessionId = _playbackSessionId;

    await _playSingleSentenceOnce(sentence, sessionId);

    // 播放完成，清除item播放状态
    _itemPlaybackSentenceIndex = null;
    notifyListeners();
  }

  // ============================================================================
  // 控制方法
  // ============================================================================

  Future<void> pause() async {
    _playbackSessionId++; // 取消当前播放会话
    _isMainPlaybackPlaying = false;
    _itemPlaybackSentenceIndex = null;
    await _audioPlayer.pause();
  }

  Future<void> stop() async {
    _playbackSessionId++; // 取消当前播放会话
    _isMainPlaybackPlaying = false;
    _itemPlaybackSentenceIndex = null;
    await _audioPlayer.stop();
  }

  Future<void> seek(Duration position) async {
    await _audioPlayer.seek(position);
  }

  /// 绝对位置的 seek（用于进度条拖动）
  Future<void> seekAbsolute(Duration absolutePosition) async {
    // 清除 clip 限制，切换到完整音频模式
    if (_clipStart != Duration.zero) {
      await _audioPlayer.setClip(start: null, end: null);
      // 先 seek 到绝对位置，然后再更新 _clipStart
      await _audioPlayer.seek(absolutePosition);
      _clipStart = Duration.zero;
      // 如果正在 item 播放，清除 item 播放状态
      if (_itemPlaybackSentenceIndex != null) {
        _itemPlaybackSentenceIndex = null;
        notifyListeners();
      }
    } else {
      // 直接 seek 到绝对位置
      await _audioPlayer.seek(absolutePosition);
    }
  }

  Future<void> selectFullSentence(int index) async {
    if (index < 0 || index >= _sentences.length) return;
    _currentFullIndex = index;
    _autoScrollEnabled = true;

    // 点击item选中，移动进度条到该位置
    if (_currentAudioItem != null) {
      // 清除 clip 限制，切换到完整音频模式
      if (_clipStart != Duration.zero) {
        await _audioPlayer.setClip(start: null, end: null);
        // 先 seek 到目标位置，然后再更新 _clipStart
        await _audioPlayer.seek(_sentences[index].startTime);
        _clipStart = Duration.zero;
        // 如果正在 item 播放，清除 item 播放状态
        if (_itemPlaybackSentenceIndex != null) {
          _itemPlaybackSentenceIndex = null;
        }
      } else {
        await _audioPlayer.seek(_sentences[index].startTime);
      }
    }
    notifyListeners();
  }

  Future<void> selectBookmarkedSentence(int index) async {
    if (index < 0 || index >= _sentences.length) return;
    _currentBookmarkIndex = index;
    _autoScrollEnabled = true;

    // 点击item选中，移动进度条到该位置
    if (_currentAudioItem != null) {
      // 清除 clip 限制，切换到完整音频模式
      if (_clipStart != Duration.zero) {
        await _audioPlayer.setClip(start: null, end: null);
        // 先 seek 到目标位置，然后再更新 _clipStart
        await _audioPlayer.seek(_sentences[index].startTime);
        _clipStart = Duration.zero;
        // 如果正在 item 播放，清除 item 播放状态
        if (_itemPlaybackSentenceIndex != null) {
          _itemPlaybackSentenceIndex = null;
        }
      } else {
        await _audioPlayer.seek(_sentences[index].startTime);
      }
    }
    notifyListeners();
  }

  /// 播放指定句子（用于点击播放按钮）- 单句播放模式
  Future<void> playSentence(int index) async {
    if (index < 0 || index >= _sentences.length) return;

    // 如果点击的是正在播放的item，停止播放
    if (_itemPlaybackSentenceIndex == index) {
      _playbackSessionId++; // 取消当前播放会话
      _itemPlaybackSentenceIndex = null;
      await _audioPlayer.pause();
      notifyListeners();
      return;
    }

    // 停止主播放（如果正在播放）
    if (_isMainPlaybackPlaying) {
      _playbackSessionId++; // 取消主播放会话
      _isMainPlaybackPlaying = false;
      await _audioPlayer.pause();
    }

    // 书签模式检查
    if (_playlistMode == PlaylistMode.bookmarks) {
      if (!_bookmarkedIndices.contains(index)) return;
      _currentBookmarkIndex = index;
    } else {
      _currentFullIndex = index;
    }

    // 标记为item播放
    _itemPlaybackSentenceIndex = index;
    ++_playbackSessionId;

    // 先通知 UI 状态变化，然后开始播放（播放内部会再次通知进度条更新）
    notifyListeners();
    await playSingleSentenceOnce(index);
  }

  Future<void> nextSentence() async {
    if (_sentences.isEmpty) return;

    if (_playlistMode == PlaylistMode.bookmarks) {
      final bookmarked = bookmarkedSentences;
      if (bookmarked.isEmpty) return;

      int pos = bookmarked.indexWhere((s) => s.index == _currentBookmarkIndex);
      if (pos == -1)
        pos = 0;
      else if (pos >= bookmarked.length - 1)
        return; // 到达最后一句
      else
        pos++;

      _currentBookmarkIndex = bookmarked[pos].index;
      print(
        'next bookmark Sentence: $_currentBookmarkIndex , sentence: ${bookmarkedSentences[pos]}',
      );
    } else {
      if (_currentFullIndex == null)
        _currentFullIndex = 0;
      else if (_currentFullIndex! >= _sentences.length - 1)
        return; // 到达最后一句
      else
        _currentFullIndex = _currentFullIndex! + 1;
    }

    // 启用自动滚动，确保选中的 item 可见
    _autoScrollEnabled = true;

    // 确定目标位置
    final index = _playlistMode == PlaylistMode.bookmarks
        ? _currentBookmarkIndex
        : _currentFullIndex;

    if (index != null) {
      // 清除 clip 限制，确保进度条显示绝对时间
      if (_clipStart != Duration.zero) {
        await _audioPlayer.setClip(start: null, end: null);
        _clipStart = Duration.zero;
        if (_itemPlaybackSentenceIndex != null) {
          _itemPlaybackSentenceIndex = null;
        }
      }
      await _audioPlayer.seek(_sentences[index].startTime);
    }

    notifyListeners();
  }

  Future<void> previousSentence() async {
    if (_sentences.isEmpty) return;

    if (_playlistMode == PlaylistMode.bookmarks) {
      final bookmarked = bookmarkedSentences;
      if (bookmarked.isEmpty) return;

      int pos = bookmarked.indexWhere((s) => s.index == _currentBookmarkIndex);
      if (pos <= 0) return; // 到达第一句
      pos--;

      _currentBookmarkIndex = bookmarked[pos].index;
      print(
        'previous bookmark Sentence: $_currentBookmarkIndex, sentence: ${bookmarkedSentences[pos]}',
      );
    } else {
      if (_currentFullIndex == null)
        _currentFullIndex = 0;
      else if (_currentFullIndex! <= 0)
        return; // 到达第一句
      else
        _currentFullIndex = _currentFullIndex! - 1;
    }

    // 启用自动滚动，确保选中的 item 可见
    _autoScrollEnabled = true;

    // 确定目标位置
    final index = _playlistMode == PlaylistMode.bookmarks
        ? _currentBookmarkIndex
        : _currentFullIndex;

    if (index != null) {
      // 清除 clip 限制，确保进度条显示绝对时间
      if (_clipStart != Duration.zero) {
        await _audioPlayer.setClip(start: null, end: null);
        _clipStart = Duration.zero;
        if (_itemPlaybackSentenceIndex != null) {
          _itemPlaybackSentenceIndex = null;
        }
      }
      await _audioPlayer.seek(_sentences[index].startTime);
    }

    notifyListeners();
  }

  Future<void> toggleBookmark(int index) async {
    if (_bookmarkedIndices.contains(index)) {
      _bookmarkedIndices.remove(index);
      _sentences[index].isBookmarked = false;
    } else {
      _bookmarkedIndices.add(index);
      _sentences[index].isBookmarked = true;
    }

    if (_currentAudioItem != null) {
      await StorageService.saveBookmarks(
        _currentAudioItem!.id,
        _bookmarkedIndices,
      );
    }

    notifyListeners();
  }

  Future<void> updateSettings(PlaybackSettings newSettings) async {
    _settings = newSettings;
    await _audioPlayer.setSpeed(newSettings.playbackSpeed);
    await StorageService.saveSettings(newSettings);
    notifyListeners();
  }

  void setAutoScroll(bool enabled) {
    _autoScrollEnabled = enabled;
    notifyListeners();
  }

  @override
  void dispose() {
    _isDisposed = true;
    _positionSubscription?.cancel();
    _playerStateSubscription?.cancel();
    _audioPlayer.dispose();
    super.dispose();
  }
}
