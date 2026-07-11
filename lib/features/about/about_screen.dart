import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:arrow_drift/core/constants/app_constants.dart';
import 'package:arrow_drift/core/theme/app_theme.dart';
import 'package:arrow_drift/core/widgets/app_logo.dart';
import 'package:arrow_drift/features/about/help_center_screen.dart';
import 'package:arrow_drift/features/about/privacy_policy_screen.dart';
import 'package:arrow_drift/features/about/terms_of_service_screen.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  static const String routePath = '/about';

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
          'About',
          style: AppTextStyles.heading(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: colors.primaryText,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        children: [
          const Center(child: AppLogoMark(size: 72)),
          const SizedBox(height: 16),
          Text(
            AppConstants.appName,
            textAlign: TextAlign.center,
            style: AppTextStyles.heading(
              fontSize: 26,
              fontWeight: FontWeight.w700,
              color: colors.primaryText,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Version 1.0.0 · MVP',
            textAlign: TextAlign.center,
            style: AppTextStyles.body(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: colors.secondaryText,
            ),
          ),
          const SizedBox(height: 28),
          _NavRow(
            label: 'Help Center',
            onTap: () => context.push(HelpCenterScreen.routePath),
          ),
          _NavRow(
            label: 'Terms of Service',
            onTap: () => context.push(TermsOfServiceScreen.routePath),
          ),
          _NavRow(
            label: 'Privacy Policy',
            onTap: () => context.push(PrivacyPolicyScreen.routePath),
          ),
        ],
      ),
    );
  }
}

class _NavRow extends StatelessWidget {
  const _NavRow({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: colors.surface,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: colors.border, width: 0.5),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    label,
                    style: AppTextStyles.body(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: colors.primaryText,
                    ),
                  ),
                ),
                Icon(Icons.chevron_right_rounded, color: colors.secondaryText),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
