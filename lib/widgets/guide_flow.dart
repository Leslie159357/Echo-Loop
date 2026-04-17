import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:showcaseview/showcaseview.dart';

import '../l10n/app_localizations.dart';
import '../providers/new_user_guide_provider.dart';
import '../services/app_logger.dart';

/// 单个页面级引导步骤。
///
/// [key] 同时用于 [Showcase] widget 的 key 和 `startShowCase` 调用，
/// 由 screen 在 state 中持有，传给对应的 [GuideTarget] 和 [GuideFlow]。
/// 同一个 step 需要被 [GuideFlow.steps] 和 [GuideTarget] 引用**同一个实例**
/// （或者至少是相同的 key），这样 Host 能在 `startShowCase` 时拿到对应的
/// key，并且 showcaseview 能在 tree 里通过 key 定位到目标 widget。
class GuideStep {
  final GlobalKey key;
  final String title;
  final String description;

  const GuideStep({
    required this.key,
    required this.title,
    required this.description,
  });
}

/// 单个页面级引导 flow 的声明。
class GuideFlow {
  final String flowId;
  final bool shouldRun;
  final List<GuideStep> steps;

  const GuideFlow({
    required this.flowId,
    required this.shouldRun,
    required this.steps,
  });
}

/// 在 screen 内按顺序声明并启动一组页面级 flow。
///
/// 对齐 showcaseview 官方示例：flow 启动时 **一次性** 把所有 step 的 key
/// 传给 `ShowcaseView.get().startShowCase([...])`，推进完全由 showcaseview
/// 内部处理（next 按钮 / barrier 点击），tour 结束时通过
/// [GuideShowcaseBus] 走回 controller 标记已看。
class GuideFlowSequenceHost extends ConsumerStatefulWidget {
  final List<GuideFlow> flows;
  final Widget child;

  const GuideFlowSequenceHost({
    super.key,
    required this.flows,
    required this.child,
  });

  @override
  ConsumerState<GuideFlowSequenceHost> createState() =>
      _GuideFlowSequenceHostState();
}

class _GuideFlowSequenceHostState extends ConsumerState<GuideFlowSequenceHost> {
  ProviderSubscription<GuideControllerState>? _guideSubscription;
  bool _attemptScheduled = false;
  bool _lastTickerEnabled = true;

  @override
  void initState() {
    super.initState();
    _guideSubscription = ref.listenManual<GuideControllerState>(
      guideControllerProvider,
      _onControllerStateChanged,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _scheduleAttempt();
    });
  }

  void _onControllerStateChanged(
    GuideControllerState? previous,
    GuideControllerState next,
  ) {
    if (!mounted) return;
    final resetChanged =
        previous != null && previous.resetGeneration != next.resetGeneration;
    if (resetChanged || !next.isActive) {
      _attemptScheduled = false;
      _scheduleAttempt();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final tickerEnabled = TickerMode.valuesOf(context).enabled;
    if (tickerEnabled && !_lastTickerEnabled) {
      _attemptScheduled = false;
      _scheduleAttempt();
    }
    _lastTickerEnabled = tickerEnabled;
  }

  @override
  void didUpdateWidget(covariant GuideFlowSequenceHost oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_flowsConfigChanged(oldWidget.flows, widget.flows)) {
      _attemptScheduled = false;
      _scheduleAttempt();
    }
  }

  @override
  void dispose() {
    _guideSubscription?.close();
    super.dispose();
  }

  bool _flowsConfigChanged(List<GuideFlow> a, List<GuideFlow> b) {
    if (a.length != b.length) return true;
    for (var i = 0; i < a.length; i++) {
      if (a[i].flowId != b[i].flowId || a[i].shouldRun != b[i].shouldRun) {
        return true;
      }
    }
    return false;
  }

  void _scheduleAttempt() {
    if (_attemptScheduled ||
        widget.flows.isEmpty ||
        !TickerMode.valuesOf(context).enabled) {
      return;
    }
    _attemptScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      _attemptScheduled = false;
      if (!mounted) return;
      await _tryStartNext();
    });
  }

  Future<void> _tryStartNext() async {
    if (!mounted) return;
    if (!TickerMode.valuesOf(context).enabled) return;
    final showcase = _tryGetShowcase();
    if (showcase == null) return;
    if (ref.read(guideControllerProvider).isActive) return;

    final registry = ref.read(guideRegistryProvider);
    for (final flow in widget.flows) {
      if (!flow.shouldRun || flow.steps.isEmpty) continue;
      if (await registry.isSeen(flow.flowId)) continue;
      if (!mounted) return;

      final started = await ref
          .read(guideControllerProvider.notifier)
          .startFlow(flow.flowId);
      if (!mounted) return;
      if (!started) continue;

      GuideShowcaseBus.setOnEnd(() {
        ref.read(guideControllerProvider.notifier).completeActiveFlow();
      });
      final keys = flow.steps.map((s) => s.key).toList();
      AppLogger.log(
        'Guide',
        'host startShowCase flow=${flow.flowId} keys=${keys.length}',
      );
      showcase.startShowCase(keys);
      return;
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// 获取全局 [ShowcaseView]；未注册（如纯 unit 测试环境）时返回 null。
ShowcaseView? _tryGetShowcase() {
  try {
    return ShowcaseView.get();
  } catch (_) {
    return null;
  }
}

/// 引导 tooltip 的视觉方案（light / dark 双主题）。
class _GuideTooltipScheme {
  const _GuideTooltipScheme._({
    required this.surface,
    required this.title,
    required this.description,
    required this.actionBg,
    required this.actionText,
    required this.barrier,
    required this.barrierOpacity,
  });

  final Color surface;
  final Color title;
  final Color description;
  final Color actionBg;
  final Color actionText;
  final Color barrier;
  final double barrierOpacity;

  static const _light = _GuideTooltipScheme._(
    surface: Color(0xFFFFFFFF),
    title: Color(0xFF0F1115),
    description: Color(0xFF5A6270),
    actionBg: Color(0xFF111418),
    actionText: Color(0xFFFFFFFF),
    barrier: Color(0xFF0A0D12),
    barrierOpacity: 0.55,
  );

  static const _dark = _GuideTooltipScheme._(
    surface: Color(0xFF1B1E23),
    title: Color(0xFFF4F5F7),
    description: Color(0xFF9BA3AE),
    actionBg: Color(0xFFF4F5F7),
    actionText: Color(0xFF0F1115),
    barrier: Color(0xFF000000),
    barrierOpacity: 0.62,
  );

  static _GuideTooltipScheme of(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? _dark : _light;
}

/// 引导 tooltip 的几何与字体 tokens（与配色解耦）。
abstract class _GuideTooltipStyle {
  static const tooltipRadius = BorderRadius.all(Radius.circular(14));
  static const tooltipPadding = EdgeInsets.fromLTRB(18, 16, 18, 14);
  static const targetPadding = EdgeInsets.all(4);
  static const targetRadius = BorderRadius.all(Radius.circular(16));
  static const actionRadius = BorderRadius.all(Radius.circular(8));
  static const actionPadding = EdgeInsets.symmetric(
    horizontal: 14,
    vertical: 8,
  );

  static TextStyle title(Color color) => TextStyle(
    fontSize: 15,
    height: 1.35,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.1,
    color: color,
  );

  static TextStyle description(Color color) => TextStyle(
    fontSize: 13,
    height: 1.55,
    fontWeight: FontWeight.w400,
    color: color,
  );

  static TextStyle action(Color color) => TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.1,
    color: color,
  );
}

/// 可复用的 showcase target 包装器。
///
/// 本身是一个无状态的薄包装：只负责把 [step.key] 设给 [Showcase] widget
/// 并应用统一的视觉方案。Key 由 screen 侧管理，和 [GuideFlow] 里声明的
/// key 同一实例，确保 `startShowCase([keys])` 能正确定位到目标。
class GuideTarget extends StatelessWidget {
  final GuideStep step;
  final Widget child;

  const GuideTarget({super.key, required this.step, required this.child});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = _GuideTooltipScheme.of(context);

    return Showcase(
      key: step.key,
      title: step.title,
      description: step.description,

      // 表面
      tooltipBackgroundColor: scheme.surface,
      tooltipBorderRadius: _GuideTooltipStyle.tooltipRadius,
      tooltipPadding: _GuideTooltipStyle.tooltipPadding,
      targetPadding: _GuideTooltipStyle.targetPadding,
      targetBorderRadius: _GuideTooltipStyle.targetRadius,

      // 版式
      titleTextStyle: _GuideTooltipStyle.title(scheme.title),
      descTextStyle: _GuideTooltipStyle.description(scheme.description),
      titleAlignment: Alignment.centerLeft,
      descriptionAlignment: Alignment.centerLeft,
      titleTextAlign: TextAlign.left,
      descriptionTextAlign: TextAlign.left,

      // barrier（遮罩）
      overlayColor: scheme.barrier,
      overlayOpacity: scheme.barrierOpacity,

      // 动作按钮——默认 next 行为由 showcaseview 接管，过最后一步自动 onFinish。
      tooltipActionConfig: const TooltipActionConfig(
        alignment: MainAxisAlignment.end,
        position: TooltipActionPosition.inside,
        actionGap: 8,
        gapBetweenContentAndAction: 12,
      ),
      tooltipActions: [
        TooltipActionButton(
          type: TooltipDefaultActionType.next,
          name: l10n.guideNext,
          backgroundColor: scheme.actionBg,
          textStyle: _GuideTooltipStyle.action(scheme.actionText),
          borderRadius: _GuideTooltipStyle.actionRadius,
          padding: _GuideTooltipStyle.actionPadding,
        ),
      ],
      child: Semantics(label: step.title, child: child),
    );
  }
}
