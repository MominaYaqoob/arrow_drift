import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:arrow_drift/core/theme/app_theme.dart';

/// Rate-prompt dialog — themed for light / dark. Shown every 10 campaign levels.
class RateGameDialog extends StatefulWidget {
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
  State<RateGameDialog> createState() => _RateGameDialogState();
}

class _RateGameDialogState extends State<RateGameDialog>
    with TickerProviderStateMixin {
  late final AnimationController _enterController;
  late final AnimationController _pulseController;
  late final AnimationController _starController;

  late final Animation<double> _bgOpacity;
  late final Animation<double> _cardScale;
  late final Animation<double> _cardOpacity;
  late final Animation<double> _pulse;

  @override
  void initState() {
    super.initState();

    _enterController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    );
    _bgOpacity = CurvedAnimation(
      parent: _enterController,
      curve: const Interval(0, 0.55, curve: Curves.easeOut),
    );
    _cardOpacity = CurvedAnimation(
      parent: _enterController,
      curve: const Interval(0.12, 0.75, curve: Curves.easeOut),
    );
    _cardScale = Tween<double>(begin: 0.88, end: 1).animate(
      CurvedAnimation(
        parent: _enterController,
        curve: const Interval(0.12, 1, curve: Curves.easeOutBack),
      ),
    );

    _starController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    );
    _pulse = Tween<double>(begin: 1, end: 1.08).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _enterController.forward();
    Future<void>.delayed(const Duration(milliseconds: 180), () {
      if (mounted) _starController.forward();
    });
    Future<void>.delayed(const Duration(milliseconds: 500), () {
      if (mounted) _pulseController.repeat(reverse: true);
    });
  }

  @override
  void dispose() {
    _enterController.dispose();
    _pulseController.dispose();
    _starController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Material(
      color: Colors.transparent,
      child: AnimatedBuilder(
        animation: _enterController,
        builder: (context, _) {
          return Stack(
            fit: StackFit.expand,
            children: [
              Opacity(
                opacity: _bgOpacity.value,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: const Alignment(0, -0.12),
                      radius: 1.2,
                      colors: isDark
                          ? const [
                              Color(0xFF134840),
                              Color(0xFF0A101A),
                              Color(0xFF060A12),
                            ]
                          : const [
                              Color(0xFFD4F5EE),
                              Color(0xFFF6F3EC),
                              Color(0xFFEDE8DC),
                            ],
                      stops: const [0.0, 0.48, 1.0],
                    ),
                  ),
                ),
              ),
              Opacity(
                opacity: _bgOpacity.value * 0.85,
                child: CustomPaint(
                  painter: _RateBurstPainter(
                    color: AppColors.accentTeal
                        .withValues(alpha: isDark ? 0.12 : 0.07),
                    spin: _enterController.value * 0.08,
                  ),
                ),
              ),
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 28),
                  child: Opacity(
                    opacity: _cardOpacity.value,
                    child: Transform.scale(
                      scale: _cardScale.value,
                      child: Material(
                        color: colors.surface,
                        elevation: isDark ? 0 : 12,
                        shadowColor: Colors.black26,
                        borderRadius: BorderRadius.circular(26),
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(26),
                            border: Border.all(
                              color: isDark
                                  ? colors.border
                                  : colors.border.withValues(alpha: 0.55),
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.accentTeal.withValues(
                                  alpha: isDark ? 0.18 : 0.1,
                                ),
                                blurRadius: 24,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: Stack(
                            children: [
                              Padding(
                                padding:
                                    const EdgeInsets.fromLTRB(22, 32, 22, 22),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    AnimatedBuilder(
                                      animation: _pulseController,
                                      builder: (context, child) {
                                        return Transform.scale(
                                          scale: _pulse.value,
                                          child: child,
                                        );
                                      },
                                      child: Container(
                                        width: 64,
                                        height: 64,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          gradient: LinearGradient(
                                            begin: Alignment.topLeft,
                                            end: Alignment.bottomRight,
                                            colors: [
                                              AppColors.accentTeal.withValues(
                                                alpha: isDark ? 0.28 : 0.18,
                                              ),
                                              AppColors.lightGold.withValues(
                                                alpha: isDark ? 0.18 : 0.14,
                                              ),
                                            ],
                                          ),
                                          boxShadow: [
                                            BoxShadow(
                                              color: AppColors.lightGold
                                                  .withValues(alpha: 0.28),
                                              blurRadius: 16,
                                              spreadRadius: 1,
                                            ),
                                          ],
                                        ),
                                        child: const Icon(
                                          Icons.star_rounded,
                                          size: 34,
                                          color: AppColors.lightGold,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      'Enjoying Arrow Drift?',
                                      textAlign: TextAlign.center,
                                      style: AppTextStyles.heading(
                                        fontSize: 22,
                                        fontWeight: FontWeight.w800,
                                        color: colors.primaryText,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      'Tap a rating — it only takes a second.',
                                      textAlign: TextAlign.center,
                                      style: AppTextStyles.body(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w500,
                                        color: colors.secondaryText,
                                      ),
                                    ),
                                    const SizedBox(height: 18),
                                    AnimatedBuilder(
                                      animation: _starController,
                                      builder: (context, _) {
                                        return Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: List.generate(5, (i) {
                                            final start = i * 0.12;
                                            final end =
                                                (start + 0.45).clamp(0.0, 1.0);
                                            final t = Curves.easeOutBack
                                                .transform(
                                              (((_starController.value -
                                                              start) /
                                                          (end - start))
                                                      .clamp(0.0, 1.0)),
                                            );
                                            return Padding(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                horizontal: 3,
                                              ),
                                              child: Opacity(
                                                opacity: t.clamp(0.0, 1.0),
                                                child: Transform.scale(
                                                  scale: 0.55 + 0.45 * t,
                                                  child: Transform.translate(
                                                    offset: Offset(
                                                      0,
                                                      (1 - t) * 10,
                                                    ),
                                                    child: Icon(
                                                      Icons.star_rounded,
                                                      size: 36,
                                                      color:
                                                          AppColors.lightGold,
                                                      shadows: [
                                                        Shadow(
                                                          color: AppColors
                                                              .lightGold
                                                              .withValues(
                                                            alpha: 0.45,
                                                          ),
                                                          blurRadius: 10,
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            );
                                          }),
                                        );
                                      },
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      'If you like the game, a 5★ rating helps '
                                      'a lot. Thanks for playing!',
                                      textAlign: TextAlign.center,
                                      style: AppTextStyles.body(
                                        fontSize: 14,
                                        height: 1.4,
                                        fontWeight: FontWeight.w500,
                                        color: colors.secondaryText,
                                      ),
                                    ),
                                    const SizedBox(height: 22),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: SizedBox(
                                            height: 50,
                                            child: OutlinedButton(
                                              onPressed: widget.onLowStars,
                                              style: OutlinedButton.styleFrom(
                                                foregroundColor:
                                                    colors.primaryText,
                                                side: BorderSide(
                                                  color: colors.border,
                                                ),
                                                backgroundColor:
                                                    colors.surface2,
                                                shape: RoundedRectangleBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(
                                                    999,
                                                  ),
                                                ),
                                              ),
                                              child: Text(
                                                '1–4 ★',
                                                style: AppTextStyles.button(
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.w700,
                                                  color: isDark
                                                      ? AppColors.accentTeal
                                                      : AppColors
                                                          .accentTealDeep,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: SizedBox(
                                            height: 50,
                                            child: DecoratedBox(
                                              decoration: BoxDecoration(
                                                borderRadius:
                                                    BorderRadius.circular(999),
                                                gradient:
                                                    const LinearGradient(
                                                  colors: [
                                                    AppColors.accentTeal,
                                                    AppColors.accentTealDeep,
                                                  ],
                                                ),
                                                boxShadow: [
                                                  BoxShadow(
                                                    color: AppColors
                                                        .accentTealDeep
                                                        .withValues(
                                                      alpha: 0.38,
                                                    ),
                                                    blurRadius: 12,
                                                    offset:
                                                        const Offset(0, 5),
                                                  ),
                                                ],
                                              ),
                                              child: Material(
                                                color: Colors.transparent,
                                                child: InkWell(
                                                  onTap: widget.onFiveStars,
                                                  borderRadius:
                                                      BorderRadius.circular(
                                                    999,
                                                  ),
                                                  child: Center(
                                                    child: Text(
                                                      '5 ★ Rate',
                                                      style:
                                                          AppTextStyles.button(
                                                        fontSize: 15,
                                                        fontWeight:
                                                            FontWeight.w800,
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
                                  color: colors.surface2,
                                  shape: const CircleBorder(),
                                  child: InkWell(
                                    customBorder: const CircleBorder(),
                                    onTap: widget.onDismiss,
                                    child: SizedBox(
                                      width: 34,
                                      height: 34,
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
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _RateBurstPainter extends CustomPainter {
  _RateBurstPainter({required this.color, this.spin = 0});

  final Color color;
  final double spin;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height * 0.42);
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    const rays = 18;
    final radius = size.longestSide;
    final spinRad = spin * math.pi * 2;
    for (var i = 0; i < rays; i++) {
      final a0 = (i / rays) * math.pi * 2 + spinRad;
      final a1 = ((i + 0.4) / rays) * math.pi * 2 + spinRad;
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
      oldDelegate.color != color || oldDelegate.spin != spin;
}
