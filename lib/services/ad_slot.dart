import 'package:flutter/material.dart';

import 'package:arrow_drift/core/theme/app_theme.dart';

/// Fixed-height dummy ad banner. Real SDK can replace child later.
class AdSlot extends StatelessWidget {
  const AdSlot({
    super.key,
    required this.height,
    this.label = 'Sponsored',
    this.margin = EdgeInsets.zero,
  });

  final double height;
  final String label;
  final EdgeInsetsGeometry margin;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: margin,
      child: SizedBox(
        width: double.infinity,
        height: height,
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: isDark
                  ? const [
                      Color(0xFF0F3D3A),
                      Color(0xFF164E63),
                      Color(0xFF1A3A5C),
                    ]
                  : const [
                      Color(0xFFD4F5EE),
                      Color(0xFFC8E8F5),
                      Color(0xFFE8F0D8),
                    ],
            ),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isDark
                  ? const Color(0xFF3DDCB8).withValues(alpha: 0.55)
                  : const Color(0xFF0B8F7A).withValues(alpha: 0.45),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.accentTeal.withValues(alpha: isDark ? 0.22 : 0.14),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Stack(
            children: [
              Positioned(
                right: -8,
                top: -10,
                child: Container(
                  width: height * 0.9,
                  height: height * 0.9,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFFFFC857).withValues(alpha: isDark ? 0.14 : 0.22),
                  ),
                ),
              ),
              Positioned(
                left: 10,
                top: 6,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF3DDCB8), Color(0xFF1FA88E)],
                    ),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'Ad',
                    style: AppTextStyles.label(
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              Center(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.ads_click_rounded,
                      size: height < 55 ? 16 : 20,
                      color: isDark
                          ? const Color(0xFF7EF0D4)
                          : const Color(0xFF0B7A68),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        label,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.label(
                          fontSize: height < 55 ? 11 : 12,
                          fontWeight: FontWeight.w700,
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.95)
                              : const Color(0xFF0E2A26),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
