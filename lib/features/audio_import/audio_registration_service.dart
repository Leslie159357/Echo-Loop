import 'package:uuid/uuid.dart';

import '../../models/audio_item.dart';
import '../../providers/audio_library_provider.dart';
import '../../providers/collection_provider.dart';
import '../../utils/audio_duration.dart';

/// 已在应用沙盒内的音频注册服务。
///
/// 本地导入和链接下载只负责把音频文件放入沙盒；创建 [AudioItem]、写入音频库、
/// 关联合集和重复处理统一从这里进入，避免不同来源绕过数据库入库流程。
class AudioRegistrationService {
  AudioRegistrationService({
    Uuid? uuid,
    Future<int> Function(String relativePath)? readDurationSeconds,
  }) : _uuid = uuid ?? const Uuid(),
       _readDurationSeconds = readDurationSeconds ?? getAudioDurationSeconds;

  final Uuid _uuid;
  final Future<int> Function(String relativePath) _readDurationSeconds;

  Future<AudioRegistrationResult> registerSandboxedAudio({
    required SandboxedAudioRegistrationInput input,
    required AudioLibrary audioLibrary,
    required AudioLibraryState audioLibraryState,
    CollectionList? collectionList,
    CollectionState? collectionState,
    String? collectionId,
  }) async {
    if (input.audioSha256 == null) {
      final existingResult = await registerExistingAudioByName(
        name: input.name,
        audioLibraryState: audioLibraryState,
        collectionList: collectionList,
        collectionState: collectionState,
        collectionId: collectionId,
      );
      if (existingResult != null) return existingResult;
    }

    final duration = await _readDurationSeconds(input.relativePath);
    final audioItem = AudioItem(
      id: _uuid.v4(),
      name: input.name,
      audioPath: input.relativePath,
      addedDate: DateTime.now(),
      totalDuration: duration,
      audioSha256: input.audioSha256,
      originalAudioSha256: input.originalAudioSha256,
      importSourceType: input.importSourceType,
      importSourceUrl: input.importSourceUrl,
    );

    await audioLibrary.addAudioItem(audioItem);
    if (collectionId != null) {
      await collectionList?.addAudioToCollection(collectionId, audioItem.id);
    }
    return AudioRegistrationAdded(audioItem);
  }

  /// 如果库中已有同名音频，按统一规则处理重复或合集关联。
  ///
  /// 返回 `null` 表示没有同名音频，调用方可以继续复制或下载新文件。
  Future<AudioRegistrationResult?> registerExistingAudioByName({
    required String name,
    required AudioLibraryState audioLibraryState,
    CollectionList? collectionList,
    CollectionState? collectionState,
    String? collectionId,
  }) async {
    final existingItem = _findExistingByName(
      audioLibraryState.audioItems,
      name,
    );
    if (existingItem == null) return null;

    if (collectionId == null) {
      return AudioRegistrationDuplicate(name);
    }

    final audioIds = collectionState?.getAudioIds(collectionId) ?? const [];
    if (audioIds.contains(existingItem.id)) {
      return AudioRegistrationDuplicate(name);
    }

    await collectionList?.addAudioToCollection(collectionId, existingItem.id);
    return AudioRegistrationAdded(existingItem);
  }

  AudioItem? _findExistingByName(List<AudioItem> items, String name) {
    for (final item in items) {
      if (item.name == name) return item;
    }
    return null;
  }
}

class SandboxedAudioRegistrationInput {
  const SandboxedAudioRegistrationInput({
    required this.name,
    required this.relativePath,
    required this.importSourceType,
    this.audioSha256,
    this.importSourceUrl,
    this.originalAudioSha256,
  });

  final String name;
  final String relativePath;
  final AudioImportSourceType importSourceType;
  final String? audioSha256;
  final String? importSourceUrl;
  final String? originalAudioSha256;
}

sealed class AudioRegistrationResult {
  const AudioRegistrationResult();
}

class AudioRegistrationAdded extends AudioRegistrationResult {
  const AudioRegistrationAdded(this.item);

  final AudioItem item;
}

class AudioRegistrationDuplicate extends AudioRegistrationResult {
  const AudioRegistrationDuplicate(this.name);

  final String name;
}
