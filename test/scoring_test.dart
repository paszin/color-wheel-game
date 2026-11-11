import 'package:color_wheel_game/logic/scoring.dart';
import 'package:color_wheel_game/model/board.dart';
import 'package:color_wheel_game/theme/palette.dart';
import 'package:flutter_test/flutter_test.dart';

const y = WheelColor.yellow;
const o = WheelColor.orange;
const r = WheelColor.red;
const p = WheelColor.purple;
const b = WheelColor.blue;
const g = WheelColor.green;

/// A straight line of fields 0–1–2–…; `null` leaves a field empty.
Board line(List<WheelColor?> colours) => Board.fromSpec(
  BoardSpec(
    positions: [for (var i = 0; i < colours.length; i++) Offset(i * 1.0, 0)],
    edges: [for (var i = 0; i + 1 < colours.length; i++) (i, i + 1)],
    preset: {
      for (var i = 0; i < colours.length; i++)
        if (colours[i] != null) i: colours[i]!,
    },
  ),
);

int pointsOf(MoveResult m, ScoreKind kind) =>
    m.events.where((e) => e.kind == kind).fold(0, (s, e) => s + e.points);

void main() {
  test('wheel order makes opposite colours complementary', () {
    expect(y.complement, p);
    expect(o.complement, b);
    expect(r.complement, g);
    expect(ColorWheel.classic.shift(g, 1), y);
    expect(ColorWheel.classic.shift(y, -1), g);
  });

  test('complements are the same on the twelve-colour wheel', () {
    expect(y.complement, p);
    expect(WheelColor.amber.complement, WheelColor.indigo);
    expect(WheelColor.turquoise.complement, WheelColor.coral);
    for (final c in WheelColor.values) {
      expect(c.complement.complement, c);
    }
  });

  test('same colour neighbour scores 1 and claims both fields', () {
    final board = line([b, null]);
    final m = evaluateMove(board.nodes[1], b);
    expect(m.points, 1);
    expect(m.claimed, {board.nodes[0], board.nodes[1]});
  });

  test('complementary neighbour scores 2', () {
    final board = line([y, null]);
    expect(evaluateMove(board.nodes[1], p).points, 2);
  });

  test('pair rules count every matching neighbour', () {
    // 1 point for the left blue, 2 for the right orange.
    final board = line([b, null, o]);
    final m = evaluateMove(board.nodes[1], b);
    expect(pointsOf(m, ScoreKind.same), 1);
    expect(pointsOf(m, ScoreKind.complement), 2);
  });

  test('a chain of two is no sequence', () {
    final board = line([y, null]);
    expect(pointsOf(evaluateMove(board.nodes[1], o), ScoreKind.sequence), 0);
  });

  test('sequence scores its length when the new card ends it', () {
    final board = line([y, o, null]);
    final m = evaluateMove(board.nodes[2], r);
    expect(pointsOf(m, ScoreKind.sequence), 3);
    expect(m.claimed.length, 3);
  });

  test('sequence through the middle and in descending order', () {
    final board = line([b, null, r, o]);
    // blue, purple, red, orange: descending along the line.
    final m = evaluateMove(board.nodes[1], p);
    expect(pointsOf(m, ScoreKind.sequence), 4);
    final chain = m.events.firstWhere((e) => e.kind == ScoreKind.sequence);
    expect(
      chain.nodes.map((n) => n.id).toList(),
      anyOf(equals([0, 1, 2, 3]), equals([3, 2, 1, 0])),
    );
  });

  test('sequence wraps from green to yellow', () {
    final board = line([b, g, null]);
    expect(pointsOf(evaluateMove(board.nodes[2], y), ScoreKind.sequence), 3);
  });

  test('all six colours earn the full-wheel bonus', () {
    final board = line([y, o, r, p, b, null]);
    final m = evaluateMove(board.nodes[5], g);
    expect(pointsOf(m, ScoreKind.sequence), 6);
    expect(pointsOf(m, ScoreKind.fullWheel), ColorWheel.classic.fullWheelBonus);
  });

  group('twelve-colour wheel', () {
    const wheel = ColorWheel.extended;

    test('a sequence steps through the intermediate tone', () {
      final board = line([y, WheelColor.amber, null]);
      final m = evaluateMove(board.nodes[2], o, wheel: wheel);
      expect(pointsOf(m, ScoreKind.sequence), 3);
    });

    test('main colours alone are no sequence', () {
      final board = line([y, o, null]);
      final m = evaluateMove(board.nodes[2], r, wheel: wheel);
      expect(pointsOf(m, ScoreKind.sequence), 0);
    });

    test('sequence wraps from lime to yellow', () {
      final board = line([g, WheelColor.lime, null]);
      final m = evaluateMove(board.nodes[2], y, wheel: wheel);
      expect(pointsOf(m, ScoreKind.sequence), 3);
    });

    test('all twelve colours earn the bigger bonus, six do not', () {
      final board = line([...WheelColor.values.take(11), null]);
      final m = evaluateMove(board.nodes[11], WheelColor.lime, wheel: wheel);
      expect(pointsOf(m, ScoreKind.sequence), 12);
      expect(pointsOf(m, ScoreKind.fullWheel), 6);

      final half = line([...WheelColor.values.take(5), null]);
      final short = evaluateMove(
        half.nodes[5],
        WheelColor.magenta,
        wheel: wheel,
      );
      expect(pointsOf(short, ScoreKind.fullWheel), 0);
    });
  });

  test('only the longest chain through the new card counts', () {
    // Field 0 is the new card (yellow) with two branches:
    // 0–1–2 (orange, red) and 0–3–4–5 (orange, red, purple).
    final board = Board.fromSpec(
      const BoardSpec(
        positions: [
          Offset(0, 0),
          Offset(1, 0),
          Offset(2, 0),
          Offset(0, 1),
          Offset(0, 2),
          Offset(0, 3),
        ],
        edges: [(0, 1), (1, 2), (0, 3), (3, 4), (4, 5)],
        preset: {1: o, 2: r, 3: o, 4: r, 5: p},
      ),
    );
    final m = evaluateMove(board.nodes[0], y);
    expect(pointsOf(m, ScoreKind.sequence), 4);
  });

  test('a chain never reuses a field', () {
    // Triangle yellow–orange–red: the new yellow cannot loop back.
    final board = Board.fromSpec(
      const BoardSpec(
        positions: [Offset(0, 0), Offset(1, 0), Offset(0.5, 1)],
        edges: [(0, 1), (1, 2), (2, 0)],
        preset: {1: o, 2: r},
      ),
    );
    final m = evaluateMove(board.nodes[0], y);
    expect(pointsOf(m, ScoreKind.sequence), 3);
  });

  test('secured fields are not claimed, but still score', () {
    final board = line([y, o, null]);
    board.nodes[0].secured = true;
    final m = evaluateMove(board.nodes[2], r);
    expect(pointsOf(m, ScoreKind.sequence), 3);
    expect(m.claimed, {board.nodes[1], board.nodes[2]});
  });

  group('after a full wheel', () {
    /// Line y–o–r–p–b–g–(empty), with the wheel's links spent.
    Board spentWheel() {
      final board = line([y, o, r, p, b, g, null]);
      for (var i = 0; i < 5; i++) {
        board.nodes[i].spentLinks.add(board.nodes[i + 1]);
        board.nodes[i + 1].spentLinks.add(board.nodes[i]);
      }
      return board;
    }

    test('no sequence runs along the spent links', () {
      final m = evaluateMove(spentWheel().nodes[6], y);
      expect(pointsOf(m, ScoreKind.sequence), 0);
    });

    test('same colour and complement still score', () {
      final board = spentWheel();
      expect(pointsOf(evaluateMove(board.nodes[6], g), ScoreKind.same), 1);
      expect(
        pointsOf(evaluateMove(board.nodes[6], r), ScoreKind.complement),
        2,
      );
    });

    test('a new sequence may include one card of the spent line', () {
      // Spent green (5) – new yellow (6) – orange (7): green, yellow,
      // orange is a fresh chain of three.
      final board = Board.fromSpec(
        BoardSpec(
          positions: [for (var i = 0; i < 8; i++) Offset(i * 1.0, 0)],
          edges: [for (var i = 0; i < 7; i++) (i, i + 1)],
          preset: const {0: y, 1: o, 2: r, 3: p, 4: b, 5: g, 7: o},
        ),
      );
      for (var i = 0; i < 5; i++) {
        board.nodes[i].spentLinks.add(board.nodes[i + 1]);
        board.nodes[i + 1].spentLinks.add(board.nodes[i]);
      }
      final m = evaluateMove(board.nodes[6], y);
      expect(pointsOf(m, ScoreKind.sequence), 3);
    });
  });

  test('evaluateMove leaves the board untouched', () {
    final board = line([y, null]);
    evaluateMove(board.nodes[1], p);
    expect(board.nodes[1].isEmpty, isTrue);
    expect(board.nodes[0].owner, isNull);
  });
}
