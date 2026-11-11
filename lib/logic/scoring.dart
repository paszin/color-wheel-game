import '../model/board.dart';
import '../theme/palette.dart';

enum ScoreKind {
  same('Gleiche Farbe'),
  complement('Komplementär'),
  sequence('Farbfolge'),
  fullWheel('Voller Farbkreis');

  const ScoreKind(this.label);
  final String label;
}

class ScoreEvent {
  const ScoreEvent(this.kind, this.nodes, this.points);

  final ScoreKind kind;

  /// Involved fields; for a sequence they are in chain order.
  final List<ColorNode> nodes;
  final int points;
}

class MoveResult {
  const MoveResult(this.node, this.color, this.events);

  final ColorNode node;
  final WheelColor color;
  final List<ScoreEvent> events;

  int get points => events.fold(0, (s, e) => s + e.points);

  /// Whether the move scores and therefore secures its fields.
  bool get secures => events.isNotEmpty;

  /// Every field that goes to the player making the move: [node] itself and
  /// each scoring field nobody has secured yet. Secured fields stay put.
  Set<ColorNode> get claimed => {
    node,
    for (final e in events)
      for (final n in e.nodes)
        if (!n.secured) n,
  };
}

const sameColorPoints = 1;
const complementPoints = 2;
const minSequenceLength = 3;

/// Upper bound for enumerated chain paths per direction, so a dense board
/// can never stall a move.
const _pathLimit = 4000;

/// Scores placing [color] on the empty [node] without changing the board.
///
/// * Every neighbour with the same colour: 1 point.
/// * Every neighbour with the complementary colour: 2 points.
/// * The longest chain of neighbouring cards through [node] that follows the
///   colour wheel step by step (either direction, wrapping from green back to
///   yellow) scores its length, if it is at least 3 long. A chain that
///   contains every colour of [wheel] earns [ColorWheel.fullWheelBonus].
/// * A sequence never runs along the links of an earlier full wheel
///   ([ColorNode.spentLinks]), so a closed wheel cannot be scored again.
MoveResult evaluateMove(
  ColorNode node,
  WheelColor color, {
  ColorWheel wheel = ColorWheel.classic,
}) {
  WheelColor? colorOf(ColorNode n) => identical(n, node) ? color : n.color;

  final events = <ScoreEvent>[];
  for (final n in node.neighbors) {
    final c = n.color;
    if (c == null) continue;
    if (c == color) {
      events.add(ScoreEvent(ScoreKind.same, [node, n], sameColorPoints));
    } else if (c.isComplementOf(color)) {
      events.add(ScoreEvent(ScoreKind.complement, [node, n], complementPoints));
    }
  }

  final chain = longestChainThrough(node, colorOf, wheel: wheel);
  if (chain.length >= minSequenceLength) {
    events.add(ScoreEvent(ScoreKind.sequence, chain, chain.length));
    final colours = {for (final n in chain) colorOf(n)};
    if (colours.length == wheel.length) {
      events.add(ScoreEvent(ScoreKind.fullWheel, chain, wheel.fullWheelBonus));
    }
  }
  return MoveResult(node, color, events);
}

/// Longest simple path through [start] in which every next card is the next
/// colour on the wheel. Reading the path backwards gives the descending
/// direction, so one direction covers both.
List<ColorNode> longestChainThrough(
  ColorNode start,
  WheelColor? Function(ColorNode) colorOf, {
  ColorWheel wheel = ColorWheel.classic,
}) {
  final startColor = colorOf(start);
  if (startColor == null) return [start];

  final forward = _paths(start, startColor, 1, colorOf, wheel);
  final backward = _paths(start, startColor, -1, colorOf, wheel);
  // Longest first, so the search can stop at the first disjoint pair that
  // cannot be beaten.
  forward.sort((a, b) => b.length.compareTo(a.length));
  backward.sort((a, b) => b.length.compareTo(a.length));

  var best = <ColorNode>[start];
  for (final f in forward) {
    if (f.length + 1 + backward.first.length <= best.length) break;
    final fSet = f.toSet();
    for (final b in backward) {
      final total = f.length + 1 + b.length;
      if (total <= best.length) break;
      if (b.any(fSet.contains)) continue;
      best = [...b.reversed, start, ...f];
      break;
    }
  }
  return best;
}

/// All simple paths leaving [start] (excluding it) where each card is
/// [step] positions on [wheel] after the previous one. Includes the empty path.
List<List<ColorNode>> _paths(
  ColorNode start,
  WheelColor startColor,
  int step,
  WheelColor? Function(ColorNode) colorOf,
  ColorWheel wheel,
) {
  final out = <List<ColorNode>>[];
  final path = <ColorNode>[];
  final visited = <ColorNode>{start};

  void walk(ColorNode cur, WheelColor curColor) {
    out.add(List.of(path));
    if (out.length >= _pathLimit) return;
    final want = wheel.shift(curColor, step);
    for (final n in cur.neighbors) {
      if (visited.contains(n) || colorOf(n) != want) continue;
      if (cur.spentLinks.contains(n)) continue;
      visited.add(n);
      path.add(n);
      walk(n, want);
      path.removeLast();
      visited.remove(n);
      if (out.length >= _pathLimit) return;
    }
  }

  walk(start, startColor);
  return out;
}
