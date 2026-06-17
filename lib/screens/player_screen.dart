import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:universal_io/io.dart' show Platform;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:audio_video_progress_bar/audio_video_progress_bar.dart';
import '../l10n/app_localizations.dart';
import '../models/retell_settings.dart';
import '../models/sentence.dart';
import '../providers/listening_practice/listening_practice_provider.dart';
import '../providers/audio_engine/audio_engine_provider.dart';
import '../providers/collection_provider.dart';
import '../router/app_router.dart';
import '../services/subtitle_parser.dart';
import '../theme/app_theme.dart';
import '../widgets/playback_controls.dart';
import '../widgets/common/paragraph_sentence_list_card.dart';
import '../widgets/common/audio_app_bar_title.dart';
import '../widgets/settings_dialog.dart';
import '../widgets/player_hotkey_scope.dart';
import '../widgets/common/text_context_menu.dart';
import 'sentence_detail_screen.dart';

class PlayerScreen extends ConsumerStatefulWidget {
  const PlayerScreen({super.key});

  @override
  ConsumerState<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends ConsumerState<PlayerScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int _previousTabIndex = 0;

  /// 防止进入讲解页重入（点击主体区 → pause + 导航）
  bool _isNavigatingToDetail = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await ref
          .read(listeningPracticeProvider.notifier)
          .setPlaylistMode(PlaylistMode.full);
    });
    _tabController.addListener(() {
      if (_tabController.index != _previousTabIndex) {
        _previousTabIndex = _tabController.index;
        ref
            .read(listeningPracticeProvider.notifier)
            .setPlaylistMode(
              _tabController.index == 0
                  ? PlaylistMode.full
                  : PlaylistMode.bookmarks,
            );
      }
    });
  }

  @override
  void deactivate() {
    // 延迟到下一帧执行，避免在 widget 树销毁过程中修改 provider state
    final notifier = ref.read(listeningPracticeProvider.notifier);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      notifier.pause();
      notifier.saveCurrentPlaybackState();
    });
    super.deactivate();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final playerState = ref.watch(listeningPracticeProvider);
    final controller = ref.read(listeningPracticeProvider.notifier);

    final engineNotifier = ref.read(audioEngineProvider.notifier);

    return LearningHotkeyScope(
      onPlayPause: () =>
          engineNotifier.isPlaying ? controller.pause() : controller.play(),
      onPrevious: () {
        if (playerState.hasSentences) controller.previousSentence();
      },
      onNext: () {
        if (playerState.hasSentences) controller.nextSentence();
      },
      child: Scaffold(
        appBar: AppBar(
          titleSpacing: 0,
          title: _buildAppBarTitle(playerState, l10n),
          actions: [
            IconButton(
              icon: const Icon(Icons.tune),
              onPressed: () => _showSettingsDialog(context),
            ),
          ],
        ),
        body: !playerState.hasAudio
            ? Center(child: Text(l10n.noAudioLoaded))
            : _buildLayout(context, playerState),
      ),
    );
  }

  /// AppBar 标题：音频名为主标题，下方附带所属合集副标题。
  /// 与学习计划页共用 [AudioAppBarTitle] 且合集名同源（按音频 id 查
  /// [collectionListProvider] 的 audioToCollectionsMap），保证两页一致。
  Widget _buildAppBarTitle(
    ListeningPracticeState playerState,
    AppLocalizations l10n,
  ) {
    final audioItem = playerState.currentAudioItem;
    final audioName = audioItem?.name ?? l10n.player;
    final collectionNames = audioItem == null
        ? const <String>[]
        : ref.watch(
            collectionListProvider.select((s) {
              final ids = s.audioToCollectionsMap[audioItem.id] ?? const [];
              if (ids.isEmpty) return const <String>[];
              final idSet = ids.toSet();
              return s.collections
                  .where((c) => idSet.contains(c.id))
                  .map((c) => c.name)
                  .toList(growable: false);
            }),
          );

    return AudioAppBarTitle(
      audioName: audioName,
      collectionNames: collectionNames,
    );
  }

  Widget _buildLayout(
    BuildContext context,
    ListeningPracticeState playerState,
  ) {
    return Column(
      children: [
        Expanded(child: _buildTranscriptView(playerState)),
        _buildControlPanel(context, playerState),
      ],
    );
  }

  Widget _buildTranscriptView(ListeningPracticeState playerState) {
    final l10n = AppLocalizations.of(context)!;
    final controller = ref.read(listeningPracticeProvider.notifier);

    if (!playerState.hasSentences) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.subtitles_off_outlined,
              size: 64,
              color: Theme.of(context).colorScheme.outline,
            ),
            const SizedBox(height: AppSpacing.m),
            Text(
              l10n.noSubtitle,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        TabBar(
          controller: _tabController,
          labelPadding: const EdgeInsets.symmetric(horizontal: 8),
          tabs: [
            Tab(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.article, size: 18),
                  const SizedBox(width: 8),
                  Text('${l10n.fullText} (${playerState.sentences.length})'),
                ],
              ),
            ),
            Tab(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.bookmark, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    '${l10n.bookmarked} (${playerState.bookmarkedSentences.length})',
                  ),
                ],
              ),
            ),
          ],
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildFullTextTab(playerState, controller),
              _buildBookmarkedTab(playerState, controller),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFullTextTab(
    ListeningPracticeState playerState,
    ListeningPractice controller,
  ) {
    final l10n = AppLocalizations.of(context)!;

    if (playerState.settings.singleSentenceMode) {
      if (playerState.currentFullIndex == null &&
          playerState.sentences.isNotEmpty) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          controller.selectFullSentence(0, autoPlay: false);
        });
        return const Center(child: CircularProgressIndicator());
      }
      if (playerState.currentFullIndex != null) {
        return _buildSingleSentenceView(
          playerState,
          controller,
          playerState.currentFullIndex!,
        );
      }
      return Center(
        child: Text(
          l10n.noSentenceSelected,
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      );
    }

    if (playerState.currentFullIndex == null &&
        playerState.sentences.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        controller.selectFullSentence(0, autoPlay: false);
      });
    }
    // 全文列表中 sentence.index == 列表位置，currentFullIndex 即本地位置索引
    return ParagraphSentenceListCard(
      sentences: playerState.sentences,
      displayMode: playerState.settings.showTranscript
          ? RetellDisplayMode.showAll
          : RetellDisplayMode.hideAll,
      keywordMap: const {},
      playingSentenceIndex: playerState.currentFullIndex ?? -1,
      autoFocusEnabled: true,
      bookmarkedSentenceIndices: playerState.bookmarkedIndices,
      onSentencePlayFrom: (s) => controller.selectFullSentence(s.index),
      onSentenceTap: _handleSentenceDetail,
    );
  }

  Widget _buildBookmarkedTab(
    ListeningPracticeState playerState,
    ListeningPractice controller,
  ) {
    final l10n = AppLocalizations.of(context)!;
    final bookmarkedSentences = playerState.bookmarkedSentences;

    if (bookmarkedSentences.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.bookmark_border,
              size: 64,
              color: Theme.of(context).colorScheme.outline,
            ),
            const SizedBox(height: AppSpacing.m),
            Text(
              l10n.noBookmarkedSentences,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppSpacing.s),
            Text(
              l10n.tapBookmarkIcon,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      );
    }

    if (playerState.settings.singleSentenceMode) {
      if (playerState.currentBookmarkIndex == null ||
          !playerState.bookmarkedIndices.contains(
            playerState.currentBookmarkIndex,
          )) {
        if (bookmarkedSentences.isNotEmpty) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            controller.selectBookmarkedSentence(
              bookmarkedSentences.first.index,
              autoPlay: false,
            );
          });
          return const Center(child: CircularProgressIndicator());
        }
        return Center(
          child: Text(
            l10n.noSentenceSelected,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        );
      }
      return _buildSingleSentenceView(
        playerState,
        controller,
        playerState.currentBookmarkIndex!,
      );
    }

    if ((playerState.currentBookmarkIndex == null ||
            !playerState.bookmarkedIndices.contains(
              playerState.currentBookmarkIndex,
            )) &&
        bookmarkedSentences.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        controller.selectBookmarkedSentence(
          bookmarkedSentences.first.index,
          autoPlay: false,
        );
      });
    }
    // 收藏子集中列表位置 ≠ 全局 index，需将 currentBookmarkIndex 换算成本地位置
    final playingLocalIndex = bookmarkedSentences.indexWhere(
      (s) => s.index == playerState.currentBookmarkIndex,
    );
    return ParagraphSentenceListCard(
      sentences: bookmarkedSentences,
      displayMode: playerState.settings.showTranscript
          ? RetellDisplayMode.showAll
          : RetellDisplayMode.hideAll,
      keywordMap: const {},
      playingSentenceIndex: playingLocalIndex,
      autoFocusEnabled: true,
      bookmarkedSentenceIndices: playerState.bookmarkedIndices,
      onSentencePlayFrom: (s) => controller.selectBookmarkedSentence(s.index),
      onSentenceTap: _handleSentenceDetail,
    );
  }

  Widget _buildSingleSentenceView(
    ListeningPracticeState playerState,
    ListeningPractice controller,
    int index,
  ) {
    final currentSentence = playerState.sentences[index];
    final isBookmarked = playerState.bookmarkedIndices.contains(
      currentSentence.index,
    );
    final isMobile = !kIsWeb && (Platform.isIOS || Platform.isAndroid);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: GestureDetector(
          onSecondaryTapDown: (details) {
            _showContextMenu(
              context,
              details.globalPosition,
              currentSentence.text,
            );
          },
          onLongPressStart: isMobile
              ? (details) => _showContextMenu(
                  context,
                  details.globalPosition,
                  currentSentence.text,
                )
              : null,
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.m),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Stack(
                    children: [
                      Text(
                        currentSentence.text,
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(fontWeight: FontWeight.normal),
                        textAlign: TextAlign.left,
                      ),
                      if (!playerState.settings.showTranscript)
                        Positioned.fill(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: BackdropFilter(
                              filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
                              child: Container(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurface.withValues(alpha: 0.05),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.m),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            Text(
                              '#${currentSentence.index + 1}',
                              style: AppTextStyles.caption(context),
                            ),
                            const SizedBox(width: AppSpacing.l),
                            Text(
                              '${SubtitleParser.formatDuration(currentSentence.startTime)} - ${SubtitleParser.formatDuration(currentSentence.endTime)}',
                              style: AppTextStyles.caption(context),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: Icon(
                          isBookmarked ? Icons.bookmark : Icons.bookmark_border,
                          color: isBookmarked
                              ? AppTheme.bookmarkColor
                              : Theme.of(context).colorScheme.outline,
                        ),
                        onPressed: () =>
                            controller.toggleBookmark(currentSentence.index),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// 点击句子主体 → 暂停播放 → 进入句子讲解页
  ///
  /// 与盲听任务行为一致：导航前停止音频，返回后同步收藏状态。
  /// 仅本页持有，不与盲听共享（共享面只到句子列表组件）。
  Future<void> _handleSentenceDetail(Sentence sentence) async {
    if (_isNavigatingToDetail) return;
    _isNavigatingToDetail = true;

    final controller = ref.read(listeningPracticeProvider.notifier);
    final playerState = ref.read(listeningPracticeProvider);
    final audioItem = playerState.currentAudioItem;
    if (audioItem == null) {
      _isNavigatingToDetail = false;
      return;
    }

    await controller.pause();
    if (!mounted) {
      _isNavigatingToDetail = false;
      return;
    }

    await context.push(
      AppRoutes.sentenceDetail,
      extra: SentenceDetailArgs(
        audioItemId: audioItem.id,
        audioName: audioItem.name,
        sentenceText: sentence.text,
        sentenceIndex: sentence.index,
        startTimeMs: sentence.startTime.inMilliseconds,
        endTimeMs: sentence.endTime.inMilliseconds,
      ),
    );

    _isNavigatingToDetail = false;

    // 返回后刷新收藏状态（讲解页可能修改了收藏）
    if (!mounted) return;
    await controller.syncBookmarks();
  }

  void _showContextMenu(BuildContext context, Offset position, String text) {
    TextContextMenu.show(context, position, text);
  }

  void _showSettingsDialog(BuildContext context) {
    showSettingsSheet(context);
  }

  Widget _buildControlPanel(
    BuildContext context,
    ListeningPracticeState playerState,
  ) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 600;

        return Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            border: Border(
              top: BorderSide(
                color: Theme.of(context).colorScheme.outlineVariant,
                width: 0.5,
              ),
            ),
          ),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildProgressBar(playerState, isMobile),
                const PlaybackControls(),
                if (!isMobile) _buildInfoBar(playerState),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildProgressBar(ListeningPracticeState playerState, bool isMobile) {
    final engineNotifier = ref.read(audioEngineProvider.notifier);
    final controller = ref.read(listeningPracticeProvider.notifier);
    final engine = ref.watch(audioEngineProvider);

    return Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        isMobile ? 16 : 12,
        16,
        isMobile ? 4 : 8,
      ),
      child: StreamBuilder<Duration>(
        stream: engineNotifier.absolutePositionStream,
        builder: (context, snapshot) {
          final position = snapshot.data ?? Duration.zero;
          final total = engine.totalDuration ?? Duration.zero;

          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ProgressBar(
                progress: position,
                total: total,
                onSeek: (duration) => controller.seekAbsolute(duration),
                barHeight: 3,
                thumbRadius: 5,
                timeLabelTextStyle: AppTextStyles.caption(context),
                timeLabelLocation: TimeLabelLocation.none,
              ),
              const SizedBox(height: AppSpacing.xs),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    SubtitleParser.formatDuration(position),
                    style: AppTextStyles.caption(context),
                  ),
                  Text(() {
                    final clampedPos = position > total ? total : position;
                    final remaining = total - clampedPos;
                    return '-${SubtitleParser.formatDuration(remaining)}';
                  }(), style: AppTextStyles.caption(context)),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildInfoBar(ListeningPracticeState playerState) {
    final l10n = AppLocalizations.of(context)!;
    final captionStyle = AppTextStyles.caption(context);
    final iconColor = Theme.of(context).colorScheme.onSurfaceVariant;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.m,
        vertical: AppSpacing.s,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    playerState.settings.singleSentenceMode
                        ? Icons.format_quote
                        : Icons.article,
                    size: 14,
                    color: iconColor,
                  ),
                  const SizedBox(width: 3),
                  Text(
                    playerState.settings.singleSentenceMode
                        ? l10n.singleSentenceMode
                        : l10n.listMode,
                    style: captionStyle,
                  ),
                ],
              ),
              if (playerState.settings.loopEnabled) ...[
                const SizedBox(width: 12),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.repeat_one, size: 14, color: iconColor),
                    const SizedBox(width: 3),
                    Text(
                      'x${playerState.settings.loopCount}',
                      style: captionStyle,
                    ),
                  ],
                ),
              ],
              if (playerState.settings.loopAudioEnabled) ...[
                const SizedBox(width: 12),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.repeat, size: 14, color: iconColor),
                    const SizedBox(width: 3),
                    Text(
                      playerState.settings.loopAudio == 0
                          ? '∞'
                          : 'x${playerState.settings.loopAudio}',
                      style: captionStyle,
                    ),
                  ],
                ),
              ],
              const SizedBox(width: 12),
              Text(
                '${playerState.settings.playbackSpeed}x',
                style: captionStyle,
              ),
            ],
          ),
          const Spacer(),
          if (!kIsWeb && Platform.isMacOS)
            SizedBox(
              child: Align(
                alignment: Alignment.centerRight,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 280),
                  child: _HotkeyTipsCarousel(l10n: l10n),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _HotkeyTipsCarousel extends StatefulWidget {
  final AppLocalizations l10n;

  const _HotkeyTipsCarousel({required this.l10n});

  @override
  State<_HotkeyTipsCarousel> createState() => _HotkeyTipsCarouselState();
}

class _HotkeyTipsCarouselState extends State<_HotkeyTipsCarousel> {
  int _currentIndex = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startCarousel();
  }

  void _startCarousel() {
    _timer = Timer.periodic(const Duration(seconds: 4), (timer) {
      if (mounted) {
        setState(() {
          _currentIndex = (_currentIndex + 1) % 4;
        });
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String _getCurrentTip() {
    switch (_currentIndex) {
      case 0:
        return widget.l10n.hotkeyReplay;
      case 1:
        return widget.l10n.hotkeyPlayPause;
      case 2:
        return widget.l10n.hotkeyToggleTranscript;
      case 3:
        return widget.l10n.hotkeyNavigation;
      default:
        return widget.l10n.hotkeyReplay;
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      child: Text(
        _getCurrentTip(),
        key: ValueKey<int>(_currentIndex),
        style: AppTextStyles.caption(context),
        textAlign: TextAlign.right,
      ),
    );
  }
}
