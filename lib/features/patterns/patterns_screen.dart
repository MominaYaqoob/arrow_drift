import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:arrow_drift/core/theme/app_theme.dart';
import 'package:arrow_drift/data/models/arrow_model.dart';
import 'package:arrow_drift/data/models/level_model.dart';
import 'package:arrow_drift/data/repositories/shape_masks.dart';
import 'package:arrow_drift/data/repositories/synthetic_arrows.dart';
import 'package:arrow_drift/features/patterns/pattern_preview_screen.dart';

/// Dummy pattern gallery — static UI only, no unlock / data logic.
class PatternsScreen extends StatelessWidget {
  const PatternsScreen({super.key});

  static const String routePath = '/patterns';

  static const int _totalLevels = 200;
  static const int _unlockedThrough = 50;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: DecoratedBox(
        decoration: BoxDecoration(
          color: colors.background,
          gradient: RadialGradient(
            center: const Alignment(0.85, -0.85),
            radius: 1.1,
            colors: [
              colors.accentTeal.withValues(alpha: isDark ? 0.14 : 0.14),
              colors.background,
            ],
            stops: const [0.0, 0.45],
          ),
        ),
        child: SafeArea(
          bottom: false,
          child: Column(
            children: [
              Expanded(
                child: CustomScrollView(
                  physics: const BouncingScrollPhysics(),
                  slivers: [
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                      sliver: SliverToBoxAdapter(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Level Patterns',
                              style: AppTextStyles.heading(
                                fontSize: 28,
                                fontWeight: FontWeight.w700,
                                color: colors.primaryText,
                                letterSpacing: -0.4,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Collect shapes as you clear levels',
                              style: AppTextStyles.body(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: colors.secondaryText,
                              ),
                            ),
                            const SizedBox(height: 18),
                          ],
                        ),
                      ),
                    ),
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                      sliver: SliverGrid(
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          crossAxisSpacing: 10,
                          mainAxisSpacing: 10,
                          childAspectRatio: 0.72,
                        ),
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            final level = index + 1;
                            return _PatternCard(
                              level: level,
                              locked: level > _unlockedThrough,
                            );
                          },
                          childCount: _totalLevels,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: _UnlockPromoBanner(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PatternCard extends StatelessWidget {
  const _PatternCard({required this.level, required this.locked});

  final int level;
  final bool locked;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final borderColor = locked ? colors.border : colors.accentTealDeep;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: locked
            ? () {
                ScaffoldMessenger.of(context)
                  ..hideCurrentSnackBar()
                  ..showSnackBar(
                    const SnackBar(
                      content: Text('Coming soon'),
                      behavior: SnackBarBehavior.floating,
                      duration: Duration(seconds: 2),
                    ),
                  );
              }
            : () => context.push(
                  PatternPreviewScreen.routePath,
                  extra: level,
                ),
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: borderColor,
              width: 5,
            ),
            boxShadow: [
              BoxShadow(
                color: (locked ? colors.border : colors.accentTealDeep)
                    .withValues(alpha: isDark ? 0.28 : 0.18),
                blurRadius: 12,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(5),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: isDark ? colors.surface2 : colors.background,
                borderRadius: BorderRadius.circular(11),
                border: Border.all(
                  color: locked
                      ? colors.border
                      : colors.accentTeal.withValues(alpha: 0.28),
                  width: 1.2,
                ),
              ),
              child: Stack(
                clipBehavior: Clip.antiAlias,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(6, 8, 6, 8),
                    child: Column(
                      children: [
                        Text(
                          'Level $level',
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.label(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: locked
                                ? colors.secondaryText
                                : colors.primaryText,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Expanded(
                          child: locked
                              ? const SizedBox.expand()
                              : level >= 1 && level <= 50
                                  ? _ShapeCardPreview(
                                      maskBuilder: () =>
                                          _maskForGalleryLevel(level),
                                      seed: level,
                                    )
                                  : _DummyMazePreview(
                                      seed: level,
                                      teal: colors.accentTeal,
                                      tealDeep: colors.accentTealDeep,
                                    ),
                        ),
                      ],
                    ),
                  ),
                  if (locked)
                    Positioned.fill(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: colors.surface2.withValues(alpha: 0.9),
                          borderRadius: BorderRadius.circular(11),
                        ),
                        child: Column(
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Text(
                                'Level $level',
                                textAlign: TextAlign.center,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppTextStyles.label(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: colors.secondaryText,
                                ),
                              ),
                            ),
                            Expanded(
                              child: Icon(
                                Icons.lock_rounded,
                                size: 32,
                                color: colors.secondaryText,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    Positioned(
                      right: 6,
                      bottom: 6,
                      child: Container(
                        width: 22,
                        height: 22,
                        decoration: BoxDecoration(
                          color: isDark
                              ? Colors.black.withValues(alpha: 0.4)
                              : colors.surface2,
                          shape: BoxShape.circle,
                          border: Border.all(color: colors.border, width: 0.6),
                        ),
                        child: Icon(
                          Icons.lock_rounded,
                          size: 12,
                          color: colors.gold,
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

/// Instant synthetic-arrow thumbnail — never loads a nested maze.
class _ShapeCardPreview extends StatelessWidget {
  const _ShapeCardPreview({
    required this.maskBuilder,
    required this.seed,
  });

  final List<List<bool>> Function() maskBuilder;
  final int seed;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final mask = maskBuilder();
    final arrows = buildSyntheticDecorativeArrows(mask, seed: seed);
    const paletteBlue = Color(0xFF4C7EF3);
    final palette = [
      colors.accentTeal,
      colors.gold,
      colors.heartRed,
      paletteBlue,
    ];

    final CustomPainter painter;
    if (arrows.isEmpty || mask.isEmpty || mask.first.isEmpty) {
      painter = _ShapeMaskPainter(
        mask: mask,
        color: colors.accentTeal,
      );
    } else {
      painter = _PreviewArrowsPainter(
        level: LevelModel(
          levelNumber: 909000 + seed,
          gridRows: mask.length,
          gridCols: mask.first.length,
          arrows: arrows,
          heartsAllowed: 3,
          hintsAllowed: 2,
          shapeMask: mask,
        ),
        palette: palette,
      );
    }

    return DecoratedBox(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF16262B) : const Color(0xFF1C2C32),
        borderRadius: BorderRadius.circular(6),
      ),
      child: CustomPaint(
        painter: painter,
        child: const SizedBox.expand(),
      ),
    );
  }
}

List<List<bool>> _maskForGalleryLevel(int level) {
  return switch (level) {
    1 => generateHeartShapeMask(24),
    2 => generateCarShapeMask(24),
    3 => generateStarShapeMask(24),
    4 => generateDogShapeMask(24),
    5 => generateOwlShapeMask(24),
    6 => generateSportsCarShapeMask(24),
    7 => generateBicycleShapeMask(24),
    8 => ringMask(24, 24),
    9 => generateAppleShapeMask(24),
    10 => crescentMask(24, 24),
    11 => generateAirplaneShapeMask(24),
    12 => generateRabbitShapeMask(24),
    13 => generatePeacockShapeMask(24),
    14 => generateSuvShapeMask(24),
    15 => generateMotorbikeShapeMask(24),
    16 => thickRingMask(24, 24),
    17 => generateBananaShapeMask(24),
    18 => generateSixPointStarShapeMask(24),
    19 => generatePaperPlaneShapeMask(24),
    20 => generateElephantShapeMask(24),
    21 => generateLeftArrowShapeMask(24),
    22 => generateLightningBoltShapeMask(24),
    23 => generateRightArrowShapeMask(24),
    24 => generateWheelShapeMask(24),
    25 => generateFigureEightShapeMask(24),
    26 => generateCatShapeMask(24),
    27 => generateBirdShapeMask(24),
    28 => generateTruckShapeMask(24),
    29 => generateScooterShapeMask(24),
    30 => hourglassMask(24, 24),
    31 => generateGrapesShapeMask(24),
    32 => generateShootingStarShapeMask(24),
    33 => generateHelicopterShapeMask(24),
    34 => generateLionShapeMask(24),
    35 => generateDuckShapeMask(24),
    36 => generateVanShapeMask(24),
    37 => generateSportsBikeShapeMask(24),
    38 => plusMask(24, 24),
    39 => generateStrawberryShapeMask(24),
    40 => generateStarBurstShapeMask(24),
    41 => generateJetFighterShapeMask(24),
    42 => generateBearShapeMask(24),
    43 => generateParrotShapeMask(24),
    44 => generateJeepShapeMask(24),
    45 => generateCruiserBikeShapeMask(24),
    46 => shieldMask(24, 24),
    47 => generateWatermelonShapeMask(24),
    48 => generateFullMoonShapeMask(24),
    49 => generateGliderShapeMask(24),
    50 => generateFoxShapeMask(24),
    _ => generateHeartShapeMask(24),
  };
}

class _PreviewArrowsPainter extends CustomPainter {
  _PreviewArrowsPainter({required this.level, required this.palette});

  final LevelModel level;
  final List<Color> palette;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty || level.arrows.isEmpty) return;

    var minR = level.gridRows;
    var maxR = 0;
    var minC = level.gridCols;
    var maxC = 0;
    for (final arrow in level.arrows) {
      for (final cell in arrow.path) {
        if (cell.row < minR) minR = cell.row;
        if (cell.row > maxR) maxR = cell.row;
        if (cell.col < minC) minC = cell.col;
        if (cell.col > maxC) maxC = cell.col;
      }
    }
    if (maxR < minR || maxC < minC) return;

    final cellsW = maxC - minC + 1;
    final cellsH = maxR - minR + 1;
    const pad = 3.0;
    final cell = ((size.width - pad * 2) / cellsW)
        .clamp(0.0, (size.height - pad * 2) / cellsH);
    if (cell <= 0) return;
    final originX = (size.width - cellsW * cell) / 2;
    final originY = (size.height - cellsH * cell) / 2;

    Offset center(GridCell grid) {
      return Offset(
        originX + (grid.col - minC + 0.5) * cell,
        originY + (grid.row - minR + 0.5) * cell,
      );
    }

    final strokeWidth = (cell * 0.42).clamp(1.05, 2.4);

    for (var i = 0; i < level.arrows.length; i++) {
      final arrow = level.arrows[i];
      if (arrow.isRemoved || arrow.path.isEmpty) continue;
      final color = palette[i % palette.length];
      final points = [for (final grid in arrow.path) center(grid)];
      if (points.length == 1) {
        final nudge = cell * 0.32;
        final delta = switch (arrow.direction) {
          ArrowDirection.up => Offset(0, -nudge),
          ArrowDirection.down => Offset(0, nudge),
          ArrowDirection.left => Offset(-nudge, 0),
          ArrowDirection.right => Offset(nudge, 0),
        };
        points.add(points.first + delta);
      }
      _paintArrow(canvas, points, color, strokeWidth, arrow.direction);
    }
  }

  void _paintArrow(
    Canvas canvas,
    List<Offset> points,
    Color color,
    double strokeWidth,
    ArrowDirection direction,
  ) {
    if (points.length < 2) return;

    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.butt
      ..strokeJoin = StrokeJoin.miter
      ..isAntiAlias = true;

    final tip = points.last;
    final headLen = (strokeWidth * 2.4).clamp(3.2, 7.0);
    final unit = tip - points[points.length - 2];
    final len = unit.distance;
    final dir = len == 0 ? Offset.zero : unit / len;
    final shaftEnd = tip - dir * (headLen * 0.45);

    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (var i = 1; i < points.length - 1; i++) {
      path.lineTo(points[i].dx, points[i].dy);
    }
    path.lineTo(shaftEnd.dx, shaftEnd.dy);
    canvas.drawPath(path, stroke);

    final angle = len < 1e-6
        ? switch (direction) {
            ArrowDirection.up => -math.pi / 2,
            ArrowDirection.down => math.pi / 2,
            ArrowDirection.left => math.pi,
            ArrowDirection.right => 0.0,
          }
        : math.atan2(unit.dy, unit.dx);
    final headHalf = headLen * 0.5;
    Offset rot(double x, double y) {
      final c = math.cos(angle);
      final s = math.sin(angle);
      return Offset(tip.dx + x * c - y * s, tip.dy + x * s + y * c);
    }

    canvas.drawPath(
      Path()
        ..moveTo(tip.dx, tip.dy)
        ..lineTo(rot(-headLen, -headHalf).dx, rot(-headLen, -headHalf).dy)
        ..lineTo(rot(-headLen, headHalf).dx, rot(-headLen, headHalf).dy)
        ..close(),
      Paint()
        ..color = color
        ..style = PaintingStyle.fill
        ..isAntiAlias = true,
    );
  }

  @override
  bool shouldRepaint(covariant _PreviewArrowsPainter oldDelegate) {
    return oldDelegate.level != level || oldDelegate.palette != palette;
  }
}

class _ShapeMaskPainter extends CustomPainter {
  _ShapeMaskPainter({required this.mask, required this.color});

  final List<List<bool>> mask;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;

    var minR = mask.length;
    var maxR = 0;
    var minC = mask.first.length;
    var maxC = 0;
    for (var r = 0; r < mask.length; r++) {
      for (var c = 0; c < mask[r].length; c++) {
        if (!mask[r][c]) continue;
        if (r < minR) minR = r;
        if (r > maxR) maxR = r;
        if (c < minC) minC = c;
        if (c > maxC) maxC = c;
      }
    }
    if (maxR < minR || maxC < minC) return;

    final cellsW = maxC - minC + 1;
    final cellsH = maxR - minR + 1;
    const pad = 3.0;
    final cell = ((size.width - pad * 2) / cellsW)
        .clamp(0.0, (size.height - pad * 2) / cellsH);
    final originX = (size.width - cellsW * cell) / 2;
    final originY = (size.height - cellsH * cell) / 2;
    final paint = Paint()..color = color;

    for (var r = minR; r <= maxR; r++) {
      for (var c = minC; c <= maxC; c++) {
        if (!mask[r][c]) continue;
        canvas.drawRect(
          Rect.fromLTWH(
            originX + (c - minC) * cell,
            originY + (r - minR) * cell,
            cell + 0.4,
            cell + 0.4,
          ),
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _ShapeMaskPainter oldDelegate) {
    return oldDelegate.color != color || oldDelegate.mask != mask;
  }
}

/// Tiny dummy maze — visual placeholder only, not a real level.
class _DummyMazePreview extends StatelessWidget {
  const _DummyMazePreview({
    required this.seed,
    required this.teal,
    required this.tealDeep,
  });

  final int seed;
  final Color teal;
  final Color tealDeep;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _DummyMazePainter(
        seed: seed,
        teal: teal,
        tealDeep: tealDeep,
      ),
      child: const SizedBox.expand(),
    );
  }
}

class _DummyMazePainter extends CustomPainter {
  const _DummyMazePainter({
    required this.seed,
    required this.teal,
    required this.tealDeep,
  });

  final int seed;
  final Color teal;
  final Color tealDeep;

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = Paint()
      ..color = tealDeep
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final fill = Paint()
      ..color = teal.withValues(alpha: 0.18)
      ..style = PaintingStyle.fill;

    final w = size.width;
    final h = size.height;
    final inset = 4.0;
    final rect = Rect.fromLTWH(inset, inset, w - inset * 2, h - inset * 2);
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(6)),
      fill,
    );

    final path = Path();
    final shift = (seed % 4) * 0.08;
    path.moveTo(rect.left + 6, rect.top + rect.height * (0.22 + shift));
    path.lineTo(rect.left + rect.width * 0.38, rect.top + 8);
    path.lineTo(rect.right - 8, rect.top + rect.height * 0.28);
    path.lineTo(rect.right - 8, rect.bottom - 10);
    path.lineTo(rect.left + rect.width * 0.42, rect.bottom - 8);
    path.lineTo(rect.left + 8, rect.bottom - rect.height * 0.32);
    path.close();

    final inner = Paint()
      ..color = teal
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(path, stroke);

    final midY = rect.center.dy + ((seed.isEven) ? 4 : -4);
    canvas.drawLine(
      Offset(rect.left + 10, midY),
      Offset(rect.right - 10, midY),
      inner,
    );
    canvas.drawLine(
      Offset(rect.center.dx + (seed.isOdd ? 6 : -6), rect.top + 10),
      Offset(rect.center.dx, rect.bottom - 10),
      inner,
    );
  }

  @override
  bool shouldRepaint(covariant _DummyMazePainter oldDelegate) {
    return oldDelegate.seed != seed ||
        oldDelegate.teal != teal ||
        oldDelegate.tealDeep != tealDeep;
  }
}

/// Same treatment as Daily's Play Today — no coins, pinned CTA.
class _UnlockPromoBanner extends StatelessWidget {
  const _UnlockPromoBanner();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: Material(
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: () {
            ScaffoldMessenger.of(context)
              ..hideCurrentSnackBar()
              ..showSnackBar(
                const SnackBar(
                  content: Text('Coming soon'),
                  behavior: SnackBarBehavior.floating,
                  duration: Duration(seconds: 2),
                ),
              );
          },
          borderRadius: BorderRadius.circular(16),
          child: Ink(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [AppColors.accentTeal, AppColors.accentTealDeep],
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.accentTealDeep.withValues(alpha: 0.28),
                  blurRadius: 22,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: Center(
              child: Text(
                'Unlock More Patterns',
                style: AppTextStyles.button(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
