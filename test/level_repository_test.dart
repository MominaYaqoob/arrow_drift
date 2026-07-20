import 'package:flutter_test/flutter_test.dart';

import 'package:arrow_drift/data/models/arrow_model.dart';
import 'package:arrow_drift/data/models/level_model.dart';
import 'package:arrow_drift/data/repositories/level_repository.dart';
import 'package:arrow_drift/features/gameplay/game_controller.dart';

void main() {
  group('generateSolvableLevel', () {
    final configs = <({
      int levelNumber,
      int gridSize,
      int arrowCount,
      int hearts,
      int hints,
      LevelDifficulty difficulty,
    })>[
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

    test(
        'L1 tutorial; L2-5 Easy; L6-20 Medium; L21-199 Hard; L200-500 '
        'Expert; all solvable', () {
      final repo = LevelRepository();
      expect(repo.levelCount, 500);

      // L1 unchanged tutorial.
      expect(repo.getLevel(1).arrows, hasLength(3));
      expect(repo.getLevel(1).gridRows, 3);
      final l1 = repo.getLevel(1).arrows;
      final byCol = {for (final a in l1) a.col: a};
      expect(byCol[0]!.direction, ArrowDirection.up);
      expect(byCol[1]!.direction, ArrowDirection.up);
      expect(byCol[2]!.direction, ArrowDirection.down);

      // L2-5: Easy tier — 10-20 arrows, light blocking (1-2 free).
      for (var n = 2; n <= 5; n++) {
        final level = repo.getLevel(n);
        expect(level.levelNumber, n);
        expect(level.difficulty, LevelDifficulty.easy, reason: 'L$n');
        expect(level.gridRows, greaterThanOrEqualTo(6), reason: 'L$n');
        expect(level.gridRows, lessThanOrEqualTo(13), reason: 'L$n');
        expect(level.arrows.length, greaterThanOrEqualTo(10), reason: 'L$n');
        expect(level.arrows.length, lessThanOrEqualTo(20), reason: 'L$n');
        for (final a in level.arrows) {
          expect(a.path.length, greaterThanOrEqualTo(2), reason: 'L$n ${a.id}');
        }
        expectInMask(level);
        final freeCount = freeCountFor(level);
        expect(freeCount, greaterThanOrEqualTo(1), reason: 'L$n >=1 free');
        expect(freeCount, lessThanOrEqualTo(8), reason: 'L$n mostly locked');
      }

      // L6-20: Medium tier — 30-40 nested arrows, seal-chain blocking.
      for (var n = 6; n <= 20; n++) {
        final level = repo.getLevel(n);
        expect(level.levelNumber, n);
        expect(level.difficulty, LevelDifficulty.medium, reason: 'L$n');
        expect(level.gridRows, greaterThanOrEqualTo(10), reason: 'L$n');
        expect(level.gridRows, lessThanOrEqualTo(17), reason: 'L$n');
        expect(level.arrows.length, greaterThanOrEqualTo(30), reason: 'L$n');
        expect(level.arrows.length, lessThanOrEqualTo(40), reason: 'L$n');
        for (final a in level.arrows) {
          expect(a.path.length, greaterThanOrEqualTo(2), reason: 'L$n ${a.id}');
        }
        expectInMask(level);

        final freeCount = freeCountFor(level);
        expect(freeCount, greaterThanOrEqualTo(1), reason: 'L$n >=1 free');
        expect(freeCount, lessThanOrEqualTo(8), reason: 'L$n bounded free');
      }

      // L21-199: Hard tier — 70-199 arrows, sampled for CI speed.
      final hardSample = <int>{21, 199, for (var n = 21; n <= 199; n += 11) n};
      for (final n in hardSample) {
        final level = repo.getLevel(n);
        expect(level.levelNumber, n);
        expect(level.difficulty, LevelDifficulty.hard, reason: 'L$n');
        expect(level.gridRows, greaterThanOrEqualTo(20), reason: 'L$n');
        expect(level.gridRows, lessThanOrEqualTo(26), reason: 'L$n');
        expect(level.arrows.length, greaterThanOrEqualTo(70), reason: 'L$n');
        expect(level.arrows.length, lessThanOrEqualTo(199), reason: 'L$n');
        for (final a in level.arrows) {
          expect(a.path.length, greaterThanOrEqualTo(2), reason: 'L$n ${a.id}');
        }
        expectInMask(level);

        final freeCount = freeCountFor(level);
        expect(freeCount, greaterThanOrEqualTo(1), reason: 'L$n >=1 free');
        expect(freeCount, lessThanOrEqualTo(40), reason: 'L$n mostly locked');
        expect(level.heartsAllowed, 3, reason: 'L$n hearts floor');
        expect(level.hintsAllowed, 2, reason: 'L$n hints floor');
      }

      // L200-500: Expert tier — 100-250 arrows, sampled.
      final expertSample = <int>{
        200,
        500,
        for (var n = 200; n <= 500; n += 23) n,
      };
      for (final n in expertSample) {
        final level = repo.getLevel(n);
        expect(level.levelNumber, n);
        expect(level.difficulty, LevelDifficulty.expert, reason: 'L$n');
        expect(level.gridRows, greaterThanOrEqualTo(18), reason: 'L$n');
        expect(level.gridRows, lessThanOrEqualTo(30), reason: 'L$n');
        expect(level.gridCols, lessThanOrEqualTo(30), reason: 'L$n');
        expect(level.arrows.length, greaterThanOrEqualTo(100), reason: 'L$n');
        expect(level.arrows.length, lessThanOrEqualTo(250), reason: 'L$n');
        for (final a in level.arrows) {
          expect(a.path.length, greaterThanOrEqualTo(2), reason: 'L$n ${a.id}');
        }
        expectInMask(level);

        final freeCount = freeCountFor(level);
        expect(freeCount, greaterThanOrEqualTo(1), reason: 'L$n >=1 free');
        expect(freeCount, lessThanOrEqualTo(40), reason: 'L$n mostly locked');
        expect(level.heartsAllowed, 3, reason: 'L$n hearts floor');
        expect(level.hintsAllowed, 2, reason: 'L$n hints floor');
      }

      // Solvability replay: exhaustive for L1-20, sampled for Hard/Expert.
      for (var n = 1; n <= 20; n++) {
        expectSolvable(repo, repo.getLevel(n));
      }
      for (final n in hardSample) {
        expectSolvable(repo, repo.getLevel(n));
      }
      for (final n in expertSample) {
        expectSolvable(repo, repo.getLevel(n));
      }

      expect(repo.getLevel(501).levelNumber, 500);
    });
  });
}
