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

    test('L1–10 Easy; L11–15 Medium; L16–20 Hard long snakes; all solvable', () {
      final repo = LevelRepository();
      expect(repo.levelCount, 20);

      // L1 unchanged tutorial.
      expect(repo.getLevel(1).arrows, hasLength(3));
      expect(repo.getLevel(1).gridRows, 3);
      final l1 = repo.getLevel(1).arrows;
      final byCol = {for (final a in l1) a.col: a};
      expect(byCol[0]!.direction, ArrowDirection.up);
      expect(byCol[1]!.direction, ArrowDirection.up);
      expect(byCol[2]!.direction, ArrowDirection.down);

      // L2–5: previous open-rectangle nested boards.
      expect(repo.getLevel(2).gridRows, 6);
      expect(repo.getLevel(2).gridCols, 6);
      expect(repo.getLevel(3).gridRows, 6);
      expect(repo.getLevel(4).gridRows, 7);
      expect(repo.getLevel(5).gridRows, 12);
      for (var n = 2; n <= 5; n++) {
        final level = repo.getLevel(n);
        expect(level.shapeMask, isNull, reason: 'L$n open rect');
        expect(level.arrows, isNotEmpty);
        for (final a in level.arrows) {
          expect(a.path.length, greaterThanOrEqualTo(2), reason: 'L$n ${a.id}');
        }
      }

      // L1–10: all labeled Easy.
      for (var n = 1; n <= 10; n++) {
        expect(
          repo.getLevel(n).difficulty,
          LevelDifficulty.easy,
          reason: 'L$n should be Easy',
        );
      }

      // L6: heart silhouette + nested snakes.
      final l6 = repo.getLevel(6);
      expect(l6.shapeMask, isNotNull);
      expectInMask(l6);

      for (var n = 7; n <= 10; n++) {
        final level = repo.getLevel(n);
        expect(level.arrows, isNotEmpty, reason: 'L$n');
        for (final a in level.arrows) {
          expect(a.path.length, greaterThanOrEqualTo(2), reason: 'L$n ${a.id}');
        }
        expectInMask(level);
      }

      // L11–15: Medium.
      for (var n = 11; n <= 15; n++) {
        final level = repo.getLevel(n);
        expect(level.levelNumber, n);
        expect(level.difficulty, LevelDifficulty.medium, reason: 'L$n');
        expect(level.gridRows, greaterThanOrEqualTo(11), reason: 'L$n');
        expect(level.arrows.length, greaterThanOrEqualTo(14), reason: 'L$n');
        for (final a in level.arrows) {
          expect(a.path.length, greaterThanOrEqualTo(2), reason: 'L$n ${a.id}');
        }
        expectInMask(level);
      }

      // L16–18: Hard maze pack.
      for (var n = 16; n <= 18; n++) {
        final level = repo.getLevel(n);
        expect(level.levelNumber, n);
        expect(level.difficulty, LevelDifficulty.hard, reason: 'L$n');
        expect(level.gridRows, greaterThanOrEqualTo(12), reason: 'L$n');
        expect(level.arrows.length, greaterThanOrEqualTo(16), reason: 'L$n');
        expectInMask(level);
      }

      // L19–20: dense space-fill, fast build.
      for (var n = 19; n <= 20; n++) {
        final level = repo.getLevel(n);
        expect(level.levelNumber, n);
        expect(level.difficulty, LevelDifficulty.hard, reason: 'L$n');
        expect(level.gridRows, greaterThanOrEqualTo(12), reason: 'L$n');
        expect(level.arrows.length, greaterThanOrEqualTo(18), reason: 'L$n');

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
        expect(freeCount, greaterThanOrEqualTo(1), reason: 'L$n ≥1 free');
        final cells = level.gridRows * level.gridCols;
        final occupied =
            level.arrows.fold<int>(0, (s, a) => s + a.path.length);
        expect(occupied / cells, greaterThanOrEqualTo(0.75), reason: 'L$n fill');
        expectInMask(level);
      }

      for (var n = 1; n <= 20; n++) {
        expectSolvable(repo, repo.getLevel(n));
      }

      expect(repo.getLevel(21).levelNumber, 20);
    });
  });
}
