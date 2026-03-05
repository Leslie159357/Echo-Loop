// 添加音频对话框
//
// 支持两种模式：
// - 有 collectionId：添加音频后自动关联到指定合集
// - 无 collectionId：显示合集下拉框，可选择归入合集
//
// 添加成功后弹出字幕确认对话框，返回 AudioItem 表示用户选择添加字幕。
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:universal_io/io.dart';
import 'package:path_provider/path_provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as path;
import '../models/audio_item.dart';
import '../providers/collection_provider.dart';
import '../providers/audio_library_provider.dart';
import '../l10n/app_localizations.dart';
import '../utils/audio_duration.dart';

/// 添加音频对话框 — collectionId 可选
///
///
/// 返回值：
/// - `AudioItem` — 用户选择"添加字幕"
/// - `null` — 取消或选择"不需要"
class AddAudioDialog extends ConsumerStatefulWidget {
  /// 合集 ID（为 null 时显示合集下拉框）
  final String? collectionId;

  const AddAudioDialog({super.key, this.collectionId});

  @override
  ConsumerState<AddAudioDialog> createState() => _AddAudioDialogState();
}

class _AddAudioDialogState extends ConsumerState<AddAudioDialog> {
  String? _audioPath;
  String _audioName = '';
  bool _isLoading = false;

  /// 用户选择的合集 ID（仅 collectionId == null 时使用）
  String? _selectedCollectionId;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return AlertDialog(
      title: Text(
        widget.collectionId != null ? l10n.addAudioToCollection : l10n.addAudio,
      ),
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
            // 无 collectionId 时显示合集下拉框
            if (widget.collectionId == null) ...[
              const SizedBox(height: 16),
              _buildCollectionDropdown(l10n),
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

  /// 构建合集下拉选择框
  Widget _buildCollectionDropdown(AppLocalizations l10n) {
    final collections =
        ref.watch(collectionListProvider).rawCollections;
    return DropdownButtonFormField<String?>(
      value: _selectedCollectionId,
      decoration: InputDecoration(
        labelText: l10n.selectCollection,
        isDense: true,
      ),
      items: [
        DropdownMenuItem<String?>(
          value: null,
          child: Text(l10n.noCollection),
        ),
        ...collections.map(
          (c) => DropdownMenuItem<String?>(
            value: c.id,
            child: Text(c.name),
          ),
        ),
      ],
      onChanged: _isLoading
          ? null
          : (value) => setState(() => _selectedCollectionId = value),
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

  Future<String?> _getDownloadsDirectory() async {
    try {
      final home = Platform.environment['HOME'];
      if (home == null) return null;
      return path.join(home, 'Downloads');
    } catch (_) {
      return null;
    }
  }

  /// 保存文件到应用沙盒，返回相对于 Documents 目录的相对路径
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
    // 确定最终使用的合集 ID（外部传入优先，否则使用下拉框选择）
    final collectionId = widget.collectionId ?? _selectedCollectionId;

    // 有合集时检查合集中是否已存在同名音频
    if (collectionId != null) {
      final collectionState = ref.read(collectionListProvider);
      final collection = collectionState.rawCollections
          .where((c) => c.id == collectionId)
          .firstOrNull;
      if (collection != null) {
        final libraryNotifier = ref.read(audioLibraryProvider.notifier);
        final existingAudioIds = collectionState.getAudioIds(collectionId);
        for (final existingId in existingAudioIds) {
          final existingAudio = libraryNotifier.getItemById(existingId);
          if (existingAudio != null && existingAudio.name == _audioName) {
            if (mounted) {
              showDialog(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: Text(l10n.audioAlreadyInCollection),
                  content: Text(
                    l10n.audioAlreadyInCollectionMessage(_audioName),
                  ),
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
    }

    // 检查音频库中是否已存在同名音频
    final library = ref.read(audioLibraryProvider.notifier);
    final libraryState = ref.read(audioLibraryProvider);
    final existingItem = libraryState.audioItems
        .where((item) => item.name == _audioName)
        .firstOrNull;

    String audioId;
    AudioItem resultItem;

    if (existingItem != null) {
      if (collectionId != null) {
        // 有合集：音频已存在于库中，直接关联
        audioId = existingItem.id;
        resultItem = existingItem;
      } else {
        // 无合集：提示重复，拒绝上传
        if (mounted) {
          showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              title: Text(l10n.audioAlreadyInLibrary),
              content: Text(l10n.audioAlreadyInLibraryMessage(_audioName)),
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
    } else {
      // 新音频，先添加到音频库
      setState(() {
        _isLoading = true;
      });

      final duration = await getAudioDurationSeconds(_audioPath!);

      final audioItem = AudioItem(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        name: _audioName,
        audioPath: _audioPath!,
        addedDate: DateTime.now(),
        totalDuration: duration,
      );

      await library.addAudioItem(audioItem);
      audioId = audioItem.id;
      resultItem = audioItem;
    }

    // 有合集时关联到合集
    if (collectionId != null && mounted) {
      await ref
          .read(collectionListProvider.notifier)
          .addAudioToCollection(collectionId, audioId);
    }

    if (mounted) {
      Navigator.pop(context, resultItem);
    }
  }
}
