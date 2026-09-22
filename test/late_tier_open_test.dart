import 'package:flutter_test/flutter_test.dart';

import 'package:arrow_drift/data/models/level_model.dart';
import 'package:arrow_drift/data/repositories/campaign_shapes.dart';
import 'package:arrow_drift/data/repositories/level_repository.dart';

void main() {
  test('L501+ tiers open with the planned arrow count', () {
    final repo = LevelRepository();
    final cases = <(int, LevelDifficulty)>[
      (501, LevelDifficulty.expertPlus),
      (502, LevelDifficulty.expertPlus),
      (650, LevelDifficulty.expertPlus),
      (651, LevelDifficulty.master),
      (800, LevelDifficulty.master),
      (801, LevelDifficulty.grandmaster),
      (1000, LevelDifficulty.grandmaster),
    ];
    for (final (n, diff) in cases) {
      final level = repo.getLevel(n);
      expect(level.levelNumber, n, reason: 'L$n');
      expect(level.difficulty, diff, reason: 'L$n');
      expect(level.arrows.length, waveCount(n), reason: 'L$n');
    }
  });
}
