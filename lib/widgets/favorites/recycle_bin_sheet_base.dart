/// 回收站弹窗公共组件
///
/// 提供弹窗骨架、左滑操作组件和排序枚举，
/// 供句子回收站和词汇回收站弹窗复用。
library;

import 'package:flutter/material.dart';

import '../../database/daos/bookmark_dao.dart' show RecycleBinSortMode;
import '../../l10n/app_localizations.dart';
import '../../theme/app_theme.dart';

export '../../database/daos/bookmark_dao.dart' show RecycleBinSortMode;

/// 打开回收站底部弹窗的公共方法
Future<void> showRecycleBinSheet({
  required BuildContext context,
  required WidgetBuilder builder,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: builder,
  );
}

/// 回收站弹窗骨架
///
/// 包含拖动指示条、标题行（标题+数量+清空按钮+排序按钮）、
/// 以及列表/空状态内容区。
class RecycleBinSheetScaffold extends StatelessWidget {
  /// 条目总数
  final int itemCount;

  /// 是否正在加载
  final bool isLoading;

  /// 当前排序方式
  final RecycleBinSortMode sortMode;

  /// 排序变更回调
  final ValueChanged<RecycleBinSortMode> onSortChanged;

  /// 清空回收站回调（null 表示禁用）
  final VoidCallback? onClearAll;

  /// 列表内容区
  final Widget child;

  const RecycleBinSheetScaffold({
    super.key,
    required this.itemCount,
    required this.isLoading,
    required this.sortMode,
    required this.onSortChanged,
    required this.onClearAll,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return SafeArea(
      child: FractionallySizedBox(
        heightFactor: 0.82,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.l,
            12,
            AppSpacing.l,
            AppSpacing.l,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 拖动指示条
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.outlineVariant,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              // 标题行
              Row(
                children: [
                  Expanded(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          l10n.recycleBinTitle,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          l10n.recycleBinItemCount(itemCount),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // 清空按钮
                  if (itemCount > 0)
                    IconButton(
                      icon: const Icon(Icons.delete_sweep_rounded, size: 20),
                      visualDensity: VisualDensity.compact,
                      color: theme.colorScheme.error,
                      onPressed: onClearAll,
                    ),
                  const SizedBox(width: 4),
                  // 排序按钮
                  _SortButton(sortMode: sortMode, onSortChanged: onSortChanged),
                ],
              ),
              const SizedBox(height: AppSpacing.m),
              // 内容区
              Expanded(
                child: isLoading
                    ? const Center(child: CircularProgressIndicator.adaptive())
                    : itemCount == 0
                    ? _EmptyState()
                    : child,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 排序按钮
class _SortButton extends StatelessWidget {
  final RecycleBinSortMode sortMode;
  final ValueChanged<RecycleBinSortMode> onSortChanged;

  const _SortButton({required this.sortMode, required this.onSortChanged});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return PopupMenuButton<RecycleBinSortMode>(
      initialValue: sortMode,
      onSelected: onSortChanged,
      itemBuilder: (context) => [
        PopupMenuItem(
          value: RecycleBinSortMode.timeDesc,
          child: Text(l10n.recycleBinSortTimeDesc),
        ),
        PopupMenuItem(
          value: RecycleBinSortMode.timeAsc,
          child: Text(l10n.recycleBinSortTimeAsc),
        ),
        PopupMenuItem(
          value: RecycleBinSortMode.alphaAsc,
          child: Text(l10n.flashcardSortAlphaAsc),
        ),
        PopupMenuItem(
          value: RecycleBinSortMode.alphaDesc,
          child: Text(l10n.flashcardSortAlphaDesc),
        ),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest.withValues(
            alpha: 0.5,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.tune_rounded,
              size: 18,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 6),
            Text(
              _sortLabel(l10n, sortMode),
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _sortLabel(AppLocalizations l10n, RecycleBinSortMode mode) {
    return switch (mode) {
      RecycleBinSortMode.timeDesc => l10n.recycleBinSortTimeDesc,
      RecycleBinSortMode.timeAsc => l10n.recycleBinSortTimeAsc,
      RecycleBinSortMode.alphaAsc => l10n.flashcardSortAlphaAsc,
      RecycleBinSortMode.alphaDesc => l10n.flashcardSortAlphaDesc,
    };
  }
}

/// 空状态组件
class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.restore_from_trash_rounded,
              size: 56,
              color: theme.colorScheme.outline.withValues(alpha: 0.5),
            ),
            const SizedBox(height: AppSpacing.m),
            Text(
              l10n.recycleBinEmpty,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 回收站左滑删除组件
///
/// 左滑直接永久删除。
class RecycleBinDismissible extends StatelessWidget {
  /// 唯一标识
  final Key dismissKey;

  /// 永久删除回调
  final VoidCallback onDelete;

  /// 子组件
  final Widget child;

  const RecycleBinDismissible({
    super.key,
    required this.dismissKey,
    required this.onDelete,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Dismissible(
      key: dismissKey,
      direction: DismissDirection.endToStart,
      onDismissed: (_) => onDelete(),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: AppSpacing.l),
        color: theme.colorScheme.error,
        child: Icon(
          Icons.delete_forever_rounded,
          color: theme.colorScheme.onError,
        ),
      ),
      child: child,
    );
  }
}

/// 恢复收藏按钮（书签图标）
///
/// 点击后将条目从回收站恢复到收藏列表。
class RecycleBinRestoreButton extends StatelessWidget {
  /// 恢复回调
  final VoidCallback onRestore;

  const RecycleBinRestoreButton({super.key, required this.onRestore});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return IconButton(
      icon: const Icon(Icons.bookmark_add_outlined),
      color: theme.colorScheme.primary,
      visualDensity: VisualDensity.compact,
      onPressed: onRestore,
    );
  }
}
