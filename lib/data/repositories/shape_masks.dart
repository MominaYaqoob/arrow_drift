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

List<List<bool>> _maskFromPredicate(
  int gridSize,
  bool Function(double nx, double ny) inside, {
  double span = 2.15,
}) {
  final mask = List.generate(
    gridSize,
    (_) => List<bool>.filled(gridSize, false),
  );
  final half = span / 2;
  for (var row = 0; row < gridSize; row++) {
    for (var col = 0; col < gridSize; col++) {
      final nx = ((col + 0.5) / gridSize) * span - half;
      final ny = ((row + 0.5) / gridSize) * span - half;
      if (inside(nx, ny)) {
        mask[row][col] = true;
      }
    }
  }
  return mask;
}

bool _inEllipse(
  double nx,
  double ny,
  double cx,
  double cy,
  double rx,
  double ry,
) {
  if (rx <= 0 || ry <= 0) return false;
  final dx = (nx - cx) / rx;
  final dy = (ny - cy) / ry;
  return dx * dx + dy * dy <= 1.0;
}

bool _inCapsule(
  double nx,
  double ny,
  double x1,
  double y1,
  double x2,
  double y2,
  double radius,
) {
  final dx = x2 - x1;
  final dy = y2 - y1;
  final len2 = dx * dx + dy * dy;
  if (len2 < 1e-8) {
    return (nx - x1) * (nx - x1) + (ny - y1) * (ny - y1) <= radius * radius;
  }
  var t = ((nx - x1) * dx + (ny - y1) * dy) / len2;
  t = t.clamp(0.0, 1.0);
  final px = x1 + t * dx;
  final py = y1 + t * dy;
  return (nx - px) * (nx - px) + (ny - py) * (ny - py) <= radius * radius;
}

bool _inTriangle(
  double px,
  double py,
  double x1,
  double y1,
  double x2,
  double y2,
  double x3,
  double y3,
) {
  final d = (y2 - y3) * (x1 - x3) + (x3 - x2) * (y1 - y3);
  if (d.abs() < 1e-10) return false;
  final a = ((y2 - y3) * (px - x3) + (x3 - x2) * (py - y3)) / d;
  final b = ((y3 - y1) * (px - x3) + (x1 - x3) * (py - y3)) / d;
  final c = 1.0 - a - b;
  return a >= -1e-6 && b >= -1e-6 && c >= -1e-6;
}

/// Dog side-profile — round head, snout, ear, body, thick legs and tail.
List<List<bool>> generateDogShapeMask(int gridSize) {
  return _maskFromPredicate(gridSize, (nx, ny) {
    final body = _inEllipse(nx, ny, -0.02, 0.18, 0.58, 0.36);
    final head = _inEllipse(nx, ny, 0.48, -0.08, 0.32, 0.30);
    final snout = _inEllipse(nx, ny, 0.78, 0.02, 0.24, 0.16);
    final ear = _inEllipse(nx, ny, 0.34, -0.38, 0.16, 0.24);
    final frontLeg = _inEllipse(nx, ny, 0.26, 0.58, 0.13, 0.24);
    final backLeg = _inEllipse(nx, ny, -0.32, 0.58, 0.14, 0.24);
    final tail = _inEllipse(nx, ny, -0.72, -0.02, 0.24, 0.14);
    return body || head || snout || ear || frontLeg || backLeg || tail;
  });
}

/// Owl — round body, thick ear tufts, eye bulges (filled, not hollow).
List<List<bool>> generateOwlShapeMask(int gridSize) {
  return _maskFromPredicate(gridSize, (nx, ny) {
    final body = _inEllipse(nx, ny, 0, 0.12, 0.58, 0.64);
    final leftTuft = _inEllipse(nx, ny, -0.30, -0.62, 0.18, 0.24);
    final rightTuft = _inEllipse(nx, ny, 0.30, -0.62, 0.18, 0.24);
    final leftEye = _inEllipse(nx, ny, -0.22, -0.12, 0.22, 0.20);
    final rightEye = _inEllipse(nx, ny, 0.22, -0.12, 0.22, 0.20);
    final beak = _inTriangle(nx, ny, 0, 0.18, -0.12, 0.02, 0.12, 0.02);
    return body || leftTuft || rightTuft || leftEye || rightEye || beak;
  });
}

/// Low sports-car side-profile — sleeker and lower than [generateCarShapeMask].
List<List<bool>> generateSportsCarShapeMask(int gridSize) {
  return _maskFromPredicate(gridSize, (nx, ny) {
    final cabinT = ((ny + 0.22) / 0.38).clamp(0.0, 1.0);
    final cabinLeft = -0.18;
    final cabinRight = 0.22 + 0.42 * cabinT;
    final inCabin =
        ny >= -0.24 && ny <= 0.16 && nx >= cabinLeft && nx <= cabinRight;
    final inBody =
        ny >= 0.08 && ny <= 0.42 && nx >= -0.96 && nx <= 0.96;
    final inNose = nx >= 0.62 &&
        nx <= 1.02 &&
        ny >= 0.12 &&
        ny <= 0.40 &&
        (ny - 0.26).abs() <= 0.16 * (1.0 - (nx - 0.62) / 0.42);
    final inRear = nx <= -0.72 &&
        nx >= -1.04 &&
        ny >= 0.12 &&
        ny <= 0.40 &&
        (ny - 0.26).abs() <= 0.15 * (1.0 - (-0.72 - nx) / 0.34);
    final rearWheel =
        (nx + 0.50) * (nx + 0.50) + (ny - 0.46) * (ny - 0.46) <= 0.20 * 0.20;
    final frontWheel =
        (nx - 0.50) * (nx - 0.50) + (ny - 0.46) * (ny - 0.46) <= 0.20 * 0.20;
    return inCabin || inBody || inNose || inRear || rearWheel || frontWheel;
  }, span: 2.05);
}

/// Bicycle side-profile — two thick wheels plus a connected frame.
List<List<bool>> generateBicycleShapeMask(int gridSize) {
  return _maskFromPredicate(gridSize, (nx, ny) {
    const wr = 0.28;
    final rear = _inEllipse(nx, ny, -0.50, 0.30, wr, wr);
    final front = _inEllipse(nx, ny, 0.52, 0.30, wr, wr);
    const bar = 0.11;
    final down = _inCapsule(nx, ny, -0.50, 0.30, 0.08, -0.18, bar);
    final top = _inCapsule(nx, ny, 0.08, -0.18, 0.42, -0.08, bar);
    final seatStay = _inCapsule(nx, ny, -0.50, 0.30, -0.08, -0.22, bar);
    final chain = _inCapsule(nx, ny, -0.50, 0.30, 0.18, 0.30, bar);
    final fork = _inCapsule(nx, ny, 0.52, 0.30, 0.42, -0.08, bar);
    final seat = _inEllipse(nx, ny, -0.08, -0.28, 0.16, 0.10);
    final bars = _inEllipse(nx, ny, 0.46, -0.18, 0.16, 0.10);
    return rear ||
        front ||
        down ||
        top ||
        seatStay ||
        chain ||
        fork ||
        seat ||
        bars;
  });
}

/// Apple with a small top notch, stem, and leaf.
List<List<bool>> generateAppleShapeMask(int gridSize) {
  return _maskFromPredicate(gridSize, (nx, ny) {
    final fruit = _inEllipse(nx, ny, 0, 0.12, 0.70, 0.68);
    final notch = _inEllipse(nx, ny, 0, -0.62, 0.16, 0.14);
    final stem = _inCapsule(nx, ny, 0.0, -0.52, 0.08, -0.82, 0.08);
    final leaf = _inEllipse(nx, ny, 0.26, -0.62, 0.22, 0.11);
    return (fruit && !notch) || stem || leaf;
  });
}

/// Commercial airplane — fuselage, wings, and tail (slight top-down).
List<List<bool>> generateAirplaneShapeMask(int gridSize) {
  return _maskFromPredicate(gridSize, (nx, ny) {
    final fuse = _inEllipse(nx, ny, 0.04, 0.04, 0.88, 0.16);
    final wing = _inEllipse(nx, ny, -0.08, 0.04, 0.28, 0.72);
    final tail = _inEllipse(nx, ny, 0.72, 0.04, 0.16, 0.34);
    final nose = nx >= 0.70 &&
        nx <= 1.02 &&
        (ny - 0.04).abs() <= 0.12 * (1.0 - (nx - 0.70) / 0.34);
    return fuse || wing || tail || nose;
  });
}

/// Rabbit with thick long ears, head, body, and tail.
List<List<bool>> generateRabbitShapeMask(int gridSize) {
  return _maskFromPredicate(gridSize, (nx, ny) {
    final body = _inEllipse(nx, ny, 0.02, 0.32, 0.50, 0.42);
    final head = _inEllipse(nx, ny, 0.40, -0.02, 0.28, 0.26);
    final earL = _inCapsule(nx, ny, 0.26, -0.18, 0.10, -0.90, 0.12);
    final earR = _inCapsule(nx, ny, 0.48, -0.18, 0.46, -0.92, 0.12);
    final tail = _inEllipse(nx, ny, -0.50, 0.40, 0.16, 0.16);
    return body || head || earL || earR || tail;
  });
}

/// Peacock — compact body with a filled fanned tail.
List<List<bool>> generatePeacockShapeMask(int gridSize) {
  return _maskFromPredicate(gridSize, (nx, ny) {
    final fan = ny <= 0.42 && _inEllipse(nx, ny, 0, 0.38, 0.92, 0.92);
    final body = _inEllipse(nx, ny, 0, 0.48, 0.28, 0.36);
    final head = _inEllipse(nx, ny, 0, 0.12, 0.14, 0.14);
    final neck = _inCapsule(nx, ny, 0, 0.28, 0, 0.12, 0.10);
    return fan || body || head || neck;
  });
}

/// Boxy, taller SUV side-profile — distinct from sedan and sports car.
List<List<bool>> generateSuvShapeMask(int gridSize) {
  return _maskFromPredicate(gridSize, (nx, ny) {
    final inCabin =
        ny >= -0.46 && ny <= 0.18 && nx >= -0.78 && nx <= 0.38;
    final inBody =
        ny >= 0.02 && ny <= 0.48 && nx >= -0.94 && nx <= 0.90;
    final inNose = nx >= 0.55 &&
        nx <= 0.98 &&
        ny >= 0.06 &&
        ny <= 0.44 &&
        (ny - 0.25).abs() <= 0.20;
    final rearWheel =
        (nx + 0.50) * (nx + 0.50) + (ny - 0.50) * (ny - 0.50) <= 0.20 * 0.20;
    final frontWheel =
        (nx - 0.46) * (nx - 0.46) + (ny - 0.50) * (ny - 0.50) <= 0.20 * 0.20;
    return inCabin || inBody || inNose || rearWheel || frontWheel;
  }, span: 2.05);
}

/// Motorbike side-profile — two wheels, tank, seat, and fork.
List<List<bool>> generateMotorbikeShapeMask(int gridSize) {
  return _maskFromPredicate(gridSize, (nx, ny) {
    const wr = 0.26;
    final rear = _inEllipse(nx, ny, -0.50, 0.32, wr, wr);
    final front = _inEllipse(nx, ny, 0.52, 0.32, wr, wr);
    final tank = _inEllipse(nx, ny, 0.08, 0.04, 0.40, 0.20);
    final seat = _inEllipse(nx, ny, -0.18, -0.02, 0.28, 0.14);
    final fork = _inCapsule(nx, ny, 0.52, 0.32, 0.28, -0.18, 0.10);
    final bars = _inEllipse(nx, ny, 0.26, -0.22, 0.18, 0.10);
    final engine = _inEllipse(nx, ny, 0.02, 0.22, 0.22, 0.16);
    return rear || front || tank || seat || fork || bars || engine;
  });
}

/// Curved banana — thick tapered crescent, not a thin moon cutout.
List<List<bool>> generateBananaShapeMask(int gridSize) {
  return _maskFromPredicate(gridSize, (nx, ny) {
    if (nx < -0.98 || nx > 0.98) return false;
    final t = ((nx + 0.98) / 1.96).clamp(0.0, 1.0);
    final cy = 0.28 - 0.95 * nx * nx;
    final half = 0.10 + 0.16 * sin(pi * t);
    return (ny - cy).abs() <= half;
  });
}

/// 6-pointed hexagram (Star of David), distinct from the 5-point Patterns star.
List<List<bool>> generateSixPointStarShapeMask(int gridSize) {
  return _maskFromPredicate(gridSize, (nx, ny) {
    final px = nx;
    final py = -ny;
    final up = _inTriangle(px, py, 0, 1.02, 0.92, -0.58, -0.92, -0.58);
    final down = _inTriangle(px, py, 0, -1.02, 0.92, 0.58, -0.92, 0.58);
    return up || down;
  });
}

/// Folded paper airplane — thick dart pointing right.
List<List<bool>> generatePaperPlaneShapeMask(int gridSize) {
  return _maskFromPredicate(gridSize, (nx, ny) {
    final t = ((nx + 0.95) / 1.90).clamp(0.0, 1.0);
    final half = 0.58 * (1.0 - t);
    final inDart = nx >= -0.95 && nx <= 0.98 && ny.abs() <= half.clamp(0.10, 0.58);
    final inSpine = nx >= -0.70 && nx <= 0.90 && ny.abs() <= 0.14;
    return inDart || inSpine;
  });
}

/// Elephant — body, large ear, head, thick trunk, and legs.
List<List<bool>> generateElephantShapeMask(int gridSize) {
  return _maskFromPredicate(gridSize, (nx, ny) {
    final body = _inEllipse(nx, ny, -0.10, 0.10, 0.54, 0.42);
    final head = _inEllipse(nx, ny, 0.42, -0.02, 0.32, 0.32);
    final ear = _inEllipse(nx, ny, 0.18, -0.08, 0.36, 0.42);
    final trunk = _inCapsule(nx, ny, 0.68, 0.08, 0.78, 0.58, 0.12);
    final trunkTip = _inEllipse(nx, ny, 0.72, 0.62, 0.14, 0.12);
    final frontLeg = _inEllipse(nx, ny, 0.18, 0.62, 0.14, 0.22);
    final midLeg = _inEllipse(nx, ny, -0.08, 0.64, 0.14, 0.22);
    final backLeg = _inEllipse(nx, ny, -0.38, 0.62, 0.15, 0.22);
    final tail = _inCapsule(nx, ny, -0.62, 0.08, -0.82, 0.28, 0.08);
    return body ||
        head ||
        ear ||
        trunk ||
        trunkTip ||
        frontLeg ||
        midLeg ||
        backLeg ||
        tail;
  });
}

/// Bold left-pointing arrow — thick triangular head + rectangular shaft.
List<List<bool>> generateLeftArrowShapeMask(int gridSize) {
  return _maskFromPredicate(gridSize, _isInsideLeftArrow);
}

bool _isInsideLeftArrow(double nx, double ny) {
  final inShaft = nx >= -0.18 && nx <= 0.94 && ny.abs() <= 0.30;
  if (nx <= -0.02 && nx >= -1.02) {
    final t = ((nx + 1.02) / 1.00).clamp(0.0, 1.0);
    final half = 0.16 + 0.58 * t;
    if (ny.abs() <= half) return true;
  }
  return inShaft;
}

/// Classic jagged lightning bolt / zigzag.
List<List<bool>> generateLightningBoltShapeMask(int gridSize) {
  return _maskFromPredicate(gridSize, (nx, ny) {
    const bar = 0.16;
    const pts = <(double, double)>[
      (0.22, -0.96),
      (0.42, -0.38),
      (-0.08, -0.18),
      (0.28, 0.32),
      (-0.38, 0.96),
    ];
    for (var i = 0; i < pts.length - 1; i++) {
      if (_inCapsule(
        nx,
        ny,
        pts[i].$1,
        pts[i].$2,
        pts[i + 1].$1,
        pts[i + 1].$2,
        bar,
      )) {
        return true;
      }
    }
    return false;
  });
}

/// Bold right-pointing arrow — mirror of [generateLeftArrowShapeMask].
List<List<bool>> generateRightArrowShapeMask(int gridSize) {
  return _maskFromPredicate(gridSize, (nx, ny) => _isInsideLeftArrow(-nx, ny));
}

/// Wheel / clock — thick outer rim, hub, and wide radial spokes.
List<List<bool>> generateWheelShapeMask(int gridSize) {
  return _maskFromPredicate(gridSize, (nx, ny) {
    final r2 = nx * nx + ny * ny;
    final inRim = r2 <= 0.96 * 0.96 && r2 >= 0.68 * 0.68;
    final inHub = r2 <= 0.30 * 0.30;
    const spokeR = 0.13;
    const spokes = 6;
    for (var i = 0; i < spokes; i++) {
      final ang = i * pi / (spokes / 2);
      final x2 = 0.82 * cos(ang);
      final y2 = 0.82 * sin(ang);
      if (_inCapsule(nx, ny, 0, 0, x2, y2, spokeR)) return true;
    }
    return inRim || inHub;
  });
}

/// Figure-8 / snowman — smaller filled circle stacked on a larger one.
List<List<bool>> generateFigureEightShapeMask(int gridSize) {
  return _maskFromPredicate(gridSize, (nx, ny) {
    final upper = _inEllipse(nx, ny, 0, -0.38, 0.44, 0.44);
    final lower = _inEllipse(nx, ny, 0, 0.34, 0.60, 0.60);
    return upper || lower;
  });
}

/// Sitting cat — round body, pointed ears, thick tail.
List<List<bool>> generateCatShapeMask(int gridSize) {
  return _maskFromPredicate(gridSize, (nx, ny) {
    final body = _inEllipse(nx, ny, -0.08, 0.28, 0.48, 0.42);
    final head = _inEllipse(nx, ny, 0.28, -0.12, 0.34, 0.32);
    final earL = _inCapsule(nx, ny, 0.12, -0.22, 0.18, -0.82, 0.13);
    final earR = _inCapsule(nx, ny, 0.42, -0.22, 0.52, -0.82, 0.13);
    final whisker = _inEllipse(nx, ny, 0.48, -0.02, 0.22, 0.16);
    final tail = _inCapsule(nx, ny, -0.52, 0.22, -0.82, -0.22, 0.14);
    return body || head || earL || earR || whisker || tail;
  });
}

/// Perched bird — folded wing, round body, small beak.
List<List<bool>> generateBirdShapeMask(int gridSize) {
  return _maskFromPredicate(gridSize, (nx, ny) {
    final body = _inEllipse(nx, ny, -0.08, 0.18, 0.48, 0.38);
    final head = _inEllipse(nx, ny, 0.38, -0.18, 0.24, 0.24);
    final beak = _inEllipse(nx, ny, 0.68, -0.14, 0.22, 0.10);
    final wing = _inEllipse(nx, ny, -0.12, 0.08, 0.36, 0.22);
    final tail = _inCapsule(nx, ny, -0.52, 0.18, -0.88, 0.08, 0.14);
    return body || head || beak || wing || tail;
  });
}

/// Pickup / delivery truck side-profile.
List<List<bool>> generateTruckShapeMask(int gridSize) {
  return _maskFromPredicate(gridSize, (nx, ny) {
    final cab = nx >= -0.92 && nx <= -0.18 && ny >= -0.42 && ny <= 0.42;
    final bed = nx >= -0.22 && nx <= 0.92 && ny >= 0.02 && ny <= 0.42;
    final rearWheel =
        (nx + 0.58) * (nx + 0.58) + (ny - 0.50) * (ny - 0.50) <= 0.20 * 0.20;
    final frontWheel =
        (nx - 0.52) * (nx - 0.52) + (ny - 0.50) * (ny - 0.50) <= 0.20 * 0.20;
    return cab || bed || rearWheel || frontWheel;
  }, span: 2.05);
}

/// Scooter — step-through deck, stem, small wheels.
List<List<bool>> generateScooterShapeMask(int gridSize) {
  return _maskFromPredicate(gridSize, (nx, ny) {
    final rear = _inEllipse(nx, ny, -0.48, 0.38, 0.22, 0.22);
    final front = _inEllipse(nx, ny, 0.52, 0.38, 0.22, 0.22);
    final deck = _inCapsule(nx, ny, -0.42, 0.18, 0.22, 0.22, 0.14);
    final stem = _inCapsule(nx, ny, 0.28, 0.18, 0.42, -0.28, 0.13);
    final bars = _inEllipse(nx, ny, 0.42, -0.32, 0.18, 0.10);
    final column = _inEllipse(nx, ny, -0.12, 0.02, 0.16, 0.16);
    return rear || front || deck || stem || bars || column;
  });
}

/// Bunch of grapes — overlapping filled circles plus a short stem.
List<List<bool>> generateGrapesShapeMask(int gridSize) {
  return _maskFromPredicate(gridSize, (nx, ny) {
    const berries = <(double, double)>[
      (0.00, 0.02),
      (0.28, 0.12),
      (-0.28, 0.12),
      (0.14, 0.38),
      (-0.14, 0.38),
      (0.38, 0.40),
      (-0.38, 0.40),
      (0.00, 0.62),
      (0.22, 0.62),
      (-0.22, 0.62),
    ];
    for (final (cx, cy) in berries) {
      if (_inEllipse(nx, ny, cx, cy, 0.22, 0.22)) return true;
    }
    final stem = _inCapsule(nx, ny, 0.0, -0.18, 0.08, -0.58, 0.12);
    final leaf = _inEllipse(nx, ny, 0.22, -0.48, 0.20, 0.10);
    return stem || leaf;
  });
}

/// 5-point star with a thick tapered comet tail.
List<List<bool>> generateShootingStarShapeMask(int gridSize) {
  return _maskFromPredicate(gridSize, (nx, ny) {
    final star = _isInsideStar((nx - 0.28) * 1.65, (ny + 0.18) * 1.65);
    final t1 = _inCapsule(nx, ny, 0.05, 0.02, -0.42, 0.28, 0.18);
    final t2 = _inCapsule(nx, ny, -0.38, 0.26, -0.82, 0.52, 0.15);
    final t3 = _inCapsule(nx, ny, -0.78, 0.50, -0.98, 0.66, 0.12);
    return star || t1 || t2 || t3;
  });
}

/// Helicopter side-profile — cabin, tail boom, thick rotor.
List<List<bool>> generateHelicopterShapeMask(int gridSize) {
  return _maskFromPredicate(gridSize, (nx, ny) {
    final cabin = _inEllipse(nx, ny, -0.18, 0.12, 0.42, 0.32);
    final boom = _inCapsule(nx, ny, 0.18, 0.12, 0.88, 0.08, 0.14);
    final tailFin = _inEllipse(nx, ny, 0.88, -0.02, 0.16, 0.24);
    final rotor = _inCapsule(nx, ny, -0.78, -0.36, 0.68, -0.36, 0.13);
    final mast = _inCapsule(nx, ny, -0.12, -0.08, -0.12, -0.36, 0.12);
    final skid = _inCapsule(nx, ny, -0.48, 0.48, 0.18, 0.48, 0.12);
    return cabin || boom || tailFin || rotor || mast || skid;
  });
}

/// Lion head with a thick mane ring.
List<List<bool>> generateLionShapeMask(int gridSize) {
  return _maskFromPredicate(gridSize, (nx, ny) {
    final mane = _inEllipse(nx, ny, 0, 0.06, 0.72, 0.70);
    final tuftL = _inEllipse(nx, ny, -0.62, 0.02, 0.32, 0.36);
    final tuftR = _inEllipse(nx, ny, 0.62, 0.02, 0.32, 0.36);
    final tuftT = _inEllipse(nx, ny, 0, -0.48, 0.42, 0.28);
    final tuftB = _inEllipse(nx, ny, 0, 0.62, 0.38, 0.26);
    final face = _inEllipse(nx, ny, 0, 0.10, 0.48, 0.46);
    final earL = _inEllipse(nx, ny, -0.32, -0.42, 0.18, 0.16);
    final earR = _inEllipse(nx, ny, 0.32, -0.42, 0.18, 0.16);
    return mane || tuftL || tuftR || tuftT || tuftB || face || earL || earR;
  });
}

/// Duck — round body, head, and thick bill.
List<List<bool>> generateDuckShapeMask(int gridSize) {
  return _maskFromPredicate(gridSize, (nx, ny) {
    final body = _inEllipse(nx, ny, -0.10, 0.22, 0.58, 0.40);
    final head = _inEllipse(nx, ny, 0.38, -0.22, 0.26, 0.26);
    final bill = _inEllipse(nx, ny, 0.72, -0.16, 0.28, 0.12);
    final tail = _inTriangle(nx, ny, -0.62, 0.05, -0.98, -0.08, -0.58, 0.28);
    return body || head || bill || tail;
  });
}

/// Boxy van — taller cabin, short nose, distinct from truck/SUV.
List<List<bool>> generateVanShapeMask(int gridSize) {
  return _maskFromPredicate(gridSize, (nx, ny) {
    final box = nx >= -0.88 && nx <= 0.72 && ny >= -0.48 && ny <= 0.42;
    final nose = nx >= 0.62 && nx <= 0.96 && ny >= 0.02 && ny <= 0.42;
    final rearWheel =
        (nx + 0.50) * (nx + 0.50) + (ny - 0.50) * (ny - 0.50) <= 0.20 * 0.20;
    final frontWheel =
        (nx - 0.48) * (nx - 0.48) + (ny - 0.50) * (ny - 0.50) <= 0.20 * 0.20;
    return box || nose || rearWheel || frontWheel;
  }, span: 2.05);
}

/// Sport motorcycle — low fairing, aggressive stance.
List<List<bool>> generateSportsBikeShapeMask(int gridSize) {
  return _maskFromPredicate(gridSize, (nx, ny) {
    final rear = _inEllipse(nx, ny, -0.48, 0.34, 0.24, 0.24);
    final front = _inEllipse(nx, ny, 0.52, 0.28, 0.24, 0.24);
    final fairing = _inTriangle(nx, ny, -0.15, -0.08, 0.62, -0.22, 0.42, 0.22);
    final tank = _inEllipse(nx, ny, 0.02, 0.02, 0.36, 0.18);
    final tail = _inEllipse(nx, ny, -0.28, -0.02, 0.22, 0.12);
    final fork = _inCapsule(nx, ny, 0.52, 0.28, 0.38, -0.18, 0.12);
    return rear || front || fairing || tank || tail || fork;
  });
}

/// Strawberry — tapered berry with a leafy top.
List<List<bool>> generateStrawberryShapeMask(int gridSize) {
  return _maskFromPredicate(gridSize, (nx, ny) {
    final t = ((ny + 0.55) / 1.45).clamp(0.0, 1.0);
    final half = 0.58 * (1.0 - t * 0.72);
    final inBerry = ny >= -0.42 && ny <= 0.92 && nx.abs() <= half;
    final cap = _inEllipse(nx, ny, 0, -0.48, 0.42, 0.18);
    final leafL = _inEllipse(nx, ny, -0.28, -0.62, 0.22, 0.12);
    final leafR = _inEllipse(nx, ny, 0.28, -0.62, 0.22, 0.12);
    return inBerry || cap || leafL || leafR;
  });
}

/// Many-pointed sparkle burst, denser than the 6-point star.
List<List<bool>> generateStarBurstShapeMask(int gridSize) {
  return _maskFromPredicate(gridSize, _isInsideStarBurst);
}

bool _isInsideStarBurst(double nx, double ny) {
  final px = nx;
  final py = -ny;
  final r = sqrt(px * px + py * py);
  if (r < 0.28) return true;
  var ang = atan2(py, px) + pi / 2;
  if (ang < 0) ang += 2 * pi;
  const spikes = 8;
  const outer = 1.0;
  const inner = 0.36;
  final slice = 2 * pi / spikes;
  final a = ang % slice;
  final half = slice / 2;
  final edgeR = a <= half
      ? outer + (inner - outer) * (a / half)
      : inner + (outer - inner) * ((a - half) / half);
  return r <= edgeR * 0.98;
}

/// Fighter jet — swept wings, narrow fuselage.
List<List<bool>> generateJetFighterShapeMask(int gridSize) {
  return _maskFromPredicate(gridSize, (nx, ny) {
    final fuse = _inEllipse(nx, ny, 0.08, 0.02, 0.90, 0.14);
    final wing = _inTriangle(nx, ny, -0.18, 0.02, 0.22, -0.78, 0.22, 0.78);
    final tail = _inTriangle(nx, ny, 0.52, 0.02, 0.86, -0.36, 0.86, 0.36);
    final nose = nx >= 0.78 &&
        nx <= 1.02 &&
        (ny - 0.02).abs() <= 0.12 * (1.0 - (nx - 0.78) / 0.26);
    return fuse || wing || tail || nose;
  });
}

/// Bear face — round muzzle and round ears.
List<List<bool>> generateBearShapeMask(int gridSize) {
  return _maskFromPredicate(gridSize, (nx, ny) {
    final face = _inEllipse(nx, ny, 0, 0.12, 0.62, 0.58);
    final earL = _inEllipse(nx, ny, -0.48, -0.52, 0.26, 0.24);
    final earR = _inEllipse(nx, ny, 0.48, -0.52, 0.26, 0.24);
    final snout = _inEllipse(nx, ny, 0, 0.38, 0.32, 0.22);
    return face || earL || earR || snout;
  });
}

/// Parrot — curved beak and a long tail.
List<List<bool>> generateParrotShapeMask(int gridSize) {
  return _maskFromPredicate(gridSize, (nx, ny) {
    final body = _inEllipse(nx, ny, -0.02, 0.12, 0.36, 0.48);
    final head = _inEllipse(nx, ny, 0.22, -0.32, 0.26, 0.26);
    final beak = _inEllipse(nx, ny, 0.52, -0.22, 0.22, 0.12);
    final tail = _inCapsule(nx, ny, -0.12, 0.48, -0.26, 0.92, 0.16);
    final wing = _inEllipse(nx, ny, -0.18, 0.08, 0.22, 0.32);
    return body || head || beak || tail || wing;
  });
}

/// Boxy off-road jeep — vertical windshield, short overhangs.
List<List<bool>> generateJeepShapeMask(int gridSize) {
  return _maskFromPredicate(gridSize, (nx, ny) {
    final cabin = nx >= -0.62 && nx <= 0.22 && ny >= -0.42 && ny <= 0.18;
    final body = nx >= -0.82 && nx <= 0.78 && ny >= 0.02 && ny <= 0.42;
    final snorkel = nx >= -0.78 && nx <= -0.52 && ny >= -0.52 && ny <= -0.18;
    final rearWheel =
        (nx + 0.48) * (nx + 0.48) + (ny - 0.52) * (ny - 0.52) <= 0.22 * 0.22;
    final frontWheel =
        (nx - 0.42) * (nx - 0.42) + (ny - 0.52) * (ny - 0.52) <= 0.22 * 0.22;
    return cabin || body || snorkel || rearWheel || frontWheel;
  }, span: 2.05);
}

/// Cruiser motorcycle — long, low wheelbase.
List<List<bool>> generateCruiserBikeShapeMask(int gridSize) {
  return _maskFromPredicate(gridSize, (nx, ny) {
    final rear = _inEllipse(nx, ny, -0.58, 0.32, 0.26, 0.26);
    final front = _inEllipse(nx, ny, 0.62, 0.32, 0.26, 0.26);
    final tank = _inEllipse(nx, ny, -0.02, 0.02, 0.42, 0.16);
    final seat = _inEllipse(nx, ny, -0.32, 0.00, 0.28, 0.12);
    final fork = _inCapsule(nx, ny, 0.62, 0.32, 0.42, -0.12, 0.11);
    final bars = _inEllipse(nx, ny, 0.38, -0.16, 0.16, 0.10);
    final engine = _inEllipse(nx, ny, 0.08, 0.22, 0.22, 0.14);
    return rear || front || tank || seat || fork || bars || engine;
  });
}

/// Watermelon slice — thick rounded wedge.
List<List<bool>> generateWatermelonShapeMask(int gridSize) {
  return _maskFromPredicate(gridSize, (nx, ny) {
    final cy = 0.22;
    final dx = nx;
    final dy = ny - cy;
    final r2 = dx * dx + dy * dy;
    final inDisc = r2 <= 0.88 * 0.88 && ny <= 0.38;
    return inDisc && ny >= -0.72;
  });
}

/// Full moon — filled disc with shallow crater notches on the edge.
List<List<bool>> generateFullMoonShapeMask(int gridSize) {
  return _maskFromPredicate(gridSize, (nx, ny) {
    final disc = nx * nx + ny * ny <= 0.88 * 0.88;
    // Edge bites only — interior holes break nested packing.
    final craterA = _inEllipse(nx, ny, 0.86, -0.36, 0.16, 0.14);
    final craterB = _inEllipse(nx, ny, -0.52, 0.78, 0.18, 0.14);
    return disc && !craterA && !craterB;
  });
}

/// Glider — long slender wings, distinct from jet and airliner.
List<List<bool>> generateGliderShapeMask(int gridSize) {
  return _maskFromPredicate(gridSize, (nx, ny) {
    final fuse = _inEllipse(nx, ny, 0.05, 0.04, 0.72, 0.14);
    final wing = _inEllipse(nx, ny, -0.08, 0.04, 0.22, 0.92);
    final tail = _inEllipse(nx, ny, 0.62, 0.04, 0.14, 0.32);
    return fuse || wing || tail;
  });
}

/// Fox head — pointed ears and a narrow snout.
List<List<bool>> generateFoxShapeMask(int gridSize) {
  return _maskFromPredicate(gridSize, (nx, ny) {
    final face = _inEllipse(nx, ny, 0, 0.12, 0.48, 0.42);
    final earL = _inCapsule(nx, ny, -0.28, -0.12, -0.38, -0.82, 0.14);
    final earR = _inCapsule(nx, ny, 0.28, -0.12, 0.38, -0.82, 0.14);
    final snout = _inTriangle(nx, ny, -0.28, 0.22, 0.28, 0.22, 0.0, 0.82);
    return face || earL || earR || snout;
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
