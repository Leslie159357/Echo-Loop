import 'audio_item.dart';
import 'sentence.dart';
import 'playback_settings.dart';

enum PlaylistMode { full, bookmarks }

class ListeningPracticeState {
  final AudioItem? currentAudioItem;
  final List<Sentence> sentences;
  final int? currentFullIndex;
  final int? currentBookmarkIndex;
  final int? lastPlayedFullIndex;
  final int? lastPlayedBookmarkIndex;
  final PlaybackSettings settings;
  final PlaylistMode playlistMode;
  final Set<int> bookmarkedIndices;
  final bool autoScrollEnabled;
  final bool isLoading;

  const ListeningPracticeState({
    this.currentAudioItem,
    this.sentences = const [],
    this.currentFullIndex,
    this.currentBookmarkIndex,
    this.lastPlayedFullIndex,
    this.lastPlayedBookmarkIndex,
    this.settings = const PlaybackSettings(),
    this.playlistMode = PlaylistMode.full,
    this.bookmarkedIndices = const {},
    this.autoScrollEnabled = true,
    this.isLoading = false,
  });

  // 计算属性
  List<Sentence> get bookmarkedSentences =>
      sentences.where((s) => bookmarkedIndices.contains(s.index)).toList();

  Sentence? get currentSentence =>
      currentFullIndex != null && currentFullIndex! < sentences.length
          ? sentences[currentFullIndex!]
          : null;

  bool get hasAudio => currentAudioItem != null;
  bool get hasSentences => sentences.isNotEmpty;

  ListeningPracticeState copyWith({
    AudioItem? currentAudioItem,
    bool clearCurrentAudioItem = false,
    List<Sentence>? sentences,
    int? currentFullIndex,
    bool clearCurrentFullIndex = false,
    int? currentBookmarkIndex,
    bool clearCurrentBookmarkIndex = false,
    int? lastPlayedFullIndex,
    bool clearLastPlayedFullIndex = false,
    int? lastPlayedBookmarkIndex,
    bool clearLastPlayedBookmarkIndex = false,
    PlaybackSettings? settings,
    PlaylistMode? playlistMode,
    Set<int>? bookmarkedIndices,
    bool? autoScrollEnabled,
    bool? isLoading,
  }) {
    return ListeningPracticeState(
      currentAudioItem: clearCurrentAudioItem
          ? null
          : (currentAudioItem ?? this.currentAudioItem),
      sentences: sentences ?? this.sentences,
      currentFullIndex: clearCurrentFullIndex
          ? null
          : (currentFullIndex ?? this.currentFullIndex),
      currentBookmarkIndex: clearCurrentBookmarkIndex
          ? null
          : (currentBookmarkIndex ?? this.currentBookmarkIndex),
      lastPlayedFullIndex: clearLastPlayedFullIndex
          ? null
          : (lastPlayedFullIndex ?? this.lastPlayedFullIndex),
      lastPlayedBookmarkIndex: clearLastPlayedBookmarkIndex
          ? null
          : (lastPlayedBookmarkIndex ?? this.lastPlayedBookmarkIndex),
      settings: settings ?? this.settings,
      playlistMode: playlistMode ?? this.playlistMode,
      bookmarkedIndices: bookmarkedIndices ?? this.bookmarkedIndices,
      autoScrollEnabled: autoScrollEnabled ?? this.autoScrollEnabled,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}
