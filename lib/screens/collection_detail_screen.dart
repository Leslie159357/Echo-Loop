// 合集详情页面
//
// 展示合集中的音频列表，复用 AudioListView 和 AudioSortButton。
// 支持上传音频到合集。
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/audio_item.dart';
import '../models/collection.dart';
import '../providers/collection_provider.dart';
import '../providers/audio_library_provider.dart';
import '../providers/new_user_guide_provider.dart';
import '../l10n/app_localizations.dart';
import '../theme/app_theme.dart';
import '../widgets/add_audio_dialog.dart';
import '../widgets/audio_list_view.dart';
import '../widgets/guide_flow.dart';
import '../widgets/manage_subtitles_sheet.dart';

/// 合集详情页面 - 展示合集中的音频，支持上传音频
class CollectionDetailScreen extends ConsumerStatefulWidget {
  final String collectionId;

  const CollectionDetailScreen({super.key, required this.collectionId});

  @override
  ConsumerState<CollectionDetailScreen> createState() =>
      _CollectionDetailScreenState();
}

class _CollectionDetailScreenState
    extends ConsumerState<CollectionDetailScreen> {
  final _keyUpload = GlobalKey();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final collectionState = ref.watch(collectionListProvider);
    ref.watch(audioLibraryProvider); // watch to rebuild when library changes

    final collection = collectionState.rawCollections
        .where((c) => c.id == widget.collectionId)
        .firstOrNull;
    if (collection == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: Text('Collection not found')),
      );
    }

    // 获取合集中的音频项（从 junction 表缓存中读取）
    final audioIds = collectionState.getAudioIds(widget.collectionId);
    final audioItems = audioIds
        .map((id) => ref.read(audioLibraryProvider.notifier).getItemById(id))
        .whereType<AudioItem>()
        .toList();

    final hasAudioItems = audioItems.isNotEmpty;

    final stepUpload = GuideStep(
      key: _keyUpload,
      title: l10n.guideCollectionUploadTitle,
      description: l10n.guideCollectionUploadDescription,
    );

    return GuideFlowSequenceHost(
      flows: [
        GuideFlow(
          flowId: GuideFlowIds.collectionDetailUpload,
          shouldRun: true,
          steps: [stepUpload],
        ),
      ],
      child: Scaffold(
        appBar: AppBar(
          title: Text(collection.name),
          actions: [
            // 排序按钮（复用公开的 AudioSortButton）
            const AudioSortButton(),
            GuideTarget(
              step: stepUpload,
              child: IconButton(
                icon: const Icon(Icons.add),
                onPressed: () => _showAddAudioDialog(context, collection),
              ),
            ),
          ],
        ),
        body: AudioListView(
          items: audioItems,
          collectionId: widget.collectionId,
          guideFirstAudioMenu: hasAudioItems,
          guideLeadingItems: hasAudioItems,
          emptyState: _CollectionEmptyState(
            l10n: l10n,
            onAdd: () => _showAddAudioDialog(context, collection),
          ),
        ),
      ),
    );
  }

  /// 显示添加音频对话框，添加成功后弹字幕确认
  void _showAddAudioDialog(BuildContext context, Collection collection) async {
    final results = await showDialog<List<AudioItem>>(
      context: context,
      builder: (context) => AddAudioDialog(collectionId: collection.id),
    );
    if (results == null || results.isEmpty || !context.mounted) return;

    if (results.length == 1) {
      // 单文件：保持字幕提示流程
      final l10n = AppLocalizations.of(context)!;
      final wantSubtitle = await _showSubtitlePrompt(context, l10n);
      if (wantSubtitle && context.mounted) {
        showModalBottomSheet(
          context: context,
          builder: (_) => ManageSubtitlesSheet(audioItem: results.first),
        );
      }
    } else {
      // 多文件：显示成功提示
      if (context.mounted) {
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

/// 合集空状态视图
class _CollectionEmptyState extends StatelessWidget {
  final AppLocalizations l10n;
  final VoidCallback onAdd;

  const _CollectionEmptyState({required this.l10n, required this.onAdd});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.library_music_outlined,
            size: 64,
            color: theme.colorScheme.outline,
          ),
          const SizedBox(height: AppSpacing.m),
          Text(l10n.emptyCollection, style: theme.textTheme.titleLarge),
          const SizedBox(height: AppSpacing.s),
          Text(
            l10n.tapToAddAudio,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppSpacing.l),
          FilledButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.add),
            label: Text(l10n.addAudioToCollection),
          ),
        ],
      ),
    );
  }
}
