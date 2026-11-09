/// Options read from the page URL, e.g. `…/color-wheel-game/?punkte`.
library;

/// Shows how many points a card would score while hovering over a field.
/// Off by default; on with the URL parameter `punkte` (any value but `0`).
final bool showPointPreview = () {
  final value = Uri.base.queryParameters['punkte'];
  return value != null && value != '0';
}();
