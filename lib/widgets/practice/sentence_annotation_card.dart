/// 标注模式内容卡片
///
/// 显示句子文本（单词可点击弹出词典弹窗）、
/// 难句标记切换、三按钮工具栏（拆意群/翻译/解析）。
library;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import '../../l10n/app_localizations.dart';
import '../../services/app_logger.dart';
import '../../models/sense_group_result.dart';
import '../../models/sentence_ai_result.dart';
import '../../models/speech_practice_models.dart';
import '../../theme/app_theme.dart';
import '../../utils/sense_group_timing.dart';
import '../common/async_toggle_button.dart';
import '../common/shimmer_placeholder.dart';
import '../common/text_context_menu.dart';
import '../intensive_listen/word_dictionary_sheet.dart';
import 'sense_group_text.dart';

/// 内容加载状态
enum ContentLoadState { idle, loading, loaded, error }

/// 意群显示模式
enum SenseGroupMode { off, medium, fine }

/// 标注模式句子卡片
///
/// 使用 StatefulWidget 管理 TapGestureRecognizer 生命周期，
/// 防止内存泄漏。内部管理翻译/解析的加载状态和意群显示开关。
///
/// 工具栏可以通过 [showToolbar] 控制是否在卡片内部渲染。
/// 当 [showToolbar] 为 false 时，外部可通过 [GlobalKey] 获取
/// [SentenceAnnotationCardState] 并调用 [SentenceAnnotationCardState.buildToolbar]
/// 在其他位置渲染工具栏。
class SentenceAnnotationCard extends StatefulWidget {
  /// 句子文本
  final String text;

  /// 请求翻译回调（返回翻译文本）
  final Future<String> Function()? onRequestTranslation;

  /// 请求解析回调（返回解析 JSON 文本）
  final Future<String> Function()? onRequestAnalysis;

  /// 已缓存的翻译文本
  final String? cachedTranslation;

  /// 已缓存的解析文本（grammar\nvocabulary\nusage 格式）
  final String? cachedAnalysis;

  /// 来源音频 ID（用于词典弹窗收藏单词时记录来源）
  final String? audioItemId;

  /// 来源句子索引
  final int? sentenceIndex;

  /// 来源句子起始时间（毫秒）
  final int? sentenceStartMs;

  /// 来源句子结束时间（毫秒）
  final int? sentenceEndMs;

  /// 句子正文下方的附加反馈区域。
  final Widget? inlineFeedback;

  /// 句子正文的高亮片段；为空时按原始句子构建。
  final List<SpeechTranscriptSegment>? highlightedSegments;

  /// AI 意群拆分结果（null 表示未请求或无数据，包含大意群和小意群）
  final SenseGroupResult? senseGroupResult;

  /// 各意群时间范围（对应当前显示的粒度）
  final List<SenseGroupTiming>? senseGroupTimings;

  /// 意群粒度切换时的回调（传入当前显示的意群列表，用于重新计算时间范围）
  final void Function(List<String> chunks)? onSenseGroupModeChanged;

  /// 正在播放的意群索引
  final int? playingSenseGroupIndex;

  /// 已播放过的意群索引集合
  final Set<int> playedSenseGroupIndices;

  /// 点击意群回调
  final void Function(int groupIndex)? onTapSenseGroup;

  /// 请求拆分意群回调
  final Future<void> Function()? onRequestSenseGroups;

  /// 是否有词级时间戳（决定拆意群按钮是否可用）
  final bool hasWordTimestamps;

  /// 已收藏的意群文本集合（归一化后，用于 badge 橙色高亮）
  final Set<String> savedGroupTexts;

  /// 点击意群回调（附带 badge 全局位置，用于显示工具条）
  final void Function(int groupIndex, Rect globalRect)? onTapGroupWithRect;

  /// 是否在卡片内部渲染工具栏
  ///
  /// 设为 false 时，工具栏不会在卡片内渲染。外部可通过
  /// [GlobalKey<SentenceAnnotationCardState>] 调用
  /// [SentenceAnnotationCardState.buildToolbar] 在其他位置渲染。
  final bool showToolbar;

  /// 工具栏状态变化回调
  ///
  /// 当 [showToolbar] 为 false 时，卡片内部状态（翻译/解析加载、意群切换）
  /// 变化后调用此回调，通知外部刷新工具栏。
  final VoidCallback? onToolbarStateChanged;

  /// 用户点击工具栏按钮（意群/翻译/解析）时触发，通知外部切换到手动模式
  final VoidCallback? onToolbarButtonTapped;

  const SentenceAnnotationCard({
    super.key,
    required this.text,
    this.onRequestTranslation,
    this.onRequestAnalysis,
    this.cachedTranslation,
    this.cachedAnalysis,
    this.audioItemId,
    this.sentenceIndex,
    this.sentenceStartMs,
    this.sentenceEndMs,
    this.inlineFeedback,
    this.highlightedSegments,
    this.senseGroupResult,
    this.senseGroupTimings,
    this.onSenseGroupModeChanged,
    this.playingSenseGroupIndex,
    this.playedSenseGroupIndices = const {},
    this.onTapSenseGroup,
    this.onRequestSenseGroups,
    this.hasWordTimestamps = false,
    this.showToolbar = true,
    this.onToolbarStateChanged,
    this.onToolbarButtonTapped,
    this.savedGroupTexts = const {},
    this.onTapGroupWithRect,
  });

  @override
  State<SentenceAnnotationCard> createState() => SentenceAnnotationCardState();
}

/// [SentenceAnnotationCard] 的公开 State，支持外部调用 [buildToolbar]。
class SentenceAnnotationCardState extends State<SentenceAnnotationCard> {
  final List<TapGestureRecognizer> _recognizers = [];
  static final RegExp _textPartPattern = RegExp(r'\s+|[^\s]+');

  /// 当前被按压高亮的词索引（-1 表示无）
  int _highlightedWordIndex = -1;

  /// 意群显示模式
  SenseGroupMode _senseGroupMode = SenseGroupMode.off;

  /// 翻译面板状态
  ContentLoadState _translationState = ContentLoadState.idle;
  String? _translationContent;
  bool _translationExpanded = false;
  bool _translationActivated = false;

  /// 解析面板状态
  ContentLoadState _analysisState = ContentLoadState.idle;
  String? _analysisContent;
  bool _analysisExpanded = false;
  bool _analysisActivated = false;

  @override
  void initState() {
    super.initState();
    // 有意群数据时自动显示大意群
    if (widget.senseGroupResult != null &&
        widget.senseGroupResult!.medium.isNotEmpty) {
      _senseGroupMode = SenseGroupMode.medium;
    }
    // 预存缓存内容（用户点击按钮时可立即显示，但不自动展开）
    if (widget.cachedTranslation != null) {
      _translationContent = widget.cachedTranslation;
    }
    if (widget.cachedAnalysis != null) {
      _analysisContent = widget.cachedAnalysis;
    }
    // 首帧构建后通知外部工具栏刷新（解决 GlobalKey 时序问题）
    if (widget.onToolbarStateChanged != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _notifyToolbar();
      });
    }
  }

  @override
  void didUpdateWidget(SentenceAnnotationCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 意群数据从无到有时自动进入 medium 模式
    // 兜底逻辑：_onTapSenseGroup 的 await 返回时 widget 可能还没更新，
    // 此处在 parent rebuild 后再次检查并进入正确模式。
    if (widget.senseGroupResult != null &&
        widget.senseGroupResult!.medium.isNotEmpty &&
        oldWidget.senseGroupResult == null &&
        _senseGroupMode == SenseGroupMode.off) {
      setState(() => _senseGroupMode = SenseGroupMode.medium);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          widget.onSenseGroupModeChanged?.call(widget.senseGroupResult!.medium);
          _notifyToolbar();
        }
      });
    }
    // 意群数据变化时通知工具栏刷新
    if (widget.senseGroupResult != oldWidget.senseGroupResult) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _notifyToolbar();
      });
    }
  }

  @override
  void dispose() {
    for (final r in _recognizers) {
      r.dispose();
    }
    super.dispose();
  }

  // -- 按钮点击处理 --

  /// 通知外部工具栏状态已变化
  void _notifyToolbar() {
    widget.onToolbarStateChanged?.call();
  }

  /// 获取当前模式下应显示的意群列表（off 时返回 null）
  List<String>? get _activeSenseGroups {
    final result = widget.senseGroupResult;
    if (result == null) return null;
    return switch (_senseGroupMode) {
      SenseGroupMode.medium => result.medium,
      SenseGroupMode.fine => result.fine,
      SenseGroupMode.off => null,
    };
  }

  /// 拆意群按钮点击（返回 Future 供 AsyncToggleButton 管理 loading）
  ///
  /// 循环逻辑：
  /// - 两种结果相同：off → medium → off
  /// - 两种结果不同：off → medium（大意群）→ fine（小意群）→ off
  Future<void> _onTapSenseGroup() async {
    final result = widget.senseGroupResult;

    if (result != null && result.medium.isNotEmpty) {
      // 已有有效数据，切换显示模式
      // 仅从 off 进入 medium 时触发手动模式（首次激活）
      if (_senseGroupMode == SenseGroupMode.off) {
        widget.onToolbarButtonTapped?.call();
      }
      final bothEqual = result.areBothEqual;
      final prevMode = _senseGroupMode;
      setState(() {
        switch (_senseGroupMode) {
          case SenseGroupMode.off:
            _senseGroupMode = SenseGroupMode.medium;
          case SenseGroupMode.medium:
            _senseGroupMode = bothEqual
                ? SenseGroupMode.off
                : SenseGroupMode.fine;
          case SenseGroupMode.fine:
            _senseGroupMode = SenseGroupMode.off;
        }
      });
      AppLogger.log(
        'SenseGroup',
        '切换模式: $prevMode → $_senseGroupMode (bothEqual=$bothEqual)',
      );
      // 通知外部重新计算时间范围 + 停止播放（off 时传空列表）
      widget.onSenseGroupModeChanged?.call(_activeSenseGroups ?? []);
      _notifyToolbar();
    } else if (widget.onRequestSenseGroups != null) {
      // 无数据时 await 异步请求，按钮自动显示 loading
      // （空结果不会被父组件缓存，因此可重复点击重试）
      widget.onToolbarButtonTapped?.call();
      AppLogger.log('SenseGroup', '无数据，发起 API 请求...');
      await widget.onRequestSenseGroups!();
      // 请求完成后，父组件已通过 setState 将 senseGroupResult 传入。
      // 显式进入 medium 模式（不依赖 didUpdateWidget 的时序）。
      if (mounted &&
          widget.senseGroupResult != null &&
          widget.senseGroupResult!.medium.isNotEmpty) {
        setState(() => _senseGroupMode = SenseGroupMode.medium);
        AppLogger.log('SenseGroup', 'API 返回后进入 medium 模式');
        widget.onSenseGroupModeChanged?.call(widget.senseGroupResult!.medium);
        _notifyToolbar();
      }
    }
  }

  /// 翻译按钮点击（返回 Future 供 AsyncToggleButton 管理 loading）
  Future<void> _onTapTranslation() async {
    widget.onToolbarButtonTapped?.call();
    if (!_translationActivated) {
      _translationActivated = true;
    }
    if (_translationContent != null) {
      setState(() {
        _translationExpanded = !_translationExpanded;
        _translationState = ContentLoadState.loaded;
      });
      _notifyToolbar();
      return;
    }
    if (widget.onRequestTranslation == null) return;
    setState(() => _translationExpanded = true);
    try {
      final result = await widget.onRequestTranslation!();
      if (mounted) {
        setState(() {
          _translationContent = result;
          _translationState = ContentLoadState.loaded;
        });
        _notifyToolbar();
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _translationExpanded = false;
          _translationState = ContentLoadState.idle;
        });
        _notifyToolbar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.aiTranslationFailed),
          ),
        );
      }
    }
  }

  /// 解析按钮点击（返回 Future 供 AsyncToggleButton 管理 loading）
  Future<void> _onTapAnalysis() async {
    widget.onToolbarButtonTapped?.call();
    if (!_analysisActivated) {
      _analysisActivated = true;
    }
    if (_analysisContent != null) {
      setState(() {
        _analysisExpanded = !_analysisExpanded;
        _analysisState = ContentLoadState.loaded;
      });
      _notifyToolbar();
      return;
    }
    if (widget.onRequestAnalysis == null) return;
    try {
      final result = await widget.onRequestAnalysis!();
      if (mounted) {
        setState(() {
          _analysisContent = result;
          _analysisExpanded = true;
          _analysisState = ContentLoadState.loaded;
        });
        _notifyToolbar();
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _analysisExpanded = false;
          _analysisState = ContentLoadState.idle;
        });
        _notifyToolbar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.aiAnalysisFailed),
          ),
        );
      }
    }
  }

  // -- 词点击 --

  /// 短暂高亮被点击的词（150ms 后自动清除）
  void _flashWord(int index) {
    setState(() => _highlightedWordIndex = index);
    Future.delayed(const Duration(milliseconds: 150), () {
      if (mounted) setState(() => _highlightedWordIndex = -1);
    });
  }

  /// 每次 build 前清理旧 recognizer，创建新的
  List<InlineSpan> _buildWordSpans(ThemeData theme) {
    // 清理旧 recognizer
    for (final r in _recognizers) {
      r.dispose();
    }
    _recognizers.clear();

    final parts = _textPartPattern
        .allMatches(widget.text)
        .map((match) => match.group(0) ?? '')
        .toList();
    final highlightColor = theme.colorScheme.primary.withValues(alpha: 0.1);
    final result = <InlineSpan>[];
    for (int i = 0; i < parts.length; i++) {
      final part = parts[i];
      final cleanWord = part.replaceAll(RegExp(r'[.,!?;:\-—…、，。！？；：]'), '');
      if (part.trim().isEmpty) {
        result.add(TextSpan(text: part));
        continue;
      }
      final wordIndex = i;
      final recognizer = TapGestureRecognizer()
        ..onTap = () {
          if (cleanWord.isNotEmpty) {
            _flashWord(wordIndex);
            widget.onToolbarButtonTapped?.call();
            showWordDictionarySheet(
              context: context,
              word: cleanWord,
              audioItemId: widget.audioItemId,
              sentenceIndex: widget.sentenceIndex,
              sentenceText: widget.text,
              sentenceStartMs: widget.sentenceStartMs,
              sentenceEndMs: widget.sentenceEndMs,
            );
          }
        };
      _recognizers.add(recognizer);
      result.add(
        TextSpan(
          text: part,
          recognizer: recognizer,
          style: _highlightedWordIndex == wordIndex
              ? TextStyle(backgroundColor: highlightColor)
              : null,
        ),
      );
    }
    return result;
  }

  /// 基于高亮片段生成可点击的富文本 span。
  List<InlineSpan> _buildHighlightedWordSpans(ThemeData theme) {
    final segments = widget.highlightedSegments;
    if (segments == null || segments.isEmpty) {
      return _buildWordSpans(theme);
    }

    for (final r in _recognizers) {
      r.dispose();
    }
    _recognizers.clear();

    final highlightColor = theme.colorScheme.primary.withValues(alpha: 0.1);
    final spans = <InlineSpan>[];
    int wordIndex = 0;
    for (final segment in segments) {
      final parts = _textPartPattern
          .allMatches(segment.text)
          .map((match) => match.group(0) ?? '')
          .toList();
      for (final part in parts) {
        if (part.isEmpty) {
          continue;
        }
        if (part.trim().isEmpty) {
          spans.add(TextSpan(text: part));
          continue;
        }
        final cleanWord = part.replaceAll(RegExp(r'[.,!?;:\-—…、，。！？；：]'), '');
        final currentIndex = wordIndex++;
        final recognizer = TapGestureRecognizer()
          ..onTap = () {
            if (cleanWord.isNotEmpty) {
              _flashWord(currentIndex);
              widget.onToolbarButtonTapped?.call();
              showWordDictionarySheet(
                context: context,
                word: cleanWord,
                audioItemId: widget.audioItemId,
                sentenceIndex: widget.sentenceIndex,
                sentenceText: widget.text,
                sentenceStartMs: widget.sentenceStartMs,
                sentenceEndMs: widget.sentenceEndMs,
              );
            }
          };
        _recognizers.add(recognizer);
        final isHighlighted = _highlightedWordIndex == currentIndex;
        spans.add(
          TextSpan(
            text: part,
            recognizer: recognizer,
            style: TextStyle(
              color: segment.isMatched ? const Color(0xFF2E9B51) : null,
              backgroundColor: isHighlighted ? highlightColor : null,
            ),
          ),
        );
      }
    }
    return spans;
  }

  // -- 工具栏相关 --

  bool get _isSenseGroupEnabled => widget.onRequestSenseGroups != null;

  bool get _hasTranslation =>
      widget.onRequestTranslation != null || widget.cachedTranslation != null;

  bool get _hasAnalysis =>
      widget.onRequestAnalysis != null || widget.cachedAnalysis != null;

  /// 是否有任何可用的工具栏按钮
  bool get hasToolbarButtons =>
      _isSenseGroupEnabled || _hasTranslation || _hasAnalysis;

  /// 构建工具栏按钮行
  ///
  /// 当 [SentenceAnnotationCard.showToolbar] 为 false 时，外部可通过
  /// `GlobalKey<SentenceAnnotationCardState>` 获取 state 并调用此方法，
  /// 将工具栏渲染在卡片外部（如固定在滚动区域上方）。
  Widget buildToolbar(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    final showSenseGroupBlocks =
        _senseGroupMode != SenseGroupMode.off &&
        _activeSenseGroups != null &&
        _activeSenseGroups!.isNotEmpty;

    // 按钮文案根据当前模式变化
    final senseGroupLabel = switch (_senseGroupMode) {
      SenseGroupMode.medium => l10n.annotationBtnSenseGroupMedium,
      SenseGroupMode.fine => l10n.annotationBtnSenseGroupFine,
      SenseGroupMode.off => l10n.annotationBtnSenseGroup,
    };

    return Row(
      children: [
        Expanded(
          child: AsyncToggleButton(
            key: const ValueKey('analysis'),
            label: l10n.annotationBtnAnalysis,
            icon: Icons.auto_awesome,
            iconColor: Colors.purple.shade400,
            isActive:
                _analysisExpanded && _analysisState != ContentLoadState.idle,
            isDisabled: !_hasAnalysis,
            onPressed: _onTapAnalysis,
          ),
        ),
        const SizedBox(width: AppSpacing.s),
        Expanded(
          child: AsyncToggleButton(
            key: const ValueKey('translation'),
            label: l10n.annotationBtnTranslation,
            icon: Icons.translate,
            iconColor: Colors.blue.shade600,
            isActive:
                _translationExpanded &&
                _translationState != ContentLoadState.idle,
            isDisabled: !_hasTranslation,
            onPressed: _onTapTranslation,
          ),
        ),
        const SizedBox(width: AppSpacing.s),
        Expanded(
          child: AsyncToggleButton(
            key: const ValueKey('senseGroup'),
            label: senseGroupLabel,
            icon: Icons.auto_fix_high,
            iconColor: Colors.orange.shade700,
            isActive: showSenseGroupBlocks,
            isDisabled: !_isSenseGroupEnabled,
            onPressed: _onTapSenseGroup,
          ),
        ),
      ],
    );
  }

  // -- 构建 --

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    // 判断意群是否应显示色块
    final showSenseGroupBlocks =
        _senseGroupMode != SenseGroupMode.off &&
        _activeSenseGroups != null &&
        _activeSenseGroups!.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 句子文本 — 意群色块模式或纯 RichText（带长按/右键复制整句）
        if (showSenseGroupBlocks) ...[
          SenseGroupText(
            chunks: _activeSenseGroups!,
            timings: widget.senseGroupTimings ?? const [],
            playingGroupIndex: widget.playingSenseGroupIndex,
            playedGroupIndices: widget.playedSenseGroupIndices,
            onTapGroup: widget.onTapSenseGroup ?? (_) {},
            savedGroupTexts: widget.savedGroupTexts,
            onTapGroupWithRect: widget.onTapGroupWithRect,
          ),
        ] else
          GestureDetector(
            onLongPressStart: (details) => TextContextMenu.show(
              context,
              details.globalPosition,
              widget.text,
            ),
            onSecondaryTapDown: (details) => TextContextMenu.show(
              context,
              details.globalPosition,
              widget.text,
            ),
            child: RichText(
              text: TextSpan(
                style: theme.textTheme.titleMedium?.copyWith(
                  height: 1.6,
                  color: theme.colorScheme.onSurface,
                ),
                children: _buildHighlightedWordSpans(theme),
              ),
            ),
          ),

        // 翻译文本（直接显示在句子下方，弱化字体）
        _buildInlineTranslation(theme, l10n),

        // 工具栏按钮行（showToolbar=true 时在卡片内渲染）
        if (widget.showToolbar && hasToolbarButtons) ...[
          const SizedBox(height: AppSpacing.m),
          buildToolbar(context),
        ],

        // 附加反馈区域
        if (widget.inlineFeedback case final inlineFeedback?) ...[
          const SizedBox(height: AppSpacing.l),
          Align(alignment: Alignment.centerRight, child: inlineFeedback),
        ],

        // 解析内容展示区
        _buildContentArea(theme, l10n),
      ],
    );
  }

  /// 构建翻译文本（直接显示在句子下方，弱化字体，无面板包裹）
  Widget _buildInlineTranslation(ThemeData theme, AppLocalizations l10n) {
    if (!_translationExpanded) return const SizedBox.shrink();

    final Widget content;
    switch (_translationState) {
      case ContentLoadState.loading:
        content = Padding(
          padding: const EdgeInsets.only(top: AppSpacing.xs),
          child: SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
            ),
          ),
        );
      case ContentLoadState.loaded:
        content = Padding(
          padding: const EdgeInsets.only(top: AppSpacing.xs),
          child: Text(
            _translationContent ?? '',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              height: 1.5,
            ),
          ),
        );
      case ContentLoadState.error:
        content = const SizedBox.shrink();
      case ContentLoadState.idle:
        content = const SizedBox.shrink();
    }

    return content;
  }

  /// 构建解析内容展示区
  Widget _buildContentArea(ThemeData theme, AppLocalizations l10n) {
    if (!_analysisExpanded) return const SizedBox.shrink();

    return AnimatedSize(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeInOut,
      alignment: Alignment.topCenter,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: AppSpacing.s),
          _buildContentPanel(
            theme: theme,
            l10n: l10n,
            state: _analysisState,
            content: _analysisContent,
            contentBuilder: (content) => _AnalysisContent(content: content),
          ),
        ],
      ),
    );
  }

  /// 构建单个内容面板（shimmer / 内容）
  Widget _buildContentPanel({
    required ThemeData theme,
    required AppLocalizations l10n,
    required ContentLoadState state,
    required String? content,
    Widget Function(String)? contentBuilder,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.m),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(8),
      ),
      child: switch (state) {
        ContentLoadState.loading => const ShimmerPlaceholder(),
        ContentLoadState.loaded => _buildLoadedContent(
          theme,
          content ?? '',
          contentBuilder,
        ),
        ContentLoadState.error => const SizedBox.shrink(),
        ContentLoadState.idle => const SizedBox.shrink(),
      },
    );
  }

  Widget _buildLoadedContent(
    ThemeData theme,
    String content,
    Widget Function(String)? contentBuilder,
  ) {
    if (contentBuilder != null) return contentBuilder(content);
    return Text(
      content,
      style: theme.textTheme.bodyMedium?.copyWith(
        color: theme.colorScheme.onSurfaceVariant,
        height: 1.5,
      ),
    );
  }

}

/// 解析内容结构化展示
///
/// 使用 [SentenceAnalysis.parseDisplayString] 将内容按字段分隔符拆分为
/// grammar / vocabulary / listening 三段，每段带标签标题。
/// vocabulary 和 listening 字段内按 `\n` 拆分为多条，每条前加 bullet。
class _AnalysisContent extends StatelessWidget {
  final String content;

  const _AnalysisContent({required this.content});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final fields = SentenceAnalysis.parseDisplayString(content);
    final labels = [l10n.aiGrammar, l10n.aiVocabulary, l10n.aiListening];

    final bodyStyle = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
      height: 1.5,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < fields.length && i < labels.length; i++) ...[
          if (i > 0) const SizedBox(height: AppSpacing.s),
          // 标签标题（primary 色 + w600）
          Text(
            labels[i],
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 2),
          // grammar（单行）直接展示；vocabulary / listening（多行）加 bullet
          if (i == 0)
            Text(fields[i], style: bodyStyle)
          else
            ..._buildBulletItems(fields[i], bodyStyle),
        ],
      ],
    );
  }

  /// 将 `\n` 分隔的多条内容渲染为带 bullet 的列表
  List<Widget> _buildBulletItems(String field, TextStyle? style) {
    final items = field.split('\n').where((s) => s.trim().isNotEmpty).toList();
    if (items.length <= 1) {
      return [Text(field, style: style)];
    }
    return [
      for (final item in items)
        Padding(
          padding: const EdgeInsets.only(left: 4),
          child: Text('· $item', style: style),
        ),
    ];
  }
}
