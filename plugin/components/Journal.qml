pragma ComponentBehavior: Bound

// The Journal: what Jarvis remembers, on paper.
//
// A page in the fish's own paper and ink, hosted by Service.qml in its own
// layer surface. Three tabs — today's conversation (with what went on in his
// head, folded under each exchange, and « Oublier » on the last one), every
// past conversation, and the routines he runs on the clock. It reads the CLI's
// JSON verbs and nothing else: `transcript`, `conversations`, `routines`,
// `undo`, `routine`. Each probe is one Process, re-armed on open and every
// five seconds while the page is showing — never two of the same in flight.

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui as Ui

FocusScope {
  id: root

  property color ink: "#181208"
  property color paper: "#FFF8E6"
  // The host tells us when the page is showing: probes and the clock only
  // run then.
  property bool open: false
  // today | conversations | routines
  property string tab: "today"

  signal closeRequested()

  readonly property color dim: Qt.rgba(ink.r, ink.g, ink.b, 0.55)
  readonly property color faint: Qt.rgba(ink.r, ink.g, ink.b, 0.18)
  readonly property color wash: Qt.rgba(ink.r, ink.g, ink.b, 0.06)
  readonly property int pad: Style.space(14)

  readonly property var tabs: [
    { value: "today", label: "Aujourd'hui" },
    { value: "conversations", label: "Conversations" },
    { value: "routines", label: "Routines" }
  ]

  // A name from the outside (IPC `journalTab`) — lenient on spelling, and
  // anything unknown lands on today rather than on a blank page.
  function setTab(name) {
    var n = String(name).toLowerCase()
    if (n.indexOf("conv") === 0) tab = "conversations"
    else if (n.indexOf("rout") === 0) tab = "routines"
    else tab = "today"
  }

  // ---------------------------------------------------------------- data
  property var today: []             // [{at, ask, reply, thoughts, tools}]
  property bool todayLoaded: false
  property var conversations: []     // [{id, kind, current, started, ended, exchanges, first}]
  property bool convLoaded: false
  property bool showTasks: false
  // A past conversation opened from the list: its row, and its exchanges.
  property string session: ""
  property var sessionMeta: null
  property var sessionExchanges: []
  property bool sessionLoaded: false
  property var routines: []          // [{n, on, when, days, once, verb, text, next, line}]
  property bool routinesLoaded: false

  // One line of feedback under the tabs (« Rien à oublier »), gone after 4 s.
  property string notice: ""
  Timer { id: noticeClock; interval: 4000; onTriggered: root.notice = "" }
  function say(text) { notice = text; noticeClock.restart() }

  // A verb that prints nothing valid (no conversation yet, a routines verb the
  // installed CLI does not have) reads as an empty list, never as a crash.
  function parseList(text) {
    try {
      var v = JSON.parse(String(text))
      return Array.isArray(v) ? v : null
    } catch (e) {
      return null
    }
  }

  function same(a, b) { return JSON.stringify(a) === JSON.stringify(b) }

  // ---------------------------------------------------------------- probes
  function arm(p) { if (!p.running) p.running = true }

  function refresh() {
    if (!open) return
    if (tab === "today") arm(todayProbe)
    else if (tab === "conversations") {
      arm(convProbe)
      if (session.length > 0) {
        // Set by hand, not bound: a binding could still read the previous
        // id when the process starts.
        sessionProbe.command = ["omarchy-jarvis", "transcript", "--json", "--session", session, "50"]
        arm(sessionProbe)
      }
    } else arm(routinesProbe)
  }

  onOpenChanged: {
    if (open) { refresh(); return }
    // Closing forgets the confirmation, not the place.
    undoArmed = false
  }
  onTabChanged: refresh()
  onSessionChanged: { sessionExchanges = []; sessionLoaded = false; refresh() }

  Timer {
    interval: 5000
    repeat: true
    running: root.open
    onTriggered: root.refresh()
  }

  Process {
    id: todayProbe
    command: ["omarchy-jarvis", "transcript", "--json", "30"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        var list = root.parseList(text) || []
        if (!root.same(list, root.today)) root.today = list
        root.todayLoaded = true
      }
    }
  }

  Process {
    id: sessionProbe
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        var list = root.parseList(text) || []
        if (!root.same(list, root.sessionExchanges)) root.sessionExchanges = list
        root.sessionLoaded = true
      }
    }
  }

  Process {
    id: convProbe
    command: ["omarchy-jarvis", "conversations", "--json"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        var list = root.parseList(text) || []
        if (!root.same(list, root.conversations)) root.conversations = list
        root.convLoaded = true
      }
    }
  }

  Process {
    id: routinesProbe
    command: ["omarchy-jarvis", "routines", "--json"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        var list = root.parseList(text) || []
        if (!root.same(list, root.routines)) root.routines = list
        root.routinesLoaded = true
      }
    }
  }

  // ---------------------------------------------------------------- actions
  //
  // One process for every verb that changes something; its exit code is the
  // answer (undo says no when he is busy or there is nothing left), and the
  // page re-reads itself either way.
  property string actionError: ""

  Process {
    id: action
    stderr: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.actionError = String(text).trim().split("\n")[0] || ""
    }
    onExited: function(code) {
      if (code !== 0) root.say(root.actionError.length > 0 ? root.actionError : "Refusé")
      root.actionError = ""
      root.refresh()
    }
  }

  function run(argv) {
    if (action.running) return
    actionError = ""
    action.command = argv
    action.running = true
  }

  // « Oublier » asks twice: the first click arms it for three seconds, the
  // second one forgets.
  property bool undoArmed: false
  Timer { id: undoClock; interval: 3000; onTriggered: root.undoArmed = false }

  function undo() {
    if (!undoArmed) { undoArmed = true; undoClock.restart(); return }
    undoArmed = false
    undoClock.stop()
    run(["omarchy-jarvis", "undo", "--quiet"])
  }

  function setRoutine(n, on) { run(["omarchy-jarvis", "routine", String(n), on ? "on" : "off"]) }
  function deleteRoutine(n) { run(["omarchy-jarvis", "routine", String(n), "delete"]) }
  function addRoutine(line) {
    var t = String(line).trim().replace(/^-\s*/, "")
    if (t.length === 0) return
    run(["omarchy-jarvis", "routine", "add", t])
  }

  // ---------------------------------------------------------------- text
  function pad2(n) { return String(n).padStart(2, "0") }

  function todayStamp() {
    var d = new Date()
    return d.getFullYear() + "-" + pad2(d.getMonth() + 1) + "-" + pad2(d.getDate())
  }

  // "AAAA-MM-JJ HH:MM" → "HH:MM" today, "JJ/MM HH:MM" otherwise.
  function whenText(s) {
    var m = /^(\d{4})-(\d{2})-(\d{2}) (\d{2}:\d{2})$/.exec(String(s || ""))
    if (!m) return String(s || "")
    if (m[1] + "-" + m[2] + "-" + m[3] === todayStamp()) return m[4]
    return m[3] + "/" + m[2] + " " + m[4]
  }

  function nextText(epoch) {
    var n = Number(epoch)
    if (!isFinite(n) || n <= 0) return ""
    var d = new Date(n * 1000)
    var stamp = d.getFullYear() + "-" + pad2(d.getMonth() + 1) + "-" + pad2(d.getDate())
    var hm = pad2(d.getHours()) + ":" + pad2(d.getMinutes())
    return stamp === todayStamp() ? "prochaine à " + hm
      : "prochaine le " + pad2(d.getDate()) + "/" + pad2(d.getMonth() + 1) + " à " + hm
  }

  function plural(n, word) { return n + " " + word + (n > 1 ? "s" : "") }

  readonly property var shownConversations: conversations.filter(function(c) {
    return showTasks || c.kind !== "tâche"
  })

  // ---------------------------------------------------------------- pieces
  component PaperButton: Rectangle {
    id: btn
    property string text: ""
    property bool active: false
    property bool small: false
    signal clicked()

    implicitWidth: btnLabel.implicitWidth + Style.space(btn.small ? 12 : 16)
    implicitHeight: btnLabel.implicitHeight + Style.space(btn.small ? 6 : 8)
    color: btn.active ? root.ink : (btnHover.hovered ? root.wash : "transparent")
    border.width: 2
    border.color: root.ink

    Text {
      id: btnLabel
      anchors.centerIn: parent
      text: btn.text
      color: btn.active ? root.paper : root.ink
      font.family: Style.font.family
      font.pixelSize: btn.small ? Style.font.caption : Style.font.bodySmall
      font.bold: btn.active
    }

    HoverHandler { id: btnHover }

    MouseArea {
      anchors.fill: parent
      cursorShape: Qt.PointingHandCursor
      onClicked: btn.clicked()
    }
  }

  // A scrolling list with the wheel driven by hand: Hyprland scales the
  // touchpad by 0.4 and Flickable applies pixelDelta 1:1, so a long swipe
  // would move the page an inch (same handler as the notification center).
  component Sheet: Flickable {
    id: sheet
    default property alias content: sheetColumn.data

    contentWidth: width
    contentHeight: sheetColumn.implicitHeight
    clip: true
    boundsBehavior: Flickable.StopAtBounds
    flickableDirection: Flickable.VerticalFlick
    interactive: contentHeight > height
    ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

    WheelHandler {
      target: null
      acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
      onWheel: function(event) {
        var dy = event.pixelDelta.y !== 0
          ? event.pixelDelta.y * 2.5
          : event.angleDelta.y / 120 * Style.space(80)
        var maxY = Math.max(0, sheet.contentHeight - sheet.height)
        sheet.contentY = Math.max(0, Math.min(maxY, sheet.contentY - dy))
      }
    }

    Column {
      id: sheetColumn
      width: sheet.width
      spacing: Style.space(10)
    }
  }

  component Empty: Text {
    width: parent ? parent.width : implicitWidth
    topPadding: Style.space(40)
    horizontalAlignment: Text.AlignHCenter
    color: root.dim
    font.family: Style.font.family
    font.pixelSize: Style.font.bodySmall
    wrapMode: Text.WordWrap
  }

  // One conversation, exchange by exchange. `canUndo` puts « Oublier » on the
  // last one: only the current conversation can be forgotten from.
  component Exchanges: Sheet {
    id: view
    property var exchanges: []
    property bool loaded: false
    property bool canUndo: false

    Empty {
      visible: view.loaded && view.exchanges.length === 0
      text: "Aucune conversation"
    }

    Repeater {
      model: view.exchanges

      delegate: Column {
        id: card
        required property var modelData
        required property int index
        readonly property var thoughts: card.modelData.thoughts || []
        readonly property var tools: card.modelData.tools || []
        readonly property int inside: card.thoughts.length + card.tools.length
        readonly property bool last: card.index === view.exchanges.length - 1
        property bool unfolded: false

        width: view.width
        spacing: Style.space(4)

        Rectangle {
          visible: card.index > 0
          width: parent.width
          height: 2
          color: root.faint
        }

        Row {
          width: parent.width
          spacing: Style.space(8)

          Text {
            id: at
            text: String(card.modelData.at || "")
            color: root.dim
            font.family: Style.font.family
            font.pixelSize: Style.font.caption
            font.bold: true
            topPadding: Style.space(2)
          }

          Text {
            width: parent.width - at.width - parent.spacing
            text: "« " + String(card.modelData.ask || "") + " »"
            color: root.ink
            font.family: Style.font.family
            font.pixelSize: Style.font.bodySmall
            font.italic: true
            wrapMode: Text.WordWrap
            maximumLineCount: 6
            elide: Text.ElideRight
          }
        }

        Text {
          width: parent.width
          visible: text.length > 0
          text: String(card.modelData.reply || "")
          color: root.ink
          font.family: Style.font.family
          font.pixelSize: Style.font.bodySmall
          wrapMode: Text.WordWrap
        }

        Row {
          width: parent.width
          spacing: Style.space(8)

          // The fold: what went on in his head, thoughts first, then the
          // tools in the order they ran.
          Text {
            visible: card.inside > 0
            text: (card.unfolded ? "▾" : "▸") + " dans sa tête · " + card.inside
            color: root.dim
            font.family: Style.font.family
            font.pixelSize: Style.font.caption

            MouseArea {
              anchors.fill: parent
              cursorShape: Qt.PointingHandCursor
              onClicked: card.unfolded = !card.unfolded
            }
          }

          Item { width: 1; height: 1 }

          PaperButton {
            visible: view.canUndo && card.last
            small: true
            text: root.undoArmed ? "Sûr ?" : "Oublier"
            active: root.undoArmed
            onClicked: root.undo()
          }
        }

        Column {
          visible: card.unfolded
          width: parent.width
          leftPadding: Style.space(12)
          spacing: Style.space(3)

          Repeater {
            model: card.unfolded ? card.thoughts : []
            delegate: Text {
              id: thought
              required property var modelData
              width: card.width - Style.space(12)
              text: "✎ " + String(thought.modelData)
              color: root.dim
              font.family: Style.font.family
              font.pixelSize: Style.font.caption
              font.italic: true
              wrapMode: Text.WordWrap
            }
          }

          Repeater {
            model: card.unfolded ? card.tools : []
            delegate: Column {
              id: tool
              required property var modelData
              width: card.width - Style.space(12)
              spacing: Style.space(1)

              Text {
                width: parent.width
                text: "→ " + String(tool.modelData.call || "")
                color: root.ink
                font.family: Style.font.family
                font.pixelSize: Style.font.caption
                wrapMode: Text.WrapAnywhere
                maximumLineCount: 4
                elide: Text.ElideRight
              }

              Text {
                width: parent.width
                visible: text.length > 2
                text: "← " + String(tool.modelData.result || "")
                color: root.dim
                font.family: Style.font.family
                font.pixelSize: Style.font.caption
                wrapMode: Text.WrapAnywhere
                maximumLineCount: 3
                elide: Text.ElideRight
              }

              Text {
                width: parent.width
                visible: text.length > 2
                text: "✗ " + String(tool.modelData.error || "")
                color: root.ink
                font.family: Style.font.family
                font.pixelSize: Style.font.caption
                wrapMode: Text.WrapAnywhere
                maximumLineCount: 3
                elide: Text.ElideRight
              }
            }
          }
        }
      }
    }
  }

  // ---------------------------------------------------------------- layout
  focus: true
  Keys.onEscapePressed: root.closeRequested()

  ColumnLayout {
    anchors.fill: parent
    anchors.margins: root.pad
    spacing: Style.space(10)

    RowLayout {
      Layout.fillWidth: true
      spacing: Style.space(6)

      Repeater {
        model: root.tabs
        delegate: PaperButton {
          id: chip
          required property var modelData
          text: chip.modelData.label
          active: root.tab === chip.modelData.value
          onClicked: root.tab = chip.modelData.value
        }
      }

      Item { Layout.fillWidth: true }

      Text {
        text: "✕"
        color: closeHover.hovered ? root.ink : root.dim
        font.family: Style.font.family
        font.pixelSize: Style.font.title

        HoverHandler { id: closeHover }

        MouseArea {
          anchors.fill: parent
          anchors.margins: -Style.space(6)
          cursorShape: Qt.PointingHandCursor
          onClicked: root.closeRequested()
        }
      }
    }

    Text {
      Layout.fillWidth: true
      visible: root.notice.length > 0
      text: root.notice
      color: root.ink
      font.family: Style.font.family
      font.pixelSize: Style.font.caption
      font.bold: true
      wrapMode: Text.WordWrap
    }

    // ------------------------------------------------------- Aujourd'hui
    Exchanges {
      visible: root.tab === "today"
      Layout.fillWidth: true
      Layout.fillHeight: true
      exchanges: root.today
      loaded: root.todayLoaded
      canUndo: true
    }

    // ------------------------------------------------------- Conversations
    ColumnLayout {
      visible: root.tab === "conversations" && root.session.length === 0
      Layout.fillWidth: true
      Layout.fillHeight: true
      spacing: Style.space(8)

      RowLayout {
        Layout.fillWidth: true
        spacing: Style.space(8)

        Text {
          text: root.plural(root.shownConversations.length, "conversation")
          color: root.dim
          font.family: Style.font.family
          font.pixelSize: Style.font.caption
        }

        Item { Layout.fillWidth: true }

        // The rounds and missions are conversations too, one exchange each;
        // they would bury the real ones.
        PaperButton {
          small: true
          text: "voir aussi les tâches"
          active: root.showTasks
          onClicked: root.showTasks = !root.showTasks
        }
      }

      Sheet {
        Layout.fillWidth: true
        Layout.fillHeight: true

        Empty {
          visible: root.convLoaded && root.shownConversations.length === 0
          text: "Aucune conversation"
        }

        Repeater {
          model: root.shownConversations

          delegate: Rectangle {
            id: row
            required property var modelData
            width: parent.width
            implicitHeight: rowCol.implicitHeight + Style.space(12)
            color: rowHover.hovered ? root.wash : "transparent"
            border.width: 2
            border.color: row.modelData.current ? root.ink : root.faint

            HoverHandler { id: rowHover }

            MouseArea {
              anchors.fill: parent
              cursorShape: Qt.PointingHandCursor
              onClicked: {
                root.sessionMeta = row.modelData
                root.session = String(row.modelData.id)
              }
            }

            Column {
              id: rowCol
              anchors.left: parent.left
              anchors.right: parent.right
              anchors.top: parent.top
              anchors.margins: Style.space(6)
              anchors.leftMargin: Style.space(8)
              spacing: Style.space(2)

              Text {
                width: parent.width
                text: (row.modelData.current ? "● " : "")
                  + root.whenText(row.modelData.started)
                  + " · " + root.plural(Number(row.modelData.exchanges || 0), "échange")
                  + (row.modelData.kind === "tâche" ? " · tâche" : "")
                color: root.dim
                font.family: Style.font.family
                font.pixelSize: Style.font.caption
                font.bold: row.modelData.current === true
                elide: Text.ElideRight
              }

              Text {
                width: parent.width
                text: String(row.modelData.first || "")
                color: root.ink
                font.family: Style.font.family
                font.pixelSize: Style.font.bodySmall
                wrapMode: Text.WordWrap
                maximumLineCount: 2
                elide: Text.ElideRight
              }
            }
          }
        }
      }
    }

    // A past conversation, opened from the list: the same rendering, with
    // the way back on top and no « Oublier ».
    ColumnLayout {
      visible: root.tab === "conversations" && root.session.length > 0
      Layout.fillWidth: true
      Layout.fillHeight: true
      spacing: Style.space(8)

      RowLayout {
        Layout.fillWidth: true
        spacing: Style.space(8)

        PaperButton {
          small: true
          text: "← Conversations"
          onClicked: root.session = ""
        }

        Text {
          Layout.fillWidth: true
          text: root.sessionMeta
            ? root.whenText(root.sessionMeta.started) + " → " + root.whenText(root.sessionMeta.ended)
              + " · " + root.plural(Number(root.sessionMeta.exchanges || 0), "échange")
            : ""
          color: root.dim
          font.family: Style.font.family
          font.pixelSize: Style.font.caption
          elide: Text.ElideRight
        }
      }

      Exchanges {
        Layout.fillWidth: true
        Layout.fillHeight: true
        exchanges: root.sessionExchanges
        loaded: root.sessionLoaded
        canUndo: false
      }
    }

    // ------------------------------------------------------- Routines
    ColumnLayout {
      visible: root.tab === "routines"
      Layout.fillWidth: true
      Layout.fillHeight: true
      spacing: Style.space(8)

      Sheet {
        Layout.fillWidth: true
        Layout.fillHeight: true

        Empty {
          visible: root.routinesLoaded && root.routines.length === 0
          text: "Aucune routine"
        }

        Repeater {
          model: root.routines

          delegate: Rectangle {
            id: rt
            required property var modelData
            readonly property bool on: rt.modelData.on === true
            width: parent.width
            implicitHeight: rtRow.implicitHeight + Style.space(12)
            color: "transparent"
            border.width: 2
            border.color: rt.on ? root.ink : root.faint

            RowLayout {
              id: rtRow
              anchors.left: parent.left
              anchors.right: parent.right
              anchors.top: parent.top
              anchors.margins: Style.space(6)
              anchors.leftMargin: Style.space(8)
              spacing: Style.space(10)

              // The switch, in ink: a frame with the knob on the right when on.
              Rectangle {
                Layout.preferredWidth: Style.space(30)
                Layout.preferredHeight: Style.space(16)
                Layout.alignment: Qt.AlignTop
                Layout.topMargin: Style.space(2)
                color: rt.on ? root.ink : "transparent"
                border.width: 2
                border.color: root.ink

                Rectangle {
                  width: Style.space(8)
                  height: Style.space(8)
                  anchors.verticalCenter: parent.verticalCenter
                  x: rt.on ? parent.width - width - Style.space(4) : Style.space(4)
                  color: rt.on ? root.paper : root.ink

                  Behavior on x { NumberAnimation { duration: 120 } }
                }

                MouseArea {
                  anchors.fill: parent
                  anchors.margins: -Style.space(4)
                  cursorShape: Qt.PointingHandCursor
                  onClicked: root.setRoutine(rt.modelData.n, !rt.on)
                }
              }

              Column {
                Layout.fillWidth: true
                spacing: Style.space(2)

                Text {
                  width: parent.width
                  text: String(rt.modelData.when || "")
                    + (rt.modelData.once ? " · une fois" : " · " + (rt.modelData.days === "*" ? "tous les jours" : String(rt.modelData.days || "")))
                    + " · " + String(rt.modelData.verb || "")
                  color: rt.on ? root.ink : root.dim
                  font.family: Style.font.family
                  font.pixelSize: Style.font.caption
                  font.bold: true
                  elide: Text.ElideRight
                }

                Text {
                  width: parent.width
                  text: String(rt.modelData.text || "")
                  color: rt.on ? root.ink : root.dim
                  font.family: Style.font.family
                  font.pixelSize: Style.font.bodySmall
                  wrapMode: Text.WordWrap
                  maximumLineCount: 3
                  elide: Text.ElideRight
                }

                Text {
                  width: parent.width
                  visible: rt.on && text.length > 0
                  text: root.nextText(rt.modelData.next)
                  color: root.dim
                  font.family: Style.font.family
                  font.pixelSize: Style.font.caption
                  elide: Text.ElideRight
                }
              }

              Text {
                Layout.alignment: Qt.AlignTop
                text: "󰆴"
                color: binHover.hovered ? root.ink : root.dim
                font.family: Style.font.family
                font.pixelSize: Style.font.title

                HoverHandler { id: binHover }

                MouseArea {
                  anchors.fill: parent
                  anchors.margins: -Style.space(4)
                  cursorShape: Qt.PointingHandCursor
                  onClicked: root.deleteRoutine(rt.modelData.n)
                }
              }
            }
          }
        }
      }

      // Adding one is writing its line, the way the file itself reads.
      Rectangle {
        Layout.fillWidth: true
        implicitHeight: addField.implicitHeight + Style.space(8)
        color: "transparent"
        border.width: 2
        border.color: root.ink

        Ui.TextField {
          id: addField
          anchors.fill: parent
          anchors.margins: Style.space(4)
          placeholderText: "Ajouter : 08:00 lun-ven ask --quiet Briefing du matin"
          foreground: root.ink
          font.pixelSize: Style.font.bodySmall
          onAccepted: {
            root.addRoutine(text)
            clear()
          }
        }
      }

      Text {
        Layout.fillWidth: true
        text: "HH:MM jours verbe texte — jours : *, lun-ven, lun,mer · ou AAAA-MM-JJ HH:MM once · verbes : say, ask, ask --quiet, notify, dispatch"
        color: root.dim
        font.family: Style.font.family
        font.pixelSize: Style.font.caption
        wrapMode: Text.WordWrap
      }
    }
  }
}
