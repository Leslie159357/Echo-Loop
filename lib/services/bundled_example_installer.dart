import 'dart:io';

import 'package:drift/drift.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import '../utils/app_data_dir.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../database/app_database.dart';

/// 内置示例内容安装器
///
/// 首次启动时将 assets/demo/ 中的示例音频复制到 Documents 目录，
/// 并在数据库中创建 "Examples" 合集和对应的音频条目（无字幕，引导用户生成）。
/// 通过 SharedPreferences 标记确保只执行一次。
class BundledExampleInstaller {
  static const _installedKey = 'bundled_example_installed';

  /// 固定 ID（保证幂等）
  static const _audioId = 'bundled-example-audio-0001';
  static const _collectionId = 'bundled-example-collection-0001';

  /// assets 中的文件名
  static const _audioAsset =
      'assets/demo/English in a Minute - On the Ball.m4a';

  /// Documents 中的目标相对路径
  static const _audioRelPath = 'audios/English in a Minute - On the Ball.m4a';

  final AppDatabase db;
  final SharedPreferences prefs;

  BundledExampleInstaller(this.db, this.prefs);

  /// 首次启动时安装示例内容，已安装则跳过。
  Future<void> installOnFirstLaunch() async {
    if (prefs.getBool(_installedKey) == true) return;

    // 如果数据库已有数据（非全新安装），标记完成并跳过
    final existing = await (db.select(db.audioItems)..limit(1)).get();
    if (existing.isNotEmpty) {
      await prefs.setBool(_installedKey, true);
      return;
    }

    await _copyAssetFiles();
    await _insertDatabaseRecords();
    await prefs.setBool(_installedKey, true);
  }

  /// 将 asset 文件复制到应用数据目录
  Future<void> _copyAssetFiles() async {
    final docsDir = await getAppDataDirectory();
    final audiosDir = Directory(p.join(docsDir.path, 'audios'));
    if (!audiosDir.existsSync()) {
      await audiosDir.create(recursive: true);
    }

    // 仅复制音频文件，字幕由用户通过 AI 转录生成
    final audioData = await rootBundle.load(_audioAsset);
    final audioFile = File(p.join(docsDir.path, _audioRelPath));
    await audioFile.writeAsBytes(audioData.buffer.asUint8List(), flush: true);
  }

  /// 在数据库中创建合集和音频条目
  Future<void> _insertDatabaseRecords() async {
    final now = DateTime.now();

    await db.transaction(() async {
      // 创建 "Examples" 合集
      await db
          .into(db.collections)
          .insert(
            CollectionsCompanion.insert(
              id: _collectionId,
              name: 'Examples',
              createdDate: now,
              updatedAt: now,
            ),
          );

      // 创建音频条目（无字幕，引导用户通过 AI 转录生成）
      await db
          .into(db.audioItems)
          .insert(
            AudioItemsCompanion.insert(
              id: _audioId,
              name: 'English in a Minute - On the Ball',
              audioPath: _audioRelPath,
              addedDate: now,
              updatedAt: now,
            ),
          );

      // 关联音频到合集
      await db
          .into(db.collectionAudioItems)
          .insert(
            CollectionAudioItemsCompanion.insert(
              collectionId: _collectionId,
              audioItemId: _audioId,
              sortOrder: const Value(0),
              addedAt: now,
            ),
          );
    });
  }
}
