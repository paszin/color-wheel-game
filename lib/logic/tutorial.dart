import 'dart:math';

import '../model/levels.dart';
import '../model/tutorial.dart';
import 'game_state.dart';
import 'scoring.dart';

/// Builds the game for tutorial [step] number [index]: its board, the preset
/// owners and points.
GameState tutorialState(TutorialStep step, int index) {
  final level = Level(
    // Distinct numbers keep the pencil lines of the steps apart.
    number: 100 + index,
    name: step.title,
    subtitle: '',
    aiSkill: 0,
    build: step.board,
    wheel: step.wheel,
  );
  final state = GameState(level, GameMode.vsComputer, rng: Random(index));
  step.owners.forEach((id, owner) {
    state.board.nodes[id]
      ..owner = owner.$1
      ..secured = owner.$2;
  });
  state.players[0].points = step.points.$1;
  state.players[1].points = step.points.$2;
  return state;
}

/// Gives the mover of [move] its scripted hand and makes them current.
void prepareTutorialMove(GameState state, TutorialMove move) {
  state.current = move.byComputer ? 1 : 0;
  state.currentPlayer.hand
    ..clear()
    ..addAll(move.hand);
}

/// Plays [move] exactly as scripted.
MoveResult playTutorialMove(GameState state, TutorialMove move) {
  prepareTutorialMove(state, move);
  return state.play(
    move.hand.indexOf(move.color),
    state.board.nodes[move.node],
  );
}
