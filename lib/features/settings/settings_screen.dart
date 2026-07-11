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
    final settingsAsync = ref.watch(settingsProvider);

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
          'Settings',
          style: AppTextStyles.heading(
            fontSize: 20,
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
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            children: [
              _ToggleRow(
                label: 'Sounds',
                value: settings.sounds,
                onChanged: notifier.setSounds,
              ),
              _ToggleRow(
                label: 'Vibration',
                value: settings.vibration,
                onChanged: notifier.setVibration,
              ),
              _ToggleRow(
                label: 'Dark Theme',
                value: settings.darkTheme,
                onChanged: notifier.setDarkTheme,
              ),
              _ToggleRow(
                label: 'Auto-Lock',
                value: settings.autoLock,
                onChanged: notifier.setAutoLock,
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
  });

  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: colors.surface,
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
          Switch.adaptive(
            value: value,
            activeThumbColor: colors.accentTeal,
            activeTrackColor: colors.accentTeal.withValues(alpha: 0.45),
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}
