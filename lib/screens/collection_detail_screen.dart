import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:universal_io/io.dart';
import 'package:path_provider/path_provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as path;
import '../models/audio_item.dart';
import '../models/collection.dart';
import '../providers/collection_provider.dart';
import '../providers/audio_library_provider.dart';
import '../providers/listening_practice/listening_practice_provider.dart';
import '../l10n/app_localizations.dart';
import '../router/app_router.dart';
import '../theme/app_theme.dart';

/// 合集详情页面 - 展示合集中的音频，支持上传音频
class CollectionDetailScreen extends ConsumerWidget {
  final String collectionId;

  const CollectionDetailScreen({super.key, required this.collectionId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final collectionState = ref.watch(collectionListProvider);
    ref.watch(audioLibraryProvider); // watch to rebuild when library changes

    final collection = collectionState.rawCollections
        .where((c) => c.id == collectionId)
        .firstOrNull;
    if (collection == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: Text('Collection not found')),
      );
    }

    // 获取合集中的音频项（从 junction 表缓存中读取）
    final audioIds = collectionState.getAudioIds(collectionId);
    final audioItems = audioIds
        .map((id) => ref.read(audioLibraryProvider.notifier).getItemById(id))
        .whereType<AudioItem>()
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(collection.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: l10n.addAudioToCollection,
            onPressed: () => _showAddAudioDialog(context, collection),
          ),
        ],
      ),
      body: audioItems.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.library_music_outlined,
                    size: 64,
                    color: Theme.of(context).colorScheme.outline,
                  ),
                  const SizedBox(height: AppSpacing.m),
                  Text(
                    l10n.emptyCollection,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: AppSpacing.s),
                  Text(
                    l10n.tapToAddAudio,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.l),
                  FilledButton.icon(
                    onPressed: () => _showAddAudioDialog(context, collection),
                    icon: const Icon(Icons.add),
                    label: Text(l10n.addAudioToCollection),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(8),
              itemCount: audioItems.length,
              itemBuilder: (context, index) {
                final item = audioItems[index];
                return _CollectionAudioTile(
                  audioItem: item,
                  collectionId: collectionId,
                );
              },
            ),
    );
  }

  /// 显示添加音频对话框（复用音频库的上传逻辑）
  void _showAddAudioDialog(BuildContext context, Collection collection) {
    showDialog(
      context: context,
      builder: (context) =>
          _AddAudioToCollectionDialog(collectionId: collection.id),
    );
  }
}

/// 合集中的音频列表项
class _CollectionAudioTile extends ConsumerWidget {
  final AudioItem audioItem;
  final String collectionId;

  const _CollectionAudioTile({
    required this.audioItem,
    required this.collectionId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final currentAudioItem = ref.watch(
      listeningPracticeProvider.select((s) => s.currentAudioItem),
    );
    final isCurrentlyPlaying = currentAudioItem?.id == audioItem.id;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      color: isCurrentlyPlaying
          ? Theme.of(
              context,
            ).colorScheme.primaryContainer.withValues(alpha: 0.3)
          : null,
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Colors.transparent,
          child: Icon(
            Icons.audiotrack,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
        title: Text(
          audioItem.name,
          style: const TextStyle(fontWeight: FontWeight.w500),
        ),
        subtitle: Row(
          children: [
            if (audioItem.hasTranscript) ...[
              Icon(
                Icons.subtitles,
                size: 16,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 4),
              Text(
                l10n.transcript,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.primary,
                  fontSize: 12,
                ),
              ),
              const SizedBox(width: 12),
            ],
            Text(
              l10n.addedOn(_formatDate(audioItem.addedDate)),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isCurrentlyPlaying)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  l10n.playing,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onPrimary,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            const SizedBox(width: 8),
            PopupMenuButton(
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: 'rename',
                  child: Row(
                    children: [
                      const Icon(Icons.edit, size: 20),
                      const SizedBox(width: 8),
                      Text(l10n.renameAudio),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'delete',
                  child: Row(
                    children: [
                      Icon(
                        Icons.delete,
                        size: 20,
                        color: Theme.of(context).colorScheme.error,
                      ),
                      const SizedBox(width: 8),
                      Text(l10n.delete),
                    ],
                  ),
                ),
              ],
              onSelected: (value) {
                if (value == 'rename') {
                  _showRenameAudioDialog(context, ref);
                } else if (value == 'delete') {
                  _confirmRemove(context, ref);
                }
              },
            ),
          ],
        ),
        onTap: () async {
          // 验证音频文件是否存在
          final fullAudioPath = await audioItem.getFullAudioPath();
          final audioFile = File(fullAudioPath);
          if (!await audioFile.exists()) {
            if (!context.mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(l10n.audioFileNotFound),
                duration: const Duration(seconds: 3),
              ),
            );
            return;
          }
          if (!context.mounted) return;
          context.push(
            AppRoutes.learningPlan(collectionId, audioItem.id),
          );
        },
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.month}/${date.day}/${date.year}';
  }

  /// 重命名音频对话框
  void _showRenameAudioDialog(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final controller = TextEditingController(text: audioItem.name);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.renameAudio),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(labelText: l10n.audioName),
          onSubmitted: (_) {
            final name = controller.text.trim();
            if (name.isNotEmpty) {
              ref
                  .read(audioLibraryProvider.notifier)
                  .updateAudioItem(audioItem.copyWith(name: name));
              Navigator.pop(ctx);
            }
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.cancel),
          ),
          ElevatedButton(
            onPressed: () {
              final name = controller.text.trim();
              if (name.isNotEmpty) {
                ref
                    .read(audioLibraryProvider.notifier)
                    .updateAudioItem(audioItem.copyWith(name: name));
                Navigator.pop(ctx);
              }
            },
            child: Text(l10n.ok),
          ),
        ],
      ),
    );
  }

  void _confirmRemove(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.removeFromCollection),
        content: Text(l10n.removeFromCollectionConfirm(audioItem.name)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () {
              ref
                  .read(collectionListProvider.notifier)
                  .removeAudioFromCollection(collectionId, audioItem.id);
              Navigator.pop(ctx);
            },
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(ctx).colorScheme.error,
            ),
            child: Text(l10n.delete),
          ),
        ],
      ),
    );
  }
}

/// 添加音频到合集对话框 - 复用音频库的上传逻辑
class _AddAudioToCollectionDialog extends ConsumerStatefulWidget {
  final String collectionId;

  const _AddAudioToCollectionDialog({required this.collectionId});

  @override
  ConsumerState<_AddAudioToCollectionDialog> createState() =>
      _AddAudioToCollectionDialogState();
}

class _AddAudioToCollectionDialogState
    extends ConsumerState<_AddAudioToCollectionDialog> {
  String? _audioPath;
  String? _transcriptPath;
  String _audioName = '';
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return AlertDialog(
      title: Text(l10n.addAudioToCollection),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ElevatedButton.icon(
              onPressed: _isLoading ? null : _pickAudioFile,
              icon: const Icon(Icons.audiotrack),
              label: Text(l10n.selectAudioFile),
            ),
            if (_audioPath != null) ...[
              const SizedBox(height: 8),
              Text(
                path.basename(_audioPath!),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _isLoading ? null : _pickTranscriptFile,
              icon: const Icon(Icons.subtitles),
              label: Text(l10n.selectTranscript),
            ),
            if (_transcriptPath != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      path.basename(_transcriptPath!),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 16),
                    onPressed: () {
                      setState(() {
                        _transcriptPath = null;
                      });
                    },
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.pop(context),
          child: Text(l10n.cancel),
        ),
        ElevatedButton(
          onPressed: _audioPath == null || _isLoading ? null : _addAudio,
          child: _isLoading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(l10n.add),
        ),
      ],
    );
  }

  Future<void> _pickAudioFile() async {
    try {
      final FilePickerResult? result;

      if (!kIsWeb && Platform.isIOS) {
        result = await FilePicker.platform.pickFiles(
          type: FileType.custom,
          allowedExtensions: ['mp3', 'wav', 'm4a', 'aac', 'flac'],
        );
      } else {
        final initialDir = !kIsWeb && Platform.isMacOS
            ? await _getDownloadsDirectory()
            : null;
        result = await FilePicker.platform.pickFiles(
          type: FileType.custom,
          allowedExtensions: ['mp3', 'wav', 'm4a', 'aac', 'flac'],
          initialDirectory: initialDir,
        );
      }

      if (result != null && result.files.isNotEmpty) {
        final file = result.files.single;
        final dest = await _savePickedFileToSandbox(file, 'audios');
        if (!mounted) return;
        setState(() {
          _audioPath = dest;
          _audioName = path.basenameWithoutExtension(dest);
        });
      }
    } catch (e) {
      if (mounted) {
        final l10n = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${l10n.pickAudioFileFailed}: $e')),
        );
      }
    }
  }

  Future<void> _pickTranscriptFile() async {
    try {
      final FilePickerResult? result;

      if (!kIsWeb && Platform.isIOS) {
        result = await FilePicker.platform.pickFiles(
          type: FileType.custom,
          allowedExtensions: ['srt', 'lrc', 'txt', 'vtt', 'ass', 'ssa'],
          allowMultiple: false,
        );
      } else {
        final initialDir = !kIsWeb && Platform.isMacOS
            ? await _getDownloadsDirectory()
            : null;
        result = await FilePicker.platform.pickFiles(
          type: FileType.custom,
          allowedExtensions: ['srt', 'lrc', 'txt', 'vtt', 'ass', 'ssa'],
          initialDirectory: initialDir,
          allowMultiple: false,
        );
      }

      if (result != null && result.files.isNotEmpty) {
        final file = result.files.single;
        final dest = await _savePickedFileToSandbox(file, 'transcripts');
        if (!mounted) return;
        setState(() {
          _transcriptPath = dest;
        });
      }
    } catch (e) {
      if (mounted) {
        final l10n = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${l10n.pickTranscriptFileFailed}: $e')),
        );
      }
    }
  }

  Future<String?> _getDownloadsDirectory() async {
    try {
      final home = Platform.environment['HOME'];
      if (home == null) return null;
      return path.join(home, 'Downloads');
    } catch (_) {
      return null;
    }
  }

  /// 保存文件到应用沙盒，返回相对于Documents目录的相对路径
  Future<String> _savePickedFileToSandbox(
    PlatformFile file,
    String subdir,
  ) async {
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory(path.join(docs.path, subdir));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }

    final baseName = file.name.isNotEmpty
        ? file.name
        : (file.path != null ? path.basename(file.path!) : 'file');
    final destPath = path.join(dir.path, baseName);

    // 如果文件已存在，直接返回相对路径
    if (await File(destPath).exists()) {
      return path.join(subdir, baseName);
    }

    // 文件不存在，复制到沙盒
    if (file.path != null) {
      await File(file.path!).copy(destPath);
    } else if (file.bytes != null) {
      await File(destPath).writeAsBytes(file.bytes!);
    } else if (file.readStream != null) {
      final out = File(destPath).openWrite();
      await file.readStream!.pipe(out);
      await out.close();
    } else {
      throw Exception('Unable to access picked file');
    }

    return path.join(subdir, baseName);
  }

  Future<void> _addAudio() async {
    if (_audioPath == null) return;

    final l10n = AppLocalizations.of(context)!;

    // 检查当前合集中是否已存在同名音频
    final collectionState = ref.read(collectionListProvider);
    final collection = collectionState.rawCollections
        .where((c) => c.id == widget.collectionId)
        .firstOrNull;
    if (collection != null) {
      final libraryNotifier = ref.read(audioLibraryProvider.notifier);
      final existingAudioIds = collectionState.getAudioIds(widget.collectionId);
      for (final existingId in existingAudioIds) {
        final existingAudio = libraryNotifier.getItemById(existingId);
        if (existingAudio != null && existingAudio.name == _audioName) {
          // 合集中已存在同名音频，弹出提醒
          if (mounted) {
            showDialog(
              context: context,
              builder: (ctx) => AlertDialog(
                title: Text(l10n.audioAlreadyInCollection),
                content: Text(l10n.audioAlreadyInCollectionMessage(_audioName)),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: Text(l10n.ok),
                  ),
                ],
              ),
            );
          }
          return;
        }
      }
    }

    // 检查是否已存在同名文件
    final library = ref.read(audioLibraryProvider.notifier);
    final libraryState = ref.read(audioLibraryProvider);
    final existingItem = libraryState.audioItems.firstWhere(
      (item) => item.name == _audioName,
      orElse: () =>
          AudioItem(id: '', name: '', audioPath: '', addedDate: DateTime.now()),
    );

    String audioId;

    if (existingItem.id.isNotEmpty) {
      // 音频已存在于音频库中，直接关联到合集
      audioId = existingItem.id;
    } else {
      // 新音频，先添加到音频库
      setState(() {
        _isLoading = true;
      });

      final audioItem = AudioItem(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        name: _audioName,
        audioPath: _audioPath!,
        transcriptPath: _transcriptPath,
        addedDate: DateTime.now(),
      );

      await library.addAudioItem(audioItem);
      audioId = audioItem.id;
    }

    // 添加到合集
    if (mounted) {
      await ref
          .read(collectionListProvider.notifier)
          .addAudioToCollection(widget.collectionId, audioId);
      Navigator.pop(context);
    }
  }
}
