import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flutter/painting.dart';

import '../audio/sound.dart';
import '../config.dart';
import '../logic/game_state.dart';
import '../logic/scoring.dart';
import '../model/board.dart';
import '../painting/watercolor.dart';
import '../theme/palette.dart';
import '../theme/typography.dart';

/// Renders the board of a [GameState] and reports taps on fields.
/// Menus, hands and scores are Flutter widgets around this game.
class ColorWheelGame extends FlameGame {
  ColorWheelGame({required this.state, required this.onNodeTap});

  final GameState state;
  final void Function(ColorNode node) onNodeTap;

  /// Colour the human currently holds ready to place, if any.
  WheelColor? selectedColor;

  /// False while the computer moves or the game is over.
  bool interactive = true;

  /// Field the tutorial asks for; it pulses while [interactive].
  int? hintNode;

  /// Painted field whose colour name is shown next to it.
  int? inspectedNode;

  double nodeRadius = 24;
  int layoutVersion = 0;
  final Map<int, NodeComponent> nodeComponents = {};

  @override
  Color backgroundColor() => const Color(0x00000000);

  @override
  Future<void> onLoad() async {
    add(EdgesComponent());
    add(InspectLabel());
    for (final node in state.board.nodes) {
      final c = NodeComponent(node);
      nodeComponents[node.id] = c;
      add(c);
    }
    _layout(size);
  }

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    if (isLoaded) _layout(size);
  }

  void _layout(Vector2 size) {
    final nodes = state.board.nodes;
    if (nodes.isEmpty || size.x <= 0 || size.y <= 0) return;

    var minX = double.infinity, minY = double.infinity;
    var maxX = -double.infinity, maxY = -double.infinity;
    for (final n in nodes) {
      minX = math.min(minX, n.position.dx);
      maxX = math.max(maxX, n.position.dx);
      minY = math.min(minY, n.position.dy);
      maxY = math.max(maxY, n.position.dy);
    }
    var minEdge = double.infinity;
    for (final (a, b) in state.board.edges) {
      minEdge = math.min(minEdge, (a.position - b.position).distance);
    }
    if (minEdge == double.infinity) minEdge = 1;

    final bw = math.max(maxX - minX, 0.001);
    final bh = math.max(maxY - minY, 0.001);
    // Fit twice: the margin depends on the field radius, which depends on
    // the scale.
    var margin = 24.0;
    var scale = 1.0;
    // Large boards get relatively bigger fields so they stay easy to tap;
    // rings (1.1 r) and tap areas (1.2 r) of neighbours still do not touch.
    final fill = nodes.length > 30 ? 0.35 : 0.31;
    for (var i = 0; i < 2; i++) {
      scale = math.min((size.x - 2 * margin) / bw, (size.y - 2 * margin) / bh);
      nodeRadius = math.min(minEdge * scale * fill, 44);
      margin = nodeRadius * 1.3 + 10;
    }
    final centre = Vector2(size.x / 2, size.y / 2);
    final boardCentre = Offset((minX + maxX) / 2, (minY + maxY) / 2);
    for (final n in nodes) {
      final p = (n.position - boardCentre) * scale;
      nodeComponents[n.id]!
        ..position = centre + Vector2(p.dx, p.dy)
        ..size = Vector2.all(nodeRadius * 2.8);
    }
    layoutVersion++;
  }

  int seedFor(ColorNode n) => n.id * 7919 + state.level.number * 104729;

  /// Plays the placement and scoring animation for a finished move.
  void showMove(MoveResult result, int player) {
    final placed = nodeComponents[result.node.id];
    placed?.bloom();
    // Each score event starts its animation, and its sound, a bit later.
    final delays = [
      for (var i = 0; i < result.events.length; i++) 0.35 + i * 0.45,
    ];
    Sound.move(
      result,
      byComputer: state.players[player].isComputer,
      delays: delays,
    );
    for (var i = 0; i < result.events.length; i++) {
      final e = result.events[i];
      final delay = delays[i];
      add(ScoreLink(e, player, delay: delay));
      final centroid =
          e.nodes
              .map<Vector2>((n) => nodeComponents[n.id]!.position.clone())
              .reduce((a, b) => a + b) /
          e.nodes.length.toDouble();
      add(
        ScorePopup(
          '+${e.points} ${e.kind.label}',
          Inks.players[player],
          centroid - Vector2(0, nodeRadius * 0.6),
          delay: delay,
        ),
      );
      if (e.kind == ScoreKind.fullWheel) {
        add(SpentChain(e.nodes, delay: delay + 0.8));
      }
      for (final n in e.nodes) {
        if (!identical(n, result.node)) {
          nodeComponents[n.id]?.claimed(delay + 0.3);
        }
      }
    }
  }
}

/// Grey line through the cards of a completed full wheel: these links are
/// spent and no sequence can run along them again. Drawn on top of the
/// cards, sketched in from the first card to the last.
class SpentChain extends Component with HasGameReference<ColorWheelGame> {
  SpentChain(this.nodes, {this.delay = 0}) : super(priority: 20);

  final List<ColorNode> nodes;

  /// Seconds until the line starts to appear.
  double delay;
  double _progress = 0;

  @override
  void update(double dt) {
    if (delay > 0) {
      delay -= dt;
    } else if (_progress < 1) {
      _progress = math.min(1, _progress + dt * 1.2);
    }
  }

  @override
  void render(Canvas canvas) {
    if (_progress <= 0) return;
    final points = [
      for (final n in nodes) game.nodeComponents[n.id]!.position.toOffset(),
    ];
    final segments = points.length - 1;
    final reach = _progress * segments;
    final rng = math.Random(nodes.first.id * 31 + nodes.last.id);
    final r = game.nodeRadius;
    for (var i = 0; i < segments; i++) {
      final t = (reach - i).clamp(0.0, 1.0);
      final a = points[i];
      final b = points[i + 1];
      // Consume the random numbers for every segment so the wobble does
      // not change while the line grows.
      final end = Offset.lerp(a, b, t)!;
      final segRng = math.Random(rng.nextInt(1 << 30));
      if (t <= 0) continue;
      Watercolor.pencilLine(
        canvas,
        a,
        end,
        segRng,
        color: Inks.graphite,
        width: math.max(2.5, r * 0.14),
        opacity: 0.6,
      );
    }
  }
}

/// Pencil lines between neighbouring fields.
class EdgesComponent extends Component with HasGameReference<ColorWheelGame> {
  EdgesComponent() : super(priority: 0);

  ui.Picture? _picture;
  int _version = -1;

  @override
  void render(Canvas canvas) {
    if (_version != game.layoutVersion) {
      _picture?.dispose();
      final rec = ui.PictureRecorder();
      final c = Canvas(rec);
      final rng = math.Random(game.state.level.number);
      for (final (a, b) in game.state.board.edges) {
        final pa = game.nodeComponents[a.id]!.position.toOffset();
        final pb = game.nodeComponents[b.id]!.position.toOffset();
        final dir = (pb - pa) / (pb - pa).distance;
        final inset = game.nodeRadius * 0.95;
        Watercolor.pencilLine(
          c,
          pa + dir * inset,
          pb - dir * inset,
          rng,
          width: math.max(1, game.nodeRadius * 0.05),
          opacity: 0.45,
        );
      }
      _picture = rec.endRecording();
      _version = game.layoutVersion;
    }
    canvas.drawPicture(_picture!);
  }

  @override
  void onRemove() {
    _picture?.dispose();
    super.onRemove();
  }
}

class NodeComponent extends PositionComponent
    with TapCallbacks, HoverCallbacks, HasGameReference<ColorWheelGame> {
  NodeComponent(this.node) : super(anchor: Anchor.center, priority: 10);

  final ColorNode node;

  double _grow = 1;
  double _pulse = 0;
  double _pulseDelay = 0;
  bool _hovered = false;
  double _clock = 0;

  // Memo for the hover preview.
  WheelColor? _previewColor;
  int _previewPoints = 0;

  void bloom() => _grow = 0;

  void claimed(double delay) {
    _pulseDelay = delay;
    _pulse = 1;
  }

  @override
  bool containsLocalPoint(Vector2 point) =>
      (point - size / 2).length <= game.nodeRadius * 1.2;

  @override
  void onTapUp(TapUpEvent event) => game.onNodeTap(node);

  @override
  void onHoverEnter() => _hovered = true;

  @override
  void onHoverExit() => _hovered = false;

  @override
  void update(double dt) {
    _clock += dt;
    if (_grow < 1) _grow = math.min(1, _grow + dt * 2.2);
    if (_pulseDelay > 0) {
      _pulseDelay -= dt;
    } else if (_pulse > 0) {
      _pulse = math.max(0, _pulse - dt * 1.4);
    }
  }

  @override
  void render(Canvas canvas) {
    final c = (size / 2).toOffset();
    final r = game.nodeRadius;
    final seed = game.seedFor(node);
    final color = node.color;

    if (color == null) {
      _renderEmpty(canvas, c, r, seed);
      return;
    }

    final owner = node.owner;
    if (owner != null) {
      // Unsecured cards can still be taken: a pale ring until secured.
      Watercolor.ownerRing(
        canvas,
        c,
        r * 1.1,
        owner,
        seed,
        opacity: node.secured ? 1 : 0.4,
      );
      if (_pulse > 0 && _pulseDelay <= 0) {
        final t = 1 - _pulse;
        Watercolor.ownerRing(
          canvas,
          c,
          r * (1.1 + t * 0.35),
          owner,
          seed + 1,
          opacity: _pulse * 0.8,
        );
      }
    } else {
      // Neutral pre-printed card: a faint graphite outline.
      final rng = math.Random(seed + 5);
      canvas.drawPath(
        Watercolor.wobblyCircle(c, r * 1.08, rng, roughness: 0.03),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = math.max(1, r * 0.035)
          ..color = Inks.graphite.withValues(alpha: 0.5),
      );
    }

    final scale = _grow >= 1 ? 1.0 : _easeOutBack(_grow);
    Watercolor.drawDisc(
      canvas,
      c,
      r,
      color.pigment,
      seed,
      scale: scale,
      opacity: math.min(1, _grow * 2.5),
    );

    if (game.inspectedNode == node.id) {
      canvas.drawPath(
        Watercolor.wobblyCircle(
          c,
          r * 1.3,
          math.Random(seed + 11),
          roughness: 0.04,
        ),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = math.max(2, r * 0.08)
          ..color = Inks.ink.withValues(alpha: 0.6),
      );
    }
  }

  void _renderEmpty(Canvas canvas, Offset c, double r, int seed) {
    final rng = math.Random(seed);
    final outline = Watercolor.wobblyCircle(c, r * 0.92, rng, roughness: 0.04);
    canvas.drawPath(
      outline,
      Paint()..color = Inks.paperShade.withValues(alpha: 0.32),
    );
    canvas.drawPath(
      outline,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(1, r * 0.035)
        ..color = Inks.graphite.withValues(alpha: 0.38),
    );

    if (game.hintNode == node.id && game.interactive) {
      final wave = 0.5 + 0.5 * math.sin(_clock * 4);
      canvas.drawPath(
        Watercolor.wobblyCircle(
          c,
          r * (1.12 + 0.08 * wave),
          math.Random(seed + 9),
          roughness: 0.04,
        ),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = math.max(2, r * 0.09)
          ..color = Inks.ink.withValues(alpha: 0.3 + 0.4 * wave),
      );
    }

    final selected = game.selectedColor;
    if (selected == null || !game.interactive) return;

    if (!_hovered) {
      canvas.drawPath(
        outline,
        Paint()..color = selected.pigment.withValues(alpha: 0.1),
      );
      return;
    }

    Watercolor.drawDisc(canvas, c, r, selected.pigment, seed, opacity: 0.5);
    if (!showPointPreview) return;
    if (_previewColor != selected) {
      _previewColor = selected;
      _previewPoints = evaluateMove(
        node,
        selected,
        wheel: game.state.level.wheel,
      ).points;
    }
    if (_previewPoints > 0) {
      _drawLabel(canvas, '+$_previewPoints', c, r * 0.9, Inks.ink);
    }
  }

  @override
  void onMount() {
    super.onMount();
    // Reset the preview memo whenever the board may have changed.
    game.state.addListener(_resetPreview);
  }

  @override
  void onRemove() {
    game.state.removeListener(_resetPreview);
    super.onRemove();
  }

  void _resetPreview() => _previewColor = null;
}

double _easeOutBack(double t) {
  const c1 = 1.70158, c3 = c1 + 1;
  return 1 + c3 * math.pow(t - 1, 3) + c1 * math.pow(t - 1, 2);
}

void _drawLabel(
  Canvas canvas,
  String text,
  Offset c,
  double size,
  Color color, {
  double opacity = 1,
}) {
  final style = AppText.hand(size, color: color.withValues(alpha: opacity));
  final halo = TextPainter(
    text: TextSpan(
      text: text,
      style: style.copyWith(
        foreground: Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = size * 0.18
          ..strokeJoin = StrokeJoin.round
          ..color = Inks.paper.withValues(alpha: 0.85 * opacity),
        color: null,
      ),
    ),
    textDirection: TextDirection.ltr,
  )..layout();
  final fill = TextPainter(
    text: TextSpan(text: text, style: style),
    textDirection: TextDirection.ltr,
  )..layout();
  final o = c - Offset(fill.width / 2, fill.height / 2);
  halo.paint(canvas, o);
  fill.paint(canvas, o);
}

/// Name of the colour on [ColorWheelGame.inspectedNode], above the field,
/// or below it when the field sits at the top edge.
class InspectLabel extends Component with HasGameReference<ColorWheelGame> {
  InspectLabel() : super(priority: 90);

  @override
  void render(Canvas canvas) {
    final id = game.inspectedNode;
    final color = id == null ? null : game.state.board.nodes[id].color;
    if (id == null || color == null) return;
    final c = game.nodeComponents[id]!.position.toOffset();
    final r = game.nodeRadius;
    final size = math.max(20.0, r * 0.75);
    final gap = r * 1.35 + size * 0.6;
    final above = c.dy - gap - size * 0.6 >= 0;
    _drawLabel(
      canvas,
      color.label,
      c + Offset(0, above ? -gap : gap),
      size,
      Inks.ink,
    );
  }
}

/// Floating "+2 Komplementär" text.
class ScorePopup extends PositionComponent {
  ScorePopup(this.text, this.color, Vector2 position, {double delay = 0})
    : _t = -delay,
      super(position: position, priority: 100);

  final String text;
  final Color color;
  double _t;
  static const _life = 2.0;

  @override
  void update(double dt) {
    _t += dt;
    if (_t > _life) removeFromParent();
  }

  @override
  void render(Canvas canvas) {
    if (_t < 0) return;
    final p = _t / _life;
    final opacity = p < 0.12
        ? p / 0.12
        : p > 0.7
        ? (1 - p) / 0.3
        : 1.0;
    final rise = 40 * (1 - math.pow(1 - p, 3));
    _drawLabel(
      canvas,
      text,
      Offset(0, -rise.toDouble()),
      26,
      color,
      opacity: opacity.clamp(0, 1),
    );
  }
}

/// Brush stroke in the scorer's ink that connects the fields of an event.
class ScoreLink extends Component with HasGameReference<ColorWheelGame> {
  ScoreLink(this.event, this.player, {double delay = 0})
    : _t = -delay,
      super(priority: 5);

  final ScoreEvent event;
  final int player;
  double _t;
  static const _life = 1.8;

  @override
  void update(double dt) {
    _t += dt;
    if (_t > _life) removeFromParent();
  }

  @override
  void render(Canvas canvas) {
    if (_t < 0) return;
    final p = _t / _life;
    final draw = math.min(1.0, p / 0.3);
    final opacity = p > 0.6 ? (1 - p) / 0.4 : 1.0;
    final pts = [
      for (final n in event.nodes)
        game.nodeComponents[n.id]!.position.toOffset(),
    ];
    if (pts.length < 2) return;
    final path = Path()..moveTo(pts.first.dx, pts.first.dy);
    for (final q in pts.skip(1)) {
      path.lineTo(q.dx, q.dy);
    }
    final partial = Path();
    for (final metric in path.computeMetrics()) {
      partial.addPath(metric.extractPath(0, metric.length * draw), Offset.zero);
    }
    final ink = Inks.players[player];
    final w = game.nodeRadius * 0.32;
    canvas.drawPath(
      partial,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..strokeWidth = w
        ..color = ink.withValues(alpha: 0.35 * opacity)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, w * 0.25),
    );
  }
}
