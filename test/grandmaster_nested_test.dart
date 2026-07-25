import 'package:flutter_test/flutter_test.dart';

import 'package:arrow_drift/data/models/level_model.dart';
import 'package:arrow_drift/data/repositories/level_repository.dart';

void main() {
  test('Grandmaster boards are nested polylines in arrow band', () {
    final repo = LevelRepository();
    for (final n in [801, 850, 999, 1000]) {
      final level = repo.getLevel(n);
      expect(level.difficulty, LevelDifficulty.grandmaster, reason: 'L$n');
      expect(level.arrows.length, greaterThanOrEqualTo(210), reason: 'L$n');
      expect(level.arrows.length, lessThanOrEqualTo(250), reason: 'L$n');
      // Tip-only fallback used to produce pathless arrows — must not return.
      for (final a in level.arrows) {
        expect(
          a.path.length,
          greaterThanOrEqualTo(2),
          reason: 'L$n ${a.id} must be a nested polyline',
        );
      }
    }
  });
}
