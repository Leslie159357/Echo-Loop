/// 本地词典查询服务
///
/// 基于 SQLite 的离线词典，从 assets 中加载 dict.db，
/// 首次使用时复制到应用文档目录，后续直接打开查询。
library;

import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:lemmatizerx/lemmatizerx.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqlite3/sqlite3.dart';

import '../models/dict_entry.dart';

/// 词典服务单例
class DictionaryService {
  DictionaryService._()
    : _prefsOverride = null,
      _appDirProvider = null,
      _assetBytesLoader = null,
      _onDictionaryInstalled = null;

  /// 测试用构造器，允许注入已打开的数据库
  @visibleForTesting
  DictionaryService.withDatabase(Database db)
    : _db = db,
      _prefsOverride = null,
      _appDirProvider = null,
      _assetBytesLoader = null,
      _onDictionaryInstalled = null;

  /// 测试用构造器，允许注入词典 asset、目录和偏好存储。
  @visibleForTesting
  DictionaryService.withEnvironment({
    SharedPreferences? prefs,
    Future<Directory> Function()? appDirProvider,
    Future<Uint8List> Function()? assetBytesLoader,
    void Function()? onDictionaryInstalled,
  }) : _prefsOverride = prefs,
       _appDirProvider = appDirProvider,
       _assetBytesLoader = assetBytesLoader,
       _onDictionaryInstalled = onDictionaryInstalled;

  static DictionaryService _instance = DictionaryService._();
  static const String _dictAssetPath = 'assets/dict/dict.db';
  static const String _dictAssetShaKey = 'dictionary_asset_sha256';

  /// 全局单例
  static DictionaryService get instance => _instance;

  /// 测试用：替换全局单例，返回旧实例以便恢复
  @visibleForTesting
  static DictionaryService replaceInstance(DictionaryService service) {
    final old = _instance;
    _instance = service;
    return old;
  }

  Database? _db;
  final Lemmatizer _lemmatizer = Lemmatizer();
  final SharedPreferences? _prefsOverride;
  final Future<Directory> Function()? _appDirProvider;
  final Future<Uint8List> Function()? _assetBytesLoader;
  final void Function()? _onDictionaryInstalled;

  static final RegExp _edgePunctuationPattern = RegExp(
    r'^[^A-Za-z0-9]+|[^A-Za-z0-9]+$',
  );

  /// 确保数据库已初始化
  Future<void> _ensureInitialized() async {
    if (_db != null) return;

    final appDir = _appDirProvider != null
        ? await _appDirProvider()
        : await getApplicationSupportDirectory();
    final dbPath = p.join(appDir.path, 'dict.db');
    final dbFile = File(dbPath);
    final prefs = await _getPrefs();
    final assetBytes = await _loadAssetBytes();
    final assetSha = sha256.convert(assetBytes).toString();
    final installedSha = prefs.getString(_dictAssetShaKey);

    // 首次安装或 asset 发生变化时，覆盖本地词典。
    // 这样用户升级应用后会自动拿到新版词库，不会一直卡在旧缓存。
    final shouldInstall = !dbFile.existsSync() || installedSha != assetSha;
    if (shouldInstall) {
      await _installDictionaryFile(
        dbFile: dbFile,
        assetBytes: assetBytes,
        assetSha: assetSha,
        prefs: prefs,
      );
    }

    _db = sqlite3.open(dbPath, mode: OpenMode.readOnly);
  }

  Future<SharedPreferences> _getPrefs() async {
    return _prefsOverride ?? SharedPreferences.getInstance();
  }

  Future<Uint8List> _loadAssetBytes() async {
    if (_assetBytesLoader != null) {
      return _assetBytesLoader();
    }
    final data = await rootBundle.load(_dictAssetPath);
    return data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
  }

  Future<void> _installDictionaryFile({
    required File dbFile,
    required Uint8List assetBytes,
    required String assetSha,
    required SharedPreferences prefs,
  }) async {
    final tempFile = File('${dbFile.path}.tmp');
    final hadExistingFile = dbFile.existsSync();

    try {
      await tempFile.writeAsBytes(assetBytes, flush: true);
      if (hadExistingFile) {
        await dbFile.delete();
      }
      await tempFile.rename(dbFile.path);
      await prefs.setString(_dictAssetShaKey, assetSha);
      _onDictionaryInstalled?.call();
    } catch (error) {
      if (tempFile.existsSync()) {
        await tempFile.delete();
      }
      if (!hadExistingFile) {
        rethrow;
      }
      debugPrint('Dictionary asset upgrade skipped: $error');
    }
  }

  /// 查询单词，返回词典条目；未找到返回 null
  ///
  /// 精确匹配失败时，自动通过词形还原（lemmatization）尝试查找原形。
  Future<DictEntry?> lookup(String word) async {
    await _ensureInitialized();

    final lower = _normalizeLookupWord(word);
    if (lower.isEmpty) return null;

    // 精确匹配
    final exact = _queryWord(lower);
    if (exact != null) return exact;

    // 词形还原 fallback：获取所有可能的原形，逐个查询
    final lemmas = _lemmatizer.lemmas(lower);
    for (final lemma in lemmas) {
      for (final form in lemma.lemmas) {
        if (form == lower) continue; // 跳过与原词相同的形式
        final result = _queryWord(form);
        if (result != null) return result;
      }
    }

    return null;
  }

  String _normalizeLookupWord(String word) {
    return word.trim().replaceAll(_edgePunctuationPattern, '').toLowerCase();
  }

  /// 直接查询数据库
  DictEntry? _queryWord(String word) {
    final result = _db!.select(
      'SELECT word, phonetic, translation, collins, tag FROM words WHERE word = ? COLLATE NOCASE',
      [word],
    );

    if (result.isEmpty) return null;

    final row = result.first;
    return DictEntry.fromRow(
      word: row['word'] as String,
      phonetic: row['phonetic'] as String,
      translation: row['translation'] as String?,
      collins: (row['collins'] as int?) ?? 0,
      tag: row['tag'] as String?,
    );
  }

  /// 释放资源
  void dispose() {
    _db?.dispose();
    _db = null;
  }
}
