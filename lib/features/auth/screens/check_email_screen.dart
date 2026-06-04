import 'package:flutter/material.dart';

import 'email_sign_in_screen.dart';

/// 兼容旧验证码路由：真实 UI 已收敛到单页邮箱验证码流程。
class CheckEmailScreen extends StatelessWidget {
  const CheckEmailScreen({super.key, required this.email});

  final String email;

  @override
  Widget build(BuildContext context) {
    return EmailSignInScreen(initialEmail: email, startInOtpStep: true);
  }
}
