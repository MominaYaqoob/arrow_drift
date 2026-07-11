import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:arrow_drift/core/theme/app_theme.dart';
import 'package:arrow_drift/data/models/arrow_model.dart';
import 'package:arrow_drift/features/gameplay/widgets/arrow_tile.dart';

/// Level-complete celebration — teal burst, continuous confetti, staggered UI.
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
    this.isCampaignComplete = false,
  });

  final int completedLevel;
  final int nextLevelNumber;
  final List<ArrowModel> previewArrows;
  final int gridRows;
  final int gridCols;
  final VoidCallback onNextGame;
  final VoidCallback onMain;
  final bool isCampaignComplete;

  @override
  State<LevelCompletedOverlay> createState() => _LevelCompletedOverlayState();
}

class _LevelCompletedOverlayState extends State<LevelCompletedOverlay>
    with TickerProviderStateMixin {
  late final AnimationController _bgController;
  late final AnimationController _titleController;
  late final AnimationController _cardController;
  late final AnimationController _buttonController;
  late final AnimationController _mainController;
  late final AnimationController _confettiController;
  late final AnimationController _pressController;

  late final Animation<double> _bgOpacity;
  late final Animation<double> _titleOpacity;
  late final Animation<double> _titleSlideY;
  late final Animation<double> _cardScale;
  late final Animation<double> _buttonOpacity;
  late final Animation<double> _buttonSlideY;
  late final Animation<double> _mainOpacity;
  late final Animation<double> _pressScale;
  late final List<_ConfettiParticle> _particles;

  bool _navigating = false;

  @override
  void initState() {
    super.initState();

    // 1) Background fade/cut onto teal burst
    _bgController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
    );
    _bgOpacity = CurvedAnimation(parent: _bgController, curve: Curves.easeOut);

    // 2) Title: fade + slide down from 10px above
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

    // 3) Card: scale 0 → 1.1 → 1.0 (bouncy)
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

    // 4) Continue button: slide up + fade
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

    // Press feedback: 1.0 → 0.96 → 1.0 (~100ms total)
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

    // 5) Main: subtle fade last
    _mainController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
    );
    _mainOpacity = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _mainController, curve: Curves.easeOut),
    );

    // Continuous confetti for the whole time this screen is visible
    _confettiController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2800),
    )..repeat();

    final rng = math.Random(42);
    _particles = List.generate(88, (i) {
      const colors = [
        Color(0xFFFF4D8D), // pink
        Color(0xFFFFD93D), // yellow
        Color(0xFF2EC4A6), // teal
        Color(0xFF5BE0C8), // light teal
        Color(0xFF4DDCFF), // cyan/blue accent
        Color(0xFF7CFF4D), // lime
        Color(0xFFFF8A5B), // orange
        Colors.white,
      ];
      return _ConfettiParticle(
        x: rng.nextDouble(),
        startY: -0.35 - rng.nextDouble() * 0.7,
        speed: 0.18 + rng.nextDouble() * 0.55,
        drift: (rng.nextDouble() - 0.5) * 0.32,
        size: Size(5 + rng.nextDouble() * 8, 9 + rng.nextDouble() * 14),
        color: colors[i % colors.length],
        spin: (rng.nextDouble() - 0.5) * 10,
        phase: rng.nextDouble(),
      );
    });

    // Stagger: ~200–300ms between each beat
    _bgController.forward();
    Future<void>.delayed(const Duration(milliseconds: 80), () {
      if (mounted) _titleController.forward();
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
    _cardController.dispose();
    _buttonController.dispose();
    _mainController.dispose();
    _confettiController.dispose();
    _pressController.dispose();
    super.dispose();
  }

  Future<void> _onContinuePressed() async {
    if (_navigating) return;
    _navigating = true;

    await _pressController.forward(from: 0);

    // Fade out teal bg + confetti before navigating (~250ms).
    _confettiController.stop();
    _bgController.duration = const Duration(milliseconds: 250);
    await _bgController.reverse();
    if (!mounted) return;
    widget.onNextGame();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: FadeTransition(
        opacity: _bgOpacity,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Teal radial burst (replaces blue)
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment(0, -0.08),
                  radius: 1.2,
                  colors: [
                    Color(0xFF7EEFD8), // light teal center
                    Color(0xFF2EC4A6), // AppColors.accentTeal
                    Color(0xFF0F8F7A), // AppColors.accentTealDeep
                    Color(0xFF0A6B5C), // deeper edge
                  ],
                  stops: [0.0, 0.35, 0.7, 1.0],
                ),
              ),
            ),
            CustomPaint(painter: _SunburstPainter()),
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
                      child: Text(
                        'Level Completed!',
                        textAlign: TextAlign.center,
                        style: AppTextStyles.body(
                          fontSize: 30,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(height: 28),
                    AnimatedBuilder(
                      animation: _cardController,
                      builder: (context, child) {
                        return Transform.scale(
                          scale: _cardScale.value,
                          child: child,
                        );
                      },
                      child: _SolvedPreviewCard(
                        arrows: widget.previewArrows,
                        gridRows: widget.gridRows,
                        gridCols: widget.gridCols,
                      ),
                    ),
                    const Spacer(flex: 3),
                    AnimatedBuilder(
                      animation: Listenable.merge([
                        _buttonController,
                        _mainController,
                        _pressController,
                      ]),
                      builder: (context, _) {
                        return Column(
                          children: [
                            Opacity(
                              opacity: _buttonOpacity.value,
                              child: Transform.translate(
                                offset: Offset(0, _buttonSlideY.value),
                                child: Transform.scale(
                                  scale: _pressScale.value,
                                  child: SizedBox(
                                    width: double.infinity,
                                    child: Material(
                                      color: const Color(0xFFF2F2F2),
                                      borderRadius: BorderRadius.circular(40),
                                      elevation: 1,
                                      shadowColor: Colors.black26,
                                      child: InkWell(
                                        onTap: widget.isCampaignComplete
                                            ? widget.onMain
                                            : _onContinuePressed,
                                        borderRadius: BorderRadius.circular(40),
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(
                                            vertical: 16,
                                          ),
                                          child: Column(
                                            children: [
                                              Text(
                                                widget.isCampaignComplete
                                                    ? 'Main'
                                                    : 'Continue',
                                                style: AppTextStyles.button(
                                                  fontSize: 18,
                                                  fontWeight: FontWeight.w800,
                                                  color: const Color(0xFF1A2740),
                                                ),
                                              ),
                                              if (!widget.isCampaignComplete) ...[
                                                const SizedBox(height: 2),
                                                Text(
                                                  'Level ${widget.nextLevelNumber}',
                                                  style: AppTextStyles.body(
                                                    fontSize: 13,
                                                    fontWeight: FontWeight.w500,
                                                    color:
                                                        const Color(0xFF5A8A80),
                                                  ),
                                                ),
                                              ],
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            if (!widget.isCampaignComplete) ...[
                              const SizedBox(height: 16),
                              Opacity(
                                opacity: _mainOpacity.value,
                                child: TextButton(
                                  onPressed: widget.onMain,
                                  child: Text(
                                    'Main',
                                    style: AppTextStyles.body(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 28),
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

class _SolvedPreviewCard extends StatelessWidget {
  const _SolvedPreviewCard({
    required this.arrows,
    required this.gridRows,
    required this.gridCols,
  });

  final List<ArrowModel> arrows;
  final int gridRows;
  final int gridCols;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 200,
      height: 200,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: CustomPaint(
        painter: _MiniBoardPainter(
          arrows: arrows,
          gridRows: gridRows,
          gridCols: gridCols,
        ),
      ),
    );
  }
}

class _MiniBoardPainter extends CustomPainter {
  _MiniBoardPainter({
    required this.arrows,
    required this.gridRows,
    required this.gridCols,
  });

  final List<ArrowModel> arrows;
  final int gridRows;
  final int gridCols;

  @override
  void paint(Canvas canvas, Size size) {
    if (arrows.isEmpty) return;

      // Always prefer real grid path preview when grid size is known.
      if (gridRows > 0 && gridCols > 0) {
        _paintPathBoard(canvas, size);
        return;
      }

    final ordered = [...arrows]..sort((a, b) {
        final c = a.col.compareTo(b.col);
        return c != 0 ? c : a.row.compareTo(b.row);
      });

    final n = ordered.length;
    final gap = size.width / (n + 1);
    final strokeW = (size.height * 0.055).clamp(3.5, 6.5);
    final shaftLen = size.height * 0.68;

    for (var i = 0; i < n; i++) {
      final arrow = ordered[i];
      final cx = gap * (i + 1);
      final cy = size.height / 2;

      late Offset tip;
      late Offset tail;
      switch (arrow.direction) {
        case ArrowDirection.up:
          tip = Offset(cx, cy - shaftLen / 2);
          tail = Offset(cx, cy + shaftLen / 2);
        case ArrowDirection.down:
          tip = Offset(cx, cy + shaftLen / 2);
          tail = Offset(cx, cy - shaftLen / 2);
        case ArrowDirection.left:
          tip = Offset(cx - shaftLen / 2, cy);
          tail = Offset(cx + shaftLen / 2, cy);
        case ArrowDirection.right:
          tip = Offset(cx + shaftLen / 2, cy);
          tail = Offset(cx - shaftLen / 2, cy);
      }

      final unit = tip - tail;
      final len = unit.distance;
      final dir = len == 0 ? Offset.zero : unit / len;
      final headLen = strokeW * 1.55;
      final shaftEnd = tip - dir * (headLen * 0.55);

      canvas.drawLine(
        tail,
        shaftEnd,
        Paint()
          ..color = ArrowTile.referenceArrowColor
          ..strokeWidth = strokeW
          ..strokeCap = StrokeCap.round
          ..style = PaintingStyle.stroke,
      );

      final angle = switch (arrow.direction) {
        ArrowDirection.up => -math.pi / 2,
        ArrowDirection.down => math.pi / 2,
        ArrowDirection.left => math.pi,
        ArrowDirection.right => 0.0,
      };
      Offset rot(double x, double y) {
        final c = math.cos(angle);
        final s = math.sin(angle);
        return Offset(tip.dx + x * c - y * s, tip.dy + x * s + y * c);
      }

      final headHalf = strokeW * 1.15;
      final head = Path()
        ..moveTo(tip.dx, tip.dy)
        ..lineTo(rot(-headLen, -headHalf).dx, rot(-headLen, -headHalf).dy)
        ..lineTo(rot(-headLen, headHalf).dx, rot(-headLen, headHalf).dy)
        ..close();
      canvas.drawPath(
        head,
        Paint()
          ..color = ArrowTile.referenceArrowColor
          ..style = PaintingStyle.fill,
      );
    }
  }

  void _paintPathBoard(Canvas canvas, Size size) {
    final cellW = size.width / gridCols;
    final cellH = size.height / gridRows;
    final cell = math.min(cellW, cellH);

    // Dots behind paths (same feel as gameplay nested boards).
    final dotPaint = Paint()
      ..color = const Color(0xFFB8B0A0).withValues(alpha: 0.55);
    final dotR = (cell * 0.04).clamp(1.2, 2.2);
    for (var r = 0; r <= gridRows; r++) {
      for (var c = 0; c <= gridCols; c++) {
        canvas.drawCircle(Offset(c * cellW, r * cellH), dotR, dotPaint);
      }
    }

    // Medium weight — readable but not overly thick.
    final strokeW = (cell * 0.26).clamp(3.5, 6.5);
    final headLen = strokeW * 2.2;
    final headHalf = strokeW * 1.1;

    for (final arrow in arrows) {
      final cells = arrow.path.isNotEmpty
          ? arrow.path
          : [GridCell(arrow.row, arrow.col)];

      late final List<Offset> points;
      if (cells.length == 1) {
        final cx = (cells.first.col + 0.5) * cellW;
        final cy = (cells.first.row + 0.5) * cellH;
        final half = cell * 0.38;
        final tip = Offset(cx, cy) +
            switch (arrow.direction) {
              ArrowDirection.up => Offset(0, -half),
              ArrowDirection.down => Offset(0, half),
              ArrowDirection.left => Offset(-half, 0),
              ArrowDirection.right => Offset(half, 0),
            };
        final tail = Offset(cx, cy) -
            switch (arrow.direction) {
              ArrowDirection.up => Offset(0, -half),
              ArrowDirection.down => Offset(0, half),
              ArrowDirection.left => Offset(-half, 0),
              ArrowDirection.right => Offset(half, 0),
            };
        points = [tail, tip];
      } else {
        points = [
          for (final c in cells)
            Offset((c.col + 0.5) * cellW, (c.row + 0.5) * cellH),
        ];
        final tip = points.last;
        final nudge = cell * 0.32;
        points.add(
          tip +
              switch (arrow.direction) {
                ArrowDirection.up => Offset(0, -nudge),
                ArrowDirection.down => Offset(0, nudge),
                ArrowDirection.left => Offset(-nudge, 0),
                ArrowDirection.right => Offset(nudge, 0),
              },
        );
      }

      final tip = points.last;
      final prev = points[points.length - 2];
      final unit = tip - prev;
      final len = unit.distance;
      final dir = len == 0 ? Offset.zero : unit / len;
      final shaftEnd = tip - dir * (headLen * 0.45);

      final path = Path()..moveTo(points.first.dx, points.first.dy);
      for (var i = 1; i < points.length - 1; i++) {
        path.lineTo(points[i].dx, points[i].dy);
      }
      path.lineTo(shaftEnd.dx, shaftEnd.dy);

      canvas.drawPath(
        path,
        Paint()
          ..color = ArrowTile.referenceArrowColor
          ..strokeWidth = strokeW
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..style = PaintingStyle.stroke
          ..isAntiAlias = true,
      );

      final angle = switch (arrow.direction) {
        ArrowDirection.up => -math.pi / 2,
        ArrowDirection.down => math.pi / 2,
        ArrowDirection.left => math.pi,
        ArrowDirection.right => 0.0,
      };
      Offset rot(double x, double y) {
        final c = math.cos(angle);
        final s = math.sin(angle);
        return Offset(tip.dx + x * c - y * s, tip.dy + x * s + y * c);
      }

      final head = Path()
        ..moveTo(tip.dx, tip.dy)
        ..lineTo(rot(-headLen, -headHalf).dx, rot(-headLen, -headHalf).dy)
        ..lineTo(rot(-headLen, headHalf).dx, rot(-headLen, headHalf).dy)
        ..close();
      canvas.drawPath(
        head,
        Paint()
          ..color = ArrowTile.referenceArrowColor
          ..style = PaintingStyle.fill
          ..isAntiAlias = true,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _MiniBoardPainter oldDelegate) =>
      oldDelegate.arrows != arrows ||
      oldDelegate.gridRows != gridRows ||
      oldDelegate.gridCols != gridCols;
}

class _SunburstPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height * 0.42);
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.08)
      ..style = PaintingStyle.fill;
    const rays = 18;
    final radius = size.longestSide;
    for (var i = 0; i < rays; i++) {
      final a0 = (i / rays) * math.pi * 2;
      final a1 = ((i + 0.42) / rays) * math.pi * 2;
      final path = Path()
        ..moveTo(center.dx, center.dy)
        ..lineTo(
          center.dx + math.cos(a0) * radius,
          center.dy + math.sin(a0) * radius,
        )
        ..lineTo(
          center.dx + math.cos(a1) * radius,
          center.dy + math.sin(a1) * radius,
        )
        ..close();
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
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
  });

  final double x;
  final double startY;
  final double speed;
  final double drift;
  final Size size;
  final Color color;
  final double spin;
  final double phase;
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
      canvas.rotate(cycle * p.spin);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset.zero,
            width: p.size.width,
            height: p.size.height,
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
      oldDelegate.t != t;
}
