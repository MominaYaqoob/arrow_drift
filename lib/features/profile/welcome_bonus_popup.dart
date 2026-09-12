import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:arrow_drift/core/theme/app_theme.dart';
import 'package:arrow_drift/data/repositories/progress_repository.dart';

/// First-run gift after nickname create — Collect adds +100 coins once.
class WelcomeBonusPopup extends StatefulWidget {
  const WelcomeBonusPopup({
    super.key,
    required this.onCollect,
  });

  final Future<void> Function() onCollect;

  static Future<void> show(
    BuildContext context, {
    required Future<void> Function() onCollect,
  }) {
    return showGeneralDialog<void>(
      context: context,
      barrierDismissible: false,
      barrierLabel: 'Welcome Bonus',
      barrierColor: Colors.black.withValues(alpha: 0.55),
      transitionDuration: const Duration(milliseconds: 320),
      pageBuilder: (context, animation, secondaryAnimation) {
        return WelcomeBonusPopup(onCollect: onCollect);
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutBack,
        );
        return FadeTransition(
          opacity: animation,
          child: ScaleTransition(scale: curved, child: child),
        );
      },
    );
  }

  @override
  State<WelcomeBonusPopup> createState() => _WelcomeBonusPopupState();
}

class _WelcomeBonusPopupState extends State<WelcomeBonusPopup>
    with SingleTickerProviderStateMixin {
  late final AnimationController _shine;
  bool _collecting = false;

  @override
  void initState() {
    super.initState();
    _shine = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat();
  }

  @override
  void dispose() {
    _shine.dispose();
    super.dispose();
  }

  Future<void> _collect() async {
    if (_collecting) return;
    setState(() => _collecting = true);
    await widget.onCollect();
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return SafeArea(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
          child: Material(
            color: colors.surface,
            elevation: 16,
            shadowColor: Colors.black.withValues(alpha: 0.35),
            borderRadius: BorderRadius.circular(22),
            clipBehavior: Clip.antiAlias,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: 360,
                maxHeight: MediaQuery.sizeOf(context).height - 48,
              ),
              child: SingleChildScrollView(
              child: Stack(
                children: [
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.fromLTRB(22, 22, 22, 50),
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [Color(0xFF0E1726), Color(0xFF1C2A42)],
                          ),
                        ),
                        child: Column(
                          children: [
                            const SizedBox(height: 62),
                            Text(
                              'Welcome Bonus',
                              textAlign: TextAlign.center,
                              style: AppTextStyles.heading(
                                fontSize: 24,
                                fontWeight: FontWeight.w800,
                                color: colors.gold,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'A gift to get you started',
                              textAlign: TextAlign.center,
                              style: AppTextStyles.body(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: const Color(0xFFB8C0CC),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 36, 20, 20),
                        child: Column(
                          children: [
                            SizedBox(
                              height: 220,
                              width: double.infinity,
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  Positioned.fill(
                                    child: IgnorePointer(
                                      child: AnimatedBuilder(
                                        animation: _shine,
                                        builder: (context, _) {
                                          return CustomPaint(
                                            painter: _SparkPainter(
                                              t: _shine.value,
                                              gold: colors.gold,
                                            ),
                                          );
                                        },
                                      ),
                                    ),
                                  ),
                                  Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Image(
                                        image: AssetImage(
                                          'assets/branding/welcome_gift.png',
                                        ),
                                        height: 132,
                                        fit: BoxFit.contain,
                                        filterQuality: FilterQuality.high,
                                      ),
                                      const SizedBox(height: 8),
                                      SizedBox(
                                        width: double.infinity,
                                        child: Text(
                                          '+${ProgressRepository.welcomeBonusCoins}',
                                          textAlign: TextAlign.center,
                                          style: AppTextStyles.heading(
                                            fontSize: 40,
                                            fontWeight: FontWeight.w800,
                                            color: colors.gold,
                                          ),
                                        ),
                                      ),
                                      SizedBox(
                                        width: double.infinity,
                                        child: Text(
                                          'COINS',
                                          textAlign: TextAlign.center,
                                          style: AppTextStyles.label(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w800,
                                            color: colors.secondaryText,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              'Unlock Custom levels with coins you collect.',
                              textAlign: TextAlign.center,
                              style: AppTextStyles.body(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: colors.secondaryText,
                              ),
                            ),
                            const SizedBox(height: 20),
                            SizedBox(
                              width: double.infinity,
                              height: 52,
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(999),
                                  gradient: const LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: [
                                      Color(0xFF3DDCB8),
                                      Color(0xFF0F8F7A),
                                    ],
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: AppColors.accentTealDeep
                                          .withValues(alpha: 0.28),
                                      blurRadius: 12,
                                      offset: const Offset(0, 6),
                                    ),
                                  ],
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(999),
                                  child: Stack(
                                    children: [
                                      Positioned.fill(
                                        child: Material(
                                          color: Colors.transparent,
                                          child: InkWell(
                                            onTap:
                                                _collecting ? null : _collect,
                                            child: Center(
                                              child: _collecting
                                                  ? const SizedBox(
                                                      width: 22,
                                                      height: 22,
                                                      child:
                                                          CircularProgressIndicator(
                                                        strokeWidth: 2.5,
                                                        color: Colors.white,
                                                      ),
                                                    )
                                                  : Text(
                                                      'Collect',
                                                      style:
                                                          AppTextStyles.button(
                                                        fontSize: 17,
                                                        fontWeight:
                                                            FontWeight.w800,
                                                        color: Colors.white,
                                                      ),
                                                    ),
                                            ),
                                          ),
                                        ),
                                      ),
                                      Positioned.fill(
                                        child: IgnorePointer(
                                          child: _SoftShineSweep(
                                            animation: _shine,
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
                      ),
                    ],
                  ),
                  const Positioned(
                    top: 18,
                    left: 0,
                    right: 0,
                    child: Center(child: _GiftBadge()),
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

class _GiftBadge extends StatelessWidget {
  const _GiftBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 72,
      height: 72,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: const Color(0xFF152033),
        border: Border.all(color: AppColors.accentTeal, width: 2.2),
        boxShadow: [
          BoxShadow(
            color: AppColors.lightGold.withValues(alpha: 0.28),
            blurRadius: 12,
          ),
        ],
      ),
      child: const Icon(
        Icons.card_giftcard_rounded,
        size: 30,
        color: AppColors.lightGold,
      ),
    );
  }
}

class _SoftShineSweep extends StatelessWidget {
  const _SoftShineSweep({required this.animation});

  final Animation<double> animation;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, _) {
        return CustomPaint(
          painter: _SoftShinePainter(t: animation.value),
        );
      },
    );
  }
}

class _SoftShinePainter extends CustomPainter {
  _SoftShinePainter({required this.t});

  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    canvas.clipRect(Offset.zero & size);
    final x = (t * 1.7 - 0.35) * size.width;
    final band = Rect.fromLTWH(-10, -16, 20, size.height + 32);
    final shine = Paint()
      ..shader = LinearGradient(
        colors: [
          Colors.transparent,
          Colors.white.withValues(alpha: 0.10),
          Colors.white.withValues(alpha: 0.28),
          Colors.white.withValues(alpha: 0.10),
          Colors.transparent,
        ],
      ).createShader(band);
    canvas.save();
    canvas.translate(x, size.height * 0.5);
    canvas.rotate(-0.35);
    canvas.drawRect(band, shine);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _SoftShinePainter oldDelegate) {
    return oldDelegate.t != t;
  }
}

class _SparkPainter extends CustomPainter {
  _SparkPainter({required this.t, required this.gold});

  final double t;
  final Color gold;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;

    void spark(Offset c, double phase, double scale) {
      final pulse = (math.sin((t + phase) * math.pi * 2) * 0.5 + 0.5);
      if (pulse < 0.2) return;
      final p = Paint()
        ..color = gold.withValues(alpha: 0.25 + pulse * 0.7)
        ..strokeWidth = 1.2
        ..strokeCap = StrokeCap.round;
      final s = 2.6 * scale;
      canvas.drawLine(Offset(c.dx - s, c.dy), Offset(c.dx + s, c.dy), p);
      canvas.drawLine(Offset(c.dx, c.dy - s), Offset(c.dx, c.dy + s), p);
    }

    spark(Offset(size.width * 0.14, size.height * 0.12), 0.0, 1.0);
    spark(Offset(size.width * 0.86, size.height * 0.16), 0.12, 0.95);
    spark(Offset(size.width * 0.50, size.height * 0.06), 0.24, 1.2);
    spark(Offset(size.width * 0.22, size.height * 0.38), 0.36, 0.85);
    spark(Offset(size.width * 0.78, size.height * 0.42), 0.48, 1.05);
    spark(Offset(size.width * 0.16, size.height * 0.62), 0.60, 0.9);
    spark(Offset(size.width * 0.84, size.height * 0.66), 0.72, 1.0);
    spark(Offset(size.width * 0.32, size.height * 0.88), 0.84, 0.85);
    spark(Offset(size.width * 0.68, size.height * 0.90), 0.96, 1.1);
  }

  @override
  bool shouldRepaint(covariant _SparkPainter oldDelegate) {
    return oldDelegate.t != t || oldDelegate.gold != gold;
  }
}
