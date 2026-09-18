local BKA = BFAKeyAlerts
local Tracker = { observed = {}, baseline = {}, rows = {} }
BKA.GroupInterrupts = Tracker

local units = { "player", "party1", "party2", "party3", "party4" }
local UTILITY_SLOT_COUNT = 4
local UTILITY_AREA_WIDTH = 142

-- Interrupt cooldowns. Remote members are inferred from combat log; the player uses
-- the real API cooldown whenever possible.
local cooldowns = {
    [1766] = 15, [96231] = 15, [6552] = 15, [47528] = 15, [106839] = 15,
    [183752] = 15, [116705] = 15, [57994] = 12, [2139] = 24, [147362] = 24,
    [187707] = 15, [15487] = 45, [19647] = 24, [78675] = 60, [31935] = 15,

    -- High-value hard CC shown as compact utility icons.
    [853] = 60,       -- Hammer of Justice
    [119381] = 60,    -- Leg Sweep
    [91800] = 60,     -- Gnaw (Unholy ghoul)
    [19577] = 60,     -- Intimidation
    [113724] = 45,    -- Ring of Frost
    [179057] = 60,    -- Chaos Nova
    [46968] = 40,     -- Shockwave
    [192058] = 60,    -- Capacitor Totem
    [5211] = 60,      -- Mighty Bash
    [2094] = 120,     -- Blind
    [8122] = 60,      -- Psychic Scream
    [30283] = 60,     -- Shadowfury
    [115078] = 45,    -- Paralysis
    [115750] = 90,    -- Blinding Light
}

local aliases = { [93985] = 106839, [132409] = 19647 }
local primary = {
    ROGUE = 1766, PALADIN = 96231, WARRIOR = 6552, DEATHKNIGHT = 47528,
    DRUID = 106839, DEMONHUNTER = 183752, MONK = 116705, SHAMAN = 57994,
    MAGE = 2139, HUNTER = 147362, PRIEST = 15487, WARLOCK = 19647,
}

-- Keep this deliberately small: the HUD is for "what can save this pull right now",
-- not a full spellbook. Optional talent CC starts as unknown for remote players until
-- the addon sees it used, avoiding a false READY signal.
local classCC = {
    PALADIN = {
        { id = 853, badge = "CC" },
        { id = 115750, badge = "CC", optional = true },
    },
    MONK = {
        { id = 119381, badge = "CC" },
        { id = 115078, badge = "CC" },
    },
    DEATHKNIGHT = { { id = 91800, badge = "CC", spec = 252 } },
    HUNTER = { { id = 19577, badge = "CC", spec = 253 } },
    MAGE = { { id = 113724, badge = "CC", optional = true } },
    DEMONHUNTER = { { id = 179057, badge = "CC" } },
    WARRIOR = { { id = 46968, badge = "CC", optional = true } },
    SHAMAN = { { id = 192058, badge = "CC" } },
    DRUID = { { id = 5211, badge = "CC", optional = true } },
    ROGUE = { { id = 2094, badge = "CC" } },
    PRIEST = { { id = 8122, badge = "CC" } },
    WARLOCK = { { id = 30283, badge = "CC" } },
}

local READY = {0.31, 0.88, 0.69}
local COOLDOWN = {0.98, 0.62, 0.18}
local BLOCKED = {0.90, 0.30, 0.18}
local UNKNOWN = {0.43, 0.48, 0.56}
local KICK_ACCENT = {0.35, 0.83, 0.77}
local CC_ACCENT = {0.58, 0.46, 0.96}

local function challengeActive()
    if not (C_ChallengeMode and C_ChallengeMode.GetActiveChallengeMapID) then return false end
    local mapID = C_ChallengeMode.GetActiveChallengeMapID()
    return mapID and mapID > 0 or false
end

local function petUnit(unit)
    if unit == "player" then return "pet" end
    local index = string.match(unit or "", "party(%d+)")
    return index and ("partypet" .. index) or nil
end

local function groupSpec(unit)
    if unit == "player" then
        local index = GetSpecialization and GetSpecialization()
        return index and GetSpecializationInfo and GetSpecializationInfo(index) or nil
    end
    if GetInspectSpecialization then
        local id = GetInspectSpecialization(unit)
        if id and id > 0 then return id end
    end
end

local function knownPlayerSpell(spellID)
    if not IsSpellKnown then return true end
    return IsSpellKnown(spellID) or (IsPlayerSpell and IsPlayerSpell(spellID)) or false
end

local function spellName(spellID)
    return GetSpellInfo(spellID) or tostring(spellID)
end

local function spellIcon(spellID)
    return (GetSpellTexture and GetSpellTexture(spellID)) or "Interface\\Icons\\INV_Misc_QuestionMark"
end

local function lower(value)
    return string.lower(tostring(value or ""))
end

local function cooldownText(remaining)
    remaining = math.max(0, tonumber(remaining) or 0)
    if remaining <= 0 then return "" end
    if remaining < 10 then return string.format("%.1f", remaining) end
    return tostring(math.ceil(remaining))
end

function Tracker:GetPrimarySpell(unit)
    local _, class = UnitClass(unit)
    if not class then return nil end
    local healer = UnitGroupRolesAssigned and UnitGroupRolesAssigned(unit) == "HEALER"
    if healer and (class == "PALADIN" or class == "PRIEST" or class == "DRUID" or class == "MONK") then
        return nil
    end

    local spec = groupSpec(unit)
    local id = primary[class]
    if class == "DRUID" and spec == 102 then id = 78675 end
    if class == "HUNTER" and spec == 255 then id = 187707 end
    return id
end

function Tracker:GetAbilityDefinitions(unit)
    local _, class = UnitClass(unit)
    if not class then return nil, {} end
    local spec = groupSpec(unit)
    local primaryID = self:GetPrimarySpell(unit)
    local main = primaryID and {
        key = primaryID, spellID = primaryID, cooldown = cooldowns[primaryID] or 15,
        kind = "kick", badge = "K", assumeReady = true,
    } or nil

    local utilities = {}
    local seen = {}
    if primaryID then seen[primaryID] = true end

    -- Protection paladin gets Avenger's Shield as a second interrupt tool.
    if class == "PALADIN" and spec == 66 then
        utilities[#utilities + 1] = {
            key = 31935, spellID = 31935, cooldown = cooldowns[31935],
            kind = "kick", badge = "K", assumeReady = true,
        }
        seen[31935] = true
    end

    for _, definition in ipairs(classCC[class] or {}) do
        local specKnown = spec and spec > 0
        local specMatches = not definition.spec or not specKnown or definition.spec == spec
        if specMatches then
            local include = true
            if unit == "player" and definition.optional and not knownPlayerSpell(definition.id) then
                include = false
            end
            if include and not seen[definition.id] then
                local uncertainSpec = definition.spec and not specKnown
                utilities[#utilities + 1] = {
                    key = definition.id,
                    spellID = definition.id,
                    cooldown = cooldowns[definition.id] or 60,
                    kind = "cc",
                    badge = definition.badge or "CC",
                    assumeReady = definition.optional ~= true and not uncertainSpec,
                    optional = definition.optional == true or uncertainSpec,
                }
                seen[definition.id] = true
            end
        end
    end

    -- If Firestorm reports another tracked interrupt/CC from this player, keep it on
    -- the row instead of silently losing it after the first observation.
    local guid = UnitGUID(unit)
    for key in pairs(self.observed[guid] or {}) do
        if type(key) == "number" and cooldowns[key] and not seen[key] and key ~= primaryID then
            utilities[#utilities + 1] = {
                key = key, spellID = key, cooldown = cooldowns[key], kind = "cc", badge = "CC",
                assumeReady = false,
            }
            seen[key] = true
        end
    end

    return main, utilities
end

function Tracker:ResetBaseline()
    wipe(self.observed)
    wipe(self.baseline)
    for _, unit in ipairs(units) do
        local guid = UnitGUID(unit)
        if guid then self.baseline[guid] = true end
    end
end

function Tracker:FindOwner(sourceGUID)
    if not sourceGUID then return nil end
    for _, unit in ipairs(units) do
        local guid = UnitGUID(unit)
        if guid and sourceGUID == guid then return unit, guid end
        local pet = petUnit(unit)
        if guid and pet and sourceGUID == UnitGUID(pet) then return unit, guid end
    end
end

function Tracker:MarkUsed(ownerGUID, key, duration)
    if not ownerGUID or not key then return end
    self.observed[ownerGUID] = self.observed[ownerGUID] or {}
    local old = self.observed[ownerGUID][key]
    local now = GetTime()
    -- CAST_SUCCESS and SPELL_INTERRUPT can both fire for the same action.
    if not old or now - (old.usedAt or 0) > 2 then
        self.observed[ownerGUID][key] = { usedAt = now, readyAt = now + duration }
    end
end

function Tracker:HandleCombatLog()
    local _, subevent, _, sourceGUID, _, _, _, _, _, _, _, spellID = CombatLogGetCurrentEventInfo()
    if subevent ~= "SPELL_CAST_SUCCESS" and subevent ~= "SPELL_INTERRUPT" then return end
    local unit, ownerGUID = self:FindOwner(sourceGUID)
    if not unit or not ownerGUID then return end

    spellID = aliases[spellID] or spellID
    local duration = cooldowns[spellID]
    if duration then self:MarkUsed(ownerGUID, spellID, duration) end
end

function Tracker:GetAbilityState(unit, definition)
    if not definition then return nil end
    local guid = UnitGUID(unit)
    if not guid then return nil end
    local now = GetTime()
    local observed = self.observed[guid] and self.observed[guid][definition.key]
    local remaining = observed and math.max(0, (observed.readyAt or now) - now) or nil
    local state = remaining and (remaining > 0 and "cooldown" or "ready") or "unknown"

    if not observed and self.baseline[guid] and definition.assumeReady ~= false then
        state, remaining = "ready", 0
    end

    local name, icon = spellName(definition.spellID), spellIcon(definition.spellID)
    if unit == "player" and GetSpellCooldown then
        local start, duration, enabled = GetSpellCooldown(definition.spellID)
        if start and duration and enabled == 1 then
            local gs, gd = GetSpellCooldown(61304)
            local mirror = gs and gd and duration <= gd + 0.15 and math.abs(start + duration - gs - gd) <= 0.15
            remaining = mirror and 0 or math.max(0, start + duration - now)
            if duration > 1.5 then definition.cooldown = duration end
            state = remaining > 0 and "cooldown" or "ready"
        end
    end

    if UnitIsDeadOrGhost(unit) or not UnitIsConnected(unit) then
        state, remaining = "blocked", 0
    end

    return {
        key = definition.key,
        spellID = definition.spellID,
        name = name,
        icon = icon,
        owner = UnitName(unit) or unit,
        cooldown = tonumber(definition.cooldown) or 15,
        remaining = tonumber(remaining) or 0,
        state = state,
        kind = definition.kind,
        badge = definition.badge,
        optional = definition.optional,
    }
end

function Tracker:GetUnitState(unit)
    local mainDef, utilityDefs = self:GetAbilityDefinitions(unit)
    local state = { unit = unit, owner = UnitName(unit) or unit, primary = nil, utilities = {} }
    if mainDef then state.primary = self:GetAbilityState(unit, mainDef) end
    for _, definition in ipairs(utilityDefs) do
        local entry = self:GetAbilityState(unit, definition)
        if entry then state.utilities[#state.utilities + 1] = entry end
    end
    return state
end

local function stateColor(state)
    if state == "ready" then return READY end
    if state == "cooldown" then return COOLDOWN end
    if state == "blocked" then return BLOCKED end
    return UNKNOWN
end

local function setOwnerColor(row, unit)
    local _, class = UnitClass(unit)
    local c = class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]
    if c then
        row.owner:SetTextColor(c.r, c.g, c.b)
        row.classStripe:SetColorTexture(c.r, c.g, c.b, 0.95)
    else
        row.owner:SetTextColor(0.93, 0.95, 0.98)
        row.classStripe:SetColorTexture(0.45, 0.50, 0.58, 0.95)
    end
end

local function styleSlot(slot, entry)
    if not entry then
        slot.entry = nil
        slot:Hide()
        return
    end
    slot.entry = entry
    slot:Show()
    slot.icon:SetTexture(entry.icon)
    slot.badge:SetText(entry.badge or "")

    local color = stateColor(entry.state)
    slot:SetBackdropBorderColor(color[1], color[2], color[3], entry.state == "ready" and 0.95 or 0.78)
    if entry.kind == "kick" then
        slot.badge:SetTextColor(unpack(KICK_ACCENT))
    else
        slot.badge:SetTextColor(unpack(CC_ACCENT))
    end

    if entry.state == "ready" then
        slot.icon:SetDesaturated(false); slot.icon:SetAlpha(1)
        slot.time:SetText("")
        slot.glow:SetColorTexture(color[1], color[2], color[3], 0.16)
    elseif entry.state == "cooldown" then
        slot.icon:SetDesaturated(true); slot.icon:SetAlpha(0.53)
        slot.time:SetText(cooldownText(entry.remaining))
        slot.glow:SetColorTexture(color[1], color[2], color[3], 0.08)
    elseif entry.state == "blocked" then
        slot.icon:SetDesaturated(true); slot.icon:SetAlpha(0.27)
        slot.time:SetText("X")
        slot.glow:SetColorTexture(color[1], color[2], color[3], 0.06)
    else
        slot.icon:SetDesaturated(true); slot.icon:SetAlpha(0.38)
        slot.time:SetText("?")
        slot.glow:SetColorTexture(color[1], color[2], color[3], 0.04)
    end
end

function Tracker:CreateUtilitySlot(row, index)
    local slot = CreateFrame("Frame", nil, row)
    slot:SetSize(27, 27)
    slot:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
    slot:SetBackdropColor(0.010, 0.014, 0.021, 0.94)
    slot:SetBackdropBorderColor(0.22, 0.25, 0.30, 0.78)
    slot:SetPoint("RIGHT", row, "RIGHT", -10 - (index - 1) * 31, 0)

    slot.glow = slot:CreateTexture(nil, "BACKGROUND")
    slot.glow:SetPoint("TOPLEFT", 1, -1)
    slot.glow:SetPoint("BOTTOMRIGHT", -1, 1)
    slot.glow:SetColorTexture(0.2, 0.8, 0.7, 0.08)

    slot.icon = slot:CreateTexture(nil, "ARTWORK")
    slot.icon:SetPoint("TOPLEFT", 2, -2)
    slot.icon:SetPoint("BOTTOMRIGHT", -2, 2)
    slot.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    slot.time = slot:CreateFontString(nil, "OVERLAY")
    slot.time:SetFont(STANDARD_TEXT_FONT, 9, "OUTLINE")
    slot.time:SetPoint("CENTER", 0, 0)
    slot.time:SetTextColor(1, 1, 1)

    slot.badge = slot:CreateFontString(nil, "OVERLAY")
    slot.badge:SetFont(STANDARD_TEXT_FONT, 7, "OUTLINE")
    slot.badge:SetPoint("BOTTOMRIGHT", -1, 1)
    slot.badge:SetTextColor(unpack(CC_ACCENT))

    slot:EnableMouse(true)
    slot:SetScript("OnEnter", function(self)
        local entry = self.entry
        if not entry or not GameTooltip then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(entry.name or "", 1, 1, 1)
        if entry.state == "ready" then
            GameTooltip:AddLine(BKA:L("READY"), READY[1], READY[2], READY[3])
        elseif entry.state == "cooldown" then
            GameTooltip:AddLine(BKA:L("COOLDOWN_FMT", cooldownText(entry.remaining)), COOLDOWN[1], COOLDOWN[2], COOLDOWN[3])
        elseif entry.state == "blocked" then
            GameTooltip:AddLine(BKA:L("UNAVAILABLE"), BLOCKED[1], BLOCKED[2], BLOCKED[3])
        else
            GameTooltip:AddLine(BKA:L("UNKNOWN_READY"), UNKNOWN[1], UNKNOWN[2], UNKNOWN[3])
        end
        GameTooltip:Show()
    end)
    slot:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)

    row.utilitySlots[index] = slot
    return slot
end

function Tracker:CreateRow(frame, index)
    local row = CreateFrame("Frame", nil, frame)
    row:SetHeight(44)

    row.bg = row:CreateTexture(nil, "BACKGROUND")
    row.bg:SetAllPoints()
    row.bg:SetColorTexture(0.022, 0.028, 0.038, index % 2 == 0 and 0.72 or 0.88)

    row.classStripe = row:CreateTexture(nil, "ARTWORK")
    row.classStripe:SetPoint("TOPLEFT", 0, -3)
    row.classStripe:SetPoint("BOTTOMLEFT", 0, 3)
    row.classStripe:SetWidth(3)

    row.iconBox = CreateFrame("Frame", nil, row)
    row.iconBox:SetSize(30, 30)
    row.iconBox:SetPoint("LEFT", 10, 0)
    row.iconBox:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
    row.iconBox:SetBackdropColor(0.010, 0.014, 0.021, 0.96)
    row.iconBox:SetBackdropBorderColor(0.18, 0.22, 0.28, 0.90)

    row.icon = row.iconBox:CreateTexture(nil, "ARTWORK")
    row.icon:SetPoint("TOPLEFT", 2, -2)
    row.icon:SetPoint("BOTTOMRIGHT", -2, 2)
    row.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    row.owner = row:CreateFontString(nil, "OVERLAY")
    row.owner:SetFont(STANDARD_TEXT_FONT, 11, "OUTLINE")
    row.owner:SetPoint("LEFT", row.iconBox, "RIGHT", 8, 6)
    row.owner:SetPoint("RIGHT", row, "RIGHT", -(UTILITY_AREA_WIDTH + 42), 6)
    row.owner:SetJustifyH("LEFT")
    row.owner:SetWordWrap(false)

    row.state = row:CreateFontString(nil, "OVERLAY")
    row.state:SetFont(STANDARD_TEXT_FONT, 9, "OUTLINE")
    row.state:SetPoint("RIGHT", row, "RIGHT", -UTILITY_AREA_WIDTH, 6)
    row.state:SetJustifyH("RIGHT")

    row.bar = BKA.HUD:Bar(row, 0, 0, 100, 6, unpack(READY))
    row.bar:ClearAllPoints()
    row.bar:SetPoint("BOTTOMLEFT", row.iconBox, "BOTTOMRIGHT", 8, 6)
    row.bar:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", -UTILITY_AREA_WIDTH, 6)
    row.bar:SetHeight(6)
    row.bar.background:SetColorTexture(0.064, 0.078, 0.101, 0.96)

    row.utilitySlots = {}
    for slotIndex = 1, UTILITY_SLOT_COUNT do self:CreateUtilitySlot(row, slotIndex) end

    row.separator = row:CreateTexture(nil, "ARTWORK")
    row.separator:SetPoint("TOPRIGHT", row, "TOPRIGHT", -(UTILITY_AREA_WIDTH - 5), -7)
    row.separator:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", -(UTILITY_AREA_WIDTH - 5), 7)
    row.separator:SetWidth(1)
    row.separator:SetColorTexture(0.12, 0.15, 0.20, 0.72)

    frame.rows[index] = row
    return row
end

function Tracker:CreateFrame()
    if self.frame then return self.frame end
    local settings = BKA.db.kickTracker
    local f = BKA.HUD:CreatePanel("BFAKeyAlerts_GroupKicks", settings, BKA:L("GROUP_CONTROL"), 350, -160)
    f:SetSize(settings.width or 320, 60)
    f:SetBackdropColor(0.012, 0.017, 0.025, 0.94)
    f:SetBackdropBorderColor(0.075, 0.095, 0.125, 0.94)
    f.accent:SetColorTexture(0.31, 0.75, 0.68, 0.52)
    f.rows = {}

    f.title = BKA.HUD:Text(f, 10, 10, -9, 180)
    f.title:SetText(BKA:L("GROUP_CONTROL_HEADER"))
    f.title:SetTextColor(0.76, 0.82, 0.89)

    f.summary = BKA.HUD:Text(f, 9, 0, 0, 150)
    f.summary:ClearAllPoints()
    f.summary:SetPoint("TOPRIGHT", -10, -9)
    f.summary:SetJustifyH("RIGHT")
    f.summary:SetTextColor(0.48, 0.55, 0.63)
    f.summary:SetText("-")

    f.divider = f:CreateTexture(nil, "ARTWORK")
    f.divider:SetPoint("TOPLEFT", 8, -25)
    f.divider:SetPoint("TOPRIGHT", -8, -25)
    f.divider:SetHeight(1)
    f.divider:SetColorTexture(0.13, 0.16, 0.21, 0.76)

    self.frame = f
    return f
end

function Tracker:IsVisibleByContext(settings)
    local groupVisible = (IsInGroup and IsInGroup() and (not IsInRaid or not IsInRaid())) or settings.locked == false
    local keyVisible = settings.onlyInKey ~= true or challengeActive() or settings.locked == false
    return BKA.db.enabled ~= false and settings.shown ~= false and groupVisible and keyVisible
end

function Tracker:ApplySettings()
    if not BKA.db then return end
    local settings = BKA.db.kickTracker
    local f = self:CreateFrame()
    settings.width = math.max(280, math.min(480, tonumber(settings.width) or 320))
    settings.alpha = math.max(0.20, math.min(1.00, tonumber(settings.alpha) or 0.92))
    f:SetWidth(settings.width)
    f:SetAlpha(settings.alpha)
    BKA.HUD:Apply(f, settings, 350, -160)
    if self:IsVisibleByContext(settings) then f:Show() else f:Hide() end
end

function Tracker:RenderPrimary(row, entry)
    if not entry then
        row.icon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
        row.icon:SetDesaturated(true); row.icon:SetAlpha(0.22)
        row.iconBox:SetBackdropBorderColor(UNKNOWN[1], UNKNOWN[2], UNKNOWN[3], 0.50)
        row.state:SetText("-")
        row.state:SetTextColor(unpack(UNKNOWN))
        row.bar:SetMinMaxValues(0, 1); row.bar:SetValue(0)
        row.bar:SetStatusBarColor(unpack(UNKNOWN))
        return false
    end

    row.icon:SetTexture(entry.icon)
    local color = stateColor(entry.state)
    row.iconBox:SetBackdropBorderColor(color[1], color[2], color[3], 0.92)
    local cooldown = math.max(0.01, tonumber(entry.cooldown) or 15)
    local remaining = math.max(0, tonumber(entry.remaining) or 0)
    row.bar:SetMinMaxValues(0, cooldown)
    row.bar:SetValue(entry.state == "ready" and cooldown or math.max(0, cooldown - remaining))
    row.bar:SetStatusBarColor(color[1], color[2], color[3], 0.90)

    if entry.state == "ready" then
        row.state:SetText(BKA:L("READY"))
        row.icon:SetDesaturated(false); row.icon:SetAlpha(1)
    elseif entry.state == "cooldown" then
        row.state:SetText(cooldownText(remaining))
        row.icon:SetDesaturated(true); row.icon:SetAlpha(0.58)
    elseif entry.state == "blocked" then
        row.state:SetText(BKA:L("DOWN"))
        row.icon:SetDesaturated(true); row.icon:SetAlpha(0.30)
        row.bar:SetValue(0)
    else
        row.state:SetText("?")
        row.icon:SetDesaturated(true); row.icon:SetAlpha(0.38)
        row.bar:SetValue(0)
    end
    row.state:SetTextColor(color[1], color[2], color[3])
    return entry.state == "ready"
end

function Tracker:Refresh(force)
    if not BKA.db then return end
    local settings = BKA.db.kickTracker
    if not self:IsVisibleByContext(settings) then
        if self.frame then self.frame:Hide() end
        return
    end
    local now = GetTime()
    if not force and now < (self.nextUpdate or 0) then return end
    self.nextUpdate = now + 0.10

    local frame = self:CreateFrame()
    self:ApplySettings()
    local rowIndex, readyKicks, totalKicks, readyCC = 0, 0, 0, 0

    for _, unit in ipairs(units) do
        if UnitExists(unit) then
            rowIndex = rowIndex + 1
            local state = self:GetUnitState(unit)
            local row = frame.rows[rowIndex] or self:CreateRow(frame, rowIndex)
            row:ClearAllPoints()
            row:SetPoint("TOPLEFT", 6, -31 - (rowIndex - 1) * 45)
            row:SetPoint("TOPRIGHT", -6, -31 - (rowIndex - 1) * 45)
            row.owner:SetText(state.owner)
            setOwnerColor(row, unit)

            if state.primary then
                totalKicks = totalKicks + 1
                if self:RenderPrimary(row, state.primary) then readyKicks = readyKicks + 1 end
            else
                self:RenderPrimary(row, nil)
            end

            -- Utilities are right-aligned so the compact CC area stays stable.
            local utilityCount = math.min(UTILITY_SLOT_COUNT, #state.utilities)
            for slotIndex = 1, UTILITY_SLOT_COUNT do
                local entryIndex = #state.utilities - slotIndex + 1
                local entry = slotIndex <= utilityCount and state.utilities[entryIndex] or nil
                local slot = row.utilitySlots[slotIndex]
                styleSlot(slot, entry)
                if entry and entry.kind == "cc" and entry.state == "ready" then readyCC = readyCC + 1 end
            end
            row:Show()
        end
    end

    for i = rowIndex + 1, #frame.rows do frame.rows[i]:Hide() end
    frame.summary:SetText(BKA:L("KICK_SUMMARY_FMT", readyKicks, totalKicks, readyCC))
    frame:SetHeight(math.max(50, 35 + rowIndex * 45))
    frame:Show()
end

function Tracker:ResetPosition()
    local s = BKA.db.kickTracker
    s.point, s.relativePoint, s.x, s.y = "CENTER", "CENTER", 350, -160
    s.scale, s.width = 1, 320
    self:ApplySettings()
end

function Tracker:Initialize()
    if self.initialized then return end
    self.initialized = true
    self:ResetBaseline()
    local eventFrame = CreateFrame("Frame")
    eventFrame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
    eventFrame:RegisterEvent("GROUP_ROSTER_UPDATE")
    eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
    eventFrame:RegisterEvent("CHALLENGE_MODE_START")
    eventFrame:SetScript("OnEvent", function(_, event)
        if event == "COMBAT_LOG_EVENT_UNFILTERED" then
            Tracker:HandleCombatLog()
        else
            Tracker:ResetBaseline()
            Tracker:Refresh(true)
        end
    end)

    local elapsed = 0
    eventFrame:SetScript("OnUpdate", function(_, dt)
        elapsed = elapsed + dt
        if elapsed < 0.10 then return end
        elapsed = 0
        Tracker:Refresh(false)
    end)
    self.eventFrame = eventFrame
    self:Refresh(true)
end
