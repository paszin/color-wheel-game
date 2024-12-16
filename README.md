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
- new programming language, dart + flame, or kotlin?
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
          for 
          for each neighboor: if abs(neighboor.colorIndex - self.colorIndex) == 1: allPaths.append([neighboor], hasNew = True
          if hasNew: continue, else: break
        
def get_circulary_neighboors(node, prevNodes):
    resp = []
    for n in neighboors: if isColorWheelNeighbor(node): resp.append[prevNodes + [node] + get_circulary_neighboors(node, prevNodes + [node, n]])
