-- Eight Second Argument: shared cooldown from your casts, LANCE / BLAST / WAIT, honest when Fingers is hidden.
package.path = "tests/?.lua;" .. package.path
local W = require("mock_wow"); W.install()
local S = W.S
local check = W.check
local ns = W.loadAddon(".", "EightSecondArgument")
W.fire("PLAYER_LOGIN")
local EA, FS = ns.EA, _G.FrostSuite_1_0
local row = FS.rows.EightSecondArgument
local LANCE, BLAST, BLAST15, FOF, NOVA = 400640, 10199, 400616, 400669, 10230

local function reset()
  W.combat = false; W.moving = false; W.target = nil; W.fire("PLAYER_REGEN_ENABLED"); W.advance(30)
  S.install(W); W.prints = {}
  EA.readyAt, EA.hiddenEvents, EA.plainCasts, EA.toldHidden, EA.lit = nil, 0, 0, nil, {}
  EA.DB = nil
  ns.EA.Update()
  W.fire("PLAYER_LOGIN")
end
local function fight() W.combat = true; W.fire("PLAYER_REGEN_DISABLED") end
local db = KennyEightSecondArgumentDB

local n8, n15 = 0, 0
for _, v in pairs(EA.LANCE) do if v == 8 then n8 = n8 + 1 end end
for _, v in pairs(EA.BLAST) do if v == 8 then n8 = n8 + 1 else n15 = n15 + 1 end end
check(n8 == 13 and n15 == 7, "6 Ice Lance + 7 Fire Blast ranks at 8 s, 7 Fire Blast spells at 15 s (client data)")

-- 1. Strict client, alert never seen: timer works, verdict honest.
reset(); db.alertSeen = nil; fight()
check(EA.modes.timer == "cast" and EA.modes.fingers == "alert" and EA.modes.frozen == "none", "strict: cast timer, alert, frozen hidden")
check(EA.verdict == "ready" and row.headText == "READY" and row.statusText == "timer only: Fingers hidden", "no guess: READY + Fingers hidden")
S.cast(BLAST)
check(EA.verdict == "wait" and row.headText == "WAIT 8", "Fire Blast starts WAIT 8")
W.advance(3)
check(row.headText == "WAIT 5" and math.abs(row.barValue - 5 / 8) < 0.05, "counts down from your cast")
W.advance(5.1)
check(EA.verdict == "ready", "free again after 8 s")
S.cast(LANCE)
check(row.headText == "WAIT 8", "Ice Lance starts the same shared wait")
W.advance(8.1)
S.cast(BLAST15)
check(row.headText == "WAIT 15", "the 15 s Fire Blast spells wait 15 s")
W.advance(15.1)
-- Cold Snap does not reset the shared timer.
S.cast(BLAST); S.cast(12472)
check(EA.verdict == "wait", "Cold Snap is not assumed to reset Fire Blast")
W.advance(8.1)
-- 2. The game's spell alert on Ice Lance: LANCE; once seen, its absence means BLAST.
S.glow(LANCE, true)
check(EA.verdict == "lance" and row.headText == "LANCE" and db.alertSeen == true, "alert lit: LANCE")
S.glow(LANCE, false)
check(EA.verdict == "ready", "alert seen, but the target's freeze is hidden: no BLAST while standing")
W.moving = true; W.fire("PLAYER_STARTED_MOVING")
check(EA.verdict == "blast" and row.headText == "BLAST" and row.lineText[2] == "Frozen target hidden", "moving + no Fingers: BLAST")
check(row.h == 78 and row.lines[2].shown and 44 + 14 * 2 + 6 <= row.h, "r4: line 2 (Frozen target hidden) fits inside the box")
W.moving = false; W.fire("PLAYER_STOPPED_MOVING")
-- 3. Never-secret Fingers and readable target freeze (restrictions off): full verdicts.
reset(); S.restrictions = false; W.target = "mob"; fight()
check(EA.modes.fingers == "aura" and EA.modes.frozen == "aura", "readable: aura modes")
check(EA.verdict == "blast", "no Fingers, target not frozen: BLAST")
S.gain(FOF, 1, 15)
check(EA.verdict == "lance", "Fingers up: LANCE")
S.drop(FOF); S.unitGain("target", NOVA, 0, 8)
check(EA.verdict == "lance", "target Frozen: LANCE")
S.cast(LANCE)
check(EA.verdict == "wait", "WAIT beats LANCE while the cooldown runs")
-- 4. Strict client: secret target auras are never read as 'not frozen'.
reset(); W.target = "mob"; fight()
S.unitGain("target", NOVA, 0, 8)
check(EA.Frozen() == nil, "secret freeze on target: unknown, not false")
-- 5. Hidden casts: no verdict.
reset(); S.castSecretInCombat = true; fight()
S.cast(BLAST)
check(EA.verdict == "none" and row.statusText == "can't see your casts here" and EA.readyAt == nil, "hidden casts: no timer, says so")
check(W.printed("can't time the shared cooldown"), "chat says so once")
-- 6. Needs both spells; other units ignored; TEXT style never glows.
reset(); W.known = { [2136] = true }; W.fire("SPELLS_CHANGED")
check(row.state == "hidden", "Fire Blast without Ice Lance: hidden")
W.known = nil; W.fire("SPELLS_CHANGED")
S.cast(LANCE, "party1")
check(EA.readyAt == nil, "other units ignored")
check(FS.RequestFlash("EightSecondArgument") == false, "never glows (TEXT)")
local src = io.open("EightSecondArgument.lua"):read("*a")
check(not src:find("CastSpell") and not src:find("TargetUnit") and not src:find("UseAction"), "no cast, target or movement calls")
W.done("EightSecondArgument")
