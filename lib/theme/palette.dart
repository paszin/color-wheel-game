import 'package:flutter/painting.dart';

/// The six colours of the painter's colour wheel, in wheel order.
///
/// Opposite colours (index distance 3) are complementary:
/// yellow ↔ purple, orange ↔ blue, red ↔ green.
/// The pigments are deliberately muted so they sit together like
/// watercolour pans instead of pure screen colours.
enum WheelColor {
  yellow('Gelb', Color(0xFFE2B552)),
  orange('Orange', Color(0xFFDB8449)),
  red('Rot', Color(0xFFC2534D)),
  purple('Violett', Color(0xFF8A619D)),
  blue('Blau', Color(0xFF4F7CAB)),
  green('Grün', Color(0xFF6C9C6A));

  const WheelColor(this.label, this.pigment);

  final String label;
  final Color pigment;

  WheelColor shift(int steps) => values[(index + steps) % values.length];

  WheelColor get complement => shift(values.length ~/ 2);

  bool isComplementOf(WheelColor other) => other == complement;

  /// Darker tone used where pigment pools at the edge of a wash.
  Color get deep => _tone(pigment, lightness: -0.15, saturation: 0.04);

  /// Lighter, more watery tone.
  Color get wash => _tone(pigment, lightness: 0.16, saturation: -0.08);
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
