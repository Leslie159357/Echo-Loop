/// Flashcard 单词卡片复习页面
///
/// 全屏页面，显示翻转卡片 + 底部控制栏 + 倒计时进度条。
/// 支持左右滑动切换卡片、点击翻转、自动倒计时。
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/app_localizations.dart';
import '../models/flashcard_settings.dart';
import '../providers/flashcard/flashcard_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/flashcard/flashcard_card.dart';
import '../widgets/flashcard/flashcard_settings_sheet.dart';

/// Flashcard 复习页面
class FlashcardScreen extends ConsumerStatefulWidget {
  const FlashcardScreen({super.key});

  @override
  ConsumerState<FlashcardScreen> createState() => _FlashcardScreenState();
}

class _FlashcardScreenState extends ConsumerState<FlashcardScreen> {
  late final AppLifecycleListener _lifecycleListener;

  @override
  void initState() {
    super.initState();
    _lifecycleListener = AppLifecycleListener(
      onPause: () => ref.read(flashcardNotifierProvider.notifier).pause(),
      onResume: () => ref.read(flashcardNotifierProvider.notifier).resume(),
      onInactive: () => ref.read(flashcardNotifierProvider.notifier).pause(),
    );
  }

  @override
  void dispose() {
    _lifecycleListener.dispose();
    super.dispose();
  }

  /// 退出页面前清理资源并返回
  Future<void> _handleExit() async {
    await ref.read(flashcardNotifierProvider.notifier).disposePlayer();
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(flashcardNotifierProvider);
    final l10n = AppLocalizations.of(context)!;

    if (state.isCompleted) {
      return _CompletedView(
        totalReviewed: state.words.length + state.removedCount,
        removedCount: state.removedCount,
      );
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _handleExit();
      },
      child: Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: _handleExit,
        ),
        title: Text(
          state.words.isNotEmpty
              ? l10n.flashcardProgress(
                  state.currentIndex + 1,
                  state.words.length,
                )
              : l10n.flashcardTitle,
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.tune),
            onPressed: () => _showSettings(context),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: Column(
        children: [
          // 卡片区域
          Expanded(
            child: GestureDetector(
              onHorizontalDragEnd: (details) {
                final velocity = details.primaryVelocity ?? 0;
                if (velocity < -200) {
                  // 左滑 → 下一张
                  ref.read(flashcardNotifierProvider.notifier).nextCard();
                } else if (velocity > 200) {
                  // 右滑 → 上一张
                  ref.read(flashcardNotifierProvider.notifier).previousCard();
                }
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.l,
                  vertical: AppSpacing.m,
                ),
                child: state.currentWord != null
                    ? FlashcardCard(
                        key: ValueKey(state.currentWord!.savedWord.word),
                        item: state.currentWord!,
                        isShowingBack: state.isShowingBack,
                        onFlip: () => ref
                            .read(flashcardNotifierProvider.notifier)
                            .flipCard(),
                        onUnsave: () => _handleUnsave(context),
                        autoPlaySentence: state.settings.autoPlaySentence,
                        autoPlayWord: state.settings.autoPlayWord,
                      )
                    : const SizedBox.shrink(),
              ),
            ),
          ),

          // 底部控制栏
          _BottomControls(
            currentIndex: state.currentIndex,
            totalCount: state.words.length,
            countdownRemaining: state.countdownRemaining,
            countdownTotal: state.countdownTotal,
            isPaused: state.isPaused,
            showCountdown:
                state.settings.timerMode != FlashcardTimerMode.off &&
                state.countdownTotal > 0,
            onPrevious: state.currentIndex > 0
                ? () => ref
                      .read(flashcardNotifierProvider.notifier)
                      .previousCard()
                : null,
            onNext: () =>
                ref.read(flashcardNotifierProvider.notifier).nextCard(),
            onTogglePause: () =>
                ref.read(flashcardNotifierProvider.notifier).togglePause(),
          ),
        ],
      ),
    ),
    );
  }

  /// 显示设置弹窗
  void _showSettings(BuildContext context) {
    final notifier = ref.read(flashcardNotifierProvider.notifier);
    notifier.pause();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => FlashcardSettingsSheet(
        settings: ref.read(flashcardNotifierProvider).settings,
        onSettingsChanged: (settings) {
          notifier.updateSettings(settings);
        },
      ),
    ).then((_) {
      notifier.resume();
    });
  }

  /// 取消收藏
  void _handleUnsave(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    ref.read(flashcardNotifierProvider.notifier).unsaveCurrentWord();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(l10n.favoritesWordRemoved),
        duration: const Duration(seconds: 1),
      ),
    );
  }
}

/// 底部控制栏（上一张 / 环形倒计时 / 下一张）
class _BottomControls extends StatelessWidget {
  final int currentIndex;
  final int totalCount;
  final int countdownRemaining;
  final int countdownTotal;
  final bool isPaused;
  final bool showCountdown;
  final VoidCallback? onPrevious;
  final VoidCallback onNext;
  final VoidCallback onTogglePause;

  const _BottomControls({
    required this.currentIndex,
    required this.totalCount,
    required this.countdownRemaining,
    required this.countdownTotal,
    required this.isPaused,
    required this.showCountdown,
    this.onPrevious,
    required this.onNext,
    required this.onTogglePause,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.l,
          AppSpacing.s,
          AppSpacing.l,
          AppSpacing.l,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // 上一张
            IconButton(
              onPressed: onPrevious,
              icon: const Icon(Icons.arrow_back_ios_new),
              color: theme.colorScheme.onSurfaceVariant,
            ),

            // 环形倒计时（可暂停/恢复）
            if (showCountdown)
              _CountdownChip(
                remaining: countdownRemaining,
                total: countdownTotal,
                isPaused: isPaused,
                onTap: onTogglePause,
              )
            else
              const SizedBox(width: 44),

            // 下一张
            IconButton(
              onPressed: onNext,
              icon: const Icon(Icons.arrow_forward_ios),
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }
}

/// 环形倒计时控制按钮（连续动画）
///
/// 圆形按钮，外围带进度环，内部显示暂停/恢复图标，下方显示秒数。
/// 进度环连续平滑变化，不跳跃。
class _CountdownChip extends StatefulWidget {
  final int remaining;
  final int total;
  final bool isPaused;
  final VoidCallback onTap;

  const _CountdownChip({
    required this.remaining,
    required this.total,
    required this.isPaused,
    required this.onTap,
  });

  @override
  State<_CountdownChip> createState() => _CountdownChipState();
}

class _CountdownChipState extends State<_CountdownChip>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    );
    _startOrPause();
  }

  @override
  void didUpdateWidget(covariant _CountdownChip oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 剩余秒数变化 → 重启 1 秒动画
    if (oldWidget.remaining != widget.remaining) {
      _controller.forward(from: 0);
    }
    // 暂停/恢复状态变化
    if (oldWidget.isPaused != widget.isPaused) {
      _startOrPause();
    }
  }

  void _startOrPause() {
    if (widget.isPaused) {
      _controller.stop();
    } else {
      _controller.forward(from: _controller.value);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return GestureDetector(
      onTap: widget.onTap,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          // 连续进度：当前整秒 + 动画分数（0→1 对应该秒的流逝）
          final fraction = widget.isPaused ? 0.0 : _controller.value;
          final smoothRemaining = widget.remaining - fraction;
          final progress = widget.total > 0
              ? 1.0 - (smoothRemaining / widget.total)
              : 1.0;

          // 使用 SizedBox + Stack 让秒数文字溢出到环下方，
          // 不影响 Row 的 crossAxisAlignment.center 对齐
          return SizedBox(
            width: 44,
            height: 44,
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                // 环形进度
                SizedBox(
                  width: 44,
                  height: 44,
                  child: CircularProgressIndicator(
                    value: progress.clamp(0.0, 1.0),
                    strokeWidth: 3,
                    strokeCap: StrokeCap.round,
                    backgroundColor: theme.colorScheme.primary.withValues(
                      alpha: 0.12,
                    ),
                    valueColor: AlwaysStoppedAnimation(
                      theme.colorScheme.primary.withValues(alpha: 0.6),
                    ),
                  ),
                ),
                // 暂停/恢复图标
                Icon(
                  widget.isPaused
                      ? Icons.play_arrow_rounded
                      : Icons.pause_rounded,
                  size: 20,
                  color: theme.colorScheme.primary,
                ),
                // 秒数文字（溢出到环下方，不影响对齐）
                Positioned(
                  bottom: -16,
                  child: Text(
                    '${widget.remaining}s',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant.withValues(
                        alpha: 0.5,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// 完成页面
class _CompletedView extends ConsumerWidget {
  final int totalReviewed;
  final int removedCount;

  const _CompletedView({
    required this.totalReviewed,
    required this.removedCount,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.flashcardComplete), centerTitle: true),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.check_circle_outline,
                size: 80,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(height: AppSpacing.l),
              Text(
                l10n.flashcardComplete,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: AppSpacing.m),
              Text(
                l10n.flashcardWordsReviewed(totalReviewed),
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              if (removedCount > 0) ...[
                const SizedBox(height: AppSpacing.xs),
                Text(
                  l10n.flashcardWordsRemoved(removedCount),
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: theme.colorScheme.primary,
                  ),
                ),
              ],
              const SizedBox(height: AppSpacing.xl),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  OutlinedButton(
                    onPressed: () =>
                        ref.read(flashcardNotifierProvider.notifier).reset(),
                    child: Text(l10n.flashcardPracticeAgain),
                  ),
                  const SizedBox(width: AppSpacing.m),
                  FilledButton(
                    onPressed: () {
                      ref
                          .read(flashcardNotifierProvider.notifier)
                          .disposePlayer();
                      Navigator.of(context).pop();
                    },
                    child: Text(l10n.flashcardFinish),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
