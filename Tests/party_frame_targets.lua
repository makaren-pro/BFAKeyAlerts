-- Confirmed target overlays and frame adapters. Run with Lua 5.1.
local now = 10
local addonLoaded = {}
wipe = function(value) for key in pairs(value) do value[key] = nil end end
local currentUnits = { player = "Player-A", party1 = "Player-B", party2 = "Player-C" }
local function makeFrame(name, unit, parent)
    local frame = { name = name, unit = unit, parent = parent, shown = true, mouse = true,
        points = {}, protected = true, attributes = { unit = unit } }
    function frame:EnableMouse(value) self.mouse = value end
    function frame:SetMouseClickEnabled(value) self.mouseClick = value end
    function frame:CreateTexture()
        local texture = {}
        function texture:SetAllPoints() end
        function texture:SetTexture(value) self.texture = value end
        function texture:SetColorTexture(r, g, b, a) self.color = { r, g, b, a } end
        function texture:ClearAllPoints() self.points = {} end
        function texture:SetPoint(...) self.points = self.points or {}; self.points[#self.points + 1] = { ... } end
        function texture:SetHeight(value) self.height = value end
        function texture:SetWidth(value) self.width = value end
        return texture
    end
    function frame:CreateFontString()
        local font = {}
        function font:SetPoint() end
        function font:SetText(value) self.value = value end
        function font:SetTextColor() end
        function font:SetShadowOffset() end
        function font:Show() self.shown = true end
        function font:Hide() self.shown = false end
        return font
    end
    function frame:SetSize(width, height) self.width, self.height = width, height end
    function frame:GetSize() return self.width, self.height end
    function frame:SetParent(value) self.parent = value end
    function frame:GetParent() return self.parent end
    function frame:SetFrameStrata(value) self.strata = value end
    function frame:GetFrameStrata() return "MEDIUM" end
    function frame:SetFrameLevel(value) self.level = value end
    function frame:GetFrameLevel() return 1 end
    function frame:ClearAllPoints() self.points = {} end
    function frame:SetPoint(...) self.points[#self.points + 1] = { ... } end
    function frame:SetAllPoints() end
    function frame:Show() self.shown = true end
    function frame:Hide() self.shown = false end
    function frame:IsShown() return self.shown end
    function frame:IsVisible() return self.shown end
    function frame:IsForbidden() return self.forbidden == true end
    function frame:GetName() return self.name end
    function frame:GetAttribute(key) return self.attributes[key] end
    function frame:SetScript(name, fn) self[name] = fn end
    function frame:RegisterEvent() end
    return frame
end

UIParent = makeFrame("UIParent")
local created = {}
CreateFrame = function(_, name, parent)
    local frame = makeFrame(name, nil, parent)
    created[#created + 1] = frame
    return frame
end
GetTime = function() return now end
UnitGUID = function(unit) return currentUnits[unit] end
UnitExists = function(unit) return currentUnits[unit] ~= nil end
UnitIsUnit = function(left, right) return currentUnits[left] ~= nil and currentUnits[left] == currentUnits[right] end
IsInRaid = function() return false end
IsAddOnLoaded = function(name) return addonLoaded[name] == true end
GetNumGroupMembers = function() return 3 end

local partyFrame = makeFrame("CompactPartyFrameMember1", "party1")
CompactPartyFrameMember1 = partyFrame
PlayerFrame = makeFrame("PlayerFrame", "player")
PartyMemberFrame1 = makeFrame("PartyMemberFrame1", "party2")

BFAKeyAlerts = {
    active = true, db = { enabled = true, partyFrameTargets = { enabled = true, maxSpells = 3,
        minSeverity = 3, iconSize = 18, anchor = 1, countdown = true } },
    severityRank = { LOW = 1, MEDIUM = 2, HIGH = 3, CRITICAL = 4 },
    colors = { HIGH = { 1, 0.36, 0.12 }, CRITICAL = { 1, 0.08, 0.08 } },
    ActiveCasts = { byUnit = {} },
    ResolveIcon = function(_, ability) return "icon-" .. tostring(ability.id) end,
    IsPlayerOrPartyGUID = function(_, guid) return guid == "Player-A" or guid == "Player-B" or guid == "Player-C" end,
}
dofile("PartyFrameTargets.lua")
dofile("PartyFrameAdapters/Blizzard.lua")
dofile("PartyFrameAdapters/VuhDo.lua")
dofile("PartyFrameAdapters/HealBot.lua")
local targets = BFAKeyAlerts.PartyFrameTargets

local function equal(actual, expected, label)
    assert(actual == expected, label .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual))
end

local function cast(sourceGUID, spellID, identity, severity, finish, targetGUID, confidence)
    return { sourceGUID = sourceGUID, spellID = spellID, identity = identity, startTime = 1,
        endTime = finish, targetGUID = targetGUID, targetConfidence = confidence or "CONFIRMED",
        texture = "texture-" .. identity,
        resolution = { severity = severity, ability = { id = spellID, severity = severity } } }
end

local high = cast("Creature-1", 50, "high", "CRITICAL", 20, "Player-B")
local earlySameSpellOtherSource = cast("Creature-2", 50, "other-source", "HIGH", 12, "Player-B")
local early = cast("Creature-3", 51, "early", "HIGH", 11, "Player-B")
local aliased = cast("Creature-4", 52, "alias", "HIGH", 18, "Player-B")
local predictionOnly = cast("Creature-5", 53, "prediction", "CRITICAL", 30, "Player-B", "PREDICTED")
local staleSource = cast("Creature-old", 54, "stale-source", "CRITICAL", 30, "Player-B")
local suppressed = cast("Creature-7", 55, "suppressed", "CRITICAL", 30, "Player-B")
suppressed.resolution.suppressAlert = true
BFAKeyAlerts.ActiveCasts.byUnit = {
    nameplate1 = high, boss1 = high, -- one cast indexed through two owned units is rendered once
    nameplate2 = earlySameSpellOtherSource,
    nameplate3 = early,
    nameplate4 = aliased,
    nameplate5 = predictionOnly,
    nameplate6 = staleSource,
    nameplate7 = suppressed,
}
currentUnits.nameplate1, currentUnits.nameplate2 = "Creature-1", "Creature-2"
currentUnits.nameplate3, currentUnits.nameplate4 = "Creature-3", "Creature-4"
currentUnits.nameplate5, currentUnits.nameplate6, currentUnits.nameplate7 = "Creature-5", "Creature-recycled", "Creature-7"
currentUnits.boss1 = "Creature-1"
targets:Refresh()

local binding = targets.bindings["Player-B"]
assert(binding and binding.adapter.name == "Blizzard", "Blizzard frame is used when optional healers are absent")
equal(binding.sourceFrame, partyFrame, "frame is validated by its actual unit attribute")
equal(binding.overlay:GetParent(), UIParent, "overlay is independent of protected frame parent")
equal(partyFrame.mouse, true, "source mouse handling remains untouched")
equal(partyFrame.points and #partyFrame.points or 0, 0, "source anchors remain untouched")
local rows = binding.overlay.rows
equal(rows[1].icon.texture, "texture-high", "highest severity cast sorts first")
equal(rows[2].icon.texture, "texture-early", "earliest confirmed cast sorts next")
equal(rows[3].icon.texture, "texture-other-source", "same spell from another source remains distinct")
equal(rows[1].count.value, "10.0", "countdown uses cast end time")
equal(rows[1].mouse, false, "overlay row is mouse disabled")
equal(rows[1].borders[1].color[1], 1, "severity colors are applied through a cached border")
equal(targets.candidates["Player-B"].casts[1].id == targets.candidates["Player-B"].casts[2].id, false,
    "different cast identities do not collapse")
for _, entry in ipairs(targets.candidates["Player-B"].casts) do
    assert(entry.id ~= "prediction" and entry.id ~= "stale-source" and entry.id ~= "suppressed",
        "predictions, suppressed resolutions, and recycled sources are excluded")
end

currentUnits.nameplate1 = "Creature-recycled"
targets:Refresh()
assert(targets.bindings["Player-B"], "live boss alias preserves a cast when its nameplate recycles")
currentUnits.nameplate1 = "Creature-1"

-- A visible VuhDo button wins selection only when its live unit attribute matches.
local vuhdoFrame = makeFrame("Vd2H3", "party1")
addonLoaded.VuhDo = true
VUHDO_getUnitButtons = function(unit)
    if unit == "party1" then return { vuhdoFrame } end
    return nil
end
targets:Refresh()
binding = targets.bindings["Player-B"]
equal(binding.adapter.name, "VuhDo", "visible VuhDo frame is preferred")
equal(binding.sourceFrame, vuhdoFrame, "VuhDo frame attached")
equal(vuhdoFrame.mouse, true, "VuhDo source input remains unchanged")
vuhdoFrame.forbidden = true
targets:Refresh()
equal(targets.bindings["Player-B"].adapter.name, "Blizzard", "forbidden healer frames are skipped")
vuhdoFrame.forbidden = false
targets:Refresh()

-- Recycled party tokens cannot retain a prior player's confirmed cast icons.
currentUnits.party1 = "Player-C"
targets:Refresh()
equal(targets.bindings["Player-B"], nil, "recycled frame drops old target overlay")
equal(vuhdoFrame.shown, true, "adapter does not hide or mutate the source frame")

-- Confirmed casts rebind to the new current target and obey configured bounds.
high.targetGUID, earlySameSpellOtherSource.targetGUID, early.targetGUID = "Player-C", "Player-C", "Player-C"
aliased.targetGUID = "Player-C"
targets:Refresh()
binding = targets.bindings["Player-C"]
assert(binding and binding.sourceFrame == vuhdoFrame, "confirmed new target uses its current healer frame")
equal(binding.overlay.rows[4], nil, "only three icon rows are allocated per overlay")
now = 21
targets:Update(now, true)
equal(targets.bindings["Player-C"], nil, "expired casts remove their target overlay")

-- Missing optional addons and stray globals are harmless; Blizzard fallback remains available.
addonLoaded.VuhDo = false
addonLoaded.HealBot = false
HealBot_Unit_Button1 = makeFrame("HealBot_Unit_Button1", "party1")
HealBot_Unit_Button1.attributes.unit = "party4"
currentUnits.party1 = "Player-B"
for _, item in ipairs({ high, earlySameSpellOtherSource, early, aliased }) do
    item.endTime, item.targetGUID = 30, "Player-B"
end
targets:Refresh()
binding = targets.bindings["Player-B"]
assert(binding and binding.adapter.name == "Blizzard", "unloaded HealBot globals are ignored")

-- HealBot and LibGetFrame are discovered on addon load and use their dot-call API.
addonLoaded.HealBot = true
local healBotFrame = makeFrame("HealBot_Action_HealUnit4", "party1")
LibStub = function(name, silent)
    if name ~= "LibGetFrame-1.0" or silent ~= true then return nil end
    return { GetUnitFrame = function(unit, options)
        equal(unit, "party1", "LibGetFrame receives the unit as its first argument")
        equal(options.returnAll, true, "LibGetFrame requests all matching frames")
        return { [healBotFrame] = "HealBot_Action_HealUnit4" }
    end }
end
targets.frame.OnEvent(targets.frame, "ADDON_LOADED", "HealBot")
binding = targets.bindings["Player-B"]
assert(binding and binding.adapter.name == "HealBot" and binding.sourceFrame == healBotFrame,
    "HealBot frame binds after addon load")

-- ActiveCasts stop lifecycle hook clears the overlay immediately.
dofile("ActiveCasts.lua")
local active = BFAKeyAlerts.ActiveCasts
BFAKeyAlerts.Sounds = { CancelCastIdentity = function() end }
BFAKeyAlerts.Nameplates = { ClearActive = function() end }
BFAKeyAlerts.Alerts = { Hide = function() end }
BFAKeyAlerts.targetDecisions = {}
BFAKeyAlerts.diagnostics = { confirmedPersonalTargets = 0 }
function BFAKeyAlerts:NormalizeFrontalBehavior() return "FIXED_FORWARD" end
function BFAKeyAlerts:IsTargetBasedFrontal() return false end
function BFAKeyAlerts:GetGroupRoleForGUID() return "DAMAGER" end
local changing = cast("Creature-1", 60, "changing", "CRITICAL", 30, nil, "NONE")
changing.targetConfidence = "NONE"
changing.resolution.ability.dynamicTarget = true
changing.units = {}
active.byUnit = { nameplate1 = changing }
targets:Refresh()
equal(active:ApplyConfirmedTarget(changing, { guid = "Player-B", name = "Bravo", role = "DAMAGER" }, "test"), true,
    "confirmed target is accepted")
assert(targets.bindings["Player-B"], "confirmed-target hook displays immediately")
equal(active:ApplyConfirmedTarget(changing, { guid = "Player-C", name = "Charlie", role = "DAMAGER" }, "test update"), true,
    "dynamic target update is accepted")
equal(targets.bindings["Player-B"], nil, "target change immediately removes the old frame overlay")
assert(targets.bindings["Player-C"], "target change immediately attaches the new frame")
active:ReleaseCast(changing)
equal(targets.bindings["Player-C"], nil, "cast stop hook clears immediately")

print("party_frame_targets: PASS")
