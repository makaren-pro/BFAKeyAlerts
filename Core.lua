local addonName, addon = ...

local BKA = addon or {}
_G.BFAKeyAlerts = BKA

BKA.name = addonName
BKA.version = "1.5.0"
BKA.dungeons = {}
BKA.dungeonByChallengeMap = {}
BKA.dungeonByInstanceMap = {}
BKA.active = false
BKA.activeDungeon = nil
BKA.iconCache = {}
BKA.iconFallbacks = {}
BKA.targetDecisions = {}
BKA.diagnostics = {
    unknownCasts = 0,
    heuristicTargetsIgnored = 0,
    confirmedPersonalTargets = 0,
    centerSafetyNetPromotions = 0,
}
BKA.targetConfidence = { NONE = "NONE", HEURISTIC = "HEURISTIC", CONFIRMED = "CONFIRMED" }
BKA.frontalBehavior = {
    FIXED_FORWARD = "FIXED_FORWARD",
    SNAPSHOT_TARGET = "SNAPSHOT_TARGET",
    TRACK_TARGET = "TRACK_TARGET",
    UNKNOWN = "UNKNOWN",
}

BKA.severityRank = {
    LOW = 1,
    MEDIUM = 2,
    HIGH = 3,
    CRITICAL = 4,
}

BKA.colors = {
    LOW = {0.72, 0.76, 0.82},
    MEDIUM = {1.00, 0.77, 0.20},
    HIGH = {1.00, 0.36, 0.12},
    CRITICAL = {1.00, 0.08, 0.08},
}

function BKA:RegisterDungeon(data)
    self.dungeons[#self.dungeons + 1] = data
    self.dungeonByChallengeMap[data.challengeMapID] = data
    for _, mapID in ipairs(data.instanceMapIDs or {}) do
        self.dungeonByInstanceMap[mapID] = data
    end
end

function BKA:GetNPCID(guid)
    if type(guid) ~= "string" then
        return nil
    end
    local _, _, _, _, _, npcID = strsplit("-", guid)
    return tonumber(npcID)
end

function BKA:IsPlayerOrPartyGUID(guid)
    return guid and self.partyGUIDs and self.partyGUIDs[guid] or false
end

function BKA:Print(message)
    DEFAULT_CHAT_FRAME:AddMessage("|cff33ff99BKA|r " .. tostring(message))
end

local SEMANTIC_ICONS = {
    CAST = "Interface\\Icons\\Spell_Nature_Lightning",
    INFO = "Interface\\Icons\\INV_Misc_Note_01",
    KICK = "Interface\\Icons\\Ability_Kick",
    STOP = "Interface\\Icons\\Ability_Paladin_HammeroftheRighteous",
    CC = "Interface\\Icons\\Spell_Frost_Stun",
    TURN = "Interface\\Icons\\Ability_Rogue_Feint",
    AOE = "Interface\\Icons\\Spell_Fire_SelfDestruct",
    FRONTAL = "Interface\\Icons\\Ability_Warrior_Shockwave",
    MOVE = "Interface\\Icons\\Ability_Rogue_Sprint",
    MOVE_MOBS = "Interface\\Icons\\Ability_Hunter_Misdirection",
    DODGE = "Interface\\Icons\\Ability_Rogue_Sprint",
    GTFO = "Interface\\Icons\\Spell_Fire_Volcano",
    YOU = "Interface\\Icons\\Achievement_Character_Human_Female",
    TARGET = "Interface\\Icons\\Ability_Hunter_SniperShot",
    TARGETED = "Interface\\Icons\\Ability_Hunter_SniperShot",
    DISPEL = "Interface\\Icons\\Spell_Holy_DispelMagic",
    PURGE = "Interface\\Icons\\Spell_Nature_Purge",
    SOOTHE = "Interface\\Icons\\Ability_Hunter_BeastSoothe",
    DEF = "Interface\\Icons\\Spell_Holy_DevotionAura",
    DEFENSIVE = "Interface\\Icons\\Spell_Holy_DevotionAura",
    HEAL = "Interface\\Icons\\Spell_Holy_FlashHeal",
    SOAK = "Interface\\Icons\\Spell_Holy_PowerWordShield",
    SPREAD = "Interface\\Icons\\Spell_Nature_WispSplode",
    STACK = "Interface\\Icons\\Ability_Druid_CatForm",
    RESET = "Interface\\Icons\\Ability_Rogue_Feint",
    LOS = "Interface\\Icons\\Ability_Vanish",
    RUN = "Interface\\Icons\\Ability_Rogue_Sprint",
    FIXATE = "Interface\\Icons\\Ability_Hunter_SniperShot",
    KITE = "Interface\\Icons\\Ability_Hunter_Pathfinding",
    PREWARN = "Interface\\Icons\\Spell_Holy_BorrowedTime",
    PREPARE = "Interface\\Icons\\Spell_Holy_BorrowedTime",
}

local function addIconCandidate(candidates, seen, spellID)
    spellID = tonumber(spellID)
    if spellID and spellID > 0 and not seen[spellID] then
        seen[spellID] = true
        candidates[#candidates + 1] = spellID
    end
end

function BKA:ResolveIcon(ability, context)
    context = context or {}
    local texture = context.texture
    if texture then return texture end
    if ability and ability._resolvedIcon then return ability._resolvedIcon end
    local candidates, seen = {}, {}
    addIconCandidate(candidates, seen, ability and ability.iconSpellID)
    addIconCandidate(candidates, seen, ability and ability.displaySpellID)
    addIconCandidate(candidates, seen, context.spellID)
    addIconCandidate(candidates, seen, ability and ability.id)
    for _, trigger in ipairs(ability and ability.triggers or {}) do
        addIconCandidate(candidates, seen, trigger.spell)
    end
    for _, spellID in ipairs(ability and ability.aliasSpellIDs or {}) do
        addIconCandidate(candidates, seen, spellID)
    end
    for _, spellID in ipairs(candidates) do
        texture = GetSpellTexture(spellID) or select(3, GetSpellInfo(spellID))
        if texture then
            if ability then ability._resolvedIcon = texture end
            return texture
        end
    end
    local action = self:NormalizeAction(context.action or (ability and (ability.primaryAction or ability.action or ability.mechanic)), ability and ability.mechanic)
    local fallback = SEMANTIC_ICONS[action] or SEMANTIC_ICONS.CAST
    local spellID = context.spellID or (ability and ability.id) or 0
    local auditKey = tostring(spellID) .. ":" .. tostring(action)
    if not self.iconFallbacks[auditKey] then
        self.iconFallbacks[auditKey] = { spellID = spellID, action = action }
    end
    return fallback
end

function BKA:NormalizeAction(action, mechanic)
    action = string.upper(tostring(action or ""))
    mechanic = string.upper(tostring(mechanic or ""))
    if action == "WATCH" or action == "INFO" or action == "TARGET" or action == "" then
        if mechanic ~= "" and mechanic ~= "INFO" and mechanic ~= "TARGETED" then return mechanic end
        return mechanic == "TARGETED" and "TARGETED" or "CAST"
    end
    if action == "YOU" then return "TARGETED" end
    return action
end

function BKA:IsConfirmedPersonal(context)
    return context and context.isPlayer == true and context.targetConfidence == "CONFIRMED"
end

function BKA:NormalizeFrontalBehavior(value)
    value = string.upper(tostring(value or "UNKNOWN"))
    if self.frontalBehavior[value] then return value end
    return "UNKNOWN"
end

function BKA:IsTargetBasedFrontal(ability)
    local behavior = self:NormalizeFrontalBehavior(ability and ability.frontalBehavior)
    return behavior == "SNAPSHOT_TARGET" or behavior == "TRACK_TARGET"
end

function BKA:ShortUnitName(name)
    if not name or name == "" then return nil end
    if name == "YOU" then return name end
    return string.match(name, "^([^-]+)") or name
end

function BKA:GetGroupRoleForGUID(guid)
    if not guid then return "NONE" end
    local units = { "player", "party1", "party2", "party3", "party4" }
    for _, unit in ipairs(units) do
        if UnitGUID(unit) == guid then
            return UnitGroupRolesAssigned and UnitGroupRolesAssigned(unit) or "NONE"
        end
    end
    return "NONE"
end

function BKA:GetFrontalTargetLabel(ability, context)
    context = context or {}
    if not self:IsTargetBasedFrontal(ability) or context.targetConfidence ~= "CONFIRMED" then return nil end
    if context.isPlayer then return "YOU" end
    if self.db and self.db.showFrontalTarget == false then return nil end
    if context.targetRole == "TANK" then return "TANK" end
    return self:ShortUnitName(context.targetName)
end

function BKA:GetFrontalStateLabel(ability, context, compact)
    context = context or {}
    if context.alertState == "PREWARN" then return nil end
    local behavior = self:NormalizeFrontalBehavior(ability and ability.frontalBehavior)
    if behavior == "FIXED_FORWARD" then return "FIXED" end
    if self.db and self.db.showFrontalTarget == false and not self:IsConfirmedPersonal(context) then return nil end
    if behavior == "SNAPSHOT_TARGET" then return "LOCKED" end
    if behavior == "TRACK_TARGET" then return compact and "TRACK" or "TRACKING" end
end

function BKA:IsBossSource(sourceGUID)
    if not sourceGUID then return false end
    for i = 1, 5 do
        if UnitGUID("boss" .. i) == sourceGUID then return true end
    end
    return false
end

function BKA:IsGeometryAction(action, mechanic)
    action = self:NormalizeAction(action, mechanic)
    return action == "AOE" or action == "FRONTAL" or action == "CLEAVE"
end

function BKA:ShouldCenterAbility(ability, action, context)
    context = context or {}
    local policy = ability and ability.centerPolicy
    local personal = self:IsConfirmedPersonal(context)
    if policy == "NEVER" then return false, false end
    if policy == "ALWAYS" then return true, false end
    -- A confirmed YOU mechanic is never allowed to disappear because an imported
    -- record was marked nameplate-only or informational. Personal truth wins.
    if personal and ability and ability.voiceAction == "YOU" then return true, false end
    if policy == "IF_PERSONAL" then return personal, false end
    local rank = self.severityRank[ability and ability.severity] or 1
    if policy == "IF_HIGH" then return rank >= self.severityRank.HIGH, false end
    if ability and ability.center == true then return true, false end
    action = self:NormalizeAction(action or (ability and (ability.primaryAction or ability.action)), ability and ability.mechanic)
    local alwaysDangerous = action == "DODGE" or action == "GTFO" or action == "MOVE_MOBS" or
        action == "SPREAD" or action == "SOAK" or action == "LOS" or action == "DEFENSIVE"
    local highArea = action == "AOE" or action == "FRONTAL" or action == "CLEAVE" or action == "MOVE"
    local promoted = alwaysDangerous or (highArea and (rank >= self.severityRank.HIGH or self:IsBossSource(context.sourceGUID)))
    return promoted, promoted
end

function BKA:ResetRunDiagnostics()
    wipe(self.iconFallbacks)
    wipe(self.targetDecisions)
    self.diagnostics.unknownCasts = 0
    self.diagnostics.heuristicTargetsIgnored = 0
    self.diagnostics.confirmedPersonalTargets = 0
    self.diagnostics.centerSafetyNetPromotions = 0
end

BKA.eventFrame = CreateFrame("Frame")
BKA.eventFrame:SetScript("OnEvent", function(_, event, ...)
    if BKA.OnEvent then
        BKA:OnEvent(event, ...)
    end
end)
BKA.eventFrame:RegisterEvent("ADDON_LOADED")
BKA.eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
BKA.eventFrame:RegisterEvent("CHALLENGE_MODE_START")
BKA.eventFrame:RegisterEvent("CHALLENGE_MODE_RESET")
BKA.eventFrame:RegisterEvent("CHALLENGE_MODE_COMPLETED")
