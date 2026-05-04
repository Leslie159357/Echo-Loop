import 'package:flutter_test/flutter_test.dart';
import 'package:echo_loop/models/speech_practice_models.dart';
import 'package:echo_loop/services/speech_practice_matcher.dart';

void main() {
  group('SpeechTranscriptMatcher', () {
    final matcher = SpeechTranscriptMatcher();

    test('低于 50% 时不通过', () {
      final result = matcher.evaluate(
        referenceText: 'The quick brown fox jumps over the lazy dog',
        transcript: 'quick fox over dog',
      );

      expect(result.status, SpeechPracticeAttemptStatus.belowThreshold);
      expect(result.score, closeTo(4 / 9, 0.001));
    });

    test('词形还原后可通过', () {
      final result = matcher.evaluate(
        referenceText: 'He walks to the stores',
        transcript: 'he walked to the store',
      );

      expect(result.status, SpeechPracticeAttemptStatus.passed);
      expect(result.matchedTokenCount, 5);
      expect(result.totalTargetTokenCount, 5);
    });

    test('没有英文时返回 noEnglishDetected', () {
      final result = matcher.evaluate(
        referenceText: 'This is a test sentence',
        transcript: '你好 123',
      );

      expect(result.status, SpeechPracticeAttemptStatus.noEnglishDetected);
      expect(result.recognizedEnglishTokenCount, 0);
    });

    test('乱序单词不会被全部命中', () {
      final result = matcher.evaluate(
        referenceText: 'the cat sat on the mat',
        transcript: 'mat the cat sat',
      );

      expect(result.matchedTokenCount, 3);
      expect(result.totalTargetTokenCount, 6);
    });

    test('生成 transcript 高亮片段', () {
      final result = matcher.evaluate(
        referenceText: 'I really like this idea',
        transcript: 'I really love this idea',
      );

      expect(result.transcriptSegments, isNotEmpty);
      expect(
        result.transcriptSegments.where((segment) => segment.isMatched).length,
        greaterThanOrEqualTo(4),
      );
      expect(
        result.referenceSegments.where((segment) => segment.isMatched).length,
        greaterThanOrEqualTo(4),
      );
    });
  });
}
