import 'package:flutter_test/flutter_test.dart';

import 'package:arrow_drift/data/models/arrow_model.dart';
import 'package:arrow_drift/data/repositories/level_repository.dart';
import 'package:arrow_drift/features/gameplay/game_controller.dart';

void main() {
  group('isArrowBlocked', () {
    test('up is blocked by an active arrow above in the same column', () {
      final arrows = [
        ArrowModel(id: 'a', row: 2, col: 1, direction: ArrowDirection.up),
        ArrowModel(id: 'b', row: 0, col: 1, direction: ArrowDirection.right),
      ];
      expect(isArrowBlocked(arrow: arrows[0], arrows: arrows), isTrue);
      expect(isArrowBlocked(arrow: arrows[1], arrows: arrows), isFalse);
    });

    test('removed blockers are ignored', () {
      final arrows = [
        ArrowModel(id: 'a', row: 2, col: 1, direction: ArrowDirection.up),
        ArrowModel(
          id: 'b',
          row: 0,
          col: 1,
          direction: ArrowDirection.right,
          isRemoved: true,
        ),
      ];
      expect(isArrowBlocked(arrow: arrows[0], arrows: arrows), isFalse);
    });
  });

  group('GameController.tapArrow', () {
    test('removes free arrows and shakes blocked ones (hearts drop)', () {
      final level = LevelRepository().getLevel(1);
      final controller = GameController(level);

      // Keep tapping free arrows until none remain or board clears.
      var safety = 0;
      while (!controller.state.isWon &&
          !controller.state.isLost &&
          safety < 100) {
        safety++;
        final active = controller.state.arrows
            .where((arrow) => !arrow.isRemoved)
            .toList();
        if (active.isEmpty) break;

        final free = active.where(
          (arrow) => !isArrowBlocked(
            arrow: arrow,
            arrows: controller.state.arrows,
          ),
        );

        if (free.isNotEmpty) {
          final target = free.first;
          final beforeHearts = controller.state.heartsLeft;
          final result = controller.tapArrow(target.id);
          expect(result, TapArrowResult.removed);
          expect(
            controller.state.arrows
                .firstWhere((arrow) => arrow.id == target.id)
                .isRemoved,
            isTrue,
          );
          expect(controller.state.heartsLeft, beforeHearts);
        } else {
          final target = active.first;
          final beforeHearts = controller.state.heartsLeft;
          final result = controller.tapArrow(target.id);
          expect(result, TapArrowResult.wrongTap);
          expect(
            controller.state.arrows
                .firstWhere((arrow) => arrow.id == target.id)
                .isRemoved,
            isFalse,
          );
          expect(controller.state.heartsLeft, beforeHearts - 1);
          break;
        }
      }

      expect(controller.state.isWon || controller.state.heartsLeft < level.heartsAllowed,
          isTrue);
    });

    test('levels 1-10 can be fully cleared by always tapping a free arrow', () {
      final repo = LevelRepository();
      for (var n = 1; n <= 10; n++) {
        final level = repo.getLevel(n);
        final controller = GameController(level);
        var safety = 0;

        while (!controller.state.isWon && safety < 200) {
          safety++;
          final free = controller.state.arrows.where(
            (arrow) =>
                !arrow.isRemoved &&
                !isArrowBlocked(
                  arrow: arrow,
                  arrows: controller.state.arrows,
                  gridRows: level.gridRows,
                  gridCols: level.gridCols,
                  shapeMask: level.shapeMask,
                ),
          );
          expect(
            free.isNotEmpty,
            isTrue,
            reason: 'Level $n stuck with no free arrow mid-solve',
          );
          final result = controller.tapArrow(free.first.id);
          expect(result, TapArrowResult.removed);
        }

        expect(controller.state.isWon, isTrue, reason: 'Level $n should be won');
        expect(controller.state.heartsLeft, level.heartsAllowed);
      }
    });

    test('retry via resetLevel restores the same level from scratch', () {
      final level = LevelRepository().getLevel(1);
      final controller = GameController(level);
      final firstFree = controller.state.arrows.firstWhere(
        (arrow) => !isArrowBlocked(arrow: arrow, arrows: controller.state.arrows),
      );
      controller.tapArrow(firstFree.id);
      expect(controller.state.arrows.any((a) => a.isRemoved), isTrue);

      // Force a loss by repeatedly tapping a blocked arrow if one exists.
      for (var i = 0; i < 10 && !controller.state.isLost; i++) {
        final blocked = controller.state.arrows.where(
          (arrow) =>
              !arrow.isRemoved &&
              isArrowBlocked(arrow: arrow, arrows: controller.state.arrows),
        );
        if (blocked.isEmpty) break;
        controller.tapArrow(blocked.first.id);
      }

      controller.resetLevel();
      expect(controller.state.heartsLeft, level.heartsAllowed);
      expect(controller.state.hintsLeft, level.hintsAllowed);
      expect(controller.state.arrows.every((a) => !a.isRemoved), isTrue);
      expect(controller.state.isLost, isFalse);
      expect(controller.state.isWon, isFalse);
      expect(controller.state.level.levelNumber, 1);
    });
  });
}
