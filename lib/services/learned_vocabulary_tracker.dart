import 'dart:async';

import '../models/sentence.dart';

typedef PersistLearnedWordForms =
    Future<void> Function(Map<String, DateTime> wordForms);

/// 已学习词形追踪器
///
/// 将句子中的英文词形异步去重后批量写入数据库，
/// 避免在播放回调中阻塞音频主流程。
class LearnedVocabularyTracker {
  final PersistLearnedWordForms _persistWordForms;
  final void Function() _onStatsUpdated;
  final Duration _flushDelay;
  final void Function(Object error, StackTrace stackTrace)? _onError;

  final Map<String, DateTime> _pendingWordForms = <String, DateTime>{};
  Timer? _flushTimer;
  Future<void>? _flushInFlight;

  LearnedVocabularyTracker({
    required PersistLearnedWordForms persistWordForms,
    required void Function() onStatsUpdated,
    Duration flushDelay = const Duration(milliseconds: 400),
    void Function(Object error, StackTrace stackTrace)? onError,
  }) : _persistWordForms = persistWordForms,
       _onStatsUpdated = onStatsUpdated,
       _flushDelay = flushDelay,
       _onError = onError;

  /// 异步记录单句中首次听到的词形。
  Future<void> recordSentence(String text, {DateTime? learnedAt}) async {
    _queueWordForms(_extractWordForms(text), learnedAt ?? DateTime.now());
  }

  /// 异步记录多句中首次听到的词形。
  Future<void> recordSentences(
    Iterable<Sentence> sentences, {
    DateTime? learnedAt,
  }) async {
    final timestamp = learnedAt ?? DateTime.now();
    for (final sentence in sentences) {
      _queueWordForms(_extractWordForms(sentence.text), timestamp);
    }
  }

  /// 立即刷新待写入的数据。
  Future<void> flush() async {
    _flushTimer?.cancel();
    _flushTimer = null;
    await _flushNow();
  }

  /// 销毁前兜底刷新，尽量减少异步统计丢失。
  Future<void> dispose() => flush();

  void _queueWordForms(Set<String> wordForms, DateTime learnedAt) {
    if (wordForms.isEmpty) return;

    for (final wordForm in wordForms) {
      final existing = _pendingWordForms[wordForm];
      if (existing == null || learnedAt.isBefore(existing)) {
        _pendingWordForms[wordForm] = learnedAt;
      }
    }

    _flushTimer?.cancel();
    _flushTimer = Timer(_flushDelay, () {
      unawaited(_flushNow());
    });
  }

  Future<void> _flushNow() {
    if (_pendingWordForms.isEmpty) {
      return _flushInFlight ?? Future<void>.value();
    }
    if (_flushInFlight != null) {
      return _flushInFlight!;
    }

    final payload = Map<String, DateTime>.from(_pendingWordForms);
    _pendingWordForms.clear();

    final future = _persistWordForms(payload)
        .then((_) {
          _onStatsUpdated();
        })
        .catchError((Object error, StackTrace stackTrace) {
          _onError?.call(error, stackTrace);
        })
        .whenComplete(() {
          _flushInFlight = null;
          if (_pendingWordForms.isNotEmpty) {
            _flushTimer?.cancel();
            _flushTimer = Timer(_flushDelay, () {
              unawaited(_flushNow());
            });
          }
        });

    _flushInFlight = future;
    return future;
  }

  /// 从句子中提取唯一词形（德语版：含 ä/ö/ü/ß 等变音字母）。
  ///
  /// 规则：
  /// - 统一转小写
  /// - 保留内部撇号和连字符
  /// - 忽略数字和纯符号
  /// - 用 Unicode 字母类而非 `[A-Za-z]`：后者会把 über/schön/Äpfel 切成
  ///   ber/sch+n/pfel，导致已学词汇库与进度统计存的是残词。
  static Set<String> extractWordForms(String text) => _extractWordForms(text);

  static final RegExp _wordPattern = RegExp(
    r"[\p{L}]+(?:['’-][\p{L}]+)*",
    unicode: true,
  );

  static Set<String> _extractWordForms(String text) {
    if (text.isEmpty) return <String>{};
    return _wordPattern
        .allMatches(text)
        .map((match) => match.group(0)!.toLowerCase())
        .toSet();
  }
}
