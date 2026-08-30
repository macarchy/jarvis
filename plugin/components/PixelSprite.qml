// Nearest-neighbor sprite-sheet animator. The sheet is one horizontal strip
// of fixed-size frames; the Image is scaled with smooth: false so pixels
// stay square, and a timer slides the visible window frame by frame.

import QtQuick

Item {
  id: root

  property url sheet
  property int frameCount: 1
  property real fps: 3
  // Native frame size, in sheet pixels.
  property int frameWidth: 36
  property int frameHeight: 28
  property int pixelScale: 4
  property bool playing: true

  property int frame: 0

  width: frameWidth * pixelScale
  height: frameHeight * pixelScale
  clip: true

  onSheetChanged: frame = 0

  Image {
    source: root.sheet
    smooth: false
    fillMode: Image.Stretch
    width: root.width * root.frameCount
    height: root.height
    x: -root.frame * root.width
  }

  Timer {
    interval: Math.max(40, Math.round(1000 / root.fps))
    running: root.playing && root.visible && root.frameCount > 1
    repeat: true
    onTriggered: root.frame = (root.frame + 1) % root.frameCount
  }
}
