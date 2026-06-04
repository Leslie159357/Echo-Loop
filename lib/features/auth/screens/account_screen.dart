import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../l10n/app_localizations.dart';
import '../../../router/app_router.dart';
import '../../../theme/app_theme.dart';
import '../providers/auth_providers.dart';

class AccountScreen extends ConsumerStatefulWidget {
  const AccountScreen({super.key, this.onSignOut});

  final Future<void> Function()? onSignOut;

  @override
  ConsumerState<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends ConsumerState<AccountScreen> {
  bool _isSigningOut = false;

  /// 账号页只服务已登录用户；一旦 session 消失，下一帧立即回到设置页，
  /// 避免退出登录过程中短暂渲染 `/account` 的已登出占位卡片。
  void _redirectToSettingsIfSignedOut() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.go(AppRoutes.settings);
    });
  }

  Future<void> _signOut() async {
    if (_isSigningOut) return;

    setState(() => _isSigningOut = true);
    try {
      final action = widget.onSignOut;
      if (action != null) {
        await action();
      } else {
        await ref.read(authControllerProvider).signOut();
      }
      if (!mounted) return;
      context.go(AppRoutes.settings);
    } finally {
      if (mounted) {
        setState(() => _isSigningOut = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final session = ref.watch(supabaseSessionProvider).valueOrNull;
    final user = session?.user;

    if (user == null) {
      _redirectToSettingsIfSignedOut();
      return const Scaffold(body: SizedBox.shrink());
    }

    return Scaffold(
      appBar: AppBar(title: Text(l10n.account)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.m),
          children: [
            _SignedInAccountCard(
              email: user.email ?? user.id,
              isSigningOut: _isSigningOut,
              onSignOut: _signOut,
            ),
          ],
        ),
      ),
    );
  }
}

class _SignedInAccountCard extends StatelessWidget {
  const _SignedInAccountCard({
    required this.email,
    required this.isSigningOut,
    required this.onSignOut,
  });

  final String email;
  final bool isSigningOut;
  final Future<void> Function() onSignOut;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Card(
      child: Column(
        children: [
          ListTile(
            leading: const Icon(Icons.account_circle_outlined),
            title: Text(email),
            subtitle: Text(l10n.account),
          ),
          const Divider(height: 1),
          ListTile(
            leading: isSigningOut
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.logout),
            title: Text(l10n.authSignOut),
            enabled: !isSigningOut,
            onTap: isSigningOut ? null : onSignOut,
          ),
        ],
      ),
    );
  }
}
