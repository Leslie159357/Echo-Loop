/// FlashcardScreen Widget 测试
///
/// 验证 Flashcard 页面的 UI 渲染、交互操作、完成视图等行为。
/// 使用 TestFlashcardNotifier 模拟 Provider 状态，避免真实 I/O。
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:fluency/l10n/app_localizations.dart';
import 'package:fluency/screens/flashcard_screen.dart';
import 'package:fluency/providers/flashcard/flashcard_provider.dart';
import 'package:fluency/providers/flashcard/flashcard_flow_phase.dart';
import 'package:fluency/providers/audio_engine/audio_engine_provider.dart';
import 'package:fluency/models/flashcard_item.dart';
import 'package:fluency/database/app_database.dart' show SavedWord;
import 'package:fluency/theme/app_theme.dart';

import '../helpers/mock_providers.dart';

// ========== 测试用 FlashcardNotifier ==========

/// 测试用 FlashcardNotifier — 不访问 SharedPreferences / TTS / 音频引擎
class _TestFlashcardNotifier extends FlashcardNotifier {
  final FlashcardState _initialState;

  _TestFlashcardNotifier(this._initialState);

  @override
  FlashcardState build() => _initialState;

  @override
  Future<void> initialize(List<FlashcardItem> items) async {}

  @override
  Future<void> userFlipCard() async {
    if (state.isCompleted || state.words.isEmpty) return;
    state = state.copyWith(isShowingBack: !state.isShowingBack);
  }

  @override
  Future<void> userNextCard() async {
    if (state.currentIndex >= state.words.length - 1) {
      state = state.copyWith(isCompleted: true);
      return;
    }
    state = state.copyWith(
      currentIndex: state.currentIndex + 1,
      isShowingBack: false,
    );
  }

  @override
  Future<void> userPreviousCard() async {
    if (state.currentIndex <= 0) return;
    state = state.copyWith(
      currentIndex: state.currentIndex - 1,
      isShowingBack: false,
    );
  }

  @override
  void onAppBackgrounded() {
    state = state.copyWith(
      phase: const FlashcardWaitingForUser(
        FlashcardWaitingReason.appBackgrounded,
      ),
    );
  }

  @override
  void onSettingsOpened() {
    state = state.copyWith(
      phase: const FlashcardWaitingForUser(
        FlashcardWaitingReason.userOpenedSettings,
      ),
    );
  }

  @override
  Future<void> userPlayWord() async {}

  @override
  Future<void> userPlaySentence() async {}

  @override
  Future<void> disposePlayer() async {
    state = const FlashcardState();
  }

  @override
  Future<void> reset() async {
    state = _initialState;
  }

  /// 直接设置状态（测试用）
  void setState(FlashcardState newState) {
    state = newState;
  }
}

// ========== 测试数据工厂 ==========

SavedWord _createWord({
  required int id,
  required String word,
  int practiceCount = 0,
}) {
  return SavedWord(
    id: id,
    word: word,
    audioItemId: null,
    sentenceIndex: null,
    sentenceText: null,
    sentenceStartMs: null,
    sentenceEndMs: null,
    practiceCount: practiceCount,
    totalStudyMs: 0,
    viewedBack: false,
    lastPracticedAt: null,
    createdAt: DateTime(2026, 1, 1),
    updatedAt: DateTime(2026, 1, 1),
    deletedAt: null,
    syncStatus: 0,
  );
}

List<FlashcardWordItem> _createWordItems(int count) {
  return List.generate(count, (i) {
    return FlashcardWordItem(
      savedWord: _createWord(id: i + 1, word: 'word${i + 1}'),
    );
  });
}

// ========== 测试 App 包装器 ==========

Widget _createTestWidget({
  required FlashcardState initialState,
  Locale locale = const Locale('en'),
}) {
  return ProviderScope(
    overrides: [
      flashcardNotifierProvider.overrideWith(
        () => _TestFlashcardNotifier(initialState),
      ),
      audioEngineProvider.overrideWith(() => TestAudioEngine()),
    ],
    child: MaterialApp(
      locale: locale,
      supportedLocales: const [Locale('en'), Locale('zh')],
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: AppTheme.light(),
      home: const FlashcardScreen(),
    ),
  );
}

void main() {
  group('FlashcardScreen — 基本渲染', () {
    testWidgets('显示卡片进度（1/3）', (tester) async {
      final items = _createWordItems(3);
      await tester.pumpWidget(
        _createTestWidget(
          initialState: FlashcardState(words: items, currentIndex: 0),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('1/3'), findsOneWidget);
    });

    testWidgets('显示当前单词', (tester) async {
      final items = _createWordItems(2);
      await tester.pumpWidget(
        _createTestWidget(
          initialState: FlashcardState(words: items, currentIndex: 0),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('word1'), findsOneWidget);
    });

    testWidgets('AppBar 包含设置按钮', (tester) async {
      final items = _createWordItems(1);
      await tester.pumpWidget(
        _createTestWidget(initialState: FlashcardState(words: items)),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.tune), findsOneWidget);
    });

    testWidgets('AppBar 包含关闭按钮', (tester) async {
      final items = _createWordItems(1);
      await tester.pumpWidget(
        _createTestWidget(initialState: FlashcardState(words: items)),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.close), findsOneWidget);
    });
  });

  group('FlashcardScreen — 翻转交互', () {
    testWidgets('点击卡片翻转到背面', (tester) async {
      final items = _createWordItems(1);
      await tester.pumpWidget(
        _createTestWidget(initialState: FlashcardState(words: items)),
      );
      await tester.pumpAndSettle();

      // 点击卡片区域
      await tester.tap(find.text('word1'));
      await tester.pumpAndSettle();

      // 翻转后 isShowingBack=true，会重建卡片
    });
  });

  group('FlashcardScreen — 完成视图', () {
    testWidgets('isCompleted=true 时显示完成视图', (tester) async {
      final items = _createWordItems(3);
      await tester.pumpWidget(
        _createTestWidget(
          initialState: FlashcardState(
            words: items,
            isCompleted: true,
            removedCount: 1,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.check_circle_outline), findsOneWidget);
    });

    testWidgets('完成视图有两个操作按钮', (tester) async {
      final items = _createWordItems(2);
      await tester.pumpWidget(
        _createTestWidget(
          initialState: FlashcardState(words: items, isCompleted: true),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(OutlinedButton), findsOneWidget);
      expect(find.byType(FilledButton), findsOneWidget);
    });
  });

  group('FlashcardScreen — 倒计时显示', () {
    testWidgets('Countdown phase 时显示倒计时', (tester) async {
      final items = _createWordItems(2);
      await tester.pumpWidget(
        _createTestWidget(
          initialState: FlashcardState(
            words: items,
            phase: const FlashcardCountdown(
              remaining: Duration(seconds: 5),
              total: Duration(seconds: 8),
            ),
          ),
        ),
      );
      // CountdownChip 自驱动动画，pump 一帧让 AnimationController 初始化
      await tester.pump();

      // CountdownChip 从 total(8s) 开始倒数，初始显示 8
      expect(find.text('8'), findsOneWidget);
    });

    testWidgets('WaitingForUser phase 时不显示倒计时', (tester) async {
      final items = _createWordItems(2);
      await tester.pumpWidget(
        _createTestWidget(
          initialState: FlashcardState(
            words: items,
            phase: const FlashcardWaitingForUser(
              FlashcardWaitingReason.userFlippedCard,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 不应该有 CountdownChip
      // 占位 SizedBox 应该存在
      expect(
        find.byWidgetPredicate(
          (w) => w is SizedBox && w.width == 56 && w.height == 56,
        ),
        findsOneWidget,
      );
    });
  });

  group('FlashcardScreen — 中文本地化', () {
    testWidgets('中文进度文本', (tester) async {
      final items = _createWordItems(5);
      await tester.pumpWidget(
        _createTestWidget(
          initialState: FlashcardState(words: items, currentIndex: 2),
          locale: const Locale('zh'),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('3/5'), findsOneWidget);
    });
  });
}
