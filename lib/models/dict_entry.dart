/// 词典条目模型
///
/// 由在线词典 API（`/api/v1/dictionary/{dict}`）返回的词条构建。
library;

/// 词典查询结果
class DictEntry {
  /// 单词原文
  final String word;

  /// 音标（IPA 格式），无音标时为空字符串
  final String phonetic;

  /// 中文释义：每个义项一行，行首可带词性缩写（如 `n. 生日`）
  final String? translation;

  /// 柯林斯星级（0 表示无星级，1-5 表示星级）
  final int collins;

  /// 考试标签列表（如 CET4、CET6、TOEFL 等）
  final List<String> examTags;

  const DictEntry({
    required this.word,
    required this.phonetic,
    this.translation,
    this.collins = 0,
    this.examTags = const [],
  });


  /// 从词典 API 词条 JSON 构建。
  ///
  /// 只读取当前展示所需的字段，其余字段（如例句及后端未来新增的字段）一律忽略，
  /// 避免后端扩展结构时客户端解析失败。字段类型不符时取默认值；唯一的硬性要求是
  /// `headword` 与至少一条可用释义，否则抛出 [FormatException]，由调用方决定是否缓存。
  factory DictEntry.fromApiJson(Map<String, Object?> json) {
    final headword = json['headword'];
    if (headword is! String || headword.isEmpty) {
      throw const FormatException('dictionary entry missing headword');
    }

    final lines = _definitionLines(json['definitions']);
    if (lines.isEmpty) {
      throw FormatException('dictionary entry has no translations: $headword');
    }

    final phonetic = json['phonetic'];
    final collins = json['collins'];

    return DictEntry(
      word: headword,
      phonetic: phonetic is String ? phonetic : '',
      translation: lines.join('\n'),
      collins: collins is int ? collins.clamp(0, 5) : 0,
      examTags: _examTags(json['tags']),
    );
  }

  /// 每个义项拼成一行：`pos. 释义1, 释义2`（与原离线词典的释义格式一致）；词性缺失时无前缀。
  static List<String> _definitionLines(Object? definitions) {
    if (definitions is! List<Object?>) return const [];
    final lines = <String>[];
    for (final definition in definitions) {
      if (definition is! Map<String, Object?>) continue;
      final translations = definition['translations'];
      if (translations is! List<Object?>) continue;
      final items = [
        for (final item in translations)
          if (item is String && item.trim().isNotEmpty) item.trim(),
      ];
      if (items.isEmpty) continue;

      final pos = definition['pos'];
      final prefix = pos is String && pos.trim().isNotEmpty
          ? '${pos.trim()}. '
          : '';
      lines.add('$prefix${items.join(', ')}');
    }
    return lines;
  }

  /// 德语版不展示考试标签：上游的 CET4/CET6/TOEFL/IELTS/GRE 是英语考试体系，
  /// 对德语学习者没有意义，所以一律返回空（UI 侧的三处展示会自动跳过）。
  static List<String> _examTags(Object? tags) => const [];
}
