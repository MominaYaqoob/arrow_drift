enum ArrowDirection { up, down, left, right }

/// One grid cell occupied by an arrow body (or tip).
class GridCell {
  const GridCell(this.row, this.col);

  final int row;
  final int col;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GridCell && other.row == row && other.col == col;

  @override
  int get hashCode => Object.hash(row, col);

  @override
  String toString() => '($row,$col)';
}

class ArrowModel {
  ArrowModel({
    required this.id,
    required this.row,
    required this.col,
    required this.direction,
    List<GridCell>? path,
    this.isRemoved = false,
  }) : path = List<GridCell>.unmodifiable(
          path ?? [GridCell(row, col)],
        );

  final String id;

  /// Tip cell row (last cell in [path]).
  int row;

  /// Tip cell col (last cell in [path]).
  int col;

  final ArrowDirection direction;

  /// Body cells ordered tail → tip. Always non-empty; tip is last.
  final List<GridCell> path;

  bool isRemoved;

  bool get isMultiCell => path.length > 1;

  ArrowModel copyWith({
    String? id,
    int? row,
    int? col,
    ArrowDirection? direction,
    List<GridCell>? path,
    bool? isRemoved,
  }) {
    final nextPath = path ?? this.path;
    final tip = nextPath.isNotEmpty ? nextPath.last : null;
    return ArrowModel(
      id: id ?? this.id,
      row: row ?? tip?.row ?? this.row,
      col: col ?? tip?.col ?? this.col,
      direction: direction ?? this.direction,
      path: nextPath,
      isRemoved: isRemoved ?? this.isRemoved,
    );
  }
}
