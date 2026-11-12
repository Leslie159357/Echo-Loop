/// 跟读录音识别文本比对器。
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lemmatizerx/lemmatizerx.dart';

import '../models/speech_practice_models.dart';

/// 文本匹配器 provider。
final speechTranscriptMatcherProvider = Provider<SpeechTranscriptMatcher>((
  ref,
) {
  return SpeechTranscriptMatcher();
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
  SpeechTranscriptMatcher({Lemmatizer? lemmatizer})
    : _lemmatizer = lemmatizer ?? Lemmatizer();

  final Lemmatizer _lemmatizer;

  static final RegExp _wordPattern = RegExp(
    r"[A-Za-zäöüÄÖÜß\u00C0-\u024F\u1E00-\u1EFF]+(?:'[A-Za-zäöüÄÖÜß\u00C0-\u024F\u1E00-\u1EFF]+)?",
  );

  /// 计算识别文本与目标文本的覆盖率，并输出 transcript 高亮片段。
  ///
  /// 规则：
  /// - 只保留英文词
  /// - 全部小写
  /// - 做词形还原
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
    return _wordPattern
        .allMatches(text)
        .map(
          (match) => _IndexedToken(
            rawText: match.group(0) ?? '',
            normalizedText: _lemmatize((match.group(0) ?? '').toLowerCase()),
            start: match.start,
            end: match.end,
          ),
        )
        .where((token) => token.normalizedText.isNotEmpty)
        .toList();
  }

  String _lemmatize(String token) {
    final candidates = _lemmatizer.lemmas(token);
    for (final candidate in candidates) {
      for (final lemma in candidate.lemmas) {
        if (lemma.isNotEmpty) {
          return lemma.toLowerCase();
        }
      }
    }
    return token;
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
