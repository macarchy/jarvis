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
import Quickshell.Services.UPower
import qs.Commons

import "components"

Item {
  id: service

  property var shell: null
  property var manifest: null

  // idle | listening | thinking | speaking | sleeping
  property string mood: "idle"
  property string bubbleText: ""
  property bool shown: true

  // ------------------------------------------------------------ emotions
  //
  // The pipeline mood always wins. At rest, the body wears the system's
  // state: a punctual emote (celebrate, worried…) first, then headphones
  // under DND, then exhaustion on a low discharging battery.
  property string emote: ""

  readonly property var notificationService: shell ? shell.serviceFor("omarchy.notifications") : null
  readonly property bool dnd: notificationService ? notificationService.doNotDisturb : false
  readonly property var batteryDevice: UPower.displayDevice
  readonly property bool batteryLow: batteryDevice
    ? Number(batteryDevice.percentage || 1) < 0.2
      && batteryDevice.state === UPowerDeviceState.Discharging
    : false

  // Circadian rest: late at night an idle fish sleeps on his own. Waking
  // interactions (mood, emotes) still win — he is asleep, not gone.
  property int hourNow: new Date().getHours()
  readonly property bool night: hourNow >= 23 || hourNow < 7

  Timer {
    interval: 60 * 1000
    repeat: true
    running: true
    onTriggered: service.hourNow = new Date().getHours()
  }

  readonly property string sprite: mood !== "idle" ? mood
    : (emote !== "" ? emote
    : (dnd ? "dnd"
    : (batteryLow ? "tired"
    : (night ? "sleeping" : "idle"))))

  // [frameCount, fps] per sheet.
  readonly property var sheets: ({
    idle: [6, 2.2],
    listening: [2, 4],
    thinking: [3, 3],
    speaking: [4, 8],
    sleeping: [4, 1.4],
    tired: [2, 1.6],
    dnd: [2, 2.2],
    worried: [2, 2.5],
    proud: [2, 2.2],
    curious: [2, 2.5],
    celebrate: [3, 6]
  })

  Timer {
    id: emoteTimer
    interval: 6000
    repeat: false
    onTriggered: service.emote = ""
  }

  function playEmote(name) {
    if (!sheets[name]) return
    emote = name
    emoteTimer.restart()
  }

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

    // Punctual emotion over the idle body (celebrate, worried, tired, dnd).
    function emote(name: string): void { service.playEmote(String(name)) }
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
      sheet: service.assetsDir + service.sprite + ".png"
      frameCount: service.sheets[service.sprite][0]
      fps: service.sheets[service.sprite][1]

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
