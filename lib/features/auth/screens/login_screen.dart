import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../l10n/app_localizations.dart';
import '../../../router/app_router.dart';
import '../../../theme/app_theme.dart';
import '../auth_form_utils.dart';

class LoginScreen extends ConsumerWidget {
  const LoginScreen({super.key});

  void _showComingSoon(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(l10n.authProviderComingSoon)));
  }

  Future<void> _openPolicy(String path) async {
    await launchUrl(Uri.parse('https://www.echo-loop.top$path'));
  }

  void _goBack(BuildContext context) {
    if (context.canPop()) {
      context.pop();
      return;
    }
    context.go(AppRoutes.settings);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;

    return AuthScaffold(
      title: l10n.authSignInTitle,
      showPolicyNotice: true,
      onTermsTap: () => _openPolicy('/terms'),
      onPrivacyTap: () => _openPolicy('/privacy'),
      onBack: () => _goBack(context),
      topGap: 44,
      headerGap: 56,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _AuthMethodButton(
            icon: Icon(Icons.apple, size: 22, color: colorScheme.onSurface),
            label: l10n.authContinueWithApple,
            onPressed: () => _showComingSoon(context),
          ),
          const SizedBox(height: AppSpacing.m),
          _AuthMethodButton(
            icon: FaIcon(
              FontAwesomeIcons.google,
              size: 22,
              color: colorScheme.onSurface,
            ),
            label: l10n.authContinueWithGoogle,
            onPressed: () => _showComingSoon(context),
          ),
          const SizedBox(height: AppSpacing.m),
          _AuthMethodButton(
            icon: Icon(
              Icons.mail_outline_rounded,
              size: 22,
              color: colorScheme.onSurface,
            ),
            label: l10n.authContinueWithEmail,
            onPressed: () => context.push(AppRoutes.emailSignIn),
          ),
        ],
      ),
    );
  }
}

class _AuthMethodButton extends StatelessWidget {
  const _AuthMethodButton({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final Widget icon;
  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        alignment: Alignment.center,
        foregroundColor: colorScheme.onSurface,
        side: BorderSide(color: colorScheme.outlineVariant),
        backgroundColor: colorScheme.surface.withValues(alpha: 0.88),
        minimumSize: const Size.fromHeight(58),
        padding: const EdgeInsets.symmetric(horizontal: 20),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          const Positioned.fill(child: SizedBox()),
          Align(
            alignment: Alignment.centerLeft,
            child: SizedBox(width: 24, child: Center(child: icon)),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              label,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
                letterSpacing: 0,
              ),
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
