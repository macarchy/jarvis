// The Babel fish — Jarvis's mascot.
//
// A small always-on layer surface in the bottom-right corner: a pixel-art
// Babel fish that idles, perks up when Jarvis listens, ponders while the
// brain thinks, and mouths along while the reply is spoken — with the
// exchange shown in a comic philactère drawn in his own pixels: the ask
// in pale ink, the reply typed out at reading speed while the voice
// speaks, thinking dots while the brain works, and a thought bubble
// (dashed, beads) for what he says in his sleep.
//
// The voice pipeline (~/Work/jarvis/bin/jarvis) drives it over IPC:
//   omarchy-shell macarchy.jarvis setState idle|listening|thinking|speaking
//   omarchy-shell macarchy.jarvis heard "<transcript>"
//   omarchy-shell macarchy.jarvis reply "<text>"
// Clicking the fish is the same as the push-to-talk key. Clicking the
// bubble reveals the rest of a reply still typing, then dismisses it.
// Right-click hides the fish until `omarchy-shell macarchy.jarvis show`.

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.UPower
import Quickshell.Hyprland
import qs.Commons
import qs.Ui as Ui

import "components"

Item {
  id: service

  property var shell: null
  property var manifest: null

  // idle | listening | thinking | speaking | sleeping
  property string mood: "idle"
  property bool shown: true

  // ------------------------------------------------------- the philactère
  //
  // The fish's own ink and paper (sprites/generate.py palette): the bubble
  // is HIS object, deliberately the same in every shell theme.
  readonly property color bubbleInk: "#181208"
  readonly property color bubblePaper: "#FFF8E6"

  property string heardText: ""    // the ask, kept visible under the reply
  property string replyTarget: ""  // the full reply so far (grows by sentence)
  property int typeN: 0            // characters revealed by the typewriter
  property string bubbleStyle: "speech"

  readonly property bool typing: typeN < replyTarget.length
  readonly property bool dotsOn: mood === "thinking" && replyTarget.length === 0
  readonly property bool bubbleOn: shown
    && (heardText.length > 0 || replyTarget.length > 0 || dotsOn)

  // ~60 chars/s: comfortably ahead of the voice, clearly behind a paste.
  Timer {
    id: typeTimer
    interval: 34
    repeat: true
    running: service.typing && service.shown
    onTriggered: service.typeN = Math.min(service.replyTarget.length, service.typeN + 2)
  }

  function clearBubble() {
    heardText = ""
    replyTarget = ""
    typeN = 0
    bubbleLinger.stop()
  }

  // Once the exchange is over, the bubble hangs around long enough to
  // read — proportionally to how much there is to read.
  Timer {
    id: bubbleLinger
    repeat: false
    onTriggered: service.clearBubble()
  }

  function restLinger() {
    var chars = heardText.length + replyTarget.length
    if (chars === 0) return
    bubbleLinger.interval = Math.min(20000, Math.max(6000, 4000 + chars * 55))
    bubbleLinger.restart()
  }

  // ------------------------------------------------------------ emotions
  //
  // The pipeline mood always wins. At rest, the body wears the system's
  // state: a punctual emote (celebrate, worried…) first, then headphones
  // under DND, then exhaustion on a low discharging battery.
  property string emote: ""

  readonly property var notificationService: shell ? shell.serviceFor("omarchy.notifications") : null
  readonly property var popupModel: notificationService ? notificationService.popupModel : null
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

  // --------------------------------------------------------- visible life
  //
  // A pet that only exists when spoken to is a widget. Every so often an
  // idle fish takes a little swim along the bottom edge and comes back;
  // a fresh notification earns a curious glance. Both stand down the
  // moment the pipeline needs the body.
  property real swimX: 0
  property double lastGlance: 0

  SequentialAnimation {
    id: excursion
    NumberAnimation { target: service; property: "swimX"; to: -Style.space(150); duration: 4600; easing.type: Easing.InOutSine }
    PauseAnimation { duration: 1100 }
    ScriptAction { script: fishMirror.xScale = -1 }
    PauseAnimation { duration: 350 }
    NumberAnimation { target: service; property: "swimX"; to: 0; duration: 4600; easing.type: Easing.InOutSine }
    ScriptAction { script: fishMirror.xScale = 1 }
  }

  function stopExcursion() {
    if (!excursion.running && swimX === 0) return
    excursion.stop()
    swimX = 0
    fishMirror.xScale = 1
  }

  onMoodChanged: if (mood !== "idle") stopExcursion()
  onShownChanged: if (!shown) stopExcursion()

  Timer {
    id: excursionClock
    interval: (10 + Math.random() * 12) * 60 * 1000
    repeat: true
    running: service.shown && !service.night
    onTriggered: {
      interval = (10 + Math.random() * 12) * 60 * 1000
      if (service.mood === "idle" && !excursion.running) excursion.start()
    }
  }

  Connections {
    target: service.popupModel
    ignoreUnknownSignals: true
    function onCountChanged() {
      if (!service.popupModel || service.popupModel.count === 0) return
      var now = Date.now()
      if (service.mood !== "idle" || now - service.lastGlance < 120000) return
      service.lastGlance = now
      service.playEmote("curious")
    }
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

  // The sheets live OUTSIDE the plugin folder (the shell hot-reloads
  // itself on any change in there): `omarchy-jarvis look` writes them to
  // the user's data dir and pings `reload`.
  readonly property url assetsDir: "file://" + Quickshell.env("HOME") + "/.local/share/jarvis/sprites/"
  // Flipping this drops the sheet URL for one tick, which — with
  // Image.cache off — makes the sprite re-read the freshly generated
  // file. `omarchy-jarvis look` calls reload after every regeneration.
  property bool spriteBust: false

  function setMood(next) {
    var valid = ["idle", "listening", "thinking", "speaking", "sleeping"]
    if (valid.indexOf(next) === -1) return
    mood = next
    if (next === "idle") restLinger()
    else bubbleLinger.stop()
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
      var t = String(text)
      if (t.length === 0) { service.clearBubble(); return }
      service.heardText = "« " + t + " »"
      service.replyTarget = ""
      service.typeN = 0
      service.bubbleStyle = "speech"
      bubbleLinger.stop()
    }

    function reply(text: string): void {
      var t = String(text)
      if (t.length === 0) { service.clearBubble(); return }
      // The pipeline resends the whole reply as it grows sentence by
      // sentence: keep the typewriter's place when the new text only
      // extends the old, restart it otherwise.
      if (!(service.replyTarget.length > 0 && t.indexOf(service.replyTarget) === 0))
        service.typeN = 0
      service.replyTarget = t
      service.bubbleStyle = service.mood === "sleeping" ? "thought" : "speech"
      if (service.mood === "sleeping") service.heardText = ""
      bubbleLinger.stop()
      if (service.mood === "idle") service.restLinger()
    }

    function show(): void { service.shown = true }
    function hide(): void { service.shown = false }
    function toggle(): void { service.shown = !service.shown }
    function isShown(): string { return service.shown ? "on" : "off" }

    // Punctual emotion over the idle body (celebrate, worried, tired, dnd).
    function emote(name: string): void { service.playEmote(String(name)) }

    // The written exchange: a small prompt bar (SUPER+ALT+K). Enter sends
    // to `ask --quiet`, the reply lands in the philactère.
    function prompt(): void {
      if (!service.promptOpen) promptField.text = ""
      service.promptOpen = !service.promptOpen
    }

    // Re-read the sprite sheets after `omarchy-jarvis look` regenerated them.
    function reload(): void {
      service.spriteBust = true
      Qt.callLater(function() { service.spriteBust = false })
    }

    // A little swim along the bottom edge, on demand (idle only).
    function swim(): void {
      if (service.mood === "idle" && !excursion.running) excursion.start()
    }
    function ping(): string { return "ok" }
  }

  // ------------------------------------------------------ the prompt bar
  //
  // A paper strip near the top of the screen, keyboard-exclusive while
  // open: type, Enter, and the fish answers in his bubble. Escape or a
  // click elsewhere puts it away.
  property bool promptOpen: false

  PanelWindow {
    id: promptWin
    visible: service.promptOpen
    screen: Quickshell.screens.length > 0 ? Quickshell.screens[0] : null
    color: "transparent"

    WlrLayershell.namespace: "macarchy-jarvis-prompt"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: service.promptOpen ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    exclusionMode: ExclusionMode.Ignore

    anchors { top: true }
    margins { top: Style.space(140) }
    implicitWidth: Style.space(540)
    implicitHeight: promptBox.height + Style.space(8)

    HyprlandFocusGrab {
      active: service.promptOpen
      windows: [promptWin]
      onCleared: service.promptOpen = false
    }

    Rectangle {
      id: promptBox
      anchors.horizontalCenter: parent.horizontalCenter
      y: Style.space(4)
      width: parent.width - Style.space(8)
      height: promptField.implicitHeight + Style.space(20)
      color: service.bubblePaper
      border.width: 4
      border.color: service.bubbleInk

      Ui.TextField {
        id: promptField
        anchors.fill: parent
        anchors.margins: Style.space(10)
        placeholderText: "Écris à Jarvis…"
        foreground: service.bubbleInk
        font.pixelSize: Style.font.body
        Keys.onEscapePressed: service.promptOpen = false
        onAccepted: {
          var t = text.trim()
          service.promptOpen = false
          if (t.length > 0) Quickshell.execDetached(["omarchy-jarvis", "ask", "--quiet", t])
        }
      }
    }

    onVisibleChanged: if (visible) Qt.callLater(function() { promptField.forceActiveFocus() })
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
    implicitHeight: bubble.visible ? fish.height + bubble.height + Style.space(6) : fish.height

    // Only the fish and its bubble catch the pointer; the rest of the
    // surface is click-through.
    mask: Region {
      item: fish
      Region { item: bubble }
    }

    PixelBubble {
      id: bubble

      readonly property int pad: px * 3

      visible: service.bubbleOn
      anchors.right: parent.right
      anchors.bottom: fish.top
      anchors.bottomMargin: Style.space(2)
      px: 4
      ink: service.bubbleInk
      paper: service.bubblePaper
      kind: service.bubbleStyle
      // Snapped to the unit grid: fractional text metrics would other-
      // wise shear the border and detach the tail by half a pixel.
      width: Math.ceil(Math.min(bubbleCol.implicitWidth + pad * 2, window.implicitWidth) / px) * px
      height: Math.ceil((bubbleCol.implicitHeight + pad * 2) / px) * px + tailPx
      // Aim the tail at the mouth: the fish faces left, mouth ~31 units
      // in from his right edge (which is also the bubble's right edge).
      tailX: Math.max(3, Math.min(Math.round(width / px) - 5, Math.round(width / px) - 31))

      Column {
        id: bubbleCol
        x: bubble.pad
        y: bubble.pad
        spacing: Style.space(5)

        readonly property int maxw: window.implicitWidth - bubble.pad * 2

        Text {
          visible: service.heardText.length > 0
          width: Math.min(implicitWidth, parent.maxw)
          text: service.heardText
          color: Qt.rgba(service.bubbleInk.r, service.bubbleInk.g, service.bubbleInk.b, 0.5)
          font.family: Style.font.family
          font.pixelSize: Style.font.caption
          wrapMode: Text.WordWrap
        }

        Text {
          visible: service.replyTarget.length > 0
          width: Math.min(implicitWidth, parent.maxw)
          // The block cursor rides along while the typewriter works.
          text: service.replyTarget.substring(0, service.typeN) + (service.typing ? "█" : "")
          color: service.bubbleInk
          font.family: Style.font.family
          font.pixelSize: Style.font.bodySmall
          wrapMode: Text.WordWrap
        }

        Row {
          visible: service.dotsOn
          spacing: bubble.px

          property int active: 0
          Timer {
            running: service.dotsOn
            interval: 280
            repeat: true
            onTriggered: parent.active = (parent.active + 1) % 3
          }

          Repeater {
            model: 3
            Rectangle {
              width: bubble.px * 2
              height: bubble.px * 2
              color: service.bubbleInk
              opacity: parent.active === index ? 1 : 0.45
            }
          }
        }
      }

      MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: {
          if (service.typing) service.typeN = service.replyTarget.length
          else service.clearBubble()
        }
      }
    }

    PixelSprite {
      id: fish
      anchors.right: parent.right
      anchors.bottom: parent.bottom
      // 72x56 sheets at 2: the same 144x112 on screen as the old 36x28 at 4,
      // with four times the pixels for the parts engine to draw with.
      frameWidth: 72
      frameHeight: 56
      pixelScale: 2
      sheet: service.spriteBust ? "" : service.assetsDir + service.sprite + ".png"
      frameCount: service.sheets[service.sprite][0]
      fps: service.sheets[service.sprite][1]

      // The excursion glides him left and back; the mirror turns him
      // around for the return leg.
      transform: [
        Scale {
          id: fishMirror
          xScale: 1
          origin.x: fish.width / 2

          Behavior on xScale { NumberAnimation { duration: 90 } }
        },
        Translate {
          id: swim
          x: service.swimX
          y: 0
        }
      ]

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
