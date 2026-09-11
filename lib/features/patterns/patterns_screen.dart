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
import 'package:arrow_drift/features/gameplay/widgets/pattern_board_chrome.dart';
import 'package:arrow_drift/features/patterns/pattern_preview_screen.dart';
import 'package:arrow_drift/features/patterns/unlock_level_sheet.dart';

/// Custom level gallery — 2×2 pages with Previous/Next.
class PatternsScreen extends ConsumerStatefulWidget {
  const PatternsScreen({super.key});

  static const String routePath = '/patterns';

  static const int _unlockedThrough = 100;
  static const int _pageSize = 4;

  @override
  ConsumerState<PatternsScreen> createState() => _PatternsScreenState();
}

class _PatternsScreenState extends ConsumerState<PatternsScreen> {
  int _pageIndex = 0;

  int get _startLevel => 1 + _pageIndex * PatternsScreen._pageSize;

  int get _endLevel => (_startLevel + PatternsScreen._pageSize - 1)
      .clamp(1, PatternsScreen._unlockedThrough);

  int get _itemCount => _endLevel - _startLevel + 1;

  int get _pageCount =>
      (PatternsScreen._unlockedThrough + PatternsScreen._pageSize - 1) ~/
      PatternsScreen._pageSize;

  bool get _canGoPrev => _pageIndex > 0;

  bool get _canGoNext =>
      _startLevel + PatternsScreen._pageSize <= PatternsScreen._unlockedThrough;

  @override
  void initState() {
    super.initState();
    _pageIndex = 0;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _schedulePagePreviews();
    });
  }

  void _schedulePagePreviews() {
    for (var level = _startLevel; level <= _endLevel; level++) {
      LevelRepository.scheduleGalleryPreview(level);
    }
  }

  void _goToPage(int index) {
    if (index < 0) return;
    final start = 1 + index * PatternsScreen._pageSize;
    if (start > PatternsScreen._unlockedThrough) return;
    setState(() => _pageIndex = index);
    _schedulePagePreviews();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final wellColor = Color.lerp(
      colors.surface2,
      colors.gold,
      isDark ? 0.10 : 0.07,
    )!;

    return Scaffold(
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: isDark
                ? const [
                    Color(0xFF0A3F38),
                    Color(0xFF0A3F38),
                    Color(0xFF121A26),
                    Color(0xFF0A101A),
                  ]
                : const [
                    Color(0xFF0B5E52),
                    Color(0xFF0B5E52),
                    Color(0xFFEAF6F2),
                    Color(0xFFF6F3EC),
                  ],
            stops: const [0.0, 0.16, 0.16, 1.0],
          ),
        ),
        child: SafeArea(
          bottom: false,
          child: Column(
            children: [
              const _CustomHero(),
              Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(6, 4, 6, 0),
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: IgnorePointer(
                            child: CustomPaint(
                              painter: _ParchmentOrnamentPainter(
                                color: colors.gold.withValues(
                                  alpha: isDark ? 0.12 : 0.20,
                                ),
                              ),
                            ),
                          ),
                        ),
                        Positioned.fill(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 22),
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                color: wellColor,
                                borderRadius: BorderRadius.circular(24),
                                border: Border.all(
                                  color: colors.gold.withValues(
                                    alpha: isDark ? 0.32 : 0.42,
                                  ),
                                  width: 1.3,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: colors.gold.withValues(
                                      alpha: isDark ? 0.12 : 0.10,
                                    ),
                                    blurRadius: 16,
                                    offset: const Offset(0, 6),
                                  ),
                                ],
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(22.5),
                                child: Stack(
                                  children: [
                                    Positioned.fill(
                                      child: IgnorePointer(
                                        child: CustomPaint(
                                          painter:
                                              PatternBoardInnerShadowPainter(
                                            color: Colors.black.withValues(
                                              alpha: isDark ? 0.28 : 0.08,
                                            ),
                                            extent: 18,
                                            radius: 22.5,
                                          ),
                                        ),
                                      ),
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.fromLTRB(
                                        12,
                                        12,
                                        12,
                                        12,
                                      ),
                                      child: LayoutBuilder(
                                        builder: (context, constraints) {
                                          const cols = 2;
                                          const spacing = 10.0;
                                          const fitRows = 2;
                                          final colW =
                                              (constraints.maxWidth - spacing) /
                                                  cols;
                                          final rowH =
                                              (constraints.maxHeight -
                                                      spacing) /
                                                  fitRows;
                                          final aspect =
                                              (colW / rowH).clamp(0.01, 10.0);
                                          return NotificationListener<
                                              ScrollNotification>(
                                            onNotification: (notification) {
                                              if (notification.depth == 0) {
                                                LevelRepository
                                                    .notifyGalleryViewportChanged();
                                              }
                                              return false;
                                            },
                                            child: GridView.builder(
                                              physics:
                                                  const NeverScrollableScrollPhysics(),
                                              padding: EdgeInsets.zero,
                                              gridDelegate:
                                                  SliverGridDelegateWithFixedCrossAxisCount(
                                                crossAxisCount: cols,
                                                crossAxisSpacing: spacing,
                                                mainAxisSpacing: spacing,
                                                childAspectRatio: aspect,
                                              ),
                                              itemCount: _itemCount,
                                              addAutomaticKeepAlives: false,
                                              itemBuilder: (context, index) {
                                                final level =
                                                    _startLevel + index;
                                                return _PatternCard(
                                                  key: ValueKey(level),
                                                  level: level,
                                                  locked: level >
                                                      PatternsScreen
                                                          ._unlockedThrough,
                                                );
                                              },
                                            ),
                                          );
                                        },
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: _GalleryPageButton(
                            icon: Icons.chevron_left_rounded,
                            enabled: _canGoPrev,
                            goldFace: true,
                            onTap: () => _goToPage(_pageIndex - 1),
                          ),
                        ),
                        Align(
                          alignment: Alignment.centerRight,
                          child: _GalleryPageButton(
                            icon: Icons.chevron_right_rounded,
                            enabled: _canGoNext,
                            goldFace: false,
                            onTap: () => _goToPage(_pageIndex + 1),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 10, 20, 10),
                  child: _GalleryPageIndicator(
                    pageIndex: _pageIndex,
                    pageCount: _pageCount,
                  ),
                ),
              ],
            ),
          ),
        ),
    );
  }
}

class _CustomHero extends StatelessWidget {
  const _CustomHero();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment(-0.4, -1),
          end: Alignment(0.6, 1),
          colors: [Color(0xFF14A089), Color(0xFF0B5E52), Color(0xFF08463D)],
        ),
      ),
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
                    color: Colors.white,
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
              color: Colors.white.withValues(alpha: 0.82),
            ),
          ),
        ],
      ),
    );
  }
}

class _LevelCaptionChip extends StatelessWidget {
  const _LevelCaptionChip({required this.level, required this.locked});

  final int level;
  final bool locked;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: locked ? colors.border : colors.accentTealDeep,
            width: 1.5,
          ),
          gradient: locked
              ? null
              : LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color.lerp(colors.accentTeal, Colors.white, 0.28)!,
                    colors.accentTeal,
                    colors.accentTealDeep,
                  ],
                  stops: const [0.0, 0.48, 1.0],
                ),
          color: locked ? colors.surface2 : null,
          boxShadow: locked
              ? null
              : [
                  BoxShadow(
                    color: colors.accentTeal.withValues(alpha: 0.28),
                    blurRadius: 5,
                    offset: const Offset(0, 1),
                  ),
                ],
        ),
        child: Text(
          'Level $level',
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppTextStyles.label(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            color: locked ? colors.secondaryText : Colors.white,
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return ValueListenableBuilder<int>(
      valueListenable: ProgressRepository.coinBalanceTick,
      builder: (context, balance, _) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
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
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.12),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Text(
            '🪙 $balance',
            style: AppTextStyles.label(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF3D2E12),
            ),
          ),
        );
      },
    );
  }
}

class _PatternCard extends ConsumerWidget {
  const _PatternCard({super.key, required this.level, required this.locked});

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
    final playable = !locked && coinUnlocked;
    final bronze = Color.lerp(colors.gold, const Color(0xFF8A6A1E), 0.45)!;
    final rim = locked
        ? colors.border
        : (playable ? colors.gold : bronze);
    final paper = isDark ? colors.surface2 : colors.background;
    final goldHair = colors.gold.withValues(alpha: isDark ? 0.28 : 0.42);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _onTap(context, ref),
        borderRadius: BorderRadius.circular(18),
        child: Ink(
          decoration: BoxDecoration(
            color: paper,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: rim, width: playable ? 1.7 : 1.4),
            boxShadow: [
              if (playable) ...[
                BoxShadow(
                  color: colors.gold.withValues(alpha: isDark ? 0.42 : 0.48),
                  blurRadius: 16,
                  spreadRadius: 0.6,
                ),
                BoxShadow(
                  color: colors.gold.withValues(alpha: isDark ? 0.22 : 0.28),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ] else
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.28 : 0.10),
                  blurRadius: 10,
                  offset: const Offset(0, 5),
                ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(2),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: paper,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: goldHair, width: 1),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(15),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
                          child: _LevelCaptionChip(
                            level: level,
                            locked: locked,
                          ),
                        ),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(5, 0, 5, 6),
                            child: locked
                                ? const SizedBox.expand()
                                : level <= 100
                                    ? _PlayBoardCardPreview(
                                        galleryLevel: level,
                                      )
                                    : _DummyMazePreview(
                                        seed: level,
                                        teal: colors.accentTeal,
                                        tealDeep: colors.accentTealDeep,
                                      ),
                          ),
                        ),
                      ],
                    ),
                    IgnorePointer(
                      child: CustomPaint(
                        painter: PatternBoardInnerShadowPainter(
                          color: Colors.black.withValues(
                            alpha: isDark ? 0.16 : 0.05,
                          ),
                          extent: 8,
                          radius: 15,
                        ),
                      ),
                    ),
                    if (locked)
                      Positioned.fill(
                        child: ColoredBox(
                          color: colors.surface2.withValues(alpha: 0.92),
                          child: Column(
                            children: [
                              Padding(
                                padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
                                child: _LevelCaptionChip(
                                  level: level,
                                  locked: true,
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
                      const Positioned(
                        right: 8,
                        bottom: 8,
                        child: _CornerLockBadge(),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final tealRim = colors.accentTeal.withValues(alpha: isDark ? 0.3 : 0.35);

    return Container(
      decoration: BoxDecoration(
        color: boardColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: tealRim, width: 1),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(
                painter: PatternBoardWashPainter.theme(
                  isDark: isDark,
                  accentTeal: colors.accentTeal,
                  accentTealSoft: colors.accentTealSoft,
                  gold: colors.gold,
                  radius: 8,
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: IgnorePointer(
              child: RepaintBoundary(
                child: CustomPaint(
                  painter: PatternBoardTexturePainter(
                    color: isDark
                        ? colors.accentTeal.withValues(alpha: 0.04)
                        : const Color(0xFF2A2A2A).withValues(alpha: 0.04),
                    seed: widget.galleryLevel,
                    densityScale: 0.45,
                    radiusScale: 0.55,
                  ),
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(
                painter: PatternBoardVignettePainter(
                  color: Colors.black.withValues(
                    alpha: isDark ? 0.055 : 0.035,
                  ),
                  radius: 8,
                ),
              ),
            ),
          ),
          if (level == null)
            Center(
              child: SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.2,
                  color: colors.accentTeal,
                ),
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.all(4),
              child: RepaintBoundary(
                child: CustomPaint(
                  painter: _PreviewArrowsPainter(
                    level: level,
                    palette: palette,
                    playBoardStyle: true,
                    fitToShape: true,
                  ),
                  child: const SizedBox.expand(),
                ),
              ),
            ),
          Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(
                painter: PatternBoardInnerShadowPainter(
                  color: Colors.black.withValues(alpha: isDark ? 0.08 : 0.05),
                  extent: 7,
                  radius: 8,
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(
                painter: PatternBoardHairlinePainter(
                  color: isDark
                      ? Colors.black.withValues(alpha: 0.08)
                      : const Color(0xFF2A2A2A).withValues(alpha: 0.12),
                  radius: 8,
                  inset: 2.25,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PreviewArrowsPainter extends CustomPainter {
  _PreviewArrowsPainter({
    required this.level,
    required this.palette,
    this.playBoardStyle = false,
    this.fitToShape = false,
  });

  final LevelModel level;
  final List<Color> palette;
  final bool playBoardStyle;
  final bool fitToShape;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty || level.arrows.isEmpty) return;

    var minR = 0;
    var maxR = level.gridRows - 1;
    var minC = 0;
    var maxC = level.gridCols - 1;
    if (!playBoardStyle || fitToShape) {
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
    final pad = fitToShape ? 2.0 : (playBoardStyle ? 1.0 : 3.0);
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
        ? (cell * 0.15 * 2.2).clamp(0.7, 4.2)
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
        oldDelegate.playBoardStyle != playBoardStyle ||
        oldDelegate.fitToShape != fitToShape;
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

class _GalleryPageButton extends StatelessWidget {
  const _GalleryPageButton({
    required this.icon,
    required this.enabled,
    required this.goldFace,
    required this.onTap,
  });

  final IconData icon;
  final bool enabled;
  final bool goldFace;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final light = goldFace
        ? Color.lerp(colors.gold, Colors.white, 0.42)!
        : const Color(0xFF5EE0C8);
    final mid = goldFace ? colors.gold : colors.accentTeal;
    final dark = goldFace
        ? Color.lerp(colors.gold, const Color(0xFF8A6A1E), 0.4)!
        : colors.accentTealDeep;
    final iconColor = goldFace
        ? const Color(0xFF3D2E12)
        : Colors.white;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: enabled ? onTap : null,
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: Ink(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: enabled
                    ? [light, mid, dark]
                    : [
                        colors.surface.withValues(alpha: isDark ? 0.55 : 0.85),
                        colors.surface2,
                      ],
              ),
              border: Border.all(
                color: enabled
                    ? Colors.white.withValues(alpha: goldFace ? 0.55 : 0.35)
                    : colors.border,
                width: 1.2,
              ),
              boxShadow: enabled
                  ? [
                      BoxShadow(
                        color: (goldFace ? colors.gold : colors.accentTeal)
                            .withValues(alpha: 0.38),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                      BoxShadow(
                        color: Colors.black.withValues(
                          alpha: isDark ? 0.35 : 0.14,
                        ),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ]
                  : null,
            ),
            child: Center(
              child: Icon(
                icon,
                size: 26,
                color: enabled
                    ? iconColor
                    : colors.secondaryText.withValues(alpha: 0.38),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _GalleryPageIndicator extends StatelessWidget {
  const _GalleryPageIndicator({
    required this.pageIndex,
    required this.pageCount,
  });

  final int pageIndex;
  final int pageCount;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final leftStart = (pageIndex - 3).clamp(0, pageIndex);
    final rightEnd = (pageIndex + 4).clamp(pageIndex + 1, pageCount);

    Widget dot(int i) {
      final current = i == pageIndex;
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 3),
        child: Container(
          width: current ? 8 : 6,
          height: current ? 8 : 6,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: current
                ? colors.accentTeal
                : colors.gold.withValues(alpha: isDark ? 0.55 : 0.7),
          ),
        ),
      );
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = leftStart; i < pageIndex; i++) dot(i),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Text(
            '${pageIndex + 1} / $pageCount',
            style: AppTextStyles.label(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: isDark ? colors.accentTeal : colors.accentTealDeep,
            ),
          ),
        ),
        for (var i = pageIndex; i < rightEnd; i++) dot(i),
      ],
    );
  }
}

class _CornerLockBadge extends StatelessWidget {
  const _CornerLockBadge();

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Container(
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: Color.lerp(colors.gold, const Color(0xFF8A6A1E), 0.4)!,
          width: 1.3,
        ),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color.lerp(colors.gold, Colors.white, 0.35)!,
            colors.gold,
            Color.lerp(colors.gold, const Color(0xFF8A6A1E), 0.28)!,
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.28),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: const Icon(
        Icons.lock_rounded,
        size: 13,
        color: Color(0xFF3D2E12),
      ),
    );
  }
}

class _ParchmentOrnamentPainter extends CustomPainter {
  _ParchmentOrnamentPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.1
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    const m = 16.0;
    const len = 38.0;
    const gap = 5.0;

    void corner(Offset origin, bool flipX, bool flipY) {
      final sx = flipX ? -1.0 : 1.0;
      final sy = flipY ? -1.0 : 1.0;
      Offset p(double x, double y) =>
          Offset(origin.dx + x * sx, origin.dy + y * sy);
      canvas.drawPath(
        Path()
          ..moveTo(p(0, len).dx, p(0, len).dy)
          ..lineTo(p(0, 0).dx, p(0, 0).dy)
          ..lineTo(p(len, 0).dx, p(len, 0).dy),
        paint,
      );
      canvas.drawPath(
        Path()
          ..moveTo(p(gap, len - 4).dx, p(gap, len - 4).dy)
          ..lineTo(p(gap, gap).dx, p(gap, gap).dy)
          ..lineTo(p(len - 4, gap).dx, p(len - 4, gap).dy),
        paint,
      );
      canvas.drawCircle(p(gap + 3, gap + 3), 1.4, Paint()..color = color);
    }

    corner(const Offset(m, m), false, false);
    corner(Offset(size.width - m, m), true, false);
    corner(Offset(m, size.height - m), false, true);
    corner(Offset(size.width - m, size.height - m), true, true);
  }

  @override
  bool shouldRepaint(covariant _ParchmentOrnamentPainter oldDelegate) {
    return oldDelegate.color != color;
  }
}
