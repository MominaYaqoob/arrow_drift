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

/// Campaign levels 1–5 built with [generateSolvableLevel].
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

    // Loop / extend past curated pack with medium boards.
    return generateSolvableLevel(
      key,
      6,
      14,
      4,
      2,
      difficulty: LevelDifficulty.medium,
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
    // L1 tutorial, L2–L5 nested boards, L6 heart nest.
    return [
      _tutorialLevel1(),
      _nestedLevel2(),
      _nestedLevel3(),
      _nestedLevel4(),
      _nestedLevel5(),
      generateSolvableLevel(
        6,
        12,
        40,
        3,
        1,
        difficulty: LevelDifficulty.hard,
        seed: 6 * 7919 + 12 * 97 + 40,
        shapeMask: generateHeartShapeMask(12),
      ),
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
        difficulty: LevelDifficulty.medium,
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
        difficulty: LevelDifficulty.medium,
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

  /// Fixed Level 4: dense nested polylines (reference SS — winding U / zigzags).
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

    // 7×7 nest — tall right U + zigzags (no shared cells).
    final arrows = [
      // A: outer L tip RIGHT — free
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
      // B: outer right tip DOWN — free
      pathArrow(
        '4-B',
        [(1, 6), (2, 6), (3, 6), (4, 6), (5, 6), (6, 6)],
        ArrowDirection.down,
      ),
      // C: bottom bar tip LEFT (blocked by A)
      pathArrow(
        '4-C',
        [(6, 5), (6, 4), (6, 3), (6, 2), (6, 1)],
        ArrowDirection.left,
      ),
      // D: right column tip DOWN (blocked by C)
      pathArrow(
        '4-D',
        [(1, 5), (2, 5), (3, 5), (4, 5), (5, 5)],
        ArrowDirection.down,
      ),
      // I: inner-right column tip DOWN (blocked by C) — tall U with D
      pathArrow(
        '4-I',
        [(2, 4), (3, 4), (4, 4), (5, 4)],
        ArrowDirection.down,
      ),
      // E: top zig tip RIGHT (blocked by D)
      pathArrow(
        '4-E',
        [(1, 1), (1, 2), (1, 3), (1, 4)],
        ArrowDirection.right,
      ),
      // F: bottom-inner tip RIGHT (blocked by I)
      pathArrow(
        '4-F',
        [(5, 1), (5, 2), (5, 3)],
        ArrowDirection.right,
      ),
      // J: mid horizontal tip RIGHT (blocked by I)
      pathArrow(
        '4-J',
        [(2, 1), (2, 2), (2, 3)],
        ArrowDirection.right,
      ),
      // G: mid U tip LEFT — last segment is left (was UP → crooked head)
      pathArrow(
        '4-G',
        [(4, 2), (4, 3), (3, 3), (3, 2)],
        ArrowDirection.left,
      ),
      // H: left hook tip UP (blocked by J)
      pathArrow(
        '4-H',
        [(4, 1), (3, 1)],
        ArrowDirection.up,
      ),
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
      // Solve: A,B,C,D,I,E,F,J,H,G
      placementOrder: const [
        '4-G',
        '4-H',
        '4-J',
        '4-F',
        '4-E',
        '4-I',
        '4-D',
        '4-C',
        '4-B',
        '4-A',
      ],
    );
  }

  /// Fixed Level 5: dense nested maze reset to match reference SS.
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

    // 8×8 packed nest — winding L/U/zigs, tip matches last segment.
    final arrows = [
      pathArrow(
        '5-A',
        [
          (7, 0),
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
          (0, 7),
        ],
        ArrowDirection.right,
      ),
      pathArrow(
        '5-B',
        [(1, 7), (2, 7), (3, 7), (4, 7), (5, 7), (6, 7), (7, 7)],
        ArrowDirection.down,
      ),
      pathArrow(
        '5-C',
        [(7, 6), (7, 5), (7, 4), (7, 3), (7, 2), (7, 1)],
        ArrowDirection.left,
      ),
      pathArrow(
        '5-D',
        [(1, 6), (2, 6), (3, 6), (4, 6), (5, 6), (6, 6)],
        ArrowDirection.down,
      ),
      // Top zig-L tip RIGHT
      pathArrow(
        '5-E',
        [(1, 1), (1, 2), (2, 2), (2, 3), (1, 3), (1, 4), (1, 5)],
        ArrowDirection.right,
      ),
      // Bottom zig-L tip RIGHT
      pathArrow(
        '5-F',
        [(6, 1), (6, 2), (5, 2), (5, 3), (6, 3), (6, 4), (6, 5)],
        ArrowDirection.right,
      ),
      pathArrow(
        '5-G',
        [(3, 1), (4, 1), (5, 1)],
        ArrowDirection.down,
      ),
      pathArrow(
        '5-H',
        [(2, 5), (3, 5), (4, 5), (5, 5)],
        ArrowDirection.down,
      ),
      // Mid hook tip UP
      pathArrow(
        '5-I',
        [(3, 2), (3, 3), (3, 4), (2, 4)],
        ArrowDirection.up,
      ),
      // Lower hook tip DOWN
      pathArrow(
        '5-J',
        [(4, 2), (4, 3), (4, 4), (5, 4)],
        ArrowDirection.down,
      ),
      pathArrow(
        '5-K',
        [(2, 1)],
        ArrowDirection.down,
      ),
    ];

    return SolvableLevelResult(
      level: LevelModel(
        levelNumber: 5,
        gridRows: 8,
        gridCols: 8,
        arrows: arrows,
        heartsAllowed: 3,
        hintsAllowed: 1,
        difficulty: LevelDifficulty.medium,
      ),
      placementOrder: const [
        '5-K',
        '5-J',
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
