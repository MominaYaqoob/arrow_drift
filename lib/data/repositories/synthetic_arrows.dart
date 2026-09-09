import 'package:arrow_drift/data/models/arrow_model.dart';

/// Short decorative arrows that fill [mask]. Synchronous and cheap — not a
/// solvable puzzle. Caps occupied cells so large masks stay thumbnail-fast.
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

  final arrows = <ArrowModel>[];
  var id = 0;
  const dirs = ArrowDirection.values;

  outer:
  for (var r = 0; r < rows; r++) {
    for (var c = 0; c < cols; c++) {
      if (occupied.length >= maxOccupiedCells) break outer;
      if (!free(r, c)) continue;
      final dir = dirs[(r * 3 + c * 5 + seed) % dirs.length];
      final (dr, dc) = delta(dir);
      final path = <GridCell>[GridCell(r, c)];
      mark(r, c);
      var cr = r;
      var cc = c;
      for (var step = 0; step < 2; step++) {
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
  }

  return arrows;
}
