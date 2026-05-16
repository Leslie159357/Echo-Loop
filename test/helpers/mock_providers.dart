/// Mock Provider 集合
///
/// 用 Riverpod overrideWith 模式创建测试用 Notifier，
/// 避免真实 I/O（SharedPreferences、文件系统、just_audio）。
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart' as ja;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:echo_loop/analytics/analytics_channel.dart';
import 'package:echo_loop/analytics/analytics_providers.dart';
import 'package:echo_loop/analytics/analytics_service.dart';
import 'package:echo_loop/analytics/consent_manager.dart';
import 'package:echo_loop/models/audio_item.dart';
import 'package:echo_loop/models/collection.dart';
import 'package:echo_loop/models/tag.dart';
import 'package:echo_loop/models/difficult_practice_settings.dart';
import 'package:echo_loop/models/intensive_listen_settings.dart';
import 'package:echo_loop/models/playback_settings.dart';
import 'package:echo_loop/models/audio_engine_state.dart';
import 'package:echo_loop/providers/settings_provider.dart';
import 'package:echo_loop/providers/audio_library_provider.dart';
import 'package:echo_loop/providers/collection_provider.dart';
import 'package:echo_loop/providers/tag_provider.dart';
import 'package:echo_loop/providers/listening_practice/listening_practice_provider.dart';
import 'package:echo_loop/providers/audio_engine/audio_engine_provider.dart';
import 'package:echo_loop/providers/learning_progress_provider.dart';
import 'package:echo_loop/providers/learning_settings_provider.dart';
import 'package:echo_loop/providers/learning_session/learning_session_provider.dart';
import 'package:echo_loop/providers/learning_session/blind_listen_player_provider.dart';
import 'package:echo_loop/providers/learning_session/intensive_listen_player_provider.dart';
import 'package:echo_loop/providers/learning_session/retell_player_provider.dart';
import 'package:echo_loop/models/retell_settings.dart';
import 'package:echo_loop/providers/learning_session/review_difficult_practice_provider.dart';
import 'package:echo_loop/providers/repeat_flow/repeat_flow_engine.dart';
import 'package:echo_loop/providers/daily_study_time_provider.dart';
import 'package:echo_loop/providers/speech/speech_recording_controller.dart';
import 'package:echo_loop/providers/retell_recording_controller_provider.dart';
import 'package:echo_loop/models/speech_practice_models.dart';
import 'package:echo_loop/providers/transcription_task_provider.dart';
import 'package:echo_loop/services/transcription_api_client.dart';
import 'package:echo_loop/database/enums.dart';
import 'package:echo_loop/database/providers.dart';
import 'package:echo_loop/models/app_update_info.dart';
import 'package:echo_loop/models/learning_progress.dart';
import 'package:echo_loop/models/study_stage.dart';
import 'package:echo_loop/services/study_event_recorder.dart';
import 'package:echo_loop/services/study_time_service.dart';
import 'package:echo_loop/models/blind_listen_settings.dart';
import 'package:echo_loop/models/sentence.dart';
import 'package:echo_loop/providers/app_update_provider.dart';
import 'package:echo_loop/providers/dictionary_provider.dart';
import 'package:echo_loop/providers/offline_asr_settings_provider.dart';
import 'package:echo_loop/services/asr/offline_asr_engine.dart';

// ========== 测试数据工厂 ==========

/// 创建测试用 AudioItem
AudioItem createTestAudioItem({
  String id = 'test-audio-1',
  String name = 'Test Audio',
  String audioPath = 'audios/test.mp3',
  String? transcriptPath = 'transcripts/test.srt',
  DateTime? addedDate,
  int totalDuration = 120,
}) {
  return AudioItem(
    id: id,
    name: name,
    audioPath: audioPath,
    transcriptPath: transcriptPath,
    addedDate: addedDate ?? DateTime(2026, 1, 1),
    totalDuration: totalDuration,
  );
}

/// 创建测试用 Sentence 列表
List<Sentence> createTestSentences({int count = 5}) {
  return List.generate(count, (i) {
    return Sentence(
      index: i,
      text: 'Test sentence number ${i + 1}.',
      startTime: Duration(seconds: i * 5),
      endTime: Duration(seconds: (i + 1) * 5),
    );
  });
}

/// 创建测试用 Collection
Collection createTestCollection({
  String id = 'test-collection-1',
  String name = 'Test Collection',
  bool isPinned = false,
  DateTime? createdDate,
}) {
  return Collection(
    id: id,
    name: name,
    createdDate: createdDate ?? DateTime(2026, 1, 1),
    isPinned: isPinned,
  );
}

/// 创建测试用 Tag
Tag createTestTag({
  String id = 'test-tag-1',
  String name = 'Test Tag',
  int colorValue = 0xFFF44336,
  DateTime? createdDate,
}) {
  return Tag(
    id: id,
    name: name,
    colorValue: colorValue,
    createdDate: createdDate ?? DateTime(2026, 1, 1),
  );
}

// ========== 测试用分析服务 ==========

/// 测试用 AnalyticsChannel — 不做任何操作
class NoOpAnalyticsChannel implements AnalyticsChannel {
  @override
  String get name => 'NoOp';

  @override
  Future<void> initialize() async {}

  @override
  Future<void> logEvent(String name, Map<String, Object>? parameters) async {}

  @override
  Future<void> setUserId(String? id) async {}

  @override
  Future<void> setUserProperty(String name, String? value) async {}

  @override
  Future<void> registerSuperProperties(Map<String, Object> properties) async {}
}

/// 创建测试用 AnalyticsService（no-op，不会访问网络或持久化）
///
/// 调用前必须确保已执行 SharedPreferences.setMockInitialValues({})
Future<AnalyticsService> createTestAnalyticsService() async {
  final prefs = await SharedPreferences.getInstance();
  return AnalyticsService(
    channel: NoOpAnalyticsChannel(),
    consent: ConsentManager(prefs),
  );
}

/// 同步创建测试用 AnalyticsService（使用 no-op consent）
AnalyticsService createTestAnalyticsServiceSync() {
  return AnalyticsService(
    channel: NoOpAnalyticsChannel(),
    consent: _NoOpConsentManager(),
  );
}

/// 简单的同意管理器替身（始终返回 true）
class _NoOpConsentManager extends ConsentManager {
  _NoOpConsentManager() : super(_DummySharedPreferences());

  @override
  bool get hasConsented => true;
}

/// SharedPreferences 占位（不会被实际使用）
class _DummySharedPreferences implements SharedPreferences {
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

/// 返回 analyticsServiceProvider 的 override（在 ProviderContainer overrides 中使用）
Override analyticsOverride() {
  return analyticsServiceProvider.overrideWithValue(
    createTestAnalyticsServiceSync(),
  );
}

/// 返回学习设置 Provider 系列的 override 列表（用于测试默认/自定义初值）。
///
/// 测试默认 autoSkipRetell=false（与生产默认一致：默认不自动跳过）；
/// 显式开启用 `autoSkipRetell: true`。
///
/// [prefs] 可选 SharedPreferences 实例：如果传入，会同时 override
/// `sharedPreferencesProvider`。
List<Override> learningSettingsOverrides({
  bool autoSkipRetell = false,
  SharedPreferences? prefs,
}) {
  return [
    initialLearningSettingsProvider.overrideWithValue(
      LearningSettings(autoSkipRetell: autoSkipRetell),
    ),
    if (prefs != null) sharedPreferencesProvider.overrideWithValue(prefs),
  ];
}

/// 返回 dictionaryProvider 的 override，状态为已下载
///
/// 用于测试需要查询词典的 Widget（如 WordDictionarySheet）。
Override dictionaryOverride({
  DictionaryStatus status = DictionaryStatus.downloaded,
  String nativeLanguage = 'zh',
}) {
  return dictionaryProvider.overrideWith(
    () => TestDictionary(
      DictionaryState(
        status: status,
        nativeLanguage: nativeLanguage,
      ),
    ),
  );
}

/// 测试用 Dictionary — 不执行下载/打开数据库
class TestDictionary extends Dictionary {
  final DictionaryState _initialState;

  TestDictionary([
    this._initialState = const DictionaryState(
      status: DictionaryStatus.notDownloaded,
      nativeLanguage: 'zh',
    ),
  ]);

  @override
  DictionaryState build() => _initialState;

  @override
  Future<void> retryDownload() async {
    // 测试中不执行下载
  }
}

// ========== 测试 Notifier ==========

/// 测试用 AppUpdate — 不访问网络和 SharedPreferences
class TestAppUpdate extends AppUpdate {
  @override
  AppUpdateState build() => const AppUpdateInitial();

  @override
  Future<AppUpdateResult> manualCheck() async {
    return const AppUpdateResult(type: AppUpdateType.none);
  }

  @override
  Future<void> dismiss() async {
    state = const AppUpdateDismissed();
  }
}

/// 测试用 AppSettings — 不访问 SharedPreferences
class TestAppSettings extends AppSettings {
  final AppSettingsState _initialState;

  TestAppSettings([this._initialState = const AppSettingsState()]);

  @override
  AppSettingsState build() => _initialState;

  @override
  Future<void> setThemeMode(ThemeMode mode) async {
    state = state.copyWith(themeMode: mode);
  }

  @override
  Future<void> setLocale(Locale? locale) async {
    state = locale == null
        ? state.copyWith(clearLocale: true)
        : state.copyWith(locale: locale);
  }

  @override
  Future<void> setTimeMachineDateTime(DateTime? value) async {
    state = state.copyWith(
      timeMachineDateTime: value,
      clearTimeMachineDateTime: value == null,
    );
  }
}

/// 测试用 AudioLibrary — 不访问文件系统
class TestAudioLibrary extends AudioLibrary {
  final AudioLibraryState _initialState;

  TestAudioLibrary([this._initialState = const AudioLibraryState()]);

  @override
  AudioLibraryState build() => _initialState;

  @override
  Future<void> loadLibrary() async {
    // 测试中不做任何 I/O
  }

  /// 直接设置音频列表（测试用）
  void setItems(List<AudioItem> items) {
    state = state.copyWith(audioItems: items);
  }

  @override
  Future<void> addAudioItem(AudioItem item) async {
    state = state.copyWith(audioItems: [...state.audioItems, item]);
  }

  @override
  Future<void> removeAudioItem(String id) async {
    state = state.copyWith(
      audioItems: state.audioItems.where((item) => item.id != id).toList(),
    );
  }

  @override
  Future<void> updateAudioItem(AudioItem updatedItem) async {
    final items = [...state.audioItems];
    final index = items.indexWhere((item) => item.id == updatedItem.id);
    if (index != -1) {
      items[index] = updatedItem;
      state = state.copyWith(audioItems: items);
    }
  }

  @override
  Future<void> togglePin(String id) async {
    final items = [...state.audioItems];
    final index = items.indexWhere((item) => item.id == id);
    if (index != -1) {
      items[index] = items[index].copyWith(isPinned: !items[index].isPinned);
      state = state.copyWith(audioItems: items);
    }
  }
}

/// 测试用 CollectionList — 不访问 StorageService
class TestCollectionList extends CollectionList {
  final CollectionState _initialState;

  TestCollectionList([this._initialState = const CollectionState()]);

  @override
  CollectionState build() => _initialState;

  @override
  Future<void> loadCollections() async {
    // 测试中不做任何 I/O
  }

  @override
  Future<void> createCollection(String name) async {
    final collection = Collection(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: name,
      createdDate: DateTime.now(),
    );
    state = state.copyWith(
      rawCollections: [...state.rawCollections, collection],
    );
  }

  @override
  Future<void> deleteCollection(String id) async {
    state = state.copyWith(
      rawCollections: state.rawCollections.where((c) => c.id != id).toList(),
    );
  }

  @override
  Future<void> renameCollection(String id, String newName) async {
    final collections = [...state.rawCollections];
    final index = collections.indexWhere((c) => c.id == id);
    if (index != -1) {
      collections[index] = collections[index].copyWith(name: newName);
      state = state.copyWith(rawCollections: collections);
    }
  }

  @override
  Future<void> togglePin(String id) async {
    final collections = [...state.rawCollections];
    final index = collections.indexWhere((c) => c.id == id);
    if (index != -1) {
      collections[index] = collections[index].copyWith(
        isPinned: !collections[index].isPinned,
      );
      state = state.copyWith(rawCollections: collections);
    }
  }

  @override
  void setSortType(CollectionSortType type) {
    state = state.copyWith(sortType: type);
  }
}

/// 测试用 TagList — 不访问数据库
class TestTagList extends TagList {
  final TagState _initialState;

  TestTagList([this._initialState = const TagState()]);

  @override
  TagState build() => _initialState;

  @override
  Future<void> loadTags() async {
    // 测试中不做任何 I/O
  }

  @override
  Future<void> createTag(String name, int colorValue) async {
    final tag = Tag(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: name,
      colorValue: colorValue,
      createdDate: DateTime.now(),
    );
    state = state.copyWith(tags: [...state.tags, tag]);
  }

  @override
  Future<void> deleteTag(String id) async {
    final newMap = Map<String, List<String>>.from(state.audioIdsMap)
      ..remove(id);
    state = state.copyWith(
      tags: state.tags.where((t) => t.id != id).toList(),
      audioIdsMap: newMap,
    );
  }

  @override
  Future<void> renameTag(String id, String newName) async {
    final tags = [...state.tags];
    final index = tags.indexWhere((t) => t.id == id);
    if (index != -1) {
      tags[index] = tags[index].copyWith(name: newName);
      state = state.copyWith(tags: tags);
    }
  }

  @override
  Future<void> updateTagColor(String id, int colorValue) async {
    final tags = [...state.tags];
    final index = tags.indexWhere((t) => t.id == id);
    if (index != -1) {
      tags[index] = tags[index].copyWith(colorValue: colorValue);
      state = state.copyWith(tags: tags);
    }
  }

  @override
  Future<void> addAudioToTag(String tagId, String audioId) async {
    final newMap = Map<String, List<String>>.from(state.audioIdsMap);
    final ids = List<String>.from(newMap[tagId] ?? []);
    if (!ids.contains(audioId)) {
      ids.add(audioId);
      newMap[tagId] = ids;
      state = state.copyWith(audioIdsMap: newMap);
    }
  }

  @override
  Future<void> removeAudioFromTag(String tagId, String audioId) async {
    final newMap = Map<String, List<String>>.from(state.audioIdsMap);
    final ids = List<String>.from(newMap[tagId] ?? []);
    ids.remove(audioId);
    newMap[tagId] = ids;
    state = state.copyWith(audioIdsMap: newMap);
  }

  @override
  Future<void> removeAudioFromAllTags(String audioId) async {
    final newMap = Map<String, List<String>>.from(state.audioIdsMap);
    for (final key in newMap.keys) {
      newMap[key] = List<String>.from(newMap[key]!)..remove(audioId);
    }
    state = state.copyWith(audioIdsMap: newMap);
  }

  @override
  Future<void> updateAudioTagMembership(
    String audioId,
    Set<String> targetTagIds,
  ) async {
    final currentTags = state.audioToTagsMap[audioId]?.toSet() ?? <String>{};
    final toAdd = targetTagIds.difference(currentTags);
    final toRemove = currentTags.difference(targetTagIds);

    for (final tagId in toAdd) {
      await addAudioToTag(tagId, audioId);
    }
    for (final tagId in toRemove) {
      await removeAudioFromTag(tagId, audioId);
    }
  }
}

/// 测试用 ListeningPractice — 不访问音频引擎
class TestListeningPractice extends ListeningPractice {
  final ListeningPracticeState _initialState;

  TestListeningPractice([this._initialState = const ListeningPracticeState()]);

  @override
  ListeningPracticeState build() => _initialState;

  @override
  Future<void> loadAudio(
    AudioItem audioItem, {
    bool forceTranscriptReload = false,
  }) async {
    // 测试中不做任何 I/O
  }

  @override
  Future<void> play() async {}

  @override
  Future<void> pause() async {}

  @override
  Future<void> stop() async {}

  @override
  Future<void> seek(Duration position) async {}

  @override
  Future<void> seekAbsolute(Duration absolutePosition) async {}

  @override
  Future<void> selectFullSentence(int index, {bool autoPlay = true}) async {
    state = state.copyWith(currentFullIndex: index);
  }

  @override
  Future<void> selectBookmarkedSentence(
    int index, {
    bool autoPlay = true,
  }) async {
    state = state.copyWith(currentBookmarkIndex: index);
  }

  @override
  Future<void> nextSentence() async {}

  @override
  Future<void> previousSentence() async {}

  @override
  Future<void> replayCurrentSentence() async {}

  @override
  Future<void> toggleBookmark(int index) async {
    final bookmarks = Set<int>.from(state.bookmarkedIndices);
    if (bookmarks.contains(index)) {
      bookmarks.remove(index);
    } else {
      bookmarks.add(index);
    }
    state = state.copyWith(bookmarkedIndices: bookmarks);
  }

  @override
  Future<void> updateSettings(PlaybackSettings newSettings) async {
    state = state.copyWith(settings: newSettings);
  }

  @override
  void setAutoScroll(bool enabled) {
    state = state.copyWith(autoScrollEnabled: enabled);
  }

  @override
  Future<void> setPlaylistMode(PlaylistMode mode) async {
    state = state.copyWith(playlistMode: mode);
  }

  @override
  Future<void> saveCurrentPlaybackState() async {}

  @override
  void suspendListeners() {
    // 测试中不做任何操作
  }

  @override
  void resumeListeners() {
    // 测试中不做任何操作
  }

  @override
  Future<void> syncBookmarks() async {
    // 测试中不做任何操作
  }
}

/// 创建测试用 LearningProgress
LearningProgress createTestLearningProgress({
  String audioItemId = 'test-audio-1',
  LearningStage currentStage = LearningStage.firstLearn,
  SubStageType currentSubStage = SubStageType.blindListen,
  DifficultyLevel difficulty = DifficultyLevel.medium,
  DateTime? firstLearnCompletedAt,
  DateTime? lastStageCompletedAt,
  DateTime? currentStageStartedAt,
  int totalStudyDurationMs = 0,
  int blindListenPassCount = 0,
  DateTime? newLearningBreakpointSavedAt,
  DateTime? freePlayBreakpointSavedAt,
  DateTime? updatedAt,
}) {
  return LearningProgress(
    audioItemId: audioItemId,
    currentStage: currentStage,
    currentSubStage: currentSubStage,
    difficulty: difficulty,
    firstLearnCompletedAt: firstLearnCompletedAt,
    lastStageCompletedAt: lastStageCompletedAt,
    currentStageStartedAt: currentStageStartedAt,
    totalStudyDurationMs: totalStudyDurationMs,
    blindListenPassCount: blindListenPassCount,
    newLearningBreakpointSavedAt: newLearningBreakpointSavedAt,
    freePlayBreakpointSavedAt: freePlayBreakpointSavedAt,
    updatedAt: updatedAt ?? DateTime(2026, 1, 1),
  );
}

/// 测试用 LearningProgressNotifier — 不访问数据库
class TestLearningProgressNotifier extends LearningProgressNotifier {
  final LearningProgressState _initialState;

  TestLearningProgressNotifier([
    this._initialState = const LearningProgressState(),
  ]);

  @override
  LearningProgressState build() => _initialState;

  @override
  Future<void> loadAll() async {
    // 测试中不做任何 I/O
  }

  @override
  Future<LearningProgress> ensureProgress(String audioItemId) async {
    final existing = state.progressMap[audioItemId];
    if (existing != null) return existing;

    final progress = LearningProgress(
      audioItemId: audioItemId,
      updatedAt: DateTime.now(),
    );
    final newMap = Map<String, LearningProgress>.from(state.progressMap);
    newMap[audioItemId] = progress;
    state = state.copyWith(progressMap: newMap);
    return progress;
  }

  @override
  Future<void> completeCurrentSubStage(String audioItemId) async {
    // 测试中的简化实现
  }

  @override
  Future<LearningProgress?> getLatestByAudioId(String audioItemId) async {
    return state.progressMap[audioItemId];
  }

  @override
  Future<LearningProgress> getLatestOrEnsureProgress(String audioItemId) async {
    final existing = state.progressMap[audioItemId];
    if (existing != null) return existing;
    return ensureProgress(audioItemId);
  }

  @override
  Future<void> setDifficulty(
    String audioItemId,
    DifficultyLevel difficulty,
  ) async {
    // 测试中的简化实现
  }

  @override
  Future<void> incrementBlindListenPassCount(String audioItemId) async {
    final progress = state.progressMap[audioItemId];
    if (progress == null) return;

    final newMap = Map<String, LearningProgress>.from(state.progressMap);
    newMap[audioItemId] = progress.copyWith(
      blindListenPassCount: progress.blindListenPassCount + 1,
    );
    state = state.copyWith(progressMap: newMap);
  }

  @override
  Future<void> deleteProgress(String audioItemId) async {
    final newMap = Map<String, LearningProgress>.from(state.progressMap);
    newMap.remove(audioItemId);
    state = state.copyWith(progressMap: newMap);
  }

  @override
  Future<void> pauseProgress(String audioItemId) async {
    final progress = state.progressMap[audioItemId];
    if (progress == null) return;
    final newMap = Map<String, LearningProgress>.from(state.progressMap);
    newMap[audioItemId] = progress.copyWith(isPaused: true);
    state = state.copyWith(progressMap: newMap);
  }

  @override
  Future<void> resumeProgress(String audioItemId) async {
    final progress = state.progressMap[audioItemId];
    if (progress == null) return;
    final newMap = Map<String, LearningProgress>.from(state.progressMap);
    newMap[audioItemId] = progress.copyWith(isPaused: false);
    state = state.copyWith(progressMap: newMap);
  }

  @override
  Future<void> saveBlindListenParagraphIndex(
    String audioItemId,
    int? paragraphIndex, {
    required bool isFreePlay,
  }) async {
    // 测试中不做持久化
  }

  @override
  Future<void> saveIntensiveListenSentenceIndex(
    String audioItemId,
    int? sentenceIndex, {
    required bool isFreePlay,
  }) async {
    // 测试中不做持久化
  }

  @override
  Future<void> saveShadowingSentenceIndex(
    String audioItemId,
    int? sentenceIndex, {
    required bool isFreePlay,
  }) async {
    // 测试中不做持久化
  }

  @override
  Future<void> saveDifficultPracticeSentenceIndex(
    String audioItemId,
    int? sentenceIndex, {
    required bool isFreePlay,
  }) async {
    // 测试中不做持久化
  }

  @override
  Future<void> saveRetellParagraphIndex(
    String audioItemId,
    int? paragraphIndex, {
    required bool isFreePlay,
  }) async {
    // 测试中不做持久化
  }
}

/// 测试用 LearningSession — 不依赖音频引擎
class TestLearningSession extends LearningSession {
  final LearningSessionState _initialState;

  TestLearningSession([this._initialState = const LearningSessionState()]);

  @override
  LearningSessionState build() => _initialState;

  @override
  Future<void> enterBlindListenMode(
    String audioItemId, {
    bool isFreePlay = false,
    required List<List<Sentence>> paragraphs,
    BlindListenSettings? settings,
  }) async {
    state = state.copyWith(
      learningMode: LearningMode.blindListen,
      audioItemId: audioItemId,
      isFreePlay: isFreePlay,
    );
  }

  @override
  Future<void> enterIntensiveListenMode(
    String audioItemId,
    List<Sentence> sentences, {
    bool isFreePlay = false,
  }) async {
    state = state.copyWith(
      learningMode: LearningMode.intensiveListen,
      audioItemId: audioItemId,
      isFreePlay: isFreePlay,
    );
  }

  @override
  Future<void> replayBlindListen() async {
    state = state.copyWith(blindListenCompleted: false);
  }

  @override
  Future<void> enterListenAndRepeatMode(
    String audioItemId,
    List<Sentence> sentences, {
    bool isFreePlay = false,
  }) async {
    state = state.copyWith(
      learningMode: LearningMode.listenAndRepeat,
      audioItemId: audioItemId,
      isFreePlay: isFreePlay,
    );
  }

  @override
  Future<void> exitLearningMode() async {
    state = const LearningSessionState();
  }

  @override
  void addOutputWords(int count) {
    // 测试中不访问 StudyStatsNotifier
  }
}

/// 测试用 BlindListenPlayer — 不依赖音频引擎
class TestBlindListenPlayer extends BlindListenPlayer {
  final BlindListenPlayerState _initialState;

  TestBlindListenPlayer([this._initialState = const BlindListenPlayerState()]);

  @override
  BlindListenPlayerState build() => _initialState;

  @override
  Future<void> startPlaying() async {
    state = state.copyWith(isPlaying: true);
  }

  @override
  Future<void> pause() async {
    state = state.copyWith(isPlaying: false);
  }

  @override
  Future<void> resume() async {
    state = state.copyWith(isPlaying: true);
  }

  @override
  Future<void> restart() async {
    state = const BlindListenPlayerState();
    state = state.copyWith(isPlaying: true);
  }

  @override
  void disposePlayer() {
    state = const BlindListenPlayerState();
  }
}

/// 测试用 IntensiveListenPlayer — 不依赖音频引擎
class TestIntensiveListenPlayer extends IntensiveListenPlayer {
  final IntensiveListenState _initialState;
  final List<Sentence> _testSentences;

  TestIntensiveListenPlayer([
    this._initialState = const IntensiveListenState(),
    this._testSentences = const [],
  ]);

  @override
  IntensiveListenState build() => _initialState;

  @override
  Sentence? get currentSentence =>
      _testSentences.isNotEmpty &&
          state.currentSentenceIndex < _testSentences.length
      ? _testSentences[state.currentSentenceIndex]
      : null;

  @override
  List<Sentence> get sentences => List.unmodifiable(_testSentences);

  @override
  int get currentIndex => state.currentSentenceIndex;

  @override
  Future<void> initialize(
    List<Sentence> sentences, {
    int startIndex = 0,
  }) async {
    state = IntensiveListenState(
      currentSentenceIndex: startIndex,
      totalSentences: sentences.length,
    );
  }

  @override
  void updateSettings(IntensiveListenSettings newSettings) {
    state = state.copyWith(settings: newSettings);
  }

  @override
  void enterWaitingForUserInBlindMode() {
    state = state.copyWith(
      isPlaying: false,
      isPauseBetweenPlays: false,
      isPauseBetweenSentences: false,
    );
  }

  @override
  void onAnnotationUserInteraction() {
    state = state.copyWith(isPlaying: false);
  }

  @override
  Future<void> startPlaying() async {
    state = state.copyWith(isPlaying: true);
  }

  @override
  Future<void> pause() async {
    state = state.copyWith(isPlaying: false);
  }

  @override
  Future<void> resume() async {
    state = state.copyWith(isPlaying: true);
  }

  @override
  Future<void> goToNext() async {
    if (state.currentSentenceIndex < state.totalSentences - 1) {
      state = state.copyWith(
        currentSentenceIndex: state.currentSentenceIndex + 1,
        currentPlayCount: 1,
        isAnnotationMode: false,
        isAnnotationReplay: false,
        isTextRevealed: false,
        isCurrentSentenceAutoMarked: false,
      );
    }
  }

  @override
  Future<void> goToPrevious() async {
    if (state.currentSentenceIndex > 0) {
      state = state.copyWith(
        currentSentenceIndex: state.currentSentenceIndex - 1,
        currentPlayCount: 1,
        isAnnotationMode: false,
        isAnnotationReplay: false,
        isTextRevealed: false,
        isCurrentSentenceAutoMarked: false,
      );
    }
  }

  @override
  void enterAnnotationMode() {
    if (state.isAnnotationMode) return;
    final newDifficult = Set<int>.from(state.difficultSentences);
    final wasAlreadyDifficult = newDifficult.contains(
      state.currentSentenceIndex,
    );
    newDifficult.add(state.currentSentenceIndex);
    state = state.copyWith(
      isAnnotationMode: true,
      isPlaying: false,
      isPauseBetweenPlays: false,
      isPauseBetweenSentences: false,
      pauseRemaining: Duration.zero,
      pauseDuration: Duration.zero,
      difficultSentences: newDifficult,
      isCurrentSentenceAutoMarked: !wasAlreadyDifficult,
    );
  }

  @override
  Future<void> exitAnnotationMode() async {
    state = state.copyWith(
      isAnnotationMode: true,
      isAnnotationReplay: true,
      isPlaying: true,
      annotationReplayRemaining: const Duration(seconds: 3),
      annotationReplayDuration: const Duration(seconds: 3),
      isCurrentSentenceAutoMarked: false,
    );
  }

  @override
  Future<void> replayInAnnotationMode() async {
    if (!state.isAnnotationMode) return;
    // 测试中模拟重播：设置 isPlaying 然后立即停止
    state = state.copyWith(isPlaying: true);
  }

  @override
  Future<void> replayDuringCountdown() async {
    if (state.isAnnotationMode) {
      state = state.copyWith(
        isPlaying: true,
        isPauseBetweenPlays: false,
        isPauseBetweenSentences: false,
        isAnnotationReplay: true,
        annotationReplayRemaining: const Duration(seconds: 3),
        annotationReplayDuration: const Duration(seconds: 3),
      );
      return;
    }

    state = state.copyWith(
      isPlaying: true,
      isPauseBetweenPlays: false,
      isPauseBetweenSentences: false,
      annotationReplayRemaining: Duration.zero,
      annotationReplayDuration: Duration.zero,
    );
  }

  @override
  void toggleDifficultSentence() {
    final idx = state.currentSentenceIndex;
    final newSet = Set<int>.from(state.difficultSentences);
    if (newSet.contains(idx)) {
      newSet.remove(idx);
    } else {
      newSet.add(idx);
    }
    state = state.copyWith(
      difficultSentences: newSet,
      isCurrentSentenceAutoMarked: false,
    );
  }

  @override
  void setTextRevealed(bool revealed) {
    state = state.copyWith(isTextRevealed: revealed);
  }

  @override
  void disposePlayer() {
    state = const IntensiveListenState();
  }

  @override
  void stopPlayback() {
    state = state.copyWith(
      isPlaying: false,
      isPauseBetweenPlays: false,
      isPauseBetweenSentences: false,
      isAnnotationReplay: false,
      annotationReplayRemaining: Duration.zero,
      annotationReplayDuration: Duration.zero,
    );
  }
}

/// 测试用 ReviewDifficultPractice — 不依赖音频引擎
class TestReviewDifficultPractice extends ReviewDifficultPractice {
  final ReviewDifficultPracticeState _initialState;
  List<Sentence> _testSentences;
  RepeatFlowEngine? _testRepeatEngine;

  TestReviewDifficultPractice([
    this._initialState = const ReviewDifficultPracticeState(),
    this._testSentences = const [],
  ]);

  @override
  ReviewDifficultPracticeState build() => _initialState;

  @override
  Sentence? get currentSentence =>
      _testSentences.isNotEmpty &&
          state.currentSentenceIndex < _testSentences.length
      ? _testSentences[state.currentSentenceIndex]
      : null;

  @override
  List<Sentence> get sentences => List.unmodifiable(_testSentences);

  @override
  RepeatFlowEngine? get repeatEngine {
    if (!state.isAnnotationMode) return null;
    final sentence = currentSentence;
    if (sentence == null) return null;

    _testRepeatEngine ??= RepeatFlowEngine(
      onStateChanged: (_) {},
      callbacks: RepeatFlowCallbacks(
        pauseAudio: () {},
        playSentence: (_, _) async {},
        startRecording:
            ({
              required String promptId,
              required String referenceText,
              required Duration maxDuration,
              Duration? referenceDuration,
            }) {},
        cancelRecording: () async {},
        stopAndEvaluate: ({required String referenceText}) async {},
        clearRecording: () {},
        setMaxRecordingDuration: (_) {},
        hasDetectedSpeech: () => false,
      ),
    );
    _testRepeatEngine!.prepare(
      sentences: [sentence],
      config: RepeatFlowConfig(
        audioItemId: 'test-audio',
        getRepeatCount: (_) => 3,
        getIntervalDuration: (_) => const Duration(seconds: 3),
        isManualMode: () => state.isManualMode,
      ),
    );
    return _testRepeatEngine;
  }

  @override
  int get currentIndex => state.currentSentenceIndex;

  @override
  void initialize(List<Sentence> sentences, {int startIndex = 0}) {
    _testSentences = sentences.map((s) => s.copyWith()).toList();
    final validIndex = _testSentences.isEmpty
        ? 0
        : startIndex.clamp(0, _testSentences.length - 1);
    state = ReviewDifficultPracticeState(
      currentSentenceIndex: validIndex,
      totalSentences: _testSentences.length,
    );
  }

  @override
  Future<void> startPlaying() async {
    if (_testSentences.isEmpty) return;
    state = state.copyWith(isPlaying: true);
  }

  @override
  void pause() {
    state = state.copyWith(
      isPlaying: false,
      isPauseBetweenPlays: false,
      isCountdownPaused: false,
      isCountdownFastForward: false,
    );
  }

  @override
  void stopPlayback() {
    state = state.copyWith(
      isPlaying: false,
      isPauseBetweenPlays: false,
      isPauseBetweenSentences: false,
    );
  }

  @override
  Future<void> resume() async {
    if (state.isAnnotationMode) {
      state = state.copyWith(isPlaying: true, currentPlayCount: 1);
      return;
    }
    state = state.copyWith(isPlaying: true);
  }

  @override
  void enterAnnotationMode() {
    if (state.isAnnotationMode) return;
    state = state.copyWith(
      isAnnotationMode: true,
      isPlaying: true,
      currentPlayCount: 1,
      isPauseBetweenPlays: false,
      isTextRevealed: false,
    );
  }

  @override
  Future<void> skipShadowReading() async {
    state = state.copyWith(
      isAnnotationMode: false,
      isPlaying: false,
      isPauseBetweenPlays: false,
    );
  }

  @override
  void setTextRevealed(bool revealed) {
    state = state.copyWith(isTextRevealed: revealed);
  }

  @override
  void enterWaitingForUserInBlindMode() {
    state = state.copyWith(
      isPlaying: false,
      isPauseBetweenPlays: false,
      isPauseBetweenSentences: false,
    );
  }

  @override
  Future<void> updateSettings(DifficultPracticeSettings newSettings) async {
    state = state.copyWith(settings: newSettings, isPlaying: false);
  }

  @override
  Sentence? removeDifficultMark() {
    if (_testSentences.isEmpty) return null;

    final removedIndex = state.currentSentenceIndex;
    final removed = _testSentences[removedIndex];
    _testSentences = List.from(_testSentences)..removeAt(removedIndex);

    if (_testSentences.isEmpty) {
      state = state.copyWith(isPlaying: false, totalSentences: 0);
      return removed;
    }

    final newIndex = removedIndex >= _testSentences.length
        ? _testSentences.length - 1
        : removedIndex;

    state = state.copyWith(
      currentSentenceIndex: newIndex,
      totalSentences: _testSentences.length,
      currentPlayCount: 1,
      isPlaying: false,
      isAnnotationMode: false,
      isTextRevealed: false,
    );

    return removed;
  }

  @override
  Future<void> toggleCurrentBookmark(String audioItemId) async {
    final sentence = currentSentence;
    if (sentence == null) return;
    _testSentences[state.currentSentenceIndex] = sentence.copyWith(
      isBookmarked: !sentence.isBookmarked,
    );
    state = state.copyWith(bookmarkVersion: state.bookmarkVersion + 1);
  }

  @override
  Future<void> goToNext() async {
    if (state.currentSentenceIndex < state.totalSentences - 1) {
      state = state.copyWith(
        currentSentenceIndex: state.currentSentenceIndex + 1,
        currentPlayCount: 1,
        isAnnotationMode: false,
        isTextRevealed: false,
      );
    }
  }

  @override
  Future<void> goToPrevious() async {
    if (state.currentSentenceIndex > 0) {
      state = state.copyWith(
        currentSentenceIndex: state.currentSentenceIndex - 1,
        currentPlayCount: 1,
        isAnnotationMode: false,
        isTextRevealed: false,
      );
    }
  }

  @override
  Future<void> replayDuringCountdown() async {
    if (state.isAnnotationMode) {
      state = state.copyWith(
        isPlaying: true,
        currentPlayCount: 1,
        isPauseBetweenPlays: false,
      );
    } else {
      state = state.copyWith(
        isPlaying: true,
        isPauseBetweenPlays: false,
        isPauseBetweenSentences: false,
        isCountdownPaused: false,
        isCountdownFastForward: false,
      );
    }
  }

  Future<void> completePausedTurn() async {
    // 测试用：不执行实际逻辑
  }

  @override
  void pauseCountdown() {
    state = state.copyWith(isCountdownPaused: true);
  }

  @override
  void resumeCountdown() {
    state = state.copyWith(isCountdownPaused: false);
  }

  @override
  void disposePlayer() {
    _testSentences = [];
    state = const ReviewDifficultPracticeState();
  }
}

/// 测试用 DailyStudyTime — 不依赖 SharedPreferences
class TestDailyStudyTime extends DailyStudyTime {
  @override
  Future<int> build() async => 0;

  @override
  Future<void> refresh() async {}
}

/// 测试用 AudioEngine — 不依赖 just_audio
class TestAudioEngine extends AudioEngine {
  final AudioEngineState _initialState;
  bool _isPlaying;

  TestAudioEngine({
    AudioEngineState initialState = const AudioEngineState(),
    bool isPlaying = false,
  }) : _initialState = initialState,
       _isPlaying = isPlaying;

  @override
  AudioEngineState build() => _initialState;

  @override
  bool get isPlaying => _isPlaying;

  /// 测试中直接设置播放状态
  set isPlaying(bool value) => _isPlaying = value;

  @override
  Duration get currentPosition => Duration.zero;

  @override
  Stream<Duration> get absolutePositionStream => Stream.value(Duration.zero);

  @override
  Stream<ja.PlayerState> get playerStateStream => const Stream.empty();

  @override
  Future<void> play() async {
    _isPlaying = true;
  }

  @override
  Future<void> pause() async {
    _isPlaying = false;
  }

  @override
  Future<void> stop() async {
    _isPlaying = false;
  }

  @override
  Future<void> seek(Duration pos) async {}

  @override
  Future<void> setSpeed(double speed) async {}

  @override
  int newSession() => 0;

  @override
  bool isActiveSession(int id) => true;

  @override
  Future<void> clearClip() async {}
}

/// 测试用 TranscriptionTaskManager — 不执行真实转录
class TestTranscriptionTaskManager extends TranscriptionTaskManager {
  final Map<String, TranscriptionTaskState> _initialState;

  TestTranscriptionTaskManager([this._initialState = const {}]);

  @override
  Map<String, TranscriptionTaskState> build() => Map.of(_initialState);

  @override
  Future<void> startTranscription(AudioItem audioItem, String language) async {
    // 测试中不执行真实转录
  }

  @override
  void cancelTranscription(String audioId) {
    state = Map.of(state)..remove(audioId);
  }

  @override
  void clearState(String audioId) {
    state = Map.of(state)..remove(audioId);
  }
}

/// 测试用 RetellPlayer — 不依赖音频引擎
class TestRetellPlayer extends RetellPlayer {
  final RetellPlayerState _initialState;
  List<List<Sentence>> _testParagraphs;
  Map<int, Set<int>> _testKeywords;

  TestRetellPlayer([
    this._initialState = const RetellPlayerState(),
    this._testParagraphs = const [],
    this._testKeywords = const {},
  ]);

  @override
  RetellPlayerState build() => _initialState;

  @override
  List<Sentence> get currentParagraphSentences =>
      _testParagraphs.isNotEmpty &&
          state.currentParagraphIndex < _testParagraphs.length
      ? _testParagraphs[state.currentParagraphIndex]
      : [];

  @override
  List<List<Sentence>> get paragraphs => List.unmodifiable(_testParagraphs);

  @override
  Map<int, Set<int>> get keywordsMap => Map.unmodifiable(_testKeywords);

  @override
  Duration get currentParagraphDuration {
    final sentences = currentParagraphSentences;
    if (sentences.isEmpty) return Duration.zero;
    return sentences.last.endTime - sentences.first.startTime;
  }

  @override
  int? get currentParagraphFirstSentenceIndex {
    final sentences = currentParagraphSentences;
    return sentences.isNotEmpty ? sentences.first.index : null;
  }

  @override
  void initialize(
    List<List<Sentence>> paragraphs,
    Map<int, Set<int>> keywordsMap, {
    int? startSentenceIndex,
  }) {
    _testParagraphs = paragraphs;
    _testKeywords = keywordsMap;
    var safeIndex = 0;
    if (startSentenceIndex != null && paragraphs.isNotEmpty) {
      for (var i = 0; i < paragraphs.length; i++) {
        if (paragraphs[i].any((s) => s.index == startSentenceIndex)) {
          safeIndex = i;
          break;
        }
      }
    }
    state = RetellPlayerState(
      currentParagraphIndex: safeIndex,
      totalParagraphs: paragraphs.length,
    );
  }

  @override
  Future<void> startPlaying() async {
    if (_testParagraphs.isEmpty) return;
    state = state.copyWith(
      phase: RetellPhase.listening,
      isPlaying: true,
      playingSentenceIndex: 0,
    );
  }

  @override
  Future<void> restart() async {
    state = RetellPlayerState(
      currentParagraphIndex: 0,
      totalParagraphs: _testParagraphs.length,
      settings: state.settings,
      displayMode: RetellDisplayMode.keywordsOnly,
      phase: RetellPhase.listening,
      isPlaying: true,
      playingSentenceIndex: 0,
    );
  }

  @override
  Future<void> pause() async {
    state = state.copyWith(isPlaying: false, isRetellCountdown: false);
  }

  @override
  Future<void> resume() async {
    if (state.phase == RetellPhase.listening) {
      state = state.copyWith(isPlaying: true);
    }
  }

  @override
  Future<void> goToNextParagraph() async {
    if (state.currentParagraphIndex >= state.totalParagraphs - 1) {
      state = state.copyWith(isPlaying: false, isRetellCountdown: false);
      return;
    }
    state = state.copyWith(
      currentParagraphIndex: state.currentParagraphIndex + 1,
      phase: RetellPhase.listening,
      currentRepeatCount: 1,
      playingSentenceIndex: 0,
      isRetellCountdown: false,
      isPlaying: true,
      displayMode: RetellDisplayMode.keywordsOnly,
    );
  }

  @override
  Future<void> goToPreviousParagraph() async {
    if (state.currentParagraphIndex <= 0) return;
    state = state.copyWith(
      currentParagraphIndex: state.currentParagraphIndex - 1,
      phase: RetellPhase.listening,
      currentRepeatCount: 1,
      playingSentenceIndex: 0,
      isRetellCountdown: false,
      isPlaying: true,
      displayMode: RetellDisplayMode.keywordsOnly,
    );
  }

  @override
  void pauseCountdown() {
    state = state.copyWith(isCountdownPaused: true);
  }

  @override
  void resumeCountdown() {
    state = state.copyWith(isCountdownPaused: false);
  }

  @override
  void toggleCountdownFastForward() {
    state = state.copyWith(
      isCountdownFastForward: !state.isCountdownFastForward,
    );
  }

  @override
  Future<void> replayDuringCountdown() async {
    state = state.copyWith(
      phase: RetellPhase.listening,
      isRetellCountdown: false,
      isCountdownPaused: false,
      isCountdownFastForward: false,
      isPlaying: true,
    );
  }

  @override
  void setDisplayMode(RetellDisplayMode mode) {
    state = state.copyWith(displayMode: mode);
  }

  @override
  void updateSettings(RetellSettings newSettings) {
    state = state.copyWith(settings: newSettings);
  }

  @override
  void regenerateKeywords() {}

  @override
  void disposePlayer() {
    _testParagraphs = [];
    _testKeywords = {};
    state = const RetellPlayerState();
  }
}

/// 测试用 SpeechRecordingController — 不依赖平台通道
class TestSpeechRecordingController extends SpeechRecordingController {
  /// 初始阶段（默认 idle）
  final SpeechRecordingPhase initialPhase;

  TestSpeechRecordingController({
    this.initialPhase = SpeechRecordingPhase.idle,
  });

  @override
  SpeechRecordingState build() => SpeechRecordingState(phase: initialPhase);

  @override
  Future<void> startRecording({
    required String promptId,
    required String referenceText,
    Duration? referenceDuration,
  }) async {}

  @override
  Future<void> stopAndEvaluate({required String referenceText}) async {}

  @override
  Future<void> cancelActiveRecording() async {}

  @override
  Future<void> clearRecording() async {
    state = const SpeechRecordingState();
  }

  @override
  Future<void> fullReset() async {
    state = const SpeechRecordingState();
  }

  @override
  Future<void> deleteRecording(String filePath) async {}

  @override
  void setRecorder(StudyEventRecorder? recorder) {
    // 测试环境中无实际录音服务，忽略 recorder 设置。
  }
}

/// 测试用 RetellRecordingController — 不依赖平台通道
class TestRetellRecordingController extends RetellRecordingController {
  TestRetellRecordingController([
    this._initialState = const RetellRecordingState(),
  ]);

  final RetellRecordingState _initialState;

  @override
  RetellRecordingState build() => _initialState;

  @override
  void setRecorder(StudyEventRecorder? recorder) {
    // 测试环境中无实际录音服务，忽略 recorder 设置。
  }

  @override
  Future<void> startRecording({
    required String promptId,
    required String referenceText,
    Duration? referenceDuration,
  }) async {
    state = state.copyWith(
      phase: RetellRecordingPhase.recording,
      promptId: promptId,
      awaitingSpeechTimedOut: false,
    );
  }

  @override
  Future<void> stopAndEvaluate({required String referenceText}) async {
    state = state.copyWith(phase: RetellRecordingPhase.processing);
    state = state.copyWith(
      phase: RetellRecordingPhase.idle,
      currentAttempt: SpeechPracticeAttempt(
        promptId: state.promptId ?? '',
        status: SpeechPracticeAttemptStatus.passed,
        score: 0.8,
      ),
      clearPromptId: true,
    );
  }

  @override
  Future<void> cancelActiveRecording() async {
    state = state.copyWith(
      phase: RetellRecordingPhase.idle,
      clearPromptId: true,
    );
  }

  @override
  Future<void> clearRecording() async {
    state = state.copyWith(
      clearCurrentAttempt: true,
      clearLiveTranscript: true,
      clearPromptId: true,
      phase: RetellRecordingPhase.idle,
      awaitingSpeechTimedOut: false,
    );
  }

  @override
  Future<void> fullReset() async {
    state = const RetellRecordingState();
  }
}

/// 测试用 TranscriptionApiClient Provider 值
TranscriptionApiClient createTestTranscriptionApiClient() {
  return TranscriptionApiClient(baseUrl: 'https://test.local');
}

/// 测试用 StudyTimeService + 录音控制器 Overrides
///
/// 返回一个 Override 列表，提供无操作的 [StudyTimeService] 和录音控制器。
/// 用于测试需要读取 [studyTimeServiceProvider] 的 Provider（如各播放器 Provider）。
List<Override> studyTimeOverrides() {
  return [
    studyTimeServiceProvider.overrideWithValue(_NoOpStudyTimeService()),
    speechRecordingControllerProvider.overrideWith(
      TestSpeechRecordingController.new,
    ),
    retellRecordingControllerProvider.overrideWith(
      TestRetellRecordingController.new,
    ),
    offlineAsrOverride(),
  ];
}

/// 无操作 StudyTimeService — 所有写入操作静默忽略，查询返回零值。
class _NoOpStudyTimeService implements StudyTimeService {
  @override
  Future<int> getStudyTime(DateTime date) async => 0;
  @override
  Future<int> getTodayStudyTime() async => 0;
  @override
  Future<void> addStudyTime(
    int seconds, {
    DateTime? date,
    StudyStage? stage,
  }) async {}
  @override
  Future<int> getStudyStreak({DateTime? now}) async => 0;
  @override
  Future<List<int>> getWeeklyStudyTimes({DateTime? now}) async =>
      List.filled(7, 0);
  @override
  Future<int> getWeekTotalStudyTime({DateTime? now}) async => 0;
  @override
  Future<int> getInputWords(DateTime date) async => 0;
  @override
  Future<int> getTodayInputWords() async => 0;
  @override
  Future<void> addInputWords(int count, {DateTime? date}) async {}
  @override
  Future<int> getOutputWords(DateTime date) async => 0;
  @override
  Future<int> getTodayOutputWords() async => 0;
  @override
  Future<void> addOutputWords(int count, {DateTime? date}) async {}
  @override
  Future<int> getInputTime(DateTime date) async => 0;
  @override
  Future<int> getTodayInputTime() async => 0;
  @override
  Future<void> addInputTime(
    int seconds, {
    DateTime? date,
    StudyStage? stage,
  }) async {}
  @override
  Future<List<int>> getWeeklyInputTimes({DateTime? now}) async =>
      List.filled(7, 0);
  @override
  Future<int> getOutputTime(DateTime date) async => 0;
  @override
  Future<int> getTodayOutputTime() async => 0;
  @override
  Future<void> addOutputTime(
    int seconds, {
    DateTime? date,
    StudyStage? stage,
  }) async {}
  @override
  Future<List<int>> getWeeklyOutputTimes({DateTime? now}) async =>
      List.filled(7, 0);
  @override
  Future<List<DailyStageStudyRecordData>> getStageBreakdown(
    DateTime date,
  ) async => [];
  @override
  Future<DailyTotalData?> getDayTotal(DateTime date) async => null;
}

/// 测试用 OfflineAsrSettings — 不执行模型下载/平台调用
class TestOfflineAsrSettings extends OfflineAsrSettingsNotifier {
  final OfflineAsrSettingsState _initialState;

  TestOfflineAsrSettings([
    this._initialState = const OfflineAsrSettingsState(
      enabled: true,
      backend: AsrBackend.platform,
      engineReady: true,
      recommendedModel: AsrModelInfo(
        id: 'test-model',
        displayName: 'Test Model',
        type: AsrModelType.moonshine,
      ),
    ),
  ]);

  @override
  OfflineAsrSettingsState build() => _initialState;

  @override
  Future<void> enable() async {
    state = state.copyWith(enabled: true);
  }

  @override
  Future<void> disable() async {
    state = state.copyWith(enabled: false);
  }

  @override
  Future<void> retryDownload() async {
    // 测试中不执行下载
  }

  @override
  Future<void> loadEngine() async {
    state = state.copyWith(engineReady: true);
  }
}

/// 返回 offlineAsrSettingsProvider 的 override（默认开启且就绪）
Override offlineAsrOverride({
  bool enabled = true,
  AsrBackend backend = AsrBackend.platform,
  bool engineReady = true,
}) {
  // 测试用默认模型
  const testModel = AsrModelInfo(
    id: 'test-model',
    displayName: 'Test Model',
    type: AsrModelType.moonshine,
  );
  return offlineAsrSettingsProvider.overrideWith(
    () => TestOfflineAsrSettings(
      OfflineAsrSettingsState(
        enabled: enabled,
        backend: backend,
        engineReady: engineReady,
        recommendedModel: testModel,
      ),
    ),
  );
}
