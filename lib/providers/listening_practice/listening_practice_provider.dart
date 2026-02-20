import 'dart:async';
import 'package:just_audio/just_audio.dart' as ja;
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../models/audio_item.dart';
import '../../models/sentence.dart';
import '../../models/playback_settings.dart';
import '../../models/listening_practice_state.dart';
import '../../services/storage_service.dart';
import '../audio_engine/audio_engine_provider.dart';
import 'bookmark_manager.dart';
import 'playback_state_storage.dart';
import 'sentence_tracker.dart';

export '../../models/listening_practice_state.dart'
    show PlaylistMode, ListeningPracticeState;

part 'listening_practice_provider.g.dart';

@Riverpod(keepAlive: true)
class ListeningPractice extends _$ListeningPractice {
  StreamSubscription? _positionSub;
  StreamSubscription? _playerStateSub;

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
      _playerStateSub =
          _engine.playerStateStream.listen(_onPlayerStateChanged);
    });
  }

  void _disposeListeners() {
    _positionSub?.cancel();
    _playerStateSub?.cancel();
  }

  Future<void> _loadSettings() async {
    final settings = await StorageService.loadSettings();
    state = state.copyWith(settings: settings);
  }

  void _onPositionChanged(Duration absolutePosition) {
    _updateCurrentSentence(absolutePosition);
  }

  void _onPlayerStateChanged(ja.PlayerState playerState) {
    if (playerState.processingState == ja.ProcessingState.completed) {
      _handlePlaybackCompleted();
    }
    // Force rebuild for isPlaying changes
    state = state.copyWith();
  }

  bool _shouldUseContinuousMode() {
    if (state.playlistMode == PlaylistMode.bookmarks) return false;
    if (state.settings.autoPlayNextSentenceEnabled &&
        !state.settings.loopEnabled) {
      return true;
    }
    return false;
  }

  void _updateCurrentSentence(Duration position) {
    if (!_shouldUseContinuousMode() || !_engine.isPlaying) return;
    if (state.sentences.isEmpty) return;

    int newIndex = SentenceTracker.findSentenceIndexByPosition(
      state.sentences,
      position,
    );

    if (newIndex != -1 && newIndex != state.currentFullIndex) {
      state = state.copyWith(currentFullIndex: newIndex);
    }
  }

  void _handlePlaybackCompleted() {
    if (!_shouldUseContinuousMode()) return;

    if (state.settings.loopAudioEnabled) {
      final shouldLoop = state.settings.loopAudio == 0 || true;
      if (shouldLoop && state.sentences.isNotEmpty) {
        Future.microtask(() async {
          if (state.playlistMode == PlaylistMode.bookmarks) {
            final bookmarked = state.bookmarkedSentences;
            if (bookmarked.isNotEmpty) {
              state = state.copyWith(
                currentBookmarkIndex: bookmarked.first.index,
              );
            }
          } else {
            state = state.copyWith(currentFullIndex: 0);
          }
          await _playContinuous();
        });
      }
    }
  }

  // --- 加载音频（业务编排）---
  Future<void> loadAudio(AudioItem audioItem) async {
    print("loadAudio: ${audioItem.name}");
    state = state.copyWith(autoScrollEnabled: true);

    if (state.currentAudioItem?.id == audioItem.id) return;

    state = state.copyWith(isLoading: true);

    try {
      await stop();

      state = state.copyWith(
        currentAudioItem: audioItem,
        sentences: [],
        clearCurrentFullIndex: true,
        clearCurrentBookmarkIndex: true,
      );

      try {
        await _engine.loadAudio(audioItem, state.settings.playbackSpeed);
      } catch (e) {
        print('Error loading audio file: $e');
        state = state.copyWith(clearCurrentAudioItem: true);
        rethrow;
      }

      final sentences = await _engine.loadTranscript(audioItem);

      final storedBookmarks =
          await BookmarkManager.loadBookmarks(audioItem.id);
      var bookmarkedIndices = Set<int>.from(storedBookmarks);

      final isFirstLoad = storedBookmarks.isEmpty;
      if (isFirstLoad) {
        final autoBookmarks =
            BookmarkManager.autoAddBracketBookmarks(sentences);
        bookmarkedIndices = {...bookmarkedIndices, ...autoBookmarks};

        if (autoBookmarks.isNotEmpty) {
          await BookmarkManager.saveBookmarks(
            audioItem.id,
            bookmarkedIndices,
          );
        }
      }

      // 清理 [] 包裹的句子文本
      final cleanedSentences = <Sentence>[];
      for (int i = 0; i < sentences.length; i++) {
        final text = sentences[i].text.trim();
        if (text.startsWith('[') && text.endsWith(']') && text.length > 2) {
          cleanedSentences.add(sentences[i].copyWith(
            text: text.substring(1, text.length - 1).trim(),
          ));
        } else {
          cleanedSentences.add(sentences[i]);
        }
      }

      // 更新书签状态
      for (var sentence in cleanedSentences) {
        sentence.isBookmarked = bookmarkedIndices.contains(sentence.index);
      }

      state = state.copyWith(
        sentences: cleanedSentences,
        bookmarkedIndices: bookmarkedIndices,
        currentFullIndex: 0,
      );

      // 恢复播放状态
      await _restorePlaybackState(audioItem);

      // 如果没有恢复到有效状态，设置初始句子
      if (state.sentences.isNotEmpty && state.currentFullIndex == null) {
        state = state.copyWith(currentFullIndex: 0);
        await _engine.seek(state.sentences[0].startTime);
      }
    } catch (e) {
      print('Error loading audio: $e');
      state = state.copyWith(clearCurrentAudioItem: true);
    } finally {
      state = state.copyWith(isLoading: false);
    }
  }

  Future<void> _restorePlaybackState(AudioItem audioItem) async {
    final result =
        await PlaybackStateStorage.loadPlaybackState(audioItem.id);
    if (result == null) return;

    try {
      if (result.playlistMode != null) {
        state = state.copyWith(playlistMode: result.playlistMode);
      }
      if (result.currentFullIndex != null) {
        state = state.copyWith(currentFullIndex: result.currentFullIndex);
      }
      if (result.currentBookmarkIndex != null) {
        state = state.copyWith(
          currentBookmarkIndex: result.currentBookmarkIndex,
        );
      }
      if (result.position != null) {
        await _engine.seek(result.position!);
      }
      print('Restored playback state for ${audioItem.name}');
    } catch (e) {
      print('Error restoring playback state: $e');
    }
  }

  // --- Play ---
  Future<void> play() async {
    if (state.currentAudioItem == null) return;

    if (state.sentences.isEmpty) {
      await _engine.play();
      return;
    }

    // 确保初始索引存在
    if (state.playlistMode == PlaylistMode.bookmarks) {
      final bookmarked = state.bookmarkedSentences;
      if (bookmarked.isEmpty) return;
      if (state.currentBookmarkIndex == null ||
          !state.bookmarkedIndices.contains(state.currentBookmarkIndex)) {
        state = state.copyWith(
          currentBookmarkIndex: bookmarked.first.index,
        );
      }
    } else {
      if (state.currentFullIndex == null ||
          state.currentFullIndex! >= state.sentences.length) {
        state = state.copyWith(currentFullIndex: 0);
      }
    }

    if (_shouldUseContinuousMode()) {
      await _playContinuous();
    } else {
      // 准备播放列表和起始位置
      List<Sentence> playList;
      int startIndex;

      if (state.playlistMode == PlaylistMode.bookmarks) {
        playList = state.bookmarkedSentences;
        if (state.currentBookmarkIndex != null) {
          startIndex = playList.indexWhere(
            (s) => s.index == state.currentBookmarkIndex,
          );
          if (startIndex == -1) startIndex = 0;
        } else {
          startIndex = 0;
        }
      } else {
        playList = state.sentences;
        startIndex = state.currentFullIndex ?? 0;
      }

      await _playSubtitleDriven(playList, startIndex);
    }
  }

  // --- 连续播放模式 ---
  Future<void> _playContinuous() async {
    final sessionId = _engine.newSession();

    final startIndex = state.currentFullIndex;
    Duration? targetPosition;
    if (startIndex != null && startIndex < state.sentences.length) {
      targetPosition = state.sentences[startIndex].startTime;
    }

    await _engine.clearClip();
    if (targetPosition != null) {
      await _engine.seek(targetPosition);
    }

    await _engine.play();

    if (_engine.isPlaying) {
      await _engine.playerStateStream.firstWhere(
        (playerState) =>
            !_engine.isActiveSession(sessionId) ||
            !playerState.playing ||
            playerState.processingState == ja.ProcessingState.completed,
      );
    }

    print("playContinuous end");
    if (_engine.isActiveSession(sessionId)) {
      await _engine.stop();
    }
  }

  // --- 字幕驱动模式 ---
  Future<void> _playSubtitleDriven(
    List<Sentence> playList,
    int startIndex,
  ) async {
    final sessionId = _engine.newSession();

    if (playList.isEmpty) return;

    int audioLoopCount = 0;

    while (true) {
      if (audioLoopCount > 0) {
        if (!state.settings.loopAudioEnabled) break;
        final shouldLoop = state.settings.loopAudio == 0 ||
            audioLoopCount < state.settings.loopAudio;
        if (!shouldLoop) break;
      }

      final int loopStartIdx = audioLoopCount == 0 ? startIndex : 0;

      for (int i = loopStartIdx; i < playList.length; i++) {
        if (!_engine.isActiveSession(sessionId)) return;

        final sentence = playList[i];

        // 更新当前索引
        if (state.playlistMode == PlaylistMode.bookmarks) {
          if (state.currentBookmarkIndex != sentence.index) {
            state = state.copyWith(currentBookmarkIndex: sentence.index);
          }
        } else {
          if (state.currentFullIndex != sentence.index) {
            state = state.copyWith(currentFullIndex: sentence.index);
          }
        }

        // 播放当前句子
        await _engine.playClipWithLoops(
          sentence,
          sessionId,
          loopCount:
              state.settings.loopEnabled ? state.settings.loopCount : 1,
          interval: state.settings.pauseInterval,
        );

        // 句子之间间隔
        if (i < playList.length - 1) {
          if (state.playlistMode == PlaylistMode.bookmarks &&
              !state.settings.loopEnabled) {
            await Future.delayed(const Duration(seconds: 1));
          } else if (state.settings.autoPlayNextSentenceEnabled &&
              state.settings.loopEnabled &&
              state.settings.pauseInterval > Duration.zero) {
            await Future.delayed(state.settings.pauseInterval);
          }
        }

        if (!_engine.isActiveSession(sessionId)) return;

        if (!state.settings.autoPlayNextSentenceEnabled) {
          if (_engine.isPlaying) {
            await _engine.playerStateStream.firstWhere(
              (playerState) =>
                  !playerState.playing ||
                  playerState.processingState ==
                      ja.ProcessingState.completed,
            );
          }
          return;
        }
      }

      audioLoopCount++;

      if (!state.settings.loopAudioEnabled) break;
    }

    if (_engine.isActiveSession(sessionId)) {
      await _engine.stop();
    }
  }

  Future<void> pause() async {
    await _engine.pause();
  }

  Future<void> stop() async {
    await _engine.stop();
  }

  Future<void> seek(Duration position) async {
    await _engine.seek(position);
  }

  Future<void> seekAbsolute(Duration absolutePosition) async {
    final wasPlaying = _engine.isPlaying;
    if (wasPlaying) {
      await pause();
    }

    state = state.copyWith(autoScrollEnabled: true);

    // 清除 clip 状态
    await _engine.clearClip();
    await _engine.seek(absolutePosition);

    int? snappedBookmarkIndex;
    if (state.sentences.isNotEmpty) {
      final newIndex = SentenceTracker.findSentenceIndexByPosition(
        state.sentences,
        absolutePosition,
      );

      if (newIndex != -1) {
        if (state.playlistMode == PlaylistMode.bookmarks) {
          if (state.bookmarkedIndices.contains(newIndex)) {
            state = state.copyWith(currentBookmarkIndex: newIndex);
            snappedBookmarkIndex = newIndex;
          } else {
            final closestIdx = SentenceTracker.findClosestBookmark(
              state.bookmarkedSentences,
              absolutePosition,
            );
            if (closestIdx != null) {
              state = state.copyWith(currentBookmarkIndex: closestIdx);
              snappedBookmarkIndex = closestIdx;
            }
          }
        } else {
          state = state.copyWith(currentFullIndex: newIndex);
        }
      }
    }

    if (snappedBookmarkIndex != null) {
      final s = state.sentences[snappedBookmarkIndex];
      await _engine.seek(s.startTime);
    }

    if (wasPlaying) {
      await play();
    }
  }

  Future<void> selectFullSentence(int index, {bool autoPlay = true}) async {
    if (index < 0 || index >= state.sentences.length) return;

    final shouldResume = autoPlay && _engine.isPlaying;
    if (shouldResume) {
      await pause();
    }

    state = state.copyWith(
      currentFullIndex: index,
      lastPlayedFullIndex: index,
    );

    if (state.currentAudioItem != null) {
      await _engine.clearClip();
      await _engine.seek(state.sentences[index].startTime);
    }

    if (autoPlay) {
      await play();
    }
  }

  Future<void> selectBookmarkedSentence(
    int index, {
    bool autoPlay = true,
  }) async {
    if (index < 0 || index >= state.sentences.length) return;

    final shouldResume = autoPlay && _engine.isPlaying;
    if (shouldResume) {
      await pause();
    }

    state = state.copyWith(
      currentBookmarkIndex: index,
      lastPlayedBookmarkIndex: index,
    );

    if (state.currentAudioItem != null) {
      await _engine.clearClip();
      await _engine.seek(state.sentences[index].startTime);
    }

    if (autoPlay) {
      await play();
    }
  }

  Future<void> replayCurrentSentence() async {
    if (state.sentences.isEmpty) return;

    int? lastPlayedIndex;
    if (state.playlistMode == PlaylistMode.bookmarks) {
      lastPlayedIndex = state.lastPlayedBookmarkIndex;
    } else {
      lastPlayedIndex = state.lastPlayedFullIndex;
    }

    if (lastPlayedIndex == null) return;

    if (_engine.isPlaying) {
      await pause();
    }

    if (state.playlistMode == PlaylistMode.bookmarks) {
      await selectBookmarkedSentence(lastPlayedIndex, autoPlay: true);
    } else {
      await selectFullSentence(lastPlayedIndex, autoPlay: true);
    }
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

    final shouldResume = _engine.isPlaying;
    if (shouldResume) await pause();

    if (state.playlistMode == PlaylistMode.bookmarks) {
      state = state.copyWith(
        currentBookmarkIndex: newIndex,
        lastPlayedBookmarkIndex: newIndex,
        autoScrollEnabled: true,
      );
    } else {
      state = state.copyWith(
        currentFullIndex: newIndex,
        lastPlayedFullIndex: newIndex,
        autoScrollEnabled: true,
      );
    }

    await _engine.clearClip();
    await _engine.seek(state.sentences[newIndex].startTime);

    if (shouldResume) {
      await play();
    }
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

    final shouldResume = _engine.isPlaying;
    if (shouldResume) await pause();

    if (state.playlistMode == PlaylistMode.bookmarks) {
      state = state.copyWith(
        currentBookmarkIndex: newIndex,
        lastPlayedBookmarkIndex: newIndex,
        autoScrollEnabled: true,
      );
    } else {
      state = state.copyWith(
        currentFullIndex: newIndex,
        lastPlayedFullIndex: newIndex,
        autoScrollEnabled: true,
      );
    }

    await _engine.clearClip();
    await _engine.seek(state.sentences[newIndex].startTime);

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
      state.sentences,
      state.bookmarkedIndices,
      state.playlistMode == PlaylistMode.bookmarks,
    );

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
          final s = newSentences[nextIndex];
          state = state.copyWith(
            bookmarkedIndices: newBookmarks,
            sentences: newSentences,
            currentBookmarkIndex: nextIndex,
          );
          await _engine.setClip(s.startTime, s.endTime);
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
      await BookmarkManager.saveBookmarks(
        state.currentAudioItem!.id,
        state.bookmarkedIndices,
      );
    }

    if (inBookmarksMode &&
        shouldResume &&
        state.bookmarkedSentences.isNotEmpty) {
      await play();
    }
  }

  Future<void> updateSettings(PlaybackSettings newSettings) async {
    final oldSettings = state.settings;
    final wasPlaying = _engine.isPlaying;

    final oldContinuousMode = state.playlistMode == PlaylistMode.full &&
        oldSettings.autoPlayNextSentenceEnabled &&
        !oldSettings.loopEnabled;
    final newContinuousMode = state.playlistMode == PlaylistMode.full &&
        newSettings.autoPlayNextSentenceEnabled &&
        !newSettings.loopEnabled;
    final modeWillChange = oldContinuousMode != newContinuousMode;

    state = state.copyWith(settings: newSettings);
    await _engine.setSpeed(newSettings.playbackSpeed);
    await StorageService.saveSettings(newSettings);

    if (wasPlaying && modeWillChange) {
      await pause();
      await play();
    }
  }

  void setAutoScroll(bool enabled) {
    state = state.copyWith(autoScrollEnabled: enabled);
  }

  Future<void> setPlaylistMode(PlaylistMode mode) async {
    if (state.playlistMode == mode) return;

    await pause();

    state = state.copyWith(playlistMode: mode);

    await _engine.clearClip();

    if (mode == PlaylistMode.full) {
      if (state.currentFullIndex != null &&
          state.currentFullIndex! < state.sentences.length) {
        await _engine.seek(
          state.sentences[state.currentFullIndex!].startTime,
        );
      } else if (state.sentences.isNotEmpty) {
        state = state.copyWith(currentFullIndex: 0);
        await _engine.seek(state.sentences[0].startTime);
      }
    } else {
      final bookmarked = state.bookmarkedSentences;
      if (bookmarked.isEmpty) return;

      if (state.currentBookmarkIndex != null &&
          state.currentBookmarkIndex! < state.sentences.length &&
          state.bookmarkedIndices.contains(state.currentBookmarkIndex)) {
        await _engine.seek(
          state.sentences[state.currentBookmarkIndex!].startTime,
        );
      } else {
        state = state.copyWith(
          currentBookmarkIndex: bookmarked.first.index,
        );
        await _engine.seek(bookmarked.first.startTime);
      }
    }
  }

  Future<void> saveCurrentPlaybackState() async {
    if (state.currentAudioItem == null) return;

    await PlaybackStateStorage.savePlaybackState(
      state.currentAudioItem!,
      _engine.audioPlayer,
      state,
    );
  }
}
