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

/// Path must be a single orthogonally-adjacent chain (no gaps / diagonals /
/// duplicates), tip must match last cell, and tip direction must match the
/// last step. Broken paths look like floating fragments on the board.
bool _pathIsConnectedPolyline(ArrowModel arrow) {
  final path = arrow.path;
  if (path.length < 2) return false;
  final seen = <String>{};
  for (var i = 0; i < path.length; i++) {
    final key = '${path[i].row}:${path[i].col}';
    if (!seen.add(key)) return false;
    if (i == 0) continue;
    final prev = path[i - 1];
    final cur = path[i];
    final dist =
        (cur.row - prev.row).abs() + (cur.col - prev.col).abs();
    if (dist != 1) return false;
  }
  final tip = path.last;
  if (tip.row != arrow.row || tip.col != arrow.col) return false;
  final prev = path[path.length - 2];
  final (dr, dc) = _dirDelta(arrow.direction);
  if (tip.row - prev.row != dr || tip.col - prev.col != dc) return false;
  return true;
}

/// Throws [StateError] listing the first bad arrow (level + id).
void _assertNestedPathsValid(int levelNumber, List<ArrowModel> arrows) {
  final occupied = <String, String>{};
  for (final arrow in arrows) {
    if (!_pathIsConnectedPolyline(arrow)) {
      throw StateError(
        'Broken arrow path L$levelNumber/${arrow.id} '
        '(len=${arrow.path.length}, tip=${arrow.row},${arrow.col} '
        '${arrow.direction.name})',
      );
    }
    for (final cell in arrow.path) {
      final key = '${cell.row}:${cell.col}';
      final other = occupied[key];
      if (other != null) {
        throw StateError(
          'Overlapping arrow cells L$levelNumber: $other & ${arrow.id} at $key',
        );
      }
      occupied[key] = arrow.id;
    }
  }
}

int _pathTurnCount(List<GridCell> path) {
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
  return turns;
}

/// Count occupied neighbors sitting in the "inside corner" of path bends
/// (U/C hooks wrapping around another arrow — reference style).
int _cupWrapBonus(List<GridCell> path, Set<String> occupied) {
  if (path.length < 3 || occupied.isEmpty) return 0;
  var bonus = 0;
  for (var i = 1; i < path.length - 1; i++) {
    final a = path[i - 1];
    final b = path[i];
    final c = path[i + 1];
    final d1r = b.row - a.row;
    final d1c = b.col - a.col;
    final d2r = c.row - b.row;
    final d2c = c.col - b.col;
    if (d1r == d2r && d1c == d2c) continue; // straight — no pocket
    // Inside corner cell of the 90° bend.
    final ir = b.row - d1r + d2r;
    final ic = b.col - d1c + d2c;
    // Prefer the diagonal inward pocket from the bend.
    final pocketR = a.row + d2r;
    final pocketC = a.col + d2c;
    for (final (pr, pc) in [(ir, ic), (pocketR, pocketC), (c.row - d1r, c.col - d1c)]) {
      if (occupied.contains('$pr:$pc')) bonus++;
    }
  }
  return bonus;
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
  /// When true with [maxFreeAtStart], require free count == that value.
  bool exactFreeAtStart = false,
  /// Daily-style mix: long + medium + small arrow lengths interleaved.
  bool mixPathSizes = false,
}) {
  final random = Random(
    seed ?? levelNumber * 9973 + rows * 131 + cols * 17,
  );
  final occupied = <String>{};
  final arrows = <ArrowModel>[];
  final placementOrder = <String>[];
  var nextArrowSeq = 0;
  String allocArrowId() => '$levelNumber-${nextArrowSeq++}';

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
    // Exact-one-free: prefer empty cells on a currently-free tip's escape ray
    // so the next snake can seal and keep free count at 1.
    if (exactFreeAtStart && maxFreeAtStart == 1 && arrows.isNotEmpty) {
      final rayCells = <(int, int)>[];
      for (final other in arrows) {
        if (!escapeClear(other.row, other.col, other.direction)) continue;
        final (dr, dc) = _dirDelta(other.direction);
        var r = other.row + dr;
        var c = other.col + dc;
        while (inBounds(r, c)) {
          if (!inMask(r, c)) {
            if (!playableAheadOnRay(r, c, dr, dc)) break;
            r += dr;
            c += dc;
            continue;
          }
          if (occupied.contains(cellKey(r, c))) break;
          if (isEmpty(r, c)) rayCells.add((r, c));
          r += dr;
          c += dc;
        }
      }
      if (rayCells.isNotEmpty) {
        return rayCells[random.nextInt(rayCells.length)];
      }
    }
    // Hard nests: tips almost always grow beside existing snakes (hooks around).
    if (hardNest && occupied.isNotEmpty && random.nextDouble() < 0.92) {
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
        // Bias hard toward bend-into-neighbor growth (U/C hooks like reference).
        if (nestTurns.isNotEmpty && random.nextDouble() < 0.94) {
          pick = nestTurns[random.nextInt(nestTurns.length)];
        } else if (hugging.isNotEmpty && random.nextDouble() < 0.85) {
          pick = hugging[random.nextInt(hugging.length)];
        } else if (turns.isNotEmpty && random.nextDouble() < 0.95) {
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

  /// Pull a free tip back one cell so its escape ray gains a sealable empty.
  bool tryRetractAFreeTip() {
    if (!(exactFreeAtStart && maxFreeAtStart == 1)) return false;
    int countFree() {
      var n = 0;
      for (final a in arrows) {
        if (isArrowFree(
          arrow: a,
          arrows: arrows,
          gridRows: rows,
          gridCols: cols,
          shapeMask: shapeMask,
        )) {
          n++;
        }
      }
      return n;
    }

    for (var i = 0; i < arrows.length; i++) {
      final arrow = arrows[i];
      if (!escapeClear(arrow.row, arrow.col, arrow.direction)) continue;
      if (arrow.path.length <= (minPathLen < 2 ? 2 : minPathLen)) continue;
      final oldTip = arrow.path.last;
      final newPath = arrow.path.sublist(0, arrow.path.length - 1);
      final newTip = newPath.last;
      if (newPath.length < 2) continue;
      final prev = newPath[newPath.length - 2];
      final dr = newTip.row - prev.row;
      final dc = newTip.col - prev.col;
      ArrowDirection? newDir;
      for (final d in ArrowDirection.values) {
        final (ddr, ddc) = _dirDelta(d);
        if (ddr == dr && ddc == dc) {
          newDir = d;
          break;
        }
      }
      if (newDir == null) continue;
      occupied.remove(cellKey(oldTip.row, oldTip.col));
      arrows[i] = ArrowModel(
        id: arrow.id,
        row: newTip.row,
        col: newTip.col,
        direction: newDir,
        path: newPath,
      );
      // Retract must not reopen a second free tip.
      if (countFree() != 1) {
        occupied.add(cellKey(oldTip.row, oldTip.col));
        arrows[i] = arrow;
        continue;
      }
      return true;
    }
    return false;
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

      // Count how many currently-free tips this path would seal.
      var sealedFrees = 0;
      for (final other in arrows) {
        if (!escapeClear(other.row, other.col, other.direction)) continue;
        final (odr, odc) = _dirDelta(other.direction);
        var rr = other.row + odr;
        var cc = other.col + odc;
        while (inBounds(rr, cc)) {
          if (!inMask(rr, cc)) {
            if (!playableAheadOnRay(rr, cc, odr, odc)) break;
            rr += odr;
            cc += odc;
            continue;
          }
          final hit = path.any((cell) => cell.row == rr && cell.col == cc);
          if (hit) {
            sealedFrees++;
            break;
          }
          if (occupied.contains(cellKey(rr, cc))) break;
          rr += odr;
          cc += odc;
        }
      }
      // Exact-one-free: after the first tip, every new snake must seal ≥1
      // free tip so free-at-start stays exactly 1 (new free replaces sealed).
      if (exactFreeAtStart &&
          maxFreeAtStart == 1 &&
          arrows.isNotEmpty &&
          sealedFrees < 1) {
        continue;
      }
      // First tip must leave ≥2 empty ray cells so later seals can land.
      if (exactFreeAtStart && maxFreeAtStart == 1 && arrows.isEmpty) {
        final (dr, dc) = _dirDelta(direction);
        var empties = 0;
        var r = tipR + dr;
        var c = tipC + dc;
        while (inBounds(r, c) && empties < 3) {
          if (!inMask(r, c)) {
            if (!playableAheadOnRay(r, c, dr, dc)) break;
            r += dr;
            c += dc;
            continue;
          }
          empties++;
          r += dr;
          c += dc;
        }
        if (empties < 5) continue;
      }

      var score = sealedFrees * (exactFreeAtStart && maxFreeAtStart == 1 ? 40 : 14);
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
          // Reward bends / U-hooks (reference: wrap around another arrow).
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
          score += turns * 7;
          if (turns >= 2) score += 10; // real hook / zigzag, not a single L
          if (turns >= 3) score += 6;
          if (path.length >= 5 && turns == 0) score -= 14;

          // Nest against neighbors — floating separated snakes score poorly.
          final contacts = nestContactScore(path);
          score += contacts * 6;
          if (arrows.isNotEmpty && contacts == 0) score -= 28;
          if (contacts >= 3) score += 10;
          if (contacts >= 5) score += 6;

          // Occupied cells cupped in bend pockets (hooks around neighbors).
          score += _cupWrapBonus(path, occupied) * 5;
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
      // Prefer multi-bend hooks when available (reference U/C wraps).
      final hooked = [
        for (final o in pool)
          if (_pathTurnCount(o.path) >= 2) o,
      ];
      if (hooked.isNotEmpty) pool = hooked;
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
        id: allocArrowId(),
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
    // Hard nests (L11+ style): mostly mid/long serpentine; few min-length decoys.
    if (hardNest && minPathLen >= 5) {
      final roll = random.nextDouble();
      if (roll < 0.35) {
        // Long winding 10–max (~35%+)
        final tallMin = max(10, minPathLen + 3).clamp(minPathLen, maxPathLen);
        return tallMin +
            random.nextInt((maxPathLen - tallMin).clamp(0, 99) + 1);
      }
      if (roll < 0.88) {
        final mid =
            ((minPathLen + maxPathLen) / 2).round().clamp(minPathLen, maxPathLen);
        final lo = max(minPathLen, mid - 1);
        final hi = min(maxPathLen, mid + 2);
        return lo + random.nextInt((hi - lo).clamp(0, 99) + 1);
      }
      // Decoy: min length only (still continuous — never 1–3 cell stubs)
      return minPathLen;
    }
    // Hard nests: mostly mid/long serpentine; few short decoys (~10%).
    if (hardNest && minPathLen >= 4) {
      final roll = random.nextDouble();
      if (roll < 0.30) {
        // Long winding 8–max (25–30%+ of pack)
        final tallMin = max(8, minPathLen + 2).clamp(minPathLen, maxPathLen);
        return tallMin +
            random.nextInt((maxPathLen - tallMin).clamp(0, 99) + 1);
      }
      if (roll < 0.90) {
        final mid =
            ((minPathLen + maxPathLen) / 2).round().clamp(minPathLen, maxPathLen);
        final lo = (mid - 1).clamp(minPathLen, maxPathLen);
        final hi = (mid + 2).clamp(minPathLen, maxPathLen);
        return lo + random.nextInt((hi - lo).clamp(0, 99) + 1);
      }
      // Decoy shorts (visually simple, still placed deep via pocket tips)
      return max(2, minPathLen - 1);
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

  final growFloor = hardNest && minPathLen >= 4 ? minPathLen : 2;
  // L11+ strict: never place stub fragments below minPathLen.
  final strictMin = minPathLen >= 5 ? minPathLen : growFloor;
  /// Dedicated seal: tip on a free escape ray (guarantees sealedFrees ≥ 1).
  bool tryForceSealPlacement() {
    if (!(exactFreeAtStart && maxFreeAtStart == 1) || arrows.isEmpty) {
      return false;
    }
    final frees = <ArrowModel>[
      for (final a in arrows)
        if (escapeClear(a.row, a.col, a.direction)) a,
    ];
    if (frees.isEmpty) return false;
    frees.shuffle(random);
    for (final free in frees) {
      final (dr, dc) = _dirDelta(free.direction);
      final cells = <(int, int)>[];
      var r = free.row + dr;
      var c = free.col + dc;
      while (inBounds(r, c)) {
        if (!inMask(r, c)) {
          if (!playableAheadOnRay(r, c, dr, dc)) break;
          r += dr;
          c += dc;
          continue;
        }
        if (occupied.contains(cellKey(r, c))) break;
        if (isEmpty(r, c)) cells.add((r, c));
        r += dr;
        c += dc;
      }
      // Straight seal leaves ≥5 empties ahead so the chain can continue.
      for (var tipIndex = 4; tipIndex <= cells.length - 6; tipIndex++) {
        final (tr, tc) = cells[tipIndex];
        if (!escapeClear(tr, tc, free.direction)) continue;
        final segment = cells.sublist(tipIndex - 4, tipIndex + 1);
        final path = [
          for (final cell in segment) GridCell(cell.$1, cell.$2),
        ];
        placeArrow(
          ArrowModel(
            id: allocArrowId(),
            row: tr,
            col: tc,
            direction: free.direction,
            path: path,
          ),
        );
        return true;
      }

      // Short ray: tip on ray, grow sideways (still seals via tip cell).
      cells.shuffle(random);
      for (var idx = 0; idx < cells.length; idx++) {
        final (tr, tc) = cells[idx];
        final dirs = [
          for (final d in ArrowDirection.values)
            if (d != free.direction) d,
        ]..shuffle(random);
        for (final direction in dirs) {
          if (!escapeClear(tr, tc, direction)) continue;
          final path = growPath(
            tipR: tr,
            tipC: tc,
            direction: direction,
            targetLen: max(minPathLen, 8),
            minLen: minPathLen < 2 ? 2 : minPathLen,
          );
          if (path == null) continue;
          placeArrow(
            ArrowModel(
              id: allocArrowId(),
              row: tr,
              col: tc,
              direction: direction,
              path: path,
            ),
          );
          return true;
        }
      }
    }
    return false;
  }

  if (exactFreeAtStart && maxFreeAtStart == 1) {
    // Chain seals: each new tip sits on the current free tip's ray.
    // Guarantees free-at-start == 1 and reverse-solvable packing.
    var keeperOk = false;
    // Systematic keeper near center pointing at a long clear ray to the rim.
    for (final direction in ArrowDirection.values) {
      if (keeperOk) break;
      final (dr, dc) = _dirDelta(direction);
      final tipR = rows ~/ 2;
      final tipC = cols ~/ 2;
      // Walk tip toward opposite of direction so shaft fits + ray is long.
      for (var back = 4; back <= 10 && !keeperOk; back++) {
        final tr = tipR + (-dr) * 0; // keep center tip, check shaft/ray
        final tc = tipC;
        // Try tip positions along the center line.
        for (var shift = -3; shift <= 3 && !keeperOk; shift++) {
          final pr = (tipR + (dr == 0 ? shift : 0)).clamp(0, rows - 1);
          final pc = (tipC + (dc == 0 ? shift : 0)).clamp(0, cols - 1);
          // Tip inset `back` cells from the far rim along -direction.
          final farR = dr > 0
              ? rows - 1
              : dr < 0
                  ? 0
                  : pr;
          final farC = dc > 0
              ? cols - 1
              : dc < 0
                  ? 0
                  : pc;
          // Place tip `back` cells before the rim along direction... 
          // Simpler: tip at center-ish, require ahead>=5 and shaft 4.
          if (!isEmpty(pr, pc)) continue;
          var ahead = 0;
          var r = pr + dr;
          var c = pc + dc;
          while (inBounds(r, c) && ahead < 8) {
            if (!inMask(r, c)) {
              if (!playableAheadOnRay(r, c, dr, dc)) break;
              r += dr;
              c += dc;
              continue;
            }
            if (!isEmpty(r, c)) break;
            ahead++;
            r += dr;
            c += dc;
          }
          if (ahead < 5) continue;
          final path = <GridCell>[];
          var ok = true;
          for (var i = 4; i >= 0; i--) {
            final sr = pr - dr * i;
            final sc = pc - dc * i;
            if (!isEmpty(sr, sc)) {
              ok = false;
              break;
            }
            path.add(GridCell(sr, sc));
          }
          if (!ok) continue;
          placeArrow(
            ArrowModel(
              id: allocArrowId(),
              row: pr,
              col: pc,
              direction: direction,
              path: path,
            ),
          );
          keeperOk = true;
        }
      }
    }
    // Random fallback.
    for (var attempt = 0; attempt < 2000 && !keeperOk; attempt++) {
      final direction =
          ArrowDirection.values[random.nextInt(ArrowDirection.values.length)];
      final (dr, dc) = _dirDelta(direction);
      final tipR = random.nextInt(rows);
      final tipC = random.nextInt(cols);
      if (!isEmpty(tipR, tipC)) continue;
      var ahead = 0;
      var r = tipR + dr;
      var c = tipC + dc;
      while (inBounds(r, c) && ahead < 5) {
        if (!inMask(r, c)) {
          if (!playableAheadOnRay(r, c, dr, dc)) break;
          r += dr;
          c += dc;
          continue;
        }
        if (!isEmpty(r, c)) break;
        ahead++;
        r += dr;
        c += dc;
      }
      if (ahead < 5) continue;
      final path = <GridCell>[];
      var ok = true;
      for (var i = 4; i >= 0; i--) {
        final pr = tipR - dr * i;
        final pc = tipC - dc * i;
        if (!isEmpty(pr, pc)) {
          ok = false;
          break;
        }
        path.add(GridCell(pr, pc));
      }
      if (!ok) continue;
      placeArrow(
        ArrowModel(
          id: allocArrowId(),
          row: tipR,
          col: tipC,
          direction: direction,
          path: path,
        ),
      );
      keeperOk = true;
    }
    if (!keeperOk) {
      throw StateError('Nested nest failed to place free keeper tip');
    }

    var safety = 0;
    var stall = 0;
    while (arrows.length < max(minArrows, 15) && underArrowCap() && safety < 8000) {
      safety++;
      final before = arrows.length;
      if (!tryForceSealPlacement()) {
        tryRetractAFreeTip();
        tryForceSealPlacement();
      }
      // Extra densify once past minArrows floor.
      if (arrows.length == before) {
        final tip = pickTip();
        final len = pickPathLen();
        tryPlaceAt(
          tipR: tip.$1,
          tipC: tip.$2,
          targetLen: len < strictMin ? strictMin : len,
          minLen: strictMin < 2 ? 2 : strictMin,
          preferInward: true,
        );
      }
      if (arrows.length == before) {
        stall++;
        if (stall > 600) break;
      } else {
        stall = 0;
      }
    }

    // Optional fill toward targetCells with seal-required placements.
    safety = 0;
    stall = 0;
    while (occupied.length < targetCells && underArrowCap() && safety < 4000) {
      safety++;
      final before = occupied.length;
      tryForceSealPlacement();
      if (occupied.length == before) {
        final tip = pickTip();
        tryPlaceAt(
          tipR: tip.$1,
          tipC: tip.$2,
          targetLen: pickPathLen().clamp(strictMin, maxPathLen),
          minLen: strictMin < 2 ? 2 : strictMin,
          preferInward: true,
        );
      }
      if (occupied.length == before) {
        stall++;
        if (stall > 40) tryRetractAFreeTip();
        if (stall > 400) break;
      } else {
        stall = 0;
      }
    }
  } else {
  // Phase 1: woven snakes — tips biased into nesting pockets.
  var safety = 0;
  var stall = 0;
  while (occupied.length < targetCells && underArrowCap() && safety < 5000) {
    safety++;
    final before = occupied.length;
    if (exactFreeAtStart && maxFreeAtStart == 1 && arrows.isNotEmpty) {
      tryForceSealPlacement();
    }
    if (occupied.length == before) {
      final tip = pickTip();
      final len = pickPathLen();
      tryPlaceAt(
        tipR: tip.$1,
        tipC: tip.$2,
        targetLen: len < strictMin ? strictMin : len,
        minLen: strictMin < 2 ? 2 : strictMin,
        preferInward: true,
      );
    }
    if (occupied.length == before) {
      stall++;
      if (exactFreeAtStart &&
          maxFreeAtStart == 1 &&
          stall > 20 &&
          stall % 10 == 0) {
        tryRetractAFreeTip();
      }
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
    if (exactFreeAtStart && maxFreeAtStart == 1 && arrows.isNotEmpty) {
      tryForceSealPlacement();
    }
    if (occupied.length == before) {
      final tip = pickTip();
      final len = mixPathSizes ? pickPathLen() : (strictMin + random.nextInt(3));
      tryPlaceAt(
        tipR: tip.$1,
        tipC: tip.$2,
        targetLen: len < strictMin ? strictMin : len,
        minLen: strictMin < 2 ? 2 : strictMin,
        preferInward: true,
      );
    }
    if (occupied.length == before) {
      stall++;
      if (exactFreeAtStart &&
          maxFreeAtStart == 1 &&
          stall > 20 &&
          stall % 10 == 0) {
        tryRetractAFreeTip();
      }
      if (stall > 300) break;
    } else {
      stall = 0;
    }
  }

  // Phase 3: leftovers — hard nests still bury tips (refs); soft allow any tip.
  // Never place stub fragments when minPathLen is strict (L11+).
  final mopMin = hardNest && minPathLen >= 5 ? minPathLen : 2;
  for (var r = 0; r < rows && underArrowCap(); r++) {
    for (var c = 0; c < cols && underArrowCap(); c++) {
      if (!isEmpty(r, c)) continue;
      tryPlaceAt(
        tipR: r,
        tipC: c,
        targetLen: mixPathSizes
            ? pickPathLen()
            : (hardNest ? max(4, mopMin) : 3),
        minLen: mopMin,
        preferInward: hardNest || mixPathSizes,
      );
    }
  }

  // Phase 4: hard nests mop remaining corridors — keep inward bias.
  // Skip ultra-short (2–3) fills when minPathLen >= 5 — those look like
  // broken floating fragments on the board.
  if (hardNest) {
    for (var pass = 0; pass < 5 && underArrowCap(); pass++) {
      var placed = false;
      for (var r = 0; r < rows && underArrowCap(); r++) {
        for (var c = 0; c < cols && underArrowCap(); c++) {
          if (!isEmpty(r, c)) continue;
          final len =
              mopMin >= 5 ? mopMin + (pass % 3) : 2 + (pass % 3);
          if (tryPlaceAt(
            tipR: r,
            tipC: c,
            targetLen: len,
            minLen: mopMin,
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
  // Disabled for strict hard nests — short stubs are the broken-arrow look.
  if ((mixPathSizes || maxArrows != null) && mopMin < 5) {
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

  } // end non-exactOne reverse pack

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
    if (exactFreeAtStart) {
      if (free != maxFreeAtStart) {
        throw StateError(
          'Nested nest free-at-start $free != exact $maxFreeAtStart',
        );
      }
    } else if (free > maxFreeAtStart) {
      throw StateError(
        'Nested nest too open at start ($free free > $maxFreeAtStart)',
      );
    }
  }

  _assertNestedPathsValid(levelNumber, arrows);

  // Retracts / seal-required packs can desync reverse placement order —
  // rebuild from a wave-clear solve so hints stay valid.
  if (exactFreeAtStart && maxFreeAtStart == 1) {
    final live = cloneArrows(arrows);
    final solve = <String>[];
    var clearSafety = 0;
    while (live.any((a) => !a.isRemoved) && clearSafety < 5000) {
      clearSafety++;
      ArrowModel? pick;
      for (final a in live) {
        if (a.isRemoved) continue;
        if (!isArrowFree(
          arrow: a,
          arrows: live,
          gridRows: rows,
          gridCols: cols,
          shapeMask: shapeMask,
        )) {
          continue;
        }
        if (pick == null || a.id.compareTo(pick.id) < 0) pick = a;
      }
      if (pick == null) {
        throw StateError(
          'Nested nest unsolvable (cleared ${solve.length}/${arrows.length})',
        );
      }
      solve.add(pick.id);
      final idx = live.indexWhere((a) => a.id == pick!.id);
      live[idx] = live[idx].copyWith(isRemoved: true);
    }
    placementOrder
      ..clear()
      ..addAll(solve.reversed);
  }

  final built = LevelModel(
    levelNumber: levelNumber,
    gridRows: rows,
    gridCols: cols,
    arrows: arrows,
    heartsAllowed: hearts,
    hintsAllowed: hints,
    difficulty: difficulty,
    shapeMask: shapeMask,
  );
  final depths = arrowClearDepths(built);
  if (depths.length != arrows.length) {
    throw StateError(
      'Nested nest unsolvable after free-cap (cleared ${depths.length}/'
      '${arrows.length})',
    );
  }

  return SolvableLevelResult(
    level: built,
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

/// Campaign levels 1–10. Daily / endless helpers stay separate.
class LevelRepository {
  LevelRepository({List<SolvableLevelResult>? prebuilt})
      : _prebuilt = prebuilt,
        _lazy = List<SolvableLevelResult?>.filled(campaignLevelCount, null);

  final List<SolvableLevelResult>? _prebuilt;
  final List<SolvableLevelResult?> _lazy;
  final Map<int, LevelModel> _dailyCache = {};

  static const int campaignLevelCount = 10;

  SolvableLevelResult _resultAt(int index) {
    if (index < 0 || index >= campaignLevelCount) {
      throw RangeError('No campaign level at index $index');
    }
    if (_prebuilt != null) return _prebuilt![index];
    return _lazy[index] ??= _buildCampaignLevel(index + 1);
  }

  /// Prefer [getLevel] — only 10 campaign levels are shipped.
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
    if (key > campaignLevelCount) {
      return _resultAt(campaignLevelCount - 1).level;
    }
    return _resultAt(key - 1).level;
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
  /// Large nested silhouette (~120–150 arrows), mixed sizes, hardNest.
  static LevelModel _buildDailyChallengeLevel(DateTime day, int levelNumber) {
    final dayOfYear = day.difference(DateTime(day.year)).inDays;
    final shapeIndex = (dayOfYear + day.year * 5 + day.month * 3) % 12;

    // Large primary boards so 120–150 mixed arrows pack tightly.
    final config = switch (shapeIndex) {
      0 => (
          rows: 26,
          cols: 26,
          mask: generateHeartShapeMask(26),
          fbRows: 24,
          fbCols: 24,
          fbMask: generateHeartShapeMask(24),
        ),
      1 => (
          rows: 26,
          cols: 26,
          mask: ovalMask(26, 26),
          fbRows: 24,
          fbCols: 24,
          fbMask: ovalMask(24, 24),
        ),
      2 => (
          rows: 26,
          cols: 26,
          mask: starMask(26, 26),
          fbRows: 24,
          fbCols: 24,
          fbMask: cloverMask(24, 24),
        ),
      3 => (
          rows: 26,
          cols: 26,
          mask: crescentMask(26, 26),
          fbRows: 24,
          fbCols: 24,
          fbMask: circleMask(24, 24),
        ),
      4 => (
          rows: 26,
          cols: 26,
          mask: cloverMask(26, 26),
          fbRows: 24,
          fbCols: 24,
          fbMask: octagonMask(24, 24),
        ),
      5 => (
          rows: 27,
          cols: 25,
          mask: shieldMask(27, 25),
          fbRows: 24,
          fbCols: 22,
          fbMask: shieldMask(24, 22),
        ),
      6 => (
          rows: 24,
          cols: 28,
          mask: fishMask(24, 28),
          fbRows: 22,
          fbCols: 26,
          fbMask: fishMask(22, 26),
        ),
      7 => (
          rows: 26,
          cols: 26,
          mask: butterflyMask(26, 26),
          fbRows: 24,
          fbCols: 24,
          fbMask: flowerMask(24, 24),
        ),
      8 => (
          rows: 25,
          cols: 27,
          mask: birdOutlineMask(25, 27),
          fbRows: 23,
          fbCols: 25,
          fbMask: birdOutlineMask(23, 25),
        ),
      9 => (
          rows: 26,
          cols: 26,
          mask: catFaceMask(26, 26),
          fbRows: 24,
          fbCols: 24,
          fbMask: catFaceMask(24, 24),
        ),
      10 => (
          rows: 26,
          cols: 28,
          mask: stadiumMask(26, 28),
          fbRows: 24,
          fbCols: 26,
          fbMask: stadiumMask(24, 26),
        ),
      _ => (
          rows: 27,
          cols: 27,
          mask: octagonMask(27, 27),
          fbRows: 24,
          fbCols: 24,
          fbMask: diamondMask(24, 24),
        ),
    };

    const minArrows = 100;
    const maxArrows = 150;
    StateError? lastError;

    LevelModel? tryBuild({
      required int rows,
      required int cols,
      required List<List<bool>> mask,
      required int seed,
      required double fill,
      required int arrows,
      int maxPath = 10,
      bool nest = true,
    }) {
      final want = arrows.clamp(minArrows, maxArrows);
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
          maxPathLen: maxPath,
          minArrows: want,
          maxArrows: maxArrows,
          hardNest: nest,
          mixPathSizes: true,
          maxFreeAtStart: null,
        ).level;
      } on StateError catch (e) {
        lastError = e;
        return null;
      }
    }

    // Dense nest pack: always ≥100 arrows, fill white gaps in the silhouette.
    for (var attempt = 0; attempt < 28; attempt++) {
      final target = (145 - (attempt ~/ 4) * 5).clamp(minArrows, maxArrows);
      final level = tryBuild(
        rows: config.rows,
        cols: config.cols,
        mask: config.mask,
        seed: levelNumber + attempt * 211 + shapeIndex * 47,
        fill: 0.995,
        arrows: target,
        maxPath: attempt < 12 ? 9 : 7,
        nest: true,
      );
      if (level != null) return level;
    }

    for (var attempt = 0; attempt < 20; attempt++) {
      final level = tryBuild(
        rows: config.fbRows,
        cols: config.fbCols,
        mask: config.fbMask,
        seed: levelNumber + 9000 + attempt * 131,
        fill: 0.99,
        arrows: (130 - attempt).clamp(minArrows, maxArrows),
        maxPath: 7,
        nest: true,
      );
      if (level != null) return level;
    }

    // Pack with shorter shafts so empty mask cells get arrows (still nested mix).
    for (var attempt = 0; attempt < 24; attempt++) {
      final level = tryBuild(
        rows: config.rows,
        cols: config.cols,
        mask: config.mask,
        seed: levelNumber + 17000 + attempt * 97,
        fill: 0.995,
        arrows: (120 - (attempt ~/ 3) * 2).clamp(minArrows, maxArrows),
        maxPath: 6,
        nest: false,
      );
      if (level != null) return level;
    }

    for (var attempt = 0; attempt < 24; attempt++) {
      final size = 26 + (attempt % 4); // 26–29 large enough for 100+ arrows
      final mask = switch ((shapeIndex + attempt) % 5) {
        0 => circleMask(size, size),
        1 => ovalMask(size, size),
        2 => generateHeartShapeMask(size),
        3 => cloverMask(size, size),
        _ => octagonMask(size, size),
      };
      final level = tryBuild(
        rows: size,
        cols: size,
        mask: mask,
        seed: levelNumber + 29000 + attempt * 37,
        fill: 0.99,
        arrows: (125 - attempt).clamp(minArrows, maxArrows),
        maxPath: 6,
        nest: attempt.isEven,
      );
      if (level != null) return level;
    }

    // Last resort: big circle, short pieces, must still hit 100.
    for (var attempt = 0; attempt < 40; attempt++) {
      final size = 28 + (attempt % 3);
      final level = tryBuild(
        rows: size,
        cols: size,
        mask: circleMask(size, size),
        seed: levelNumber + 41000 + attempt * 19,
        fill: 0.98,
        arrows: minArrows,
        maxPath: 5,
        nest: false,
      );
      if (level != null) return level;
    }

    final last = tryBuild(
      rows: 30,
      cols: 30,
      mask: ovalMask(30, 30),
      seed: levelNumber + 99,
      fill: 0.97,
      arrows: minArrows,
      maxPath: 5,
      nest: false,
    );
    if (last != null) return last;
    throw lastError ??
        StateError('Failed to build dense daily (≥$minArrows) for $levelNumber');
  }

  static SolvableLevelResult _buildCampaignLevel(int levelNumber) {
    return switch (levelNumber) {
      1 => _tutorialLevel1(),
      >= 2 && <= 10 => _earlyCampaignLevel(levelNumber),
      _ => throw RangeError('Campaign only ships levels 1–10 (got $levelNumber)'),
    };
  }

  /// Progressive early campaign on fixed rectangular boards (no shape mask).
  /// Keeps historical grid sizes for L2–10; only arrows/placement change.
  static SolvableLevelResult _earlyCampaignLevel(int levelNumber) {
    final (rows, cols) = switch (levelNumber) {
      2 => (6, 6),
      3 => (6, 6),
      4 => (7, 7),
      5 => (12, 12),
      6 => (9, 9),
      7 => (10, 10),
      8 => (11, 11),
      9 => (14, 14),
      _ => (11, 11), // 10
    };

    final LevelDifficulty difficulty;
    final double fillTarget;
    final int minPath;
    final int maxPath;
    final int minArrows;
    final int maxFree;
    final int hearts;
    final int hints;
    final bool nest;

    if (levelNumber <= 5) {
      // Easy: short→mid paths, several free starts, light nesting.
      difficulty = LevelDifficulty.easy;
      fillTarget = switch (levelNumber) {
        2 || 3 => 0.82,
        4 => 0.86,
        _ => 0.84, // L5 is a large 12×12 — keep lighter than Hard
      };
      minPath = 3;
      maxPath = levelNumber <= 3 ? 7 : (levelNumber == 4 ? 8 : 9);
      minArrows = switch (levelNumber) {
        2 => 5,
        3 => 6,
        4 => 8,
        _ => 16,
      };
      maxFree = levelNumber <= 3 ? 5 : 4;
      hearts = 3;
      hints = 2;
      nest = levelNumber >= 5; // L2–4: soft; L5: light hardNest
    } else if (levelNumber <= 9) {
      // Medium: longer woven paths, 2–3 free starts, onion nesting.
      difficulty =
          levelNumber <= 7 ? LevelDifficulty.medium : LevelDifficulty.hard;
      fillTarget = 0.90 + (levelNumber - 6) * 0.01;
      minPath = 4;
      maxPath = 10 + (levelNumber - 6);
      minArrows = switch (levelNumber) {
        6 => 12,
        7 => 14,
        8 => 16,
        _ => 22,
      };
      maxFree = levelNumber <= 7 ? 3 : 2;
      hearts = 3;
      hints = 1;
      nest = true;
    } else {
      // Hard entry (L10): deep nest on same 11×11 frame.
      difficulty = LevelDifficulty.expert;
      fillTarget = 0.94;
      minPath = 4;
      maxPath = 12;
      minArrows = 18;
      maxFree = 2;
      hearts = 3;
      hints = 1;
      nest = true;
    }

    StateError? lastError;
    for (var attempt = 0; attempt < 48; attempt++) {
      try {
        return generateNestedSolvableLevel(
          levelNumber,
          rows,
          cols,
          hearts,
          hints,
          difficulty: difficulty,
          seed: levelNumber * 7919 + attempt * 131 + rows * 17,
          fillTarget: (fillTarget - (attempt > 24 ? 0.04 : 0)).clamp(0.78, 0.96),
          minPathLen: minPath,
          maxPathLen: maxPath,
          minArrows: (minArrows - (attempt ~/ 10) * 2).clamp(4, minArrows),
          hardNest: nest,
          mixPathSizes: nest,
          maxFreeAtStart: maxFree + (attempt ~/ 8),
        );
      } on StateError catch (e) {
        lastError = e;
      }
    }

    // Soft last resort — same grid size; drop free-cap gate so level always builds.
    try {
      return generateNestedSolvableLevel(
        levelNumber,
        rows,
        cols,
        hearts,
        hints,
        difficulty: difficulty,
        seed: levelNumber * 4243,
        fillTarget: 0.78,
        minPathLen: 2,
        maxPathLen: maxPath,
        minArrows: max(4, minArrows ~/ 2),
        hardNest: nest,
        mixPathSizes: true,
        maxFreeAtStart: null,
      );
    } on StateError catch (e) {
      throw lastError ?? e;
    }
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
