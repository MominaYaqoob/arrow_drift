/// Grid shape masks for special campaign levels (e.g. heart silhouette).

List<List<bool>> generateHeartShapeMask(int gridSize) {
  final mask = List.generate(
    gridSize,
    (_) => List<bool>.filled(gridSize, false),
  );

  for (var row = 0; row < gridSize; row++) {
    for (var col = 0; col < gridSize; col++) {
      final x = ((col + 0.5) / gridSize) * 2.55 - 1.275;
      final y = -(((row + 0.5) / gridSize) * 2.55 - 1.275) + 0.18;

      if (_isInsideHeart(x, y)) {
        mask[row][col] = true;
      }
    }
  }

  return mask;
}

bool _isInsideHeart(double x, double y) {
  final term1 = x * x + y * y - 1;
  final left = term1 * term1 * term1;
  final right = x * x * y * y * y;
  return left - right <= 0;
}

void debugPrintHeartMask(int gridSize) {
  final mask = generateHeartShapeMask(gridSize);
  for (final row in mask) {
    final line = row.map((inside) => inside ? '█' : '·').join(' ');
    // ignore: avoid_print
    print(line);
  }
}
