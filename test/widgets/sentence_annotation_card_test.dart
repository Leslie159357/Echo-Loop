import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluency/widgets/intensive_listen/sentence_annotation_card.dart';
import 'package:fluency/widgets/common/ai_content_section.dart';

import '../helpers/test_app.dart';

void main() {
  group('SentenceAnnotationCard', () {
    testWidgets('显示句子文本和难句标记', (tester) async {
      await tester.pumpWidget(
        createTestApp(
          SentenceAnnotationCard(
            text: 'Hello world',
            isDifficult: false,
            onToggle: () {},
          ),
        ),
      );

      // 句子文本通过 RichText 渲染，验证 RichText 存在
      expect(find.byType(RichText), findsWidgets);

      // 非难句状态
      expect(find.byIcon(Icons.star_border), findsOneWidget);

      // 无 AI 回调和缓存时，翻译和解析区域不显示
      expect(find.text('Translation'), findsNothing);
      expect(find.text('Analysis'), findsNothing);
    });

    testWidgets('难句标记状态正确显示', (tester) async {
      await tester.pumpWidget(
        createTestApp(
          SentenceAnnotationCard(
            text: 'Difficult sentence',
            isDifficult: true,
            onToggle: () {},
          ),
        ),
      );

      expect(find.byIcon(Icons.star), findsOneWidget);
    });

    testWidgets('自动标记分支显示自动文案', (tester) async {
      await tester.pumpWidget(
        createTestApp(
          SentenceAnnotationCard(
            text: 'Auto difficult',
            isDifficult: true,
            showAutoMarkedLabel: true,
            onToggle: () {},
          ),
        ),
      );

      expect(find.text('Auto-marked difficult, tap to undo'), findsOneWidget);
    });

    testWidgets('已标记分支显示普通难句文案', (tester) async {
      await tester.pumpWidget(
        createTestApp(
          SentenceAnnotationCard(
            text: 'Marked difficult',
            isDifficult: true,
            showAutoMarkedLabel: false,
            onToggle: () {},
          ),
        ),
      );

      expect(find.text('Marked difficult, tap to undo'), findsOneWidget);
    });

    testWidgets('点击难句标记触发 onToggle', (tester) async {
      var toggled = false;
      await tester.pumpWidget(
        createTestApp(
          SentenceAnnotationCard(
            text: 'Test',
            isDifficult: false,
            onToggle: () => toggled = true,
          ),
        ),
      );

      // 点击星标区域
      await tester.tap(find.byIcon(Icons.star_border));
      expect(toggled, isTrue);
    });

    testWidgets('cachedTranslation 直接展示', (tester) async {
      await tester.pumpWidget(
        createTestApp(
          SentenceAnnotationCard(
            text: 'Hello',
            isDifficult: false,
            onToggle: () {},
            cachedTranslation: '你好',
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.text('你好'), findsOneWidget);
    });

    testWidgets('cachedAnalysis 直接展示', (tester) async {
      await tester.pumpWidget(
        createTestApp(
          SentenceAnnotationCard(
            text: 'Hello',
            isDifficult: false,
            onToggle: () {},
            cachedAnalysis: '语法分析\n词汇分析\n用法分析',
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.text('语法分析'), findsOneWidget);
      expect(find.text('词汇分析'), findsOneWidget);
      expect(find.text('用法分析'), findsOneWidget);
    });

    testWidgets('有 AI 回调时翻译和解析区域包含正确图标', (tester) async {
      await tester.pumpWidget(
        createTestApp(
          SentenceAnnotationCard(
            text: 'Test',
            isDifficult: false,
            onToggle: () {},
            onRequestTranslation: () async => '翻译',
            onRequestAnalysis: () async => '语法\n词汇\n用法',
          ),
        ),
      );

      expect(find.byIcon(Icons.translate), findsOneWidget);
      expect(find.byIcon(Icons.auto_awesome), findsOneWidget);
    });

    testWidgets('无 AI 回调和缓存时不显示翻译和解析区域', (tester) async {
      await tester.pumpWidget(
        createTestApp(
          SentenceAnnotationCard(
            text: 'Test',
            isDifficult: false,
            onToggle: () {},
          ),
        ),
      );

      expect(find.byIcon(Icons.translate), findsNothing);
      expect(find.byIcon(Icons.auto_awesome), findsNothing);
      expect(find.byType(AiContentSection), findsNothing);
    });
  });

  group('SentenceAnnotationCard — AI 区域可见性', () {
    testWidgets('仅有 onRequestTranslation 时只显示翻译区域', (tester) async {
      await tester.pumpWidget(
        createTestApp(
          SentenceAnnotationCard(
            text: 'Test',
            isDifficult: false,
            onToggle: () {},
            onRequestTranslation: () async => '翻译结果',
          ),
        ),
      );

      expect(find.byIcon(Icons.translate), findsOneWidget);
      expect(find.byIcon(Icons.auto_awesome), findsNothing);
    });

    testWidgets('仅有 onRequestAnalysis 时只显示解析区域', (tester) async {
      await tester.pumpWidget(
        createTestApp(
          SentenceAnnotationCard(
            text: 'Test',
            isDifficult: false,
            onToggle: () {},
            onRequestAnalysis: () async => '语法\n词汇\n用法',
          ),
        ),
      );

      expect(find.byIcon(Icons.translate), findsNothing);
      expect(find.byIcon(Icons.auto_awesome), findsOneWidget);
    });

    testWidgets('仅有 cachedTranslation 时显示翻译区域', (tester) async {
      await tester.pumpWidget(
        createTestApp(
          SentenceAnnotationCard(
            text: 'Test',
            isDifficult: false,
            onToggle: () {},
            cachedTranslation: '缓存翻译',
          ),
        ),
      );

      expect(find.byIcon(Icons.translate), findsOneWidget);
      expect(find.byIcon(Icons.auto_awesome), findsNothing);
    });

    testWidgets('仅有 cachedAnalysis 时显示解析区域', (tester) async {
      await tester.pumpWidget(
        createTestApp(
          SentenceAnnotationCard(
            text: 'Test',
            isDifficult: false,
            onToggle: () {},
            cachedAnalysis: '语法\n词汇\n用法',
          ),
        ),
      );

      expect(find.byIcon(Icons.translate), findsNothing);
      expect(find.byIcon(Icons.auto_awesome), findsOneWidget);
    });
  });

  group('SentenceAnnotationCard — AI 展开交互', () {
    testWidgets('点击翻译区域触发 onRequestTranslation 并展示结果', (tester) async {
      var requested = false;
      final completer = Completer<String>();

      await tester.pumpWidget(
        createTestApp(
          SentenceAnnotationCard(
            text: 'Test sentence',
            isDifficult: false,
            onToggle: () {},
            onRequestTranslation: () {
              requested = true;
              return completer.future;
            },
            onRequestAnalysis: () async => '语法\n词汇\n用法',
          ),
        ),
      );

      // 初始状态：折叠，无翻译内容
      expect(find.text('这是翻译结果'), findsNothing);

      // 点击翻译区域标题
      await tester.tap(find.byIcon(Icons.translate));
      await tester.pump();

      // 验证请求已触发
      expect(requested, isTrue);

      // 返回结果
      completer.complete('这是翻译结果');
      await tester.pumpAndSettle();

      // 翻译内容已展示
      expect(find.text('这是翻译结果'), findsOneWidget);
    });

    testWidgets('点击解析区域触发 onRequestAnalysis 并展示结果', (tester) async {
      var requested = false;
      final completer = Completer<String>();

      await tester.pumpWidget(
        createTestApp(
          SentenceAnnotationCard(
            text: 'Test sentence',
            isDifficult: false,
            onToggle: () {},
            onRequestTranslation: () async => '翻译',
            onRequestAnalysis: () {
              requested = true;
              return completer.future;
            },
          ),
        ),
      );

      // 点击解析区域标题
      await tester.tap(find.byIcon(Icons.auto_awesome));
      await tester.pump();

      expect(requested, isTrue);

      // 返回结果
      completer.complete('语法结果\n词汇结果\n用法结果');
      await tester.pumpAndSettle();

      // 解析内容已展示
      expect(find.text('语法结果'), findsOneWidget);
      expect(find.text('词汇结果'), findsOneWidget);
      expect(find.text('用法结果'), findsOneWidget);
    });

    testWidgets('翻译请求失败显示错误状态和重试按钮', (tester) async {
      var callCount = 0;

      await tester.pumpWidget(
        createTestApp(
          SentenceAnnotationCard(
            text: 'Test',
            isDifficult: false,
            onToggle: () {},
            onRequestTranslation: () {
              callCount++;
              return Future.error('network error');
            },
            onRequestAnalysis: () async => '语法\n词汇\n用法',
          ),
        ),
      );

      // 点击翻译区域
      await tester.tap(find.byIcon(Icons.translate));
      await tester.pumpAndSettle();

      // 显示错误状态
      expect(find.byIcon(Icons.error_outline), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
      expect(callCount, 1);

      // 点击重试
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();

      // 重试触发了新请求
      expect(callCount, 2);
    });

    testWidgets('展开后再次点击可折叠', (tester) async {
      await tester.pumpWidget(
        createTestApp(
          SentenceAnnotationCard(
            text: 'Test',
            isDifficult: false,
            onToggle: () {},
            onRequestTranslation: () async => '翻译内容',
            onRequestAnalysis: () async => '语法\n词汇\n用法',
          ),
        ),
      );

      // 展开翻译
      await tester.tap(find.byIcon(Icons.translate));
      await tester.pumpAndSettle();
      expect(find.text('翻译内容'), findsOneWidget);

      // 再次点击折叠
      await tester.tap(find.byIcon(Icons.translate));
      await tester.pumpAndSettle();
      expect(find.text('翻译内容'), findsNothing);
    });

    testWidgets('翻译和解析可独立展开', (tester) async {
      await tester.pumpWidget(
        createTestApp(
          SentenceAnnotationCard(
            text: 'Test',
            isDifficult: false,
            onToggle: () {},
            onRequestTranslation: () async => '翻译OK',
            onRequestAnalysis: () async => '语法OK\n词汇OK\n用法OK',
          ),
        ),
      );

      // 展开翻译
      await tester.tap(find.byIcon(Icons.translate));
      await tester.pumpAndSettle();
      expect(find.text('翻译OK'), findsOneWidget);
      expect(find.text('语法OK'), findsNothing);

      // 展开解析
      await tester.tap(find.byIcon(Icons.auto_awesome));
      await tester.pumpAndSettle();
      expect(find.text('翻译OK'), findsOneWidget);
      expect(find.text('语法OK'), findsOneWidget);
      expect(find.text('词汇OK'), findsOneWidget);
      expect(find.text('用法OK'), findsOneWidget);
    });

    testWidgets('cachedTranslation 自动展开且不触发 onRequest', (tester) async {
      var requested = false;

      await tester.pumpWidget(
        createTestApp(
          SentenceAnnotationCard(
            text: 'Test',
            isDifficult: false,
            onToggle: () {},
            cachedTranslation: '已缓存的翻译',
            onRequestTranslation: () {
              requested = true;
              return Future.value('新翻译');
            },
          ),
        ),
      );

      await tester.pumpAndSettle();

      // 缓存内容直接展示
      expect(find.text('已缓存的翻译'), findsOneWidget);
      // 未触发网络请求
      expect(requested, isFalse);
    });
  });
}
