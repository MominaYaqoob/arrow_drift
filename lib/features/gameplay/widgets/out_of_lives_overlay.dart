import 'package:flutter/material.dart';

import 'package:arrow_drift/core/theme/app_theme.dart';

/// Centered modal shown when [GameState.isLost] is true (Image 5).
class OutOfLivesOverlay extends StatelessWidget {
  const OutOfLivesOverlay({
    super.key,
    required this.onGetMoreLives,
    required this.onRestart,
  });

  final VoidCallback onGetMoreLives;
  final VoidCallback onRestart;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return Material(
      color: Colors.black.withValues(alpha: 0.45),
      child: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(22, 28, 22, 22),
              decoration: BoxDecoration(
                color: colors.surface,
                borderRadius: BorderRadius.circular(22),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.18),
                    blurRadius: 28,
                    offset: const Offset(0, 12),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Out of Lives!',
                    textAlign: TextAlign.center,
                    style: AppTextStyles.heading(
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      color: colors.primaryText,
                    ),
                  ),
                  const SizedBox(height: 22),
                  SizedBox(
                    width: 96,
                    height: 96,
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Container(
                          width: 96,
                          height: 96,
                          decoration: BoxDecoration(
                            color: colors.surface2,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.favorite_rounded,
                            size: 44,
                            color: colors.heartRed,
                          ),
                        ),
                        Positioned(
                          right: -2,
                          top: -2,
                          child: Container(
                            width: 32,
                            height: 32,
                            alignment: Alignment.center,
                            decoration: const BoxDecoration(
                              color: AppColors.accentTeal,
                              shape: BoxShape.circle,
                            ),
                            child: Text(
                              '+1',
                              style: AppTextStyles.label(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 26),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: onGetMoreLives,
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.accentTeal,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(28),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'Get More Lives',
                            style: AppTextStyles.button(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Icon(Icons.smart_display_rounded, size: 22),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: onRestart,
                    child: Text(
                      'Restart Game',
                      style: AppTextStyles.body(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.accentTealDeep,
                      ),
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
