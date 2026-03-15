import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluency/widgets/blind_listen_briefing_sheet.dart';

import '../helpers/test_app.dart';

void main() {
  group('BlindListenBriefingSheet', () {
    testWidgets('首次学习模式 — 显示正确标题和提示', (tester) async {
      bool startPracticeCalled = false;

      await tester.pumpWidget(
        createTestApp(
          Builder(
            builder: (context) => ElevatedButton(
              onPressed: () {
                showBlindListenBriefingSheet(
                  context: context,
                  isFirstStudy: true,
                  onStartPractice: () {
                    startPracticeCalled = true;
                  },
                );
              },
              child: const Text('Open'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      // 验证标题和提示
      expect(find.text('Full Listening'), findsOneWidget);
      expect(find.text('First Study - Full Listening'), findsOneWidget);
      expect(
        find.text('Listen without subtitles, try to get the gist'),
        findsOneWidget,
      );
      expect(find.text('Start Practice'), findsOneWidget);

      // 点击开始练习
      await tester.tap(find.text('Start Practice'));
      await tester.pumpAndSettle();

      expect(startPracticeCalled, true);
    });

    testWidgets('复习模式 — 显示复习轮次', (tester) async {
      await tester.pumpWidget(
        createTestApp(
          Builder(
            builder: (context) => ElevatedButton(
              onPressed: () {
                showBlindListenBriefingSheet(
                  context: context,
                  isFirstStudy: false,
                  reviewRound: 3,
                  onStartPractice: () {},
                );
              },
              child: const Text('Open'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(find.text('Review 3 - Full Listening'), findsOneWidget);
    });

    testWidgets('显示音频时长', (tester) async {
      await tester.pumpWidget(
        createTestApp(
          Builder(
            builder: (context) => ElevatedButton(
              onPressed: () {
                showBlindListenBriefingSheet(
                  context: context,
                  isFirstStudy: true,
                  audioDuration: const Duration(minutes: 3, seconds: 45),
                  onStartPractice: () {},
                );
              },
              child: const Text('Open'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(find.text('3:45'), findsOneWidget);
    });

    testWidgets('无音频时长时不显示时长行', (tester) async {
      await tester.pumpWidget(
        createTestApp(
          Builder(
            builder: (context) => ElevatedButton(
              onPressed: () {
                showBlindListenBriefingSheet(
                  context: context,
                  isFirstStudy: true,
                  onStartPractice: () {},
                );
              },
              child: const Text('Open'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      // 无音频时长时不显示 music_note 图标
      expect(find.byIcon(Icons.music_note), findsNothing);
    });
  });
}
