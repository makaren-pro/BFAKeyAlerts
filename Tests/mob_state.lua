-- Observed mob auras, power/absorbs, native health ticks, and confirmed fixates.
local now = 1
local function equal(actual, expected, message)
    if type(actual) == "number" and type(expected) == "number" and math.abs(actual - expected) < 0.001 then return end
    assert(actual == expected, (message or "values differ") .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual))
end
local units = {
    player = "Player-self", party1 = "Player-target",
    nameplate1 = "Creature-0-1-0-0-136160-000001",
    nameplate2 = "Creature-0-1-0-0-133379-000002",
    nameplate3 = "Creature-0-1-0-0-133389-000003",
}
local auraData = {}
local auraCalls, absorbCalls, powerCalls = 0, 0, {}
local absorbs = { nameplate1 = 1250, nameplate2 = -2, nameplate3 = 0 / 0 }
local dead = {}
local function makeFrame(name, parent)
    local frame = { name = name, parent = parent, shown = true, mouse = true, points = {} }
    function frame:EnableMouse(value) self.mouse = value end
    function frame:SetMouseClickEnabled(value) self.mouseClick = value end
    function frame:SetSize(w, h) self.width, self.height = w, h end
    function frame:SetHeight(value) self.height = value end
    function frame:SetFrameLevel(value) self.frameLevel = value end
    function frame:GetFrameLevel() return self.frameLevel or 5 end
    function frame:GetReverseFill() return self.reverseFill == true end
    function frame:SetMinMaxValues(minimum, maximum) self.minimum, self.maximum = minimum, maximum end
    function frame:SetValue(value) self.value = value end
    function frame:SetStatusBarColor(...) self.statusColor = { ... } end
    function frame:SetStatusBarTexture(value) self.statusTexture = value end
    function frame:GetWidth() return self.width or 200 end
    function frame:GetHeight() return self.height or 12 end
    function frame:GetParent() return self.parent end
    function frame:SetParent(value) self.parent = value end
    function frame:ClearAllPoints() self.points = {} end
    function frame:SetPoint(...) self.points[#self.points + 1] = { ... } end
    function frame:Show() self.shown = true end
    function frame:Hide() self.shown = false end
    function frame:IsShown() return self.shown end
    function frame:IsVisible() return self.shown end
    function frame:IsForbidden() return false end
    function frame:CreateTexture()
        local texture = {}
        function texture:SetTexture(value) self.texture = value end
        function texture:SetPoint(...) self.points = { ... } end
        function texture:SetAllPoints() end
        function texture:SetColorTexture(...) self.color = { ... } end
        return texture
    end
    function frame:CreateFontString()
        local text = {}
        function text:SetPoint() end
        function text:SetText(value) self.value = value end
        function text:Show() self.shown = true end
        function text:Hide() self.shown = false end
        function text:SetTextColor() end
        return text
    end
    return frame
end

wipe = function(value) for key in pairs(value) do value[key] = nil end end
CreateFrame = function(_, name, parent) return makeFrame(name, parent) end
GetTime = function() return now end
UnitExists = function(unit) return units[unit] ~= nil end
UnitGUID = function(unit) return units[unit] end
UnitIsDeadOrGhost = function(unit) return dead[unit] == true end
UnitCanAttack = function(_, unit) return string.match(unit or "", "^nameplate") ~= nil end
UnitName = function(unit)
    if unit == "party1" then return "Test-Target" end
    return unit
end
UnitClass = function(unit) if unit == "party1" then return "Тестовый класс", "MAGE" end end
RAID_CLASS_COLORS = { MAGE = { r = 0.41, g = 0.8, b = 0.94 } }
GetSpellTexture = function(spellID) return "spell-" .. tostring(spellID) end
UnitGetTotalAbsorbs = function(unit) absorbCalls = absorbCalls + 1; return absorbs[unit] end
UnitPower = function(unit, powerType)
    powerCalls[#powerCalls + 1] = { unit = unit, type = powerType }
    if unit == "nameplate2" then return 7 end
    if powerType == 10 then return 56 end
    return 12
end
UnitPowerMax = function(unit, powerType)
    powerCalls[#powerCalls + 1] = { unit = unit, type = powerType, maximum = true }
    if unit == "nameplate2" then return 13 end
    if powerType == 10 then return 100 end
    return 20
end
UnitHealth = function() return 720 end
UnitHealthMax = function() return 1000 end
UnitAura = function(unit, index, filter)
    auraCalls = auraCalls + 1
    local list = auraData[unit] or {}
    local aura = list[index]
    if not aura then return nil end
    return aura.name, aura.icon, 0, aura.dispelType, aura.duration or 0,
        aura.expiration or 0, aura.source, aura.stealable, false, aura.spellID
end

local hosts = {}
local function newHost(guid, unit)
    local host = makeFrame("host-" .. unit)
    host.ownerGUID, host.unit, host.groups = guid, unit, {}
    return host
end
local plates = {}
for index = 1, 3 do
    local unit = "nameplate" .. index
    local unitFrame = makeFrame("UnitFrame-" .. unit)
    local healthBar = makeFrame("HealthBar-" .. unit, unitFrame)
    healthBar.width = 200
    healthBar.height = 12
    healthBar.frameLevel = 90
    unitFrame.healthBar = healthBar
    local plate = makeFrame("Plate-" .. unit)
    plate.UnitFrame = unitFrame
    local overlay = makeFrame("NameplateOverlay-" .. unit, plate)
    plates[unit] = overlay
end

BFAKeyAlerts = {
    active = true, db = { enabled = true, showNameplates = true, mobState = { enabled = true, absorb = true,
        power = true, immunity = true, fixate = true, thresholds = true, purge = true } },
    L = function(_, key)
        local labels = { CI_SHIELD_BADGE = "SH", CI_INTERRUPT_IMMUNE_BADGE = "×I", CI_INTERRUPT_BADGE = "I", CI_DR_BADGE = "DR",
            CI_PURGE_BADGE = "P", CI_STEAL_BADGE = "S", CI_IMMUNE_BADGE = "IMM",
            CI_FIXATE_BADGE = "F", CI_POWER_BADGE = "PWR" }
        return labels[key] or key
    end,
    ShortUnitName = function(_, name) return string.match(name, "^([^-]+)") or name end,
    GetNPCID = function(_, guid) return tonumber(string.match(guid, "(%d+)%-%x+$")) or tonumber(string.match(guid, "(%d+)%-%d+$")) end,
    Targets = { guidToUnit = {} },
    PartyFrameTargets = {},
    Nameplates = { GetOverlay = function(_, unit) return plates[unit] end },
    CombatIntelligence = {
        hosts = {},
        GetHost = function(self, unit)
            local guid = UnitGUID(unit)
            local host = self.hosts[unit]
            if not host or host.ownerGUID ~= guid then host = newHost(guid, unit); self.hosts[unit] = host end
            return host
        end,
        GetRows = function(_, host, key, count)
            local rows = host.groups[key] or {}
            host.groups[key] = rows
            for index = 1, count do
                if not rows[index] then
                    local row = makeFrame("row-" .. index, host)
                    row.icon = row:CreateTexture()
                    row.text = row:CreateFontString()
                    rows[index] = row
                end
                rows[index]:Show()
            end
            for index = count + 1, #rows do rows[index]:Hide() end
            return rows
        end,
        HideRows = function(_, host, key)
            for _, row in ipairs(host.groups[key] or {}) do row:Hide() end
        end,
    },
}
local BKA = BFAKeyAlerts
for guid, unit in pairs({ [units.nameplate1] = "nameplate1", [units.nameplate2] = "nameplate2", [units.nameplate3] = "nameplate3" }) do
    BKA.Targets.guidToUnit[guid] = unit
end
function BKA:IsPlayerOrPartyGUID(guid) return guid == "Player-self" or guid == "Player-target" end
function BKA.PartyFrameTargets:GetUnitForGUID(guid) if guid == "Player-target" then return "party1" end end

local hostileAuras = {
    { name = "Tectonic Barrier", icon = "aura-263215", dispelType = nil, spellID = 263215 },
    { name = "Protective Aura", icon = "aura-267981", dispelType = nil, spellID = 267981 },
    { name = "Earth Shield", icon = "aura-268709", dispelType = "Magic", spellID = 268709 },
    { name = "Earth Shield duplicate", icon = "ignored", dispelType = "Magic", spellID = 268709 },
}
auraData.nameplate1 = hostileAuras
auraData.nameplate2 = {}
auraData.nameplate3 = {}
auraData.party1 = {}
dofile("MobStatePolicies.lua")
dofile("MobState.lua")
local state = BKA.MobState
state:Refresh()
state:Update(now)

local dazar = state.entries[units.nameplate1]
assert(dazar and dazar.host and dazar.host.stateFrame.shown, "Dazar state host is active")
equal(dazar.host.stateFrame.points[1][2], plates.nameplate1.parent.UnitFrame.healthBar, "mob badges anchor outside the native health bar")
equal(#dazar.auras, 3, "supported auras dedupe by spell ID and cap at three")
equal(dazar.auras[1].spellID, 267981, "damage reduction aura sorts first")
assert(string.find(dazar.auras[2].text, "×I", 1, true) and string.find(dazar.auras[2].text, "SH", 1, true),
    "Tectonic Barrier is shield plus interrupt immunity, not generic immunity")
assert(string.find(dazar.auras[3].text, "P", 1, true), "verified live Magic Earth Shield can be purged")
equal(state.entries[units.nameplate1].absorbs, 1250, "real nonnegative absorb total is used")
equal(dazar.host.groups.mobState[4].text.value, "SH 1250", "absorb total is surfaced")
equal(#dazar.host.stateFrame.thresholdTicks, 3, "Dazar thresholds attach to native health bar")
equal(dazar.host.stateFrame.thresholdTicks[1].points[1][4], 160, "80 percent tick uses native bar width")
equal(dazar.host.stateFrame.thresholdTicks[2].points[1][4], 120, "60 percent tick uses native bar width")
equal(dazar.host.stateFrame.thresholdTicks[3].points[1][4], 80, "40 percent tick uses native bar width")
equal(dazar.host.stateFrame.thresholdTicks[1].parent, dazar.host.stateFrame, "tick widget is parented to pooled satellite")
equal(dazar.host.stateFrame.thresholdTicks[1].frameLevel, 95, "threshold tick draws above the native BFA health bar")

local adderis = state.entries[units.nameplate2]
local galvazzt = state.entries[units.nameplate3]
equal(adderis.absorbs, nil, "negative absorbs are rejected")
equal(galvazzt.absorbs, nil, "non-finite absorbs are rejected")
equal(adderis.power.current, 7, "Adderis reads actual default power")
equal(adderis.power.maximum, 13, "Adderis uses real maximum, not 100")
equal(galvazzt.power.current, 56, "Galvazzt reads alternate power type 10")
equal(galvazzt.power.maximum, 100, "Galvazzt uses UnitPowerMax type 10")
equal(powerCalls[1].type, nil, "Adderis uses default UnitPower type")
local hasAlternatePower = false
for _, call in ipairs(powerCalls) do if call.unit == "nameplate3" and call.type == 10 then hasAlternatePower = true end end
assert(hasAlternatePower, "Galvazzt requests actual alternate type")
equal(adderis.host.stateFrame.powerBar.maximum, 13, "power bar uses actual maximum")

-- Unknown auras and cast-derived predictions cannot invent defensive state.
auraData.nameplate1 = { { name = "Unknown immunity", icon = "unknown", spellID = 999001 } }
state:OnEvent("UNIT_AURA", "nameplate1")
now = 1.1
state:Update(now)
equal(#dazar.auras, 0, "unknown aura does not create immunity or shield state")
assert(not BKA.MobStatePolicies.auras[999001], "policy has no invented generic immunity seed")

-- Live isStealable is S; a non-Magic shield is not labeled purgeable.
auraData.nameplate1 = {
    { name = "Lightning Shield", icon = "lightning", spellID = 263246, stealable = true },
    { name = "Earth Shield", icon = "earth", dispelType = "Curse", spellID = 268709 },
}
state:OnEvent("UNIT_AURA", "nameplate1")
now = 1.21
state:Update(now)
local lightning, earth
for _, aura in ipairs(dazar.auras) do
    if aura.spellID == 263246 then lightning = aura end
    if aura.spellID == 268709 then earth = aura end
end
assert(lightning and string.find(lightning.text, "S", 1, true), "live stealable aura uses S")
assert(earth and not string.find(earth.text, "P", 1, true), "non-Magic aura is not labeled purgeable")

-- A confirmed distinct-source fixate is tracked; self-buffs and unrelated targets are ignored.
local adderisGUID = units.nameplate2
state:OnCombatLog("SPELL_AURA_APPLIED", adderisGUID, adderisGUID, 257314)
equal(state.fixates[adderisGUID], nil, "self-buff is not a fixate")
state:OnCombatLog("SPELL_AURA_APPLIED", adderisGUID, "Player-target", 257314)
assert(state.fixates[adderisGUID], "confirmed mob-to-party fixate is retained")
auraData.party1 = { { name = "Black Powder Bomb", icon = "fixate", source = "nameplate2", spellID = 257314 } }
now = 1.72
state:Update(now)
local adderisFixateRows = adderis.host.groups.mobState
local fixateFound = false
for _, row in ipairs(adderisFixateRows) do
    if string.find(row.text.value or "", "F ", 1, true) and string.find(row.text.value or "", "Test", 1, true) then fixateFound = true end
end
assert(fixateFound, "fixate shows the validated target on the source mob")
local coloredFixate = false
for _, row in ipairs(adderisFixateRows) do
    if string.find(row.text.value or "", "|cff", 1, true) and string.find(row.text.value or "", "Test", 1, true) then coloredFixate = true end
end
assert(coloredFixate, "party fixate target uses its class color")
state:OnCombatLog("SPELL_AURA_REMOVED", adderisGUID, "Player-target", 257314)
now = 2.22
state:Update(now)
equal(state.fixates[adderisGUID], nil, "fixate removal clears source state")

-- Event-driven aura scans are throttled, while the two-second fallback eventually refreshes.
local scans = auraCalls
now = 2.3
state:Update(now)
equal(auraCalls, scans, "sub-interval update does not rescan auras")
now = 4.3
state:Update(now)
assert(auraCalls > scans, "throttled fallback rescans stale aura state")

-- Reverse-fill native bars place the same threshold from the right edge.
plates.nameplate1.parent.UnitFrame.healthBar.reverseFill = true
state:OnEvent("UNIT_HEALTH_FREQUENT", "nameplate1")
now = 4.8
state:Update(now)
equal(dazar.host.stateFrame.thresholdTicks[1].points[1][4], 40, "reverse-fill 80 percent tick is mirrored")
equal(dazar.host.stateFrame.thresholdTicks[3].points[1][4], 120, "reverse-fill 40 percent tick is mirrored")

-- Recycled GUID and death cleanup hide pooled rows/ticks without touching native bars.
local savedHost = dazar.host
units.nameplate1 = "Creature-0-1-0-0-999999-000004"
state:RemoveUnit("nameplate1")
equal(state.entries["Creature-0-1-0-0-136160-000001"], nil, "RemoveUnit clears the previous owner after token recycle")
now = 5.3
state:Update(now)
equal(state.entries["Creature-0-1-0-0-136160-000001"], nil, "recycled nameplate loses old entry")
equal(savedHost.stateFrame.shown, false, "recycled host hides satellite state and threshold ticks")
state:OnCombatLog("UNIT_DIED", nil, adderisGUID, nil)
equal(state.entries[adderisGUID], nil, "death removes mob state")
equal(state.fixates[adderisGUID], nil, "death removes fixate state")

state:Clear()
equal(next(state.entries), nil, "Clear drops all mob entries")
equal(next(state.fixates), nil, "Clear drops all fixates")

-- Configuration switches gate their own displays without invented replacement values.
now = 5.8
units.nameplate1 = "Creature-0-1-0-0-136160-000001"
auraData.nameplate1 = { { name = "Tectonic Barrier", icon = "aura-263215", spellID = 263215 } }
BKA.Targets.guidToUnit[units.nameplate1] = "nameplate1"
BKA.db.mobState.absorb = false
BKA.db.mobState.power = false
BKA.db.mobState.immunity = false
BKA.db.mobState.purge = false
BKA.db.mobState.thresholds = false
state:SettingsChanged()
now = 6.3
state:Update(now)
local toggled = state.entries[units.nameplate1]
assert(toggled and toggled.absorbs == nil and toggled.power == nil, "absorb and power toggles suppress reads")
equal(#toggled.auras, 0, "aura-state toggle suppresses shields, reduction and immunity tags")
assert(not toggled.host.stateFrame.thresholdTicks[1].shown, "threshold toggle hides native-bar ticks")
print("mob_state: PASS")
