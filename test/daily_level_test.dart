import 'package:flutter_test/flutter_test.dart';

import 'package:arrow_drift/data/models/level_model.dart';
import 'package:arrow_drift/data/repositories/level_repository.dart';
import 'package:arrow_drift/features/gameplay/game_controller.dart';

void main() {
  test('daily level is nested Expert maze (bent polylines)', () {
    final repo = LevelRepository();
    final level = repo.getDailyLevel(DateTime(2026, 7, 13));

    expect(level.difficulty, LevelDifficulty.expert);
    expect(level.heartsAllowed, 3);
    expect(level.arrows.length, greaterThanOrEqualTo(18));

    final multi = level.arrows.where((a) => a.isMultiCell).length;
    expect(multi, greaterThanOrEqualTo(8));

    // Solvable: clear waves until empty.
    final arrows = cloneArrows(level.arrows);
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
}
