/// Flashcard 卡片组件
///
/// 包含 3D 翻转动画（Matrix4.rotateY），正面显示单词+音标+发音，
/// 背面显示释义+来源例句。右上角取消收藏按钮。
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../database/providers.dart';
import '../../l10n/app_localizations.dart';
import '../../models/audio_item.dart' as model;
import '../../models/dict_entry.dart';
import '../../providers/audio_engine/audio_engine_provider.dart';
import '../../providers/flashcard/flashcard_provider.dart';
import '../../services/tts_service.dart';
import '../../theme/app_theme.dart';

/// Flashcard 翻转卡片
class FlashcardCard extends StatefulWidget {
  /// 卡片数据
  final FlashcardWordItem item;

  /// 是否显示背面
  final bool isShowingBack;

  /// 翻转回调
  final VoidCallback onFlip;

  /// 取消收藏回调
  final VoidCallback onUnsave;

  /// 是否自动播放来源例句
  final bool autoPlaySentence;

  const FlashcardCard({
    super.key,
    required this.item,
    required this.isShowingBack,
    required this.onFlip,
    required this.onUnsave,
    this.autoPlaySentence = true,
  });

  @override
  State<FlashcardCard> createState() => _FlashcardCardState();
}

class _FlashcardCardState extends State<FlashcardCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  bool _showFrontContent = true;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _animation = Tween<double>(
      begin: 0,
      end: math.pi,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));

    // 在动画 50% 处切换正/背面内容
    _controller.addListener(() {
      final shouldShowFront = _controller.value < 0.5;
      if (_showFrontContent != shouldShowFront) {
        setState(() => _showFrontContent = shouldShowFront);
      }
    });

    if (widget.isShowingBack) {
      _controller.value = 1.0;
      _showFrontContent = false;
    } else {
      _showFrontContent = true;
    }
  }

  @override
  void didUpdateWidget(covariant FlashcardCard oldWidget) {
    super.didUpdateWidget(oldWidget);

    // 检测卡片切换（不同单词）→ 立即重置无动画
    if (oldWidget.item.savedWord.word != widget.item.savedWord.word) {
      _controller.value = widget.isShowingBack ? 1.0 : 0.0;
      _showFrontContent = !widget.isShowingBack;
      return;
    }

    // 翻转动画
    if (widget.isShowingBack != oldWidget.isShowingBack) {
      if (widget.isShowingBack) {
        _controller.forward();
      } else {
        _controller.reverse();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onFlip,
      child: AnimatedBuilder(
        animation: _animation,
        builder: (context, child) {
          // 背面内容需要水平镜像翻转，否则文字是反的
          final angle = _animation.value;
          final transform = Matrix4.identity()
            ..setEntry(3, 2, 0.001) // 透视效果
            ..rotateY(angle);

          return Transform(
            alignment: Alignment.center,
            transform: transform,
            child: _showFrontContent
                ? _FrontContent(item: widget.item, onUnsave: widget.onUnsave)
                : Transform(
                    alignment: Alignment.center,
                    transform: Matrix4.identity()..rotateY(math.pi),
                    child: _BackContent(
                      item: widget.item,
                      onUnsave: widget.onUnsave,
                      autoPlaySentence: widget.autoPlaySentence,
                    ),
                  ),
          );
        },
      ),
    );
  }
}

/// 正面内容：单词 + 音标 + 发音 + 柯林斯星级
class _FrontContent extends StatelessWidget {
  final FlashcardWordItem item;
  final VoidCallback onUnsave;

  const _FrontContent({required this.item, required this.onUnsave});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final word = item.savedWord;
    final dict = item.dictEntry;

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(AppSpacing.l),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // 右上角取消收藏
            Align(
              alignment: Alignment.topRight,
              child: _UnsaveButton(onUnsave: onUnsave),
            ),

            const Spacer(),

            // 柯林斯星级（角落淡显）
            if (dict != null && dict.collins > 0) ...[
              _CollinsStars(rating: dict.collins),
              const SizedBox(height: AppSpacing.m),
            ],

            // 单词（大号居中）
            Text(
              word.word,
              style: theme.textTheme.displaySmall?.copyWith(
                fontWeight: FontWeight.w700,
                letterSpacing: -0.5,
              ),
              textAlign: TextAlign.center,
            ),

            // 音标
            if (dict != null && dict.phonetic.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.s),
              Text(
                '/${dict.phonetic}/',
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],

            // 发音按钮
            const SizedBox(height: AppSpacing.m),
            IconButton.filled(
              onPressed: () => TtsService.instance.speak(word.word),
              icon: const Icon(Icons.volume_up),
              style: IconButton.styleFrom(
                backgroundColor: theme.colorScheme.primaryContainer.withValues(
                  alpha: 0.5,
                ),
                foregroundColor: theme.colorScheme.primary,
              ),
            ),

            const Spacer(),

            // 提示文字
            Text(
              l10n.flashcardViewAnswer,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.outline,
              ),
            ),

            const SizedBox(height: AppSpacing.m),
          ],
        ),
      ),
    );
  }
}

/// 背面内容：单词+音标(小) + 柯林斯+标签 + 词性+释义 + 来源例句（可播放）
class _BackContent extends ConsumerStatefulWidget {
  final FlashcardWordItem item;
  final VoidCallback onUnsave;
  final bool autoPlaySentence;

  const _BackContent({
    required this.item,
    required this.onUnsave,
    this.autoPlaySentence = true,
  });

  @override
  ConsumerState<_BackContent> createState() => _BackContentState();
}

class _BackContentState extends ConsumerState<_BackContent> {
  bool _isPlaying = false;

  @override
  void initState() {
    super.initState();
    // TTS 朗读单词完成后，延迟一小段时间再自动播放来源例句
    if (widget.autoPlaySentence && widget.item.savedWord.sentenceText != null) {
      _autoPlayAfterTts();
    }
  }

  /// 等 TTS 朗读完毕 + 600ms 间隔后，自动播放例句原声
  Future<void> _autoPlayAfterTts() async {
    // 等待当前 TTS 播报完成
    await TtsService.instance.speak(widget.item.savedWord.word);
    if (!mounted) return;
    // 间隔 600ms
    await Future<void>.delayed(const Duration(milliseconds: 600));
    if (!mounted) return;
    _playSentence();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final word = widget.item.savedWord;
    final dict = widget.item.dictEntry;

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(AppSpacing.l),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 右上角取消收藏
            Align(
              alignment: Alignment.topRight,
              child: _UnsaveButton(onUnsave: widget.onUnsave),
            ),

            // 单词 + 音标（顶部，较小）
            Row(
              children: [
                Text(
                  word.word,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(width: AppSpacing.s),
                if (dict != null && dict.phonetic.isNotEmpty)
                  Text(
                    '/${dict.phonetic}/',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                const SizedBox(width: AppSpacing.xs),
                // 发音按钮（小）
                SizedBox(
                  width: 32,
                  height: 32,
                  child: IconButton(
                    onPressed: () => TtsService.instance.speak(word.word),
                    icon: const Icon(Icons.volume_up, size: 18),
                    color: theme.colorScheme.primary,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ),
              ],
            ),

            // 柯林斯星级 + 考试标签（单词下方、释义上方）
            if (dict != null &&
                (dict.collins > 0 || dict.examTags.isNotEmpty)) ...[
              const SizedBox(height: AppSpacing.s),
              _buildMetaTags(theme, dict),
            ],

            const SizedBox(height: AppSpacing.m),

            // 释义（主体）
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (dict != null && dict.translation != null)
                      _buildTranslation(theme, dict.translation!)
                    else
                      Text(
                        l10n.flashcardNoDefinition,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                          fontStyle: FontStyle.italic,
                        ),
                      ),

                    // 来源例句（支持播放）
                    if (word.sentenceText != null) ...[
                      const SizedBox(height: AppSpacing.m),
                      const Divider(height: 1),
                      const SizedBox(height: AppSpacing.m),
                      _buildSentenceRow(theme, word),
                    ],
                  ],
                ),
              ),
            ),

            // 提示文字
            Center(
              child: Text(
                l10n.flashcardTapToFlip,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.outline,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 来源例句行 — 带播放按钮
  Widget _buildSentenceRow(ThemeData theme, dynamic word) {
    final canPlay =
        word.audioItemId != null &&
        (word.sentenceIndex != null ||
            (word.sentenceStartMs != null && word.sentenceEndMs != null));

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (canPlay)
          GestureDetector(
            onTap: _playSentence,
            child: Padding(
              padding: const EdgeInsets.only(top: 2, right: 8),
              child: Icon(
                _isPlaying
                    ? Icons.stop_circle_outlined
                    : Icons.play_circle_outline,
                size: 22,
                color: _isPlaying
                    ? theme.colorScheme.error
                    : theme.colorScheme.primary,
              ),
            ),
          ),
        Expanded(
          child: Text(
            word.sentenceText!,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontStyle: FontStyle.italic,
              height: 1.6,
            ),
          ),
        ),
      ],
    );
  }

  /// 播放来源句子的原声片段
  Future<void> _playSentence() async {
    final word = widget.item.savedWord;
    if (word.audioItemId == null) return;

    final hasStoredTiming =
        word.sentenceStartMs != null && word.sentenceEndMs != null;
    if (!hasStoredTiming && word.sentenceIndex == null) return;

    if (_isPlaying) {
      ref.read(audioEngineProvider.notifier).stop();
      setState(() => _isPlaying = false);
      return;
    }

    setState(() => _isPlaying = true);

    try {
      final engine = ref.read(audioEngineProvider.notifier);
      final engineState = ref.read(audioEngineProvider);

      final dao = ref.read(audioItemDaoProvider);
      final row = await dao.getById(word.audioItemId!);
      if (row == null || !mounted) {
        setState(() => _isPlaying = false);
        return;
      }

      final audioItem = model.AudioItem(
        id: row.id,
        name: row.name,
        audioPath: row.audioPath,
        transcriptPath: row.transcriptPath,
        addedDate: row.addedDate,
        totalDuration: row.totalDuration,
        sentenceCount: row.sentenceCount,
        wordCount: row.wordCount,
        isStarred: row.isStarred,
        transcriptSource: model.TranscriptSource.fromIndex(
          row.transcriptSource,
        ),
        audioSha256: row.audioSha256,
        transcriptLanguage: row.transcriptLanguage,
      );

      if (engineState.currentAudioId != word.audioItemId) {
        await engine.loadAudio(audioItem, 1.0);
      }
      if (!mounted) return;

      Duration startTime;
      Duration endTime;

      if (hasStoredTiming) {
        startTime = Duration(milliseconds: word.sentenceStartMs!);
        endTime = Duration(milliseconds: word.sentenceEndMs!);
      } else {
        if (row.transcriptPath == null) {
          setState(() => _isPlaying = false);
          return;
        }
        final sentences = await engine.loadTranscript(audioItem);
        if (!mounted || word.sentenceIndex! >= sentences.length) {
          setState(() => _isPlaying = false);
          return;
        }
        final sentence = sentences[word.sentenceIndex!];
        startTime = sentence.startTime;
        endTime = sentence.endTime;
      }

      final sessionId = engine.newSession();
      await engine.playRangeOnce(startTime, endTime, sessionId);
    } catch (_) {
      // 忽略播放错误（音频文件不存在等）
    } finally {
      if (mounted) {
        setState(() => _isPlaying = false);
      }
    }
  }

  /// 释义内容 — 解析词性前缀
  Widget _buildTranslation(ThemeData theme, String translation) {
    final lines = translation.split('\n').where((l) => l.trim().isNotEmpty);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final line in lines)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: _buildDefinitionLine(theme, line.trim()),
          ),
      ],
    );
  }

  /// 单条释义行 — 词性标签 + 释义文本
  Widget _buildDefinitionLine(ThemeData theme, String line) {
    final posMatch = RegExp(
      r'^([a-z]+\.(?:\s*&\s*[a-z]+\.)*)\s*',
    ).firstMatch(line);

    if (posMatch == null) {
      return Text(
        line,
        style: theme.textTheme.bodyLarge?.copyWith(height: 1.6),
      );
    }

    final pos = posMatch.group(1)!;
    final definition = line.substring(posMatch.end);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              pos,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: theme.colorScheme.primary,
                height: 1.3,
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            definition,
            style: theme.textTheme.bodyLarge?.copyWith(height: 1.6),
          ),
        ),
      ],
    );
  }

  /// 柯林斯星级 + 考试标签
  Widget _buildMetaTags(ThemeData theme, DictEntry entry) {
    return Wrap(
      spacing: 8,
      runSpacing: 4,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        if (entry.collins > 0) _CollinsStars(rating: entry.collins),
        for (final tag in entry.examTags)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              tag,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.primary,
              ),
            ),
          ),
      ],
    );
  }
}

/// 取消收藏按钮 + 提示
class _UnsaveButton extends StatelessWidget {
  final VoidCallback onUnsave;

  const _UnsaveButton({required this.onUnsave});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          l10n.flashcardUnsaveHint,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.outline.withValues(alpha: 0.6),
          ),
        ),
        IconButton(
          onPressed: onUnsave,
          icon: const Icon(Icons.bookmark, size: 20),
          color: theme.colorScheme.primary,
          tooltip: l10n.flashcardUnsaveHint,
        ),
      ],
    );
  }
}

/// 柯林斯星级
class _CollinsStars extends StatelessWidget {
  final int rating;

  const _CollinsStars({required this.rating});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (i) {
        return Icon(
          Icons.star_rounded,
          size: 14,
          color: i < rating
              ? Colors.amber.shade600
              : theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
        );
      }),
    );
  }
}
