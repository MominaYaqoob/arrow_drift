import 'dart:math';

/// Arrow counts and board shapes for campaign levels 201–1000.
///
/// Pure Dart (no Flutter) so `tool/generate_shape_levels.dart` can share it:
/// the pre-built L201–400 boards and the runtime L401–1000 boards must follow
/// exactly the same count / shape rules.

const _wave = [0, 4, -3, 6, -5, 2, -2, 5, -4, 3];

/// Arrow count for L201–L1000 with a 10-level wave, reflected at the band
/// edges: L201–400 ramp 151 → 175; L401–1000 stay between 165 and 182 so
/// arrows can stay long (more arrows would force 2–4 cell arrows).
int waveCount(int level) {
  if (level >= 401) {
    final i = level - 401;
    final base = 169 + (i * 9) ~/ 600; // 169 → 177
    var v = base + _wave[i % 10];
    if (v < 165) v = 165 + (165 - v);
    if (v > 182) v = 182 - (v - 182);
    return v;
  }
  final i = level - 200;
  final base = 151 + (i * 100) ~/ 801;
  var v = base + _wave[i % 10];
  if (v < 151) v = 151 + (151 - v);
  if (v > 250) v = 250 - (v - 250);
  return v;
}

/// Ten wide shapes used from L201 on (no triangles / diamond).
const List<String> kShapeCycle201 = [
  'circle',
  'roundedSquare',
  'oval',
  'tallOctagon',
  'square',
  'stadium',
  'hexagon',
  'roundedRectangle',
  'rectangle',
  'octagon',
];

List<String>? _shapes201;

/// Shapes for L201–L1000: never the previous level's shape; a repeated arrow
/// count gets a shape it has not had yet, or failing that the one it had
/// longest ago.
List<String> assignShapes201() => _shapes201 ??= _buildShapes201();

List<String> _buildShapes201() {
  final lastUse = <int, Map<String, int>>{};
  final shapes = <String>[];
  var previous = 'octagon'; // L200
  var cursor = kShapeCycle201.indexOf(previous) + 1;
  for (var level = 201; level <= 1000; level++) {
    final n = waveCount(level);
    final uses = lastUse.putIfAbsent(n, () => {});
    String? pick;
    var pickAge = -1;
    for (var step = 0; step < kShapeCycle201.length; step++) {
      final candidate = kShapeCycle201[(cursor + step) % kShapeCycle201.length];
      if (candidate == previous) continue;
      final age = uses.containsKey(candidate)
          ? level - uses[candidate]!
          : 1 << 30; // never used for this count
      if (age > pickAge) {
        pick = candidate;
        pickAge = age;
        if (age == 1 << 30) {
          cursor += step;
          break;
        }
      }
    }
    cursor++;
    uses[pick!] = level;
    shapes.add(pick);
    previous = pick;
  }
  return List.unmodifiable(shapes);
}

/// Shape name for a level in 201–1000.
String shapeForLevel(int level) => assignShapes201()[level - 201];

/// Four wide shapes used by the Daily challenge (circle/oval dropped —
/// their round corners made them too slow to build reliably on device).
const List<String> kDailyShapes = ['square', 'rectangle', 'hexagon', 'octagon'];

/// Days since 2026-01-01 — the Daily plan runs off this number.
int dailyIndex(DateTime day) =>
    DateTime(day.year, day.month, day.day).difference(DateTime(2026)).inDays;

/// Daily arrow count: 100 → 140 in the same 10-day wave, so two days in a
/// row never feel identical. Kept lower than campaign so each arrow can
/// stay long inside the time budget the board is built in.
int dailyArrowCount(DateTime day) {
  final i = dailyIndex(day);
  var v = 120 + _wave[i % 10] * 3; // 105 … 138
  if (v < 100) v = 100 + (100 - v);
  if (v > 140) v = 140 - (v - 140);
  return v;
}

/// Daily shape: cycles the six shapes, so two days in a row always differ.
String dailyShape(DateTime day) =>
    kDailyShapes[dailyIndex(day) % kDailyShapes.length];

/// Tall shapes use a portrait board (rows ≈ 1.35 × cols).
bool isPortraitShape(String shape) =>
    shape == 'oval' ||
    shape == 'rectangle' ||
    shape == 'stadium' ||
    shape == 'roundedRectangle' ||
    shape == 'tallOctagon';

/// (rows, cols) for a shape whose narrow side is [side].
(int, int) shapeDims(String shape, int side) =>
    isPortraitShape(shape) ? ((side * 1.35).round(), side) : (side, side);

/// Playable cells of [shape] on a rows × cols board.
List<List<bool>> campaignShapeMask(String shape, int rows, int cols) {
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
      'roundedSquare' ||
      'roundedRectangle' => _roundedRect(dx, dy, w / 2, h / 2, 0.3 * min(w, h)),
      'stadium' => _roundedRect(dx, dy, w / 2, h / 2, w / 2),
      'tallOctagon' => _chamferedRect(dx, dy, w / 2, h / 2, 0.3 * min(w, h)),
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
