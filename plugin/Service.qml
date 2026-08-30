// The Babel fish — Jarvis's mascot.
//
// A small always-on layer surface in the bottom-right corner: a pixel-art
// Babel fish that idles, perks up when Jarvis listens, ponders while the
// brain thinks, and mouths along while the reply is spoken — with the
// transcript and reply shown in a glass speech bubble.
//
// The voice pipeline (~/Work/jarvis/bin/jarvis) drives it over IPC:
//   omarchy-shell macarchy.jarvis setState idle|listening|thinking|speaking
//   omarchy-shell macarchy.jarvis heard "<transcript>"
//   omarchy-shell macarchy.jarvis reply "<text>"
// Clicking the fish is the same as the push-to-talk key. Right-click hides
// it until `omarchy-shell macarchy.jarvis show`.

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.Commons

import "components"

Item {
  id: service

  property var shell: null
  property var manifest: null

  // idle | listening | thinking | speaking
  property string mood: "idle"
  property string bubbleText: ""
  property bool shown: true

  readonly property url assetsDir: Qt.resolvedUrl("assets/")

  function setMood(next) {
    var valid = ["idle", "listening", "thinking", "speaking", "sleeping"]
    if (valid.indexOf(next) === -1) return
    mood = next
    if (next === "idle") bubbleLinger.restart()
    else bubbleLinger.stop()
  }

  // Once the exchange is over, the bubble hangs around long enough to read,
  // then the fish goes back to just being a fish.
  Timer {
    id: bubbleLinger
    interval: 8000
    repeat: false
    onTriggered: service.bubbleText = ""
  }

  // The body clock: whenever Jarvis idles, tick him — the script decides
  // between a nap (memory to digest) and a round (system health check),
  // and owns every guard: conversation freshness and both cooldowns.
  Timer {
    interval: 5 * 60 * 1000
    repeat: true
    running: service.mood === "idle"
    onTriggered: Quickshell.execDetached(["omarchy-jarvis", "tick"])
  }

  IpcHandler {
    target: "macarchy.jarvis"

    function setState(state: string): string {
      service.setMood(String(state))
      return service.mood
    }

    function heard(text: string): void {
      service.bubbleText = "« " + String(text) + " »"
    }

    function reply(text: string): void {
      service.bubbleText = String(text)
    }

    function show(): void { service.shown = true }
    function hide(): void { service.shown = false }
    function toggle(): void { service.shown = !service.shown }
    function isShown(): string { return service.shown ? "on" : "off" }
    function ping(): string { return "ok" }
  }

  PanelWindow {
    id: window
    visible: service.shown
    screen: Quickshell.screens.length > 0 ? Quickshell.screens[0] : null
    color: "transparent"

    WlrLayershell.namespace: "macarchy-jarvis"
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    exclusionMode: ExclusionMode.Ignore

    anchors {
      bottom: true
      right: true
    }

    margins {
      bottom: Style.space(14)
      right: Style.space(14)
    }

    implicitWidth: Style.space(300)
    implicitHeight: bubble.visible ? fish.height + bubble.height + Style.space(10) : fish.height

    // Only the fish and its bubble catch the pointer; the rest of the
    // surface is click-through.
    mask: Region {
      item: fish
      Region { item: bubble }
    }

    // Speech bubble: glass card, right-aligned above the fish, with a
    // little pixel tail pointing down at it.
    Rectangle {
      id: bubble
      visible: service.bubbleText.length > 0
      anchors.right: parent.right
      anchors.bottom: fish.top
      anchors.bottomMargin: Style.space(10)
      width: Math.min(bubbleLabel.implicitWidth + Style.space(24), window.implicitWidth)
      height: bubbleLabel.implicitHeight + Style.space(18)
      radius: Style.space(8)
      color: Color.popups.background
      border.width: 1
      border.color: Util.alpha(Color.popups.text, 0.25)

      Rectangle {
        anchors.top: parent.bottom
        anchors.right: parent.right
        anchors.rightMargin: Style.space(28)
        width: Style.space(8)
        height: Style.space(8)
        rotation: 45
        anchors.topMargin: -Style.space(5)
        color: bubble.color
        border.width: 1
        border.color: bubble.border.color
      }

      Text {
        id: bubbleLabel
        anchors.centerIn: parent
        width: Math.min(implicitWidth, window.implicitWidth - Style.space(24))
        text: service.bubbleText
        color: Color.popups.text
        font.family: Style.font.family
        font.pixelSize: Style.font.bodySmall
        wrapMode: Text.WordWrap
      }

      MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: service.bubbleText = ""
      }
    }

    PixelSprite {
      id: fish
      anchors.right: parent.right
      anchors.bottom: parent.bottom
      pixelScale: 4
      sheet: service.assetsDir + service.mood + ".png"
      frameCount: service.mood === "idle" ? 6
        : (service.mood === "listening" ? 2
        : (service.mood === "thinking" ? 3
        : (service.mood === "sleeping" ? 4 : 4)))
      fps: service.mood === "idle" ? 2.2
        : (service.mood === "listening" ? 4
        : (service.mood === "thinking" ? 3
        : (service.mood === "sleeping" ? 1.4 : 8)))

      // Swim in from below when shown, dive away when hidden.
      transform: Translate {
        id: swim
        y: 0
      }

      MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onClicked: function(mouse) {
          if (mouse.button === Qt.RightButton) service.shown = false
          else Quickshell.execDetached(["omarchy-jarvis", "listen"])
        }
      }
    }
  }
}
