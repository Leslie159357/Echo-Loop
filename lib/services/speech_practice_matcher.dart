/// 跟读录音识别文本比对器。
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/speech_practice_models.dart';

/// 文本匹配器 provider。
final speechTranscriptMatcherProvider = Provider<SpeechTranscriptMatcher>((
  ref,
) {
  // 本 fork 即德语版：恒用德语比对（跳过英文词形还原）。
  return SpeechTranscriptMatcher(german: true);
});

class _IndexedToken {
  final String rawText;
  final String normalizedText;
  final int start;
  final int end;

  const _IndexedToken({
    required this.rawText,
    required this.normalizedText,
    required this.start,
    required this.end,
  });
}

/// 将识别文本与目标句子做宽松词级比对。
class SpeechTranscriptMatcher {
  /// 德语版：不再引入英文词形还原（lemmatizerx 对德语变位词不可靠，也会把
  /// 德语词误映射成英文 lemma）。`german`/`lemmatizer` 形参保留只为兼容旧调用点。
  SpeechTranscriptMatcher({bool german = true, Object? lemmatizer});

  static final RegExp _wordPattern = RegExp(
    r"[A-Za-zäöüÄÖÜß\u00C0-\u024F\u1E00-\u1EFF]+(?:'[A-Za-zäöüÄÖÜß\u00C0-\u024F\u1E00-\u1EFF]+)?"
    r"|\d+(?:[.,]\d+)?",
  );

  static final RegExp _digitStart = RegExp(r'^\d');
  static final RegExp _hasLetter = RegExp(r'[A-Za-zäöüÄÖÜß]');

  /// 计算识别文本与目标文本的覆盖率，并输出 transcript 高亮片段。
  ///
  /// 规则：
  /// - 只保留字母词（德语版含 äöüß）
  /// - 全部小写
  /// - 英文模式做词形还原；德语模式（german=true）跳过英文还原
  /// - 使用 token 级 LCS，保留基本词序
  SpeechMatchResult evaluate({
    required String referenceText,
    required String transcript,
  }) {
    final trimmedTranscript = transcript.trim();
    final targetTokens = _tokenize(referenceText);
    final recognizedTokens = _tokenize(trimmedTranscript);

    if (recognizedTokens.isEmpty) {
      return const SpeechMatchResult(
        status: SpeechPracticeAttemptStatus.noEnglishDetected,
        finalTranscript: '',
        score: 0,
        matchedTokenCount: 0,
        totalTargetTokenCount: 0,
        recognizedEnglishTokenCount: 0,
        transcriptSegments: [],
        referenceSegments: [],
      );
    }

    final alignment = _findMatchedIndexes(
      targetTokens.map((token) => token.normalizedText).toList(),
      recognizedTokens.map((token) => token.normalizedText).toList(),
    );

    final totalTargetTokenCount = targetTokens.length;
    final matchedTokenCount = alignment.transcriptIndexes.length;
    final score = totalTargetTokenCount == 0
        ? 0.0
        : matchedTokenCount / totalTargetTokenCount;

    return SpeechMatchResult(
      status: score >= 0.5
          ? SpeechPracticeAttemptStatus.passed
          : SpeechPracticeAttemptStatus.belowThreshold,
      finalTranscript: trimmedTranscript,
      score: score,
      matchedTokenCount: matchedTokenCount,
      totalTargetTokenCount: totalTargetTokenCount,
      recognizedEnglishTokenCount: recognizedTokens.length,
      transcriptSegments: _buildTranscriptSegments(
        originalTranscript: trimmedTranscript,
        recognizedTokens: recognizedTokens,
        matchedTokenIndexes: alignment.transcriptIndexes,
      ),
      referenceSegments: _buildTranscriptSegments(
        originalTranscript: referenceText,
        recognizedTokens: targetTokens,
        matchedTokenIndexes: alignment.referenceIndexes,
      ),
    );
  }

  List<_IndexedToken> _tokenize(String text) {
    // 没有任何字母（纯数字/纯中文）视为「没识别出德语」，交给上层报未检测到。
    if (!_hasLetter.hasMatch(text)) return const [];
    return _wordPattern
        .allMatches(text)
        .map((match) {
          final raw = match.group(0) ?? '';
          // 数字就地转成德语数词（21 → einundzwanzig），索引仍与原文对齐，
          // 高亮片段不会因为替换而错位。
          final normalized = _digitStart.hasMatch(raw)
              ? _numberToWords(raw)
              : _lemmatize(raw);
          return _IndexedToken(
            rawText: raw,
            normalizedText: normalized,
            start: match.start,
            end: match.end,
          );
        })
        .where((token) => token.normalizedText.isNotEmpty)
        .toList();
  }

  /// 「21」→ einundzwanzig，「199」→ einhundertneunundneunzig，
  /// 「9,30」→ neun Komma drei null。
  String _numberToWords(String raw) {
    if (raw.contains(',') || raw.contains('.')) {
      final parts = raw.split(RegExp(r'[,.]'));
      final head = int.tryParse(parts.first);
      if (head == null) return raw;
      final decimals = parts.last
          .split('')
          .map((d) => _belowTwenty[int.tryParse(d) ?? 0])
          .join(' ');
      return '${_germanNumber(head)} Komma $decimals';
    }
    final value = int.tryParse(raw);
    if (value == null || value > 9999) return raw;
    return _germanNumber(value);
  }

  /// 德语归一：小写 + `ß`→`ss`（ASR 对 Straße/Strasse 两种写法都会输出）。
  String _lemmatize(String token) =>
      token.toLowerCase().replaceAll('ß', 'ss');

  static final RegExp _numberPattern = RegExp(r'\d+(?:[.,]\d+)?');

  static const List<String> _belowTwenty = [
    'null', 'eins', 'zwei', 'drei', 'vier', 'fünf', 'sechs', 'sieben',
    'acht', 'neun', 'zehn', 'elf', 'zwölf', 'dreizehn', 'vierzehn',
    'fünfzehn', 'sechzehn', 'siebzehn', 'achtzehn', 'neunzehn',
  ];

  static const List<String> _tens = [
    '', '', 'zwanzig', 'dreißig', 'vierzig', 'fünfzig',
    'sechzig', 'siebzig', 'achtzig', 'neunzig',
  ];


  String _germanNumber(int value) {
    if (value < 20) return _belowTwenty[value];
    if (value < 100) {
      final tens = value ~/ 10;
      final ones = value % 10;
      if (ones == 0) return _tens[tens];
      final one = ones == 1 ? 'ein' : _belowTwenty[ones];
      return '${one}und${_tens[tens]}';
    }
    if (value < 1000) {
      final hundreds = value ~/ 100;
      final rest = value % 100;
      final head = '${hundreds == 1 ? 'ein' : _belowTwenty[hundreds]}hundert';
      return rest == 0 ? head : '$head${_germanNumber(rest)}';
    }
    final thousands = value ~/ 1000;
    final rest = value % 1000;
    final head = '${thousands == 1 ? 'ein' : _germanNumber(thousands)}tausend';
    return rest == 0 ? head : '$head${_germanNumber(rest)}';
  }

  ({Set<int> referenceIndexes, Set<int> transcriptIndexes}) _findMatchedIndexes(
    List<String> referenceTokens,
    List<String> transcriptTokens,
  ) {
    if (referenceTokens.isEmpty || transcriptTokens.isEmpty) {
      return (
        referenceIndexes: const <int>{},
        transcriptIndexes: const <int>{},
      );
    }

    final rows = referenceTokens.length + 1;
    final cols = transcriptTokens.length + 1;
    final dp = List.generate(rows, (_) => List.filled(cols, 0));

    for (var i = 1; i < rows; i++) {
      for (var j = 1; j < cols; j++) {
        if (referenceTokens[i - 1] == transcriptTokens[j - 1]) {
          dp[i][j] = dp[i - 1][j - 1] + 1;
        } else {
          dp[i][j] = dp[i - 1][j] > dp[i][j - 1] ? dp[i - 1][j] : dp[i][j - 1];
        }
      }
    }

    final matchedReferenceIndexes = <int>{};
    final matchedTranscriptIndexes = <int>{};
    var i = referenceTokens.length;
    var j = transcriptTokens.length;
    while (i > 0 && j > 0) {
      if (referenceTokens[i - 1] == transcriptTokens[j - 1]) {
        matchedReferenceIndexes.add(i - 1);
        matchedTranscriptIndexes.add(j - 1);
        i -= 1;
        j -= 1;
      } else if (dp[i - 1][j] >= dp[i][j - 1]) {
        i -= 1;
      } else {
        j -= 1;
      }
    }
    return (
      referenceIndexes: matchedReferenceIndexes,
      transcriptIndexes: matchedTranscriptIndexes,
    );
  }

  List<SpeechTranscriptSegment> _buildTranscriptSegments({
    required String originalTranscript,
    required List<_IndexedToken> recognizedTokens,
    required Set<int> matchedTokenIndexes,
  }) {
    if (originalTranscript.isEmpty) {
      return const [];
    }

    final segments = <SpeechTranscriptSegment>[];
    var cursor = 0;
    for (var index = 0; index < recognizedTokens.length; index++) {
      final token = recognizedTokens[index];
      if (cursor < token.start) {
        segments.add(
          SpeechTranscriptSegment(
            text: originalTranscript.substring(cursor, token.start),
            isMatched: false,
          ),
        );
      }
      segments.add(
        SpeechTranscriptSegment(
          text: originalTranscript.substring(token.start, token.end),
          isMatched: matchedTokenIndexes.contains(index),
        ),
      );
      cursor = token.end;
    }

    if (cursor < originalTranscript.length) {
      segments.add(
        SpeechTranscriptSegment(
          text: originalTranscript.substring(cursor),
          isMatched: false,
        ),
      );
    }
    return segments;
  }
}
