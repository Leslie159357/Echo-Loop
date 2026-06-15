// 合集详情页面
//
// 展示合集中的音频列表，复用 AudioListView 和 AudioSortButton。
// 支持上传音频到合集。
import 'dart:async';
import 'dart:convert';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/audio_item.dart';
import '../models/collection.dart';
import '../providers/collection_provider.dart';
import '../providers/audio_library_provider.dart';
import '../providers/new_user_guide_provider.dart';
import '../l10n/app_localizations.dart';
import '../theme/app_theme.dart';
import '../providers/audio_list_settings_provider.dart';
import '../widgets/audio_list_view.dart';
import '../widgets/guide_flow.dart';
import '../widgets/import_audio_sheet.dart';
import '../features/podcast/podcast_repository.dart';
import '../features/podcast/podcast_models.dart';
import '../features/podcast/podcast_info_sheet.dart';

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
  _PodcastRefreshViewState? _podcastRefreshState;

  /// 官方合集的排序状态，页面内独立持有（不走全局 audioListSettingsProvider，
  /// 避免污染资源库 / 用户自建合集的排序偏好）。首次打开默认「官方编排顺序」。
  AudioSortType _officialSort = AudioSortType.custom;

  /// 官方合集排序菜单的可选项
  static const _officialAllowedSorts = [
    AudioSortType.custom,
    AudioSortType.nameAsc,
    AudioSortType.nameDesc,
    AudioSortType.originalDateAsc,
    AudioSortType.originalDateDesc,
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_refreshPodcastFeed(force: false));
    });
  }

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
            // 官方合集：独立 sort state + 5 项菜单（默认 / 名称×2 / 原始发布×2）
            // 用户合集：保持现状 —— 4 项默认菜单 + 全局 provider
            if (collection.isOfficial)
              AudioSortButton(
                allowedTypes: _officialAllowedSorts,
                current: _officialSort,
                onChanged: (t) => setState(() => _officialSort = t),
              )
            else
              const AudioSortButton(),
            // 官方合集 / podcast 合集禁止手动添加/删除音频，按钮隐藏
            if (!collection.isOfficial && !collection.isPodcast)
              GuideTarget(
                step: stepUpload,
                child: IconButton(
                  icon: const Icon(Icons.add),
                  onPressed: () => showImportAudioSheet(
                    context,
                    collectionId: collection.id,
                  ),
                ),
              ),
          ],
        ),
        body: collection.isPodcast
            ? _PodcastCollectionBody(
                collection: collection,
                audioItems: audioItems,
                guideFirstAudioMenu: hasAudioItems,
                guideLeadingItems: hasAudioItems,
                refreshState: _podcastRefreshState,
                onRefresh: () => _refreshPodcastFeed(force: true),
              )
            : AudioListView(
                items: audioItems,
                collectionId: widget.collectionId,
                guideFirstAudioMenu: hasAudioItems,
                guideLeadingItems: hasAudioItems,
                overrideSortType: collection.isOfficial ? _officialSort : null,
                emptyState: collection.isOfficial
                    ? Center(
                        child: Text(
                          // 区分「已下架」vs「暂无音频」：前者是后端主动下线，后者
                          // 是合集刚建还没上内容，两种文案语义不同不能复用。
                          collection.isDeprecated
                              ? l10n.officialCollectionDeprecated
                              : l10n.officialCollectionEmpty,
                          textAlign: TextAlign.center,
                        ),
                      )
                    : _CollectionEmptyState(
                        l10n: l10n,
                        onAdd: () => showImportAudioSheet(
                          context,
                          collectionId: collection.id,
                        ),
                      ),
              ),
      ),
    );
  }

  /// 刷新 podcast feed。
  ///
  /// 进入页面时走普通刷新，交给 repository 的通用刷新策略节流；
  /// 下拉时传 force=true 强制拉取 RSS。
  Future<void> _refreshPodcastFeed({required bool force}) async {
    if (force && mounted) {
      setState(() {
        _podcastRefreshState = _PodcastRefreshViewState.refreshing(
          DateTime.now(),
        );
      });
    }
    try {
      await ref
          .read(podcastRepositoryProvider)
          .refresh(widget.collectionId, force: force);
      if (!mounted || !force) return;
      setState(() {
        _podcastRefreshState = null;
      });
    } catch (e) {
      if (!mounted || !force) return;
      setState(() {
        _podcastRefreshState = null;
      });
      final l10n = AppLocalizations.of(context)!;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.podcastSubscribeFailed(e.toString()))),
      );
    }
  }
}

class _PodcastRefreshViewState {
  final DateTime time;

  const _PodcastRefreshViewState._(this.time);

  factory _PodcastRefreshViewState.refreshing(DateTime time) =>
      _PodcastRefreshViewState._(time);
}

String? _podcastRefreshStatusText(
  AppLocalizations l10n,
  Collection collection,
  _PodcastRefreshViewState? state,
) {
  return podcastRefreshStatusText(l10n, collection, refreshingAt: state?.time);
}

/// Podcast 合集详情内容：顶部展示 Feed 元信息，下面复用音频列表。
class _PodcastCollectionBody extends StatelessWidget {
  final Collection collection;
  final List<AudioItem> audioItems;
  final bool guideFirstAudioMenu;
  final bool guideLeadingItems;
  final _PodcastRefreshViewState? refreshState;
  final Future<void> Function() onRefresh;

  const _PodcastCollectionBody({
    required this.collection,
    required this.audioItems,
    required this.guideFirstAudioMenu,
    required this.guideLeadingItems,
    required this.refreshState,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Column(
      children: [
        _PodcastFeedHeader(collection: collection, refreshState: refreshState),
        Expanded(
          child: RefreshIndicator(
            onRefresh: onRefresh,
            child: AudioListView(
              items: audioItems,
              collectionId: collection.id,
              guideFirstAudioMenu: guideFirstAudioMenu,
              guideLeadingItems: guideLeadingItems,
              emptyState: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  SizedBox(
                    height: MediaQuery.of(context).size.height * 0.5,
                    child: Center(
                      child: Text(
                        l10n.officialCollectionEmpty,
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _PodcastFeedHeader extends StatefulWidget {
  final Collection collection;
  final _PodcastRefreshViewState? refreshState;

  const _PodcastFeedHeader({
    required this.collection,
    required this.refreshState,
  });

  @override
  State<_PodcastFeedHeader> createState() => _PodcastFeedHeaderState();
}

class _PodcastFeedHeaderState extends State<_PodcastFeedHeader> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final meta = _decodeMeta(widget.collection.podcastMetaJson);
    final imageUrl = meta?.imageUrl ?? widget.collection.coverUrl;
    final description = meta?.description ?? widget.collection.description;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => showPodcastFeedInfoSheet(
          context,
          widget.collection,
          refreshStatusText: _podcastRefreshStatusText(
            l10n,
            widget.collection,
            widget.refreshState,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.m,
            AppSpacing.s,
            AppSpacing.m,
            AppSpacing.s,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _PodcastCover(imageUrl: imageUrl),
              const SizedBox(width: AppSpacing.m),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (description != null && description.isNotEmpty) ...[
                      Text(
                        description,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                          height: 1.25,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                    ],
                    Text(
                      l10n.podcastShowMore,
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  PodcastFeedMeta? _decodeMeta(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    try {
      return PodcastFeedMeta.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }
}

class _PodcastCover extends StatelessWidget {
  final String? imageUrl;

  const _PodcastCover({required this.imageUrl});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final placeholder = DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(
        Icons.podcasts_rounded,
        color: theme.colorScheme.onPrimaryContainer,
      ),
    );

    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: SizedBox(
        width: 56,
        height: 56,
        child: imageUrl == null || imageUrl!.isEmpty
            ? placeholder
            : CachedNetworkImage(
                imageUrl: imageUrl!,
                fit: BoxFit.cover,
                placeholder: (_, __) => placeholder,
                errorWidget: (_, __, ___) => placeholder,
              ),
      ),
    );
  }
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
