import 'dart:math';

import 'package:color_wheel_game/logic/ai.dart';
import 'package:color_wheel_game/logic/deck.dart';
import 'package:color_wheel_game/logic/game_state.dart';
import 'package:color_wheel_game/model/levels.dart';
import 'package:color_wheel_game/theme/palette.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('drawing favours colours not yet in the hand', () {
    final rng = Random(1);
    final hand = [WheelColor.red, WheelColor.red];
    var red = 0;
    const draws = 6000;
    for (var i = 0; i < draws; i++) {
      if (drawCard(hand, rng) == WheelColor.red) red++;
    }
    // Weight of red is 1/7 against 1 for the other five → about 2.8 %.
    expect(red / draws, lessThan(0.06));
    expect(red, greaterThan(0));
  });

  test('every level builds a connected board with valid presets', () {
    for (final level in levels) {
      final state = GameState(level, GameMode.twoPlayers, rng: Random(2));
      final nodes = state.board.nodes;
      final seen = {nodes.first};
      final queue = [nodes.first];
      while (queue.isNotEmpty) {
        for (final n in queue.removeLast().neighbors) {
          if (seen.add(n)) queue.add(n);
        }
      }
      expect(seen.length, nodes.length, reason: level.name);
      expect(
        nodes.where((n) => !n.isEmpty).every((n) => n.owner == null),
        isTrue,
      );
    }
  });

  test('play claims involved fields, refills the hand and passes the turn', () {
    final state = GameState(levels.first, GameMode.twoPlayers, rng: Random(3));
    final first = state.board.nodes[0];
    final second = state.board.nodes[1];
    state.players[0].hand[0] = WheelColor.yellow;
    state.players[1].hand[0] = WheelColor.purple;

    state.play(0, first);
    expect(first.owner, 0);
    expect(state.current, 1);
    expect(state.players[0].hand.length, handSize);

    final result = state.play(0, second);
    expect(result.points, 2);
    expect(first.owner, 1, reason: 'complementary pair steals the card');
    expect(state.players[1].points, 2);
    expect(state.ownedFields(1), 2);
    expect(state.total(1), 4);
  });

  test('computer games always finish on every level', () {
    for (final level in levels) {
      final rng = Random(level.number);
      final state = GameState(level, GameMode.twoPlayers, rng: rng);
      var moves = 0;
      while (!state.isOver) {
        final move = chooseAiMove(state, level.aiSkill, rng);
        expect(move.node.isEmpty, isTrue);
        state.play(move.handIndex, move.node);
        moves++;
      }
      expect(moves, state.board.nodes.length - level.build().preset.length);
      expect(
        state.ownedFields(0) + state.ownedFields(1),
        lessThanOrEqualTo(state.board.nodes.length),
      );
    }
  });

  test('a skilled computer beats a careless one most of the time', () {
    var skilledWins = 0;
    const games = 30;
    for (var g = 0; g < games; g++) {
      final rng = Random(100 + g);
      final state = GameState(levels[3], GameMode.twoPlayers, rng: rng);
      while (!state.isOver) {
        final skill = state.current == 0 ? 0.95 : 0.1;
        final move = chooseAiMove(state, skill, rng);
        state.play(move.handIndex, move.node);
      }
      if (state.winner == 0) skilledWins++;
    }
    expect(skilledWins, greaterThan(games * 0.6));
  });
}
