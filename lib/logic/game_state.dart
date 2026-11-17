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
  GameState(this.level, this.mode, {Random? rng, this.happy = false})
    : rng = rng ?? Random(),
      board = Board.fromSpec(level.build()) {
    players = [
      PlayerState(
        mode == GameMode.vsComputer ? 'Du' : 'Spieler 1',
        isComputer: false,
        hand: dealHand(this.rng, wheel: level.wheel, size: level.handSize),
      ),
      PlayerState(
        mode == GameMode.vsComputer ? 'Computer' : 'Spieler 2',
        isComputer: mode == GameMode.vsComputer,
        hand: dealHand(this.rng, wheel: level.wheel, size: level.handSize),
      ),
    ];
    if (happy) {
      final hand = players[0].hand;
      for (var i = 0; i < hand.length; i++) {
        hand[i] = _draw(players[0], [...hand]..removeAt(i));
      }
    }
  }

  final Level level;
  final GameMode mode;
  final Random rng;
  final Board board;

  /// Happy difficulty: the player always wins. A computer card that does not
  /// score stays neutral, and a computer move that would take a card from
  /// the player or bring the computer level with them scores nothing (see
  /// [holdsBack]). So the computer total only grows while it stays behind.
  /// The human player is dealt cards that score (see `goodCard`).
  final bool happy;
  late final List<PlayerState> players;

  int current = 0;
  MoveResult? lastMove;

  PlayerState get currentPlayer => players[current];

  /// True until the first card is placed.
  bool get notStarted => lastMove == null;

  /// Lets the second player (the computer) make the first move.
  void secondPlayerStarts() {
    if (!notStarted) throw StateError('The game has already started');
    current = 1;
    notifyListeners();
  }

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

  /// A new card for [player]: on happy the human gets one that scores.
  WheelColor _draw(PlayerState player, List<WheelColor> rest) =>
      happy && !player.isComputer
      ? goodCard(board, rest, rng, wheel: level.wheel)
      : drawCard(rest, rng, wheel: level.wheel);

  /// Whether the happy computer, about to make [r], gives up its points.
  bool holdsBack(MoveResult r) {
    if (!happy || !currentPlayer.isComputer || !r.secures) return false;
    final me = current, opp = 1 - current;
    if (r.claimed.any((n) => n.owner == opp)) return true;
    final gain = r.points + r.claimed.where((n) => n.owner != me).length;
    return total(me) + gain >= total(opp);
  }

  /// Places card [handIndex] of the current player on [node], scores it,
  /// claims and secures every involved field nobody has secured yet,
  /// refills the hand and passes the turn.
  MoveResult play(int handIndex, ColorNode node) {
    if (isOver) throw StateError('Game is over');
    if (!node.isEmpty) throw ArgumentError('Field ${node.id} is taken');
    final player = currentPlayer;
    final color = player.hand[handIndex];

    var result = evaluateMove(node, color, wheel: level.wheel);
    if (holdsBack(result)) result = MoveResult(node, color, const []);
    node.color = color;
    for (final n in result.claimed) {
      n.owner = current;
      if (result.secures) n.secured = true;
    }
    if (happy && player.isComputer && !result.secures) node.owner = null;
    for (final e in result.events) {
      if (e.kind == ScoreKind.fullWheel) {
        for (var i = 0; i + 1 < e.nodes.length; i++) {
          e.nodes[i].spentLinks.add(e.nodes[i + 1]);
          e.nodes[i + 1].spentLinks.add(e.nodes[i]);
        }
      }
    }
    player.points += result.points;
    final rest = [...player.hand]..removeAt(handIndex);
    player.hand[handIndex] = _draw(player, rest);
    lastMove = result;
    if (!isOver) current = 1 - current;
    notifyListeners();
    return result;
  }
}
