import 'package:arrow_drift/data/models/arrow_model.dart';
import 'package:arrow_drift/data/models/level_model.dart';

class GameState {
  GameState({
    required this.level,
    required this.arrows,
    required this.heartsLeft,
    required this.hintsLeft,
    this.isWon = false,
    this.isLost = false,
  });

  final LevelModel level;
  final List<ArrowModel> arrows;
  final int heartsLeft;
  final int hintsLeft;
  final bool isWon;
  final bool isLost;

  GameState copyWith({
    LevelModel? level,
    List<ArrowModel>? arrows,
    int? heartsLeft,
    int? hintsLeft,
    bool? isWon,
    bool? isLost,
  }) {
    return GameState(
      level: level ?? this.level,
      arrows: arrows ?? this.arrows,
      heartsLeft: heartsLeft ?? this.heartsLeft,
      hintsLeft: hintsLeft ?? this.hintsLeft,
      isWon: isWon ?? this.isWon,
      isLost: isLost ?? this.isLost,
    );
  }
}
