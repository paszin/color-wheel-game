import '../model/levels.dart';
import '../theme/palette.dart';

/// Strength of the computer opponent, chosen independently of the level.
enum Difficulty {
  easy('Leicht', WheelColor.green),
  medium('Mittel', WheelColor.yellow),
  hard('Schwer', WheelColor.red);

  const Difficulty(this.label, this.color);

  final String label;
  final WheelColor color;

  /// Skill passed to the AI (see `chooseAiMove`).
  /// Medium keeps the per-level curve; easy plays a third as carefully;
  /// hard plays close to its best on every board.
  double skillFor(Level level) => switch (this) {
    Difficulty.easy => level.aiSkill * 0.35,
    Difficulty.medium => level.aiSkill,
    Difficulty.hard => (level.aiSkill + 0.3).clamp(0.9, 1.0),
  };
}
