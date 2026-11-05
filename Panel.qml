import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Commons as Commons
import qs.Ui
import "Model.js" as Model

// Pomodoro bar widget: a countdown ring and the remaining time in the bar,
// with a full focus panel in the popup — gradient hero, one primary action,
// the block lengths and the behaviour switches.
//
// The timer is not here: it lives in Service.qml, mounted once per shell, so
// each monitor's bar surface reads the same countdown instead of running its
// own copy.
Panel {
  id: root
  moduleName: "honor.pomodoro"
  ipcTarget: "honor.pomodoro"
  // manageIpc: false so this widget can own the single IpcHandler for the
  // target and expose timer verbs beside open/close/toggle.
  manageIpc: false

  Commons.Translations {
    id: strings
    directory: Qt.resolvedUrl("i18n")
  }

  // Caveat ships with the plugin: the shell has no handwriting face, and the
  // "Focus Mode ON" line is the one hand-made mark in an otherwise geometric
  // panel.
  FontLoader {
    id: handFont
    source: "fonts/Caveat.ttf"
  }

  // The bar surface injects the facade; serviceFor() is scoped to this plugin,
  // so this is the one shared timer instance. The service is created by the
  // shell's service loader, which can land after this widget, so the lookup is
  // retried until it does instead of being a one-shot binding.
  property var service: null

  function bindService() {
    if (root.service || !bar || !bar.shell || typeof bar.shell.serviceFor !== "function") return
    var candidate = bar.shell.serviceFor(root.moduleName)
    if (!candidate) return
    root.service = candidate
    candidate.applySettings(root.settings)
  }

  onBarChanged: Qt.callLater(root.bindService)
  Component.onCompleted: Qt.callLater(root.bindService)

  // A panel re-opened after being scrolled (or after the content grew when a
  // setting changed) otherwise starts mid-list, with the hero cut off above.
  onOpenedChanged: if (opened) flick.contentY = 0

  readonly property bool vertical: bar ? bar.vertical : false
  readonly property color foreground: bar ? bar.barForeground : Commons.Color.foreground
  readonly property color urgent: bar ? bar.urgent : Commons.Color.urgent
  readonly property color accent: Commons.Color.accent
  readonly property string fontFamily: bar ? bar.fontFamily : Style.font.family
  readonly property color popupText: Commons.Color.popups.text
  // The canvas the mark is drawn on, for the state glyph's cut-out.
  readonly property color barBackground: bar ? bar.background : Commons.Color.bar.background

  // ---- panel design tokens ------------------------------------------------
  // The panel has its own type and colour scale. The shell's `caption` is
  // 10 px on a dark card, which this user rejects as unreadable; everything
  // read here is 11 px or larger, and captions keep a 0.55–0.72 tint of the
  // ink rather than a darker colour.
  readonly property real uiScale: Style.fontScale
  function px(n) { return Math.max(1, Math.round(n * uiScale)) }

  readonly property int sizeCaption: Style.font.body          // 12
  readonly property int sizeBody: Style.font.subtitle         // 13
  readonly property color ink: "#F3F7FF"
  readonly property color dimInk: Qt.rgba(0.85, 0.90, 0.98, 0.62)
  readonly property color violet: "#8A6BFF"
  readonly property color blue: "#3D7DFF"
  readonly property string displayFamily: "Inter Display"
  readonly property string bodyFamily: "Inter"
  readonly property string glyphFamily: "JetBrainsMono Nerd Font"
  readonly property string handFamily: handFont.name !== "" ? handFont.name : root.bodyFamily
  readonly property int pad: root.px(17)

  // ---- timer view --------------------------------------------------------
  readonly property string phase: service ? service.phase : "focus"
  readonly property bool running: service ? service.running : false
  readonly property bool started: service ? service.started : false
  readonly property bool paused: service ? service.paused : false
  readonly property real remainingMs: service ? service.remainingMs : 25 * 60000
  readonly property real fraction: service ? service.fraction : 1
  readonly property int completedToday: service ? service.completedToday : 0
  readonly property int cycleCount: service ? service.cycleCount : 0
  readonly property int longEvery: service ? service.longEvery : 4

  readonly property bool urgentNow: running && phase === "focus" && remainingMs <= 60000

  // The bar mark wears the panel's violet rather than the theme accent: the
  // widget should be recognisable from the bar alone. Alarms keep the theme's
  // urgent colour, because "the block is ending" must not read as decoration.
  readonly property color barColor: {
    if (root.urgentNow) return root.urgent
    if (root.phase !== "focus") return "#B49BFF"
    return root.violet
  }

  readonly property string markState: !started ? "idle" : (paused ? "paused" : "running")

  // One beat in the bar when a phase ends: the mark steps out and settles.
  // Driven by the phase change itself, so it also fires for a block that
  // finished while the panel was closed.
  property real phasePulse: 0
  onPhaseChanged: phasePulseAnim.restart()
  SequentialAnimation {
    id: phasePulseAnim
    NumberAnimation {
      target: root; property: "phasePulse"; to: 1.0
      duration: 110; easing.type: Easing.OutBack; easing.overshoot: 2.4
    }
    NumberAnimation {
      target: root; property: "phasePulse"; to: 0.0
      duration: 420; easing.type: Easing.OutCubic
    }
  }

  function pad2(value) {
    var number = Math.max(0, Math.round(value))
    var text = Commons.I18n.formatNumber(number)
    return number < 10 ? Commons.I18n.zeroDigit + text : text
  }

  // Countdown as the language writes it: localized digits, and hours only
  // when the block actually has them (a 90-minute focus block).
  readonly property string clockText: {
    var parts = Model.clockParts(root.remainingMs)
    if (parts.h > 0) return pad2(parts.h) + ":" + pad2(parts.m) + ":" + pad2(parts.s)
    return pad2(parts.m) + ":" + pad2(parts.s)
  }

  // The same clock as a vertical stack: hours only take a line of their own
  // when the block has them.
  readonly property var verticalLines: {
    var parts = Model.clockParts(root.remainingMs)
    return parts.h > 0
      ? [pad2(parts.h), pad2(parts.m), pad2(parts.s)]
      : [pad2(parts.m), pad2(parts.s)]
  }

  readonly property string phaseTitle: {
    if (root.phase === "shortBreak") return strings.t("phase.shortBreak", "Short break")
    if (root.phase === "longBreak") return strings.t("phase.longBreak", "Long break")
    return strings.t("phase.focus", "Focus")
  }

  // Uppercase form for badges.
  readonly property string phaseKicker: root.phaseTitle.toUpperCase()
  // A break is a different mode, not a different colour of the same mood:
  // it gets its own badge, its own tint and its own dial gradient, so a glance
  // at the header or the ring says which mode is running.
  readonly property bool onBreak: root.phase !== "focus"
  readonly property color phaseTint: root.onBreak ? "#6FA8FF" : "#A78BFF"
  readonly property string handNote: {
    if (root.phase === "shortBreak") return strings.t("panel.handnoteBreak", "Break time")
    if (root.phase === "longBreak") return strings.t("panel.handnoteLongBreak", "Long break")
    return strings.t("panel.handnote", "Focus Mode ON")
  }
  readonly property string phaseBadge: {
    if (root.phase === "shortBreak") return strings.t("phase.shortBreakBadge", "ПЕРЕРЫВ")
    if (root.phase === "longBreak") return strings.t("phase.longBreakBadge", "ДЛИННЫЙ ПЕРЕРЫВ")
    return strings.t("phase.focusBadge", "ФОКУС")
  }

  readonly property string tooltipText: {
    if (!root.service) return strings.t("tooltip.idle", "Pomodoro")
    if (root.running) {
      return strings.t(root.phase === "focus" ? "tooltip.focus" : "tooltip.break", "%1 · %2 left")
        .arg(root.phaseTitle).arg(root.clockText)
    }
    if (root.paused) {
      return strings.t("tooltip.paused", "Paused · %1 left").arg(root.clockText)
    }
    return strings.t("tooltip.idle", "Pomodoro · click for the timer")
  }

  readonly property string stateWord: {
    if (root.running) return strings.t("status.live", "LIVE")
    if (root.paused) return strings.t("status.paused", "PAUSED")
    return strings.t("status.ready", "READY")
  }

  // "2 of 4 · 3 focus blocks today" — the cycle position and the day's total
  // are two facts, so they are two clauses separated by a dot rather than one
  // number standing for both.
  readonly property string cycleLine: {
    var position = strings.t("panel.cycle", "%1 of %2")
      .arg(Commons.I18n.formatNumber(root.cycleCount + 1))
      .arg(Commons.I18n.formatNumber(root.longEvery))
    var today = strings.tn("panel.today", root.completedToday)
      .arg(Commons.I18n.formatNumber(root.completedToday))
    return position + "  ·  " + today
  }

  // ---- settings ----------------------------------------------------------
  function setting(name, fallback) {
    var value = settings ? settings[name] : undefined
    return value === undefined || value === null ? fallback : value
  }

  readonly property int focusMinutes: Model.focusMinutes(settings)
  readonly property int shortBreakMinutes: Model.shortBreakMinutes(settings)
  readonly property int longBreakMinutes: Model.longBreakMinutes(settings)
  readonly property int longBreakEvery: Model.longBreakEvery(settings)
  readonly property bool autoStart: Model.boolValue(setting("autoStart", true), true)
  readonly property bool soundOn: Model.boolValue(setting("sound", true), true)
  readonly property bool notifyOn: Model.boolValue(setting("notify", true), true)
  readonly property bool stayAwakeOn: Model.boolValue(setting("stayAwake", true), true)

  // Applied locally first so the panel redraws on the click itself; the
  // shell.json write comes back through the bar as the same value.
  function persistSettings(values) {
    var entry = { id: root.moduleName }
    for (var existing in root.settings) if (existing !== "id") entry[existing] = root.settings[existing]
    for (var key in values) entry[key] = values[key]

    root.settings = entry
    if (root.service) root.service.applySettings(entry)
    if (root.bar && root.bar.shell && typeof root.bar.shell.updateEntryInline === "function")
      root.bar.shell.updateEntryInline(root.moduleName, entry)
  }

  function syncService() {
    if (root.service) root.service.applySettings(root.settings)
  }
  onServiceChanged: syncService()
  onSettingsChanged: syncService()

  // ---- timer verbs (also reached over IPC) -------------------------------
  function toggleTimer() { if (root.service) root.service.toggleTimer() }
  function startTimer() { if (root.service) root.service.start() }
  function pauseTimer() { if (root.service) root.service.pause() }
  function skipPhase() { if (root.service) root.service.skip() }
  function resetTimer() { if (root.service) root.service.reset() }
  function addFive() { if (root.service) root.service.adjustMinutes(5) }
  function finishPhase() { if (root.service) root.service.finishPhase(true) }

  // A widget that mounts before the service is created (bar reload during a
  // plugin rescan) would otherwise sit on a dead reference for the session.
  Timer {
    interval: 250
    repeat: true
    running: root.service === null
    onTriggered: root.bindService()
  }

  // ---- bar geometry ------------------------------------------------------
  // An untouched widget takes one icon slot; the countdown adds its own width
  // only while there is something to count. A vertical bar has no room beside
  // the icon, so the clock stacks under it instead.
  implicitWidth: vertical ? button.implicitWidth : button.implicitWidth + (timeLabel.visible ? Style.space(3) + timeLabel.implicitWidth : 0)
  implicitHeight: vertical
    ? button.implicitHeight + (verticalTime.visible ? verticalTime.implicitHeight : 0)
    : button.implicitHeight

  readonly property real openPanelIndicatorWidth: root.implicitWidth

  // ---- IPC ---------------------------------------------------------------
  IpcHandler {
    target: root.ipcTarget

    function open(): void { root.open() }
    function close(): void { root.close() }
    function show(): void { root.open() }
    function hide(): void { root.close() }
    function toggle(): void { root.toggleTimer() }
    function start(): void { root.startTimer() }
    function pause(): void { root.pauseTimer() }
    function skip(): void { root.skipPhase() }
    function reset(): void { root.resetTimer() }
    function add(): void { root.addFive() }
    // `complete` is taken by IpcHandler's own PostReloadHook method, so the
    // "finish this phase now" verb ships under a name of its own.
    function finish(): void { root.finishPhase() }
    function remaining(): string { return root.clockText }
    // A marker bumped on every edit: an old answer means a stale compiled
    // unit, not a stale file.
    function build(): string { return "focus-panel-1" }
    function status(): string {
      if (!root.service) return "unavailable"
      return root.phase + ":" + (root.running ? "running" : (root.paused ? "paused" : "idle"))
        + ":" + root.clockText + ":" + root.completedToday
    }
    // Layout audit: a countdown that fits while idle but spills at 99:59 is
    // only caught by asking the live tree.
    // Where the card actually lands on screen, so a capture can crop it
    // without guessing from the wallpaper.
    function debugRect(): string {
      var point = flick.mapToItem(null, 0, 0)
      return JSON.stringify({ x: Math.round(point.x), y: Math.round(point.y),
                              w: Math.round(flick.width), h: Math.round(flick.height) })
    }
    function debugLayout(): string {
      var out = { w: panel.contentWidth, h: panel.contentHeight, column: column.implicitHeight,
                  colH: column.height, contentH: flick.contentHeight, pulse: Math.round(root.phasePulse * 100) / 100, badgeWidth: Math.round(phaseLabel.contentWidth), badgeSize: Math.round(phaseLabel.font.pixelSize), ticksFresh: arc.tickAlpha(0), ticksSpent: arc.tickAlpha(30), kicks: arc.kicks, kick: Math.round(arc.kick * 100) / 100, tickShift: Math.round(arc.scaleKick * 10) / 10,
                  flick: flick.height, scroll: flick.contentHeight > flick.height + 1,
                  clips: [], overflows: [] }
      function walk(item) {
        var kids = item.children
        for (var i = 0; i < kids.length; i++) {
          var child = kids[i]
          if (!child) continue
          if (child.text !== undefined && child.height + 0.5 < child.implicitHeight)
            out.clips.push(String(child.objectName || child.text).slice(0, 30))
          if (child.x + child.width > flick.width + 1 && child.visible)
            out.overflows.push(String(child.objectName || "item") + ":" + Math.round(child.x + child.width))
          walk(child)
        }
      }
      walk(column)
      return JSON.stringify(out)
    }
  }

  BarIconButton {
    id: button
    anchors.left: root.vertical ? undefined : parent.left
    anchors.horizontalCenter: root.vertical ? parent.horizontalCenter : undefined
    anchors.verticalCenter: parent.verticalCenter
    bar: root.bar
    text: ""
    foreground: root.barColor
    active: root.urgentNow || root.phase !== "focus"
    activeColor: root.barColor
    tooltipText: root.tooltipText

    iconComponent: Component {
      ProgressMark {
        anchors.centerIn: parent
        fraction: root.fraction
        mark: root.markState
        color: root.barColor
        pulse: root.phasePulse
        thickness: 1.6
      }
    }

    onPressed: function(code) {
      if (code === Qt.LeftButton) root.toggle()
      else if (code === Qt.RightButton) root.toggleTimer()
      else if (code === Qt.MiddleButton) root.skipPhase()
    }
  }

  // Remaining time, in the shell's own family so the digits do not jitter as
  // they change.
  Text {
    id: timeLabel
    visible: root.started && !root.vertical
    anchors.left: button.right
    anchors.leftMargin: Style.space(3)
    anchors.verticalCenter: parent.verticalCenter
    textFormat: Text.PlainText
    text: root.clockText
    color: root.barColor
    opacity: root.paused ? 0.65 : 1.0
    font.family: root.fontFamily
    font.pixelSize: Style.font.body
    renderType: Text.NativeRendering
    Behavior on opacity {
      enabled: !root.bar || root.bar.foregroundAnimationEnabled
      NumberAnimation { duration: Style.duration(160); easing.type: Easing.OutCubic }
    }
  }

  // Vertical bar: "MM:SS" has no room beside the icon, so it stacks under it,
  // one line per part, at a size that fits the 28px width.
  Column {
    id: verticalTime
    visible: root.vertical && root.started
    anchors.horizontalCenter: parent.horizontalCenter
    anchors.top: button.bottom
    spacing: 0

    Repeater {
      model: root.verticalLines

      Text {
        required property string modelData
        textFormat: Text.PlainText
        width: button.width
        text: modelData
        color: root.barColor
        opacity: root.paused ? 0.65 : 1.0
        horizontalAlignment: Text.AlignHCenter
        font.family: root.fontFamily
        font.pixelSize: Style.font.bodySmall
        renderType: Text.NativeRendering
      }
    }
  }

  // ---- popup -------------------------------------------------------------
  KeyboardPanel {
    id: panel
    anchorItem: button
    owner: root
    bar: root.bar
    open: root.opened
    focusTarget: keyCatcher
    // The gradient has to reach the card's edge, so the card's own padding is
    // handed to the panel content and drawn there instead.
    padding: 0
    contentWidth: panel.fittedContentWidth(Style.space(460))
    contentHeight: panel.fittedContentHeight(column.implicitHeight + root.pad * 2 + root.px(9), Style.space(950))

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      onActivateRequested: root.toggleTimer()
      onCloseRequested: root.close()
      onTabRequested: function(direction) { root.switchPanel(direction) }
      onTextKey: function(t) {
        var key = String(t).toLowerCase()
        if (key === "s") root.skipPhase()
        else if (key === "r") root.resetTimer()
      }

      // Full-bleed night-blue face with a violet bloom at the top, so the
      // card reads as one lit surface rather than a list on a flat fill.
      Rectangle {
        anchors.fill: parent
        radius: Style.cornerRadius
        gradient: Gradient {
          GradientStop { position: 0.0; color: "#161C3A" }
          GradientStop { position: 0.45; color: "#0D1226" }
          GradientStop { position: 1.0; color: "#080B18" }
        }
      }

      Rectangle {
        anchors.fill: parent
        radius: Style.cornerRadius
        gradient: Gradient {
          GradientStop { position: 0.0; color: Qt.rgba(0.42, 0.30, 0.92, 0.30) }
          GradientStop { position: 0.55; color: Qt.rgba(0.25, 0.20, 0.60, 0.08) }
          GradientStop { position: 1.0; color: Qt.rgba(0.10, 0.12, 0.35, 0.0) }
        }
      }

      Flickable {
        id: flick
        anchors.fill: parent
        contentWidth: width
        contentHeight: column.implicitHeight + root.pad * 2
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        interactive: contentHeight > height + 1

        Column {
          id: column
          x: root.pad
          y: root.pad
          width: flick.width - root.pad * 2
          spacing: root.px(10)

          // ---- Header: the mark, the name, the handwritten note, the state.
          Item {
            width: parent.width
            height: root.px(46)

            LogoMark {
              id: logo
              anchors.left: parent.left
              anchors.verticalCenter: parent.verticalCenter
              width: root.px(40)
              height: width
              glyphFamily: root.glyphFamily
            }

            Text {
              id: title
              objectName: "title"
              anchors.left: logo.right
              anchors.leftMargin: root.px(11)
              anchors.top: logo.top
              anchors.topMargin: root.px(4)
              textFormat: Text.PlainText
              text: "Focus"
              color: root.ink
              font.family: root.displayFamily
              font.pixelSize: root.px(22)
              font.weight: Font.DemiBold
              font.letterSpacing: 0.2
            }

            Text {
              id: hand
              objectName: "hand"
              anchors.left: title.right
              anchors.leftMargin: root.px(12)
              anchors.right: phasePill.left
              anchors.rightMargin: root.px(10)
              anchors.verticalCenter: title.verticalCenter
              anchors.verticalCenterOffset: root.px(2)
              textFormat: Text.PlainText
              text: root.handNote
              elide: Text.ElideRight
              color: root.onBreak ? "#A9C8FF" : "#C0A8FF"
              font.family: root.handFamily
              font.pixelSize: root.px(21)
              rotation: -4
              transformOrigin: Item.Left
            }

            Rectangle {
              id: phasePill
              anchors.right: parent.right
              anchors.verticalCenter: parent.verticalCenter
              width: pillRow.implicitWidth + root.px(18)
              height: root.px(26)
              radius: height / 2
              color: root.onBreak ? Qt.rgba(0.36, 0.55, 1.0, 0.12) : Qt.rgba(0.58, 0.44, 1.0, 0.12)
              border.width: 1
              border.color: root.onBreak ? Qt.rgba(0.45, 0.66, 1.0, 0.38) : Qt.rgba(0.66, 0.52, 1.0, 0.38)

              Row {
                id: pillRow
                anchors.centerIn: parent
                spacing: root.px(7)

                Rectangle {
                  anchors.verticalCenter: parent.verticalCenter
                  width: root.px(7)
                  height: width
                  radius: width / 2
                  // Filled and bright while the clock runs, dim when it waits.
                  color: root.phaseTint
                  opacity: root.running ? 1.0 : (root.paused ? 0.55 : 0.30)
                  Behavior on opacity { NumberAnimation { duration: 180 } }
                }

                Text {
                  id: phaseLabel
                  anchors.verticalCenter: parent.verticalCenter
                  textFormat: Text.PlainText
                  text: root.phaseBadge
                  color: root.onBreak ? "#DCE9FF" : "#EAE2FF"
                  font.family: root.bodyFamily
                  font.pixelSize: root.px(10)
                  font.weight: Font.DemiBold
                  font.letterSpacing: root.px(1.2)
                }
              }
            }

          }

          // ---- Hero: the countdown inside its own dial. The ring is the
          //      progress read-out, so there is no second bar repeating it.
          Rectangle {
            id: hero
            width: parent.width
            height: ringBox.height + caption.implicitHeight + root.px(34)
            radius: root.px(20)
            border.width: 1
            border.color: root.onBreak
              ? Qt.rgba(0.42, 0.62, 1.0, 0.30)
              : Qt.rgba(0.62, 0.52, 1.0, 0.22)
            gradient: Gradient {
              GradientStop { position: 0.0; color: root.onBreak ? "#1F2E72" : "#2E2270" }
              GradientStop { position: 0.55; color: root.onBreak ? "#1A2450" : "#1D2252" }
              GradientStop { position: 1.0; color: root.onBreak ? "#152039" : "#161A3C" }
            }

            // A soft top light on the hero face, so the card is lit from
            // above like the tile in the header.
            Rectangle {
              anchors.fill: parent
              radius: hero.radius
              gradient: Gradient {
                GradientStop { position: 0.0; color: Qt.rgba(1, 1, 1, 0.10) }
                GradientStop { position: 0.5; color: Qt.rgba(1, 1, 1, 0.0) }
              }
            }

            Item {
              id: ringBox
              objectName: "ringBox"
              width: root.px(200)
              height: width
              anchors.horizontalCenter: parent.horizontalCenter
              anchors.top: parent.top
              anchors.topMargin: root.px(12)

              ProgressRing {
                id: arc
                anchors.fill: parent
                fraction: root.fraction
                paused: root.paused
                running: root.running
                thickness: 7
                tintFrom: root.onBreak ? "#7FB0FF" : "#A78BFF"
                tintTo: root.onBreak ? "#2F7BE8" : "#4A86FF"
              }

              // The dial holds one figure only, centred on its own axis.
              Text {
                id: clock
                objectName: "timer"
                anchors.centerIn: parent
                horizontalAlignment: Text.AlignHCenter
                textFormat: Text.PlainText
                text: root.started
                  ? root.clockText
                  : Commons.I18n.formatNumber(root.focusMinutes) + ":" + Commons.I18n.zeroDigit + Commons.I18n.zeroDigit
                color: root.paused ? Qt.rgba(0.95, 0.96, 1.0, 0.78) : "#FFFFFF"
                font.family: root.displayFamily
                font.pixelSize: root.px(46)
                font.weight: Font.Bold
                font.letterSpacing: root.px(1)
              }
            }

            Text {
              id: caption
              objectName: "cycle"
              anchors.top: ringBox.bottom
              anchors.topMargin: root.px(12)
              anchors.horizontalCenter: parent.horizontalCenter
              width: parent.width - root.px(24)
              horizontalAlignment: Text.AlignHCenter
              textFormat: Text.PlainText
              text: root.cycleLine
              color: Qt.rgba(0.88, 0.91, 1.0, 0.72)
              elide: Text.ElideRight
              font.family: root.bodyFamily
              font.pixelSize: root.px(13)
            }
          }

          // ---- The one primary action.
          GradientButton {
            width: parent.width
            height: root.px(54)
            running: root.running
            glyph: root.running ? "\uf04c" : "\uf04b"   // nf-fa-pause / nf-fa-play
            // In a break the same verb would read as "pause the break?" — name
            // the thing being paused.
            label: root.running
              ? (root.onBreak
                  ? strings.t("action.pauseBreak", "Pause break")
                  : strings.t("action.pause", "Pause"))
              : (root.paused
                  ? (root.onBreak
                      ? strings.t("action.resumeBreak", "Resume break")
                      : strings.t("action.resume", "Resume"))
                  : (root.onBreak
                      ? strings.t("action.startBreak", "Start break")
                      : strings.t("action.start", "Start")))
            ink: "#FFFFFF"
            fontFamily: root.displayFamily
            glyphFamily: root.glyphFamily
            onClicked: root.toggleTimer()
          }

          // ---- The three small verbs.
          Row {
            width: parent.width
            spacing: root.px(8)

            SoftButton {
              width: Math.round((parent.width - parent.spacing * 2) / 3)
              height: root.px(40)
              glyph: "\uf051"   // nf-fa-step-forward
              label: strings.t("action.skip", "Skip phase")
              fontFamily: root.bodyFamily
              glyphFamily: root.glyphFamily
              ink: "#E3EAF8"
              onClicked: root.skipPhase()
            }

            SoftButton {
              width: Math.round((parent.width - parent.spacing * 2) / 3)
              height: root.px(40)
              glyph: "\uf017"   // nf-fa-clock-o
              label: strings.t("action.addFive", "+5 min")
              fontFamily: root.bodyFamily
              glyphFamily: root.glyphFamily
              ink: "#E3EAF8"
              onClicked: root.addFive()
            }

            SoftButton {
              width: parent.width - parent.spacing * 2 - Math.round((parent.width - parent.spacing * 2) / 3) * 2
              height: root.px(40)
              glyph: "\uf021"   // nf-fa-refresh
              label: strings.t("action.reset", "Reset")
              fontFamily: root.bodyFamily
              glyphFamily: root.glyphFamily
              ink: "#E3EAF8"
              onClicked: root.resetTimer()
            }
          }

          SectionLabel {
            width: parent.width
            ink: root.ink
            fontFamily: root.bodyFamily
            text: strings.t("section.lengths", "LENGTHS")
          }

          Rectangle {
            width: parent.width
            height: lengthsColumn.implicitHeight + root.px(12)
            radius: root.px(16)
            border.width: 1
            border.color: Qt.rgba(1, 1, 1, 0.10)
            gradient: Gradient {
              GradientStop { position: 0.0; color: Qt.rgba(1, 1, 1, 0.105) }
              GradientStop { position: 0.26; color: Qt.rgba(1, 1, 1, 0.045) }
              GradientStop { position: 1.0; color: Qt.rgba(1, 1, 1, 0.015) }
            }

            // A tint of the panel's violet in the top corner and a specular
            // along the top edge: enough to read as a glass slab over the
            // backdrop, cheap enough to keep the rows' contrast.
            Rectangle {
              anchors.fill: parent
              radius: parent.radius
              gradient: Gradient {
                GradientStop { position: 0.0; color: Qt.rgba(0.45, 0.35, 1.0, 0.14) }
                GradientStop { position: 0.45; color: Qt.rgba(0.35, 0.30, 0.85, 0.03) }
                GradientStop { position: 1.0; color: Qt.rgba(0.20, 0.20, 0.55, 0.0) }
              }
            }


            Rectangle {
              anchors.fill: parent
              radius: parent.radius
              gradient: Gradient {
                GradientStop { position: 0.0; color: Qt.rgba(1, 1, 1, 0.07) }
                GradientStop { position: 0.35; color: Qt.rgba(1, 1, 1, 0.0) }
              }
            }
            Rectangle {
              anchors.left: parent.left
              anchors.right: parent.right
              anchors.top: parent.top
              anchors.margins: root.px(4)
              height: root.px(1.6)
              radius: height / 2
              color: Qt.rgba(1, 1, 1, 0.32)
            }


            // The far edge is in shade: a sliver of black along the bottom is
            // what gives the slab its thickness.
            Rectangle {
              anchors.fill: parent
              radius: parent.radius
              gradient: Gradient {
                GradientStop { position: 0.78; color: Qt.rgba(0, 0, 0, 0.0) }
                GradientStop { position: 1.0; color: Qt.rgba(0, 0, 0, 0.16) }
              }
            }

            Column {
              id: lengthsColumn
              x: root.px(14)
              y: root.px(6)
              width: parent.width - root.px(28)

              LengthRow {
                width: parent.width
                label: strings.t("setting.focus", "Focus")
                value: root.focusMinutes
                from: 1
                to: 180
                stepSize: 5
                suffix: strings.t("unit.min", "min")
                ink: root.ink
                fontFamily: root.bodyFamily
                onChanged: function(v) { root.persistSettings({ focusMinutes: v }) }
              }

              Rectangle { width: parent.width; height: 1; color: Qt.rgba(1, 1, 1, 0.06) }

              LengthRow {
                width: parent.width
                label: strings.t("setting.shortBreak", "Short break")
                value: root.shortBreakMinutes
                from: 1
                to: 60
                stepSize: 1
                suffix: strings.t("unit.min", "min")
                ink: root.ink
                fontFamily: root.bodyFamily
                onChanged: function(v) { root.persistSettings({ shortBreakMinutes: v }) }
              }

              Rectangle { width: parent.width; height: 1; color: Qt.rgba(1, 1, 1, 0.06) }

              LengthRow {
                width: parent.width
                label: strings.t("setting.longBreak", "Long break")
                value: root.longBreakMinutes
                from: 1
                to: 120
                stepSize: 5
                suffix: strings.t("unit.min", "min")
                ink: root.ink
                fontFamily: root.bodyFamily
                onChanged: function(v) { root.persistSettings({ longBreakMinutes: v }) }
              }

              Rectangle { width: parent.width; height: 1; color: Qt.rgba(1, 1, 1, 0.06) }

              LengthRow {
                width: parent.width
                label: strings.t("setting.longEvery", "Long break every")
                value: root.longBreakEvery
                from: 2
                to: 12
                stepSize: 1
                suffix: strings.tn("unit.blocks", root.longBreakEvery)
                ink: root.ink
                fontFamily: root.bodyFamily
                onChanged: function(v) { root.persistSettings({ longBreakEvery: v }) }
              }
            }
          }

          SectionLabel {
            width: parent.width
            ink: root.ink
            fontFamily: root.bodyFamily
            text: strings.t("section.behavior", "BEHAVIOR")
          }

          Rectangle {
            width: parent.width
            height: behaviorColumn.implicitHeight + root.px(10)
            radius: root.px(16)
            border.width: 1
            border.color: Qt.rgba(1, 1, 1, 0.10)
            gradient: Gradient {
              GradientStop { position: 0.0; color: Qt.rgba(1, 1, 1, 0.105) }
              GradientStop { position: 0.26; color: Qt.rgba(1, 1, 1, 0.045) }
              GradientStop { position: 1.0; color: Qt.rgba(1, 1, 1, 0.015) }
            }

            // A tint of the panel's violet in the top corner and a specular
            // along the top edge: enough to read as a glass slab over the
            // backdrop, cheap enough to keep the rows' contrast.
            Rectangle {
              anchors.fill: parent
              radius: parent.radius
              gradient: Gradient {
                GradientStop { position: 0.0; color: Qt.rgba(0.45, 0.35, 1.0, 0.14) }
                GradientStop { position: 0.45; color: Qt.rgba(0.35, 0.30, 0.85, 0.03) }
                GradientStop { position: 1.0; color: Qt.rgba(0.20, 0.20, 0.55, 0.0) }
              }
            }


            Rectangle {
              anchors.fill: parent
              radius: parent.radius
              gradient: Gradient {
                GradientStop { position: 0.0; color: Qt.rgba(1, 1, 1, 0.07) }
                GradientStop { position: 0.35; color: Qt.rgba(1, 1, 1, 0.0) }
              }
            }
            Rectangle {
              anchors.left: parent.left
              anchors.right: parent.right
              anchors.top: parent.top
              anchors.margins: root.px(4)
              height: root.px(1.6)
              radius: height / 2
              color: Qt.rgba(1, 1, 1, 0.32)
            }


            // The far edge is in shade: a sliver of black along the bottom is
            // what gives the slab its thickness.
            Rectangle {
              anchors.fill: parent
              radius: parent.radius
              gradient: Gradient {
                GradientStop { position: 0.78; color: Qt.rgba(0, 0, 0, 0.0) }
                GradientStop { position: 1.0; color: Qt.rgba(0, 0, 0, 0.16) }
              }
            }

            Column {
              id: behaviorColumn
              x: root.px(8)
              y: root.px(5)
              width: parent.width - root.px(16)

              BehaviorRow {
                width: parent.width
                glyph: "\uf0e7"   // nf-fa-bolt
                label: strings.t("toggle.autoStart", "Auto-start the next phase")
                description: strings.t("toggle.autoStartHint", "Flow from focus into break and back.")
                checked: root.autoStart
                ink: root.ink
                fontFamily: root.bodyFamily
                glyphFamily: root.glyphFamily
                onToggled: root.persistSettings({ autoStart: !root.autoStart })
              }

              Rectangle { width: parent.width; x: 0; height: 1; color: Qt.rgba(1, 1, 1, 0.05) }

              BehaviorRow {
                width: parent.width
                glyph: "\uf028"   // nf-fa-volume-up
                label: strings.t("toggle.sound", "Sound")
                description: strings.t("toggle.soundHint", "Chime when a phase ends.")
                checked: root.soundOn
                ink: root.ink
                fontFamily: root.bodyFamily
                glyphFamily: root.glyphFamily
                onToggled: root.persistSettings({ sound: !root.soundOn })
              }

              Rectangle { width: parent.width; x: 0; height: 1; color: Qt.rgba(1, 1, 1, 0.05) }

              BehaviorRow {
                width: parent.width
                glyph: "\uf0f3"   // nf-fa-bell
                label: strings.t("toggle.notify", "Notifications")
                description: strings.t("toggle.notifyHint", "Desktop notification when a phase ends.")
                checked: root.notifyOn
                ink: root.ink
                fontFamily: root.bodyFamily
                glyphFamily: root.glyphFamily
                onToggled: root.persistSettings({ notify: !root.notifyOn })
              }

              Rectangle { width: parent.width; x: 0; height: 1; color: Qt.rgba(1, 1, 1, 0.05) }

              BehaviorRow {
                width: parent.width
                glyph: "\uf108"   // nf-fa-desktop
                label: strings.t("toggle.stayAwake", "Keep the screen awake")
                description: strings.t("toggle.stayAwakeHint", "No idle, screensaver or lock while focusing.")
                checked: root.stayAwakeOn
                ink: root.ink
                fontFamily: root.bodyFamily
                glyphFamily: root.glyphFamily
                onToggled: root.persistSettings({ stayAwake: !root.stayAwakeOn })
              }
            }
          }

          // ---- Key hints: the caps are drawn, since the shell renders every
          //      panel in one font and a keycap needs its own shape.
          Row {
            width: parent.width
            spacing: root.px(10)

            Repeater {
              model: [
                { key: "Space", hint: strings.t("hint.startpause", "start/pause") },
                { key: "S", hint: strings.t("hint.skip", "skip") },
                { key: "R", hint: strings.t("hint.reset", "reset") }
              ]

              Row {
                required property var modelData
                spacing: root.px(5)

                Rectangle {
                  anchors.verticalCenter: parent.verticalCenter
                  width: keyLabel.implicitWidth + root.px(10)
                  height: root.px(20)
                  radius: root.px(5)
                  color: Qt.rgba(1, 1, 1, 0.07)
                  border.width: 1
                  border.color: Qt.rgba(1, 1, 1, 0.12)

                  Text {
                    id: keyLabel
                    anchors.centerIn: parent
                    textFormat: Text.PlainText
                    text: modelData.key
                    color: Qt.rgba(0.85, 0.90, 0.98, 0.85)
                    font.family: root.bodyFamily
                    font.pixelSize: root.px(10)
                    font.weight: Font.DemiBold
                  }
                }

                Text {
                  anchors.verticalCenter: parent.verticalCenter
                  textFormat: Text.PlainText
                  text: modelData.hint
                  color: Qt.rgba(0.86, 0.91, 0.99, 0.70)
                  font.family: root.bodyFamily
                  font.pixelSize: root.px(11)
                }
              }
            }
          }
        }
      }
    }
  }
}
