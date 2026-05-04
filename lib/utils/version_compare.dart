/// 版本号比较工具
///
/// 提供 semver 风格的版本号比较，支持构建号（+N 后缀）：
/// - `1.0.8` → [1, 0, 8, 0]
/// - `1.0.8+2` → [1, 0, 8, 2]
/// - null / "" → [0, 0, 0, 0]
/// - "1.0" → [1, 0, 0, 0]（自动补零）
/// - "1.0.0-beta" → [1, 0, 0, 0]（去除 pre-release 后缀）
/// - "abc" / "1.x.0" → 对应段解析为 0
/// - 任何输入都不抛异常
library;

/// 将版本号字符串解析为整数列表 [major, minor, patch, build]
///
/// 容错处理：去除 v 前缀、去除 pre-release 后缀、自动补零、非法段解析为 0。
/// 构建号（+N 后缀）会被解析为第 4 个元素，无构建号则为 0。
List<int> parseVersion(String? version) {
  if (version == null || version.isEmpty) return [0, 0, 0, 0];

  // 去除 "v" 前缀（如 "v1.0.0"）
  final cleaned = version.startsWith('v') || version.startsWith('V')
      ? version.substring(1)
      : version;

  // 先分离构建号（+ 后缀）
  final buildParts = cleaned.split('+');
  final coreWithPre = buildParts.first;
  final buildNumber = buildParts.length > 1
      ? (int.tryParse(buildParts[1].split('-').first) ?? 0)
      : 0;

  // 去除 pre-release 后缀（- 后缀）
  final core = coreWithPre.split('-').first;

  final parts = core.split('.');
  final result = <int>[];
  for (var i = 0; i < 3; i++) {
    result.add(i < parts.length ? (int.tryParse(parts[i]) ?? 0) : 0);
  }
  result.add(buildNumber);
  return result;
}

/// 比较两个版本号
///
/// 返回值：
/// - 负数：a < b
/// - 0：a == b
/// - 正数：a > b
int compareVersions(String? a, String? b) {
  final va = parseVersion(a);
  final vb = parseVersion(b);
  for (var i = 0; i < 4; i++) {
    if (va[i] != vb[i]) return va[i] - vb[i];
  }
  return 0;
}

/// 判断远程版本是否比本地版本更新
bool isNewerVersion({
  required String? localVersion,
  required String? remoteVersion,
}) {
  return compareVersions(remoteVersion, localVersion) > 0;
}
