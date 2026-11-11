import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../audio/sound.dart';
import '../painting/watercolor.dart';
import '../theme/palette.dart';
import '../theme/typography.dart';
import 'widgets.dart';

Future<void> showRules(BuildContext context) {
  Sound.page();
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const _RulesSheet(),
  );
}

class _RulesSheet extends StatelessWidget {
  const _RulesSheet();

  @override
  Widget build(BuildContext context) {
    final maxHeight = MediaQuery.sizeOf(context).height * 0.88;
    return Center(
      heightFactor: 1,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: 480, maxHeight: maxHeight),
        child: ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
          child: Stack(
            children: [
              const Positioned.fill(
                child: CustomPaint(painter: PaperPainter()),
              ),
              SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(22, 14, 22, 28),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 44,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Inks.paperDeep,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text('Spielregeln', style: AppText.title(36)),
                    const SizedBox(height: 8),
                    Text(
                      'Ihr legt abwechselnd eine Farbkarte aus eurer Hand auf '
                      'ein freies Feld. Danach wird die Hand wieder auf drei '
                      'Karten aufgefüllt (ab Level 9 auf vier). Punkte gibt es, wenn die neue Karte '
                      'zu ihren Nachbarn passt – entlang der Bleistiftlinien.',
                      style: AppText.body(15),
                    ),
                    const SizedBox(height: 18),
                    const Center(
                      child: _WheelDiagram(
                        size: 190,
                        wheel: ColorWheel.classic,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Center(
                      child: Text(
                        'Gegenüber im Farbkreis liegen die Komplementärfarben.',
                        textAlign: TextAlign.center,
                        style: AppText.hand(19, color: Inks.graphite),
                      ),
                    ),
                    const SizedBox(height: 18),
                    const _RuleRow(
                      colors: [WheelColor.yellow, WheelColor.purple],
                      title: 'Komplementär · 2 Punkte',
                      text: 'Für jede benachbarte Karte in der Gegenfarbe.',
                    ),
                    const _RuleRow(
                      colors: [WheelColor.blue, WheelColor.blue],
                      title: 'Gleiche Farbe · 1 Punkt',
                      text: 'Für jede benachbarte Karte in derselben Farbe.',
                    ),
                    const _RuleRow(
                      colors: [
                        WheelColor.orange,
                        WheelColor.red,
                        WheelColor.purple,
                      ],
                      title: 'Farbfolge · 1 Punkt je Karte',
                      text:
                          'Eine Kette verbundener Karten, die dem Farbkreis '
                          'Schritt für Schritt folgt – vorwärts oder rückwärts, '
                          'auch über Grün zurück zu Gelb. Ab drei Karten; '
                          'gewertet wird die längste Kette durch die neue Karte.',
                    ),
                    _RuleRow(
                      colors: ColorWheel.classic.colors,
                      title: 'Voller Farbkreis · +3 Bonus',
                      text:
                          'Wenn eine Farbfolge alle sechs Farben enthält. '
                          'Eine graue Linie verbindet danach diesen Kreis: '
                          'entlang dieser Linie zählt keine Farbfolge mehr. '
                          'Gleiche Farbe und Komplementär punkten weiter, und '
                          'eine neue Farbfolge darf eine dieser Karten '
                          'einschließen.',
                    ),
                    const SizedBox(height: 10),
                    Text('Felder erobern', style: AppText.title(26)),
                    const SizedBox(height: 4),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(top: 2, right: 10),
                          child: Row(
                            children: [
                              for (var p = 0; p < 2; p++)
                                SizedBox.square(
                                  dimension: 30,
                                  child: CustomPaint(painter: _RingPainter(p)),
                                ),
                            ],
                          ),
                        ),
                        Expanded(
                          child: Text(
                            'Jede gelegte Karte gehört dir, zunächst nur '
                            'vorläufig (blasser Ring). Wer als Erstes mit einer '
                            'Karte punktet, sichert sie sich (kräftiger Ring) – '
                            'auch Karten des Gegenübers, solange sie nicht '
                            'gesichert sind. Gesicherte Felder bleiben, wem sie '
                            'gehören; Punkte gibt es trotzdem voll. Einfacher '
                            'Ring: Spieler 1, doppelter: Spieler 2.',
                            style: AppText.body(15),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Text('Zwischentöne · ab Level 9', style: AppText.title(26)),
                    const SizedBox(height: 4),
                    Text(
                      'Zwischen je zwei Farben liegt ein Zwischenton: '
                      'Bernstein (zwischen Gelb und Orange), Koralle (Orange '
                      'und Rot), Magenta (Rot und Violett), Indigo (Violett '
                      'und Blau), Türkis (Blau und Grün) und Limette (Grün '
                      'und Gelb). Der Farbkreis hat dann zwölf Farben, und '
                      'jeder hält vier Karten. Eine Farbfolge geht in '
                      'Schritten zum nächsten Ton, also Gelb → Bernstein → '
                      'Orange. Komplementär ist '
                      'weiterhin die gegenüberliegende Farbe. Ein voller '
                      'Farbkreis braucht alle zwölf Farben und bringt +6.',
                      style: AppText.body(15),
                    ),
                    const SizedBox(height: 12),
                    const Center(
                      child: _WheelDiagram(
                        size: 230,
                        wheel: ColorWheel.extended,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text('Spielende', style: AppText.title(26)),
                    const SizedBox(height: 4),
                    Text(
                      'Sind alle Felder bemalt, zählt: Punkte + eigene Felder. '
                      'Wer mehr hat, gewinnt. Gegen den Computer schaltet ein '
                      'Sieg das nächste Level frei. Bei einer knappen '
                      'Niederlage (höchstens 10\u00a0% der Gesamtpunkte des Siegers, '
                      'mindestens 3 Punkte Abstand) oder nach drei Partien '
                      'ohne Sieg darfst du trotzdem weiter. Dein bester '
                      'Gesamtstand je Level wird gespeichert.',
                      style: AppText.body(15),
                    ),
                    const SizedBox(height: 22),
                    Center(
                      child: BrushButton(
                        label: 'Los geht’s',
                        color: WheelColor.yellow,
                        seed: 5,
                        fontSize: 26,
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RuleRow extends StatelessWidget {
  const _RuleRow({
    required this.colors,
    required this.title,
    required this.text,
  });

  final List<WheelColor> colors;
  final String title;
  final String text;

  @override
  Widget build(BuildContext context) {
    final disc = colors.length > 3 ? 22.0 : 34.0;
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              for (var i = 0; i < colors.length; i++) ...[
                if (i > 0)
                  Container(
                    width: 10,
                    height: 1.4,
                    color: Inks.graphite.withValues(alpha: 0.5),
                  ),
                PaintedDisc(color: colors[i], size: disc, seed: 90 + i),
              ],
              const SizedBox(width: 12),
              Expanded(child: Text(title, style: AppText.hand(23))),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            text,
            style: AppText.body(14, color: Inks.ink.withValues(alpha: 0.8)),
          ),
        ],
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter(this.player);
  final int player;

  @override
  void paint(Canvas canvas, Size size) => Watercolor.ownerRing(
    canvas,
    size.center(Offset.zero),
    size.shortestSide * 0.34,
    player,
    4,
  );

  @override
  bool shouldRepaint(_RingPainter old) => old.player != player;
}

/// The colour wheel with pencil lines joining complementary pairs.
class _WheelDiagram extends StatelessWidget {
  const _WheelDiagram({required this.size, required this.wheel});

  final double size;
  final ColorWheel wheel;

  @override
  Widget build(BuildContext context) =>
      CustomPaint(size: Size.square(size), painter: _WheelPainter(wheel));
}

class _WheelPainter extends CustomPainter {
  _WheelPainter(this.wheel);

  final ColorWheel wheel;

  @override
  void paint(Canvas canvas, Size size) {
    final n = wheel.length;
    final c = size.center(Offset.zero);
    final r = size.shortestSide / 2;
    final disc = r * (n > 6 ? 0.17 : 0.24);
    Offset at(int i) {
      final a = -math.pi / 2 + i * 2 * math.pi / n;
      return c + Offset(math.cos(a), math.sin(a)) * (r - disc * 1.1);
    }

    final rng = math.Random(3);
    for (var i = 0; i < n ~/ 2; i++) {
      Watercolor.pencilLine(
        canvas,
        at(i),
        at(i + n ~/ 2),
        rng,
        opacity: 0.35,
        width: 1,
      );
    }
    for (var i = 0; i < n; i++) {
      final color = wheel.colors[i];
      Watercolor.drawDisc(canvas, at(i), disc, color.pigment, 60 + i);
    }
    for (var i = 0; i < n; i++) {
      final tp = TextPainter(
        text: TextSpan(
          text: wheel.colors[i].label,
          style: AppText.hand(n > 6 ? 13 : 15),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      if (n <= 6) {
        tp.paint(canvas, at(i) - Offset(tp.width / 2, tp.height / 2));
        continue;
      }
      // Twelve labels do not fit side by side; they run along the spokes
      // inside the ring, turned so that none is upside down.
      final angle = -math.pi / 2 + i * 2 * math.pi / n;
      final outer = r - disc * 2.3;
      final leftHalf = math.cos(angle) < -1e-6;
      canvas
        ..save()
        ..translate(c.dx, c.dy)
        ..rotate(leftHalf ? angle + math.pi : angle);
      tp.paint(
        canvas,
        Offset(leftHalf ? -outer : outer - tp.width, -tp.height / 2),
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_WheelPainter old) => old.wheel != wheel;
}
