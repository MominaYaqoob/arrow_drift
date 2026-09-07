import 'package:flutter/material.dart';

import 'package:arrow_drift/core/theme/app_theme.dart';

class GameTopRow extends StatelessWidget {
  const GameTopRow({
    super.key,
    required this.title,
    required this.onBack,
    required this.onSettings,
    this.minimal = false,
  });

  final String title;
  final VoidCallback onBack;
  final VoidCallback? onSettings;
  final bool minimal;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    if (minimal) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(8, 16, 8, 0),
        child: SizedBox(
          height: 44,
          child: Center(
            child: Text(
              title,
              textAlign: TextAlign.center,
              style: AppTextStyles.body(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: colors.primaryText,
              ),
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
      child: Row(
        children: [
          IconButton(
            onPressed: onBack,
            icon: Icon(
              Icons.chevron_left_rounded,
              size: 32,
              color: colors.primaryText,
            ),
          ),
          Expanded(
            child: Text(
              title,
              textAlign: TextAlign.center,
              style: AppTextStyles.heading(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: colors.primaryText,
              ),
            ),
          ),
          IconButton(
            onPressed: onSettings,
            icon: Icon(
              Icons.settings_rounded,
              size: 24,
              color: colors.primaryText,
            ),
          ),
        ],
      ),
    );
  }
}
