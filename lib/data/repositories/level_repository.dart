import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:arrow_drift/data/models/arrow_model.dart';
import 'package:arrow_drift/data/models/level_model.dart';
import 'package:arrow_drift/data/repositories/shape_masks.dart';
import 'package:arrow_drift/features/gameplay/game_controller.dart';

/// Result of [generateSolvableLevel], including placement order for tests.
class SolvableLevelResult {
  const SolvableLevelResult({
    required this.level,
    required this.placementOrder,
  });

  final LevelModel level;

  /// Arrow ids in the order they were placed (solve order is the reverse).
  final List<String> placementOrder;
}

/// Builds a solvable level by placing arrows backward.
SolvableLevelResult generateSolvableLevel(
  int levelNumber,
  int gridSize,
  int arrowCount,
  int hearts,
  int hints, {
  LevelDifficulty difficulty = LevelDifficulty.easy,
  int? seed,
  List<List<bool>>? shapeMask,
}) {
  final random = Random(seed ?? levelNumber * 7919 + gridSize * 97 + arrowCount);
  final occupied = <String>{};
  final arrows = <ArrowModel>[];
  final placementOrder = <String>[];

  bool inMask(int row, int col) {
    if (shapeMask == null) return true;
    if (row < 0 ||
        col < 0 ||
        row >= shapeMask.length ||
        col >= shapeMask[row].length) {
      return false;
    }
    return shapeMask[row][col];
  }

  var safety = 0;
  while (arrows.length < arrowCount && safety < 40000) {
    safety++;
    final row = random.nextInt(gridSize);
    final col = random.nextInt(gridSize);
    if (!inMask(row, col)) continue;
    final cellKey = '$row:$col';
    if (occupied.contains(cellKey)) continue;

    final clearDirections = <ArrowDirection>[];
    for (final direction in ArrowDirection.values) {
      final candidate = ArrowModel(
        id: '_probe',
        row: row,
        col: col,
        direction: direction,
      );
      if (isArrowFree(
        arrow: candidate,
        arrows: arrows,
        gridRows: gridSize,
        gridCols: gridSize,
        shapeMask: shapeMask,
      )) {
        clearDirections.add(direction);
      }
    }

    if (clearDirections.isEmpty) continue;

    final direction = difficulty == LevelDifficulty.easy
        ? _preferNearestEdge(row, col, gridSize, clearDirections, random)
        : clearDirections[random.nextInt(clearDirections.length)];

    final id = '$levelNumber-${arrows.length}';
    arrows.add(
      ArrowModel(
        id: id,
        row: row,
        col: col,
        direction: direction,
      ),
    );
    occupied.add(cellKey);
    placementOrder.add(id);
  }

  if (arrows.length < arrowCount) {
    throw StateError(
      'Could only place ${arrows.length}/$arrowCount arrows for level $levelNumber',
    );
  }

  return SolvableLevelResult(
    level: LevelModel(
      levelNumber: levelNumber,
      gridRows: gridSize,
      gridCols: gridSize,
      arrows: arrows,
      heartsAllowed: hearts,
      hintsAllowed: hints,
      difficulty: difficulty,
      shapeMask: shapeMask,
    ),
    placementOrder: List<String>.unmodifiable(placementOrder),
  );
}

ArrowDirection _preferNearestEdge(
  int row,
  int col,
  int gridSize,
  List<ArrowDirection> clearDirections,
  Random random,
) {
  int score(ArrowDirection direction) {
    return switch (direction) {
      ArrowDirection.up => row,
      ArrowDirection.down => gridSize - 1 - row,
      ArrowDirection.left => col,
      ArrowDirection.right => gridSize - 1 - col,
    };
  }

  clearDirections.sort((a, b) => score(a).compareTo(score(b)));
  final bestScore = score(clearDirections.first);
  final best = clearDirections.where((d) => score(d) == bestScore).toList();
  return best[random.nextInt(best.length)];
}

/// Wave-clear depth for each arrow (0 = free at start, 2+ = multi-step dependency).
Map<String, int> arrowClearDepths(LevelModel level) {
  final arrows = cloneArrows(level.arrows);
  final depths = <String, int>{};
  var wave = 0;
  var safety = 0;
  while (arrows.any((a) => !a.isRemoved) && safety < 500) {
    safety++;
    final freeIds = <String>[];
    for (final arrow in arrows) {
      if (arrow.isRemoved) continue;
      if (isArrowFree(
        arrow: arrow,
        arrows: arrows,
        gridRows: level.gridRows,
        gridCols: level.gridCols,
        shapeMask: level.shapeMask,
      )) {
        freeIds.add(arrow.id);
        depths.putIfAbsent(arrow.id, () => wave);
      }
    }
    if (freeIds.isEmpty) break;
    for (final id in freeIds) {
      final index = arrows.indexWhere((a) => a.id == id);
      arrows[index] = arrows[index].copyWith(isRemoved: true);
    }
    wave++;
  }
  return depths;
}

/// Regenerates until blocked-at-start / dependency constraints are met.
SolvableLevelResult generateSolvableLevelWithBias({
  required int levelNumber,
  required int gridSize,
  required int arrowCount,
  required int hearts,
  required int hints,
  required LevelDifficulty difficulty,
  required int minBlockedAtStart,
  required int maxBlockedAtStart,
  int minDepth2Chains = 0,
}) {
  SolvableLevelResult? last;
  for (var attempt = 0; attempt < 250; attempt++) {
    final seed =
        levelNumber * 7919 + gridSize * 97 + arrowCount * 13 + attempt * 131;
    final result = generateSolvableLevel(
      levelNumber,
      gridSize,
      arrowCount,
      hearts,
      hints,
      difficulty: difficulty,
      seed: seed,
    );
    last = result;
    final depths = arrowClearDepths(result.level);
    final blocked = depths.values.where((d) => d > 0).length;
    final depth2 = depths.values.where((d) => d >= 2).length;
    if (blocked >= minBlockedAtStart &&
        blocked <= maxBlockedAtStart &&
        depth2 >= minDepth2Chains) {
      return result;
    }
  }
  return last!;
}

(int, int) _dirDelta(ArrowDirection direction) {
  return switch (direction) {
    ArrowDirection.up => (-1, 0),
    ArrowDirection.down => (1, 0),
    ArrowDirection.left => (0, -1),
    ArrowDirection.right => (0, 1),
  };
}

/// True when non-consecutive body cells share an edge (tight U-turn / hug).
bool _polylineSelfHugs(List<GridCell> path) {
  for (var i = 0; i < path.length; i++) {
    for (var j = i + 2; j < path.length; j++) {
      final a = path[i];
      final b = path[j];
      if ((a.row - b.row).abs() + (a.col - b.col).abs() == 1) {
        return true;
      }
    }
  }
  return false;
}

/// Tips on one row/col aiming at each other (▸ … ◂) confuse escape reading.
/// Only nearby pairs (≤4 cells apart) are rejected so dense packs still fill.
bool _tipsFaceEachOtherOnLine({
  required int tipR,
  required int tipC,
  required ArrowDirection direction,
  required List<ArrowModel> others,
}) {
  for (final other in others) {
    if (tipR == other.row && tipC != other.col) {
      final dist = (tipC - other.col).abs();
      if (dist > 4) continue;
      final newLeft = tipC < other.col;
      final facing =
          (newLeft &&
              direction == ArrowDirection.right &&
              other.direction == ArrowDirection.left) ||
          (!newLeft &&
              direction == ArrowDirection.left &&
              other.direction == ArrowDirection.right);
      if (facing) return true;
    }
    if (tipC == other.col && tipR != other.row) {
      final dist = (tipR - other.row).abs();
      if (dist > 4) continue;
      final newAbove = tipR < other.row;
      final facing =
          (newAbove &&
              direction == ArrowDirection.down &&
              other.direction == ArrowDirection.up) ||
          (!newAbove &&
              direction == ArrowDirection.up &&
              other.direction == ArrowDirection.down);
      if (facing) return true;
    }
  }
  return false;
}

/// Builds a solvable nested polyline board (bent snakes like campaign Expert).
///
/// Places arrows **backward** (each new arrow is free against already-placed
/// ones), so reverse placement order is always a valid solve.
///
/// Tuned for **fast** daily generation on the UI isolate (tight caps + local
/// occupied-set escape checks — no per-probe full [isArrowFree] scans).
SolvableLevelResult generateNestedSolvableLevel(
  int levelNumber,
  int rows,
  int cols,
  int hearts,
  int hints, {
  LevelDifficulty difficulty = LevelDifficulty.expert,
  int? seed,
  double fillTarget = 0.88,
  int minPathLen = 3,
  int maxPathLen = 14,
  int minArrows = 28,
  /// Stop placing once this many arrows exist (daily caps at 100).
  int? maxArrows,
  List<List<bool>>? shapeMask,
  /// Escape-puzzle mode: prefer bends / U-hooks; allow own parallel arms.
  bool hardNest = false,
  /// Retry if too many tips are free at start (easy first moves).
  int? maxFreeAtStart,
  /// Daily-style mix: long + medium + small arrow lengths interleaved.
  bool mixPathSizes = false,
}) {
  final random = Random(
    seed ?? levelNumber * 9973 + rows * 131 + cols * 17,
  );
  final occupied = <String>{};
  final arrows = <ArrowModel>[];
  final placementOrder = <String>[];

  String cellKey(int r, int c) => '$r:$c';

  bool inBounds(int r, int c) =>
      r >= 0 && c >= 0 && r < rows && c < cols;

  bool inMask(int r, int c) {
    if (shapeMask == null) return true;
    if (r < 0 ||
        c < 0 ||
        r >= shapeMask.length ||
        c >= shapeMask[r].length) {
      return false;
    }
    return shapeMask[r][c];
  }

  bool isPlayable(int r, int c) => inBounds(r, c) && inMask(r, c);

  bool isEmpty(int r, int c) =>
      isPlayable(r, c) && !occupied.contains(cellKey(r, c));

  var playableCount = 0;
  for (var r = 0; r < rows; r++) {
    for (var c = 0; c < cols; c++) {
      if (isPlayable(r, c)) playableCount++;
    }
  }
  final targetCells = (playableCount * fillTarget).floor();

  /// Escape ray: occupied blocks. Outside-mask gaps with more shape ahead are
  /// skipped; ending the silhouette on this ray = free.
  bool escapeClear(int tipR, int tipC, ArrowDirection direction) {
    final (dr, dc) = _dirDelta(direction);
    bool playableAhead(int r, int c) {
      var rr = r;
      var cc = c;
      for (var i = 0; i < 64; i++) {
        if (!inBounds(rr, cc)) return false;
        if (inMask(rr, cc)) return true;
        rr += dr;
        cc += dc;
      }
      return false;
    }

    var r = tipR + dr;
    var c = tipC + dc;
    while (inBounds(r, c)) {
      if (!inMask(r, c)) {
        if (!playableAhead(r, c)) return true;
        r += dr;
        c += dc;
        continue;
      }
      if (occupied.contains(cellKey(r, c))) return false;
      r += dr;
      c += dc;
    }
    return true;
  }

  bool playableAheadOnRay(int r, int c, int dr, int dc) {
    var rr = r;
    var cc = c;
    for (var i = 0; i < 64; i++) {
      if (!inBounds(rr, cc)) return false;
      if (inMask(rr, cc)) return true;
      rr += dr;
      cc += dc;
    }
    return false;
  }

  int centerBiased(int max) {
    if (max <= 1) return 0;
    return ((random.nextInt(max) + random.nextInt(max)) / 2).floor();
  }

  bool hasOccupiedNeighbor(int r, int c) {
    for (final (dr, dc) in const [(0, 1), (0, -1), (1, 0), (-1, 0)]) {
      if (occupied.contains(cellKey(r + dr, c + dc))) return true;
    }
    return false;
  }

  int nestContactScore(List<GridCell> path) {
    var contacts = 0;
    for (final cell in path) {
      for (final (dr, dc) in const [(0, 1), (0, -1), (1, 0), (-1, 0)]) {
        if (occupied.contains(cellKey(cell.row + dr, cell.col + dc))) {
          contacts++;
        }
      }
    }
    return contacts;
  }

  (int, int)? samplePocketTip() {
    if (occupied.isEmpty) return null;
    for (var t = 0; t < 48; t++) {
      final tipR = centerBiased(rows);
      final tipC = centerBiased(cols);
      if (!isEmpty(tipR, tipC)) continue;
      if (hasOccupiedNeighbor(tipR, tipC)) return (tipR, tipC);
    }
    final keys = occupied.toList(growable: false);
    final start = random.nextInt(keys.length);
    for (var i = 0; i < keys.length && i < 24; i++) {
      final parts = keys[(start + i) % keys.length].split(':');
      final or = int.parse(parts[0]);
      final oc = int.parse(parts[1]);
      final dirs = [
        (0, 1),
        (0, -1),
        (1, 0),
        (-1, 0),
      ]..shuffle(random);
      for (final (dr, dc) in dirs) {
        final nr = or + dr;
        final nc = oc + dc;
        if (isEmpty(nr, nc)) return (nr, nc);
      }
    }
    return null;
  }

  (int tipR, int tipC) pickTip() {
    if (hardNest && occupied.isNotEmpty && random.nextDouble() < 0.78) {
      final pocket = samplePocketTip();
      if (pocket != null) return pocket;
    }
    return (centerBiased(rows), centerBiased(cols));
  }

  /// Grow tail←tip so the last step into the tip matches [direction].
  /// Rejects hairpin / self-hugging folds that confuse path reading.
  /// Always at least tip + one shaft cell (no floating lone triangles).
  List<GridCell>? growPath({
    required int tipR,
    required int tipC,
    required ArrowDirection direction,
    required int targetLen,
    required int minLen,
  }) {
    final want = targetLen < 2 ? 2 : targetLen;
    final need = minLen < 2 ? 2 : minLen;

    final (dr, dc) = _dirDelta(direction);
    final rev = <GridCell>[GridCell(tipR, tipC)];
    final used = <String>{cellKey(tipR, tipC)};
    var r = tipR - dr;
    var c = tipC - dc;
    if (!isEmpty(r, c)) return null;
    rev.add(GridCell(r, c));
    used.add(cellKey(r, c));

    var growDr = -dr;
    var growDc = -dc;

    /// New cell may only touch the current head — not earlier body cells.
    /// Hard nests allow parallel U-arms (like reference Escape Puzzle boards).
    bool hugsOwnBody(int nr, int nc) {
      if (hardNest) return false;
      for (final cell in rev) {
        if (cell.row == r && cell.col == c) continue;
        if ((cell.row - nr).abs() + (cell.col - nc).abs() == 1) {
          return true;
        }
      }
      return false;
    }

    while (rev.length < want) {
      final candidates = <(int, int, int, int)>[];
      void consider(int ndr, int ndc) {
        final nr = r + ndr;
        final nc = c + ndc;
        final k = cellKey(nr, nc);
        if (!inBounds(nr, nc) ||
            !inMask(nr, nc) ||
            occupied.contains(k) ||
            used.contains(k) ||
            hugsOwnBody(nr, nc)) {
          return;
        }
        candidates.add((nr, nc, ndr, ndc));
      }

      consider(growDr, growDc);
      final turnA = (growDc, -growDr);
      final turnB = (-growDc, growDr);
      consider(turnA.$1, turnA.$2);
      consider(turnB.$1, turnB.$2);

      if (candidates.isEmpty) break;

      (int, int, int, int) pick;
      if (candidates.length == 1) {
        pick = candidates.first;
      } else if (hardNest) {
        // Prefer growing along / into existing snakes so paths nest, not float alone.
        final hugging = [
          for (final c in candidates)
            if (hasOccupiedNeighbor(c.$1, c.$2)) c,
        ];
        final turns = [
          for (final c in candidates)
            if (!(c.$3 == growDr && c.$4 == growDc)) c,
        ];
        final nestTurns = [
          for (final c in hugging)
            if (!(c.$3 == growDr && c.$4 == growDc)) c,
        ];
        if (nestTurns.isNotEmpty && random.nextDouble() < 0.8) {
          pick = nestTurns[random.nextInt(nestTurns.length)];
        } else if (hugging.isNotEmpty && random.nextDouble() < 0.7) {
          pick = hugging[random.nextInt(hugging.length)];
        } else if (turns.isNotEmpty && random.nextDouble() < 0.88) {
          pick = turns[random.nextInt(turns.length)];
        } else {
          pick = candidates[random.nextInt(candidates.length)];
        }
      } else {
        // Prefer straight runs — fewer sharp folds.
        final straight = candidates.first;
        final isStraight =
            straight.$3 == growDr && straight.$4 == growDc;
        if (isStraight && random.nextDouble() < 0.82) {
          pick = straight;
        } else {
          pick = candidates[random.nextInt(candidates.length)];
        }
      }

      r = pick.$1;
      c = pick.$2;
      growDr = pick.$3;
      growDc = pick.$4;
      rev.add(GridCell(r, c));
      used.add(cellKey(r, c));
    }

    if (rev.length < need) return null;
    final path = rev.reversed.toList(growable: false);
    if (!hardNest && _polylineSelfHugs(path)) return null;
    return path;
  }

  void placeArrow(ArrowModel arrow) {
    arrows.add(arrow);
    placementOrder.add(arrow.id);
    for (final cell in arrow.path) {
      occupied.add(cellKey(cell.row, cell.col));
    }
  }

  /// Tip steps toward board center (tail will grow toward the rim).
  bool pointsInward(int tipR, int tipC, ArrowDirection direction) {
    final cy = (rows - 1) / 2.0;
    final cx = (cols - 1) / 2.0;
    final (dr, dc) = _dirDelta(direction);
    final before = (tipR - cy).abs() + (tipC - cx).abs();
    final after = (tipR + dr - cy).abs() + (tipC + dc - cx).abs();
    return after < before - 0.05;
  }

  /// Tip on rim pointing straight off the board — too easy to clear first.
  bool easyOutwardRim(int tipR, int tipC, ArrowDirection direction) {
    return switch (direction) {
      ArrowDirection.up => tipR <= 1,
      ArrowDirection.down => tipR >= rows - 2,
      ArrowDirection.left => tipC <= 1,
      ArrowDirection.right => tipC >= cols - 2,
    };
  }

  bool tryPlaceAt({
    required int tipR,
    required int tipC,
    required int targetLen,
    required int minLen,
    bool preferInward = true,
    bool allowFacingTips = false,
  }) {
    if (!isEmpty(tipR, tipC)) return false;
    final dirs = ArrowDirection.values.toList(growable: false);
    final start = random.nextInt(dirs.length);

    final options = <({ArrowDirection dir, List<GridCell> path, int score})>[];
    for (var i = 0; i < dirs.length; i++) {
      final direction = dirs[(start + i) % dirs.length];
      if (!escapeClear(tipR, tipC, direction)) continue;
      if (!allowFacingTips &&
          _tipsFaceEachOtherOnLine(
            tipR: tipR,
            tipC: tipC,
            direction: direction,
            others: arrows,
          )) {
        continue;
      }

      final path = growPath(
        tipR: tipR,
        tipC: tipC,
        direction: direction,
        targetLen: targetLen,
        minLen: minLen,
      );
      if (path == null) continue;

      var score = 0;
      if (preferInward) {
        if (pointsInward(tipR, tipC, direction)) score += 8;
        if (easyOutwardRim(tipR, tipC, direction)) {
          // Reference boards bury tips — skip easy rim clears when possible.
          score -= hardNest ? 20 : 8;
        }
        // Prefer tips away from the absolute rim.
        if (tipR > 1 && tipR < rows - 2 && tipC > 1 && tipC < cols - 2) {
          score += 4;
        }
        // Tail (path.first) hugging the border = complex like reference boards.
        final tail = path.first;
        if (tail.row <= 1 ||
            tail.row >= rows - 2 ||
            tail.col <= 1 ||
            tail.col >= cols - 2) {
          score += hardNest ? 6 : 3;
        }
        if (hardNest) {
          // Reward bends / hooks (Escape Puzzle style interlocking).
          var turns = 0;
          for (var i = 2; i < path.length; i++) {
            final a = path[i - 2];
            final b = path[i - 1];
            final c = path[i];
            final d1r = b.row - a.row;
            final d1c = b.col - a.col;
            final d2r = c.row - b.row;
            final d2c = c.col - b.col;
            if (d1r != d2r || d1c != d2c) turns++;
          }
          score += turns * 4;
          if (path.length >= 5 && turns == 0) score -= 6;

          // Nest against neighbors — floating separated snakes score poorly.
          final contacts = nestContactScore(path);
          score += contacts * 4;
          if (arrows.isNotEmpty && contacts == 0) score -= 18;
          if (contacts >= 3) score += 6;

          // Prefer placements that seal currently-free tips (deep dependency chains).
          for (final other in arrows) {
            if (!escapeClear(other.row, other.col, other.direction)) continue;
            final (odr, odc) = _dirDelta(other.direction);
            var rr = other.row + odr;
            var cc = other.col + odc;
            var sealed = false;
            while (inBounds(rr, cc) && !sealed) {
              if (!inMask(rr, cc)) {
                if (!playableAheadOnRay(rr, cc, odr, odc)) break;
                rr += odr;
                cc += odc;
                continue;
              }
              for (final cell in path) {
                if (cell.row == rr && cell.col == cc) {
                  score += 7;
                  sealed = true;
                  break;
                }
              }
              rr += odr;
              cc += odc;
            }
          }
        }
      } else if (hardNest && arrows.isNotEmpty) {
        // Late fill: still prefer nesting against existing paths.
        final contacts = nestContactScore(path);
        score += contacts * 3;
        if (contacts == 0) score -= 10;
      }
      options.add((dir: direction, path: path, score: score));
    }

    if (options.isEmpty) return false;

    // Hard nests: drop easy outward-rim tips if any better options exist.
    var pool = options;
    if (preferInward && hardNest) {
      final buried = [
        for (final o in options)
          if (!easyOutwardRim(tipR, tipC, o.dir)) o,
      ];
      if (buried.isNotEmpty) pool = buried;
    }
    // Prefer nested (contacting) paths once the board has snakes.
    if (hardNest && arrows.isNotEmpty) {
      final nested = [
        for (final o in pool)
          if (nestContactScore(o.path) > 0) o,
      ];
      if (nested.isNotEmpty) pool = nested;
    }

    pool.sort((a, b) => b.score.compareTo(a.score));
    final best = pool.first.score;
    final top = [
      for (final o in pool)
        if (o.score >= best - (preferInward ? 3 : 99)) o,
    ];
    final pick = top[random.nextInt(top.length)];

    placeArrow(
      ArrowModel(
        id: '$levelNumber-${arrows.length}',
        row: tipR,
        col: tipC,
        direction: pick.dir,
        path: pick.path,
      ),
    );
    return true;
  }

  bool underArrowCap() =>
      maxArrows == null || arrows.length < maxArrows;

  int pickPathLen() {
    if (!mixPathSizes) {
      final span = (maxPathLen - minPathLen).clamp(0, 99);
      return minPathLen + (span == 0 ? 0 : random.nextInt(span + 1));
    }
    // Length mix tuned so ~100 arrows nearly fill a dense silhouette (avg ~6).
    final roll = random.nextDouble();
    if (roll < 0.25) {
      final tallMin = (maxPathLen - 2).clamp(minPathLen, maxPathLen);
      return tallMin + random.nextInt((maxPathLen - tallMin).clamp(0, 99) + 1);
    }
    if (roll < 0.70) {
      final mid = ((minPathLen + maxPathLen) / 2).round().clamp(4, maxPathLen);
      final lo = (mid - 1).clamp(4, maxPathLen);
      final hi = (mid + 2).clamp(4, maxPathLen);
      return lo + random.nextInt((hi - lo).clamp(0, 99) + 1);
    }
    return 2 + random.nextInt(2); // small 2–3
  }

  // Phase 1: woven snakes — tips biased into nesting pockets.
  var safety = 0;
  var stall = 0;
  while (occupied.length < targetCells && underArrowCap() && safety < 5000) {
    safety++;
    final before = occupied.length;
    final tip = pickTip();
    final len = pickPathLen();
    tryPlaceAt(
      tipR: tip.$1,
      tipC: tip.$2,
      targetLen: len < 2 ? 2 : len,
      minLen: mixPathSizes ? 2 : (minPathLen < 2 ? 2 : minPathLen),
      preferInward: true,
    );
    if (occupied.length == before) {
      stall++;
      if (stall > 400) break;
    } else {
      stall = 0;
    }
  }

  // Phase 2: mop up — keep size mix; fill gaps tightly for daily.
  safety = 0;
  stall = 0;
  while (occupied.length < targetCells && underArrowCap() && safety < 3000) {
    safety++;
    final before = occupied.length;
    final tip = pickTip();
    final len = mixPathSizes ? pickPathLen() : (2 + random.nextInt(3));
    tryPlaceAt(
      tipR: tip.$1,
      tipC: tip.$2,
      targetLen: len < 2 ? 2 : len,
      minLen: 2,
      preferInward: true,
    );
    if (occupied.length == before) {
      stall++;
      if (stall > 300) break;
    } else {
      stall = 0;
    }
  }

  // Phase 3: leftovers — hard nests still bury tips (refs); soft allow any tip.
  for (var r = 0; r < rows && underArrowCap(); r++) {
    for (var c = 0; c < cols && underArrowCap(); c++) {
      if (!isEmpty(r, c)) continue;
      tryPlaceAt(
        tipR: r,
        tipC: c,
        targetLen: mixPathSizes
            ? pickPathLen()
            : (hardNest ? 4 : 3),
        minLen: 2,
        preferInward: hardNest || mixPathSizes,
      );
    }
  }

  // Phase 4: hard nests mop remaining corridors — keep inward bias.
  if (hardNest) {
    for (var pass = 0; pass < 5 && underArrowCap(); pass++) {
      var placed = false;
      for (var r = 0; r < rows && underArrowCap(); r++) {
        for (var c = 0; c < cols && underArrowCap(); c++) {
          if (!isEmpty(r, c)) continue;
          if (tryPlaceAt(
            tipR: r,
            tipC: c,
            targetLen: 2 + (pass % 3),
            minLen: 2,
            preferInward: true,
            allowFacingTips: pass >= 3,
          )) {
            placed = true;
          }
        }
      }
      if (!placed) break;
    }
  }

  // Phase 5: pack leftover gaps with short shafts (esp. daily size-mix packs).
  if (mixPathSizes || maxArrows != null) {
    for (var pass = 0; pass < 20 && underArrowCap(); pass++) {
      var placed = false;
      for (var r = 0; r < rows && underArrowCap(); r++) {
        for (var c = 0; c < cols && underArrowCap(); c++) {
          if (!isEmpty(r, c)) continue;
          if (tryPlaceAt(
            tipR: r,
            tipC: c,
            targetLen: 2 + (pass % 4),
            minLen: 2,
            preferInward: false,
            allowFacingTips: true,
          )) {
            placed = true;
          }
        }
      }
      if (!placed) break;
    }
  }

  if (arrows.length < minArrows) {
    throw StateError(
      'Nested daily only placed ${arrows.length}/$minArrows arrows '
      '($rows×$cols, fill ${occupied.length}/${rows * cols})',
    );
  }

  if (maxFreeAtStart != null) {
    var free = 0;
    for (final arrow in arrows) {
      if (isArrowFree(
        arrow: arrow,
        arrows: arrows,
        gridRows: rows,
        gridCols: cols,
        shapeMask: shapeMask,
      )) {
        free++;
      }
    }
    if (free > maxFreeAtStart) {
      throw StateError(
        'Nested nest too open at start ($free free > $maxFreeAtStart)',
      );
    }
  }

  return SolvableLevelResult(
    level: LevelModel(
      levelNumber: levelNumber,
      gridRows: rows,
      gridCols: cols,
      arrows: arrows,
      heartsAllowed: hearts,
      hintsAllowed: hints,
      difficulty: difficulty,
      shapeMask: shapeMask,
    ),
    placementOrder: List<String>.unmodifiable(placementOrder),
  );
}

/// Upright triangle silhouette (apex top-center → full base).
List<List<bool>> uprightTriangleMask(int rows, int cols) {
  final mid = (cols - 1) / 2.0;
  return List.generate(rows, (r) {
    final t = rows <= 1 ? 1.0 : r / (rows - 1);
    final half = t * mid;
    return List.generate(cols, (c) => (c - mid).abs() <= half + 1e-6);
  });
}

/// Inverted triangle (wide top → apex bottom).
List<List<bool>> invertedTriangleMask(int rows, int cols) {
  final mid = (cols - 1) / 2.0;
  return List.generate(rows, (r) {
    final t = rows <= 1 ? 1.0 : 1.0 - r / (rows - 1);
    final half = t * mid;
    return List.generate(cols, (c) => (c - mid).abs() <= half + 1e-6);
  });
}

/// Diamond / rhombus silhouette.
List<List<bool>> diamondMask(int rows, int cols) {
  final cy = (rows - 1) / 2.0;
  final cx = (cols - 1) / 2.0;
  return List.generate(rows, (r) {
    return List.generate(cols, (c) {
      final nr = (r - cy).abs() / (cy == 0 ? 1 : cy);
      final nc = (c - cx).abs() / (cx == 0 ? 1 : cx);
      return nr + nc <= 1.02;
    });
  });
}

/// Rounded hexagon-ish blob (good for dense Expert nests).
List<List<bool>> hexagonMask(int rows, int cols) {
  final cy = (rows - 1) / 2.0;
  final cx = (cols - 1) / 2.0;
  final ry = cy * 0.98;
  final rx = cx * 0.98;
  return List.generate(rows, (r) {
    return List.generate(cols, (c) {
      final dy = (r - cy).abs() / (ry == 0 ? 1 : ry);
      final dx = (c - cx).abs() / (rx == 0 ? 1 : rx);
      // Flat-top hex approximation.
      return dy <= 1.0 && dx <= 1.0 && (dx * 0.55 + dy) <= 1.08;
    });
  });
}

/// Soft circle / oval board.
List<List<bool>> circleMask(int rows, int cols) {
  final cy = (rows - 1) / 2.0;
  final cx = (cols - 1) / 2.0;
  final ry = cy * 0.98;
  final rx = cx * 0.98;
  return List.generate(rows, (r) {
    return List.generate(cols, (c) {
      final ny = (r - cy) / (ry == 0 ? 1 : ry);
      final nx = (c - cx) / (rx == 0 ? 1 : rx);
      return nx * nx + ny * ny <= 1.02;
    });
  });
}

/// 4-point star (complex Expert silhouette).
List<List<bool>> starMask(int rows, int cols) {
  final cy = (rows - 1) / 2.0;
  final cx = (cols - 1) / 2.0;
  return List.generate(rows, (r) {
    return List.generate(cols, (c) {
      final dy = (r - cy).abs() / (cy == 0 ? 1 : cy);
      final dx = (c - cx).abs() / (cx == 0 ? 1 : cx);
      // Cross arms + diamond center.
      final inCross = (dx <= 0.38 && dy <= 1.0) || (dy <= 0.38 && dx <= 1.0);
      final inDiamond = dx + dy <= 0.72;
      return inCross || inDiamond;
    });
  });
}

/// Campaign levels 1–30. Dense late levels are built lazily so app start
/// does not freeze the UI (~20s+ if every nest were generated up front).
class LevelRepository {
  LevelRepository({List<SolvableLevelResult>? prebuilt})
      : _prebuilt = prebuilt,
        _lazy = List<SolvableLevelResult?>.filled(30, null);

  final List<SolvableLevelResult>? _prebuilt;
  final List<SolvableLevelResult?> _lazy;
  final Map<int, LevelModel> _dailyCache = {};
  final Map<int, LevelModel> _endlessCache = {};

  static const int campaignLevelCount = 30;

  SolvableLevelResult _resultAt(int index) {
    if (index < 0 || index >= campaignLevelCount) {
      throw RangeError('No campaign level at index $index');
    }
    if (_prebuilt != null) return _prebuilt![index];
    return _lazy[index] ??= _buildCampaignLevel(index + 1);
  }

  List<LevelModel> get levels => [
        for (var i = 0; i < campaignLevelCount; i++) _resultAt(i).level,
      ];

  int get levelCount => campaignLevelCount;

  List<String> placementOrderFor(int levelNumber) {
    return _resultAt(levelNumber - 1).placementOrder;
  }

  /// Solve order for tutorials (reverse of placement).
  List<String> solveOrderFor(int levelNumber) =>
      placementOrderFor(levelNumber).reversed.toList();

  LevelModel getLevel(int levelNumber) {
    final key = levelNumber < 1 ? 1 : levelNumber;
    if (key <= campaignLevelCount) {
      return _resultAt(key - 1).level;
    }

    return _endlessCache.putIfAbsent(key, () {
      // Endless Expert nests after the curated pack (auto-grows harder).
      final size = (18 + ((key - 30) % 8)).clamp(18, 24);
      final minArrows = (66 + (key - 30) * 2).clamp(66, 100);
      final maxFree = (3 - ((key - 30) ~/ 8)).clamp(2, 3);
      try {
        return generateNestedSolvableLevel(
          key,
          size,
          size + (key.isEven ? 1 : 0),
          3,
          1,
          difficulty: LevelDifficulty.expert,
          seed: key * 9973 + size * 19,
          fillTarget: 0.98,
          minPathLen: 2,
          maxPathLen: 12,
          minArrows: minArrows,
          hardNest: true,
          mixPathSizes: true,
          maxFreeAtStart: maxFree,
        ).level;
      } on StateError {
        return generateNestedSolvableLevel(
          key,
          18,
          18,
          3,
          1,
          difficulty: LevelDifficulty.expert,
          seed: key,
          fillTarget: 0.92,
          minPathLen: 2,
          maxPathLen: 10,
          minArrows: 50,
          hardNest: true,
          mixPathSizes: true,
        ).level;
      }
    });
  }

  LevelModel nextLevel(int currentLevelNumber) =>
      getLevel(currentLevelNumber + 1);

  LevelModel getDailyLevel([DateTime? date]) {
    final day = date ?? DateTime.now();
    final levelNumber =
        900000000 + day.year * 10000 + day.month * 100 + day.day;
    return _dailyCache.putIfAbsent(
      levelNumber,
      () => _buildDailyChallengeLevel(day, levelNumber),
    );
  }

  /// Daily puzzles are calendar-seeded (one unique board per day).
  /// Dense shaped nest (~100 arrows): no free space, mixed small/medium/tall.
  static LevelModel _buildDailyChallengeLevel(DateTime day, int levelNumber) {
    final dayOfYear = day.difference(DateTime(day.year)).inDays;
    final shapeIndex = (dayOfYear + day.year * 5 + day.month * 3) % 16;

    // Shrink primary boards so 100 mixed arrows pack nearly solid.
    final config = switch (shapeIndex) {
      0 => (
          rows: 22,
          cols: 22,
          mask: circleMask(22, 22),
          fbRows: 22,
          fbCols: 22,
          fbMask: circleMask(22, 22),
        ),
      1 => (
          rows: 22,
          cols: 22,
          mask: octagonMask(22, 22),
          fbRows: 22,
          fbCols: 22,
          fbMask: octagonMask(22, 22),
        ),
      2 => (
          rows: 22,
          cols: 22,
          mask: diamondMask(22, 22),
          fbRows: 22,
          fbCols: 22,
          fbMask: diamondMask(22, 22),
        ),
      3 => (
          rows: 23,
          cols: 25,
          mask: hexagonMask(23, 25),
          fbRows: 21,
          fbCols: 23,
          fbMask: hexagonMask(21, 23),
        ),
      4 => (
          rows: 22,
          cols: 22,
          mask: generateHeartShapeMask(22),
          fbRows: 22,
          fbCols: 22,
          fbMask: generateHeartShapeMask(22),
        ),
      5 => (
          rows: 22,
          cols: 22,
          mask: circleMask(22, 22),
          fbRows: 22,
          fbCols: 22,
          fbMask: octagonMask(22, 22),
        ),
      6 => (
          rows: 25,
          cols: 25,
          mask: octagonMask(25, 25),
          fbRows: 23,
          fbCols: 23,
          fbMask: circleMask(23, 23),
        ),
      7 => (
          rows: 23,
          cols: 25,
          mask: stadiumMask(23, 25),
          fbRows: 21,
          fbCols: 23,
          fbMask: stadiumMask(21, 23),
        ),
      8 => (
          rows: 22,
          cols: 22,
          mask: cloverMask(22, 22),
          fbRows: 22,
          fbCols: 22,
          fbMask: octagonMask(22, 22),
        ),
      9 => (
          rows: 25,
          cols: 25,
          mask: circleMask(25, 25),
          fbRows: 23,
          fbCols: 23,
          fbMask: circleMask(23, 23),
        ),
      10 => (
          rows: 22,
          cols: 22,
          mask: flowerMask(22, 22),
          fbRows: 22,
          fbCols: 22,
          fbMask: diamondMask(22, 22),
        ),
      11 => (
          rows: 24,
          cols: 22,
          mask: shieldMask(24, 22),
          fbRows: 22,
          fbCols: 20,
          fbMask: octagonMask(22, 20),
        ),
      12 => (
          rows: 22,
          cols: 22,
          mask: octagonMask(22, 22),
          fbRows: 22,
          fbCols: 22,
          fbMask: diamondMask(22, 22),
        ),
      13 => (
          rows: 22,
          cols: 26,
          mask: stadiumMask(22, 26),
          fbRows: 20,
          fbCols: 24,
          fbMask: stadiumMask(20, 24),
        ),
      14 => (
          rows: 25,
          cols: 25,
          mask: diamondMask(25, 25),
          fbRows: 23,
          fbCols: 23,
          fbMask: circleMask(23, 23),
        ),
      _ => (
          rows: 22,
          cols: 22,
          mask: circleMask(22, 22),
          fbRows: 22,
          fbCols: 22,
          fbMask: octagonMask(22, 22),
        ),
    };

    const minArrows = 100;
    const maxArrows = 100;
    StateError? lastError;

    LevelModel? tryBuild({
      required int rows,
      required int cols,
      required List<List<bool>> mask,
      required int seed,
      required double fill,
      int? freeCap,
    }) {
      try {
        return generateNestedSolvableLevel(
          levelNumber,
          rows,
          cols,
          3,
          2,
          difficulty: LevelDifficulty.expert,
          seed: seed,
          shapeMask: mask,
          fillTarget: fill,
          minPathLen: 2,
          maxPathLen: 11,
          minArrows: minArrows,
          maxArrows: maxArrows,
          hardNest: true,
          mixPathSizes: true,
          maxFreeAtStart: freeCap,
        ).level;
      } on StateError catch (e) {
        lastError = e;
        return null;
      }
    }

    // Near-solid fill — keep placing until 100 arrows pack the silhouette.
    for (var attempt = 0; attempt < 28; attempt++) {
      final level = tryBuild(
        rows: config.rows,
        cols: config.cols,
        mask: config.mask,
        seed: levelNumber + attempt * 211 + shapeIndex * 47,
        fill: 0.995,
        freeCap: attempt < 18 ? 12 : 16,
      );
      if (level != null) return level;
    }

    for (var attempt = 0; attempt < 18; attempt++) {
      final level = tryBuild(
        rows: config.fbRows,
        cols: config.fbCols,
        mask: config.fbMask,
        seed: levelNumber + 9000 + attempt * 131,
        fill: 0.99,
        freeCap: attempt < 10 ? 14 : null,
      );
      if (level != null) return level;
    }

    for (var attempt = 0; attempt < 20; attempt++) {
      final size = 21 + (attempt % 3); // 21–23 dense circles
      final level = tryBuild(
        rows: size,
        cols: size,
        mask: circleMask(size, size),
        seed: levelNumber + 17000 + attempt * 97,
        fill: 0.98,
        freeCap: null,
      );
      if (level != null) return level;
    }

    // Rectangles sized so 100 mixed arrows pack nearly solid.
    for (var attempt = 0; attempt < 36; attempt++) {
      final size = 20 + (attempt % 4); // 20–23
      try {
        return generateNestedSolvableLevel(
          levelNumber,
          size,
          size,
          3,
          2,
          difficulty: LevelDifficulty.expert,
          seed: levelNumber + 29000 + attempt * 37,
          fillTarget: 0.98,
          minPathLen: 2,
          maxPathLen: 10,
          minArrows: minArrows,
          maxArrows: maxArrows,
          hardNest: true,
          mixPathSizes: true,
        ).level;
      } on StateError catch (e) {
        lastError = e;
      }
    }

    // Soft hardNest off — still bent paths via mix sizes, pack 20–22 boards solid.
    for (var attempt = 0; attempt < 28; attempt++) {
      final size = 20 + (attempt % 3); // 20–22
      try {
        return generateNestedSolvableLevel(
          levelNumber,
          size,
          size,
          3,
          2,
          difficulty: LevelDifficulty.expert,
          seed: levelNumber + 41000 + attempt * 19,
          fillTarget: 0.97,
          minPathLen: 2,
          maxPathLen: 10,
          minArrows: 90,
          maxArrows: maxArrows,
          hardNest: attempt.isEven,
          mixPathSizes: true,
        ).level;
      } on StateError catch (e) {
        lastError = e;
      }
    }

    for (var attempt = 0; attempt < 24; attempt++) {
      try {
        return generateNestedSolvableLevel(
          levelNumber,
          24,
          24,
          3,
          2,
          difficulty: LevelDifficulty.expert,
          seed: levelNumber + 52000 + attempt * 23,
          fillTarget: 0.92,
          minPathLen: 2,
          maxPathLen: 9,
          minArrows: 80,
          maxArrows: maxArrows,
          hardNest: false,
          mixPathSizes: true,
        ).level;
      } on StateError catch (e) {
        lastError = e;
      }
    }

    try {
      return generateNestedSolvableLevel(
        levelNumber,
        24,
        24,
        3,
        2,
        difficulty: LevelDifficulty.expert,
        seed: levelNumber + 99,
        fillTarget: 0.9,
        minPathLen: 2,
        maxPathLen: 8,
        minArrows: 70,
        maxArrows: maxArrows,
        hardNest: false,
        mixPathSizes: true,
      ).level;
    } on StateError catch (e) {
      throw lastError ?? e;
    }
  }

  static SolvableLevelResult _buildCampaignLevel(int levelNumber) {
    return switch (levelNumber) {
      1 => _tutorialLevel1(),
      2 => _nestedLevel2(),
      3 => _nestedLevel3(),
      4 => _nestedLevel4(),
      5 => _nestedLevel5(),
      6 => _nestedLevel6(),
      7 => _nestedLevel7(),
      8 => _nestedLevel8(),
      9 => _nestedLevel9(),
      10 => _nestedLevel10(),
      11 => _nestedLevel11(),
      12 => _nestedLevel12(),
      13 => _nestedLevel13(),
      14 => _nestedLevel14(),
      15 => _nestedLevel15(),
      16 => _nestedLevel16(),
      17 => _nestedLevel17(),
      18 => _nestedLevel18(),
      19 => _nestedLevel19(),
      20 => _nestedLevel20(),
      21 => _nestedLevel21(),
      22 => _nestedLevel22(),
      23 => _nestedLevel23(),
      24 => _nestedLevel24(),
      25 => _nestedLevel25(),
      26 => _nestedLevel26(),
      27 => _nestedLevel27(),
      28 => _nestedLevel28(),
      29 => _nestedLevel29(),
      30 => _nestedLevel30(),
      _ => throw RangeError('No campaign builder for level $levelNumber'),
    };
  }

  /// Fixed Level 1: three vertical arrows — UP, UP, DOWN (left → right).
  /// Hand guides the middle UP arrow first (first free in list order).
  static SolvableLevelResult _tutorialLevel1() {
    // Middle listed first so findFreeArrow() highlights it initially.
    final arrows = [
      ArrowModel(
        id: '1-0',
        row: 1,
        col: 1,
        direction: ArrowDirection.up,
      ),
      ArrowModel(
        id: '1-1',
        row: 1,
        col: 0,
        direction: ArrowDirection.up,
      ),
      ArrowModel(
        id: '1-2',
        row: 1,
        col: 2,
        direction: ArrowDirection.down,
      ),
    ];

    return SolvableLevelResult(
      level: LevelModel(
        levelNumber: 1,
        gridRows: 3,
        gridCols: 3,
        arrows: arrows,
        heartsAllowed: 5,
        hintsAllowed: 3,
        difficulty: LevelDifficulty.easy,
      ),
      // Placement order: solve order is reverse → middle, then left, then right.
      placementOrder: const ['1-1', '1-2', '1-0'],
    );
  }

  /// Fixed Level 2: nested paths matching reference screenshot directions.
  ///
  /// 1) Outer L: left↑ then top→ tip RIGHT
  /// 2) Outer right: vertical tip DOWN
  /// 3) Inner top L: tip LEFT
  /// 4) Inner left L: tip UP
  /// 5) Center inverted-U tip DOWN
  /// 6) Bottom short tip RIGHT
  ///
  /// Solve e.g. A → C → D, B → F → E
  static SolvableLevelResult _nestedLevel2() {
    ArrowModel pathArrow(
      String id,
      List<(int, int)> cells,
      ArrowDirection direction,
    ) {
      final path = [for (final c in cells) GridCell(c.$1, c.$2)];
      final tip = path.last;
      return ArrowModel(
        id: id,
        row: tip.row,
        col: tip.col,
        direction: direction,
        path: path,
      );
    }

    final arrows = [
      // Outer L: bottom-left → up left side → across top → tip RIGHT
      pathArrow(
        '2-A',
        [
          (5, 0),
          (4, 0),
          (3, 0),
          (2, 0),
          (1, 0),
          (0, 0),
          (0, 1),
          (0, 2),
          (0, 3),
          (0, 4),
          (0, 5),
        ],
        ArrowDirection.right,
      ),
      // Outer right edge: tip DOWN
      pathArrow(
        '2-B',
        [(1, 5), (2, 5), (3, 5), (4, 5), (5, 5)],
        ArrowDirection.down,
      ),
      // Inner top: vertical then left → tip LEFT
      pathArrow(
        '2-C',
        [(2, 4), (1, 4), (1, 3), (1, 2), (1, 1)],
        ArrowDirection.left,
      ),
      // Inner left: bottom hook then up → tip UP
      pathArrow(
        '2-D',
        [(4, 2), (4, 1), (3, 1), (2, 1)],
        ArrowDirection.up,
      ),
      // Center inverted U → tip DOWN
      pathArrow(
        '2-E',
        [(3, 2), (2, 2), (2, 3), (3, 3)],
        ArrowDirection.down,
      ),
      // Inner bottom short → tip RIGHT
      pathArrow(
        '2-F',
        [(5, 2), (5, 3), (5, 4)],
        ArrowDirection.right,
      ),
    ];

    return SolvableLevelResult(
      level: LevelModel(
        levelNumber: 2,
        gridRows: 6,
        gridCols: 6,
        arrows: arrows,
        heartsAllowed: 3,
        hintsAllowed: 2,
        difficulty: LevelDifficulty.easy,
      ),
      // Placement order: solve order is reverse (A,C,D,B,F,E).
      placementOrder: const ['2-E', '2-F', '2-B', '2-D', '2-C', '2-A'],
    );
  }

  /// Fixed Level 3: denser L2-style nesting (more hooks / dependencies).
  static SolvableLevelResult _nestedLevel3() {
    ArrowModel pathArrow(
      String id,
      List<(int, int)> cells,
      ArrowDirection direction,
    ) {
      final path = [for (final c in cells) GridCell(c.$1, c.$2)];
      final tip = path.last;
      return ArrowModel(
        id: id,
        row: tip.row,
        col: tip.col,
        direction: direction,
        path: path,
      );
    }

    // Clustered nest with more bends than Level 2 (same 6×6).
    final arrows = [
      // A: outer L tip RIGHT — free
      pathArrow(
        '3-A',
        [
          (5, 0),
          (4, 0),
          (3, 0),
          (2, 0),
          (1, 0),
          (0, 0),
          (0, 1),
          (0, 2),
          (0, 3),
          (0, 4),
          (0, 5),
        ],
        ArrowDirection.right,
      ),
      // B: outer right tip DOWN — free
      pathArrow(
        '3-B',
        [(1, 5), (2, 5), (3, 5), (4, 5), (5, 5)],
        ArrowDirection.down,
      ),
      // C: top-inner → down left-inner tip DOWN (blocked by E)
      pathArrow(
        '3-C',
        [(1, 4), (1, 3), (1, 2), (1, 1), (2, 1), (3, 1), (4, 1)],
        ArrowDirection.down,
      ),
      // D: mid-right bar tip RIGHT (blocked by B)
      pathArrow(
        '3-D',
        [(4, 2), (4, 3), (4, 4)],
        ArrowDirection.right,
      ),
      // E: bottom bar tip RIGHT (blocked by B)
      pathArrow(
        '3-E',
        [(5, 1), (5, 2), (5, 3), (5, 4)],
        ArrowDirection.right,
      ),
      // F: small center bar tip RIGHT (blocked by G/B)
      pathArrow(
        '3-F',
        [(2, 2), (2, 3)],
        ArrowDirection.right,
      ),
      // G: upper-mid vertical tip UP (blocked by C)
      pathArrow(
        '3-G',
        [(3, 4), (2, 4)],
        ArrowDirection.up,
      ),
      // H: center stub tip RIGHT (blocked by G/B) — axis-aligned with path
      pathArrow(
        '3-H',
        [(3, 2), (3, 3)],
        ArrowDirection.right,
      ),
    ];

    return SolvableLevelResult(
      level: LevelModel(
        levelNumber: 3,
        gridRows: 6,
        gridCols: 6,
        arrows: arrows,
        heartsAllowed: 3,
        hintsAllowed: 2,
        difficulty: LevelDifficulty.easy,
      ),
      // Solve: A,B,E,C,G,D,F,H (placement = reverse).
      placementOrder: const [
        '3-H',
        '3-F',
        '3-D',
        '3-G',
        '3-C',
        '3-E',
        '3-B',
        '3-A',
      ],
    );
  }

  /// Fixed Level 4: dense nested polylines (validated design).
  static SolvableLevelResult _nestedLevel4() {
    ArrowModel pathArrow(
      String id,
      List<(int, int)> cells,
      ArrowDirection direction,
    ) {
      final path = [for (final c in cells) GridCell(c.$1, c.$2)];
      final tip = path.last;
      return ArrowModel(
        id: id,
        row: tip.row,
        col: tip.col,
        direction: direction,
        path: path,
      );
    }

    // 7×7 nest — 9 arrows.
    final arrows = [
      pathArrow(
        '4-A',
        [
          (6, 0),
          (5, 0),
          (4, 0),
          (3, 0),
          (2, 0),
          (1, 0),
          (0, 0),
          (0, 1),
          (0, 2),
          (0, 3),
          (0, 4),
          (0, 5),
          (0, 6),
        ],
        ArrowDirection.right,
      ),
      pathArrow(
        '4-B',
        [(1, 6), (2, 6), (3, 6), (4, 6), (5, 6), (6, 6)],
        ArrowDirection.down,
      ),
      pathArrow(
        '4-C',
        [(6, 5), (6, 4), (6, 3), (6, 2), (6, 1)],
        ArrowDirection.left,
      ),
      pathArrow(
        '4-D',
        [(1, 5), (2, 5), (3, 5), (4, 5), (5, 5)],
        ArrowDirection.down,
      ),
      pathArrow(
        '4-E',
        [(1, 1), (1, 2), (1, 3), (1, 4)],
        ArrowDirection.right,
      ),
      // Stop short of 4-D tip — avoids head/tail clash on row 5.
      pathArrow(
        '4-F',
        [(5, 1), (5, 2), (5, 3)],
        ArrowDirection.right,
      ),
      // Stop short of former 4-F tip cell.
      pathArrow(
        '4-G',
        [(2, 4), (3, 4)],
        ArrowDirection.down,
      ),
      pathArrow(
        '4-H',
        [
          (2, 1),
          (3, 1),
          (4, 1),
          (4, 2),
          (4, 3),
          (3, 3),
          (2, 3),
        ],
        ArrowDirection.up,
      ),
      // Tip RIGHT — not UP into H's tip row (was confusing head/tail align).
      pathArrow('4-I', [(3, 2)], ArrowDirection.right),
    ];

    return SolvableLevelResult(
      level: LevelModel(
        levelNumber: 4,
        gridRows: 7,
        gridCols: 7,
        arrows: arrows,
        heartsAllowed: 3,
        hintsAllowed: 2,
        difficulty: LevelDifficulty.medium,
      ),
      // Solve: A,B,C,D,E,H,F,G,I (H waits for E; I waits for H)
      placementOrder: const [
        '4-I',
        '4-G',
        '4-F',
        '4-H',
        '4-E',
        '4-D',
        '4-C',
        '4-B',
        '4-A',
      ],
    );
  }

  /// Fixed Level 5: dense nested maze (validated design).
  static SolvableLevelResult _nestedLevel5() {
    ArrowModel pathArrow(
      String id,
      List<(int, int)> cells,
      ArrowDirection direction,
    ) {
      final path = [for (final c in cells) GridCell(c.$1, c.$2)];
      final tip = path.last;
      return ArrowModel(
        id: id,
        row: tip.row,
        col: tip.col,
        direction: direction,
        path: path,
      );
    }

    // 12×12 nest with 1-cell empty margin — tips stop short so heads
    // never stab the next ring (clean on mobile).
    final arrows = [
      pathArrow(
        '5-A',
        [for (var c = 1; c <= 10; c++) (1, c)],
        ArrowDirection.right,
      ),
      pathArrow(
        '5-B',
        [for (var r = 2; r <= 10; r++) (r, 10)],
        ArrowDirection.down,
      ),
      pathArrow(
        '5-C',
        [for (var c = 9; c >= 1; c--) (10, c)],
        ArrowDirection.left,
      ),
      // Stop short of A — gaps at (2,1)/(3,1) so D tip and I tip stay clear.
      pathArrow(
        '5-D',
        [for (var r = 9; r >= 4; r--) (r, 1)],
        ArrowDirection.up,
      ),
      // Stop short of B — gap at (2,9).
      pathArrow(
        '5-E',
        [(2, 2), (2, 3), (2, 4), (2, 5), (2, 6), (2, 7), (2, 8)],
        ArrowDirection.right,
      ),
      // Stop short of D — gap at (9,2).
      pathArrow(
        '5-F',
        [(9, 9), (9, 8), (9, 7), (9, 6), (9, 5), (9, 4), (9, 3)],
        ArrowDirection.left,
      ),
      // Stop short of F — gap at (8,9).
      pathArrow(
        '5-G',
        [(3, 9), (4, 9), (5, 9), (6, 9), (7, 9)],
        ArrowDirection.down,
      ),
      // Stop short so tip UP has empty cells before E (no tip-into-shaft).
      pathArrow(
        '5-H',
        [(8, 2), (7, 2), (6, 2)],
        ArrowDirection.up,
      ),
      // Open C on the LEFT — path never climbs back under its own top bar,
      // so tip cannot sit under / into its own head-tail corner.
      pathArrow(
        '5-I',
        [
          (3, 3),
          (3, 4),
          (3, 5),
          (3, 6),
          (3, 7),
          (3, 8),
          (4, 8),
          (5, 8),
          (6, 8),
          (7, 8),
          (8, 8),
          (8, 7),
          (8, 6),
          (8, 5),
          (8, 4),
          (8, 3),
        ],
        ArrowDirection.left,
      ),
      // Small L — tip DOWN into empty center, away from own top bar.
      pathArrow(
        '5-J',
        [
          (4, 5),
          (4, 6),
          (5, 6),
          (6, 6),
        ],
        ArrowDirection.down,
      ),
      // Fill open pocket left of the C — tip DOWN with gap before I.
      pathArrow(
        '5-K',
        [(4, 3), (5, 3), (6, 3)],
        ArrowDirection.down,
      ),
    ];

    return SolvableLevelResult(
      level: LevelModel(
        levelNumber: 5,
        gridRows: 12,
        gridCols: 12,
        arrows: arrows,
        heartsAllowed: 3,
        hintsAllowed: 1,
        difficulty: LevelDifficulty.medium,
      ),
      placementOrder: const [
        '5-J',
        '5-K',
        '5-I',
        '5-H',
        '5-G',
        '5-F',
        '5-E',
        '5-D',
        '5-C',
        '5-B',
        '5-A',
      ],
    );
  }

  /// Fixed Level 6: nested Hard maze (validated vertical-first design).
  static SolvableLevelResult _nestedLevel6() {
    ArrowModel pathArrow(
      String id,
      List<(int, int)> cells,
      ArrowDirection direction,
    ) {
      final path = [for (final c in cells) GridCell(c.$1, c.$2)];
      final tip = path.last;
      return ArrowModel(
        id: id,
        row: tip.row,
        col: tip.col,
        direction: direction,
        path: path,
      );
    }

    // 9×9 nest — 12 arrows.
    final arrows = [
      pathArrow(
        '6-A',
        [for (var r = 8; r >= 0; r--) (r, 0)],
        ArrowDirection.up,
      ),
      pathArrow(
        '6-B',
        [for (var c = 1; c <= 8; c++) (0, c)],
        ArrowDirection.right,
      ),
      pathArrow(
        '6-C',
        [for (var r = 1; r <= 8; r++) (r, 8)],
        ArrowDirection.down,
      ),
      pathArrow(
        '6-D',
        [for (var c = 7; c >= 1; c--) (8, c)],
        ArrowDirection.left,
      ),
      // Stop one cell short of 6-D tip to avoid head/tail clash.
      pathArrow(
        '6-E',
        [(1, 1), (2, 1), (3, 1), (4, 1), (5, 1), (6, 1)],
        ArrowDirection.down,
      ),
      pathArrow(
        '6-F',
        [(1, 7), (2, 7), (3, 7), (4, 7), (5, 7), (6, 7), (7, 7)],
        ArrowDirection.down,
      ),
      pathArrow(
        '6-G',
        [
          (1, 2),
          (1, 3),
          (2, 3),
          (2, 4),
          (1, 4),
          (1, 5),
          (1, 6),
        ],
        ArrowDirection.right,
      ),
      // Tip stops short of 6-F tip (was tip-into-tip on row 7).
      pathArrow(
        '6-H',
        [
          (7, 2),
          (7, 3),
          (6, 3),
          (6, 4),
          (7, 4),
          (7, 5),
        ],
        ArrowDirection.right,
      ),
      pathArrow(
        '6-I',
        [(2, 2), (3, 2), (4, 2), (5, 2), (6, 2)],
        ArrowDirection.down,
      ),
      pathArrow(
        '6-J',
        [(2, 6), (3, 6), (4, 6), (5, 6)],
        ArrowDirection.down,
      ),
      // Open U — last step UP matches tip UP (was tip UP after LEFT approach =
      // broken L-shaped head). Tip into empty (2,5), not into own start.
      pathArrow(
        '6-K',
        [
          (4, 3),
          (5, 3),
          (5, 4),
          (5, 5),
          (4, 5),
          (3, 5),
        ],
        ArrowDirection.up,
      ),
      // Tip DOWN — center of open U.
      pathArrow('6-L', [(4, 4)], ArrowDirection.down),
    ];

    return SolvableLevelResult(
      level: LevelModel(
        levelNumber: 6,
        gridRows: 9,
        gridCols: 9,
        arrows: arrows,
        heartsAllowed: 3,
        hintsAllowed: 2,
        difficulty: LevelDifficulty.hard,
      ),
      placementOrder: const [
        '6-L',
        '6-K',
        '6-J',
        '6-I',
        '6-H',
        '6-G',
        '6-F',
        '6-E',
        '6-D',
        '6-C',
        '6-B',
        '6-A',
      ],
    );
  }

  /// Fixed Level 7: mid horizontal separator (validated design).
  static SolvableLevelResult _nestedLevel7() {
    ArrowModel pathArrow(
      String id,
      List<(int, int)> cells,
      ArrowDirection direction,
    ) {
      final path = [for (final c in cells) GridCell(c.$1, c.$2)];
      final tip = path.last;
      return ArrowModel(
        id: id,
        row: tip.row,
        col: tip.col,
        direction: direction,
        path: path,
      );
    }

    // 10×10 nest — 14 arrows.
    final arrows = [
      pathArrow(
        '7-A',
        [for (var c = 0; c <= 9; c++) (0, c)],
        ArrowDirection.right,
      ),
      pathArrow(
        '7-B',
        [(1, 9), (2, 9), (3, 9)],
        ArrowDirection.down,
      ),
      pathArrow(
        '7-C',
        [for (var c = 8; c >= 0; c--) (4, c)],
        ArrowDirection.left,
      ),
      pathArrow(
        '7-D',
        [for (var r = 5; r <= 9; r++) (r, 0)],
        ArrowDirection.down,
      ),
      pathArrow(
        '7-E',
        [for (var c = 1; c <= 9; c++) (9, c)],
        ArrowDirection.right,
      ),
      // Tip one cell above 7-E tip — avoids head/tail clash, still blocked by E.
      pathArrow(
        '7-F',
        [(5, 9), (6, 9), (7, 9)],
        ArrowDirection.down,
      ),
      // Tip one cell above 7-C tip — avoids head/tail clash.
      pathArrow(
        '7-G',
        [(1, 0), (2, 0)],
        ArrowDirection.down,
      ),
      pathArrow(
        '7-H',
        [
          (1, 1),
          (1, 2),
          (2, 2),
          (2, 3),
          (1, 3),
          (1, 4),
          (1, 5),
          (1, 6),
          (1, 7),
          (1, 8),
        ],
        ArrowDirection.right,
      ),
      pathArrow(
        '7-I',
        [
          (3, 1),
          (3, 2),
          (3, 3),
          (3, 4),
          (3, 5),
          (3, 6),
          (3, 7),
          (3, 8),
          (2, 8),
          (2, 7),
          (2, 6),
          (2, 5),
          (2, 4),
        ],
        ArrowDirection.left,
      ),
      pathArrow(
        '7-J',
        [
          (5, 1),
          (5, 2),
          (5, 3),
          (5, 4),
          (5, 5),
          (5, 6),
          (5, 7),
          (5, 8),
        ],
        ArrowDirection.right,
      ),
      pathArrow(
        '7-K',
        [
          (8, 1),
          (8, 2),
          (7, 2),
          (7, 3),
          (8, 3),
          (8, 4),
          (8, 5),
          (8, 6),
          (8, 7),
          (8, 8),
        ],
        ArrowDirection.right,
      ),
      pathArrow('7-L', [(6, 1), (7, 1)], ArrowDirection.down),
      // Single cell — gap above 7-K tip avoids head/tail clash.
      pathArrow('7-M', [(6, 8)], ArrowDirection.down),
      pathArrow(
        '7-N',
        [(6, 4), (6, 5), (7, 5), (7, 4)],
        ArrowDirection.left,
      ),
    ];

    return SolvableLevelResult(
      level: LevelModel(
        levelNumber: 7,
        gridRows: 10,
        gridCols: 10,
        arrows: arrows,
        heartsAllowed: 3,
        hintsAllowed: 2,
        difficulty: LevelDifficulty.hard,
      ),
      // K no longer waits on F body at (8,9); solve K before F is fine.
      placementOrder: const [
        '7-N',
        '7-I',
        '7-M',
        '7-L',
        '7-H',
        '7-J',
        '7-B',
        '7-G',
        '7-F',
        '7-K',
        '7-E',
        '7-D',
        '7-C',
        '7-A',
      ],
    );
  }

  /// Fixed Level 8: mixed-direction Hard nest (opposing tips + zigzags).
  static SolvableLevelResult _nestedLevel8() {
    ArrowModel pathArrow(
      String id,
      List<(int, int)> cells,
      ArrowDirection direction,
    ) {
      final path = [for (final c in cells) GridCell(c.$1, c.$2)];
      final tip = path.last;
      return ArrowModel(
        id: id,
        row: tip.row,
        col: tip.col,
        direction: direction,
        path: path,
      );
    }

    // 11×11 — 12 arrows. Not a pure clockwise spiral: left/right
    // columns oppose the outer frame, mid rings zigzag.
    final arrows = [
      pathArrow(
        '8-A',
        [for (var r = 10; r >= 0; r--) (r, 0)],
        ArrowDirection.up,
      ),
      pathArrow(
        '8-B',
        [for (var c = 1; c <= 10; c++) (0, c)],
        ArrowDirection.right,
      ),
      pathArrow(
        '8-C',
        [for (var r = 1; r <= 10; r++) (r, 10)],
        ArrowDirection.down,
      ),
      pathArrow(
        '8-D',
        [for (var c = 9; c >= 1; c--) (10, c)],
        ArrowDirection.left,
      ),
      // Tip DOWN — opposes outer left UP (harder read).
      pathArrow(
        '8-E',
        [(1, 1), (2, 1), (3, 1), (4, 1), (5, 1), (6, 1), (7, 1), (8, 1)],
        ArrowDirection.down,
      ),
      // Tip UP — opposes outer right DOWN.
      pathArrow(
        '8-F',
        [(9, 9), (8, 9), (7, 9), (6, 9), (5, 9), (4, 9), (3, 9), (2, 9)],
        ArrowDirection.up,
      ),
      // Top serpentine tip RIGHT.
      pathArrow(
        '8-G',
        [
          (1, 2),
          (1, 3),
          (2, 3),
          (2, 4),
          (1, 4),
          (1, 5),
          (1, 6),
          (1, 7),
          (1, 8),
        ],
        ArrowDirection.right,
      ),
      // Bottom serpentine tip RIGHT — stop short of 8-F tip cell.
      pathArrow(
        '8-H',
        [
          (9, 2),
          (9, 3),
          (8, 3),
          (8, 4),
          (9, 4),
          (9, 5),
          (9, 6),
          (9, 7),
        ],
        ArrowDirection.right,
      ),
      pathArrow(
        '8-I',
        [(2, 2), (3, 2), (4, 2), (5, 2), (6, 2), (7, 2), (8, 2)],
        ArrowDirection.down,
      ),
      pathArrow(
        '8-J',
        [(2, 8), (3, 8), (4, 8), (5, 8), (6, 8), (7, 8)],
        ArrowDirection.down,
      ),
      // Open U — last step UP matches tip UP (clear head).
      pathArrow(
        '8-K',
        [
          (3, 3),
          (4, 3),
          (5, 3),
          (5, 4),
          (5, 5),
          (5, 6),
          (5, 7),
          (4, 7),
          (3, 7),
        ],
        ArrowDirection.up,
      ),
      // Center bar tip LEFT into empty.
      pathArrow(
        '8-L',
        [(3, 4), (3, 5), (3, 6), (4, 6), (4, 5), (4, 4)],
        ArrowDirection.left,
      ),
      // Upper mid gap (below G, above K) — tip RIGHT.
      pathArrow(
        '8-M',
        [(2, 5), (2, 6)],
        ArrowDirection.right,
      ),
      // Lower mid gap (below K, above H) — tip LEFT (opposes M).
      pathArrow(
        '8-N',
        [(6, 7), (6, 6), (6, 5), (6, 4)],
        ArrowDirection.left,
      ),
    ];

    return SolvableLevelResult(
      level: LevelModel(
        levelNumber: 8,
        gridRows: 11,
        gridCols: 11,
        arrows: arrows,
        heartsAllowed: 3,
        hintsAllowed: 2,
        difficulty: LevelDifficulty.hard,
      ),
      placementOrder: const [
        '8-L',
        '8-M',
        '8-N',
        '8-K',
        '8-J',
        '8-I',
        '8-H',
        '8-G',
        '8-F',
        '8-E',
        '8-D',
        '8-C',
        '8-B',
        '8-A',
      ],
    );
  }

  /// Fixed Level 9: dense bent Hard nest — 20 complex arrows (L11 reference).
  static SolvableLevelResult _nestedLevel9() {
    ArrowModel pathArrow(
      String id,
      List<(int, int)> cells,
      ArrowDirection direction,
    ) {
      final path = [for (final c in cells) GridCell(c.$1, c.$2)];
      final tip = path.last;
      return ArrowModel(
        id: id,
        row: tip.row,
        col: tip.col,
        direction: direction,
        path: path,
      );
    }

    // 14×14 — 20 bent arrows (L / U / S / jogs — not plain straights).
    final arrows = [
      // Outer L: top → right tip DOWN.
      pathArrow('9-A', [
        for (var c = 0; c <= 13; c++) (0, c),
        for (var r = 1; r <= 13; r++) (r, 13),
      ], ArrowDirection.down),
      // Outer L: bottom → left tip UP.
      pathArrow('9-B', [
        for (var c = 12; c >= 0; c--) (13, c),
        for (var r = 12; r >= 1; r--) (r, 0),
      ], ArrowDirection.up),
      // Right spine tip DOWN.
      pathArrow('9-C', [
        (1, 12), (2, 12), (3, 12), (4, 12), (5, 12), (6, 12), (7, 12), (8, 12),
        (9, 12), (10, 12), (11, 12),
      ], ArrowDirection.down),
      // Bottom tip RIGHT (stay on row 12 — clear of 9-H jog).
      pathArrow('9-D', [
        (12, 1), (12, 2), (12, 3), (12, 4), (12, 5), (12, 6), (12, 7), (12, 8),
        (12, 9), (12, 10), (12, 11),
      ], ArrowDirection.right),
      // Left spine tip DOWN.
      pathArrow('9-E', [
        (1, 1), (2, 1), (3, 1), (4, 1), (5, 1), (6, 1), (7, 1), (8, 1), (9, 1),
        (10, 1), (11, 1),
      ], ArrowDirection.down),
      // Top serpentine tip LEFT.
      pathArrow('9-F', [
        (1, 11), (1, 10), (2, 10), (2, 9), (1, 9), (1, 8), (1, 7), (1, 6),
        (1, 5), (1, 4), (1, 3), (1, 2),
      ], ArrowDirection.left),
      // Right-inner tip UP.
      pathArrow('9-G', [
        (11, 11), (10, 11), (9, 11), (8, 11), (7, 11), (6, 11), (5, 11),
        (4, 11), (3, 11), (2, 11),
      ], ArrowDirection.up),
      // Bottom serpentine tip RIGHT.
      pathArrow('9-H', [
        (11, 2), (11, 3), (10, 3), (10, 4), (11, 4), (11, 5), (11, 6), (11, 7),
        (11, 8), (11, 9), (11, 10),
      ], ArrowDirection.right),
      // Left-inner tip DOWN.
      pathArrow('9-I', [
        (2, 2), (3, 2), (4, 2), (5, 2), (6, 2), (7, 2), (8, 2), (9, 2), (10, 2),
      ], ArrowDirection.down),
      // Upper mid S tip RIGHT.
      pathArrow('9-J', [
        (2, 3), (2, 4), (3, 4), (3, 5), (2, 5), (2, 6), (2, 7), (2, 8),
      ], ArrowDirection.right),
      // Mid-left tip DOWN.
      pathArrow('9-K', [
        (3, 3), (4, 3), (5, 3), (6, 3), (7, 3), (8, 3), (9, 3),
      ], ArrowDirection.down),
      // Mid-right L tip DOWN.
      pathArrow('9-L', [
        (3, 8), (3, 9), (3, 10), (4, 10), (5, 10), (6, 10), (7, 10), (8, 10),
        (9, 10),
      ], ArrowDirection.down),
      // Lower mid S tip LEFT.
      pathArrow('9-M', [
        (10, 10), (10, 9), (9, 9), (9, 8), (10, 8), (10, 7), (10, 6), (10, 5),
      ], ArrowDirection.left),
      // Mid hook tip RIGHT (above the three).
      pathArrow('9-N', [
        (3, 6), (3, 7),
      ], ArrowDirection.right),
      // 1) Outer C tip LEFT — top→right, right→down, bottom→left (ref).
      pathArrow('9-O', [
        (4, 4), (4, 5), (4, 6), (4, 7), (4, 8),
        (5, 8), (6, 8), (7, 8),
        (7, 7), (7, 6), (7, 5), (7, 4),
      ], ArrowDirection.left),
      // 2) Inner U tip UP — down, right, up (ref).
      pathArrow('9-P', [
        (5, 5), (6, 5), (6, 6), (6, 7), (5, 7),
      ], ArrowDirection.up),
      // Mid-right tip DOWN.
      pathArrow('9-Q', [
        (4, 9), (5, 9), (6, 9), (7, 9), (8, 9),
      ], ArrowDirection.down),
      // Small filler tip DOWN (outside the three).
      pathArrow('9-R', [
        (8, 8),
      ], ArrowDirection.down),
      // 3) Bottom bar tip RIGHT (ref).
      pathArrow('9-S', [
        (8, 5), (8, 6), (8, 7),
      ], ArrowDirection.right),
      // Lower mid tip RIGHT.
      pathArrow('9-T', [
        (9, 4), (9, 5), (9, 6), (9, 7),
      ], ArrowDirection.right),
    ];

    return SolvableLevelResult(
      level: LevelModel(
        levelNumber: 9,
        gridRows: 14,
        gridCols: 14,
        arrows: arrows,
        heartsAllowed: 3,
        hintsAllowed: 2,
        difficulty: LevelDifficulty.hard,
      ),
      placementOrder: const [
        '9-T',
        '9-S',
        '9-R',
        '9-Q',
        '9-P',
        '9-O',
        '9-N',
        '9-L',
        '9-M',
        '9-K',
        '9-J',
        '9-I',
        '9-H',
        '9-G',
        '9-F',
        '9-E',
        '9-D',
        '9-C',
        '9-B',
        '9-A',
      ],
    );
  }

  /// Fixed Level 10: two-zone mid bar on 11×11 (validated design).
  static SolvableLevelResult _nestedLevel10() {
    ArrowModel pathArrow(
      String id,
      List<(int, int)> cells,
      ArrowDirection direction,
    ) {
      final path = [for (final c in cells) GridCell(c.$1, c.$2)];
      final tip = path.last;
      return ArrowModel(
        id: id,
        row: tip.row,
        col: tip.col,
        direction: direction,
        path: path,
      );
    }

    // 11×11 nest — 16 arrows.
    final arrows = [
      pathArrow(
        '10-A',
        [for (var c = 0; c <= 10; c++) (0, c)],
        ArrowDirection.right,
      ),
      pathArrow(
        '10-B',
        [(1, 10), (2, 10), (3, 10), (4, 10)],
        ArrowDirection.down,
      ),
      pathArrow(
        '10-C',
        [for (var c = 9; c >= 0; c--) (5, c)],
        ArrowDirection.left,
      ),
      pathArrow(
        '10-D',
        [for (var r = 6; r <= 10; r++) (r, 0)],
        ArrowDirection.down,
      ),
      pathArrow(
        '10-E',
        [for (var c = 1; c <= 10; c++) (10, c)],
        ArrowDirection.right,
      ),
      // Tip one cell above 10-E tip — avoids head/tail clash.
      pathArrow(
        '10-F',
        [(6, 10), (7, 10), (8, 10)],
        ArrowDirection.down,
      ),
      // Tip one cell above 10-C tip — avoids head/tail clash.
      pathArrow(
        '10-G',
        [(1, 0), (2, 0), (3, 0)],
        ArrowDirection.down,
      ),
      pathArrow(
        '10-H',
        [
          (1, 1),
          (1, 2),
          (2, 2),
          (2, 3),
          (1, 3),
          (1, 4),
          (1, 5),
          (1, 6),
          (1, 7),
          (1, 8),
          (1, 9),
        ],
        ArrowDirection.right,
      ),
      pathArrow(
        '10-I',
        [
          (4, 1),
          (4, 2),
          (4, 3),
          (4, 4),
          (4, 5),
          (4, 6),
          (4, 7),
          (4, 8),
          (4, 9),
          (3, 9),
          (3, 8),
          (3, 7),
          (3, 6),
          (3, 5),
          (3, 4),
          (3, 3),
        ],
        ArrowDirection.left,
      ),
      pathArrow(
        '10-J',
        [(2, 4), (2, 5), (2, 6), (2, 7), (2, 8), (2, 9)],
        ArrowDirection.right,
      ),
      pathArrow(
        '10-K',
        [
          (6, 1),
          (6, 2),
          (6, 3),
          (6, 4),
          (6, 5),
          (6, 6),
          (6, 7),
          (6, 8),
          (6, 9),
        ],
        ArrowDirection.right,
      ),
      pathArrow(
        '10-L',
        [
          (9, 1),
          (9, 2),
          (8, 2),
          (8, 3),
          (9, 3),
          (9, 4),
          (9, 5),
          (9, 6),
          (9, 7),
          (9, 8),
          (9, 9),
        ],
        ArrowDirection.right,
      ),
      pathArrow('10-M', [(7, 1), (8, 1)], ArrowDirection.down),
      // Single cell — gap above 10-L tip avoids head/tail clash.
      pathArrow('10-N', [(7, 9)], ArrowDirection.down),
      // Stop short of 10-N tip — avoids head/tail clash on row 7.
      pathArrow(
        '10-O',
        [
          (7, 3),
          (7, 4),
          (8, 4),
          (8, 5),
          (7, 5),
          (7, 6),
          (7, 7),
        ],
        ArrowDirection.right,
      ),
      pathArrow('10-P', [(8, 6), (8, 7)], ArrowDirection.right),
    ];

    return SolvableLevelResult(
      level: LevelModel(
        levelNumber: 10,
        gridRows: 11,
        gridCols: 11,
        arrows: arrows,
        heartsAllowed: 3,
        hintsAllowed: 1,
        difficulty: LevelDifficulty.expert,
      ),
      placementOrder: const [
        '10-P',
        '10-O',
        '10-N',
        '10-M',
        '10-J',
        '10-H',
        '10-L',
        '10-K',
        '10-I',
        '10-B',
        '10-G',
        '10-F',
        '10-E',
        '10-D',
        '10-C',
        '10-A',
      ],
    );
  }

  /// Fixed Level 11: dense interlocking nest (reference SS style).
  static SolvableLevelResult _nestedLevel11() {
    ArrowModel pathArrow(
      String id,
      List<(int, int)> cells,
      ArrowDirection direction,
    ) {
      final path = [for (final c in cells) GridCell(c.$1, c.$2)];
      final tip = path.last;
      return ArrowModel(
        id: id,
        row: tip.row,
        col: tip.col,
        direction: direction,
        path: path,
      );
    }

    final arrows = [
      pathArrow('11-A', [
        for (var c = 0; c <= 11; c++) (0, c),
        for (var r = 1; r <= 11; r++) (r, 11),
      ], ArrowDirection.down),
      pathArrow('11-B', [
        for (var c = 10; c >= 0; c--) (11, c),
        for (var r = 10; r >= 1; r--) (r, 0),
      ], ArrowDirection.up),
      pathArrow('11-C', [for (var r = 1; r <= 9; r++) (r, 10)], ArrowDirection.down),
      pathArrow('11-D', [for (var c = 1; c <= 9; c++) (10, c)], ArrowDirection.right),
      pathArrow('11-E', [for (var r = 1; r <= 9; r++) (r, 1)], ArrowDirection.down),
      pathArrow('11-F', [
        (1, 9), (1, 8), (2, 8), (2, 7), (1, 7), (1, 6), (1, 5), (1, 4), (1, 3),
        (1, 2),
      ], ArrowDirection.left),
      pathArrow('11-G', [
        (9, 9), (8, 9), (7, 9), (6, 9), (5, 9), (4, 9), (3, 9), (2, 9),
      ], ArrowDirection.up),
      pathArrow('11-H', [
        (9, 2), (9, 3), (8, 3), (8, 4), (9, 4), (9, 5), (9, 6), (9, 7), (9, 8),
      ], ArrowDirection.right),
      pathArrow('11-I', [
        (2, 2), (3, 2), (4, 2), (5, 2), (6, 2), (7, 2), (8, 2),
      ], ArrowDirection.down),
      pathArrow('11-J', [
        (2, 3), (2, 4), (3, 4), (3, 5), (2, 5), (2, 6),
      ], ArrowDirection.right),
      pathArrow('11-K', [
        (3, 3), (4, 3), (5, 3), (6, 3), (7, 3),
      ], ArrowDirection.down),
      // Stop short of 11-H tip to avoid head/tail clash.
      pathArrow('11-L', [
        (3, 6), (3, 7), (3, 8), (4, 8), (5, 8), (6, 8), (7, 8),
      ], ArrowDirection.down),
      // Outer C: last segment left → tip LEFT (ref).
      pathArrow('11-M', [
        (5, 4), (6, 4), (7, 4), (7, 5), (7, 6), (7, 7), (6, 7), (5, 7),
        (4, 7), (4, 6), (4, 5), (4, 4),
      ], ArrowDirection.left),
      // Inner U: last segment up → tip UP (ref).
      pathArrow('11-N', [
        (5, 5), (6, 5), (6, 6), (5, 6),
      ], ArrowDirection.up),
      // Bottom bar: last segment right → tip RIGHT (ref).
      pathArrow('11-O', [
        (8, 5), (8, 6), (8, 7),
      ], ArrowDirection.right),
    ];

    return SolvableLevelResult(
      level: LevelModel(
        levelNumber: 11,
        gridRows: 12,
        gridCols: 12,
        arrows: arrows,
        heartsAllowed: 3,
        hintsAllowed: 1,
        difficulty: LevelDifficulty.expert,
      ),
      placementOrder: const [
        '11-N', '11-O', '11-M', '11-L', '11-K', '11-I', '11-J', '11-H', '11-G',
        '11-F', '11-E', '11-C', '11-D', '11-B', '11-A',
      ],
    );
  }

  /// Level 12 — Expert nested maze (full board, L11-style outer frame + woven center).
  static SolvableLevelResult _nestedLevel12() {
    ArrowModel pathArrow(
      String id,
      List<(int, int)> cells,
      ArrowDirection direction,
    ) {
      final path = [for (final c in cells) GridCell(c.$1, c.$2)];
      final tip = path.last;
      return ArrowModel(
        id: id,
        row: tip.row,
        col: tip.col,
        direction: direction,
        path: path,
      );
    }

    final arrows = [
      // Outer frame (split L for readable Expert density)
      pathArrow('12-A', [for (var c = 0; c <= 14; c++) (0, c)], ArrowDirection.right),
      pathArrow('12-B', [for (var r = 1; r <= 15; r++) (r, 14)], ArrowDirection.down),
      pathArrow('12-C', [for (var c = 13; c >= 0; c--) (15, c)], ArrowDirection.left),
      pathArrow('12-D', [for (var r = 14; r >= 1; r--) (r, 0)], ArrowDirection.up),
      // Inner rails
      pathArrow('12-E', [for (var r = 1; r <= 7; r++) (r, 13)], ArrowDirection.down),
      pathArrow('12-F', [for (var r = 8; r <= 13; r++) (r, 13)], ArrowDirection.down),
      pathArrow('12-G', [for (var c = 1; c <= 12; c++) (14, c)], ArrowDirection.right),
      pathArrow('12-H', [(14, 13)], ArrowDirection.right),
      pathArrow('12-I', [for (var r = 1; r <= 7; r++) (r, 1)], ArrowDirection.down),
      pathArrow('12-J', [for (var r = 8; r <= 13; r++) (r, 1)], ArrowDirection.down),
      // Top serpentine
      pathArrow('12-K', [
        (1, 12), (1, 11), (2, 11), (2, 10), (1, 10), (1, 9), (1, 8), (1, 7),
      ], ArrowDirection.left),
      pathArrow('12-L', [(1, 6), (1, 5), (1, 4), (1, 3), (1, 2)], ArrowDirection.left),
      // Right / bottom / left serpentine
      pathArrow('12-M', [for (var r = 13; r >= 8; r--) (r, 12)], ArrowDirection.up),
      pathArrow('12-N', [for (var r = 7; r >= 2; r--) (r, 12)], ArrowDirection.up),
      pathArrow('12-O', [
        (13, 2), (13, 3), (12, 3), (12, 4), (13, 4), (13, 5), (13, 6),
      ], ArrowDirection.right),
      pathArrow('12-P', [(13, 7), (13, 8), (13, 9), (13, 10), (13, 11)], ArrowDirection.right),
      pathArrow('12-Q', [for (var r = 2; r <= 7; r++) (r, 2)], ArrowDirection.down),
      pathArrow('12-R', [for (var r = 8; r <= 12; r++) (r, 2)], ArrowDirection.down),
      // Upper mid weave
      pathArrow('12-S', [
        (2, 3), (2, 4), (3, 4), (3, 5), (2, 5), (2, 6),
      ], ArrowDirection.right),
      pathArrow('12-T', [(2, 7), (2, 8), (2, 9)], ArrowDirection.right),
      pathArrow('12-U', [(3, 3), (4, 3), (5, 3), (6, 3), (7, 3)], ArrowDirection.down),
      pathArrow('12-V', [(8, 3), (9, 3), (10, 3), (11, 3)], ArrowDirection.down),
      pathArrow('12-W', [
        (3, 9), (3, 10), (3, 11), (4, 11), (5, 11), (6, 11),
      ], ArrowDirection.down),
      pathArrow('12-X', [(7, 11), (8, 11), (9, 11), (10, 11), (11, 11)], ArrowDirection.down),
      pathArrow('12-Y', [
        (12, 11), (12, 10), (11, 10), (11, 9), (12, 9), (12, 8),
      ], ArrowDirection.left),
      pathArrow('12-Z', [(12, 7), (12, 6), (12, 5)], ArrowDirection.left),
      pathArrow('12-AA', [
        (3, 6), (3, 7), (3, 8), (4, 8), (5, 8),
      ], ArrowDirection.down),
      pathArrow('12-AB', [(8, 8), (9, 8), (10, 8)], ArrowDirection.down),
      pathArrow('12-AN', [(6, 8), (7, 8)], ArrowDirection.down),
      // Nested center C / U / bar
      pathArrow('12-AC', [
        (5, 4), (6, 4), (7, 4), (8, 4), (9, 4), (10, 4),
      ], ArrowDirection.down),
      pathArrow('12-AD', [(10, 5), (10, 6), (10, 7)], ArrowDirection.right),
      pathArrow('12-AE', [
        (9, 7), (8, 7), (7, 7), (6, 7), (5, 7), (5, 6), (5, 5),
      ], ArrowDirection.left),
      pathArrow('12-AF', [
        (6, 5), (7, 5), (8, 5), (9, 5), (9, 6), (8, 6), (7, 6), (6, 6),
      ], ArrowDirection.up),
      pathArrow('12-AG', [(4, 4), (4, 5), (4, 6), (4, 7)], ArrowDirection.right),
      pathArrow('12-AH', [(4, 9), (4, 10), (5, 10), (6, 10)], ArrowDirection.down),
      pathArrow('12-AI', [(7, 10), (8, 10), (9, 10)], ArrowDirection.down),
      pathArrow('12-AJ', [(11, 4), (11, 5), (11, 6), (11, 7), (11, 8)], ArrowDirection.right),
      pathArrow('12-AK', [(5, 9), (6, 9), (7, 9)], ArrowDirection.down),
      pathArrow('12-AL', [(8, 9), (9, 9), (10, 9)], ArrowDirection.down),
      pathArrow('12-AM', [(10, 10)], ArrowDirection.down),
    ];

    return SolvableLevelResult(
      level: LevelModel(
        levelNumber: 12,
        gridRows: 16,
        gridCols: 15,
        arrows: arrows,
        heartsAllowed: 3,
        hintsAllowed: 1,
        difficulty: LevelDifficulty.expert,
      ),
      placementOrder: const [
        '12-AF', '12-AG', '12-AH', '12-AI', '12-AD', '12-AM', '12-AK', '12-AL',
        '12-AE', '12-AC', '12-AA', '12-AN', '12-AB', '12-AJ', '12-W', '12-X',
        '12-Y', '12-Z', '12-U', '12-V', '12-S', '12-T', '12-Q', '12-R', '12-O',
        '12-P', '12-M', '12-N', '12-K', '12-L', '12-I', '12-J', '12-G', '12-E',
        '12-F', '12-H', '12-D', '12-C', '12-B', '12-A',
      ],
    );
  }

  /// Level 13 — Expert nest: L12 core + outermost ring on 18×17.
  static SolvableLevelResult _nestedLevel13() {
    ArrowModel pathArrow(
      String id,
      List<(int, int)> cells,
      ArrowDirection direction,
    ) {
      final path = [for (final c in cells) GridCell(c.$1, c.$2)];
      final tip = path.last;
      return ArrowModel(
        id: id,
        row: tip.row,
        col: tip.col,
        direction: direction,
        path: path,
      );
    }

    final arrows = [
      // Outermost ring
      pathArrow('13-OUTA', [for (var c = 0; c <= 16; c++) (0, c)], ArrowDirection.right),
      pathArrow('13-OUTB', [for (var r = 1; r <= 17; r++) (r, 16)], ArrowDirection.down),
      pathArrow('13-OUTC', [for (var c = 15; c >= 0; c--) (17, c)], ArrowDirection.left),
      pathArrow('13-OUTD', [for (var r = 16; r >= 1; r--) (r, 0)], ArrowDirection.up),

      // Second-layer outer frame
      pathArrow('13-A', [for (var c = 1; c <= 15; c++) (1, c)], ArrowDirection.right),
      pathArrow('13-B', [for (var r = 2; r <= 16; r++) (r, 15)], ArrowDirection.down),
      pathArrow('13-C', [for (var c = 14; c >= 1; c--) (16, c)], ArrowDirection.left),
      pathArrow('13-D', [for (var r = 15; r >= 2; r--) (r, 1)], ArrowDirection.up),

      // Inner rails
      pathArrow('13-E', [for (var r = 2; r <= 8; r++) (r, 14)], ArrowDirection.down),
      pathArrow('13-F', [for (var r = 9; r <= 14; r++) (r, 14)], ArrowDirection.down),
      pathArrow('13-G', [for (var c = 2; c <= 13; c++) (15, c)], ArrowDirection.right),
      pathArrow('13-H', [(15, 14)], ArrowDirection.right),
      pathArrow('13-I', [for (var r = 2; r <= 8; r++) (r, 2)], ArrowDirection.down),
      pathArrow('13-J', [for (var r = 9; r <= 14; r++) (r, 2)], ArrowDirection.down),

      // Top serpentine
      pathArrow('13-K', [
        (2, 13), (2, 12), (3, 12), (3, 11), (2, 11), (2, 10), (2, 9), (2, 8),
      ], ArrowDirection.left),
      pathArrow('13-L', [(2, 7), (2, 6), (2, 5), (2, 4), (2, 3)], ArrowDirection.left),

      // Right / bottom / left serpentine
      pathArrow('13-M', [for (var r = 14; r >= 9; r--) (r, 13)], ArrowDirection.up),
      pathArrow('13-N', [for (var r = 8; r >= 3; r--) (r, 13)], ArrowDirection.up),
      pathArrow('13-O', [
        (14, 3), (14, 4), (13, 4), (13, 5), (14, 5), (14, 6), (14, 7),
      ], ArrowDirection.right),
      pathArrow('13-P', [(14, 8), (14, 9), (14, 10), (14, 11), (14, 12)], ArrowDirection.right),
      pathArrow('13-Q', [for (var r = 3; r <= 8; r++) (r, 3)], ArrowDirection.down),
      pathArrow('13-R', [for (var r = 9; r <= 13; r++) (r, 3)], ArrowDirection.down),

      // Upper mid weave
      pathArrow('13-S', [
        (3, 4), (3, 5), (4, 5), (4, 6), (3, 6), (3, 7),
      ], ArrowDirection.right),
      pathArrow('13-T', [(3, 8), (3, 9), (3, 10)], ArrowDirection.right),
      pathArrow('13-U', [(4, 4), (5, 4), (6, 4), (7, 4), (8, 4)], ArrowDirection.down),
      pathArrow('13-V', [(9, 4), (10, 4), (11, 4), (12, 4)], ArrowDirection.down),
      pathArrow('13-W', [
        (4, 10), (4, 11), (4, 12), (5, 12), (6, 12), (7, 12),
      ], ArrowDirection.down),
      pathArrow('13-X', [(8, 12), (9, 12), (10, 12), (11, 12), (12, 12)], ArrowDirection.down),
      pathArrow('13-Y', [
        (13, 12), (13, 11), (12, 11), (12, 10), (13, 10), (13, 9),
      ], ArrowDirection.left),
      pathArrow('13-Z', [(13, 8), (13, 7), (13, 6)], ArrowDirection.left),
      pathArrow('13-AA', [
        (4, 7), (4, 8), (4, 9), (5, 9), (6, 9),
      ], ArrowDirection.down),
      pathArrow('13-AB', [(9, 9), (10, 9), (11, 9)], ArrowDirection.down),
      pathArrow('13-AN', [(7, 9), (8, 9)], ArrowDirection.down),

      // Nested center C / U / bar
      pathArrow('13-AC', [
        (6, 5), (7, 5), (8, 5), (9, 5), (10, 5), (11, 5),
      ], ArrowDirection.down),
      pathArrow('13-AD', [(11, 6), (11, 7), (11, 8)], ArrowDirection.right),
      pathArrow('13-AE', [
        (10, 8), (9, 8), (8, 8), (7, 8), (6, 8), (6, 7), (6, 6),
      ], ArrowDirection.left),
      pathArrow('13-AF', [
        (7, 6), (8, 6), (9, 6), (10, 6), (10, 7), (9, 7), (8, 7), (7, 7),
      ], ArrowDirection.up),
      pathArrow('13-AG', [(5, 5), (5, 6), (5, 7), (5, 8)], ArrowDirection.right),
      pathArrow('13-AH', [(5, 10), (5, 11), (6, 11), (7, 11)], ArrowDirection.down),
      pathArrow('13-AI', [(8, 11), (9, 11), (10, 11)], ArrowDirection.down),
      pathArrow('13-AJ', [(12, 5), (12, 6), (12, 7), (12, 8), (12, 9)], ArrowDirection.right),
      pathArrow('13-AK', [(6, 10), (7, 10), (8, 10)], ArrowDirection.down),
      pathArrow('13-AL', [(9, 10), (10, 10), (11, 10)], ArrowDirection.down),
      pathArrow('13-AM', [(11, 11)], ArrowDirection.down),
    ];

    return SolvableLevelResult(
      level: LevelModel(
        levelNumber: 13,
        gridRows: 18,
        gridCols: 17,
        arrows: arrows,
        heartsAllowed: 3,
        hintsAllowed: 1,
        difficulty: LevelDifficulty.expert,
      ),
      placementOrder: const [
        '13-AF', '13-AG', '13-AH', '13-AI', '13-AD', '13-AM', '13-AK', '13-AL',
        '13-AE', '13-AC', '13-AA', '13-AN', '13-AB', '13-AJ', '13-W', '13-X',
        '13-Y', '13-Z', '13-U', '13-V', '13-S', '13-T', '13-Q', '13-R', '13-O',
        '13-P', '13-M', '13-N', '13-K', '13-L', '13-I', '13-J', '13-G', '13-E',
        '13-F', '13-H', '13-D', '13-C', '13-B', '13-A',
        '13-OUTD', '13-OUTC', '13-OUTB', '13-OUTA',
      ],
    );
  }

  /// Level 14 — denser Expert triangle nest.
  static SolvableLevelResult _nestedLevel14() {
    return _shapedExpertLevel(
      levelNumber: 14,
      rows: 18,
      cols: 19,
      mask: uprightTriangleMask(18, 19),
      minArrows: 32,
      maxPathLen: 13,
      fillTarget: 0.9,
      fallbackRows: 16,
      fallbackCols: 17,
      fallbackMask: uprightTriangleMask(16, 17),
    );
  }

  /// Level 15 — denser Expert diamond nest.
  static SolvableLevelResult _nestedLevel15() {
    return _shapedExpertLevel(
      levelNumber: 15,
      rows: 18,
      cols: 18,
      mask: diamondMask(18, 18),
      minArrows: 34,
      maxPathLen: 13,
      fillTarget: 0.9,
      fallbackRows: 16,
      fallbackCols: 16,
      fallbackMask: diamondMask(16, 16),
    );
  }

  /// Level 16 — denser Expert hexagon nest.
  static SolvableLevelResult _nestedLevel16() {
    return _shapedExpertLevel(
      levelNumber: 16,
      rows: 19,
      cols: 21,
      mask: hexagonMask(19, 21),
      minArrows: 36,
      maxPathLen: 13,
      fillTarget: 0.9,
      fallbackRows: 17,
      fallbackCols: 19,
      fallbackMask: hexagonMask(17, 19),
    );
  }

  /// Level 17 — packed mix nest (small/medium/tall, little free space).
  static SolvableLevelResult _nestedLevel17() {
    return _shapedExpertLevel(
      levelNumber: 17,
      rows: 20,
      cols: 20,
      mask: generateHeartShapeMask(20),
      minArrows: 40,
      maxPathLen: 12,
      fillTarget: 0.98,
      fallbackRows: 18,
      fallbackCols: 18,
      fallbackMask: generateHeartShapeMask(18),
      mixPathSizes: true,
    );
  }

  /// Level 18 — heart silhouette: short L/U/zigzag arrows pack into each other
  /// (Escape Puzzle style). Not a concentric ring like L12/L13.
  static SolvableLevelResult _nestedLevel18() {
    return _shapedExpertLevel(
      levelNumber: 18,
      rows: 19,
      cols: 19,
      mask: generateHeartShapeMask(19),
      minArrows: 50,
      maxPathLen: 8,
      fillTarget: 0.99,
      fallbackRows: 17,
      fallbackCols: 17,
      fallbackMask: generateHeartShapeMask(17),
      mixPathSizes: true,
    );
  }

  /// Level 19 — packed mix circle nest.
  static SolvableLevelResult _nestedLevel19() {
    return _shapedExpertLevel(
      levelNumber: 19,
      rows: 21,
      cols: 21,
      mask: circleMask(21, 21),
      minArrows: 48,
      maxPathLen: 12,
      fillTarget: 0.97,
      fallbackRows: 19,
      fallbackCols: 19,
      fallbackMask: circleMask(19, 19),
      mixPathSizes: true,
    );
  }

  /// Level 20 — packed mix nest.
  static SolvableLevelResult _nestedLevel20() {
    return _shapedExpertLevel(
      levelNumber: 20,
      rows: 22,
      cols: 22,
      mask: octagonMask(22, 22),
      minArrows: 52,
      maxPathLen: 12,
      fillTarget: 0.97,
      fallbackRows: 20,
      fallbackCols: 20,
      fallbackMask: circleMask(20, 20),
      mixPathSizes: true,
    );
  }

  /// Level 21 — packed Escape-puzzle mix nest.
  static SolvableLevelResult _nestedLevel21() {
    return _denseExpertRect(
      levelNumber: 21,
      rows: 18,
      cols: 18,
      minArrows: 48,
      maxFreeAtStart: 6,
      mixPathSizes: true,
    );
  }

  /// Level 22 — packed Escape-puzzle mix nest.
  static SolvableLevelResult _nestedLevel22() {
    return _denseExpertRect(
      levelNumber: 22,
      rows: 18,
      cols: 19,
      minArrows: 50,
      maxFreeAtStart: 6,
      mixPathSizes: true,
    );
  }

  /// Level 23 — packed Escape-puzzle mix nest.
  static SolvableLevelResult _nestedLevel23() {
    return _denseExpertRect(
      levelNumber: 23,
      rows: 19,
      cols: 19,
      minArrows: 52,
      maxFreeAtStart: 6,
      mixPathSizes: true,
    );
  }

  /// Level 24 — packed Escape-puzzle mix nest.
  static SolvableLevelResult _nestedLevel24() {
    return _denseExpertRect(
      levelNumber: 24,
      rows: 19,
      cols: 20,
      minArrows: 54,
      maxFreeAtStart: 6,
      mixPathSizes: true,
    );
  }

  /// Level 25 — packed Escape-puzzle mix nest.
  static SolvableLevelResult _nestedLevel25() {
    return _denseExpertRect(
      levelNumber: 25,
      rows: 20,
      cols: 20,
      minArrows: 56,
      maxFreeAtStart: 7,
      mixPathSizes: true,
    );
  }

  /// Level 26 — packed Escape-puzzle mix nest.
  static SolvableLevelResult _nestedLevel26() {
    return _denseExpertRect(
      levelNumber: 26,
      rows: 20,
      cols: 21,
      minArrows: 58,
      maxFreeAtStart: 7,
      mixPathSizes: true,
    );
  }

  /// Level 27 — packed Escape-puzzle mix nest.
  static SolvableLevelResult _nestedLevel27() {
    return _denseExpertRect(
      levelNumber: 27,
      rows: 21,
      cols: 21,
      minArrows: 60,
      maxFreeAtStart: 7,
      mixPathSizes: true,
    );
  }

  /// Level 28 — packed Escape-puzzle mix nest.
  static SolvableLevelResult _nestedLevel28() {
    return _denseExpertRect(
      levelNumber: 28,
      rows: 21,
      cols: 22,
      minArrows: 62,
      maxFreeAtStart: 8,
      mixPathSizes: true,
    );
  }

  /// Level 29 — packed Escape-puzzle mix nest.
  static SolvableLevelResult _nestedLevel29() {
    return _denseExpertRect(
      levelNumber: 29,
      rows: 22,
      cols: 22,
      minArrows: 64,
      maxFreeAtStart: 8,
      mixPathSizes: true,
    );
  }

  /// Level 30 — packed Escape-puzzle mix nest (campaign finale).
  static SolvableLevelResult _nestedLevel30() {
    return _denseExpertRect(
      levelNumber: 30,
      rows: 22,
      cols: 23,
      minArrows: 66,
      maxFreeAtStart: 8,
      mixPathSizes: true,
    );
  }

  /// Full-rectangle Expert nest — ref-style bent hooks, few free at start.
  static SolvableLevelResult _denseExpertRect({
    required int levelNumber,
    required int rows,
    required int cols,
    required int minArrows,
    int maxFreeAtStart = 4,
    bool mixPathSizes = false,
  }) {
    StateError? lastError;
    final minPath = mixPathSizes ? 2 : 3;
    final fillTight = mixPathSizes ? 0.97 : 0.94;

    SolvableLevelResult? tryOnce({
      required int r,
      required int c,
      required int seed,
      required int arrows,
      required double fill,
      required int maxPath,
      int? freeCap,
    }) {
      try {
        return generateNestedSolvableLevel(
          levelNumber,
          r,
          c,
          3,
          1,
          difficulty: LevelDifficulty.expert,
          seed: seed,
          fillTarget: fill,
          minPathLen: minPath,
          maxPathLen: maxPath,
          minArrows: arrows,
          hardNest: true,
          mixPathSizes: mixPathSizes,
          maxFreeAtStart: freeCap,
        );
      } on StateError catch (e) {
        lastError = e;
        return null;
      }
    }

    for (var attempt = 0; attempt < (mixPathSizes ? 60 : 160); attempt++) {
      final result = tryOnce(
        r: rows,
        c: cols,
        seed: levelNumber * 9973 + attempt * 173 + rows * 19,
        arrows: minArrows,
        fill: fillTight,
        maxPath: mixPathSizes ? 12 : 11,
        freeCap: attempt < (mixPathSizes ? 40 : 90)
            ? maxFreeAtStart
            : maxFreeAtStart + 2,
      );
      if (result != null) return result;
    }

    final soft = (minArrows * 0.85).round().clamp(34, minArrows);
    for (var attempt = 0; attempt < (mixPathSizes ? 40 : 100); attempt++) {
      final result = tryOnce(
        r: rows,
        c: cols,
        seed: levelNumber * 4243 + attempt * 41,
        arrows: soft,
        fill: mixPathSizes ? 0.95 : 0.92,
        maxPath: mixPathSizes ? 10 : 9,
        freeCap: maxFreeAtStart + 3,
      );
      if (result != null) return result;
    }

    for (var attempt = 0; attempt < 80; attempt++) {
      final result = tryOnce(
        r: (rows + 1).clamp(rows, 24),
        c: (cols + 1).clamp(cols, 24),
        seed: levelNumber * 1117 + attempt * 29,
        arrows: (minArrows * 0.75).round().clamp(32, soft),
        fill: mixPathSizes ? 0.93 : 0.9,
        maxPath: 8,
        freeCap: maxFreeAtStart + 3,
      );
      if (result != null) return result;
    }

    for (var attempt = 0; attempt < 100; attempt++) {
      final size = 18 + (attempt % 5);
      final result = tryOnce(
        r: size,
        c: size + (attempt.isEven ? 1 : 0),
        seed: levelNumber * 3331 + attempt * 17,
        arrows: (minArrows * 0.65).round().clamp(36, soft),
        fill: mixPathSizes ? 0.94 : 0.91,
        maxPath: 8,
        freeCap: 8,
      );
      if (result != null) return result;
    }

    return tryOnce(
          r: 19,
          c: 19,
          seed: levelNumber * 3331,
          arrows: mixPathSizes ? 40 : 42,
          fill: mixPathSizes ? 0.93 : 0.91,
          maxPath: 8,
          freeCap: 8,
        ) ??
        generateNestedSolvableLevel(
          levelNumber,
          19,
          19,
          3,
          1,
          difficulty: LevelDifficulty.expert,
          seed: levelNumber * 3331 + 7,
          fillTarget: mixPathSizes ? 0.92 : 0.9,
          minPathLen: minPath,
          maxPathLen: 8,
          minArrows: 40,
          hardNest: true,
          mixPathSizes: mixPathSizes,
        );
  }

  /// Shared builder for L14–L20 shaped Expert nests (solvable by construction).
  static SolvableLevelResult _shapedExpertLevel({
    required int levelNumber,
    required int rows,
    required int cols,
    required List<List<bool>> mask,
    required int minArrows,
    required int maxPathLen,
    required double fillTarget,
    required int fallbackRows,
    required int fallbackCols,
    required List<List<bool>> fallbackMask,
    bool mixPathSizes = false,
  }) {
    StateError? lastError;
    final minPath = mixPathSizes ? 2 : 3;

    SolvableLevelResult? tryOnce({
      required int r,
      required int c,
      required List<List<bool>> m,
      required int seed,
      required int arrows,
      required double fill,
      required int maxPath,
      int? freeCap,
    }) {
      try {
        return generateNestedSolvableLevel(
          levelNumber,
          r,
          c,
          3,
          1,
          difficulty: LevelDifficulty.expert,
          seed: seed,
          shapeMask: m,
          fillTarget: fill,
          minPathLen: minPath,
          maxPathLen: maxPath,
          minArrows: arrows,
          hardNest: true,
          mixPathSizes: mixPathSizes,
          maxFreeAtStart: freeCap,
        );
      } on StateError catch (e) {
        lastError = e;
        return null;
      }
    }

    for (var attempt = 0; attempt < (mixPathSizes ? 50 : 120); attempt++) {
      final result = tryOnce(
        r: rows,
        c: cols,
        m: mask,
        seed: levelNumber * 9973 + attempt * 173 + rows * 19,
        arrows: minArrows,
        fill: fillTarget,
        maxPath: maxPathLen,
        freeCap: attempt < (mixPathSizes ? 30 : 70) ? 8 : 11,
      );
      if (result != null) return result;
    }

    final softMin = (minArrows * 0.8).round().clamp(26, minArrows);
    for (var attempt = 0; attempt < (mixPathSizes ? 30 : 80); attempt++) {
      final result = tryOnce(
        r: fallbackRows,
        c: fallbackCols,
        m: fallbackMask,
        seed: levelNumber * 7919 + attempt * 97 + 42,
        arrows: softMin,
        fill: (fillTarget - 0.02).clamp(0.84, 0.95),
        maxPath: maxPathLen,
        freeCap: 12,
      );
      if (result != null) return result;
    }

    for (var attempt = 0; attempt < 70; attempt++) {
      final size = 18 + (attempt % 4);
      final result = tryOnce(
        r: size,
        c: size,
        m: octagonMask(size, size),
        seed: levelNumber * 4243 + attempt * 53,
        arrows: softMin,
        fill: mixPathSizes ? 0.94 : 0.9,
        maxPath: mixPathSizes ? 10 : 9,
        freeCap: 10,
      );
      if (result != null) return result;
    }

    return tryOnce(
          r: 18,
          c: 18,
          m: octagonMask(18, 18),
          seed: levelNumber * 2221,
          arrows: mixPathSizes ? 32 : 28,
          fill: mixPathSizes ? 0.92 : 0.88,
          maxPath: 8,
        ) ??
        generateNestedSolvableLevel(
          levelNumber,
          18,
          18,
          3,
          1,
          difficulty: LevelDifficulty.expert,
          seed: levelNumber * 2221 + 3,
          shapeMask: octagonMask(18, 18),
          fillTarget: mixPathSizes ? 0.9 : 0.86,
          minPathLen: minPath,
          maxPathLen: 8,
          minArrows: mixPathSizes ? 28 : 24,
          hardNest: true,
          mixPathSizes: mixPathSizes,
        );
  }

}

final levelRepositoryProvider = Provider<LevelRepository>((ref) {
  return LevelRepository();
});

final levelsRepositoryProvider = levelRepositoryProvider;

final levelByNumberProvider = Provider.family<LevelModel, int>((ref, levelNumber) {
  return ref.watch(levelRepositoryProvider).getLevel(levelNumber);
});

final dailyLevelProvider = Provider<LevelModel>((ref) {
  return ref.watch(levelRepositoryProvider).getDailyLevel();
});

/// Daily puzzle for a calendar day key `yyyy-MM-dd`.
final dailyLevelForDateProvider =
    Provider.family<LevelModel, String>((ref, dateKey) {
  final parts = dateKey.split('-');
  final date = DateTime(
    int.parse(parts[0]),
    int.parse(parts[1]),
    int.parse(parts[2]),
  );
  return ref.watch(levelRepositoryProvider).getDailyLevel(date);
});

String dailyDateKey(DateTime date) {
  final y = date.year.toString().padLeft(4, '0');
  final m = date.month.toString().padLeft(2, '0');
  final d = date.day.toString().padLeft(2, '0');
  return '$y-$m-$d';
}
