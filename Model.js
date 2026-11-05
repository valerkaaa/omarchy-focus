// Pure helpers for the Pomodoro plugin.
//
// No QML here: the service owns timers and the widget owns the picture, but
// every decision about what the next phase is, how long it lasts, and how a
// clock is written can be made from values alone. Keeping it in one place
// means the tests in tests/model.test.js run under node against the same
// functions the shell loads.

var PHASES = ["focus", "shortBreak", "longBreak"]

var DEFAULTS = {
  focusMinutes: 25,
  shortBreakMinutes: 5,
  longBreakMinutes: 15,
  longBreakEvery: 4
}

function clamp(value, min, max) {
  var n = Number(value)
  if (!isFinite(n)) return min
  return Math.max(min, Math.min(max, n))
}

function clampInt(value, fallback, min, max) {
  var n = parseInt(String(value), 10)
  if (!isFinite(n)) n = fallback
  return Math.max(min, Math.min(max, n))
}

// Settings arrive either as JSON booleans (written by this plugin) or as the
// strings `omarchy bar set` writes ("true"/"false"), and an unrecognised value
// must not silently read as "on".
function boolValue(value, fallback) {
  if (value === true || value === false) return value
  if (value === undefined || value === null || value === "") return fallback
  var text = String(value).trim().toLowerCase()
  if (text === "true" || text === "on" || text === "1" || text === "yes") return true
  if (text === "false" || text === "off" || text === "0" || text === "no") return false
  return fallback
}

function isPhase(value) {
  return PHASES.indexOf(String(value)) >= 0
}

function focusMinutes(settings) {
  return clampInt(settings && settings.focusMinutes, DEFAULTS.focusMinutes, 1, 180)
}

function shortBreakMinutes(settings) {
  return clampInt(settings && settings.shortBreakMinutes, DEFAULTS.shortBreakMinutes, 1, 60)
}

function longBreakMinutes(settings) {
  return clampInt(settings && settings.longBreakMinutes, DEFAULTS.longBreakMinutes, 1, 120)
}

function longBreakEvery(settings) {
  return clampInt(settings && settings.longBreakEvery, DEFAULTS.longBreakEvery, 2, 12)
}

function phaseDurationMs(phase, settings) {
  var minutes
  if (phase === "shortBreak") minutes = shortBreakMinutes(settings)
  else if (phase === "longBreak") minutes = longBreakMinutes(settings)
  else minutes = focusMinutes(settings)
  return minutes * 60000
}

// `completedInCycle` is the number of focus blocks finished since the last
// long break, already including the one that just ended.
function nextPhase(phase, completedInCycle, every) {
  if (phase !== "focus") {
    return { phase: "focus", completedInCycle: phase === "longBreak" ? 0 : completedInCycle }
  }
  var target = clampInt(every, DEFAULTS.longBreakEvery, 2, 12)
  return {
    phase: completedInCycle >= target ? "longBreak" : "shortBreak",
    completedInCycle: completedInCycle
  }
}

// Whole seconds, rounded up: a countdown that says 00:00 while a phase is
// still running would be a lie, so the last second stays "01" until it ends.
function clockParts(ms) {
  var total = Math.max(0, Math.ceil((Number(ms) || 0) / 1000))
  return {
    h: Math.floor(total / 3600),
    m: Math.floor((total % 3600) / 60),
    s: total % 60
  }
}

function progress(remainingMs, totalMs) {
  var total = Number(totalMs) || 0
  if (total <= 0) return 0
  return clamp((Number(remainingMs) || 0) / total, 0, 1)
}

function dayKey(date) {
  var d = date instanceof Date ? date : new Date()
  var month = d.getMonth() + 1
  var day = d.getDate()
  return d.getFullYear() + "-" + (month < 10 ? "0" : "") + month + "-" + (day < 10 ? "0" : "") + day
}

// Notification daemons read the body as markup. These strings are ours, but a
// translation is still text from a file, and the daemon is a sink this plugin
// does not control: escape it so a stray "<" can never become a tag.
function plain(text) {
  return String(text === undefined || text === null ? "" : text)
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
}

// Persisted state is read back from disk after a crash or a shell restart, so
// every field is validated rather than trusted.
function parseState(raw) {
  var out = { valid: false, day: "", completedToday: 0, cycleCount: 0 }
  var parsed
  try {
    parsed = JSON.parse(String(raw || ""))
  } catch (e) {
    return out
  }
  if (!parsed || typeof parsed !== "object" || Array.isArray(parsed)) return out
  out.valid = true
  out.day = typeof parsed.day === "string" && /^\d{4}-\d{2}-\d{2}$/.test(parsed.day) ? parsed.day : ""
  out.completedToday = clampInt(parsed.completedToday, 0, 0, 999)
  out.cycleCount = clampInt(parsed.cycleCount, 0, 0, 99)
  return out
}

function serialiseState(state) {
  var value = state && typeof state === "object" ? state : {}
  return JSON.stringify({
    version: 1,
    day: typeof value.day === "string" ? value.day : "",
    completedToday: clampInt(value.completedToday, 0, 0, 999),
    cycleCount: clampInt(value.cycleCount, 0, 0, 99)
  }) + "\n"
}

if (typeof module !== "undefined" && module.exports) {
  module.exports = {
    PHASES: PHASES,
    DEFAULTS: DEFAULTS,
    clamp: clamp,
    clampInt: clampInt,
    boolValue: boolValue,
    isPhase: isPhase,
    focusMinutes: focusMinutes,
    shortBreakMinutes: shortBreakMinutes,
    longBreakMinutes: longBreakMinutes,
    longBreakEvery: longBreakEvery,
    phaseDurationMs: phaseDurationMs,
    nextPhase: nextPhase,
    clockParts: clockParts,
    progress: progress,
    dayKey: dayKey,
    plain: plain,
    parseState: parseState,
    serialiseState: serialiseState
  }
}
