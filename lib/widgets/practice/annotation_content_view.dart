/// 标注模式内容视图（共享组件）
///
/// 将工具栏固定在顶部不随内容滚动，句子文本和翻译/解析在下方可滚动区域。
/// 通过 [GlobalKey<SentenceAnnotationCardState>] 管理卡片状态，
/// 切句时自动重建 key 确保状态重置。
///
/// 用于精听、难句补练、难句跟读和收藏复习页面。
library;

import 'package:flutter/material.dart';

import '../../models/sense_group_result.dart';
import '../../providers/sentence_ai_provider.dart';
import '../../theme/app_theme.dart';
import '../../utils/sense_group_timing.dart';
import '../intensive_listen/sentence_annotation_card.dart';

/// 标注模式内容视图
///
/// 工具栏固定在顶部不随内容滚动，句子文本和解析内容在下方可滚动。
class AnnotationContentView extends StatefulWidget {
  /// 句子文本
  final String text;

  /// 当前句子是否标记为难句
  final bool isDifficult;

  /// 是否展示"自动标记为难句"文案
  final bool isAutoMarked;

  /// AI 翻译/解析服务
  final SentenceAiNotifier? aiNotifier;

  /// 来源音频 ID（用于词典弹窗收藏单词）
  final String? audioItemId;

  /// 当前句子索引
  final int? sentenceIndex;

  /// 当前句子起始时间（毫秒）
  final int? sentenceStartMs;

  /// 当前句子结束时间（毫秒）
  final int? sentenceEndMs;

  /// AI 意群拆分结果（双粒度）
  final SenseGroupResult? senseGroupResult;

  /// 各意群时间范围
  final List<SenseGroupTiming>? senseGroupTimings;

  /// 意群粒度切换回调
  final void Function(List<String> chunks)? onSenseGroupModeChanged;

  /// 正在播放的意群索引
  final int? playingSenseGroupIndex;

  /// 已播放过的意群索引集合
  final Set<int> playedSenseGroupIndices;

  /// 点击意群回调
  final void Function(int groupIndex)? onTapSenseGroup;

  /// 请求拆分意群回调
  final Future<void> Function()? onRequestSenseGroups;

  /// 是否有词级时间戳
  final bool hasWordTimestamps;

  const AnnotationContentView({
    super.key,
    required this.text,
    required this.isDifficult,
    required this.isAutoMarked,
    this.aiNotifier,
    this.audioItemId,
    this.sentenceIndex,
    this.sentenceStartMs,
    this.sentenceEndMs,
    this.senseGroupResult,
    this.senseGroupTimings,
    this.onSenseGroupModeChanged,
    this.playingSenseGroupIndex,
    this.playedSenseGroupIndices = const {},
    this.onTapSenseGroup,
    this.onRequestSenseGroups,
    this.hasWordTimestamps = false,
  });

  @override
  State<AnnotationContentView> createState() => _AnnotationContentViewState();
}

class _AnnotationContentViewState extends State<AnnotationContentView> {
  /// 用于访问卡片 State 以构建外部工具栏。
  /// 切句时重建 GlobalKey 确保卡片 State 重置。
  GlobalKey<SentenceAnnotationCardState> _cardKey =
      GlobalKey<SentenceAnnotationCardState>();

  /// 工具栏刷新通知器，卡片 State 变化时通知工具栏重建
  final _toolbarNotifier = RebuildNotifier();

  @override
  void dispose() {
    _toolbarNotifier.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(AnnotationContentView oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 切句时重建 GlobalKey，确保卡片 State 重置
    if (widget.text != oldWidget.text) {
      _cardKey = GlobalKey<SentenceAnnotationCardState>();
    }
  }

  @override
  Widget build(BuildContext context) {
    final ai = widget.aiNotifier;
    final cachedTranslation = ai
        ?.getCachedTranslation(widget.text)
        ?.translation;
    final cachedAnalysis = ai?.getCachedAnalysis(widget.text);
    final cachedAnalysisText = cachedAnalysis?.toDisplayString();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 固定工具栏（监听 notifier 刷新）
        Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.m),
          child: ListenableBuilder(
            listenable: _toolbarNotifier,
            builder: (context, _) {
              final cardState = _cardKey.currentState;
              if (cardState == null || !cardState.hasToolbarButtons) {
                return const SizedBox.shrink();
              }
              return cardState.buildToolbar(context);
            },
          ),
        ),
        // 可滚动内容区
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.only(bottom: AppSpacing.l),
            child: SentenceAnnotationCard(
              key: _cardKey,
              text: widget.text,
              isDifficult: widget.isDifficult,
              showAutoMarkedLabel: widget.isAutoMarked,
              showToolbar: false,
              onToolbarStateChanged: _toolbarNotifier.notify,
              onRequestTranslation: ai != null
                  ? () async {
                      final result = await ai.getTranslation(widget.text);
                      return result.translation;
                    }
                  : null,
              onRequestAnalysis: ai != null
                  ? () async {
                      final result = await ai.getAnalysis(widget.text);
                      return result.toDisplayString();
                    }
                  : null,
              cachedTranslation: cachedTranslation,
              cachedAnalysis: cachedAnalysisText,
              audioItemId: widget.audioItemId,
              sentenceIndex: widget.sentenceIndex,
              sentenceStartMs: widget.sentenceStartMs,
              sentenceEndMs: widget.sentenceEndMs,
              senseGroupResult: widget.senseGroupResult,
              senseGroupTimings: widget.senseGroupTimings,
              onSenseGroupModeChanged: widget.onSenseGroupModeChanged,
              playingSenseGroupIndex: widget.playingSenseGroupIndex,
              playedSenseGroupIndices: widget.playedSenseGroupIndices,
              onTapSenseGroup: widget.onTapSenseGroup,
              onRequestSenseGroups: widget.onRequestSenseGroups,
              hasWordTimestamps: widget.hasWordTimestamps,
            ),
          ),
        ),
      ],
    );
  }
}

/// 简单的重建通知器，用于卡片状态变化时触发工具栏重建
class RebuildNotifier extends ChangeNotifier {
  /// 通知所有监听者重建
  void notify() => notifyListeners();
}
