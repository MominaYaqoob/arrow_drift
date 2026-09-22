import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:arrow_drift/data/repositories/level_repository.dart';
import 'package:arrow_drift/features/gameplay/game_controller.dart';

void main() {
  test('leaving a level and coming back resumes the same board', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final level = LevelRepository().getLevel(3);

    // Screen open → tap one free arrow.
    final sub = container.listen(gameControllerProvider(level), (_, _) {});
    final controller = container.read(gameControllerProvider(level).notifier);
    final free = findFreeArrow(controller.state)!;
    controller.tapArrow(free.id);
    // Screen closed.
    sub.close();
    await Future<void>.delayed(Duration.zero);

    // Screen reopened → still the same in-progress board.
    final state = container.read(gameControllerProvider(level));
    expect(state.arrows.firstWhere((a) => a.id == free.id).isRemoved, isTrue);
  });

  test('older boards are released once newer levels are opened', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final repo = LevelRepository();
    final first = repo.getLevel(2);

    final controller = container.read(gameControllerProvider(first).notifier);
    controller.tapArrow(findFreeArrow(controller.state)!.id);

    for (final n in [3, 4, 5, 6]) {
      container.read(gameControllerProvider(repo.getLevel(n)));
    }
    await Future<void>.delayed(Duration.zero);

    // Level 2 was freed, so it starts fresh again.
    final state = container.read(gameControllerProvider(first));
    expect(state.arrows.every((a) => !a.isRemoved), isTrue);
  });
}
