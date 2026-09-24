local BKA = BFAKeyAlerts

local HOT_EVENTS = {
    "COMBAT_LOG_EVENT_UNFILTERED",
    "NAME_PLATE_UNIT_ADDED",
    "NAME_PLATE_UNIT_REMOVED",
    "UNIT_SPELLCAST_START",
    "UNIT_SPELLCAST_CHANNEL_START",
    "UNIT_SPELLCAST_DELAYED",
    "UNIT_SPELLCAST_CHANNEL_UPDATE",
    "UNIT_SPELLCAST_STOP",
    "UNIT_SPELLCAST_CHANNEL_STOP",
    "UNIT_SPELLCAST_INTERRUPTED",
    "UNIT_SPELLCAST_FAILED",
    "UNIT_SPELLCAST_SUCCEEDED",
    "UNIT_TARGET",
    "UNIT_AURA",
    "ENCOUNTER_START",
    "ENCOUNTER_END",
    "GROUP_ROSTER_UPDATE",
}

local SAFE_SOURCE_EVENTS = {
    CHAT_MSG_RAID_BOSS_EMOTE = true,
    CHAT_MSG_MONSTER_YELL = true,
    CHAT_MSG_MONSTER_SAY = true,
}


local TANK_ONLY_SPELLS = {
    -- Evidence-backed tank-only mechanics that were imported as role=ALL.
    -- Keep group-response mechanics (interrupts, dispels, real frontals) out of this list.
    [252687] = true, -- Venomfang Strike, Atal'Dazar trash
    [255434] = true, -- Serrated Teeth, Rezan
    [255579] = true, -- Gilded Claws, Priestess Alun'za (tank pressure window)
    [258079] = true, -- Massive Chomp, Tol Dagor trash
    [260512] = true, -- Soul Harvest stacks, Soulbound Goliath
    [261438] = true, -- Wasting Strike, Lord Waycrest
    [264556] = true, -- Tearing Strike, Waycrest Thornguard
    [265760] = true, -- Thorned Barrage, Matron Bryndle
    [265881] = true, -- Decaying Touch, Matron Alma
    [274400] = true, -- Poisoning Strike, Freehold Irontide Corsair
    [274555] = true, -- Scabrous Bite, Freehold shiprats
}


local DAMAGE_EVENTS = {
    SPELL_DAMAGE = true,
    SPELL_PERIODIC_DAMAGE = true,
    SPELL_MISSED = true,
    SPELL_PERIODIC_MISSED = true,
}

local function sourceMatches(ability, npcID)
    if not ability.sourceSet or not next(ability.sourceSet) then
        return true
    end
    return npcID and ability.sourceSet[npcID] or false
end

function BKA:BuildPartyGUIDs()
    self.partyGUIDs = self.partyGUIDs or {}
    wipe(self.partyGUIDs)
    local playerGUID = UnitGUID("player")
    if playerGUID then
        self.partyGUIDs[playerGUID] = true
    end
    for i = 1, 4 do
        local guid = UnitGUID("party" .. i)
        if guid then
            self.partyGUIDs[guid] = true
        end
    end
end

function BKA:FindCurrentDungeon()
    if C_ChallengeMode and C_ChallengeMode.GetActiveChallengeMapID then
        local challengeMapID = C_ChallengeMode.GetActiveChallengeMapID()
        if challengeMapID and self.dungeonByChallengeMap[challengeMapID] then
            return self.dungeonByChallengeMap[challengeMapID]
        end
    end
    local inInstance = IsInInstance()
    if inInstance then
        local instanceMapID = select(8, GetInstanceInfo())
        return self.dungeonByInstanceMap[instanceMapID]
    end
end

function BKA:CompileDungeon(dungeon)
    self.byEventSpell = {}
    self.bySpell = {}
    self.spellNameToID = {}
    self:ApplyGeometryExtras(dungeon)
    self.activeAbilities = dungeon.abilities
    self.SpecialHandlers:ApplyCorrections(dungeon)
    self.Stacks:Compile(dungeon.abilities)
    for _, ability in ipairs(dungeon.abilities) do
        self:ApplyGeometryPolicy(ability)
        if TANK_ONLY_SPELLS[ability.id] then
            ability.role = "TANK"
            ability.tankOnly = true
        end
        ability.primaryAction = ability.primaryAction or self:NormalizeAction(ability.action, ability.mechanic)
        if ability.primaryAction == "YOU" then ability.primaryAction = "TARGETED" end
        if ability.action == "YOU" then ability.action = "TARGETED" end
        if ability.mechanic == "YOU" then ability.mechanic = "TARGETED" end
        ability.castControl = ability.castControl or (ability.mechanic == "INTERRUPT" and "KICK" or "NONE")
        ability.kickPriority = ability.kickPriority or (ability.castControl == "KICK" and "NORMAL" or "NONE")
        ability.voiceAction = ability.voiceAction or (ability.sound and ability.primaryAction or "NONE")
        ability.targetBehavior = ability.targetBehavior or ability.target or "NONE"
        if self:IsGeometryAction(ability.primaryAction, ability.mechanic) then
            ability.nameplate = true -- geometry must stay anchored to its caster
            if self:NormalizeAction(ability.primaryAction, ability.mechanic) == "FRONTAL" then
                ability.frontalBehavior = self:NormalizeFrontalBehavior(ability.frontalBehavior)
            end
        end
        ability.centerPolicy = ability.centerPolicy or (ability.center == true and "ALWAYS" or nil)
        if not ability.presentationTier then
            if ability.personalOnly then
                ability.presentationTier = "PERSONAL"
            elseif ability.severity == "CRITICAL" then
                ability.presentationTier = "CRITICAL"
            elseif ability.center or ability.severity == "HIGH" then
                ability.presentationTier = "IMPORTANT"
            elseif ability.nameplate then
                ability.presentationTier = "NAMEPLATE_ONLY"
            else
                ability.presentationTier = "INFO"
            end
        end
        local policy = self:GetInterruptPolicy(nil, ability.id)
        local stopPolicy = self:GetStopPolicy(nil, ability.id)
        for _, trigger in ipairs(ability.triggers or {}) do
            policy = policy or self:GetInterruptPolicy(nil, trigger.spell)
            stopPolicy = stopPolicy or self:GetStopPolicy(nil, trigger.spell)
        end
        if policy then
            ability.interruptPolicy = policy.policy
            ability.castControl = policy.policy
            ability.suppressAlert = policy.suppressAlert
            ability.strategicReason = policy.reason
            if policy.suppressAlert then
                ability.center, ability.nameplate, ability.sound = false, false, false
            elseif policy.action then
                ability.primaryAction, ability.action = policy.action, policy.action
                ability.voiceAction = policy.sound == false and "NONE" or policy.action
            end
            if policy.sound ~= nil then ability.sound = policy.sound end
        elseif stopPolicy then
            ability.interruptPolicy = "STOP"
            ability.castControl = "STOP"
            if ability.primaryAction == "CAST" or ability.primaryAction == "INFO" then
                ability.primaryAction, ability.action = "STOP", "STOP"
            end
            ability.voiceAction = "STOP"
            ability.severity, ability.center, ability.nameplate, ability.sound = "HIGH", true, true, true
            ability.strategicReason = stopPolicy.reason
        end
        local indexedSpells = {}
        ability.sourceSet = ability.sourceSet or {}
        for _, npcID in ipairs(ability.sources or {}) do
            ability.sourceSet[npcID] = true
        end
        for _, trigger in ipairs(ability.triggers or {}) do
            local eventIndex = self.byEventSpell[trigger.event]
            if not eventIndex then
                eventIndex = {}
                self.byEventSpell[trigger.event] = eventIndex
            end
            local list = eventIndex[trigger.spell]
            if not list then
                list = {}
                eventIndex[trigger.spell] = list
            end
            list[#list + 1] = ability
            indexedSpells[trigger.spell] = true
            local spellList = self.bySpell[trigger.spell]
            if not spellList then
                spellList = {}
                self.bySpell[trigger.spell] = spellList
            end
            spellList[#spellList + 1] = ability
            local name = GetSpellInfo(trigger.spell)
            if name then
                self.spellNameToID[name] = trigger.spell
            end
        end
        if ability.nameplate and ability.id and not indexedSpells[ability.id] then
            local spellList = self.bySpell[ability.id]
            if not spellList then
                spellList = {}
                self.bySpell[ability.id] = spellList
            end
            spellList[#spellList + 1] = ability
            local name = GetSpellInfo(ability.id)
            if name then
                self.spellNameToID[name] = ability.id
            end
        end
    end
    local learned = self.db.firestorm.cursedPulseSpellID
    if learned and learned > 0 then
        local learnedName = GetSpellInfo(learned)
        if learnedName then self.spellNameToID[learnedName] = learned end
    end
end

function BKA:GetAbilityForUnitSpell(npcID, spellID)
    local affix = self.Affixes:GetKnownAbility(spellID)
    if affix then
        return affix
    end
    local list = self.bySpell and self.bySpell[spellID]
    if not list then
        return nil
    end
    local fallback
    for _, ability in ipairs(list) do
        if sourceMatches(ability, npcID) then
            fallback = fallback or ability
            for _, trigger in ipairs(ability.triggers or {}) do
                if trigger.event == "SPELL_CAST_START" or trigger.event == "SPELL_CAST_SUCCESS" then
                    return ability
                end
            end
        end
    end
    return fallback
end

function BKA:FindAbilityByID(spellID, npcID, handler)
    for _, ability in ipairs(self.activeAbilities or {}) do
        if ability.id == spellID and (not npcID or sourceMatches(ability, npcID)) and (not handler or ability.handler == handler) then
            return ability
        end
    end
end

function BKA:ResolveRuntimeAction(ability, sourceGUID, sourceUnit, knownNotInterruptible)
    local primaryAction = self:NormalizeAction(ability.primaryAction or ability.action, ability.mechanic)
    if ability.castControl == "IGNORE" then return primaryAction end
    if ability.castControl == "STOP" and (primaryAction == "CAST" or primaryAction == "INFO") then return "STOP" end
    if ability.castControl ~= "KICK" or primaryAction ~= "KICK" then return primaryAction end
    sourceUnit = sourceUnit or (sourceGUID and self.Targets:GetUnit(sourceGUID))
    local notInterruptible = knownNotInterruptible
    if notInterruptible == nil then
        notInterruptible = ability.interruptible == false
        if sourceUnit then
            if UnitCastingInfo(sourceUnit) then
                notInterruptible = select(8, UnitCastingInfo(sourceUnit))
            elseif UnitChannelInfo(sourceUnit) then
                notInterruptible = select(7, UnitChannelInfo(sourceUnit))
            end
        end
    end
    if notInterruptible then
        return "CAST"
    end
    return "KICK"
end

function BKA:ResolveObservedCast(cast)
    local policy = self:GetInterruptPolicy(cast.npcID, cast.spellID)
    local stopPolicy = self:GetStopPolicy(cast.npcID, cast.spellID)
    local ability = cast.spellID and self:GetAbilityForUnitSpell(cast.npcID, cast.spellID)
    local severity = ability and ability.severity or "MEDIUM"
    if stopPolicy then severity = "HIGH" end
    local action, nameplateAction, voiceAction, controlAction

    if policy and policy.policy == "IGNORE" then
        if policy.suppressAlert then
            return { policy = policy, ability = ability, suppressAlert = true, center = false, shouldLog = not ability }
        end
        action = policy.action or (ability and ability.primaryAction) or "CAST"
        local geometry = ability and self:NormalizeAction(ability.primaryAction or ability.action, ability.mechanic)
        nameplateAction = self:IsGeometryAction(geometry) and geometry or action
        voiceAction = policy.sound == false and "NONE" or action
    elseif ability then
        local primary = self:NormalizeAction(ability.primaryAction or ability.action, ability.mechanic)
        local control = ability.castControl or (ability.mechanic == "INTERRUPT" and "KICK" or "NONE")
        if control == "KICK" and not cast.notInterruptible then
            controlAction = "KICK"
        elseif control == "STOP" or stopPolicy or (policy and policy.policy == "STOP") then
            controlAction = "STOP"
        end
        if primary == "KICK" and control == "KICK" and cast.notInterruptible and ability.stopIfUninterruptible then
            action = "CAST"
        else
            action = primary ~= "CAST" and primary ~= "INFO" and primary or controlAction or "CAST"
        end
        -- Geometry and cast control are orthogonal: a frontal can also be a KICK/CC.
        -- Keep the geometric shape as the primary plate language and carry control
        -- as a badge instead of replacing the whole plate with STOP/KICK.
        nameplateAction = self:IsGeometryAction(primary) and primary or controlAction or action
        voiceAction = ability.voiceAction ~= nil and ability.voiceAction or (ability.sound and action or "NONE")
        if action == "CAST" and primary == "KICK" and ability.stopIfUninterruptible then voiceAction = "NONE" end
        if ability.kickPriority == "LOW" and voiceAction == "KICK" then voiceAction = "NONE" end
    else
        action = cast.notInterruptible and "CAST" or "KICK"
        nameplateAction, voiceAction = action, action == "KICK" and "KICK" or "NONE"
    end

    local synthetic = ability or {
        id = cast.spellID or 0, mechanic = action, action = action,
        severity = severity, center = stopPolicy and true or false, nameplate = true,
        sound = stopPolicy and true or false, role = "ALL",
    }
    local center, promoted = self:ShouldCenterAbility(synthetic, action, {
        sourceGUID = cast.sourceGUID,
        isPlayer = cast.targetIsPlayer,
        targetConfidence = cast.targetConfidence,
    })
    if stopPolicy then center, promoted = true, false end
    if promoted and not cast.centerSafetyNetPromoted then
        cast.centerSafetyNetPromoted = true
        self.diagnostics.centerSafetyNetPromotions = self.diagnostics.centerSafetyNetPromotions + 1
    end
    return {
        policy = policy, ability = synthetic, action = action, severity = severity,
        nameplateAction = nameplateAction or action, voiceAction = voiceAction or action,
        controlAction = controlAction or (ability and ability.ccCapable and "CC" or nil),
        center = center, centerPromoted = promoted, suppressAlert = false, shouldLog = not ability,
    }
end

function BKA:DispatchUnitSpell(unit, combatEvent, spellID)
    if not spellID or not UnitExists(unit) or UnitIsFriend("player", unit) then
        return
    end
    local eventIndex = self.byEventSpell and self.byEventSpell[combatEvent]
    local abilities = eventIndex and eventIndex[spellID]
    if not abilities then
        return
    end
    local sourceGUID = UnitGUID(unit)
    local context = {
        event = combatEvent,
        sourceGUID = sourceGUID,
        sourceName = UnitName(unit),
        npcID = self:GetNPCID(sourceGUID),
        spellID = spellID,
        spellName = GetSpellInfo(spellID),
    }
    for _, ability in ipairs(abilities) do
        self:DispatchAbility(ability, context)
    end
end

function BKA:RegisterHotEvents(dungeon)
    for _, event in ipairs(HOT_EVENTS) do
        self.eventFrame:RegisterEvent(event)
    end
    for _, event in ipairs(dungeon.sourceEvents or {}) do
        if SAFE_SOURCE_EVENTS[event] then
            self.eventFrame:RegisterEvent(event)
        end
    end
    for _, event in ipairs(self.SpecialHandlers:GetEvents(dungeon.key)) do
        self.eventFrame:RegisterEvent(event)
    end
end

function BKA:UnregisterHotEvents()
    for _, event in ipairs(HOT_EVENTS) do
        self.eventFrame:UnregisterEvent(event)
    end
    for event in pairs(SAFE_SOURCE_EVENTS) do
        self.eventFrame:UnregisterEvent(event)
    end
    for event in pairs(self.SpecialHandlers.allEvents) do
        self.eventFrame:UnregisterEvent(event)
    end
end

function BKA:Activate(dungeon)
    if self.active and self.activeDungeon == dungeon then
        self.Affixes:Refresh()
        return
    end
    self:Deactivate()
    self:ResetRunDiagnostics()
    self.active = true
    self.activeDungeon = dungeon
    self:CompileDungeon(dungeon)
    self:BuildPartyGUIDs()
    self.Targets:RefreshBossUnits()
    self:RegisterHotEvents(dungeon)
    self.Affixes:Refresh()
end

function BKA:Deactivate()
    if not self.active and not self.activeDungeon then
        return
    end
    self.active = false
    self:UnregisterHotEvents()
    self.Alerts:Clear()
    self.Timers:Clear()
    self.Nameplates:Clear()
    self.Targets:Clear()
    self.Logger:ClearRuntime()
    self.ActiveCasts:Clear()
    self.Sounds:Clear()
    self.Stacks:Clear()
    self.Affixes:Clear()
    self.SpecialHandlers:Reset()
    self.activeDungeon = nil
    self.activeAbilities = nil
    self.byEventSpell = nil
    self.bySpell = nil
    self.recentSourceCasts = nil
    self.throttles = nil
    self.specialState = nil
end

function BKA:RefreshActivation()
    if not self.db or not self.db.enabled then
        self:Deactivate()
        return
    end
    local dungeon = self:FindCurrentDungeon()
    if dungeon then
        self:Activate(dungeon)
    else
        self:Deactivate()
    end
end

function BKA:ResetCompletionSound()
    self.completionSoundGeneration = (self.completionSoundGeneration or 0) + 1
    self.completionSoundPlayed = false
    self.completionSoundIdentity = nil
end

function BKA:ResolveCompletionSound(generation, finalAttempt)
    if generation ~= self.completionSoundGeneration or self.completionSoundPlayed then return end
    if not C_ChallengeMode or not C_ChallengeMode.GetCompletionInfo then return end
    local mapID, level, completionTime, onTime, upgrades, practiceRun = C_ChallengeMode.GetCompletionInfo()
    if not mapID or not level or onTime == nil then return end
    local identity = table.concat({ tostring(mapID), tostring(level), tostring(completionTime or "?") }, ":")
    local upgradeCount = tonumber(upgrades)
    if onTime == true and practiceRun ~= true and (not upgradeCount or upgradeCount < 1) and not finalAttempt then
        return
    end
    self.completionSoundPlayed = true
    self.completionSoundIdentity = identity
    local upgraded = onTime == true and practiceRun ~= true and upgradeCount and upgradeCount >= 1
    if not upgraded and finalAttempt and onTime == true and practiceRun ~= true then
        upgraded = true
    end
    if upgraded then
        self.Sounds:PlayKeyUpgrade(false)
    end
end

function BKA:BeginCompletionSound()
    self.completionSoundGeneration = (self.completionSoundGeneration or 0) + 1
    local generation = self.completionSoundGeneration
    local delays = { 0, 0.10, 0.30, 0.75 }
    for index, delay in ipairs(delays) do
        C_Timer.After(delay, function()
            BKA:ResolveCompletionSound(generation, index == #delays)
        end)
    end
end

function BKA:RoleAllows(ability, destGUID)
    if destGUID == UnitGUID("player") or not self.db.roleFilter or ability.role == "ALL" then
        return true
    end
    local role = UnitGroupRolesAssigned and UnitGroupRolesAssigned("player") or "NONE"
    return ability.role == role
end

function BKA:IsGlobalAction(action, isPlayer)
    if isPlayer then return true end
    action = self.Sounds and self.Sounds:Normalize(action) or self:NormalizeAction(action, action)
    return action == "KICK" or action == "STOP" or action == "TURN" or action == "MOVE" or action == "RUN" or action == "YOU"
end

function BKA:RoleNotificationAllows(ability, action, isPlayer)
    -- Explicit role toggles are hard presentation gates. They must run before
    -- global-action semantics so a tank-only MOVE/FRONTAL/STACK can never leak
    -- into a DPS player's center alert, sound, or nameplate presentation.
    local tankOnly = ability.role == "TANK" or ability.tankOnly or ability.mechanic == "TANK"
    if tankOnly and not self.db.showTankAlerts then return false end
    if ability.role == "HEALER" and not self.db.showHealerAlerts then return false end
    if self:IsGlobalAction(action, isPlayer) then return true end
    return true
end

function BKA:RoleCenterAllows(ability, isPlayer, action)
    return self:RoleNotificationAllows(ability, action or ability.primaryAction or ability.action or ability.mechanic, isPlayer)
end

function BKA:DispatchAbility(ability, context)
    if not sourceMatches(ability, context.npcID) then
        return
    end
    local interruptPolicy = self:GetInterruptPolicy(context.npcID, context.spellID or ability.id)
    if interruptPolicy and interruptPolicy.policy == "IGNORE" and interruptPolicy.suppressAlert then
        return
    end
    if ability.personalOnly and context.destGUID ~= UnitGUID("player") then
        return
    end
    if ability.stackRule and self.Stacks:Handle(ability, context) then
        return
    end
    if ability.stack and context.amount and context.amount < ability.stack then
        return
    end
    local runtimeAction = interruptPolicy and interruptPolicy.action or self:ResolveRuntimeAction(ability, context.sourceGUID)
    local voiceAction = ability.voiceAction ~= nil and ability.voiceAction or (ability.sound and runtimeAction or "NONE")
    local personalVoice = voiceAction == "YOU"
    if runtimeAction == "CAST" and ability.primaryAction == "KICK" and ability.stopIfUninterruptible then voiceAction = "NONE" end
    local targetBehavior = ability.targetBehavior or ability.target or "NONE"
    local destinationConfirmed = context.destGUID and (targetBehavior == "DESTINATION" or targetBehavior == "PLAYER" or targetBehavior == "PARTY")
    local targetConfidence = destinationConfirmed and "CONFIRMED" or "NONE"
    local isPlayer = destinationConfirmed and context.destGUID == UnitGUID("player") or false
    if not self:RoleAllows(ability, context.destGUID) and not self:IsGlobalAction(runtimeAction, isPlayer) then
        return
    end
    if not self:RoleNotificationAllows(ability, runtimeAction, isPlayer) then
        return
    end
    if personalVoice and destinationConfirmed and not isPlayer then
        -- YOU mechanics are personal: keep tactical nameplate data, but never center/sound another player's cast.
        voiceAction = "NONE"
    end
    self.throttles = self.throttles or {}
    local throttleKey = table.concat({ability.id, context.sourceGUID or "", context.destGUID or "", context.event or ""}, ":")
    local now = GetTime()
    if self.throttles[throttleKey] and now - self.throttles[throttleKey] < (ability.throttle or 0.5) then
        return
    end
    self.throttles[throttleKey] = now

    local activeOwner
    if context.event == "SPELL_CAST_START" or context.event == "SPELL_CAST_SUCCESS" then
        activeOwner = self.ActiveCasts:GetBySourceSpell(context.sourceGUID, context.spellID, ability)
        if not activeOwner and context.event == "SPELL_CAST_SUCCESS" then
            activeOwner = self.ActiveCasts:WasRecentlyOwned(context.sourceGUID, context.spellID, ability)
        end
    end
    local suppressPresentation = activeOwner and true or false
    if destinationConfirmed then
        if activeOwner then
            self.ActiveCasts:ConfirmDestination(context.sourceGUID, context.spellID, ability, context.destGUID, context.destName, context.event)
        else
            self.ActiveCasts:RecordTargetDecision({
                spellID = context.spellID or ability.id,
                spellName = context.spellName,
                npcID = context.npcID,
                npcName = context.sourceName,
                targetGUID = context.destGUID,
                targetName = context.destName,
                targetRole = self:GetGroupRoleForGUID(context.destGUID),
                targetIsPlayer = isPlayer,
                targetBehavior = targetBehavior,
                targetConfidence = "CONFIRMED",
                frontalBehavior = ability.frontalBehavior,
                targetEvidence = context.event,
            }, context.event)
            if isPlayer then
                self.diagnostics.confirmedPersonalTargets = self.diagnostics.confirmedPersonalTargets + 1
            end
        end
    end
    local alertContext = {
        sourceGUID = context.sourceGUID,
        destGUID = context.destGUID,
        spellName = context.spellName,
        targetName = context.destName,
        targetRole = self:GetGroupRoleForGUID(context.destGUID),
        isPlayer = isPlayer,
        targetConfidence = targetConfidence,
        action = runtimeAction,
        soundHandled = true,
    }
    if context.spellID == 257908 and context.event == "SPELL_AURA_APPLIED" then
        alertContext.spellName = (GetSpellInfo(257908) or context.spellName or "") ..
            "  |  " .. self:L("OILED_BLADE_FMT")
    end
    if not suppressPresentation then
        if voiceAction and voiceAction ~= "NONE" and (not personalVoice or isPlayer) then
            self.Sounds:PlayMechanic(voiceAction, {
                sourceGUID = context.sourceGUID, spellID = context.spellID or ability.id,
                key = throttleKey, isPlayer = isPlayer, targetConfidence = targetConfidence,
                personalFatal = isPlayer and ability.severity == "CRITICAL",
                criticalPersonal = isPlayer and ability.severity == "CRITICAL",
                route = "combat-log", primaryAction = runtimeAction,
            })
        end
        if (not personalVoice or alertContext.isPlayer) and self:RoleCenterAllows(ability, alertContext.isPlayer, runtimeAction) then
            self.Alerts:Show(ability, alertContext)
        end
        if ability.nameplate then
            local primary = self:NormalizeAction(ability.primaryAction or ability.action, ability.mechanic)
            local nameplateAction = self:IsGeometryAction(primary) and primary or runtimeAction
            local controlAction = ability.ccCapable and "CC" or nil
            if ability.castControl == "KICK" then
                local sourceUnit = context.sourceGUID and self.Targets:GetUnit(context.sourceGUID)
                local notInterruptible = sourceUnit and UnitCastingInfo(sourceUnit) and select(8, UnitCastingInfo(sourceUnit))
                if sourceUnit and not notInterruptible then
                    controlAction = "KICK"
                    if not self:IsGeometryAction(primary) then nameplateAction = "KICK" end
                end
            elseif ability.castControl == "STOP" then
                controlAction = "STOP"
                if not self:IsGeometryAction(primary) then nameplateAction = "STOP" end
            end
            local plateUnit = context.destGUID and self.Targets:GetUnit(context.destGUID)
            if not plateUnit or not string.match(plateUnit, "^nameplate") then
                plateUnit = context.sourceGUID and self.Targets:GetUnit(context.sourceGUID)
            end
            if plateUnit and string.match(plateUnit, "^nameplate") then
                self.Nameplates:Display(plateUnit, ability.id, nameplateAction, ability.severity, false, ability.nameplateDuration, controlAction)
            end
        end
        local frontalTargetAllowed = runtimeAction ~= "FRONTAL" or self:IsTargetBasedFrontal(ability)
        if targetBehavior == "SOURCE_TARGET" and context.sourceGUID and frontalTargetAllowed then
            local delayedTargetTruth = runtimeAction == "FRONTAL" or personalVoice
            self.Targets:ResolveSourceTarget(context.sourceGUID, function(target)
                alertContext.targetName = target.name
                alertContext.targetRole = target.role
                alertContext.isPlayer = target.isPlayer
                alertContext.targetConfidence = "CONFIRMED"
                if personalVoice and alertContext.isPlayer then
                    BKA.Sounds:PlayMechanic("YOU", {
                        sourceGUID = context.sourceGUID, spellID = context.spellID or ability.id, key = throttleKey,
                        isPlayer = true, targetConfidence = "CONFIRMED", route = "combat-log-target-confirmed",
                        criticalPersonal = ability.severity == "CRITICAL", personalFatal = ability.severity == "CRITICAL",
                    })
                end
                if (not personalVoice or alertContext.isPlayer) and BKA:RoleCenterAllows(ability, alertContext.isPlayer, runtimeAction) then
                    BKA.Alerts:Show(ability, alertContext)
                end
            end, delayedTargetTruth and { confirmAfterWindow = true } or nil)
        end
    end
    if ability.cooldown then
        self.Timers:Schedule(ability, ability.cooldown, context.sourceGUID)
    end
end

function BKA:HandleCombatLog()
    local timestamp, event, _, sourceGUID, sourceName, sourceFlags, _, destGUID, destName, _, _, arg12, arg13, arg14, arg15, arg16, arg17, arg18, arg19, arg20, arg21, arg22 = CombatLogGetCurrentEventInfo()
    if event == "UNIT_DIED" then
        self.Timers:CancelSource(destGUID)
        self.ActiveCasts:StopSource(destGUID)
        self.SpecialHandlers:HandleDeath(destGUID, destName)
        self.Stacks:ClearGUID(destGUID)
        return
    end
    local spellID, spellName, auraType, amount
    if event == "SPELL_ABSORBED" then
        if type(arg12) == "number" then
            -- Spell hit: original spell, then absorber payload.
            spellID, spellName, amount = arg12, arg13, arg22
        else
            -- Swing hit: no original spell, only the absorber spell.
            spellID, spellName, amount = arg16, arg17, arg19
        end
    else
        spellID, spellName, auraType, amount = arg12, arg13, arg15, arg16
    end
    if not spellID then
        return
    end
    if event == "SPELL_CAST_START" then
        self.recentSourceCasts = self.recentSourceCasts or {}
        self.recentSourceCasts[sourceGUID] = { spellID = spellID, spellName = spellName, expires = GetTime() + 1 }
        local sourceUnit = self.Targets:GetUnit(sourceGUID)
        if sourceUnit then
            self.ActiveCasts:Start(sourceUnit, nil, spellID)
        end
    end
    local npcID = self:GetNPCID(sourceGUID)
    local context = {
        event = event, sourceGUID = sourceGUID, sourceName = sourceName, npcID = npcID,
        destGUID = destGUID, destName = destName, spellID = spellID, spellName = spellName,
        auraType = auraType, amount = amount, timestamp = timestamp,
    }
    if self.Affixes:IsCursedPulse(spellID, spellName) then
        context.npcName = sourceName
        context.isPlayer = destGUID == UnitGUID("player")
        context.isParty = self:IsPlayerOrPartyGUID(destGUID)
        if DAMAGE_EVENTS[event] then
            self.Logger:ObserveUnknownDamage(context)
        else
            self.Logger:RecordUnknown(context)
        end
    end
    if spellID == 209858 and event == "SPELL_PERIODIC_DAMAGE" then
        self.Affixes:RecordNecroticTick(destGUID, tonumber(arg15))
    end
    if self.Affixes:HandleCombatLog(event, spellID, spellName, destGUID, destName, amount) then
        return
    end
    local suppress = self.SpecialHandlers:ShouldSuppressCombatLog(event, context)
    local eventIndex = self.byEventSpell and self.byEventSpell[event]
    local abilities = eventIndex and eventIndex[spellID]
    if abilities and not suppress then
        for _, ability in ipairs(abilities) do
            self:DispatchAbility(ability, context)
        end
    end
    self.SpecialHandlers:HandleCombatLog(event, context)
    local hostile = sourceFlags and bit and bit.band(sourceFlags, COMBATLOG_OBJECT_REACTION_HOSTILE or 0x00000040) ~= 0
    if not abilities and hostile and DAMAGE_EVENTS[event] then
        context.npcName = sourceName
        context.isPlayer = destGUID == UnitGUID("player")
        context.isParty = self:IsPlayerOrPartyGUID(destGUID)
        self.Logger:ObserveUnknownDamage(context)
    elseif hostile and (event == "SPELL_CAST_START" or event == "SPELL_CAST_SUCCESS") and not (self.bySpell and self.bySpell[spellID]) and not self.SpecialHandlers:IsKnownSpell(spellID) then
        context.npcName = sourceName
        context.isPlayer = destGUID == UnitGUID("player")
        context.isParty = self:IsPlayerOrPartyGUID(destGUID)
        self.Logger:RecordUnknown(context)
    end
end

function BKA:StartEncounterTimers()
    local bossNPCs = {}
    for i = 1, 5 do
        local guid = UnitGUID("boss" .. i)
        local npcID = self:GetNPCID(guid)
        if npcID then
            bossNPCs[npcID] = guid
        end
    end
    for _, ability in ipairs(self.activeAbilities or {}) do
        if ability.initial and ability.module ~= "Trash" and ability.module ~= "MDT" and ability.module ~= "Options" then
            for npcID, guid in pairs(bossNPCs) do
                if sourceMatches(ability, npcID) then
                    self.Timers:Schedule(ability, ability.initial, guid)
                    break
                end
            end
        end
    end
end

function BKA:OnEvent(event, ...)
    if event == "ADDON_LOADED" then
        local loaded = ...
        if loaded == self.name then
            self:InitDB()
            if self.Version and self.Version.Initialize then self.Version:Initialize() end
            self.Alerts:Initialize()
            if self.GroupInterrupts and self.GroupInterrupts.Initialize then self.GroupInterrupts:Initialize() end
            if self.KeystoneHUD and self.KeystoneHUD.Initialize then self.KeystoneHUD:Initialize() end
            self.Options:Initialize()
            if self.MinimapButton then self.MinimapButton:Initialize() end
            if self.KeystoneAutoSlot then self.KeystoneAutoSlot:Initialize() end
            if self.EnemyForces then self.EnemyForces:Initialize() end
            if self.Nameplates and self.Nameplates.RefreshClickTargeting then
                self.Nameplates:RefreshClickTargeting()
            end
            self:RefreshActivation()
        end
        return
    elseif event == "PLAYER_ENTERING_WORLD" then
        self:ResetCompletionSound()
        if self.db then
            C_Timer.After(0.5, function()
                if BKA.Nameplates and BKA.Nameplates.RefreshClickTargeting then
                    BKA.Nameplates:RefreshClickTargeting()
                end
                BKA:RefreshActivation()
            end)
        end
        return
    elseif event == "CHALLENGE_MODE_START" then
        self:ResetCompletionSound()
        C_Timer.After(0.2, function() BKA:RefreshActivation() end)
        return
    elseif event == "CHALLENGE_MODE_RESET" then
        self:ResetCompletionSound()
        self.Sounds:CancelAllPendingCombat()
        self:Deactivate()
        return
    elseif event == "CHALLENGE_MODE_COMPLETED" then
        self.Sounds:CancelAllPendingCombat()
        self:Deactivate()
        self:BeginCompletionSound()
        return
    end
    if not self.active then
        return
    end

    if event == "COMBAT_LOG_EVENT_UNFILTERED" then
        self:HandleCombatLog()
    elseif event == "NAME_PLATE_UNIT_ADDED" then
        self.Nameplates:OnAdded(...)
    elseif event == "NAME_PLATE_UNIT_REMOVED" then
        self.Nameplates:OnRemoved(...)
    elseif event == "UNIT_TARGET" then
        local unit = ...
        self.Targets:AddUnit(unit)
        self.ActiveCasts:UpdateTarget(unit)
    elseif event == "UNIT_AURA" then
        local unit = ...
        if unit == "player" or string.match(unit or "", "^party%d$") or string.match(unit or "", "^nameplate%d+$") then
            self.Affixes:ScanUnitAuras(unit)
        end
    elseif event == "UNIT_SPELLCAST_START" or event == "UNIT_SPELLCAST_CHANNEL_START" then
        local unit, castGUID, spellID = ...
        if string.match(unit or "", "^nameplate%d+$") or string.match(unit or "", "^boss%d$") then
            self.ActiveCasts:Start(unit, castGUID, spellID, event == "UNIT_SPELLCAST_CHANNEL_START")
        end
        self.SpecialHandlers:HandleUnitEvent(event, unit, spellID)
    elseif event == "UNIT_SPELLCAST_DELAYED" or event == "UNIT_SPELLCAST_CHANNEL_UPDATE" then
        local unit, castGUID, spellID = ...
        if string.match(unit or "", "^nameplate%d+$") or string.match(unit or "", "^boss%d$") then
            self.ActiveCasts:Resync(unit, castGUID, spellID, event == "UNIT_SPELLCAST_CHANNEL_UPDATE")
        end
    elseif event == "UNIT_SPELLCAST_SUCCEEDED" then
        local unit, _, spellID = ...
        if string.match(unit or "", "^nameplate%d+$") or string.match(unit or "", "^boss%d$") then
            self:DispatchUnitSpell(unit, "SPELL_CAST_SUCCESS", spellID)
        end
        self.SpecialHandlers:HandleUnitEvent(event, unit, spellID)
    elseif event == "UNIT_SPELLCAST_STOP" or event == "UNIT_SPELLCAST_CHANNEL_STOP" or event == "UNIT_SPELLCAST_INTERRUPTED" or event == "UNIT_SPELLCAST_FAILED" then
        local unit, castGUID, spellID = ...
        if string.match(unit or "", "^nameplate%d+$") or string.match(unit or "", "^boss%d$") then
            self.ActiveCasts:Stop(unit, castGUID, spellID)
        end
    elseif event == "INSTANCE_ENCOUNTER_ENGAGE_UNIT" then
        self.Targets:RefreshBossUnits()
        self.SpecialHandlers:HandleEngageUnits()
    elseif event == "ENCOUNTER_START" then
        local encounterID = ...
        self.Targets:RefreshBossUnits()
        self.SpecialHandlers:OnEncounterStart(encounterID)
        C_Timer.After(0.1, function()
            if BKA.active and not BKA.SpecialHandlers:StartEncounterTimers() then
                BKA:StartEncounterTimers()
            end
        end)
    elseif event == "ENCOUNTER_END" then
        self.ActiveCasts:Clear()
        self.Timers:Clear()
        self.Alerts:Clear()
        self.Stacks:Clear()
        self.SpecialHandlers:Reset()
    elseif event == "GROUP_ROSTER_UPDATE" then
        self:BuildPartyGUIDs()
    elseif event == "UNIT_HEALTH_FREQUENT" or event == "UNIT_POWER_FREQUENT" or event == "UNIT_TARGETABLE_CHANGED" then
        self.SpecialHandlers:HandleUnitEvent(event, ...)
    elseif SAFE_SOURCE_EVENTS[event] then
        local message = ...
        local targetName = select(5, ...)
        self.SpecialHandlers:HandleChatEvent(event, message, targetName)
    end
end
