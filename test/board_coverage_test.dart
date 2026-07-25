import 'package:arrow_drift/data/repositories/level_repository.dart';
import 'package:flutter_test/flutter_test.dart';

/// Fraction of in-mask cells consumed by arrow paths.
double _coverage(int level, LevelRepository repo) {
  final model = repo.getLevel(level);
  final mask = model.shapeMask;
  var maskCells = 0;
  if (mask == null) {
    maskCells = model.gridRows * model.gridCols;
  } else {
    for (final row in mask) {
      for (final inMask in row) {
        if (inMask) maskCells++;
      }
    }
  }
  var occupied = 0;
  for (final arrow in model.arrows) {
    occupied += arrow.path.length;
  }
  final avgPath = occupied / model.arrows.length;
  // ignore: avoid_print
  print(
    'L$level ${model.gridRows}x${model.gridCols} mask=$maskCells '
    'arrows=${model.arrows.length} avgPath=${avgPath.toStringAsFixed(1)} '
    'fill=${(occupied / maskCells * 100).toStringAsFixed(1)}%',
  );
  return occupied / maskCells;
}

void main() {
  test('L10–20 boards stay visually full', () {
    final repo = LevelRepository();
    final sparse = <String>[];
    for (final n in <int>[10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20]) {
      final fill = _coverage(n, repo);
      if (fill < 0.75) {
        sparse.add('L$n=${(fill * 100).toStringAsFixed(1)}%');
      }
    }
    expect(sparse, isEmpty, reason: 'sparse: ${sparse.join(', ')}');
  });

  test('sample Hard/Dense boards stay visually full', () {
    final repo = LevelRepository();
    final sparse = <String>[];
    for (final n in <int>[21, 50, 100, 150, 200, 500, 800, 1000]) {
      final fill = _coverage(n, repo);
      if (fill < 0.70) {
        sparse.add('L$n=${(fill * 100).toStringAsFixed(1)}%');
      }
    }
    expect(sparse, isEmpty, reason: 'sparse: ${sparse.join(', ')}');
  }, timeout: const Timeout(Duration(minutes: 5)));
}
