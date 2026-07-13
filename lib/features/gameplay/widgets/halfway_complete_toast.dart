import 'package:flutter/material.dart';

import 'package:arrow_drift/core/theme/app_theme.dart';

/// Brief mid-level celebration — sits under the Level title / hearts (≈2s).
class HalfwayCompleteToast extends StatelessWidget {
  const HalfwayCompleteToast({super.key});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Align(
        alignment: Alignment.topCenter,
        child: Material(
          color: Colors.transparent,
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.9, end: 1),
            duration: const Duration(milliseconds: 280),
            curve: Curves.easeOutBack,
            builder: (context, scale, child) {
              return Transform.scale(scale: scale, child: child);
            },
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 28),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.14),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
                border: Border.all(
                  color: AppColors.accentTeal.withValues(alpha: 0.35),
                  width: 1.5,
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('🥳', style: TextStyle(fontSize: 28)),
                  const SizedBox(height: 4),
                  Text(
                    '50% complete',
                    textAlign: TextAlign.center,
                    style: AppTextStyles.heading(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: AppColors.lightPrimaryText,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Keep going! ✨',
                    textAlign: TextAlign.center,
                    style: AppTextStyles.body(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF6B7280),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
