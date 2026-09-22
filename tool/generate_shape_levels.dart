// Offline generator for campaign levels 21–1000: long maze-like arrows packed
// into simple shapes (circle, oval, triangles, square, rectangle, diamond,
// hexagon, octagon). Run once and commit the output; the app never runs this.
//
//   dart run tool/generate_shape_levels.dart              # L21–100
//   dart run tool/generate_shape_levels.dart --batch=101  # L101–200
//   dart run tool/generate_shape_levels.dart --batch=201  # L201–300 (…901)
//
// Extra numeric args preview only those levels (no data file written).
// ignore_for_file: avoid_print
import 'dart:io';
import 'dart:isolate';
import 'dart:math';

import 'package:arrow_drift/data/repositories/campaign_shapes.dart';

/// Arrow count per level (L21–L100): 61 → 100 with a gentle wave.
const List<int> kArrowCounts = [
  61, 65, 63, 68, 64, 65, 62, 69, 61, 68, // L21–30
  66, 70, 64, 73, 63, 70, 67, 74, 66, 73, // L31–40
  71, 75, 69, 78, 68, 75, 72, 79, 71, 78, // L41–50
  76, 80, 74, 83, 73, 80, 77, 84, 76, 83, // L51–60
  81, 85, 79, 88, 78, 85, 82, 89, 81, 88, // L61–70
  86, 90, 84, 93, 83, 90, 87, 94, 86, 93, // L71–80
  91, 95, 89, 98, 88, 95, 92, 99, 91, 98, // L81–90
  96, 100, 94, 97, 93, 100, 97, 96, 96, 97, // L91–100
];
const int kFirstLevel = 21;

/// Arrow count per level (L101–L200): 101 → 151 with the same wave.
const List<int> kArrowCounts101 = [
  101, 105, 103, 108, 104, 105, 102, 109, 101, 108, // L101–110
  106, 110, 104, 113, 103, 110, 107, 114, 106, 113, // L111–120
  111, 115, 109, 118, 108, 115, 112, 119, 111, 118, // L121–130
  116, 120, 114, 123, 113, 120, 117, 124, 116, 123, // L131–140
  121, 125, 119, 128, 118, 125, 122, 129, 121, 128, // L141–150
  126, 130, 124, 133, 123, 130, 127, 134, 126, 133, // L151–160
  131, 135, 129, 138, 128, 135, 132, 139, 131, 138, // L161–170
  136, 140, 134, 143, 133, 140, 137, 144, 136, 143, // L171–180
  141, 145, 139, 148, 138, 145, 142, 149, 141, 148, // L181–190
  146, 150, 144, 147, 143, 150, 147, 146, 146, 151, // L191–200
];

/// One generated range of levels and its board limits.
class _Batch {
  const _Batch({
    required this.firstLevel,
    required this.counts,
    required this.maxSide,
    required this.narrowMaxSide,
    required this.maxPortraitRows,
    required this.seeds,
    required this.outFile,
    required this.mapName,
    this.narrowMaxArrows,
    this.previousShape,
    this.flipOnlyFree = false,
    this.fallbackExtraSide = 0,
    this.shapes,
    this.compact = false,
  });

  final int firstLevel;
  final List<int> counts;
  final int maxSide;

  /// Board cap for triangles / diamond (they use only ~half the board).
  final int narrowMaxSide;
  final int maxPortraitRows;
  final int seeds;
  final String outFile;
  final String mapName;

  /// Triangles / diamond only on levels with at most this many arrows.
  final int? narrowMaxArrows;

  /// Shape of the level just before [firstLevel] (never repeated).
  final String? previousShape;

  /// Only try flipping arrows that start free (keeps big boards fast).
  final bool flipOnlyFree;

  /// If no board fits, retry once with the board this many cells bigger.
  final int fallbackExtraSide;

  /// Pre-assigned shape per level (overrides the cycle rules).
  final List<String>? shapes;

  /// Write arrows as `dir:start:moves` and masks run-length encoded.
  final bool compact;

  int get lastLevel => firstLevel + counts.length - 1;
}

const _batch21 = _Batch(
  firstLevel: kFirstLevel,
  counts: kArrowCounts,
  maxSide: 30,
  narrowMaxSide: 32,
  maxPortraitRows: 34,
  seeds: 90,
  outFile: 'lib/data/repositories/shape_levels_data.dart',
  mapName: 'kShapeLevelData',
);

const _batch101 = _Batch(
  firstLevel: 101,
  counts: kArrowCounts101,
  maxSide: 34,
  narrowMaxSide: 34,
  maxPortraitRows: 44,
  seeds: 60,
  outFile: 'lib/data/repositories/shape_levels_data_101_200.dart',
  mapName: 'kShapeLevelData101',
  narrowMaxArrows: 0, // no triangles / diamond in L101–200
  previousShape: 'hexagon', // L100
  flipOnlyFree: true,
  fallbackExtraSide: 2,
);

bool _isNarrow(String shape) => shape.endsWith('riangle') || shape == 'diamond';

// --- L201–L1000 (counts and shapes shared with the app) ----------------

/// L[start]–L[start+99] for start in 201, 301, …, 901.
_Batch _chunkBatch(int start) {
  final all = assignShapes201();
  return _Batch(
    firstLevel: start,
    counts: [for (var l = start; l < start + 100; l++) waveCount(l)],
    maxSide: 36,
    narrowMaxSide: 36,
    maxPortraitRows: 48,
    seeds: 30,
    outFile:
        'lib/data/repositories/shape_levels_data_${start}_${start + 99}.dart',
    mapName: 'kShapeLevelData$start',
    narrowMaxArrows: 0,
    flipOnlyFree: true,
    fallbackExtraSide: 2,
    shapes: all.sublist(start - 201, start - 201 + 100),
    compact: true,
  );
}

const List<String> kShapeCycle = [
  'circle',
  'oval',
  'triangle',
  'invertedTriangle',
  'square',
  'rectangle',
  'diamond',
  'hexagon',
  'octagon',
];

const _dirs = [(-1, 0), (1, 0), (0, -1), (0, 1)]; // up, down, left, right
const _maxArrowLen = 32;

/// Triangles and the diamond use only ~half the board, so they get a bit more.
int _sideCap(String shape, _Batch batch, [int extra = 0]) =>
    (_isNarrow(shape) ? batch.narrowMaxSide : batch.maxSide) + extra;

// --- Shapes ---------------------------------------------------------------

bool _portrait(String shape) =>
    shape == 'oval' ||
    shape == 'rectangle' ||
    shape == 'stadium' ||
    shape == 'roundedRectangle' ||
    shape == 'tallOctagon';

/// (rows, cols) for a shape whose narrow side is [side].
(int, int) _dims(String shape, int side) =>
    _portrait(shape) ? ((side * 1.35).round(), side) : (side, side);

List<List<bool>> _mask(String shape, int rows, int cols) {
  final w = cols.toDouble(), h = rows.toDouble();
  bool inside(double x, double y) {
    final dx = (x - w / 2).abs(), dy = (y - h / 2).abs();
    return switch (shape) {
      'circle' || 'oval' => pow(dx / (w / 2), 2) + pow(dy / (h / 2), 2) <= 1.0,
      'triangle' => dx <= (y / h) * (w / 2) + 0.35,
      'invertedTriangle' => dx <= ((h - y) / h) * (w / 2) + 0.35,
      'diamond' => dx / (w / 2) + dy / (h / 2) <= 1.04,
      'hexagon' => dx <= w / 2 && dy + dx * (h / 4) / (w / 2) <= h / 2 + 0.2,
      'octagon' => dx + dy <= 1.414 * (w / 2) * 1.0 + 0.2,
      'roundedSquare' => _roundedRect(dx, dy, w / 2, h / 2, 0.3 * min(w, h)),
      'stadium' => _roundedRect(dx, dy, w / 2, h / 2, w / 2),
      'roundedRectangle' => _roundedRect(dx, dy, w / 2, h / 2, 0.3 * min(w, h)),
      'tallOctagon' => _chamferedRect(dx, dy, w / 2, h / 2, 0.3 * min(w, h)),
      'shield' => _shield(x / w, y / h),
      'heart' => _heart(x / w, y / h),
      _ => true, // square, rectangle
    };
  }

  return [
    for (var r = 0; r < rows; r++)
      [for (var c = 0; c < cols; c++) inside(c + 0.5, r + 0.5)],
  ];
}

/// Rectangle with half-size (hw, hh) and 45° corner cuts of size c.
bool _chamferedRect(double dx, double dy, double hw, double hh, double c) {
  if (dx > hw || dy > hh) return false;
  return (dx - (hw - c)) + (dy - (hh - c)) <= c + 0.2;
}

/// Rectangle with half-size (hw, hh) and corner radius r.
bool _roundedRect(double dx, double dy, double hw, double hh, double r) {
  if (dx > hw || dy > hh) return false;
  final cx = dx - (hw - r), cy = dy - (hh - r);
  if (cx <= 0 || cy <= 0) return true;
  return cx * cx + cy * cy <= r * r;
}

/// Flat top, straight sides, curving to a point at the bottom (u, v in 0..1).
bool _shield(double u, double v) {
  final dx = (u - 0.5).abs() * 2; // 0 centre … 1 edge
  const shoulder = 0.5;
  if (v <= shoulder) return dx <= 1;
  final t = (v - shoulder) / (1 - shoulder);
  return dx <= 1 - pow(t, 1.8);
}

/// Classic heart curve (x²+y²−1)³ − x²y³ ≤ 0, lobes on top (u, v in 0..1).
bool _heart(double u, double v) {
  final x = (u - 0.5) * 2.36;
  final y = (0.56 - v) * 2.5;
  final a = x * x + y * y - 1;
  return a * a * a - x * x * y * y * y <= 0;
}

int _cells(List<List<bool>> mask) =>
    mask.fold(0, (a, row) => a + row.where((v) => v).length);

/// Smallest board that leaves room for ~11-cell average arrows (capped so
/// cells stay tappable on a phone).
(int, int, List<List<bool>>) _boardFor(
  String shape,
  int arrows,
  _Batch batch, [
  int extra = 0,
]) {
  final maxRows = batch.maxPortraitRows + (extra * 1.35).round();
  for (var side = 18; side <= _sideCap(shape, batch, extra); side++) {
    final (rows, cols) = _dims(shape, side);
    if (_portrait(shape) && rows > maxRows) break;
    final mask = _mask(shape, rows, cols);
    if (_cells(mask) * 0.93 >= arrows * 11) return (rows, cols, mask);
  }
  var side = _sideCap(shape, batch, extra);
  var (rows, cols) = _dims(shape, side);
  while (_portrait(shape) && rows > maxRows) {
    side--;
    (rows, cols) = _dims(shape, side);
  }
  return (rows, cols, _mask(shape, rows, cols));
}

// --- Board model ----------------------------------------------------------

class _Arrow {
  _Arrow(this.cells, this.dr, this.dc);
  List<int> cells; // tail → tip, cell = r * cols + c
  int dr, dc;
}

class _Stats {
  const _Stats(this.freeStart, this.avgFree, this.maxFree, this.removal);
  final int freeStart;
  final double avgFree;
  final int maxFree;
  final List<int> removal; // arrow indexes in a valid solve order
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

/// Builds arrows backwards from the shape centre outward: every new arrow
/// has a clear ray and tries to cover the rays of still-open arrows.
List<_Arrow>? _generate(
  _Grid g,
  int n,
  int seed, {
  bool fitLengths = false,
  double ringMargin = 1.0,
}) {
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
  if (fitLengths) {
    // Dense boards: trim the longest planned arrows until the plan fits.
    var sum = lengths.fold(0, (a, b) => a + b);
    while (sum > total) {
      var longest = 0;
      for (var i = 1; i < lengths.length; i++) {
        if (lengths[i] > lengths[longest]) longest = i;
      }
      if (lengths[longest] <= 2) break;
      lengths[longest]--;
      sum--;
    }
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
    final radius = sqrt((filled + target) / area) + ringMargin / unit;
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

/// Flip arrows end-for-end while it lowers how many start free.
_Stats _improveByFlips(
  _Grid g,
  List<_Arrow> arrows,
  _Stats stats, {
  bool onlyFree = false,
}) {
  var current = stats;
  for (var pass = 0; pass < 6; pass++) {
    var improved = false;
    final candidates = onlyFree ? _freeAtStart(g, arrows) : arrows;
    for (final a in candidates) {
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

// --- Per level --------------------------------------------------------------

/// Builds one level; returns the data-file entry plus a summary line.
(String, String) _buildLevel((int, int, String, _Batch) job) {
  final (level, n, shape, batch) = job;
  final ranked = <(double, List<_Arrow>, _Stats, double)>[];
  late int rows, cols;
  late List<List<bool>> mask;
  late _Grid g;
  for (final extra in [
    0,
    if (batch.fallbackExtraSide > 0) batch.fallbackExtraSide,
  ]) {
    (rows, cols, mask) = _boardFor(shape, n, batch, extra);
    g = _Grid(rows, cols, mask);
    final area = _cells(mask);
    for (final minFill in [0.9, 0.87, 0.84, 0.8]) {
      for (var i = 1; i <= batch.seeds; i++) {
        final arrows = _generate(
          g,
          n,
          level * 100003 + i * 7919,
          fitLengths: false,
          ringMargin: 1.0,
        );
        if (arrows == null) continue;
        final fill = arrows.fold(0, (a, b) => a + b.cells.length) / area;
        if (fill < minFill) continue;
        final stats = _play(g, arrows);
        if (stats == null) continue;
        ranked.add((stats.rank, arrows, stats, fill));
      }
      if (ranked.isNotEmpty) break;
    }
    if (ranked.isNotEmpty) break;
  }
  if (ranked.isEmpty) throw StateError('L$level ($shape): no board found');
  ranked.sort((a, b) => a.$1.compareTo(b.$1));

  List<_Arrow>? best;
  _Stats? bestStats;
  var bestFill = 0.0;
  for (final (_, arrows, stats, fill) in ranked.take(4)) {
    final improved = _improveByFlips(
      g,
      arrows,
      stats,
      onlyFree: batch.flipOnlyFree,
    );
    if (bestStats == null || improved.rank < bestStats.rank) {
      best = arrows;
      bestStats = improved;
      bestFill = fill;
    }
  }

  final lengths = best!.map((a) => a.cells.length).toList()..sort();
  final summary =
      'L$level: ${shape.padRight(16)} ${rows}x$cols, $n arrows, '
      '${(bestFill * 100).toStringAsFixed(1)}% filled, '
      'longest ${lengths.last}, avg ${(lengths.reduce((a, b) => a + b) / n).toStringAsFixed(1)}, '
      'free at start ${bestStats!.freeStart}, '
      'avg free ${bestStats.avgFree.toStringAsFixed(2)}';

  final out = StringBuffer()
    ..writeln('  $level: [')
    ..writeln("    '$rows,$cols,$shape',");
  final full = mask.every((row) => row.every((v) => v));
  String maskText() {
    if (!batch.compact) {
      return mask.map((row) => row.map((v) => v ? '1' : '0').join()).join('/');
    }
    // Each row as run lengths, starting with an "outside" run (may be 0).
    return mask
        .map((row) {
          final runs = <int>[];
          var current = false;
          var run = 0;
          for (final v in row) {
            if (v == current) {
              run++;
            } else {
              runs.add(run);
              current = v;
              run = 1;
            }
          }
          runs.add(run);
          return runs.join('.');
        })
        .join('/');
  }

  out.writeln(full ? "    ''," : "    '${maskText()}',");
  String dirChar(int dr, int dc) => switch ((dr, dc)) {
    (-1, 0) => 'U',
    (1, 0) => 'D',
    (0, -1) => 'L',
    _ => 'R',
  };
  // Placement order = reverse of a valid solve order.
  for (final k in bestStats.removal.reversed) {
    final a = best[k];
    final d = dirChar(a.dr, a.dc);
    if (batch.compact) {
      final moves = StringBuffer();
      for (var i = 1; i < a.cells.length; i++) {
        final prev = a.cells[i - 1], cur = a.cells[i];
        moves.write(
          dirChar(cur ~/ cols - prev ~/ cols, cur % cols - prev % cols),
        );
      }
      out.writeln("    '$d:${a.cells.first}:$moves',");
    } else {
      out.writeln("    '$d:${a.cells.join(',')}',");
    }
  }
  out.writeln('  ],');
  return (out.toString(), summary);
}

/// Shape per level: follows the cycle, never repeats the previous level's
/// shape, and never reuses a shape for an arrow count seen before.
List<String> _assignShapes(_Batch batch) {
  if (batch.shapes != null) return batch.shapes!;
  final usedByCount = <int, Set<String>>{};
  final shapes = <String>[];
  var cursor = batch.previousShape == null
      ? 0
      : kShapeCycle.indexOf(batch.previousShape!) + 1;
  for (final n in batch.counts) {
    final used = usedByCount.putIfAbsent(n, () => {});
    final previous = shapes.isNotEmpty ? shapes.last : batch.previousShape;
    final narrowAllowed =
        batch.narrowMaxArrows == null || n <= batch.narrowMaxArrows!;
    var pick = kShapeCycle[cursor % kShapeCycle.length];
    for (var step = 0; step < kShapeCycle.length; step++) {
      final candidate = kShapeCycle[(cursor + step) % kShapeCycle.length];
      final repeatsPrev = previous == candidate;
      if (!narrowAllowed && _isNarrow(candidate)) continue;
      if (!used.contains(candidate) && !repeatsPrev) {
        pick = candidate;
        cursor += step;
        break;
      }
    }
    cursor++;
    used.add(pick);
    shapes.add(pick);
  }
  return shapes;
}

Future<void> main(List<String> args) async {
  final batchArg = args.firstWhere(
    (a) => a.startsWith('--batch='),
    orElse: () => '--batch=21',
  );
  final start = int.parse(batchArg.substring('--batch='.length));
  final batch = switch (start) {
    21 => _batch21,
    101 => _batch101,
    _ => _chunkBatch(start),
  };
  final shapes = _assignShapes(batch);
  if (args.contains('--shapes')) {
    for (var i = 0; i < shapes.length; i++) {
      print('L${batch.firstLevel + i}: ${batch.counts[i]} ${shapes[i]}');
    }
    return;
  }
  // Optional args: level numbers to preview (no data file written).
  final only = args.where((a) => !a.startsWith('--')).map(int.parse).toSet();
  final jobs = [
    for (var i = 0; i < batch.counts.length; i++)
      if (only.isEmpty || only.contains(batch.firstLevel + i))
        (batch.firstLevel + i, batch.counts[i], shapes[i], batch),
  ];

  final results = List<(String, String)?>.filled(jobs.length, null);
  var next = 0;
  final workers = max(1, Platform.numberOfProcessors - 1);
  await Future.wait([
    for (var w = 0; w < workers; w++)
      () async {
        while (next < jobs.length) {
          final i = next++;
          final job = jobs[i];
          try {
            results[i] = await Isolate.run(() => _buildLevel(job));
            print(results[i]!.$2);
          } catch (e) {
            print('L${job.$1}: FAILED $e');
            // L201+: a level the tool cannot build is left out and the app
            // builds it on the device instead (same count and shape).
            if (!batch.compact) rethrow;
          }
        }
      }(),
  ]);

  if (only.isNotEmpty) return;
  final out = StringBuffer()
    ..writeln('// GENERATED by tool/generate_shape_levels.dart — do not edit.')
    ..writeln('//')
    ..writeln(
      '// Campaign L${batch.firstLevel}–L${batch.lastLevel} boards. '
      'Each entry: "rows,cols,shape", then the',
    )
    ..writeln(
      "// shape mask as rows of 0/1 joined by '/' ('' = full board), then",
    )
    ..writeln('// arrows in placement order as "<U|D|L|R>:<cell,cell,...>"')
    ..writeln(
      '// (tail → tip, cell = row * cols + col). Solve order is the reverse.',
    )
    ..writeln()
    ..writeln('const Map<int, List<String>> ${batch.mapName} = {');
  for (final r in results) {
    if (r == null) continue;
    out.write(r.$1);
  }
  out.writeln('};');
  File(batch.outFile).writeAsStringSync(out.toString());
}
