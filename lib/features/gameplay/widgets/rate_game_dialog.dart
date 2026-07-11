import 'package:flutter/material.dart';

import 'package:arrow_drift/core/theme/app_theme.dart';

/// Rate-prompt dialog shown once after clearing Level 5 (teal accents).
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
          // Soft teal celebration behind the card (matches win screen family).
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: Alignment(0, -0.1),
                radius: 1.1,
                colors: [
                  Color(0xFF7EEFD8),
                  Color(0xFF2EC4A6),
                  Color(0xFF0F8F7A),
                  Color(0xFF0A6B5C),
                ],
                stops: [0.0, 0.35, 0.7, 1.0],
              ),
            ),
          ),
          CustomPaint(painter: _RateBurstPainter()),
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Material(
                color: Colors.white,
                elevation: 10,
                shadowColor: Colors.black38,
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
                                  color: Color(0xFFFFC107),
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
                              color: const Color(0xFF6B7280),
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
                                      backgroundColor: const Color(0xFFF3F4F6),
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
                        color: const Color(0xFFE5E7EB),
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
                              color: Colors.white,
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
      ..color = Colors.white.withValues(alpha: 0.07)
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
