/// 意群拆分结果模型
///
/// 存储 AI 返回的意群列表，每个意群包含英文文本和核心意群标记。
/// 用于精听标注模式中的意群色块渲染。
library;

/// 意群拆分结果
class SenseGroupResult {
  /// 意群列表
  final List<SenseGroup> groups;

  const SenseGroupResult({required this.groups});

  /// 从 API 响应 JSON 反序列化
  factory SenseGroupResult.fromJson(Map<String, dynamic> json) {
    final groupsList = (json['groups'] as List)
        .map((g) => SenseGroup.fromJson(g as Map<String, dynamic>))
        .toList();
    return SenseGroupResult(groups: groupsList);
  }
}

/// 单个意群
class SenseGroup {
  /// 意群英文文本
  final String text;

  /// 是否为核心意群（承载句子核心语义）
  final bool isCore;

  const SenseGroup({required this.text, this.isCore = false});

  /// 从 JSON 反序列化
  factory SenseGroup.fromJson(Map<String, dynamic> json) {
    return SenseGroup(
      text: json['text'] as String,
      isCore: json['isCore'] as bool? ?? false,
    );
  }

  /// 序列化为 JSON
  Map<String, dynamic> toJson() => {'text': text, 'isCore': isCore};
}
