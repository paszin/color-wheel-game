import 'dart:math';

import '../model/board.dart';
import '../theme/palette.dart';
import 'scoring.dart';

/// Cards in hand on the six-colour levels; a level can ask for more.
const defaultHandSize = 3;

/// Draws a colour of [wheel] for [hand]. Colours already in the hand are less
/// likely, so a hand rarely holds duplicates: weight = 1 / (1 + 3·count).
WheelColor drawCard(
  List<WheelColor> hand,
  Random rng, {
  ColorWheel wheel = ColorWheel.classic,
}) {
  final colours = wheel.colors;
  final weights = [
    for (final c in colours) 1 / (1 + 3 * hand.where((h) => h == c).length),
  ];
  final total = weights.fold<double>(0, (a, b) => a + b);
  var roll = rng.nextDouble() * total;
  for (var i = 0; i < weights.length; i++) {
    roll -= weights[i];
    if (roll < 0) return colours[i];
  }
  return colours.last;
}

List<WheelColor> dealHand(
  Random rng, {
  ColorWheel wheel = ColorWheel.classic,
  int size = defaultHandSize,
}) {
  final hand = <WheelColor>[];
  while (hand.length < size) {
    hand.add(drawCard(hand, rng, wheel: wheel));
  }
  return hand;
}

/// The colour that scores most on [board] right now, for the happy
/// difficulty. Colours already in [hand] count less, so the player gets
/// chances for several fields. Falls back to [drawCard] while no colour can
/// score anywhere, e.g. on an empty board.
WheelColor goodCard(
  Board board,
  List<WheelColor> hand,
  Random rng, {
  ColorWheel wheel = ColorWheel.classic,
}) {
  WheelColor? best;
  var bestValue = 0.0;
  for (final c in wheel.colors) {
    var points = 0;
    for (final node in board.empty) {
      points = max(points, evaluateMove(node, c, wheel: wheel).points);
    }
    if (points == 0) continue;
    final value =
        points - 2.0 * hand.where((h) => h == c).length + rng.nextDouble();
    if (value > bestValue) {
      bestValue = value;
      best = c;
    }
  }
  return best ?? drawCard(hand, rng, wheel: wheel);
}
