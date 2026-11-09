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
    expect(g.shift(1), y);
    expect(y.shift(-1), g);
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
    expect(pointsOf(m, ScoreKind.fullWheel), fullWheelBonus);
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

  test('evaluateMove leaves the board untouched', () {
    final board = line([y, null]);
    evaluateMove(board.nodes[1], p);
    expect(board.nodes[1].isEmpty, isTrue);
    expect(board.nodes[0].owner, isNull);
  });
}
