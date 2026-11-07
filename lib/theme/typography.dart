import 'package:flutter/material.dart';

import 'palette.dart';

/// Serif for titles, handwriting for scores and labels, a soft sans for text.
/// The fonts are bundled in assets/fonts (see pubspec.yaml).
abstract final class AppText {
  static TextStyle title(double size, {Color color = Inks.ink}) => TextStyle(
    fontFamily: 'Cormorant Garamond',
    fontSize: size,
    fontWeight: FontWeight.w600,
    color: color,
    height: 1.05,
    fontFeatures: const [FontFeature.liningFigures()],
  );

  static TextStyle hand(
    double size, {
    Color color = Inks.ink,
    FontWeight weight = FontWeight.w600,
  }) => TextStyle(
    fontFamily: 'Caveat',
    fontSize: size,
    fontWeight: weight,
    color: color,
    height: 1.0,
  );

  static TextStyle body(double size, {Color color = Inks.ink}) => TextStyle(
    fontFamily: 'Nunito',
    fontSize: size,
    color: color,
    height: 1.4,
  );
}
