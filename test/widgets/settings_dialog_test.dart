/// SettingsDialog 组件测试
///
/// 测试播放设置对话框的渲染和交互。
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:echo_loop/widgets/settings_dialog.dart';
import 'package:echo_loop/models/playback_settings.dart';
import 'package:echo_loop/providers/settings_provider.dart';
import 'package:echo_loop/providers/listening_practice/listening_practice_provider.dart';
import 'package:echo_loop/providers/audio_engine/audio_engine_provider.dart';

import '../helpers/mock_providers.dart';
import '../helpers/test_app.dart';

/// 辅助函数：打开 SettingsDialog
Widget _buildSettingsDialogTest({
  ListeningPracticeState? practiceState,
  List<Override>? overrides,
}) {
  final defaultOverrides = <Override>[
    appSettingsProvider.overrideWith(() => TestAppSettings()),
    listeningPracticeProvider.overrideWith(
      () => TestListeningPractice(
        practiceState ?? const ListeningPracticeState(),
      ),
    ),
    audioEngineProvider.overrideWith(() => TestAudioEngine()),
  ];

  return createTestApp(
    Builder(
      builder: (context) {
        // 直接渲染 Dialog 内容
        return const SettingsDialog();
      },
    ),
    overrides: overrides ?? defaultOverrides,
  );
}

void main() {
  group('SettingsDialog', () {
    group('渲染', () {
      testWidgets('显示句子循环设置区域', (tester) async {
        await tester.pumpWidget(_buildSettingsDialogTest());
        await tester.pumpAndSettle();

        // 句子循环开关标题
        expect(find.text('Sentence Repeat'), findsOneWidget);
        // 自动播放下一句开关
        expect(find.text('Auto Play Next Sentence'), findsOneWidget);
      });

      testWidgets('显示音频循环设置区域', (tester) async {
        await tester.pumpWidget(_buildSettingsDialogTest());
        await tester.pumpAndSettle();

        expect(find.text('Audio Loop'), findsOneWidget);
      });

      testWidgets('循环关闭时不显示子设置', (tester) async {
        // 默认 loopEnabled=false
        await tester.pumpWidget(_buildSettingsDialogTest());
        await tester.pumpAndSettle();

        // 循环次数和间隔时间不应显示
        expect(find.text('Repeat Count'), findsNothing);
        expect(find.text('Interval (seconds)'), findsNothing);
      });

      testWidgets('循环开启时显示子设置', (tester) async {
        await tester.pumpWidget(
          _buildSettingsDialogTest(
            practiceState: const ListeningPracticeState(
              settings: PlaybackSettings(loopEnabled: true),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // 循环次数和间隔时间应显示
        expect(find.text('Repeat Count'), findsOneWidget);
        expect(find.text('Interval (seconds)'), findsOneWidget);
      });

      testWidgets('音频循环关闭时不显示子设置', (tester) async {
        // 默认 loopAudioEnabled=false
        await tester.pumpWidget(_buildSettingsDialogTest());
        await tester.pumpAndSettle();

        expect(find.text('Loop Count'), findsNothing);
      });

      testWidgets('音频循环开启时显示循环次数', (tester) async {
        await tester.pumpWidget(
          _buildSettingsDialogTest(
            practiceState: const ListeningPracticeState(
              settings: PlaybackSettings(loopAudioEnabled: true),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Loop Count'), findsOneWidget);
      });
    });

    group('交互', () {
      testWidgets('切换句子循环开关', (tester) async {
        await tester.pumpWidget(_buildSettingsDialogTest());
        await tester.pumpAndSettle();

        // 找到句子循环开关（第二个 Switch，第一个是自动播放下一句）
        final switches = find.byType(Switch);
        expect(switches, findsAtLeast(2));

        // 点击句子循环开关（第二个 Switch）
        await tester.tap(switches.at(1));
        await tester.pumpAndSettle();

        // 切换后应显示子设置
        expect(find.text('Repeat Count'), findsOneWidget);
        expect(find.text('Interval (seconds)'), findsOneWidget);
      });

      testWidgets('切换音频循环开关', (tester) async {
        await tester.pumpWidget(_buildSettingsDialogTest());
        await tester.pumpAndSettle();

        // 音频循环开关是第三个 Switch
        final switches = find.byType(Switch);
        expect(switches, findsAtLeast(3));

        await tester.tap(switches.at(2));
        await tester.pumpAndSettle();

        // 切换后应显示循环次数
        expect(find.text('Loop Count'), findsOneWidget);
      });

      testWidgets('关闭按钮可以关闭对话框', (tester) async {
        await tester.pumpWidget(
          createTestApp(
            Builder(
              builder: (context) {
                return ElevatedButton(
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (context) => const SettingsDialog(),
                    );
                  },
                  child: const Text('Open'),
                );
              },
            ),
          ),
        );
        await tester.pumpAndSettle();

        // 打开对话框
        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();

        expect(find.text('Settings'), findsOneWidget);

        // 点击关闭按钮
        await tester.tap(find.byIcon(Icons.close));
        await tester.pumpAndSettle();

        // 对话框应已关闭
        expect(find.text('Sentence Repeat'), findsNothing);
      });
    });
  });
}
