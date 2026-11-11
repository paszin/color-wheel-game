import 'package:color_wheel_game/logic/scoring.dart';
import 'package:color_wheel_game/logic/tutorial.dart';
import 'package:color_wheel_game/model/tutorial.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('every scripted move is legal and scores what its text says', () {
    // Points per move, as promised in the step texts.
    const expected = [
      [0],
      [1],
      [4],
      [3],
      [4],
      [0, 1, 2],
      [11],
      [2],
      [3],
    ];
    expect(tutorialSteps.length, expected.length);
    for (var s = 0; s < tutorialSteps.length; s++) {
      final step = tutorialSteps[s];
      final state = tutorialState(step, s);
      for (var m = 0; m < step.moves.length; m++) {
        final move = step.moves[m];
        expect(move.hand, contains(move.color), reason: '${step.title} #$m');
        for (final c in move.hand) {
          expect(step.wheel.colors, contains(c));
        }
        final result = playTutorialMove(state, move);
        expect(result.points, expected[s][m], reason: '${step.title} #$m');
      }
    }
  });

  test('the ownership step: the computer takes the unsecured card', () {
    final step = tutorialSteps.firstWhere((s) => s.title == 'Felder erobern');
    final state = tutorialState(step, 0);
    for (final move in step.moves) {
      playTutorialMove(state, move);
    }
    final nodes = state.board.nodes;
    expect([for (final n in nodes) n.owner], [1, 1, 0]);
    expect(nodes.every((n) => n.secured), isTrue);
  });

  test('the full-wheel step closes all six colours', () {
    final step = tutorialSteps.firstWhere((s) => s.title == 'Voller Farbkreis');
    final result = playTutorialMove(tutorialState(step, 0), step.moves.single);
    expect(result.events.map((e) => e.kind), contains(ScoreKind.fullWheel));
  });

  test('the final step ends the game with 9 to 6', () {
    final step = tutorialSteps.firstWhere((s) => s.title == 'Spielende');
    final state = tutorialState(step, 0);
    playTutorialMove(state, step.moves.single);
    expect(state.isOver, isTrue);
    expect([state.total(0), state.total(1)], [9, 6]);
  });
}
