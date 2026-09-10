import 'package:flutter_test/flutter_test.dart';

import 'package:arrow_drift/data/models/level_model.dart';
import 'package:arrow_drift/data/repositories/level_repository.dart';
import 'package:arrow_drift/features/gameplay/game_controller.dart';

void main() {
  test('daily level is long dense nested pack with size mix', () {
    final repo = LevelRepository();
    final level = repo.getDailyLevel(DateTime(2026, 7, 13));

    expect(level.difficulty, LevelDifficulty.expert);
    expect(level.heartsAllowed, 3);
    expect(level.gridRows, greaterThanOrEqualTo(22));
    expect(level.gridCols, greaterThanOrEqualTo(22));
    expect(level.arrows.length, greaterThanOrEqualTo(100));
    expect(level.arrows.length, lessThanOrEqualTo(150));
    expect(level.shapeMask, isNotNull);
    expect(level.arrows.every((a) => a.path.length >= 2), isTrue);

    // Nested mid/long pack — leftover crumbs may still be short.
    final medium =
        level.arrows.where((a) => a.path.length >= 4 && a.path.length <= 8).length;
    final tall = level.arrows.where((a) => a.path.length >= 6).length;
    expect(medium, greaterThanOrEqualTo(8));
    expect(tall + medium, greaterThanOrEqualTo(20));

    // Pack playable cells tightly — little free white space.
    var playable = 0;
    if (level.shapeMask != null) {
      for (final row in level.shapeMask!) {
        for (final cell in row) {
          if (cell) playable++;
        }
      }
    } else {
      playable = level.gridRows * level.gridCols;
    }
    final occupied =
        level.arrows.fold<int>(0, (s, a) => s + a.path.length);
    expect(occupied / playable, greaterThan(0.65));

    if (level.shapeMask != null) {
      for (final arrow in level.arrows) {
        for (final cell in arrow.path) {
          expect(
            level.shapeMask![cell.row][cell.col],
            isTrue,
            reason: 'daily ${arrow.id} outside shape',
          );
        }
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
  }, timeout: const Timeout(Duration(minutes: 3)));

  test('daily shapes rotate across days and stay long nested', () {
    final repo = LevelRepository();
    final a = repo.getDailyLevel(DateTime(2026, 1, 2));
    final b = repo.getDailyLevel(DateTime(2026, 1, 5));
    final c = repo.getDailyLevel(DateTime(2026, 6, 20));

    for (final level in [a, b, c]) {
      expect(level.difficulty, LevelDifficulty.expert);
      expect(level.shapeMask, isNotNull);
      expect(level.arrows.length, greaterThanOrEqualTo(100));
      expect(level.arrows.length, lessThanOrEqualTo(150));
      expect(level.gridRows * level.gridCols, greaterThanOrEqualTo(22 * 22));
    }

    expect(
      '${a.gridRows}x${a.gridCols}:${a.arrows.first.id}',
      isNot(equals('${b.gridRows}x${b.gridCols}:${b.arrows.first.id}')),
    );
  }, timeout: const Timeout(Duration(minutes: 4)));

  test('daily shapeIndex 0, 3, 7, 11 still generate within budget', () {
    int shapeIndexFor(DateTime day) {
      final dayOfYear = day.difference(DateTime(day.year)).inDays;
      return (dayOfYear + day.year * 5 + day.month * 3) % 12;
    }

    DateTime dateForShape(int want) {
      var day = DateTime(2026, 1, 1);
      while (shapeIndexFor(day) != want) {
        day = day.add(const Duration(days: 1));
      }
      return day;
    }

    final repo = LevelRepository();
    for (final index in [0, 3, 7, 11]) {
      final day = dateForShape(index);
      expect(shapeIndexFor(day), index);
      final level = repo.getDailyLevel(day);
      expect(level.arrows.length, greaterThanOrEqualTo(100));
      expect(level.arrows.length, lessThanOrEqualTo(150));
      final maxLen =
          level.arrows.map((a) => a.path.length).reduce((a, b) => a > b ? a : b);
      // ignore: avoid_print
      print(
        'shapeIndex=$index date=$day arrows=${level.arrows.length} '
        'grid=${level.gridRows}x${level.gridCols} maxPath=$maxLen',
      );
    }
  }, timeout: const Timeout(Duration(minutes: 8)));
}
