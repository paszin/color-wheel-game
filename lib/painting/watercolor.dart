import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';

import '../theme/palette.dart';

/// Procedural watercolour painting: soft irregular washes built from several
/// translucent layers, darker pigment at the edges, granulation specks and
/// pencil lines. Everything is seeded, so a card always looks the same.
abstract final class Watercolor {
  /// Irregular closed blob around [c] with radius [r].
  static Path wobblyCircle(
    Offset c,
    double r,
    math.Random rng, {
    double roughness = 0.05,
    int segments = 36,
  }) {
    final harmonics = [
      for (var k = 0; k < 4; k++)
        (
          amp: roughness * (0.4 + rng.nextDouble()) / (k + 1),
          phase: rng.nextDouble() * math.pi * 2,
          freq: k + 2,
        ),
    ];
    final pts = <Offset>[];
    for (var i = 0; i < segments; i++) {
      final t = i / segments * math.pi * 2;
      var k = 1.0;
      for (final h in harmonics) {
        k += h.amp * math.sin(h.freq * t + h.phase);
      }
      k += (rng.nextDouble() - 0.5) * roughness * 0.3;
      pts.add(c + Offset(math.cos(t), math.sin(t)) * (r * k));
    }
    return smoothClosed(pts);
  }

  static Path smoothClosed(List<Offset> pts) {
    Offset mid(Offset a, Offset b) =>
        Offset((a.dx + b.dx) / 2, (a.dy + b.dy) / 2);
    final n = pts.length;
    final start = mid(pts[n - 1], pts[0]);
    final path = Path()..moveTo(start.dx, start.dy);
    for (var i = 0; i < n; i++) {
      final p = pts[i];
      final m = mid(p, pts[(i + 1) % n]);
      path.quadraticBezierTo(p.dx, p.dy, m.dx, m.dy);
    }
    return path..close();
  }

  /// A round watercolour wash of [pigment].
  static void paintDisc(
    Canvas canvas,
    Offset c,
    double r,
    Color pigment,
    int seed,
  ) {
    final rng = math.Random(seed);
    final deep = darken(pigment, 0.16);
    final light = lighten(pigment, 0.1);

    // Bleed into the paper.
    canvas.drawPath(
      wobblyCircle(c, r * 1.03, rng, roughness: 0.07),
      Paint()
        ..color = pigment.withValues(alpha: 0.16)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 0.07),
    );

    // Layered glazes; overlaps get denser, borders stay uneven.
    Path? outer;
    for (var i = 0; i < 5; i++) {
      final jitter = Offset(
        (rng.nextDouble() - 0.5) * r * 0.07,
        (rng.nextDouble() - 0.5) * r * 0.07,
      );
      final layer = wobblyCircle(
        c + jitter,
        r * (0.9 + rng.nextDouble() * 0.09),
        rng,
        roughness: 0.085,
      );
      outer ??= layer;
      canvas.drawPath(
        layer,
        Paint()..color = (i.isEven ? pigment : light).withValues(alpha: 0.28),
      );
    }

    // Wet-in-wet: darker pigment drifting inside the wash.
    for (var i = 0; i < 3; i++) {
      final a = rng.nextDouble() * math.pi * 2;
      final bc =
          c + Offset(math.cos(a), math.sin(a)) * r * rng.nextDouble() * 0.5;
      canvas.drawPath(
        wobblyCircle(
          bc,
          r * (0.25 + rng.nextDouble() * 0.2),
          rng,
          roughness: 0.2,
        ),
        Paint()
          ..color = deep.withValues(alpha: 0.1 + rng.nextDouble() * 0.06)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 0.1),
      );
    }

    // A thinner, more watery patch where less pigment settled.
    {
      final a = rng.nextDouble() * math.pi * 2;
      final lc = c + Offset(math.cos(a), math.sin(a)) * r * 0.3;
      canvas.drawPath(
        wobblyCircle(lc, r * 0.38, rng, roughness: 0.18),
        Paint()
          ..color = lighten(pigment, 0.2).withValues(alpha: 0.22)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 0.12),
      );
    }

    // Occasional backrun with a ragged, darker rim near the edge.
    if (rng.nextDouble() < 0.35) {
      final a = rng.nextDouble() * math.pi * 2;
      final bc = c + Offset(math.cos(a), math.sin(a)) * r * 0.55;
      final bloom = wobblyCircle(bc, r * 0.22, rng, roughness: 0.22);
      canvas.drawPath(bloom, Paint()..color = light.withValues(alpha: 0.25));
      canvas.drawPath(
        bloom,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = r * 0.02
          ..color = deep.withValues(alpha: 0.2)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 0.008),
      );
    }

    // Pigment pooling at the edge.
    canvas.drawPath(
      outer!,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = r * 0.055
        ..color = deep.withValues(alpha: 0.42)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 0.018),
    );

    // Granulation.
    final speck = Paint();
    for (var i = 0; i < 55; i++) {
      final a = rng.nextDouble() * math.pi * 2;
      final d = math.sqrt(rng.nextDouble()) * r * 0.88;
      speck.color = deep.withValues(alpha: 0.07 + rng.nextDouble() * 0.12);
      canvas.drawCircle(
        c + Offset(math.cos(a), math.sin(a)) * d,
        r * (0.01 + rng.nextDouble() * 0.022),
        speck,
      );
    }
  }

  static final Map<String, ui.Picture> _discs = {};

  /// Cached recording of [paintDisc] centred on the origin.
  static ui.Picture disc(Color pigment, double r, int seed) {
    if (_discs.length > 300) {
      for (final p in _discs.values) {
        p.dispose();
      }
      _discs.clear();
    }
    final key = '${pigment.toARGB32()}|${r.toStringAsFixed(1)}|$seed';
    return _discs.putIfAbsent(key, () {
      final rec = ui.PictureRecorder();
      paintDisc(Canvas(rec), Offset.zero, r, pigment, seed);
      return rec.endRecording();
    });
  }

  static void drawDisc(
    Canvas canvas,
    Offset c,
    double r,
    Color pigment,
    int seed, {
    double scale = 1,
    double opacity = 1,
  }) {
    if (scale <= 0 || opacity <= 0) return;
    canvas.save();
    canvas.translate(c.dx, c.dy);
    if (scale != 1) canvas.scale(scale);
    if (opacity < 1) {
      final bounds = Rect.fromCircle(center: Offset.zero, radius: r * 1.3);
      canvas.saveLayer(
        bounds,
        Paint()..color = Color.fromRGBO(0, 0, 0, opacity),
      );
      canvas.drawPicture(disc(pigment, r, seed));
      canvas.restore();
    } else {
      canvas.drawPicture(disc(pigment, r, seed));
    }
    canvas.restore();
  }

  /// Hand-drawn pencil line.
  static void pencilLine(
    Canvas canvas,
    Offset a,
    Offset b,
    math.Random rng, {
    Color color = Inks.graphite,
    double width = 1.2,
    double opacity = 0.5,
  }) {
    final d = b - a;
    final len = d.distance;
    if (len == 0) return;
    final normal = Offset(-d.dy, d.dx) / len;
    for (var pass = 0; pass < 2; pass++) {
      final bend = (rng.nextDouble() - 0.5) * len * 0.05;
      final mid = a + d * (0.4 + rng.nextDouble() * 0.2) + normal * bend;
      final shift = normal * ((rng.nextDouble() - 0.5) * 1.4);
      final path = Path()
        ..moveTo(a.dx + shift.dx, a.dy + shift.dy)
        ..quadraticBezierTo(mid.dx, mid.dy, b.dx - shift.dx, b.dy - shift.dy);
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeWidth = pass == 0 ? width : width * 0.6
          ..color = color.withValues(
            alpha: pass == 0 ? opacity : opacity * 0.45,
          ),
      );
    }
  }

  /// Brushed ink ring marking a field's owner. Player 2 gets a double ring
  /// so ownership does not depend on telling the two inks apart.
  static void ownerRing(
    Canvas canvas,
    Offset c,
    double r,
    int player,
    int seed, {
    double opacity = 1,
  }) {
    final rng = math.Random(seed * 31 + player);
    final ink = Inks.players[player];
    canvas.drawPath(
      wobblyCircle(c, r, rng, roughness: 0.025, segments: 40),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(1.6, r * 0.065)
        ..color = ink.withValues(alpha: 0.62 * opacity)
        ..maskFilter = r >= 40
            ? MaskFilter.blur(BlurStyle.normal, r * 0.012)
            : null,
    );
    canvas.drawPath(
      wobblyCircle(c, r * 1.01, rng, roughness: 0.035, segments: 40),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(0.8, r * 0.03)
        ..color = ink.withValues(alpha: 0.35 * opacity),
    );
    if (player == 1) {
      canvas.drawPath(
        wobblyCircle(c, r * 1.14, rng, roughness: 0.03, segments: 40),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = math.max(1.2, r * 0.035)
          ..color = ink.withValues(alpha: 0.6 * opacity),
      );
    }
  }

  /// Horizontal brush stroke filling [rect], e.g. behind a button label.
  static void brushStroke(
    Canvas canvas,
    Rect rect,
    Color color,
    int seed, {
    double opacity = 1,
  }) {
    final rng = math.Random(seed);
    for (var layer = 0; layer < 3; layer++) {
      canvas.drawPath(
        _strokePath(rect, rng, layer, seed),
        Paint()
          ..color = color.withValues(
            alpha: (layer == 0 ? 0.32 : 0.22) * opacity,
          ),
      );
    }
  }

  static Path _strokePath(Rect rect, math.Random rng, int layer, int seed) {
    final n = math.max(28, rect.width ~/ 10);
    final top = <Offset>[];
    final bottom = <Offset>[];
    final wobble = rect.height * 0.08;
    for (var i = 0; i <= n; i++) {
      final t = i / n;
      final x = rect.left + rect.width * t + (rng.nextDouble() - 0.5) * 2;
      final thickness = math.pow(math.sin(math.pi * t), 0.35) * rect.height / 2;
      final cy =
          rect.center.dy +
          math.sin(t * math.pi * 2 + layer + seed) * rect.height * 0.04;
      top.add(Offset(x, cy - thickness + (rng.nextDouble() - 0.5) * wobble));
      bottom.add(Offset(x, cy + thickness * (0.85 + rng.nextDouble() * 0.15)));
    }
    return smoothClosed([...top, ...bottom.reversed]);
  }

  /// The colour wheel unrolled into one brush stroke. Each colour sits in
  /// the middle of its sixth; both ends blend green into yellow, so the
  /// strip reads as a closed circle.
  static void wheelStrip(
    Canvas canvas,
    Rect rect,
    int seed, {
    ColorWheel wheel = ColorWheel.classic,
  }) {
    final colours = wheel.colors;
    final wrap = Color.lerp(colours.last.pigment, colours.first.pigment, 0.5)!;
    final stops = <double>[0];
    final list = <Color>[wrap];
    for (var i = 0; i < colours.length; i++) {
      stops.add((i + 0.5) / colours.length);
      list.add(colours[i].pigment);
    }
    stops.add(1);
    list.add(wrap);
    final shader = ui.Gradient.linear(
      rect.centerLeft,
      rect.centerRight,
      list,
      stops,
    );
    final rng = math.Random(seed);
    for (var layer = 0; layer < 3; layer++) {
      canvas.drawPath(
        _strokePath(rect, rng, layer, seed),
        Paint()
          ..shader = shader
          ..color = Color.fromRGBO(0, 0, 0, layer == 0 ? 0.55 : 0.35),
      );
    }
    // Granulation keeps the gradient from looking digital.
    final speck = Paint();
    for (var i = 0; i < rect.width ~/ 3; i++) {
      final t = rng.nextDouble();
      final idx = ((t * colours.length) - 0.5).round().clamp(
        0,
        colours.length - 1,
      );
      speck.color = colours[idx].deep.withValues(
        alpha: 0.08 + rng.nextDouble() * 0.1,
      );
      canvas.drawCircle(
        Offset(
          rect.left + rect.width * t,
          rect.center.dy + (rng.nextDouble() - 0.5) * rect.height * 0.6,
        ),
        0.6 + rng.nextDouble() * 0.9,
        speck,
      );
    }
  }
}

/// Calm desk surface around the paper sheet on wide screens: a muted warm
/// grey with very faint washes of the six wheel colours.
class DeskPainter extends CustomPainter {
  const DeskPainter();

  static ui.Picture? _cache;
  static Size? _cacheSize;

  @override
  void paint(Canvas canvas, Size size) {
    if (_cache == null || _cacheSize != size) {
      _cache?.dispose();
      final rec = ui.PictureRecorder();
      final c = Canvas(rec);
      final rng = math.Random(17);
      c.drawRect(Offset.zero & size, Paint()..color = const Color(0xFFE3DDD2));
      for (var i = 0; i < 9; i++) {
        final colour = ColorWheel.classic.colors[i % 6];
        final centre = Offset(
          rng.nextDouble() * size.width,
          rng.nextDouble() * size.height,
        );
        final r = (0.25 + rng.nextDouble() * 0.3) * size.longestSide;
        c.drawCircle(
          centre,
          r,
          Paint()
            ..shader = ui.Gradient.radial(centre, r, [
              colour.pigment.withValues(alpha: 0.07),
              colour.pigment.withValues(alpha: 0),
            ]),
        );
      }
      final count = (size.width * size.height / 260).clamp(500, 9000).toInt();
      c.drawPoints(
        ui.PointMode.points,
        [
          for (var i = 0; i < count; i++)
            Offset(
              rng.nextDouble() * size.width,
              rng.nextDouble() * size.height,
            ),
        ],
        Paint()
          ..strokeWidth = 1.2
          ..strokeCap = StrokeCap.round
          ..color = Inks.paperDeep.withValues(alpha: 0.35),
      );
      _cache = rec.endRecording();
      _cacheSize = size;
    }
    canvas.drawPicture(_cache!);
  }

  @override
  bool shouldRepaint(DeskPainter oldDelegate) => false;
}

/// Warm cotton paper with fibres, specks, soft blotches and a vignette.
class PaperPainter extends CustomPainter {
  const PaperPainter();

  static final Map<Size, ui.Picture> _cache = {};

  @override
  void paint(Canvas canvas, Size size) {
    var picture = _cache[size];
    if (picture == null) {
      if (_cache.length >= 4) _cache.remove(_cache.keys.first)?.dispose();
      final rec = ui.PictureRecorder();
      _paintPaper(Canvas(rec), size);
      picture = _cache[size] = rec.endRecording();
    }
    canvas.drawPicture(picture);
  }

  static void _paintPaper(Canvas canvas, Size size) {
    final rng = math.Random(7);
    final rect = Offset.zero & size;
    canvas.drawRect(rect, Paint()..color = Inks.paper);

    // Uneven tone.
    for (var i = 0; i < 16; i++) {
      final c = Offset(
        rng.nextDouble() * size.width,
        rng.nextDouble() * size.height,
      );
      final r = (0.15 + rng.nextDouble() * 0.35) * size.shortestSide;
      canvas.drawCircle(
        c,
        r,
        Paint()
          ..shader = ui.Gradient.radial(c, r, [
            Inks.paperShade.withValues(alpha: 0.28),
            Inks.paperShade.withValues(alpha: 0),
          ]),
      );
    }

    // Fibres.
    final fibre = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.6;
    final fibres = (size.width * size.height / 900).clamp(150, 1200).toInt();
    for (var i = 0; i < fibres; i++) {
      final a = Offset(
        rng.nextDouble() * size.width,
        rng.nextDouble() * size.height,
      );
      final ang = rng.nextDouble() * math.pi * 2;
      final len = 4 + rng.nextDouble() * 12;
      final b = a + Offset(math.cos(ang), math.sin(ang)) * len;
      final ctrl =
          Offset.lerp(a, b, 0.5)! +
          Offset((rng.nextDouble() - 0.5) * 6, (rng.nextDouble() - 0.5) * 6);
      fibre.color = (rng.nextBool() ? Inks.graphite : const Color(0xFFFFFFFF))
          .withValues(alpha: 0.05 + rng.nextDouble() * 0.06);
      canvas.drawPath(
        Path()
          ..moveTo(a.dx, a.dy)
          ..quadraticBezierTo(ctrl.dx, ctrl.dy, b.dx, b.dy),
        fibre,
      );
    }

    // Specks.
    final count = (size.width * size.height / 120).clamp(800, 9000).toInt();
    for (var group = 0; group < 4; group++) {
      final pts = <Offset>[
        for (var i = 0; i < count ~/ 4; i++)
          Offset(rng.nextDouble() * size.width, rng.nextDouble() * size.height),
      ];
      canvas.drawPoints(
        ui.PointMode.points,
        pts,
        Paint()
          ..strokeWidth = 1 + group * 0.3
          ..strokeCap = StrokeCap.round
          ..color = (group.isEven ? Inks.paperDeep : const Color(0xFFFFFFFF))
              .withValues(alpha: 0.35),
      );
    }

    // Vignette.
    canvas.drawRect(
      rect,
      Paint()
        ..shader = ui.Gradient.radial(
          rect.center,
          size.longestSide * 0.75,
          [
            Inks.paperShade.withValues(alpha: 0),
            Inks.paperDeep.withValues(alpha: 0.45),
          ],
          [0.55, 1],
        ),
    );
  }

  @override
  bool shouldRepaint(PaperPainter oldDelegate) => false;
}

/// Paints a [Watercolor] disc filling its box; usable as a widget painter.
class DiscPainter extends CustomPainter {
  const DiscPainter(this.color, this.seed, {this.opacity = 1});

  final WheelColor color;
  final int seed;
  final double opacity;

  @override
  void paint(Canvas canvas, Size size) {
    final r = size.shortestSide / 2 / 1.08;
    Watercolor.drawDisc(
      canvas,
      size.center(Offset.zero),
      r,
      color.pigment,
      seed,
      opacity: opacity,
    );
  }

  @override
  bool shouldRepaint(DiscPainter old) =>
      old.color != color || old.seed != seed || old.opacity != opacity;
}

/// Brush stroke filling its box.
class BrushStrokePainter extends CustomPainter {
  const BrushStrokePainter(this.color, this.seed, {this.opacity = 1});

  final Color color;
  final int seed;
  final double opacity;

  @override
  void paint(Canvas canvas, Size size) {
    Watercolor.brushStroke(
      canvas,
      Offset.zero & size,
      color,
      seed,
      opacity: opacity,
    );
  }

  @override
  bool shouldRepaint(BrushStrokePainter old) =>
      old.color != color || old.seed != seed || old.opacity != opacity;
}
