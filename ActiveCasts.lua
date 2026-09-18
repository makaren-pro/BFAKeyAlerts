local BKA = BFAKeyAlerts
local ActiveCasts = { byUnit = {}, bySourceSpell = {}, recentlyOwned = {}, generation = 0 }
BKA.ActiveCasts = ActiveCasts

local function readCast(unit, forceChannel)
    local name, _, texture, startMS, endMS, _, apiCastID, notInterruptible, spellID
    local isChannel = forceChannel and true or false
    if not forceChannel then
        name, _, texture, startMS, endMS, _, apiCastID, notInterruptible, spellID = UnitCastingInfo(unit)
    end
    if not name then
        name, _, texture, startMS, endMS, _, notInterruptible, spellID = UnitChannelInfo(unit)
        apiCastID = nil
        isChannel = name and true or false
    end
    if not name or not startMS or not endMS then
        return nil
    end
    return {
        unit = unit,
        sourceGUID = UnitGUID(unit),
        apiCastID = apiCastID,
        spellID = spellID,
        spellName = name,
        texture = texture,
        startTimeMS = startMS,
        startTime = startMS / 1000,
        endTime = endMS / 1000,
        notInterruptible = notInterruptible and true or false,
        isChannel = isChannel,
    }
end

local function sourceSpellKey(sourceGUID, spellID)
    if not sourceGUID or not spellID then return nil end
    return tostring(sourceGUID) .. ":" .. tostring(spellID)
end

local function castAbility(cast)
    return cast and cast.resolution and cast.resolution.ability
end

local function targetCanChange(cast)
    local ability = castAbility(cast)
    if not ability then return false end
    local behavior = BKA:NormalizeFrontalBehavior(ability.frontalBehavior)
    if behavior == "SNAPSHOT_TARGET" then return false end
    if behavior == "TRACK_TARGET" then return true end
    return ability.dynamicTarget == true
end

local function frontalTargetAllowed(cast)
    local resolution = cast and cast.resolution
    return not resolution or resolution.action ~= "FRONTAL" or BKA:IsTargetBasedFrontal(resolution.ability)
end

function ActiveCasts:BuildIdentity(castGUID, sourceGUID, spellID, startTimeMS)
    if castGUID and tostring(castGUID) ~= "" then
        return "cast:" .. tostring(castGUID), true
    end
    if sourceGUID and spellID and startTimeMS then
        return table.concat({ "runtime", tostring(sourceGUID), tostring(spellID), tostring(math.floor(startTimeMS + 0.5)) }, ":"), true
    end
    return table.concat({ "weak", tostring(sourceGUID or "?"), tostring(spellID or "?") }, ":"), false
end

function ActiveCasts:Index(cast, resolution)
    cast.indexKeys = cast.indexKeys or {}
    local spellIDs = { [cast.spellID or false] = true }
    local ability = resolution and resolution.ability
    if ability then
        if ability.id then spellIDs[ability.id] = true end
        for _, trigger in ipairs(ability.triggers or {}) do
            if trigger.spell then spellIDs[trigger.spell] = true end
        end
    end
    for spellID in pairs(spellIDs) do
        if spellID then
            local key = sourceSpellKey(cast.sourceGUID, spellID)
            if key then
                self.bySourceSpell[key] = cast
                cast.indexKeys[key] = true
            end
        end
    end
end

function ActiveCasts:Unindex(cast)
    for key in pairs(cast.indexKeys or {}) do
        if self.bySourceSpell[key] == cast then self.bySourceSpell[key] = nil end
    end
    cast.indexKeys = nil
end

function ActiveCasts:RememberOwnership(cast)
    local expires = GetTime() + 1.0
    for key in pairs(cast.indexKeys or {}) do self.recentlyOwned[key] = expires end
end

function ActiveCasts:GetBySourceSpell(sourceGUID, spellID, ability)
    local key = sourceSpellKey(sourceGUID, spellID)
    local cast = key and self.bySourceSpell[key]
    if cast then return cast end
    if ability then
        key = sourceSpellKey(sourceGUID, ability.id)
        cast = key and self.bySourceSpell[key]
        if cast then return cast end
        for _, trigger in ipairs(ability.triggers or {}) do
            key = sourceSpellKey(sourceGUID, trigger.spell)
            cast = key and self.bySourceSpell[key]
            if cast then return cast end
        end
    end
end

function ActiveCasts:WasRecentlyOwned(sourceGUID, spellID, ability)
    local now = GetTime()
    local keys = {}
    local function addKey(key)
        if key then keys[#keys + 1] = key end
    end
    addKey(sourceSpellKey(sourceGUID, spellID))
    if ability then addKey(sourceSpellKey(sourceGUID, ability.id)) end
    if ability then
        for _, trigger in ipairs(ability.triggers or {}) do addKey(sourceSpellKey(sourceGUID, trigger.spell)) end
    end
    for _, key in ipairs(keys) do
        local expires = key and self.recentlyOwned[key]
        if expires and expires >= now then return true end
        if expires then self.recentlyOwned[key] = nil end
    end
    return false
end

function ActiveCasts:Get(unit)
    return self.byUnit[unit]
end

function ActiveCasts:RecordTargetDecision(cast, evidence)
    local decision = {
        spellID = cast.spellID,
        spellName = cast.spellName,
        npcID = cast.npcID,
        npcName = cast.npcName,
        targetName = cast.targetName,
        targetRole = cast.targetRole,
        targetBehavior = cast.targetBehavior or "NONE",
        confidence = cast.targetConfidence or "NONE",
        evidence = evidence or cast.targetEvidence or "none",
        personal = cast.targetIsPlayer and cast.targetConfidence == "CONFIRMED" or false,
        frontalBehavior = cast.frontalBehavior,
        frontalState = cast.frontalBehavior == "TRACK_TARGET" and "tracking" or
            (cast.frontalBehavior == "SNAPSHOT_TARGET" and cast.targetLocked and "locked" or nil),
    }
    table.insert(BKA.targetDecisions, 1, decision)
    while #BKA.targetDecisions > 12 do table.remove(BKA.targetDecisions) end
end

function ActiveCasts:ApplyConfirmedTarget(cast, target, evidence)
    if not cast or not target or not target.guid then return false end
    if not frontalTargetAllowed(cast) then return false end
    local dynamic = targetCanChange(cast)
    if cast.targetLocked and not dynamic then return false end
    if cast.targetConfidence == "CONFIRMED" and cast.targetGUID == target.guid then return false end
    local wasPersonal = cast.targetIsPlayer and cast.targetConfidence == "CONFIRMED"
    cast.targetGUID = target.guid
    cast.targetName = target.name
    local targetRole = target.role
    if not targetRole or targetRole == "NONE" then
        targetRole = BKA:GetGroupRoleForGUID(target.guid)
    end
    cast.targetRole = targetRole or "NONE"
    cast.targetIsPlayer = target.isPlayer and true or false
    cast.targetConfidence = "CONFIRMED"
    cast.targetEvidence = evidence or "resolver"
    cast.targetLocked = not dynamic
    self:RecordTargetDecision(cast, cast.targetEvidence)
    local personal = cast.targetIsPlayer == true
    if personal and not wasPersonal then
        BKA.diagnostics.confirmedPersonalTargets = BKA.diagnostics.confirmedPersonalTargets + 1
    end
    if BKA.Logger and BKA.Logger.UpdateUnknownCastTarget then BKA.Logger:UpdateUnknownCastTarget(cast) end
    for ownedUnit in pairs(cast.units or {}) do
        if string.match(ownedUnit, "^nameplate%d+$") then BKA.Nameplates:ShowActive(cast, cast.resolution, ownedUnit) end
    end
    if cast.alertKey then
        BKA.Alerts:SetTarget(cast.alertKey, cast.generation, cast.targetName, personal, "CONFIRMED", cast.targetRole)
    end
    local resolvedVoice = cast.resolution and (cast.resolution.voiceAction or (cast.resolution.ability and cast.resolution.ability.voiceAction))
    local personalVoice = resolvedVoice == "YOU"
    if personal and not cast.alertKey and cast.presentationStarted and cast.resolution and personalVoice and
        cast.resolution.ability and BKA:RoleCenterAllows(cast.resolution.ability, true, cast.resolution.action) then
        cast.alertKey = "active:" .. tostring(cast.identity)
        BKA.Alerts:Show(cast.resolution.ability, {
            key = cast.alertKey, ownerUnit = cast.unit, ownerGeneration = cast.generation,
            sourceGUID = cast.sourceGUID, destGUID = cast.targetGUID, spellID = cast.spellID,
            spellName = cast.spellName, texture = cast.texture, targetName = cast.targetName,
            targetRole = cast.targetRole, isPlayer = true, targetConfidence = "CONFIRMED",
            action = cast.resolution.action, startTime = cast.startTime, endTime = cast.endTime,
            alertState = "ACTIVE", soundHandled = true, forceCenter = true,
        })
    end
    if personal and not wasPersonal and cast.presentationStarted and cast.resolution and cast.resolution.ability then
        local configuredVoice = cast.resolution.voiceAction or cast.resolution.ability.voiceAction
        if configuredVoice == "YOU" then
            BKA.Sounds:PlayMechanic("YOU", {
                sourceGUID = cast.sourceGUID, spellID = cast.spellID,
                castIdentity = cast.identity, stableIdentity = cast.identityStable,
                startTimeMS = cast.startTimeMS, generation = cast.generation,
                isPlayer = true, targetConfidence = "CONFIRMED",
                personalFatal = cast.resolution.severity == "CRITICAL",
                criticalPersonal = cast.resolution.severity == "CRITICAL",
                route = "target-confirmed",
            })
        end
    end
    return true
end

function ActiveCasts:AcquireSourceTarget(cast)
    if not cast or cast.targetBehavior ~= "SOURCE_TARGET" or not frontalTargetAllowed(cast) then return end
    if cast.targetLocked and not targetCanChange(cast) then return end
    local identity = cast.identity
    local targetBasedFrontal = cast.resolution and cast.resolution.action == "FRONTAL" and
        BKA:IsTargetBasedFrontal(cast.resolution.ability)
    local personalVoice = cast.resolution and (cast.resolution.voiceAction == "YOU" or
        (cast.resolution.ability and cast.resolution.ability.voiceAction == "YOU"))
    local delayedTargetTruth = targetBasedFrontal or personalVoice
    if delayedTargetTruth and not cast.initialFrontalTargetDeferred then
        cast.initialFrontalTargetDeferred = true
        local initial = BKA.Targets:GetCurrentTarget(cast.sourceGUID)
        if initial then
            BKA.diagnostics.heuristicTargetsIgnored = BKA.diagnostics.heuristicTargetsIgnored + 1
        end
    end
    BKA.Targets:ResolveSourceTarget(cast.sourceGUID, function(target)
        if ActiveCasts:IsIdentityActive(identity) then
            ActiveCasts:ApplyConfirmedTarget(cast, target,
                delayedTargetTruth and "post-start resolver window" or "resolver")
        end
    end, delayedTargetTruth and { confirmAfterWindow = true } or nil)
end

function ActiveCasts:ConfirmDestination(sourceGUID, spellID, ability, destGUID, destName, evidence)
    if not destGUID then return false end
    local cast = self:GetBySourceSpell(sourceGUID, spellID, ability)
    if not cast then return false end
    local behavior = ability and (ability.targetBehavior or ability.target) or "NONE"
    if behavior ~= "DESTINATION" and behavior ~= "PLAYER" and behavior ~= "PARTY" then return false end
    return self:ApplyConfirmedTarget(cast, {
        guid = destGUID,
        name = destName,
        isPlayer = destGUID == UnitGUID("player"),
        isParty = BKA:IsPlayerOrPartyGUID(destGUID),
        role = BKA:GetGroupRoleForGUID(destGUID),
    }, evidence or "combat-log destination")
end

function ActiveCasts:IsIdentityActive(identity)
    for _, cast in pairs(self.byUnit) do
        if cast.identity == identity then return true end
    end
    return false
end

function ActiveCasts:GetBySource(sourceGUID, spellID, startTime)
    for unit, cast in pairs(self.byUnit) do
        if cast.sourceGUID == sourceGUID and (not spellID or cast.spellID == spellID) and (not startTime or math.abs((cast.startTime or 0) - startTime) < 0.01) then
            return cast, unit
        end
    end
end

function ActiveCasts:ReleaseCast(cast)
    if not cast then return false end
    BKA.Sounds:CancelCastIdentity(cast.identity)
    self:RememberOwnership(cast)
    self:Unindex(cast)
    local units = {}
    for unit, owned in pairs(self.byUnit) do
        if owned == cast then units[#units + 1] = unit end
    end
    for _, unit in ipairs(units) do
        self.byUnit[unit] = nil
        BKA.Nameplates:ClearActive(unit, cast.generation)
    end
    if cast.alertKey then
        BKA.Alerts:Hide(cast.alertKey, cast.generation)
    end
    return true
end

function ActiveCasts:Start(unit, eventCastGUID, eventSpellID, forceChannel)
    if not BKA.active or not UnitExists(unit) or UnitIsFriend("player", unit) then
        return nil
    end
    local cast = readCast(unit, forceChannel)
    if not cast then
        return nil
    end
    cast.spellID = cast.spellID or eventSpellID or (BKA.spellNameToID and BKA.spellNameToID[cast.spellName])
    local recent = BKA.recentSourceCasts and BKA.recentSourceCasts[cast.sourceGUID]
    if not cast.spellID and recent and recent.expires >= GetTime() and recent.spellName == cast.spellName then
        cast.spellID = recent.spellID
    end
    local existing = self.byUnit[unit]
    local sameStart = existing and math.abs((existing.startTime or 0) - cast.startTime) < 0.01
    local sameIdentity = not eventCastGUID or not existing or not existing.hasEventCastGUID or tostring(eventCastGUID) == tostring(existing.castGUID)
    if existing and sameStart and sameIdentity and existing.sourceGUID == cast.sourceGUID and existing.spellID == cast.spellID then
        if eventCastGUID and not existing.hasEventCastGUID then
            existing.castGUID = eventCastGUID
            existing.hasEventCastGUID = true
        end
        return self:Resync(unit, eventCastGUID, eventSpellID, forceChannel)
    end
    if existing then
        BKA.Sounds:CancelCastIdentity(existing.identity)
        self:ReleaseCast(existing)
    end

    local sibling = self:GetBySource(cast.sourceGUID, cast.spellID, cast.startTime)
    if sibling then
        self.byUnit[unit] = sibling
        sibling.units[unit] = true
        if eventCastGUID and not sibling.hasEventCastGUID then
            sibling.castGUID = eventCastGUID
            sibling.hasEventCastGUID = true
        end
        if string.match(unit, "^nameplate%d+$") then
            BKA.Nameplates:ShowActive(sibling, sibling.resolution, unit)
        end
        return sibling
    end
    cast.castGUID = eventCastGUID or cast.apiCastID
    cast.hasEventCastGUID = eventCastGUID and true or false
    cast.identity, cast.identityStable = self:BuildIdentity(eventCastGUID, cast.sourceGUID, cast.spellID, cast.startTimeMS)
    cast.npcID = BKA:GetNPCID(cast.sourceGUID)
    cast.npcName = UnitName(unit)
    cast.targetGUID, cast.targetName, cast.targetRole, cast.targetIsPlayer = nil, nil, "NONE", false
    cast.targetConfidence, cast.targetEvidence, cast.targetLocked = "NONE", "none", false
    self.generation = self.generation + 1
    cast.generation = self.generation
    cast.units = { [unit] = true }
    self.byUnit[unit] = cast
    BKA.Targets:AddUnit(unit)

    local resolution = BKA:ResolveObservedCast(cast)
    cast.resolution = resolution
    cast.targetBehavior = resolution.ability and (resolution.ability.targetBehavior or resolution.ability.target) or "NONE"
    if resolution.action == "FRONTAL" then
        cast.frontalBehavior = BKA:NormalizeFrontalBehavior(resolution.ability and resolution.ability.frontalBehavior)
        self:RecordTargetDecision(cast, "cast start")
    end
    if cast.targetBehavior == "SOURCE_TARGET" then cast.targetAcquireUntil = GetTime() + 0.55 end
    self:Index(cast, resolution)
    self:AcquireSourceTarget(cast)
    BKA.Timers:CancelPrewarning(cast.spellID, cast.sourceGUID)
    if resolution.ability and resolution.ability.id and resolution.ability.id ~= cast.spellID then
        BKA.Timers:CancelPrewarning(resolution.ability.id, cast.sourceGUID)
    end
    if resolution.ability then
        BKA.Alerts:HideCastPresentation(cast.sourceGUID, cast.indexKeys)
    end

    if resolution.suppressAlert then
        BKA.Nameplates:ClearActive(unit)
        return cast
    end

    local ability = resolution.ability
    local personal = cast.targetIsPlayer and cast.targetConfidence == "CONFIRMED"
    local roleAllowed = BKA:RoleAllows(ability, cast.targetGUID) or BKA:IsGlobalAction(resolution.action, personal)
    if not roleAllowed or not BKA:RoleNotificationAllows(ability, resolution.action, personal) then
        BKA.Nameplates:ClearActive(unit)
        if resolution.shouldLog then BKA.Logger:RecordUnknownCast(cast) end
        return cast
    end

    local voiceAction = resolution.voiceAction or resolution.action
    local personalVoice = voiceAction == "YOU"
    local shouldSound = voiceAction and voiceAction ~= "NONE" and (not personalVoice or personal)
    if resolution.policy and resolution.policy.sound ~= nil then
        shouldSound = resolution.policy.sound and (not personalVoice or personal)
    end
    if shouldSound then
        BKA.Sounds:PlayMechanic(voiceAction, {
            sourceGUID = cast.sourceGUID, spellID = cast.spellID,
            castIdentity = cast.identity, stableIdentity = cast.identityStable,
            startTimeMS = cast.startTimeMS, generation = cast.generation,
            isPlayer = personal, targetConfidence = cast.targetConfidence,
            personalFatal = personal and resolution.severity == "CRITICAL",
            criticalPersonal = personal and resolution.severity == "CRITICAL",
            route = "active-cast", primaryAction = resolution.action,
        })
    end

    if string.match(unit, "^nameplate%d+$") then
        BKA.Nameplates:ShowActive(cast, resolution)
    end
    if resolution.center and (not personalVoice or personal) then
        cast.alertKey = "active:" .. tostring(cast.identity)
        BKA.Alerts:Show(resolution.ability, {
            key = cast.alertKey,
            ownerUnit = unit,
            ownerGeneration = cast.generation,
            sourceGUID = cast.sourceGUID,
            destGUID = cast.targetGUID,
            spellID = cast.spellID,
            spellName = cast.spellName,
            texture = cast.texture,
            targetName = cast.targetName,
            targetRole = cast.targetRole,
            isPlayer = personal,
            targetConfidence = cast.targetConfidence,
            action = resolution.action,
            startTime = cast.startTime,
            endTime = cast.endTime,
            alertState = "ACTIVE",
            soundHandled = true,
            forceCenter = resolution.center,
            safetyNetCounted = resolution.centerPromoted,
        })
    end
    cast.presentationStarted = true
    if resolution.shouldLog then
        BKA.Logger:RecordUnknownCast(cast)
    end
    return cast
end

function ActiveCasts:Resync(unit, eventCastGUID, eventSpellID, forceChannel)
    local old = self.byUnit[unit]
    if not old then
        return self:Start(unit, eventCastGUID, eventSpellID, forceChannel)
    end
    if eventCastGUID and old.hasEventCastGUID and tostring(eventCastGUID) ~= tostring(old.castGUID) then
        return nil
    end
    local fresh = readCast(unit, forceChannel)
    if not fresh then
        return
    end
    old.startTime = fresh.startTime
    old.endTime = fresh.endTime
    old.texture = fresh.texture or old.texture
    old.notInterruptible = fresh.notInterruptible
    old.isChannel = fresh.isChannel
    if eventCastGUID and old.hasEventCastGUID then
        old.castGUID = eventCastGUID
    end
    local previousAction = old.resolution and old.resolution.action
    local previousNameplateAction = old.resolution and old.resolution.nameplateAction
    local previousVoiceAction = old.resolution and old.resolution.voiceAction
    local resolution = BKA:ResolveObservedCast(old)
    if resolution and (resolution.action ~= previousAction or resolution.nameplateAction ~= previousNameplateAction or resolution.voiceAction ~= previousVoiceAction) then
        old.resolution = resolution
        BKA.Sounds:CancelCastIdentity(old.identity)
        local ability = resolution.ability
        local voiceAction = resolution.voiceAction or resolution.action
        local personal = old.targetIsPlayer and old.targetConfidence == "CONFIRMED"
        local personalVoice = voiceAction == "YOU"
        local shouldSound = voiceAction and voiceAction ~= "NONE" and (not personalVoice or personal)
        if resolution.policy and resolution.policy.sound ~= nil then
            shouldSound = resolution.policy.sound and (not personalVoice or personal)
        end
        if shouldSound and not resolution.suppressAlert and BKA:RoleAllows(ability, old.targetGUID) and BKA:RoleNotificationAllows(ability, resolution.action, personal) then
            BKA.Sounds:PlayMechanic(voiceAction, {
                sourceGUID = old.sourceGUID, spellID = old.spellID,
                castIdentity = old.identity, stableIdentity = old.identityStable,
                startTimeMS = old.startTimeMS, generation = old.generation,
                isPlayer = personal, targetConfidence = old.targetConfidence,
                personalFatal = personal and resolution.severity == "CRITICAL",
                criticalPersonal = personal and resolution.severity == "CRITICAL",
                route = "active-cast-resync", primaryAction = resolution.action,
            })
        end
    end
    for ownedUnit in pairs(old.units or { [unit] = true }) do
        if string.match(ownedUnit, "^nameplate%d+$") then
            BKA.Nameplates:ShowActive(old, old.resolution, ownedUnit)
        end
    end
    if old.alertKey then
        BKA.Alerts:Resync(old.alertKey, old.generation, old.startTime, old.endTime, old.texture)
    end
    return old
end

function ActiveCasts:UpdateTarget(unit)
    local cast = self.byUnit[unit]
    if not cast then return end
    if cast.targetBehavior ~= "SOURCE_TARGET" then return end
    if not frontalTargetAllowed(cast) then return end
    local dynamic = targetCanChange(cast)
    if cast.targetLocked and not dynamic then return end
    if not dynamic and cast.targetAcquireUntil and GetTime() > cast.targetAcquireUntil then return end
    local target = BKA.Targets:GetCurrentTarget(cast.sourceGUID)
    if target then self:ApplyConfirmedTarget(cast, target, "UNIT_TARGET resolver") end
end

function ActiveCasts:Stop(unit, eventCastGUID, eventSpellID)
    local cast = self.byUnit[unit]
    if not cast then
        return false
    end
    if eventCastGUID and cast.hasEventCastGUID and tostring(eventCastGUID) ~= tostring(cast.castGUID) then
        return false
    end
    if (not eventCastGUID or not cast.hasEventCastGUID) and eventSpellID and cast.spellID and eventSpellID ~= cast.spellID then
        return false
    end
    if eventCastGUID and not cast.hasEventCastGUID then
        local current = readCast(unit)
        if current and math.abs(current.startTime - cast.startTime) < 0.01 then
            local generation = cast.generation
            C_Timer.After(0, function()
                local pending = ActiveCasts.byUnit[unit]
                if not pending or pending.generation ~= generation then return end
                local stillCasting = readCast(unit)
                if not stillCasting or math.abs(stillCasting.startTime - pending.startTime) >= 0.01 then
                    ActiveCasts:ReleaseCast(pending)
                end
            end)
            return false
        end
    end
    if not eventCastGUID then
        local current = readCast(unit)
        if current and current.startTime > cast.startTime + 0.01 then return false end
    end
    return self:ReleaseCast(cast)
end

function ActiveCasts:Expire(unit, generation)
    local cast = self.byUnit[unit]
    if not cast then
        for _, candidate in pairs(self.byUnit) do
            if candidate.generation == generation then cast = candidate break end
        end
    end
    if not cast or cast.generation ~= generation then
        return false
    end
    return self:ReleaseCast(cast)
end

function ActiveCasts:UnitGone(unit)
    local cast = self.byUnit[unit]
    if not cast then
        return
    end
    self.byUnit[unit] = nil
    if cast.units then cast.units[unit] = nil end
    local replacement
    for ownedUnit, owned in pairs(self.byUnit) do
        if owned == cast then replacement = ownedUnit break end
    end
    if replacement then
        if cast.unit == unit then cast.unit = replacement end
    elseif cast.alertKey then
        BKA.Sounds:CancelCastIdentity(cast.identity)
        BKA.Alerts:Hide(cast.alertKey, cast.generation)
        self:RememberOwnership(cast)
        self:Unindex(cast)
    else
        BKA.Sounds:CancelCastIdentity(cast.identity)
        self:RememberOwnership(cast)
        self:Unindex(cast)
    end
end

function ActiveCasts:StopSource(sourceGUID)
    local units = {}
    for unit, cast in pairs(self.byUnit) do if cast.sourceGUID == sourceGUID then units[#units + 1] = unit end end
    for _, unit in ipairs(units) do
        local cast = self.byUnit[unit]
        if cast then self:Stop(unit, cast.castGUID, cast.spellID) end
    end
end

function ActiveCasts:Clear()
    local units = {}
    for unit in pairs(self.byUnit) do units[#units + 1] = unit end
    for _, unit in ipairs(units) do
        local cast = self.byUnit[unit]
        if cast then self:Stop(unit, cast.castGUID, cast.spellID) end
    end
    wipe(self.byUnit)
    wipe(self.bySourceSpell)
    wipe(self.recentlyOwned)
end
