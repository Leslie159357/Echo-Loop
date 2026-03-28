/// 意群色块文本组件
///
/// 将句子按意群渲染为圆角色块，每个色块可点击播放对应音频片段。
/// 支持三种状态：空闲 / 播放中 / 已播放。
/// 意群内单词仍可点击查词典。
library;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import '../../models/sense_group_result.dart';
import '../../theme/app_theme.dart';
import '../../utils/sense_group_timing.dart';
import 'word_dictionary_sheet.dart';

/// 意群色块文本
class SenseGroupText extends StatelessWidget {
  /// 意群列表
  final List<SenseGroup> groups;

  /// 各意群时间范围
  final List<SenseGroupTiming> timings;

  /// 正在播放的意群索引（null 表示无播放）
  final int? playingGroupIndex;

  /// 已播放过的意群索引集合
  final Set<int> playedGroupIndices;

  /// 点击意群回调
  final void Function(int groupIndex) onTapGroup;

  /// 来源音频 ID（用于词典弹窗）
  final String? audioItemId;

  /// 来源句子索引
  final int? sentenceIndex;

  /// 完整句子文本
  final String sentenceText;

  /// 来源句子起始时间（毫秒）
  final int? sentenceStartMs;

  /// 来源句子结束时间（毫秒）
  final int? sentenceEndMs;

  const SenseGroupText({
    super.key,
    required this.groups,
    required this.timings,
    this.playingGroupIndex,
    this.playedGroupIndices = const {},
    required this.onTapGroup,
    this.audioItemId,
    this.sentenceIndex,
    required this.sentenceText,
    this.sentenceStartMs,
    this.sentenceEndMs,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Wrap(
      spacing: AppSpacing.xs,
      runSpacing: AppSpacing.xs,
      children: [
        for (var i = 0; i < groups.length; i++)
          _SenseGroupChip(
            group: groups[i],
            index: i,
            isPlaying: playingGroupIndex == i,
            isPlayed: playedGroupIndices.contains(i),
            onTap: () => onTapGroup(i),
            onTapWord: (word) => _onTapWord(context, word),
            theme: theme,
          ),
      ],
    );
  }

  void _onTapWord(BuildContext context, String word) {
    final cleanWord = word.replaceAll(
      RegExp(r'[.,!?;:\-—…、，。！？；：]'),
      '',
    );
    if (cleanWord.isNotEmpty) {
      showWordDictionarySheet(
        context: context,
        word: cleanWord,
        audioItemId: audioItemId,
        sentenceIndex: sentenceIndex,
        sentenceText: sentenceText,
        sentenceStartMs: sentenceStartMs,
        sentenceEndMs: sentenceEndMs,
      );
    }
  }
}

/// 单个意群色块
class _SenseGroupChip extends StatelessWidget {
  final SenseGroup group;
  final int index;
  final bool isPlaying;
  final bool isPlayed;
  final VoidCallback onTap;
  final void Function(String word) onTapWord;
  final ThemeData theme;

  const _SenseGroupChip({
    required this.group,
    required this.index,
    required this.isPlaying,
    required this.isPlayed,
    required this.onTap,
    required this.onTapWord,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = theme.colorScheme;

    // 状态样式
    final backgroundColor = isPlaying
        ? colorScheme.primaryContainer
        : colorScheme.surfaceContainerLow;
    final borderColor = isPlaying
        ? colorScheme.primary
        : Colors.transparent;
    final leftBorderColor = isPlayed && !isPlaying
        ? colorScheme.primary
        : Colors.transparent;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.s,
          vertical: AppSpacing.xs,
        ),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: borderColor, width: 1.5),
          // 已播放的意群左侧竖线
          boxShadow: leftBorderColor != Colors.transparent
              ? [
                  BoxShadow(
                    color: leftBorderColor,
                    offset: const Offset(-2, 0),
                    blurRadius: 0,
                    spreadRadius: 0,
                  ),
                ]
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // 英文文本（单词可点击查词典）
            _WordTappableText(
              text: group.text,
              onTapWord: onTapWord,
              style: theme.textTheme.titleMedium?.copyWith(
                height: 1.4,
                color: colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 2),
            // 中文翻译
            Text(
              group.translation,
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
                height: 1.3,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 可点击单词的文本组件
///
/// 使用 RichText + TapGestureRecognizer 实现单词级点击。
class _WordTappableText extends StatefulWidget {
  final String text;
  final void Function(String word) onTapWord;
  final TextStyle? style;

  const _WordTappableText({
    required this.text,
    required this.onTapWord,
    this.style,
  });

  @override
  State<_WordTappableText> createState() => _WordTappableTextState();
}

class _WordTappableTextState extends State<_WordTappableText> {
  final List<TapGestureRecognizer> _recognizers = [];

  @override
  void dispose() {
    for (final r in _recognizers) {
      r.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 清理旧 recognizer
    for (final r in _recognizers) {
      r.dispose();
    }
    _recognizers.clear();

    final words = widget.text.split(RegExp(r'\s+'));
    final spans = <InlineSpan>[];
    for (var i = 0; i < words.length; i++) {
      if (i > 0) spans.add(const TextSpan(text: ' '));
      final word = words[i];
      final recognizer = TapGestureRecognizer()
        ..onTap = () => widget.onTapWord(word);
      _recognizers.add(recognizer);
      spans.add(TextSpan(text: word, recognizer: recognizer));
    }

    return RichText(
      text: TextSpan(style: widget.style, children: spans),
    );
  }
}
