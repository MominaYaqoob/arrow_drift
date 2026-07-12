import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:arrow_drift/core/theme/app_theme.dart';
import 'package:arrow_drift/data/repositories/settings_repository.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  static const String routePath = '/settings';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.appColors;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF0E141C) : const Color(0xFFF1EDE4);
    final settingsAsync = ref.watch(settingsProvider);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
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
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            children: [
              Container(
                decoration: BoxDecoration(
                  color: colors.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: colors.border),
                ),
                child: Column(
                  children: [
                    _ToggleRow(
                      label: 'Sounds',
                      value: settings.sounds,
                      onChanged: notifier.setSounds,
                      showDivider: true,
                    ),
                    _ToggleRow(
                      label: 'Vibration',
                      value: settings.vibration,
                      onChanged: notifier.setVibration,
                      showDivider: true,
                    ),
                    _ToggleRow(
                      label: 'Dark Theme',
                      value: settings.darkTheme,
                      onChanged: notifier.setDarkTheme,
                      showDivider: true,
                    ),
                    _ToggleRow(
                      label: 'Auto-Lock',
                      value: settings.autoLock,
                      onChanged: notifier.setAutoLock,
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _ToggleRow extends StatelessWidget {
  const _ToggleRow({
    required this.label,
    required this.value,
    required this.onChanged,
    this.showDivider = false,
  });

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
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
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
              Switch.adaptive(
                value: value,
                activeThumbColor: colors.accentTeal,
                activeTrackColor: colors.accentTeal.withValues(alpha: 0.45),
                onChanged: onChanged,
              ),
            ],
          ),
        ),
        if (showDivider)
          Divider(height: 1, thickness: 0.5, color: colors.border),
      ],
    );
  }
}
