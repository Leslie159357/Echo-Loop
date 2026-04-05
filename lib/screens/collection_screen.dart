// 合集列表页面及可复用组件
//
// 原 CollectionScreen 保留用于 import，
// 内部组件（排序按钮、列表/网格视图、空状态、对话框）
// 导出供 LibraryScreen 复用。
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../models/collection.dart';
import '../providers/collection_provider.dart';
import '../l10n/app_localizations.dart';
import '../router/app_router.dart';
import '../theme/app_theme.dart';
import '../widgets/dialogs/confirm_dialog.dart';
import '../widgets/dialogs/text_input_dialog.dart';

/// 合集排序按钮（公开供 LibraryScreen 使用）
class CollectionSortButton extends ConsumerWidget {
  const CollectionSortButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    return PopupMenuButton<CollectionSortType>(
      icon: const Icon(Icons.sort),
      onSelected: (type) {
        ref.read(collectionListProvider.notifier).setSortType(type);
      },
      itemBuilder: (context) {
        final current = ref.read(collectionListProvider).sortType;
        return [
          _sortMenuItem(
            l10n.sortByNameAsc,
            CollectionSortType.nameAsc,
            current,
          ),
          _sortMenuItem(
            l10n.sortByNameDesc,
            CollectionSortType.nameDesc,
            current,
          ),
          _sortMenuItem(
            l10n.sortByDateAsc,
            CollectionSortType.dateAsc,
            current,
          ),
          _sortMenuItem(
            l10n.sortByDateDesc,
            CollectionSortType.dateDesc,
            current,
          ),
        ];
      },
    );
  }

  PopupMenuItem<CollectionSortType> _sortMenuItem(
    String label,
    CollectionSortType type,
    CollectionSortType current,
  ) {
    return PopupMenuItem(
      value: type,
      child: Row(
        children: [
          if (type == current)
            const Icon(Icons.check, size: 18)
          else
            const SizedBox(width: 18),
          const SizedBox(width: 8),
          Text(label),
        ],
      ),
    );
  }
}

/// 合集空状态视图
class CollectionEmptyState extends StatelessWidget {
  const CollectionEmptyState({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.collections_bookmark_outlined,
            size: 64,
            color: Theme.of(context).colorScheme.outline,
          ),
          const SizedBox(height: AppSpacing.m),
          Text(
            l10n.noCollectionsYet,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: AppSpacing.s),
          Text(
            l10n.tapToCreateCollection,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppSpacing.l),
          FilledButton.icon(
            onPressed: () => showCreateCollectionDialog(context),
            icon: const Icon(Icons.add),
            label: Text(l10n.createCollection),
          ),
        ],
      ),
    );
  }
}

/// 合集网格视图
class CollectionGridView extends StatelessWidget {
  final List<Collection> collections;

  const CollectionGridView({super.key, required this.collections});

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 180,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 0.85,
      ),
      itemCount: collections.length,
      itemBuilder: (context, index) {
        return _CollectionGridTile(collection: collections[index]);
      },
    );
  }
}

/// 合集列表视图
class CollectionListView extends StatelessWidget {
  final List<Collection> collections;

  const CollectionListView({super.key, required this.collections});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: collections.length,
      itemBuilder: (context, index) {
        return _CollectionListTile(collection: collections[index]);
      },
    );
  }
}

/// 显示创建合集对话框（公开供 LibraryScreen 使用）
///
/// 需要 [WidgetRef] 来读取合集列表状态并创建合集。
void showCreateCollectionDialog(BuildContext context) {
  // 从 context 中找到最近的 ProviderScope
  final container = ProviderScope.containerOf(context);
  final l10n = AppLocalizations.of(context)!;

  showTextInputDialog(
    context: context,
    title: l10n.createCollection,
    labelText: l10n.collectionName,
    hintText: l10n.enterCollectionName,
    confirmLabel: l10n.add,
    cancelLabel: l10n.cancel,
    validator: (name) {
      if (name.isEmpty) return l10n.collectionNameEmpty;
      final collectionState = container.read(collectionListProvider);
      final exists = collectionState.collections.any(
        (c) => c.name.toLowerCase() == name.toLowerCase(),
      );
      if (exists) return l10n.collectionNameExists;
      return null;
    },
  ).then((name) {
    if (name != null) {
      container.read(collectionListProvider.notifier).createCollection(name);
    }
  });
}

/// 文件夹网格卡片
class _CollectionGridTile extends ConsumerWidget {
  final Collection collection;

  const _CollectionGridTile({required this.collection});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final collectionState = ref.watch(collectionListProvider);
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _openCollection(context),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Column(
            children: [
              // 顶部操作栏：星标 + 更多
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  SizedBox(
                    width: 32,
                    height: 32,
                    child: IconButton(
                      padding: EdgeInsets.zero,
                      iconSize: 18,
                      icon: Icon(
                        collection.isStarred ? Icons.star : Icons.star_border,
                        color: collection.isStarred
                            ? AppTheme.bookmarkColor.withValues(alpha: 0.7)
                            : Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                      ),
                      onPressed: () {
                        ref
                            .read(collectionListProvider.notifier)
                            .toggleStar(collection.id);
                      },
                    ),
                  ),
                  SizedBox(
                    width: 32,
                    height: 32,
                    child: PopupMenuButton(
                      padding: EdgeInsets.zero,
                      iconSize: 18,
                      iconColor: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                      itemBuilder: (context) => [
                        PopupMenuItem(
                          value: 'rename',
                          child: Row(
                            children: [
                              const Icon(Icons.edit, size: 18),
                              const SizedBox(width: 8),
                              Text(l10n.renameCollection),
                            ],
                          ),
                        ),
                        PopupMenuItem(
                          value: 'delete',
                          child: Row(
                            children: [
                              Icon(
                                Icons.delete,
                                size: 18,
                                color: Theme.of(context).colorScheme.error,
                              ),
                              const SizedBox(width: 8),
                              Text(l10n.delete),
                            ],
                          ),
                        ),
                      ],
                      onSelected: (value) {
                        if (value == 'rename') {
                          _showRenameCollectionDialog(context, ref, collection);
                        } else if (value == 'delete') {
                          _showDeleteConfirmDialog(context, ref, collection);
                        }
                      },
                    ),
                  ),
                ],
              ),
              // 文件夹图标
              CircleAvatar(
                radius: 28,
                backgroundColor: Colors.transparent,
                child: Icon(
                  Icons.folder,
                  size: 32,
                  color: collection.isStarred
                      ? AppTheme.bookmarkColor
                      : Theme.of(context).colorScheme.primary,
                ),
              ),
              const SizedBox(height: 4),
              // 合集名称
              Text(
                collection.name,
                style: Theme.of(context).textTheme.titleSmall,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 2),
              // 音频数量
              Text(
                l10n.audioCount(collectionState.getAudioCount(collection.id)),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openCollection(BuildContext context) {
    context.push(AppRoutes.collectionDetail(collection.id));
  }
}

/// 列表项
class _CollectionListTile extends ConsumerWidget {
  final Collection collection;

  const _CollectionListTile({required this.collection});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final collectionState = ref.watch(collectionListProvider);
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      child: ListTile(
        leading: Icon(
          collection.isStarred ? Icons.folder_special : Icons.folder,
          color: collection.isStarred
              ? AppTheme.bookmarkColor
              : Theme.of(context).colorScheme.onPrimaryContainer,
        ),
        title: Text(
          collection.name,
          style: const TextStyle(fontWeight: FontWeight.w500),
        ),
        subtitle: Text(
          '${l10n.audioCount(collectionState.getAudioCount(collection.id))} · ${l10n.addedOn(_formatDate(collection.createdDate))}',
          style: Theme.of(context).textTheme.bodySmall,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 36,
              child: IconButton(
                icon: Icon(
                  collection.isStarred ? Icons.star : Icons.star_border,
                  color: collection.isStarred
                      ? AppTheme.bookmarkColor.withValues(alpha: 0.7)
                      : Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                  size: 22,
                ),
                padding: EdgeInsets.zero,
                onPressed: () {
                  ref
                      .read(collectionListProvider.notifier)
                      .toggleStar(collection.id);
                },
              ),
            ),
            SizedBox(
              width: 36,
              child: PopupMenuButton(
                padding: EdgeInsets.zero,
                iconSize: 22,
                iconColor: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: 'rename',
                    child: Row(
                      children: [
                        const Icon(Icons.edit),
                        const SizedBox(width: 8),
                        Text(l10n.renameCollection),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(
                          Icons.delete,
                          color: Theme.of(context).colorScheme.error,
                        ),
                        const SizedBox(width: 8),
                        Text(l10n.delete),
                      ],
                    ),
                  ),
                ],
                onSelected: (value) {
                  if (value == 'rename') {
                    _showRenameCollectionDialog(context, ref, collection);
                  } else if (value == 'delete') {
                    _showDeleteConfirmDialog(context, ref, collection);
                  }
                },
              ),
            ),
          ],
        ),
        onTap: () => _openCollection(context),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.month}/${date.day}/${date.year}';
  }

  void _openCollection(BuildContext context) {
    context.push(AppRoutes.collectionDetail(collection.id));
  }
}

// ===== 公共辅助方法 =====

/// 重命名合集对话框
void _showRenameCollectionDialog(
  BuildContext context,
  WidgetRef ref,
  Collection collection,
) async {
  final l10n = AppLocalizations.of(context)!;

  final name = await showTextInputDialog(
    context: context,
    title: l10n.renameCollection,
    labelText: l10n.collectionName,
    initialValue: collection.name,
    confirmLabel: l10n.ok,
    cancelLabel: l10n.cancel,
  );

  if (name != null) {
    ref
        .read(collectionListProvider.notifier)
        .renameCollection(collection.id, name);
  }
}

/// 删除确认对话框
void _showDeleteConfirmDialog(
  BuildContext context,
  WidgetRef ref,
  Collection collection,
) async {
  final l10n = AppLocalizations.of(context)!;

  final confirmed = await showConfirmDialog(
    context: context,
    title: l10n.deleteCollection,
    message: l10n.deleteCollectionConfirm(collection.name),
    icon: Icons.warning_amber_rounded,
    isDestructive: true,
    confirmLabel: l10n.delete,
    cancelLabel: l10n.cancel,
  );

  if (confirmed == true) {
    ref.read(collectionListProvider.notifier).deleteCollection(collection.id);
  }
}
