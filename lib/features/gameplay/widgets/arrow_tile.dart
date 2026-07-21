import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:arrow_drift/core/theme/app_theme.dart';
import 'package:arrow_drift/data/models/arrow_model.dart';

/// Temporary paint feedback after a tap.
enum ArrowTapFeedback { none, correct, wrong }

/// Easybrain-style arrow: single-cell shaft or multi-cell rounded polyline.
class ArrowTile extends StatefulWidget {
  const ArrowTile({
    super.key,
    required this.arrow,
    required this.cellSize,
    required this.onTap,
    required this.allArrows,
    required this.gridRows,
    required this.gridCols,
    this.highlighted = false,
    this.tutorialHand = false,
    this.shakeToken = 0,
    this.wrongBumpCells = 0,
    this.onShakeCompleted,
    this.entranceIndex = 0,
    this.playEntrance = false,
  });

  final ArrowModel arrow;
  final double cellSize;
  final VoidCallback onTap;
  final List<ArrowModel> allArrows;
  final int gridRows;
  final int gridCols;
  final bool highlighted;
  final bool tutorialHand;
  final int shakeToken;

  /// When > 0 with a new [shakeToken], slide this many cells toward the tip
  /// (almost to the blocker), flash red, then return home.
  final double wrongBumpCells;
  final VoidCallback? onShakeCompleted;

  /// Stagger index for entrance (60ms * index).
  final int entranceIndex;

  /// When true, fade+scale in on first appear.
  final bool playEntrance;

  /// Default arrow stroke in light theme (#0E1726).
  static const Color referenceArrowColor = Color(0xFF0E1726);

  @override
  State<ArrowTile> createState() => _ArrowTileState();
}

class _ArrowTileState extends State<ArrowTile> with TickerProviderStateMixin {
  late final AnimationController _shakeController;
  late final AnimationController _glowController;
  late final AnimationController _handController;
  late final AnimationController _exitController;
  late final AnimationController _wrongColorController;
  late final AnimationController _wrongBumpController;
  late final AnimationController _entranceController;

  late final Animation<double> _shakeAnimation;
  late final Animation<double> _wrongBumpAnimation;
  late final Animation<double> _exitOpacity;
  late final Animation<double> _entranceOpacity;
  late final Animation<double> _entranceScale;
  late Animation<Offset> _exitOffset;

  ArrowTapFeedback _feedback = ArrowTapFeedback.none;
  bool _exitStarted = false;
  bool _exitFinished = false;
  int _lastShakeToken = 0;
  double _activeWrongBumpCells = 0;

  @override
  void initState() {
    super.initState();
    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
    );
    _shakeAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0, end: -5), weight: 1),
      TweenSequenceItem(tween: Tween(begin: -5, end: 5), weight: 1),
      TweenSequenceItem(tween: Tween(begin: 5, end: -5), weight: 1),
      TweenSequenceItem(tween: Tween(begin: -5, end: 5), weight: 1),
      TweenSequenceItem(tween: Tween(begin: 5, end: -4), weight: 1),
      TweenSequenceItem(tween: Tween(begin: -4, end: 0), weight: 1),
    ]).animate(CurvedAnimation(parent: _shakeController, curve: Curves.linear));

    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _handController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    _exitController = AnimationController(
      vsync: this,
      duration: _exitDurationFor(widget.arrow),
    );
    // Stay fully visible until near the board rim, then fade inside the clip.
    _exitOpacity = Tween<double>(begin: 1, end: 0).animate(
      CurvedAnimation(
        parent: _exitController,
        curve: const Interval(0.62, 1.0, curve: Curves.easeIn),
      ),
    );
    _exitOffset = _buildExitOffset(widget.arrow.direction);
    _exitController.addStatusListener((status) {
      if (status == AnimationStatus.completed && mounted) {
        setState(() => _exitFinished = true);
      }
    });

    _wrongColorController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 680),
    );
    _wrongColorController.addStatusListener((status) {
      if (status == AnimationStatus.completed && mounted) {
        // Keep red until bump finishes when bumping; otherwise clear.
        if (!_wrongBumpController.isAnimating &&
            _wrongBumpController.value == 0) {
          setState(() => _feedback = ArrowTapFeedback.none);
        }
      }
    });

    // 0 → 1 (toward blocker) → 0 (home). Red clears when back home.
    _wrongBumpController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 560),
    );
    _wrongBumpAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(begin: 0.0, end: 1.0)
            .chain(CurveTween(curve: Curves.easeOutCubic)),
        weight: 45,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 1.0, end: 0.0)
            .chain(CurveTween(curve: Curves.easeInCubic)),
        weight: 55,
      ),
    ]).animate(_wrongBumpController);
    _wrongBumpController.addStatusListener((status) {
      if (status == AnimationStatus.completed && mounted) {
        setState(() {
          _feedback = ArrowTapFeedback.none;
          _activeWrongBumpCells = 0;
        });
        widget.onShakeCompleted?.call();
      }
    });

    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _entranceOpacity = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _entranceController, curve: Curves.easeOut),
    );
    _entranceScale = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _entranceController, curve: Curves.easeOutCubic),
    );

    _lastShakeToken = widget.shakeToken;
    _syncGuideAnimations();
    if (widget.arrow.isRemoved) {
      _startExit();
    } else if (widget.playEntrance) {
      _startEntrance();
    } else {
      _entranceController.value = 1;
    }
  }

  Future<void> _startEntrance() async {
    final delay = Duration(milliseconds: 60 * widget.entranceIndex);
    await Future<void>.delayed(delay);
    if (!mounted || widget.arrow.isRemoved) return;
    _entranceController.forward();
  }

  Duration _exitDurationFor(ArrowModel arrow) {
    if (!arrow.isMultiCell) {
      return const Duration(milliseconds: 280);
    }
    final pathCells = arrow.path.length.clamp(2, 14);
    final tip = arrow.path.last;
    final toEdge = switch (arrow.direction) {
      ArrowDirection.up => tip.row + 1,
      ArrowDirection.down => widget.gridRows - tip.row,
      ArrowDirection.left => tip.col + 1,
      ArrowDirection.right => widget.gridCols - tip.col,
    };
    // Longer board exits (short arrow mid-board) get a bit more time.
    final travel = (pathCells + toEdge).clamp(4, 26);
    return Duration(milliseconds: 260 + travel * 30);
  }

  Animation<Offset> _buildExitOffset(ArrowDirection direction) {
    // Straight (single-cell) arrows: rigid tip-direction slide past the edge.
    final cell = widget.cellSize;
    final path = widget.arrow.path;
    var minR = widget.arrow.row;
    var maxR = widget.arrow.row;
    var minC = widget.arrow.col;
    var maxC = widget.arrow.col;
    for (final c in path) {
      if (c.row < minR) minR = c.row;
      if (c.row > maxR) maxR = c.row;
      if (c.col < minC) minC = c.col;
      if (c.col > maxC) maxC = c.col;
    }
    final pad = cell * 0.55;
    final travel = switch (direction) {
      ArrowDirection.up => (maxR + 1) * cell + pad,
      ArrowDirection.down => (widget.gridRows - minR) * cell + pad,
      ArrowDirection.left => (maxC + 1) * cell + pad,
      ArrowDirection.right => (widget.gridCols - minC) * cell + pad,
    };
    return Tween<Offset>(
      begin: Offset.zero,
      end: switch (direction) {
        ArrowDirection.up => Offset(0, -travel),
        ArrowDirection.down => Offset(0, travel),
        ArrowDirection.left => Offset(-travel, 0),
        ArrowDirection.right => Offset(travel, 0),
      },
    ).animate(
      CurvedAnimation(parent: _exitController, curve: Curves.easeOutCubic),
    );
  }

  Offset _tipUnit(ArrowDirection direction) {
    return switch (direction) {
      ArrowDirection.up => const Offset(0, -1),
      ArrowDirection.down => const Offset(0, 1),
      ArrowDirection.left => const Offset(-1, 0),
      ArrowDirection.right => const Offset(1, 0),
    };
  }

  /// Path centers (tail→tip) + straight exit ray past the board edge.
  ///
  /// Short arrows must travel the remaining distance to the edge (plus a
  /// body-length so the whole snake leaves), not just ~1 cell past the tip.
  List<Offset> _escapeRail() {
    final cell = widget.cellSize;
    final points = _polylinePoints();
    if (points.length < 2) return points;

    var bodyLen = 0.0;
    for (var i = 1; i < points.length; i++) {
      bodyLen += (points[i] - points[i - 1]).distance;
    }

    final tip = points.last;
    final unit = _tipUnit(widget.arrow.direction);
    final boardW = widget.gridCols * cell;
    final boardH = widget.gridRows * cell;
    final clearPastEdge = switch (widget.arrow.direction) {
      ArrowDirection.up => tip.dy + cell * 0.7,
      ArrowDirection.down => (boardH - tip.dy) + cell * 0.7,
      ArrowDirection.left => tip.dx + cell * 0.7,
      ArrowDirection.right => (boardW - tip.dx) + cell * 0.7,
    };
    // bodyLen: slide onto the exit ray; clearPastEdge: reach the board rim
    // (parent Clip hides anything past the card — no phone-screen overflow).
    final exitLen = bodyLen + clearPastEdge;
    points.add(tip + unit * exitLen);
    return points;
  }

  static double _polylineLength(List<Offset> pts) {
    var len = 0.0;
    for (var i = 1; i < pts.length; i++) {
      len += (pts[i] - pts[i - 1]).distance;
    }
    return len;
  }

  static Offset _pointAlong(List<Offset> pts, double distance) {
    if (pts.isEmpty) return Offset.zero;
    if (pts.length == 1 || distance <= 0) return pts.first;
    var left = distance;
    for (var i = 1; i < pts.length; i++) {
      final seg = pts[i] - pts[i - 1];
      final segLen = seg.distance;
      if (segLen < 1e-6) continue;
      if (left <= segLen) {
        return pts[i - 1] + seg * (left / segLen);
      }
      left -= segLen;
    }
    return pts.last;
  }

  /// Sliding window of fixed body length along [rail], starting at [start].
  static List<Offset> _windowAlong(
    List<Offset> rail,
    double start,
    double bodyLen,
  ) {
    if (rail.length < 2) return rail;
    const samples = 12;
    final out = <Offset>[
      for (var i = 0; i <= samples; i++)
        _pointAlong(rail, start + bodyLen * (i / samples)),
    ];
    // Drop near-duplicates so joins stay clean.
    final cleaned = <Offset>[out.first];
    for (var i = 1; i < out.length; i++) {
      if ((out[i] - cleaned.last).distance > 0.5) cleaned.add(out[i]);
    }
    if (cleaned.length < 2) cleaned.add(out.last);
    return cleaned;
  }

  List<Offset> _escapingPolylinePoints() {
    final rail = _escapeRail();
    if (rail.length < 2) return rail;
    final bodyPts = _polylinePoints();
    final bodyLen = _polylineLength(bodyPts);
    final railLen = _polylineLength(rail);
    final maxStart = math.max(0.0, railLen - bodyLen);
    final t = Curves.easeOutCubic.transform(_exitController.value);
    final start = t * maxStart;
    return _windowAlong(rail, start, bodyLen);
  }

  /// Wrong-tap: same snake window as escape, but only toward the blocker and back.
  List<Offset> _wrongBumpPolylinePoints() {
    final cell = widget.cellSize;
    final bodyPts = _polylinePoints();
    if (bodyPts.length < 2) return bodyPts;
    final bumpDist = _activeWrongBumpCells * cell;
    if (bumpDist <= 0) return bodyPts;

    final rail = List<Offset>.from(bodyPts);
    rail.add(rail.last + _tipUnit(widget.arrow.direction) * bumpDist);

    final bodyLen = _polylineLength(bodyPts);
    final maxStart = bumpDist;
    final start = _wrongBumpAnimation.value * maxStart;
    return _windowAlong(rail, start, bodyLen);
  }

  void _syncGuideAnimations() {
    if (widget.highlighted && !widget.tutorialHand) {
      _glowController.repeat(reverse: true);
    } else {
      _glowController.stop();
      _glowController.value = 0;
    }
    if (widget.tutorialHand) {
      _handController.repeat(reverse: true);
    } else {
      _handController.stop();
      _handController.value = 0;
    }
  }

  void _startExit() {
    if (_exitStarted || _exitFinished) return;
    _exitStarted = true;
    _feedback = ArrowTapFeedback.correct;
    // Entrance may still be at 0 opacity — force full visibility for escape.
    _entranceController.stop();
    _entranceController.value = 1;
    _exitOffset = _buildExitOffset(widget.arrow.direction);
    _exitController.forward(from: 0);
    if (mounted) setState(() {});
  }

  @override
  void didUpdateWidget(covariant ArrowTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.arrow.direction != oldWidget.arrow.direction ||
        widget.cellSize != oldWidget.cellSize ||
        widget.gridRows != oldWidget.gridRows ||
        widget.gridCols != oldWidget.gridCols) {
      _exitOffset = _buildExitOffset(widget.arrow.direction);
    }
    if (widget.arrow.isRemoved && !oldWidget.arrow.isRemoved) {
      _startExit();
    } else if (!widget.arrow.isRemoved && oldWidget.arrow.isRemoved) {
      // Restart / reset: restore arrow on the board.
      _exitController.stop();
      _exitController.value = 0;
      _exitStarted = false;
      _exitFinished = false;
      _feedback = ArrowTapFeedback.none;
    }
    if (widget.shakeToken != _lastShakeToken) {
      _lastShakeToken = widget.shakeToken;
      _feedback = ArrowTapFeedback.wrong;
      _activeWrongBumpCells = widget.wrongBumpCells;
      _wrongColorController.forward(from: 0);
      if (widget.wrongBumpCells > 0) {
        // Primary: slide to blocker, stay red, return → black.
        _wrongBumpController.forward(from: 0);
      } else {
        // Blocker partner: flash red only, then black.
        _shakeController.forward(from: 0).then((_) {
          widget.onShakeCompleted?.call();
        });
      }
    }
    if (widget.highlighted != oldWidget.highlighted ||
        widget.tutorialHand != oldWidget.tutorialHand) {
      _syncGuideAnimations();
    }
  }

  @override
  void dispose() {
    _shakeController.dispose();
    _glowController.dispose();
    _handController.dispose();
    _exitController.dispose();
    _wrongColorController.dispose();
    _wrongBumpController.dispose();
    _entranceController.dispose();
    super.dispose();
  }

  Color _resolvePaintColor(Color base) {
    if (_feedback == ArrowTapFeedback.correct) {
      return AppColors.accentTeal;
    }
    if (_feedback == ArrowTapFeedback.wrong) {
      // Stay fully red while bumping toward/away from blocker.
      if (_activeWrongBumpCells > 0 &&
          (_wrongBumpController.isAnimating ||
              _wrongBumpController.value > 0)) {
        return AppColors.heartRed;
      }
      // Solid red for most of the flash, then ease back to base.
      final t = _wrongColorController.value;
      if (t < 0.72) return AppColors.heartRed;
      final flash = 1.0 - (t - 0.72) / 0.28;
      return Color.lerp(base, AppColors.heartRed, flash.clamp(0.0, 1.0))!;
    }
    return base;
  }

  /// Straight shaft confined to this arrow's own cell (Level 1 / generated).
  ({Offset tip, Offset tail}) _straightLine() {
    final cell = widget.cellSize;
    final left = widget.arrow.col * cell;
    final top = widget.arrow.row * cell;
    final cx = left + cell / 2;
    final cy = top + cell / 2;

    return switch (widget.arrow.direction) {
      ArrowDirection.up => (
          tip: Offset(cx, top + cell * 0.06),
          tail: Offset(cx, top + cell * 0.94),
        ),
      ArrowDirection.down => (
          tip: Offset(cx, top + cell * 0.94),
          tail: Offset(cx, top + cell * 0.06),
        ),
      ArrowDirection.left => (
          tip: Offset(left + cell * 0.12, cy),
          tail: Offset(left + cell * 0.88, cy),
        ),
      ArrowDirection.right => (
          tip: Offset(left + cell * 0.88, cy),
          tail: Offset(left + cell * 0.12, cy),
        ),
    };
  }

  List<Offset> _polylinePoints() {
    final cell = widget.cellSize;
    final points = <Offset>[
      for (final c in widget.arrow.path)
        Offset((c.col + 0.5) * cell, (c.row + 0.5) * cell),
    ];
    if (points.isEmpty) return points;

    // Keep tip-cell center, then extend along facing dir so the last segment
    // stays axis-aligned (never diagonal when path + tip direction differ).
    final nudge = cell * 0.28;
    points.add(
      points.last +
          switch (widget.arrow.direction) {
            ArrowDirection.up => Offset(0, -nudge),
            ArrowDirection.down => Offset(0, nudge),
            ArrowDirection.left => Offset(-nudge, 0),
            ArrowDirection.right => Offset(nudge, 0),
          },
    );
    return points;
  }

  @override
  Widget build(BuildContext context) {
    if (_exitFinished) return const SizedBox.shrink();

    final colors = context.appColors;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    // Light: #0E1726 · Dark: #EEF3F8
    final baseColor =
        isDark ? colors.arrowLight : ArrowTile.referenceArrowColor;
    final cell = widget.cellSize;
    // Unity reference uses a thin, uniform stroke relative to its grid step
    // (Line prefab widthMultiplier: 0.1) rather than the thicker ~0.2 ratio
    // this used before — thinned toward that reference while keeping a
    // slightly higher floor/ceiling for touch-target legibility on mobile.
    // Dense / large grids (daily ~100 arrows): thinner stroke so board stays readable.
    final strokeWidth = (cell * 0.15).clamp(1.6, 4.0);
    final multi = widget.arrow.isMultiCell;

    return AnimatedBuilder(
      animation: Listenable.merge([
        _shakeController,
        _glowController,
        _handController,
        _exitController,
        _wrongColorController,
        _wrongBumpController,
        _entranceController,
      ]),
      builder: (context, _) {
        final t = _glowController.value;
        final ringScale = 1.0 + 0.3 * t;
        final ringOpacity = 0.6 * (1.0 - t);
        final paintColor = _resolvePaintColor(baseColor);
        // While escaping, ignore entrance opacity/scale so the slide is visible.
        final entranceOp = _exitStarted ? 1.0 : _entranceOpacity.value;
        final entranceSc = _exitStarted ? 1.0 : _entranceScale.value;
        // Level-1 tutorial: pulse the arrow itself (no separate hand/rings icon).
        final tutorialPulse = widget.tutorialHand && !_exitStarted
            ? 1.0 + 0.14 * _handController.value
            : 1.0;
        final combinedScale = entranceSc * tutorialPulse;

        final tipCell = Offset(
          (widget.arrow.col + 0.5) * cell,
          (widget.arrow.row + 0.5) * cell,
        );

        final bump = _wrongBumpAnimation.value * _activeWrongBumpCells * cell;
        final bumpOffset = _tipUnit(widget.arrow.direction) * bump;
        final bumping = _activeWrongBumpCells > 0 &&
            (_wrongBumpController.isAnimating ||
                _wrongBumpController.value > 0);

        Widget painted;
        final boardW = widget.gridCols * cell;
        final boardH = widget.gridRows * cell;
        if (multi) {
          // Nested / L: snake along path (escape or wrong-tap bump).
          final pts = _exitStarted
              ? _escapingPolylinePoints()
              : bumping
                  ? _wrongBumpPolylinePoints()
                  : _polylinePoints();
          // Small pad so the stroke can reach the rim before the board clip hides it.
          final escapePad = (_exitStarted || bumping) ? cell * 0.85 : 0.0;
          final paintW = boardW + escapePad * 2;
          final paintH = boardH + escapePad * 2;
          final shifted = escapePad > 0
              ? [
                  for (final p in pts)
                    Offset(p.dx + escapePad, p.dy + escapePad),
                ]
              : pts;
          painted = OverflowBox(
            minWidth: boardW,
            maxWidth: paintW,
            minHeight: boardH,
            maxHeight: paintH,
            alignment: Alignment.center,
            child: CustomPaint(
              size: Size(paintW, paintH),
              painter: ArrowPolylinePainter(
                points: shifted,
                color: paintColor,
                strokeWidth: strokeWidth,
                direction: widget.arrow.direction,
              ),
            ),
          );
        } else {
          final line = _straightLine();
          final minX = math.min(line.tip.dx, line.tail.dx);
          final maxX = math.max(line.tip.dx, line.tail.dx);
          final minY = math.min(line.tip.dy, line.tail.dy);
          final maxY = math.max(line.tip.dy, line.tail.dy);
          final pad = strokeWidth * 2.2;
          final left = minX - pad;
          final top = minY - pad;
          final width = (maxX - minX) + pad * 2;
          final height = (maxY - minY) + pad * 2;
          painted = SizedBox(
            width: boardW,
            height: boardH,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned(
                  left: left,
                  top: top,
                  width: width,
                  height: height,
                  child: CustomPaint(
                    size: Size(width, height),
                    painter: ArrowPathPainter(
                      tip: line.tip - Offset(left, top),
                      tail: line.tail - Offset(left, top),
                      color: paintColor,
                      strokeWidth: strokeWidth,
                      direction: widget.arrow.direction,
                    ),
                  ),
                ),
              ],
            ),
          );
        }

        // Escape / wrong-bump: multi snakes in paint; single uses tip-axis translate.
        final exitDx =
            (!multi && _exitStarted) ? _exitOffset.value.dx : 0.0;
        final exitDy =
            (!multi && _exitStarted) ? _exitOffset.value.dy : 0.0;
        final shakeX = _activeWrongBumpCells > 0 ? 0.0 : _shakeAnimation.value;
        final wrongDx = (!multi && bumping) ? bumpOffset.dx : 0.0;
        final wrongDy = (!multi && bumping) ? bumpOffset.dy : 0.0;

        return Opacity(
          opacity: (_exitStarted ? _exitOpacity.value : 1) * entranceOp,
          child: Transform.translate(
            offset: Offset(
              exitDx + shakeX + wrongDx,
              exitDy + wrongDy,
            ),
            child: Transform.scale(
              scale: combinedScale,
              alignment: Alignment(
                (tipCell.dx / (widget.gridCols * cell)) * 2 - 1,
                (tipCell.dy / (widget.gridRows * cell)) * 2 - 1,
              ),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  if (widget.highlighted && !widget.tutorialHand)
                    Positioned(
                      left: tipCell.dx - cell * 0.55 * ringScale,
                      top: tipCell.dy - cell * 0.55 * ringScale,
                      width: cell * 1.1 * ringScale,
                      height: cell * 1.1 * ringScale,
                      child: IgnorePointer(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: colors.accentTeal
                                  .withValues(alpha: ringOpacity),
                              width: 3,
                            ),
                          ),
                        ),
                      ),
                    ),
                  // Paint layer — ignore pointer; cells handle taps.
                  IgnorePointer(child: painted),
                  for (final c in widget.arrow.path)
                    Positioned(
                      left: c.col * cell,
                      top: c.row * cell,
                      width: cell,
                      height: cell,
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: widget.arrow.isRemoved || _exitStarted
                            ? null
                            : widget.onTap,
                        child: const SizedBox.expand(),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Multi-cell rounded polyline + triangular head (Level 2 nested paths).
class ArrowPolylinePainter extends CustomPainter {
  ArrowPolylinePainter({
    required this.points,
    required this.color,
    required this.direction,
    this.strokeWidth = 5,
  });

  final List<Offset> points;
  final Color color;
  final ArrowDirection direction;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    if (points.length < 2) return;

    // Unity reference (Line (1).prefab): numCornerVertices: 0, numCapVertices: 0
    // — sharp miter joins + flat butt caps, not rounded. Matches the crisp
    // blocky maze look in the reference screenshots.
    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.butt
      ..strokeJoin = StrokeJoin.miter
      ..isAntiAlias = true;

    final tip = points.last;
    final headLen = (strokeWidth * 2.6).clamp(7.0, 13.0);
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
    _drawHead(canvas, tip, headLen);
  }

  void _drawHead(Canvas canvas, Offset tip, double headLen) {
    final headHalf = headLen * 0.5;

    // Follow local tangent (L bends + escape slide) instead of fixed enum.
    final prev = points[points.length - 2];
    final unit = tip - prev;
    final angle = unit.distance < 1e-6
        ? switch (direction) {
            ArrowDirection.up => -math.pi / 2,
            ArrowDirection.down => math.pi / 2,
            ArrowDirection.left => math.pi,
            ArrowDirection.right => 0.0,
          }
        : math.atan2(unit.dy, unit.dx);

    Offset rot(double x, double y) {
      final c = math.cos(angle);
      final s = math.sin(angle);
      return Offset(tip.dx + x * c - y * s, tip.dy + x * s + y * c);
    }

    final path = Path()
      ..moveTo(tip.dx, tip.dy)
      ..lineTo(rot(-headLen, -headHalf).dx, rot(-headLen, -headHalf).dy)
      ..lineTo(rot(-headLen, headHalf).dx, rot(-headLen, headHalf).dy)
      ..close();

    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.fill
        ..isAntiAlias = true,
    );
  }

  @override
  bool shouldRepaint(covariant ArrowPolylinePainter oldDelegate) {
    if (oldDelegate.color != color ||
        oldDelegate.direction != direction ||
        oldDelegate.strokeWidth != strokeWidth ||
        oldDelegate.points.length != points.length) {
      return true;
    }
    for (var i = 0; i < points.length; i++) {
      if (oldDelegate.points[i] != points[i]) return true;
    }
    return false;
  }
}

/// Draws one straight thick stroke with a solid triangular arrowhead.
class ArrowPathPainter extends CustomPainter {
  ArrowPathPainter({
    required this.tip,
    required this.tail,
    required this.color,
    required this.direction,
    this.strokeWidth = 5,
  });

  final Offset tip;
  final Offset tail;
  final Color color;
  final ArrowDirection direction;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    // Flat butt cap to match the Unity reference (numCapVertices: 0).
    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.butt
      ..isAntiAlias = true;

    final headLen = (strokeWidth * 2.6).clamp(7.0, 13.0);
    final unit = tip - tail;
    final len = unit.distance;
    final dir = len == 0 ? Offset.zero : unit / len;
    final shaftEnd = tip - dir * (headLen * 0.55);
    canvas.drawLine(tail, shaftEnd, stroke);
    _drawHead(canvas, headLen);
  }

  void _drawHead(Canvas canvas, double headLen) {
    final headHalf = headLen * 0.5;

    final angle = switch (direction) {
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

    final path = Path()
      ..moveTo(tip.dx, tip.dy)
      ..lineTo(rot(-headLen, -headHalf).dx, rot(-headLen, -headHalf).dy)
      ..lineTo(rot(-headLen, headHalf).dx, rot(-headLen, headHalf).dy)
      ..close();

    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.fill
        ..isAntiAlias = true,
    );
  }

  @override
  bool shouldRepaint(covariant ArrowPathPainter oldDelegate) {
    return oldDelegate.color != color ||
        oldDelegate.direction != direction ||
        oldDelegate.strokeWidth != strokeWidth ||
        oldDelegate.tip != tip ||
        oldDelegate.tail != tail;
  }
}
