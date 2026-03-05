// 资源库页面
//
// 包含 SegmentedButton 切换合集/音频双视图，
// 使用 IndexedStack 保持两个视图状态。
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/audio_item.dart';
import '../providers/collection_provider.dart';
import '../l10n/app_localizations.dart';
import '../widgets/audio_list_view.dart';
import '../widgets/add_audio_dialog.dart';
import '../widgets/manage_subtitles_sheet.dart';
import 'collection_screen.dart';

// AudioSortButton 已提取到 audio_list_view.dart 中作为公开组件

/// 资源库视图类型
enum LibraryViewType { collections, audio }

/// 资源库页面 — 合集/音频双视图
class LibraryScreen extends ConsumerStatefulWidget {
  const LibraryScreen({super.key});

  @override
  ConsumerState<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends ConsumerState<LibraryScreen> {
  LibraryViewType _currentView = LibraryViewType.collections;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: SegmentedButton<LibraryViewType>(
          segments: [
            ButtonSegment(
              value: LibraryViewType.collections,
              label: Text(l10n.collectionsTab),
            ),
            ButtonSegment(
              value: LibraryViewType.audio,
              label: Text(l10n.audioTab),
            ),
          ],
          selected: {_currentView},
          onSelectionChanged: (selected) {
            setState(() {
              _currentView = selected.first;
            });
          },
          showSelectedIcon: false,
          style: ButtonStyle(
            visualDensity: VisualDensity.compact,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ),
        actions: _buildActions(l10n),
      ),
      body: IndexedStack(
        index: _currentView.index,
        children: const [_CollectionListBody(), AudioListView()],
      ),
    );
  }

  /// 根据当前视图构建 AppBar actions
  List<Widget> _buildActions(AppLocalizations l10n) {
    if (_currentView == LibraryViewType.collections) {
      return [
        // 合集排序
        const CollectionSortButton(),
        // 视图切换
        Consumer(
          builder: (context, ref, _) {
            final viewMode = ref.watch(
              collectionListProvider.select((s) => s.viewMode),
            );
            final isGrid = viewMode == CollectionViewMode.grid;
            return IconButton(
              icon: Icon(isGrid ? Icons.view_list : Icons.grid_view),
              tooltip: isGrid ? l10n.listView : l10n.gridView,
              onPressed: () =>
                  ref.read(collectionListProvider.notifier).toggleViewMode(),
            );
          },
        ),
        // 创建合集
        IconButton(
          icon: const Icon(Icons.add),
          tooltip: l10n.createCollection,
          onPressed: () => showCreateCollectionDialog(context),
        ),
      ];
    } else {
      return [
        // 音频排序
        const AudioSortButton(),
        // 添加音频
        IconButton(
          icon: const Icon(Icons.add),
          tooltip: l10n.addAudio,
          onPressed: () async {
            final result = await showDialog<AudioItem>(
              context: context,
              builder: (context) => const AddAudioDialog(),
            );
            if (result != null && context.mounted) {
              final l = AppLocalizations.of(context)!;
              final wantSubtitle = await _showSubtitlePrompt(context, l);
              if (wantSubtitle && context.mounted) {
                showModalBottomSheet(
                  context: context,
                  builder: (_) => ManageSubtitlesSheet(audioItem: result),
                );
              }
            }
          },
        ),
      ];
    }
  }
}

/// 添加音频后弹出字幕确认对话框
Future<bool> _showSubtitlePrompt(
  BuildContext context,
  AppLocalizations l10n,
) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(l10n.addSubtitlePromptTitle),
      content: Text(l10n.addSubtitlePromptMessage),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: Text(l10n.cancel),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(l10n.addSubtitle),
        ),
      ],
    ),
  );
  return result ?? false;
}

/// 合集列表视图体（不含 Scaffold/AppBar）
class _CollectionListBody extends ConsumerWidget {
  const _CollectionListBody();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final collectionState = ref.watch(collectionListProvider);

    if (collectionState.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (collectionState.isEmpty) {
      return const CollectionEmptyState();
    }

    final collections = collectionState.collections;
    if (collectionState.viewMode == CollectionViewMode.grid) {
      return CollectionGridView(collections: collections);
    } else {
      return CollectionListView(collections: collections);
    }
  }
}
