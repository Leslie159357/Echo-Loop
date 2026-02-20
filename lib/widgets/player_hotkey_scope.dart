import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/listening_practice/listening_practice_provider.dart';
import '../providers/audio_engine/audio_engine_provider.dart';

// 自定义 Intent
class PlayPauseIntent extends Intent {
  const PlayPauseIntent();
}

class PrevSentenceIntent extends Intent {
  const PrevSentenceIntent();
}

class NextSentenceIntent extends Intent {
  const NextSentenceIntent();
}

class ToggleTranscriptIntent extends Intent {
  const ToggleTranscriptIntent();
}

// 播放器快捷键作用域
class PlayerHotkeyScope extends ConsumerWidget {
  final Widget child;

  const PlayerHotkeyScope({
    super.key,
    required this.child,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playerState = ref.watch(listeningPracticeProvider);
    final controller = ref.read(listeningPracticeProvider.notifier);
    final engineNotifier = ref.read(audioEngineProvider.notifier);

    return Focus(
      autofocus: true,
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent) {
          final key = event.logicalKey;
          // 空格：播放/暂停
          if (key == LogicalKeyboardKey.space) {
            engineNotifier.isPlaying ? controller.pause() : controller.play();
            return KeyEventResult.handled;
          }
          // 左右箭头：上一/下一句
          if (key == LogicalKeyboardKey.arrowLeft) {
            if (playerState.hasSentences) controller.previousSentence();
            return KeyEventResult.handled;
          }
          if (key == LogicalKeyboardKey.arrowRight) {
            if (playerState.hasSentences) controller.nextSentence();
            return KeyEventResult.handled;
          }
          // 上箭头：切换字幕显示
          if (key == LogicalKeyboardKey.arrowUp) {
            final s = playerState.settings;
            controller.updateSettings(
              s.copyWith(showTranscript: !s.showTranscript),
            );
            return KeyEventResult.handled;
          }
          // 下箭头：拦截，防止列表滚动
          if (key == LogicalKeyboardKey.arrowDown) {
            return KeyEventResult.handled;
          }
          // R 键：重播当前句子
          if (key == LogicalKeyboardKey.keyR) {
            if (playerState.hasSentences) {
              controller.replayCurrentSentence();
            }
            return KeyEventResult.handled;
          }
        }
        return KeyEventResult.ignored;
      },
      child: Shortcuts(
        shortcuts: <ShortcutActivator, Intent>{
          SingleActivator(LogicalKeyboardKey.space): const PlayPauseIntent(),
          SingleActivator(LogicalKeyboardKey.arrowLeft):
              const PrevSentenceIntent(),
          SingleActivator(LogicalKeyboardKey.arrowRight):
              const NextSentenceIntent(),
          SingleActivator(LogicalKeyboardKey.arrowUp):
              const ToggleTranscriptIntent(),
        },
        child: Actions(
          actions: <Type, Action<Intent>>{
            PlayPauseIntent: CallbackAction<PlayPauseIntent>(
              onInvoke: (i) {
                engineNotifier.isPlaying
                    ? controller.pause()
                    : controller.play();
                return null;
              },
            ),
            PrevSentenceIntent: CallbackAction<PrevSentenceIntent>(
              onInvoke: (i) {
                if (playerState.hasSentences) {
                  controller.previousSentence();
                }
                return null;
              },
            ),
            NextSentenceIntent: CallbackAction<NextSentenceIntent>(
              onInvoke: (i) {
                if (playerState.hasSentences) controller.nextSentence();
                return null;
              },
            ),
            ToggleTranscriptIntent: CallbackAction<ToggleTranscriptIntent>(
              onInvoke: (i) {
                final s = playerState.settings;
                controller.updateSettings(
                  s.copyWith(showTranscript: !s.showTranscript),
                );
                return null;
              },
            ),
          },
          child: child,
        ),
      ),
    );
  }
}
