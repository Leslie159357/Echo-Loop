import 'package:echo_loop/features/custom_api/custom_cloud_transcription_service.dart';
import 'package:echo_loop/utils/srt_generator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('parseCustomTranscriptionResponse', () {
    test('parses diarized segments into timed subtitle sentences', () {
      final result = parseCustomTranscriptionResponse(
        {
          'text': 'Hello there. General Kenobi.',
          'segments': [
            {
              'speaker': 'A',
              'text': 'Hello there.',
              'start': 0.25,
              'end': 1.5,
            },
            {
              'speaker': 'B',
              'text': 'General Kenobi.',
              'start': 1.8,
              'end': 3.0,
            },
          ],
        },
        model: diarizedTranscriptionModel,
      );

      expect(result.sentences, hasLength(2));
      expect(result.sentences.first.text, 'Hello there.');
      expect(
        result.sentences.first.startTime,
        const Duration(milliseconds: 250),
      );
      expect(result.words, isNull);
      expect(result.fullText, 'Hello there. General Kenobi.');
    });

    test('parses Whisper segment and word timestamps', () {
      final result = parseCustomTranscriptionResponse(
        {
          'text': 'Hello world.',
          'segments': [
            {'text': 'Hello world.', 'start': 0.0, 'end': 1.2},
          ],
          'words': [
            {'word': 'Hello', 'start': 0.0, 'end': 0.5},
            {'word': 'world.', 'start': 0.6, 'end': 1.2},
          ],
        },
        model: wordTimestampTranscriptionModel,
      );

      expect(
        result.sentences.single.endTime,
        const Duration(milliseconds: 1200),
      );
      final words = result.words;
      expect(words, hasLength(2));
      expect(words?.last.word, 'world.');
      expect(words?.last.confidence, 1.0);
    });

    test('falls back to word bounds when Whisper omits segments', () {
      final result = parseCustomTranscriptionResponse(
        {
          'text': 'Short line.',
          'words': [
            {'word': 'Short', 'start': 2.0, 'end': 2.4},
            {'word': 'line.', 'start': 2.5, 'end': 3.0},
          ],
        },
        model: wordTimestampTranscriptionModel,
      );

      expect(result.sentences.single.startTime, const Duration(seconds: 2));
      expect(result.sentences.single.endTime, const Duration(seconds: 3));
    });
  });

  test('mergeShortTranscriptSentences merges adjacent short segments', () {
    final merged = mergeShortTranscriptSentences([
      const TranscriptSentence(
        text: 'One.',
        startTime: Duration.zero,
        endTime: Duration(seconds: 1),
      ),
      const TranscriptSentence(
        text: 'Two.',
        startTime: Duration(seconds: 1),
        endTime: Duration(seconds: 3),
      ),
      const TranscriptSentence(
        text: 'Three.',
        startTime: Duration(seconds: 3),
        endTime: Duration(seconds: 5),
      ),
    ]);

    expect(merged, hasLength(1));
    expect(merged.single.text, 'One. Two. Three.');
    expect(merged.single.endTime, const Duration(seconds: 5));
  });
}
