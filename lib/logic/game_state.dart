import 'dart:math';

import 'package:flutter/foundation.dart';

import '../model/board.dart';
import '../model/levels.dart';
import '../theme/palette.dart';
import 'deck.dart';
import 'scoring.dart';

enum GameMode { vsComputer, twoPlayers }

class PlayerState {
  PlayerState(this.name, {required this.isComputer, required this.hand});

  final String name;
  final bool isComputer;
  final List<WheelColor> hand;
  int points = 0;
}

class GameState extends ChangeNotifier {
  GameState(this.level, this.mode, {Random? rng})
    : rng = rng ?? Random(),
      board = Board.fromSpec(level.build()) {
    players = [
      PlayerState(
        mode == GameMode.vsComputer ? 'Du' : 'Spieler 1',
        isComputer: false,
        hand: dealHand(this.rng),
      ),
      PlayerState(
        mode == GameMode.vsComputer ? 'Computer' : 'Spieler 2',
        isComputer: mode == GameMode.vsComputer,
        hand: dealHand(this.rng),
      ),
    ];
  }

  final Level level;
  final GameMode mode;
  final Random rng;
  final Board board;
  late final List<PlayerState> players;

  int current = 0;
  MoveResult? lastMove;

  PlayerState get currentPlayer => players[current];

  bool get isOver => board.isFull;

  int ownedFields(int player) =>
      board.nodes.where((n) => n.owner == player).length;

  /// Final standing: scored points plus one per owned field.
  int total(int player) => players[player].points + ownedFields(player);

  /// Index of the winner, or null for a draw. Only meaningful when [isOver].
  int? get winner {
    final a = total(0), b = total(1);
    if (a == b) return null;
    return a > b ? 0 : 1;
  }

  /// Places card [handIndex] of the current player on [node], scores it,
  /// claims all involved fields, refills the hand and passes the turn.
  MoveResult play(int handIndex, ColorNode node) {
    if (isOver) throw StateError('Game is over');
    if (!node.isEmpty) throw ArgumentError('Field ${node.id} is taken');
    final player = currentPlayer;
    final color = player.hand[handIndex];

    final result = evaluateMove(node, color);
    node.color = color;
    for (final n in result.claimed) {
      n.owner = current;
    }
    player.points += result.points;
    final rest = [...player.hand]..removeAt(handIndex);
    player.hand[handIndex] = drawCard(rest, rng);
    lastMove = result;
    if (!isOver) current = 1 - current;
    notifyListeners();
    return result;
  }
}
