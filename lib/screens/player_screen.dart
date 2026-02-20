import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';
import 'package:universal_io/io.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:audio_video_progress_bar/audio_video_progress_bar.dart';
import '../l10n/app_localizations.dart';
import '../providers/listening_practice/listening_practice_provider.dart';
import '../providers/audio_engine/audio_engine_provider.dart';
import '../services/subtitle_parser.dart';
import '../widgets/playback_controls.dart';
import '../widgets/sentence_list_view.dart';
import '../widgets/settings_dialog.dart';
import '../widgets/player_hotkey_scope.dart';

class PlayerScreen extends ConsumerStatefulWidget {
  const PlayerScreen({super.key});

  @override
  ConsumerState<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends ConsumerState<PlayerScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int _previousTabIndex = 0;

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
        ref.read(listeningPracticeProvider.notifier).setPlaylistMode(
          _tabController.index == 0
              ? PlaylistMode.full
              : PlaylistMode.bookmarks,
        );
      }
    });
  }

  @override
  void dispose() {
    // Save state and pause on dispose
    ref.read(listeningPracticeProvider.notifier).pause();
    ref.read(listeningPracticeProvider.notifier).saveCurrentPlaybackState();
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final playerState = ref.watch(listeningPracticeProvider);
    final controller = ref.read(listeningPracticeProvider.notifier);

    return PlayerHotkeyScope(
      child: Scaffold(
        appBar: AppBar(
          title: Text(playerState.currentAudioItem?.name ?? l10n.player),
          actions: [
            IconButton(
              icon: Icon(
                playerState.autoScrollEnabled
                    ? Icons.center_focus_strong
                    : Icons.center_focus_weak,
              ),
              onPressed: () =>
                  controller.setAutoScroll(!playerState.autoScrollEnabled),
              tooltip: playerState.autoScrollEnabled
                  ? l10n.disableAutoScroll
                  : l10n.enableAutoScroll,
            ),
            IconButton(
              icon: const Icon(Icons.settings),
              onPressed: () => _showSettingsDialog(context),
              tooltip: l10n.settings,
            ),
          ],
        ),
        body: !playerState.hasAudio
            ? Center(child: Text(l10n.noAudioLoaded))
            : _buildLayout(context, playerState),
      ),
    );
  }

  Widget _buildLayout(BuildContext context, ListeningPracticeState playerState) {
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
            Icon(Icons.subtitles_off, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              l10n.noSubtitle,
              style: const TextStyle(fontSize: 16, color: Colors.grey),
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
                  Text(
                    '${l10n.fullText} (${playerState.sentences.length})',
                  ),
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
          style: const TextStyle(color: Colors.grey),
        ),
      );
    }

    if (playerState.currentFullIndex == null &&
        playerState.sentences.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        controller.selectFullSentence(0, autoPlay: false);
      });
    }
    return SentenceListView(
      sentences: playerState.sentences,
      currentIndex: playerState.currentFullIndex,
      bookmarkedIndices: playerState.bookmarkedIndices,
      showTranscript: playerState.settings.showTranscript,
      autoScrollEnabled: playerState.autoScrollEnabled,
      onSentenceTap: (index) => controller.selectFullSentence(index),
      onBookmarkToggle: (index) => controller.toggleBookmark(index),
      onUserScroll: () => controller.setAutoScroll(false),
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
            Icon(Icons.bookmark_border, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              l10n.noBookmarkedSentences,
              style: const TextStyle(fontSize: 16, color: Colors.grey),
            ),
            const SizedBox(height: 8),
            Text(
              l10n.tapBookmarkIcon,
              style: const TextStyle(fontSize: 14, color: Colors.grey),
            ),
          ],
        ),
      );
    }

    if (playerState.settings.singleSentenceMode) {
      if (playerState.currentBookmarkIndex == null ||
          !playerState.bookmarkedIndices
              .contains(playerState.currentBookmarkIndex)) {
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
            style: const TextStyle(color: Colors.grey),
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
            !playerState.bookmarkedIndices
                .contains(playerState.currentBookmarkIndex)) &&
        bookmarkedSentences.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        controller.selectBookmarkedSentence(
          bookmarkedSentences.first.index,
          autoPlay: false,
        );
      });
    }
    return SentenceListView(
      sentences: bookmarkedSentences,
      currentIndex: playerState.currentBookmarkIndex,
      bookmarkedIndices: playerState.bookmarkedIndices,
      showTranscript: playerState.settings.showTranscript,
      autoScrollEnabled: playerState.autoScrollEnabled,
      onSentenceTap: (index) => controller.selectBookmarkedSentence(index),
      onBookmarkToggle: (index) => controller.toggleBookmark(index),
      onUserScroll: () => controller.setAutoScroll(false),
    );
  }

  Widget _buildSingleSentenceView(
    ListeningPracticeState playerState,
    ListeningPractice controller,
    int index,
  ) {
    final l10n = AppLocalizations.of(context)!;
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
            elevation: 4,
            child: Padding(
              padding: const EdgeInsets.all(16),
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
                                color: Colors.grey.withValues(alpha: 0.1),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            Text(
                              '#${currentSentence.index + 1}',
                              style: TextStyle(color: Colors.grey[500]),
                            ),
                            const SizedBox(width: 24),
                            Text(
                              '${SubtitleParser.formatDuration(currentSentence.startTime)} - ${SubtitleParser.formatDuration(currentSentence.endTime)}',
                              style: TextStyle(color: Colors.grey[600]),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: Icon(
                          isBookmarked ? Icons.bookmark : Icons.bookmark_border,
                          color: isBookmarked ? Colors.amber : Colors.grey,
                        ),
                        onPressed: () =>
                            controller.toggleBookmark(currentSentence.index),
                        tooltip: isBookmarked
                            ? l10n.removeBookmarkTip
                            : l10n.addBookmarkTip,
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

  void _showContextMenu(
    BuildContext context,
    Offset position,
    String text,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    final RenderBox? overlay =
        Overlay.of(context).context.findRenderObject() as RenderBox?;

    final result = await showMenu(
      context: context,
      position: RelativeRect.fromRect(
        position & const Size(40, 40),
        Offset.zero & (overlay?.size ?? const Size(0, 0)),
      ),
      items: [
        PopupMenuItem<String>(
          value: 'copy',
          child: Row(
            children: [
              const Icon(Icons.copy, size: 20),
              const SizedBox(width: 12),
              Text(l10n.copy),
            ],
          ),
        ),
      ],
    );

    if (result == 'copy' && context.mounted) {
      await Clipboard.setData(ClipboardData(text: text));
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.copied),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  void _showSettingsDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => const SettingsDialog(),
    );
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
                color: Theme.of(context).dividerColor.withValues(alpha: 0.3),
                width: 1,
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
                timeLabelTextStyle: const TextStyle(fontSize: 11),
                timeLabelLocation: TimeLabelLocation.none,
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    SubtitleParser.formatDuration(position),
                    style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                  ),
                  Text(() {
                    final clampedPos = position > total ? total : position;
                    final remaining = total - clampedPos;
                    return '-${SubtitleParser.formatDuration(remaining)}';
                  }(),
                      style:
                          TextStyle(fontSize: 11, color: Colors.grey[600])),
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

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
                    color: Colors.grey[600],
                  ),
                  const SizedBox(width: 3),
                  Text(
                    playerState.settings.singleSentenceMode
                        ? l10n.singleSentenceMode
                        : l10n.listMode,
                    style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                  ),
                ],
              ),
              if (playerState.settings.loopEnabled) ...[
                const SizedBox(width: 12),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.repeat_one, size: 14, color: Colors.grey[600]),
                    const SizedBox(width: 3),
                    Text(
                      'x${playerState.settings.loopCount}',
                      style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                    ),
                  ],
                ),
              ],
              if (playerState.settings.loopAudioEnabled) ...[
                const SizedBox(width: 12),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.repeat, size: 14, color: Colors.grey[600]),
                    const SizedBox(width: 3),
                    Text(
                      playerState.settings.loopAudio == 0
                          ? '∞'
                          : 'x${playerState.settings.loopAudio}',
                      style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                    ),
                  ],
                ),
              ],
              const SizedBox(width: 12),
              Text(
                '${playerState.settings.playbackSpeed}x',
                style: TextStyle(fontSize: 11, color: Colors.grey[600]),
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
        style: TextStyle(fontSize: 11, color: Colors.grey[600]),
        textAlign: TextAlign.right,
      ),
    );
  }
}
