import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:arrow_drift/core/theme/app_theme.dart';
import 'package:arrow_drift/core/widgets/app_logo.dart';
import 'package:arrow_drift/data/models/arrow_model.dart';

/// Level-complete celebration — dark teal win screen with logo (no white card).
/// Callbacks unchanged; [previewArrows] kept for call-site compatibility.
class LevelCompletedOverlay extends StatefulWidget {
  const LevelCompletedOverlay({
    super.key,
    required this.completedLevel,
    required this.nextLevelNumber,
    required this.previewArrows,
    required this.gridRows,
    required this.gridCols,
    required this.onNextGame,
    required this.onMain,
    this.heartsLeft,
    this.heartsAllowed,
    this.isCampaignComplete = false,
    this.isDaily = false,
    this.coinsEarned,
  });

  final int completedLevel;
  final int nextLevelNumber;
  final List<ArrowModel> previewArrows;
  final int gridRows;
  final int gridCols;
  final VoidCallback onNextGame;
  final VoidCallback onMain;
  final int? heartsLeft;
  final int? heartsAllowed;
  final bool isCampaignComplete;
  final bool isDaily;
  final int? coinsEarned;

  @override
  State<LevelCompletedOverlay> createState() => _LevelCompletedOverlayState();
}

class _LevelCompletedOverlayState extends State<LevelCompletedOverlay>
    with TickerProviderStateMixin {
  late final AnimationController _bgController;
  late final AnimationController _titleController;
  late final AnimationController _praiseController;
  late final AnimationController _emojiBounceController;
  late final AnimationController _cardController;
  late final AnimationController _buttonController;
  late final AnimationController _mainController;
  late final AnimationController _confettiController;
  late final AnimationController _pressController;
  AnimationController? _logoPulseController;
  Animation<double>? _logoPulse;

  late final Animation<double> _bgOpacity;
  late final Animation<double> _titleOpacity;
  late final Animation<double> _titleSlideY;
  late final Animation<double> _praiseOpacity;
  late final Animation<double> _praiseScale;
  late final Animation<double> _emojiBounce;
  late final Animation<double> _cardScale;
  late final Animation<double> _buttonOpacity;
  late final Animation<double> _buttonSlideY;
  late final Animation<double> _mainOpacity;
  late final Animation<double> _pressScale;
  late final List<_ConfettiParticle> _particles;
  late final ({String text, String emoji}) _praise;

  bool _navigating = false;

  static ({String text, String emoji}) _pickPraise({
    required int completedLevel,
    int? heartsLeft,
    int? heartsAllowed,
    required bool campaignComplete,
  }) {
    if (campaignComplete) {
      return (text: 'Excellent!', emoji: '🏆');
    }
    final left = heartsLeft;
    final allowed = heartsAllowed;
    if (left != null && allowed != null && allowed > 0) {
      if (left >= allowed) {
        return (text: 'Excellent!', emoji: '🌟');
      }
      if (left >= (allowed / 2).ceil()) {
        return (text: 'Amazing!', emoji: '🤩');
      }
      return (text: 'Good!', emoji: '👍');
    }
    const pool = [
      (text: 'Good!', emoji: '👍'),
      (text: 'Amazing!', emoji: '🤩'),
      (text: 'Excellent!', emoji: '🌟'),
    ];
    return pool[(completedLevel - 1) % pool.length];
  }

  void _ensureLogoPulse() {
    if (_logoPulseController != null) return;
    _logoPulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);
    _logoPulse = Tween<double>(begin: 1.0, end: 1.1).animate(
      CurvedAnimation(
        parent: _logoPulseController!,
        curve: Curves.easeInOut,
      ),
    );
  }

  @override
  void initState() {
    super.initState();

    _praise = _pickPraise(
      completedLevel: widget.completedLevel,
      heartsLeft: widget.heartsLeft,
      heartsAllowed: widget.heartsAllowed,
      campaignComplete: widget.isCampaignComplete,
    );

    _bgController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
    );
    _bgOpacity = CurvedAnimation(parent: _bgController, curve: Curves.easeOut);

    _titleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    );
    _titleOpacity = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _titleController, curve: Curves.easeOut),
    );
    _titleSlideY = Tween<double>(begin: -10, end: 0).animate(
      CurvedAnimation(parent: _titleController, curve: Curves.easeOut),
    );

    _praiseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 520),
    );
    _praiseOpacity = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _praiseController,
        curve: const Interval(0, 0.45, curve: Curves.easeOut),
      ),
    );
    _praiseScale = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(begin: 0.4, end: 1.18)
            .chain(CurveTween(curve: Curves.easeOutBack)),
        weight: 70,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 1.18, end: 1.0)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 30,
      ),
    ]).animate(_praiseController);

    _emojiBounceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _emojiBounce = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(begin: 0.0, end: -14.0)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 40,
      ),
      TweenSequenceItem(
        tween: Tween(begin: -14.0, end: 0.0)
            .chain(CurveTween(curve: Curves.bounceOut)),
        weight: 60,
      ),
    ]).animate(_emojiBounceController);

    _cardController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 560),
    );
    _cardScale = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(begin: 0.0, end: 1.1)
            .chain(CurveTween(curve: Curves.easeOutCubic)),
        weight: 65,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 1.1, end: 1.0)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 35,
      ),
    ]).animate(_cardController);

    _buttonController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 340),
    );
    _buttonOpacity = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _buttonController, curve: Curves.easeOut),
    );
    _buttonSlideY = Tween<double>(begin: 18, end: 0).animate(
      CurvedAnimation(parent: _buttonController, curve: Curves.easeOutCubic),
    );

    _pressController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );
    _pressScale = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.96), weight: 1),
      TweenSequenceItem(tween: Tween(begin: 0.96, end: 1.0), weight: 1),
    ]).animate(
      CurvedAnimation(parent: _pressController, curve: Curves.easeOut),
    );

    _mainController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
    );
    _mainOpacity = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _mainController, curve: Curves.easeOut),
    );

    _ensureLogoPulse();

    _confettiController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2800),
    )..repeat();

    final rng = math.Random(42);
    _particles = List.generate(72, (i) {
      const colors = [
        Color(0xFF2EC4A6),
        Color(0xFFE0B13A),
        Color(0xFF7DE2C8),
        Color(0xFFF0C86B),
        Color(0xFFB8F0E4),
        Colors.white,
      ];
      final circle = i.isEven;
      return _ConfettiParticle(
        x: rng.nextDouble(),
        startY: -0.35 - rng.nextDouble() * 0.7,
        speed: 0.18 + rng.nextDouble() * 0.55,
        drift: (rng.nextDouble() - 0.5) * 0.28,
        size: circle
            ? Size(4 + rng.nextDouble() * 3, 4 + rng.nextDouble() * 3)
            : Size(5 + rng.nextDouble() * 5, 8 + rng.nextDouble() * 8),
        color: colors[i % colors.length],
        spin: (rng.nextDouble() - 0.5) * 8,
        phase: rng.nextDouble(),
        circle: circle,
      );
    });

    _bgController.forward();
    Future<void>.delayed(const Duration(milliseconds: 80), () {
      if (mounted) _titleController.forward();
    });
    Future<void>.delayed(const Duration(milliseconds: 200), () {
      if (!mounted) return;
      _praiseController.forward();
      _emojiBounceController.forward();
    });
    Future<void>.delayed(const Duration(milliseconds: 900), () {
      if (!mounted) return;
      _emojiBounceController.repeat();
    });
    Future<void>.delayed(const Duration(milliseconds: 280), () {
      if (mounted) _cardController.forward();
    });
    Future<void>.delayed(const Duration(milliseconds: 580), () {
      if (mounted) _buttonController.forward();
    });
    Future<void>.delayed(const Duration(milliseconds: 820), () {
      if (mounted) _mainController.forward();
    });
  }

  @override
  void dispose() {
    _bgController.dispose();
    _titleController.dispose();
    _praiseController.dispose();
    _emojiBounceController.dispose();
    _cardController.dispose();
    _buttonController.dispose();
    _mainController.dispose();
    _confettiController.dispose();
    _pressController.dispose();
    _logoPulseController?.dispose();
    super.dispose();
  }

  Future<void> _onContinuePressed() async {
    if (_navigating) return;
    _navigating = true;

    await _pressController.forward(from: 0);

    _confettiController.stop();
    _emojiBounceController.stop();
    _logoPulseController?.stop();
    _bgController.duration = const Duration(milliseconds: 250);
    await _bgController.reverse();
    if (!mounted) return;
    widget.onNextGame();
  }

  @override
  Widget build(BuildContext context) {
    _ensureLogoPulse();
    final colors = context.appColors;
    final logoListenable = _logoPulseController;

    return Material(
      color: Colors.transparent,
      child: FadeTransition(
        opacity: _bgOpacity,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Dark navy / teal radial win backdrop.
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment(0, -0.32),
                  radius: 1.2,
                  colors: [
                    Color(0xFF1C554C),
                    Color(0xFF123A40),
                    Color(0xFF0E1726),
                    Color(0xFF090F18),
                  ],
                  stops: [0.0, 0.28, 0.62, 1.0],
                ),
              ),
            ),
            // Soft spotlight behind logo / title.
            Positioned(
              top: MediaQuery.sizeOf(context).height * 0.18,
              left: 0,
              right: 0,
              child: IgnorePointer(
                child: Center(
                  child: Container(
                    width: 220,
                    height: 220,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          const Color(0xFF2EC4A6).withValues(alpha: 0.22),
                          const Color(0xFF2EC4A6).withValues(alpha: 0.0),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Positioned.fill(
              child: AnimatedBuilder(
                animation: _confettiController,
                builder: (context, _) {
                  return CustomPaint(
                    painter: _ConfettiPainter(
                      particles: _particles,
                      t: _confettiController.value,
                    ),
                  );
                },
              ),
            ),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 28),
                child: Column(
                  children: [
                    const Spacer(flex: 2),
                    AnimatedBuilder(
                      animation: _titleController,
                      builder: (context, child) {
                        return Opacity(
                          opacity: _titleOpacity.value,
                          child: Transform.translate(
                            offset: Offset(0, _titleSlideY.value),
                            child: child,
                          ),
                        );
                      },
                      child: Column(
                        children: [
                          Text(
                            widget.isDaily
                                ? 'Daily Challenge Completed'
                                : 'Level Completed!',
                            textAlign: TextAlign.center,
                            style: AppTextStyles.heading(
                              fontSize: widget.isDaily ? 24 : 30,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                              letterSpacing: -0.4,
                            ).copyWith(
                              shadows: [
                                Shadow(
                                  color: Colors.black.withValues(alpha: 0.35),
                                  blurRadius: 12,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                            ),
                          ),
                          if (!widget.isDaily && !widget.isCampaignComplete) ...[
                            const SizedBox(height: 10),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 5,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(999),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.14),
                                ),
                              ),
                              child: Text(
                                'Level ${widget.completedLevel}',
                                style: AppTextStyles.label(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white.withValues(alpha: 0.78),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    AnimatedBuilder(
                      animation: Listenable.merge([
                        _praiseController,
                        _emojiBounceController,
                      ]),
                      builder: (context, _) {
                        return Opacity(
                          opacity: _praiseOpacity.value,
                          child: Transform.scale(
                            scale: _praiseScale.value,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Transform.translate(
                                  offset: Offset(0, _emojiBounce.value),
                                  child: Text(
                                    _praise.emoji,
                                    style: const TextStyle(fontSize: 34),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Text(
                                  _praise.text,
                                  style: AppTextStyles.heading(
                                    fontSize: 26,
                                    fontWeight: FontWeight.w800,
                                    color: const Color(0xFF3DDCB8),
                                    letterSpacing: -0.3,
                                  ).copyWith(
                                    shadows: [
                                      Shadow(
                                        color: const Color(0xFF2EC4A6)
                                            .withValues(alpha: 0.45),
                                        blurRadius: 16,
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Transform.translate(
                                  offset: Offset(0, _emojiBounce.value),
                                  child: Text(
                                    _praise.emoji,
                                    style: const TextStyle(fontSize: 34),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                    if (widget.coinsEarned != null) ...[
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: colors.gold.withValues(alpha: 0.16),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(color: colors.gold, width: 1),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.monetization_on_rounded,
                              size: 16,
                              color: colors.gold,
                            ),
                            const SizedBox(width: 5),
                            Text(
                              '+${widget.coinsEarned} coins',
                              style: AppTextStyles.label(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                color: colors.gold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 28),
                    AnimatedBuilder(
                      animation: Listenable.merge([
                        _cardController,
                        ?logoListenable,
                      ]),
                      builder: (context, _) {
                        return Transform.scale(
                          scale: _cardScale.value,
                          child: Transform.scale(
                            scale: _logoPulse?.value ?? 1.0,
                            child: Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(28),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFF2EC4A6)
                                        .withValues(alpha: 0.28),
                                    blurRadius: 28,
                                    spreadRadius: 2,
                                  ),
                                ],
                              ),
                              child: const AppLogoMark(size: 118),
                            ),
                          ),
                        );
                      },
                    ),
                    const Spacer(flex: 3),
                    AnimatedBuilder(
                      animation: Listenable.merge([
                        _buttonController,
                        _mainController,
                        _pressController,
                        ?logoListenable,
                      ]),
                      builder: (context, _) {
                        final pulse = _logoPulse?.value ?? 1.0;
                        return Column(
                          children: [
                            Opacity(
                              opacity: _buttonOpacity.value,
                              child: Transform.translate(
                                offset: Offset(0, _buttonSlideY.value),
                                child: Transform.scale(
                                  scale: _pressScale.value *
                                      (0.97 + 0.03 * pulse),
                                  child: Container(
                                    width: double.infinity,
                                    height: 56,
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(999),
                                      boxShadow: [
                                        BoxShadow(
                                          color: const Color(0xFF2EC4A6)
                                              .withValues(alpha: 0.28),
                                          blurRadius: 18,
                                          offset: const Offset(0, 6),
                                        ),
                                        BoxShadow(
                                          color: Colors.black
                                              .withValues(alpha: 0.25),
                                          blurRadius: 10,
                                          offset: const Offset(0, 4),
                                        ),
                                      ],
                                    ),
                                    child: Material(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(999),
                                      child: InkWell(
                                        onTap: widget.isCampaignComplete
                                            ? widget.onMain
                                            : _onContinuePressed,
                                        borderRadius:
                                            BorderRadius.circular(999),
                                        child: Center(
                                          child: Text(
                                            widget.isCampaignComplete
                                                ? 'Main'
                                                : 'Continue',
                                            style: AppTextStyles.button(
                                              fontSize: 18,
                                              fontWeight: FontWeight.w800,
                                              color: AppColors.lightPrimaryText,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            if (!widget.isCampaignComplete) ...[
                              const SizedBox(height: 14),
                              Opacity(
                                opacity: _mainOpacity.value,
                                child: Material(
                                  color: Colors.transparent,
                                  child: InkWell(
                                    onTap: widget.onMain,
                                    borderRadius: BorderRadius.circular(999),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 22,
                                        vertical: 10,
                                      ),
                                      decoration: BoxDecoration(
                                        borderRadius:
                                            BorderRadius.circular(999),
                                        border: Border.all(
                                          color: Colors.white
                                              .withValues(alpha: 0.22),
                                        ),
                                        color: Colors.white
                                            .withValues(alpha: 0.06),
                                      ),
                                      child: Text(
                                        'Main',
                                        style: AppTextStyles.body(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.white
                                              .withValues(alpha: 0.92),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ConfettiParticle {
  const _ConfettiParticle({
    required this.x,
    required this.startY,
    required this.speed,
    required this.drift,
    required this.size,
    required this.color,
    required this.spin,
    required this.phase,
    this.circle = false,
  });

  final double x;
  final double startY;
  final double speed;
  final double drift;
  final Size size;
  final Color color;
  final double spin;
  final double phase;
  final bool circle;
}

class _ConfettiPainter extends CustomPainter {
  _ConfettiPainter({
    required this.particles,
    required this.t,
  });

  final List<_ConfettiParticle> particles;
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;
    for (final p in particles) {
      final cycle = (t + p.phase) % 1.0;
      final y = (p.startY + cycle * (1.45 + p.speed)) * size.height;
      final x = (p.x + math.sin(cycle * math.pi * 2) * p.drift) * size.width;
      paint.color = p.color;
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(p.spin * cycle * math.pi);
      if (p.circle) {
        canvas.drawCircle(Offset.zero, p.size.width / 2, paint);
      } else {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(
              center: Offset.zero,
              width: p.size.width,
              height: p.size.height,
            ),
            const Radius.circular(2),
          ),
          paint,
        );
      }
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _ConfettiPainter oldDelegate) =>
      oldDelegate.t != t;
}
