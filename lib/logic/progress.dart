import 'package:shared_preferences/shared_preferences.dart';

import 'difficulty.dart';

/// Remembers the highest unlocked level (1-based), the chosen computer
/// difficulty, the games in a row without a win and the best total per level
/// on this device.
class Progress {
  static const _key = 'unlockedLevel';
  static const _difficultyKey = 'difficulty';
  static String _lossesKey(int level) => 'lossesInRow_$level';
  static String _bestKey(int level) => 'bestTotal_$level';

  /// Records a finished game against the computer on [level] and returns
  /// the games in a row without a win, including this one (0 after a win).
  static Future<int> recordResult(int level, {required bool won}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final losses = won ? 0 : (prefs.getInt(_lossesKey(level)) ?? 0) + 1;
      await prefs.setInt(_lossesKey(level), losses);
      return losses;
    } catch (_) {
      return won ? 0 : 1;
    }
  }

  /// Best own total on [level] so far, or null if none is stored.
  static Future<int?> best(int level) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getInt(_bestKey(level));
    } catch (_) {
      return null;
    }
  }

  /// Stores [total] if it beats the best total on [level].
  static Future<void> submitBest(int level, int total) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final old = prefs.getInt(_bestKey(level));
      if (old == null || total > old) {
        await prefs.setInt(_bestKey(level), total);
      }
    } catch (_) {
      // See [unlock].
    }
  }

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
