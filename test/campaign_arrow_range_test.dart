import 'package:flutter_test/flutter_test.dart';

import 'package:arrow_drift/data/models/level_model.dart';
import 'package:arrow_drift/data/repositories/level_repository.dart';

/// Asserts live boards stay inside the configured campaign arrow bands.
void main() {
  (int min, int max) bandFor(int n) {
    if (n == 1) return (3, 3);
    if (n <= 5) return (40, 50);
    if (n <= 20) return (50, 80);
    if (n <= 100) return (80, 100);
    if (n <= 199) return (100, 150);
    if (n <= 500) return (150, 180);
    if (n <= 650) return (180, 190);
    if (n <= 800) return (190, 210);
    return (210, 250);
  }

  LevelDifficulty difficultyFor(int n) {
    if (n == 1) return LevelDifficulty.easy;
    if (n <= 5) return LevelDifficulty.easy;
    if (n <= 20) return LevelDifficulty.medium;
    if (n <= 100) return LevelDifficulty.hard;
    if (n <= 199) return LevelDifficulty.hardPlus;
    if (n <= 500) return LevelDifficulty.expert;
    if (n <= 650) return LevelDifficulty.expertPlus;
    if (n <= 800) return LevelDifficulty.master;
    return LevelDifficulty.grandmaster;
  }

  test('campaign arrow ranges match configured bands', () {
    final repo = LevelRepository();
    expect(repo.levelCount, 1000);

    final sample = <int>{
      1,
      2,
      5,
      6,
      20,
      21,
      100,
      101,
      199,
      200,
      500,
      501,
      650,
      651,
      800,
      801,
      1000,
      for (var n = 2; n <= 5; n++) n,
      for (var n = 6; n <= 20; n += 3) n,
      for (var n = 21; n <= 100; n += 19) n,
      for (var n = 101; n <= 199; n += 23) n,
      for (var n = 200; n <= 500; n += 50) n,
      for (var n = 501; n <= 650; n += 40) n,
      for (var n = 651; n <= 800; n += 40) n,
      for (var n = 801; n <= 1000; n += 50) n,
    };

    for (final n in sample.toList()..sort()) {
      final level = repo.getLevel(n);
      final (min, max) = bandFor(n);
      expect(level.levelNumber, n, reason: 'L$n number');
      expect(level.difficulty, difficultyFor(n), reason: 'L$n difficulty');
      expect(
        level.arrows.length,
        inInclusiveRange(min, max),
        reason: 'L$n arrows=${level.arrows.length} expected $min–$max',
      );
    }
  });

  test('after Easy, arrow counts ramp upward within each band', () {
    final repo = LevelRepository();
    expect(
      repo.getLevel(6).arrows.length,
      lessThan(repo.getLevel(20).arrows.length),
    );
    expect(
      repo.getLevel(21).arrows.length,
      lessThan(repo.getLevel(100).arrows.length),
    );
    expect(
      repo.getLevel(101).arrows.length,
      lessThan(repo.getLevel(199).arrows.length),
    );
    expect(
      repo.getLevel(200).arrows.length,
      lessThan(repo.getLevel(500).arrows.length),
    );
    expect(
      repo.getLevel(801).arrows.length,
      lessThanOrEqualTo(repo.getLevel(1000).arrows.length),
    );
  });
}
