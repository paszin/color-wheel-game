import 'package:shared_preferences/shared_preferences.dart';

import 'difficulty.dart';

/// Remembers the highest unlocked level (1-based) and the chosen computer
/// difficulty on this device.
class Progress {
  static const _key = 'unlockedLevel';
  static const _difficultyKey = 'difficulty';

  static Future<int> unlocked() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getInt(_key) ?? 1;
    } catch (_) {
      return 1;
    }
  }

  static Future<void> unlock(int level) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if ((prefs.getInt(_key) ?? 1) < level) await prefs.setInt(_key, level);
    } catch (_) {
      // Storage can be unavailable (private window); progress is a nicety.
    }
  }

  static Future<Difficulty> difficulty() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final name = prefs.getString(_difficultyKey);
      return Difficulty.values.firstWhere(
        (d) => d.name == name,
        orElse: () => Difficulty.medium,
      );
    } catch (_) {
      return Difficulty.medium;
    }
  }

  static Future<void> setDifficulty(Difficulty d) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_difficultyKey, d.name);
    } catch (_) {
      // See [unlock].
    }
  }
}
