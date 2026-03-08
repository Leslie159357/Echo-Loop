/// DifficultPracticeSettings 模型单元测试
///
/// 验证默认值、copyWith、JSON 序列化和 pause 计算逻辑。
import 'package:flutter_test/flutter_test.dart';
import 'package:fluency/models/difficult_practice_settings.dart';
import 'package:fluency/models/intensive_listen_settings.dart';

void main() {
  group('DifficultPracticeSettings', () {
    test('默认值', () {
      const settings = DifficultPracticeSettings();
      expect(settings.blindListenRepeatCount, 1);
      expect(settings.shadowReadingRepeatCount, 3);
      expect(settings.pauseMode, PauseMode.smart);
      expect(settings.fixedPauseSeconds, 5);
      expect(settings.pauseMultiplier, 2.0);
    });

    test('copyWith — 部分更新', () {
      const settings = DifficultPracticeSettings();
      final updated = settings.copyWith(
        blindListenRepeatCount: 5,
        shadowReadingRepeatCount: 2,
      );
      expect(updated.blindListenRepeatCount, 5);
      expect(updated.shadowReadingRepeatCount, 2);
      // 未更新字段保持默认
      expect(updated.pauseMode, PauseMode.smart);
      expect(updated.fixedPauseSeconds, 5);
    });

    test('copyWith — 更新停顿模式', () {
      const settings = DifficultPracticeSettings();
      final updated = settings.copyWith(
        pauseMode: PauseMode.fixed,
        fixedPauseSeconds: 10,
      );
      expect(updated.pauseMode, PauseMode.fixed);
      expect(updated.fixedPauseSeconds, 10);
    });

    group('toJson / fromJson', () {
      test('往返序列化', () {
        const original = DifficultPracticeSettings(
          blindListenRepeatCount: 3,
          shadowReadingRepeatCount: 5,
          pauseMode: PauseMode.multiplier,
          fixedPauseSeconds: 10,
          pauseMultiplier: 3.0,
        );

        final json = original.toJson();
        final restored = DifficultPracticeSettings.fromJson(json);

        expect(restored.blindListenRepeatCount, 3);
        expect(restored.shadowReadingRepeatCount, 5);
        expect(restored.pauseMode, PauseMode.multiplier);
        expect(restored.fixedPauseSeconds, 10);
        expect(restored.pauseMultiplier, 3.0);
      });

      test('非法值回退默认', () {
        final restored = DifficultPracticeSettings.fromJson({
          'blindListenRepeatCount': 'invalid',
          'shadowReadingRepeatCount': 99,
          'pauseMode': 'unknown',
          'fixedPauseSeconds': 999,
          'pauseMultiplier': 999.0,
        });

        expect(restored.blindListenRepeatCount, 1);
        expect(restored.shadowReadingRepeatCount, 10); // clamp to max
        expect(restored.pauseMode, PauseMode.smart);
        expect(restored.fixedPauseSeconds, 5);
        expect(restored.pauseMultiplier, 2.0);
      });

      test('空 JSON 回退默认', () {
        final restored = DifficultPracticeSettings.fromJson({});
        expect(restored.blindListenRepeatCount, 1);
        expect(restored.shadowReadingRepeatCount, 3);
        expect(restored.pauseMode, PauseMode.smart);
      });
    });

    group('calculateInterSentencePause', () {
      test('smart 模式 — max(句长, 1000ms)', () {
        const settings = DifficultPracticeSettings(pauseMode: PauseMode.smart);

        // 短句：返回最小 1000ms
        expect(
          settings.calculateInterSentencePause(
            const Duration(milliseconds: 500),
          ),
          const Duration(milliseconds: 1000),
        );

        // 长句：返回句长
        expect(
          settings.calculateInterSentencePause(
            const Duration(milliseconds: 3000),
          ),
          const Duration(milliseconds: 3000),
        );
      });

      test('fixed 模式 — 固定秒数', () {
        const settings = DifficultPracticeSettings(
          pauseMode: PauseMode.fixed,
          fixedPauseSeconds: 10,
        );

        expect(
          settings.calculateInterSentencePause(
            const Duration(milliseconds: 3000),
          ),
          const Duration(seconds: 10),
        );
      });

      test('multiplier 模式 — 句长 × 倍数', () {
        const settings = DifficultPracticeSettings(
          pauseMode: PauseMode.multiplier,
          pauseMultiplier: 2.0,
        );

        expect(
          settings.calculateInterSentencePause(
            const Duration(milliseconds: 2000),
          ),
          const Duration(milliseconds: 4000),
        );
      });

      test('multiplier 模式 — 至少 1000ms', () {
        const settings = DifficultPracticeSettings(
          pauseMode: PauseMode.multiplier,
          pauseMultiplier: 1.0,
        );

        expect(
          settings.calculateInterSentencePause(
            const Duration(milliseconds: 500),
          ),
          const Duration(milliseconds: 1000),
        );
      });

      test('smart 模式 — 零时长返回 1000ms', () {
        const settings = DifficultPracticeSettings(pauseMode: PauseMode.smart);
        expect(
          settings.calculateInterSentencePause(Duration.zero),
          const Duration(milliseconds: 1000),
        );
      });
    });
  });
}
