// The comic philactère, in the fish's own pixels. A paper card with a
// stepped ink border drawn on a unit grid (one unit = one fish pixel),
// a tail that leans down-left toward the mouth, and a "thought" variant
// (dashed border, drifting beads) for what he says in his sleep.
//
// The Canvas only draws chrome; the caller owns the content and sizes
// this item so that height = content + margins + tailUnits * px.

import QtQuick

Item {
  id: root

  property color paper: "#FFF8E6"
  property color ink: "#181208"
  property int px: 4
  property int tailUnits: 4
  // Tail apex, in units from the LEFT edge; the caller aims it at the
  // mouth and clamps it inside the card.
  property int tailX: 6
  property string kind: "speech" // speech | thought

  readonly property int tailPx: tailUnits * px

  onWidthChanged: canvas.requestPaint()
  onHeightChanged: canvas.requestPaint()
  onTailXChanged: canvas.requestPaint()
  onKindChanged: canvas.requestPaint()
  onPaperChanged: canvas.requestPaint()
  onInkChanged: canvas.requestPaint()

  Canvas {
    id: canvas
    anchors.fill: parent
    onPaint: {
      var ctx = getContext("2d")
      ctx.clearRect(0, 0, width, height)
      var u = root.px
      var W = Math.round(width / u)
      var Hp = Math.round((height - root.tailPx) / u)
      if (W < 8 || Hp < 4) return
      var dashed = root.kind === "thought"
      function cell(x, y, c) { ctx.fillStyle = c; ctx.fillRect(x * u, y * u, u, u) }
      function inkCell(x, y, i) { if (!dashed || i % 3 !== 2) cell(x, y, root.ink) }

      // Paper first, chrome over it.
      ctx.fillStyle = root.paper
      ctx.fillRect(u, u, (W - 2) * u, (Hp - 2) * u)

      var i, n = 0
      for (i = 2; i <= W - 3; i++) inkCell(i, 0, n++)
      for (i = 2; i <= Hp - 3; i++) inkCell(W - 1, i, n++)
      for (i = W - 3; i >= 2; i--) {
        if (root.kind === "speech" && i >= root.tailX && i <= root.tailX + 2) {
          cell(i, Hp - 1, root.paper); n++
        } else {
          inkCell(i, Hp - 1, n++)
        }
      }
      for (i = Hp - 3; i >= 2; i--) inkCell(0, i, n++)
      // Stepped corners always print, even dashed.
      cell(1, 1, root.ink); cell(W - 2, 1, root.ink)
      cell(1, Hp - 2, root.ink); cell(W - 2, Hp - 2, root.ink)

      var tx = root.tailX
      if (root.kind === "speech") {
        // A clean right triangle: straight left edge, hypotenuse
        // tapering down-left toward the mouth.
        cell(tx - 1, Hp - 1, root.ink); cell(tx + 3, Hp - 1, root.ink)
        cell(tx - 1, Hp, root.ink); cell(tx, Hp, root.paper); cell(tx + 1, Hp, root.paper); cell(tx + 2, Hp, root.paper); cell(tx + 3, Hp, root.ink)
        cell(tx - 1, Hp + 1, root.ink); cell(tx, Hp + 1, root.paper); cell(tx + 1, Hp + 1, root.paper); cell(tx + 2, Hp + 1, root.ink)
        cell(tx - 1, Hp + 2, root.ink); cell(tx, Hp + 2, root.paper); cell(tx + 1, Hp + 2, root.ink)
        cell(tx - 1, Hp + 3, root.ink); cell(tx, Hp + 3, root.ink)
      } else {
        // Thought beads drifting down toward the head: paper hearts so
        // they read as bubbles, not crumbs.
        cell(tx - 1, Hp, root.ink); cell(tx, Hp, root.ink); cell(tx + 1, Hp, root.ink)
        cell(tx - 1, Hp + 1, root.ink); cell(tx, Hp + 1, root.paper); cell(tx + 1, Hp + 1, root.ink)
        cell(tx - 1, Hp + 2, root.ink); cell(tx, Hp + 2, root.ink); cell(tx + 1, Hp + 2, root.ink)
        cell(tx - 3, Hp + 3, root.ink); cell(tx - 2, Hp + 3, root.ink)
      }
    }
  }
}
