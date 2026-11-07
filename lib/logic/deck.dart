import 'dart:math';

import '../theme/palette.dart';

const handSize = 3;

/// Draws a colour for [hand]. Colours already in the hand are less likely,
/// so a hand of three rarely holds duplicates: weight = 1 / (1 + 3·count).
WheelColor drawCard(List<WheelColor> hand, Random rng) {
  final weights = [
    for (final c in WheelColor.values)
      1 / (1 + 3 * hand.where((h) => h == c).length),
  ];
  final total = weights.fold<double>(0, (a, b) => a + b);
  var roll = rng.nextDouble() * total;
  for (var i = 0; i < weights.length; i++) {
    roll -= weights[i];
    if (roll < 0) return WheelColor.values[i];
  }
  return WheelColor.values.last;
}

List<WheelColor> dealHand(Random rng) {
  final hand = <WheelColor>[];
  while (hand.length < handSize) {
    hand.add(drawCard(hand, rng));
  }
  return hand;
}
