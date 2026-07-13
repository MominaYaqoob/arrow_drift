import 'package:flutter/material.dart';

import 'package:arrow_drift/core/theme/app_theme.dart';

/// Rate-prompt dialog shown once after clearing Level 11.
/// Same layout; colors match the cream / navy / teal app palette.
class RateGameDialog extends StatelessWidget {
  const RateGameDialog({
    super.key,
    required this.onDismiss,
    required this.onFiveStars,
    required this.onLowStars,
  });

  final VoidCallback onDismiss;
  final VoidCallback onFiveStars;
  final VoidCallback onLowStars;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Soft cream + teal wash (same family as gameplay UI).
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: Alignment(0, -0.15),
                radius: 1.15,
                colors: [
                  Color(0xFFD9F5EE),
                  Color(0xFFF6F3EC),
                  Color(0xFFEDE8DC),
                ],
                stops: [0.0, 0.45, 1.0],
              ),
            ),
          ),
          CustomPaint(painter: _RateBurstPainter()),
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Material(
                color: AppColors.lightSurface,
                elevation: 10,
                shadowColor: Colors.black26,
                borderRadius: BorderRadius.circular(22),
                child: Stack(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(22, 28, 22, 22),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Rate Game',
                            style: AppTextStyles.heading(
                              fontSize: 22,
                              fontWeight: FontWeight.w700,
                              color: AppColors.lightPrimaryText,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: List.generate(
                              5,
                              (_) => const Padding(
                                padding: EdgeInsets.symmetric(horizontal: 3),
                                child: Icon(
                                  Icons.star_rounded,
                                  size: 36,
                                  color: AppColors.lightGold,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'If you are enjoying Arrow Drift, take a moment '
                            'to rate the game. Thanks for your support!',
                            textAlign: TextAlign.center,
                            style: AppTextStyles.body(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: AppColors.lightSecondaryText,
                            ),
                          ),
                          const SizedBox(height: 22),
                          Row(
                            children: [
                              Expanded(
                                child: SizedBox(
                                  height: 48,
                                  child: TextButton(
                                    onPressed: onLowStars,
                                    style: TextButton.styleFrom(
                                      backgroundColor: AppColors.lightSurface2,
                                      foregroundColor: AppColors.accentTealDeep,
                                      shape: const StadiumBorder(),
                                    ),
                                    child: Text(
                                      '1–4 stars',
                                      style: AppTextStyles.button(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.accentTealDeep,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: SizedBox(
                                  height: 48,
                                  child: FilledButton(
                                    onPressed: onFiveStars,
                                    style: FilledButton.styleFrom(
                                      backgroundColor: AppColors.accentTeal,
                                      foregroundColor: Colors.white,
                                      elevation: 0,
                                      shape: const StadiumBorder(),
                                    ),
                                    child: Text(
                                      '5 stars',
                                      style: AppTextStyles.button(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Material(
                        color: AppColors.lightSurface2,
                        shape: const CircleBorder(),
                        child: InkWell(
                          customBorder: const CircleBorder(),
                          onTap: onDismiss,
                          child: const SizedBox(
                            width: 32,
                            height: 32,
                            child: Icon(
                              Icons.close_rounded,
                              size: 18,
                              color: AppColors.lightPrimaryText,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RateBurstPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height * 0.42);
    final paint = Paint()
      ..color = AppColors.accentTeal.withValues(alpha: 0.06)
      ..style = PaintingStyle.fill;
    const rays = 16;
    final radius = size.longestSide;
    for (var i = 0; i < rays; i++) {
      final a0 = (i / rays) * 6.28318530718;
      final a1 = ((i + 0.42) / rays) * 6.28318530718;
      final p = Path()
        ..moveTo(center.dx, center.dy)
        ..lineTo(
          center.dx + Offset.fromDirection(a0, radius).dx,
          center.dy + Offset.fromDirection(a0, radius).dy,
        )
        ..lineTo(
          center.dx + Offset.fromDirection(a1, radius).dx,
          center.dy + Offset.fromDirection(a1, radius).dy,
        )
        ..close();
      canvas.drawPath(p, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
