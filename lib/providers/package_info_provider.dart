/// PackageInfo Provider
///
/// 在 main.dart 中通过 ProviderScope.overrides 注入实例，
/// 与 appDatabaseProvider 模式一致。
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// PackageInfo Provider
/// 在 main.dart 中通过 ProviderScope override 注入实例
final packageInfoProvider = Provider<PackageInfo>((ref) {
  throw UnimplementedError('packageInfoProvider 必须在 ProviderScope 中 override');
});
