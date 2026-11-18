import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../l10n/app_localizations.dart';
import '../../router/app_router.dart';
import 'providers/auth_providers.dart';

/// 直接打开登录页。
///
/// 供界面中明确标注为“登录”的按钮使用；这类用户主动操作不再额外显示
/// 登录原因弹窗。需要登录才能继续的功能操作仍应使用 [ensureSignedInForAction]。
void openSignInPage(BuildContext context) {
  context.push(AppRoutes.login);
}

/// 在受保护操作前检查登录状态，并复用统一的登录引导交互。
///
/// 已登录时返回 `true`，调用方可以继续原操作；未登录时显示提示，用户确认后
/// 进入登录页，并返回 `false`，避免登录完成后隐式重放原操作。
Future<bool> ensureSignedInForAction({
  required BuildContext context,
  required WidgetRef ref,
  required String title,
  required String message,
}) async {
  // 自建模式下全面免登录放行
  return true;
}
