import 'dart:math' as math;

import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/material.dart';

/// One scatter speckle. Positions are in board pixels for a cached size.
class _ScatterDot {
  const _ScatterDot(this.x, this.y, this.radius);

  final double x;
  final double y;
  final double radius;
}

/// Lifetime cache so rebuilds / arrow ticks never re-roll the scatter.
class _ScatterDotCache {
  _ScatterDotCache._();

  /// Previous grid used 15px spacing → ~1/225 dots per px².
  static const referenceSpacing = 15.0;

  static final Map<int, List<_ScatterDot>> _byKey = {};

  static List<_ScatterDot> dotsFor({
    required int seed,
    required Size size,
    required double densityScale,
    required double radiusScale,
  }) {
    if (size.isEmpty || densityScale <= 0) return const [];
    final qw = (size.width * 2).round();
    final qh = (size.height * 2).round();
    final key = Object.hash(
      seed,
      qw,
      qh,
      (densityScale * 100).round(),
      (radiusScale * 100).round(),
    );
    return _byKey.putIfAbsent(
      key,
      () => _generate(
        seed: seed,
        width: qw / 2,
        height: qh / 2,
        densityScale: densityScale,
        radiusScale: radiusScale,
      ),
    );
  }

  static List<_ScatterDot> _generate({
    required int seed,
    required double width,
    required double height,
    required double densityScale,
    required double radiusScale,
  }) {
    final area = width * height;
    final cell = referenceSpacing * referenceSpacing;
    final count = math.max(1, (area / cell * densityScale).round());
    final rng = math.Random(seed);
    return List<_ScatterDot>.generate(count, (_) {
      return _ScatterDot(
        rng.nextDouble() * width,
        rng.nextDouble() * height,
        (0.6 + rng.nextDouble() * 0.8) * radiusScale,
      );
    });
  }
}

/// Diagonal teal → gold wash above the solid fill. Static, no animation cost.
class PatternBoardWashPainter extends CustomPainter {
  PatternBoardWashPainter({
    required this.colors,
    this.stops = const [0.0, 0.46, 1.0],
    this.radius = 0,
  });

  factory PatternBoardWashPainter.theme({
    required bool isDark,
    required Color accentTeal,
    required Color accentTealSoft,
    required Color gold,
    double radius = 0,
  }) {
    return PatternBoardWashPainter(
      radius: radius,
      colors: isDark
          ? [
              accentTeal.withValues(alpha: 0.12),
              accentTeal.withValues(alpha: 0),
              gold.withValues(alpha: 0.09),
            ]
          : [
              accentTealSoft.withValues(alpha: 0.50),
              accentTealSoft.withValues(alpha: 0),
              gold.withValues(alpha: 0.08),
            ],
    );
  }

  final List<Color> colors;
  final List<double> stops;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty || colors.length < 2) return;
    final rect = Offset.zero & size;
    if (radius > 0) {
      canvas.clipRRect(
        RRect.fromRectAndRadius(rect, Radius.circular(radius)),
      );
    }
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: colors,
          stops: stops,
        ).createShader(rect),
    );
  }

  @override
  bool shouldRepaint(covariant PatternBoardWashPainter oldDelegate) {
    return oldDelegate.radius != radius ||
        !listEquals(oldDelegate.stops, stops) ||
        !listEquals(oldDelegate.colors, colors);
  }
}

/// Static scattered grain. [shouldRepaint] ignores animation rebuilds;
/// positions are cached for [seed] + quantized size.
class PatternBoardTexturePainter extends CustomPainter {
  PatternBoardTexturePainter({
    required this.color,
    required this.seed,
    this.densityScale = 1,
    this.radiusScale = 1,
  });

  final Color color;
  final int seed;
  final double densityScale;
  final double radiusScale;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final dots = _ScatterDotCache.dotsFor(
      seed: seed,
      size: size,
      densityScale: densityScale,
      radiusScale: radiusScale,
    );
    if (dots.isEmpty) return;
    final paint = Paint()
      ..color = color
      ..isAntiAlias = true;
    for (final dot in dots) {
      canvas.drawCircle(Offset(dot.x, dot.y), dot.radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant PatternBoardTexturePainter oldDelegate) {
    return oldDelegate.color != color ||
        oldDelegate.seed != seed ||
        oldDelegate.densityScale != densityScale ||
        oldDelegate.radiusScale != radiusScale;
  }
}

/// Inward-fading edge wash so the board reads slightly recessed.
class PatternBoardInnerShadowPainter extends CustomPainter {
  PatternBoardInnerShadowPainter({
    required this.color,
    this.extent = 12,
    this.radius = 0,
  });

  final Color color;
  final double extent;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty || extent <= 0) return;

    if (radius > 0) {
      canvas.clipRRect(
        RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(radius)),
      );
    }

    void edge(Rect band, Alignment begin, Alignment end) {
      if (band.width <= 0 || band.height <= 0) return;
      canvas.save();
      canvas.clipRect(band);
      canvas.drawRect(
        band,
        Paint()
          ..shader = LinearGradient(
            begin: begin,
            end: end,
            colors: [color, color.withValues(alpha: 0)],
          ).createShader(band),
      );
      canvas.restore();
    }

    final w = size.width;
    final h = size.height;
    final e = extent;
    edge(Rect.fromLTWH(0, 0, w, e), Alignment.topCenter, Alignment.bottomCenter);
    edge(
      Rect.fromLTWH(0, h - e, w, e),
      Alignment.bottomCenter,
      Alignment.topCenter,
    );
    edge(Rect.fromLTWH(0, 0, e, h), Alignment.centerLeft, Alignment.centerRight);
    edge(
      Rect.fromLTWH(w - e, 0, e, h),
      Alignment.centerRight,
      Alignment.centerLeft,
    );
  }

  @override
  bool shouldRepaint(covariant PatternBoardInnerShadowPainter oldDelegate) {
    return oldDelegate.color != color ||
        oldDelegate.extent != extent ||
        oldDelegate.radius != radius;
  }
}

/// Center stays clear; corners pick up a faint dark wash.
class PatternBoardVignettePainter extends CustomPainter {
  PatternBoardVignettePainter({
    required this.color,
    this.radius = 0,
  });

  final Color color;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final rect = Offset.zero & size;
    if (radius > 0) {
      canvas.clipRRect(
        RRect.fromRectAndRadius(rect, Radius.circular(radius)),
      );
    }
    canvas.drawRect(
      rect,
      Paint()
        ..shader = RadialGradient(
          center: Alignment.center,
          radius: 1.08,
          colors: [color.withValues(alpha: 0), color],
          stops: const [0.42, 1.0],
        ).createShader(rect),
    );
  }

  @override
  bool shouldRepaint(covariant PatternBoardVignettePainter oldDelegate) {
    return oldDelegate.color != color || oldDelegate.radius != radius;
  }
}

/// 1px inset rim just inside the teal border.
class PatternBoardHairlinePainter extends CustomPainter {
  PatternBoardHairlinePainter({
    required this.color,
    required this.radius,
    this.inset = 3.5,
    this.strokeWidth = 1,
  });

  final Color color;
  final double radius;
  final double inset;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final rect = (Offset.zero & size).deflate(inset);
    if (rect.width <= 0 || rect.height <= 0) return;
    final r = (radius - inset).clamp(0.0, radius);
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, Radius.circular(r)),
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..isAntiAlias = true,
    );
  }

  @override
  bool shouldRepaint(covariant PatternBoardHairlinePainter oldDelegate) {
    return oldDelegate.color != color ||
        oldDelegate.radius != radius ||
        oldDelegate.inset != inset ||
        oldDelegate.strokeWidth != strokeWidth;
  }
}
