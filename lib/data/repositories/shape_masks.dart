import 'dart:math';

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

/// Axis-aligned oval / ellipse (connected).
List<List<bool>> ovalMask(int rows, int cols) {
  final cy = (rows - 1) / 2.0;
  final cx = (cols - 1) / 2.0;
  final ry = cy == 0 ? 1.0 : cy * 0.98;
  final rx = cx == 0 ? 1.0 : cx * 0.78;
  return List.generate(rows, (r) {
    return List.generate(cols, (c) {
      final ny = (r - cy) / ry;
      final nx = (c - cx) / rx;
      return ny * ny + nx * nx <= 1.0;
    });
  });
}

/// Stylized fish facing right (body ellipse + triangle tail, connected).
List<List<bool>> fishMask(int rows, int cols) {
  final cy = (rows - 1) / 2.0;
  final cx = (cols - 1) / 2.0;
  final ry = cy == 0 ? 1.0 : cy;
  final rx = cx == 0 ? 1.0 : cx;
  return List.generate(rows, (r) {
    return List.generate(cols, (c) {
      final ny = (r - cy) / ry;
      final nx = (c - cx) / rx;
      // Body: horizontal ellipse shifted left of center.
      final by = ny / 0.55;
      final bx = (nx + 0.08) / 0.62;
      final inBody = by * by + bx * bx <= 1.0 && nx > -0.72 && nx < 0.55;
      // Tail: V pointing left.
      final inTail = nx <= -0.45 &&
          nx >= -1.02 &&
          ny.abs() <= 0.55 * (-0.35 - nx).clamp(0.15, 0.7);
      // Dorsal bump (connected).
      final inFin = nx > -0.15 &&
          nx < 0.25 &&
          ny < -0.25 &&
          ny > -0.72 &&
          (nx + 0.05).abs() * 2.2 + (-0.35 - ny) < 0.55;
      return inBody || inTail || inFin;
    });
  });
}

/// Butterfly — two wing lobes + center body (center glue keeps connected).
List<List<bool>> butterflyMask(int rows, int cols) {
  final cy = (rows - 1) / 2.0;
  final cx = (cols - 1) / 2.0;
  final ry = cy == 0 ? 1.0 : cy * 0.95;
  final rx = cx == 0 ? 1.0 : cx * 0.95;
  return List.generate(rows, (r) {
    return List.generate(cols, (c) {
      final ny = (r - cy) / ry;
      final nx = (c - cx) / rx;
      // Upper wings.
      final ulx = (nx + 0.38) / 0.42;
      final uly = (ny + 0.22) / 0.38;
      final urx = (nx - 0.38) / 0.42;
      final ury = (ny + 0.22) / 0.38;
      final upper =
          (ulx * ulx + uly * uly <= 1.0) || (urx * urx + ury * ury <= 1.0);
      // Lower wings (slightly smaller).
      final llx = (nx + 0.32) / 0.36;
      final lly = (ny - 0.32) / 0.34;
      final lrx = (nx - 0.32) / 0.36;
      final lry = (ny - 0.32) / 0.34;
      final lower =
          (llx * llx + lly * lly <= 1.0) || (lrx * lrx + lry * lry <= 1.0);
      // Body strip.
      final body = nx.abs() <= 0.1 && ny.abs() <= 0.72;
      return upper || lower || body;
    });
  });
}

/// Simple bird outline facing right (round body + beak + head, connected).
List<List<bool>> birdOutlineMask(int rows, int cols) {
  final cy = (rows - 1) / 2.0;
  final cx = (cols - 1) / 2.0;
  final ry = cy == 0 ? 1.0 : cy;
  final rx = cx == 0 ? 1.0 : cx;
  return List.generate(rows, (r) {
    return List.generate(cols, (c) {
      final ny = (r - cy) / ry;
      final nx = (c - cx) / rx;
      // Body oval.
      final bodyY = (ny - 0.08) / 0.48;
      final bodyX = (nx + 0.05) / 0.55;
      final inBody = bodyY * bodyY + bodyX * bodyX <= 1.0;
      // Head.
      final headY = (ny + 0.28) / 0.28;
      final headX = (nx - 0.38) / 0.28;
      final inHead = headY * headY + headX * headX <= 1.0;
      // Beak triangle.
      final inBeak = nx >= 0.55 &&
          nx <= 0.98 &&
          (ny + 0.28).abs() <= 0.22 * (1.0 - (nx - 0.55) / 0.45);
      // Wing lobe on top-left of body.
      final wingY = (ny + 0.15) / 0.28;
      final wingX = (nx + 0.15) / 0.35;
      final inWing = wingY * wingY + wingX * wingX <= 1.0 && ny < 0.05;
      return inBody || inHead || inBeak || inWing;
    });
  });
}

/// Simple cat-face silhouette (round head + ears, connected).
List<List<bool>> catFaceMask(int rows, int cols) {
  final cy = (rows - 1) / 2.0;
  final cx = (cols - 1) / 2.0;
  final ry = cy == 0 ? 1.0 : cy * 0.92;
  final rx = cx == 0 ? 1.0 : cx * 0.92;
  return List.generate(rows, (r) {
    return List.generate(cols, (c) {
      final ny = (r - cy) / ry;
      final nx = (c - cx) / rx;
      // Round face.
      final inFace = nx * nx + (ny - 0.08) * (ny - 0.08) / 0.95 <= 0.85;
      // Left / right ears (triangles glued to top of head).
      final inLeftEar = nx >= -0.72 &&
          nx <= -0.12 &&
          ny <= -0.35 &&
          ny >= -1.02 &&
          (ny + 1.0) <= 1.35 * (-0.12 - nx).abs().clamp(0.05, 0.7);
      final inRightEar = nx <= 0.72 &&
          nx >= 0.12 &&
          ny <= -0.35 &&
          ny >= -1.02 &&
          (ny + 1.0) <= 1.35 * (nx - 0.12).abs().clamp(0.05, 0.7);
      // Chin glue.
      final inChin = nx.abs() <= 0.35 && ny >= 0.55 && ny <= 0.92;
      return inFace || inLeftEar || inRightEar || inChin;
    });
  });
}

/// Side-view car facing right (cabin + chassis + two wheels, connected).
List<List<bool>> generateCarShapeMask(int gridSize) {
  final mask = List.generate(
    gridSize,
    (_) => List<bool>.filled(gridSize, false),
  );

  for (var row = 0; row < gridSize; row++) {
    for (var col = 0; col < gridSize; col++) {
      // Fill most of the square so the car stays prominent on a 32 grid.
      final nx = ((col + 0.5) / gridSize) * 2.05 - 1.025;
      final ny = ((row + 0.5) / gridSize) * 2.05 - 1.025;
      if (_isInsideCar(nx, ny)) {
        mask[row][col] = true;
      }
    }
  }

  return mask;
}

bool _isInsideCar(double nx, double ny) {
  // Cabin / greenhouse — taller, windshield slants forward.
  final cabinT = ((ny + 0.50) / 0.58).clamp(0.0, 1.0);
  final cabinLeft = -0.42;
  final cabinRight = -0.06 + 0.50 * cabinT;
  final inCabin = ny >= -0.52 &&
      ny <= 0.12 &&
      nx >= cabinLeft &&
      nx <= cabinRight;

  // Main chassis — long rounded body.
  final inBody = ny >= -0.06 &&
      ny <= 0.50 &&
      nx >= -0.94 &&
      nx <= 0.90 &&
      (ny - 0.22).abs() <= 0.30;

  // Front nose.
  final inNose = nx >= 0.58 &&
      nx <= 1.00 &&
      ny >= 0.02 &&
      ny <= 0.44 &&
      (ny - 0.23).abs() <= 0.22 * (1.0 - (nx - 0.58) / 0.48);

  // Rear bumper.
  final inRear = nx <= -0.70 &&
      nx >= -1.04 &&
      ny >= 0.02 &&
      ny <= 0.44 &&
      (ny - 0.23).abs() <= 0.20 * (1.0 - (-0.70 - nx) / 0.36);

  // Wheels overlap the body so the silhouette stays one piece.
  final rearWheel =
      (nx + 0.52) * (nx + 0.52) + (ny - 0.52) * (ny - 0.52) <= 0.22 * 0.22;
  final frontWheel =
      (nx - 0.48) * (nx - 0.48) + (ny - 0.52) * (ny - 0.52) <= 0.22 * 0.22;

  return inCabin || inBody || inNose || inRear || rearWheel || frontWheel;
}

/// 5-point star, point-up — Patterns Level 3 silhouette.
List<List<bool>> generateStarShapeMask(int gridSize) {
  final mask = List.generate(
    gridSize,
    (_) => List<bool>.filled(gridSize, false),
  );

  for (var row = 0; row < gridSize; row++) {
    for (var col = 0; col < gridSize; col++) {
      final nx = ((col + 0.5) / gridSize) * 2.15 - 1.075;
      final ny = ((row + 0.5) / gridSize) * 2.15 - 1.075;
      if (_isInsideStar(nx, ny)) {
        mask[row][col] = true;
      }
    }
  }

  return mask;
}

bool _isInsideStar(double nx, double ny) {
  // Screen y grows down; flip so a tip points up.
  final px = nx;
  final py = -ny;
  final r = sqrt(px * px + py * py);
  if (r < 0.12) return true;
  var ang = atan2(py, px) + pi / 2;
  if (ang < 0) ang += 2 * pi;
  const spikes = 5;
  const outer = 1.0;
  const inner = 0.38;
  final slice = 2 * pi / spikes;
  final a = ang % slice;
  final half = slice / 2;
  final edgeR = a <= half
      ? outer + (inner - outer) * (a / half)
      : inner + (outer - inner) * ((a - half) / half);
  return r <= edgeR * 0.98;
}

void debugPrintHeartMask(int gridSize) {
  final mask = generateHeartShapeMask(gridSize);
  for (final row in mask) {
    final line = row.map((inside) => inside ? '█' : '·').join(' ');
    // ignore: avoid_print
    print(line);
  }
}
