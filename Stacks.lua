local BKA = BFAKeyAlerts
local Stacks = { active = {}, rulesBySpell = {} }
BKA.Stacks = Stacks

local AURA_EVENTS = {
    SPELL_AURA_APPLIED = true,
    SPELL_AURA_APPLIED_DOSE = true,
    SPELL_AURA_REMOVED_DOSE = true,
    SPELL_AURA_REMOVED = true,
}

local function copyAbility(ability, severity)
    local copy = {}
    for key, value in pairs(ability) do copy[key] = value end
    copy.severity = severity or ability.severity
    copy.center = true
    copy.sound = false
    return copy
end

function Stacks:Compile(abilities)
    wipe(self.rulesBySpell)
    for _, ability in ipairs(abilities or {}) do
        if ability.stackRule then
            self.rulesBySpell[ability.id] = ability.stackRule
            for _, trigger in ipairs(ability.triggers or {}) do
                if AURA_EVENTS[trigger.event] then self.rulesBySpell[trigger.spell] = ability.stackRule end
            end
        end
    end
    for _, ability in ipairs(abilities or {}) do
        if not ability.stackRule then
            for _, trigger in ipairs(ability.triggers or {}) do
                if AURA_EVENTS[trigger.event] and self.rulesBySpell[trigger.spell] then
                    ability.stackRule = self.rulesBySpell[trigger.spell]
                    break
                end
            end
        end
    end
end

function Stacks:OwnerAllows(rule, context)
    local owner = rule.owner or "PARTY"
    local playerGUID = UnitGUID("player")
    if owner == "PLAYER" then return context.destGUID == playerGUID end
    if owner == "TANK" then
        return context.destGUID == playerGUID and UnitGroupRolesAssigned("player") == "TANK"
    end
    if owner == "BOSS" then return context.destGUID and not BKA:IsPlayerOrPartyGUID(context.destGUID) end
    if owner == "PARTY" then return BKA:IsPlayerOrPartyGUID(context.destGUID) end
    return true
end

function Stacks:ShouldWarn(rule, amount)
    if rule.warnFirst and amount == 1 then return true end
    if rule.warnAbove and amount > rule.warnAbove then return true end
    local warnAt = rule.warnAt or 1
    if amount < warnAt then return false end
    local every = rule.warnEvery or 1
    return every > 0 and amount % every == 0
end

function Stacks:Hide(spellID, destGUID)
    local key = "stack:" .. tostring(spellID) .. ":" .. tostring(destGUID or "")
    self.active[key] = nil
    BKA.Alerts:Hide(key)
end

function Stacks:Handle(ability, context)
    local rule = ability.stackRule or self.rulesBySpell[context.spellID or ability.id]
    if not rule or not AURA_EVENTS[context.event] or not self:OwnerAllows(rule, context) then return false end
    local spellID = context.spellID or ability.id
    local key = "stack:" .. tostring(spellID) .. ":" .. tostring(context.destGUID or "")
    local action = rule.action or ability.primaryAction or "STACK"
    local isPlayer = context.destGUID == UnitGUID("player")
    if not BKA:RoleNotificationAllows(ability, action, isPlayer) then
        self:Hide(spellID, context.destGUID)
        return true
    end
    local amount = tonumber(context.amount)
    if context.event == "SPELL_AURA_REMOVED" then amount = 0 end
    if context.event == "SPELL_AURA_APPLIED" and not amount then amount = 1 end
    amount = amount or 0
    if amount <= 0 then
        self:Hide(spellID, context.destGUID)
        return true
    end

    local spellName = context.spellName or GetSpellInfo(spellID)
    if rule.effectPercent and rule.effectKey then
        local percent = amount * rule.effectPercent
        spellName = (spellName or BKA:L("SPELL_FALLBACK", tostring(spellID))) .. "  |  " ..
            (rule.effectDual and BKA:L(rule.effectKey, percent, percent) or BKA:L(rule.effectKey, percent))
    end

    local criticalAt = tonumber(rule.criticalAt) or 0
    local severity = criticalAt > 0 and amount >= criticalAt and "CRITICAL" or ability.severity
    if (BKA.severityRank[severity] or 1) < 2 then severity = "MEDIUM" end
    self.active[key] = {
        spellID = spellID, amount = amount, sourceGUID = context.sourceGUID,
        sourceName = context.sourceName, destGUID = context.destGUID,
        destName = context.destName, auraType = context.auraType,
    }
    BKA.Alerts:Show(copyAbility(ability, severity), {
        key = key, sourceGUID = context.sourceGUID, destGUID = context.destGUID,
        spellID = spellID, spellName = spellName, targetName = context.destName,
        isPlayer = isPlayer, targetConfidence = "CONFIRMED", action = action, stackAmount = amount,
        persistent = true, silent = true, soundHandled = true,
    })

    if self:ShouldWarn(rule, amount) then
        local voice = rule.voiceAction or ability.voiceAction or action
        if voice and voice ~= "NONE" and (voice ~= "YOU" or isPlayer) then
            BKA.Sounds:PlayMechanic(voice, {
                sourceGUID = context.sourceGUID, spellID = spellID, key = key .. ":" .. amount,
                isPlayer = isPlayer, targetConfidence = "CONFIRMED", criticalPersonal = isPlayer and severity == "CRITICAL",
                personalFatal = isPlayer and severity == "CRITICAL", route = "stack",
            })
        end
    end
    return true
end

function Stacks:ClearGUID(guid)
    local keys = {}
    for key, state in pairs(self.active) do
        if state.sourceGUID == guid or state.destGUID == guid then keys[#keys + 1] = key end
    end
    for _, key in ipairs(keys) do
        self.active[key] = nil
        BKA.Alerts:Hide(key)
    end
end

function Stacks:Clear()
    local keys = {}
    for key in pairs(self.active) do keys[#keys + 1] = key end
    for _, key in ipairs(keys) do BKA.Alerts:Hide(key) end
    wipe(self.active)
    wipe(self.rulesBySpell)
end
