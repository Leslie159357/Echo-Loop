/// Flashcard 卡片组件
///
/// 包含 3D 翻转动画（Matrix4.rotateY），正面显示单词+音标+发音，
/// 背面显示释义+来源例句。右上角取消收藏按钮。
library;

import 'dart:math' as math;
import 'dart:math' show min;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:go_router/go_router.dart';

import '../../database/providers.dart';
import '../../l10n/app_localizations.dart';
import '../../models/audio_item.dart' as model;
import '../../models/dict_entry.dart';
import '../../providers/audio_engine/audio_engine_provider.dart';
import '../../models/flashcard_item.dart';
import '../../providers/flashcard/flashcard_provider.dart';
import '../../router/app_router.dart';
import '../../services/app_logger.dart';
import '../../services/tts_service.dart';
import '../../theme/app_theme.dart';
import '../common/text_context_menu.dart';

/// Flashcard 翻转卡片
class FlashcardCard extends StatefulWidget {
  /// 卡片数据
  final FlashcardItem item;

  /// 是否显示背面
  final bool isShowingBack;

  /// 翻转回调
  final VoidCallback onFlip;

  /// 切换收藏状态回调
  final VoidCallback onUnsave;

  /// 当前单词是否已取消收藏
  final bool isUnsaved;

  /// 是否自动播放来源例句
  final bool autoPlaySentence;

  /// 是否自动 TTS 朗读单词
  final bool autoPlayWord;

  /// 正面点击发音按钮时的回调（用于重置倒计时等）
  final VoidCallback? onPlayWord;

  const FlashcardCard({
    super.key,
    required this.item,
    required this.isShowingBack,
    required this.onFlip,
    required this.onUnsave,
    this.isUnsaved = false,
    this.autoPlaySentence = true,
    this.autoPlayWord = true,
    this.onPlayWord,
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
    if (oldWidget.item.displayText != widget.item.displayText) {
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
                ? _FrontContent(
                    item: widget.item,
                    onUnsave: widget.onUnsave,
                    isUnsaved: widget.isUnsaved,
                    onPlayWord: widget.onPlayWord,
                  )
                : Transform(
                    alignment: Alignment.center,
                    transform: Matrix4.identity()..rotateY(math.pi),
                    child: _BackContent(
                      item: widget.item,
                      onUnsave: widget.onUnsave,
                      isUnsaved: widget.isUnsaved,
                      autoPlaySentence: widget.autoPlaySentence,
                      autoPlayWord: widget.autoPlayWord,
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
  final FlashcardItem item;
  final VoidCallback onUnsave;
  final bool isUnsaved;
  final VoidCallback? onPlayWord;

  const _FrontContent({
    required this.item,
    required this.onUnsave,
    this.isUnsaved = false,
    this.onPlayWord,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final word = item;
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
              child: _UnsaveButton(onUnsave: onUnsave, isUnsaved: isUnsaved),
            ),

            const Spacer(),

            // 柯林斯星级（角落淡显）
            if (dict != null && dict.collins > 0) ...[
              _CollinsStars(rating: dict.collins),
              const SizedBox(height: AppSpacing.m),
            ],

            // 单词（大号居中，支持长按/右键复制）
            GestureDetector(
              onLongPressStart: (details) => TextContextMenu.show(
                context,
                details.globalPosition,
                word.displayText,
              ),
              onSecondaryTapDown: (details) => TextContextMenu.show(
                context,
                details.globalPosition,
                word.displayText,
              ),
              child: Text(
                word.displayText,
                style: _displayTextStyle(theme, word.displayText.length),
                textAlign: TextAlign.center,
              ),
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
              onPressed:
                  onPlayWord ?? () => TtsService.instance.speak(word.displayText),
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
  final FlashcardItem item;
  final VoidCallback onUnsave;
  final bool isUnsaved;
  final bool autoPlaySentence;
  final bool autoPlayWord;

  const _BackContent({
    required this.item,
    required this.onUnsave,
    this.isUnsaved = false,
    this.autoPlaySentence = true,
    this.autoPlayWord = true,
  });

  @override
  ConsumerState<_BackContent> createState() => _BackContentState();
}

class _BackContentState extends ConsumerState<_BackContent> {
  bool _isPlaying = false;

  /// 用户手动点击播放时置 true，阻止自动播放覆盖
  bool _autoPlayCancelled = false;

  /// 源音频名称（异步加载）
  String? _audioName;

  @override
  void initState() {
    super.initState();
    // 翻转到背面时：先 TTS 朗读单词（如开启），再自动播放来源例句（如开启）
    _autoPlayOnFlipToBack();
    // 异步加载源音频名称
    _loadAudioName();
  }

  /// 加载源音频名称
  Future<void> _loadAudioName() async {
    final audioId = widget.item.audioItemId;
    if (audioId == null) return;
    final dao = ref.read(audioItemDaoProvider);
    final row = await dao.getById(audioId);
    if (mounted && row != null) {
      setState(() => _audioName = row.name);
    }
  }

  /// 翻转到背面时的自动播放逻辑
  ///
  /// TTS + 例句全部播完后通知 Provider 启动倒计时。
  Future<void> _autoPlayOnFlipToBack() async {
    AppLogger.log(
      'FC-Audio',
      'autoPlay START: word="${widget.item.savedWord.word}", '
          'autoPlayWord=${widget.autoPlayWord}, '
          'autoPlaySentence=${widget.autoPlaySentence}',
    );

    // TTS 朗读单词
    if (widget.autoPlayWord) {
      await TtsService.instance.speak(widget.item.displayText);
      if (!mounted) return;
      // TTS 播完，计入 1 个输入词
      ref.read(flashcardNotifierProvider.notifier).onWordPlayed();
    }

    // 自动播放来源例句
    if (widget.autoPlaySentence && widget.item.sentenceText != null) {
      await Future<void>.delayed(const Duration(milliseconds: 600));
      AppLogger.log(
        'FC-Audio',
        'autoPlay: 600ms elapsed, cancelled=$_autoPlayCancelled, '
            'mounted=$mounted',
      );
      if (!mounted || _autoPlayCancelled) return;
      await _playSentence();
      if (!mounted) return;
    }

    // 全部播放完成，通知 Provider 启动倒计时
    ref.read(flashcardNotifierProvider.notifier).onAutoPlayCompleted();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final word = widget.item;
    final dict = widget.item.dictEntry;

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(AppSpacing.l),
        child: Column(
          children: [
            // 右上角取消收藏
            Align(
              alignment: Alignment.topRight,
              child: _UnsaveButton(
                onUnsave: widget.onUnsave,
                isUnsaved: widget.isUnsaved,
              ),
            ),

            // 主体内容整体居中（单词+释义+例句作为一个块）
            Expanded(
              child: Center(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 单词/意群文本
                      GestureDetector(
                        onLongPressStart: (details) => TextContextMenu.show(
                          context,
                          details.globalPosition,
                          word.displayText,
                        ),
                        onSecondaryTapDown: (details) =>
                            TextContextMenu.show(
                              context,
                              details.globalPosition,
                              word.displayText,
                            ),
                        child: Text(
                          word.displayText,
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      // 音标 + TTS
                      Row(
                        children: [
                          if (dict != null && dict.phonetic.isNotEmpty)
                            Text(
                              '/${dict.phonetic}/',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          if (dict != null && dict.phonetic.isNotEmpty)
                            const SizedBox(width: AppSpacing.xs),
                          SizedBox(
                            width: 32,
                            height: 32,
                            child: IconButton(
                              onPressed: () async {
                                await TtsService.instance.speak(word.displayText);
                                if (!mounted) return;
                                ref
                                    .read(flashcardNotifierProvider.notifier)
                                    .onWordPlayed();
                              },
                              icon: const Icon(Icons.volume_up, size: 18),
                              color: theme.colorScheme.primary,
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                            ),
                          ),
                        ],
                      ),

                      // 柯林斯星级 + 考试标签
                      if (dict != null &&
                          (dict.collins > 0 || dict.examTags.isNotEmpty)) ...[
                        const SizedBox(height: AppSpacing.s),
                        _buildMetaTags(theme, dict),
                      ],

                      const SizedBox(height: AppSpacing.m),

                      // 释义
                      if (dict != null && dict.translation != null)
                        _buildTranslation(theme, dict.translation!),

                      // 来源例句
                      if (word.sentenceText != null) ...[
                        const SizedBox(height: AppSpacing.m),
                        const Divider(height: 1),
                        const SizedBox(height: AppSpacing.m),
                        _buildSentenceRow(theme, word),
                      ],

                      // 源音频引用
                      if (_audioName != null && word.audioItemId != null) ...[
                        const SizedBox(height: AppSpacing.s),
                        _AudioSourceLink(
                          audioName: _audioName!,
                          audioItemId: word.audioItemId!,
                        ),
                      ],
                    ],
                  ),
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

  /// 来源例句行 — 点击整行播放句子原声
  Widget _buildSentenceRow(ThemeData theme, dynamic word) {
    final canPlay =
        word.audioItemId != null &&
        (word.sentenceIndex != null ||
            (word.sentenceStartMs != null && word.sentenceEndMs != null));

    final row = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (canPlay)
          Padding(
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
        Expanded(
          child: Text(
            word.sentenceText!,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              height: 1.6,
            ),
          ),
        ),
      ],
    );

    // 可播放时，整行点击触发播放（同时阻止冒泡到卡片翻转）
    // 长按/右键弹出复制菜单
    if (canPlay) {
      return GestureDetector(
        onTap: () => _playSentence(isUserTap: true),
        onLongPressStart: (details) => TextContextMenu.show(
          context,
          details.globalPosition,
          word.sentenceText!,
        ),
        onSecondaryTapDown: (details) => TextContextMenu.show(
          context,
          details.globalPosition,
          word.sentenceText!,
        ),
        behavior: HitTestBehavior.opaque,
        child: row,
      );
    }
    // 不可播放时也支持长按/右键复制
    return GestureDetector(
      onLongPressStart: (details) => TextContextMenu.show(
        context,
        details.globalPosition,
        word.sentenceText!,
      ),
      onSecondaryTapDown: (details) => TextContextMenu.show(
        context,
        details.globalPosition,
        word.sentenceText!,
      ),
      child: row,
    );
  }

  /// 播放来源句子的原声片段
  ///
  /// [isUserTap] 为 true 表示用户手动点击，会取消自动播放。
  Future<void> _playSentence({bool isUserTap = false}) async {
    if (isUserTap) _autoPlayCancelled = true;

    final word = widget.item;
    if (word.audioItemId == null) return;

    final hasStoredTiming =
        word.sentenceStartMs != null && word.sentenceEndMs != null;
    if (!hasStoredTiming && word.sentenceIndex == null) {
      AppLogger.log(
        'FC-Audio',
        '_playSentence RETURN: no stored timing and sentenceIndex is null',
      );
      return;
    }

    final notifier = ref.read(flashcardNotifierProvider.notifier);

    if (_isPlaying) {
      AppLogger.log(
        'FC-Audio',
        '_playSentence STOP: already playing, calling engine.stop()',
      );
      ref.read(audioEngineProvider.notifier).stop();
      setState(() => _isPlaying = false);
      notifier.onSentencePlaybackEnded();
      return;
    }

    setState(() => _isPlaying = true);
    notifier.onSentencePlaybackStarted();

    try {
      final engine = ref.read(audioEngineProvider.notifier);
      final engineState = ref.read(audioEngineProvider);

      final dao = ref.read(audioItemDaoProvider);
      final row = await dao.getById(word.audioItemId!);
      AppLogger.log(
        'FC-Audio',
        'DB fetch: ${row != null ? "found" : "NULL"}, '
            'audioPath=${row?.audioPath}',
      );
      if (row == null || !mounted) {
        AppLogger.log('FC-Audio', '_playSentence RETURN: row=$row, mounted=$mounted');
        if (mounted) setState(() => _isPlaying = false);
        notifier.onSentencePlaybackEnded();
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

      final needReload = engineState.currentAudioId != word.audioItemId;
      AppLogger.log(
        'FC-Audio',
        'Audio load: currentAudioId=${engineState.currentAudioId}, '
            'needed=${word.audioItemId}, reload=$needReload, '
            'sessionId=${engineState.sessionId}',
      );
      if (needReload) {
        await engine.loadAudio(audioItem, 1.0);
        AppLogger.log(
          'FC-Audio',
          'loadAudio done. newAudioId=${ref.read(audioEngineProvider).currentAudioId}, '
              'sessionId=${ref.read(audioEngineProvider).sessionId}',
        );
      }
      if (!mounted) return;

      Duration startTime;
      Duration endTime;

      /// 存储时间是否可信（最少 200ms）
      const minDurationMs = 200;
      final storedDurationOk = hasStoredTiming &&
          (word.sentenceEndMs! - word.sentenceStartMs!) >= minDurationMs;

      // 优先用存储时间，但如果太短（数据异常）则回退 transcript
      if (hasStoredTiming && storedDurationOk) {
        startTime = Duration(milliseconds: word.sentenceStartMs!);
        endTime = Duration(milliseconds: word.sentenceEndMs!);
        AppLogger.log(
          'FC-Audio',
          'Timing(stored): ${startTime.inMilliseconds}-${endTime.inMilliseconds}ms, '
              'duration=${(endTime - startTime).inMilliseconds}ms',
        );
      } else {
        // 存储时间异常时记录警告
        if (hasStoredTiming && !storedDurationOk) {
          AppLogger.log(
            'FC-Audio',
            '⚠ Stored timing too short: '
                '${word.sentenceStartMs}-${word.sentenceEndMs}ms '
                '(${word.sentenceEndMs! - word.sentenceStartMs!}ms), '
                'falling back to transcript',
          );
        }
        if (word.sentenceIndex == null) {
          AppLogger.log(
            'FC-Audio',
            '_playSentence RETURN: no valid timing and sentenceIndex is null',
          );
          if (mounted) setState(() => _isPlaying = false);
          notifier.onSentencePlaybackEnded();
          return;
        }
        if (row.transcriptPath == null) {
          AppLogger.log('FC-Audio', '_playSentence RETURN: transcriptPath is null');
          if (mounted) setState(() => _isPlaying = false);
          notifier.onSentencePlaybackEnded();
          return;
        }
        final sentences = await engine.loadTranscript(audioItem);
        AppLogger.log(
          'FC-Audio',
          'Transcript loaded: ${sentences.length} sentences, '
              'need index=${word.sentenceIndex}',
        );
        if (!mounted || sentences.isEmpty) {
          if (mounted) setState(() => _isPlaying = false);
          notifier.onSentencePlaybackEnded();
          return;
        }

        // 优先用 sentenceIndex，但若字幕重新生成导致索引错位，
        // 则通过 sentenceText 匹配找到正确句子
        final idx = word.sentenceIndex!;
        var sentence = idx < sentences.length ? sentences[idx] : null;
        final storedText = word.sentenceText;

        // 检测索引错位：索引对应句子文本与存储文本不匹配
        if (sentence != null &&
            storedText != null &&
            sentence.text.trim() != storedText.trim()) {
          AppLogger.log(
            'FC-Audio',
            '⚠ Index mismatch! index=$idx text="${sentence.text.substring(0, min(30, sentence.text.length))}" '
                'vs stored="${storedText.substring(0, min(30, storedText.length))}", '
                'trying text match',
          );
          // 文本匹配回退
          sentence = null;
          for (final s in sentences) {
            if (s.text.trim() == storedText.trim()) {
              sentence = s;
              AppLogger.log(
                'FC-Audio',
                '✓ Text match found at index=${s.index}, '
                    '${s.startTime.inMilliseconds}-${s.endTime.inMilliseconds}ms',
              );
              break;
            }
          }
        }

        if (sentence == null) {
          AppLogger.log(
            'FC-Audio',
            '_playSentence RETURN: no matching sentence found '
                '(index=$idx, totalSentences=${sentences.length})',
          );
          if (mounted) setState(() => _isPlaying = false);
          notifier.onSentencePlaybackEnded();
          return;
        }

        startTime = sentence.startTime;
        endTime = sentence.endTime;
        AppLogger.log(
          'FC-Audio',
          'Timing(transcript): ${startTime.inMilliseconds}-${endTime.inMilliseconds}ms, '
              'duration=${(endTime - startTime).inMilliseconds}ms, '
              'transcriptText="${sentence.text.substring(0, min(40, sentence.text.length))}"',
        );
      }

      final sessionId = engine.newSession();
      AppLogger.log(
        'FC-Audio',
        'Calling playRangeOnce: '
            '${startTime.inMilliseconds}-${endTime.inMilliseconds}ms, '
            'sessionId=$sessionId',
      );
      await engine.playRangeOnce(startTime, endTime, sessionId);
      AppLogger.log(
        'FC-Audio',
        'playRangeOnce returned. mounted=$mounted, _isPlaying=$_isPlaying',
      );

      // 例句播放完成，计入输入词数
      if (mounted && word.sentenceText != null) {
        ref
            .read(flashcardNotifierProvider.notifier)
            .onSentencePlayed(word.sentenceText!);
      }
    } catch (e, stackTrace) {
      AppLogger.log(
        'FC-Audio',
        '⚠ _playSentence error: $e\n$stackTrace',
      );
    } finally {
      AppLogger.log(
        'FC-Audio',
        '_playSentence FINALLY: mounted=$mounted, _isPlaying=$_isPlaying',
      );
      if (mounted && _isPlaying) {
        setState(() => _isPlaying = false);
        notifier.onSentencePlaybackEnded();
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

/// 收藏状态切换按钮 + 提示
class _UnsaveButton extends StatelessWidget {
  final VoidCallback onUnsave;
  final bool isUnsaved;

  const _UnsaveButton({required this.onUnsave, this.isUnsaved = false});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;

    return GestureDetector(
      onTap: onUnsave,
      behavior: HitTestBehavior.opaque,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            isUnsaved
                ? l10n.favoritesVocabularyRemoved
                : l10n.flashcardUnsaveHint,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.outline.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(width: 4),
          Icon(
            isUnsaved ? Icons.bookmark_border : Icons.bookmark,
            size: 20,
            color: isUnsaved ? Colors.grey : Colors.amber,
          ),
        ],
      ),
    );
  }
}

/// 源音频引用链接（小字弱化，右对齐，点击跳转学习计划）
class _AudioSourceLink extends StatelessWidget {
  final String audioName;
  final String audioItemId;

  const _AudioSourceLink({required this.audioName, required this.audioItemId});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;

    return Align(
      alignment: Alignment.centerRight,
      child: GestureDetector(
        onTap: () => context.push(AppRoutes.audioLearningPlan(audioItemId)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.headphones,
              size: 12,
              color: theme.colorScheme.outline.withValues(alpha: 0.6),
            ),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                l10n.bookmarkReviewFromAudio(audioName),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  fontSize: 11,
                  color: theme.colorScheme.outline.withValues(alpha: 0.6),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 柯林斯星级
/// 根据文本长度计算闪卡正面的字体样式
///
/// 短单词用大号字体，长意群/短语逐级缩小，保证可读性。
TextStyle? _displayTextStyle(ThemeData theme, int length) {
  final TextStyle? base;
  if (length <= 10) {
    base = theme.textTheme.displaySmall; // ~36sp
  } else if (length <= 20) {
    base = theme.textTheme.headlineLarge; // ~32sp
  } else if (length <= 35) {
    base = theme.textTheme.headlineMedium; // ~28sp
  } else if (length <= 50) {
    base = theme.textTheme.headlineSmall; // ~24sp
  } else {
    base = theme.textTheme.titleLarge; // ~22sp
  }
  return base?.copyWith(
    fontWeight: FontWeight.w700,
    letterSpacing: -0.5,
  );
}

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
