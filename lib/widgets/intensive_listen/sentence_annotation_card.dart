/// 标注模式内容卡片
///
/// 显示句子文本（单词可点击弹出词典弹窗）、
/// 难句标记切换、AI 翻译和 AI 解析区域。
library;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import '../../l10n/app_localizations.dart';
import '../../theme/app_theme.dart';
import '../common/ai_content_section.dart';
import 'word_dictionary_sheet.dart';

/// 标注模式句子卡片
///
/// 使用 StatefulWidget 管理 TapGestureRecognizer 生命周期，
/// 防止内存泄漏。
class SentenceAnnotationCard extends StatefulWidget {
  /// 句子文本
  final String text;

  /// 当前句子是否标记为难句
  final bool isDifficult;

  /// 是否展示“自动标记”文案
  ///
  /// 仅在“看不懂”触发自动标记的当次传 true；
  /// 其它场景（包括已存在的难句）保持 false。
  final bool showAutoMarkedLabel;

  /// 切换难句标记回调
  final VoidCallback onToggle;

  /// 请求翻译回调（返回翻译文本）
  final Future<String> Function()? onRequestTranslation;

  /// 请求解析回调（返回解析 JSON 文本）
  final Future<String> Function()? onRequestAnalysis;

  /// 已缓存的翻译文本
  final String? cachedTranslation;

  /// 已缓存的解析文本（grammar\nvocabulary\nusage 格式）
  final String? cachedAnalysis;

  /// 来源音频 ID（用于词典弹窗收藏单词时记录来源）
  final String? audioItemId;

  /// 来源句子索引
  final int? sentenceIndex;

  /// 来源句子起始时间（毫秒）
  final int? sentenceStartMs;

  /// 来源句子结束时间（毫秒）
  final int? sentenceEndMs;

  const SentenceAnnotationCard({
    super.key,
    required this.text,
    required this.isDifficult,
    this.showAutoMarkedLabel = false,
    required this.onToggle,
    this.onRequestTranslation,
    this.onRequestAnalysis,
    this.cachedTranslation,
    this.cachedAnalysis,
    this.audioItemId,
    this.sentenceIndex,
    this.sentenceStartMs,
    this.sentenceEndMs,
  });

  @override
  State<SentenceAnnotationCard> createState() => _SentenceAnnotationCardState();
}

class _SentenceAnnotationCardState extends State<SentenceAnnotationCard> {
  final List<TapGestureRecognizer> _recognizers = [];

  @override
  void dispose() {
    for (final r in _recognizers) {
      r.dispose();
    }
    super.dispose();
  }

  /// 每次 build 前清理旧 recognizer，创建新的
  List<InlineSpan> _buildWordSpans(ThemeData theme) {
    // 清理旧 recognizer
    for (final r in _recognizers) {
      r.dispose();
    }
    _recognizers.clear();

    final words = widget.text.split(RegExp(r'(\s+)'));
    return words.map((word) {
      if (word.trim().isEmpty) {
        return TextSpan(text: word);
      }
      final recognizer = TapGestureRecognizer()
        ..onTap = () {
          final cleanWord = word.replaceAll(RegExp(r'[.,!?;:\-—…、，。！？；：]'), '');
          if (cleanWord.isNotEmpty) {
            showWordDictionarySheet(
              context: context,
              word: cleanWord,
              audioItemId: widget.audioItemId,
              sentenceIndex: widget.sentenceIndex,
              sentenceText: widget.text,
              sentenceStartMs: widget.sentenceStartMs,
              sentenceEndMs: widget.sentenceEndMs,
            );
          }
        };
      _recognizers.add(recognizer);
      return TextSpan(text: '$word ', recognizer: recognizer);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 难句标记（可点击切换）
        GestureDetector(
          onTap: widget.onToggle,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Flexible(
                child: Text(
                  widget.isDifficult
                      ? (widget.showAutoMarkedLabel
                            ? l10n.intensiveListenAutoMarkedDifficult
                            : l10n.intensiveListenMarkedDifficult)
                      : l10n.intensiveListenNotDifficult,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: widget.isDifficult
                        ? Colors.amber.shade700
                        : Colors.grey,
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              Icon(
                widget.isDifficult ? Icons.star : Icons.star_border,
                color: widget.isDifficult ? Colors.amber : Colors.grey,
                size: 18,
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.m),

        // 句子文本（单词可点击查词典）
        RichText(
          text: TextSpan(
            style: theme.textTheme.titleMedium?.copyWith(
              height: 1.6,
              color: theme.colorScheme.onSurface,
            ),
            children: _buildWordSpans(theme),
          ),
        ),
        // AI 翻译区域（仅在有回调或缓存时显示）
        if (widget.onRequestTranslation != null ||
            widget.cachedTranslation != null) ...[
          const SizedBox(height: AppSpacing.l),
          AiContentSection(
            icon: Icons.translate,
            title: l10n.aiTranslation,
            onRequest: widget.onRequestTranslation,
            cachedContent: widget.cachedTranslation,
          ),
        ],

        // AI 解析区域（仅在有回调或缓存时显示）
        if (widget.onRequestAnalysis != null ||
            widget.cachedAnalysis != null) ...[
          const SizedBox(height: AppSpacing.s),
          AiContentSection(
            icon: Icons.auto_awesome,
            title: l10n.aiAnalysis,
            onRequest: widget.onRequestAnalysis,
            cachedContent: widget.cachedAnalysis,
            contentBuilder: (content) => _AnalysisContent(content: content),
          ),
        ],
      ],
    );
  }
}

/// 解析内容结构化展示
///
/// 将 "grammar\nvocabulary\nusage" 格式的文本分行展示，
/// 每行带有标签标题（primary 色 + w600）和正文。
class _AnalysisContent extends StatelessWidget {
  final String content;

  const _AnalysisContent({required this.content});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final lines = content.split('\n');
    // 使用本地化标签名
    final labels = [l10n.aiGrammar, l10n.aiVocabulary, l10n.aiUsage];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < lines.length && i < labels.length; i++) ...[
          if (i > 0) const SizedBox(height: AppSpacing.s),
          // 标签标题（primary 色 + w600）
          Text(
            labels[i],
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 2),
          // 正文
          Text(
            lines[i],
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              height: 1.5,
            ),
          ),
        ],
      ],
    );
  }
}
