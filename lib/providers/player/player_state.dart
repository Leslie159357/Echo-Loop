import 'package:flutter/foundation.dart';
import '../../models/audio_item.dart';
import '../../models/sentence.dart';
import '../../models/playback_settings.dart';

enum PlaylistMode { full, bookmarks }

/// 播放器状态管理
/// 负责管理所有播放相关的状态数据
class PlayerState extends ChangeNotifier {
  // 音频和句子相关
  AudioItem? _currentAudioItem;
  List<Sentence> _sentences = [];
  
  // 索引管理
  int? _currentFullIndex;
  int? _currentBookmarkIndex;
  int? _lastPlayedFullIndex; // 记录上次手动选择播放的句子（全文模式）
  int? _lastPlayedBookmarkIndex; // 记录上次手动选择播放的句子（收藏模式）
  
  // 设置和模式
  PlaybackSettings _settings = PlaybackSettings();
  PlaylistMode _playlistMode = PlaylistMode.full;
  
  // 书签
  Set<int> _bookmarkedIndices = {};
  
  // UI状态
  bool _isLoading = false;
  bool _autoScrollEnabled = true;
  
  // 播放会话管理
  int _playbackSessionId = 0;
  
  // 进度相关
  Duration? _fullDuration;
  Duration _clipStart = Duration.zero;
  
  // Getters
  AudioItem? get currentAudioItem => _currentAudioItem;
  List<Sentence> get sentences => _sentences;
  List<Sentence> get bookmarkedSentences =>
      _sentences.where((s) => _bookmarkedIndices.contains(s.index)).toList();
  int? get currentFullIndex => _currentFullIndex;
  int? get currentBookmarkIndex => _currentBookmarkIndex;
  int? get lastPlayedFullIndex => _lastPlayedFullIndex;
  int? get lastPlayedBookmarkIndex => _lastPlayedBookmarkIndex;
  Sentence? get currentSentence =>
      _currentFullIndex != null && _currentFullIndex! < _sentences.length
          ? _sentences[_currentFullIndex!]
          : null;
  PlaybackSettings get settings => _settings;
  PlaylistMode get playlistMode => _playlistMode;
  Set<int> get bookmarkedIndices => _bookmarkedIndices;
  bool get isLoading => _isLoading;
  bool get autoScrollEnabled => _autoScrollEnabled;
  Duration? get totalDuration => _fullDuration;
  Duration get clipStart => _clipStart;
  bool get hasAudio => _currentAudioItem != null;
  bool get hasSentences => _sentences.isNotEmpty;
  int get playbackSessionId => _playbackSessionId;
  
  // Setters
  void setCurrentAudioItem(AudioItem? item) {
    _currentAudioItem = item;
    notifyListeners();
  }
  
  void setSentences(List<Sentence> sentences) {
    _sentences = sentences;
    notifyListeners();
  }
  
  void setCurrentFullIndex(int? index) {
    _currentFullIndex = index;
    notifyListeners();
  }
  
  void setCurrentBookmarkIndex(int? index) {
    _currentBookmarkIndex = index;
    notifyListeners();
  }
  
  void setLastPlayedFullIndex(int? index) {
    _lastPlayedFullIndex = index;
  }
  
  void setLastPlayedBookmarkIndex(int? index) {
    _lastPlayedBookmarkIndex = index;
  }
  
  void setSettings(PlaybackSettings settings) {
    _settings = settings;
    notifyListeners();
  }
  
  void setPlaylistMode(PlaylistMode mode) {
    _playlistMode = mode;
    notifyListeners();
  }
  
  void setBookmarkedIndices(Set<int> indices) {
    _bookmarkedIndices = indices;
    notifyListeners();
  }
  
  void setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }
  
  void setAutoScrollEnabled(bool enabled) {
    _autoScrollEnabled = enabled;
    notifyListeners();
  }
  
  void setFullDuration(Duration? duration) {
    _fullDuration = duration;
    notifyListeners();
  }
  
  void setClipStart(Duration start) {
    _clipStart = start;
    notifyListeners();
  }
  
  void incrementPlaybackSessionId() {
    _playbackSessionId++;
  }
  
  void resetIndices() {
    _currentFullIndex = null;
    _currentBookmarkIndex = null;
    notifyListeners();
  }
  
  /// 清空所有状态
  void clear() {
    _currentAudioItem = null;
    _sentences = [];
    _currentFullIndex = null;
    _currentBookmarkIndex = null;
    _bookmarkedIndices = {};
    _fullDuration = null;
    _clipStart = Duration.zero;
    notifyListeners();
  }
}
