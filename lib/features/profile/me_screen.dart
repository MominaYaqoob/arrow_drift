import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:arrow_drift/core/theme/app_theme.dart';
import 'package:arrow_drift/features/about/about_screen.dart';
import 'package:arrow_drift/features/about/help_center_screen.dart';
import 'package:arrow_drift/features/about/privacy_policy_screen.dart';
import 'package:arrow_drift/features/awards/awards_screen.dart';
import 'package:arrow_drift/features/settings/settings_screen.dart';

/// Profile hub — grouped list (teal accents), light/dark palette aware.
class MeScreen extends ConsumerWidget {
  const MeScreen({super.key});

  static const String routePath = '/profile';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.appColors;

    return Scaffold(
      backgroundColor: colors.background,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
          children: [
            Center(
              child: Text(
                'Me',
                style: AppTextStyles.heading(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: colors.primaryText,
                ),
              ),
            ),
            const SizedBox(height: 20),
            _MeCard(
              children: [
                _MeRow(
                  icon: Icons.emoji_events_rounded,
                  iconBg: const Color(0xFFE8F4FF),
                  iconColor: const Color(0xFFE0B13A),
                  label: 'Awards',
                  onTap: () => context.push(AwardsScreen.routePath),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _MeCard(
              children: [
                _MeRow(
                  icon: Icons.settings_rounded,
                  iconBg: AppColors.accentTeal,
                  iconColor: Colors.white,
                  label: 'Settings',
                  onTap: () => context.push(SettingsScreen.routePath),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _MeCard(
              children: [
                _MeRow(
                  icon: Icons.help_rounded,
                  iconBg: const Color(0xFF34C759),
                  iconColor: Colors.white,
                  label: 'Help',
                  onTap: () => context.push(HelpCenterScreen.routePath),
                  showDivider: true,
                ),
                _MeRow(
                  icon: Icons.info_rounded,
                  iconBg: AppColors.accentTeal,
                  iconColor: Colors.white,
                  label: 'About Game',
                  onTap: () => context.push(AboutScreen.routePath),
                  showDivider: true,
                ),
                _MeRow(
                  icon: Icons.policy_rounded,
                  iconBg: const Color(0xFF5B6CDB),
                  iconColor: Colors.white,
                  label: 'Privacy Rights',
                  onTap: () => context.push(PrivacyPolicyScreen.routePath),
                  showDivider: true,
                ),
                _MeRow(
                  icon: Icons.privacy_tip_rounded,
                  iconBg: AppColors.accentTealDeep,
                  iconColor: Colors.white,
                  label: 'Privacy Preferences',
                  onTap: () => context.push(PrivacyPolicyScreen.routePath),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _MeCard(
              children: [
                _MeRow(
                  icon: Icons.block_rounded,
                  iconBg: AppColors.heartRed,
                  iconColor: Colors.white,
                  label: 'Remove Ads',
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Remove Ads coming soon'),
                        duration: Duration(seconds: 2),
                      ),
                    );
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MeCard extends StatelessWidget {
  const _MeCard({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Material(
      color: colors.surface,
      borderRadius: BorderRadius.circular(14),
      clipBehavior: Clip.antiAlias,
      child: Column(children: children),
    );
  }
}

class _MeRow extends StatelessWidget {
  const _MeRow({
    required this.icon,
    required this.iconBg,
    required this.iconColor,
    required this.label,
    required this.onTap,
    this.showDivider = false,
  });

  final IconData icon;
  final Color iconBg;
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
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: iconBg,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, size: 20, color: iconColor),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    label,
                    style: AppTextStyles.body(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
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
            padding: const EdgeInsets.only(left: 62),
            child: Divider(height: 1, thickness: 0.5, color: colors.border),
          ),
      ],
    );
  }
}
