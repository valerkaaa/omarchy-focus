import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Commons as Commons
import "Model.js" as Model

// The timer itself lives here, in one instance, not in the bar widget.
// The bar draws a widget per monitor, so a timer owned by a widget would run
// three times on a three-monitor desk. A service is mounted once by the shell
// (keepLoaded: true) and every bar surface reads the same countdown.
Item {
  id: root

  // The bar widget pushes its inline shell.json entry here; the service is
  // created before any bar surface, so it starts from the manifest defaults.
  property var settings: ({})

  Commons.Translations {
    id: strings
    directory: Qt.resolvedUrl("i18n")
  }

  readonly property string home: Quickshell.env("HOME")
  readonly property string stateDir: home + "/.local/state/omarchy/plugins/pomodoro"
  readonly property string statePath: stateDir + "/state.json"
  readonly property string inhibitPath: stateDir + "/idle-inhibit"

  // ---- timer state -------------------------------------------------------
  property string phase: "focus"          // focus | shortBreak | longBreak
  property bool running: false
  // True once the first block has started (or a phase has completed): an
  // untouched widget shows the mark alone instead of a permanent 25:00.
  property bool started: false
  property real remainingMs: Model.phaseDurationMs("focus", settings)
  property real endsAt: 0
  property int cycleCount: 0               // focus blocks since the last long break
  property int completedToday: 0
  property string day: Model.dayKey(new Date())
  property bool stateReady: false

  readonly property int longEvery: Model.longBreakEvery(settings)
  readonly property real phaseTotalMs: Model.phaseDurationMs(phase, settings)
  readonly property real fraction: Model.progress(remainingMs, phaseTotalMs)
  readonly property bool paused: started && !running
  readonly property bool focusing: running && phase === "focus"

  readonly property bool notifyEnabled: boolSetting("notify", true)
  readonly property bool soundEnabled: boolSetting("sound", true)
  readonly property bool autoStart: boolSetting("autoStart", true)
  readonly property bool stayAwakeEnabled: boolSetting("stayAwake", true)

  function setting(name, fallback) {
    var value = settings ? settings[name] : undefined
    return value === undefined || value === null ? fallback : value
  }

  function boolSetting(name, fallback) {
    return Model.boolValue(setting(name, fallback), fallback)
  }

  function durationFor(value) {
    return Model.phaseDurationMs(value, root.settings)
  }

  // Called by every bar widget whenever settings change. The last writer wins,
  // and all monitors carry the same entry.
  function applySettings(value) {
    root.settings = Util.isPlainObject(value) ? value : ({})
    if (!root.started) root.remainingMs = root.durationFor(root.phase)
  }

  function beginRunning() {
    root.endsAt = Date.now() + root.remainingMs
    root.running = true
  }

  function start() {
    root.refreshDay()
    if (root.running) return
    if (!root.started) {
      root.started = true
      root.remainingMs = root.durationFor(root.phase)
    }
    if (root.remainingMs <= 0) root.remainingMs = root.durationFor(root.phase)
    root.beginRunning()
  }

  function pause() {
    if (!root.running) return
    root.remainingMs = Math.max(0, root.endsAt - Date.now())
    root.running = false
  }

  function toggleTimer() {
    if (root.running) root.pause()
    else root.start()
  }

  function skip() {
    root.finishPhase(false)
  }

  function reset() {
    root.running = false
    root.started = false
    root.phase = "focus"
    root.cycleCount = 0
    root.remainingMs = root.durationFor("focus")
    root.save()
    root.syncIdleInhibit()
  }

  // Add or remove minutes on the running block without touching the phase.
  function adjustMinutes(delta) {
    var next = Math.max(60000, Math.min(3 * 3600000, root.remainingMs + delta * 60000))
    root.started = root.started || root.running
    root.remainingMs = next
    if (root.running) root.beginRunning()
  }

  // Called on every tick. Wall-clock arithmetic means a suspended machine
  // wakes up with the right remaining time instead of a stale counter.
  function tick() {
    if (!root.running) return
    root.refreshDay()
    var left = root.endsAt - Date.now()
    if (left <= 0) {
      root.finishPhase(true)
      return
    }
    root.remainingMs = left
  }

  function finishPhase(counted) {
    var finished = root.phase
    if (finished === "focus" && counted) {
      root.refreshDay()
      root.completedToday += 1
      root.cycleCount += 1
    }
    var next = Model.nextPhase(finished, root.cycleCount, root.longEvery)
    root.cycleCount = next.completedInCycle
    root.running = false
    root.phase = next.phase
    root.remainingMs = root.durationFor(next.phase)
    root.started = true
    root.save()
    // A skip is a deliberate move to the next phase; announcing "focus
    // complete" for a block that was cut short would be a lie.
    if (counted) root.announce(finished, next.phase)
    if (root.autoStart) root.beginRunning()
    root.syncIdleInhibit()
  }

  function refreshDay() {
    var today = Model.dayKey(new Date())
    if (today === root.day) return
    root.day = today
    root.completedToday = 0
    root.save()
  }

  // ---- announcements -----------------------------------------------------

  function announce(finished, next) {
    var title = ""
    var body = ""
    if (finished === "focus") {
      title = strings.t("notify.focusDone.title", "Focus complete")
      body = next === "longBreak"
        ? strings.t("notify.longBreak.body", "Take a %1 minute long break.")
            .arg(Commons.I18n.formatNumber(Model.longBreakMinutes(root.settings)))
        : strings.t("notify.shortBreak.body", "Take a %1 minute break.")
            .arg(Commons.I18n.formatNumber(Model.shortBreakMinutes(root.settings)))
    } else {
      title = strings.t("notify.breakDone.title", "Break over")
      body = strings.t("notify.breakDone.body", "Back to focus.")
    }

    if (root.notifyEnabled && title !== "") {
      // argv, not a shell string: the notification daemon reads the body as
      // markup, so plain() escapes it before it leaves the plugin.
      Util.execArgv(["omarchy-notification-send", "-g", "\uf017", "-u", "normal",
        Model.plain(title), Model.plain(body)])
    }

    if (root.soundEnabled) {
      var sound = finished === "focus" ? "alarm-clock-elapsed" : "complete"
      // A fixed command: no settings or environment values are interpolated.
      Util.execDetached("canberra-gtk-play -i " + sound + " >/dev/null 2>&1"
        + " || paplay /usr/share/sounds/freedesktop/stereo/" + sound + ".oga >/dev/null 2>&1"
        + " || true")
    }
  }

  // ---- idle inhibition ---------------------------------------------------
  // A focus block should not lock the screen out from under it. The idle
  // service owns that state, so the plugin borrows it and gives it back: a
  // marker file records whether the plugin turned idle off (owned) or the
  // user already had stay-awake on before the block (preexisting), so a
  // manual choice is never undone by the timer ending.
  property bool idleInhibited: false

  function syncIdleInhibit() {
    var want = root.focusing && root.stayAwakeEnabled
    if (want === root.idleInhibited) return
    root.idleInhibited = want
    if (want) idleInhibitProc.running = true
    else idleReleaseProc.running = true
  }

  onFocusingChanged: root.syncIdleInhibit()
  onStayAwakeEnabledChanged: root.syncIdleInhibit()

  Process {
    id: idleInhibitProc
    command: ["bash", "-lc",
      "mkdir -p " + Util.shellQuote(root.stateDir) + "\n"
      + "f=" + Util.shellQuote(root.inhibitPath) + "\n"
      + "[ -e \"$f\" ] && exit 0\n"
      + "if omarchy-shell idle status 2>/dev/null | grep -q '\"stayAwake\":true'; then\n"
      + "  printf preexisting > \"$f\"\n"
      + "else\n"
      + "  printf owned > \"$f\"\n"
      + "  omarchy-shell -q idle disable\n"
      + "fi"]
  }

  Process {
    id: idleReleaseProc
    command: ["bash", "-lc",
      "f=" + Util.shellQuote(root.inhibitPath) + "\n"
      + "[ -e \"$f\" ] || exit 0\n"
      + "[ \"$(cat \"$f\")\" = owned ] && omarchy-shell -q idle enable\n"
      + "rm -f \"$f\""]
  }

  // ---- persistence -------------------------------------------------------
  // Only the day counter and the cycle position are stored; a running block
  // is deliberately not resumed across a shell restart, because a 25-minute
  // countdown that silently kept going while the shell was down would fire a
  // notification for a block nobody remembers starting.

  function loadState(raw) {
    var state = Model.parseState(raw)
    if (!state.valid) return
    root.day = state.day || Model.dayKey(new Date())
    root.completedToday = state.day === Model.dayKey(new Date()) ? state.completedToday : 0
    root.cycleCount = Math.min(state.cycleCount, root.longEvery - 1)
  }

  function save() {
    if (!root.stateReady) return
    stateFile.setText(Model.serialiseState({
      day: root.day,
      completedToday: root.completedToday,
      cycleCount: root.cycleCount
    }))
  }

  Timer {
    interval: 250
    repeat: true
    running: root.running
    onTriggered: root.tick()
  }

  Process {
    id: mkdirProc
    command: ["bash", "-lc", "mkdir -p " + Util.shellQuote(root.stateDir)]
    onExited: {
      root.stateReady = true
      stateFile.reload()
    }
  }

  FileView {
    id: stateFile
    path: root.statePath
    watchChanges: true
    atomicWrites: true
    printErrors: false
    onLoaded: root.loadState(text())
    onFileChanged: reload()
  }

  Component.onCompleted: {
    mkdirProc.running = true
    // A focus block is not resumed across a shell restart, so a marker left by
    // one must not keep the machine awake forever. Releasing is safe: the
    // command only touches idle if the plugin itself turned it off.
    idleReleaseProc.running = true
  }
}
