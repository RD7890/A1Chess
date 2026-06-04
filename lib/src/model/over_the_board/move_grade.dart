import 'package:flutter/material.dart';

/// Quality classification of a chess move vs. the engine's best.
enum MoveGrade {
  brilliant('✦ Brilliant',  Color(0xFF00BCD4), 'Better than the engine!'),
  best     ('★ Best Move',  Color(0xFF2ECC40), "Engine's top choice"),
  good     ('▲ Good',       Color(0xFF8BC34A), 'Solid move'),
  inaccuracy('~ Inaccuracy',Color(0xFFFF9F1A), 'Better options existed'),
  mistake  ('? Mistake',    Color(0xFFFF5722), 'Significant error'),
  blunder  ('?? Blunder',   Color(0xFFE74C3C), 'Major blunder');

  const MoveGrade(this.label, this.color, this.note);

  final String label;
  final Color color;
  final String note;

  /// Grade based on centipawn gain for the side that moved.
  /// [cpGain] = eval after move (player's POV) − eval before move (player's POV).
  /// Positive = improvement (brilliant/best), negative = loss (mistake/blunder).
  static MoveGrade fromCentipawnGain(int cpGain) {
    if (cpGain > 30)   return MoveGrade.brilliant;
    if (cpGain >= 0)   return MoveGrade.best;
    if (cpGain >= -20) return MoveGrade.good;
    if (cpGain >= -60) return MoveGrade.inaccuracy;
    if (cpGain >= -150)return MoveGrade.mistake;
    return MoveGrade.blunder;
  }
}

/// Result of grading a single played move.
class MoveGradeResult {
  const MoveGradeResult({
    required this.grade,
    required this.playedUci,
    required this.bestUci,
  });

  final MoveGrade grade;
  /// UCI of the move the player actually played (e.g. "e2e4").
  final String playedUci;
  /// UCI of the engine's best move before this move was made.
  final String bestUci;
}
