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

    test('L1 tutorial; L2–5 prior nests; L6+ Mix snakes; all solvable', () {
      final repo = LevelRepository();
      expect(repo.levelCount, 10);

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
      expect(repo.getLevel(2).difficulty, LevelDifficulty.easy);
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

      // L6: heart silhouette + nested snakes.
      final l6 = repo.getLevel(6);
      expect(l6.shapeMask, isNotNull);
      expect(l6.difficulty, LevelDifficulty.hard);
      expectInMask(l6);

      // L7–10: nested paths, in-mask when masked, solvable.
      for (var n = 7; n <= 10; n++) {
        final level = repo.getLevel(n);
        expect(level.arrows, isNotEmpty, reason: 'L$n');
        for (final a in level.arrows) {
          expect(a.path.length, greaterThanOrEqualTo(2), reason: 'L$n ${a.id}');
        }
        expectInMask(level);
      }
      expect(repo.getLevel(10).difficulty, LevelDifficulty.expert);

      for (var n = 1; n <= 10; n++) {
        expectSolvable(repo, repo.getLevel(n));
      }

      // Beyond campaign pack clamps to level 10.
      expect(repo.getLevel(11).levelNumber, 10);
    });
  });
}
