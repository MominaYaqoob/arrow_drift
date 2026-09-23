import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:arrow_drift/core/theme/app_theme.dart';
import 'package:arrow_drift/data/repositories/progress_repository.dart';

/// One wedge on the Daily Spin wheel. `coins == 0` is the "no win" wedge.
class _SpinPrize {
  const _SpinPrize(this.coins);
  final int coins;
  bool get isEmpty => coins == 0;
  String get label => '$coins';
}

/// 8 wedges, each a different amount.
const List<_SpinPrize> _kSpinPrizes = [
  _SpinPrize(50),
  _SpinPrize(150),
  _SpinPrize(75),
  _SpinPrize(200),
  _SpinPrize(100),
  _SpinPrize(175),
  _SpinPrize(0),
  _SpinPrize(125),
];

/// Home top-bar icon: opens the Daily Spin wheel, with a red dot while
/// today's spin is still unclaimed. Resets at midnight (calendar day).
class DailySpinButton extends ConsumerWidget {
  const DailySpinButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.appColors;
    final canSpin = ref.watch(canSpinTodayProvider).valueOrNull ?? false;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => DailySpinDialog.show(context, ref),
        borderRadius: BorderRadius.circular(26),
        child: Container(
          width: 34,
          height: 34,
          padding: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color.lerp(colors.gold, Colors.white, 0.38)!,
                colors.gold,
                Color.lerp(colors.gold, const Color(0xFF8A6A1E), 0.35)!,
              ],
            ),
            border: Border.all(
              color: Color.lerp(colors.gold, const Color(0xFF8A6A1E), 0.45)!,
              width: 1.3,
            ),
            boxShadow: [
              BoxShadow(
                color: colors.gold.withValues(alpha: 0.35),
                blurRadius: 8,
              ),
            ],
          ),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned.fill(
                child: DecoratedBox(
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Color(0xFFFFF7E4),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(2.5),
                    child: CustomPaint(painter: _MiniWheelPainter()),
                  ),
                ),
              ),
              if (canSpin)
                Positioned(
                  top: -2,
                  right: -2,
                  child: Container(
                    width: 11,
                    height: 11,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE5484D),
                      shape: BoxShape.circle,
                      border: Border.all(color: colors.surface, width: 1.6),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Full-screen Daily Spin dialog: wheel, spin button, and the claimed /
/// come-back-tomorrow states.
class DailySpinDialog extends ConsumerStatefulWidget {
  const DailySpinDialog({super.key});

  static Future<void> show(BuildContext context, WidgetRef ref) {
    return showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Daily Spin',
      barrierColor: Colors.black.withValues(alpha: 0.55),
      transitionDuration: const Duration(milliseconds: 260),
      pageBuilder: (context, animation, secondaryAnimation) {
        // showGeneralDialog does not centre its content itself (unlike
        // showDialog), so centre it explicitly.
        return const Center(child: DailySpinDialog());
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
  ConsumerState<DailySpinDialog> createState() => _DailySpinDialogState();
}

class _DailySpinDialogState extends ConsumerState<DailySpinDialog>
    with TickerProviderStateMixin {
  late final AnimationController _controller;
  late final AnimationController _confettiController;
  Animation<double> _rotation = const AlwaysStoppedAnimation<double>(0);
  List<_ConfettiBit> _confetti = const [];
  bool _spinning = false;
  _SpinPrize? _result;
  bool _alreadySpun = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3200),
    );
    _confettiController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    );
    _alreadySpun = !(ref.read(canSpinTodayProvider).valueOrNull ?? true);
  }

  @override
  void dispose() {
    _controller.dispose();
    _confettiController.dispose();
    super.dispose();
  }

  /// Small celebratory burst from the pointer, only for an actual coin win.
  void _fireConfetti() {
    final rng = math.Random();
    const wedgeColors = _WheelPainter._wedgeColors;
    _confetti = [
      for (var i = 0; i < 22; i++)
        _ConfettiBit(
          angle: (-math.pi / 2) + (rng.nextDouble() - 0.5) * math.pi * 0.9,
          speed: 0.7 + rng.nextDouble() * 0.6,
          size: 4 + rng.nextDouble() * 4,
          color: wedgeColors[rng.nextInt(wedgeColors.length)],
          spin: (rng.nextDouble() - 0.5) * 6,
        ),
    ];
    _confettiController
      ..reset()
      ..forward();
  }

  Duration _timeUntilMidnight() {
    final now = DateTime.now();
    final midnight = DateTime(now.year, now.month, now.day + 1);
    return midnight.difference(now);
  }

  String _formatCountdown(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes % 60;
    return '${h}h ${m.toString().padLeft(2, '0')}m';
  }

  Future<void> _spin() async {
    if (_spinning || _alreadySpun || _result != null) return;
    // Sync lock before any await so a double-tap cannot start two spins.
    _spinning = true;
    setState(() {});

    final repo = await ref.read(progressRepositoryProvider.future);
    if (repo.hasSpunToday()) {
      if (!mounted) return;
      setState(() {
        _spinning = false;
        _alreadySpun = true;
      });
      return;
    }

    final index = math.Random().nextInt(_kSpinPrizes.length);
    final segmentAngle = (2 * math.pi) / _kSpinPrizes.length;
    // Rotate several full turns, ending with the chosen wedge under the
    // fixed top pointer (pointer is fixed at the top; wedge 0 is centred
    // just clockwise of top when unrotated — see _WheelPainter).
    final target = 5 * 2 * math.pi - (index + 0.5) * segmentAngle;

    setState(() {
      _rotation = Tween<double>(begin: 0, end: target).animate(
        CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
      );
    });
    _controller.reset();
    await _controller.forward();
    final prize = _kSpinPrizes[index];

    if (!mounted) return;
    setState(() {
      _result = prize;
      _spinning = false;
      _alreadySpun = true; // lock this session; prefs marked below
      if (prize.coins > 0) _fireConfetti();
    });

    if (prize.coins > 0) {
      await repo.addCoins(prize.coins);
    }
    await repo.markSpunToday();
    ref.read(spinAvailableTickProvider.notifier).update((v) => v + 1);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20),
      child: ConstrainedBox(
        // Same sizing approach as NicknameDialog: a fixed max width,
        // centred on screen, so the card is exactly the same size in every
        // state (before spin, spinning, result, already-spun) instead of
        // shrink-wrapping to whichever text happens to be showing.
        constraints: const BoxConstraints(maxWidth: 400),
        child: Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.18)
                  : Colors.black.withValues(alpha: 0.16),
              width: 1.6,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.5 : 0.18),
                blurRadius: 28,
                offset: const Offset(0, 14),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(27),
            // Default Stack alignment is topLeft, which left-shifted the
            // wheel/text while idle (narrow Column). After a win the result
            // banner is full-width so the Column stretched and looked centered.
            child: Stack(
              alignment: Alignment.topCenter,
              children: [
                // Fixed-size glow behind the header — same every time, unlike
                // a full-card gradient which shifted with the dialog's height.
                Positioned(
                  top: -74,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: Container(
                      width: 240,
                      height: 240,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            colors.gold.withValues(alpha: isDark ? 0.16 : 0.12),
                            colors.gold.withValues(alpha: 0),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: 6,
                  right: 6,
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () => Navigator.of(context).pop(),
                      borderRadius: BorderRadius.circular(16),
                      child: Padding(
                        padding: const EdgeInsets.all(4),
                        child: Icon(
                          Icons.close_rounded,
                          size: 19,
                          color: colors.secondaryText,
                        ),
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(22, 20, 22, 20),
                  child: SizedBox(
                    width: double.infinity,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                      Transform.translate(
                        offset: const Offset(0, -6),
                        child: Container(
                          width: 60,
                          height: 60,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Color.lerp(colors.gold, Colors.white, 0.38)!,
                                colors.gold,
                                Color.lerp(
                                  colors.gold,
                                  const Color(0xFF8A6A1E),
                                  0.35,
                                )!,
                              ],
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: colors.gold.withValues(alpha: 0.4),
                                blurRadius: 14,
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.card_giftcard_rounded,
                            size: 30,
                            color: Color(0xFF3D2E12),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Daily Spin',
                        style: AppTextStyles.label(
                          fontSize: 21,
                          fontWeight: FontWeight.w800,
                          color: colors.primaryText,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Free coins once a day',
                        style: AppTextStyles.label(
                          fontSize: 13,
                          color: colors.secondaryText,
                        ),
                      ),
                      const SizedBox(height: 18),
                      SizedBox(
                        width: 228,
                        height: 228,
                        child: Stack(
                          alignment: Alignment.center,
                          clipBehavior: Clip.none,
                          children: [
                            Container(
                              width: 228,
                              height: 228,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    colors.gold,
                                    Color.lerp(
                                      colors.gold,
                                      const Color(0xFF8A6A1E),
                                      0.4,
                                    )!,
                                  ],
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: colors.gold.withValues(alpha: 0.3),
                                    blurRadius: 18,
                                    spreadRadius: 1,
                                  ),
                                ],
                              ),
                            ),
                            AnimatedBuilder(
                              animation: _rotation,
                              builder: (context, child) {
                                return Transform.rotate(
                                  angle: _rotation.value,
                                  child: child,
                                );
                              },
                              child: CustomPaint(
                                size: const Size(208, 208),
                                painter: _WheelPainter(
                                  colors: colors,
                                  isDark: isDark,
                                ),
                              ),
                            ),
                            // High-contrast pointer (white outline + red
                            // fill) so it always stands out against the
                            // gold ring, whatever wedge colors sit below it.
                            Positioned(
                              top: -20,
                              child: Stack(
                                alignment: Alignment.topCenter,
                                children: [
                                  const Icon(
                                    Icons.arrow_drop_down_rounded,
                                    size: 68,
                                    color: Colors.white,
                                    shadows: [
                                      Shadow(
                                        color: Colors.black45,
                                        blurRadius: 6,
                                      ),
                                    ],
                                  ),
                                  const Icon(
                                    Icons.arrow_drop_down_rounded,
                                    size: 56,
                                    color: Color(0xFFE5484D),
                                  ),
                                ],
                              ),
                            ),
                            // Confetti burst from the pointer — plays once on a win.
                            IgnorePointer(
                              child: SizedBox(
                                width: 228,
                                height: 228,
                                child: AnimatedBuilder(
                                  animation: _confettiController,
                                  builder: (context, _) {
                                    return CustomPaint(
                                      painter: _ConfettiPainter(
                                        bits: _confetti,
                                        t: _confettiController.value,
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ),
                            // Only the centre hub is tappable — tapping the
                            // colored wedges does nothing.
                            SizedBox(
                              width: 58,
                              height: 58,
                              child: Material(
                                color: Colors.transparent,
                                shape: const CircleBorder(),
                                child: InkWell(
                                  customBorder: const CircleBorder(),
                                  onTap: (_spinning ||
                                          _alreadySpun ||
                                          _result != null)
                                      ? null
                                      : _spin,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 18),
                      if (_result != null)
                        _ResultBanner(prize: _result!, colors: colors)
                      else if (_alreadySpun)
                        Column(
                          children: [
                            Text(
                              'Come back tomorrow!',
                              style: AppTextStyles.label(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: colors.primaryText,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Next spin in ${_formatCountdown(_timeUntilMidnight())}',
                              style: AppTextStyles.label(
                                fontSize: 12,
                                color: colors.secondaryText,
                              ),
                            ),
                          ],
                        )
                      else
                        Text(
                          _spinning ? 'Spinning…' : 'Tap the wheel to spin!',
                          style: AppTextStyles.label(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: colors.secondaryText,
                          ),
                        ),
                      const SizedBox(height: 4),
                    ],
                  ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ResultBanner extends StatelessWidget {
  const _ResultBanner({required this.prize, required this.colors});

  final _SpinPrize prize;
  final AppColorScheme colors;

  @override
  Widget build(BuildContext context) {
    if (prize.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
        decoration: BoxDecoration(
          color: colors.surface2,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Text(
          'No luck today — try again tomorrow!',
          textAlign: TextAlign.center,
          style: AppTextStyles.label(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: colors.secondaryText,
          ),
        ),
      );
    }
    // Light pop-in celebration when the player collects a coin win.
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.86, end: 1),
      duration: const Duration(milliseconds: 480),
      curve: Curves.easeOutBack,
      builder: (context, scale, child) {
        final t = ((scale - 0.86) / 0.14).clamp(0.0, 1.0);
        return Opacity(
          opacity: t,
          child: Transform.scale(scale: scale, child: child),
        );
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          gradient: LinearGradient(
            colors: [
              colors.gold.withValues(alpha: 0.18),
              colors.gold.withValues(alpha: 0.08),
            ],
          ),
          border: Border.all(color: colors.gold.withValues(alpha: 0.4)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Congratulations!',
              textAlign: TextAlign.center,
              style: AppTextStyles.label(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: colors.primaryText,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'You won ${prize.coins} 🪙',
              textAlign: TextAlign.center,
              style: AppTextStyles.label(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: colors.gold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One piece of the win-celebration confetti burst.
class _ConfettiBit {
  const _ConfettiBit({
    required this.angle,
    required this.speed,
    required this.size,
    required this.color,
    required this.spin,
  });

  final double angle;
  final double speed;
  final double size;
  final Color color;
  final double spin;
}

/// Short burst of confetti from the pointer, celebrating a coin win.
class _ConfettiPainter extends CustomPainter {
  _ConfettiPainter({required this.bits, required this.t});

  final List<_ConfettiBit> bits;
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    if (t <= 0 || t >= 1) return;
    final origin = Offset(size.width / 2, 0);
    final fade = (1 - t).clamp(0.0, 1.0);
    final paint = Paint()..style = PaintingStyle.fill;
    for (final bit in bits) {
      final distance = bit.speed * t * size.width * 0.55;
      final fallOffset = 60 * t * t; // gentle gravity arc
      final pos = Offset(
        origin.dx + math.cos(bit.angle) * distance,
        origin.dy + math.sin(bit.angle) * distance + fallOffset,
      );
      paint.color = bit.color.withValues(alpha: fade);
      canvas.save();
      canvas.translate(pos.dx, pos.dy);
      canvas.rotate(bit.spin * t * math.pi);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset.zero,
            width: bit.size,
            height: bit.size * 0.6,
          ),
          const Radius.circular(1.5),
        ),
        paint,
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _ConfettiPainter oldDelegate) =>
      oldDelegate.t != t || oldDelegate.bits != bits;
}

/// Small static preview of the spin wheel, used on the Home icon.
class _MiniWheelPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    const wedgeCount = 8;
    const segmentAngle = (2 * math.pi) / wedgeCount;
    const wedgeColors = [
      Color(0xFF2EC4A6),
      Color(0xFFE2B93B),
      Color(0xFF0F8F7A),
      Color(0xFFE5484D),
      Color(0xFF2EC4A6),
      Color(0xFFE2B93B),
      Color(0xFF0F8F7A),
      Color(0xFF2EC4A6),
    ];

    for (var i = 0; i < wedgeCount; i++) {
      final paint = Paint()
        ..color = wedgeColors[i % wedgeColors.length]
        ..style = PaintingStyle.fill;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        -math.pi / 2 + i * segmentAngle,
        segmentAngle,
        true,
        paint,
      );
    }
    canvas.drawCircle(center, radius * 0.18, Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(covariant _MiniWheelPainter oldDelegate) => false;
}

class _WheelPainter extends CustomPainter {
  _WheelPainter({required this.colors, required this.isDark});

  final AppColorScheme colors;
  final bool isDark;

  static const List<Color> _wedgeColors = [
    Color(0xFFE53935), // red
    Color(0xFFFB8C00), // orange
    Color(0xFFFDD835), // yellow
    Color(0xFF43A047), // green
    Color(0xFF00ACC1), // teal
    Color(0xFF3949AB), // indigo
    Color(0xFF8E24AA), // purple
    Color(0xFFD81B60), // pink
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    final segmentAngle = (2 * math.pi) / _kSpinPrizes.length;

    for (var i = 0; i < _kSpinPrizes.length; i++) {
      final start = -math.pi / 2 + i * segmentAngle;
      final paint = Paint()
        ..color = _wedgeColors[i % _wedgeColors.length]
        ..style = PaintingStyle.fill;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        start,
        segmentAngle,
        true,
        paint,
      );

      final labelAngle = start + segmentAngle / 2;
      final labelOffset = Offset(
        center.dx + math.cos(labelAngle) * radius * 0.64,
        center.dy + math.sin(labelAngle) * radius * 0.64,
      );
      final textPainter = TextPainter(
        text: TextSpan(
          text: _kSpinPrizes[i].label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 15,
            fontWeight: FontWeight.w900,
            shadows: [Shadow(color: Colors.black38, blurRadius: 3)],
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      textPainter.paint(
        canvas,
        labelOffset - Offset(textPainter.width / 2, textPainter.height / 2),
      );
    }

    // Thin white spokes between wedges.
    final spokePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.85)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    for (var i = 0; i < _kSpinPrizes.length; i++) {
      final angle = -math.pi / 2 + i * segmentAngle;
      canvas.drawLine(
        center,
        Offset(
          center.dx + math.cos(angle) * radius,
          center.dy + math.sin(angle) * radius,
        ),
        spokePaint,
      );
    }

    // Carnival-style bulbs around the rim.
    const bulbCount = 16;
    for (var i = 0; i < bulbCount; i++) {
      final angle = (2 * math.pi / bulbCount) * i;
      final bulbCenter = Offset(
        center.dx + math.cos(angle) * radius * 0.94,
        center.dy + math.sin(angle) * radius * 0.94,
      );
      canvas.drawCircle(
        bulbCenter,
        radius * 0.05,
        Paint()..color = i.isEven ? Colors.white : colors.gold,
      );
    }

    // Outer ring.
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = colors.gold
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4,
    );

    // Centre hub with "Spin" text.
    final hubRadius = radius * 0.26;
    canvas.drawCircle(
      center,
      hubRadius,
      Paint()
        ..shader = RadialGradient(
          colors: [Color.lerp(colors.gold, Colors.white, 0.5)!, colors.gold],
        ).createShader(Rect.fromCircle(center: center, radius: hubRadius)),
    );
    canvas.drawCircle(
      center,
      hubRadius,
      Paint()
        ..color = Color.lerp(colors.gold, const Color(0xFF8A6A1E), 0.5)!
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5,
    );
    final hubText = TextPainter(
      text: const TextSpan(
        text: 'Spin',
        style: TextStyle(
          color: Color(0xFF3D2E12),
          fontSize: 15,
          fontWeight: FontWeight.w900,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    hubText.paint(
      canvas,
      center - Offset(hubText.width / 2, hubText.height / 2),
    );
  }

  @override
  bool shouldRepaint(covariant _WheelPainter oldDelegate) => false;
}
