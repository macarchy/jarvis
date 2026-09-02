// The Babel fish — Jarvis's mascot.
//
// A small always-on layer surface in the bottom-right corner: a pixel-art
// Babel fish that idles, perks up when Jarvis listens, ponders while the
// brain thinks, and mouths along while the reply is spoken — with the
// exchange shown in a comic philactère drawn in his own pixels: the ask
// in pale ink, the reply typed out at reading speed while the voice
// speaks, thinking dots while the brain works, a thought bubble (dashed,
// beads) for what he says in his sleep, and a severed tail when you cut
// him off mid-sentence.
//
// The voice pipeline (~/Work/jarvis/bin/jarvis) drives it over IPC:
//   omarchy-shell macarchy.jarvis setState idle|listening|thinking|speaking|cancelling
//   omarchy-shell macarchy.jarvis heard "<transcript>"
//   omarchy-shell macarchy.jarvis reply "<text>"
//   omarchy-shell macarchy.jarvis abort
// Clicking the fish is the same as the push-to-talk key, which is modal:
// while he is busy it cancels. So does right-clicking him, clicking the
// bubble while he speaks, and Escape in the prompt bar — every surface
// that can start a request can take it back. Right-click on an idle fish
// hides him until `omarchy-shell macarchy.jarvis show`.

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

  // idle | listening | thinking | speaking | sleeping | cancelling
  property string mood: "idle"
  property bool shown: true

  // Anything but rest: a request is in flight and the surfaces that start
  // one become the ones that take it back.
  readonly property bool busy: mood !== "idle"

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
  //
  // The hours are not the mascot's to decide. `silence` lives in SOUL.md
  // and bash resolves it on every transition into $STATE_DIR/quiet, so a
  // user who turns quiet hours off from the Control Center no longer gets
  // a fish curling up asleep at 23:05 while Jarvis demonstrably is not.
  // The clock below survives only as the fallback for a machine where the
  // pipeline has not spoken yet.
  property int hourNow: new Date().getHours()
  property string quietFlag: ""
  readonly property bool night: quietFlag === ""
    ? (hourNow >= 23 || hourNow < 7)
    : quietFlag === "1"

  readonly property string quietPath: (Quickshell.env("JARVIS_STATE")
    || (Quickshell.env("HOME") + "/.local/state/jarvis")) + "/quiet"

  FileView {
    id: quietFile
    path: service.quietPath
    watchChanges: true
    preload: true
    // A machine that has never run the pipeline has no such file, and that
    // is not worth a line in the shell's log every time it is looked at.
    printErrors: false
    onFileChanged: reload()
    onLoaded: service.quietFlag = quietFile.text().trim()
    onLoadFailed: service.quietFlag = ""
  }

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

  // Every write to swimX from OUTSIDE an animation eases: being called back
  // mid-swim, and the shake's way home. The excursion's own NumberAnimations
  // drive the property directly and are unaffected — an animation bypasses
  // an interceptor.
  Behavior on swimX {
    NumberAnimation { duration: 420; easing.type: Easing.OutCubic }
  }

  SequentialAnimation {
    id: excursion
    NumberAnimation { target: service; property: "swimX"; to: -Style.space(150); duration: 4600; easing.type: Easing.InOutSine }
    PauseAnimation { duration: 1100 }
    // He turns around inside a squash-cut: the mirror flips at the bottom
    // of the dip, where there is least of him to see it happen.
    ScriptAction { script: fish.cut(function() { fishMirror.xScale = -1 }) }
    PauseAnimation { duration: 350 }
    NumberAnimation { target: service; property: "swimX"; to: 0; duration: 4600; easing.type: Easing.InOutSine }
    ScriptAction { script: fish.cut(function() { fishMirror.xScale = 1 }) }
  }

  // Being called back mid-swim used to teleport him into the corner in one
  // frame, sometimes back-to-front. Now he turns around first and the
  // Behavior on swimX carries him home over 420 ms; the mirror only comes
  // back once he has arrived.
  function stopExcursion() {
    if (!excursion.running && swimX === 0) return
    excursion.stop()
    if (swimX === 0) {
      fishMirror.xScale = 1
      return
    }
    fishMirror.xScale = -1
    swimX = 0
    swimHome.restart()
  }

  Timer {
    id: swimHome
    interval: 520
    repeat: false
    onTriggered: fishMirror.xScale = 1
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

  // Only a notification ARRIVING is news. The handler fires on any change
  // of the count, so dismissing one of three popups used to make him
  // curious about a notification going away.
  property int lastPopups: 0

  Connections {
    target: service.popupModel
    ignoreUnknownSignals: true
    function onCountChanged() {
      if (!service.popupModel) return
      var n = service.popupModel.count
      var grew = n > service.lastPopups
      service.lastPopups = n
      if (!grew) return
      var now = Date.now()
      if (service.mood !== "idle" || now - service.lastGlance < 120000) return
      service.lastGlance = now
      service.playEmote("curious")
    }
  }

  // ------------------------------------------------------ the interruption
  //
  // Cancelling is a gesture, and a gesture needs a body. Without one his
  // whole answer to being aborted was to go on quietly typing out the reply
  // for another twenty seconds — which reads as not having heard you at
  // all. So: the sentence stops where the voice stopped, the philactère's
  // tail is severed, and he recoils.
  property bool aborting: false
  property int swimHomeMs: 0

  // The cancel sheet outlives the shake by a beat: an animation shorter
  // than a blink is one the user is not sure he saw.
  Timer {
    id: abortHold
    interval: 1300
    repeat: false
    onTriggered: service.aborting = false
  }

  // What is still un-typed was never said out loud, so it is dropped rather
  // than written out after the fact, and the ellipsis says the answer was
  // cut rather than finished. Truncating also stops the typewriter, whose
  // `running` is bound to there being something left to type.
  function clampReply() {
    if (typeN >= replyTarget.length) return
    replyTarget = replyTarget.substring(0, typeN) + " …"
    typeN = replyTarget.length
  }

  function playAbort() {
    clampReply()
    bubbleStyle = "cut"
    aborting = true
    abortHold.restart()
    restLinger()
    // The shake rides the Translate the excursion already uses: he has one
    // body and it only ever moves along the bottom edge. If he is still out
    // there swimming, the first step of the shake is the way home.
    swimHomeMs = Math.abs(swimX) > 1 ? 260 : 0
    abortShake.restart()
  }

  SequentialAnimation {
    id: abortShake
    NumberAnimation { target: service; property: "swimX"; to: 0; duration: service.swimHomeMs; easing.type: Easing.OutCubic }
    NumberAnimation { target: service; property: "swimX"; to: Style.space(9); duration: 60; easing.type: Easing.OutQuad }
    NumberAnimation { target: service; property: "swimX"; to: -Style.space(7); duration: 70; easing.type: Easing.InOutQuad }
    NumberAnimation { target: service; property: "swimX"; to: Style.space(4); duration: 60; easing.type: Easing.InOutQuad }
    NumberAnimation { target: service; property: "swimX"; to: 0; duration: 70; easing.type: Easing.OutQuad }
  }

  // ---------------------------------------------------------- the drawing
  readonly property string sprite: (aborting || mood === "cancelling") ? "cancel"
    : (mood !== "idle" ? mood
    : (emote !== "" ? emote
    : (dnd ? "dnd"
    : (batteryLow ? "tired"
    : (night ? "sleeping" : "idle")))))

  // [frameCount, fps] per sheet.
  readonly property var sheets: ({
    idle: [6, 2.2],
    listening: [2, 4],
    thinking: [3, 3],
    speaking: [4, 8],
    cancel: [4, 6],
    sleeping: [4, 1.4],
    tired: [2, 1.6],
    dnd: [2, 2.2],
    worried: [2, 2.5],
    proud: [2, 2.2],
    curious: [2, 2.5],
    celebrate: [3, 6]
  })

  // Nothing may index this map blind: `setState` is public IPC and a name
  // nobody drew would otherwise reach frameCount as undefined.
  function sheetOf(name) {
    return sheets.hasOwnProperty(name) ? sheets[name] : sheets.idle
  }

  // The six seconds an emotion lasts are six seconds of being SEEN: the
  // timer only counts while the emote is the sprite actually drawn. He is
  // told to be proud in the middle of his own answer, when the pipeline
  // mood wins the body — the emotion used to expire unwatched, every time.
  Timer {
    id: emoteTimer
    interval: 6000
    repeat: false
    running: service.emote !== "" && service.sprite === service.emote
    onTriggered: service.emote = ""
  }

  // Clearing first re-arms the timer through its binding: restart() would
  // write `running` by hand and throw that binding away.
  function playEmote(name) {
    if (!sheets.hasOwnProperty(name)) return
    emote = ""
    emote = name
  }

  // The sheets live OUTSIDE the plugin folder (the shell hot-reloads
  // itself on any change in there): `omarchy-jarvis look` writes them to
  // the user's data dir and pings `reload`.
  readonly property url assetsDir: "file://" + Quickshell.env("HOME") + "/.local/share/jarvis/sprites/"
  // Flipping this drops the sheet URL for one tick, which — with
  // Image.cache off — makes the sprite re-read the freshly generated
  // file. `omarchy-jarvis look` calls reload after every regeneration.
  property bool spriteBust: false

  // The pipeline's vocabulary is the state machine's, not the sheet's: two
  // of its seven states have no picture of their own and borrow one, and
  // anything the machine has never heard of is refused rather than drawn as
  // a hole.
  readonly property var moodAlias: ({ transcribing: "thinking", followup: "listening" })
  readonly property var moods: ["idle", "listening", "thinking", "speaking", "sleeping", "cancelling"]

  function setMood(next) {
    var m = moodAlias.hasOwnProperty(next) ? moodAlias[next] : next
    if (moods.indexOf(m) === -1) return
    if (m === mood) return
    // Leaving `speaking` means the voice has stopped, whether it finished,
    // failed or was cut: from here on nothing more will be said, so nothing
    // more is written either. (Only leaving it — the quiet path of `ask`
    // never speaks at all, and the typewriter is the whole delivery there.)
    if (mood === "speaking" || mood === "cancelling") clampReply()
    // A body with something else to do is done being cancelled.
    if (m !== "idle" && m !== "cancelling") {
      aborting = false
      abortHold.stop()
    }
    mood = m
    if (m === "idle") restLinger()
    else bubbleLinger.stop()
  }

  // The body clock: tick him — the script decides between a nap (memory to
  // digest) and a round (system health check), and owns every guard:
  // conversation freshness and both cooldowns.
  //
  // It used to run only while he idled, which meant one wedged request
  // stopped all autonomy for the rest of the login session. It now runs
  // always, and a systemd timer beats beside it so the pulse no longer
  // depends on the shell being alive either.
  Timer {
    interval: 5 * 60 * 1000
    repeat: true
    running: true
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

    // A request was cancelled. `cancel` sends this last, after the state has
    // already come down, so it must be legible on its own: the reply stops
    // where the voice did, the tail is cut, and he recoils.
    function abort(): void { service.playAbort() }

    // The written exchange: a small prompt bar (SUPER+ALT+E). Enter sends
    // to `ask --quiet`, the reply lands in the philactère.
    function prompt(): void {
      if (!service.promptOpen) promptField.text = ""
      service.promptOpen = !service.promptOpen
    }

    // The Journal: what he remembers, on paper (today's exchanges with what
    // went on in his head, past conversations, routines). `journal`
    // toggles, `journalTab conversations|routines|today` opens on a tab.
    function journal(): void { service.journalOpen = !service.journalOpen }
    function journalClose(): void { service.journalOpen = false }
    function journalTab(name: string): void {
      journalPage.setTab(String(name))
      service.journalOpen = true
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
        // Escape puts the strip away — and takes back the question it
        // asked, if that one is still in flight.
        Keys.onEscapePressed: {
          if (service.busy) Quickshell.execDetached(["omarchy-jarvis", "cancel"])
          service.promptOpen = false
        }
        onAccepted: {
          var t = text.trim()
          service.promptOpen = false
          if (t.length > 0) Quickshell.execDetached(["omarchy-jarvis", "ask", "--quiet", t])
        }
      }
    }

    onVisibleChanged: if (visible) Qt.callLater(function() { promptField.forceActiveFocus() })
  }

  // ------------------------------------------------------ the journal
  //
  // A sheet of his paper under the bar, top right: today's conversation
  // with what went on in his head, the past ones, and his routines. It
  // takes the keyboard only when clicked into (OnDemand), so an open
  // journal never steals a keystroke from the window you are working in;
  // Escape, once it has the keyboard, puts it away.
  property bool journalOpen: false

  PanelWindow {
    id: journalWin
    visible: service.journalOpen
    screen: Quickshell.screens.length > 0 ? Quickshell.screens[0] : null
    color: "transparent"

    WlrLayershell.namespace: "macarchy-jarvis-journal"
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.keyboardFocus: service.journalOpen ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
    // Respect the bar's reserved edge (so "top" means under it), reserve
    // nothing ourselves.
    exclusionMode: ExclusionMode.Normal
    exclusiveZone: 0

    anchors { top: true; right: true }
    margins { top: Style.space(8); right: Style.space(8) }
    implicitWidth: Style.space(520)
    implicitHeight: Math.min(Style.space(700), (screen ? screen.height : 900) - Style.space(60))

    // The page's frame is the bubble's own stepped border, without a tail.
    PixelBubble {
      anchors.fill: parent
      px: 4
      tailUnits: 0
      kind: "plain"
      paper: service.bubblePaper
      ink: service.bubbleInk
    }

    Item {
      anchors.fill: parent

      Journal {
        id: journalPage
        anchors.fill: parent
        anchors.margins: 6
        ink: service.bubbleInk
        paper: service.bubblePaper
        open: service.journalOpen
        onCloseRequested: service.journalOpen = false
      }
    }

    onVisibleChanged: if (visible) Qt.callLater(function() { journalPage.forceActiveFocus() })
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
          // While he is speaking, the thing you want from the bubble is not
          // to read it faster: it is for him to stop.
          if (service.mood === "speaking") {
            Quickshell.execDetached(["omarchy-jarvis", "cancel"])
            return
          }
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
      frameCount: service.sheetOf(service.sprite)[0]
      fps: service.sheetOf(service.sprite)[1]

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
          // Left click is the push-to-talk key, modal in bash: start,
          // finish, barge in, or cancel, depending on where he is. Right
          // click puts him away — unless he is busy, in which case putting
          // him away would only hide a request that keeps running.
          if (mouse.button !== Qt.RightButton)
            Quickshell.execDetached(["omarchy-jarvis", "press"])
          else if (service.busy)
            Quickshell.execDetached(["omarchy-jarvis", "cancel"])
          else
            service.shown = false
        }
      }
    }
  }
}
