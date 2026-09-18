local BKA = BFAKeyAlerts
local Affixes = { active = {} }
BKA.Affixes = Affixes

local AURA_ABILITIES = {
    [209858] = { id = 209858, affix = 4, mechanic = "TANK", action = "KITE", severity = "HIGH", center = true, sound = true, stack = 10, role = "TANK", tankOnly = true }, -- Necrotic
    [240443] = { id = 240443, affix = 11, mechanic = "AOE", action = "BURSTING", severity = "HIGH", center = true, sound = true, stack = 3 },
    [240447] = { id = 240447, affix = 14, mechanic = "SPREAD", action = "SPREAD", severity = "CRITICAL", center = true, sound = true }, -- Quaking
    [226512] = { id = 226512, affix = 8, mechanic = "GTFO", action = "GTFO", severity = "CRITICAL", center = true, sound = true }, -- Sanguine
    [209862] = { id = 209862, affix = 3, mechanic = "MOVE", action = "MOVE", severity = "HIGH", center = true, sound = true }, -- Volcanic
}

local NAMEPLATE_AURAS = {
    [228318] = { label = "PURGE", severity = "HIGH", affix = 6 }, -- Raging
}

-- BFA Season 1: Symbiote of G'huun. This is rendered by Nameplates as a
-- dedicated small affix badge, not as a full BKA cast alert.
local INFESTED_AURA_IDS = {
    [277242] = true, -- Symbiote of G'huun
}

function Affixes:Refresh()
    wipe(self.active)
    if not C_ChallengeMode or not C_ChallengeMode.GetActiveKeystoneInfo then
        return
    end
    local _, affixIDs = C_ChallengeMode.GetActiveKeystoneInfo()
    if type(affixIDs) == "table" then
        for _, affixID in ipairs(affixIDs) do
            self.active[affixID] = true
        end
    end
    -- Existing nameplates are already on screen when the countdown starts. Refresh
    -- them immediately so Infested badges appear without waiting for a UNIT_AURA.
    if BKA.active and BKA.Nameplates and BKA.Nameplates.RefreshAll then
        BKA.Nameplates:RefreshAll()
    end
end

function Affixes:IsActive(affixID)
    return self.active[affixID] or false
end

function Affixes:LearnCursedPulse(spellID)
    if spellID and spellID > 0 then
        BKA.db.firestorm.cursedPulseSpellID = spellID
    end
    return {
        id = spellID or 0,
        mechanic = "AOE",
        action = "AOE",
        severity = "HIGH",
        center = true,
        nameplate = true,
        sound = true,
        target = "NONE",
        throttle = 0.6,
        source = "Firestorm-runtime",
    }
end

function Affixes:IsCursedPulse(spellID, spellName)
    local learned = BKA.db.firestorm.cursedPulseSpellID
    if learned and learned > 0 then
        return spellID == learned
    end
    if spellName == "Cursed Pulse" then
        self:LearnCursedPulse(spellID)
        return true
    end
    return false
end

function Affixes:GetKnownAbility(spellID)
    if not spellID then
        return nil
    end
    if BKA.db.firestorm.cursedPulseSpellID == spellID then
        return self:LearnCursedPulse(spellID)
    end
    return AURA_ABILITIES[spellID]
end


function Affixes:GetInfestedAura(unit)
    if not self:IsActive(16) or not UnitExists(unit) then return nil end
    for i = 1, 40 do
        local name, _, _, _, _, _, _, _, _, spellID = UnitAura(unit, i, "HELPFUL")
        if not name then break end
        if INFESTED_AURA_IDS[spellID] then return spellID, name end
    end
    return nil
end

function Affixes:IsInfestedUnit(unit)
    return self:GetInfestedAura(unit) ~= nil
end

function Affixes:GetNameplateMarker(unit)
    for i = 1, 40 do
        local name, _, _, _, _, _, _, _, _, spellID = UnitAura(unit, i, "HELPFUL")
        if not name then
            break
        end
        local marker = NAMEPLATE_AURAS[spellID]
        if marker and self:IsActive(marker.affix) then
            return marker, spellID
        end
    end
end

function Affixes:ScanUnitAuras(unit)
    if not BKA.active or not UnitExists(unit) then
        return
    end
    local isFriendly = UnitIsFriend("player", unit)
    if not isFriendly then
        if BKA.Nameplates and BKA.Nameplates.RefreshInfestedMarker then
            BKA.Nameplates:RefreshInfestedMarker(unit)
        end
        local marker, markerSpellID = self:GetNameplateMarker(unit)
        if marker then
            BKA.Nameplates:Display(unit, markerSpellID, marker.label, marker.severity, true)
        else
            BKA.Nameplates:RestorePersistent(unit, true)
        end
        return
    end
    for i = 1, 40 do
        local name, _, count, _, duration, expires, _, _, _, spellID = UnitAura(unit, i, isFriendly and "HARMFUL" or "HELPFUL")
        if not name then
            break
        end
        local ability = AURA_ABILITIES[spellID]
        local isPlayer = UnitIsUnit(unit, "player")
        if ability and self:IsActive(ability.affix) and (not ability.stack or (count or 0) >= ability.stack) and
            BKA:RoleNotificationAllows(ability, ability.action or ability.mechanic, isPlayer) then
            BKA.Alerts:Show(ability, {
                spellName = name, isPlayer = isPlayer, targetConfidence = "CONFIRMED", targetName = UnitName(unit),
                startTime = duration and duration > 0 and expires - duration or nil,
                endTime = expires and expires > 0 and expires or nil,
                key = "affix:" .. tostring(spellID) .. ":" .. tostring(UnitGUID(unit)),
            })
        end
    end
end

function Affixes:HandleCombatLog(event, spellID, spellName, destGUID, destName, amount)
    local ability
    if self:IsCursedPulse(spellID, spellName) then
        ability = self:LearnCursedPulse(spellID)
    else
        ability = self:GetKnownAbility(spellID)
    end
    if not ability or (ability.affix and not self:IsActive(ability.affix)) then
        return false
    end
    if ability.source == "Firestorm-runtime" then
        if event == "SPELL_CAST_START" or event == "SPELL_CAST_SUCCESS" then
            BKA.Alerts:Show(ability, { spellName = spellName, key = "cursed-pulse:" .. tostring(spellID) })
        end
        return true
    end
    if not BKA:IsPlayerOrPartyGUID(destGUID) then
        return false
    end
    if spellID == 226512 or spellID == 209862 then
        if event ~= "SPELL_DAMAGE" and event ~= "SPELL_PERIODIC_DAMAGE" and event ~= "SPELL_MISSED" and event ~= "SPELL_PERIODIC_MISSED" then
            return true
        end
    elseif event ~= "SPELL_AURA_APPLIED" and event ~= "SPELL_AURA_APPLIED_DOSE" then
        return true
    end
    if ability.stack and (amount or 0) < ability.stack then
        return true
    end
    local isPlayer = destGUID == UnitGUID("player")
    if not BKA:RoleNotificationAllows(ability, ability.action or ability.mechanic, isPlayer) then
        return true
    end
    if spellID == 226512 and not isPlayer then
        return true
    end
    BKA.Alerts:Show(ability, {
        spellName = spellName,
        targetName = destName,
        isPlayer = isPlayer,
        targetConfidence = "CONFIRMED",
        key = "affix-cleu:" .. tostring(spellID) .. ":" .. tostring(destGUID),
    })
    return true
end

function Affixes:Clear()
    wipe(self.active)
end
