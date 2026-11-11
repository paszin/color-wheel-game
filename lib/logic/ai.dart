import 'dart:math';

import '../model/board.dart';
import '../theme/palette.dart';
import 'game_state.dart';
import 'scoring.dart';

class AiMove {
  const AiMove(this.handIndex, this.node);
  final int handIndex;
  final ColorNode node;
}

/// Greedy computer player.
///
/// A move is worth its points plus the change in owned fields (stealing a
/// card swings the standing by two). From [skill] 0.5 upwards it also
/// subtracts what the opponent could score next to the new card. Lower skill
/// adds more random noise, so early levels make human-like mistakes.
AiMove chooseAiMove(GameState state, double skill, Random rng) {
  final me = state.current;
  final opp = 1 - me;
  final hand = state.players[me].hand;
  final oppHand = state.players[opp].hand.toSet();
  final wheel = state.level.wheel;

  AiMove? best;
  var bestValue = double.negativeInfinity;
  final triedColours = <WheelColor>{};

  for (var i = 0; i < hand.length; i++) {
    if (!triedColours.add(hand[i])) continue;
    for (final node in state.board.empty) {
      final result = evaluateMove(node, hand[i], wheel: wheel);
      var value = result.points + _ownershipGain(result, me, opp);
      if (skill >= 0.5) {
        value -=
            _threat(node, hand[i], result.secures, me, opp, oppHand, wheel) *
            skill *
            0.7;
      }
      value += rng.nextDouble() * (1 - skill) * 4;
      if (value > bestValue) {
        bestValue = value;
        best = AiMove(i, node);
      }
    }
  }
  return best!;
}

double _ownershipGain(MoveResult r, int me, int opp) {
  var gain = 0.0;
  for (final n in r.claimed) {
    if (identical(n, r.node) || n.owner == null) {
      gain += 1;
    } else if (n.owner == opp) {
      gain += 2;
    } else if (n.owner == me) {
      gain += 0.5; // securing an own card protects it
    }
  }
  return gain;
}

/// Best value the opponent could reach on a field next to [node] once
/// [color] lies there.
double _threat(
  ColorNode node,
  WheelColor color,
  bool secured,
  int me,
  int opp,
  Set<WheelColor> oppHand,
  ColorWheel wheel,
) {
  node.color = color;
  node.owner = me;
  node.secured = secured;
  var worst = 0.0;
  try {
    for (final m in node.neighbors) {
      if (!m.isEmpty) continue;
      for (final c in oppHand) {
        final r = evaluateMove(m, c, wheel: wheel);
        if (r.points == 0) continue;
        final v = r.points + _ownershipGain(r, opp, me);
        if (v > worst) worst = v;
      }
    }
  } finally {
    node.color = null;
    node.owner = null;
    node.secured = false;
  }
  return worst;
}
