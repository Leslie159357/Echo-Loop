/// 文本归一化工具
///
/// 提供缓存键生成所需的文本归一化和哈希功能。
/// 用于 AI 翻译/解析的三级缓存（内存 → SQLite → API）查找。
library;

import 'dart:convert';

import 'package:crypto/crypto.dart';

/// 归一化文本，用于缓存键匹配
///
/// 处理步骤：去首尾空白 → 转小写 → 合并连续空白。
/// 确保同一句话的不同格式变体映射到同一缓存键。
String normalizeForCache(String text) {
  return text.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
}

/// 生成文本的 SHA-256 哈希值
///
/// 先归一化文本，再计算哈希。返回 64 字符十六进制字符串。
String hashText(String text) {
  final normalized = normalizeForCache(text);
  return sha256.convert(utf8.encode(normalized)).toString();
}
