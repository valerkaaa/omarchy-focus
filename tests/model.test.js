// Unit tests for Model.js under node. The module is loaded from disk rather
// than re-imported through QML, so these run anywhere: `node tests/model.test.js`
const assert = require("assert")
const Model = require("../Model.js")

let failures = 0
function test(name, fn) {
  try {
    fn()
    console.log("ok   " + name)
  } catch (error) {
    failures++
    console.log("FAIL " + name + "\n     " + error.message)
  }
}

test("clampInt falls back on garbage and clamps the range", () => {
  assert.strictEqual(Model.clampInt("abc", 25, 1, 180), 25)
  assert.strictEqual(Model.clampInt("999", 25, 1, 180), 180)
  assert.strictEqual(Model.clampInt(0, 25, 1, 180), 1)
  assert.strictEqual(Model.clampInt(50, 25, 1, 180), 50)
})

test("boolValue reads JSON booleans and the strings `omarchy bar set` writes", () => {
  assert.strictEqual(Model.boolValue(true, false), true)
  assert.strictEqual(Model.boolValue("true", false), true)
  assert.strictEqual(Model.boolValue("Off", true), false)
  // An unrecognised value keeps the fallback rather than reading as "on".
  assert.strictEqual(Model.boolValue("maybe", false), false)
  assert.strictEqual(Model.boolValue(undefined, true), true)
})

test("phaseDurationMs maps each phase to its own setting", () => {
  const settings = { focusMinutes: 30, shortBreakMinutes: 4, longBreakMinutes: 12 }
  assert.strictEqual(Model.phaseDurationMs("focus", settings), 30 * 60000)
  assert.strictEqual(Model.phaseDurationMs("shortBreak", settings), 4 * 60000)
  assert.strictEqual(Model.phaseDurationMs("longBreak", settings), 12 * 60000)
})

test("nextPhase takes a long break every Nth focus block", () => {
  assert.deepStrictEqual(Model.nextPhase("focus", 1, 4), { phase: "shortBreak", completedInCycle: 1 })
  assert.deepStrictEqual(Model.nextPhase("focus", 3, 4), { phase: "shortBreak", completedInCycle: 3 })
  assert.deepStrictEqual(Model.nextPhase("focus", 4, 4), { phase: "longBreak", completedInCycle: 4 })
  // A skip does not count the block, so it never reaches the long break.
  assert.deepStrictEqual(Model.nextPhase("focus", 4, 4).phase, "longBreak")
})

test("nextPhase always returns to focus and resets the counter after a long break", () => {
  assert.deepStrictEqual(Model.nextPhase("shortBreak", 2, 4), { phase: "focus", completedInCycle: 2 })
  assert.deepStrictEqual(Model.nextPhase("longBreak", 4, 4), { phase: "focus", completedInCycle: 0 })
})

test("clockParts rounds up, so the last second still reads 01", () => {
  assert.deepStrictEqual(Model.clockParts(0), { h: 0, m: 0, s: 0 })
  assert.deepStrictEqual(Model.clockParts(1), { h: 0, m: 0, s: 1 })
  assert.deepStrictEqual(Model.clockParts(999), { h: 0, m: 0, s: 1 })
  assert.deepStrictEqual(Model.clockParts(60000), { h: 0, m: 1, s: 0 })
  assert.deepStrictEqual(Model.clockParts(25 * 60000), { h: 0, m: 25, s: 0 })
  assert.deepStrictEqual(Model.clockParts(90 * 60000), { h: 1, m: 30, s: 0 })
  assert.deepStrictEqual(Model.clockParts(-5), { h: 0, m: 0, s: 0 })
})

test("progress is clamped and safe against a zero total", () => {
  assert.strictEqual(Model.progress(0, 0), 0)
  assert.strictEqual(Model.progress(30000, 60000), 0.5)
  assert.strictEqual(Model.progress(-1, 60000), 0)
  assert.strictEqual(Model.progress(99999, 60000), 1)
})

test("plain escapes the body so a notification daemon cannot read markup", () => {
  assert.strictEqual(Model.plain("<img src=x>"), "&lt;img src=x&gt;")
  assert.strictEqual(Model.plain("Tom & Jerry"), "Tom &amp; Jerry")
  assert.strictEqual(Model.plain(null), "")
})

test("parseState validates every field it reads back from disk", () => {
  assert.strictEqual(Model.parseState("nonsense").valid, false)
  assert.strictEqual(Model.parseState("[]").valid, false)

  const parsed = Model.parseState(JSON.stringify({ day: "2026-11-05", completedToday: 3, cycleCount: 2 }))
  assert.deepStrictEqual(parsed, { valid: true, day: "2026-11-05", completedToday: 3, cycleCount: 2 })

  const hostile = Model.parseState(JSON.stringify({ day: "../../etc", completedToday: -4, cycleCount: 1e6 }))
  assert.strictEqual(hostile.day, "")
  assert.strictEqual(hostile.completedToday, 0)
  assert.strictEqual(hostile.cycleCount, 99)
})

test("serialiseState round-trips and always ends in a newline", () => {
  const raw = Model.serialiseState({ day: "2026-11-05", completedToday: 2, cycleCount: 1 })
  assert.ok(raw.endsWith("\n"))
  const back = Model.parseState(raw)
  assert.deepStrictEqual(back, { valid: true, day: "2026-11-05", completedToday: 2, cycleCount: 1 })
})

test("dayKey is zero-padded", () => {
  assert.strictEqual(Model.dayKey(new Date(2026, 0, 3)), "2026-01-03")
  assert.strictEqual(Model.dayKey(new Date(2026, 10, 15)), "2026-11-15")
})

if (failures > 0) {
  console.log("\n" + failures + " test(s) failed")
  process.exit(1)
}
console.log("\nall tests passed")
