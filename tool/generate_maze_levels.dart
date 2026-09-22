// Offline generator for campaign levels 2–20 (square board, long maze-like
// arrows). Run once and commit the output; the app never runs this.
//
//   dart run tool/generate_maze_levels.dart
//
// Writes lib/data/repositories/maze_levels_data.dart.
// ignore_for_file: avoid_print
import 'dart:io';
import 'dart:math';

/// Arrow count per level (L2–L20).
const Map<int, int> kArrowCounts = {
  2: 40, 3: 41, 4: 43, 5: 44, 6: 46, 7: 47, 8: 48, 9: 49, 10: 50, //
  11: 51, 12: 52, 13: 53, 14: 54, 15: 55, 16: 56, 17: 57, 18: 58, 19: 59,
  20: 60,
};

const _dirs = [(-1, 0), (1, 0), (0, -1), (0, 1)]; // up, down, left, right
const _maxArrowLen = 32;

class _Arrow {
  _Arrow(this.cells, this.dr, this.dc);
  List<int> cells; // tail → tip, cell = r * s + c
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

List<int> _ray(int s, int tip, int dr, int dc) {
  final out = <int>[];
  var r = tip ~/ s + dr, c = tip % s + dc;
  while (r >= 0 && c >= 0 && r < s && c < s) {
    out.add(r * s + c);
    r += dr;
    c += dc;
  }
  return out;
}

/// Same rule as the game: an arrow escapes when no other arrow sits on its
/// ray. Returns null when the board cannot be cleared.
_Stats? _play(int s, List<_Arrow> arrows) {
  final n = arrows.length;
  final occ = List<int>.filled(s * s, -1);
  for (var k = 0; k < n; k++) {
    for (final x in arrows[k].cells) {
      occ[x] = k;
    }
  }
  final alive = List<bool>.filled(n, true);
  bool free(int k) {
    final a = arrows[k];
    return _ray(s, a.cells.last, a.dr, a.dc)
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

/// Builds arrows backwards from the board centre outward: every new arrow
/// has a clear ray and tries to cover the rays of still-open arrows.
List<_Arrow>? _generate(int s, int n, int seed) {
  final rng = Random(seed);
  final occ = List<int>.filled(s * s, -1);
  final total = (s * s * 0.86).round();
  final longCount = n ~/ 5;
  final lengths = <int>[
    for (var i = 0; i < longCount; i++) 18 + rng.nextInt(13),
  ];
  final rest = n - longCount;
  final restAvg = max(4, (total - lengths.fold(0, (a, b) => a + b)) ~/ rest);
  for (var i = 0; i < rest; i++) {
    lengths.add(max(3, restAvg - 3 + rng.nextInt(7)));
  }

  final c0 = (s - 1) / 2;
  double ring(int x) => max((x ~/ s - c0).abs(), (x % s - c0).abs());
  final unsealed = <int>{};
  final rayOwn = List<List<int>>.generate(s * s, (_) => []);
  final arrows = <_Arrow>[];
  var filled = 0;

  for (var k = 0; k < n; k++) {
    final target = lengths[k];
    final radius = sqrt(filled + target) / 2 + 1.0;
    double outside(int x) => max(0, ring(x) - radius);

    List<int>? best;
    (int, int)? bestDir;
    var bestScore = -1e9;
    var bestSealed = <int>{};

    final cands = <(int, int, int)>[];
    for (var t = 0; t < s * s; t++) {
      if (occ[t] != -1) continue;
      for (final (a, b) in _dirs) {
        cands.add((t, a, b));
      }
    }
    cands.shuffle(rng);
    var evaluated = 0;
    for (final (tip, dr, dc) in cands) {
      if (evaluated >= 90) break;
      final ray = _ray(s, tip, dr, dc);
      if (ray.any((x) => occ[x] != -1)) continue;
      final pr = tip ~/ s - dr, pc = tip % s - dc;
      if (pr < 0 || pc < 0 || pr >= s || pc >= s) continue;
      final prev = pr * s + pc;
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
          final nr = cur ~/ s + ddr, nc = cur % s + ddc;
          if (nr < 0 || nc < 0 || nr >= s || nc >= s) continue;
          final x = nr * s + nc;
          if (occ[x] != -1 || inPath.contains(x) || raySet.contains(x)) {
            continue;
          }
          var walls = 0;
          for (final (a, b) in _dirs) {
            final rr = nr + a, cc = nc + b;
            if (rr < 0 || cc < 0 || rr >= s || cc >= s) {
              if (radius >= c0) walls++;
            } else {
              final y = rr * s + cc;
              if (y != cur && (occ[y] != -1 || inPath.contains(y))) walls++;
            }
          }
          final straight = ddr == bdr && ddc == bdc;
          var score = walls * 1.6 + rng.nextDouble() * 1.2;
          if (straight && run < runLen) score += 2.2;
          if (!straight && run >= runLen) score += 1.8;
          score -= outside(x) * 2.5;
          if (rayOwn[x]
              .any((j) => unsealed.contains(j) && !sealedNow.contains(j))) {
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
      final score = got / target * 10 +
          sealedNow.length * 5 -
          remaining * 4 -
          outside(tip) * 3 +
          rng.nextDouble();
      if (score > bestScore) {
        bestScore = score;
        best = path;
        bestDir = (dr, dc);
        bestSealed = {...sealedNow};
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
    for (final x in _ray(s, cells.last, bestDir.$1, bestDir.$2)) {
      rayOwn[x].add(k);
    }
  }

  // Grow tails into leftover dots; a cell on the ray of any arrow placed at
  // or after k would break the solve order, so those are skipped.
  final rayOwners = List<List<int>>.generate(s * s, (_) => []);
  for (var k = 0; k < n; k++) {
    final a = arrows[k];
    for (final x in _ray(s, a.cells.last, a.dr, a.dc)) {
      rayOwners[x].add(k);
    }
  }
  var changed = true;
  while (changed) {
    changed = false;
    for (var x = 0; x < s * s; x++) {
      if (occ[x] != -1) continue;
      final r = x ~/ s, c = x % s;
      for (final (a, b) in [..._dirs]..shuffle(rng)) {
        final rr = r + a, cc = c + b;
        if (rr < 0 || cc < 0 || rr >= s || cc >= s) continue;
        final k = occ[rr * s + cc];
        if (k == -1 || arrows[k].cells.first != rr * s + cc) continue;
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
_Stats _improveByFlips(int s, List<_Arrow> arrows, _Stats stats) {
  var current = stats;
  for (var pass = 0; pass < 3; pass++) {
    var improved = false;
    for (final a in arrows) {
      if (a.cells.length < 2) continue;
      final oldCells = a.cells, oldDr = a.dr, oldDc = a.dc;
      final tail = oldCells.first, next = oldCells[1];
      a.cells = oldCells.reversed.toList();
      a.dr = tail ~/ s - next ~/ s;
      a.dc = tail % s - next % s;
      final trial = _play(s, arrows);
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

int boardSizeFor(int arrows) => 23 + ((arrows - 40) * 5 / 20).round();

void main() {
  final out = StringBuffer()
    ..writeln('// GENERATED by tool/generate_maze_levels.dart — do not edit.')
    ..writeln('//')
    ..writeln('// Campaign L2–L20 boards. Each entry: board size, then arrows in')
    ..writeln('// placement order as "<U|D|L|R>:<cell,cell,...>" (tail → tip,')
    ..writeln('// cell = row * size + col). Solve order is the reverse.')
    ..writeln()
    ..writeln('const Map<int, List<String>> kMazeLevelData = {');

  for (final entry in kArrowCounts.entries) {
    final level = entry.key, n = entry.value, s = boardSizeFor(n);
    final ranked = <(double, int, List<_Arrow>, _Stats)>[];
    for (var i = 1; i <= 260; i++) {
      final seed = level * 100003 + i * 7919;
      final arrows = _generate(s, n, seed);
      if (arrows == null) continue;
      final cells = arrows.fold(0, (a, b) => a + b.cells.length);
      if (cells / (s * s) < 0.9) continue;
      final stats = _play(s, arrows);
      if (stats == null) continue;
      ranked.add((stats.rank, seed, arrows, stats));
    }
    ranked.sort((a, b) => a.$1.compareTo(b.$1));
    List<_Arrow>? best;
    _Stats? bestStats;
    for (final (_, _, arrows, stats) in ranked.take(6)) {
      final improved = _improveByFlips(s, arrows, stats);
      if (bestStats == null || improved.rank < bestStats.rank) {
        best = arrows;
        bestStats = improved;
      }
    }
    if (best == null || bestStats == null) {
      stderr.writeln('L$level: no board found');
      exit(1);
    }
    final cells = best.fold(0, (a, b) => a + b.cells.length);
    final longest = best.map((a) => a.cells.length).reduce(max);
    print('L$level: ${s}x$s, $n arrows, '
        '${(cells * 100 / (s * s)).toStringAsFixed(1)}% filled, '
        'longest $longest, free at start ${bestStats.freeStart}, '
        'avg free ${bestStats.avgFree.toStringAsFixed(2)}, '
        'max free ${bestStats.maxFree}');

    out.writeln('  $level: [');
    out.writeln("    '$s',");
    // Placement order = reverse of a valid solve order.
    for (final a in [for (final k in bestStats.removal.reversed) best[k]]) {
      final d = switch ((a.dr, a.dc)) {
        (-1, 0) => 'U',
        (1, 0) => 'D',
        (0, -1) => 'L',
        _ => 'R',
      };
      out.writeln("    '$d:${a.cells.join(',')}',");
    }
    out.writeln('  ],');
  }
  out.writeln('};');
  File('lib/data/repositories/maze_levels_data.dart')
      .writeAsStringSync(out.toString());
}
