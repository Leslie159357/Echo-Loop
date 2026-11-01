/// 内置离线词典资源目录。
///
/// 词典资源随 App 版本发布：更新词典时先上传新的 ZIP，再同步修改此文件中的
/// resourceId、URL 和 SHA-256。运行中的 App 不通过远程 manifest 检查更新。
library;

/// 单个离线词典 ZIP 资源规格，归档路径相对于运行时选择的 CDN 基地址。
class DictionarySpec {
  const DictionarySpec({
    required this.nativeLanguage,
    required this.resourceId,
    required this.archivePath,
    required this.archiveSha256,
    required this.estimatedDownloadBytes,
  });

  final String nativeLanguage;
  final String resourceId;
  final String archivePath;
  final String archiveSha256;

  /// CDN 压缩包的预计下载大小（字节），用于展示或后续下载策略。
  final int estimatedDownloadBytes;
}

/// 当前发布的离线词典资源。
const dictionarySpecs = <String, DictionarySpec>{
  'zh-CN': DictionarySpec(
    nativeLanguage: 'zh-CN',
    resourceId: 'dict-de_zh-CN-v1',
    archivePath: 'dictionary/en_zh-CN/dict_en_zh-CN-v1.sqlite.zip',
    archiveSha256:
        'ef7c206a86edd6354682669e5a5185f42835b0e12aaced62c548a519fcae2f51',
    estimatedDownloadBytes: 8316707,
  ),
  'zh-TW': DictionarySpec(
    nativeLanguage: 'zh-TW',
    resourceId: 'dict-de_zh-CN-v1',
    archivePath: 'dictionary/en_zh-CN/dict_en_zh-CN-v1.sqlite.zip',
    archiveSha256:
        'ef7c206a86edd6354682669e5a5185f42835b0e12aaced62c548a519fcae2f51',
    estimatedDownloadBytes: 8316707,
  ),
};

/// 返回指定母语的内置词典规格。
DictionarySpec dictionarySpecOf(String nativeLanguage) {
  final spec = dictionarySpecs[nativeLanguage];
  if (spec == null) {
    throw ArgumentError.value(nativeLanguage, 'nativeLanguage');
  }
  return spec;
}
