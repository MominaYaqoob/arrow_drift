import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:arrow_drift/core/constants/app_constants.dart';
import 'package:arrow_drift/core/theme/app_theme.dart';
import 'package:arrow_drift/core/utils/external_links.dart';

class HelpCenterScreen extends StatelessWidget {
  const HelpCenterScreen({super.key});

  static const String routePath = '/help-center';

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: colors.background,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                IconButton(
                  onPressed: () => context.pop(),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                  icon: Icon(
                    Icons.chevron_left_rounded,
                    size: 32,
                    color: colors.primaryText,
                  ),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Help Center',
                          style: AppTextStyles.heading(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            color: colors.primaryText,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Quick answers for Arrow Drift.',
                          style: AppTextStyles.body(
                            fontSize: 13,
                            color: colors.secondaryText,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            _HelpCard(
              isDark: isDark,
              children: const [
                _HelpTopic(
                  icon: Icons.touch_app_rounded,
                  iconBg: Color(0xFF1FA88E),
                  title: 'How to play',
                  body:
                      'Tap an arrow to slide it in the direction of its tip. '
                      'If another arrow blocks the path, clear that blocker first. '
                      'Empty the board to finish the level.',
                  showDivider: true,
                ),
                _HelpTopic(
                  icon: Icons.lightbulb_outline_rounded,
                  iconBg: Color(0xFFC9A227),
                  title: 'Hints & lives',
                  body:
                      'Hints highlight a free arrow. Lives drop when you tap a blocked arrow. '
                      'Watch a short ad to earn an extra hint or life when you run out.',
                  showDivider: true,
                ),
                _HelpTopic(
                  icon: Icons.calendar_month_rounded,
                  iconBg: Color(0xFF1B6B5A),
                  title: 'Daily challenge',
                  body:
                      'Each calendar day has one unique nested puzzle. '
                      'Complete it to keep your streak.',
                ),
              ],
            ),
            const SizedBox(height: 22),
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 8),
              child: Text(
                'SUPPORT',
                style: AppTextStyles.label(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: colors.secondaryText,
                ).copyWith(letterSpacing: 1.1),
              ),
            ),
            _HelpCard(
              isDark: isDark,
              children: [
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: openSupportEmail,
                    borderRadius: BorderRadius.circular(14),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: const Color(0xFF1B6B5A),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(
                              Icons.mail_outline_rounded,
                              color: Colors.white,
                              size: 22,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        'Need more help?',
                                        style: AppTextStyles.body(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w700,
                                          color: colors.primaryText,
                                        ),
                                      ),
                                    ),
                                    Icon(
                                      Icons.open_in_new_rounded,
                                      size: 16,
                                      color: colors.secondaryText,
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Email us and we will get back to you.',
                                  style: AppTextStyles.body(
                                    fontSize: 13,
                                    height: 1.35,
                                    color: colors.secondaryText,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  AppConstants.supportEmail,
                                  style: AppTextStyles.body(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: colors.accentTeal,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _HelpCard extends StatelessWidget {
  const _HelpCard({required this.children, required this.isDark});

  final List<Widget> children;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.border.withValues(alpha: isDark ? 1 : 0.7)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.22 : 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(children: children),
    );
  }
}

class _HelpTopic extends StatelessWidget {
  const _HelpTopic({
    required this.icon,
    required this.iconBg,
    required this.title,
    required this.body,
    this.showDivider = false,
  });

  final IconData icon;
  final Color iconBg;
  final String title;
  final String body;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: iconBg,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: Colors.white, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: AppTextStyles.body(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: colors.primaryText,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      body,
                      style: AppTextStyles.body(
                        fontSize: 13,
                        height: 1.4,
                        color: colors.secondaryText,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        if (showDivider)
          Padding(
            padding: const EdgeInsets.only(left: 68),
            child: Divider(height: 1, thickness: 0.5, color: colors.border),
          ),
      ],
    );
  }
}

class TermsOfServiceScreen extends StatelessWidget {
  const TermsOfServiceScreen({super.key});

  static const String routePath = '/terms-of-service';

  @override
  Widget build(BuildContext context) {
    return const _LegalDocPage(
      title: 'Terms of Service',
      sections: [
        (
          'Agreement',
          'By downloading or using ${AppConstants.appName}, you agree to these Terms. '
              'If you do not agree, please uninstall the app.',
        ),
        (
          'License',
          'We grant you a personal, non-exclusive, non-transferable license to use '
              'the app for entertainment on your own devices.',
        ),
        (
          'Ads & purchases',
          'The app may show advertisements. Optional in-app purchases (such as Remove Ads) '
              'may be offered in future updates and are subject to the store’s refund rules.',
        ),
        (
          'Progress',
          'Campaign progress, settings, and daily streak are stored on your device. '
              'Uninstalling or clearing app data may erase progress.',
        ),
        (
          'Disclaimer',
          'The app is provided “as is” without warranties. We are not liable for lost '
              'progress, device issues, or third-party ad content.',
        ),
        (
          'Contact',
          'Questions: ${AppConstants.supportEmail}',
        ),
      ],
    );
  }
}

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  static const String routePath = '/privacy-policy';

  @override
  Widget build(BuildContext context) {
    // Hosted policy is primary; this screen is a lightweight offline fallback.
    return const _LegalDocPage(
      title: 'Privacy Policy',
      sections: [
        (
          'Summary',
          '${AppConstants.appName} is an offline puzzle game. We do not require an account '
              'and we do not sell your personal information.',
        ),
        (
          'Online policy',
          'For the full Privacy Policy, open the hosted page from About → Privacy Policy.',
        ),
        (
          'Contact',
          'Privacy questions: ${AppConstants.supportEmail}',
        ),
      ],
    );
  }
}

class _LegalDocPage extends StatelessWidget {
  const _LegalDocPage({required this.title, required this.sections});

  final String title;
  final List<(String, String)> sections;

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
      body: ListView.separated(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        itemCount: sections.length,
        separatorBuilder: (_, _) => const SizedBox(height: 18),
        itemBuilder: (context, index) {
          final (heading, body) = sections[index];
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                heading,
                style: AppTextStyles.heading(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: colors.primaryText,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                body,
                style: AppTextStyles.body(
                  fontSize: 14,
                  height: 1.45,
                  color: colors.secondaryText,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
