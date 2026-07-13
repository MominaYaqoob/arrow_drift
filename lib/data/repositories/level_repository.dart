import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:arrow_drift/data/models/arrow_model.dart';
import 'package:arrow_drift/data/models/level_model.dart';
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
}) {
  final random = Random(
    seed ?? levelNumber * 9973 + rows * 131 + cols * 17,
  );
  final occupied = <String>{};
  final arrows = <ArrowModel>[];
  final placementOrder = <String>[];
  final targetCells = (rows * cols * fillTarget).floor();

  String cellKey(int r, int c) => '$r:$c';

  bool inBounds(int r, int c) =>
      r >= 0 && c >= 0 && r < rows && c < cols;

  bool isEmpty(int r, int c) =>
      inBounds(r, c) && !occupied.contains(cellKey(r, c));

  /// Escape ray clear using the live occupied set (O(grid) — not O(all paths)).
  bool escapeClear(int tipR, int tipC, ArrowDirection direction) {
    final (dr, dc) = _dirDelta(direction);
    var r = tipR + dr;
    var c = tipC + dc;
    while (inBounds(r, c)) {
      if (occupied.contains(cellKey(r, c))) return false;
      r += dr;
      c += dc;
    }
    return true;
  }

  /// Grow tail←tip so the last step into the tip matches [direction].
  List<GridCell>? growPath({
    required int tipR,
    required int tipC,
    required ArrowDirection direction,
    required int targetLen,
    required int minLen,
  }) {
    if (targetLen <= 1) {
      return [GridCell(tipR, tipC)];
    }

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

    while (rev.length < targetLen) {
      // Weighted picks without building a big list every step.
      final candidates = <(int, int, int, int)>[];
      void consider(int ndr, int ndc) {
        final nr = r + ndr;
        final nc = c + ndc;
        final k = cellKey(nr, nc);
        if (!inBounds(nr, nc) ||
            occupied.contains(k) ||
            used.contains(k)) {
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
      } else {
        // ~70% prefer straight if present.
        final straight = candidates.first;
        final isStraight =
            straight.$3 == growDr && straight.$4 == growDc;
        if (isStraight && random.nextDouble() < 0.7) {
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

    if (rev.length < minLen) return null;
    return rev.reversed.toList(growable: false);
  }

  void placeArrow(ArrowModel arrow) {
    arrows.add(arrow);
    placementOrder.add(arrow.id);
    for (final cell in arrow.path) {
      occupied.add(cellKey(cell.row, cell.col));
    }
  }

  bool tryPlaceAt({
    required int tipR,
    required int tipC,
    required int targetLen,
    required int minLen,
  }) {
    if (!isEmpty(tipR, tipC)) return false;
    final dirs = ArrowDirection.values.toList(growable: false);
    // Rotate start dir instead of full shuffle alloc each call.
    final start = random.nextInt(dirs.length);
    for (var i = 0; i < dirs.length; i++) {
      final direction = dirs[(start + i) % dirs.length];
      if (!escapeClear(tipR, tipC, direction)) continue;

      final path = growPath(
        tipR: tipR,
        tipC: tipC,
        direction: direction,
        targetLen: targetLen,
        minLen: minLen,
      );
      if (path == null) continue;

      placeArrow(
        ArrowModel(
          id: '$levelNumber-${arrows.length}',
          row: tipR,
          col: tipC,
          direction: direction,
          path: path,
        ),
      );
      return true;
    }
    return false;
  }

  // Phase 1: long woven snakes (hard cap keeps UI responsive).
  var safety = 0;
  var stall = 0;
  while (occupied.length < targetCells && safety < 4000) {
    safety++;
    final before = occupied.length;
    final tipR = random.nextInt(rows);
    final tipC = random.nextInt(cols);
    final len = minPathLen + random.nextInt(maxPathLen - minPathLen + 1);
    tryPlaceAt(tipR: tipR, tipC: tipC, targetLen: len, minLen: minPathLen);
    if (occupied.length == before) {
      stall++;
      if (stall > 400) break;
    } else {
      stall = 0;
    }
  }

  // Phase 2: mop up with short polylines / singles.
  safety = 0;
  stall = 0;
  while (occupied.length < targetCells && safety < 2500) {
    safety++;
    final before = occupied.length;
    final tipR = random.nextInt(rows);
    final tipC = random.nextInt(cols);
    final len = 1 + random.nextInt(3);
    tryPlaceAt(tipR: tipR, tipC: tipC, targetLen: len, minLen: 1);
    if (occupied.length == before) {
      stall++;
      if (stall > 300) break;
    } else {
      stall = 0;
    }
  }

  // Phase 3: scan leftovers once (no heavy retries).
  for (var r = 0; r < rows; r++) {
    for (var c = 0; c < cols; c++) {
      if (!isEmpty(r, c)) continue;
      tryPlaceAt(tipR: r, tipC: c, targetLen: 1, minLen: 1);
    }
  }

  if (arrows.length < minArrows) {
    throw StateError(
      'Nested daily only placed ${arrows.length}/$minArrows arrows '
      '($rows×$cols, fill ${occupied.length}/${rows * cols})',
    );
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
    ),
    placementOrder: List<String>.unmodifiable(placementOrder),
  );
}

/// Campaign levels 1–13 built as nested polyline boards.
class LevelRepository {
  LevelRepository({List<SolvableLevelResult>? prebuilt})
      : _results = prebuilt ?? _buildCampaignLevels();

  final List<SolvableLevelResult> _results;
  final Map<int, LevelModel> _dailyCache = {};

  List<LevelModel> get levels =>
      _results.map((result) => result.level).toList(growable: false);

  int get levelCount => _results.length;

  List<String> placementOrderFor(int levelNumber) {
    final index = levelNumber - 1;
    if (index < 0 || index >= _results.length) {
      throw RangeError('No placement order for level $levelNumber');
    }
    return _results[index].placementOrder;
  }

  /// Solve order for tutorials (reverse of placement).
  List<String> solveOrderFor(int levelNumber) =>
      placementOrderFor(levelNumber).reversed.toList();

  LevelModel getLevel(int levelNumber) {
    final key = levelNumber < 1 ? 1 : levelNumber;
    if (key <= _results.length) {
      return _results[key - 1].level;
    }

    // Loop / extend past curated pack with hard boards.
    return generateSolvableLevel(
      key,
      6,
      14,
      4,
      2,
      difficulty: LevelDifficulty.hard,
    ).level;
  }

  LevelModel nextLevel(int currentLevelNumber) =>
      getLevel(currentLevelNumber + 1);

  LevelModel getDailyLevel([DateTime? date]) {
    final day = date ?? DateTime.now();
    final levelNumber =
        900000000 + day.year * 10000 + day.month * 100 + day.day;
    return _dailyCache.putIfAbsent(
      levelNumber,
      () {
        // One fast nested pass first (16×15). Fallback only if needed.
        for (final attempt in const [
          (rows: 16, cols: 15, minArrows: 30),
          (rows: 14, cols: 14, minArrows: 24),
        ]) {
          try {
            return generateNestedSolvableLevel(
              levelNumber,
              attempt.rows,
              attempt.cols,
              3,
              2,
              difficulty: LevelDifficulty.expert,
              seed: levelNumber + attempt.rows * 19 + attempt.cols * 7,
              minArrows: attempt.minArrows,
            ).level;
          } on StateError {
            continue;
          }
        }
        return generateNestedSolvableLevel(
          levelNumber,
          12,
          12,
          3,
          2,
          difficulty: LevelDifficulty.expert,
          seed: levelNumber,
          minArrows: 18,
          fillTarget: 0.85,
        ).level;
      },
    );
  }

  static List<SolvableLevelResult> _buildCampaignLevels() {
    // L1 tutorial, L2–L13 nested / sparse polylines.
    return [
      _tutorialLevel1(),
      _nestedLevel2(),
      _nestedLevel3(),
      _nestedLevel4(),
      _nestedLevel5(),
      _nestedLevel6(),
      _nestedLevel7(),
      _nestedLevel8(),
      _nestedLevel9(),
      _nestedLevel10(),
      _nestedLevel11(),
      _nestedLevel12(),
      _nestedLevel13(),
    ];
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
