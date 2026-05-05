import 'package:flutter_test/flutter_test.dart';
import 'package:echo_loop/models/app_update_info.dart';
import 'package:echo_loop/providers/app_update_provider.dart';
import 'package:echo_loop/utils/version_compare.dart';

void main() {
  group('AppUpdate._determineUpdateType', () {
    const info = AppUpdateInfo(
      latestVersion: '2.0.0',
      minimumVersion: '1.5.0',
    );

    test('低于最低版本时强制更新', () {
      expect(
        AppUpdate.determineUpdateType('1.0.0', info),
        AppUpdateType.forceUpdate,
      );
    });

    test('低于最新版但高于最低版本时软更新', () {
      expect(
        AppUpdate.determineUpdateType('1.5.0', info),
        AppUpdateType.softUpdate,
      );
    });

    test('高于最新版时无需更新', () {
      expect(
        AppUpdate.determineUpdateType('2.0.0', info),
        AppUpdateType.none,
      );
    });

    test('高于最新版时无需更新（更高版本）', () {
      expect(
        AppUpdate.determineUpdateType('3.0.0', info),
        AppUpdateType.none,
      );
    });

    test('恰好等于最低版本时软更新', () {
      expect(
        AppUpdate.determineUpdateType('1.5.0', info),
        AppUpdateType.softUpdate,
      );
    });

    test('在最低和最新之间时软更新', () {
      expect(
        AppUpdate.determineUpdateType('1.9.0', info),
        AppUpdateType.softUpdate,
      );
    });
  });

  group('版本比较辅助验证', () {
    test('compareVersions 正确比较 semver', () {
      expect(compareVersions('1.0.0', '1.5.0'), lessThan(0));
      expect(compareVersions('1.5.0', '2.0.0'), lessThan(0));
      expect(compareVersions('2.0.0', '2.0.0'), 0);
    });
  });

  group('构建号场景', () {
    test('本地 1.0.9+1 与远程 1.0.9+1 相等，无需更新', () {
      const info = AppUpdateInfo(
        latestVersion: '1.0.9+1',
        minimumVersion: '1.0.0',
      );
      expect(
        AppUpdate.determineUpdateType('1.0.9+1', info),
        AppUpdateType.none,
      );
    });

    test('本地 1.0.9+1 与远程 1.0.9+0 相等，无需更新', () {
      const info = AppUpdateInfo(
        latestVersion: '1.0.9',
        minimumVersion: '1.0.0',
      );
      expect(
        AppUpdate.determineUpdateType('1.0.9+1', info),
        AppUpdateType.none,
      );
    });

    test('本地 1.0.9+1 低于远程 1.0.9+2，需要更新', () {
      const info = AppUpdateInfo(
        latestVersion: '1.0.9+2',
        minimumVersion: '1.0.0',
      );
      expect(
        AppUpdate.determineUpdateType('1.0.9+1', info),
        AppUpdateType.softUpdate,
      );
    });

    test('本地 1.0.9+2 高于远程 1.0.9+1，无需更新', () {
      const info = AppUpdateInfo(
        latestVersion: '1.0.9+1',
        minimumVersion: '1.0.0',
      );
      expect(
        AppUpdate.determineUpdateType('1.0.9+2', info),
        AppUpdateType.none,
      );
    });

    test('本地 1.0.9 高于远程 1.0.8+5，无需更新（patch 高于构建号）', () {
      const info = AppUpdateInfo(
        latestVersion: '1.0.8+5',
        minimumVersion: '1.0.0',
      );
      expect(
        AppUpdate.determineUpdateType('1.0.9', info),
        AppUpdateType.none,
      );
    });

    test('本地 1.0.9+0 等于远程 1.0.9，无需更新', () {
      const info = AppUpdateInfo(
        latestVersion: '1.0.9',
        minimumVersion: '1.0.0',
      );
      expect(
        AppUpdate.determineUpdateType('1.0.9+0', info),
        AppUpdateType.none,
      );
    });

    test('buildNumber 为空时默认 +0，与远程 1.0.9 相等', () {
      const info = AppUpdateInfo(
        latestVersion: '1.0.9',
        minimumVersion: '1.0.0',
      );
      // 空 buildNumber 时 localVersion 会是 "1.0.9+0"
      expect(
        AppUpdate.determineUpdateType('1.0.9+0', info),
        AppUpdateType.none,
      );
    });
  });
}
