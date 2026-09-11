import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:arrow_drift/core/theme/app_theme.dart';
import 'package:arrow_drift/data/models/arrow_model.dart';
import 'package:arrow_drift/data/models/level_model.dart';
import 'package:arrow_drift/data/repositories/level_repository.dart';
import 'package:arrow_drift/data/repositories/progress_repository.dart';
import 'package:arrow_drift/features/gameplay/widgets/arrow_tile.dart';
import 'package:arrow_drift/features/patterns/pattern_preview_screen.dart';
import 'package:arrow_drift/features/patterns/unlock_level_sheet.dart';

/// Custom level gallery — 2×2 on first screen, then +2 rows via View more.
class PatternsScreen extends ConsumerStatefulWidget {
  const PatternsScreen({super.key});

  static const String routePath = '/patterns';

  static const int _unlockedThrough = 50;
  static const int _initialCount = 4;
  static const int _morePageSize = 2;

  @override
  ConsumerState<PatternsScreen> createState() => _PatternsScreenState();
}

class _PatternsScreenState extends ConsumerState<PatternsScreen> {
  int _visibleCount = PatternsScreen._initialCount;
  bool _loadingMore = false;

  bool get _hasMoreCustomLevels =>
      _visibleCount < PatternsScreen._unlockedThrough;

  Future<void> _showNextPage() async {
    if (!_hasMoreCustomLevels || _loadingMore) return;
    final from = _visibleCount + 1;
    final to = (_visibleCount + PatternsScreen._morePageSize)
        .clamp(0, PatternsScreen._unlockedThrough);
    setState(() => _loadingMore = true);
    try {
      for (var level = from; level <= to; level++) {
        if (!mounted) return;
        try {
          await LevelRepository.loadGalleryPatternPreviewLevel(level);
        } catch (_) {
          // Reveal the page anyway; the card can keep its own spinner.
        }
      }
    } finally {
      if (!mounted) return;
      setState(() {
        _visibleCount = to;
        _loadingMore = false;
      });
    }
  }

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
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Custom Levels',
                            style: AppTextStyles.heading(
                              fontSize: 28,
                              fontWeight: FontWeight.w700,
                              color: colors.primaryText,
                              letterSpacing: -0.4,
                            ),
                          ),
                        ),
                        const _CoinBalancePill(),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Collect shapes as you clear custom levels',
                      style: AppTextStyles.body(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: colors.secondaryText,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      const cols = 2;
                      const spacing = 12.0;
                      const fitRows = 2;
                      final colW =
                          (constraints.maxWidth - spacing) / cols;
                      final rowH =
                          (constraints.maxHeight - spacing) / fitRows;
                      final aspect =
                          (colW / rowH).clamp(0.01, 10.0);
                      return NotificationListener<ScrollNotification>(
                        onNotification: (notification) {
                          if (notification.depth == 0) {
                            LevelRepository.notifyGalleryViewportChanged();
                          }
                          return false;
                        },
                        child: GridView.builder(
                          physics: _visibleCount <= PatternsScreen._initialCount
                              ? const NeverScrollableScrollPhysics()
                              : const BouncingScrollPhysics(),
                          padding: EdgeInsets.zero,
                          gridDelegate:
                              SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: cols,
                            crossAxisSpacing: spacing,
                            mainAxisSpacing: spacing,
                            childAspectRatio: aspect,
                          ),
                          itemCount: _visibleCount,
                          addAutomaticKeepAlives: false,
                          itemBuilder: (context, index) {
                            final level = index + 1;
                            return _PatternCard(
                              level: level,
                              locked:
                                  level > PatternsScreen._unlockedThrough,
                            );
                          },
                        ),
                      );
                    },
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: _UnlockPromoBanner(
                  showMore: _hasMoreCustomLevels,
                  loading: _loadingMore,
                  onViewMore: _showNextPage,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CoinBalancePill extends ConsumerWidget {
  const _CoinBalancePill();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(progressRepositoryProvider);
    final colors = context.appColors;
    return ValueListenableBuilder<int>(
      valueListenable: ProgressRepository.coinBalanceTick,
      builder: (context, balance, _) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: colors.border, width: 0.8),
          ),
          child: Text(
            '🪙 $balance',
            style: AppTextStyles.label(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: colors.gold,
            ),
          ),
        );
      },
    );
  }
}

class _PatternCard extends ConsumerWidget {
  const _PatternCard({required this.level, required this.locked});

  final int level;
  final bool locked;

  void _onTap(BuildContext context, WidgetRef ref) {
    if (locked) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text('Coming soon'),
            behavior: SnackBarBehavior.floating,
            duration: Duration(seconds: 2),
          ),
        );
      return;
    }
    final repo = ref.read(progressRepositoryProvider).valueOrNull;
    final unlocked = repo?.isPatternLevelUnlocked(level) ?? level == 1;
    if (unlocked) {
      context.push(PatternPreviewScreen.routePath, extra: level);
      return;
    }
    showUnlockLevelSheet(context, level: level);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.appColors;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    ref.watch(unlockedPatternTickProvider);
    ref.watch(progressRepositoryProvider);
    return ValueListenableBuilder<int>(
      valueListenable: ProgressRepository.unlockedPatternTick,
      builder: (context, _, _) {
        return _buildCard(context, ref, colors, isDark);
      },
    );
  }

  Widget _buildCard(
    BuildContext context,
    WidgetRef ref,
    AppColorScheme colors,
    bool isDark,
  ) {
    final repo = ref.read(progressRepositoryProvider).valueOrNull;
    final coinUnlocked = repo?.isPatternLevelUnlocked(level) ?? level == 1;
    final borderColor = locked ? colors.border : colors.accentTealDeep;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _onTap(context, ref),
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
                              : level <= 50
                                  ? _PlayBoardCardPreview(galleryLevel: level)
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
                  else if (!coinUnlocked)
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

/// Real play-board thumbnail — same maze as inside the level, cached after load.
class _PlayBoardCardPreview extends StatefulWidget {
  const _PlayBoardCardPreview({required this.galleryLevel});

  final int galleryLevel;

  @override
  State<_PlayBoardCardPreview> createState() => _PlayBoardCardPreviewState();
}

class _PlayBoardCardPreviewState extends State<_PlayBoardCardPreview> {
  LevelModel? _level;

  @override
  void initState() {
    super.initState();
    _level =
        LevelRepository.peekGalleryPatternPreviewLevel(widget.galleryLevel);
    LevelRepository.galleryPreviewEpoch.addListener(_onGalleryEpoch);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _syncPreview();
      Future<void>.delayed(const Duration(milliseconds: 120), () {
        if (mounted) _syncPreview();
      });
    });
  }

  @override
  void dispose() {
    LevelRepository.galleryPreviewEpoch.removeListener(_onGalleryEpoch);
    super.dispose();
  }

  void _onGalleryEpoch() => _syncPreview();

  bool _isOnScreen() {
    final box = context.findRenderObject();
    if (box is! RenderBox || !box.hasSize) return true;
    final origin = box.localToGlobal(Offset.zero);
    final rect = origin & box.size;
    final view = View.of(context);
    final logical = view.physicalSize / view.devicePixelRatio;
    if (logical.isEmpty) return true;
    // Keep a margin so the first 2 rows still queue if the banner clips them.
    final screen = Rect.fromLTWH(
      -48,
      -48,
      logical.width + 96,
      logical.height + 96,
    );
    return rect.overlaps(screen);
  }

  void _syncPreview() {
    if (!mounted) return;
    final peek =
        LevelRepository.peekGalleryPatternPreviewLevel(widget.galleryLevel);
    if (peek != null) {
      if (!identical(_level, peek)) {
        setState(() => _level = peek);
      }
      return;
    }
    if (_isOnScreen()) {
      LevelRepository.scheduleGalleryPreview(widget.galleryLevel);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    const paletteBlue = Color(0xFF4C7EF3);
    final palette = [
      colors.accentTeal,
      colors.gold,
      colors.heartRed,
      paletteBlue,
    ];
    final level = _level;
    final boardColor = colors.background;

    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: ColoredBox(
        color: boardColor,
        child: level == null
            ? Center(
                child: SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.2,
                    color: colors.accentTeal,
                  ),
                ),
              )
            : Padding(
                padding: const EdgeInsets.all(4),
                child: RepaintBoundary(
                  child: CustomPaint(
                    painter: _PreviewArrowsPainter(
                      level: level,
                      palette: palette,
                      playBoardStyle: true,
                    ),
                    child: const SizedBox.expand(),
                  ),
                ),
              ),
      ),
    );
  }
}

class _PreviewArrowsPainter extends CustomPainter {
  _PreviewArrowsPainter({
    required this.level,
    required this.palette,
    this.playBoardStyle = false,
  });

  final LevelModel level;
  final List<Color> palette;
  final bool playBoardStyle;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty || level.arrows.isEmpty) return;

    var minR = 0;
    var maxR = level.gridRows - 1;
    var minC = 0;
    var maxC = level.gridCols - 1;
    if (!playBoardStyle) {
      minR = level.gridRows;
      maxR = 0;
      minC = level.gridCols;
      maxC = 0;
      for (final arrow in level.arrows) {
        for (final cell in arrow.path) {
          if (cell.row < minR) minR = cell.row;
          if (cell.row > maxR) maxR = cell.row;
          if (cell.col < minC) minC = cell.col;
          if (cell.col > maxC) maxC = cell.col;
        }
      }
    }
    if (maxR < minR || maxC < minC) return;

    final cellsW = maxC - minC + 1;
    final cellsH = maxR - minR + 1;
    final pad = playBoardStyle ? 1.0 : 3.0;
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

    final strokeWidth = playBoardStyle
        ? (cell * 0.15).clamp(0.45, 1.5)
        : (cell * 0.15).clamp(0.85, 1.8);

    for (var i = 0; i < level.arrows.length; i++) {
      final arrow = level.arrows[i];
      if (arrow.isRemoved || arrow.path.isEmpty) continue;
      final color = palette[i % palette.length];
      final points = [for (final grid in arrow.path) center(grid)];
      final nudge = cell * 0.28;
      final tipNudge = switch (arrow.direction) {
        ArrowDirection.up => Offset(0, -nudge),
        ArrowDirection.down => Offset(0, nudge),
        ArrowDirection.left => Offset(-nudge, 0),
        ArrowDirection.right => Offset(nudge, 0),
      };
      if (points.length == 1) {
        points.add(points.first + tipNudge);
      } else {
        points.add(points.last + tipNudge);
      }
      if (playBoardStyle) {
        _paintScaledArrow(canvas, points, color, strokeWidth, arrow.direction);
      } else {
        ArrowPolylinePainter(
          points: points,
          color: color,
          direction: arrow.direction,
          strokeWidth: strokeWidth,
        ).paint(canvas, size);
      }
    }
  }

  void _paintScaledArrow(
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
    final headLen = strokeWidth * 2.6;
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
    return oldDelegate.level != level ||
        oldDelegate.palette != palette ||
        oldDelegate.playBoardStyle != playBoardStyle;
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
  const _UnlockPromoBanner({
    required this.showMore,
    required this.onViewMore,
    this.loading = false,
  });

  final bool showMore;
  final bool loading;
  final VoidCallback onViewMore;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: Material(
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: loading
              ? null
              : showMore
                  ? onViewMore
                  : () {
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
              child: loading
                  ? const SizedBox(
                      width: 26,
                      height: 26,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.6,
                        color: Colors.white,
                      ),
                    )
                  : Text(
                      showMore
                          ? 'View more custom levels'
                          : 'Unlock More Custom Levels',
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
