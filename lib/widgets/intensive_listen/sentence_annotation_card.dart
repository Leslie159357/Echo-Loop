/// 标注模式内容卡片
///
/// 显示句子文本（单词可点击弹出词典弹窗）、
/// 难句标记切换、三按钮工具栏（拆意群/翻译/解析）。
library;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import '../../l10n/app_localizations.dart';
import '../../models/sense_group_result.dart';
import '../../models/sentence_ai_result.dart';
import '../../models/speech_practice_models.dart';
import '../../theme/app_theme.dart';
import '../../utils/sense_group_timing.dart';
import '../common/shimmer_placeholder.dart';
import '../common/tappable_wrapper.dart';
import '../common/text_context_menu.dart';
import 'sense_group_text.dart';
import 'word_dictionary_sheet.dart';

/// 内容加载状态
enum ContentLoadState { idle, loading, loaded, error }

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

  /// 当前句子是否标记为难句
  final bool isDifficult;

  /// 是否展示"自动标记"文案
  ///
  /// 仅在"看不懂"触发自动标记的当次传 true；
  /// 其它场景（包括已存在的难句）保持 false。
  final bool showAutoMarkedLabel;

  /// 切换难句标记回调（为 null 时不显示标记行）
  final VoidCallback? onToggle;

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

  /// AI 意群拆分结果（null 表示未请求或无数据）
  final List<SenseGroup>? senseGroups;

  /// 各意群时间范围
  final List<SenseGroupTiming>? senseGroupTimings;

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

  /// 是否正在加载意群
  final bool isSenseGroupLoading;

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

  const SentenceAnnotationCard({
    super.key,
    required this.text,
    required this.isDifficult,
    this.showAutoMarkedLabel = false,
    this.onToggle,
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
    this.senseGroups,
    this.senseGroupTimings,
    this.playingSenseGroupIndex,
    this.playedSenseGroupIndices = const {},
    this.onTapSenseGroup,
    this.onRequestSenseGroups,
    this.hasWordTimestamps = false,
    this.isSenseGroupLoading = false,
    this.showToolbar = true,
    this.onToolbarStateChanged,
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

  /// 意群色块是否显示（区分"有数据"和"用户是否激活显示"）
  bool _senseGroupVisible = false;

  /// 翻译面板状态
  ContentLoadState _translationState = ContentLoadState.idle;
  String? _translationContent;
  bool _translationExpanded = false;

  /// 解析面板状态
  ContentLoadState _analysisState = ContentLoadState.idle;
  String? _analysisContent;
  bool _analysisExpanded = false;

  @override
  void initState() {
    super.initState();
    // 有意群数据时自动显示
    if (widget.senseGroups != null && widget.senseGroups!.isNotEmpty) {
      _senseGroupVisible = true;
    }
    // 有缓存翻译时自动展开
    if (widget.cachedTranslation != null) {
      _translationContent = widget.cachedTranslation;
      _translationState = ContentLoadState.loaded;
      _translationExpanded = true;
    }
    // 有缓存解析时自动展开
    if (widget.cachedAnalysis != null) {
      _analysisContent = widget.cachedAnalysis;
      _analysisState = ContentLoadState.loaded;
      _analysisExpanded = true;
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
    // 意群数据从无到有时自动显示
    if (widget.senseGroups != null &&
        widget.senseGroups!.isNotEmpty &&
        oldWidget.senseGroups == null) {
      _senseGroupVisible = true;
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

  /// 拆意群按钮点击
  void _onTapSenseGroup() {
    final hasData =
        widget.senseGroups != null &&
        widget.senseGroups!.isNotEmpty &&
        widget.senseGroupTimings != null;

    if (hasData) {
      // 有数据时 toggle 显示/隐藏
      setState(() => _senseGroupVisible = !_senseGroupVisible);
      _notifyToolbar();
    } else if (widget.onRequestSenseGroups != null) {
      // 无数据时触发请求
      widget.onRequestSenseGroups!();
    }
  }

  /// 翻译按钮点击
  void _onTapTranslation() {
    if (_translationState == ContentLoadState.loading) return;

    if (_translationContent != null) {
      // 有内容时 toggle 展开/折叠
      setState(() => _translationExpanded = !_translationExpanded);
      _notifyToolbar();
      return;
    }

    // 首次请求
    _requestTranslation();
  }

  /// 解析按钮点击
  void _onTapAnalysis() {
    if (_analysisState == ContentLoadState.loading) return;

    if (_analysisContent != null) {
      // 有内容时 toggle 展开/折叠
      setState(() => _analysisExpanded = !_analysisExpanded);
      _notifyToolbar();
      return;
    }

    // 首次请求
    _requestAnalysis();
  }

  /// 请求翻译
  Future<void> _requestTranslation() async {
    if (widget.onRequestTranslation == null) return;
    setState(() {
      _translationState = ContentLoadState.loading;
      _translationExpanded = true;
    });
    _notifyToolbar();
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
        setState(() => _translationState = ContentLoadState.error);
        _notifyToolbar();
      }
    }
  }

  /// 请求解析
  Future<void> _requestAnalysis() async {
    if (widget.onRequestAnalysis == null) return;
    setState(() {
      _analysisState = ContentLoadState.loading;
      _analysisExpanded = true;
    });
    _notifyToolbar();
    try {
      final result = await widget.onRequestAnalysis!();
      if (mounted) {
        setState(() {
          _analysisContent = result;
          _analysisState = ContentLoadState.loaded;
        });
        _notifyToolbar();
      }
    } catch (_) {
      if (mounted) {
        setState(() => _analysisState = ContentLoadState.error);
        _notifyToolbar();
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

  bool get _isSenseGroupEnabled =>
      widget.hasWordTimestamps && widget.onRequestSenseGroups != null;

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
        _senseGroupVisible &&
        widget.senseGroups != null &&
        widget.senseGroups!.isNotEmpty &&
        widget.senseGroupTimings != null;

    return Row(
      children: [
        Expanded(
          child: _ToolbarButton(
            label: l10n.annotationBtnSenseGroup,
            icon: Icons.auto_fix_high,
            isActive: showSenseGroupBlocks,
            isLoading: widget.isSenseGroupLoading,
            isDisabled: !_isSenseGroupEnabled,
            onTap: _onTapSenseGroup,
            disabledMessage: l10n.senseGroupNotAvailable,
          ),
        ),
        const SizedBox(width: AppSpacing.s),
        Expanded(
          child: _ToolbarButton(
            label: l10n.annotationBtnTranslation,
            icon: Icons.translate,
            isActive:
                _translationExpanded &&
                _translationState != ContentLoadState.idle,
            isLoading: _translationState == ContentLoadState.loading,
            isDisabled: !_hasTranslation,
            onTap: _onTapTranslation,
          ),
        ),
        const SizedBox(width: AppSpacing.s),
        Expanded(
          child: _ToolbarButton(
            label: l10n.annotationBtnAnalysis,
            icon: Icons.auto_awesome,
            isActive:
                _analysisExpanded && _analysisState != ContentLoadState.idle,
            isLoading: _analysisState == ContentLoadState.loading,
            isDisabled: !_hasAnalysis,
            onTap: _onTapAnalysis,
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
        _senseGroupVisible &&
        widget.senseGroups != null &&
        widget.senseGroups!.isNotEmpty &&
        widget.senseGroupTimings != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 难句标记（可点击切换；onToggle 为 null 时不显示）
        if (widget.onToggle != null) ...[
          TappableWrapper(
            onTap: widget.onToggle,
            feedbackType: TapFeedback.opacity,
            pressedOpacity: 0.4,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Flexible(
                  child: Text(
                    widget.isDifficult
                        ? (widget.showAutoMarkedLabel
                              ? l10n.intensiveListenAutoMarkedDifficult
                              : l10n.intensiveListenMarkedDifficult)
                        : l10n.intensiveListenNotDifficult,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.outline.withValues(alpha: 0.6),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: AppSpacing.xs),
                Icon(
                  widget.isDifficult ? Icons.bookmark : Icons.bookmark_border,
                  color: widget.isDifficult ? Colors.amber : Colors.grey,
                  size: 18,
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.m),
        ],

        // 句子文本 — 意群色块模式或纯 RichText（带长按/右键复制整句）
        if (showSenseGroupBlocks) ...[
          SenseGroupText(
            groups: widget.senseGroups!,
            timings: widget.senseGroupTimings!,
            playingGroupIndex: widget.playingSenseGroupIndex,
            playedGroupIndices: widget.playedSenseGroupIndices,
            onTapGroup: widget.onTapSenseGroup ?? (_) {},
            audioItemId: widget.audioItemId,
            sentenceIndex: widget.sentenceIndex,
            sentenceText: widget.text,
            sentenceStartMs: widget.sentenceStartMs,
            sentenceEndMs: widget.sentenceEndMs,
          ),
          // 单意群提示
          if (widget.senseGroups!.length == 1) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              l10n.senseGroupSingleGroup,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
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
        content = Padding(
          padding: const EdgeInsets.only(top: AppSpacing.xs),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.error_outline,
                size: 14,
                color: theme.colorScheme.error,
              ),
              const SizedBox(width: AppSpacing.xs),
              Text(
                l10n.aiLoadFailed,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.error,
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              GestureDetector(
                onTap: _requestTranslation,
                child: Text(
                  l10n.aiRetry,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.primary,
                  ),
                ),
              ),
            ],
          ),
        );
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
            onRetry: _requestAnalysis,
            contentBuilder: (content) => _AnalysisContent(content: content),
          ),
        ],
      ),
    );
  }

  /// 构建单个内容面板（shimmer / 内容 / 错误）
  Widget _buildContentPanel({
    required ThemeData theme,
    required AppLocalizations l10n,
    required ContentLoadState state,
    required String? content,
    required VoidCallback onRetry,
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
        ContentLoadState.error => _buildErrorContent(theme, l10n, onRetry),
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

  Widget _buildErrorContent(
    ThemeData theme,
    AppLocalizations l10n,
    VoidCallback onRetry,
  ) {
    return Row(
      children: [
        Icon(Icons.error_outline, size: 16, color: theme.colorScheme.error),
        const SizedBox(width: AppSpacing.xs),
        Expanded(
          child: Text(
            l10n.aiLoadFailed,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.error,
            ),
          ),
        ),
        TextButton(onPressed: onRetry, child: Text(l10n.aiRetry)),
      ],
    );
  }
}

/// 工具栏按钮
///
/// 支持默认、选中、加载、禁用四种视觉状态。
/// 按钮高度 36dp，圆角 8dp，图标 16dp + labelMedium 文字。
class _ToolbarButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isActive;
  final bool isLoading;
  final bool isDisabled;
  final VoidCallback onTap;
  final String? disabledMessage;

  const _ToolbarButton({
    required this.label,
    required this.icon,
    this.isActive = false,
    this.isLoading = false,
    this.isDisabled = false,
    required this.onTap,
    this.disabledMessage,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    // 根据状态决定颜色
    final Color backgroundColor;
    final Color foregroundColor;
    final Border? border;

    if (isDisabled) {
      backgroundColor = colorScheme.surfaceContainerHighest.withValues(
        alpha: 0.3,
      );
      foregroundColor = colorScheme.onSurfaceVariant.withValues(alpha: 0.38);
      border = null;
    } else if (isActive || isLoading) {
      backgroundColor = colorScheme.primaryContainer;
      foregroundColor = colorScheme.primary;
      border = Border.all(color: colorScheme.primary, width: 1);
    } else {
      backgroundColor = colorScheme.surfaceContainerHighest.withValues(
        alpha: 0.5,
      );
      foregroundColor = colorScheme.onSurfaceVariant;
      border = null;
    }

    return GestureDetector(
      onTap: () {
        if (isLoading) return;
        if (isDisabled) {
          if (disabledMessage != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(disabledMessage!),
                duration: const Duration(seconds: 2),
              ),
            );
          }
          return;
        }
        onTap();
      },
      child: Container(
        height: 36,
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(8),
          border: border,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (isLoading)
              SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: foregroundColor,
                ),
              )
            else
              Icon(icon, size: 16, color: foregroundColor),
            const SizedBox(width: 4),
            Text(
              label,
              style: theme.textTheme.labelMedium?.copyWith(
                color: foregroundColor,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
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
