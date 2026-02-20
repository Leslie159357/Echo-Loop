import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../l10n/app_localizations.dart';
import '../providers/listening_practice/listening_practice_provider.dart';

class SettingsDialog extends ConsumerWidget {
  const SettingsDialog({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final playerState = ref.watch(listeningPracticeProvider);
    final controller = ref.read(listeningPracticeProvider.notifier);

    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 500, maxHeight: 600),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppBar(
              title: Text(l10n.settings),
              automaticallyImplyLeading: false,
              actions: [
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSentenceRepeatSettings(
                      context, l10n, playerState, controller,
                    ),
                    const SizedBox(height: 16),
                    _buildAudioLoopSettings(
                      context, l10n, playerState, controller,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSentenceRepeatSettings(
    BuildContext context,
    AppLocalizations l10n,
    ListeningPracticeState playerState,
    ListeningPractice controller,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              l10n.autoPlayNextSentence,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            Switch(
              value: playerState.settings.autoPlayNextSentenceEnabled,
              onChanged: (value) {
                controller.updateSettings(
                  playerState.settings
                      .copyWith(autoPlayNextSentenceEnabled: value),
                );
              },
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              l10n.sentenceRepeat,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            Switch(
              value: playerState.settings.loopEnabled,
              onChanged: (value) {
                controller.updateSettings(
                  playerState.settings.copyWith(loopEnabled: value),
                );
              },
            ),
          ],
        ),
        if (playerState.settings.loopEnabled) ...[
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(l10n.repeatCount),
              SizedBox(
                width: 140,
                child: DropdownButtonFormField<int>(
                  value: playerState.settings.loopCount,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    isDense: true,
                  ),
                  isExpanded: true,
                  menuMaxHeight: 300,
                  items: List.generate(20, (i) => i + 1).map((count) {
                    return DropdownMenuItem(
                      value: count,
                      child: Text('$count ${l10n.times}'),
                    );
                  }).toList(),
                  onChanged: (value) {
                    if (value != null) {
                      controller.updateSettings(
                        playerState.settings.copyWith(loopCount: value),
                      );
                    }
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(l10n.intervalTime),
              SizedBox(
                width: 140,
                child: DropdownButtonFormField<int>(
                  value: playerState.settings.pauseInterval.inSeconds,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    isDense: true,
                  ),
                  isExpanded: true,
                  menuMaxHeight: 300,
                  items: List.generate(31, (i) => i).map((seconds) {
                    return DropdownMenuItem(
                      value: seconds,
                      child: Text('$seconds ${l10n.seconds}'),
                    );
                  }).toList(),
                  onChanged: (value) {
                    if (value != null) {
                      controller.updateSettings(
                        playerState.settings.copyWith(
                          pauseInterval: Duration(seconds: value),
                        ),
                      );
                    }
                  },
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildAudioLoopSettings(
    BuildContext context,
    AppLocalizations l10n,
    ListeningPracticeState playerState,
    ListeningPractice controller,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              l10n.audioLoop,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            Switch(
              value: playerState.settings.loopAudioEnabled,
              onChanged: (value) {
                controller.updateSettings(
                  playerState.settings.copyWith(loopAudioEnabled: value),
                );
              },
            ),
          ],
        ),
        if (playerState.settings.loopAudioEnabled) ...[
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(l10n.loopTimes),
              SizedBox(
                width: 140,
                child: DropdownButtonFormField<int>(
                  value: playerState.settings.loopAudio,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    isDense: true,
                  ),
                  isExpanded: true,
                  menuMaxHeight: 300,
                  items: [
                    ...List.generate(10, (i) => i + 1).map((count) {
                      return DropdownMenuItem(
                        value: count,
                        child: Text('$count ${l10n.times}'),
                      );
                    }),
                    DropdownMenuItem(value: 0, child: Text(l10n.infiniteLoop)),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      controller.updateSettings(
                        playerState.settings.copyWith(loopAudio: value),
                      );
                    }
                  },
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}
