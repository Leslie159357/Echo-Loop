/// 盲听播放器页面
///
/// 极简播放器界面，仅包含播放/暂停按钮和进度条。
/// 不显示字幕、句子列表、设置等元素。
///
/// 播放完成后根据目标遍数决定行为：
/// - 未达目标遍数：显示 5 秒倒计时 → 自动播放下一遍
/// - 已达/超过目标遍数：弹完成对话框（难度选择 + 再听一遍）
/// - 自由练习模式：无倒计时、无弹窗
///
/// 进度条使用 BlindListenPlayer 的 drag-safe 状态驱动，
/// 拖动期间只更新显示位置不 seek，松手后再执行实际 seek。
library;

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../l10n/app_localizations.dart';
import '../providers/learning_progress_provider.dart';
import '../providers/learning_session/blind_listen_player_provider.dart';
import '../providers/learning_session/learning_session_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/blind_listen_complete_dialog.dart';

/// 盲听播放器页面
class BlindListenPlayerScreen extends ConsumerStatefulWidget {
  /// 合集 ID（用于返回导航，从独立音频路由进入时为 null）
  final String? collectionId;

  /// 音频项 ID
  final String audioItemId;

  const BlindListenPlayerScreen({
    super.key,
    this.collectionId,
    required this.audioItemId,
  });

  @override
  ConsumerState<BlindListenPlayerScreen> createState() =>
      _BlindListenPlayerScreenState();
}

class _BlindListenPlayerScreenState
    extends ConsumerState<BlindListenPlayerScreen> {
  /// 是否正在显示完成对话框（防止重复弹出）
  bool _isShowingDialog = false;

  /// 倒计时剩余时长（null = 不显示倒计时）
  Duration? _countdownRemaining;

  /// 倒计时总时长
  static const _countdownTotal = Duration(seconds: 5);

  /// 倒计时定时器（100ms 精度）
  Timer? _countdownTimer;

  @override
  void initState() {
    super.initState();
    // 进入后自动开始播放
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(blindListenPlayerProvider.notifier).play();
    });
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }

  /// 处理播放完成
  ///
  /// 根据目标遍数决定行为：
  /// - 未达目标遍数 → 显示 5 秒倒计时 → 自动播放下一遍
  /// - 已达/超过目标遍数 → 弹完成对话框（难度选择 + 再听一遍）
  void _handlePlaybackCompleted() {
    if (_isShowingDialog || _countdownRemaining != null) return;

    final session = ref.read(learningSessionProvider);

    // 自由练习模式：播放完成后不弹对话框、不倒计时，用户可手动重播或返回
    if (session.isFreePlay) return;

    if (session.hasRemainingPasses) {
      // 未达目标遍数 → 倒计时 → 自动播放下一遍
      _startCountdown();
    } else {
      // 达到目标遍数 → 弹完成对话框
      _showCompleteDialog();
    }
  }

  /// 开始 5 秒倒计时，结束后自动播放下一遍
  void _startCountdown() {
    setState(() {
      _countdownRemaining = _countdownTotal;
    });

    const tick = Duration(milliseconds: 100);
    _countdownTimer = Timer.periodic(tick, (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      final next = _countdownRemaining! - tick;
      if (next <= Duration.zero) {
        timer.cancel();
        setState(() {
          _countdownRemaining = null;
        });
        // 倒计时结束 → 自动播放下一遍
        ref.read(learningSessionProvider.notifier).replayBlindListen();
      } else {
        setState(() {
          _countdownRemaining = next;
        });
      }
    });
  }

  /// 跳过倒计时，直接开始下一遍
  void _skipCountdown() {
    _countdownTimer?.cancel();
    _countdownTimer = null;
    setState(() {
      _countdownRemaining = null;
    });
    // 跳过倒计时 → 自动播放下一遍
    ref.read(learningSessionProvider.notifier).replayBlindListen();
  }

  /// 显示完成对话框
  Future<void> _showCompleteDialog() async {
    if (_isShowingDialog || !mounted) return;
    _isShowingDialog = true;

    final session = ref.read(learningSessionProvider);
    final result = await showBlindListenCompleteDialog(
      context: context,
      passCount: session.blindListenPassCount,
    );

    _isShowingDialog = false;
    if (!mounted) return;

    if (result == null) {
      // 用户选择"再听一遍"
      await ref.read(learningSessionProvider.notifier).replayBlindListen();
    } else {
      // 用户选择了难度 → 保存难度 → 推进子步骤 → 退出盲听模式 → 返回
      try {
        await ref
            .read(learningProgressNotifierProvider.notifier)
            .setDifficulty(widget.audioItemId, result);
        await ref
            .read(learningProgressNotifierProvider.notifier)
            .completeCurrentSubStage(widget.audioItemId);
      } catch (e) {
        debugPrint('盲听完成处理出错: $e');
      }
      await ref.read(learningSessionProvider.notifier).exitLearningMode();
      if (mounted) context.pop();
    }
  }

  /// 格式化时长为 mm:ss
  String _formatDuration(Duration duration) {
    final totalSeconds = duration.inSeconds;
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    // 监听学习会话状态
    final session = ref.watch(learningSessionProvider);
    final playerState = ref.watch(blindListenPlayerProvider);

    // 当盲听完成时触发处理
    ref.listen<LearningSessionState>(learningSessionProvider, (prev, next) {
      if (next.blindListenCompleted && !(prev?.blindListenCompleted ?? false)) {
        _handlePlaybackCompleted();
      }
    });

    final currentPass = session.blindListenPassCount;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;

        // 自由练习模式直接退出，不弹确认对话框
        // 正常学习模式播放中弹出退出确认对话框
        if (playerState.isPlaying && !session.isFreePlay) {
          final confirm = await showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
              title: Text(l10n.exitBlindListenTitle),
              content: Text(l10n.exitBlindListenMessage),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: Text(l10n.cancel),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: Text(l10n.confirmExit),
                ),
              ],
            ),
          );
          if (confirm != true || !mounted) return;
        }

        await ref.read(learningSessionProvider.notifier).exitLearningMode();
        if (mounted) context.pop();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(l10n.blindListenAppBarTitle),
          centerTitle: true,
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: AppSpacing.m),
              child: Center(
                child: Text(
                  l10n.blindListenPassLabel(currentPass),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
          ],
        ),
        body: Column(
          children: [
            // 中央区域 — 大播放按钮 + 耳机图标
            Expanded(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // 耳机图标
                    Icon(
                      Icons.headphones,
                      size: 80,
                      color: theme.colorScheme.primary.withValues(
                        alpha: 0.3,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xl),

                    // 播放/暂停按钮
                    GestureDetector(
                      onTap: () {
                        final player = ref.read(
                          blindListenPlayerProvider.notifier,
                        );
                        if (playerState.isPlaying) {
                          player.pause();
                        } else {
                          player.play();
                        }
                      },
                      child: Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: theme.colorScheme.primary.withValues(
                                alpha: 0.3,
                              ),
                              blurRadius: 16,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Icon(
                          playerState.isPlaying
                              ? Icons.pause
                              : Icons.play_arrow,
                          size: 40,
                          color: theme.colorScheme.onPrimary,
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.l),

                    // 倒计时 / 遍数信息区域（固定高度，避免布局跳动）
                    SizedBox(
                      height: 64,
                      child: _countdownRemaining != null
                          ? _CountdownIndicator(
                              remaining: _countdownRemaining!,
                              total: _countdownTotal,
                              l10n: l10n,
                              onSkip: _skipCountdown,
                            )
                          : Center(
                              child: Text(
                                l10n.blindListenPassLabel(currentPass),
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ),
                    ),
                  ],
                ),
              ),
            ),

            // 底部进度条
            _ProgressSection(formatDuration: _formatDuration),
          ],
        ),
      ),
    );
  }
}

/// 底部进度条区域 — 完全由 BlindListenPlayer 状态驱动
class _ProgressSection extends ConsumerWidget {
  final String Function(Duration) formatDuration;

  const _ProgressSection({required this.formatDuration});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final playerState = ref.watch(blindListenPlayerProvider);
    final blindPlayer = ref.read(blindListenPlayerProvider.notifier);

    final totalMs = playerState.totalDuration.inMilliseconds;
    final posMs = playerState.position.inMilliseconds.clamp(0, totalMs);
    final progress = totalMs > 0 ? posMs / totalMs : 0.0;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.l,
        0,
        AppSpacing.l,
        AppSpacing.xl,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 进度条
          SliderTheme(
            data: SliderThemeData(
              trackHeight: 4,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
              activeTrackColor: theme.colorScheme.primary,
              inactiveTrackColor: theme.colorScheme.surfaceContainerHighest,
              thumbColor: theme.colorScheme.primary,
            ),
            child: Slider(
              value: progress.clamp(0.0, 1.0),
              onChangeStart: (_) => blindPlayer.onDragStart(),
              onChanged: (value) {
                final pos = Duration(milliseconds: (value * totalMs).round());
                blindPlayer.onDragUpdate(pos);
              },
              onChangeEnd: (value) {
                final pos = Duration(milliseconds: (value * totalMs).round());
                blindPlayer.onDragEnd(pos);
              },
            ),
          ),
          // 时间标签
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.m),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  formatDuration(Duration(milliseconds: posMs)),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                Text(
                  formatDuration(playerState.totalDuration),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 内联倒计时指示器 — 文字标签 + 线性进度条 + 跳过按钮
class _CountdownIndicator extends StatelessWidget {
  final Duration remaining;
  final Duration total;
  final AppLocalizations l10n;
  final VoidCallback onSkip;

  const _CountdownIndicator({
    required this.remaining,
    required this.total,
    required this.l10n,
    required this.onSkip,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final totalMs = total.inMilliseconds;
    final remainingMs = remaining.inMilliseconds;
    final progress = totalMs > 0 ? 1.0 - (remainingMs / totalMs) : 1.0;
    final seconds = (remainingMs / 1000).ceil();

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          l10n.blindListenCountdown(seconds),
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: AppSpacing.s),
        SizedBox(
          width: 120,
          child: LinearProgressIndicator(
            value: progress.clamp(0.0, 1.0),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        TextButton(
          onPressed: onSkip,
          child: Text(l10n.skipCountdown),
        ),
      ],
    );
  }
}
