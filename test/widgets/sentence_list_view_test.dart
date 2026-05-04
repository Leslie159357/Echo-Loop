/// SentenceListView 组件测试
///
/// 测试句子列表的渲染、交互和边界情况。
/// SentenceListView 是纯 UI 组件，不依赖 Riverpod Provider。
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:echo_loop/widgets/sentence_list_view.dart';
import 'package:echo_loop/models/sentence.dart';
import 'package:echo_loop/l10n/app_localizations.dart';

import '../helpers/mock_providers.dart';

/// 创建简易测试 App（SentenceListView 不需要 Riverpod）
Widget _buildTestWidget({
  required List<Sentence> sentences,
  int? currentIndex,
  Set<int> bookmarkedIndices = const {},
  bool showTranscript = true,
  bool autoScrollEnabled = true,
  Function(int)? onSentenceTap,
  Function(int)? onBookmarkToggle,
  VoidCallback? onUserScroll,
}) {
  return MaterialApp(
    locale: const Locale('en'),
    supportedLocales: const [Locale('en'), Locale('zh')],
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    home: Scaffold(
      body: SizedBox(
        height: 600,
        width: 400,
        child: SentenceListView(
          sentences: sentences,
          currentIndex: currentIndex,
          bookmarkedIndices: bookmarkedIndices,
          showTranscript: showTranscript,
          autoScrollEnabled: autoScrollEnabled,
          onSentenceTap: onSentenceTap ?? (_) {},
          onBookmarkToggle: onBookmarkToggle ?? (_) {},
          onUserScroll: onUserScroll,
        ),
      ),
    ),
  );
}

void main() {
  group('SentenceListView', () {
    group('渲染', () {
      testWidgets('正确显示句子列表（文本、序号）', (tester) async {
        final sentences = createTestSentences(count: 3);

        await tester.pumpWidget(_buildTestWidget(sentences: sentences));
        await tester.pumpAndSettle();

        // 验证句子文本
        expect(find.text('Test sentence number 1.'), findsOneWidget);
        expect(find.text('Test sentence number 2.'), findsOneWidget);
        expect(find.text('Test sentence number 3.'), findsOneWidget);

        // 验证序号（index + 1）
        expect(find.text('1'), findsOneWidget);
        expect(find.text('2'), findsOneWidget);
        expect(find.text('3'), findsOneWidget);
      });

      testWidgets('当前句子高亮显示', (tester) async {
        final sentences = createTestSentences(count: 3);

        await tester.pumpWidget(
          _buildTestWidget(sentences: sentences, currentIndex: 1),
        );
        await tester.pumpAndSettle();

        // 所有 Card 应该渲染
        final cards = tester.widgetList<Card>(find.byType(Card));
        expect(cards.length, 3);

        // 当前句子的 Card 应有高亮背景色（primaryContainer）
        final currentCard = cards.elementAt(1);
        expect(currentCard.color, isNotNull);

        // 其他 Card 使用默认背景（无自定义色）
        final normalCard = cards.elementAt(0);
        expect(normalCard.color, isNull);
      });

      testWidgets('书签图标状态正确（已书签/未书签）', (tester) async {
        final sentences = createTestSentences(count: 3);

        await tester.pumpWidget(
          _buildTestWidget(sentences: sentences, bookmarkedIndices: {0, 2}),
        );
        await tester.pumpAndSettle();

        // 有两个已书签的图标和一个未书签的图标
        expect(find.byIcon(Icons.bookmark), findsNWidgets(2));
        expect(find.byIcon(Icons.bookmark_border), findsOneWidget);
      });

      testWidgets('空句子列表不崩溃', (tester) async {
        await tester.pumpWidget(_buildTestWidget(sentences: const []));
        await tester.pumpAndSettle();

        // 组件应正常渲染
        expect(find.byType(SentenceListView), findsOneWidget);
      });
    });

    group('交互', () {
      testWidgets('点击句子触发 onSentenceTap 回调', (tester) async {
        final sentences = createTestSentences(count: 3);
        int? tappedIndex;

        await tester.pumpWidget(
          _buildTestWidget(
            sentences: sentences,
            onSentenceTap: (index) => tappedIndex = index,
          ),
        );
        await tester.pumpAndSettle();

        // 点击第二个句子
        await tester.tap(find.text('Test sentence number 2.'));
        await tester.pumpAndSettle();

        expect(tappedIndex, 1);
      });

      testWidgets('点击书签图标触发 onBookmarkToggle 回调', (tester) async {
        final sentences = createTestSentences(count: 3);
        int? toggledIndex;

        await tester.pumpWidget(
          _buildTestWidget(
            sentences: sentences,
            onBookmarkToggle: (index) => toggledIndex = index,
          ),
        );
        await tester.pumpAndSettle();

        // 点击第一个句子的书签图标
        final bookmarkIcons = find.byIcon(Icons.bookmark_border);
        await tester.tap(bookmarkIcons.first);
        await tester.pumpAndSettle();

        expect(toggledIndex, 0);
      });
    });
  });
}
