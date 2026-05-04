import 'package:flutter_test/flutter_test.dart';
import 'package:echo_loop/models/playback_settings.dart';

void main() {
  group('PlaybackSettings', () {
    group('默认值正确性', () {
      test('所有默认值符合预期', () {
        const settings = PlaybackSettings();

        expect(settings.loopEnabled, isFalse);
        expect(settings.loopCount, 3);
        expect(settings.pauseInterval, const Duration(seconds: 3));
        expect(settings.playbackSpeed, 1.0);
        expect(settings.singleSentenceMode, isFalse);
        expect(settings.showTranscript, isTrue);
        expect(settings.loopAudioEnabled, isFalse);
        expect(settings.loopAudio, 1);
        expect(settings.autoPlayNextSentenceEnabled, isTrue);
      });
    });

    group('toJson / fromJson 往返序列化', () {
      test('完整字段往返一致', () {
        const settings = PlaybackSettings(
          loopEnabled: true,
          loopCount: 5,
          pauseInterval: Duration(seconds: 10),
          playbackSpeed: 1.5,
          singleSentenceMode: true,
          showTranscript: false,
          loopAudioEnabled: true,
          loopAudio: 3,
          autoPlayNextSentenceEnabled: false,
        );
        final json = settings.toJson();
        final restored = PlaybackSettings.fromJson(json);

        expect(restored.loopEnabled, settings.loopEnabled);
        expect(restored.loopCount, settings.loopCount);
        expect(restored.pauseInterval, settings.pauseInterval);
        expect(restored.playbackSpeed, settings.playbackSpeed);
        expect(restored.singleSentenceMode, settings.singleSentenceMode);
        expect(restored.showTranscript, settings.showTranscript);
        expect(restored.loopAudioEnabled, settings.loopAudioEnabled);
        expect(restored.loopAudio, settings.loopAudio);
        expect(
          restored.autoPlayNextSentenceEnabled,
          settings.autoPlayNextSentenceEnabled,
        );
      });

      test('pauseInterval 以毫秒序列化', () {
        const settings = PlaybackSettings(pauseInterval: Duration(seconds: 5));
        final json = settings.toJson();
        expect(json['pauseInterval'], 5000);
      });
    });

    group('fromJson 范围校验', () {
      test('loopCount < 1 重置为默认 3', () {
        final settings = PlaybackSettings.fromJson({'loopCount': 0});
        expect(settings.loopCount, 3);
      });

      test('loopCount > 20 截断为 20', () {
        final settings = PlaybackSettings.fromJson({'loopCount': 100});
        expect(settings.loopCount, 20);
      });

      test('loopCount 负数重置为默认 3', () {
        final settings = PlaybackSettings.fromJson({'loopCount': -5});
        expect(settings.loopCount, 3);
      });

      test('loopCount 非 int 类型使用默认 3', () {
        final settings = PlaybackSettings.fromJson({'loopCount': 'abc'});
        expect(settings.loopCount, 3);
      });

      test('pauseInterval 负值截断为 0', () {
        final settings = PlaybackSettings.fromJson({'pauseInterval': -1000});
        expect(settings.pauseInterval, Duration.zero);
      });

      test('pauseInterval > 30 秒截断为 30 秒', () {
        final settings = PlaybackSettings.fromJson({
          'pauseInterval': 60000,
        }); // 60s
        expect(settings.pauseInterval, const Duration(seconds: 30));
      });

      test('loopAudio 负值重置为默认 1', () {
        final settings = PlaybackSettings.fromJson({'loopAudio': -1});
        expect(settings.loopAudio, 1);
      });

      test('loopAudio > 10 截断为 10', () {
        final settings = PlaybackSettings.fromJson({'loopAudio': 99});
        expect(settings.loopAudio, 10);
      });

      test('loopAudio = 0 允许（无限循环）', () {
        final settings = PlaybackSettings.fromJson({'loopAudio': 0});
        expect(settings.loopAudio, 0);
      });
    });

    group('copyWith', () {
      test('部分字段覆盖', () {
        const settings = PlaybackSettings();
        final copied = settings.copyWith(loopEnabled: true, playbackSpeed: 2.0);

        expect(copied.loopEnabled, isTrue);
        expect(copied.playbackSpeed, 2.0);
        // 未修改字段保持原值
        expect(copied.loopCount, 3);
        expect(copied.showTranscript, isTrue);
      });
    });
  });
}
