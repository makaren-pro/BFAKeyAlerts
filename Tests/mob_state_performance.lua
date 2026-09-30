-- Workload regression for the mob state cadence with a full set of 20 hostile plates.
-- Run from the addon root with Lua 5.1: lua Tests/mob_state_performance.lua
local now = 100
local plateCount = 20
local unitGUIDs, auraData = {}, {}
local auraCalls, resourceCalls, spellLookups = {}, { absorbs = 0, power = 0, powerMax = 0 }, 0
local nativeFrameCreations, rowCreations = 0, 0

local function equal(actual, expected, message)
    assert(actual == expected, (message or "values differ") .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual))
end

local function makeFrame(name, parent)
    local frame = { name = name, parent = parent, shown = true, points = {} }
    function frame:EnableMouse() end
    function frame:SetSize(width, height) self.width, self.height = width, height end
    function frame:SetHeight(height) self.height = height end
    function frame:SetMinMaxValues(minimum, maximum) self.minimum, self.maximum = minimum, maximum end
    function frame:SetValue(value) self.value = value end
    function frame:SetStatusBarTexture(value) self.statusTexture = value end
    function frame:SetStatusBarColor(...) self.statusColor = { ... } end
    function frame:GetWidth() return self.width or 200 end
    function frame:GetParent() return self.parent end
    function frame:SetParent(value) self.parent = value end
    function frame:ClearAllPoints() self.points = {} end
    function frame:SetPoint(...) self.points[#self.points + 1] = { ... } end
    function frame:Show() self.shown = true end
    function frame:Hide() self.shown = false end
    function frame:IsShown() return self.shown end
    function frame:CreateTexture()
        local texture = {}
        function texture:SetTexture(value) self.texture = value end
        return texture
    end
    function frame:CreateFontString()
        local font = {}
        function font:SetText(value) self.value = value end
        return font
    end
    return frame
end

wipe = function(value) for key in pairs(value) do value[key] = nil end end
CreateFrame = function(kind, name, parent)
    nativeFrameCreations = nativeFrameCreations + 1
    return makeFrame(kind .. ":" .. tostring(name), parent)
end
GetTime = function() return now end
UnitExists = function(unit) return unitGUIDs[unit] ~= nil end
UnitGUID = function(unit) return unitGUIDs[unit] end
UnitIsDeadOrGhost = function() return false end
UnitCanAttack = function(_, unit) return unitGUIDs[unit] ~= nil end
UnitName = function(unit) return unit end
UnitAura = function(unit, index)
    auraCalls[unit] = (auraCalls[unit] or 0) + 1
    local aura = (auraData[unit] or {})[index]
    if not aura then return nil end
    return aura.name, aura.icon, 0, nil, 0, 0, nil, nil, false, aura.spellID
end
UnitGetTotalAbsorbs = function() resourceCalls.absorbs = resourceCalls.absorbs + 1; return 10 end
UnitPower = function() resourceCalls.power = resourceCalls.power + 1; return 5 end
UnitPowerMax = function() resourceCalls.powerMax = resourceCalls.powerMax + 1; return 10 end
GetSpellTexture = function() spellLookups = spellLookups + 1; return "spell" end

local hosts, overlays = {}, {}
local BFAKeyAlerts = {
    active = true,
    db = { enabled = true, showNameplates = true, mobState = { enabled = true } },
    L = function(_, key) return key end,
    GetNPCID = function() return 133379 end,
    Targets = { guidToUnit = {} },
    Nameplates = { GetOverlay = function(_, unit) return overlays[unit] end },
    CombatIntelligence = {
        GetHost = function(self, unit)
            local guid = UnitGUID(unit)
            local host = hosts[unit]
            if not host or host.ownerGUID ~= guid then
                host = makeFrame("host:" .. unit)
                host.ownerGUID, host.unit, host.groups = guid, unit, {}
                hosts[unit] = host
            end
            return host
        end,
        GetRows = function(_, host, key, count)
            local rows = host.groups[key] or {}
            host.groups[key] = rows
            for index = 1, count do
                if not rows[index] then
                    rowCreations = rowCreations + 1
                    local row = makeFrame("row:" .. index, host)
                    row.icon, row.text = row:CreateTexture(), row:CreateFontString()
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
_G.BFAKeyAlerts = BFAKeyAlerts
function BFAKeyAlerts:IsPlayerOrPartyGUID() return false end

for index = 1, plateCount do
    local unit = "nameplate" .. index
    local guid = "Creature-0-1-0-0-133379-" .. string.format("%06d", index)
    unitGUIDs[unit] = guid
    BFAKeyAlerts.Targets.guidToUnit[guid] = unit
    auraData[unit] = {
        { name = "Tectonic Barrier", icon = "barrier", spellID = 263215 },
        { name = "Protective Aura", icon = "reduction", spellID = 267981 },
    }
    -- Native nameplate objects exist before addon frame accounting begins.
    local unitFrame = makeFrame("unitFrame:" .. unit)
    unitFrame.healthBar = makeFrame("healthBar:" .. unit, unitFrame)
    local plate = makeFrame("plate:" .. unit)
    plate.UnitFrame = unitFrame
    overlays[unit] = makeFrame("overlay:" .. unit, plate)
end

dofile("MobStatePolicies.lua")
dofile("MobState.lua")
local state = BFAKeyAlerts.MobState
state:Refresh()
state:Update(now)

local function totalAuraCalls()
    local total = 0
    for _, count in pairs(auraCalls) do total = total + count end
    return total
end
local function counters()
    return totalAuraCalls(), resourceCalls.absorbs, resourceCalls.power, resourceCalls.powerMax,
        spellLookups, nativeFrameCreations, rowCreations
end
local function noChange(before, message)
    local after = { counters() }
    for index = 1, #before do equal(after[index], before[index], message) end
end

-- Two real auras plus the terminating nil query: exactly three API calls per plate.
for index = 1, plateCount do
    equal(auraCalls["nameplate" .. index], 3, "initial scan is bounded by actual auras plus terminator")
end
equal(totalAuraCalls(), plateCount * 3, "initial aura workload is bounded")
equal(resourceCalls.absorbs, plateCount, "initial resource fallback reads absorbs once per plate")
equal(resourceCalls.power, plateCount, "initial resource fallback reads power once per plate")
equal(resourceCalls.powerMax, plateCount, "initial resource fallback reads power maximum once per plate")
local initialNativeFrames, initialRows = nativeFrameCreations, rowCreations
equal(initialRows, plateCount * 4, "initial display pool has two auras and two resource rows per plate")

-- Shared 0.1-second updates through 0.4 seconds must not poll any API or allocate UI.
for step = 1, 4 do
    now = 100 + step / 10
    local before = { counters() }
    state:Update(now)
    noChange(before, "sub-interval shared tick performs no API lookup or allocation")
end

-- The 0.5-second cadence reads live resources once per plate and leaves aura state cached.
for step = 5, 19 do
    now = 100 + step / 10
    local before = { counters() }
    state:Update(now)
    local tickNumber = math.floor(step / 5)
    equal(resourceCalls.absorbs, plateCount * (1 + tickNumber), "absorbs use only the 0.5-second resource cadence")
    equal(resourceCalls.power, plateCount * (1 + tickNumber), "power uses only the 0.5-second resource cadence")
    equal(resourceCalls.powerMax, plateCount * (1 + tickNumber), "power maximum uses only the 0.5-second resource cadence")
    equal(totalAuraCalls(), before[1], "no aura fallback before two seconds")
    equal(spellLookups, before[5], "shared ticks do not look up spell textures")
    equal(nativeFrameCreations, initialNativeFrames, "shared ticks do not allocate native frames")
    equal(rowCreations, initialRows, "shared ticks reuse pooled rows")
end

-- Exactly two seconds makes the fallback eligible; the pool must still be stable.
now = 102
local beforeFallback = { counters() }
state:Update(now)
equal(totalAuraCalls(), beforeFallback[1] + plateCount * 3, "two-second fallback scans each plate once")
equal(nativeFrameCreations, initialNativeFrames, "two-second fallback creates no frames")
equal(rowCreations, initialRows, "two-second fallback creates no rows")
equal(spellLookups, 0, "normal aura/resource workload makes no spell lookups")

-- A same-plate event burst coalesces to one delayed scan, and leaves other plates untouched.
local dirtyUnit = "nameplate7"
local beforeDirty = totalAuraCalls()
now = 102.05
state:OnEvent("UNIT_AURA", dirtyUnit)
state:OnEvent("UNIT_AURA", dirtyUnit)
state:OnEvent("UNIT_AURA", dirtyUnit)
now = 102.14
state:Update(now)
equal(totalAuraCalls(), beforeDirty, "dirty aura scan waits for the 0.1-second delay")
now = 102.15
state:Update(now)
equal(totalAuraCalls(), beforeDirty + 3, "coalesced dirty event scans one plate once")
for index = 1, plateCount do
    local unit = "nameplate" .. index
    local expected = index == 7 and 9 or 6
    equal(auraCalls[unit], expected, "dirty event scans only its own plate: " .. unit)
end

-- Repeated dirty notifications every 0.05 seconds keep producing due scans.
local scansBeforeStream = auraCalls[dirtyUnit]
for pulse = 1, 8 do
    local eventTime = 102.20 + (pulse - 1) * 0.05
    now = eventTime
    state:OnEvent("UNIT_AURA", dirtyUnit)
    now = eventTime + 0.05
    state:Update(now)
end
equal(auraCalls[dirtyUnit], scansBeforeStream + 4 * 3, "continuous dirty events cannot starve due scans")
for index = 1, plateCount do
    if index ~= 7 then equal(auraCalls["nameplate" .. index], 6, "continuous dirty stream leaves other plates cached") end
end

-- Removing every visible token hides its pooled rows and releases every GUID entry.
for index = 1, plateCount do state:RemoveUnit("nameplate" .. index) end
equal(next(state.entries), nil, "cleanup releases all GUID entries")
equal(next(state.fixates), nil, "cleanup leaves no fixate GUID state")
for index = 1, plateCount do
    local host = hosts["nameplate" .. index]
    for _, row in ipairs(host.groups.mobState or {}) do
        equal(row.shown, false, "cleanup hides every pooled row")
    end
    equal(host.stateFrame.ownerGUID, nil, "cleanup clears state-frame GUID ownership")
    equal(host.stateFrame.shown, false, "cleanup hides each state frame")
end

print("mob_state_performance: PASS")
