/// 按当前地区选择社区合集媒体资源地址。
///
/// 中国镜像只由服务端在对象已同步时返回；缺少镜像时继续使用全球地址。
String? communityAssetUrlForRegion({
  required String? globalUrl,
  required String? chinaUrl,
  required bool isChinaUser,
}) {
  final normalizedChinaUrl = chinaUrl?.trim();
  if (isChinaUser &&
      normalizedChinaUrl != null &&
      normalizedChinaUrl.isNotEmpty) {
    return normalizedChinaUrl;
  }
  return globalUrl;
}
