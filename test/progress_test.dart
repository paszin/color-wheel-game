import 'package:color_wheel_game/logic/progress.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test(
    'games without a win are counted per level and reset by a win',
    () async {
      expect(await Progress.recordResult(3, won: false), 1);
      expect(await Progress.recordResult(3, won: false), 2);
      expect(await Progress.recordResult(4, won: false), 1);
      expect(await Progress.recordResult(3, won: true), 0);
      expect(await Progress.recordResult(3, won: false), 1);
    },
  );

  test('the best total per level only goes up', () async {
    expect(await Progress.best(2), isNull);
    await Progress.submitBest(2, 30);
    await Progress.submitBest(2, 25);
    expect(await Progress.best(2), 30);
    await Progress.submitBest(2, 41);
    expect(await Progress.best(2), 41);
    expect(await Progress.best(5), isNull);
  });
}
