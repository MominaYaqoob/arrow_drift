import 'package:flutter/material.dart';

import 'package:arrow_drift/core/theme/app_theme.dart';

/// Rate-prompt dialog — themed for light / dark. Shown every 10 campaign levels.
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
    final colors = context.appColors;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Material(
      color: Colors.transparent,
      child: Stack(
        fit: StackFit.expand,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: const Alignment(0, -0.15),
                radius: 1.15,
                colors: isDark
                    ? const [
                        Color(0xFF0F3A34),
                        Color(0xFF0A101A),
                        Color(0xFF060A12),
                      ]
                    : const [
                        Color(0xFFD9F5EE),
                        Color(0xFFF6F3EC),
                        Color(0xFFEDE8DC),
                      ],
                stops: const [0.0, 0.45, 1.0],
              ),
            ),
          ),
          CustomPaint(
            painter: _RateBurstPainter(
              color: AppColors.accentTeal.withValues(alpha: isDark ? 0.1 : 0.06),
            ),
          ),
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Material(
                color: colors.surface,
                elevation: isDark ? 0 : 10,
                shadowColor: Colors.black26,
                borderRadius: BorderRadius.circular(24),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: isDark
                          ? colors.border
                          : colors.border.withValues(alpha: 0.55),
                    ),
                  ),
                  child: Stack(
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(22, 30, 22, 22),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 56,
                              height: 56,
                              decoration: BoxDecoration(
                                color: AppColors.accentTeal
                                    .withValues(alpha: isDark ? 0.2 : 0.14),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.star_rounded,
                                size: 30,
                                color: AppColors.lightGold,
                              ),
                            ),
                            const SizedBox(height: 14),
                            Text(
                              'Rate Game',
                              style: AppTextStyles.heading(
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                                color: colors.primaryText,
                              ),
                            ),
                            const SizedBox(height: 14),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: List.generate(
                                5,
                                (_) => const Padding(
                                  padding: EdgeInsets.symmetric(horizontal: 3),
                                  child: Icon(
                                    Icons.star_rounded,
                                    size: 34,
                                    color: AppColors.lightGold,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 14),
                            Text(
                              'If you are enjoying Arrow Drift, take a moment '
                              'to rate the game. Thanks for your support!',
                              textAlign: TextAlign.center,
                              style: AppTextStyles.body(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: colors.secondaryText,
                              ),
                            ),
                            const SizedBox(height: 22),
                            Row(
                              children: [
                                Expanded(
                                  child: SizedBox(
                                    height: 48,
                                    child: OutlinedButton(
                                      onPressed: onLowStars,
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: colors.primaryText,
                                        side: BorderSide(color: colors.border),
                                        backgroundColor: isDark
                                            ? colors.surface2
                                            : colors.surface2,
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(999),
                                        ),
                                      ),
                                      child: Text(
                                        '1–4 stars',
                                        style: AppTextStyles.button(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w700,
                                          color: isDark
                                              ? AppColors.accentTeal
                                              : AppColors.accentTealDeep,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: SizedBox(
                                    height: 48,
                                    child: DecoratedBox(
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(999),
                                        gradient: const LinearGradient(
                                          colors: [
                                            AppColors.accentTeal,
                                            AppColors.accentTealDeep,
                                          ],
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color: AppColors.accentTealDeep
                                                .withValues(alpha: 0.35),
                                            blurRadius: 10,
                                            offset: const Offset(0, 4),
                                          ),
                                        ],
                                      ),
                                      child: Material(
                                        color: Colors.transparent,
                                        child: InkWell(
                                          onTap: onFiveStars,
                                          borderRadius:
                                              BorderRadius.circular(999),
                                          child: Center(
                                            child: Text(
                                              '5 stars',
                                              style: AppTextStyles.button(
                                                fontSize: 15,
                                                fontWeight: FontWeight.w800,
                                                color: Colors.white,
                                              ),
                                            ),
                                          ),
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
                          color: isDark ? colors.surface2 : colors.surface2,
                          shape: const CircleBorder(),
                          child: InkWell(
                            customBorder: const CircleBorder(),
                            onTap: onDismiss,
                            child: SizedBox(
                              width: 32,
                              height: 32,
                              child: Icon(
                                Icons.close_rounded,
                                size: 18,
                                color: colors.primaryText,
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
          ),
        ],
      ),
    );
  }
}

class _RateBurstPainter extends CustomPainter {
  _RateBurstPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height * 0.42);
    final paint = Paint()
      ..color = color
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
  bool shouldRepaint(covariant _RateBurstPainter oldDelegate) =>
      oldDelegate.color != color;
}
