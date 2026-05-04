import 'package:flutter_test/flutter_test.dart';
import 'package:echo_loop/services/subtitle_parser.dart';

void main() {
  group('SubtitleParser.formatDuration', () {
    test('小于 1 小时格式 M:SS', () {
      expect(
        SubtitleParser.formatDuration(const Duration(minutes: 5, seconds: 30)),
        '5:30',
      );
    });

    test('分钟数不补零', () {
      expect(
        SubtitleParser.formatDuration(const Duration(minutes: 1, seconds: 5)),
        '1:05',
      );
    });

    test('秒数补零', () {
      expect(
        SubtitleParser.formatDuration(const Duration(minutes: 3, seconds: 2)),
        '3:02',
      );
    });

    test('超过 1 小时格式 H:MM:SS', () {
      expect(
        SubtitleParser.formatDuration(
          const Duration(hours: 1, minutes: 5, seconds: 30),
        ),
        '1:05:30',
      );
    });

    test('多小时', () {
      expect(
        SubtitleParser.formatDuration(
          const Duration(hours: 2, minutes: 30, seconds: 0),
        ),
        '2:30:00',
      );
    });

    test('零值', () {
      expect(SubtitleParser.formatDuration(Duration.zero), '0:00');
    });

    test('仅有秒数', () {
      expect(
        SubtitleParser.formatDuration(const Duration(seconds: 45)),
        '0:45',
      );
    });

    test('正好 1 小时', () {
      expect(
        SubtitleParser.formatDuration(const Duration(hours: 1)),
        '1:00:00',
      );
    });
  });
}
