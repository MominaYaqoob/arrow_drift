import 'package:flutter/material.dart';

import 'package:arrow_drift/core/theme/app_theme.dart';

/// Brief mid-level celebration — sits under the Level title / hearts (≈2s).
class HalfwayCompleteToast extends StatelessWidget {
  const HalfwayCompleteToast({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return IgnorePointer(
      child: Align(
        alignment: Alignment.topCenter,
        child: Material(
          color: Colors.transparent,
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.92, end: 1),
            duration: const Duration(milliseconds: 260),
            curve: Curves.easeOutBack,
            builder: (context, scale, child) {
              return Transform.scale(scale: scale, child: child);
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Container(
                width: double.infinity,
                constraints: const BoxConstraints(maxWidth: 340),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: isDark
                        ? [colors.surface2, colors.surface]
                        : const [Color(0xFFFFFFFF), Color(0xFFEAF8F4)],
                  ),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color:
                          Colors.black.withValues(alpha: isDark ? 0.38 : 0.12),
                      blurRadius: 14,
                      offset: const Offset(0, 6),
                    ),
                    BoxShadow(
                      color: AppColors.accentTeal
                          .withValues(alpha: isDark ? 0.18 : 0.12),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                  border: Border.all(
                    color: AppColors.accentTeal
                        .withValues(alpha: isDark ? 0.4 : 0.35),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.accentTeal
                            .withValues(alpha: isDark ? 0.22 : 0.15),
                      ),
                      alignment: Alignment.center,
                      child: const Text('🥳', style: TextStyle(fontSize: 18)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '50% complete',
                            style: AppTextStyles.heading(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: colors.primaryText,
                            ),
                          ),
                          const SizedBox(height: 1),
                          Text(
                            'Keep going!',
                            style: AppTextStyles.body(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: isDark
                                  ? AppColors.accentTeal
                                  : AppColors.accentTealDeep,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.trending_up_rounded,
                      size: 22,
                      color: AppColors.accentTeal
                          .withValues(alpha: isDark ? 0.9 : 0.85),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
