import 'dart:ui' show Offset;

import '../theme/palette.dart';

/// One field of the board graph. A field is empty until a colour card is
/// placed on it; afterwards [color] never changes, but [owner] can, until the
/// card is [secured] by the first scoring move it takes part in.
class ColorNode {
  ColorNode(this.id, this.position);

  final int id;

  /// Position in board units; the renderer scales it to the screen.
  final Offset position;

  final List<ColorNode> neighbors = [];

  WheelColor? color;

  /// Index of the owning player, or null for an empty field or a neutral
  /// pre-printed card.
  int? owner;

  /// Set once a card is part of a scoring move. A secured card keeps its
  /// owner for the rest of the game; until then the next scorer takes it.
  bool secured = false;

  bool get isEmpty => color == null;

  @override
  String toString() => 'ColorNode($id, ${color?.name ?? '-'})';
}

class BoardSpec {
  const BoardSpec({
    required this.positions,
    required this.edges,
    this.preset = const {},
  });

  final List<Offset> positions;
  final List<(int, int)> edges;

  /// Neutral cards printed on the board before the game starts.
  final Map<int, WheelColor> preset;
}

class Board {
  Board._(this.nodes);

  factory Board.fromSpec(BoardSpec spec) {
    final nodes = [
      for (var i = 0; i < spec.positions.length; i++)
        ColorNode(i, spec.positions[i]),
    ];
    final seen = <(int, int)>{};
    for (final (a, b) in spec.edges) {
      if (a == b) continue;
      final key = a < b ? (a, b) : (b, a);
      if (!seen.add(key)) continue;
      nodes[a].neighbors.add(nodes[b]);
      nodes[b].neighbors.add(nodes[a]);
    }
    spec.preset.forEach((i, c) => nodes[i].color = c);
    return Board._(nodes);
  }

  final List<ColorNode> nodes;

  Iterable<ColorNode> get empty => nodes.where((n) => n.isEmpty);

  bool get isFull => nodes.every((n) => !n.isEmpty);

  /// Every edge exactly once.
  Iterable<(ColorNode, ColorNode)> get edges sync* {
    for (final n in nodes) {
      for (final m in n.neighbors) {
        if (n.id < m.id) yield (n, m);
      }
    }
  }
}
