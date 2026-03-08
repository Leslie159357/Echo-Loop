/// 收藏句子复习 Provider
///
/// 加载所有收藏句子，按音频分组乱序后逐句复习。
/// 交互模式与难句补练（ReviewDifficultPractice）一致：
/// 盲听 1 遍 → 句间停顿 → 自动推进；支持偷看字幕、听不懂进入跟读模式。
///
/// 与难句补练的关键差异：
/// - 数据来源：全局 bookmarks（跨音频）
/// - 播放句子时需检测是否需要切换音频（loadAudio）
/// - 默认按音频分组乱序
/// - 不关联 LearningProgress / LearningSession
library;

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../database/daos/bookmark_dao.dart';
import '../../models/audio_item.dart';
import '../../models/bookmark_sentence.dart';
import '../../models/difficult_practice_settings.dart';
import '../../models/sentence.dart';
import '../audio_engine/audio_engine_provider.dart';
import 'review_difficult_practice_provider.dart';
import 'sentence_playback_engine.dart';

part 'bookmark_review_provider.g.dart';

/// 收藏复习 Provider
///
/// 复用 [ReviewDifficultPracticeState] 作为状态类。
/// 内部维护 [List<BookmarkSentence>] 用于跨音频播放。
@Riverpod(keepAlive: true)
class BookmarkReview extends _$BookmarkReview {
  /// 收藏句子列表（乱序后）
  List<BookmarkSentence> _sentences = [];

  /// 播放引擎
  late SentencePlaybackEngine _engine;

  /// 获取 AudioItemDao 的回调（通过 ref 注入）
  late dynamic Function(String) _getAudioItemById;

  @override
  ReviewDifficultPracticeState build() {
    _engine = SentencePlaybackEngine(
      getEngine: () => ref.read(audioEngineProvider.notifier),
    );
    ref.onDispose(() => _engine.cleanup());
    return const ReviewDifficultPracticeState();
  }

  /// 初始化收藏复习
  ///
  /// [bookmarks] 来自 BookmarkDao.watchAllWithAudioName() 的快照
  /// [getAudioItemById] 根据 audioItemId 获取 AudioItem 行数据
  void initialize(
    List<BookmarkWithAudio> bookmarks, {
    required Future<dynamic> Function(String) getAudioItemById,
  }) {
    _engine.cleanup();
    _getAudioItemById = getAudioItemById;

    // 过滤掉无效书签（迁移遗留的 startTime==endTime==0 条目）
    final validBookmarks = bookmarks.where((b) {
      final duration = b.bookmark.endTime - b.bookmark.startTime;
      return duration > 0 && b.bookmark.sentenceText.isNotEmpty;
    }).toList();

    // 按音频 ID 分组
    final grouped = <String, List<BookmarkWithAudio>>{};
    for (final b in validBookmarks) {
      (grouped[b.bookmark.audioItemId] ??= []).add(b);
    }

    // 方案 A：音频组间乱序，组内保持 sentenceIndex 顺序
    final audioIds = grouped.keys.toList()..shuffle();

    _sentences = [];
    for (final audioId in audioIds) {
      final items = grouped[audioId]!;
      // 组内已按 sentenceIndex 排序（DAO 查询保证）
      for (final item in items) {
        _sentences.add(
          BookmarkSentence(
            sentence: Sentence(
              index: item.bookmark.sentenceIndex,
              text: item.bookmark.sentenceText,
              startTime: Duration(
                milliseconds: (item.bookmark.startTime * 1000).round(),
              ),
              endTime: Duration(
                milliseconds: (item.bookmark.endTime * 1000).round(),
              ),
              isBookmarked: true,
            ),
            audioItemId: item.bookmark.audioItemId,
            audioName: item.audioName,
            originalSentenceIndex: item.bookmark.sentenceIndex,
          ),
        );
      }
    }

    state = ReviewDifficultPracticeState(
      currentSentenceIndex: 0,
      totalSentences: _sentences.length,
    );
  }

  /// 更新练习设置（仅会话内生效）
  ///
  /// 更新后中断当前播放，以新设置重新开始当前句子。
  void updateSettings(DifficultPracticeSettings newSettings) {
    _engine.invalidateSession();
    state = state.copyWith(settings: newSettings, isPlaying: false);
  }

  /// 获取当前句子索引
  int get currentIndex => state.currentSentenceIndex;

  /// 获取当前句子
  Sentence? get currentSentence =>
      _sentences.isNotEmpty && state.currentSentenceIndex < _sentences.length
      ? _sentences[state.currentSentenceIndex].sentence
      : null;

  /// 获取当前收藏句子（含音频信息）
  BookmarkSentence? get currentBookmarkSentence =>
      _sentences.isNotEmpty && state.currentSentenceIndex < _sentences.length
      ? _sentences[state.currentSentenceIndex]
      : null;

  /// 开始播放
  Future<void> startPlaying() async {
    if (_sentences.isEmpty) {
      state = state.copyWith(isCompleted: true);
      return;
    }
    await _startSentence();
  }

  /// 暂停播放
  void pause() {
    _engine.invalidateSession();
    state = state.copyWith(
      isPlaying: false,
      isPauseBetweenPlays: false,
      isCountdownPaused: false,
      isCountdownFastForward: false,
    );
  }

  /// 恢复播放
  Future<void> resume() async {
    if (state.isAnnotationMode) {
      _startShadowReading();
      return;
    }
    await _startSentence();
  }

  /// 进入跟读模式（听不懂）
  void enterAnnotationMode() {
    if (state.isAnnotationMode) return;
    _engine.invalidateSession();
    _startShadowReading();
  }

  /// 设置偷看字幕状态
  void setTextRevealed(bool revealed) {
    state = state.copyWith(isTextRevealed: revealed);
  }

  /// 取消当前句子的收藏
  ///
  /// 返回被移除的 [BookmarkSentence]（供外部调用 BookmarkDao 删除）。
  BookmarkSentence? removeBookmark() {
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
      );
      return removed;
    }

    final newIndex = removedIndex >= _sentences.length
        ? _sentences.length - 1
        : removedIndex;

    state = state.copyWith(
      currentSentenceIndex: newIndex,
      totalSentences: _sentences.length,
      isPlaying: false,
      isAnnotationMode: false,
      isTextRevealed: false,
      isPauseBetweenPlays: false,
      isPauseBetweenSentences: false,
      currentPlayCount: 1,
    );

    return removed;
  }

  /// 跳到下一句
  Future<void> goToNext() async {
    if (state.currentSentenceIndex >= state.totalSentences - 1) return;
    _engine.invalidateSession();
    state = state.copyWith(
      currentSentenceIndex: state.currentSentenceIndex + 1,
      currentPlayCount: 1,
      isAnnotationMode: false,
      isTextRevealed: false,
      isPauseBetweenPlays: false,
      isPauseBetweenSentences: false,
      isCountdownPaused: false,
      isCountdownFastForward: false,
    );
    await _startSentence();
  }

  /// 跳到上一句
  Future<void> goToPrevious() async {
    if (state.currentSentenceIndex <= 0) return;
    _engine.invalidateSession();
    state = state.copyWith(
      currentSentenceIndex: state.currentSentenceIndex - 1,
      currentPlayCount: 1,
      isAnnotationMode: false,
      isTextRevealed: false,
      isPauseBetweenPlays: false,
      isPauseBetweenSentences: false,
      isCountdownPaused: false,
      isCountdownFastForward: false,
    );
    await _startSentence();
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

  /// 倒计时期间重播当前句子
  Future<void> replayDuringCountdown() async {
    _engine.invalidateSession();
    if (state.isAnnotationMode) {
      _startShadowReading();
    } else {
      state = state.copyWith(
        isPauseBetweenPlays: false,
        isPauseBetweenSentences: false,
        isCountdownPaused: false,
        isCountdownFastForward: false,
      );
      await _startSentence();
    }
  }

  /// 重置到第一句并重新乱序播放（"再来一遍"）
  Future<void> resetToStart() async {
    _engine.cleanup();

    // 重新按音频分组乱序
    final grouped = <String, List<BookmarkSentence>>{};
    for (final s in _sentences) {
      (grouped[s.audioItemId] ??= []).add(s);
    }
    final audioIds = grouped.keys.toList()..shuffle();
    _sentences = [];
    for (final audioId in audioIds) {
      _sentences.addAll(grouped[audioId]!);
    }

    state = ReviewDifficultPracticeState(
      currentSentenceIndex: 0,
      totalSentences: _sentences.length,
    );
    await startPlaying();
  }

  /// 释放资源
  void disposePlayer() {
    _engine.cleanup();
    _sentences = [];
    state = const ReviewDifficultPracticeState();
  }

  // ========== 内部方法 ==========

  /// 确保当前句子的音频已加载
  ///
  /// 如果当前 AudioEngine 加载的不是同一音频，则切换。
  /// 返回 false 表示加载失败（应跳过该句）。
  Future<bool> _ensureAudioLoaded(BookmarkSentence bookmarkSentence) async {
    final engineState = ref.read(audioEngineProvider);
    if (engineState.currentAudioId == bookmarkSentence.audioItemId) {
      return true;
    }

    try {
      final row = await _getAudioItemById(bookmarkSentence.audioItemId);
      if (row == null) return false;

      final audioItem = AudioItem(
        id: row.id,
        name: row.name,
        audioPath: row.audioPath,
        transcriptPath: row.transcriptPath,
        addedDate: row.addedDate,
        totalDuration: row.totalDuration,
        sentenceCount: row.sentenceCount,
        wordCount: row.wordCount,
        isStarred: row.isStarred,
        transcriptSource: TranscriptSource.fromIndex(row.transcriptSource),
        audioSha256: row.audioSha256,
        transcriptLanguage: row.transcriptLanguage,
      );

      final engine = ref.read(audioEngineProvider.notifier);
      await engine.loadAudio(audioItem, 1.0);
      return true;
    } catch (e) {
      debugPrint('收藏复习：加载音频失败: $e');
      return false;
    }
  }

  /// 开始播放当前句子（盲听 N 遍）
  Future<void> _startSentence() async {
    final bookmarkSentence = currentBookmarkSentence;
    if (bookmarkSentence == null) return;

    final sentence = bookmarkSentence.sentence;

    // 跳过零时长句子
    if (sentence.duration <= Duration.zero) {
      await _autoAdvance();
      return;
    }

    // 确保音频已加载（跨音频切换）
    final loaded = await _ensureAudioLoaded(bookmarkSentence);
    if (!loaded) {
      // 音频加载失败，跳过该句
      debugPrint('收藏复习：跳过句子（音频不可用）: ${bookmarkSentence.audioName}');
      await _autoAdvance();
      return;
    }

    final repeatCount = state.settings.blindListenRepeatCount;

    state = state.copyWith(
      isPlaying: true,
      currentPlayCount: 1,
      isPauseBetweenPlays: false,
      isPauseBetweenSentences: false,
    );

    // 盲听循环：1 遍时无遍间停顿，多遍时使用跟读停顿策略
    await _engine.playSentenceLoop(
      sentence: sentence,
      repeatCount: repeatCount,
      pauseCalculator: repeatCount > 1
          ? listenAndRepeatPauseCalculator
          : (_) => Duration.zero,
      onPlayCountChanged: repeatCount > 1
          ? (count) {
              state = state.copyWith(currentPlayCount: count, isPlaying: true);
            }
          : (_) {},
      onPauseStarted: repeatCount > 1
          ? (dur) {
              state = state.copyWith(
                isPauseBetweenPlays: true,
                isPlaying: false,
                isCountdownPaused: false,
                isCountdownFastForward: false,
                pauseDuration: dur,
                pauseRemaining: dur,
              );
            }
          : (_) {},
      onPauseEnded: repeatCount > 1
          ? () {
              state = state.copyWith(isPauseBetweenPlays: false);
            }
          : () {},
      onTick: repeatCount > 1
          ? (remaining) {
              state = state.copyWith(pauseRemaining: remaining);
            }
          : (_) {},
      onAllPlaysCompleted: () async {
        await _autoAdvance();
      },
    );
  }

  /// 开始跟读循环
  void _startShadowReading() {
    final sentence = currentSentence;
    if (sentence == null || sentence.duration <= Duration.zero) return;

    state = state.copyWith(
      isAnnotationMode: true,
      isPlaying: true,
      currentPlayCount: 1,
      isPauseBetweenPlays: false,
      isPauseBetweenSentences: false,
      isTextRevealed: false,
      isCountdownPaused: false,
      isCountdownFastForward: false,
    );

    _engine.playSentenceLoop(
      sentence: sentence,
      repeatCount: state.targetRepeatCount,
      pauseCalculator: listenAndRepeatPauseCalculator,
      onPlayCountChanged: (count) {
        state = state.copyWith(currentPlayCount: count, isPlaying: true);
      },
      onPauseStarted: (dur) {
        state = state.copyWith(
          isPauseBetweenPlays: true,
          isPlaying: false,
          isCountdownPaused: false,
          isCountdownFastForward: false,
          pauseDuration: dur,
          pauseRemaining: dur,
        );
      },
      onPauseEnded: () {
        state = state.copyWith(isPauseBetweenPlays: false);
      },
      onTick: (remaining) {
        state = state.copyWith(pauseRemaining: remaining);
      },
      onAllPlaysCompleted: () async {
        state = state.copyWith(
          isAnnotationMode: false,
          isPlaying: false,
          isPauseBetweenPlays: false,
        );
        await _autoAdvance();
      },
    );
  }

  /// 自动推进到下一句（含句间停顿）
  Future<void> _autoAdvance() async {
    final isLastSentence =
        state.currentSentenceIndex >= state.totalSentences - 1;

    // 使用设置计算句间停顿时长
    final sentence = currentSentence;
    final pauseDur = sentence != null
        ? state.settings.calculateInterSentencePause(sentence.duration)
        : const Duration(seconds: 1);

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
          state = state.copyWith(
            isCompleted: true,
            isPlaying: false,
            isPauseBetweenPlays: false,
            isPauseBetweenSentences: false,
          );
        } else {
          state = state.copyWith(
            currentSentenceIndex: state.currentSentenceIndex + 1,
            currentPlayCount: 1,
            isTextRevealed: false,
            isPauseBetweenPlays: false,
            isPauseBetweenSentences: false,
            isAnnotationMode: false,
          );
          await _startSentence();
        }
      },
    );
  }
}
