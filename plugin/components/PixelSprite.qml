// Nearest-neighbor sprite-sheet animator. The sheet is one horizontal strip
// of fixed-size frames; the Image is scaled with smooth: false so pixels
// stay square, and a timer slides the visible window frame by frame.
//
// Between two sheets there is a squash-cut rather than a jump cut: the body
// dips into the water for 70 ms, the strip is exchanged at the bottom of the
// dip where the silhouette is smallest and the swap has the least to hide,
// and he comes back up with a little overshoot. That dip is measured in
// WHOLE sprite rows — a fractional squash would resample the art and shear
// it — and it is the one thing that makes him read as an animal instead of
// a status icon.

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

  // What is actually on screen, and the two numbers that belong to it. They
  // lag the requested sheet by the length of the dip, and change together:
  // an old strip read with a new frame count shows holes.
  property url shownSheet
  property int shownFrames: 1
  property real shownFps: 3

  // A strip that will not load must not blank the body: `omarchy-jarvis
  // look` has not been run since a new state was drawn, or the data dir was
  // wiped. He goes on wearing the last one that did load — a fish in the
  // wrong picture is still a fish, and an empty corner reads as a crash.
  property url lastGood
  property int lastGoodFrames: 1
  property real lastGoodFps: 3

  // Rows of the frame eaten off the bottom, always whole ones.
  property int squash: 0
  property int squashRows: 6

  width: frameWidth * pixelScale
  height: frameHeight * pixelScale
  // The height never moves with the squash: the philactère hangs off this
  // item's top edge and would bounce with him.
  clip: true

  // A dip is only worth animating on a body someone can see. The first
  // sheet, and the empty URL `reload` flashes to bust Qt's image cache,
  // are exchanged where they are.
  onSheetChanged: {
    if (!visible || shownSheet.toString() === "" || sheet.toString() === "") applySheet()
    else cut(applySheet)
  }

  // The numbers go first and the strip last: a local file can turn Ready
  // synchronously on assignment, and the handler that runs then reads them.
  function applySheet() {
    shownFrames = frameCount
    shownFps = fps
    frame = 0
    shownSheet = sheet
    holding = false
  }

  // Outside a dip the numbers follow the caller immediately — they arrive in
  // their own binding pass, which during creation is the one AFTER the sheet.
  // Inside one they are held back, because they belong to the strip they came
  // with and applySheet takes all three together.
  property bool holding: false
  onFrameCountChanged: if (!holding) shownFrames = frameCount
  onFpsChanged: if (!holding) shownFps = fps

  // The shared primitive: dip, do the thing at the bottom, come back up.
  // The excursion's turnaround borrows it to flip the mirror out of sight.
  // A second cut landing on a running one restarts the dip and keeps both
  // errands: whatever asked to happen out of sight still happens out of sight.
  property var cutActions: []

  function cut(action) {
    holding = true
    if (action) cutActions.push(action)
    cutAnim.restart()
  }

  SequentialAnimation {
    id: cutAnim
    NumberAnimation { target: root; property: "squash"; to: root.squashRows; duration: 70; easing.type: Easing.InQuad }
    ScriptAction {
      script: {
        var todo = root.cutActions
        root.cutActions = []
        root.holding = false
        for (var i = 0; i < todo.length; i++) todo[i]()
      }
    }
    NumberAnimation { target: root; property: "squash"; to: 0; duration: 110; easing.type: Easing.OutBack }
  }

  // The squash itself: the viewport loses rows off the bottom of the art and
  // slides down by exactly as many, so he sinks into the water rather than
  // shrinking in place. OutBack's overshoot takes it briefly below zero on
  // the way up, which lifts him a row — the clip above keeps that honest.
  Item {
    id: viewport
    width: root.width
    y: root.squash * root.pixelScale
    height: root.height - y
    clip: true

    Image {
      source: root.shownSheet
      // The sheets are regenerated in place (omarchy-jarvis look): never
      // serve a stale copy from Qt's cache.
      cache: false
      smooth: false
      fillMode: Image.Stretch
      width: root.width * Math.max(1, root.shownFrames)
      height: root.height
      x: -root.frame * root.width

      onStatusChanged: {
        if (status === Image.Ready) {
          root.lastGood = source
          root.lastGoodFrames = root.shownFrames
          root.lastGoodFps = root.shownFps
        } else if (status === Image.Error && root.lastGood.toString() !== "") {
          var good = root.lastGood
          root.shownFrames = root.lastGoodFrames
          root.shownFps = root.lastGoodFps
          root.shownSheet = good
        }
      }
    }
  }

  Timer {
    interval: Math.max(40, Math.round(1000 / Math.max(0.1, root.shownFps)))
    running: root.playing && root.visible && root.shownFrames > 1
    repeat: true
    onTriggered: root.frame = (root.frame + 1) % root.shownFrames
  }
}
