import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'package:arrow_drift/core/constants/app_constants.dart';
import 'package:arrow_drift/core/theme/app_theme.dart';
import 'package:arrow_drift/core/utils/external_links.dart';
import 'package:arrow_drift/core/widgets/app_logo.dart';
import 'package:arrow_drift/features/about/help_center_screen.dart';
import 'package:arrow_drift/features/about/terms_of_service_screen.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  static const String routePath = '/about';

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        backgroundColor: colors.background,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        centerTitle: true,
        leading: IconButton(
          onPressed: () => context.pop(),
          icon: Icon(
            Icons.chevron_left_rounded,
            size: 32,
            color: colors.primaryText,
          ),
        ),
        title: Text(
          'About',
          style: AppTextStyles.body(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: colors.primaryText,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(20, 28, 20, 24),
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: colors.border.withValues(alpha: isDark ? 1 : 0.7),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.22 : 0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Column(
              children: [
                const AppLogoMark(size: 72),
                const SizedBox(height: 16),
                Text(
                  AppConstants.appDisplayName,
                  textAlign: TextAlign.center,
                  style: AppTextStyles.heading(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: colors.primaryText,
                  ),
                ),
                const SizedBox(height: 8),
                FutureBuilder<PackageInfo>(
                  future: PackageInfo.fromPlatform(),
                  builder: (context, snapshot) {
                    final version = snapshot.data?.version ?? '1.0.2';
                    final build = snapshot.data?.buildNumber ?? '3';
                    return Text(
                      'Version $version ($build)',
                      textAlign: TextAlign.center,
                      style: AppTextStyles.body(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: colors.secondaryText,
                      ),
                    );
                  },
                ),
                const SizedBox(height: 12),
                Text(
                  'A nested arrow puzzle — clear the board one free arrow at a time.',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.body(
                    fontSize: 13,
                    height: 1.4,
                    color: colors.secondaryText,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 8),
            child: Text(
              'INFO',
              style: AppTextStyles.label(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: colors.secondaryText,
              ).copyWith(letterSpacing: 1.1),
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: colors.border.withValues(alpha: isDark ? 1 : 0.7),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.22 : 0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                _InfoRow(
                  icon: Icons.help_outline_rounded,
                  iconColor: const Color(0xFF2EC4A6),
                  label: 'Help Center',
                  onTap: () => context.push(HelpCenterScreen.routePath),
                  showDivider: true,
                ),
                _InfoRow(
                  icon: Icons.description_outlined,
                  iconColor: const Color(0xFFE0B13A),
                  label: 'Terms of Service',
                  onTap: () => context.push(TermsOfServiceScreen.routePath),
                  showDivider: true,
                ),
                _InfoRow(
                  icon: Icons.shield_outlined,
                  iconColor: const Color(0xFFE57373),
                  label: 'Privacy Policy',
                  onTap: openPrivacyPolicyUrl,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.onTap,
    this.showDivider = false,
  });

  final IconData icon;
  final Color iconColor;
  final String label;
  final VoidCallback onTap;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Column(
      children: [
        InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            child: Row(
              children: [
                Icon(icon, size: 24, color: iconColor),
                const SizedBox(width: 14),
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
                Icon(
                  Icons.chevron_right_rounded,
                  color: colors.secondaryText,
                  size: 22,
                ),
              ],
            ),
          ),
        ),
        if (showDivider)
          Padding(
            padding: const EdgeInsets.only(left: 52),
            child: Divider(height: 1, thickness: 0.5, color: colors.border),
          ),
      ],
    );
  }
}
