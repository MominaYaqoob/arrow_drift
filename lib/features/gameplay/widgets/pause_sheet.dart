import 'package:flutter/material.dart';

import 'package:arrow_drift/core/theme/app_theme.dart';

/// Pause / settings bottom sheet opened from the gameplay gear icon.
class PauseSheet extends StatelessWidget {
  const PauseSheet({
    super.key,
    required this.onResume,
    required this.onRestart,
    required this.onQuit,
  });

  final VoidCallback onResume;
  final VoidCallback onRestart;
  final VoidCallback onQuit;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: colors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Paused',
              style: AppTextStyles.heading(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: colors.primaryText,
              ),
            ),
            const SizedBox(height: 20),
            _SheetButton(
              label: 'Resume',
              icon: Icons.play_arrow_rounded,
              filled: true,
              onTap: onResume,
            ),
            const SizedBox(height: 10),
            _SheetButton(
              label: 'Restart Level',
              icon: Icons.refresh_rounded,
              onTap: onRestart,
            ),
            const SizedBox(height: 10),
            _SheetButton(
              label: 'Quit to Home',
              icon: Icons.home_rounded,
              onTap: onQuit,
            ),
          ],
        ),
      ),
    );
  }
}

class _SheetButton extends StatelessWidget {
  const _SheetButton({
    required this.label,
    required this.icon,
    required this.onTap,
    this.filled = false,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return SizedBox(
      width: double.infinity,
      child: Material(
        color: filled ? colors.accentTeal : colors.surface,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: filled
                  ? null
                  : Border.all(color: colors.border, width: 0.5),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  size: 22,
                  color: filled
                      ? AppColors.lightPrimaryText
                      : colors.primaryText,
                ),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: AppTextStyles.button(
                    fontWeight: FontWeight.w700,
                    color: filled
                        ? AppColors.lightPrimaryText
                        : colors.primaryText,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
