import '../theme/palette.dart';
import 'board.dart';
import 'levels.dart';

/// One scripted move of the tutorial: [color] must go on field [node].
class TutorialMove {
  const TutorialMove({
    required this.color,
    required this.node,
    required this.hand,
    required this.prompt,
    this.byComputer = false,
  });

  final WheelColor color;
  final int node;

  /// Hand of the moving player at this moment; contains [color].
  final List<WheelColor> hand;

  /// Instruction shown while this move is due.
  final String prompt;
  final bool byComputer;
}

/// A fixed scenario that teaches one mechanism.
class TutorialStep {
  const TutorialStep({
    required this.title,
    required this.board,
    required this.moves,
    required this.done,
    this.wheel = ColorWheel.classic,
    this.owners = const {},
    this.points = (0, 0),
  });

  final String title;
  final BoardSpec Function() board;
  final ColorWheel wheel;

  /// Preset cards that already belong to a player: field → (player, secured).
  final Map<int, (int, bool)> owners;

  /// Points both players hold when the step starts.
  final (int, int) points;
  final List<TutorialMove> moves;

  /// Explanation shown after the last move.
  final String done;
}

const _y = WheelColor.yellow;
const _o = WheelColor.orange;
const _r = WheelColor.red;
const _p = WheelColor.purple;
const _b = WheelColor.blue;
const _g = WheelColor.green;
const _am = WheelColor.amber;

final tutorialSteps = <TutorialStep>[
  TutorialStep(
    title: 'Eine Karte legen',
    board: () => grid(3, 1),
    moves: const [
      TutorialMove(
        color: _b,
        node: 1,
        hand: [_y, _b, _r],
        prompt:
            'Unten liegen deine drei Farbkarten. Tippe auf Blau und dann '
            'auf das leuchtende Feld.',
      ),
    ],
    done:
        'Gelegt! Deine Hand wird sofort wieder auf drei Karten aufgefüllt. '
        'Punkte gab es keine – es liegt noch keine Nachbarkarte da. Der '
        'blasse Ring zeigt: Das Feld gehört dir, aber nur vorläufig.',
  ),
  TutorialStep(
    title: 'Gleiche Farbe',
    board: () => grid(3, 1, preset: {0: _b}),
    moves: const [
      TutorialMove(
        color: _b,
        node: 1,
        hand: [_r, _b, _g],
        prompt:
            'Felder sind über Bleistiftlinien benachbart. Lege Blau neben '
            'die blaue Karte – gleiche Farbe bringt 1 Punkt.',
      ),
    ],
    done:
        '+1 Punkt! Wer punktet, sichert sich alle beteiligten Karten: '
        'Der Ring wird kräftig, beide Felder gehören jetzt fest dir.',
  ),
  TutorialStep(
    title: 'Komplementärfarben',
    board: () => grid(3, 1, preset: {0: _o, 2: _o}),
    moves: const [
      TutorialMove(
        color: _b,
        node: 1,
        hand: [_o, _b, _p],
        prompt:
            'Gegenüber im Farbkreis liegen die Komplementärfarben (siehe '
            'Leiste unten): Blau ↔ Orange, Gelb ↔ Violett, Rot ↔ Grün. Sie '
            'bringen 2 Punkte. Lege Blau zwischen die beiden Orange.',
      ),
    ],
    done:
        '+4 Punkte – zweimal Komplementär. Mit Orange hättest du nur 2 '
        'bekommen (zweimal gleiche Farbe). Jeder passende Nachbar zählt.',
  ),
  TutorialStep(
    title: 'Farbfolge',
    board: () => grid(4, 1, preset: {0: _y, 1: _o}),
    moves: const [
      TutorialMove(
        color: _r,
        node: 2,
        hand: [_g, _r, _b],
        prompt:
            'Gelb → Orange → Rot folgt dem Farbkreis. Eine solche Kette aus '
            'mindestens drei Karten bringt 1 Punkt je Karte. Lege Rot '
            'hinter das Orange.',
      ),
    ],
    done:
        '+3 Punkte für die Farbfolge Gelb – Orange – Rot. Je länger die '
        'Kette, desto mehr Punkte.',
  ),
  TutorialStep(
    title: 'Rundherum',
    board: () => grid(4, 1, preset: {0: _b, 1: _g, 3: _o}),
    moves: const [
      TutorialMove(
        color: _y,
        node: 2,
        hand: [_p, _y, _r],
        prompt:
            'Nach Grün beginnt der Farbkreis wieder bei Gelb. Die neue Karte '
            'darf auch mitten in der Kette liegen. Lege Gelb in die Lücke.',
      ),
    ],
    done:
        '+4 Punkte: Blau – Grün – Gelb – Orange. Eine Kette darf auch '
        'rückwärts laufen, z. B. Rot – Orange – Gelb.',
  ),
  TutorialStep(
    title: 'Felder erobern',
    board: () => grid(3, 1),
    moves: const [
      TutorialMove(
        color: _r,
        node: 0,
        hand: [_r, _y, _b],
        prompt:
            'Jetzt spielt der Computer mit. Lege Rot auf das leuchtende Feld '
            '– ohne Punkte, also nur vorläufig deins.',
      ),
      TutorialMove(
        color: _r,
        node: 1,
        hand: [_r, _p, _y],
        byComputer: true,
        prompt: 'Der Computer ist dran – achte auf dein rotes Feld.',
      ),
      TutorialMove(
        color: _g,
        node: 2,
        hand: [_y, _g, _o],
        prompt:
            'Der Computer hat Rot daneben gelegt und gepunktet. Damit hat er '
            'sich auch deine ungesicherte Karte geschnappt (doppelter Ring). '
            'Kontere: Grün ist die Gegenfarbe von Rot.',
      ),
    ],
    done:
        '+2 Punkte für dich – das rote Feld bleibt trotzdem beim Computer, '
        'denn es ist gesichert. Wer als Erstes mit einer Karte punktet, '
        'behält sie bis zum Schluss.',
  ),
  TutorialStep(
    title: 'Voller Farbkreis',
    board: () => grid(3, 2, preset: {0: _y, 1: _o, 2: _r, 5: _p, 3: _g}),
    moves: const [
      TutorialMove(
        color: _b,
        node: 4,
        hand: [_b, _r, _y],
        prompt:
            'Hier fehlt nur Blau, dann läuft eine Kette durch alle sechs '
            'Farben. Das gibt einen Bonus von +3.',
      ),
    ],
    done:
        '11 Punkte auf einmal: Farbfolge (6), voller Farbkreis (+3) und '
        'Blau neben Orange (2). Die graue Linie schließt den Kreis: Entlang '
        'dieser Linie zählt keine Farbfolge mehr – gleiche Farbe und '
        'Komplementär punkten aber weiter.',
  ),
  TutorialStep(
    title: 'Spielende',
    board: () => grid(2, 2, preset: {0: _r, 1: _y, 2: _b}),
    owners: const {0: (1, true), 1: (0, true), 2: (1, false)},
    points: (4, 5),
    moves: const [
      TutorialMove(
        color: _o,
        node: 3,
        hand: [_g, _o, _p],
        prompt:
            'Ist das letzte Feld bemalt, endet das Spiel. Gezählt wird: '
            'Punkte + eigene Felder. Der Computer führt – lege Orange neben '
            'sein ungesichertes Blau.',
      ),
    ],
    done:
        'Komplementär (+2) und du schnappst dir das blaue Feld. '
        'Endstand: 6 Punkte + 3 Felder = 9 für dich, 5 + 1 = 6 für den '
        'Computer. Gewonnen!',
  ),
  TutorialStep(
    title: 'Zwischentöne',
    wheel: ColorWheel.extended,
    board: () => grid(3, 1, preset: {0: _y, 1: _am}),
    moves: const [
      TutorialMove(
        color: _o,
        node: 2,
        hand: [WheelColor.coral, _o, WheelColor.turquoise, WheelColor.indigo],
        prompt:
            'Ab Level 9 hat der Farbkreis zwölf Farben und du hältst vier '
            'Karten. Zwischen Gelb und Orange liegt Bernstein. Setze die '
            'Folge mit Orange fort.',
      ),
    ],
    done:
        '+3 für Gelb – Bernstein – Orange. Komplementär bleibt die '
        'gegenüberliegende Farbe, und ein voller Kreis braucht alle zwölf '
        'Farben (+6). Jetzt kennst du alle Regeln!',
  ),
];
