import 'package:arrow_drift/data/models/arrow_model.dart';

enum LevelDifficulty {
  easy,
  medium,
  hard,
  hardPlus,
  expert,
  expertPlus,
  master,
  grandmaster,
}

extension LevelDifficultyLabel on LevelDifficulty {
  String get label => switch (this) {
        LevelDifficulty.easy => 'Easy',
        LevelDifficulty.medium => 'Medium',
        LevelDifficulty.hard => 'Hard',
        LevelDifficulty.hardPlus => 'Hard+',
        LevelDifficulty.expert => 'Expert',
        LevelDifficulty.expertPlus => 'Expert+',
        LevelDifficulty.master => 'Master',
        LevelDifficulty.grandmaster => 'Grandmaster',
      };
}

class LevelModel {
  LevelModel({
    required this.levelNumber,
    required this.gridRows,
    required this.gridCols,
    required this.arrows,
    required this.heartsAllowed,
    required this.hintsAllowed,
    this.difficulty = LevelDifficulty.easy,
    this.shapeMask,
  });

  final int levelNumber;
  final int gridRows;
  final int gridCols;
  final List<ArrowModel> arrows;
  final int heartsAllowed;
  final int hintsAllowed;
  final LevelDifficulty difficulty;

  /// When set, only these cells are playable / dotted (e.g. heart silhouette).
  final List<List<bool>>? shapeMask;

  LevelModel copyWith({
    int? levelNumber,
    int? gridRows,
    int? gridCols,
    List<ArrowModel>? arrows,
    int? heartsAllowed,
    int? hintsAllowed,
    LevelDifficulty? difficulty,
    List<List<bool>>? shapeMask,
  }) {
    return LevelModel(
      levelNumber: levelNumber ?? this.levelNumber,
      gridRows: gridRows ?? this.gridRows,
      gridCols: gridCols ?? this.gridCols,
      arrows: arrows ?? this.arrows,
      heartsAllowed: heartsAllowed ?? this.heartsAllowed,
      hintsAllowed: hintsAllowed ?? this.hintsAllowed,
      difficulty: difficulty ?? this.difficulty,
      shapeMask: shapeMask ?? this.shapeMask,
    );
  }

  /// Family providers key off [levelNumber] so instances stay stable.
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LevelModel && other.levelNumber == levelNumber;

  @override
  int get hashCode => levelNumber.hashCode;
}
