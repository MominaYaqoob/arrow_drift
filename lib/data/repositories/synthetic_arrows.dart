import 'package:arrow_drift/data/models/arrow_model.dart';

/// Decorative arrows that fill [mask]. Synchronous and cheap — not a
/// solvable puzzle. Prefers 2–4 cell shafts so thumbnail strokes read as
/// lines, not triangle blobs. Caps occupied cells so large masks stay fast.
List<ArrowModel> buildSyntheticDecorativeArrows(
  List<List<bool>> mask, {
  int seed = 0,
  int maxOccupiedCells = 200,
}) {
  if (mask.isEmpty || mask.first.isEmpty) return const [];

  final rows = mask.length;
  final cols = mask.first.length;
  final occupied = <String>{};

  bool inMask(int r, int c) =>
      r >= 0 && c >= 0 && r < rows && c < cols && mask[r][c];

  bool free(int r, int c) => inMask(r, c) && !occupied.contains('$r,$c');

  void mark(int r, int c) => occupied.add('$r,$c');

  (int, int) delta(ArrowDirection dir) => switch (dir) {
        ArrowDirection.up => (-1, 0),
        ArrowDirection.down => (1, 0),
        ArrowDirection.left => (0, -1),
        ArrowDirection.right => (0, 1),
      };

  const dirs = ArrowDirection.values;

  List<ArrowDirection> dirsFor(int r, int c) {
    final start = (r * 3 + c * 5 + seed) % dirs.length;
    return [for (var i = 0; i < dirs.length; i++) dirs[(start + i) % dirs.length]];
  }

  int growableLen(int r, int c, ArrowDirection dir, int maxLen) {
    final (dr, dc) = delta(dir);
    var len = 1;
    var cr = r;
    var cc = c;
    while (len < maxLen) {
      final nr = cr + dr;
      final nc = cc + dc;
      if (!free(nr, nc)) break;
      len++;
      cr = nr;
      cc = nc;
    }
    return len;
  }

  (ArrowDirection, int) bestGrow(int r, int c, int maxLen) {
    var bestDir = dirsFor(r, c).first;
    var bestLen = 1;
    for (final dir in dirsFor(r, c)) {
      final n = growableLen(r, c, dir, maxLen);
      if (n > bestLen) {
        bestLen = n;
        bestDir = dir;
      }
      if (bestLen >= maxLen) break;
    }
    return (bestDir, bestLen);
  }

  final arrows = <ArrowModel>[];
  var id = 0;

  void commit(int r, int c, ArrowDirection dir, int length) {
    final (dr, dc) = delta(dir);
    final path = <GridCell>[GridCell(r, c)];
    mark(r, c);
    var cr = r;
    var cc = c;
    for (var i = 1; i < length; i++) {
      if (occupied.length >= maxOccupiedCells) break;
      final nr = cr + dr;
      final nc = cc + dc;
      if (!free(nr, nc)) break;
      path.add(GridCell(nr, nc));
      mark(nr, nc);
      cr = nr;
      cc = nc;
    }
    final tip = path.last;
    arrows.add(
      ArrowModel(
        id: 'preview-$id',
        row: tip.row,
        col: tip.col,
        direction: dir,
        path: path,
      ),
    );
    id++;
  }

  void walk({required int minLen, required int maxLen}) {
    outer:
    for (var r = 0; r < rows; r++) {
      for (var c = 0; c < cols; c++) {
        if (occupied.length >= maxOccupiedCells) break outer;
        if (!free(r, c)) continue;
        final (dir, len) = bestGrow(r, c, maxLen);
        if (len < minLen) continue;
        commit(r, c, dir, len.clamp(minLen, maxLen));
      }
    }
  }

  // Prefer connected 2–4 cell shafts first; leftover isolates become 1-cell.
  walk(minLen: 2, maxLen: 4);
  walk(minLen: 1, maxLen: 2);

  return arrows;
}
