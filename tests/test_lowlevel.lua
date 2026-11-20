-- EightSecondArgument: low-level characters (FrostSuite r5). A level 1 Mage (Fireball, Frost Armor), a mid-level Mage with only some
-- spells, and a non-Mage: loads quietly, never shows made-up data, says when to learn what it needs, "Hide until I learn"
-- is saved per character, and the box comes back by itself when the spell is learned.
package.path = "tests/?.lua;" .. package.path
local W = require("mock_wow"); W.install()
local check = W.check
W.level, W.known = 1, { [133] = true, [168] = true }   -- level 1: Fireball and Frost Armor
local ns = W.loadAddon(".", "EightSecondArgument")
W.fire("PLAYER_LOGIN"); W.fire("SPELLS_CHANGED"); W.advance(2)
local FS = _G.FrostSuite_1_0
local row = FS.rows.EightSecondArgument
local function quiet(label)
  local bad = false
  for _, p in ipairs(W.prints) do if p:find("WARNING") or p:lower():find("error") then bad = true end end
  check(#ns.Core.errors == 0 and not bad, label .. ": no Lua errors, nothing alarming in chat")
end
local function learnLine() return row.state == "learn" and row.learnText and row.learnText.shown and row.learnText.text_ or nil end
local function fight(ids)
  W.combat = true; W.fire("PLAYER_REGEN_DISABLED")
  for _, id in ipairs(ids or { 133, 116 }) do W.S.cast(id) end
  W.advance(3)
end
local function peace() W.combat = false; W.fire("PLAYER_REGEN_ENABLED"); W.advance(3) end
local function learn(lvl, ids)
  W.level = lvl
  W.fire("PLAYER_LEVEL_UP", lvl)
  for _, id in ipairs(ids) do W.known[id] = true; W.fire("LEARNED_SPELL_IN_SKILL_LINE", id) end
  W.fire("SPELLS_CHANGED"); W.advance(2)
end
quiet("level 1 login")
local L1 = "Learn Fire Blast at level 6"
check(learnLine() == L1, "level 1: 'Learn Fire Blast at level 6'")
check(row.headText == "" and row.statusText == "", "no READY, LANCE or WAIT for spells it can't cast")

-- level 1, in combat: the learn box steps aside (nothing to say in a fight), no errors from casting Fireball
fight({ 133 })
check(not row.shown and not (row.learnBtn and row.learnBtn.shown), "level 1 in combat: hidden, no button")
quiet("level 1 combat")
peace()
check(learnLine() == L1, "after combat the line is back")
check(row.learnBtn.shown and row.learnBtn.text_ == "Hide until I learn", "with its small button")
check(row.h == 64 and not row.head.shown and not row.bar.shown, "one calm line in a 64 px box: no headline, bar or numbers")
-- Hide until I learn: hidden, saved per character, stays hidden through a level-up that still misses a spell
row.learnBtn.scripts.OnClick(row.learnBtn)
check(row.state == "hidden" and KennyEightSecondArgumentDB.hideUntilLearned["Kenny-TestRealm"] == true, "Hide until I learn: hidden and saved for this character")
FS.Layout()
check(not row.shown, "takes no slot in the dock")
learn(8, { 2136 })
check(row.state == "hidden" and ns.EA.need.name == "Ice Lance", "level 8, Fire Blast only: still hidden until Ice Lance")
fight({ 2136 }); check(row.headText ~= "WAIT 8" and not row.shown, "no WAIT timer for a box that can't work yet"); peace()
KennyEightSecondArgumentDB.hideUntilLearned = nil; W.fire("SPELLS_CHANGED")
check(learnLine() == "Learn Ice Lance at level 20", "mid level: names Ice Lance and its level")
learn(20, { 1312002 })
check(row.state == "idle" and (row.statusText == "ready" or row.statusText == "timer only: Fingers hidden"), "Ice Lance learned: the box works")
quiet("mid level")

-- not a Mage: never a learn line, never an error
W.class = "WARRIOR"; W.known = {}; W.level = 1; W.fire("SPELLS_CHANGED"); W.fire("PLAYER_LEVEL_UP", 2); W.advance(2)
check(row.state == "hidden" and not learnLine(), "non-Mage: hidden, no learn line")
fight({ 78 }); peace()
quiet("non-Mage")
W.class = nil
W.done("EightSecondArgument low level")
