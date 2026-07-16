import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:arrow_drift/data/models/arrow_model.dart';
import 'package:arrow_drift/data/models/game_state.dart';
import 'package:arrow_drift/data/models/level_model.dart';

/// Result of tapping an arrow on the board.
enum TapArrowResult {
  /// Arrow had a clear path and was removed.
  removed,

  /// Arrow was blocked; a heart was lost (UI should shake).
  wrongTap,

  /// Tap was ignored (already removed, won, or lost).
  ignored,
}

// ---------------------------------------------------------------------------
// Pure helpers (easy to unit-test without Riverpod)
// ---------------------------------------------------------------------------

/// Returns a fresh copy of each arrow so the original level data is never mutated.
List<ArrowModel> cloneArrows(List<ArrowModel> source) {
  return source
      .map(
        (arrow) => ArrowModel(
          id: arrow.id,
          row: arrow.row,
          col: arrow.col,
          direction: arrow.direction,
          path: List<GridCell>.from(arrow.path),
          isRemoved: arrow.isRemoved,
        ),
      )
      .toList();
}

/// Returns true when every arrow on the board has been removed.
bool areAllArrowsRemoved(List<ArrowModel> arrows) {
  return arrows.every((arrow) => arrow.isRemoved);
}

/// Non-playable cells reachable from the grid **border** without crossing
/// playable cells. Concave edges (heart dent) count as exterior escapes;
/// closed interior holes (ring/donut) do **not** — rays skip through them.
Set<String> computeExteriorEscapeKeys({
  required List<List<bool>> shapeMask,
  required int rows,
  required int cols,
}) {
  bool playable(int r, int c) {
    if (r < 0 || c < 0 || r >= rows || c >= cols) return false;
    if (r >= shapeMask.length || c >= shapeMask[r].length) return false;
    return shapeMask[r][c];
  }

  final exterior = <String>{};
  final queue = <(int, int)>[];

  void tryAdd(int r, int c) {
    if (r < 0 || c < 0 || r >= rows || c >= cols) return;
    final key = '$r:$c';
    if (exterior.contains(key) || playable(r, c)) return;
    exterior.add(key);
    queue.add((r, c));
  }

  for (var r = 0; r < rows; r++) {
    tryAdd(r, 0);
    tryAdd(r, cols - 1);
  }
  for (var c = 0; c < cols; c++) {
    tryAdd(0, c);
    tryAdd(rows - 1, c);
  }

  var head = 0;
  while (head < queue.length) {
    final (r, c) = queue[head++];
    tryAdd(r - 1, c);
    tryAdd(r + 1, c);
    tryAdd(r, c - 1);
    tryAdd(r, c + 1);
  }
  return exterior;
}

/// Returns true when another active arrow occupies a cell on [arrow]'s escape ray.
///
/// Escape ray starts at the tip and walks in [arrow.direction] until off-board.
/// Outside-silhouette gaps: if more playable cells exist further on this ray,
/// the gap is skipped (so a hit further ahead still blocks). If the silhouette
/// has ended on this ray, the tip is free — cannot "slip out" via white
/// corridors that still have playable cells ahead.
bool isArrowBlocked({
  required ArrowModel arrow,
  required List<ArrowModel> arrows,
  int gridRows = 64,
  int gridCols = 64,
  List<List<bool>>? shapeMask,
}) {
  if (arrow.isRemoved) return true;

  final occupied = <String>{};
  for (final other in arrows) {
    if (identical(other, arrow) || other.id == arrow.id) continue;
    if (other.isRemoved) continue;
    for (final cell in other.path) {
      occupied.add('${cell.row}:${cell.col}');
    }
  }

  bool inMask(int r, int c) {
    if (shapeMask == null) return true;
    if (r < 0 ||
        c < 0 ||
        r >= shapeMask.length ||
        c >= shapeMask[r].length) {
      return false;
    }
    return shapeMask[r][c];
  }

  bool playableAhead(int r, int c, int dRow, int dCol) {
    var rr = r;
    var cc = c;
    for (var i = 0; i < 64; i++) {
      if (rr < 0 || cc < 0 || rr >= gridRows || cc >= gridCols) return false;
      if (inMask(rr, cc)) return true;
      rr += dRow;
      cc += dCol;
    }
    return false;
  }

  final (dRow, dCol) = switch (arrow.direction) {
    ArrowDirection.up => (-1, 0),
    ArrowDirection.down => (1, 0),
    ArrowDirection.left => (0, -1),
    ArrowDirection.right => (0, 1),
  };

  var r = arrow.row + dRow;
  var c = arrow.col + dCol;
  for (var step = 0; step < 64; step++) {
    if (r < 0 || c < 0 || r >= gridRows || c >= gridCols) return false;
    if (!inMask(r, c)) {
      // Silhouette ended this way → escaped. Gap with more shape ahead → skip.
      if (!playableAhead(r, c, dRow, dCol)) return false;
      r += dRow;
      c += dCol;
      continue;
    }
    if (occupied.contains('$r:$c')) return true;
    r += dRow;
    c += dCol;
  }
  return false;
}

/// First active arrow that blocks [arrow]'s escape ray, and how many cells
/// away the first collision is from the tip (1 = adjacent).
({ArrowModel blocker, int steps})? findFirstBlockingArrow({
  required ArrowModel arrow,
  required List<ArrowModel> arrows,
  int gridRows = 64,
  int gridCols = 64,
  List<List<bool>>? shapeMask,
}) {
  if (arrow.isRemoved) return null;

  final occupants = <String, ArrowModel>{};
  for (final other in arrows) {
    if (identical(other, arrow) || other.id == arrow.id) continue;
    if (other.isRemoved) continue;
    for (final cell in other.path) {
      occupants.putIfAbsent('${cell.row}:${cell.col}', () => other);
    }
  }

  final (dRow, dCol) = switch (arrow.direction) {
    ArrowDirection.up => (-1, 0),
    ArrowDirection.down => (1, 0),
    ArrowDirection.left => (0, -1),
    ArrowDirection.right => (0, 1),
  };

  bool inMask(int r, int c) {
    if (shapeMask == null) return true;
    if (r < 0 ||
        c < 0 ||
        r >= shapeMask.length ||
        c >= shapeMask[r].length) {
      return false;
    }
    return shapeMask[r][c];
  }

  bool playableAhead(int r, int c) {
    var rr = r;
    var cc = c;
    for (var i = 0; i < 64; i++) {
      if (rr < 0 || cc < 0 || rr >= gridRows || cc >= gridCols) return false;
      if (inMask(rr, cc)) return true;
      rr += dRow;
      cc += dCol;
    }
    return false;
  }

  var r = arrow.row + dRow;
  var c = arrow.col + dCol;
  for (var step = 1; step <= 64; step++) {
    if (r < 0 || c < 0 || r >= gridRows || c >= gridCols) return null;
    if (!inMask(r, c)) {
      if (!playableAhead(r, c)) return null;
      r += dRow;
      c += dCol;
      continue;
    }
    final hit = occupants['$r:$c'];
    if (hit != null) return (blocker: hit, steps: step);
    r += dRow;
    c += dCol;
  }
  return null;
}

/// Inverse of [isArrowBlocked] (kept for hints / solvability helpers).
bool isArrowFree({
  required ArrowModel arrow,
  required List<ArrowModel> arrows,
  required int gridRows,
  required int gridCols,
  List<List<bool>>? shapeMask,
}) {
  if (arrow.isRemoved) return false;
  if (arrow.row < 0 ||
      arrow.col < 0 ||
      arrow.row >= gridRows ||
      arrow.col >= gridCols) {
    return false;
  }
  if (shapeMask != null &&
      (arrow.row >= shapeMask.length ||
          arrow.col >= shapeMask[arrow.row].length ||
          !shapeMask[arrow.row][arrow.col])) {
    return false;
  }
  return !isArrowBlocked(
    arrow: arrow,
    arrows: arrows,
    gridRows: gridRows,
    gridCols: gridCols,
    shapeMask: shapeMask,
  );
}

/// Finds the first active arrow that currently has a clear escape path.
ArrowModel? findFirstFreeArrow({
  required List<ArrowModel> arrows,
  required int gridRows,
  required int gridCols,
  List<List<bool>>? shapeMask,
}) {
  for (final arrow in arrows) {
    if (isArrowFree(
      arrow: arrow,
      arrows: arrows,
      gridRows: gridRows,
      gridCols: gridCols,
      shapeMask: shapeMask,
    )) {
      return arrow;
    }
  }
  return null;
}

/// Returns the first currently-free (unblocked) arrow in [state].
///
/// Reuses [isArrowFree] / [isArrowBlocked] — does not duplicate path rules.
ArrowModel? findFreeArrow(GameState state) {
  return findFirstFreeArrow(
    arrows: state.arrows,
    gridRows: state.level.gridRows,
    gridCols: state.level.gridCols,
    shapeMask: state.level.shapeMask,
  );
}

/// Builds the starting [GameState] for a level.
GameState createInitialGameState(LevelModel level) {
  return GameState(
    level: level,
    arrows: cloneArrows(level.arrows),
    heartsLeft: level.heartsAllowed,
    hintsLeft: level.hintsAllowed,
  );
}

// ---------------------------------------------------------------------------
// Controller
// ---------------------------------------------------------------------------

/// Owns gameplay state for one level and applies tap / hint / reset rules.
class GameController extends StateNotifier<GameState> {
  GameController(this._level) : super(createInitialGameState(_level));

  final LevelModel _level;

  /// Handles a player tap on the arrow with [arrowId].
  ///
  /// Free arrows are removed. Blocked arrows cost one heart and return
  /// [TapArrowResult.wrongTap] so the UI can play a shake animation.
  TapArrowResult tapArrow(String arrowId) {
    if (state.isWon || state.isLost) return TapArrowResult.ignored;

    final index = state.arrows.indexWhere((arrow) => arrow.id == arrowId);
    if (index == -1) return TapArrowResult.ignored;

    final arrow = state.arrows[index];
    if (arrow.isRemoved) return TapArrowResult.ignored;

    final blocked = isArrowBlocked(
      arrow: arrow,
      arrows: state.arrows,
      gridRows: state.level.gridRows,
      gridCols: state.level.gridCols,
      shapeMask: state.level.shapeMask,
    );

    if (!blocked) {
      // New list + new instances so Riverpod / UI always rebuild.
      final updatedArrows = [
        for (final item in state.arrows)
          if (item.id == arrowId)
            item.copyWith(isRemoved: true)
          else
            ArrowModel(
              id: item.id,
              row: item.row,
              col: item.col,
              direction: item.direction,
              path: List<GridCell>.from(item.path),
              isRemoved: item.isRemoved,
            ),
      ];

      state = state.copyWith(arrows: updatedArrows);
      checkWinCondition();
      return TapArrowResult.removed;
    }

    final heartsLeft = state.heartsLeft - 1;
    state = state.copyWith(heartsLeft: heartsLeft);
    checkLoseCondition();
    return TapArrowResult.wrongTap;
  }

  /// Marks the level as won when every arrow has been removed.
  void checkWinCondition() {
    if (areAllArrowsRemoved(state.arrows)) {
      state = state.copyWith(isWon: true);
    }
  }

  /// Marks the level as lost when hearts run out before all arrows are cleared.
  void checkLoseCondition() {
    if (state.heartsLeft <= 0 && !areAllArrowsRemoved(state.arrows)) {
      state = state.copyWith(isLost: true);
    }
  }

  /// Spends one hint and returns the id of a currently free arrow to highlight.
  ///
  /// Returns null when no hints remain or no free arrow exists.
  String? useHint() {
    if (state.isWon || state.isLost) return null;
    if (state.hintsLeft <= 0) return null;

    final freeArrow = findFirstFreeArrow(
      arrows: state.arrows,
      gridRows: state.level.gridRows,
      gridCols: state.level.gridCols,
      shapeMask: state.level.shapeMask,
    );
    if (freeArrow == null) return null;

    state = state.copyWith(hintsLeft: state.hintsLeft - 1);
    return freeArrow.id;
  }

  /// After a rewarded ad (or placeholder), grant extra hints.
  void grantExtraHint({int count = 1}) {
    if (state.isWon || state.isLost) return;
    final next = state.hintsLeft + count;
    state = state.copyWith(hintsLeft: next < 0 ? 0 : next);
  }

  /// Reloads the level with fresh arrows, hearts, and hints.
  void resetLevel() {
    state = createInitialGameState(_level);
  }

  /// Rewarded-ad placeholder: restore one life and clear the lost state.
  void grantExtraLife() {
    if (!state.isLost) return;
    state = state.copyWith(heartsLeft: 1, isLost: false);
  }
}

/// Provides a [GameController] scoped to a specific [LevelModel].
final gameControllerProvider =
    StateNotifierProvider.family<GameController, GameState, LevelModel>(
  (ref, level) => GameController(level),
);
