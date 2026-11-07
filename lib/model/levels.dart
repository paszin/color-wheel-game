import 'dart:math' as math;
import 'dart:ui' show Offset;

import '../theme/palette.dart';
import 'board.dart';

class Level {
  const Level({
    required this.number,
    required this.name,
    required this.subtitle,
    required this.aiSkill,
    required this.build,
  });

  final int number;
  final String name;
  final String subtitle;

  /// 0 = careless, 1 = plays the best move it finds.
  final double aiSkill;
  final BoardSpec Function() build;
}

const _y = WheelColor.yellow;
const _o = WheelColor.orange;
const _r = WheelColor.red;
const _p = WheelColor.purple;
const _b = WheelColor.blue;
const _g = WheelColor.green;

final levels = <Level>[
  Level(
    number: 1,
    name: 'Erster Tropfen',
    subtitle: 'Ein kleines Raster zum Kennenlernen',
    aiSkill: 0.15,
    build: () => grid(3, 3),
  ),
  Level(
    number: 2,
    name: 'Leinwand',
    subtitle: 'Mehr Platz für lange Farbfolgen',
    aiSkill: 0.3,
    build: () => grid(4, 4),
  ),
  Level(
    number: 3,
    name: 'Kreisring',
    subtitle: 'Zwei Ringe, verbunden durch Speichen',
    aiSkill: 0.4,
    build: () => rings(8),
  ),
  Level(
    number: 4,
    name: 'Waben',
    subtitle: 'Sechs Nachbarn je Feld',
    aiSkill: 0.5,
    build: () => hexagon(2, preset: {4: _o, 14: _b}),
  ),
  Level(
    number: 5,
    name: 'Zwei Inseln',
    subtitle: 'Eine Brücke entscheidet',
    aiSkill: 0.6,
    build: () => islands(preset: {9: _g, 0: _y, 18: _p}),
  ),
  Level(
    number: 6,
    name: 'Mandala',
    subtitle: 'Vom Zentrum nach außen',
    aiSkill: 0.7,
    build: () => mandala(preset: {0: _r, 7: _y, 13: _b}),
  ),
  Level(
    number: 7,
    name: 'Mosaik',
    subtitle: 'Auch diagonal benachbart',
    aiSkill: 0.8,
    build: () => grid(
      5,
      5,
      diagonal: true,
      skip: {0, 4, 20, 24},
      preset: {7: _p, 12: _o, 17: _g},
    ),
  ),
  Level(
    number: 8,
    name: 'Pinselstrich',
    subtitle: 'Das große Finale',
    aiSkill: 0.9,
    build: () => staggered(4, 7, preset: {1: _b, 9: _r, 18: _y, 26: _g}),
  ),
];

/// Rectangular grid with orthogonal (and optionally diagonal) neighbours.
/// [skip] and [preset] use row-major indices of the full grid.
BoardSpec grid(
  int cols,
  int rows, {
  bool diagonal = false,
  Set<int> skip = const {},
  Map<int, WheelColor> preset = const {},
}) {
  final index = <int, int>{};
  final positions = <Offset>[];
  for (var r = 0; r < rows; r++) {
    for (var c = 0; c < cols; c++) {
      final full = r * cols + c;
      if (skip.contains(full)) continue;
      index[full] = positions.length;
      positions.add(Offset(c.toDouble(), r.toDouble()));
    }
  }
  final edges = <(int, int)>[];
  void link(int r1, int c1, int r2, int c2) {
    if (r2 < 0 || r2 >= rows || c2 < 0 || c2 >= cols) return;
    final a = index[r1 * cols + c1], b = index[r2 * cols + c2];
    if (a != null && b != null) edges.add((a, b));
  }

  for (var r = 0; r < rows; r++) {
    for (var c = 0; c < cols; c++) {
      link(r, c, r, c + 1);
      link(r, c, r + 1, c);
      if (diagonal) {
        link(r, c, r + 1, c + 1);
        link(r, c, r + 1, c - 1);
      }
    }
  }
  return BoardSpec(
    positions: positions,
    edges: edges,
    preset: {
      for (final e in preset.entries)
        if (index[e.key] != null) index[e.key]!: e.value,
    },
  );
}

/// Inner and outer ring of [count] fields each, joined by spokes.
BoardSpec rings(int count) {
  final positions = <Offset>[];
  for (final radius in [1.3, 2.4]) {
    for (var i = 0; i < count; i++) {
      final a = -math.pi / 2 + i * 2 * math.pi / count;
      positions.add(Offset(math.cos(a), math.sin(a)) * radius);
    }
  }
  return BoardSpec(
    positions: positions,
    edges: [
      for (var i = 0; i < count; i++) ...[
        (i, (i + 1) % count),
        (count + i, count + (i + 1) % count),
        (i, count + i),
      ],
    ],
  );
}

/// Hexagon of hex cells with the given [radius] (radius 2 → 19 fields).
BoardSpec hexagon(int radius, {Map<int, WheelColor> preset = const {}}) {
  final coords = <(int, int)>[];
  for (var r = -radius; r <= radius; r++) {
    for (var q = -radius; q <= radius; q++) {
      if ((q + r).abs() <= radius) coords.add((q, r));
    }
  }
  final index = {for (var i = 0; i < coords.length; i++) coords[i]: i};
  const dirs = [(1, 0), (0, 1), (-1, 1)];
  return BoardSpec(
    positions: [
      for (final (q, r) in coords) Offset(math.sqrt(3) * (q + r / 2), 1.5 * r),
    ],
    edges: [
      for (final (q, r) in coords)
        for (final (dq, dr) in dirs)
          if (index[(q + dq, r + dr)] != null)
            (index[(q, r)]!, index[(q + dq, r + dr)]!),
    ],
    preset: preset,
  );
}

/// Two 3×3 groups joined by a single bridge field (index 9).
BoardSpec islands({Map<int, WheelColor> preset = const {}}) {
  final positions = <Offset>[];
  final edges = <(int, int)>[];
  void island(double ox, double oy) {
    final base = positions.length;
    for (var r = 0; r < 3; r++) {
      for (var c = 0; c < 3; c++) {
        positions.add(Offset(ox + c, oy + r));
        final i = base + r * 3 + c;
        if (c < 2) edges.add((i, i + 1));
        if (r < 2) edges.add((i, i + 3));
      }
    }
  }

  island(0, 0); // 0..8
  positions.add(const Offset(1.5, 3)); // 9: bridge
  island(1, 4); // 10..18
  edges.addAll([(7, 9), (8, 9), (9, 10), (9, 11)]);
  return BoardSpec(positions: positions, edges: edges, preset: preset);
}

/// Centre, ring of 6 and ring of 12 (19 fields).
BoardSpec mandala({Map<int, WheelColor> preset = const {}}) {
  final positions = <Offset>[Offset.zero];
  for (var i = 0; i < 6; i++) {
    final a = -math.pi / 2 + i * math.pi / 3;
    positions.add(Offset(math.cos(a), math.sin(a)));
  }
  for (var j = 0; j < 12; j++) {
    final a = -math.pi / 2 + j * math.pi / 6;
    positions.add(Offset(math.cos(a), math.sin(a)) * 2);
  }
  int inner(int i) => 1 + i % 6;
  int outer(int j) => 7 + j % 12;
  return BoardSpec(
    positions: positions,
    edges: [
      for (var i = 0; i < 6; i++) ...[
        (0, inner(i)),
        (inner(i), inner(i + 1)),
        (inner(i), outer(2 * i)),
        (inner(i), outer(2 * i + 1)),
        (inner(i + 1), outer(2 * i + 1)),
      ],
      for (var j = 0; j < 12; j++) (outer(j), outer(j + 1)),
    ],
    preset: preset,
  );
}

/// Offset rows like brick-laid hex cells: every odd row shifts half a field.
BoardSpec staggered(
  int cols,
  int rows, {
  Map<int, WheelColor> preset = const {},
}) {
  int idx(int r, int c) => r * cols + c;
  final edges = <(int, int)>[];
  for (var r = 0; r < rows; r++) {
    for (var c = 0; c < cols; c++) {
      if (c + 1 < cols) edges.add((idx(r, c), idx(r, c + 1)));
      if (r + 1 < rows) {
        edges.add((idx(r, c), idx(r + 1, c)));
        final diag = r.isEven ? c - 1 : c + 1;
        if (diag >= 0 && diag < cols) edges.add((idx(r, c), idx(r + 1, diag)));
      }
    }
  }
  return BoardSpec(
    positions: [
      for (var r = 0; r < rows; r++)
        for (var c = 0; c < cols; c++)
          Offset(c + (r.isOdd ? 0.5 : 0), r * math.sqrt(3) / 2),
    ],
    edges: edges,
    preset: preset,
  );
}
