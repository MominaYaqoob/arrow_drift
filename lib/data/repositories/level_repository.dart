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

  /// Campaign levels 1–11 built as nested polyline boards.
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
      () => generateSolvableLevel(
        levelNumber,
        6,
        14,
        4,
        2,
        difficulty: LevelDifficulty.medium,
        seed: levelNumber,
      ).level,
    );
  }

  static List<SolvableLevelResult> _buildCampaignLevels() {
    // L1 tutorial, L2–L12 nested / sparse polylines.
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

  /// Level 12 — reference screenshot layout (twin top U, right UP/DOWN, bottom 3×UP).
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
      pathArrow('12-A', [(1, 1), (1, 0), (0, 0), (0, 1)], ArrowDirection.right),
      pathArrow('12-B', [(1, 4), (1, 3), (0, 3), (0, 4)], ArrowDirection.right),
      pathArrow('12-C', [(2, 5), (1, 5), (0, 5)], ArrowDirection.up),
      pathArrow('12-D', [(1, 6), (1, 7), (0, 7)], ArrowDirection.up),
      pathArrow('12-E', [(1, 9), (1, 8), (0, 8)], ArrowDirection.up),
      pathArrow('12-F', [(1, 10), (0, 10), (0, 11)], ArrowDirection.right),
      pathArrow(
        '12-G',
        [for (var r = 15; r >= 0; r--) (r, 14)],
        ArrowDirection.up,
      ),
      pathArrow(
        '12-H',
        [for (var r = 0; r <= 15; r++) (r, 13)],
        ArrowDirection.down,
      ),
      pathArrow('12-I', [(2, 0), (3, 0), (4, 0)], ArrowDirection.down),
      pathArrow('12-J', [(4, 1), (3, 1), (2, 1)], ArrowDirection.up),
      pathArrow('12-K', [(2, 4), (2, 3), (3, 3), (3, 2)], ArrowDirection.left),
      pathArrow('12-L', [(2, 6), (2, 7), (3, 7), (3, 8)], ArrowDirection.right),
      pathArrow(
        '12-M',
        [(4, 9), (3, 9), (2, 9), (2, 10), (2, 11)],
        ArrowDirection.right,
      ),
      pathArrow('12-N', [(4, 12), (3, 12), (2, 12)], ArrowDirection.up),
      pathArrow(
        '12-O',
        [for (var r = 5; r <= 12; r++) (r, 0)],
        ArrowDirection.down,
      ),
      pathArrow('12-P', [(5, 1), (6, 1), (6, 2), (6, 3)], ArrowDirection.right),
      pathArrow(
        '12-Q',
        [(6, 4), (7, 4), (8, 4), (8, 3), (7, 3)],
        ArrowDirection.left,
      ),
      pathArrow('12-R', [(5, 5), (5, 6), (6, 6), (6, 7)], ArrowDirection.right),
      pathArrow(
        '12-S',
        [(5, 8), (5, 9), (6, 9), (6, 10), (5, 10)],
        ArrowDirection.up,
      ),
      pathArrow('12-T', [(7, 8), (7, 9), (7, 10), (7, 11)], ArrowDirection.right),
      pathArrow('12-U', [(8, 12), (7, 12), (6, 12), (5, 12)], ArrowDirection.up),
      pathArrow(
        '12-V',
        [
          (8, 5),
          (8, 6),
          (9, 6),
          (9, 7),
          (8, 7),
          (8, 8),
          (9, 8),
          (9, 9),
        ],
        ArrowDirection.right,
      ),
      pathArrow(
        '12-W',
        [
          (11, 4),
          (10, 4),
          (9, 4),
          (9, 3),
          (10, 3),
          (10, 2),
        ],
        ArrowDirection.left,
      ),
      pathArrow('12-X', [(9, 1), (10, 1), (11, 1)], ArrowDirection.down),
      pathArrow('12-Y', [(9, 10), (10, 10), (10, 11)], ArrowDirection.right),
      pathArrow(
        '12-Z',
        [(10, 8), (10, 9), (11, 9), (11, 10)],
        ArrowDirection.right,
      ),
      pathArrow('12-AA', [(11, 2), (11, 3), (12, 3)], ArrowDirection.down),
      pathArrow(
        '12-AB',
        [(11, 6), (11, 5), (12, 5), (12, 4)],
        ArrowDirection.left,
      ),
      pathArrow(
        '12-AC',
        [(12, 6), (12, 7), (13, 7), (13, 8), (14, 8)],
        ArrowDirection.down,
      ),
      pathArrow('12-AD', [(12, 10), (12, 11), (11, 11)], ArrowDirection.up),
      pathArrow('12-AE', [(11, 12), (10, 12), (9, 12)], ArrowDirection.up),
      pathArrow(
        '12-AF',
        [(14, 0), (15, 0), (15, 1), (15, 2), (14, 2), (14, 1)],
        ArrowDirection.left,
      ),
      pathArrow(
        '12-AG',
        [(15, 7), (15, 6), (15, 5), (15, 4), (15, 3)],
        ArrowDirection.left,
      ),
      pathArrow('12-AH', [(14, 4), (13, 4)], ArrowDirection.up),
      pathArrow('12-AI', [(14, 5), (13, 5)], ArrowDirection.up),
      pathArrow('12-AJ', [(14, 6), (13, 6)], ArrowDirection.up),
      pathArrow('12-AK', [(15, 10), (15, 9)], ArrowDirection.left),
      pathArrow(
        '12-AL',
        [(14, 9), (14, 10), (13, 10), (13, 9)],
        ArrowDirection.left,
      ),
      pathArrow('12-AM', [(14, 11), (13, 11), (13, 12)], ArrowDirection.right),
      pathArrow('12-AN', [(15, 12), (14, 12)], ArrowDirection.up),
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
        '12-AN',
        '12-AM',
        '12-AL',
        '12-AK',
        '12-AJ',
        '12-AI',
        '12-AH',
        '12-AB',
        '12-AA',
        '12-AG',
        '12-W',
        '12-X',
        '12-P',
        '12-Q',
        '12-K',
        '12-I',
        '12-O',
        '12-AF',
        '12-Z',
        '12-AD',
        '12-V',
        '12-Y',
        '12-AE',
        '12-AC',
        '12-T',
        '12-R',
        '12-U',
        '12-S',
        '12-L',
        '12-M',
        '12-N',
        '12-J',
        '12-A',
        '12-B',
        '12-F',
        '12-H',
        '12-G',
        '12-E',
        '12-D',
        '12-C',
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
