import 'package:flutter/material.dart';

import 'package:arrow_drift/core/theme/app_theme.dart';

/// Fixed-height reserved ad region. Real ads can replace the child later
/// without shifting surrounding layout.
class AdSlot extends StatelessWidget {
  const AdSlot({
    super.key,
    required this.height,
    this.label = 'Ad space',
    this.margin = EdgeInsets.zero,
  });

  final double height;
  final String label;
  final EdgeInsetsGeometry margin;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: margin,
      child: SizedBox(
        width: double.infinity,
        height: height,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: isDark
                ? colors.surface2.withValues(alpha: 0.85)
                : const Color(0xFFEDE8DC),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: colors.border.withValues(alpha: 0.7)),
          ),
          child: Center(
            child: Text(
              label,
              style: AppTextStyles.label(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: colors.secondaryText,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
