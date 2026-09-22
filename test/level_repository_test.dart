import 'package:flutter_test/flutter_test.dart';

import 'package:arrow_drift/data/models/arrow_model.dart';
import 'package:arrow_drift/data/models/level_model.dart';
import 'package:arrow_drift/data/repositories/campaign_shapes.dart';
import 'package:arrow_drift/data/repositories/level_repository.dart';
import 'package:arrow_drift/data/repositories/shape_levels_data.dart';
import 'package:arrow_drift/data/repositories/shape_levels_data_101_200.dart';
import 'package:arrow_drift/features/gameplay/game_controller.dart';

void main() {
  group('generateSolvableLevel', () {
    final configs =
        <
          ({
            int levelNumber,
            int gridSize,
            int arrowCount,
            int hearts,
            int hints,
            LevelDifficulty difficulty,
          })
        >[
          (
            levelNumber: 3,
            gridSize: 5,
            arrowCount: 9,
            hearts: 3,
            hints: 2,
            difficulty: LevelDifficulty.medium,
          ),
          (
            levelNumber: 4,
            gridSize: 6,
            arrowCount: 13,
            hearts: 3,
            hints: 2,
            difficulty: LevelDifficulty.medium,
          ),
          (
            levelNumber: 5,
            gridSize: 6,
            arrowCount: 16,
            hearts: 3,
            hints: 1,
            difficulty: LevelDifficulty.hard,
          ),
        ];

    test('every generated level is solvable in reverse placement order', () {
      for (final config in configs) {
        final result = generateSolvableLevel(
          config.levelNumber,
          config.gridSize,
          config.arrowCount,
          config.hearts,
          config.hints,
          difficulty: config.difficulty,
        );

        expect(result.level.arrows, hasLength(config.arrowCount));
        final arrows = cloneArrows(result.level.arrows);

        for (final id in result.placementOrder.reversed) {
          final arrow = arrows.firstWhere((item) => item.id == id);
          expect(
            isArrowFree(
              arrow: arrow,
              arrows: arrows,
              gridRows: result.level.gridRows,
              gridCols: result.level.gridCols,
            ),
            isTrue,
            reason: 'Level ${config.levelNumber}: arrow $id blocked',
          );
          final index = arrows.indexWhere((item) => item.id == id);
          arrows[index] = arrows[index].copyWith(isRemoved: true);
        }
      }
    });
  });

  group('LevelRepository', () {
    void expectSolvable(LevelRepository repo, LevelModel level) {
      final order = repo.placementOrderFor(level.levelNumber);
      final arrows = cloneArrows(level.arrows);
      for (final id in order.reversed) {
        final arrow = arrows.firstWhere((item) => item.id == id);
        expect(
          isArrowFree(
            arrow: arrow,
            arrows: arrows,
            gridRows: level.gridRows,
            gridCols: level.gridCols,
            shapeMask: level.shapeMask,
          ),
          isTrue,
          reason: 'Campaign level ${level.levelNumber}: $id blocked',
        );
        final index = arrows.indexWhere((item) => item.id == id);
        arrows[index] = arrows[index].copyWith(isRemoved: true);
      }
    }

    void expectInMask(LevelModel level) {
      if (level.shapeMask == null) return;
      for (final arrow in level.arrows) {
        expect(arrow.path.length, greaterThanOrEqualTo(2));
        for (final cell in arrow.path) {
          expect(
            level.shapeMask![cell.row][cell.col],
            isTrue,
            reason: 'L${level.levelNumber} ${arrow.id} outside shape',
          );
        }
      }
    }

    int freeCountFor(LevelModel level) {
      var freeCount = 0;
      for (final a in level.arrows) {
        if (isArrowFree(
          arrow: a,
          arrows: level.arrows,
          gridRows: level.gridRows,
          gridCols: level.gridCols,
          shapeMask: level.shapeMask,
        )) {
          freeCount++;
        }
      }
      return freeCount;
    }

    test('L1 tutorial; L2-5 Easy; L6-20 Medium; L21-100 Hard; L101-199 Hard+; '
        'L200-500 Expert; L501-1000 late tiers; all solvable', () {
      final repo = LevelRepository();
      expect(repo.levelCount, 1000);

      // L1 unchanged tutorial.
      expect(repo.getLevel(1).arrows, hasLength(3));
      expect(repo.getLevel(1).gridRows, 3);
      final l1 = repo.getLevel(1).arrows;
      final byCol = {for (final a in l1) a.col: a};
      expect(byCol[0]!.direction, ArrowDirection.up);
      expect(byCol[1]!.direction, ArrowDirection.up);
      expect(byCol[2]!.direction, ArrowDirection.down);

      expect(repo.getLevel(1).heartsAllowed, 3);

      // L2-20: square maze boards — exact arrow counts, long arrows,
      // almost fully covered, only a few arrows free at the start.
      const mazeCounts = {
        2: 40, 3: 41, 4: 43, 5: 44, 6: 46, 7: 47, 8: 48, 9: 49, 10: 50, //
        11: 51, 12: 52, 13: 53, 14: 54, 15: 55, 16: 56, 17: 57, 18: 58,
        19: 59, 20: 60,
      };
      for (final MapEntry(key: n, value: count) in mazeCounts.entries) {
        final level = repo.getLevel(n);
        expect(level.levelNumber, n);
        expect(
          level.difficulty,
          n <= 5 ? LevelDifficulty.easy : LevelDifficulty.medium,
          reason: 'L$n',
        );
        expect(level.shapeMask, isNull, reason: 'L$n square');
        expect(level.gridRows, level.gridCols, reason: 'L$n square');
        expect(level.gridRows, inInclusiveRange(23, 28), reason: 'L$n');
        expect(level.arrows.length, count, reason: 'L$n');
        expect(level.heartsAllowed, 3, reason: 'L$n');

        final cells = level.arrows.fold(0, (sum, a) => sum + a.path.length);
        expect(
          cells / (level.gridRows * level.gridCols),
          greaterThanOrEqualTo(0.9),
          reason: 'L$n coverage',
        );
        expect(
          level.arrows.where((a) => a.path.length >= 15).length,
          greaterThanOrEqualTo(5),
          reason: 'L$n long arrows',
        );
        for (final a in level.arrows) {
          expect(a.path.length, greaterThanOrEqualTo(2), reason: 'L$n ${a.id}');
          expect(a.row, a.path.last.row, reason: 'L$n ${a.id} tip');
          expect(a.col, a.path.last.col, reason: 'L$n ${a.id} tip');
        }

        final freeCount = freeCountFor(level);
        expect(freeCount, inInclusiveRange(1, 5), reason: 'L$n free at start');
        expectSolvable(repo, level);
      }

      // L21-100: shaped maze boards — exact counts, 9 rotating shapes, a
      // repeated arrow count never reuses a shape.
      const shapeCounts = [
        61, 65, 63, 68, 64, 65, 62, 69, 61, 68, //
        66, 70, 64, 73, 63, 70, 67, 74, 66, 73,
        71, 75, 69, 78, 68, 75, 72, 79, 71, 78,
        76, 80, 74, 83, 73, 80, 77, 84, 76, 83,
        81, 85, 79, 88, 78, 85, 82, 89, 81, 88,
        86, 90, 84, 93, 83, 90, 87, 94, 86, 93,
        91, 95, 89, 98, 88, 95, 92, 99, 91, 98,
        96, 100, 94, 97, 93, 100, 97, 96, 96, 97,
      ];
      final shapesByCount = <int, Set<String>>{};
      String? previousShape;
      for (var n = 21; n <= 100; n++) {
        final level = repo.getLevel(n);
        final count = shapeCounts[n - 21];
        expect(level.levelNumber, n);
        expect(level.difficulty, LevelDifficulty.hard, reason: 'L$n');
        expect(level.arrows.length, count, reason: 'L$n');
        expect(level.heartsAllowed, 3, reason: 'L$n');
        expect(level.gridCols, lessThanOrEqualTo(32), reason: 'L$n');
        expect(level.gridRows, lessThanOrEqualTo(34), reason: 'L$n');
        expectInMask(level);

        // Shape must differ from the previous level and from every earlier
        // level with the same arrow count.
        final shape = kShapeLevelData[n]![0].split(',')[2];
        expect(shape, isNot(previousShape), reason: 'L$n shape repeat');
        expect(
          shapesByCount.putIfAbsent(count, () => {}).add(shape),
          isTrue,
          reason: 'L$n reuses $shape for $count arrows',
        );
        previousShape = shape;

        var maskCells = level.gridRows * level.gridCols;
        if (level.shapeMask != null) {
          maskCells = level.shapeMask!.fold(
            0,
            (sum, row) => sum + row.where((v) => v).length,
          );
        }
        final cells = level.arrows.fold(0, (sum, a) => sum + a.path.length);
        expect(
          cells / maskCells,
          greaterThanOrEqualTo(0.84),
          reason: 'L$n coverage',
        );
        for (final a in level.arrows) {
          expect(a.row, a.path.last.row, reason: 'L$n ${a.id} tip');
          expect(a.col, a.path.last.col, reason: 'L$n ${a.id} tip');
        }
        expect(freeCountFor(level), greaterThanOrEqualTo(1), reason: 'L$n');
        expectSolvable(repo, level);
      }

      // L101-200: shaped maze boards — exact counts, 6 wide shapes (no
      // triangles / diamond), a repeated count never reuses a shape.
      const shapeCounts101 = [
        101, 105, 103, 108, 104, 105, 102, 109, 101, 108, //
        106, 110, 104, 113, 103, 110, 107, 114, 106, 113,
        111, 115, 109, 118, 108, 115, 112, 119, 111, 118,
        116, 120, 114, 123, 113, 120, 117, 124, 116, 123,
        121, 125, 119, 128, 118, 125, 122, 129, 121, 128,
        126, 130, 124, 133, 123, 130, 127, 134, 126, 133,
        131, 135, 129, 138, 128, 135, 132, 139, 131, 138,
        136, 140, 134, 143, 133, 140, 137, 144, 136, 143,
        141, 145, 139, 148, 138, 145, 142, 149, 141, 148,
        146, 150, 144, 147, 143, 150, 147, 146, 146, 151,
      ];
      const wideShapes = {
        'circle',
        'oval',
        'square',
        'rectangle',
        'hexagon',
        'octagon',
      };
      final shapesByCount101 = <int, Set<String>>{};
      for (var n = 101; n <= 200; n++) {
        final level = repo.getLevel(n);
        final count = shapeCounts101[n - 101];
        expect(level.levelNumber, n);
        expect(
          level.difficulty,
          n <= 199 ? LevelDifficulty.hardPlus : LevelDifficulty.expert,
          reason: 'L$n',
        );
        expect(level.arrows.length, count, reason: 'L$n');
        expect(level.heartsAllowed, 3, reason: 'L$n');
        expect(level.hintsAllowed, 2, reason: 'L$n');
        expect(level.gridCols, lessThanOrEqualTo(36), reason: 'L$n');
        expect(level.gridRows, lessThanOrEqualTo(47), reason: 'L$n');
        expectInMask(level);

        final shape = kShapeLevelData101[n]![0].split(',')[2];
        expect(wideShapes, contains(shape), reason: 'L$n $shape');
        expect(shape, isNot(previousShape), reason: 'L$n shape repeat');
        expect(
          shapesByCount101.putIfAbsent(count, () => {}).add(shape),
          isTrue,
          reason: 'L$n reuses $shape for $count arrows',
        );
        previousShape = shape;

        var maskCells = level.gridRows * level.gridCols;
        if (level.shapeMask != null) {
          maskCells = level.shapeMask!.fold(
            0,
            (sum, row) => sum + row.where((v) => v).length,
          );
        }
        final cells = level.arrows.fold(0, (sum, a) => sum + a.path.length);
        expect(
          cells / maskCells,
          greaterThanOrEqualTo(0.8),
          reason: 'L$n coverage',
        );
        for (final a in level.arrows) {
          expect(a.row, a.path.last.row, reason: 'L$n ${a.id} tip');
          expect(a.col, a.path.last.col, reason: 'L$n ${a.id} tip');
        }
        expect(freeCountFor(level), greaterThanOrEqualTo(1), reason: 'L$n');
        expectSolvable(repo, level);
      }

      // L201-1000: shape / count plan — no level repeats the previous
      // level's shape. L201-400 reuse a shape for a repeated count at most
      // once; L401-1000 (only 18 counts, 165-182) keep the same count+shape
      // pair at least 40 levels apart.
      final plan = assignShapes201();
      expect(plan, hasLength(800));
      String? prevShape = 'octagon'; // L200
      final lastUse = <String, int>{};
      var earlyReuses = 0;
      for (var n = 201; n <= 1000; n++) {
        final shape = plan[n - 201];
        expect(kShapeCycle201, contains(shape), reason: 'L$n');
        expect(shape, isNot(prevShape), reason: 'L$n shape repeat');
        final count = waveCount(n);
        if (n >= 401) {
          expect(count, inInclusiveRange(165, 182), reason: 'L$n count');
        }
        final key = '$count-$shape';
        if (lastUse.containsKey(key)) {
          if (n <= 400) earlyReuses++;
          expect(n - lastUse[key]!, greaterThanOrEqualTo(40), reason: 'L$n');
        }
        lastUse[key] = n;
        prevShape = shape;
      }
      expect(earlyReuses, lessThanOrEqualTo(1));

      // L201-1000 every level (pre-built, or built on the device when the
      // offline tool skipped it).
      final lateLevels = <int>[
        for (var n = 201; n <= 400; n++) n,
        for (var n = 401; n <= 1000; n++) n,
      ];
      for (final n in lateLevels) {
        final level = repo.getLevel(n);
        final shape = shapeForLevel(n);
        expect(level.levelNumber, n);
        expect(level.arrows.length, waveCount(n), reason: 'L$n count');
        expect(level.heartsAllowed, 3, reason: 'L$n hearts');
        expect(level.hintsAllowed, 2, reason: 'L$n hints');
        final expected = campaignShapeMask(
          shape,
          level.gridRows,
          level.gridCols,
        );
        final actual =
            level.shapeMask ??
            List.generate(
              level.gridRows,
              (_) => List<bool>.filled(level.gridCols, true),
            );
        expect(actual, expected, reason: 'L$n should be a $shape');
        for (final a in level.arrows) {
          expect(a.path.length, greaterThanOrEqualTo(2), reason: 'L$n ${a.id}');
          expect(a.row, a.path.last.row, reason: 'L$n ${a.id} tip');
          expect(a.col, a.path.last.col, reason: 'L$n ${a.id} tip');
        }
        expectInMask(level);
        expect(freeCountFor(level), greaterThanOrEqualTo(1), reason: 'L$n');
        expectSolvable(repo, level);
      }

      // Solvability replay: exhaustive for L1-20.
      for (var n = 1; n <= 20; n++) {
        expectSolvable(repo, repo.getLevel(n));
      }

      expect(repo.getLevel(1001).levelNumber, 1000);
    });
  });
}
