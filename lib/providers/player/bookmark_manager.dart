import '../../models/sentence.dart';
import '../../services/storage_service.dart';

/// 书签管理器
/// 负责书签的添加、删除、加载和保存
class BookmarkManager {
  /// 加载书签
  static Future<Set<int>> loadBookmarks(String audioId) async {
    try {
      return await StorageService.loadBookmarks(audioId);
    } catch (e) {
      print('Error loading bookmarks: $e');
      return {};
    }
  }
  
  /// 保存书签
  static Future<void> saveBookmarks(
    String audioId,
    Set<int> bookmarks,
  ) async {
    try {
      await StorageService.saveBookmarks(audioId, bookmarks);
    } catch (e) {
      print('Error saving bookmarks: $e');
    }
  }
  
  /// 自动添加 [] 包裹的句子为书签
  static Set<int> autoAddBracketBookmarks(List<Sentence> sentences) {
    final bookmarks = <int>{};
    for (var sentence in sentences) {
      final text = sentence.text.trim();
      if (text.startsWith('[') && text.endsWith(']')) {
        bookmarks.add(sentence.index);
      }
    }
    return bookmarks;
  }
  
  /// 更新句子的书签状态
  static void updateSentenceBookmarkStatus(
    List<Sentence> sentences,
    Set<int> bookmarkedIndices,
  ) {
    for (var sentence in sentences) {
      sentence.isBookmarked = bookmarkedIndices.contains(sentence.index);
    }
  }
  
  /// 切换书签状态
  /// 返回: (isRemoving, indicesToRemove, nextIndex)
  static (bool, Set<int>, int?) toggleBookmark(
    int index,
    List<Sentence> sentences,
    Set<int> bookmarkedIndices,
    bool inBookmarksMode,
  ) {
    final isRemoving = bookmarkedIndices.contains(index);
    Set<int> indicesToRemove = {};
    int? nextIndex;
    
    if (isRemoving) {
      // 计算所有同文本（不区分大小写）的书签
      final bookmarkedSentences = sentences
          .where((s) => bookmarkedIndices.contains(s.index))
          .toList();
      final targetTextLower = sentences[index].text.toLowerCase();
      
      for (final s in bookmarkedSentences) {
        if (s.text.toLowerCase() == targetTextLower) {
          indicesToRemove.add(s.index);
        }
      }
      
      // 仅在书签模式时计算"下一个"焦点
      if (inBookmarksMode) {
        final pos = bookmarkedSentences.indexWhere((s) => s.index == index);
        if (pos != -1) {
          // 找下一个句子（跳过将被移除的条目）
          for (int i = pos + 1; i < bookmarkedSentences.length; i++) {
            if (!indicesToRemove.contains(bookmarkedSentences[i].index)) {
              nextIndex = bookmarkedSentences[i].index;
              break;
            }
          }
        }
      }
    }
    
    return (isRemoving, indicesToRemove, nextIndex);
  }
}
