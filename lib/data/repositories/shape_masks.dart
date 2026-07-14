/// Grid shape masks for special campaign levels (e.g. heart silhouette).

List<List<bool>> generateHeartShapeMask(int gridSize) {
  final mask = List.generate(
    gridSize,
    (_) => List<bool>.filled(gridSize, false),
  );

  for (var row = 0; row < gridSize; row++) {
    for (var col = 0; col < gridSize; col++) {
      final x = ((col + 0.5) / gridSize) * 2.55 - 1.275;
      final y = -(((row + 0.5) / gridSize) * 2.55 - 1.275) + 0.18;

      if (_isInsideHeart(x, y)) {
        mask[row][col] = true;
      }
    }
  }

  return mask;
}

bool _isInsideHeart(double x, double y) {
  final term1 = x * x + y * y - 1;
  final left = term1 * term1 * term1;
  final right = x * x * y * y * y;
  return left - right <= 0;
}

/// Ring / donut — thick outer band with a hollow center (harder escapes).
List<List<bool>> ringMask(int rows, int cols) {
  final cy = (rows - 1) / 2.0;
  final cx = (cols - 1) / 2.0;
  final ry = cy == 0 ? 1.0 : cy;
  final rx = cx == 0 ? 1.0 : cx;
  return List.generate(rows, (r) {
    return List.generate(cols, (c) {
      final ny = (r - cy) / ry;
      final nx = (c - cx) / rx;
      final d2 = nx * nx + ny * ny;
      return d2 <= 1.02 && d2 >= 0.22;
    });
  });
}

/// Thick ring — smaller hole, wider playable band (clearer campaign nests).
List<List<bool>> thickRingMask(int rows, int cols) {
  final cy = (rows - 1) / 2.0;
  final cx = (cols - 1) / 2.0;
  final ry = cy == 0 ? 1.0 : cy;
  final rx = cx == 0 ? 1.0 : cx;
  return List.generate(rows, (r) {
    return List.generate(cols, (c) {
      final ny = (r - cy) / ry;
      final nx = (c - cx) / rx;
      final d2 = nx * nx + ny * ny;
      // Inner hole ~0.45 radius² → readable donut without sparse spokes.
      return d2 <= 1.0 && d2 >= 0.42;
    });
  });
}

/// Four-petal clover (more concave than a circle / hex).
List<List<bool>> cloverMask(int rows, int cols) {
  final cy = (rows - 1) / 2.0;
  final cx = (cols - 1) / 2.0;
  final ry = cy == 0 ? 1.0 : cy * 0.92;
  final rx = cx == 0 ? 1.0 : cx * 0.92;
  // Petal centers in unit space.
  const petals = [
    (0.0, -0.42),
    (0.0, 0.42),
    (-0.42, 0.0),
    (0.42, 0.0),
  ];
  const petalR2 = 0.38 * 0.38;
  return List.generate(rows, (r) {
    return List.generate(cols, (c) {
      final ny = (r - cy) / ry;
      final nx = (c - cx) / rx;
      for (final (px, py) in petals) {
        final dx = nx - px;
        final dy = ny - py;
        if (dx * dx + dy * dy <= petalR2) return true;
      }
      // Small center glue so the four lobes stay connected.
      return nx * nx + ny * ny <= 0.12;
    });
  });
}

/// Hourglass / bow silhouette (narrow waist).
List<List<bool>> hourglassMask(int rows, int cols) {
  final mid = (cols - 1) / 2.0;
  return List.generate(rows, (r) {
    final t = rows <= 1 ? 0.5 : r / (rows - 1);
    // Wide at top & bottom, pinched in the middle.
    final pinch = (t - 0.5).abs() * 2.0; // 0 center → 1 edges
    final half = (0.28 + 0.72 * pinch) * mid;
    return List.generate(cols, (c) => (c - mid).abs() <= half + 1e-6);
  });
}

/// Crescent moon (circle minus offset circle).
List<List<bool>> crescentMask(int rows, int cols) {
  final cy = (rows - 1) / 2.0;
  final cx = (cols - 1) / 2.0;
  final ry = cy == 0 ? 1.0 : cy * 0.95;
  final rx = cx == 0 ? 1.0 : cx * 0.95;
  final cutCy = cy - ry * 0.12;
  final cutCx = cx + rx * 0.38;
  final cutRy = ry * 0.78;
  final cutRx = rx * 0.78;
  return List.generate(rows, (r) {
    return List.generate(cols, (c) {
      final ny = (r - cy) / ry;
      final nx = (c - cx) / rx;
      if (nx * nx + ny * ny > 1.0) return false;
      final dy = (r - cutCy) / cutRy;
      final dx = (c - cutCx) / cutRx;
      return dx * dx + dy * dy > 1.0;
    });
  });
}

/// Thick plus / cross (daily variety).
List<List<bool>> plusMask(int rows, int cols) {
  final cy = (rows - 1) / 2.0;
  final cx = (cols - 1) / 2.0;
  final arm = 0.34;
  return List.generate(rows, (r) {
    return List.generate(cols, (c) {
      final dy = (r - cy).abs() / (cy == 0 ? 1 : cy);
      final dx = (c - cx).abs() / (cx == 0 ? 1 : cx);
      return (dx <= arm && dy <= 1.0) || (dy <= arm && dx <= 1.0);
    });
  });
}

/// Shield / teardrop pointing up.
List<List<bool>> shieldMask(int rows, int cols) {
  final cy = (rows - 1) / 2.0;
  final cx = (cols - 1) / 2.0;
  return List.generate(rows, (r) {
    return List.generate(cols, (c) {
      final ny = (r - cy) / (cy == 0 ? 1 : cy);
      final nx = (c - cx) / (cx == 0 ? 1 : cx);
      // Round top + tapering point at bottom.
      if (ny <= 0.15) {
        return nx * nx + (ny + 0.35) * (ny + 0.35) <= 0.85;
      }
      final taper = 0.15 + 0.85 * ((1.0 - ny) / 1.15).clamp(0.0, 1.0);
      return nx.abs() <= taper && ny <= 1.02;
    });
  });
}

/// Soft octagon.
List<List<bool>> octagonMask(int rows, int cols) {
  final cy = (rows - 1) / 2.0;
  final cx = (cols - 1) / 2.0;
  return List.generate(rows, (r) {
    return List.generate(cols, (c) {
      final dy = (r - cy).abs() / (cy == 0 ? 1 : cy);
      final dx = (c - cx).abs() / (cx == 0 ? 1 : cx);
      return dy <= 1.0 && dx <= 1.0 && (dx + dy) <= 1.45;
    });
  });
}

/// Stadium / pill (rounded rectangle).
List<List<bool>> stadiumMask(int rows, int cols) {
  final cy = (rows - 1) / 2.0;
  final cx = (cols - 1) / 2.0;
  final ry = cy * 0.72;
  final rx = cx * 0.95;
  final flat = rx - ry; // horizontal straight section half-length
  return List.generate(rows, (r) {
    return List.generate(cols, (c) {
      final dy = (r - cy).abs();
      final dx = (c - cx).abs();
      if (dx <= flat) return dy <= ry;
      final ex = dx - flat;
      return ex * ex + dy * dy <= ry * ry + 1e-6;
    });
  });
}

/// Six-petal flower.
List<List<bool>> flowerMask(int rows, int cols) {
  final cy = (rows - 1) / 2.0;
  final cx = (cols - 1) / 2.0;
  final ry = cy == 0 ? 1.0 : cy * 0.9;
  final rx = cx == 0 ? 1.0 : cx * 0.9;
  // Petal centers at 60° steps (cos, sin).
  const petals = <(double, double)>[
    (0.48, 0.0),
    (0.24, 0.4157),
    (-0.24, 0.4157),
    (-0.48, 0.0),
    (-0.24, -0.4157),
    (0.24, -0.4157),
  ];
  const petalR2 = 0.32 * 0.32;
  return List.generate(rows, (r) {
    return List.generate(cols, (c) {
      final ny = (r - cy) / ry;
      final nx = (c - cx) / rx;
      for (final (px, py) in petals) {
        final dx = nx - px;
        final dy = ny - py;
        if (dx * dx + dy * dy <= petalR2) return true;
      }
      return nx * nx + ny * ny <= 0.1;
    });
  });
}

/// Infinity / figure-eight (two overlapping lobes).
List<List<bool>> infinityMask(int rows, int cols) {
  final cy = (rows - 1) / 2.0;
  final cx = (cols - 1) / 2.0;
  final ry = cy == 0 ? 1.0 : cy * 0.7;
  final rx = cx == 0 ? 1.0 : cx * 0.48;
  final leftCx = cx - rx * 0.85;
  final rightCx = cx + rx * 0.85;
  return List.generate(rows, (r) {
    return List.generate(cols, (c) {
      final dy = (r - cy) / ry;
      final dlx = (c - leftCx) / rx;
      final drx = (c - rightCx) / rx;
      return (dlx * dlx + dy * dy <= 1.05) || (drx * drx + dy * dy <= 1.05);
    });
  });
}

void debugPrintHeartMask(int gridSize) {
  final mask = generateHeartShapeMask(gridSize);
  for (final row in mask) {
    final line = row.map((inside) => inside ? '█' : '·').join(' ');
    // ignore: avoid_print
    print(line);
  }
}
