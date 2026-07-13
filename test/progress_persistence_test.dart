import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:arrow_drift/data/repositories/progress_repository.dart';
import 'package:arrow_drift/features/gameplay/game_controller.dart';
import 'package:arrow_drift/data/repositories/level_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
  });

  test('fresh install defaults: currentLevel=1, hasSeenTutorial=false', () async {
    final prefs = await SharedPreferences.getInstance();
    final repo = ProgressRepository(prefs);

    expect(repo.getCurrentLevel(), 1);
    expect(repo.getHasSeenTutorial(), isFalse);
  });

  test('saveProgress advances currentLevel; tutorial flag persists', () async {
    final prefs = await SharedPreferences.getInstance();
    final repo = ProgressRepository(prefs);

    await repo.saveProgress(3);
    expect(repo.getCurrentLevel(), 4);
    expect(prefs.getInt(ProgressRepository.currentLevelKey), 4);

    await repo.setHasSeenTutorial(true);
    expect(repo.getHasSeenTutorial(), isTrue);
    expect(prefs.getBool(ProgressRepository.hasSeenTutorialKey), isTrue);
  });

  test('retry resets board state without changing stored currentLevel', () async {
    final prefs = await SharedPreferences.getInstance();
    final repo = ProgressRepository(prefs);
    await repo.saveProgress(2); // currentLevel -> 3
    expect(repo.getCurrentLevel(), 3);

    final level = LevelRepository().getLevel(3);
    final controller = GameController(level);
    final free = controller.state.arrows.firstWhere(
      (a) => !isArrowBlocked(arrow: a, arrows: controller.state.arrows),
    );
    controller.tapArrow(free.id);
    expect(controller.state.arrows.any((a) => a.isRemoved), isTrue);

    controller.resetLevel();
    expect(controller.state.arrows.every((a) => !a.isRemoved), isTrue);
    expect(controller.state.heartsLeft, level.heartsAllowed);
    expect(controller.state.hintsLeft, level.hintsAllowed);
    expect(controller.state.isLost, isFalse);

    // Storage unchanged by retry.
    expect(repo.getCurrentLevel(), 3);
  });

  test('stars: 0 lost=3, 1 lost=2, 2+ lost=1', () {
    int stars(int left, int allowed) {
      final lost = allowed - left;
      if (lost <= 0) return 3;
      if (lost == 1) return 2;
      return 1;
    }

    expect(stars(5, 5), 3);
    expect(stars(4, 5), 2);
    expect(stars(3, 5), 1);
    expect(stars(1, 5), 1);
  });

  test('Snapchat streak: only today counts; past backfill does not save', () async {
    final prefs = await SharedPreferences.getInstance();
    final repo = ProgressRepository(prefs);
    final day13 = DateTime(2026, 7, 13);
    final day12 = DateTime(2026, 7, 12);
    final day11 = DateTime(2026, 7, 11);

    // Clear today → streak 1
    await repo.markDailyCompleted(day13, now: day13);
    expect(repo.getCurrentStreak(now: day13), 1);

    // Past day backfill does not change streak
    await repo.markDailyCompleted(day12, now: day13);
    expect(repo.getCurrentStreak(now: day13), 1);
    expect(repo.isDailyCompleted(day12), isTrue);

    // Next real day today-clear → streak 2
    final day14 = DateTime(2026, 7, 14);
    await repo.markDailyCompleted(day14, now: day14);
    expect(repo.getCurrentStreak(now: day14), 2);

    // Skip a day → streak dead until today is cleared again
    final day16 = DateTime(2026, 7, 16);
    expect(repo.getCurrentStreak(now: day16), 0);
    await repo.markDailyCompleted(day16, now: day16);
    expect(repo.getCurrentStreak(now: day16), 1);

    // Completing day11 later still no streak bump
    await repo.markDailyCompleted(day11, now: day16);
    expect(repo.getCurrentStreak(now: day16), 1);
  });
}
