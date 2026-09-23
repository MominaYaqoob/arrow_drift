import 'dart:math';

import 'package:arrow_drift/data/models/arrow_model.dart';

/// Builds a solvable board of long, maze-like arrows inside a shape.
///
/// Same algorithm as `tool/generate_shape_levels.dart` (used for the
/// pre-built campaign boards), with a wall-clock budget so it can run on the
/// device — the Daily board is built fresh for each date.
///
/// Arrows are placed backwards from the centre outward: every new arrow has a
/// clear escape ray against the ones already placed, and it tries to cover the
/// rays of arrows that are still open. Reversing the placement order therefore
/// gives a valid solve order.

const _dirs = [(-1, 0), (1, 0), (0, -1), (0, 1)]; // up, down, left, right
const _maxArrowLen = 32;

class MazeBoard {
  const MazeBoard({
    required this.arrows,
    required this.placementOrder,
    required this.freeAtStart,
    required this.coverage,
  });

  final List<ArrowModel> arrows;

  /// Arrow ids in placement order; the reverse is a valid solve order.
  final List<String> placementOrder;
  final int freeAtStart;
  final double coverage;
}

class _Arrow {
  _Arrow(this.cells, this.dr, this.dc);
  List<int> cells; // tail → tip, cell = row * cols + col
  int dr, dc;
}

class _Stats {
  const _Stats(this.freeStart, this.avgFree, this.maxFree, this.removal);
  final int freeStart;
  final double avgFree;
  final int maxFree;

  /// Arrow indexes in a valid removal (solve) order.
  final List<int> removal;
  double get rank => freeStart * 4 + avgFree * 3 + maxFree;
}

class _Grid {
  _Grid(this.rows, this.cols, this.mask);
  final int rows, cols;
  final List<List<bool>> mask;

  bool inMask(int r, int c) =>
      r >= 0 && c >= 0 && r < rows && c < cols && mask[r][c];

  /// Same escape rule as the game (`isArrowBlocked`): walk from the tip; a
  /// gap outside the shape is skipped only if more shape lies ahead.
  List<int> ray(int tip, int dr, int dc) {
    final out = <int>[];
    var r = tip ~/ cols + dr, c = tip % cols + dc;
    while (r >= 0 && c >= 0 && r < rows && c < cols) {
      if (!mask[r][c]) {
        var rr = r, cc = c, ahead = false;
        while (rr >= 0 && cc >= 0 && rr < rows && cc < cols) {
          if (mask[rr][cc]) {
            ahead = true;
            break;
          }
          rr += dr;
          cc += dc;
        }
        if (!ahead) break;
      } else {
        out.add(r * cols + c);
      }
      r += dr;
      c += dc;
    }
    return out;
  }
}

/// Plays the board out with the game's own rule; null when it cannot clear.
_Stats? _play(_Grid g, List<_Arrow> arrows) {
  final n = arrows.length;
  final occ = List<int>.filled(g.rows * g.cols, -1);
  for (var k = 0; k < n; k++) {
    for (final x in arrows[k].cells) {
      occ[x] = k;
    }
  }
  final alive = List<bool>.filled(n, true);
  bool free(int k) {
    final a = arrows[k];
    return g
        .ray(a.cells.last, a.dr, a.dc)
        .every((x) => occ[x] == -1 || occ[x] == k);
  }

  var freeStart = 0, maxFree = 0, sum = 0;
  final removal = <int>[];
  for (var step = 0; step < n; step++) {
    final fr = [
      for (var k = 0; k < n; k++)
        if (alive[k] && free(k)) k,
    ];
    if (fr.isEmpty) return null;
    if (step == 0) freeStart = fr.length;
    maxFree = max(maxFree, fr.length);
    sum += fr.length;
    final k = fr.first;
    removal.add(k);
    alive[k] = false;
    for (final x in arrows[k].cells) {
      occ[x] = -1;
    }
  }
  return _Stats(freeStart, sum / n, maxFree, removal);
}

List<_Arrow>? _generate(_Grid g, int n, int seed) {
  final rng = Random(seed);
  final rows = g.rows, cols = g.cols;
  final occ = List<int>.filled(rows * cols, -1);
  final maskCells = <int>[
    for (var r = 0; r < rows; r++)
      for (var c = 0; c < cols; c++)
        if (g.mask[r][c]) r * cols + c,
  ];
  final area = maskCells.length;
  final total = (area * 0.86).round();
  final avg = total / n;
  final longCount = n ~/ 5;
  final longMin = (avg * 1.8).round().clamp(6, 30);
  final longMax = (avg * 2.8).round().clamp(longMin, 30);
  final lengths = <int>[
    for (var i = 0; i < longCount; i++)
      longMin + rng.nextInt(longMax - longMin + 1),
  ];
  final rest = n - longCount;
  final restAvg = max(3, (total - lengths.fold(0, (a, b) => a + b)) ~/ rest);
  for (var i = 0; i < rest; i++) {
    lengths.add(max(2, restAvg - 2 + rng.nextInt(5)));
  }

  var rc = 0.0, cc0 = 0.0;
  for (final x in maskCells) {
    rc += x ~/ cols;
    cc0 += x % cols;
  }
  rc /= area;
  cc0 /= area;
  var hr = 1.0, hc = 1.0;
  for (final x in maskCells) {
    hr = max(hr, (x ~/ cols - rc).abs());
    hc = max(hc, (x % cols - cc0).abs());
  }
  final unit = min(hr, hc);
  double ring(int x) =>
      max((x ~/ cols - rc).abs() / hr, (x % cols - cc0).abs() / hc);

  final unsealed = <int>{};
  final rayOwn = List<List<int>>.generate(rows * cols, (_) => []);
  final arrows = <_Arrow>[];
  var filled = 0;

  for (var k = 0; k < n; k++) {
    final target = lengths[k];
    final radius = sqrt((filled + target) / area) + 1.0 / unit;
    double outside(int x) => max(0, ring(x) - radius) * unit;
    final nearRim = radius >= 0.95;

    List<int>? best;
    (int, int)? bestDir;
    var bestScore = -1e9;
    var bestSealed = <int>{};

    final cands = <(int, int, int)>[];
    for (final t in maskCells) {
      if (occ[t] != -1) continue;
      for (final (a, b) in _dirs) {
        cands.add((t, a, b));
      }
    }
    cands.shuffle(rng);
    // Strict pass: except the last few, every tip needs >= 2 open cells
    // ahead so a later arrow can cover them (keeps start-free count low).
    for (final strict in [true, false]) {
      if (best != null) break;
      var evaluated = 0;
      for (final (tip, dr, dc) in cands) {
        if (evaluated >= 90) break;
        final ray = g.ray(tip, dr, dc);
        if (ray.any((x) => occ[x] != -1)) continue;
        if (strict && k < n - 3 && ray.length < 2) continue;
        final pr = tip ~/ cols - dr, pc = tip % cols - dc;
        if (!g.inMask(pr, pc)) continue;
        final prev = pr * cols + pc;
        if (occ[prev] != -1) continue;
        evaluated++;

        final raySet = ray.toSet();
        final path = <int>[tip, prev];
        final inPath = {tip, prev};
        final sealedNow = <int>{};
        void seal(int x) {
          for (final j in rayOwn[x]) {
            if (unsealed.contains(j)) sealedNow.add(j);
          }
        }

        seal(tip);
        seal(prev);
        var cur = prev;
        var bdr = -dr, bdc = -dc;
        var run = 1;
        var runLen = 2 + rng.nextInt(5);
        while (path.length < target) {
          int? pick;
          var pickScore = -1e9;
          var pickDir = (0, 0);
          for (final (ddr, ddc) in _dirs) {
            if (ddr == -bdr && ddc == -bdc) continue;
            final nr = cur ~/ cols + ddr, nc = cur % cols + ddc;
            if (!g.inMask(nr, nc)) continue;
            final x = nr * cols + nc;
            if (occ[x] != -1 || inPath.contains(x) || raySet.contains(x)) {
              continue;
            }
            var walls = 0;
            for (final (a, b) in _dirs) {
              final rr = nr + a, c2 = nc + b;
              if (!g.inMask(rr, c2)) {
                if (nearRim) walls++;
              } else {
                final y = rr * cols + c2;
                if (y != cur && (occ[y] != -1 || inPath.contains(y))) walls++;
              }
            }
            final straight = ddr == bdr && ddc == bdc;
            var score = walls * 1.6 + rng.nextDouble() * 1.2;
            if (straight && run < runLen) score += 2.2;
            if (!straight && run >= runLen) score += 1.8;
            score -= outside(x) * 2.5;
            if (rayOwn[x].any(
              (j) => unsealed.contains(j) && !sealedNow.contains(j),
            )) {
              score += 3.5;
            }
            if (score > pickScore) {
              pickScore = score;
              pick = x;
              pickDir = (ddr, ddc);
            }
          }
          if (pick == null) break;
          if (pickDir.$1 == bdr && pickDir.$2 == bdc) {
            run++;
          } else {
            run = 1;
            runLen = 2 + rng.nextInt(6);
          }
          (bdr, bdc) = pickDir;
          path.add(pick);
          inPath.add(pick);
          seal(pick);
          cur = pick;
        }
        final got = min(path.length, target);
        final remaining = unsealed.length - sealedNow.length;
        // A tip whose ray is already at the rim can never be covered later,
        // so it would start the level free — prefer rays with room to seal.
        final lastFew = k >= n - 2;
        final score =
            got / target * 10 +
            sealedNow.length * 5 -
            remaining * 4 -
            outside(tip) * 3 +
            (lastFew ? 0 : min(ray.length, 8) * 0.6 - (ray.isEmpty ? 6 : 0)) +
            rng.nextDouble();
        if (score > bestScore) {
          bestScore = score;
          best = path;
          bestDir = (dr, dc);
          bestSealed = {...sealedNow};
        }
      }
    }
    if (best == null) return null;

    final cells = best.reversed.toList();
    for (final x in cells) {
      occ[x] = k;
    }
    arrows.add(_Arrow(cells, bestDir!.$1, bestDir.$2));
    filled += cells.length;
    unsealed.removeAll(bestSealed);
    unsealed.add(k);
    for (final x in g.ray(cells.last, bestDir.$1, bestDir.$2)) {
      rayOwn[x].add(k);
    }
  }

  // Grow tails into leftover dots; a cell on the ray of any arrow placed at
  // or after k would break the solve order, so those are skipped.
  final rayOwners = List<List<int>>.generate(rows * cols, (_) => []);
  for (var k = 0; k < n; k++) {
    final a = arrows[k];
    for (final x in g.ray(a.cells.last, a.dr, a.dc)) {
      rayOwners[x].add(k);
    }
  }
  var changed = true;
  while (changed) {
    changed = false;
    for (final x in maskCells) {
      if (occ[x] != -1) continue;
      final r = x ~/ cols, c = x % cols;
      for (final (a, b) in [..._dirs]..shuffle(rng)) {
        final rr = r + a, c2 = c + b;
        if (!g.inMask(rr, c2)) continue;
        final k = occ[rr * cols + c2];
        if (k == -1 || arrows[k].cells.first != rr * cols + c2) continue;
        if (rayOwners[x].any((j) => j >= k)) continue;
        if (arrows[k].cells.length >= _maxArrowLen) continue;
        arrows[k].cells.insert(0, x);
        occ[x] = k;
        changed = true;
        break;
      }
    }
  }
  return arrows;
}

/// Arrows whose ray is clear on the full board.
List<_Arrow> _freeAtStart(_Grid g, List<_Arrow> arrows) {
  final occ = List<int>.filled(g.rows * g.cols, -1);
  for (var k = 0; k < arrows.length; k++) {
    for (final x in arrows[k].cells) {
      occ[x] = k;
    }
  }
  return [
    for (var k = 0; k < arrows.length; k++)
      if (g
          .ray(arrows[k].cells.last, arrows[k].dr, arrows[k].dc)
          .every((x) => occ[x] == -1 || occ[x] == k))
        arrows[k],
  ];
}

/// Flip arrows end-for-end while it lowers how many start free.
_Stats _improveByFlips(_Grid g, List<_Arrow> arrows, _Stats stats) {
  var current = stats;
  for (var pass = 0; pass < 3; pass++) {
    var improved = false;
    for (final a in _freeAtStart(g, arrows)) {
      if (a.cells.length < 2) continue;
      final oldCells = a.cells, oldDr = a.dr, oldDc = a.dc;
      final tail = oldCells.first, next = oldCells[1];
      a.cells = oldCells.reversed.toList();
      a.dr = tail ~/ g.cols - next ~/ g.cols;
      a.dc = tail % g.cols - next % g.cols;
      final trial = _play(g, arrows);
      if (trial != null && trial.rank < current.rank) {
        current = trial;
        improved = true;
      } else {
        a.cells = oldCells;
        a.dr = oldDr;
        a.dc = oldDc;
      }
    }
    if (!improved) break;
  }
  return current;
}

/// Builds the best board it can within [budget]; null when none worked.
///
/// [seed] keeps the result stable: the same seed and board always give the
/// same puzzle, however many attempts fit in the budget.
MazeBoard? buildMazeBoard({
  required int rows,
  required int cols,
  required List<List<bool>> mask,
  required int arrowCount,
  required int seed,
  required String idPrefix,
  Duration budget = const Duration(seconds: 8),
  double minCoverage = 0.88,
}) {
  final g = _Grid(rows, cols, mask);
  final area = mask.fold(0, (a, row) => a + row.where((v) => v).length);
  final watch = Stopwatch()..start();

  List<_Arrow>? best;
  _Stats? bestStats;
  var bestFill = 0.0;
  for (var attempt = 0; attempt < 400; attempt++) {
    if (watch.elapsed >= budget) break;
    final arrows = _generate(g, arrowCount, seed + attempt * 7919);
    if (arrows == null) continue;
    final fill = arrows.fold(0, (a, b) => a + b.cells.length) / area;
    if (fill < minCoverage) continue;
    final stats = _play(g, arrows);
    if (stats == null) continue;
    final improved = _improveByFlips(g, arrows, stats);
    if (bestStats == null || improved.rank < bestStats.rank) {
      best = arrows;
      bestStats = improved;
      bestFill = fill;
    }
  }
  if (best == null || bestStats == null) return null;

  // Placement order = reverse of a valid solve order.
  final ordered = [for (final k in bestStats.removal.reversed) best[k]];
  final arrows = <ArrowModel>[];
  for (var i = 0; i < ordered.length; i++) {
    final a = ordered[i];
    arrows.add(
      ArrowModel(
        id: '$idPrefix-$i',
        row: a.cells.last ~/ cols,
        col: a.cells.last % cols,
        direction: switch ((a.dr, a.dc)) {
          (-1, 0) => ArrowDirection.up,
          (1, 0) => ArrowDirection.down,
          (0, -1) => ArrowDirection.left,
          _ => ArrowDirection.right,
        },
        path: [for (final x in a.cells) GridCell(x ~/ cols, x % cols)],
      ),
    );
  }
  return MazeBoard(
    arrows: arrows,
    placementOrder: [for (final a in arrows) a.id],
    freeAtStart: bestStats.freeStart,
    coverage: bestFill,
  );
}
