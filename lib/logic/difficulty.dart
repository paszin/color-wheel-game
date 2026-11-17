import '../model/levels.dart';
import '../theme/palette.dart';

/// Strength of the computer opponent, chosen independently of the level.
enum Difficulty {
  happy('Lucky you', WheelColor.magenta),
  easy('Leicht', WheelColor.green),
  medium('Mittel', WheelColor.yellow),
  hard('Schwer', WheelColor.red);

  const Difficulty(this.label, this.color);

  final String label;
  final WheelColor color;

  /// Happy does not play to win: the computer uses `chooseHappyMove`, sets
  /// up scoring chances for the player and always stays behind.
  bool get isHappy => this == Difficulty.happy;

  /// Skill passed to the AI (see `chooseAiMove`); unused on [isHappy].
  /// Medium keeps the per-level curve; easy plays a third as carefully;
  /// hard plays close to its best on every board.
  double skillFor(Level level) => switch (this) {
    Difficulty.happy => 0,
    Difficulty.easy => level.aiSkill * 0.35,
    Difficulty.medium => level.aiSkill,
    Difficulty.hard => (level.aiSkill + 0.3).clamp(0.9, 1.0),
  };
}
