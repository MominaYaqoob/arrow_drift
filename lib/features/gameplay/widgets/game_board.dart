import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:arrow_drift/core/theme/app_theme.dart';
import 'package:arrow_drift/data/models/arrow_model.dart';
import 'package:arrow_drift/data/models/game_state.dart';
import 'package:arrow_drift/features/gameplay/widgets/arrow_tile.dart';

/// Zoomable board (pinch 2-finger + Grid Booster) with cream/white card, dots, arrows.
class GameBoard extends StatelessWidget {
  const GameBoard({
    super.key,
    required this.gameState,
    required this.onArrowTap,
    this.highlightedArrowId,
    this.tutorialArrowId,
    this.showTutorialTip = false,
    this.plainTutorial = false,
    this.plainBoard = false,
    this.playEntrance = false,
    this.boardZoomed = false,
    this.shakeTokens = const {},
    this.wrongBumpCells = const {},
    this.cellSize = 52,
    this.boardBackgroundOverride,
    this.arrowColorResolver,
    this.hideDots = false,
  });

  final GameState gameState;
  final ValueChanged<String> onArrowTap;
  final String? highlightedArrowId;
  final String? tutorialArrowId;
  final bool showTutorialTip;

  /// Level-1 tutorial look: plain white, no cream card / dots (matches reference SS).
  final bool plainTutorial;

  /// Level-2 reference look: plain white board, no cream card / dots.
  final bool plainBoard;

  /// Staggered fade+scale entrance for each arrow.
  final bool playEntrance;

  /// Grid Booster: moderate zoom-in (1.3x) when true.
  final bool boardZoomed;

  final Map<String, int> shakeTokens;

  /// Primary wrong-tap arrows: how far (in cells) to bump toward the blocker.
  final Map<String, double> wrongBumpCells;
  final double cellSize;

  /// When set, used instead of the default cream/white (or dark background) card.
  final Color? boardBackgroundOverride;

  /// When set, [ArrowTile] uses this color per arrow instead of the theme default.
  final Color? Function(ArrowModel arrow, int index)? arrowColorResolver;

  /// When true, skip the dotted grid behind arrows. Default false (campaign/Daily).
  final bool hideDots;

  bool get _plain => plainTutorial || plainBoard;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    // Light: white card · Dark: deep navy so #EEF3F8 arrows stay readable.
    final boardBg = boardBackgroundOverride ??
        (isDark ? colors.background : Colors.white);
    final boardShadow = isDark
        ? Colors.black.withValues(alpha: 0.45)
        : const Color(0xFF0E1726).withValues(alpha: 0.06);
    final rows = gameState.level.gridRows;
    final cols = gameState.level.gridCols;

    return LayoutBuilder(
      builder: (context, constraints) {
        final zoom = boardZoomed ? 1.3 : 1.0;
        // Plain boards: keep cell size at the unzoomed fit. Dividing by zoom
        // then AnimatedScale(zoom) cancels out on large grids (L8/L9), so the
        // booster would appear broken. Scale alone handles the zoom effect.
        final effectiveCell = _cellSizeFor(
          rows: rows,
          cols: cols,
          maxWidth: constraints.maxWidth,
          maxHeight: constraints.maxHeight,
          zoom: _plain ? 1.0 : zoom,
        );
        final boardWidth = cols * effectiveCell;
        final boardHeight = rows * effectiveCell;

        ArrowModel? tipArrow;
        if (showTutorialTip && tutorialArrowId != null) {
          for (final a in gameState.arrows) {
            if (a.id == tutorialArrowId && !a.isRemoved) {
              tipArrow = a;
              break;
            }
          }
        }

        // Clip at the board edge so escapes slide to the rim then vanish —
        // never continue onto the phone chrome past the white card.
        final arrowsLayer = SizedBox(
          width: boardWidth,
          height: boardHeight,
          child: Stack(
            clipBehavior: Clip.hardEdge,
            children: [
              if (!plainTutorial && !hideDots)
                Positioned.fill(
                  child: CustomPaint(
                    painter: _DotGridPainter(
                      rows: rows,
                      cols: cols,
                      color: isDark
                          ? colors.border
                          : const Color(0xFFB8B0A0),
                      shapeMask: gameState.level.shapeMask,
                      fillColor: boardBackgroundOverride,
                    ),
                  ),
                ),
              for (var i = 0; i < gameState.arrows.length; i++)
                Positioned(
                  left: 0,
                  top: 0,
                  width: boardWidth,
                  height: boardHeight,
                  child: ArrowTile(
                    key: ValueKey(gameState.arrows[i].id),
                    arrow: gameState.arrows[i],
                    cellSize: effectiveCell,
                    allArrows: gameState.arrows,
                    gridRows: rows,
                    gridCols: cols,
                    highlighted:
                        highlightedArrowId == gameState.arrows[i].id ||
                            tutorialArrowId == gameState.arrows[i].id,
                    tutorialHand: tutorialArrowId == gameState.arrows[i].id,
                    shakeToken: shakeTokens[gameState.arrows[i].id] ?? 0,
                    wrongBumpCells:
                        wrongBumpCells[gameState.arrows[i].id] ?? 0,
                    entranceIndex: i,
                    playEntrance: playEntrance,
                    colorOverride: arrowColorResolver?.call(
                      gameState.arrows[i],
                      i,
                    ),
                    onTap: () => onArrowTap(gameState.arrows[i].id),
                  ),
                ),
            ],
          ),
        );

        final boardStack = SizedBox(
          width: boardWidth,
          // Extra height in tutorial so tip bubble below the tile isn't clipped.
          height: plainTutorial ? boardHeight + 90 : boardHeight,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              arrowsLayer,
              if (tipArrow != null)
                _TutorialTipBubble(
                  arrow: tipArrow,
                  cellSize: effectiveCell,
                  boardWidth: boardWidth,
                  boardHeight: boardHeight,
                ),
            ],
          ),
        );

        if (_plain) {
          // Extra margin + contain fit = board sits zoomed-out on phones
          // so full nest (incl. tip heads) stays clear of chrome/edges.
          final fitted = Padding(
            padding: EdgeInsets.symmetric(
              horizontal: plainBoard ? 10 : 0,
              vertical: plainBoard ? 8 : 0,
            ),
            child: FittedBox(
              fit: BoxFit.contain,
              clipBehavior: Clip.hardEdge,
              child: boardStack,
            ),
          );

          if (plainTutorial) {
            return InteractiveViewer(
              minScale: 0.4,
              maxScale: 5.0,
              boundaryMargin: const EdgeInsets.all(220),
              clipBehavior: Clip.hardEdge,
              panEnabled: false,
              scaleEnabled: true,
              child: Center(
                child: AnimatedScale(
                  scale: zoom,
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeOutCubic,
                  child: fitted,
                ),
              ),
            );
          }

          // Scale the whole white card (dots stay inside).
          // Pinch (2-finger) zoom + pan; Grid Booster still uses [boardZoomed].
          return InteractiveViewer(
            minScale: 0.4,
            maxScale: 5.0,
            boundaryMargin: const EdgeInsets.all(220),
            clipBehavior: Clip.hardEdge,
            panEnabled: false,
            scaleEnabled: true,
            child: Center(
              child: AnimatedScale(
                scale: zoom,
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOutCubic,
                child: Container(
                  margin:
                      const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  padding: const EdgeInsets.all(14),
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(
                    color: boardBg,
                    borderRadius: BorderRadius.circular(22),
                    border: isDark
                        ? Border.all(
                            color: colors.border.withValues(alpha: 0.6),
                          )
                        : null,
                    boxShadow: [
                      BoxShadow(
                        color: boardShadow,
                        blurRadius: 24,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: fitted,
                ),
              ),
            ),
          );
        }

        // Card padding: 14 + ~8 = 22 so arrows aren't cramped at the edges.
        const cardPad = 22.0;
        final decorated = boardBackgroundOverride != null;
        final cardChild = AnimatedScale(
          scale: zoom,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
          child: Container(
            width: boardWidth + cardPad * 2,
            height: boardHeight + cardPad * 2,
            padding: decorated ? null : const EdgeInsets.all(cardPad),
            decoration: decorated
                ? BoxDecoration(
                    borderRadius: BorderRadius.circular(22),
                    gradient: RadialGradient(
                      center: Alignment.center,
                      radius: 0.95,
                      colors: isDark
                          ? const [Color(0xFF1B2E34), Color(0xFF16262B)]
                          : const [Color(0xFF223840), Color(0xFF1C2C32)],
                    ),
                    border: Border.all(
                      color: colors.accentTeal.withValues(alpha: 0.28),
                      width: 1.25,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: colors.accentTeal.withValues(alpha: 0.15),
                        blurRadius: 20,
                      ),
                    ],
                  )
                : BoxDecoration(
                    color: boardBg,
                    borderRadius: BorderRadius.circular(22),
                    border: isDark
                        ? Border.all(
                            color: colors.border.withValues(alpha: 0.6),
                          )
                        : null,
                    boxShadow: [
                      BoxShadow(
                        color: boardShadow,
                        blurRadius: 24,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
            clipBehavior: Clip.antiAlias,
            child: decorated
                ? Stack(
                    fit: StackFit.expand,
                    children: [
                      const IgnorePointer(child: _PatternBoardVignette()),
                      IgnorePointer(
                        child: CustomPaint(
                          painter: _PatternBoardTexturePainter(
                            color: colors.accentTeal.withValues(alpha: 0.04),
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(cardPad),
                        child: boardStack,
                      ),
                    ],
                  )
                : boardStack,
          ),
        );

        return InteractiveViewer(
          minScale: 0.4,
          maxScale: 5.0,
          boundaryMargin: const EdgeInsets.all(220),
          clipBehavior: Clip.hardEdge,
          panEnabled: false,
          scaleEnabled: true,
          child: Center(
            child: FittedBox(
              fit: BoxFit.contain,
              clipBehavior: decorated ? Clip.none : Clip.hardEdge,
              child: cardChild,
            ),
          ),
        );
      },
    );
  }

  /// Shrinks cells so the full grid (and optional zoom) fits the phone screen.
  double _cellSizeFor({
    required int rows,
    required int cols,
    required double maxWidth,
    required double maxHeight,
    required double zoom,
  }) {
    // Plain boards: larger inset so the nest is clearly zoomed out on phones.
    final inset = plainBoard ? 56.0 : 8.0;
    final availW = math.max(0.0, maxWidth - inset);
    final availH = math.max(0.0, maxHeight - inset);
    if (availW <= 0 || availH <= 0 || cols <= 0 || rows <= 0) {
      return 32.0;
    }

    final byW = availW / cols / zoom;
    final byH = availH / rows / zoom;
    final fitted = math.min(byW, byH);

    if (plainTutorial) {
      // Tutorial is a tiny grid — keep cells chunky but still on-screen.
      return fitted.clamp(48.0, 108.0);
    }

    // Cap only (no floor) so we never force the board wider than the phone.
    // Plain campaign: lower max cell = whole board visible with breathing room.
    return math.min(fitted, plainBoard ? 36.0 : cellSize);
  }
}

/// "Tap free arrow" bubble — always clear of the target arrow's cell.
class _TutorialTipBubble extends StatelessWidget {
  const _TutorialTipBubble({
    required this.arrow,
    required this.cellSize,
    required this.boardWidth,
    required this.boardHeight,
  });

  final ArrowModel arrow;
  final double cellSize;
  final double boardWidth;
  final double boardHeight;

  static const double _tipWidth = 130;
  static const double _tipBodyHeight = 38;
  static const double _caretHeight = 8;
  static const double _gap = 14;
  static const Color _tipTeal = AppColors.accentTeal;

  @override
  Widget build(BuildContext context) {
    final totalHeight = _caretHeight + _tipBodyHeight;
    final cellBottom = (arrow.row + 1) * cellSize;
    final cellTop = arrow.row * cellSize;

    final spaceBelow = boardHeight - cellBottom;
    final placeBelow =
        spaceBelow >= totalHeight + _gap || arrow.row <= 1;

    var top = placeBelow
        ? cellBottom + _gap
        : cellTop - _gap - totalHeight;
    top = top.clamp(0.0, (boardHeight - totalHeight).clamp(0.0, double.infinity));

    var left = arrow.col * cellSize + cellSize / 2 - _tipWidth / 2;
    left = left.clamp(0.0, (boardWidth - _tipWidth).clamp(0.0, double.infinity));

    return Positioned(
      left: left,
      top: top,
      width: _tipWidth,
      child: IgnorePointer(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (placeBelow)
              CustomPaint(
                size: const Size(12, _caretHeight),
                painter: _CaretPainter(color: _tipTeal, pointUp: true),
              ),
            Container(
              width: _tipWidth,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: _tipTeal,
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  BoxShadow(
                    color: _tipTeal.withValues(alpha: 0.28),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Text(
                'Tap free arrow',
                textAlign: TextAlign.center,
                style: AppTextStyles.body(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
            if (!placeBelow)
              CustomPaint(
                size: const Size(12, _caretHeight),
                painter: _CaretPainter(color: _tipTeal, pointUp: false),
              ),
          ],
        ),
      ),
    );
  }
}

class _CaretPainter extends CustomPainter {
  _CaretPainter({required this.color, required this.pointUp});

  final Color color;
  final bool pointUp;

  @override
  void paint(Canvas canvas, Size size) {
    final path = pointUp
        ? (Path()
          ..moveTo(0, size.height)
          ..lineTo(size.width / 2, 0)
          ..lineTo(size.width, size.height)
          ..close())
        : (Path()
          ..moveTo(0, 0)
          ..lineTo(size.width / 2, size.height)
          ..lineTo(size.width, 0)
          ..close());
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant _CaretPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.pointUp != pointUp;
}

/// Corner darkening for Patterns boards — behind arrows, no hit testing.
class _PatternBoardVignette extends StatelessWidget {
  const _PatternBoardVignette();

  @override
  Widget build(BuildContext context) {
    return const CustomPaint(
      painter: _PatternBoardVignettePainter(),
    );
  }
}

class _PatternBoardVignettePainter extends CustomPainter {
  const _PatternBoardVignettePainter();

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    const alpha = 0.18;
    final radius = math.max(size.width, size.height) * 0.42;
    final corners = <Offset>[
      Offset.zero,
      Offset(size.width, 0),
      Offset(0, size.height),
      Offset(size.width, size.height),
    ];
    for (final origin in corners) {
      final paint = Paint()
        ..shader = RadialGradient(
          colors: [
            Colors.black.withValues(alpha: alpha),
            Colors.transparent,
          ],
        ).createShader(Rect.fromCircle(center: origin, radius: radius));
      canvas.drawRect(Offset.zero & size, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _PatternBoardVignettePainter oldDelegate) =>
      false;
}

class _PatternBoardTexturePainter extends CustomPainter {
  const _PatternBoardTexturePainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;
    const step = 22.0;
    for (var x = -size.height; x < size.width; x += step) {
      canvas.drawLine(
        Offset(x, 0),
        Offset(x + size.height, size.height),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _PatternBoardTexturePainter oldDelegate) =>
      oldDelegate.color != color;
}

class _DotGridPainter extends CustomPainter {
  _DotGridPainter({
    required this.rows,
    required this.cols,
    required this.color,
    this.shapeMask,
    this.fillColor,
  });

  final int rows;
  final int cols;
  final Color color;
  final List<List<bool>>? shapeMask;
  final Color? fillColor;

  bool _cellInMask(int r, int c) {
    if (shapeMask == null) return true;
    if (r < 0 || c < 0 || r >= shapeMask!.length || c >= shapeMask![r].length) {
      return false;
    }
    return shapeMask![r][c];
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (rows <= 0 || cols <= 0 || size.isEmpty) return;

    if (fillColor != null) {
      canvas.drawRect(Offset.zero & size, Paint()..color = fillColor!);
    }

    final paint = Paint()..color = color.withValues(alpha: 0.55);
    const radius = 1.6;
    final cellW = size.width / cols;
    final cellH = size.height / rows;

    if (shapeMask == null) {
      for (var r = 0; r <= rows; r++) {
        for (var c = 0; c <= cols; c++) {
          canvas.drawCircle(Offset(c * cellW, r * cellH), radius, paint);
        }
      }
      return;
    }

    // Only corners that touch at least one in-mask cell (heart silhouette).
    for (var r = 0; r <= rows; r++) {
      for (var c = 0; c <= cols; c++) {
        final touch = _cellInMask(r - 1, c - 1) ||
            _cellInMask(r - 1, c) ||
            _cellInMask(r, c - 1) ||
            _cellInMask(r, c);
        if (!touch) continue;
        canvas.drawCircle(Offset(c * cellW, r * cellH), radius, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DotGridPainter oldDelegate) {
    return oldDelegate.rows != rows ||
        oldDelegate.cols != cols ||
        oldDelegate.color != color ||
        oldDelegate.shapeMask != shapeMask ||
        oldDelegate.fillColor != fillColor;
  }
}
