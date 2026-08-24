import 'dart:async';

import 'package:flutter/foundation.dart' show debugPrint, kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import 'package:arrow_drift/core/services/app_feedback.dart';
import 'package:arrow_drift/core/theme/app_theme.dart';
import 'package:arrow_drift/data/repositories/settings_repository.dart';
import 'package:arrow_drift/services/ads_service.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  static const String routePath = '/settings';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.appColors;
    final settingsAsync = ref.watch(settingsProvider);

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        backgroundColor: colors.background,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          onPressed: () => context.pop(),
          icon: Icon(
            Icons.chevron_left_rounded,
            color: colors.primaryText,
            size: 32,
          ),
        ),
        title: Text(
          'Settings',
          style: AppTextStyles.body(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: colors.primaryText,
          ),
        ),
      ),
      body: settingsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('$error')),
        data: (settings) {
          final notifier = ref.read(settingsProvider.notifier);
          final themeMode = ref.watch(themeModeProvider);
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            children: [
              const _SectionLabel('PREFERENCES'),
              _SettingsCard(
                children: [
                  _ToggleRow(
                    icon: Icons.volume_up_rounded,
                    iconColor: colors.accentTeal,
                    label: 'Sounds',
                    value: settings.sounds,
                    onChanged: (v) async {
                      await notifier.setSounds(v);
                      if (v) AppFeedback.previewSound();
                    },
                    showDivider: true,
                  ),
                  _ToggleRow(
                    icon: Icons.vibration_rounded,
                    iconColor: colors.accentTeal,
                    label: 'Vibration',
                    value: settings.vibration,
                    onChanged: (v) async {
                      await notifier.setVibration(v);
                      if (v) AppFeedback.previewVibration();
                    },
                  ),
                ],
              ),
              const SizedBox(height: 20),
              const _SectionLabel('APPEARANCE'),
              _SettingsCard(
                children: [
                  _ToggleRow(
                    icon: Icons.dark_mode_outlined,
                    iconColor: colors.secondaryText,
                    label: 'Dark Theme',
                    value: isDarkThemeToggleOn(context, themeMode),
                    onChanged: notifier.setDarkTheme,
                  ),
                ],
              ),
              if (kDebugMode) ...[
                const SizedBox(height: 20),
                ListTile(
                  leading: const Icon(Icons.bug_report_outlined),
                  title: const Text('Open Ad Inspector (debug only)'),
                  onTap: () async {
                    final messenger = ScaffoldMessenger.of(context);
                    try {
                      await AdsService.instance.initialize();
                      await MobileAds.instance.initialize();
                      if (!context.mounted) return;
                      messenger.showSnackBar(
                        const SnackBar(
                          content: Text('Opening Ad Inspector…'),
                          duration: Duration(seconds: 2),
                        ),
                      );
                      MobileAds.instance.openAdInspector((error) {
                        if (error == null) return;
                        debugPrint(
                          'Ad Inspector closed with error: '
                          'code=${error.code}, domain=${error.domain}, message=${error.message}',
                        );
                        unawaited(
                          MobileAds.instance.openDebugMenu(
                            'ca-app-pub-3463774223212169/9913527302',
                          ),
                        );
                        messenger.showSnackBar(
                          SnackBar(
                            content: Text(
                              'Ad Inspector: ${error.message ?? error.code}',
                            ),
                          ),
                        );
                      });
                    } catch (e) {
                      debugPrint('Failed to open Ad Inspector: $e');
                      try {
                        await MobileAds.instance.openDebugMenu(
                          'ca-app-pub-3463774223212169/9913527302',
                        );
                      } catch (_) {}
                      messenger.showSnackBar(
                        SnackBar(content: Text('Ad Inspector failed: $e')),
                      );
                    }
                  },
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        text,
        style: AppTextStyles.label(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: colors.secondaryText,
        ).copyWith(letterSpacing: 1.1),
      ),
    );
  }
}

class _SettingsCard extends StatelessWidget {
  const _SettingsCard({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(14),
        border: isDark ? Border.all(color: colors.border) : null,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.04),
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

class _ToggleRow extends StatelessWidget {
  const _ToggleRow({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
    required this.onChanged,
    this.showDivider = false,
  });

  final IconData icon;
  final Color iconColor;
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
          child: Row(
            children: [
              Icon(icon, size: 22, color: iconColor),
              const SizedBox(width: 12),
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
              _AppToggle(value: value, onChanged: onChanged),
            ],
          ),
        ),
        if (showDivider)
          Padding(
            padding: const EdgeInsets.only(left: 48),
            child: Divider(
              height: 1,
              thickness: 0.5,
              color: colors.border,
            ),
          ),
      ],
    );
  }
}

/// Solid teal ON / theme-aware OFF track with white knob.
class _AppToggle extends StatelessWidget {
  const _AppToggle({required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool> onChanged;

  static const Color _onTrack = Color(0xFF2EC4A6);

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final offTrack = isDark ? colors.surface2 : const Color(0xFFE3DFD3);

    return GestureDetector(
      onTap: () => onChanged(!value),
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        width: 52,
        height: 32,
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: value ? _onTrack : offTrack,
          borderRadius: BorderRadius.circular(16),
        ),
        alignment: value ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          width: 26,
          height: 26,
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.12),
                blurRadius: 4,
                offset: const Offset(0, 1),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
