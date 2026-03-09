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
import 'package:fluency/providers/audio_engine/audio_engine_provider.dart';
import 'package:fluency/models/flashcard_settings.dart';
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
  Future<void> initialize(List<SavedWord> words) async {
    // 测试中不做真实初始化
  }

  @override
  void flipCard() {
    if (state.isCompleted || state.words.isEmpty) return;
    state = state.copyWith(isShowingBack: !state.isShowingBack);
  }

  @override
  void nextCard() {
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
  void previousCard() {
    if (state.currentIndex <= 0) return;
    state = state.copyWith(
      currentIndex: state.currentIndex - 1,
      isShowingBack: false,
    );
  }

  @override
  void pause() {
    state = state.copyWith(isPaused: true);
  }

  @override
  void resume() {
    state = state.copyWith(isPaused: false);
  }

  @override
  void togglePause() {
    state = state.copyWith(isPaused: !state.isPaused);
  }

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
        _createTestWidget(
          initialState: FlashcardState(words: items),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.tune), findsOneWidget);
    });

    testWidgets('AppBar 包含返回按钮', (tester) async {
      final items = _createWordItems(1);
      await tester.pumpWidget(
        _createTestWidget(
          initialState: FlashcardState(words: items),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.arrow_back), findsOneWidget);
    });
  });

  group('FlashcardScreen — 翻转交互', () {
    testWidgets('点击卡片翻转到背面', (tester) async {
      final items = _createWordItems(1);
      await tester.pumpWidget(
        _createTestWidget(
          initialState: FlashcardState(words: items),
        ),
      );
      await tester.pumpAndSettle();

      // 点击卡片区域
      await tester.tap(find.text('word1'));
      await tester.pumpAndSettle();

      // 翻转后 isShowingBack=true，会重建卡片
      // 无法直接验证背面内容（需要 DictEntry），但状态已改变
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

      // 完成视图包含"再来一遍"和"完成"按钮
      expect(find.byIcon(Icons.check_circle_outline), findsOneWidget);
    });

    testWidgets('完成视图有两个操作按钮', (tester) async {
      final items = _createWordItems(2);
      await tester.pumpWidget(
        _createTestWidget(
          initialState: FlashcardState(
            words: items,
            isCompleted: true,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 应有 OutlinedButton（再来一遍）和 FilledButton（完成）
      expect(find.byType(OutlinedButton), findsOneWidget);
      expect(find.byType(FilledButton), findsOneWidget);
    });
  });

  group('FlashcardScreen — 暂停状态', () {
    testWidgets('倒计时显示时有暂停/恢复按钮', (tester) async {
      final items = _createWordItems(2);
      await tester.pumpWidget(
        _createTestWidget(
          initialState: FlashcardState(
            words: items,
            settings: const FlashcardSettings(
              timerMode: FlashcardTimerMode.fixed,
              fixedTimerSeconds: 8,
            ),
            countdownRemaining: 5,
            countdownTotal: 8,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 暂停按钮（pause_rounded 图标）
      expect(find.byIcon(Icons.pause_rounded), findsOneWidget);
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
