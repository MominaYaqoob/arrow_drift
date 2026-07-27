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

  test('Snapchat streak: midnight window; timer only while today pending',
      () async {
    final prefs = await SharedPreferences.getInstance();
    final repo = ProgressRepository(prefs);
    final day13 = DateTime(2026, 7, 13, 10, 0); // Mon 10:00
    final day12 = DateTime(2026, 7, 12);
    final day11 = DateTime(2026, 7, 11);

    // Before any clear: no streak, no timer.
    expect(repo.getCurrentStreak(now: day13), 0);
    expect(repo.getStreakRemaining(now: day13), Duration.zero);
    expect(repo.isTodayStreakPending(now: day13), isFalse);

    // Clear today → streak 1; timer HIDDEN (today already done).
    await repo.markDailyCompleted(day13, now: day13);
    expect(repo.getCurrentStreak(now: day13), 1);
    expect(repo.getStreakRemaining(now: day13), Duration.zero);
    expect(repo.isTodayStreakCleared(now: day13), isTrue);
    expect(repo.isTodayStreakPending(now: day13), isFalse);

    // Past day backfill: stars only, no streak/timer change.
    await repo.markDailyCompleted(day12, now: day13);
    expect(repo.getCurrentStreak(now: day13), 1);
    expect(repo.isDailyCompleted(day12), isTrue);
    expect(repo.getStreakRemaining(now: day13), Duration.zero);

    // Next calendar day morning → streak still alive, timer until midnight.
    final day14Morning = DateTime(2026, 7, 14, 8, 0);
    expect(repo.getCurrentStreak(now: day14Morning), 1);
    expect(repo.isTodayStreakPending(now: day14Morning), isTrue);
    expect(
      repo.getStreakRemaining(now: day14Morning),
      DateTime(2026, 7, 15).difference(day14Morning),
    );
    expect(repo.isStreakUrgent(now: day14Morning), isFalse);

    // Clear day 14 → streak 2; timer hides again.
    await repo.markDailyCompleted(day14Morning, now: day14Morning);
    expect(repo.getCurrentStreak(now: day14Morning), 2);
    expect(repo.getStreakRemaining(now: day14Morning), Duration.zero);

    // Miss a full calendar day → streak dies.
    final day16 = DateTime(2026, 7, 16, 9, 0);
    expect(repo.getCurrentStreak(now: day16), 0);
    expect(repo.getStreakRemaining(now: day16), Duration.zero);

    // Fresh clear → streak 1, no timer (today done).
    await repo.markDailyCompleted(day16, now: day16);
    expect(repo.getCurrentStreak(now: day16), 1);
    expect(repo.getStreakRemaining(now: day16), Duration.zero);

    // Past backfill still no bump.
    await repo.markDailyCompleted(day11, now: day16);
    expect(repo.getCurrentStreak(now: day16), 1);
  });

  test('Snapchat streak: same-day re-complete keeps streak; no timer', () async {
    final prefs = await SharedPreferences.getInstance();
    final repo = ProgressRepository(prefs);
    final t0 = DateTime(2026, 7, 13, 10, 0);
    await repo.markDailyCompleted(t0, now: t0);
    expect(repo.getStreakDeadline(now: t0), isNull);

    final t1 = DateTime(2026, 7, 13, 15, 0);
    await repo.markDailyCompleted(t1, now: t1);
    expect(repo.getCurrentStreak(now: t1), 1);
    expect(repo.getStreakRemaining(now: t1), Duration.zero);
    expect(repo.getStreakDeadline(now: t1), isNull);
  });

  test('Snapchat streak: last 4h of pending day is urgent', () async {
    final prefs = await SharedPreferences.getInstance();
    final repo = ProgressRepository(prefs);
    final day13 = DateTime(2026, 7, 13, 10, 0);
    await repo.markDailyCompleted(day13, now: day13);

    final day14Late = DateTime(2026, 7, 14, 21, 30); // 2.5h to midnight
    expect(repo.isTodayStreakPending(now: day14Late), isTrue);
    expect(repo.isStreakUrgent(now: day14Late), isTrue);
    expect(
      repo.getStreakRemaining(now: day14Late),
      DateTime(2026, 7, 15).difference(day14Late),
    );
  });
}