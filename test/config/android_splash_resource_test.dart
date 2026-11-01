/// Android 12+ 系统 SplashScreen 资源回归测试。
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Android 12+ splash icon is one density-independent 288dp canvas', () {
    const path = 'android/app/src/main/res/drawable/startup_splash_icon.xml';
    final icon = File(path).readAsStringSync();

    expect(icon, contains('android:width="288dp"'));
    expect(icon, contains('android:height="288dp"'));
    expect(icon, contains('android:viewportWidth="1536"'));
    expect(icon, contains('android:translateX="512"'));
    expect(icon, contains('android:translateY="512"'));

    for (final density in ['mdpi', 'hdpi', 'xhdpi', 'xxhdpi', 'xxxhdpi']) {
      expect(
        File(
          'android/app/src/main/res/drawable-$density/startup_splash_icon.png',
        ).existsSync(),
        isFalse,
        reason: 'Do not reintroduce density-specific splash bitmaps',
      );
    }

    final styles = File(
      'android/app/src/main/res/values-v31/styles.xml',
    ).readAsStringSync();
    expect(styles, contains('@drawable/startup_splash_icon'));
    expect(styles, isNot(contains('@drawable/startup_logo')));
  });
}
