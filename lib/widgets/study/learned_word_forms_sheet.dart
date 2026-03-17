import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../database/app_database.dart';
import '../../database/daos/learned_word_form_dao.dart';
import '../../database/providers.dart';
import '../../l10n/app_localizations.dart';
import '../../theme/app_theme.dart';

const int _pageSize = 50;
const double _loadMoreThreshold = 200;

/// 打开已学习词形列表底部弹窗。
Future<void> showLearnedWordFormsSheet({required BuildContext context}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => const LearnedWordFormsSheet(),
  );
}

/// 已学习词形列表底部弹窗。
class LearnedWordFormsSheet extends ConsumerStatefulWidget {
  const LearnedWordFormsSheet({super.key});

  @override
  ConsumerState<LearnedWordFormsSheet> createState() =>
      _LearnedWordFormsSheetState();
}

class _LearnedWordFormsSheetState extends ConsumerState<LearnedWordFormsSheet> {
  final ScrollController _scrollController = ScrollController();
  final List<LearnedWordForm> _items = <LearnedWordForm>[];

  LearnedWordSortMode _sortMode = LearnedWordSortMode.timeDesc;
  bool _isLoadingInitial = true;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  int _totalCount = 0;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_handleScroll);
    _initialize();
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_handleScroll)
      ..dispose();
    super.dispose();
  }

  Future<void> _initialize() async {
    final dao = ref.read(learnedWordFormDaoProvider);
    final totalCount = await dao.countAll();
    if (!mounted) return;

    setState(() {
      _totalCount = totalCount;
      _items.clear();
      _hasMore = totalCount > 0;
      _isLoadingInitial = true;
      _isLoadingMore = false;
    });

    await _loadMore(reset: true);
  }

  Future<void> _loadMore({bool reset = false}) async {
    if (_isLoadingMore) return;
    if (!reset && !_hasMore) return;

    setState(() {
      if (reset) {
        _isLoadingInitial = true;
      } else {
        _isLoadingMore = true;
      }
    });

    final dao = ref.read(learnedWordFormDaoProvider);
    final page = await dao.fetchPage(
      limit: _pageSize,
      offset: reset ? 0 : _items.length,
      sortMode: _sortMode,
    );
    if (!mounted) return;

    setState(() {
      if (reset) {
        _items
          ..clear()
          ..addAll(page);
      } else {
        _items.addAll(page);
      }
      _hasMore = _items.length < _totalCount;
      _isLoadingInitial = false;
      _isLoadingMore = false;
    });
  }

  void _handleScroll() {
    if (!_scrollController.hasClients || _isLoadingMore || !_hasMore) return;
    if (_scrollController.position.extentAfter < _loadMoreThreshold) {
      _loadMore();
    }
  }

  Future<void> _changeSort(LearnedWordSortMode sortMode) async {
    if (_sortMode == sortMode) return;

    setState(() {
      _sortMode = sortMode;
      _hasMore = true;
      _isLoadingInitial = true;
      _isLoadingMore = false;
    });

    if (_scrollController.hasClients) {
      _scrollController.jumpTo(0);
    }

    await _loadMore(reset: true);
  }

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
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: [
                            Text(
                              l10n.learnedWordFormsShort,
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              l10n.wordCountLabel(_totalCount),
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          l10n.localeName == 'zh'
                              ? '累计听到的不重复单词'
                              : 'Unique words heard so far',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.outline,
                          ),
                        ),
                      ],
                    ),
                  ),
                  PopupMenuButton<LearnedWordSortMode>(
                    tooltip: l10n.sortCollections,
                    initialValue: _sortMode,
                    onSelected: _changeSort,
                    itemBuilder: (context) => [
                      PopupMenuItem(
                        value: LearnedWordSortMode.timeDesc,
                        child: Text(l10n.learnedWordsSortTimeDesc),
                      ),
                      PopupMenuItem(
                        value: LearnedWordSortMode.timeAsc,
                        child: Text(l10n.learnedWordsSortTimeAsc),
                      ),
                      PopupMenuItem(
                        value: LearnedWordSortMode.alphabeticalAsc,
                        child: Text(l10n.flashcardSortAlphaAsc),
                      ),
                      PopupMenuItem(
                        value: LearnedWordSortMode.alphabeticalDesc,
                        child: Text(l10n.flashcardSortAlphaDesc),
                      ),
                    ],
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHighest
                            .withValues(alpha: 0.5),
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
                            _sortLabel(l10n, _sortMode),
                            style: theme.textTheme.labelMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.m),
              Expanded(child: _buildBody(context)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    if (_isLoadingInitial) {
      return const Center(child: CircularProgressIndicator.adaptive());
    }

    if (_items.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.spellcheck_rounded,
                size: 56,
                color: theme.colorScheme.outline.withValues(alpha: 0.5),
              ),
              const SizedBox(height: AppSpacing.m),
              Text(
                l10n.learnedWordsEmptyHint,
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

    return ListView.builder(
      controller: _scrollController,
      itemCount: _items.length + (_isLoadingMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index >= _items.length) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: AppSpacing.m),
            child: Center(child: CircularProgressIndicator.adaptive()),
          );
        }

        final item = _items[index];
        return _LearnedWordFormTile(
          index: index + 1,
          wordForm: item.wordForm,
          firstLearnedAt: item.firstLearnedAt,
        );
      },
    );
  }

  String _sortLabel(AppLocalizations l10n, LearnedWordSortMode sortMode) {
    return switch (sortMode) {
      LearnedWordSortMode.timeDesc => l10n.learnedWordsSortTimeDesc,
      LearnedWordSortMode.timeAsc => l10n.learnedWordsSortTimeAsc,
      LearnedWordSortMode.alphabeticalAsc => l10n.flashcardSortAlphaAsc,
      LearnedWordSortMode.alphabeticalDesc => l10n.flashcardSortAlphaDesc,
    };
  }
}

class _LearnedWordFormTile extends StatelessWidget {
  final int index;
  final String wordForm;
  final DateTime firstLearnedAt;

  const _LearnedWordFormTile({
    required this.index,
    required this.wordForm,
    required this.firstLearnedAt,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.xs,
            vertical: AppSpacing.s,
          ),
          child: Row(
            children: [
              SizedBox(
                width: 30,
                child: Text(
                  '$index',
                  textAlign: TextAlign.left,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.outline,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.s),
              Expanded(
                child: Text(
                  wordForm,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurface,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.m),
              Text(
                _formatDate(context, firstLearnedAt),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
      ],
    );
  }

  String _formatDate(BuildContext context, DateTime dateTime) {
    final locale = Localizations.localeOf(context).toString();
    return DateFormat('yyyy-MM-dd HH:mm', locale).format(dateTime);
  }
}
