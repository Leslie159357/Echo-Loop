// 资源库页面
//
// 包含 SegmentedButton 切换合集/音频双视图，
// 使用 IndexedStack 保持两个视图状态。
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/audio_item.dart';
import '../providers/new_user_guide_provider.dart';
import '../providers/collection_provider.dart';
import '../l10n/app_localizations.dart';
import '../widgets/audio_list_view.dart';
import '../widgets/add_audio_dialog.dart';
import '../widgets/guide_flow.dart';
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

  // Guide steps 的 GlobalKey 在 state 层持有，保证整个 screen 生命周期内稳定。
  // 同一个 step 会同时被 GuideFlow.steps 和对应的 GuideTarget 引用。
  final _keyCollectionList = GlobalKey();
  final _keyCollectionMenu = GlobalKey();
  final _keyCreateCollection = GlobalKey();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final collectionState = ref.watch(collectionListProvider);
    final shouldRunCollectionGuide =
        _currentView == LibraryViewType.collections &&
        !collectionState.isLoading;
    final hasCollections = collectionState.collections.isNotEmpty;

    final stepCollectionList = GuideStep(
      key: _keyCollectionList,
      title: l10n.guideLibraryCollectionListTitle,
      description: l10n.guideLibraryCollectionListDescription,
    );
    final stepCollectionMenu = GuideStep(
      key: _keyCollectionMenu,
      title: l10n.guideLibraryCollectionMenuTitle,
      description: l10n.guideLibraryCollectionMenuDescription,
    );
    final stepCreateCollection = GuideStep(
      key: _keyCreateCollection,
      title: l10n.guideLibraryCreateCollectionTitle,
      description: l10n.guideLibraryCreateCollectionDescription,
    );

    return GuideFlowSequenceHost(
      flows: [
        GuideFlow(
          flowId: GuideFlowIds.libraryCollectionList,
          shouldRun: shouldRunCollectionGuide && hasCollections,
          steps: [stepCollectionList, if (hasCollections) stepCollectionMenu],
        ),
        GuideFlow(
          flowId: GuideFlowIds.libraryCreateCollection,
          shouldRun: shouldRunCollectionGuide,
          steps: [stepCreateCollection],
        ),
      ],
      child: Scaffold(
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
          actions: _buildActions(l10n, stepCreateCollection),
        ),
        body: IndexedStack(
          index: _currentView.index,
          children: [
            _CollectionListBody(
              listStep: stepCollectionList,
              menuStep: stepCollectionMenu,
            ),
            AudioListView(
              guideFirstAudioMenu: true,
              guideLeadingItems: true,
              guideEnabled: _currentView == LibraryViewType.audio,
            ),
          ],
        ),
      ),
    );
  }

  /// 根据当前视图构建 AppBar actions
  List<Widget> _buildActions(AppLocalizations l10n, GuideStep createStep) {
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
              onPressed: () =>
                  ref.read(collectionListProvider.notifier).toggleViewMode(),
            );
          },
        ),
        // 创建合集
        GuideTarget(
          step: createStep,
          child: IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => showCreateCollectionDialog(context),
          ),
        ),
      ];
    } else {
      return [
        // 音频排序
        const AudioSortButton(),
        // 添加音频
        IconButton(icon: const Icon(Icons.add), onPressed: _handleAddAudio),
      ];
    }
  }

  Future<void> _handleAddAudio() async {
    final results = await showDialog<List<AudioItem>>(
      context: context,
      builder: (dialogContext) => const AddAudioDialog(),
    );
    if (results == null || results.isEmpty || !mounted) return;

    if (results.length == 1) {
      // 单文件：保持字幕提示流程
      final l10n = AppLocalizations.of(context)!;
      final wantSubtitle = await _showSubtitlePrompt(context, l10n);
      if (!mounted || !wantSubtitle) return;

      showModalBottomSheet(
        context: context,
        builder: (_) => ManageSubtitlesSheet(audioItem: results.first),
      );
    } else {
      // 多文件：显示成功提示
      if (mounted) {
        final l10n = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.multipleAudioAdded(results.length))),
        );
      }
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
  final GuideStep listStep;
  final GuideStep menuStep;

  const _CollectionListBody({required this.listStep, required this.menuStep});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final collectionState = ref.watch(collectionListProvider);

    if (collectionState.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (collectionState.isEmpty) return const CollectionEmptyState();

    final collections = collectionState.collections;
    if (collectionState.viewMode == CollectionViewMode.grid) {
      return CollectionGridView(
        collections: collections,
        firstItemStep: listStep,
        firstMenuStep: menuStep,
      );
    }
    return CollectionListView(
      collections: collections,
      firstItemStep: listStep,
      firstMenuStep: menuStep,
    );
  }
}
