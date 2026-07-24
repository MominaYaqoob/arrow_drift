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

  test('Snapchat streak: 24h timer starts on complete; expires; restarts fresh',
      () async {
    final prefs = await SharedPreferences.getInstance();
    final repo = ProgressRepository(prefs);
    final day13 = DateTime(2026, 7, 13, 10, 0); // Mon 10:00
    final day12 = DateTime(2026, 7, 12);
    final day11 = DateTime(2026, 7, 11);

    // Clear today → streak 1 + 24h window starts (not before).
    expect(repo.getCurrentStreak(now: day13), 0);
    expect(repo.getStreakRemaining(now: day13), Duration.zero);
    await repo.markDailyCompleted(day13, now: day13);
    expect(repo.getCurrentStreak(now: day13), 1);
    expect(
      repo.getStreakRemaining(now: day13),
      ProgressRepository.streakWindow,
    );

    // Past day backfill does not change streak or timer
    await repo.markDailyCompleted(day12, now: day13);
    expect(repo.getCurrentStreak(now: day13), 1);
    expect(repo.isDailyCompleted(day12), isTrue);
    expect(
      repo.getStreakRemaining(now: day13),
      ProgressRepository.streakWindow,
    );

    // Next calendar day, still inside 24h → streak 2 + fresh timer
    final day14Morning = DateTime(2026, 7, 14, 8, 0); // +22h
    await repo.markDailyCompleted(day14Morning, now: day14Morning);
    expect(repo.getCurrentStreak(now: day14Morning), 2);
    expect(
      repo.getStreakRemaining(now: day14Morning),
      ProgressRepository.streakWindow,
    );

    // Miss the window → streak + timer reset
    final afterExpiry = DateTime(2026, 7, 15, 9, 0); // >24h after day14 8:00
    expect(repo.getCurrentStreak(now: afterExpiry), 0);
    expect(repo.getStreakRemaining(now: afterExpiry), Duration.zero);

    // Complete again → fresh streak 1 + new timer
    await repo.markDailyCompleted(afterExpiry, now: afterExpiry);
    expect(repo.getCurrentStreak(now: afterExpiry), 1);
    expect(
      repo.getStreakRemaining(now: afterExpiry),
      ProgressRepository.streakWindow,
    );

    // Completing day11 later still no streak bump / timer restart
    await repo.markDailyCompleted(day11, now: afterExpiry);
    expect(repo.getCurrentStreak(now: afterExpiry), 1);
  });

  test('Snapchat streak: same-day re-complete does not restart timer', () async {
    final prefs = await SharedPreferences.getInstance();
    final repo = ProgressRepository(prefs);
    final t0 = DateTime(2026, 7, 13, 10, 0);
    await repo.markDailyCompleted(t0, now: t0);
    final deadline = repo.getStreakDeadline(now: t0)!;

    final t1 = DateTime(2026, 7, 13, 15, 0);
    await repo.markDailyCompleted(t1, now: t1);
    expect(repo.getCurrentStreak(now: t1), 1);
    expect(repo.getStreakDeadline(now: t1), deadline);
  });
}