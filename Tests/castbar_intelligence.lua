-- Native castbar cooldown readiness ticks only.
local now = 10
local playerClass, playerKnown, petKnown = "MAGE", true, false
local dead, connected = {}, {}
local units = { player = "Player-1", pet = "Pet-1", nameplate1 = "Creature-0-1-0-0-130000-000001" }
local function equal(actual, expected, message)
    if type(actual) == "number" and type(expected) == "number" and math.abs(actual - expected) < 0.001 then return end
    assert(actual == expected, (message or "values differ") .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual))
end

local function makeFrame(name, parent)
    local frame = { name = name, parent = parent, shown = true, mouse = true, points = {}, frameLevel = 10 }
    function frame:EnableMouse(value) self.mouse = value end
    function frame:SetSize(width, height) self.width, self.height = width, height end
    function frame:SetWidth(value) self.width = value end
    function frame:SetHeight(value) self.height = value end
    function frame:GetWidth() return self.width or 100 end
    function frame:GetHeight() return self.height or 10 end
    function frame:SetFrameLevel(value) self.frameLevel = value end
    function frame:GetFrameLevel() return self.frameLevel end
    function frame:GetParent() return self.parent end
    function frame:SetParent(parentValue) self.parent = parentValue end
    function frame:ClearAllPoints() self.points = {} end
    function frame:SetPoint(...) self.points[#self.points + 1] = { ... } end
    function frame:Show() self.shown = true end
    function frame:Hide() self.shown = false end
    function frame:IsShown() return self.shown end
    function frame:IsVisible() return self.shown end
    function frame:IsForbidden() return self.forbidden == true end
    function frame:GetReverseFill() return self.reverseFill == true end
    function frame:SetMinMaxValues(minimum, maximum) self.minimum, self.maximum = minimum, maximum end
    function frame:SetValue(value) self.value = value end
    function frame:SetStatusBarTexture(value) self.statusTexture = value end
    function frame:SetStatusBarColor(...) self.statusColor = { ... } end
    function frame:CreateTexture()
        local texture = {}
        function texture:SetSize(width, height) self.width, self.height = width, height end
        function texture:SetPoint(...) self.points = { ... } end
        function texture:SetAllPoints() end
        function texture:SetTexture(value) self.texture = value end
        function texture:SetColorTexture(...) self.color = { ... } end
        return texture
    end
    function frame:CreateFontString()
        local text = {}
        function text:SetPoint(...) self.points = { ... } end
        function text:SetJustifyH(value) self.justify = value end
        function text:SetText(value) self.value = value end
        return text
    end
    return frame
end

GetTime = function() return now end
UnitExists = function(unit) return units[unit] ~= nil end
UnitGUID = function(unit) return units[unit] end
UnitClass = function(unit) if unit == "player" then return "Mage", playerClass end end
UnitGroupRolesAssigned = function() return "DAMAGER" end
UnitIsDeadOrGhost = function(unit) return dead[unit] == true end
UnitIsConnected = function(unit) return connected[unit] ~= false end
UnitCanAttack = function(_, unit) return string.match(unit or "", "^nameplate") ~= nil end
UnitName = function(unit) return unit end
IsSpellKnown = function(spellID, isPet) if spellID == 19647 and isPet then return petKnown end; return playerKnown end
IsPlayerSpell = function() return playerKnown end
GetSpellTexture = function(spellID) return "texture-" .. tostring(spellID) end
local cooldowns = { [2139] = { 10, 8, 1 }, [19647] = { 10, 8, 1 }, [61304] = { 10, 1.5, 1 } }
GetSpellCooldown = function(spellID)
    local value = cooldowns[spellID]
    if not value then return 0, 0, 1 end
    return value[1], value[2], value[3]
end
CreateFrame = function(_, name, parent) return makeFrame(name, parent) end

BFAKeyAlerts = {
    active = true,
    db = { enabled = true, showNameplates = true, castbarIntelligence = { enabled = true, interruptTick = true } },
}
local BKA = BFAKeyAlerts
local plates, hosts = {}, {}

local unitFrame = makeFrame("UnitFrame")
local native = makeFrame("NativeCastBar", unitFrame)
native:SetSize(200, 14)
unitFrame.castBar = native
local plate = makeFrame("Plate")
plate.UnitFrame = unitFrame
plates.nameplate1 = makeFrame("Overlay", plate)
BKA.Nameplates = { GetOverlay = function(_, unit) return plates[unit] end }
BKA.CombatIntelligence = {
    GetHost = function(_, unit)
        local guid = UnitGUID(unit)
        local host = hosts[unit]
        if not host then
            host = makeFrame("Host", plate)
            host.ownerGUID = guid
            hosts[unit] = host
        end
        host.ownerGUID = guid
        return host
    end,
}
BKA.ActiveCasts = { byUnit = {} }
dofile("GroupInterrupts.lua")
dofile("CastbarIntelligence.lua")
local tracker, intelligence = BKA.GroupInterrupts, BKA.CastbarIntelligence

-- The helper uses the same GCD correction and requires known spell/API state.
equal(tracker:GetPlayerInterruptReadyAt(now), 18, "actual player cooldown readiness is used")
cooldowns[2139] = { 10, math.huge, 1 }
equal(tracker:GetPlayerInterruptReadyAt(now), nil, "non-finite cooldowns are rejected")
cooldowns[2139] = { 10, 8, 1 }
cooldowns[2139] = { 10, 1.5, 1 }
equal(tracker:GetPlayerInterruptReadyAt(now), now, "GCD mirror is treated as immediately ready")
cooldowns[2139] = { 10, 8, 1 }
playerKnown = false
equal(tracker:GetPlayerInterruptReadyAt(now), nil, "unknown interrupt spell yields no readiness estimate")
playerKnown = true
local oldIsSpellKnown, oldIsPlayerSpell = IsSpellKnown, IsPlayerSpell
IsSpellKnown = nil
IsPlayerSpell = function(spellID) return spellID == 2139 end
equal(tracker:GetPlayerInterruptReadyAt(now), 18, "IsPlayerSpell provides guarded known-spell evidence")
IsSpellKnown, IsPlayerSpell = oldIsSpellKnown, oldIsPlayerSpell
dead.player = true
equal(tracker:GetPlayerInterruptReadyAt(now), nil, "dead player yields no readiness estimate")
dead.player = nil
connected.player = false
equal(tracker:GetPlayerInterruptReadyAt(now), nil, "disconnected player yields no readiness estimate")
connected.player = nil
GetSpellCooldown = nil
equal(tracker:GetPlayerInterruptReadyAt(now), nil, "missing cooldown API does not assume readiness")
GetSpellCooldown = function(spellID) local value = cooldowns[spellID]; return value[1], value[2], value[3] end

playerClass, playerKnown, petKnown = "WARLOCK", false, true
units.pet = "Pet-1"
equal(tracker:GetPlayerInterruptReadyAt(now), 18, "known warlock pet interrupt uses live pet cooldown")
dead.pet = true
equal(tracker:GetPlayerInterruptReadyAt(now), nil, "dead pet yields no warlock interrupt estimate")
dead.pet = nil
units.pet = nil
equal(tracker:GetPlayerInterruptReadyAt(now), nil, "missing pet yields no warlock interrupt estimate")

playerClass, playerKnown = "MAGE", true
local readiness = 18
local readinessReads = 0
tracker.GetPlayerInterruptReadyAt = function(_, sampleNow) readinessReads = readinessReads + 1; return readiness end
local ability = {
    castControl = "KICK", ccCapable = true, reflectable = true, purgeable = true, stealable = true,
    primaryAction = "AOE", action = "AOE", mechanic = "AOE",
}
local cast = {
    sourceGUID = units.nameplate1, spellID = 10001, startTime = 10, endTime = 20,
    texture = "cast-icon", isChannel = false, interruptibilityKnown = true, notInterruptible = false,
    resolution = { ability = ability, action = "AOE", nameplateAction = "AOE", controlAction = "KICK" },
}
BKA.ActiveCasts.byUnit.nameplate1 = cast
units.nameplate2 = units.nameplate1
plates.nameplate2 = plates.nameplate1
local aliasCast = {
    sourceGUID = units.nameplate2, spellID = 10002, startTime = 10, endTime = 20,
    texture = "alias-icon", isChannel = false, interruptibilityKnown = true, notInterruptible = false,
    resolution = { ability = { action = "CAST" }, action = "CAST", nameplateAction = "CAST" },
}
BKA.ActiveCasts.byUnit.nameplate2 = aliasCast
intelligence:Update(now, true)
local entry = intelligence.entries[units.nameplate1]
local frame = hosts.nameplate1.castFrame
assert(entry and frame and frame.shown, "active cast attaches a pooled satellite")
equal(entry.unit, "nameplate1", "duplicate boss aliases choose the lowest stable plate token")
local activeCount = 0
for _ in pairs(intelligence.entries) do activeCount = activeCount + 1 end
equal(activeCount, 1, "duplicate GUID casts share one pooled entry")
assert(frame.tick.shown, "ready tick appears inside interruptible cast")
equal(frame.tick.points[1][4], 160, "normal cast tick uses elapsed native-bar fraction")
assert(frame.tick.frameLevel >= native.frameLevel + 5, "native overlay tick is raised above cast bar")
intelligence:Update(10.01, true)
equal(frame.points[1][2], native, "readiness tick overlay remains anchored to the native castbar")
assert(frame.mouse == false and frame.tick.mouse == false, "tick overlay controls are mouse-disabled")
equal(native.value, nil, "native cast bar is not modified")
equal(readinessReads, 2, "player cooldown readiness is read once on each update, not per cast")
BKA.ActiveCasts.byUnit.nameplate2 = nil

-- Suppressed policies still suppress the readiness tick.
cast.resolution = { ability = { action = "FRONTAL", primaryAction = "FRONTAL" }, action = "FRONTAL", nameplateAction = "FRONTAL" }
readiness = nil
intelligence:Update(10.1, true)
assert(not frame.tick.shown, "cast without KICK policy has no player interrupt tick")
cast.resolution = { ability = { castControl = "KICK", reflectable = false }, action = "KICK", nameplateAction = "KICK",
    policy = { policy = "IGNORE" } }
readiness = 18
intelligence:Update(10.2, true)
assert(not frame.shown and not frame.tick.shown, "ignored policy suppresses the readiness tick")
cast.resolution = { ability = { reflectable = false, action = "CAST" }, action = "CAST", nameplateAction = "CAST" }
intelligence:Update(10.3, true)
cast.resolution = nil
intelligence:Update(10.32, true)
assert(frame.tick.shown, "missing resolution does not suppress confirmed interruptibility facts")

-- The readiness tick follows API facts even when the ability is not tagged as a kick.
cast.resolution = { ability = { action = "AOE" }, action = "AOE", nameplateAction = "AOE" }
readiness = 18
intelligence:Update(10.35, true)
assert(frame.tick.shown, "actual interruptibility supports a tick without guessed kick metadata")
BKA.db.castbarIntelligence.interruptTick = false
intelligence:Update(10.37, true)
assert(not frame.tick.shown and not frame.shown, "disabled tick option hides the overlay")
BKA.db.castbarIntelligence.interruptTick = true

-- Interruptibility and ready-at boundaries are strict; a channel uses native remaining-time direction.
cast.resolution = { ability = { castControl = "KICK" }, action = "KICK", nameplateAction = "KICK" }
cast.isChannel = true
readiness = 16
intelligence:Update(10.4, true)
equal(frame.tick.points[1][4], 80, "native channel tick uses remaining-time fraction")
native.reverseFill = true
intelligence:Update(10.5, true)
equal(frame.tick.points[1][4], 120, "reverse-filled native bar mirrors channel tick")
native.reverseFill = false
cast.interruptibilityKnown = false
intelligence:Update(10.6, true)
assert(not frame.tick.shown, "unknown interruptibility hides the tick")
cast.interruptibilityKnown, cast.notInterruptible = true, true
intelligence:Update(10.7, true)
assert(not frame.tick.shown, "uninterruptible cast hides the tick")
cast.notInterruptible = false
readiness = cast.endTime
intelligence:Update(10.8, true)
assert(not frame.tick.shown, "readiness exactly at cast end is outside the bar")

-- Without a usable native Blizzard bar, there is no standalone substitute.
unitFrame.castBar = nil
cast.isChannel = true
readiness = 18
intelligence:Update(12, true)
assert(not frame.shown and not frame.tick.shown, "missing native bar hides the readiness overlay")
unitFrame.castBar = native
native:Hide()
intelligence:Update(12.01, true)
assert(not frame.shown and not frame.tick.shown, "hidden native bar hides the readiness overlay")
native:Show()
native.forbidden = true
intelligence:Update(12.02, true)
assert(not frame.shown and not frame.tick.shown, "forbidden native bar hides the readiness overlay")
native.forbidden = false
intelligence:Update(12.03, true)
assert(frame.shown and frame.tick.shown, "valid native bar restores the readiness overlay")

-- Stop, recycle, death, and settings changes hide the same pooled satellite immediately.
BKA.ActiveCasts.byUnit.nameplate1 = nil
intelligence:CastsChanged()
assert(not frame.shown and intelligence.entries[units.nameplate1] == nil, "cast stop clears satellite immediately")
BKA.ActiveCasts.byUnit.nameplate1 = cast
intelligence:Update(12.1, true)
units.nameplate1 = "Creature-0-1-0-0-130001-000002"
intelligence:Update(12.2, true)
assert(not frame.shown and intelligence.entries["Creature-0-1-0-0-130000-000001"] == nil, "GUID recycle clears previous cast owner")
units.nameplate1 = "Creature-0-1-0-0-130000-000001"
BKA.ActiveCasts.byUnit.nameplate1 = cast
intelligence:Update(12.3, true)
dead.nameplate1 = true
intelligence:Update(12.4, true)
assert(not frame.shown and next(intelligence.entries) == nil, "dead unit clears cast satellite")
dead.nameplate1 = nil
BKA.ActiveCasts.byUnit.nameplate1 = cast
intelligence:Update(12.5, true)
BKA.db.castbarIntelligence.enabled = false
intelligence:SettingsChanged()
assert(not frame.shown and next(intelligence.entries) == nil, "feature toggle clears pooled cast state")

BKA.db.castbarIntelligence.enabled = true
intelligence:SettingsChanged()
BKA.db.castbarIntelligence.enabled = true
BKA.ActiveCasts.byUnit.nameplate1 = cast
intelligence:Update(13, true)
cast.endTime = 12.9
intelligence:Update(13.1, true)
assert(not frame.shown and next(intelligence.entries) == nil, "expired cast is removed without a stop event")

print("castbar_intelligence: PASS")
