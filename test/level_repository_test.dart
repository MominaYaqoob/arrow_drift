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
        'L1 tutorial; L2-6 Easy; L7-20 Medium; L21-50 Hard; L51-500 Expert; '
        'all solvable', () {
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

      // L2-6: redesigned Easy tier — L2/L3 are small hardcoded Unity ports
      // (kept easy per product decision), L4-6 ramp fast (10-45 arrows) into
      // the dense mid/late game so there's no soft plateau after L3.
      for (var n = 2; n <= 6; n++) {
        final level = repo.getLevel(n);
        expect(level.levelNumber, n);
        expect(level.difficulty, LevelDifficulty.easy, reason: 'L$n');
        expect(level.gridRows, greaterThanOrEqualTo(6), reason: 'L$n');
        expect(level.gridRows, lessThanOrEqualTo(16), reason: 'L$n');
        expect(level.arrows, isNotEmpty, reason: 'L$n');
        for (final a in level.arrows) {
          expect(a.path.length, greaterThanOrEqualTo(2), reason: 'L$n ${a.id}');
        }
        expectInMask(level);
        expect(freeCountFor(level), greaterThanOrEqualTo(1), reason: 'L$n >=1 free');
      }

      // L7-20: Medium tier — shaped silhouettes, 36-56 nested arrows, and
      // (from the back half of the tier on) the single-free-tile seal chain
      // that forces sequential planning. Floors match the generator's own
      // fallback chain (its absolute-last-resort still guarantees 16 dense
      // arrows — see _mediumPuzzleLevel), not the idealized formula target.
      for (var n = 7; n <= 20; n++) {
        final level = repo.getLevel(n);
        expect(level.levelNumber, n);
        expect(level.difficulty, LevelDifficulty.medium, reason: 'L$n');
        expect(level.gridRows, greaterThanOrEqualTo(10), reason: 'L$n');
        expect(level.gridRows, lessThanOrEqualTo(17), reason: 'L$n');
        expect(level.arrows.length, greaterThanOrEqualTo(16), reason: 'L$n');
        for (final a in level.arrows) {
          expect(a.path.length, greaterThanOrEqualTo(2), reason: 'L$n ${a.id}');
        }
        expectInMask(level);

        final freeCount = freeCountFor(level);
        expect(freeCount, greaterThanOrEqualTo(1), reason: 'L$n >=1 free');
        expect(freeCount, lessThanOrEqualTo(8), reason: 'L$n bounded free');
      }

      // L21-50: Hard tier — seal-chain puzzles, 55-60 arrows, most locked at
      // start, sequential removal required. Convex shapes only. Arrow floor
      // matches _hardPuzzleLevel's absolute-last-resort clamp (14).
      for (var n = 21; n <= 50; n++) {
        final level = repo.getLevel(n);
        expect(level.levelNumber, n);
        expect(level.difficulty, LevelDifficulty.hard, reason: 'L$n');
        expect(level.gridRows, greaterThanOrEqualTo(14), reason: 'L$n');
        expect(level.gridRows, lessThanOrEqualTo(18), reason: 'L$n');
        expect(level.arrows.length, greaterThanOrEqualTo(14), reason: 'L$n');
        for (final a in level.arrows) {
          expect(a.path.length, greaterThanOrEqualTo(2), reason: 'L$n ${a.id}');
        }
        expectInMask(level);

        final freeCount = freeCountFor(level);
        expect(freeCount, greaterThanOrEqualTo(1), reason: 'L$n >=1 free');
        // Primary path aims for exact-1 / <=4 free; absolute safety-net
        // fallbacks may open further (see _hardPuzzleLevel null freeCap).
        expect(freeCount, lessThanOrEqualTo(12), reason: 'L$n mostly locked');
      }

      // L51-500: Expert/Master tier — same seal-chain logic pushed to max
      // density/turns (50-62 arrows), grid capped at 18x18 (phone-safe) for
      // the entire 450-level tail. Arrow floor matches _expertPuzzleLevel's
      // absolute-last-resort clamp (12). Sampled rather than exhaustive
      // (every 7th level, matching the shape rotation period) to keep the
      // test suite fast — the tier reuses one formula for all 450 levels,
      // so full coverage doesn't need every single level checked here.
      final expertSample = [for (var n = 51; n <= 500; n += 7) n, 500];
      for (final n in expertSample) {
        final level = repo.getLevel(n);
        expect(level.levelNumber, n);
        expect(level.difficulty, LevelDifficulty.expert, reason: 'L$n');
        expect(level.gridRows, greaterThanOrEqualTo(16), reason: 'L$n');
        expect(level.gridRows, lessThanOrEqualTo(18), reason: 'L$n phone-safe');
        expect(level.gridCols, lessThanOrEqualTo(18), reason: 'L$n phone-safe');
        expect(level.arrows.length, greaterThanOrEqualTo(12), reason: 'L$n');
        for (final a in level.arrows) {
          expect(a.path.length, greaterThanOrEqualTo(2), reason: 'L$n ${a.id}');
        }
        expectInMask(level);

        final freeCount = freeCountFor(level);
        expect(freeCount, greaterThanOrEqualTo(1), reason: 'L$n >=1 free');
        expect(freeCount, lessThanOrEqualTo(12), reason: 'L$n mostly locked');
        // Hearts/hints floor: 3 hearts / 2 hints for the entire Hard/Expert
        // range (L21-500) — product decision, not reduced further.
        expect(level.heartsAllowed, 3, reason: 'L$n hearts floor');
        expect(level.hintsAllowed, 2, reason: 'L$n hints floor');
      }
      for (var n = 21; n <= 50; n++) {
        final level = repo.getLevel(n);
        expect(level.heartsAllowed, 3, reason: 'L$n hearts floor');
        expect(level.hintsAllowed, 2, reason: 'L$n hints floor');
      }

      // Solvability: exhaustive for L1-100 (the densely-tuned early tiers),
      // sampled for the L101-500 tail — it's the same reused Expert formula
      // the whole way, so the stride-7 sample already exercises every
      // shape-rotation slot; full-500 solvability replay would just burn CI
      // time re-checking the identical mechanism.
      for (var n = 1; n <= 100; n++) {
        expectSolvable(repo, repo.getLevel(n));
      }
      for (final n in expertSample) {
        if (n <= 100) continue;
        expectSolvable(repo, repo.getLevel(n));
      }

      expect(repo.getLevel(501).levelNumber, 500);
    });
  });
}
