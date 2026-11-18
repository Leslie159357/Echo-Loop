import 'package:flutter_test/flutter_test.dart';
import 'package:echo_loop/models/speech_practice_models.dart';
import 'package:echo_loop/services/speech_practice_matcher.dart';

void main() {
  group('SpeechTranscriptMatcher（德语版）', () {
    final matcher = SpeechTranscriptMatcher();

    test('低于 50% 时不通过', () {
      final result = matcher.evaluate(
        referenceText: 'Der schnelle braune Fuchs springt über den faulen Hund',
        transcript: 'Fuchs springt über Hund',
      );

      expect(result.status, SpeechPracticeAttemptStatus.belowThreshold);
      expect(result.matchedTokenCount, 4);
      expect(result.totalTargetTokenCount, 9);
    });

    test('字面相同的德语句子可通过，忽略大小写与标点', () {
      final result = matcher.evaluate(
        referenceText: 'Ich heiße Franziska Binder.',
        transcript: 'ich heisse franziska binder',
      );

      // heiße 与 heisse 经 ß→ss 归一后一致
      expect(result.status, SpeechPracticeAttemptStatus.passed);
      expect(result.matchedTokenCount, 4);
      expect(result.totalTargetTokenCount, 4);
    });

    test('ß 与 ss 视为同一个词（ASR 两种写法都会出现）', () {
      final result = matcher.evaluate(
        referenceText: 'Wir gehen die Straße entlang.',
        transcript: 'wir gehen die Strasse entlang',
      );

      expect(result.status, SpeechPracticeAttemptStatus.passed);
      expect(result.matchedTokenCount, 5);
    });

    test('阿拉伯数字展开成德语数词后再比对', () {
      final result = matcher.evaluate(
        referenceText: 'Ich bin 21 Jahre alt.',
        transcript: 'ich bin einundzwanzig jahre alt',
      );

      expect(result.status, SpeechPracticeAttemptStatus.passed);
      expect(result.matchedTokenCount, 5);
      expect(result.totalTargetTokenCount, 5);
    });

    test('三位数字（价格/年份）也能展开', () {
      final result = matcher.evaluate(
        referenceText: 'Das kostet 199 Euro.',
        transcript: 'das kostet einhundertneunundneunzig euro',
      );

      expect(result.status, SpeechPracticeAttemptStatus.passed);
      expect(result.matchedTokenCount, 4);
    });

    test('没有识别出字母词时返回 noEnglishDetected', () {
      final result = matcher.evaluate(
        referenceText: 'Guten Morgen',
        transcript: '你好 123',
      );

      expect(result.status, SpeechPracticeAttemptStatus.noEnglishDetected);
      expect(result.recognizedEnglishTokenCount, 0);
    });

    test('乱序单词不会被全部命中', () {
      final result = matcher.evaluate(
        referenceText: 'die Katze sitzt auf der Matte',
        transcript: 'Matte die Katze sitzt',
      );

      expect(result.matchedTokenCount, 3);
      expect(result.totalTargetTokenCount, 6);
    });

    test('生成 transcript 高亮片段', () {
      final result = matcher.evaluate(
        referenceText: 'Ich mag diese Idee wirklich',
        transcript: 'ich mag diese Sache wirklich',
      );

      expect(result.transcriptSegments, isNotEmpty);
      expect(
        result.transcriptSegments.where((segment) => segment.isMatched).length,
        greaterThanOrEqualTo(3),
      );
      expect(
        result.referenceSegments.where((segment) => segment.isMatched).length,
        greaterThanOrEqualTo(3),
      );
    });
  });
}
