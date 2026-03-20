/// Flashcard 状态管理 Provider
///
/// 管理单词卡片复习的完整生命周期：卡片列表、翻转、切换、
/// 倒计时、练习统计记录。
library;

import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart' as ja;
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../database/app_database.dart';
import '../../database/providers.dart';
import '../../models/dict_entry.dart';
import '../../models/flashcard_settings.dart';
import '../../providers/audio_engine/audio_engine_provider.dart';
import '../../services/dictionary_service.dart';
import '../../services/study_time_service.dart';
import '../../services/tts_service.dart';
import '../daily_study_time_provider.dart';
import '../learning_session/countdown_controller.dart';
import '../study_stats_provider.dart';

part 'flashcard_provider.g.dart';

/// 单张卡片数据（含词典释义）
class FlashcardWordItem {
  /// 收藏单词数据
  final SavedWord savedWord;

  /// 词典条目（懒加载）
  final DictEntry? dictEntry;

  /// 词典是否已加载
  final bool dictLoaded;

  const FlashcardWordItem({
    required this.savedWord,
    this.dictEntry,
    this.dictLoaded = false,
  });

  FlashcardWordItem copyWith({
    SavedWord? savedWord,
    DictEntry? dictEntry,
    bool? dictLoaded,
  }) {
    return FlashcardWordItem(
      savedWord: savedWord ?? this.savedWord,
      dictEntry: dictEntry ?? this.dictEntry,
      dictLoaded: dictLoaded ?? this.dictLoaded,
    );
  }
}

/// Flashcard 完整状态
class FlashcardState {
  /// 卡片列表
  final List<FlashcardWordItem> words;

  /// 当前卡片索引
  final int currentIndex;

  /// 是否正在显示背面
  final bool isShowingBack;

  /// 设置
  final FlashcardSettings settings;

  /// 倒计时剩余时间
  final Duration countdownRemaining;

  /// 倒计时总时长
  final Duration countdownTotal;

  /// 是否全部完成
  final bool isCompleted;

  /// 本轮取消收藏数
  final int removedCount;

  /// 当前卡片开始查看时间（用于计算学习时长）
  final DateTime? cardStartTime;

  /// 倒计时是否暂停
  final bool isPaused;

  const FlashcardState({
    this.words = const [],
    this.currentIndex = 0,
    this.isShowingBack = false,
    this.settings = const FlashcardSettings(),
    this.countdownRemaining = Duration.zero,
    this.countdownTotal = Duration.zero,
    this.isCompleted = false,
    this.removedCount = 0,
    this.cardStartTime,
    this.isPaused = false,
  });

  /// 当前卡片
  FlashcardWordItem? get currentWord =>
      words.isNotEmpty && currentIndex < words.length
      ? words[currentIndex]
      : null;

  /// 总卡片数（含已移除的）
  int get totalWordsReviewed => currentIndex + 1;

  FlashcardState copyWith({
    List<FlashcardWordItem>? words,
    int? currentIndex,
    bool? isShowingBack,
    FlashcardSettings? settings,
    Duration? countdownRemaining,
    Duration? countdownTotal,
    bool? isCompleted,
    int? removedCount,
    DateTime? cardStartTime,
    bool clearCardStartTime = false,
    bool? isPaused,
  }) {
    return FlashcardState(
      words: words ?? this.words,
      currentIndex: currentIndex ?? this.currentIndex,
      isShowingBack: isShowingBack ?? this.isShowingBack,
      settings: settings ?? this.settings,
      countdownRemaining: countdownRemaining ?? this.countdownRemaining,
      countdownTotal: countdownTotal ?? this.countdownTotal,
      isCompleted: isCompleted ?? this.isCompleted,
      removedCount: removedCount ?? this.removedCount,
      cardStartTime: clearCardStartTime
          ? null
          : (cardStartTime ?? this.cardStartTime),
      isPaused: isPaused ?? this.isPaused,
    );
  }
}

/// SharedPreferences key
const _settingsKey = 'flashcard_settings';

/// Flashcard 主 Provider
@Riverpod(keepAlive: true)
class FlashcardNotifier extends _$FlashcardNotifier {
  final CountdownController _countdown = CountdownController();

  /// 学习时长存储服务
  late final StudyTimeService _studyTimeService;

  /// 学习计时器
  final Stopwatch _studyStopwatch = Stopwatch();

  /// 输入时间计时器（TTS + 音频播放期间运行）
  final Stopwatch _inputStopwatch = Stopwatch();

  /// 音频播放状态监听（用于输入时间追踪）
  StreamSubscription<ja.PlayerState>? _inputTimePlayerStateSub;

  @override
  FlashcardState build() {
    _studyTimeService = ref.read(studyTimeServiceProvider);
    ref.onDispose(() {
      _countdown.cancel();
      _inputTimePlayerStateSub?.cancel();
      _saveAndRefreshStudyTime();
    });
    return const FlashcardState();
  }

  /// 初始化 Flashcard 会话
  ///
  /// [words] 收藏单词列表快照
  Future<void> initialize(List<SavedWord> words) async {
    _countdown.cancel();

    // 加载设置
    final settings = await _loadSettings();

    // 排序
    final sorted = _sortWords(words, settings.sortMode);

    // 构建卡片列表
    final items = sorted.map((w) => FlashcardWordItem(savedWord: w)).toList();

    state = FlashcardState(
      words: items,
      currentIndex: 0,
      settings: settings,
      cardStartTime: DateTime.now(),
    );

    // 启动学习计时
    _studyStopwatch.reset();
    _studyStopwatch.start();

    // 启动输入时间追踪（例句音频播放）
    _startInputTimeTracking();

    if (items.isNotEmpty) {
      // 预加载词典（当前 + 前后 2 张）
      _preloadDictionaries();
      // 自动 TTS 播放
      _speakCurrentWord();
      // 启动倒计时
      _startCountdown();
    }
  }

  /// 翻转卡片
  void flipCard() {
    if (state.isCompleted || state.words.isEmpty) return;

    final wasShowingBack = state.isShowingBack;
    // 停止当前播放（避免翻转时 TTS/音频重叠）
    _stopAllPlayback();
    state = state.copyWith(isShowingBack: !wasShowingBack);

    if (!wasShowingBack) {
      // 翻到背面：记录练习统计
      // 输入词数由 _BackContent 在 TTS/例句播放完成后计入
      _recordPracticeStats();
    } else {
      // 翻回正面：朗读单词
      _speakCurrentWord();
    }

    // 重启倒计时
    _startCountdown();
  }

  /// 下一张卡片
  void nextCard() {
    if (state.isCompleted || state.words.isEmpty) return;

    _stopAllPlayback();

    if (state.currentIndex >= state.words.length - 1) {
      // 最后一张 → 完成
      _countdown.cancel();
      _saveStudyTime();
      state = state.copyWith(isCompleted: true);
      return;
    }

    _saveStudyTime();
    state = state.copyWith(
      currentIndex: state.currentIndex + 1,
      isShowingBack: false,
      cardStartTime: DateTime.now(),
    );

    _preloadDictionaries();
    _speakCurrentWord();
    _startCountdown();
  }

  /// 上一张卡片
  void previousCard() {
    if (state.currentIndex <= 0) return;

    _stopAllPlayback();
    _countdown.cancel();
    _saveStudyTime();
    state = state.copyWith(
      currentIndex: state.currentIndex - 1,
      isShowingBack: false,
      cardStartTime: DateTime.now(),
    );

    _preloadDictionaries();
    _speakCurrentWord();
    _startCountdown();
  }

  /// 取消收藏当前单词
  Future<void> unsaveCurrentWord() async {
    if (state.words.isEmpty) return;

    _stopAllPlayback();
    final word = state.words[state.currentIndex];
    _countdown.cancel();

    // 从 DAO 中删除
    final dao = ref.read(savedWordDaoProvider);
    await dao.removeWord(word.savedWord.word);

    // 从列表中移除
    final newWords = List<FlashcardWordItem>.from(state.words)
      ..removeAt(state.currentIndex);

    if (newWords.isEmpty) {
      state = state.copyWith(
        words: newWords,
        isCompleted: true,
        removedCount: state.removedCount + 1,
      );
      return;
    }

    final newIndex = state.currentIndex >= newWords.length
        ? newWords.length - 1
        : state.currentIndex;

    state = state.copyWith(
      words: newWords,
      currentIndex: newIndex,
      isShowingBack: false,
      removedCount: state.removedCount + 1,
      cardStartTime: DateTime.now(),
    );

    _preloadDictionaries();
    _speakCurrentWord();
    _startCountdown();
  }

  /// 更新设置
  Future<void> updateSettings(FlashcardSettings newSettings) async {
    _countdown.cancel();

    // 如果排序方式变了，重新排序
    if (newSettings.sortMode != state.settings.sortMode) {
      final savedWords = state.words.map((w) => w.savedWord).toList();
      final sorted = _sortWords(savedWords, newSettings.sortMode);
      final items = sorted.map((w) => FlashcardWordItem(savedWord: w)).toList();

      state = state.copyWith(
        settings: newSettings,
        words: items,
        currentIndex: 0,
        isShowingBack: false,
        cardStartTime: DateTime.now(),
      );

      _preloadDictionaries();
      _speakCurrentWord();
    } else {
      state = state.copyWith(settings: newSettings);
    }

    _startCountdown();

    // 持久化设置
    await _saveSettings(newSettings);
  }

  /// 单词 TTS 播放完成后计入 1 个输入词
  ///
  /// 由 _BackContent widget 在 TTS 朗读结束后调用。
  Future<void> onWordPlayed() => _addInputWords(1);

  /// 例句播放完成后计入输入词数
  ///
  /// 由 _BackContent widget 在例句音频播放结束后调用。
  Future<void> onSentencePlayed(String sentenceText) {
    final wordCount = sentenceText
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .length;
    return _addInputWords(wordCount);
  }

  /// TTS 朗读当前单词
  void speakCurrentWord() {
    _speakCurrentWord();
  }

  /// 暂停（AppLifecycle / 弹窗时调用）
  void pause() {
    _countdown.pause();
    _studyStopwatch.stop();
    state = state.copyWith(isPaused: true);
  }

  /// 恢复
  void resume() {
    if (state.isCompleted) return;
    _studyStopwatch.start();
    state = state.copyWith(isPaused: false);
    _countdown.resume();
  }

  /// 切换暂停/恢复
  void togglePause() {
    if (state.isPaused) {
      resume();
    } else {
      pause();
    }
  }

  /// 重新开始（再来一遍）
  Future<void> reset() async {
    _countdown.cancel();
    // 先保存已累计时间
    await _saveAndRefreshStudyTime();
    final savedWords = state.words.map((w) => w.savedWord).toList();
    await initialize(savedWords);
  }

  /// 释放资源
  Future<void> disposePlayer() async {
    _inputTimePlayerStateSub?.cancel();
    _inputTimePlayerStateSub = null;
    await _saveAndRefreshStudyTime();
    _countdown.cancel();
    _stopAllPlayback();
    state = const FlashcardState();
  }

  // ========== 内部方法 ==========

  /// 启动倒计时
  void _startCountdown() {
    _countdown.cancel();

    if (state.settings.timerMode == FlashcardTimerMode.off) {
      state = state.copyWith(
        countdownRemaining: Duration.zero,
        countdownTotal: Duration.zero,
      );
      return;
    }

    final seconds = _getTimerSeconds();
    final total = Duration(seconds: seconds);
    state = state.copyWith(countdownRemaining: total, countdownTotal: total);

    _countdown
        .start(total, (remaining) {
          state = state.copyWith(countdownRemaining: remaining);
        })
        .then((_) {
          // 倒计时自然结束（非 cancel）时触发
          if (state.countdownRemaining <= Duration.zero) {
            _onCountdownExpired();
          }
        });
  }

  /// 获取当前倒计时秒数
  ///
  /// 背面且开启自动播放例句时，额外追加例句音频时长 + TTS/延迟缓冲，
  /// 避免例句还没播完就被倒计时截断自动跳到下一张。
  int _getTimerSeconds() {
    int baseSeconds;
    switch (state.settings.timerMode) {
      case FlashcardTimerMode.fixed:
        baseSeconds = state.settings.fixedTimerSeconds;
      case FlashcardTimerMode.smart:
        final word = state.currentWord?.savedWord;
        if (word == null) return 8;
        baseSeconds = FlashcardSettings.calculateSmartSeconds(
          wordLength: word.word.length,
          practiceCount: word.practiceCount,
        );
      case FlashcardTimerMode.off:
        return 0;
    }

    // 背面 + 自动播放例句：追加例句音频时长
    if (state.isShowingBack && state.settings.autoPlaySentence) {
      baseSeconds += _getExampleSentenceExtraSeconds();
    }

    return baseSeconds;
  }

  /// 计算例句自动播放所需的额外秒数
  ///
  /// 包含：TTS 朗读单词时长 (~1s) + 600ms 延迟 + 例句音频时长。
  int _getExampleSentenceExtraSeconds() {
    final word = state.currentWord?.savedWord;
    if (word == null || word.sentenceText == null) return 0;

    // 例句音频时长（毫秒）
    int sentenceDurationMs = 0;
    if (word.sentenceStartMs != null && word.sentenceEndMs != null) {
      sentenceDurationMs = word.sentenceEndMs! - word.sentenceStartMs!;
    }

    // TTS 朗读（~1s）+ 延迟 600ms + 例句音频
    final ttsBufferMs = state.settings.autoPlayWord ? 1600 : 600;
    return ((ttsBufferMs + sentenceDurationMs) / 1000).ceil();
  }

  /// 倒计时到期回调
  void _onCountdownExpired() {
    if (state.isShowingBack) {
      // 背面到期 → 自动下一张
      nextCard();
    } else {
      // 正面到期 → 自动翻转到背面
      flipCard();
    }
  }

  /// 停止所有播放（TTS + 音频引擎）
  void _stopAllPlayback() {
    TtsService.instance.stop();
    ref.read(audioEngineProvider.notifier).stop();
  }

  /// 开始监听 AudioEngine playerState，追踪输入时间（例句音频播放）
  void _startInputTimeTracking() {
    _inputTimePlayerStateSub?.cancel();
    final engine = ref.read(audioEngineProvider.notifier);
    _inputTimePlayerStateSub = engine.playerStateStream.listen((playerState) {
      if (playerState.playing) {
        if (!_inputStopwatch.isRunning) _inputStopwatch.start();
      } else {
        _inputStopwatch.stop();
      }
    });
  }

  /// TTS 朗读当前单词（受 autoPlayWord 设置控制）
  ///
  /// TTS 朗读期间计入输入时间。
  Future<void> _speakCurrentWord() async {
    if (!state.settings.autoPlayWord) return;
    final word = state.currentWord?.savedWord.word;
    if (word != null) {
      if (!_inputStopwatch.isRunning) _inputStopwatch.start();
      await TtsService.instance.speak(word);
      _inputStopwatch.stop();
      await _addInputWords(1);
    }
  }

  /// 预加载词典（当前 + 前后各 2 张）
  void _preloadDictionaries() {
    final start = (state.currentIndex - 2).clamp(0, state.words.length - 1);
    final end = (state.currentIndex + 2).clamp(0, state.words.length - 1);

    for (var i = start; i <= end; i++) {
      if (!state.words[i].dictLoaded) {
        _loadDictionary(i);
      }
    }
  }

  /// 加载单个词典条目
  Future<void> _loadDictionary(int index) async {
    if (index < 0 || index >= state.words.length) return;
    if (state.words[index].dictLoaded) return;

    final word = state.words[index].savedWord.word;
    final entry = await DictionaryService.instance.lookup(word);

    // 检查 state 是否仍然有效
    if (index >= state.words.length) return;
    if (state.words[index].savedWord.word != word) return;

    final newWords = List<FlashcardWordItem>.from(state.words);
    newWords[index] = newWords[index].copyWith(
      dictEntry: entry,
      dictLoaded: true,
    );
    state = state.copyWith(words: newWords);
  }

  /// 记录练习统计（翻到背面时）
  Future<void> _recordPracticeStats() async {
    final word = state.currentWord?.savedWord;
    if (word == null) return;

    final now = DateTime.now();
    final cardStart = state.cardStartTime ?? now;
    final studyMs = now.difference(cardStart).inMilliseconds;

    final dao = ref.read(savedWordDaoProvider);
    await dao.updatePracticeStats(word: word.word, studyMs: studyMs);
  }

  /// 保存当前卡片的学习时间（切换卡片时调用）
  void _saveStudyTime() {
    // 学习时长已在 _recordPracticeStats 中记录（翻到背面时）
    // 这里只需重置 cardStartTime
  }

  /// 排序单词列表
  List<SavedWord> _sortWords(List<SavedWord> words, FlashcardSortMode mode) {
    final sorted = List<SavedWord>.from(words);
    switch (mode) {
      case FlashcardSortMode.alphabeticalAsc:
        sorted.sort(
          (a, b) => a.word.toLowerCase().compareTo(b.word.toLowerCase()),
        );
      case FlashcardSortMode.alphabeticalDesc:
        sorted.sort(
          (a, b) => b.word.toLowerCase().compareTo(a.word.toLowerCase()),
        );
      case FlashcardSortMode.timeAsc:
        sorted.sort((a, b) => a.createdAt.compareTo(b.createdAt));
      case FlashcardSortMode.timeDesc:
        sorted.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      case FlashcardSortMode.random:
        sorted.shuffle();
      case FlashcardSortMode.smart:
        sorted.sort((a, b) {
          final scoreA = FlashcardSettings.calculateSmartScore(
            practiceCount: a.practiceCount,
            viewedBack: a.viewedBack,
            lastPracticedAt: a.lastPracticedAt,
          );
          final scoreB = FlashcardSettings.calculateSmartScore(
            practiceCount: b.practiceCount,
            viewedBack: b.viewedBack,
            lastPracticedAt: b.lastPracticedAt,
          );
          return scoreB.compareTo(scoreA); // 分数高的在前
        });
    }
    return sorted;
  }

  /// 加载持久化设置
  Future<FlashcardSettings> _loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = prefs.getString(_settingsKey);
      if (jsonStr != null) {
        return FlashcardSettings.fromJson(
          json.decode(jsonStr) as Map<String, dynamic>,
        );
      }
    } catch (e) {
      debugPrint('Flashcard: 加载设置失败: $e');
    }
    return const FlashcardSettings();
  }

  /// 停止计时并保存已记录的学习时长 + 输入时间，刷新统计 UI
  Future<void> _saveAndRefreshStudyTime() async {
    // 保存输入时间
    _inputStopwatch.stop();
    final inputSecs = _inputStopwatch.elapsed.inSeconds;
    _inputStopwatch.reset();
    if (inputSecs > 0) {
      await _studyTimeService.addInputTime(inputSecs);
    }

    if (!_studyStopwatch.isRunning &&
        _studyStopwatch.elapsed == Duration.zero) {
      if (inputSecs > 0) {
        ref.read(dailyStudyTimeProvider.notifier).refresh();
        ref.read(studyStatsNotifierProvider.notifier).refresh();
      }
      return;
    }
    _studyStopwatch.stop();
    final seconds = _studyStopwatch.elapsed.inSeconds;
    _studyStopwatch.reset();
    if (seconds > 0) {
      await _studyTimeService.addStudyTime(seconds);
    }
    ref.read(dailyStudyTimeProvider.notifier).refresh();
    ref.read(studyStatsNotifierProvider.notifier).refresh();
  }

  /// 累加输入词数并刷新统计 UI
  Future<void> _addInputWords(int count) async {
    if (count > 0) {
      await _studyTimeService.addInputWords(count);
      ref.read(studyStatsNotifierProvider.notifier).refresh();
    }
  }

  /// 持久化设置
  Future<void> _saveSettings(FlashcardSettings settings) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_settingsKey, json.encode(settings.toJson()));
    } catch (e) {
      debugPrint('Flashcard: 保存设置失败: $e');
    }
  }
}
