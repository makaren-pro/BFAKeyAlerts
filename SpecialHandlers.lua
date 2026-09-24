local BKA = BFAKeyAlerts
local Special = { state = {}, allEvents = {
    CHAT_MSG_RAID_BOSS_EMOTE = true,
    CHAT_MSG_MONSTER_YELL = true,
    UNIT_HEALTH_FREQUENT = true,
    UNIT_POWER_FREQUENT = true,
    UNIT_TARGETABLE_CHANGED = true,
    INSTANCE_ENCOUNTER_ENGAGE_UNIT = true,
} }
BKA.SpecialHandlers = Special

local EVENTS = {
    AtalDazar = { "CHAT_MSG_RAID_BOSS_EMOTE" },
    Freehold = { "INSTANCE_ENCOUNTER_ENGAGE_UNIT" },
    KingsRest = { "CHAT_MSG_RAID_BOSS_EMOTE", "INSTANCE_ENCOUNTER_ENGAGE_UNIT", "UNIT_HEALTH_FREQUENT" },
    SiegeOfBoralus = { "INSTANCE_ENCOUNTER_ENGAGE_UNIT" },
    TempleOfSethraliss = { "CHAT_MSG_RAID_BOSS_EMOTE", "UNIT_POWER_FREQUENT", "UNIT_TARGETABLE_CHANGED" },
    TolDagor = { "CHAT_MSG_RAID_BOSS_EMOTE" },
}

local SPECIAL_CLEU = {
    Freehold = { [256005] = true, [257402] = true, [257458] = true, [257278] = true, [257305] = true, [257314] = true },
    SiegeOfBoralus = { [273720] = true, [280933] = true, [280934] = true, [273721] = true, [277965] = true, [275014] = true },
    TempleOfSethraliss = { [273677] = true },
}

local SPECIAL_SPELLS = {
    [256056] = true, [257454] = true, [257540] = true, [274002] = true,
    [268752] = true, [268745] = true, [268963] = true, [257861] = true,
    [270183] = true, [269984] = true, [270605] = true, [269377] = true,
}

local INTERRUPT_HANDLERS = {
    TerrifyingScreech = true, DinoMight = true, Transfusion = true,
    BwonsamdisMantle = true, MendingWord = true, FieryEnchant = true,
    NoxiousStench = true, WrackingPain = true, RevitalizingBrew = true,
    HealingBalm = true, SlicingBlast = true, VoidBolt = true,
    MendingRapids = true, SnakeCharm = true, HealingSurge = true,
    GreaterHealingPotion = true, ToxicBlades = true, RockLance = true,
    FuriousQuake = true, TectonicBarrier = true, TransfigurationSerum = true,
    Blowtorch = true, Overcharge = true, Repair = true,
    TransmuteEnemyToGoo = true, IcedSpritzer = true, KajacolaRefresher = true,
    InhaleVapors = true, ArtilleryBarrage = true, BloodBolt = true,
    DarkReconstitution = true, GraspingThorns = true, DarkenedLightning = true,
    WrackingChord = true, EffigyReconstruction = true,
    WateryDome = true,
}

local HIGH_INTERRUPT_HANDLERS = {
    TerrifyingScreech = true, DinoMight = true, BwonsamdisMantle = true,
    FieryEnchant = true, NoxiousStench = true, WrackingPain = true,
    RevitalizingBrew = true, SlicingBlast = true, VoidBolt = true,
    SnakeCharm = true, ToxicBlades = true, RockLance = true,
    FuriousQuake = true, TectonicBarrier = true, TransfigurationSerum = true,
    Overcharge = true, TransmuteEnemyToGoo = true, KajacolaRefresher = true,
    InhaleVapors = true, ArtilleryBarrage = true, DarkenedLightning = true,
    WrackingChord = true,
}

local PURGE_HANDLERS = {
    EarthShieldApplied = true, TectonicBarrierApplied = true,
    OverchargeApplied = true, AzeriteInjectionApplied = true,
    GiftOfGhuunApplied = true, Swiftness = true,
}


-- High-signal boss mechanics that need strategy-aware wording rather than the
-- generic action inferred from historical boss-mod messages.  Keep the key tied
-- to dungeon + handler + option spell ID: several dungeons reuse handler names
-- or expose a different trigger spell than their option ID.
local BOSS_ASSIST = {
    -- Atal'Dazar - Priestess Alun'za
    ["AtalDazar:Transfusion:255577"] = { mechanic = "SOAK", action = "SOAK - TAINTED BLOOD", primaryAction = "SOAK - TAINTED BLOOD", voiceAction = "SOAK", severity = "HIGH", center = true, nameplate = true, sound = true },
    ["AtalDazar:GildedClaws:255579"] = { mechanic = "PURGE", action = "PURGE - CLAWS", primaryAction = "PURGE - CLAWS", voiceAction = "PURGE", severity = "HIGH", center = true, nameplate = true, sound = true },
    ["AtalDazar:MoltenGold:255582"] = { mechanic = "DISPEL", action = "DISPEL - MOLTEN GOLD", primaryAction = "DISPEL - MOLTEN GOLD", voiceAction = "DISPEL", target = "DESTINATION", targetBehavior = "DESTINATION", severity = "HIGH", center = true, sound = true },

    -- Freehold - Council o' Captains / Tending Bar
    ["Freehold:BlackoutBarrel:258338"] = { mechanic = "INFO", action = "KILL - BARREL", primaryAction = "KILL - BARREL", voiceAction = "PREPARE", severity = "HIGH", center = true, nameplate = true, sound = true },
    ["Freehold:CritBrew:265088"] = { mechanic = "SOAK", action = "SOAK - GOOD CRIT BREW", primaryAction = "SOAK - GOOD CRIT BREW", voiceAction = "SOAK", severity = "HIGH", center = true, nameplate = false, sound = true },
    ["Freehold:HasteBrew:264608"] = { mechanic = "SOAK", action = "SOAK - GOOD HASTE BREW", primaryAction = "SOAK - GOOD HASTE BREW", voiceAction = "SOAK", severity = "HIGH", center = true, nameplate = false, sound = true },
    ["Freehold:CausticBrew:265168"] = { mechanic = "DODGE", action = "MOVE - BAD BREW", primaryAction = "MOVE - BAD BREW", voiceAction = "MOVE", severity = "HIGH", center = true, nameplate = false, sound = true },

    -- King's Rest - Golden Serpent / Mchimba
    ["KingsRest:SpitGold:265773"] = { mechanic = "STACK", action = "STACK - GOLD", primaryAction = "STACK - GOLD", voiceAction = "STACK", target = "DESTINATION", targetBehavior = "DESTINATION", severity = "HIGH", center = true, sound = true },
    ["KingsRest:LucresCall:265923"] = { mechanic = "STOP", action = "CC - GOLD ADDS", primaryAction = "CC - GOLD ADDS", voiceAction = "STOP", severity = "HIGH", center = true, sound = true },
    ["KingsRest:EntombApplied:267702"] = { mechanic = "TARGETED", action = "FIND - COFFIN", primaryAction = "FIND - COFFIN", voiceAction = "PREPARE", target = "DESTINATION", targetBehavior = "DESTINATION", severity = "HIGH", center = true, sound = true },

    -- Shrine of the Storm
    ["ShrineOfTheStorm:Undertow:264166"] = { mechanic = "TARGETED", action = "RUN - AGAINST WAVE", primaryAction = "RUN - AGAINST WAVE", voiceAction = "RUN", target = "DESTINATION", targetBehavior = "DESTINATION", role = "ALL", severity = "HIGH", center = true, sound = true },
    ["ShrineOfTheStorm:ReinforcingWard:267905"] = { mechanic = "MOVE_MOBS", action = "MOVE MOBS - OUT OF WARD", primaryAction = "MOVE MOBS - OUT OF WARD", voiceAction = "MOVE", severity = "HIGH", center = true, nameplate = true, sound = true },
    ["ShrineOfTheStorm:WakentheVoid:269097"] = { mechanic = "KITE", action = "KITE - VOID ORBS", primaryAction = "KITE - VOID ORBS", voiceAction = "KITE", severity = "HIGH", center = true, sound = true },
    ["ShrineOfTheStorm:AncientMindbenderApplied:269131"] = { mechanic = "TARGETED", action = "BREAK - MINDBENDER", primaryAction = "BREAK - MINDBENDER", voiceAction = "PREPARE", target = "DESTINATION", targetBehavior = "DESTINATION", severity = "HIGH", center = true, sound = true },
    ["ShrineOfTheStorm:MindRendApplied:268896"] = { mechanic = "DISPEL", action = "DISPEL - MIND REND", primaryAction = "DISPEL - MIND REND", voiceAction = "DISPEL", target = "DESTINATION", targetBehavior = "DESTINATION", severity = "HIGH", center = true, sound = true },
    ["ShrineOfTheStorm:YawningGate:269399"] = { mechanic = "MOVE_MOBS", action = "MOVE BOSS - OUT OF GATE", primaryAction = "MOVE BOSS - OUT OF GATE", voiceAction = "MOVE", severity = "HIGH", center = true, nameplate = true, sound = true },
    ["ShrineOfTheStorm:TentacleSlam:267385"] = { mechanic = "DODGE", action = "DODGE - TENTACLE", primaryAction = "DODGE - TENTACLE", voiceAction = "MOVE", severity = "HIGH", center = true, nameplate = true, sound = true },

    -- Temple of Sethraliss - Adderis & Aspix
    ["TempleOfSethraliss:LightningShield:263246"] = { mechanic = "INFO", action = "SWAP - SHIELDED BOSS", primaryAction = "SWAP - SHIELDED BOSS", voiceAction = "PREPARE", target = "DESTINATION", targetBehavior = "DESTINATION", severity = "HIGH", center = true, sound = true },
    ["TempleOfSethraliss:Conduction:263371"] = { mechanic = "SPREAD", action = "SPREAD - 8Y", primaryAction = "SPREAD - 8Y", voiceAction = "SPREAD", target = "DESTINATION", targetBehavior = "DESTINATION", severity = "HIGH", center = true, sound = true },
    ["TempleOfSethraliss:StaticShock:263257"] = { mechanic = "AOE", action = "AOE", primaryAction = "AOE", voiceAction = "DEFENSIVE", severity = "HIGH", center = true, nameplate = true, sound = true },

    -- The MOTHERLODE!!
    ["TheMotherlode:FootbombLauncher:269493"] = { mechanic = "INFO", action = "PUNT - BOMBS", primaryAction = "PUNT - BOMBS", voiceAction = "PREPARE", severity = "HIGH", center = true, sound = true },
    ["TheMotherlode:StaticPulse:262347"] = { mechanic = "AOE", action = "AOE", primaryAction = "AOE", voiceAction = "DEFENSIVE", severity = "HIGH", center = true, nameplate = true, sound = true },
    ["TheMotherlode:CallEarthrager:257593"] = { mechanic = "STOP", action = "CC - EARTHRAGER", primaryAction = "CC - EARTHRAGER", voiceAction = "STOP", severity = "HIGH", center = true, sound = true },
    ["TheMotherlode:AzeriteInfusion:271698"] = { mechanic = "INFO", action = "KILL - INFUSED ADD", primaryAction = "KILL - INFUSED ADD", voiceAction = "PREPARE", severity = "HIGH", center = true, sound = true },
    ["TheMotherlode:ResonantPulse:258622"] = { mechanic = "AOE", action = "AOE", primaryAction = "AOE", voiceAction = "DEFENSIVE", severity = "HIGH", center = true, nameplate = true, sound = true },

    -- Tol Dagor - Overseer Korgus / Knight Captain Valyri
    ["TolDagor:AzeriteRoundsIncendiary:256198"] = { mechanic = "DEFENSIVE", action = "DEFENSIVE - FIRE ROUNDS", primaryAction = "DEFENSIVE - FIRE ROUNDS", voiceAction = "DEFENSIVE", severity = "HIGH", center = true, sound = true },
    ["TolDagor:AzeriteRoundsBlast:256199"] = { mechanic = "DODGE", action = "MOVE - KNOCKBACK ROUNDS", primaryAction = "MOVE - KNOCKBACK ROUNDS", voiceAction = "MOVE", severity = "HIGH", center = true, sound = true },
    ["TolDagor:Ignition:256970"] = { mechanic = "DODGE", action = "MOVE - BARRELS", primaryAction = "MOVE - BARRELS", voiceAction = "MOVE", severity = "CRITICAL", center = true, sound = true },
    ["TolDagor:FuselighterApplied:257028"] = { mechanic = "DISPEL", action = "DISPEL - NO BARREL", primaryAction = "DISPEL - NO BARREL", voiceAction = "DISPEL", target = "DESTINATION", targetBehavior = "DESTINATION", severity = "HIGH", center = true, sound = true },

    -- The Underrot
    ["Underrot:CleansingLight:269310"] = { mechanic = "SOAK", action = "SOAK - CLEANSE BLOOD", primaryAction = "SOAK - CLEANSE BLOOD", voiceAction = "SOAK", target = "DESTINATION", targetBehavior = "DESTINATION", severity = "HIGH", center = true, sound = true },
    ["Underrot:Tantrum:260333"] = { mechanic = "AOE", action = "AOE", primaryAction = "AOE", voiceAction = "DEFENSIVE", severity = "HIGH", center = true, nameplate = true, sound = true },
    ["Underrot:FesteringHarvest:259732"] = { mechanic = "INFO", action = "CLEAR - SPORES", primaryAction = "CLEAR - SPORES", voiceAction = "PREPARE", severity = "CRITICAL", center = true, sound = true },
    ["Underrot:VolatilePods:273285"] = { mechanic = "DODGE", action = "DODGE - PODS", primaryAction = "DODGE - PODS", voiceAction = "MOVE", severity = "HIGH", center = true, sound = true },

    -- Waycrest Manor
    ["WaycrestManor:SoulThornsApplied:267907"] = { mechanic = "TARGETED", action = "KILL - SOUL THORNS", primaryAction = "KILL - SOUL THORNS", voiceAction = "PREPARE", target = "DESTINATION", targetBehavior = "DESTINATION", severity = "HIGH", center = true, sound = true },
    ["WaycrestManor:BurningBrush:260541"] = { mechanic = "DEFENSIVE", action = "DEFENSIVE - STACK RESET", primaryAction = "DEFENSIVE - STACK RESET", voiceAction = "DEFENSIVE", severity = "HIGH", center = true, sound = true },
    ["WaycrestManor:ClaimTheIris:260805"] = { center = false, sound = false },
    ["WaycrestManor:FocusingIris:260805"] = { mechanic = "INFO", action = "FOCUS - IRIS BOSS", primaryAction = "FOCUS - IRIS BOSS", voiceAction = "PREPARE", target = "DESTINATION", targetBehavior = "DESTINATION", severity = "HIGH", center = true, sound = true },
    ["WaycrestManor:DireRitual:260773"] = { mechanic = "DEFENSIVE", action = "DEFENSIVE - DIRE RITUAL", primaryAction = "DEFENSIVE - DIRE RITUAL", voiceAction = "DEFENSIVE", severity = "CRITICAL", center = true, sound = true },
    ["WaycrestManor:ConsumeAll:264734"] = { mechanic = "INFO", action = "KILL - SERVANTS", primaryAction = "KILL - SERVANTS", voiceAction = "PREPARE", severity = "CRITICAL", center = true, sound = true },
    ["WaycrestManor:CallServant:264931"] = { mechanic = "INFO", action = "ADDS - KILL", primaryAction = "ADDS - KILL", voiceAction = "PREPARE", severity = "HIGH", center = true, sound = true },
    ["WaycrestManor:SummonDeathtouchedSlaver:266266"] = { mechanic = "INFO", action = "ADD - KILL", primaryAction = "ADD - KILL", voiceAction = "PREPARE", severity = "HIGH", center = true, sound = true },
    ["WaycrestManor:AlchemicalFire:266198"] = { mechanic = "INFO", action = "BURN - CORPSES", primaryAction = "BURN - CORPSES", voiceAction = "PREPARE", severity = "HIGH", center = true, sound = true },

    -- Siege of Boralus
    ["SiegeOfBoralus:IronGaze:260954"] = { mechanic = "KITE", action = "KITE - IRON GAZE", primaryAction = "KITE - IRON GAZE", voiceAction = "KITE", target = "DESTINATION", targetBehavior = "DESTINATION", severity = "HIGH", center = true, sound = true },
    ["SiegeOfBoralus:HeavyOrdnanceApplied:277965"] = { mechanic = "INFO", action = "PICK - ORDNANCE", primaryAction = "PICK - ORDNANCE", voiceAction = "PREPARE", severity = "HIGH", center = true, sound = true },
    ["SiegeOfBoralus:HeavyOrdnanceApplied:273721"] = { mechanic = "INFO", action = "PICK - ORDNANCE", primaryAction = "PICK - ORDNANCE", voiceAction = "PREPARE", severity = "HIGH", center = true, sound = true },
    ["SiegeOfBoralus:BreakWater:257882"] = { mechanic = "DODGE", action = "DODGE - BREAK WATER", primaryAction = "DODGE - BREAK WATER", voiceAction = "MOVE", severity = "HIGH", center = true, sound = true },
    ["SiegeOfBoralus:TidalSurge:276068"] = { mechanic = "LOS", action = "LOS - STATUE", primaryAction = "LOS - STATUE", voiceAction = "LOS", severity = "CRITICAL", center = true, sound = true },
}

local function applyBossAssist(dungeonKey, entry)
    local key = table.concat({ tostring(dungeonKey or ""), tostring(entry.handler or ""), tostring(entry.id or 0) }, ":")
    local rule = BOSS_ASSIST[key]
    if not rule then return end
    for field, value in pairs(rule) do entry[field] = value end
    entry.bossAssist = true
    if rule.center == true then entry.centerPolicy = "ALWAYS" end
    entry.bossAssistAuditNote = "Strategy-aware BFA Season 1 boss mechanic override."
end

local function copyAbility(ability, overrides)
    local copy = {}
    for key, value in pairs(ability or {}) do
        copy[key] = value
    end
    for key, value in pairs(overrides or {}) do
        copy[key] = value
    end
    return copy
end

local function ability(spellID, handler, fallback)
    return BKA:FindAbilityByID(spellID, nil, handler) or BKA:FindAbilityByID(spellID) or fallback or {
        id = spellID, mechanic = "INFO", action = "WATCH", severity = "MEDIUM",
        center = true, nameplate = false, sound = false,
    }
end

local function bossGUID(npcID)
    for i = 1, 5 do
        local guid = UnitGUID("boss" .. i)
        if BKA:GetNPCID(guid) == npcID then
            return guid, "boss" .. i
        end
    end
end

local function show(spellID, context, overrides, handler)
    local source = ability(spellID, handler)
    BKA.Alerts:Show(copyAbility(source, overrides), context or { spellName = GetSpellInfo(spellID) })
end

local function schedule(spellID, delay, sourceGUID, label, overrides, handler)
    BKA.Timers:Schedule(copyAbility(ability(spellID, handler), overrides), delay, sourceGUID, label or GetSpellInfo(spellID))
end

local function targetContext(spellID, targetName, action, severity)
    local targetGUID = targetName and UnitGUID(targetName)
    return {
        spellName = GetSpellInfo(spellID), targetName = targetName,
        isPlayer = (targetGUID and targetGUID == UnitGUID("player")) or targetName == UnitName("player"),
        targetConfidence = "CONFIRMED",
        key = "special-target:" .. tostring(spellID), action = action,
    }, severity
end

local function findPutridTarget(targets, guid, name)
    for key, target in pairs(targets or {}) do
        if (guid and target.guid == guid) or (name and target.name == name) then
            return key, target
        end
    end
end

local function showPutridWatersGroup(sound)
    local targets = Special.state.putridWatersTargets
    if not targets or not next(targets) then
        BKA.Alerts:Hide("viq-putrid-group")
        return
    end
    local names = {}
    for _, target in pairs(targets) do
        names[#names + 1] = target.name or "Unknown"
    end
    table.sort(names)
    local targetText = #names <= 2 and table.concat(names, ", ") or (tostring(#names) .. " targets")
    show(275014, { spellName = GetSpellInfo(275014), targetName = targetText, key = "viq-putrid-group", silent = not sound }, { action = "SPREAD", severity = "HIGH", center = true, sound = sound })
end

local function extractTarget(message, targetName)
    if targetName and targetName ~= "" then
        return targetName
    end
    local linked = string.match(message or "", "|Hplayer:([^:|]+)")
    if linked then
        return linked
    end
    for _, unit in ipairs({"player", "party1", "party2", "party3", "party4"}) do
        local name = UnitName(unit)
        if name and string.find(message or "", name, 1, true) then
            return name
        end
    end
end

function Special:GetEvents(dungeonKey)
    return EVENTS[dungeonKey] or {}
end

function Special:IsKnownSpell(spellID)
    return SPECIAL_SPELLS[spellID] or false
end

function Special:ApplyCorrections(dungeon)
    for _, entry in ipairs(dungeon.abilities or {}) do
        if entry.source == "LittleWigs-option" then
            entry.triggers = {}
            entry.center = false
            entry.nameplate = true
        end
        if INTERRUPT_HANDLERS[entry.handler] then
            entry.mechanic = "INTERRUPT"
            entry.castControl = "KICK"
            entry.primaryAction = entry.primaryAction or "KICK"
            entry.action = entry.primaryAction
            entry.kickPriority = HIGH_INTERRUPT_HANDLERS[entry.handler] and "HIGH" or (entry.kickPriority or "NORMAL")
            entry.voiceAction = entry.voiceAction or (entry.kickPriority == "LOW" and "NONE" or entry.primaryAction)
            entry.severity = HIGH_INTERRUPT_HANDLERS[entry.handler] and "HIGH" or (entry.severity == "LOW" and "MEDIUM" or entry.severity)
            entry.center = entry.severity == "HIGH" or entry.severity == "CRITICAL"
            entry.nameplate = true
            entry.sound = entry.center
        elseif PURGE_HANDLERS[entry.handler] then
            entry.mechanic = "PURGE"
            entry.primaryAction, entry.action = "PURGE", "PURGE"
            entry.voiceAction = "PURGE"
            entry.severity = "MEDIUM"
            entry.target = "DESTINATION"
            entry.targetBehavior = "DESTINATION"
            entry.center = true
            entry.nameplate = true
        elseif entry.handler == "PutridWatersApplied" then
            entry.mechanic = "SPREAD"
            entry.primaryAction, entry.action = "SPREAD", "SPREAD"
            entry.voiceAction = "SPREAD"
            entry.target = "DESTINATION"
            entry.targetBehavior = "DESTINATION"
            entry.severity = "HIGH"
            entry.center = true
        elseif entry.handler == "HeartAttack" then
            entry.target = "DESTINATION"
            entry.targetBehavior = "DESTINATION"
            entry.triggers = entry.triggers or {}
            local hasDoseTrigger = false
            for _, trigger in ipairs(entry.triggers) do
                if trigger.event == "SPELL_AURA_APPLIED_DOSE" and trigger.spell == 268007 then
                    hasDoseTrigger = true
                    break
                end
            end
            if not hasDoseTrigger then
                entry.triggers[#entry.triggers + 1] = { event = "SPELL_AURA_APPLIED_DOSE", spell = 268007 }
            end
        elseif entry.handler == "BlindingSand" then
            entry.primaryAction, entry.action, entry.castControl = "TURN", "TURN", "NONE"
            entry.voiceAction, entry.center, entry.nameplate, entry.sound = "TURN", true, true, true
        elseif entry.handler == "WardingCandles" then
            entry.primaryAction, entry.action, entry.castControl = "MOVE_MOBS", "MOVE_MOBS", "NONE"
            entry.voiceAction, entry.center, entry.nameplate, entry.sound = "MOVE", true, true, true
        end
        applyBossAssist(dungeon.key, entry)
    end
end

function Special:Reset()
    self.generation = (self.generation or 0) + 1
    wipe(self.state)
end

function Special:OnEncounterStart(encounterID)
    self:Reset()
    self.state.encounterID = encounterID
    if encounterID == 2096 then
        self.state.harlanStage = 1
    elseif encounterID == 2094 then
        self.state.captainEngageAt = GetTime()
        self.state.captainTimersStarted = false
        self:HandleEngageUnits()
    elseif encounterID == 2140 then
        self.state.councilStage = 0
        self.state.councilOrder = {}
        self.state.councilBossGUID = nil
        self:HandleEngageUnits()
    elseif encounterID == 2097 or encounterID == 2098 then
        self.state.bombsRemaining = 0
    elseif encounterID == 2109 then
        self.state.withdrawn = false
    elseif encounterID == 2100 then
        self.state.viqStage = 1
        self.state.demolisherCount = 1
        self.state.engagedGripping = true
        self.state.putridWatersTargets = {}
    elseif encounterID == 2107 then
        self.state.chemicalBurnCount = 0
        self.state.azeriteCatalystCount = 0
    elseif encounterID == 2143 then
        self.state.dazarNextHealth = 85
        self.state.dazarMobs = {}
        self:HandleEngageUnits()
    elseif encounterID == 2124 then
        self.state.cycloneStrikeCount = 0
    elseif encounterID == 2127 then
        self.state.avatarStage = 0
        self.state.hexerCount = 4
    end
end

function Special:StartEncounterTimers()
    local id = self.state.encounterID
    local guid = UnitGUID("boss1")
    if id == 2086 then
        schedule(255371, 12, guid)
        schedule(257407, 22, guid)
        schedule(255434, 6, guid)
    elseif id == 2093 then
        schedule(255952, 4.8, guid)
    elseif id == 2096 then
        schedule(257278, 11, guid)
        schedule(257305, 20, guid)
        schedule(257316, 84.4, guid, BKA:L("NEXT_ADDS"))
    elseif id == 2140 then
        self:HandleEngageUnits()
    elseif id == 2097 or id == 2098 then
        schedule(257585, 11, guid)
    elseif id == 2109 then
        schedule(269029, 3.5, guid)
        schedule(268752, 12.1, guid)
    elseif id == 2099 then
        schedule(257882, 7, guid)
        schedule(261563, 12.5, guid)
        schedule(276068, 23.5, guid)
    elseif id == 2100 then
        schedule(275014, 5, guid)
        schedule(270185, 6, guid)
        schedule(270605, 20, guid, BKA:L("DEMOLISHING_TERROR") .. " 2", { id = 270605, action = "ADD", center = true })
    elseif id == 2107 then
        schedule(270028, 4, guid, nil, { mechanic = "DODGE", action = "MOVE", severity = "HIGH", center = true })
        schedule(259853, 12.5, guid)
        schedule(260669, 31, guid)
    elseif id == 2125 then
        schedule(263912, 6, guid)
        schedule(263958, 12, guid)
    elseif id == 2127 then
        schedule(268024, 9.5, guid)
    else
        return false
    end
    return true
end

function Special:ShouldSuppressCombatLog(event, context)
    local key = BKA.activeDungeon and BKA.activeDungeon.key
    return key and SPECIAL_CLEU[key] and SPECIAL_CLEU[key][context.spellID] or false
end

function Special:HandleChatEvent(event, message, targetName)
    if event ~= "CHAT_MSG_RAID_BOSS_EMOTE" or not message then
        return
    end
    targetName = extractTarget(message, targetName)
    local key = BKA.activeDungeon and BKA.activeDungeon.key
    if key == "AtalDazar" and string.find(message, "255421", 1, true) then
        local context = targetContext(257407, targetName, "RUN / KITE")
        show(257407, context, { mechanic = "FIXATE", action = "RUN / KITE", severity = context.isPlayer and "CRITICAL" or "HIGH", center = true, sound = true })
        schedule(257407, 35.2, (bossGUID(122963)))
    elseif key == "KingsRest" and string.find(message, "266951", 1, true) then
        local context = targetContext(266951, targetName, "FIXATE")
        show(266951, context, { mechanic = "FIXATE", action = "FIXATE", severity = context.isPlayer and "CRITICAL" or "HIGH", center = true, sound = true })
        local livingID = BKA:GetNPCID(UnitGUID("boss1"))
        schedule(266951, livingID == 135470 and 23.1 or 51, "council")
        if livingID == 135470 then schedule(266237, 9, "council") end
    elseif key == "TolDagor" and string.find(message, "257617", 1, true) then
        local context = targetContext(257608, targetName, "MOVE")
        show(257608, context, { mechanic = "TARGETED", action = "MOVE", severity = context.isPlayer and "CRITICAL" or "HIGH", center = true, sound = true })
    elseif key == "TempleOfSethraliss" and string.find(message, "269688", 1, true) then
        show(269688, { spellName = GetSpellInfo(269688), key = "rain-of-toads" }, { mechanic = "DODGE", action = "DODGE", severity = "HIGH", center = true, sound = true })
    end
end

local function startCouncilTimer(npcID, delay)
    if npcID == 135475 then
        schedule(266206, delay, "council")
    elseif npcID == 135470 then
        schedule(266951, delay, "council")
    elseif npcID == 135472 then
        schedule(267273, delay, "council")
    end
end

function Special:HandleEngageUnits()
    local id = self.state.encounterID
    if id == 2094 and not self.state.captainTimersStarted and UnitExists("boss3") then
        local offset = (self.state.captainEngageAt or GetTime()) - GetTime()
        for index = 1, 5 do
            local unit = "boss" .. index
            local guid = UnitGUID(unit)
            local npcID = BKA:GetNPCID(guid)
            if npcID == 126847 and UnitCanAttack("player", unit) then
                schedule(256589, 6.9 - offset, guid)
                schedule(258338, 19 - offset, guid)
            elseif npcID == 126848 then
                if UnitCanAttack("player", unit) then
                    schedule(258381, 8.5 - offset, guid)
                else
                    schedule(272902, 4.7 - offset, guid)
                end
            elseif npcID == 126845 and UnitCanAttack("player", unit) then
                schedule(267533, 13 - offset, guid)
                schedule(267522, 5.7 - offset, guid)
            end
        end
        self.state.captainTimersStarted = true
    elseif id == 2140 then
        local guid = UnitGUID("boss1")
        if guid and guid ~= self.state.councilBossGUID then
            self.state.councilBossGUID = guid
            self.state.councilStage = (self.state.councilStage or 0) + 1
            local stage = self.state.councilStage
            local npcID = BKA:GetNPCID(guid)
            self.state.councilOrder[stage] = npcID
            if npcID == 135475 then
                schedule(266206, 8, "council")
                schedule(266231, 24, "council")
            elseif npcID == 135470 then
                schedule(266951, 5.5, "council")
            elseif npcID == 135472 then
                schedule(267273, 16, "council")
                schedule(267060, 20, "council")
            end
            if stage > 1 then
                show(0, { spellName = BKA:L("COUNCIL_STAGE"), targetName = tostring(stage), key = "council-stage:" .. stage }, { id = 0, action = "STAGE", severity = "MEDIUM", center = true })
                startCouncilTimer(self.state.councilOrder[1], 15.8)
                if stage == 3 then startCouncilTimer(self.state.councilOrder[2], 48.1) end
            end
        elseif not guid and self.state.councilBossGUID then
            self.state.councilBossGUID = nil
            for _, spellID in ipairs({266206, 266231, 266951, 266237, 267273, 267060}) do
                BKA.Timers:CancelAbility(spellID)
            end
        end
    elseif id == 2143 then
        for index = 1, 3 do
            local unit = "boss" .. index
            local guid = UnitGUID(unit)
            if guid and not self.state.dazarMobs[guid] then
                self.state.dazarMobs[guid] = true
                local npcID = BKA:GetNPCID(guid)
                if npcID == 136984 then
                    show(269231, { sourceGUID = guid, spellName = BKA:L("REBAN"), targetName = BKA:L("SPAWNED"), key = "dazar-reban" }, { action = "ADD", severity = "MEDIUM", center = true })
                    schedule(269231, 5, guid)
                elseif npcID == 136976 then
                    show(269369, { sourceGUID = guid, spellName = BKA:L("TZALA"), targetName = BKA:L("SPAWNED"), key = "dazar-tzala" }, { action = "ADD", severity = "MEDIUM", center = true })
                    schedule(269369, 8.5, guid)
                end
            end
        end
    elseif id == 2100 and not self.state.engagedGripping and bossGUID(137405) then
        self.state.engagedGripping = true
        schedule(270605, 20, "viq", BKA:L("DEMOLISHING_TERROR") .. " 2", { id = 270605, action = "ADD", center = true })
    end
end

function Special:HandleUnitEvent(event, unit, spellID)
    local id = self.state.encounterID
    local guid = unit and UnitGUID(unit)
    local npcID = BKA:GetNPCID(guid)
    if event == "UNIT_SPELLCAST_SUCCEEDED" then
        if BKA.activeDungeon.key == "SiegeOfBoralus" and not id and spellID == 272711 then
            schedule(257169, 6, guid)
        elseif id == 2107 and spellID == 270028 then
            self.state.azeriteCatalystCount = (self.state.azeriteCatalystCount or 0) + 1
            show(270028, { sourceGUID = guid, spellName = GetSpellInfo(270028), key = "azerite-catalyst" }, { action = "MOVE", severity = "HIGH", center = true, sound = true })
            schedule(270028, self.state.azeriteCatalystCount % 2 == 1 and 15 or 27, guid, nil, { mechanic = "DODGE", action = "MOVE", severity = "HIGH", center = true })
        elseif id == 2143 and spellID == 269377 then
            show(268796, { sourceGUID = guid, spellName = GetSpellInfo(268796), key = "dazar-spears" }, { action = "SPEARS ACTIVE", severity = "HIGH", center = true, sound = true })
        elseif id == 2093 and spellID == 256056 then
            BKA.Timers:CancelAbility(255952)
            show(256056, { spellName = BKA:L("STAGE_TWO"), key = "kragg-stage-2" }, { id = 256056, action = "STAGE 2", severity = "MEDIUM", center = true, sound = true })
            schedule(256106, 7, guid)
            schedule(256005, 6, guid)
            schedule(272046, 17, guid)
        elseif id == 2096 and spellID == 257454 then
            show(257278, { sourceGUID = guid, spellName = GetSpellInfo(257278), key = "harlan-saber:" .. tostring(guid) }, { action = "DODGE", severity = "MEDIUM", center = true })
            schedule(257278, 15, guid)
        elseif (id == 2097 or id == 2098) and spellID == 257540 then
            self.state.bombsRemaining = 3
            show(257585, { sourceGUID = guid, spellName = GetSpellInfo(257585), key = "cannon-barrage" }, { mechanic = "DODGE", action = "DODGE", severity = "HIGH", center = true, sound = true })
            schedule(257585, 60, guid)
            local bombID = id == 2098 and 273721 or 277965
            schedule(bombID, id == 2098 and 43 or 42, guid, "Heavy Ordnance (3)")
        elseif (id == 2097 or id == 2098) and spellID == 274002 then
            local maximum = UnitHealthMax(unit)
            local health = maximum and maximum > 0 and UnitHealth(unit) / maximum * 100 or 100
            if health > 33 then
                show(274002, { sourceGUID = guid, spellName = GetSpellInfo(274002), key = "call-adds" }, { action = "ADDS", severity = "MEDIUM", center = true, sound = true })
            end
        elseif id == 2109 and spellID == 268752 then
            self.state.withdrawn = true
            show(268752, { sourceGUID = guid, spellName = GetSpellInfo(268752), key = "withdraw" }, { action = "WITHDRAW", severity = "MEDIUM", center = true, sound = true })
            BKA.Timers:CancelAbility(269029)
            BKA.Timers:CancelAbility(268752)
            schedule(268260, 11.2, guid)
        elseif id == 2109 and spellID == 268745 and self.state.withdrawn then
            self.state.withdrawn = false
            show(268752, { sourceGUID = guid, spellName = GetSpellInfo(268752), targetName = BKA:L("OVER"), key = "withdraw-over" }, { action = "RESUME", severity = "MEDIUM", center = true })
            schedule(269029, 7, guid)
            schedule(268752, 35.7, guid)
        elseif id == 2109 and spellID == 268963 then
            show(268963, { sourceGUID = guid, spellName = GetSpellInfo(268963), key = "ordnance-dropped" }, { action = "ORDNANCE", severity = "MEDIUM", center = true })
        elseif id == 2099 and spellID == 257861 then
            show(261563, { sourceGUID = guid, spellName = GetSpellInfo(261563), key = "crashing-tide" }, { action = "DODGE", severity = "MEDIUM", center = true })
            schedule(261563, 16, guid)
        elseif id == 2100 and spellID == 270183 then
            show(270185, { sourceGUID = guid, spellName = GetSpellInfo(270185), key = "call-deep" }, { action = "DODGE", severity = "HIGH", center = true, sound = true })
            local stage = self.state.viqStage or 1
            schedule(270185, stage == 1 and 15 or stage == 2 and 12 or 7, guid)
        elseif id == 2100 and spellID == 269984 then
            self.state.viqStage = (self.state.viqStage or 1) + 1
            if self.state.viqStage < 4 then
                self.state.engagedGripping = false
                self.state.demolisherCount = 1
                show(269984, { spellName = BKA:L("VIQ_GOTH_STAGE"), targetName = tostring(self.state.viqStage), key = "viq-stage:" .. self.state.viqStage }, { action = "STAGE", severity = "MEDIUM", center = true })
            end
        elseif id == 2100 and spellID == 270605 then
            self.state.demolisherCount = (self.state.demolisherCount or 1) + 1
            local count = self.state.demolisherCount
            if count <= 5 then
                show(270605, { spellName = BKA:L("DEMOLISHING_TERROR"), targetName = tostring(count), key = "demolisher:" .. count }, { id = 270605, action = "ADD", severity = "HIGH", center = true, sound = true })
            end
            if count <= 4 then schedule(270605, 20, "viq", BKA:L("DEMOLISHING_TERROR") .. " " .. (count + 1), { id = 270605, action = "ADD", center = true }) end
        end
    elseif event == "UNIT_SPELLCAST_START" then
        if BKA.activeDungeon.key == "SiegeOfBoralus" and not id and spellID == 272711 then
            show(272711, { sourceGUID = guid, spellName = GetSpellInfo(272711), key = "trash-crushing-slam:" .. tostring(guid) }, { action = "DODGE", severity = "HIGH", center = true, sound = true })
        elseif BKA.activeDungeon.key == "SiegeOfBoralus" and not id and spellID == 268260 and npcID == 138465 then
            show(268260, { sourceGUID = guid, spellName = GetSpellInfo(268260), key = "trash-broadside:" .. tostring(guid) }, { action = "DODGE", severity = "HIGH", center = true, sound = true })
        elseif BKA.activeDungeon.key == "SiegeOfBoralus" and not id and spellID == 272874 then
            show(272874, { sourceGUID = guid, spellName = GetSpellInfo(272874), key = "trash-trample:" .. tostring(guid) }, { action = "DODGE", severity = "MEDIUM", center = true })
        elseif BKA.activeDungeon.key == "SiegeOfBoralus" and not id and spellID == 257288 then
            show(257288, { sourceGUID = guid, spellName = GetSpellInfo(257288), key = "trash-heavy-slash:" .. tostring(guid) }, { mechanic = "FRONTAL", action = "FRONTAL", severity = "HIGH", center = true })
        elseif (id == 2097 or id == 2098) and ((id == 2098 and spellID == 257288) or (id == 2097 and spellID == 279761)) then
            show(spellID, { sourceGUID = guid, spellName = GetSpellInfo(spellID), key = "heavy-slash:" .. tostring(guid) }, { mechanic = "FRONTAL", action = "FRONTAL", severity = "HIGH", center = true })
        elseif id == 2109 and npcID == 136549 and spellID == 268260 then
            show(268260, { sourceGUID = guid, spellName = GetSpellInfo(268260), key = "broadside:" .. tostring(guid) }, { mechanic = "DODGE", action = "DODGE", severity = "HIGH", center = true, sound = true })
            schedule(268260, 12, guid)
        end
    elseif event == "UNIT_POWER_FREQUENT" and string.match(unit or "", "^boss%d$") then
        local now = GetTime()
        if id == 2124 then
            if npcID == 133379 and not UnitIsDead(unit) and UnitPower(unit) == 100 and now - (self.state.arcDashAt or 0) > 2 then
                self.state.arcDashAt = now
                show(263424, { sourceGUID = guid, spellName = GetSpellInfo(263424), key = "arc-dash:" .. tostring(guid) }, { mechanic = "DODGE", action = "DODGE", severity = "MEDIUM", center = true })
            end
            if UnitPower(unit) == 0 and guid ~= self.state.shieldGUID then
                self.state.shieldGUID = guid
                schedule(263246, 4, guid)
            end
        elseif id == 2126 and spellID == "ALTERNATE" and now - (self.state.consumeAt or 0) > 0.5 then
            local power = UnitPower(unit, 10)
            if power and power > 0 then
                self.state.consumeAt = now
                show(266512, { sourceGUID = guid, spellName = GetSpellInfo(266512), targetName = tostring(power) .. "%", key = "consume-charge:" .. tostring(guid) }, { action = "AOE", severity = "HIGH", center = true, sound = true })
            end
        end
    elseif event == "UNIT_HEALTH_FREQUENT" and id == 2143 and unit == "boss1" then
        local maximum = UnitHealthMax(unit)
        local health = maximum and maximum > 0 and UnitHealth(unit) / maximum * 100 or 100
        local threshold = self.state.dazarNextHealth or 85
        if health < threshold then
            local label = threshold == 85 and "Reban soon" or threshold == 65 and "T'zala soon" or "SPEARS SOON"
            show(0, { spellName = label, key = "dazar-health:" .. threshold }, { id = 0, action = "STAGE", severity = "MEDIUM", center = true })
            self.state.dazarNextHealth = threshold - 20
        end
    elseif event == "UNIT_TARGETABLE_CHANGED" and id == 2125 and string.match(unit or "", "^boss%d$") then
        if UnitCanAttack("player", unit) then
            show(264206, { sourceGUID = guid, spellName = GetSpellInfo(264206), targetName = BKA:L("OVER"), key = "burrow-over" }, { action = "RESUME", severity = "MEDIUM", center = true })
            schedule(263914, 6, guid)
            schedule(263958, 8, guid)
        else
            show(264206, { sourceGUID = guid, spellName = GetSpellInfo(264206), key = "burrow" }, { action = "BURROW", severity = "MEDIUM", center = true })
            schedule(264206, 29, guid)
            BKA.Timers:CancelAbility(264239)
            BKA.Timers:CancelAbility(263912)
        end
    end
end

function Special:HandleCombatLog(event, context)
    local id = self.state.encounterID
    if id == 2107 and event == "SPELL_CAST_SUCCESS" and context.spellID == 259856 then
        self.state.chemicalBurnCount = (self.state.chemicalBurnCount or 0) + 1
        schedule(259853, self.state.chemicalBurnCount % 2 == 1 and 15 or 27, context.sourceGUID)
    elseif id == 2093 and event == "SPELL_CAST_SUCCESS" and context.spellID == 256005 then
        local now = context.timestamp or GetTime()
        local delay = now - (self.state.kraggBombardmentAt or 0) > 8 and 6 or 10.8
        self.state.kraggBombardmentAt = now
        show(256005, context, { action = "DODGE", severity = "MEDIUM", center = true })
        schedule(256005, delay, context.sourceGUID)
    elseif id == 2096 then
        if event == "SPELL_CAST_START" and (context.spellID == 257402 or context.spellID == 257458) then
            self.state.harlanStage = context.spellID == 257402 and 2 or 3
            show(context.spellID, { sourceGUID = context.sourceGUID, spellName = context.spellName, key = "loaded-dice:" .. context.spellID }, { action = "STAGE " .. self.state.harlanStage, severity = "MEDIUM", center = true })
            schedule(257278, 10.9, context.sourceGUID)
            schedule(257305, 17, context.sourceGUID)
            if self.state.harlanStage == 3 then
                local remaining = BKA.Timers:GetRemaining(257316)
                if remaining > 2.4 then schedule(257316, remaining - 2.4, context.sourceGUID, BKA:L("NEXT_ADDS")) end
            end
        elseif event == "SPELL_CAST_SUCCESS" and context.spellID == 257278 then
            show(257278, context, { action = "DODGE", severity = "MEDIUM", center = true })
            schedule(257278, (self.state.harlanStage or 1) == 1 and 15.8 or 12.2, context.sourceGUID)
        elseif event == "SPELL_AURA_APPLIED" and context.spellID == 257305 then
            if not self.state.harlanCannonPending then
                self.state.harlanCannonPending = true
                self.state.harlanCannonOnPlayer = false
                self.state.harlanCannonSourceGUID = context.sourceGUID
                self.state.harlanCannonSpellName = context.spellName
                local generation = self.generation
                C_Timer.After(0.1, function()
                    if not BKA.active or Special.generation ~= generation or Special.state.encounterID ~= 2096 or not Special.state.harlanCannonPending then
                        return
                    end
                    local onPlayer = Special.state.harlanCannonOnPlayer
                    show(257305, {
                        sourceGUID = Special.state.harlanCannonSourceGUID,
                        spellName = Special.state.harlanCannonSpellName or GetSpellInfo(257305),
                        targetName = onPlayer and UnitName("player") or nil,
                        isPlayer = onPlayer,
                        targetConfidence = onPlayer and "CONFIRMED" or "NONE",
                        key = "harlan-cannon",
                    }, { action = "MOVE", severity = "HIGH", center = true, sound = true })
                    schedule(257305, 18.2, Special.state.harlanCannonSourceGUID)
                    Special.state.harlanCannonPending = nil
                    Special.state.harlanCannonOnPlayer = nil
                    Special.state.harlanCannonSourceGUID = nil
                    Special.state.harlanCannonSpellName = nil
                end)
            end
            if context.destGUID == UnitGUID("player") then
                self.state.harlanCannonOnPlayer = true
            end
        elseif event == "SPELL_AURA_APPLIED" and context.spellID == 257314 and context.sourceGUID ~= context.destGUID then
            show(257314, { sourceGUID = context.sourceGUID, spellName = context.spellName, targetName = context.destName, isPlayer = context.destGUID == UnitGUID("player"), targetConfidence = "CONFIRMED", key = "black-powder:" .. tostring(context.destGUID) }, { action = "FIXATE", severity = context.destGUID == UnitGUID("player") and "CRITICAL" or "HIGH", center = true, sound = true })
            schedule(257316, (self.state.harlanStage or 1) == 3 and 18.2 or 20.6, context.sourceGUID, BKA:L("NEXT_ADDS"))
        end
    elseif id == 2100 and context.spellID == 275014 then
        local targets = self.state.putridWatersTargets
        if not targets then
            targets = {}
            self.state.putridWatersTargets = targets
        end
        if event == "SPELL_AURA_APPLIED" then
            local targetKey, target = findPutridTarget(targets, context.destGUID, context.destName)
            local isNew = not target
            local isPlayer = context.destGUID == UnitGUID("player")
            if isNew and (context.destGUID or context.destName) then
                targetKey = context.destGUID or context.destName
                targets[targetKey] = { guid = context.destGUID, name = context.destName, isPlayer = isPlayer }
            end
            if isPlayer then
                self.state.putridWatersOnPlayer = true
                if isNew then
                    show(275014, { spellName = context.spellName, targetName = context.destName, isPlayer = true, targetConfidence = "CONFIRMED", key = "viq-putrid-player" }, { action = "SPREAD", severity = "CRITICAL", center = true, sound = true })
                end
            end
            showPutridWatersGroup(false)
            if isNew and not self.state.putridWatersPending then
                self.state.putridWatersPending = true
                self.state.putridWatersBatchOnPlayer = isPlayer
                self.state.putridWatersSourceGUID = context.sourceGUID
                local generation = self.generation
                C_Timer.After(0.1, function()
                    if not BKA.active or Special.generation ~= generation or Special.state.encounterID ~= 2100 or not Special.state.putridWatersPending then
                        return
                    end
                    showPutridWatersGroup(not Special.state.putridWatersBatchOnPlayer)
                    schedule(275014, 20, Special.state.putridWatersSourceGUID)
                    Special.state.putridWatersPending = nil
                    Special.state.putridWatersBatchOnPlayer = nil
                    Special.state.putridWatersSourceGUID = nil
                end)
            elseif isNew and isPlayer then
                self.state.putridWatersBatchOnPlayer = true
            end
        elseif event == "SPELL_AURA_REMOVED" then
            local targetKey, target = findPutridTarget(targets, context.destGUID, context.destName)
            if targetKey then
                targets[targetKey] = nil
            end
            if (target and target.isPlayer) or context.destGUID == UnitGUID("player") then
                self.state.putridWatersOnPlayer = nil
                BKA.Alerts:Hide("viq-putrid-player")
            end
            if next(targets) then
                showPutridWatersGroup(false)
            else
                BKA.Alerts:Hide("viq-putrid-group")
            end
        end
    elseif id == 2140 then
        local livingID = BKA:GetNPCID(UnitGUID("boss1"))
        if event == "SPELL_CAST_START" and context.spellID == 266206 then
            schedule(266206, livingID == 135475 and 10.9 or 50, "council")
        elseif event == "SPELL_CAST_START" and context.spellID == 267273 then
            schedule(267273, livingID == 135472 and 29.2 or 51, "council")
        end
    elseif (id == 2097 or id == 2098) and (context.spellID == 273720 or context.spellID == 280933 or context.spellID == 280934 or context.spellID == 273721 or context.spellID == 277965) then
        local now = context.timestamp or GetTime()
        if now ~= self.state.lastBombAt then
            self.state.lastBombAt = now
            self.state.bombsRemaining = math.max(0, (self.state.bombsRemaining or 0) - 1)
            local bombID = id == 2098 and 273721 or 277965
            show(bombID, { spellName = GetSpellInfo(bombID), targetName = BKA:L("REMAINING_COUNT_FMT", self.state.bombsRemaining), key = "bombs:" .. self.state.bombsRemaining }, { action = "ORDNANCE", severity = "MEDIUM", center = true })
        end
    elseif id == 2124 and event == "SPELL_CAST_START" and context.spellID == 263309 then
        self.state.cycloneStrikeCount = (self.state.cycloneStrikeCount or 0) + 1
        if self.state.cycloneStrikeCount % 2 == 1 then schedule(263309, 13.5, context.sourceGUID) end
    elseif id == 2127 and event == "SPELL_CAST_SUCCESS" and context.spellID == 273677 then
        local now = GetTime()
        if now - (self.state.taintAt or 0) > 2 then
            self.state.taintAt = now
            self.state.avatarStage = (self.state.avatarStage or 0) + 1
            self.state.hexerCount = 4
            local stage = self.state.avatarStage
            if stage > 1 then show(273677, { spellName = BKA:L("INTERMISSION_OVER"), key = "avatar-stage:" .. stage }, { action = "STAGE", severity = "MEDIUM", center = true }) end
            schedule(268007, stage == 3 and 2.5 or 3.5, "avatar", BKA:L("HEART_GUARDIAN"), { action = "ADD", center = true })
            if stage == 3 then
                schedule(268008, 3.5, "avatar-doctor-1", BKA:L("PLAGUE_DOCTOR"), { action = "ADD", center = true })
                C_Timer.After(3.5, function() if BKA.active and Special.state.encounterID == 2127 then schedule(268008, 6, "avatar-doctor-2", BKA:L("PLAGUE_DOCTOR"), { action = "ADD", center = true }) end end)
            else
                schedule(268008, 16.5, "avatar", BKA:L("PLAGUE_DOCTOR"), { action = "ADD", center = true })
            end
        end
    elseif id == 2126 and event == "SPELL_AURA_APPLIED_DOSE" and context.spellID == 266923 and context.destGUID == UnitGUID("player") and context.amount and context.amount % 3 == 0 then
        show(266923, { spellName = context.spellName, targetName = tostring(context.amount), isPlayer = true, targetConfidence = "CONFIRMED", key = "galvanize-player" }, { action = "STACKS", severity = context.amount > 6 and "HIGH" or "MEDIUM", center = true, sound = context.amount > 6 })
    end
end

function Special:HandleDeath(destGUID, destName)
    local npcID = BKA:GetNPCID(destGUID)
    if self.state.encounterID == 2100 and npcID == 137405 then
        BKA.Timers:CancelAbility(270605)
    elseif self.state.encounterID == 2127 and npcID == 137204 then
        self.state.hexerCount = math.max(0, (self.state.hexerCount or 4) - 1)
        if self.state.hexerCount > 0 then
            show(137204, { spellName = destName or BKA:L("HOODOO_HEXER"), targetName = BKA:L("REMAINING_COUNT_FMT", self.state.hexerCount), key = "hexers:" .. self.state.hexerCount }, { id = 137204, action = "ADDS", severity = "MEDIUM", center = true })
        elseif self.state.avatarStage ~= 3 then
            show(137204, { spellName = BKA:L("INTERMISSION"), key = "avatar-intermission" }, { id = 137204, action = "INTERMISSION", severity = "MEDIUM", center = true })
            BKA.Timers:CancelAbility(268024)
        end
    end
end
