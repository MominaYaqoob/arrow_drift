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
    test('exposes exactly 30 solvable campaign levels with expected params', () {
      final repo = LevelRepository();
      expect(repo.levels, hasLength(30));

      // Level 1 tutorial
      expect(repo.levels[0].arrows, hasLength(3));
      expect(repo.levels[0].gridRows, 3);

      final l1 = repo.levels.first.arrows;
      final byCol = {for (final a in l1) a.col: a};
      expect(byCol[0]!.direction, ArrowDirection.up);
      expect(byCol[1]!.direction, ArrowDirection.up);
      expect(byCol[2]!.direction, ArrowDirection.down);

      // Level 2 nested paths
      expect(repo.levels[1].arrows, hasLength(6));
      expect(repo.levels[1].gridRows, 6);
      expect(repo.levels[1].heartsAllowed, 3);
      expect(repo.levels[1].difficulty.label, 'Easy');

      // Level 3 nested paths (like Level 2, denser / different directions)
      final l3 = repo.levels[2];
      expect(l3.gridRows, 6);
      expect(l3.arrows, hasLength(8));
      expect(l3.heartsAllowed, 3);
      expect(l3.hintsAllowed, 2);
      expect(l3.difficulty.label, 'Easy');
      expect(l3.arrows.every((a) => a.isMultiCell), isTrue);

      // Level 4 nested paths (dense L2-style)
      final l4 = repo.levels[3];
      expect(l4.gridRows, 7);
      expect(l4.arrows, hasLength(9));
      expect(l4.heartsAllowed, 3);
      expect(l4.hintsAllowed, 2);
      expect(l4.difficulty.label, 'Medium');
      expect(l4.arrows.every((a) => a.path.isNotEmpty), isTrue);

      // Level 5 nested dense maze
      final l5 = repo.levels[4];
      expect(l5.gridRows, 12);
      expect(l5.arrows, hasLength(11));
      expect(l5.heartsAllowed, 3);
      expect(l5.hintsAllowed, 1);
      expect(l5.difficulty.label, 'Medium');
      expect(l5.arrows.every((a) => a.path.isNotEmpty), isTrue);

      // Level 6 nested Hard (same style as L3–L5, denser)
      final l6 = repo.levels[5];
      expect(l6.gridRows, 9);
      expect(l6.gridCols, 9);
      expect(l6.arrows, hasLength(12));
      expect(l6.heartsAllowed, 3);
      expect(l6.hintsAllowed, 2);
      expect(l6.difficulty.label, 'Hard');
      expect(l6.shapeMask, isNull);
      expect(l6.arrows.where((a) => a.isMultiCell).length, greaterThanOrEqualTo(10));
      expect(l6.arrows.every((a) => a.path.isNotEmpty), isTrue);

      final l7 = repo.levels[6];
      expect(l7.gridRows, 10);
      expect(l7.arrows, hasLength(14));
      expect(l7.difficulty.label, 'Hard');

      final l8 = repo.levels[7];
      expect(l8.gridRows, 11);
      expect(l8.arrows, hasLength(14));
      expect(l8.difficulty.label, 'Hard');

      final l9 = repo.levels[8];
      expect(l9.gridRows, 14);
      expect(l9.arrows, hasLength(20));
      expect(l9.difficulty.label, 'Hard');

      final l10 = repo.levels[9];
      expect(l10.gridRows, 11);
      expect(l10.arrows, hasLength(16));
      expect(l10.difficulty.label, 'Expert');

      final l11 = repo.levels[10];
      expect(l11.gridRows, 12);
      expect(l11.arrows, hasLength(15));
      expect(l11.difficulty.label, 'Expert');
      expect(l11.arrows.where((a) => a.isMultiCell).length, greaterThanOrEqualTo(14));

      final l12 = repo.levels[11];
      expect(l12.gridRows, 16);
      expect(l12.gridCols, 15);
      expect(l12.arrows, hasLength(40));
      expect(l12.difficulty.label, 'Expert');
      expect(l12.arrows.every((a) => a.path.isNotEmpty), isTrue);

      final l13 = repo.levels[12];
      expect(l13.gridRows, 18);
      expect(l13.gridCols, 17);
      expect(l13.arrows, hasLength(44));
      expect(l13.difficulty.label, 'Expert');
      expect(l13.arrows.every((a) => a.path.isNotEmpty), isTrue);

      final l14 = repo.levels[13];
      expect(l14.levelNumber, 14);
      expect(l14.difficulty.label, 'Expert');
      expect(l14.shapeMask, isNotNull);
      expect(l14.arrows.length, greaterThanOrEqualTo(20));
      expect(l14.arrows.every((a) => a.path.isNotEmpty), isTrue);
      expect(
        l14.arrows.every((a) => a.path.length >= 2),
        isTrue,
        reason: 'L14 has orphan tip (path length < 2)',
      );
      // Every body cell sits inside the triangle silhouette.
      for (final arrow in l14.arrows) {
        for (final cell in arrow.path) {
          expect(
            l14.shapeMask![cell.row][cell.col],
            isTrue,
            reason: 'L14 arrow ${arrow.id} cell $cell outside triangle',
          );
        }
      }

      // L15–L30: shaped Expert + solvable + cells inside mask.
      for (var i = 14; i < 30; i++) {
        final level = repo.levels[i];
        expect(level.levelNumber, i + 1);
        expect(level.difficulty, LevelDifficulty.expert);
        expect(level.shapeMask, isNotNull);
        expect(level.arrows.length, greaterThanOrEqualTo(18));
        expect(level.arrows.where((a) => a.isMultiCell).length,
            greaterThanOrEqualTo(18));
        // Nested Expert: no floating single-cell tip triangles.
        expect(
          level.arrows.every((a) => a.path.length >= 2),
          isTrue,
          reason: 'L${level.levelNumber} has orphan tip (path length < 2)',
        );
        for (final arrow in level.arrows) {
          for (final cell in arrow.path) {
            expect(
              level.shapeMask![cell.row][cell.col],
              isTrue,
              reason: 'L${level.levelNumber} ${arrow.id} outside shape',
            );
          }
        }
        // No head-on tip pairs on the same row/column (▸…◂ / ▲…▼).
        for (var ai = 0; ai < level.arrows.length; ai++) {
          final a = level.arrows[ai];
          for (var bi = ai + 1; bi < level.arrows.length; bi++) {
            final b = level.arrows[bi];
            if (a.row == b.row && a.col != b.col) {
              final left = a.col < b.col ? a : b;
              final right = a.col < b.col ? b : a;
              expect(
                !(left.direction == ArrowDirection.right &&
                    right.direction == ArrowDirection.left),
                isTrue,
                reason:
                    'L${level.levelNumber} tips face on row ${a.row}: ${left.id}/${right.id}',
              );
            }
            if (a.col == b.col && a.row != b.row) {
              final top = a.row < b.row ? a : b;
              final bottom = a.row < b.row ? b : a;
              expect(
                !(top.direction == ArrowDirection.down &&
                    bottom.direction == ArrowDirection.up),
                isTrue,
                reason:
                    'L${level.levelNumber} tips face on col ${a.col}: ${top.id}/${bottom.id}',
              );
            }
          }
        }
      }

      // All campaign levels solvable via placement reverse order.
      for (final level in repo.levels) {
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
    });
  });
}
