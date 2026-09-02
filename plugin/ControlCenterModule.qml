pragma ComponentBehavior: Bound

// Jarvis, as a Control Center module.
//
// This page used to live inside macarchy.control-center — 900 lines of
// Jarvis in a panel that knows nothing about him. It belongs here, next to
// the mascot and the service that already speak his CLI, and the Control
// Center now only knows what every module tells it: a row, and a page.
//
// The order on the page is the point of the rewrite: what is ALIVE first
// (what he is doing, the last exchange, the line to write to him), then what
// asks a DECISION of you (the suggestion inbox — it used to sit last, behind
// 1200px of settings), then the settings, folded.

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui
import "components"

Item {
  id: mod

  // ------------------------------------------------------------- contract
  property var bar: null
  property var manifest: null
  property bool panelOpen: false
  property bool pageShowing: false
  // Set false by the shell while the finger is still moving.
  property bool pageSettled: true

  property string title: "Jarvis"
  property string glyph: "󰚩"
  property bool hasToggle: true

  // The switch on the row shows/dives the Babel fish.
  readonly property bool active: mod.shown
  // A brain in trouble (quota, stall) takes over the row's badge and line —
  // that is the one thing worth seeing without opening the page.
  readonly property bool alert: !mod.brainOk
  readonly property string summary: !mod.brainOk ? mod.brainText()
    : mod.tone.charAt(0).toUpperCase() + mod.tone.slice(1)
      + (mod.lessons > 0 ? " · " + mod.lessons + " leçon" + (mod.lessons > 1 ? "s" : "") : "")

  signal toggled()
  onToggled: mod.toggleMascot()

  // ------------------------------------------------------------- state
  readonly property string soulPath: Quickshell.env("HOME") + "/Work/jarvis/SOUL.md"
  readonly property string memoryDir: Quickshell.env("HOME") + "/Work/jarvis/memory/"

  property bool shown: true
  property string tone: "majordome"
  property bool humor: true
  property bool vous: false
  property string lang: "fr"
  property bool wake: false
  property string muteMode: "ecrire"

  readonly property var tones: ["majordome", "complice", "laconique"]
  readonly property var toneOptions: [
    { value: "majordome", label: "Majordome" },
    { value: "complice", label: "Complice" },
    { value: "laconique", label: "Laconique" }
  ]
  readonly property var langs: [
    { value: "fr", label: "Français" }, { value: "en", label: "English" }, { value: "auto", label: "Auto" }
  ]
  // What he does when asked to listen with the microphone muted. The default
  // hands over the keyboard: he cannot hear you, so the honest move is the
  // other way in.
  readonly property var muteModes: [
    { value: "ecrire", label: "Clavier" }, { value: "prevenir", label: "Prévenir" }, { value: "reactiver", label: "Réactiver" }
  ]

  // The fish's look: one soul setting per part (sprites/parts.py).
  property string corps: "B1"
  property string oeil: "E1"
  property string criniere: "M1"
  property string queue: "T1"
  property string couleur: "or"
  readonly property var lookAxes: [
    { key: "corps", label: "Corps", options: [
      { value: "B1", label: "Babel" }, { value: "B2", label: "Rond" },
      { value: "B3", label: "Élancé" }, { value: "B4", label: "Anguille" }] },
    { key: "oeil", label: "Œil", options: [
      { value: "E1", label: "Grand" }, { value: "E2", label: "Amande" },
      { value: "E3", label: "Rond" }, { value: "E4", label: "Anneau" }] },
    { key: "criniere", label: "Crinière", options: [
      { value: "M1", label: "Éventail" }, { value: "M2", label: "Voile" },
      { value: "M3", label: "Mohawk" }, { value: "M4", label: "Antennes" }] },
    { key: "queue", label: "Queue", options: [
      { value: "T1", label: "Fourche" }, { value: "T2", label: "Éventail" },
      { value: "T3", label: "Croissant" }, { value: "T4", label: "Ruban" }] }
  ]
  readonly property var couleurs: [
    ["or", "#F2C94C"], ["corail", "#F08A5D"], ["lagon", "#4CC9C0"], ["lavande", "#A78BFA"],
    ["menthe", "#7ED957"], ["perle", "#ECE7DC"], ["braise", "#FF6B6B"], ["encre", "#5C8DFF"]
  ]

  function lookValue(key) {
    return key === "corps" ? corps : key === "oeil" ? oeil
      : key === "criniere" ? criniere : key === "queue" ? queue : couleur
  }

  function lookLabel(key) {
    for (var i = 0; i < lookAxes.length; i++) {
      if (lookAxes[i].key !== key) continue
      var opts = lookAxes[i].options
      for (var j = 0; j < opts.length; j++)
        if (opts[j].value === lookValue(key)) return opts[j].label
    }
    return lookValue(key)
  }

  // Live status, from `omarchy-jarvis status` (key=value lines).
  property string fsmState: "idle"
  property string brain: "ok"            // ok | quota <epoch> | blocked | down
  property bool quiet: false
  property bool rondes: true
  property bool reves: true
  property string silence: "23-7"        // "HH-HH" | "non"
  property int lastHeartbeat: 0
  property int nextHeartbeat: 0
  property string lastAsk: ""
  property string lastReply: ""
  property int failures: 0
  property int lessons: 0
  property int suggestionCount: 0
  property int routines: 0
  // [{ n, date, text }] — the dream's proposals awaiting a decision.
  property var suggestions: []

  readonly property bool brainOk: brain === "ok"

  function clock(epoch) {
    var d = new Date(epoch * 1000)
    return d.getHours() + "h" + String(d.getMinutes()).padStart(2, "0")
  }

  function stateText() {
    switch (fsmState) {
    case "listening": return "À l'écoute"
    case "transcribing": return "Transcrit"
    case "thinking": return "Réfléchit"
    case "speaking": return "Parle"
    case "followup": return "Attend une suite"
    case "sleeping": return "Rêve"
    // Milliseconds long in practice, but the label exists so an abort that
    // does wedge reads as an abort and not as a fish at rest.
    case "cancelling": return "Annule"
    default: return "Au repos"
    }
  }

  function brainText() {
    if (brain.indexOf("quota ") === 0)
      return "Quota atteint · retour " + clock(parseInt(brain.slice(6), 10))
    if (brain === "blocked") return "Ronde bloquée (approbation)"
    if (brain === "down") return "Cerveau injoignable"
    return "Cerveau OK"
  }

  function silenceText() {
    var m = /^(\d+)-(\d+)$/.exec(silence)
    return m ? m[1] + "h–" + m[2] + "h" : "23h–7h"
  }

  // The rounds line: why they are not happening, or when the next one is.
  function roundsText() {
    if (!rondes) return "Désactivées"
    if (brain.indexOf("quota ") === 0) return "Suspendues jusqu'à " + clock(parseInt(brain.slice(6), 10)) + " (quota)"
    if (quiet) return "En pause (silence " + silenceText() + ")"
    var last = lastHeartbeat > 0 ? "Dernière " + clock(lastHeartbeat) : "Aucune encore"
    var mins = Math.max(0, Math.round((nextHeartbeat - Date.now() / 1000) / 60))
    return last + " · prochaine dans ~" + mins + " min"
  }

  function soulSummary() {
    return tone.charAt(0).toUpperCase() + tone.slice(1) + " · " + lang
  }

  function autoSummary() {
    var s = (!rondes && !reves) ? "Tout est coupé"
      : silence === "non" ? "Sans silence" : "Silence " + silenceText()
    if (routines > 0) s += " · " + routines + " routine" + (routines > 1 ? "s" : "")
    return s
  }

  // The Journal window lives with the mascot (Service.qml): the same paper
  // as his bubble, under the bar, top right.
  function openJournal(tab) {
    Quickshell.execDetached(["omarchy-shell", "macarchy.jarvis", "journalTab", tab])
  }

  // Forget the last exchange. `undo` says no on its own when he is busy or
  // there is nothing left; the 900 ms recheck shows the outcome either way.
  function undo() {
    Quickshell.execDetached(["omarchy-jarvis", "undo", "--quiet"])
    recheck.restart()
  }

  // ------------------------------------------------------------- actions

  function toggleMascot() {
    shown = !shown
    Quickshell.execDetached(["omarchy-shell", "macarchy.jarvis", shown ? "show" : "hide"])
  }

  function setTone(value) {
    tone = value
    Quickshell.execDetached(["bash", "-c",
      'sed -i "s/^- ton: .*/- ton: $1/" "$2" && omarchy-jarvis reset', "--", value, soulPath])
  }

  function toggleHumor() {
    humor = !humor
    Quickshell.execDetached(["bash", "-c",
      'sed -i "s/^- humour: .*/- humour: $1/" "$2" && omarchy-jarvis reset', "--",
      humor ? "oui" : "non", soulPath])
  }

  function toggleVous() {
    vous = !vous
    Quickshell.execDetached(["bash", "-c",
      'sed -i "s/^- adresse: .*/- adresse: $1/" "$2" && omarchy-jarvis reset', "--",
      vous ? "monsieur" : "tutoiement", soulPath])
  }

  // Switching the ears off inside a follow-up window used to park him there:
  // the daemon is what closes that window, so killing it left the fish perked
  // up until the next press. `settle` is a no-op from every other state.
  // The bracket keeps this shell's own cmdline out of the pkill pattern.
  function toggleWake() {
    wake = !wake
    if (wake) Quickshell.execDetached(["omarchy-jarvis-wake"])
    else Quickshell.execDetached(["bash", "-c",
      'pkill -f "jarvis-wake[.]py"; omarchy-jarvis settle'])
    recheck.restart()
  }

  // These three pills fix the language of the whole conversation: what his
  // ears expect (whisper is pinned to this setting) and the voice that
  // answers. He re-reads it on every phrase, so no `reset` — pressing
  // « English » mid-exchange changes the next reply's voice.
  function setLang(value) {
    lang = value
    Quickshell.execDetached(["bash", "-c",
      'sed -i "s/^- langue: .*/- langue: $1/" "$2"', "--", value, soulPath])
  }

  function setMuteMode(value) {
    muteMode = value
    setSetting("micro-coupe", value)
  }

  // The automations live in SOUL.md's « Réglages » like the tone does, but
  // they are read live by the FSM on every tick — no reset needed. An older
  // soul without the line gets it appended after `langue`.
  function setSetting(key, value) {
    Quickshell.execDetached(["bash", "-c",
      'grep -q "^- $1:" "$3" && sed -i "s/^- $1: .*/- $1: $2/" "$3" || sed -i "/^- langue:/a - $1: $2" "$3"',
      "--", key, value, soulPath])
    recheck.restart()
  }

  function toggleRondes() { rondes = !rondes; setSetting("rondes", rondes ? "oui" : "non") }
  function toggleReves() { reves = !reves; setSetting("reves", reves ? "oui" : "non") }

  function toggleSilence() {
    silence = silence !== "non" ? "non" : "23-7"
    setSetting("silence", silence)
  }

  function setLook(key, value) {
    if (key === "corps") corps = value
    else if (key === "oeil") oeil = value
    else if (key === "criniere") criniere = value
    else if (key === "queue") queue = value
    else couleur = value
    Quickshell.execDetached(["bash", "-c",
      'grep -q "^- $1:" "$3" && sed -i "s/^- $1: .*/- $1: $2/" "$3" || sed -i "/^- langue:/a - $1: $2" "$3"; omarchy-jarvis look',
      "--", key, value, soulPath])
  }

  function randomLook() {
    Quickshell.execDetached(["omarchy-jarvis", "look", "random"])
    recheck.restart()
  }

  // The written exchange for shared offices: one line to `omarchy-jarvis ask
  // --quiet` — same brain, same banner and bubble, no speakers. Paint the ask
  // optimistically; the 3s poll brings the state and then the reply.
  function sendText(text) {
    var t = text.trim()
    if (t.length === 0) return
    lastAsk = t
    lastReply = ""
    Quickshell.execDetached(["omarchy-jarvis", "ask", "--quiet", t])
    recheck.restart()
  }

  // A suggestion leaves the inbox either way: `accept` hands it to a
  // background mission, `reject` just journals it. Nothing vanishes.
  function decide(n, verdict) {
    suggestions = suggestions.filter(function(s) { return s.n !== n })
    Quickshell.execDetached(["omarchy-jarvis", "suggestion", String(n), verdict])
    slowRecheck.restart()
  }

  function dream() { Quickshell.execDetached(["omarchy-jarvis", "dream"]) }
  function reset() { Quickshell.execDetached(["omarchy-jarvis", "reset"]) }

  signal closeRequested()
  function edit(path) {
    mod.closeRequested()
    Quickshell.execDetached(["zed", path])
  }

  // ------------------------------------------------------------- probe

  function refresh() { probe.running = true }

  onPanelOpenChanged: if (panelOpen) refresh()
  onPageShowingChanged: if (pageShowing) refresh()

  Timer { id: recheck; interval: 900; onTriggered: mod.refresh() }
  Timer { id: slowRecheck; interval: 4000; onTriggered: mod.refresh() }

  // His state changes by the second when he is spoken to, and a round or a
  // quota notice can land while the page is open.
  Timer {
    interval: 3000
    repeat: true
    running: mod.pageShowing && mod.pageSettled
    onTriggered: probe.running = true
  }

  Process {
    id: probe
    command: ["bash", "-c",
      'omarchy-shell macarchy.jarvis isShown 2>/dev/null || echo off\n' +
      'grep -m1 "^- ton:" "$1" 2>/dev/null | sed "s/^- ton: *//"\n' +
      'grep -m1 "^- humour:" "$1" 2>/dev/null | sed "s/^- humour: *//"\n' +
      'grep -m1 "^- adresse:" "$1" 2>/dev/null | sed "s/^- adresse: *//"\n' +
      'grep -m1 "^- langue:" "$1" 2>/dev/null | sed "s/^- langue: *//"\n' +
      // The bracket keeps this probing shell's own cmdline out of the match —
      // a plain pattern makes pgrep find itself and the toggle reads "on"
      // forever.
      'pgrep -f "jarvis-wake[.]py" >/dev/null && echo on || echo off\n' +
      // Then the FSM's own report, and past a marker the suggestions as
      // tab-separated `n date text`.
      'omarchy-jarvis status 2>/dev/null\n' +
      'echo ---\n' +
      'omarchy-jarvis suggestions 2>/dev/null', "--", mod.soulPath]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        var lines = String(text).split("\n")
        mod.shown = (lines[0] || "").trim() === "on"
        var t = (lines[1] || "").trim()
        if (mod.tones.indexOf(t) !== -1) mod.tone = t
        mod.humor = (lines[2] || "").trim() !== "non"
        mod.vous = (lines[3] || "").trim() === "monsieur"
        var l = (lines[4] || "").trim()
        mod.lang = (l === "fr" || l === "en" || l === "auto") ? l : "fr"
        mod.wake = (lines[5] || "").trim() === "on"

        var kv = ({})
        var inbox = []
        var i = 6
        for (; i < lines.length && lines[i] !== "---"; i++) {
          var eq = lines[i].indexOf("=")
          if (eq > 0) kv[lines[i].slice(0, eq)] = lines[i].slice(eq + 1)
        }
        for (i++; i < lines.length; i++) {
          var parts = lines[i].split("\t")
          if (parts.length >= 3)
            inbox.push({ n: parseInt(parts[0], 10), date: parts[1], text: parts.slice(2).join("\t") })
        }
        function num(k) { var v = parseInt(kv[k] || "", 10); return isFinite(v) ? v : 0 }
        mod.fsmState = kv.state || "idle"
        mod.brain = kv.brain || "ok"
        mod.quiet = kv.quiet === "oui"
        mod.rondes = kv.rondes !== "non"
        mod.reves = kv.reves !== "non"
        mod.silence = kv.silence || "23-7"
        mod.muteMode = kv.micro_coupe || "ecrire"
        mod.corps = kv.corps || "B1"
        mod.oeil = kv.oeil || "E1"
        mod.criniere = kv.criniere || "M1"
        mod.queue = kv.queue || "T1"
        mod.couleur = kv.couleur || "or"
        mod.lastHeartbeat = num("last_heartbeat")
        mod.nextHeartbeat = num("next_heartbeat")
        mod.lastAsk = kv.last_ask || ""
        mod.lastReply = kv.last_reply || ""
        mod.failures = num("failures")
        mod.lessons = num("lessons")
        mod.suggestionCount = num("suggestions")
        mod.routines = num("routines")
        // A `var` assignment always signals, and the Repeater would rebuild
        // every card on each poll — only swap when the inbox actually changed.
        if (JSON.stringify(inbox) !== JSON.stringify(mod.suggestions))
          mod.suggestions = inbox
      }
    }
  }

  // ------------------------------------------------------------- page
  property Component page: Component {
    ColumnLayout {
      spacing: Style.space(12)

      // ------------------------------------------------ what is alive
      Rectangle {
        Layout.fillWidth: true
        radius: Math.min(Style.cornerRadius, Style.space(10))
        color: Style.normalFill
        implicitHeight: live.implicitHeight + Style.space(20)

        ColumnLayout {
          id: live
          anchors.left: parent.left
          anchors.right: parent.right
          anchors.top: parent.top
          anchors.margins: Style.space(10)
          spacing: Style.space(4)

          RowLayout {
            Layout.fillWidth: true
            spacing: Style.space(8)

            Rectangle {
              Layout.preferredWidth: Style.space(8)
              Layout.preferredHeight: Style.space(8)
              radius: width / 2
              color: mod.brainOk ? Color.accent : Color.urgent

              Behavior on color { ColorAnimation { duration: 120 } }
            }

            Text {
              text: mod.stateText()
              color: Color.popups.text
              font.family: Style.font.family
              font.pixelSize: Style.font.bodySmall
              font.bold: true
            }

            Item { Layout.fillWidth: true }

            Text {
              text: mod.brainText()
              color: mod.brainOk ? Util.alpha(Color.popups.text, 0.55) : Color.urgent
              font.family: Style.font.family
              font.pixelSize: Style.font.caption
            }
          }

          Text {
            Layout.fillWidth: true
            Layout.topMargin: Style.space(2)
            visible: mod.lastAsk.length > 0
            text: "« " + mod.lastAsk + " »"
            color: Util.alpha(Color.popups.text, 0.55)
            font.family: Style.font.family
            font.pixelSize: Style.font.caption
            wrapMode: Text.WordWrap
            maximumLineCount: 2
            elide: Text.ElideRight
          }

          Text {
            Layout.fillWidth: true
            visible: mod.lastReply.length > 0
            text: "→ " + mod.lastReply
            // Rendered markdown (bold, lists). Elision is plain-text only,
            // so the line count alone bounds it.
            textFormat: Text.MarkdownText
            color: Color.popups.text
            font.family: Style.font.family
            font.pixelSize: Style.font.caption
            wrapMode: Text.WordWrap
            maximumLineCount: 4
          }

          // Under the last exchange: read the whole conversation, or take
          // this one back.
          RowLayout {
            Layout.fillWidth: true
            Layout.topMargin: Style.space(4)
            visible: mod.lastAsk.length > 0
            spacing: Style.space(6)

            Button {
              text: "Journal"
              bordered: true
              fontSize: Style.font.caption
              foreground: Color.popups.text
              tooltipText: "La conversation, et ce qui s'est passé dans sa tête"
              onClicked: mod.openJournal("today")
            }

            Button {
              text: "Oublier"
              bordered: true
              fontSize: Style.font.caption
              foreground: Color.popups.text
              tooltipText: "Effacer le dernier échange de sa mémoire"
              onClicked: mod.undo()
            }

            Item { Layout.fillWidth: true }
          }

          // The panel is WlrKeyboardFocus.OnDemand while open, so a click in
          // the field routes the keyboard here — nothing to add.
          TextField {
            Layout.fillWidth: true
            Layout.topMargin: Style.space(6)
            placeholderText: "Écris à Jarvis…"
            foreground: Color.popups.text
            font.pixelSize: Style.font.bodySmall
            onAccepted: {
              mod.sendText(text)
              clear()
            }
          }
        }
      }

      RowLayout {
        Layout.fillWidth: true
        spacing: Style.space(8)

        Button {
          Layout.fillWidth: true
          Layout.preferredWidth: 1
          text: "Rêver"
          bordered: true
          fontSize: Style.font.caption
          foreground: Color.popups.text
          enabled: mod.failures > 0
          tooltipText: "Consolider les échecs en leçons"
          onClicked: mod.dream()
        }

        Button {
          Layout.fillWidth: true
          Layout.preferredWidth: 1
          text: "Nouvelle conversation"
          bordered: true
          fontSize: Style.font.caption
          foreground: Color.popups.text
          onClicked: mod.reset()
        }
      }

      // ------------------------------------------------ what asks a decision
      PanelSectionHeader {
        visible: mod.suggestions.length > 0
        text: "Suggestions · " + mod.suggestions.length
        foreground: Color.popups.text
      }

      Repeater {
        model: mod.suggestions

        delegate: Rectangle {
          id: suggestion
          required property var modelData
          Layout.fillWidth: true
          radius: Math.min(Style.cornerRadius, Style.space(10))
          color: Style.normalFill
          implicitHeight: card.implicitHeight + Style.space(20)

          ColumnLayout {
            id: card
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: Style.space(10)
            spacing: Style.space(6)

            Text {
              text: suggestion.modelData.date
              color: Util.alpha(Color.popups.text, 0.55)
              font.family: Style.font.family
              font.pixelSize: Style.font.caption
            }

            Text {
              Layout.fillWidth: true
              text: suggestion.modelData.text
              color: Color.popups.text
              font.family: Style.font.family
              font.pixelSize: Style.font.caption
              wrapMode: Text.WordWrap
              maximumLineCount: 5
              elide: Text.ElideRight
            }

            RowLayout {
              Layout.fillWidth: true
              spacing: Style.space(6)

              Button {
                Layout.fillWidth: true
                Layout.preferredWidth: 1
                text: "Confier"
                bordered: true
                fontSize: Style.font.caption
                foreground: Color.popups.text
                tooltipText: "Lancer une mission de fond qui l'applique"
                onClicked: mod.decide(suggestion.modelData.n, "accept")
              }

              Button {
                Layout.fillWidth: true
                Layout.preferredWidth: 1
                text: "Rejeter"
                bordered: true
                fontSize: Style.font.caption
                foreground: Color.popups.text
                onClicked: mod.decide(suggestion.modelData.n, "reject")
              }
            }
          }
        }
      }

      // ------------------------------------------------ what is set once
      Disclosure {
        Layout.fillWidth: true
        title: "Âme"
        summary: mod.soulSummary()

        PillRow {
          Layout.fillWidth: true
          options: mod.toneOptions
          value: mod.tone
          foreground: Color.popups.text
          fontSize: Style.font.caption
          onChanged: function(v) { mod.setTone(v) }
        }

        RowLayout {
          Layout.fillWidth: true
          spacing: Style.space(8)

          Text {
            Layout.preferredWidth: Style.space(74)
            text: "Langue"
            color: Util.alpha(Color.popups.text, 0.55)
            font.family: Style.font.family
            font.pixelSize: Style.font.caption
          }

          PillRow {
            options: mod.langs
            value: mod.lang
            foreground: Color.popups.text
            fontSize: Style.font.caption
            onChanged: function(v) { mod.setLang(v) }
          }
        }

        RowLayout {
          Layout.fillWidth: true
          spacing: Style.space(8)

          Text {
            Layout.preferredWidth: Style.space(74)
            text: "Micro coupé"
            color: Util.alpha(Color.popups.text, 0.55)
            font.family: Style.font.family
            font.pixelSize: Style.font.caption
          }

          PillRow {
            options: mod.muteModes
            value: mod.muteMode
            foreground: Color.popups.text
            fontSize: Style.font.caption
            onChanged: function(v) { mod.setMuteMode(v) }
          }
        }

        Toggle {
          Layout.fillWidth: true
          label: "Humour"
          checked: mod.humor
          foreground: Color.popups.text
          onClicked: mod.toggleHumor()
        }

        Toggle {
          Layout.fillWidth: true
          label: "« Hey Jarvis » (wake word)"
          checked: mod.wake
          foreground: Color.popups.text
          onClicked: mod.toggleWake()
        }

        Toggle {
          Layout.fillWidth: true
          label: "Vouvoiement (« Monsieur »)"
          checked: mod.vous
          foreground: Color.popups.text
          onClicked: mod.toggleVous()
        }

        Button {
          Layout.fillWidth: true
          text: "Éditer l'âme (SOUL.md)"
          bordered: true
          fontSize: Style.font.caption
          foreground: Color.popups.text
          onClicked: mod.edit(mod.soulPath)
        }
      }

      Disclosure {
        Layout.fillWidth: true
        title: "Automatismes"
        summary: mod.autoSummary()

        Toggle {
          Layout.fillWidth: true
          label: "Rondes"
          description: mod.roundsText()
          checked: mod.rondes
          foreground: Color.popups.text
          onClicked: mod.toggleRondes()
        }

        Toggle {
          Layout.fillWidth: true
          label: "Rêves automatiques"
          description: mod.reves ? "Consolide sa mémoire quand il s'ennuie" : "Seulement sur « Rêver »"
          checked: mod.reves
          foreground: Color.popups.text
          onClicked: mod.toggleReves()
        }

        Toggle {
          Layout.fillWidth: true
          label: "Silence " + mod.silenceText()
          description: mod.quiet
            ? "En cours — il ne parle que si on lui parle"
            : "Ni rondes, ni rêves, ni parole spontanée la nuit"
          checked: mod.silence !== "non"
          foreground: Color.popups.text
          onClicked: mod.toggleSilence()
        }

        // The routines are edited in the Journal, on his paper: this row
        // only says how many are armed and takes you there.
        Rectangle {
          Layout.fillWidth: true
          implicitHeight: Style.space(38)
          radius: Math.min(Style.cornerRadius, Style.space(10))
          color: routinesHover.hovered ? Style.hoverFill : Style.normalFill

          HoverHandler { id: routinesHover }

          MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: mod.openJournal("routines")
          }

          RowLayout {
            anchors.fill: parent
            anchors.leftMargin: Style.space(10)
            anchors.rightMargin: Style.space(10)
            spacing: Style.space(8)

            Text {
              text: "Routines"
              color: Color.popups.text
              font.family: Style.font.family
              font.pixelSize: Style.font.bodySmall
              font.bold: true
            }

            Item { Layout.fillWidth: true }

            Text {
              text: mod.routines === 0 ? "aucune" : mod.routines + " active" + (mod.routines > 1 ? "s" : "")
              color: Util.alpha(Color.popups.text, 0.55)
              font.family: Style.font.family
              font.pixelSize: Style.font.caption
            }

            Text {
              text: "󰅂"
              color: Util.alpha(Color.popups.text, 0.55)
              font.family: Style.font.family
              font.pixelSize: Style.font.iconSmall
            }
          }
        }
      }

      Disclosure {
        Layout.fillWidth: true
        title: "Apparence"
        summary: mod.lookLabel("corps") + " · " + mod.couleur

        Repeater {
          model: mod.lookAxes

          delegate: RowLayout {
            id: axis
            required property var modelData
            Layout.fillWidth: true
            spacing: Style.space(8)

            Text {
              Layout.preferredWidth: Style.space(74)
              text: axis.modelData.label
              color: Util.alpha(Color.popups.text, 0.55)
              font.family: Style.font.family
              font.pixelSize: Style.font.caption
            }

            PillRow {
              options: axis.modelData.options
              value: mod.lookValue(axis.modelData.key)
              foreground: Color.popups.text
              fontSize: Style.font.caption
              onChanged: function(v) { mod.setLook(axis.modelData.key, v) }
            }
          }
        }

        RowLayout {
          Layout.fillWidth: true
          spacing: Style.space(6)

          Text {
            Layout.preferredWidth: Style.space(74)
            text: "Couleur"
            color: Util.alpha(Color.popups.text, 0.55)
            font.family: Style.font.family
            font.pixelSize: Style.font.caption
          }

          Repeater {
            model: mod.couleurs

            delegate: Rectangle {
              id: swatch
              required property var modelData
              Layout.fillWidth: true
              Layout.preferredHeight: Style.space(22)
              radius: Style.space(4)
              color: swatch.modelData[1]
              border.width: mod.couleur === swatch.modelData[0] ? 2 : 0
              border.color: Color.popups.text

              MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: mod.setLook("couleur", swatch.modelData[0])
              }
            }
          }
        }

        Button {
          Layout.fillWidth: true
          text: "Au hasard"
          bordered: true
          fontSize: Style.font.caption
          foreground: Color.popups.text
          onClicked: mod.randomLook()
        }
      }

      Disclosure {
        Layout.fillWidth: true
        title: "Mémoire"
        summary: mod.lessons + " leçon" + (mod.lessons > 1 ? "s" : "")

        Text {
          Layout.fillWidth: true
          text: mod.failures + " échec" + (mod.failures > 1 ? "s" : "") + " en attente · "
            + mod.lessons + " leçon" + (mod.lessons > 1 ? "s" : "") + " apprise" + (mod.lessons > 1 ? "s" : "")
            + (mod.suggestionCount > 0 ? " · " + mod.suggestionCount + " suggestion" + (mod.suggestionCount > 1 ? "s" : "") : "")
          color: Util.alpha(Color.popups.text, 0.55)
          font.family: Style.font.family
          font.pixelSize: Style.font.caption
          wrapMode: Text.WordWrap
        }

        RowLayout {
          Layout.fillWidth: true
          spacing: Style.space(6)

          Button {
            Layout.fillWidth: true
            Layout.preferredWidth: 1
            text: "Échecs"
            bordered: true
            fontSize: Style.font.caption
            foreground: Color.popups.text
            onClicked: mod.edit(mod.memoryDir + "FAILURES.md")
          }

          Button {
            Layout.fillWidth: true
            Layout.preferredWidth: 1
            text: "Leçons"
            bordered: true
            fontSize: Style.font.caption
            foreground: Color.popups.text
            onClicked: mod.edit(mod.memoryDir + "LEARNED.md")
          }

          Button {
            Layout.fillWidth: true
            Layout.preferredWidth: 1
            text: "Boîte noire"
            bordered: true
            fontSize: Style.font.caption
            foreground: Color.popups.text
            tooltipText: "Chaque commande exécutée aujourd'hui"
            // Local date, not toISOString: UTC opens yesterday's trace until
            // 2 a.m. in Brussels.
            onClicked: {
              var d = new Date()
              var day = d.getFullYear() + "-"
                + String(d.getMonth() + 1).padStart(2, "0") + "-"
                + String(d.getDate()).padStart(2, "0")
              mod.edit(mod.memoryDir + "trace/" + day + ".log")
            }
          }
        }
      }
    }
  }
}
