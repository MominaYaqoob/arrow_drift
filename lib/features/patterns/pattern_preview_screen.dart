import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:arrow_drift/core/theme/app_theme.dart';

/// Static pattern preview — layout only, no gameplay logic.
class PatternPreviewScreen extends StatelessWidget {
  const PatternPreviewScreen({super.key, required this.levelNumber});

  static const String routePath = '/patterns/preview';

  final int levelNumber;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: colors.background,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => context.pop(),
                    icon: Icon(
                      Icons.chevron_left_rounded,
                      size: 32,
                      color: colors.primaryText,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      'Level $levelNumber',
                      textAlign: TextAlign.center,
                      style: AppTextStyles.heading(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: colors.primaryText,
                      ),
                    ),
                  ),
                  const SizedBox(width: 48),
                ],
              ),
            ),
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 28),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 300,
                        height: 300,
                        decoration: BoxDecoration(
                          color: colors.surface2,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: colors.border),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(
                                alpha: isDark ? 0.28 : 0.06,
                              ),
                              blurRadius: 16,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: Icon(
                          Icons.favorite_rounded,
                          size: 120,
                          color: colors.accentTeal,
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'Preview only — gameplay coming soon',
                        textAlign: TextAlign.center,
                        style: AppTextStyles.body(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: colors.secondaryText,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
