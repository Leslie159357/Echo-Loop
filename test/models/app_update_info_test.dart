import 'package:flutter_test/flutter_test.dart';
import 'package:echo_loop/models/app_update_info.dart';

void main() {
  group('AppUpdateInfo.fromJson', () {
    test('解析完整 JSON', () {
      final json = {
        'latestVersion': '1.1.0',
        'minimumVersion': '1.0.0',
        'releaseNotes': {'en': 'Bug fixes', 'zh': '修复了 bug'},
        'downloadUrl': {
          'ios': 'https://testflight.apple.com/join/XXXX',
          'fallback': 'https://example.com/download',
        },
      };
      final info = AppUpdateInfo.fromJson(json);

      expect(info.latestVersion, '1.1.0');
      expect(info.minimumVersion, '1.0.0');
      expect(info.releaseNotes['en'], 'Bug fixes');
      expect(info.releaseNotes['zh'], '修复了 bug');
      expect(info.downloadUrl['ios'], 'https://testflight.apple.com/join/XXXX');
    });

    test('releaseNotes 缺失时降级为空 Map', () {
      final json = {
        'latestVersion': '1.1.0',
        'minimumVersion': '1.0.0',
      };
      final info = AppUpdateInfo.fromJson(json);

      expect(info.releaseNotes, isEmpty);
      expect(info.downloadUrl, isEmpty);
    });

    test('latestVersion 缺失时抛 FormatException', () {
      final json = {'minimumVersion': '1.0.0'};
      expect(() => AppUpdateInfo.fromJson(json), throwsFormatException);
    });

    test('minimumVersion 缺失时抛 FormatException', () {
      final json = {'latestVersion': '1.1.0'};
      expect(() => AppUpdateInfo.fromJson(json), throwsFormatException);
    });

    test('latestVersion 为空字符串时抛 FormatException', () {
      final json = {'latestVersion': '', 'minimumVersion': '1.0.0'};
      expect(() => AppUpdateInfo.fromJson(json), throwsFormatException);
    });

    test('latestVersion 为非 String 时抛 FormatException', () {
      final json = {'latestVersion': 123, 'minimumVersion': '1.0.0'};
      expect(() => AppUpdateInfo.fromJson(json), throwsFormatException);
    });

    test('releaseNotes 非 Map 类型时降级为空 Map', () {
      final json = {
        'latestVersion': '1.1.0',
        'minimumVersion': '1.0.0',
        'releaseNotes': 'not a map',
      };
      final info = AppUpdateInfo.fromJson(json);
      expect(info.releaseNotes, isEmpty);
    });
  });

  group('AppUpdateState', () {
    test('AppUpdateInitial 类型检查', () {
      const state = AppUpdateInitial();
      expect(state, isA<AppUpdateState>());
    });

    test('AppUpdateChecking 类型检查', () {
      const state = AppUpdateChecking();
      expect(state, isA<AppUpdateState>());
    });

    test('AppUpdateResult 携带数据', () {
      const state = AppUpdateResult(type: AppUpdateType.softUpdate);
      expect(state.type, AppUpdateType.softUpdate);
      expect(state.info, isNull);
    });

    test('AppUpdateResult 携带 info', () {
      const info = AppUpdateInfo(
        latestVersion: '1.1.0',
        minimumVersion: '1.0.0',
      );
      const state = AppUpdateResult(
        type: AppUpdateType.forceUpdate,
        info: info,
      );
      expect(state.info?.latestVersion, '1.1.0');
    });

    test('AppUpdateDismissed 类型检查', () {
      const state = AppUpdateDismissed();
      expect(state, isA<AppUpdateState>());
    });
  });
}
