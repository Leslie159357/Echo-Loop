import 'package:flutter_test/flutter_test.dart';
import 'package:echo_loop/models/audio_item.dart';
import 'package:echo_loop/models/sentence.dart';
import 'package:echo_loop/models/playback_settings.dart';
import 'package:echo_loop/models/listening_practice_state.dart';

void main() {
  group('ListeningPracticeState', () {
    final sampleAudio = AudioItem(
      id: 'audio-1',
      name: '测试音频',
      audioPath: 'audios/test.mp3',
      addedDate: DateTime(2026, 1, 15),
    );

    List<Sentence> createSentences(int count) {
      return List.generate(
        count,
        (i) => Sentence(
          index: i,
          text: '句子 $i',
          startTime: Duration(seconds: i * 5),
          endTime: Duration(seconds: (i + 1) * 5),
        ),
      );
    }

    group('默认值', () {
      test('所有默认值符合预期', () {
        const state = ListeningPracticeState();

        expect(state.currentAudioItem, isNull);
        expect(state.sentences, isEmpty);
        expect(state.currentFullIndex, isNull);
        expect(state.currentBookmarkIndex, isNull);
        expect(state.lastPlayedFullIndex, isNull);
        expect(state.lastPlayedBookmarkIndex, isNull);
        expect(state.settings, isA<PlaybackSettings>());
        expect(state.playlistMode, PlaylistMode.full);
        expect(state.bookmarkedIndices, isEmpty);
        expect(state.autoScrollEnabled, isTrue);
        expect(state.isLoading, isFalse);
      });
    });

    group('copyWith 正常字段', () {
      test('部分字段覆盖', () {
        const state = ListeningPracticeState();
        final sentences = createSentences(3);
        final copied = state.copyWith(
          currentAudioItem: sampleAudio,
          sentences: sentences,
          currentFullIndex: 1,
          isLoading: true,
        );

        expect(copied.currentAudioItem, sampleAudio);
        expect(copied.sentences, sentences);
        expect(copied.currentFullIndex, 1);
        expect(copied.isLoading, isTrue);
        // 未修改保持原值
        expect(copied.playlistMode, PlaylistMode.full);
        expect(copied.autoScrollEnabled, isTrue);
      });
    });

    group('copyWith clear* 标志', () {
      test('clearCurrentAudioItem 设置为 null', () {
        final state = ListeningPracticeState(currentAudioItem: sampleAudio);
        final copied = state.copyWith(clearCurrentAudioItem: true);

        expect(copied.currentAudioItem, isNull);
      });

      test('clearCurrentFullIndex 设置为 null', () {
        const state = ListeningPracticeState(currentFullIndex: 5);
        final copied = state.copyWith(clearCurrentFullIndex: true);

        expect(copied.currentFullIndex, isNull);
      });

      test('clearCurrentBookmarkIndex 设置为 null', () {
        const state = ListeningPracticeState(currentBookmarkIndex: 3);
        final copied = state.copyWith(clearCurrentBookmarkIndex: true);

        expect(copied.currentBookmarkIndex, isNull);
      });

      test('clearLastPlayedFullIndex 设置为 null', () {
        const state = ListeningPracticeState(lastPlayedFullIndex: 2);
        final copied = state.copyWith(clearLastPlayedFullIndex: true);

        expect(copied.lastPlayedFullIndex, isNull);
      });

      test('clearLastPlayedBookmarkIndex 设置为 null', () {
        const state = ListeningPracticeState(lastPlayedBookmarkIndex: 4);
        final copied = state.copyWith(clearLastPlayedBookmarkIndex: true);

        expect(copied.lastPlayedBookmarkIndex, isNull);
      });

      test('clear 标志优先于传入值', () {
        const state = ListeningPracticeState(currentFullIndex: 5);
        final copied = state.copyWith(
          currentFullIndex: 10,
          clearCurrentFullIndex: true,
        );
        // clear 标志优先
        expect(copied.currentFullIndex, isNull);
      });
    });

    group('bookmarkedSentences 计算属性', () {
      test('正确过滤书签句子', () {
        final sentences = createSentences(5);
        final state = ListeningPracticeState(
          sentences: sentences,
          bookmarkedIndices: {0, 2, 4},
        );
        final bookmarked = state.bookmarkedSentences;

        expect(bookmarked.length, 3);
        expect(bookmarked[0].index, 0);
        expect(bookmarked[1].index, 2);
        expect(bookmarked[2].index, 4);
      });

      test('无书签时返回空列表', () {
        final sentences = createSentences(3);
        final state = ListeningPracticeState(sentences: sentences);

        expect(state.bookmarkedSentences, isEmpty);
      });

      test('无句子时返回空列表', () {
        const state = ListeningPracticeState(bookmarkedIndices: {0, 1});

        expect(state.bookmarkedSentences, isEmpty);
      });
    });

    group('currentSentence', () {
      test('full 模式下根据 currentFullIndex 返回句子', () {
        final sentences = createSentences(5);
        final state = ListeningPracticeState(
          sentences: sentences,
          currentFullIndex: 2,
          playlistMode: PlaylistMode.full,
        );

        expect(state.currentSentence, isNotNull);
        expect(state.currentSentence!.index, 2);
      });

      test('currentFullIndex 为 null 时返回 null', () {
        final sentences = createSentences(3);
        final state = ListeningPracticeState(sentences: sentences);

        expect(state.currentSentence, isNull);
      });

      test('currentFullIndex 超出范围时返回 null', () {
        final sentences = createSentences(3);
        const state = ListeningPracticeState(currentFullIndex: 10);
        // 用 copyWith 设置句子，因为 const 构造函数不能用非 const 参数
        final stateWithSentences = state.copyWith(sentences: sentences);

        expect(stateWithSentences.currentSentence, isNull);
      });
    });

    group('hasAudio / hasSentences', () {
      test('hasAudio 有音频时返回 true', () {
        final state = ListeningPracticeState(currentAudioItem: sampleAudio);
        expect(state.hasAudio, isTrue);
      });

      test('hasAudio 无音频时返回 false', () {
        const state = ListeningPracticeState();
        expect(state.hasAudio, isFalse);
      });

      test('hasSentences 有句子时返回 true', () {
        final state = ListeningPracticeState(sentences: createSentences(1));
        expect(state.hasSentences, isTrue);
      });

      test('hasSentences 无句子时返回 false', () {
        const state = ListeningPracticeState();
        expect(state.hasSentences, isFalse);
      });
    });
  });
}
