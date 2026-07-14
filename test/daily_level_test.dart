import 'package:flutter_test/flutter_test.dart';

import 'package:arrow_drift/data/models/level_model.dart';
import 'package:arrow_drift/data/repositories/level_repository.dart';
import 'package:arrow_drift/features/gameplay/game_controller.dart';

void main() {
  test('daily level is large shaped Expert maze (above campaign size)', () {
    final repo = LevelRepository();
    final level = repo.getDailyLevel(DateTime(2026, 7, 13));

    expect(level.difficulty, LevelDifficulty.expert);
    expect(level.heartsAllowed, 3);
    expect(level.shapeMask, isNotNull);
    expect(level.gridRows, greaterThanOrEqualTo(16));
    expect(level.gridCols, greaterThanOrEqualTo(16));
    expect(level.arrows.length, greaterThanOrEqualTo(18));
    expect(level.arrows.every((a) => a.path.length >= 2), isTrue);

    final multi = level.arrows.where((a) => a.isMultiCell).length;
    expect(multi, level.arrows.length);

    // Cells live inside the daily silhouette.
    for (final arrow in level.arrows) {
      for (final cell in arrow.path) {
        expect(
          level.shapeMask![cell.row][cell.col],
          isTrue,
          reason: 'daily ${arrow.id} outside shape',
        );
      }
    }

    // Solvable: clear waves until empty.
    final arrows = cloneArrows(level.arrows);
    var safety = 0;
    while (arrows.any((a) => !a.isRemoved) && safety < 800) {
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
  });

  test('daily shapes rotate across days and stay bigger than mid campaign', () {
    final repo = LevelRepository();
    final a = repo.getDailyLevel(DateTime(2026, 1, 2));
    final b = repo.getDailyLevel(DateTime(2026, 1, 5));
    final c = repo.getDailyLevel(DateTime(2026, 6, 20));

    for (final level in [a, b, c]) {
      expect(level.shapeMask, isNotNull);
      expect(level.gridRows * level.gridCols, greaterThanOrEqualTo(16 * 16));
      expect(level.arrows.length, greaterThanOrEqualTo(18));
    }

    // Different calendar days should not share identical footprints.
    expect(
      '${a.gridRows}x${a.gridCols}:${a.arrows.length}',
      isNot(equals('${b.gridRows}x${b.gridCols}:${b.arrows.length}')),
    );
  });
}
