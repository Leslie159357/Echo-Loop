import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:echo_loop/models/retell_settings.dart';
import 'package:echo_loop/models/sentence.dart';
import 'package:echo_loop/widgets/common/masked_sentence_tile.dart';

import '../helpers/test_app.dart';

/// 构造测试用 Sentence
Sentence _sentence(String text, {int index = 0}) {
  return Sentence(
    index: index,
    text: text,
    startTime: Duration.zero,
    endTime: const Duration(seconds: 5),
  );
}

/// 包装 MaskedSentenceTile 用于测试
Widget _buildTile({
  required Sentence sentence,
  RetellDisplayMode displayMode = RetellDisplayMode.keywordsOnly,
  Set<int> keywordIndices = const {},
  bool isPlayingSentence = false,
}) {
  return createTestApp(
    MaskedSentenceTile(
      sentence: sentence,
      displayMode: displayMode,
      keywordIndices: keywordIndices,
      isPlayingSentence: isPlayingSentence,
    ),
  );
}

void main() {
  group('MaskedSentenceTile 蒙版连续显示', () {
    testWidgets('hideAll 模式：每个词独立渲染但视觉连续', (tester) async {
      await tester.pumpWidget(_buildTile(
        sentence: _sentence('I love you'),
        displayMode: RetellDisplayMode.hideAll,
      ));
      await tester.pumpAndSettle();

      // 每个词仍独立渲染（保持布局稳定）
      expect(find.text('I'), findsOneWidget);
      expect(find.text('love'), findsOneWidget);
      expect(find.text('you'), findsOneWidget);

      // 连续遮盖词之间有桥接色块（通过 Stack + Positioned 溢出绘制）
      // 验证存在 Stack（clipBehavior: Clip.none）
      final stacks = tester.widgetList<Stack>(find.byType(Stack));
      // "I" 和 "love" 都有 isNextMasked=true，所以有 2 个 Stack
      expect(stacks.where((s) => s.clipBehavior == Clip.none).length, 2);
    });

    testWidgets('showAll 模式：每个词独立显示，无 Stack 溢出', (tester) async {
      await tester.pumpWidget(_buildTile(
        sentence: _sentence('I love you'),
        displayMode: RetellDisplayMode.showAll,
      ));
      await tester.pumpAndSettle();

      expect(find.text('I'), findsOneWidget);
      expect(find.text('love'), findsOneWidget);
      expect(find.text('you'), findsOneWidget);

      // showAll 模式无遮盖，不应有溢出 Stack
      final stacks = tester.widgetList<Stack>(find.byType(Stack));
      expect(stacks.where((s) => s.clipBehavior == Clip.none).length, 0);
    });

    testWidgets('keywordsOnly 模式：连续遮盖词桥接、交替词无桥接', (tester) async {
      // "I love you very much" → 关键词索引 {1}（"love"可见）
      // 遮盖: [0], [2], [3], [4]
      // 桥接: [2]→[3], [3]→[4]（2 个桥接）
      await tester.pumpWidget(_buildTile(
        sentence: _sentence('I love you very much'),
        displayMode: RetellDisplayMode.keywordsOnly,
        keywordIndices: {1},
      ));
      await tester.pumpAndSettle();

      // 所有词独立存在
      expect(find.text('I'), findsOneWidget);
      expect(find.text('love'), findsOneWidget);
      expect(find.text('you'), findsOneWidget);
      expect(find.text('very'), findsOneWidget);
      expect(find.text('much'), findsOneWidget);

      // "you"→"very" 和 "very"→"much" 有桥接 Stack
      final stacks = tester.widgetList<Stack>(find.byType(Stack));
      expect(stacks.where((s) => s.clipBehavior == Clip.none).length, 2);
    });

    testWidgets('切换模式时 Wrap 子元素数量不变', (tester) async {
      // 先 hideAll
      await tester.pumpWidget(_buildTile(
        sentence: _sentence('A B C D E'),
        displayMode: RetellDisplayMode.hideAll,
      ));
      await tester.pumpAndSettle();

      final wrapHideAll = tester.widget<Wrap>(find.byType(Wrap));
      final hideAllCount = wrapHideAll.children.length;

      // 切换到 showAll
      await tester.pumpWidget(_buildTile(
        sentence: _sentence('A B C D E'),
        displayMode: RetellDisplayMode.showAll,
      ));
      await tester.pumpAndSettle();

      final wrapShowAll = tester.widget<Wrap>(find.byType(Wrap));
      final showAllCount = wrapShowAll.children.length;

      // 子元素数量应相同（5 个词 = 5 个子元素）
      expect(hideAllCount, showAllCount);
      expect(hideAllCount, 5);
    });
  });
}
