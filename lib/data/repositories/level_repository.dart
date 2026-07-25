import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart' show compute, kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:arrow_drift/data/models/arrow_model.dart';
import 'package:arrow_drift/data/models/level_model.dart';
import 'package:arrow_drift/data/repositories/shape_masks.dart';
import 'package:arrow_drift/features/gameplay/game_controller.dart';

/// Top-level entry point for `compute()` — must be a top-level or static
/// function (not a closure) so it can be sent to a background isolate.
/// Unpacks the (day, levelNumber) record and delegates to the repository's
/// static daily-challenge builder.
LevelModel _dailyChallengeIsolateEntry((DateTime, int) args) {
  return LevelRepository._buildDailyChallengeLevel(args.$1, args.$2);
}

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
  /// Multiplier on hardNest turn/contact/cup-wrap scoring — pushes harder
  /// toward multi-bend U/C hooks for the densest late-campaign levels.
  /// 1.0 = existing behavior; only raise for L16+ so L1–15 feel is untouched.
  double turnBias = 1.0,
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
          score += (turns * 7 * turnBias).round();
          if (turns >= 2) {
            score += (10 * turnBias).round(); // real hook / zigzag, not a single L
          }
          if (turns >= 3) score += (6 * turnBias).round();
          if (path.length >= 5 && turns == 0) score -= 14;

          // Nest against neighbors — floating separated snakes score poorly.
          final contacts = nestContactScore(path);
          score += (contacts * 6 * turnBias).round();
          if (arrows.isNotEmpty && contacts == 0) score -= 28;
          if (contacts >= 3) score += (10 * turnBias).round();
          if (contacts >= 5) score += (6 * turnBias).round();

          // Occupied cells cupped in bend pockets (hooks around neighbors).
          score += (_cupWrapBonus(path, occupied) * 5 * turnBias).round();
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
      // midLow must not exceed maxPathLen (short-path dense packs use max≤3).
      final midLow = min(4, maxPathLen);
      final mid =
          ((minPathLen + maxPathLen) / 2).round().clamp(midLow, maxPathLen);
      final lo = (mid - 1).clamp(midLow, maxPathLen);
      final hi = (mid + 2).clamp(midLow, maxPathLen);
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
      // Straight seal: long first (5 cells), then short (3 cells) to densify.
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
      for (var tipIndex = 2; tipIndex <= cells.length - 3; tipIndex++) {
        final (tr, tc) = cells[tipIndex];
        if (!escapeClear(tr, tc, free.direction)) continue;
        final segment = cells.sublist(tipIndex - 2, tipIndex + 1);
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
            targetLen: max(3, min(maxPathLen, max(minPathLen, 6))),
            minLen: 3,
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
    // Random fallback (capped — long searches freeze the UI isolate).
    for (var attempt = 0; attempt < 400 && !keeperOk; attempt++) {
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
    while (arrows.length < max(minArrows, 15) && underArrowCap() && safety < 2500) {
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
        if (stall > 200) break;
      } else {
        stall = 0;
      }
    }

    // Densify with seal-only placements (never open a second free tip).
    safety = 0;
    stall = 0;
    while (occupied.length < targetCells && underArrowCap() && safety < 2500) {
      safety++;
      final before = occupied.length;
      if (!tryForceSealPlacement()) {
        tryRetractAFreeTip();
        tryForceSealPlacement();
      }
      if (occupied.length == before) {
        stall++;
        if (stall > 250) break;
      } else {
        stall = 0;
      }
    }
  } else {
  // Phase 1: woven snakes — tips biased into nesting pockets.
  var safety = 0;
  var stall = 0;
  while (occupied.length < targetCells && underArrowCap() && safety < 2000) {
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
      if (stall > 150) break;
    } else {
      stall = 0;
    }
  }

  // Phase 2: mop up — keep size mix; fill gaps tightly for daily.
  safety = 0;
  stall = 0;
  while (occupied.length < targetCells && underArrowCap() && safety < 1200) {
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
      if (stall > 120) break;
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
    while (live.any((a) => !a.isRemoved) && clearSafety < 800) {
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

/// Campaign levels 1–20. Daily / endless helpers stay separate.
class LevelRepository {
  LevelRepository({List<SolvableLevelResult>? prebuilt})
      : _prebuilt = prebuilt,
        _lazy = List<SolvableLevelResult?>.filled(campaignLevelCount, null);

  final List<SolvableLevelResult>? _prebuilt;
  final List<SolvableLevelResult?> _lazy;
  final Map<int, LevelModel> _dailyCache = {};
  /// Prevents duplicate concurrent generation of the same level (prefetch + open).
  final Map<int, Future<LevelModel>> _inflightCampaign = {};
  final Map<int, Future<LevelModel>> _inflightDaily = {};

  /// Campaign pack size. Boards are formula-driven, lazy, and cached — going
  /// from 500 to 1000 is a one-constant change plus late-tier arrow bands
  /// (see `_densePuzzleLevel`). No level is ever built eagerly: `_lazy` is
  /// just null slots (a few KB) until a level is actually opened, so this
  /// doesn't add startup cost or memory pressure.
  static const int campaignLevelCount = 1000;

  SolvableLevelResult _resultAt(int index) {
    if (index < 0 || index >= campaignLevelCount) {
      throw RangeError('No campaign level at index $index');
    }
    if (_prebuilt != null) return _prebuilt![index];
    return _lazy[index] ??= _buildCampaignLevel(index + 1);
  }

  /// Prefer [getLevel] — ships [campaignLevelCount] campaign levels.
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

  /// Async campaign level fetch. Runs generation on a background isolate
  /// via [compute] so boards with up to ~200 arrows (Hard/Expert tiers)
  /// never block the UI thread / trigger an ANR. If the level was already
  /// generated (cached in [_lazy]), returns instantly with no isolate hop.
  /// Callers that already hold a warm cache (e.g. [getLevel] called after
  /// this resolves once) keep working exactly as before — this is purely
  /// an additive, non-blocking entry point.
  Future<LevelModel> getLevelAsync(int levelNumber) async {
    final key = levelNumber < 1 ? 1 : levelNumber;
    final clamped = key > campaignLevelCount ? campaignLevelCount : key;
    final index = clamped - 1;
    if (_prebuilt != null) return _prebuilt![index].level;
    final cached = _lazy[index];
    if (cached != null) return cached.level;
    final inflight = _inflightCampaign[clamped];
    if (inflight != null) return inflight;

    final future = _generateCampaignAsync(clamped, index);
    _inflightCampaign[clamped] = future;
    try {
      return await future;
    } finally {
      _inflightCampaign.remove(clamped);
    }
  }

  Future<LevelModel> _generateCampaignAsync(int clamped, int index) async {
    // Easy/Medium (≤20) and web: build on this isolate — faster than Worker/
    // isolate cold-start. Hard/Expert stay on a background isolate so the UI
    // thread never freezes on 70–200+ arrow packs.
    final SolvableLevelResult result;
    if (kIsWeb || clamped <= 20) {
      await Future<void>.delayed(Duration.zero);
      result = _buildCampaignLevel(clamped);
    } else {
      result = await compute(_buildCampaignLevel, clamped);
    }
    _lazy[index] = result;
    return result.level;
  }

  /// Prefetch one or more campaign levels into [_lazy] without blocking UI.
  void prefetchLevels(Iterable<int> levelNumbers) {
    for (final levelNumber in levelNumbers) {
      final key = levelNumber < 1 ? 1 : levelNumber;
      final clamped = key > campaignLevelCount ? campaignLevelCount : key;
      final index = clamped - 1;
      if (_prebuilt != null || _lazy[index] != null) continue;
      unawaited(getLevelAsync(clamped));
    }
  }

  /// Async daily-challenge fetch — same background-isolate treatment as
  /// [getLevelAsync], since daily boards are the heaviest generation case
  /// (~120-150 arrows, many retry passes).
  Future<LevelModel> getDailyLevelAsync([DateTime? date]) async {
    final day = date ?? DateTime.now();
    final levelNumber =
        900000000 + day.year * 10000 + day.month * 100 + day.day;
    final cached = _dailyCache[levelNumber];
    if (cached != null) return cached;
    final inflight = _inflightDaily[levelNumber];
    if (inflight != null) return inflight;

    final future = () async {
      // Yield so the Daily loader can paint before heavy work starts.
      // Without this, the first frame after date-tap stays frozen on the
      // calendar (compute on web often runs on the UI isolate).
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(const Duration(milliseconds: 32));

      final LevelModel level;
      if (kIsWeb) {
        // Web: compute() typically shares the UI isolate — still heavy, but
        // the loader is already on screen. Android uses a real isolate.
        level = _dailyChallengeIsolateEntry((day, levelNumber));
      } else {
        level =
            await compute(_dailyChallengeIsolateEntry, (day, levelNumber));
      }
      _dailyCache[levelNumber] = level;
      return level;
    }();
    _inflightDaily[levelNumber] = future;
    try {
      return await future;
    } finally {
      _inflightDaily.remove(levelNumber);
    }
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

  /// L1 tutorial → L2–5 Easy → L6–20 Medium → L21–100 Hard → L101–199
  /// Hard+ → L200–500 Expert → L501–650 Expert+ → L651–800 Master →
  /// L801–1000 Grandmaster. Arrow counts ramp gently so mid-campaign stays
  /// phone-friendly and late tiers carry the density.
  static SolvableLevelResult _buildCampaignLevel(int levelNumber) {
    if (levelNumber == 1) return _tutorialLevel1();
    // Easy: L2–5, 40–50 arrows (L1 stays the fixed tutorial).
    if (levelNumber <= 5) return _easyPuzzleLevel(levelNumber);
    // Medium: L6–20, 50–80 arrows.
    if (levelNumber <= 20) return _mediumPuzzleLevel(levelNumber);
    // Hard / Hard+: L21–100 (80–100), L101–199 (100–150).
    if (levelNumber <= 199) return _hardPuzzleLevel(levelNumber);
    // Expert → Grandmaster: L200–1000 dense tiers (150–250).
    return _densePuzzleLevel(levelNumber);
  }

  // --- Shared helpers ---------------------------------------------------

  static double _lerp(num a, num b, double t) => a + (b - a) * t;

  static int _lerpRound(num a, num b, double t) => _lerp(a, b, t).round();

  /// Position of [levelNumber] within [start]..[end], clamped to 0..1.
  static double _tierT(int levelNumber, int start, int end) {
    if (end <= start) return 0;
    return ((levelNumber - start) / (end - start)).clamp(0.0, 1.0);
  }

  /// Playable cells in [mask] (or the whole grid when there is no mask).
  static int _maskCells(List<List<bool>>? mask, int rows, int cols) {
    if (mask == null) return rows * cols;
    var cells = 0;
    for (final row in mask) {
      for (final inMask in row) {
        if (inMask) cells++;
      }
    }
    return cells;
  }

  /// Path lengths that let a fixed [arrows] count actually cover [cells] at
  /// [fill] density: arrows × average length ≈ filled cells. The packer
  /// averages roughly `min + 0.4 × (max − min)`, so the window is set around
  /// the needed average instead of the midpoint. Keeps arrow counts untouched
  /// while removing the empty margin a short-path pack leaves behind.
  static (int min, int max) _pathBoundsForCoverage({
    required int arrows,
    required int cells,
    required double fill,
    int floor = 2,
    int ceiling = 16,
  }) {
    if (arrows <= 0) return (floor, ceiling);
    final need = cells * fill / arrows;
    // Packer averages closer to the low end, so bias the window upward.
    var lo = (need * 0.85).round();
    var hi = (need * 1.55).round();
    if (lo < floor) lo = floor;
    if (hi > ceiling) hi = ceiling;
    if (hi < lo + 1) hi = lo + 1;
    if (hi > ceiling) {
      hi = ceiling;
      if (lo > hi) lo = hi;
    }
    return (lo, hi);
  }

  /// Same as [_pathBoundsForCoverage] for a full square board of [side].
  static (int min, int max) _squarePathBounds({
    required int arrows,
    required int side,
    required double fill,
    int floor = 2,
    int ceiling = 16,
  }) =>
      _pathBoundsForCoverage(
        arrows: arrows,
        cells: side * side,
        fill: fill,
        floor: floor,
        ceiling: ceiling,
      );

  /// Seeded pick in [min, max] — stable per level, mixed across the band.
  static int _seededArrowTarget(int levelNumber, int min, int max) {
    if (max <= min) return min;
    return min + Random(levelNumber * 7919).nextInt(max - min + 1);
  }

  /// Smooth min→max ramp across a level band (±1 seeded jitter for variety).
  /// Used after Easy so later levels visibly densify inside each tier.
  static int _rampedArrowTarget(
    int levelNumber,
    int min,
    int max,
    int bandStart,
    int bandEnd,
  ) {
    if (max <= min) return min;
    final t = _tierT(levelNumber, bandStart, bandEnd);
    final base = _lerpRound(min, max, t).clamp(min, max);
    final jitter = Random(levelNumber * 7919).nextInt(3) - 1; // -1, 0, +1
    return (base + jitter).clamp(min, max);
  }

  /// Per-tier arrow bounds: (min, max, seeded target for [levelNumber]).
  /// L1 is tutorial (not via this helper). After Easy, targets ramp upward
  /// inside each band so complexity scales progressively with level number.
  ///
  /// | Levels     | Tier         | Arrows   |
  /// |------------|--------------|----------|
  /// | L2–5       | Easy         | 40–50    |
  /// | L6–20      | Medium       | 50–80    |
  /// | L21–100    | Hard         | 80–100   |
  /// | L101–199   | Hard+        | 100–150  |
  /// | L200–500   | Expert       | 150–180  |
  /// | L501–650   | Expert+      | 180–190  |
  /// | L651–800   | Master       | 190–210  |
  /// | L801–1000  | Grandmaster  | 210–250  |
  static (int min, int max, int target) _campaignArrowSpec(int levelNumber) {
    // Easy: keep mixed seeded variety (tutorial-adjacent).
    if (levelNumber <= 5) {
      const min = 40;
      const max = 50;
      return (min, max, _seededArrowTarget(levelNumber, min, max));
    }
    if (levelNumber <= 20) {
      const min = 50;
      const max = 80;
      return (min, max, _rampedArrowTarget(levelNumber, min, max, 6, 20));
    }
    if (levelNumber <= 100) {
      const min = 80;
      const max = 100;
      return (min, max, _rampedArrowTarget(levelNumber, min, max, 21, 100));
    }
    if (levelNumber <= 199) {
      const min = 100;
      const max = 150;
      return (min, max, _rampedArrowTarget(levelNumber, min, max, 101, 199));
    }
    if (levelNumber <= 500) {
      const min = 150;
      const max = 180;
      return (min, max, _rampedArrowTarget(levelNumber, min, max, 200, 500));
    }
    if (levelNumber <= 650) {
      const min = 180;
      const max = 190;
      return (min, max, _rampedArrowTarget(levelNumber, min, max, 501, 650));
    }
    if (levelNumber <= 800) {
      const min = 190;
      const max = 210;
      return (min, max, _rampedArrowTarget(levelNumber, min, max, 651, 800));
    }
    const min = 210;
    const max = 250;
    return (min, max, _rampedArrowTarget(levelNumber, min, max, 801, 1000));
  }

  /// Fuller shapes for Hard L21–100 — square / oct / hex / circle only so
  /// empty corner rings stay small and arrows read larger on screen.
  static List<List<bool>> _hardLowShapeFor(int offset, int size) {
    final square = List.generate(size, (_) => List<bool>.filled(size, true));
    return switch (offset % 4) {
      0 => square,
      1 => octagonMask(size, size),
      2 => hexagonMask(size, size),
      _ => circleMask(size, size),
    };
  }

  /// Convex/near-convex-only rotation — required for the exact-free-at-start
  /// seal-chain keeper placement (L21+) to stay reliable. Thin concave
  /// silhouettes are reserved for L2–20 (non-exact) and the daily path.
  static List<List<bool>> _convexShapeFor(int offset, int size) {
    final square = List.generate(size, (_) => List<bool>.filled(size, true));
    return switch (offset % 7) {
      0 => square,
      1 => octagonMask(size, size),
      2 => hexagonMask(size, size),
      3 => diamondMask(size, size),
      4 => circleMask(size, size),
      5 => ovalMask(size, size),
      _ => stadiumMask(size, size),
    };
  }

  /// L2–L5: Easy tier — distinct silhouettes per level, exact seeded
  /// arrow counts (40–50 band). Shape is preferred before any square fallback.
  static SolvableLevelResult _easyPuzzleLevel(int levelNumber) {
    final t = _tierT(levelNumber, 2, 5);
    final (tierMin, _, targetArrows) = _campaignArrowSpec(levelNumber);
    // 17–19 so 40–50 longer snakes still pack on shaped boards.
    final size = _lerpRound(17, 19, t).clamp(17, 19);
    final fillTarget = _lerp(0.90, 0.95, t);
    // Longer snakes so each arrow covers more of the board.
    final minPath = 4;
    final maxPath = _lerpRound(7, 10, t).clamp(7, 10);
    final maxFree = _lerpRound(2, 1, t).clamp(1, 2);
    final turnBias = _lerp(1.05, 1.25, t);
    const hearts = 3;
    const hints = 2;

    StateError? lastError;

    SolvableLevelResult? tryOnce({
      required int r,
      required int c,
      required List<List<bool>> m,
      required int seed,
      required int arrows,
      required double fill,
      int? freeCap,
      bool exact = false,
      int? pathCeil,
      bool mixPaths = true,
    }) {
      try {
        return generateNestedSolvableLevel(
          levelNumber,
          r,
          c,
          hearts,
          hints,
          difficulty: LevelDifficulty.easy,
          seed: seed,
          shapeMask: m,
          fillTarget: fill,
          minPathLen: minPath,
          maxPathLen: pathCeil ?? maxPath,
          minArrows: arrows,
          maxArrows: arrows,
          hardNest: true,
          mixPathSizes: mixPaths,
          maxFreeAtStart: freeCap,
          exactFreeAtStart: exact && freeCap == 1,
          turnBias: turnBias,
        );
      } on StateError catch (e) {
        lastError = e;
        return null;
      }
    }

    // Keep the per-level shape through primary retries.
    for (final grid in <int>[size, 18, 19]) {
      final shaped = _easyShapeFor(levelNumber, grid);
      for (var attempt = 0; attempt < 6; attempt++) {
        final result = tryOnce(
          r: shaped.$1,
          c: shaped.$2,
          m: shaped.$3,
          seed: levelNumber * 7919 + grid * 31 + attempt * 131,
          arrows: targetArrows,
          fill: (fillTarget - (attempt ~/ 3) * 0.02).clamp(0.88, fillTarget),
          freeCap: maxFree,
          exact: maxFree == 1,
          pathCeil: attempt > 2 ? 7 : maxPath,
          mixPaths: attempt > 3 ? false : true,
        );
        if (result != null) return result;
      }
    }

    // Same shape, looser free-cap / denser fill — still exact arrow count.
    for (final grid in <int>[17, 19]) {
      final shaped = _easyShapeFor(levelNumber, grid);
      for (var attempt = 0; attempt < 6; attempt++) {
        final result = tryOnce(
          r: shaped.$1,
          c: shaped.$2,
          m: shaped.$3,
          seed: levelNumber * 4243 + grid * 17 + attempt * 97,
          arrows: targetArrows,
          fill: (0.96 - attempt * 0.01).clamp(0.90, 0.96),
          freeCap: attempt < 2 ? 2 : null,
          pathCeil: 6,
          mixPaths: false,
        );
        if (result != null) return result;
      }
    }

    // Soft open on the shaped board (skip free-cap).
    for (final grid in <int>[17, 19]) {
      final shaped = _easyShapeFor(levelNumber, grid);
      final soft = tryOnce(
        r: shaped.$1,
        c: shaped.$2,
        m: shaped.$3,
        seed: levelNumber * 2221 + grid,
        arrows: targetArrows,
        fill: 0.95,
        freeCap: null,
        pathCeil: 6,
        mixPaths: false,
      );
      if (soft != null) return soft;
    }

    // Last ditch square — only if shaped packs fail; still exact count.
    final guaranteed = tryOnce(
      r: 19,
      c: 19,
      m: List.generate(19, (_) => List<bool>.filled(19, true)),
      seed: levelNumber * 3331,
      arrows: targetArrows,
      fill: 0.90,
      freeCap: null,
      pathCeil: 5,
      mixPaths: false,
    );
    if (guaranteed != null) return guaranteed;

    final bandFallback = tryOnce(
      r: 18,
      c: 18,
      m: List.generate(18, (_) => List<bool>.filled(18, true)),
      seed: levelNumber * 4447,
      arrows: tierMin,
      fill: 0.88,
      freeCap: null,
      mixPaths: false,
    );
    if (bandFallback != null) return bandFallback;

    throw lastError ??
        StateError('Failed to build easy puzzle level $levelNumber');
  }

  /// Distinct Easy silhouettes for L2–L5 (dense enough for 40–50 arrows).
  static (int rows, int cols, List<List<bool>> mask) _easyShapeFor(
    int levelNumber,
    int size,
  ) {
    final s = size.clamp(14, 20);
    return switch (levelNumber) {
      2 => (s, s, circleMask(s, s)),
      3 => (s, s, generateHeartShapeMask(s)),
      4 => (s, s, hexagonMask(s, s)),
      5 => (s, s, stadiumMask(s, s)),
      _ => (s, s, List.generate(s, (_) => List<bool>.filled(s, true))),
    };
  }

  /// L6–L20: Medium tier — shaped silhouettes, growing density + nesting,
  /// free-tile cap shrinks toward the end but stays non-exact (no forced
  /// single-key sequencing yet — that starts at L21). Arrow band: 50–80.
  static SolvableLevelResult _mediumPuzzleLevel(int levelNumber) {
    final t = _tierT(levelNumber, 6, 20);
    final (_, __, targetArrows) = _campaignArrowSpec(levelNumber);
    final fillTarget = _lerp(0.90, 0.96, t);
    // Keep the board close to L10's full look: square-ish grids, not oversized.
    // Late Medium (70+) gets 20–21 so longer snakes still pack without a
    // dotted ring (22×22 + short fallback was the sparse L11/L15–20 bug).
    final size = targetArrows >= 70
        ? _lerpRound(20, 21, t).clamp(20, 21)
        : _lerpRound(18, 20, t).clamp(18, 20);
    // L11+: full square only (like L10). Fancy silhouettes leave empty dots
    // around the nest even when paths are long.
    final (rows, cols, mask) = levelNumber >= 11
        ? (
            size,
            size,
            List.generate(size, (_) => List<bool>.filled(size, true)),
          )
        : _campaignShapeFor(levelNumber, size);
    // Arrow count is fixed by the tier band; coverage comes from path length.
    // Floor stays at 4 so the exact target still packs; maxPath carries the
    // extra length that fills the board (floor 5 caused L12+ to drop to
    // tierMin=50 and leave half the dots empty).
    final (minPath, maxPath) = _pathBoundsForCoverage(
      arrows: targetArrows,
      cells: _maskCells(mask, rows, cols),
      fill: fillTarget,
      floor: 4,
      ceiling: 14,
    );
    final maxFree = _lerpRound(2, 1, t).clamp(1, 2);
    final turnBias = _lerp(1.4, 1.7, t);
    // Prefer tight free-cap (1–2) without exact seal-chain: exact=1 causes
    // many failed full-board builds and multi-second loads. Hard tier keeps
    // the exact seal-chain. Arrow counts stay in the Medium band.
    const hearts = 3;
    final hints = t < 0.5 ? 2 : 1;

    StateError? lastError;

    SolvableLevelResult? tryOnce({
      required int r,
      required int c,
      required List<List<bool>> m,
      required int seed,
      required int arrows,
      required double fill,
      required int freeCap,
      int? pathFloor,
      int? pathCeil,
      double? bias,
      bool exact = false,
      int? cap,
    }) {
      try {
        return generateNestedSolvableLevel(
          levelNumber,
          r,
          c,
          hearts,
          hints,
          difficulty: LevelDifficulty.medium,
          seed: seed,
          shapeMask: m,
          fillTarget: fill,
          minPathLen: pathFloor ?? minPath,
          maxPathLen: pathCeil ?? maxPath,
          minArrows: arrows,
          maxArrows: cap ?? arrows,
          hardNest: true,
          mixPathSizes: true,
          maxFreeAtStart: freeCap,
          exactFreeAtStart: exact && freeCap == 1,
          turnBias: bias ?? turnBias,
        );
      } on StateError catch (e) {
        lastError = e;
        return null;
      }
    }

    // Fast primary: exact seeded target, tight free cap.
    for (var attempt = 0; attempt < 8; attempt++) {
      final result = tryOnce(
        r: rows,
        c: cols,
        m: mask,
        seed: levelNumber * 9973 + attempt * 173 + size * 19,
        arrows: targetArrows,
        fill: (fillTarget - (attempt ~/ 3) * 0.02).clamp(0.84, fillTarget),
        freeCap: (maxFree + attempt ~/ 3).clamp(maxFree, 3),
        pathFloor: minPath,
      );
      if (result != null) return result;
    }

    // Optional nicer seal if it lands quickly.
    for (var attempt = 0; attempt < 2; attempt++) {
      final result = tryOnce(
        r: rows,
        c: cols,
        m: mask,
        seed: levelNumber * 7919 + attempt * 211,
        arrows: targetArrows,
        fill: fillTarget,
        freeCap: 1,
        exact: true,
        pathFloor: minPath,
      );
      if (result != null) return result;
    }

    // Full-square fallbacks keep coverage-derived lengths. Never drop to
    // stub paths on a large board — that is what left L11/L15–20 half empty.
    final fb = size;
    final fbMask = List.generate(fb, (_) => List<bool>.filled(fb, true));
    final (fbFloor, fbCeil) = _squarePathBounds(
      arrows: targetArrows,
      side: fb,
      fill: 0.90,
      floor: 4,
      ceiling: 14,
    );
    for (var attempt = 0; attempt < 6; attempt++) {
      final result = tryOnce(
        r: fb,
        c: fb,
        m: fbMask,
        seed: levelNumber * 4243 + attempt * 97,
        arrows: targetArrows,
        fill: (0.90 - (attempt ~/ 2) * 0.02).clamp(0.84, 0.90),
        freeCap: (maxFree + 1 + attempt ~/ 2).clamp(maxFree, 6),
        pathFloor: fbFloor,
        pathCeil: fbCeil,
        bias: 1.2,
      );
      if (result != null) return result;
    }

    // Soft open: same grid + long paths, free-cap relaxed.
    for (var attempt = 0; attempt < 4; attempt++) {
      final result = tryOnce(
        r: fb,
        c: fb,
        m: fbMask,
        seed: levelNumber * 1117 + attempt * 53,
        arrows: targetArrows,
        fill: (0.88 - (attempt ~/ 2) * 0.02).clamp(0.82, 0.88),
        freeCap: 8,
        pathFloor: fbFloor,
        pathCeil: fbCeil,
        bias: 1.1,
      );
      if (result != null) return result;
    }

    // Guaranteed: skip free-cap, keep coverage lengths + exact target.
    // Never drop to tierMin on this grid — that left L12–20 half empty.
    for (var attempt = 0; attempt < 10; attempt++) {
      final result = tryOnce(
        r: fb,
        c: fb,
        m: fbMask,
        seed: levelNumber * 5557 + attempt * 19,
        arrows: targetArrows,
        fill: (0.92 - attempt * 0.01).clamp(0.82, 0.92),
        freeCap: 99,
        pathFloor: (fbFloor - attempt ~/ 3).clamp(3, 14),
        pathCeil: fbCeil,
        bias: 1.0,
      );
      if (result != null) return result;
    }

    try {
      return generateNestedSolvableLevel(
        levelNumber,
        fb,
        fb,
        hearts,
        hints,
        difficulty: LevelDifficulty.medium,
        seed: levelNumber * 5557,
        shapeMask: fbMask,
        fillTarget: 0.90,
        minPathLen: 4,
        maxPathLen: fbCeil,
        minArrows: targetArrows,
        maxArrows: targetArrows,
        hardNest: true,
        mixPathSizes: true,
        maxFreeAtStart: null,
        turnBias: 1.0,
      );
    } on StateError catch (e) {
      lastError = e;
    }

    // Absolute last: still exact target; allow slightly shorter snakes so the
    // level opens, but cap the grid so remaining cells stay few.
    final rescueSide = _lerpRound(16, 18, t).clamp(16, 18);
    final (rescueLo, rescueHi) = _squarePathBounds(
      arrows: targetArrows,
      side: rescueSide,
      fill: 0.90,
      floor: 3,
      ceiling: 12,
    );
    try {
      return generateNestedSolvableLevel(
        levelNumber,
        rescueSide,
        rescueSide,
        hearts,
        hints,
        difficulty: LevelDifficulty.medium,
        seed: levelNumber * 6661,
        shapeMask: List.generate(
          rescueSide,
          (_) => List<bool>.filled(rescueSide, true),
        ),
        fillTarget: 0.88,
        minPathLen: rescueLo,
        maxPathLen: rescueHi,
        minArrows: targetArrows,
        maxArrows: targetArrows,
        hardNest: true,
        mixPathSizes: true,
        maxFreeAtStart: null,
        turnBias: 1.0,
      );
    } on StateError catch (e) {
      lastError = e;
    }

    throw lastError ??
        StateError('Failed to build medium puzzle level $levelNumber');
  }

  /// L21–L199: Hard / Hard+ — arrow target ramps inside each band.
  /// Structural difficulty also ramps (fill / free-cap / turnBias / hints).
  static SolvableLevelResult _hardPuzzleLevel(int levelNumber) {
    final lowHard = levelNumber <= 100;
    final (tierMin, _, targetArrows) = _campaignArrowSpec(levelNumber);
    final difficulty =
        lowHard ? LevelDifficulty.hard : LevelDifficulty.hardPlus;
    final t = _tierT(levelNumber, 21, 199);
    final fillTarget = _lerp(0.94, 0.98, t);
    // Grid sized so exact arrow targets still pack without crashing.
    final size = targetArrows <= 90
        ? 22
        : targetArrows <= 100
            ? 23
            : targetArrows <= 120
                ? 24
                : targetArrows <= 140
                    ? 26
                    : 28;
    // L21–100: fuller silhouettes only (no thin diamond/oval/stadium) so
    // the playable nest reaches nearer the board edges.
    final mask = lowHard
        ? _hardLowShapeFor(levelNumber - 21, size)
        : _convexShapeFor(levelNumber - 21, size);
    // Arrow count is band-fixed, so path length carries the coverage: the pack
    // is stretched to eat the cells instead of leaving a dotted ring.
    final (minPath, maxPath) = _pathBoundsForCoverage(
      arrows: targetArrows,
      cells: _maskCells(mask, size, size),
      fill: fillTarget,
      floor: 4,
      ceiling: 12,
    );
    final turnBias = _lerp(1.55, 2.35, t);
    const hearts = 3;
    final hints = t < 0.65 ? 2 : 1;
    final preferExact = t >= 0.55;
    final primaryFree = t < 0.35 ? 2 : 1;

    StateError? lastError;

    SolvableLevelResult? tryOnce({
      required int r,
      required int c,
      required List<List<bool>> m,
      required int seed,
      required int arrows,
      required double fill,
      required int pathFloor,
      int? freeCap,
      bool exact = false,
      double bias = 1.0,
      int? pathCeil,
    }) {
      try {
        return generateNestedSolvableLevel(
          levelNumber,
          r,
          c,
          hearts,
          hints,
          difficulty: difficulty,
          seed: seed,
          shapeMask: m,
          fillTarget: fill,
          minPathLen: pathFloor,
          maxPathLen: pathCeil ?? maxPath,
          minArrows: arrows,
          maxArrows: arrows,
          hardNest: true,
          mixPathSizes: true,
          maxFreeAtStart: freeCap,
          exactFreeAtStart: exact,
          turnBias: bias,
        );
      } on StateError catch (e) {
        lastError = e;
        return null;
      }
    }

    // Prefer exact target; tighten free-cap as the Hard band progresses.
    for (var attempt = 0; attempt < 8; attempt++) {
      final result = tryOnce(
        r: size,
        c: size,
        m: mask,
        seed: levelNumber * 9973 + 5000 + attempt * 173 + size * 19,
        arrows: targetArrows,
        fill: (fillTarget - (attempt ~/ 4) * 0.02).clamp(0.90, fillTarget),
        pathFloor: minPath,
        freeCap: (primaryFree + attempt ~/ 4).clamp(primaryFree, 2),
        exact: preferExact && attempt == 0 && primaryFree == 1,
        bias: turnBias,
      );
      if (result != null) return result;
    }

    for (var attempt = 0; attempt < 3; attempt++) {
      final result = tryOnce(
        r: size,
        c: size,
        m: mask,
        seed: levelNumber * 9973 + attempt * 173 + size * 19,
        arrows: targetArrows,
        fill: fillTarget,
        pathFloor: minPath,
        freeCap: 1,
        exact: true,
        bias: turnBias,
      );
      if (result != null) return result;
    }

    // Dense square packs — exact target, lengths fitted to each grid so a
    // fallback board is still covered edge to edge. Prefer the primary size
    // first; only grow the board if that fails (still with long paths).
    for (final grid in <int>[size, (size + 1).clamp(size, 28)]) {
      final square = List.generate(grid, (_) => List<bool>.filled(grid, true));
      final (packFloor, packCeil) = _squarePathBounds(
        arrows: targetArrows,
        side: grid,
        fill: 0.94,
        floor: 4,
        ceiling: 12,
      );
      for (var attempt = 0; attempt < 5; attempt++) {
        final result = tryOnce(
          r: grid,
          c: grid,
          m: square,
          seed: levelNumber * 4243 + grid * 17 + attempt * 97,
          arrows: targetArrows,
          fill: (0.97 - attempt * 0.01).clamp(0.90, 0.97),
          pathFloor: (packFloor - attempt ~/ 2).clamp(3, 12),
          pathCeil: packCeil,
          freeCap: attempt < 3 ? 2 : null,
          bias: 1.2,
        );
        if (result != null) return result;
      }
    }

    // Guaranteed exact target: coverage lengths, no free-cap.
    final (lastFloor, lastCeil) = _squarePathBounds(
      arrows: targetArrows,
      side: size,
      fill: 0.92,
      floor: 4,
      ceiling: 12,
    );
    final lastSquare =
        List.generate(size, (_) => List<bool>.filled(size, true));
    final last = tryOnce(
      r: size,
      c: size,
      m: lastSquare,
      seed: levelNumber * 99991,
      arrows: targetArrows,
      fill: 0.95,
      pathFloor: lastFloor,
      pathCeil: lastCeil,
      freeCap: null,
      bias: 1.0,
    );
    if (last != null) return last;

    // Should be unreachable; keep app from crashing — still coverage lengths.
    final (floorLo, floorHi) = _squarePathBounds(
      arrows: tierMin,
      side: size,
      fill: 0.90,
      floor: 3,
      ceiling: 12,
    );
    final floor = tryOnce(
      r: size,
      c: size,
      m: lastSquare,
      seed: levelNumber * 88883,
      arrows: tierMin,
      fill: 0.90,
      pathFloor: floorLo,
      pathCeil: floorHi,
      freeCap: null,
      bias: 1.0,
    );
    if (floor != null) return floor;

    // Emergency open for rare late Hard+ seeds (e.g. L186/L195) where a thin
    // silhouette + long-path floor can't hit the arrow target. Full square +
    // shorter snakes; arrow count stays in-band. Does not change primary packs.
    for (final grid in <int>[size, 30]) {
      final square = List.generate(grid, (_) => List<bool>.filled(grid, true));
      for (final count in <int>[targetArrows, tierMin]) {
        for (var attempt = 0; attempt < 8; attempt++) {
          final result = tryOnce(
            r: grid,
            c: grid,
            m: square,
            seed: levelNumber * 77777 + count * 13 + grid * 7 + attempt,
            arrows: count,
            fill: (0.95 - attempt * 0.01).clamp(0.85, 0.95),
            pathFloor: 2,
            pathCeil: attempt < 4 ? 5 : 4,
            freeCap: null,
            bias: 1.0,
          );
          if (result != null) return result;
        }
      }
    }

    throw lastError ??
        StateError('Failed to build hard puzzle level $levelNumber');
  }

  /// Meta for L200–1000 dense tiers: difficulty chip + ramped heart/hint budget.
  static (LevelDifficulty difficulty, int hearts, int hints) _denseTierMeta(
    int levelNumber,
  ) {
    final t = _tierT(levelNumber, 200, 1000);
    final hearts = t < 0.55 ? 3 : 2;
    final hints = t < 0.35 ? 2 : 1;
    if (levelNumber <= 500) {
      return (LevelDifficulty.expert, hearts, hints);
    }
    if (levelNumber <= 650) {
      return (LevelDifficulty.expertPlus, hearts, hints);
    }
    if (levelNumber <= 800) {
      return (LevelDifficulty.master, hearts, hints.clamp(1, 1));
    }
    return (LevelDifficulty.grandmaster, hearts.clamp(2, 2), 1);
  }

  /// High-capacity shapes only (skip thin oval/stadium/diamond) so dense
  /// targets (≥210) pack without burning failed shaped attempts.
  static List<List<bool>> _denseShapeFor(int offset, int size, int arrows) {
    if (arrows < 210) return _convexShapeFor(offset, size);
    final square = List.generate(size, (_) => List<bool>.filled(size, true));
    return switch (offset % 4) {
      0 => square,
      1 => octagonMask(size, size),
      2 => hexagonMask(size, size),
      _ => circleMask(size, size),
    };
  }

  /// L200–L1000: Expert → Grandmaster. Arrow counts ramp inside each band;
  /// fill / free-cap / turnBias tighten progressively. Always nested polylines.
  static SolvableLevelResult _densePuzzleLevel(int levelNumber) {
    final (tierMin, _, targetArrows) = _campaignArrowSpec(levelNumber);
    final (difficulty, hearts, hints) = _denseTierMeta(levelNumber);
    final t = _tierT(levelNumber, 200, 1000);
    final isLateDense = t >= 0.7; // ~L760+
    final fillTarget = _lerp(0.94, 0.98, t);
    final size = 30;
    final mask = isLateDense || targetArrows >= 210
        ? List.generate(size, (_) => List<bool>.filled(size, true))
        : _denseShapeFor(levelNumber - 200, size, targetArrows);
    // Lengths follow the board, not the other way round: the fixed arrow count
    // is stretched over the cells so dense boards stay covered.
    final (minPath, maxPath) = _pathBoundsForCoverage(
      arrows: targetArrows,
      cells: _maskCells(mask, size, size),
      fill: fillTarget,
      floor: 2,
      ceiling: 10,
    );
    final turnBias = _lerp(1.9, 2.65, t);
    final primaryFree = t < 0.4 ? 2 : 1;
    final preferExact = t >= 0.75;

    StateError? lastError;

    SolvableLevelResult? tryOnce({
      required List<List<bool>> m,
      required int seed,
      required int arrows,
      required double fill,
      required int pathFloor,
      int? freeCap,
      bool exact = false,
      double bias = 1.0,
      int? gridSize,
      int? pathCeil,
      bool mixPaths = true,
      bool nest = true,
    }) {
      final grid = gridSize ?? size;
      final ceil = (pathCeil ?? maxPath).clamp(pathFloor, 20);
      try {
        return generateNestedSolvableLevel(
          levelNumber,
          grid,
          grid,
          hearts,
          hints,
          difficulty: difficulty,
          seed: seed,
          shapeMask: m,
          fillTarget: fill,
          minPathLen: pathFloor,
          maxPathLen: ceil,
          minArrows: arrows,
          maxArrows: arrows,
          hardNest: nest,
          mixPathSizes: mixPaths,
          maxFreeAtStart: freeCap,
          exactFreeAtStart: exact,
          turnBias: bias,
        );
      } on StateError catch (e) {
        lastError = e;
        return null;
      }
    }

    // Primary: nested pack at ramped target; free-cap tightens with t.
    // Late dense skips long shaped attempts — short square packs are reliable
    // and keep the UI from hanging on L800–1000 opens.
    if (!isLateDense) {
      for (var attempt = 0; attempt < 10; attempt++) {
        final result = tryOnce(
          m: mask,
          seed: levelNumber * 15013 + 7000 + attempt * 251 + size * 31,
          arrows: targetArrows,
          fill: (fillTarget - (attempt ~/ 4) * 0.02).clamp(0.90, fillTarget),
          pathFloor: minPath,
          freeCap: (primaryFree + attempt ~/ 4).clamp(primaryFree, 2),
          exact: preferExact && attempt == 0 && primaryFree == 1,
          bias: turnBias,
          mixPaths: true,
          pathCeil: maxPath,
          nest: true,
        );
        if (result != null) return result;
      }

      for (var attempt = 0; attempt < 3; attempt++) {
        final result = tryOnce(
          m: mask,
          seed: levelNumber * 15013 + attempt * 251 + size * 31,
          arrows: targetArrows,
          fill: fillTarget,
          pathFloor: minPath,
          freeCap: 1,
          exact: true,
          bias: turnBias,
          mixPaths: true,
        );
        if (result != null) return result;
      }
    }

    // Square nested packs — keep the full 30×30 board but stretch lengths to
    // cover it, only shortening them as attempts run out.
    final square = List.generate(30, (_) => List<bool>.filled(30, true));
    final (fbFloor, fbCeil) = _squarePathBounds(
      arrows: targetArrows,
      side: 30,
      fill: 0.94,
      floor: 2,
      ceiling: 10,
    );
    for (var attempt = 0; attempt < (isLateDense ? 16 : 12); attempt++) {
      final result = tryOnce(
        m: square,
        seed: levelNumber * 4243 + 30 * 17 + attempt * 97,
        arrows: targetArrows,
        fill: (0.98 - attempt * 0.01).clamp(0.88, 0.98),
        pathFloor: (fbFloor - attempt ~/ 3).clamp(2, 10),
        pathCeil: attempt < 6 ? fbCeil : (fbCeil - 1).clamp(3, 10),
        freeCap: isLateDense
            ? (attempt < 2 ? 1 : null)
            : (attempt < 2 ? 2 : null),
        exact: isLateDense && attempt == 0,
        gridSize: 30,
        bias: isLateDense ? turnBias : 1.1,
        mixPaths: false,
        nest: true,
      );
      if (result != null) return result;
    }

    // Tier floor, still nested polylines (never tip-only).
    final (floorLo, floorHi) = _squarePathBounds(
      arrows: tierMin,
      side: 30,
      fill: 0.92,
      floor: 2,
      ceiling: 10,
    );
    for (var attempt = 0; attempt < 10; attempt++) {
      final result = tryOnce(
        m: square,
        seed: levelNumber * 88883 + attempt * 17,
        arrows: tierMin,
        fill: (0.95 - attempt * 0.01).clamp(0.85, 0.95),
        pathFloor: (floorLo - attempt ~/ 3).clamp(2, 10),
        pathCeil: floorHi,
        freeCap: null,
        gridSize: 30,
        bias: 1.0,
        mixPaths: false,
        nest: true,
      );
      if (result != null) return result;
    }

    for (final count in <int>[targetArrows, tierMin]) {
      final (lo, hi) = _squarePathBounds(
        arrows: count,
        side: 30,
        fill: 0.88,
        floor: 2,
        ceiling: 10,
      );
      for (var attempt = 0; attempt < 6; attempt++) {
        final result = tryOnce(
          m: square,
          seed: levelNumber * 77777 + count * 13 + attempt,
          arrows: count,
          fill: 0.90,
          pathFloor: attempt < 3 ? lo : 2,
          pathCeil: hi,
          freeCap: null,
          gridSize: 30,
          bias: 1.0,
          mixPaths: true,
          nest: true,
        );
        if (result != null) return result;
      }
    }

    throw lastError ??
        StateError('Failed to build dense puzzle level $levelNumber');
  }

  /// Shape rotation for L2+: 29-shape cycle (heart, diamond, oval, star,
  /// octagon, circle, hexagon, stadium, clover, ring, thick ring, hourglass,
  /// crescent, plus, shield, flower, infinity, both triangles, fish,
  /// butterfly, bird, cat — plus square "breathing room" slots), used by
  /// the L2–6 Easy and L7–20 Medium tiers. L21+ uses [_convexShapeFor]
  /// instead (seal-chain reliability constraint).
  static (int rows, int cols, List<List<bool>> mask) _campaignShapeFor(
    int levelNumber,
    int size,
  ) {
    final s = size.clamp(6, 22);
    List<List<bool>> full() =>
        List.generate(s, (_) => List<bool>.filled(s, true));

    final slot = (levelNumber - 2) % 29;
    return switch (slot) {
      0 => (s, s, generateHeartShapeMask(s)),
      1 => (s, s, full()),
      2 => (s, s, diamondMask(s, s)),
      3 => (s, s, ovalMask(s, s)),
      4 => (s, s, starMask(s, s)),
      5 => (s, s, octagonMask(s, s)),
      6 => (s, s, full()),
      7 => (s, s, circleMask(s, s)),
      8 => (s, s, hexagonMask(s, s)),
      9 => (s, s, stadiumMask(s, s)),
      10 => (s, s, full()),
      11 => (s, s, cloverMask(s, s)),
      12 => (s, s, ringMask(s, s)),
      13 => (s, s, thickRingMask(s, s)),
      14 => (s, s, full()),
      15 => (s, s, hourglassMask(s, s)),
      16 => (s, s, crescentMask(s, s)),
      17 => (s, s, plusMask(s, s)),
      18 => (s, s, full()),
      19 => (s, s, shieldMask(s, s)),
      20 => (s, s, flowerMask(s, s)),
      21 => (s, s, infinityMask(s, s)),
      22 => (s, s, full()),
      23 => (s, s, uprightTriangleMask(s, s)),
      24 => (s, s, invertedTriangleMask(s, s)),
      25 => (s, s, fishMask(s, s)),
      26 => (s, s, butterflyMask(s, s)),
      27 => (s, s, birdOutlineMask(s, s)),
      _ => (s, s, catFaceMask(s, s)),
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


}

final _sharedLevelRepository = LevelRepository();

final levelRepositoryProvider = Provider<LevelRepository>((ref) {
  return _sharedLevelRepository;
});

final levelsRepositoryProvider = levelRepositoryProvider;

final levelByNumberProvider = Provider.family<LevelModel, int>((ref, levelNumber) {
  return ref.watch(levelRepositoryProvider).getLevel(levelNumber);
});

/// Async counterpart to [levelByNumberProvider] — generation runs on a
/// background isolate (see `LevelRepository.getLevelAsync`), so the UI can
/// show a loading state instead of freezing while a 70-200+ arrow board is
/// built. Once this resolves, the level is cached on the repo, so any
/// later sync read via [levelByNumberProvider] / `getLevel` for the same
/// level number is instant.
final levelByNumberAsyncProvider =
    FutureProvider.family<LevelModel, int>((ref, levelNumber) {
  return ref.watch(levelRepositoryProvider).getLevelAsync(levelNumber);
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

/// Async counterpart to [dailyLevelForDateProvider] — same background-
/// isolate treatment, since daily boards are the heaviest generation case.
final dailyLevelForDateAsyncProvider =
    FutureProvider.family<LevelModel, String>((ref, dateKey) {
  final parts = dateKey.split('-');
  final date = DateTime(
    int.parse(parts[0]),
    int.parse(parts[1]),
    int.parse(parts[2]),
  );
  return ref.watch(levelRepositoryProvider).getDailyLevelAsync(date);
});

String dailyDateKey(DateTime date) {
  final y = date.year.toString().padLeft(4, '0');
  final m = date.month.toString().padLeft(2, '0');
  final d = date.day.toString().padLeft(2, '0');
  return '$y-$m-$d';
}
