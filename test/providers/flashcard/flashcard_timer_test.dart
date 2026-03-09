/// FlashcardTimer 单元测试
///
/// 使用 fakeAsync 验证倒计时行为：启动、暂停、恢复、取消、到期回调。
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:fluency/providers/flashcard/flashcard_timer.dart';

void main() {
  group('FlashcardTimer', () {
    late FlashcardTimer timer;

    setUp(() {
      timer = FlashcardTimer();
    });

    tearDown(() {
      timer.cancel();
    });

    test('初始状态正确', () {
      expect(timer.remaining, 0);
      expect(timer.total, 0);
      expect(timer.isRunning, false);
      expect(timer.isPaused, false);
    });

    testWidgets('启动后每秒递减', (tester) async {
      final ticks = <int>[];
      timer.start(seconds: 3, onTick: (r) => ticks.add(r), onExpired: () {});

      expect(timer.isRunning, true);
      expect(timer.total, 3);
      expect(timer.remaining, 3);

      await tester.pump(const Duration(seconds: 1));
      expect(ticks.last, 2);

      await tester.pump(const Duration(seconds: 1));
      expect(ticks.last, 1);

      timer.cancel();
    });

    testWidgets('到期触发 onExpired 回调', (tester) async {
      var expired = false;
      timer.start(seconds: 2, onTick: (_) {}, onExpired: () => expired = true);

      await tester.pump(const Duration(seconds: 1));
      expect(expired, false);

      await tester.pump(const Duration(seconds: 1));
      expect(expired, true);
      expect(timer.isRunning, false);
    });

    testWidgets('暂停和恢复', (tester) async {
      final ticks = <int>[];
      timer.start(seconds: 5, onTick: (r) => ticks.add(r), onExpired: () {});

      await tester.pump(const Duration(seconds: 2));
      expect(timer.remaining, 3);

      timer.pause();
      expect(timer.isPaused, true);
      expect(timer.isRunning, false);

      // 暂停期间不再递减
      await tester.pump(const Duration(seconds: 2));
      expect(timer.remaining, 3);

      timer.resume(onTick: (r) => ticks.add(r), onExpired: () {});
      expect(timer.isPaused, false);
      expect(timer.isRunning, true);

      await tester.pump(const Duration(seconds: 1));
      expect(timer.remaining, 2);

      timer.cancel();
    });

    test('cancel 停止并重置状态', () {
      timer.start(seconds: 10, onTick: (_) {}, onExpired: () {});

      timer.cancel();
      expect(timer.isRunning, false);
      expect(timer.isPaused, false);
    });

    test('reset 清空所有状态', () {
      timer.start(seconds: 10, onTick: (_) {}, onExpired: () {});

      timer.reset();
      expect(timer.remaining, 0);
      expect(timer.total, 0);
      expect(timer.isRunning, false);
    });

    testWidgets('重复 start 先 cancel 旧 timer', (tester) async {
      var expiredCount = 0;
      timer.start(seconds: 2, onTick: (_) {}, onExpired: () => expiredCount++);

      // 1 秒后重新 start
      await tester.pump(const Duration(seconds: 1));
      timer.start(seconds: 3, onTick: (_) {}, onExpired: () => expiredCount++);

      expect(timer.total, 3);
      expect(timer.remaining, 3);

      // 旧 timer 的 onExpired 不应被触发
      await tester.pump(const Duration(seconds: 1));
      expect(expiredCount, 0);

      timer.cancel();
    });
  });
}
