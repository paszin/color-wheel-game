import 'dart:math';

import 'package:color_wheel_game/logic/ai.dart';
import 'package:color_wheel_game/logic/deck.dart';
import 'package:color_wheel_game/logic/difficulty.dart';
import 'package:color_wheel_game/logic/game_state.dart';
import 'package:color_wheel_game/logic/scoring.dart';
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

  test('secured fields keep their owner, points still count in full', () {
    // Level 1 is a 3 × 3 grid: 0–1–2 is the top row, 5 sits below 2.
    final state = GameState(levels.first, GameMode.twoPlayers, rng: Random(3));
    final n = state.board.nodes;
    void put(WheelColor colour, int field) {
      state.players[state.current].hand[0] = colour;
      state.play(0, n[field]);
    }

    put(WheelColor.yellow, 0); // player 1
    expect(n[0].secured, isFalse, reason: 'no points, not secured yet');
    put(WheelColor.orange, 1); // player 2
    put(WheelColor.red, 2); // player 1: yellow–orange–red
    expect(state.lastMove!.points, 3);
    expect([n[0], n[1], n[2]].every((f) => f.owner == 0 && f.secured), isTrue);

    put(WheelColor.purple, 5); // player 2: yellow–orange–red–purple
    expect(state.lastMove!.points, 4, reason: 'the whole chain still scores');
    expect([n[0], n[1], n[2]].every((f) => f.owner == 0), isTrue);
    expect(n[5].owner, 1);
    expect(n[5].secured, isTrue);
    expect(state.total(1), 4 + 1, reason: '4 points plus the new field');
  });

  test('the computer can make the first move', () {
    final state = GameState(levels.first, GameMode.vsComputer, rng: Random(1));
    expect(state.notStarted, isTrue);
    state.secondPlayerStarts();
    expect(state.currentPlayer.isComputer, isTrue);

    final move = chooseAiMove(state, 0.5, Random(1));
    state.play(move.handIndex, move.node);
    expect(move.node.owner, 1);
    expect(state.current, 0);
    expect(state.notStarted, isFalse);
    expect(state.secondPlayerStarts, throwsStateError);
  });

  test('closing a full wheel spends its links', () {
    // Level 2 is a 4 × 4 grid; 0–1–2–3 / 7–6 snakes through six fields.
    final state = GameState(levels[1], GameMode.twoPlayers, rng: Random(2));
    final n = state.board.nodes;
    final path = [0, 1, 2, 3, 7, 6];
    for (var i = 0; i < 6; i++) {
      state.players[state.current].hand[0] = WheelColor.values[i];
      state.play(0, n[path[i]]);
    }
    expect(
      state.lastMove!.events.map((e) => e.kind),
      contains(ScoreKind.fullWheel),
    );
    for (var i = 0; i + 1 < path.length; i++) {
      expect(n[path[i]].spentLinks, contains(n[path[i + 1]]));
    }
    expect(n[0].spentLinks, isNot(contains(n[4])), reason: 'not in chain');
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

  test('difficulty orders the computer strength on every level', () {
    for (final level in levels) {
      final easy = Difficulty.easy.skillFor(level);
      final medium = Difficulty.medium.skillFor(level);
      final hard = Difficulty.hard.skillFor(level);
      expect(easy, lessThan(medium), reason: level.name);
      expect(medium, lessThan(hard), reason: level.name);
      expect(hard, lessThanOrEqualTo(1));
    }
  });

  test('hard beats easy most of the time', () {
    final level = levels[1];
    var hardWins = 0;
    const games = 30;
    for (var g = 0; g < games; g++) {
      final rng = Random(500 + g);
      final state = GameState(level, GameMode.twoPlayers, rng: rng);
      // Alternate who starts so the opening move does not decide.
      final hardPlayer = g.isEven ? 0 : 1;
      while (!state.isOver) {
        final d = state.current == hardPlayer
            ? Difficulty.hard
            : Difficulty.easy;
        final move = chooseAiMove(state, d.skillFor(level), rng);
        state.play(move.handIndex, move.node);
      }
      if (state.winner == hardPlayer) hardWins++;
    }
    expect(hardWins, greaterThan(games * 0.6));
  });
}
