import 'package:shared_preferences/shared_preferences.dart';

/// Remembers the highest unlocked level (1-based) on this device.
class Progress {
  static const _key = 'unlockedLevel';

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
}
