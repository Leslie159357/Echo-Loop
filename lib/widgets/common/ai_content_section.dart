/// AI 内容区块组件
///
/// 可折叠的 AI 内容展示区域，支持 4 种状态：
/// - collapsed: 折叠状态，只显示标题栏
/// - loading: 展开中，显示 shimmer 骨架屏
/// - loaded: 展开且内容已加载
/// - error: 加载失败，显示重试按钮
library;

import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../theme/app_theme.dart';
import 'shimmer_placeholder.dart';

/// AI 内容区块状态
enum AiContentState { collapsed, loading, loaded, error }

/// AI 内容区块组件
///
/// 点击标题栏展开/折叠。展开时自动触发 [onRequest] 加载内容。
/// 如果 [cachedContent] 非空，则直接展示，不触发请求。
class AiContentSection extends StatefulWidget {
  /// 标题图标
  final IconData icon;

  /// 标题文本
  final String title;

  /// 加载内容的回调，返回文本内容
  final Future<String> Function()? onRequest;

  /// 已缓存的内容（非空则直接展示）
  final String? cachedContent;

  /// 自定义内容渲染（默认渲染为 Text）
  final Widget Function(String content)? contentBuilder;

  const AiContentSection({
    super.key,
    required this.icon,
    required this.title,
    this.onRequest,
    this.cachedContent,
    this.contentBuilder,
  });

  @override
  State<AiContentSection> createState() => _AiContentSectionState();
}

class _AiContentSectionState extends State<AiContentSection> {
  AiContentState _state = AiContentState.collapsed;
  String? _content;

  @override
  void initState() {
    super.initState();
    // 预存缓存内容，但不自动展开（用户点击时可立即显示）
    if (widget.cachedContent != null) {
      _content = widget.cachedContent;
    }
  }

  @override
  void didUpdateWidget(AiContentSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 缓存内容变化时同步更新
    if (widget.cachedContent != oldWidget.cachedContent) {
      if (widget.cachedContent != null) {
        _content = widget.cachedContent;
        // 仅在用户已主动请求（loading 状态）时自动展开，
        // 避免切换句子或多遍播放时因缓存存在而自动展开
        if (_state == AiContentState.loading) {
          _state = AiContentState.loaded;
        }
      } else {
        _content = null;
        _state = AiContentState.collapsed;
      }
    }
  }

  void _toggle() {
    if (_state == AiContentState.collapsed) {
      _expand();
    } else {
      setState(() => _state = AiContentState.collapsed);
    }
  }

  Future<void> _expand() async {
    // 已有内容直接展示
    if (_content != null) {
      setState(() => _state = AiContentState.loaded);
      return;
    }

    if (widget.onRequest == null) return;

    setState(() => _state = AiContentState.loading);
    try {
      final result = await widget.onRequest!();
      if (mounted) {
        setState(() {
          _content = result;
          _state = AiContentState.loaded;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _state = AiContentState.error);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final isExpanded = _state != AiContentState.collapsed;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 标题栏（点击展开/折叠）
          InkWell(
            onTap: _toggle,
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.m,
                vertical: AppSpacing.s,
              ),
              child: Row(
                children: [
                  Icon(widget.icon, size: 18, color: theme.colorScheme.primary),
                  const SizedBox(width: AppSpacing.s),
                  Expanded(
                    child: Text(
                      widget.title,
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ),
                  Icon(
                    isExpanded ? Icons.expand_less : Icons.expand_more,
                    size: 20,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ],
              ),
            ),
          ),

          // 内容区域
          if (isExpanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.m,
                0,
                AppSpacing.m,
                AppSpacing.m,
              ),
              child: _buildContent(theme, l10n),
            ),
        ],
      ),
    );
  }

  Widget _buildContent(ThemeData theme, AppLocalizations l10n) {
    return switch (_state) {
      AiContentState.loading => const ShimmerPlaceholder(),
      AiContentState.loaded => _buildLoadedContent(theme),
      AiContentState.error => _buildErrorContent(theme, l10n),
      AiContentState.collapsed => const SizedBox.shrink(),
    };
  }

  Widget _buildLoadedContent(ThemeData theme) {
    final content = _content ?? '';
    if (widget.contentBuilder != null) {
      return widget.contentBuilder!(content);
    }
    return Text(
      content,
      style: theme.textTheme.bodyMedium?.copyWith(
        color: theme.colorScheme.onSurfaceVariant,
        height: 1.5,
      ),
    );
  }

  Widget _buildErrorContent(ThemeData theme, AppLocalizations l10n) {
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
        TextButton(onPressed: _expand, child: Text(l10n.aiRetry)),
      ],
    );
  }
}
