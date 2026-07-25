import 'package:flutter_test/flutter_test.dart';

import 'package:arrow_drift/data/models/level_model.dart';
import 'package:arrow_drift/data/repositories/level_repository.dart';

void main() {
  test('L501+ dense tiers open within configured arrow bands', () {
    final repo = LevelRepository();
    final cases = <(int, int, int, LevelDifficulty)>[
      (501, 180, 190, LevelDifficulty.expertPlus),
      (502, 180, 190, LevelDifficulty.expertPlus),
      (650, 180, 190, LevelDifficulty.expertPlus),
      (651, 190, 210, LevelDifficulty.master),
      (800, 190, 210, LevelDifficulty.master),
      (801, 210, 250, LevelDifficulty.grandmaster),
      (1000, 210, 250, LevelDifficulty.grandmaster),
    ];
    for (final (n, min, max, diff) in cases) {
      final level = repo.getLevel(n);
      expect(level.levelNumber, n, reason: 'L$n');
      expect(level.difficulty, diff, reason: 'L$n');
      expect(
        level.arrows.length,
        inInclusiveRange(min, max),
        reason: 'L$n arrows=${level.arrows.length} expected $min–$max',
      );
    }
  });
}
