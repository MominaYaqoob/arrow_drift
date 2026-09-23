import 'package:flutter_test/flutter_test.dart';

import 'package:arrow_drift/data/models/level_model.dart';
import 'package:arrow_drift/data/repositories/campaign_shapes.dart';
import 'package:arrow_drift/data/repositories/level_repository.dart';
import 'package:arrow_drift/features/gameplay/game_controller.dart';

void main() {
  test(
    'daily level is long maze pack in one of six shapes',
    () {
      final repo = LevelRepository();
      final day = DateTime(2026, 9, 24);
      final level = repo.getDailyLevel(day);

      expect(level.difficulty, LevelDifficulty.expert);
      expect(level.heartsAllowed, 3);
      expect(level.hintsAllowed, 2);
      expect(level.shapeMask, isNotNull);
      expect(level.arrows.length, dailyArrowCount(day));
      expect(level.arrows.every((a) => a.path.length >= 2), isTrue);

      // Long-arrow maze pack: most of the level's length lives in mid/long arrows.
      final medium = level.arrows
          .where((a) => a.path.length >= 4 && a.path.length <= 8)
          .length;
      final tall = level.arrows.where((a) => a.path.length >= 6).length;
      expect(medium, greaterThanOrEqualTo(8));
      expect(tall + medium, greaterThanOrEqualTo(20));

      // Pack playable cells tightly — little free white space.
      var playable = 0;
      for (final row in level.shapeMask!) {
        for (final cell in row) {
          if (cell) playable++;
        }
      }
      final occupied = level.arrows.fold<int>(0, (s, a) => s + a.path.length);
      expect(occupied / playable, greaterThan(0.65));

      for (final arrow in level.arrows) {
        for (final cell in arrow.path) {
          expect(
            level.shapeMask![cell.row][cell.col],
            isTrue,
            reason: 'daily ${arrow.id} outside shape',
          );
        }
      }

      final arrows = cloneArrows(level.arrows);
      var safety = 0;
      while (arrows.any((a) => !a.isRemoved) && safety < 4000) {
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
          }
        }
        expect(freeIds, isNotEmpty, reason: 'stuck mid-solve at wave $safety');
        for (final id in freeIds) {
          final i = arrows.indexWhere((a) => a.id == id);
          arrows[i] = arrows[i].copyWith(isRemoved: true);
        }
      }
      expect(arrows.every((a) => a.isRemoved), isTrue);
    },
    timeout: const Timeout(Duration(minutes: 3)),
  );

  test(
    'daily shapes rotate across days and never repeat back-to-back',
    () {
      final repo = LevelRepository();
      final days = [
        for (var i = 0; i < 12; i++)
          DateTime(2026, 9, 22).add(Duration(days: i)),
      ];
      String? previous;
      for (final day in days) {
        final level = repo.getDailyLevel(day);
        final shape = dailyShape(day);
        expect(level.difficulty, LevelDifficulty.expert);
        expect(level.heartsAllowed, 3);
        expect(level.shapeMask, isNotNull);
        expect(level.arrows.length, dailyArrowCount(day), reason: '$day');
        expect(kDailyShapes, contains(shape));
        expect(shape, isNot(previous), reason: '$day shape repeat');
        previous = shape;
      }
    },
    timeout: const Timeout(Duration(minutes: 4)),
  );

  test(
    'same date always gives the same board (stable seed)',
    () {
      final repoA = LevelRepository();
      final repoB = LevelRepository();
      final day = DateTime(2026, 10, 3);
      final a = repoA.getDailyLevel(day);
      final b = repoB.getDailyLevel(day);
      expect(a.arrows.length, b.arrows.length);
      expect(a.gridRows, b.gridRows);
      expect(a.gridCols, b.gridCols);
      expect(a.arrows.first.id, b.arrows.first.id);
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );
}
