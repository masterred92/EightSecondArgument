-- Eight Second Argument: Ice Lance vs Fire Blast for Frost Mages on WoW: Forever. Written from scratch (MIT).
--
-- Why: official Nov 2, 2026 notes gave Ice Lance "an 8-second cooldown shared with Fire Blast". Client data agrees: every
-- Ice Lance rank and Fire Blast ranks 1-7 are in spell category 19 with an 8000 ms category cooldown (SpellCategories +
-- SpellCooldowns, build 1.60.1.70862). A second set of Fire Blast spells (400616, 400618-400623) is in the same category
-- with 15000 ms; if you cast one of those the wait is 15 s. Spending the shared cooldown on Fire Blast while Ice Lance would
-- shatter wastes the 300% bonus. The box says one word:
--   LANCE   shared cooldown free and Fingers of Frost is up or your target is Frozen
--   BLAST   shared cooldown free and neither is up (or you are moving and Fingers is known to be down)
--   WAIT n  the shared cooldown is running, counted from your own last Ice Lance or Fire Blast
-- It is a verdict, not a rotation helper, and it never casts. Cold Snap is NOT assumed to reset Fire Blast (official text
-- doesn't say it does), so the timer ignores Cold Snap.
--
-- What it can see (picked at runtime; /frost lance debug prints it):
--   timer:   "cast" from your UNIT_SPELLCAST_SUCCEEDED; "none" if the client hides your casts (then no verdict at all).
--   Fingers: "aura" when Fingers of Frost (400669 / 400670) can be read right now; else "alert": the game's own spell alert
--            on Ice Lance (SPELL_ACTIVATION_OVERLAY_GLOW_SHOW, not secret-flagged in the docs). Its absence only counts as
--            "no Fingers" after this character has seen the alert at least once. Else "none": "timer only: Fingers hidden".
--   Frozen:  "aura" when Frost Nova or Frostbite on your target can be read right now, else "none".
-- Spell IDs: SpellName + SkillLineAbility, builds 1.60.1.70862 and 70888.
local ADDON, ns = ...
local C, Core, FS = ns.Compat, ns.Core, ns.FrostSuite
local L = Core.L

local EA = {}
KennyEightSecondArgument = EA
ns.EA = EA
local KEY = "EightSecondArgument"
local SCHEMA = 1

EA.LANCE = { [1312002] = 8, [400640] = 8, [1240044] = 8, [1240045] = 8, [1240046] = 8, [1240047] = 8 }
EA.BLAST = { [2136] = 8, [2137] = 8, [2138] = 8, [8412] = 8, [8413] = 8, [10197] = 8, [10199] = 8,
  [400616] = 15, [400618] = 15, [400619] = 15, [400620] = 15, [400621] = 15, [400622] = 15, [400623] = 15 }
EA.FINGERS = { 400669, 400670 }
EA.FROZEN = { 122, 865, 6131, 10230, 12494 } -- Frost Nova ranks, Frostbite's freeze
EA.TICK = 0.25

local db, row
local migrations = {}
EA.readyAt = nil   -- GetTime() when the shared cooldown ends
EA.lit = {}        -- Ice Lance spellID -> true while the game's spell alert glows on it
EA.hiddenEvents, EA.plainCasts = 0, 0
EA.known = true
EA.modes = { timer = "cast", fingers = "none", frozen = "none" }
EA.verdict = "ready"
local ticking = false

local function now() return C.Clock() end

-- ---------- detection ----------
function EA.CastsHidden() return EA.hiddenEvents > 0 and EA.plainCasts == 0 end
local function anyReadable(list, unit)
  for _, id in ipairs(list) do if FS.AuraReadableNow(id, unit) then return true end end
  return false
end
function EA.EvaluateModes()
  local castOK = not EA.CastsHidden()
  for id in pairs(EA.LANCE) do if FS.CastSecrecy(id) == 1 then castOK = false end end
  EA.modes.timer = castOK and "cast" or "none"
  local alertAPI = C_SpellActivationOverlay ~= nil and type(C_SpellActivationOverlay.IsSpellOverlayed) == "function"
  EA.modes.fingers = anyReadable(EA.FINGERS, "player") and "aura" or (alertAPI and "alert" or "none")
  EA.modes.frozen = anyReadable(EA.FROZEN, "target") and "aura" or "none"
  return EA.modes
end

-- true (up), false (known down) or nil (can't tell)
function EA.Fingers()
  if EA.modes.fingers == "aura" then
    local all = true
    for _, id in ipairs(EA.FINGERS) do
      local a, ok = FS.ReadAura("player", id)
      if ok and a then return true end
      if not ok then all = false end
    end
    if all then return false end
  end
  if EA.modes.fingers ~= "none" and C_SpellActivationOverlay then
    for id in pairs(EA.LANCE) do
      if EA.lit[id] or FS.Call(C_SpellActivationOverlay.IsSpellOverlayed, id) == true then return true end
    end
    if db and db.alertSeen then return false end
  end
  return nil
end

function EA.Frozen()
  if EA.modes.frozen ~= "aura" or (UnitExists and not UnitExists("target")) then return nil end
  local all = true
  for _, id in ipairs(EA.FROZEN) do
    local a, ok = FS.ReadAura("target", id)
    if ok and a then return true end
    if not ok then all = false end
  end
  if all then return false end
  return nil
end

function EA.Left()
  if not EA.readyAt then return 0 end
  local l = EA.readyAt - now()
  if l <= 0 then EA.readyAt = nil; return 0 end
  return l
end

-- "lance", "blast", "wait", "ready" (free, window unknown), "none" (casts hidden), "hidden"
function EA.Compute()
  if not EA.known then return "hidden" end
  if EA.modes.timer == "none" then return "none" end
  if EA.Left() > 0 then return "wait" end
  local fof, frozen = EA.Fingers(), EA.Frozen()
  if fof or frozen then return "lance" end
  if fof == false and frozen == false then return "blast" end
  if fof == false and IsPlayerMoving and IsPlayerMoving() == true then return "blast" end
  return "ready"
end

local function schedule()
  if ticking then return end
  ticking = true
  C_Timer.After(EA.TICK, function() ticking = false; EA.Update() end)
end

function EA.Update()
  EA.EvaluateModes()
  EA.verdict = EA.Compute()
  if row then EA.Paint() end
  if EA.Left() > 0 or C.InCombat() then schedule() end
  return EA.verdict
end

function EA.Paint()
  local v = EA.verdict
  if v == "hidden" then FS.State(KEY, "hidden"); return end
  FS.ClearLines(KEY)
  local left = EA.Left()
  local fingersHidden = EA.modes.fingers == "none" or (EA.modes.fingers == "alert" and not (db and db.alertSeen))
  if v == "none" then
    FS.Headline(KEY, "", "Mist"); FS.Bar(KEY, nil)
    FS.Status(KEY, L["can't see your casts here"], "Mist")
    FS.State(KEY, "idle")
    return
  end
  FS.Status(KEY, fingersHidden and L["timer only: Fingers hidden"] or "", "Mist")
  if v == "wait" then
    FS.Headline(KEY, (L["WAIT %d"]):format(math.ceil(left)), "Mist")
    FS.Bar(KEY, left / (EA.lastCD or 8), "LanceCyan")
  elseif v == "lance" then FS.Headline(KEY, L["LANCE"], "LanceCyan"); FS.Bar(KEY, nil)
  elseif v == "blast" then FS.Headline(KEY, L["BLAST"], "BlastOrange"); FS.Bar(KEY, nil)
    if EA.Frozen() == nil then FS.Line(KEY, 2, L["Frozen target hidden"]) end
  else FS.Headline(KEY, C.InCombat() and L["READY"] or "", "Mist"); FS.Bar(KEY, nil)
    if not fingersHidden then FS.Status(KEY, L["ready"], "Mist") end
  end
  FS.State(KEY, (C.InCombat() or v == "wait") and "active" or "idle")
end

-- ---------- events ----------
function EA.OnSpellcast(unit, _, spellID)
  if unit ~= "player" then return end
  if C.IsSecret(spellID) then
    EA.hiddenEvents = EA.hiddenEvents + 1
    if EA.CastsHidden() and not EA.toldHidden then
      EA.toldHidden = true
      Core.Print(L["The client is hiding your casts here, so Eight Second Argument can't time the shared cooldown. /frost lance debug shows why."])
    end
    return EA.Update()
  end
  local cd = EA.LANCE[spellID] or EA.BLAST[spellID]
  if cd then
    EA.plainCasts = EA.plainCasts + 1
    EA.readyAt, EA.lastCD = now() + cd, cd
    if EA.LANCE[spellID] then EA.lit[spellID] = nil end
    EA.Update()
  end
end

function EA.OnGlow(event, spellID)
  if C.IsSecret(spellID) or not EA.LANCE[spellID] then return end
  if event == "SPELL_ACTIVATION_OVERLAY_GLOW_SHOW" then
    EA.lit[spellID] = true
    if db then db.alertSeen = true end
  else
    EA.lit[spellID] = nil
  end
  EA.Update()
end

function EA.DetectionLines()
  EA.EvaluateModes()
  local f, z = EA.Fingers(), EA.Frozen()
  return {
    ("shared cooldown timer: %s  (cast = from your Ice Lance / Fire Blast, none = the client hides your casts)"):format(EA.modes.timer),
    ("Fingers of Frost: %s  (aura = buff read, alert = the game's Ice Lance spell alert, none = hidden); now: %s"):format(EA.modes.fingers, tostring(f)),
    ("Ice Lance spell alert seen on this character: %s"):format(tostring(db and db.alertSeen or false)),
    ("Frozen target: %s  (aura = Frost Nova / Frostbite on your target read, none = hidden); now: %s"):format(EA.modes.frozen, tostring(z)),
    ("secret restrictions: %s, in combat: %s, knows Ice Lance and Fire Blast: %s"):format(tostring(FS.Restricted()), tostring(C.InCombat()), tostring(EA.known)),
    ("verdict: %s, wait left: %.1f s, casts: %d plain, %d hidden"):format(EA.verdict, EA.Left(), EA.plainCasts, EA.hiddenEvents),
    ("  Fingers 400669 / 400670 aura secrecy: %s / %s (0 = never secret)"):format(tostring(FS.AuraSecrecy(400669)), tostring(FS.AuraSecrecy(400670))),
    ("  Ice Lance 400640 cast secrecy: %s; Cold Snap is not assumed to reset Fire Blast"):format(tostring(FS.CastSecrecy(400640))),
  }
end

function EA.Slash(msg)
  local cmd = (msg or ""):lower():match("^(%S*)")
  if cmd == "debug" then for _, l in ipairs(EA.DetectionLines()) do Core.Print(l) end
  else Core.Print("/frost lance debug") end
end

-- ---------- wiring ----------
local ev = CreateFrame("Frame")
ev:RegisterEvent("ADDON_LOADED")
for _, e in ipairs({ "PLAYER_LOGIN", "SPELLS_CHANGED", "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED", "PLAYER_TARGET_CHANGED",
  "SPELL_ACTIVATION_OVERLAY_GLOW_SHOW", "SPELL_ACTIVATION_OVERLAY_GLOW_HIDE", "PLAYER_STARTED_MOVING", "PLAYER_STOPPED_MOVING" }) do ev:RegisterEvent(e) end
ev:RegisterUnitEvent("UNIT_SPELLCAST_SUCCEEDED", "player")
ev:RegisterUnitEvent("UNIT_AURA", "player", "target")

local function refresh()
  if not C.InCombat() then
    EA.known = FS.IsMage() and FS.KnowsAny(EA.LANCE) ~= false and FS.KnowsAny(EA.BLAST) ~= false
  end
  EA.Update()
end
local function update() EA.Update() end
local handlers = {
  PLAYER_LOGIN = refresh, SPELLS_CHANGED = refresh, PLAYER_REGEN_ENABLED = refresh,
  PLAYER_REGEN_DISABLED = update, PLAYER_TARGET_CHANGED = update, UNIT_AURA = update,
  PLAYER_STARTED_MOVING = update, PLAYER_STOPPED_MOVING = update,
  UNIT_SPELLCAST_SUCCEEDED = EA.OnSpellcast,
  SPELL_ACTIVATION_OVERLAY_GLOW_SHOW = function(id) EA.OnGlow("SPELL_ACTIVATION_OVERLAY_GLOW_SHOW", id) end,
  SPELL_ACTIVATION_OVERLAY_GLOW_HIDE = function(id) EA.OnGlow("SPELL_ACTIVATION_OVERLAY_GLOW_HIDE", id) end,
}
ev:SetScript("OnEvent", function(_, event, ...)
  if event == "ADDON_LOADED" then
    if ... ~= ADDON then return end
    db = Core.Migrate(KennyEightSecondArgumentDB, migrations, SCHEMA)
    KennyEightSecondArgumentDB = db
    row = FS.Register(KEY, db, { title = L["Eight Second Argument"], slash = EA.Slash, help = "debug", debug = Core.PrintDebug })
    Core.SafeCall("refresh", refresh)
    return
  end
  local h = handlers[event]
  if h and db then Core.SafeCall(event, h, ...) end
end)

Core.Setup({ cmd = "/frost lance",
  required = { "C_Timer.After" },
  optional = { "C_UnitAuras.GetUnitAuraBySpellID", "C_UnitAuras.GetPlayerAuraBySpellID", "C_Secrets.HasSecretRestrictions",
    "C_Secrets.GetSpellAuraSecrecy", "C_Secrets.ShouldSpellAuraBeSecret", "C_Secrets.GetSpellCastSecrecy",
    "C_SpellActivationOverlay.IsSpellOverlayed", "C_SpellBook.IsSpellKnown", "IsPlayerMoving" },
  db = function() return db end,
  firstRun = { L["Eight Second Argument is ready: LANCE, BLAST or WAIT for Ice Lance and Fire Blast's shared cooldown."] },
  debugLines = function() return EA.DetectionLines() end })
