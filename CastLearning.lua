local BKA = BFAKeyAlerts
local Learning = { runtime = {}, activeCount = 0 }
BKA.CastLearning = Learning

local MAX_NPCS = 48
local MAX_RUNTIME = 80
local MAX_AGE = 120
local IMPORTANT = {
    KICK = true, STOP = true, CC = true, FRONTAL = true, CLEAVE = true,
    AOE = true, MOVE = true, DEFENSIVE = true, DISPEL = true,
    PURGE = true, SOOTHE = true,
}

local function predictionMode(prediction)
    if not prediction then return nil end
    if prediction.mode then return prediction.mode end
    if prediction.source == "same-spell" or prediction.source == "rotation" then
        return BKA.CastPredictor.MODE_SCHEDULED
    end
    return BKA.CastPredictor.MODE_NEXT
end

local function predictionMetrics(model)
    if not model then return nil end
    if type(model.predictionMetrics) ~= "table" then
        -- Preserve the legacy scheduled counter as the best available starting point.
        model.predictionMetrics = { created = tonumber(model.highConfidence) or 0, displayed = 0, invalidated = 0 }
    end
    return model.predictionMetrics
end

local function samePredictionOpportunity(a, b)
    if not a or not b or a.guid ~= b.guid or a.spellID ~= b.spellID or
        predictionMode(a) ~= predictionMode(b) or a.source ~= b.source then return false end
    local aExpected, bExpected = tonumber(a.expectedTime), tonumber(b.expectedTime)
    if not aExpected or not bExpected then return false end
    -- START/SUCCESS/INTERRUPT may refresh the same opportunity with a slightly
    -- better anchor. Keep this deliberately narrow so two nearby real casts are
    -- never collapsed merely because their prediction windows overlap.
    return math.abs(aExpected - bExpected) <= 0.5
end

local function refreshPrediction(existing, candidate)
    local unit, displayed = existing.unit, existing.wasDisplayed
    local alertShown, alertKey, alertRow = existing.alertShown, existing.alertKey, existing.alertRow
    for key in pairs(existing) do existing[key] = nil end
    for key, value in pairs(candidate) do existing[key] = value end
    existing.unit = unit
    existing.wasDisplayed = displayed
    existing.alertShown, existing.alertKey, existing.alertRow = alertShown, alertKey, alertRow
    return existing
end

local function isMobGUID(guid)
    return type(guid) == "string" and (string.find(guid, "^Creature%-") or string.find(guid, "^Vehicle%-"))
end

local function hostile(flags)
    return flags and bit and bit.band(flags, COMBATLOG_OBJECT_REACTION_HOSTILE or 0x40) ~= 0
end

local function settings()
    return BKA.db and BKA.db.castLearning
end

function Learning:ResetRuntime()
    if BKA.CastPredictionUI then BKA.CastPredictionUI:Clear() end
    if BKA.Alerts then
        for _, state in pairs(self.runtime) do BKA.Alerts:HidePrediction(state.prediction) end
    end
    wipe(self.runtime)
    self.activeCount = 0
    self.lastSweep = 0
end

function Learning:BuildAllowed(dungeon)
    self.allowed = {}
    local bosses = {}
    for _, ability in ipairs(dungeon.abilities or {}) do
        if ability.module ~= "Trash" and ability.module ~= "MDT" and ability.module ~= "Options" then
            for _, npcID in ipairs(ability.sources or {}) do bosses[npcID] = true end
        end
    end
    for _, ability in ipairs(dungeon.abilities or {}) do
        if ability.module == "Trash" or ability.module == "MDT" then
            for _, npcID in ipairs(ability.sources or {}) do
                if not bosses[npcID] then self.allowed[npcID] = true end
            end
        end
    end
end

function Learning:GetModel(dungeonID, npcID)
    local db = settings()
    local dungeon = db and db.dungeons and db.dungeons[dungeonID]
    local model = type(dungeon) == "table" and type(dungeon.npcs) == "table" and dungeon.npcs[npcID]
    return type(model) == "table" and model or nil
end

function Learning:GetOrCreateModel(dungeonID, npcID)
    local db = settings()
    if not db or db.version ~= 1 then return nil end
    local dungeon = db.dungeons[dungeonID]
    if type(dungeon) ~= "table" then
        dungeon = { npcs = {}, count = 0 }
        db.dungeons[dungeonID] = dungeon
    end
    if type(dungeon.npcs) ~= "table" then dungeon.npcs = {}; dungeon.count = 0 end
    if type(dungeon.count) ~= "number" then
        dungeon.count = 0
        for _ in pairs(dungeon.npcs) do dungeon.count = dungeon.count + 1 end
    end
    local model = dungeon.npcs[npcID]
    if model then return model end
    if (dungeon.count or 0) >= MAX_NPCS then return nil end
    model = { spells = {}, transitions = {}, second = {}, total = 0 }
    dungeon.npcs[npcID] = model
    dungeon.count = (dungeon.count or 0) + 1
    return model
end

function Learning:State(guid, npcID, now)
    local state = self.runtime[guid]
    if state then state.lastEventTime = now; return state end
    if self.activeCount >= MAX_RUNTIME then self:Sweep(now, true) end
    if self.activeCount >= MAX_RUNTIME then return nil end
    state = { npcID = npcID, lastEventTime = now, lastBySpell = {}, startedBySpell = {}, recentIntervals = {},
        casts = 0, cc = { active = false, spells = {} }, ccSinceCast = false }
    self.runtime[guid] = state
    self.activeCount = self.activeCount + 1
    return state
end

function Learning:Sweep(now, force)
    if not force and now - (self.lastSweep or 0) < 10 then return end
    self.lastSweep = now
    for guid, state in pairs(self.runtime) do
        if now - (state.lastEventTime or now) > MAX_AGE then self:Remove(guid, "STALE") end
    end
end

function Learning:Remove(guid, reason)
    local state = self.runtime[guid]
    if not state then return end
    self:Invalidate(state, reason or "CANCELLED")
    self.runtime[guid] = nil
    self.activeCount = math.max(0, self.activeCount - 1)
end

function Learning:Invalidate(state, reason)
    if not state.prediction then return end
    local prediction = state.prediction
    reason = reason or "CANCELLED"
    state.lastOutcome = reason
    if reason ~= "HIT" and reason ~= "MISS" then
        local model = self:GetModel(prediction.dungeonID, state.npcID)
        BKA.CastPredictor:RecordOutcome(model, prediction, reason)
        local metrics = predictionMetrics(model)
        if metrics then metrics.invalidated = (metrics.invalidated or 0) + 1 end
    end
    if BKA.CastPredictionUI then BKA.CastPredictionUI:Hide(prediction.unit, prediction.guid) end
    if BKA.Alerts then BKA.Alerts:HidePrediction(prediction) end
    state.prediction = nil
end

function Learning:ResolveAbility(npcID, spellID)
    local policy = BKA:GetInterruptPolicy(npcID, spellID)
    if policy and policy.policy == "IGNORE" and policy.suppressAlert then return nil end
    local ability = BKA:GetAbilityForUnitSpell(npcID, spellID)
    if not ability or not ability.nameplate or ability.personalOnly then return nil end
    local action = BKA:NormalizeAction(ability.primaryAction or ability.action, ability.mechanic)
    local control = ability.castControl
    if control == "IGNORE" then return nil end
    if control == "KICK" then
        if not BKA:IsGeometryAction(action) then action = "KICK" end
    elseif control == "STOP" then
        if not BKA:IsGeometryAction(action) then action = "STOP" end
    end
    if settings().importantOnly ~= false and not IMPORTANT[action] and not IMPORTANT[control] then return nil end
    return ability, action, control
end

function Learning:Schedule(state, guid, model, now)
    local cfg = settings()
    if not cfg or not cfg.predictions then return end
    local dungeonID = BKA.activeDungeon and BKA.activeDungeon.challengeMapID
    local predictionModel = BKA.CastPredictor:GetModel(dungeonID, state.npcID) or model
    local prediction = BKA.CastPredictor:Predict(predictionModel, state, now, cfg)
    if not prediction then return end
    local ability, action, control = self:ResolveAbility(state.npcID, prediction.spellID)
    if not ability then return end
    prediction.guid = guid
    prediction.sourceGUID = guid
    prediction.dungeonID = BKA.activeDungeon and BKA.activeDungeon.challengeMapID
    prediction.npcID = state.npcID
    prediction.action = action
    prediction.controlAction = control
    prediction.severity = ability.severity or "MEDIUM"
    prediction.ability = ability
    prediction.mode = predictionMode(prediction)
    local current = state.prediction
    if current then
        if samePredictionOpportunity(current, prediction) then
            refreshPrediction(current, prediction)
            self:EnsureTicker()
            return current
        end
        -- A scheduled cooldown/rotation prediction is about a timestamp, not the
        -- immediately following cast. Intermediate casts must not replace it.
        if predictionMode(current) == BKA.CastPredictor.MODE_SCHEDULED then
            self:EnsureTicker()
            return current
        end
        self:Invalidate(state, "SUPERSEDED")
    end
    state.prediction = prediction
    local localModel = self:GetOrCreateModel(dungeonID, state.npcID) or model
    if localModel then
        local metrics = predictionMetrics(localModel)
        metrics.created = (metrics.created or 0) + 1
        -- Keep the old field readable for existing exports/tools, but only count
        -- unique prediction opportunities from this point onward.
        localModel.highConfidence = (localModel.highConfidence or 0) + 1
    end
    self:EnsureTicker()
    return prediction
end

function Learning:Feedback(state, spellID, now, model)
    local prediction = state.prediction
    if not prediction then return end
    local mode = predictionMode(prediction)
    local early = prediction.expectedTime - prediction.earlyWindow
    local late = prediction.expectedTime + prediction.lateWindow
    if mode == BKA.CastPredictor.MODE_SCHEDULED then
        if prediction.spellID ~= spellID then return end
        if now < early then
            -- The same spell fired before the predicted window. The old schedule
            -- is no longer a useful anchor, but this is not a false-prediction MISS.
            self:Invalidate(state, "EARLY_SUPERSEDED")
            return
        end
        if now > late then
            BKA.CastPredictor:RecordOutcome(model, prediction, "MISS", now)
            state.lastOutcome = "MISS"
        else
            BKA.CastPredictor:RecordOutcome(model, prediction, "HIT", now)
            state.lastOutcome = "HIT"
        end
    else
        local hit = prediction.spellID == spellID and now >= early and now <= late
        BKA.CastPredictor:RecordOutcome(model, prediction, hit and "HIT" or "MISS", now)
        state.lastOutcome = hit and "HIT" or "MISS"
    end
    if BKA.CastPredictionUI then BKA.CastPredictionUI:Hide(prediction.unit, prediction.guid) end
    if BKA.Alerts then BKA.Alerts:HidePrediction(prediction) end
    state.prediction = nil
end

function Learning:ObserveCast(guid, npcID, spellID, now, fromStart)
    local state = self:State(guid, npcID, now)
    if not state then return end
    if state.lastCast and state.lastCast.spellID == spellID and now - state.lastCast.start < 0.25 then return end
    local dungeonID = BKA.activeDungeon and BKA.activeDungeon.challengeMapID
    local model = self:GetOrCreateModel(dungeonID, npcID)
    if not model then return end
    self:Feedback(state, spellID, now, model)
    BKA.CastPredictor:Observe(model, state, spellID, now)
    if state.ccSinceCast then state.previousCast = nil else state.previousCast = state.lastCast end
    local cast = { spellID = spellID, start = now, fromStart = fromStart }
    state.lastCast = cast
    state.lastBySpell[spellID] = cast
    if fromStart then state.startedBySpell[spellID] = cast end
    state.lastCastSpellID = spellID
    state.lastCastStart = now
    if fromStart then state.activeCast = cast end
    state.casts = state.casts + 1
    state.ccSinceCast = false
    self:Schedule(state, guid, model, now)
end

function Learning:OnCastStart(guid, npcID, spellID, now)
    self:ObserveCast(guid, npcID, spellID, now, true)
end

function Learning:OnInstantCast(guid, npcID, spellID, now)
    self:ObserveCast(guid, npcID, spellID, now, false)
end

function Learning:OnEngage(guid, npcID, now)
    -- A GUID first seen casting or under CC is already in an unknown combat context.
    -- Only the first observed hostile interaction can anchor an opening sample.
    if self.runtime[guid] then return end
    local state = self:State(guid, npcID, now)
    if not state then return end
    state.combatStart = now
    state.combatStartReliable = true
    self:Schedule(state, guid, self:GetModel(BKA.activeDungeon.challengeMapID, npcID), now)
end

function Learning:OnCC(guid, spellID, sourceGUID, applied, now)
    local state = self.runtime[guid]
    if not state then return end
    local cc = state.cc
    local key = tostring(spellID) .. ":" .. tostring(sourceGUID or "?")
    if applied then
        cc.spells[key] = { spellID = spellID, started = now }
        cc.active, cc.start, cc.spellID = true, now, spellID
        state.ccSinceCast = true
        -- Old per-spell anchors must not bridge the CC window later.
        wipe(state.lastBySpell)
        wipe(state.recentIntervals)
        if state.activeCast then state.activeCast.failed = true; state.activeCast = nil end
        self:Invalidate(state, "INVALIDATED_BY_CC")
    else
        if cc.spells[key] then
            cc.spells[key] = nil
        else
            -- Some CLEU sources omit the caster on removal. Remove one matching
            -- aura while retaining any overlapping application from another caster.
            for candidate, aura in pairs(cc.spells) do
                if aura.spellID == spellID then cc.spells[candidate] = nil; break end
            end
        end
        if not next(cc.spells) then
            cc.active, cc.finish = false, now
        end
    end
end

function Learning:OnCombatLog(event, sourceGUID, sourceFlags, destGUID, destFlags, spellID, extraSpellID)
    local cfg = settings()
    if not cfg or cfg.enabled == false or cfg.version ~= 1 or not BKA.activeDungeon then return end
    local now = GetTime()
    self:Sweep(now)
    if event == "UNIT_DIED" or event == "PARTY_KILL" then
        if isMobGUID(destGUID) then self:Remove(destGUID, "MOB_DIED") end
        return
    end
    if (event == "SPELL_AURA_APPLIED" or event == "SPELL_AURA_REFRESH" or event == "SPELL_AURA_REMOVED") and
        isMobGUID(destGUID) and spellID and BKA.GroupInterrupts:IsHardCCAura(spellID) then
        local ccNPC = BKA:GetNPCID(destGUID)
        if self.allowed and self.allowed[ccNPC] then
            if event ~= "SPELL_AURA_REMOVED" then self:State(destGUID, ccNPC, now) end
            self:OnCC(destGUID, spellID, sourceGUID, event ~= "SPELL_AURA_REMOVED", now)
        end
    end
    if cfg.debug and (event == "SPELL_AURA_APPLIED" or event == "SPELL_AURA_REFRESH") and
        isMobGUID(destGUID) and type(spellID) == "number" and
        not BKA.GroupInterrupts:IsHardCCAura(spellID) then
        local auraNPC = BKA:GetNPCID(destGUID)
        if self.allowed and self.allowed[auraNPC] then
            local auraState = self:State(destGUID, auraNPC, now)
            if auraState then
                local recent = auraState.recentAuras or {}
                auraState.recentAuras = recent
                if recent[#recent] ~= spellID then
                    recent[#recent + 1] = spellID
                    if #recent > 12 then table.remove(recent, 1) end
                end
            end
        end
    end
    if event == "SPELL_INTERRUPT" and isMobGUID(destGUID) then
        local state = self.runtime[destGUID]
        local cast = state and state.activeCast
        if cast and (not extraSpellID or cast.spellID == extraSpellID) then
            cast.interrupt = now
            state.activeCast = nil
            local model = self:GetModel(BKA.activeDungeon.challengeMapID, state.npcID)
            if model then self:Schedule(state, destGUID, model, now) end
        end
    end
    if not isMobGUID(sourceGUID) then
        if isMobGUID(destGUID) and (event == "SWING_DAMAGE" or event == "SPELL_DAMAGE" or event == "SWING_MISSED" or event == "SPELL_MISSED") then
            local npcID = BKA:GetNPCID(destGUID)
            if self.allowed and self.allowed[npcID] then self:OnEngage(destGUID, npcID, now) end
        end
        return
    end
    local npcID = BKA:GetNPCID(sourceGUID)
    if not npcID or not self.allowed or not self.allowed[npcID] or not hostile(sourceFlags) then return end
    local state = self.runtime[sourceGUID]
    if state then state.lastEventTime = now end
    if event == "SWING_DAMAGE" or event == "SPELL_DAMAGE" or event == "SWING_MISSED" or event == "SPELL_MISSED" then
        self:OnEngage(sourceGUID, npcID, now)
    elseif event == "SPELL_CAST_START" and type(spellID) == "number" then
        self:OnCastStart(sourceGUID, npcID, spellID, now)
    elseif event == "SPELL_CAST_SUCCESS" and type(spellID) == "number" then
        local started = state and state.startedBySpell[spellID]
        if started and now - started.start <= 10 and
            (not started.success or now - started.success < 0.25) then
            -- SUCCESS completes the START observation; even a late SUCCESS after an
            -- interrupt must not turn into a second, instant observation.
            if not started.success then
                started.success = now
                state.lastCastSuccess = now
                if state.activeCast == started then state.activeCast = nil end
                if state.lastCast == started and not started.interrupt and not started.failed then
                    local model = self:GetModel(BKA.activeDungeon.challengeMapID, npcID)
                    if model then self:Schedule(state, sourceGUID, model, now) end
                end
            end
        elseif not (started and not started.fromStart and now - started.start < 0.25) then
            self:OnInstantCast(sourceGUID, npcID, spellID, now)
        end
    elseif event == "SPELL_CAST_FAILED" and state and state.activeCast and state.activeCast.spellID == spellID then
        state.activeCast.failed = true
        state.activeCast = nil
        state.ccSinceCast = true
        self:Invalidate(state, "FAILED")
    end
end

function Learning:EnsureTicker()
    if self.ticker then self.ticker:Show(); return end
    local frame = CreateFrame("Frame")
    self.ticker = frame
    frame.elapsed = 0
    frame:SetScript("OnUpdate", function(f, elapsed)
        f.elapsed = f.elapsed + elapsed
        if f.elapsed < 0.08 then return end
        f.elapsed = 0
        Learning:UpdatePredictions(GetTime())
    end)
end

function Learning:UpdatePredictions(now)
    local cfg = settings()
    if not cfg or not cfg.predictions or not BKA.active then
        if BKA.CastPredictionUI then BKA.CastPredictionUI:Clear() end
        if self.ticker then self.ticker:Hide() end
        return
    end
    local pending = false
    for guid, state in pairs(self.runtime) do
        local prediction = state.prediction
        if prediction then
            if now > prediction.expectedTime + prediction.lateWindow then
                local model = self:GetModel(prediction.dungeonID, state.npcID)
                BKA.CastPredictor:RecordOutcome(model, prediction, "MISS")
                state.lastOutcome = "MISS"
                self:Invalidate(state, "MISS")
            else
                pending = true
                local unit = BKA.Targets:GetUnit(guid)
                if unit and string.match(unit, "^nameplate") and UnitGUID(unit) == guid and
                    now >= prediction.expectedTime - (tonumber(cfg.leadTime) or 1) then
                    prediction.unit = unit
                    local shown = BKA.CastPredictionUI:Show(unit, prediction, prediction.ability)
                    if shown and not prediction.wasDisplayed then
                        prediction.wasDisplayed = true
                        local model = self:GetModel(prediction.dungeonID, state.npcID)
                        local metrics = predictionMetrics(model)
                        if metrics then metrics.displayed = (metrics.displayed or 0) + 1 end
                    end
                    if shown and BKA.Alerts then
                        if cfg.showPredictionAlerts ~= false and BKA.db.showAlerts ~= false then
                            if prediction.alertShown and not BKA.Alerts:SyncPrediction(prediction) then
                                prediction.alertShown = nil
                            end
                            if not prediction.alertShown then
                                prediction.alertShown = BKA.Alerts:ShowPrediction(prediction)
                            end
                        else
                            BKA.Alerts:HidePrediction(prediction)
                        end
                    elseif BKA.Alerts then
                        BKA.Alerts:HidePrediction(prediction)
                    end
                elseif prediction.unit then
                    BKA.CastPredictionUI:Hide(prediction.unit, prediction.guid)
                    prediction.unit = nil
                    if BKA.Alerts then BKA.Alerts:HidePrediction(prediction) end
                elseif BKA.Alerts then
                    BKA.Alerts:HidePrediction(prediction)
                end
            end
        end
    end
    if BKA.CastPredictionUI then BKA.CastPredictionUI:Refresh(now) end
    if self.ticker and not pending then self.ticker:Hide() end
end

function Learning:SettingsChanged()
    local cfg = settings()
    if not cfg or not cfg.enabled then
        self:ResetRuntime()
        if self.ticker then self.ticker:Hide() end
    elseif not cfg.predictions then
        for _, state in pairs(self.runtime) do self:Invalidate(state, "DISABLED") end
        if BKA.CastPredictionUI then BKA.CastPredictionUI:Clear() end
        if self.ticker then self.ticker:Hide() end
    else
        self:EnsureTicker()
    end
end

function Learning:OnNameplateAdded(unit)
    local guid = UnitGUID(unit)
    local state = guid and self.runtime[guid]
    if state and state.prediction and self.ticker then self.ticker:Show() end
end

function Learning:OnNameplateRemoved(unit)
    local guid = UnitGUID(unit)
    local state = guid and self.runtime[guid]
    if state and state.prediction then
        state.prediction.unit = nil
        if BKA.Alerts then BKA.Alerts:HidePrediction(state.prediction) end
    end
end

function Learning:GetSummary()
    local out = { dungeonID = BKA.activeDungeon and BKA.activeDungeon.challengeMapID,
        observations = 0, npcs = 0, spells = 0, entries = 0, highConfidence = 0,
        created = 0, displayed = 0, invalidated = 0, hits = 0, misses = 0, accuracy = 0 }
    local db = settings()
    for _, dungeon in pairs(db and db.dungeons or {}) do
        for _, model in pairs(dungeon.npcs or {}) do
            out.npcs = out.npcs + 1
            out.observations = out.observations + (model.total or 0)
            local aggregate = model.predictionMetrics
            if type(aggregate) == "table" then
                out.created = out.created + (aggregate.created or 0)
                out.displayed = out.displayed + (aggregate.displayed or 0)
                out.invalidated = out.invalidated + (aggregate.invalidated or 0)
            else
                out.created = out.created + (model.highConfidence or 0)
            end
            for _, spell in pairs(model.spells or {}) do
                out.spells = out.spells + 1
                out.entries = out.entries + 1
                local metrics = spell.metrics or {}
                out.hits = out.hits + (metrics.hit or 0)
                out.misses = out.misses + (metrics.miss or 0)
            end
            for _, row in pairs(model.transitions or {}) do
                for _ in pairs(row) do out.entries = out.entries + 1 end
            end
            for _, row in pairs(model.second or {}) do
                for _ in pairs(row) do out.entries = out.entries + 1 end
            end
        end
    end
    local count = out.hits + out.misses
    if count > 0 then out.accuracy = out.hits / count end
    out.highConfidence = out.created
    return out
end

function Learning:DumpTarget()
    local guid = UnitGUID("target")
    local npcID = BKA:GetNPCID(guid)
    if not npcID then BKA:Print(BKA:L("LEARN_NO_TARGET")); return end
    local state = self.runtime[guid]
    local dungeonID = BKA.activeDungeon and BKA.activeDungeon.challengeMapID
    local model = dungeonID and self:GetModel(dungeonID, npcID)
    local spells = {}
    for spellID, spell in pairs(model and model.spells or {}) do
        spells[#spells + 1] = tostring(spellID) .. ":" .. tostring(spell.casts or 0)
    end
    table.sort(spells)
    local prediction = state and state.prediction
    BKA:Print(BKA:L("LEARN_DUMP_FMT", npcID, tostring(guid),
        #spells > 0 and table.concat(spells, ", ") or "-",
        tostring(state and state.lastCastSpellID or "-"),
        tostring(prediction and prediction.spellID or "-"),
        prediction and string.format("%.0f%%", prediction.confidence * 100) or "-"))
    if state then
        local recent = {}
        if state.previousCast then recent[#recent + 1] = tostring(state.previousCast.spellID) end
        if state.lastCast then recent[#recent + 1] = tostring(state.lastCast.spellID) end
        local auras = {}
        for _, aura in pairs(state.cc.spells or {}) do auras[#auras + 1] = tostring(aura.spellID) end
        table.sort(auras)
        BKA:Print(BKA:L("LEARN_DUMP_DETAIL_FMT", #recent > 0 and table.concat(recent, " -> ") or "-",
            #auras > 0 and table.concat(auras, ", ") or "-", tostring(state.lastOutcome or "-")))
        if settings().debug then
            local recentAuras = {}
            for _, auraID in ipairs(state.recentAuras or {}) do recentAuras[#recentAuras + 1] = tostring(auraID) end
            BKA:Print(BKA:L("LEARN_DUMP_AURAS_FMT", #recentAuras > 0 and table.concat(recentAuras, ", ") or "-"))
        end
    end
end

local function encode(value)
    if type(value) == "number" then return string.format("%.8g", value) end
    if type(value) == "string" then return string.format("%q", value) end
    if type(value) ~= "table" then return "nil" end
    local keys, parts = {}, {}
    for key in pairs(value) do keys[#keys + 1] = key end
    table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)
    for _, key in ipairs(keys) do
        parts[#parts + 1] = "[" .. encode(key) .. "]=" .. encode(value[key])
    end
    return "{" .. table.concat(parts, ",") .. "}"
end

function Learning:Export()
    local db = settings()
    return "BKA_CAST_LEARNING_V1:" .. encode(db and db.dungeons or {})
end

function Learning:Reset(confirm)
    if not confirm then return false end
    local db = settings()
    if not db then return false end
    db.dungeons = {}
    self:ResetRuntime()
    return true
end

function Learning:ResetPredictionMetrics()
    local db = settings()
    if not db then return false end
    for _, dungeon in pairs(db.dungeons or {}) do
        for _, model in pairs(dungeon.npcs or {}) do
            model.highConfidence = 0
            model.predictionMetrics = { created = 0, displayed = 0, invalidated = 0 }
            for _, spell in pairs(model.spells or {}) do
                if type(spell.metrics) == "table" then
                    spell.metrics = { count = 0, hit = 0, miss = 0, mae = 0 }
                end
            end
        end
    end
    return true
end
