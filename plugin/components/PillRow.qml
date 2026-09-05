pragma ComponentBehavior: Bound

// A mutually-exclusive row of chips — qs.Ui's ButtonGroup with the one change
// that matters on this theme.
//
// ButtonGroup paints the chosen chip with Button's `selected`, and `selected`
// recolours the LABEL to an accent-derived colour ON TOP of the accent fill:
// accent on accent, unreadable on apple-glass. `active` paints the same fill
// and leaves the label in the foreground colour, which is what we want.
//
// Chips take their natural width inside a Row, so a group never comes out
// ragged the way a RowLayout of fillWidth buttons does with uneven labels.

import QtQuick
import qs.Commons
import qs.Ui

Row {
  id: root

  // [{ value, label }], et rien d'autre : le format « tableau de chaînes »
  // qu'acceptait optionValue()/optionLabel() n'a jamais eu d'appelant.
  property var options: []
  property string value: ""
  property color foreground: Color.popups.text
  property real fontSize: Style.font.caption

  signal changed(string value)

  spacing: Style.space(4)

  Repeater {
    model: root.options

    delegate: Button {
      id: chip
      required property var modelData

      text: chip.modelData.label
      active: chip.modelData.value === root.value
      bordered: true
      foreground: root.foreground
      fontSize: root.fontSize
      onClicked: root.changed(chip.modelData.value)
    }
  }
}
