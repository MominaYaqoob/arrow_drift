import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:arrow_drift/data/models/arrow_model.dart';
import 'package:arrow_drift/data/models/level_model.dart';

void main() {
  test('LevelModel JSON roundtrip keeps arrows, mask, and difficulty', () {
    final original = LevelModel(
      levelNumber: 7,
      gridRows: 4,
      gridCols: 4,
      heartsAllowed: 3,
      hintsAllowed: 2,
      difficulty: LevelDifficulty.expert,
      shapeMask: [
        [true, true, false, false],
        [true, true, true, false],
        [false, true, true, true],
        [false, false, true, true],
      ],
      arrows: [
        ArrowModel(
          id: '7-0',
          row: 0,
          col: 1,
          direction: ArrowDirection.right,
          path: const [GridCell(0, 0), GridCell(0, 1)],
        ),
      ],
    );

    final encoded = jsonEncode(original.toJson());
    final decoded = jsonDecode(encoded);
    final restored =
        LevelModel.fromJson(Map<String, dynamic>.from(decoded as Map));

    expect(restored.levelNumber, original.levelNumber);
    expect(restored.gridRows, 4);
    expect(restored.difficulty, LevelDifficulty.expert);
    expect(restored.shapeMask, original.shapeMask);
    expect(restored.arrows, hasLength(1));
    expect(restored.arrows.first.id, '7-0');
    expect(restored.arrows.first.direction, ArrowDirection.right);
    expect(restored.arrows.first.path, const [GridCell(0, 0), GridCell(0, 1)]);
  });
}
