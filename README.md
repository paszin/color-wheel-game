# color-wheel-game


inspired by https://doodles.google/doodle/rise-of-the-half-moon/


Colors: yellow, orange, red, purple, blue, green.

Layout: any grid layout, circular, rectangle. sub groups.

3 color cards in hand, when drawing a new code, increase the likelyhood of not having a duplicate

Rules: 
 - complementary touching: 2 points
 - same color touching: 1 point
 - circle: as many points as colors but at least 3

Implementation:

- layout like smartphone
- new programming language, dart + flame
- graph structure.


class ColorNode:
- id: uuid
- color: enum
- colorIndex: int
- neighbors: array[ColorNode]

  getScore:
    -
      - complementaty: for each neighboor: self.colorIndex == (neighboor.colorIndex + len(colors) / 2) % len(colors)
return 1 point, neighboor
      - same color: self.color == self.color
      - circle: allPaths = [[self]]
          hasNew = False
          for each neighboor: if abs(neighboor.colorIndex - self.colorIndex) == 1: allPaths.append([neighboor], hasNew = True
          if hasNew: continue, else: break

```
def get_circulary_neighboors(currentCircle):
    resp = []
    for n in currentCircle[-1].neighboors:
         if isColorWheelNeighbor(currentCircle[-1]):
              nextCircles = currentCircle + get_circulary_neighboors(currentCircle + [n])
              resp += nextCircles
    return resp
```

## Umsetzung (Stand)

Flutter + Flame, Web zuerst (`flutter run -d chrome`), gleicher Code für iOS/Android/macOS.

```
flutter test                    # Spiellogik, Wertung, KI
flutter build web --release     # Ergebnis in build/web
```

Regeln, wie umgesetzt:
- Gleiche Farbe benachbart: 1 Punkt je Nachbar, Komplementärfarbe benachbart: 2 Punkte je Nachbar.
- Farbfolge: längste Kette verbundener Karten durch die neue Karte, die dem Farbkreis Schritt für Schritt folgt (beide Richtungen, Grün → Gelb läuft um), ab 3 Karten, Punkte = Länge. Enthält sie alle 6 Farben: +3.
- Gelegte Karte gehört dem Spieler, bei einer Wertung übernimmt er alle beteiligten Karten.
- Spielende, wenn das Brett voll ist: Punkte + eigene Felder.
- Hand: 3 Karten, Nachziehen mit Gewicht 1 / (1 + 3 · Anzahl der Farbe in der Hand).

Code: `lib/logic/scoring.dart` (Wertung), `lib/model/levels.dart` (8 Bretter),
`lib/painting/watercolor.dart` (Aquarell-Rendering), `lib/game/` (Flame-Brett), `lib/ui/` (Screens).
