import 'package:flutter/painting.dart';

/// All colours of the painter's colour wheel, in wheel order: the six main
/// colours and the six intermediate tones between them.
///
/// Opposite colours (index distance 6) are complementary, e.g.
/// yellow ↔ purple, amber ↔ indigo. The pigments are
/// deliberately muted so they sit together like watercolour pans instead of
/// pure screen colours.
enum WheelColor {
  yellow('Gelb', Color(0xFFE2B552)),
  amber('Bernstein', Color(0xFFE09E4C)),
  orange('Orange', Color(0xFFDB8449)),
  coral('Koralle', Color(0xFFD06B49)),
  red('Rot', Color(0xFFC2534D)),
  magenta('Magenta', Color(0xFFA35473)),
  purple('Violett', Color(0xFF8A619D)),
  indigo('Indigo', Color(0xFF6A6CA8)),
  blue('Blau', Color(0xFF4F7CAB)),
  turquoise('Türkis', Color(0xFF4F8E8C)),
  green('Grün', Color(0xFF6C9C6A)),
  lime('Limette', Color(0xFFA7AC58));

  const WheelColor(this.label, this.pigment);

  final String label;
  final Color pigment;

  /// The opposite colour. It is the same on the six- and the twelve-colour
  /// wheel, because the six main colours sit on every second place.
  WheelColor get complement =>
      values[(index + values.length ~/ 2) % values.length];

  bool isComplementOf(WheelColor other) => other == complement;

  /// Darker tone used where pigment pools at the edge of a wash.
  Color get deep => _tone(pigment, lightness: -0.15, saturation: 0.04);

  /// Lighter, more watery tone.
  Color get wash => _tone(pigment, lightness: 0.16, saturation: -0.08);
}

/// The colours a level plays with, in wheel order.
class ColorWheel {
  const ColorWheel._(this.colors, this.fullWheelBonus);

  /// Six main colours: yellow, orange, red, purple, blue, green.
  static const classic = ColorWheel._([
    WheelColor.yellow,
    WheelColor.orange,
    WheelColor.red,
    WheelColor.purple,
    WheelColor.blue,
    WheelColor.green,
  ], 3);

  /// All twelve colours including the intermediate tones.
  static const extended = ColorWheel._(WheelColor.values, 6);

  final List<WheelColor> colors;

  /// Bonus for a sequence that contains every colour of this wheel.
  final int fullWheelBonus;

  int get length => colors.length;

  /// Position of [c] on this wheel.
  int indexOf(WheelColor c) => colors.indexOf(c);

  /// The colour [steps] places further on this wheel, wrapping around.
  WheelColor shift(WheelColor c, int steps) =>
      colors[(indexOf(c) + steps) % length];
}

Color _tone(Color c, {double lightness = 0, double saturation = 0}) {
  final hsl = HSLColor.fromColor(c);
  return hsl
      .withLightness((hsl.lightness + lightness).clamp(0.0, 1.0))
      .withSaturation((hsl.saturation + saturation).clamp(0.0, 1.0))
      .toColor();
}

Color darken(Color c, double amount) => _tone(c, lightness: -amount);
Color lighten(Color c, double amount) => _tone(c, lightness: amount);

/// Paper and ink tones shared by the whole app.
abstract final class Inks {
  static const paper = Color(0xFFF5EFE3);
  static const paperShade = Color(0xFFE6DCCB);
  static const paperDeep = Color(0xFFD8CBB5);
  static const ink = Color(0xFF3A3530);
  static const graphite = Color(0xFF857D72);

  /// Ownership inks: indigo for player 1, burnt umber for player 2.
  static const players = [Color(0xFF2D3B5E), Color(0xFF7A3F25)];
}
