import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:arrow_drift/core/theme/app_theme.dart';

class HelpCenterScreen extends StatelessWidget {
  const HelpCenterScreen({super.key});

  static const String routePath = '/help-center';

  @override
  Widget build(BuildContext context) {
    return const _PlaceholderPage(title: 'Help Center');
  }
}

class TermsOfServiceScreen extends StatelessWidget {
  const TermsOfServiceScreen({super.key});

  static const String routePath = '/terms-of-service';

  @override
  Widget build(BuildContext context) {
    return const _PlaceholderPage(title: 'Terms of Service');
  }
}

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  static const String routePath = '/privacy-policy';

  @override
  Widget build(BuildContext context) {
    return const _PlaceholderPage(title: 'Privacy Policy');
  }
}

class _PlaceholderPage extends StatelessWidget {
  const _PlaceholderPage({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        backgroundColor: colors.background,
        elevation: 0,
        leading: IconButton(
          onPressed: () => context.pop(),
          icon: Icon(Icons.chevron_left_rounded, color: colors.primaryText),
        ),
        title: Text(
          title,
          style: AppTextStyles.heading(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: colors.primaryText,
          ),
        ),
      ),
      body: const SizedBox.shrink(),
    );
  }
}
