local BKA = BFAKeyAlerts
local Cooldowns = { entries = {}, elapsed = 0 }
BKA.EnemySpellCooldowns = Cooldowns

local SEVERITY = { LOW = 1, MEDIUM = 2, HIGH = 3, CRITICAL = 4, FATAL = 5 }
local GROUP_KEY = "enemySpellCooldowns"
local BUILD_INTERVAL = 1
local TEXT_INTERVAL = 0.15

local function config()
    return BKA.db and BKA.db.enemySpellCooldowns or {}
end

local function learningConfig()
    return BKA.db and BKA.db.castLearning or {}
end

local function enabled()
    local cfg, learn = config(), learningConfig()
    return cfg.enabled == true and BKA.db and BKA.db.enabled ~= false and
        BKA.db.showNameplates ~= false and BKA.active == true and
        learn.enabled ~= false and BKA.activeDungeon ~= nil
end

local function numeric(value, fallback)
    value = tonumber(value)
    return value or fallback
end

local function abilityFor(npcID, spellID)
    local learning = BKA.CastLearning
    if not learning or not learning.ResolveAbility then return nil end
    return learning:ResolveAbility(npcID, spellID)
end

local function severity(ability)
    return SEVERITY[ability and ability.severity] or 0
end

local function qualifies(ability, minimum)
    return ability and ability.nameplate and not ability.personalOnly and severity(ability) >= minimum
end

local function cooldownLabel(candidate, now)
    local remaining = candidate.expectedTime and candidate.expectedTime - now
    if remaining then
        if remaining <= 0 then return "0" end
        local fuzzy = candidate.confidence and (candidate.confidence < 0.9 or (candidate.stddev or 0) > 0.25)
        return string.format("%s%.1f", fuzzy and "~" or "", remaining)
    end
    return ""
end

local function setIcon(row, candidate)
    local icon = row and row.icon
    if not icon then return end
    local texture = candidate.texture or 134400
    if icon.SetTexture then icon:SetTexture(texture) end
    if icon.SetVertexColor then
        local score = tonumber(candidate.confidence)
        if score then icon:SetVertexColor(1, 0.8 + score * 0.2, 0.35 + score * 0.65, 1)
        else icon:SetVertexColor(0.72, 0.72, 0.72, 1) end
    end
end

local function setDebug(candidate, row, enabledDebug, now)
    if not enabledDebug or not candidate.confidence then return end
    local text = row and row.text
    if text and text.SetText then
        text:SetText(string.format("%s %.0f%%", cooldownLabel(candidate, now),
            (tonumber(candidate.confidence) or 0) * 100))
    end
end

local function hidden(entry)
    if entry.host and BKA.CombatIntelligence and BKA.CombatIntelligence.HideRows then
        BKA.CombatIntelligence:HideRows(entry.host, GROUP_KEY)
    end
    entry.host, entry.rows, entry.rowCount = nil, nil, 0
    entry.textAt = nil
end

function Cooldowns:Clear()
    for guid, entry in pairs(self.entries) do
        hidden(entry)
        self.entries[guid] = nil
    end
end

function Cooldowns:RemoveUnit(unit)
    local guid = type(unit) == "string" and (string.find(unit, "^Creature%-") or string.find(unit, "^Vehicle%-")) and unit or
        (unit and UnitGUID and UnitGUID(unit))
    if guid then
        local entry = self.entries[guid]
        if entry then hidden(entry); self.entries[guid] = nil end
    elseif unit then
        for entryGUID, entry in pairs(self.entries) do
            if entry.unit == unit then hidden(entry); self.entries[entryGUID] = nil end
        end
    end
end

local function modelSources(npcID)
    local dungeonID = BKA.activeDungeon and BKA.activeDungeon.challengeMapID
    local localModel = BKA.CastLearning:GetModel(dungeonID, npcID)
    local dungeon = BKA.CastBaseline[dungeonID]
    local baselineModel = dungeon and dungeon.npcs and dungeon.npcs[npcID]
    return localModel, baselineModel
end

local function needsBuild(entry, state, cfg, learn, now)
    local last = state and state.lastCast
    local prediction = state and state.prediction
    local localModel, baselineModel = modelSources(entry.npcID)
    -- GetModel merges local and baseline data. Check only source identities in
    -- the hot loop, and rebuild the merged model/predictions only when an input
    -- changes or the one-second fallback expires.
    return now - (entry.builtAt or -BUILD_INTERVAL) >= BUILD_INTERVAL or
        entry.localModel ~= localModel or entry.baselineModel ~= baselineModel or
        entry.lastCast ~= last or entry.lastSpellID ~= (last and last.spellID) or
        entry.lastStart ~= (last and last.start) or entry.lastSuccess ~= (last and last.success) or
        entry.lastInterrupt ~= (last and last.interrupt) or entry.previousCast ~= (state and state.previousCast) or
        entry.casts ~= (state and state.casts) or entry.ccSinceCast ~= (state and state.ccSinceCast) or
        entry.ccActive ~= (state and state.cc and state.cc.active) or
        entry.prediction ~= prediction or entry.predictionSpellID ~= (prediction and prediction.spellID) or
        entry.predictionExpected ~= (prediction and prediction.expectedTime) or
        entry.minSeverity ~= cfg.minSeverity or entry.predictedOnly ~= cfg.predictedOnly or
        entry.minimumSamples ~= learn.minimumSamples or entry.minimumConfidence ~= learn.minimumConfidence
end

local function storeSnapshot(entry, state, cfg, learn)
    local last = state and state.lastCast
    local prediction = state and state.prediction
    entry.localModel, entry.baselineModel = modelSources(entry.npcID)
    entry.lastCast, entry.lastSpellID, entry.lastStart = last, last and last.spellID, last and last.start
    entry.lastSuccess, entry.lastInterrupt = last and last.success, last and last.interrupt
    entry.previousCast = state and state.previousCast
    entry.casts, entry.ccSinceCast = state and state.casts, state and state.ccSinceCast
    entry.ccActive = state and state.cc and state.cc.active
    entry.prediction, entry.predictionSpellID = prediction, prediction and prediction.spellID
    entry.predictionExpected = prediction and prediction.expectedTime
    entry.minSeverity, entry.predictedOnly = cfg.minSeverity, cfg.predictedOnly
    entry.minimumSamples, entry.minimumConfidence = learn.minimumSamples, learn.minimumConfidence
end

local function addCandidate(out, candidate, minimum)
    if not candidate then return end
    local ability, action = abilityFor(candidate.npcID, candidate.spellID)
    if not qualifies(ability, minimum) then return end
    candidate.ability = ability
    candidate.action = action
    candidate.texture = ability.icon or (BKA.ResolveIcon and BKA:ResolveIcon(ability, {
        spellID = candidate.spellID, action = action,
    })) or (GetSpellTexture and GetSpellTexture(candidate.spellID))
    -- Candidate records are reused by the per-GUID cache and retain the resolved
    -- ability/action so the 0.15-second countdown update does no resolution work.
    out[#out + 1] = candidate
end

local function staticCandidates(entry, minimum)
    local out, seen = {}, {}
    for _, ability in ipairs(BKA.activeAbilities or {}) do
        if ability.id and not seen[ability.id] then
            local matches = false
            for _, source in ipairs(ability.sources or {}) do
                if source == entry.npcID then matches = true; break end
            end
            if matches then
                local resolved, action = abilityFor(entry.npcID, ability.id)
                if qualifies(resolved, minimum) then
                    seen[ability.id] = true
                    out[#out + 1] = { spellID = ability.id, npcID = entry.npcID,
                        ability = resolved, action = action, confidence = nil }
                end
            end
        end
    end
    return out
end

local function collect(entry, now, cfg, learn)
    local state = entry.state
    if not needsBuild(entry, state, cfg, learn, now) then return end
    local model = BKA.CastPredictor:GetModel(BKA.activeDungeon.challengeMapID, entry.npcID)
    entry.model, entry.builtAt = model, now
    storeSnapshot(entry, state, cfg, learn)
    local candidates = entry.candidates
    for i = #candidates, 1, -1 do candidates[i] = nil end

    if state and not state.cc.active and not state.ccSinceCast and model then
        local predictions = BKA.CastPredictor:CollectPredictions(model, state, now, learn, entry.predictions)
        for _, prediction in ipairs(predictions) do
            if prediction.expectedTime + prediction.lateWindow > now then
                prediction.npcID = entry.npcID
                local candidateStart = #candidates
                addCandidate(candidates, prediction, numeric(cfg.minSeverity, 3))
                if #candidates > candidateStart then
                    local duplicate
                    for i = 1, #candidates - 1 do
                        if candidates[i].spellID == prediction.spellID then duplicate = i; break end
                    end
                    if duplicate then
                        local existing = candidates[duplicate]
                        local selected = state.prediction
                        local existingMatches = selected and selected.spellID == existing.spellID and
                            math.abs((selected.expectedTime or 0) - existing.expectedTime) <= 0.5
                        local candidateMatches = selected and selected.spellID == prediction.spellID and
                            math.abs((selected.expectedTime or 0) - prediction.expectedTime) <= 0.5
                        if (candidateMatches and not existingMatches) or
                            (candidateMatches == existingMatches and
                                ((prediction._priority or 99) < (existing._priority or 99) or
                                 ((prediction._priority or 99) == (existing._priority or 99) and
                                  prediction.expectedTime < existing.expectedTime))) then
                            candidates[duplicate] = prediction
                        end
                        candidates[#candidates] = nil
                    end
                end
            end
        end
    end

    if cfg.predictedOnly == false then
        local known = staticCandidates(entry, numeric(cfg.minSeverity, 3))
        for _, candidate in ipairs(known) do
            local duplicate
            for _, existing in ipairs(candidates) do
                if existing.spellID == candidate.spellID then duplicate = true; break end
            end
            if not duplicate then candidates[#candidates + 1] = candidate end
        end
    end
    table.sort(candidates, function(a, b)
        if a.expectedTime and b.expectedTime and a.expectedTime ~= b.expectedTime then
            return a.expectedTime < b.expectedTime
        end
        if (a.expectedTime ~= nil) ~= (b.expectedTime ~= nil) then return a.expectedTime ~= nil end
        local aSeverity, bSeverity = severity(a.ability), severity(b.ability)
        if aSeverity ~= bSeverity then return aSeverity > bSeverity end
        return a.spellID < b.spellID
    end)
end

local function ghostDisplayed(state, candidate)
    local prediction = state and state.prediction
    if not prediction or not prediction.wasDisplayed or prediction.spellID ~= candidate.spellID or
        math.abs((prediction.expectedTime or 0) - (candidate.expectedTime or -1)) > 0.5 then return false end
    local overlay = prediction.unit and BKA.Nameplates and BKA.Nameplates.overlays and
        BKA.Nameplates.overlays[prediction.unit]
    return overlay and overlay.ownerGUID == prediction.guid and overlay.predictionState and
        overlay.predictionState.predictionData == prediction
end

local function shouldShowCandidate(entry, candidate, now, lead)
    if not candidate.expectedTime then return true end
    local remaining = candidate.expectedTime - now
    if remaining <= 0 or candidate.expectedTime + candidate.lateWindow <= now then return false end
    if remaining <= lead and ghostDisplayed(entry.state, candidate) then return false end
    return true
end

local function render(entry, now, cfg)
    local unit = entry.unit
    if not unit or UnitGUID(unit) ~= entry.guid then hidden(entry); return end
    local intelligence = BKA.CombatIntelligence
    if not intelligence or not intelligence.GetHost then hidden(entry); return end
    local host = intelligence:GetHost(unit)
    if not host or host.ownerGUID ~= entry.guid or not intelligence.GetRows then hidden(entry); return end

    local maxRows = math.max(1, math.min(3, math.floor(numeric(cfg.maxAbilities, 2))))
    local lead = numeric(learningConfig().leadTime, 1)
    local shown = 0
    for _, candidate in ipairs(entry.candidates) do
        if shown >= maxRows then break end
        if shouldShowCandidate(entry, candidate, now, lead) then shown = shown + 1 end
    end
    if shown == 0 then
        hidden(entry)
        return
    end
    local rows = intelligence:GetRows(host, GROUP_KEY, shown, 16)
    if type(rows) ~= "table" then hidden(entry); return end
    entry.host, entry.rows, entry.rowCount = host, rows, shown
    local updateText = not entry.textAt or now - entry.textAt >= TEXT_INTERVAL
    local index = 0
    for _, candidate in ipairs(entry.candidates) do
        if index >= shown then break end
        if shouldShowCandidate(entry, candidate, now, lead) then
            index = index + 1
            local row = rows[index]
            if row then
                if row.text and row.text.SetWidth then row.text:SetWidth(56) end
                if row.text and row.text.SetWordWrap then row.text:SetWordWrap(false) end
                if row._enemyCooldownCandidate ~= candidate or row._enemyCooldownHost ~= host or
                    row._enemyCooldownRow ~= row or
                    row._enemyCooldownIndex ~= index then
                    if row.ClearAllPoints then row:ClearAllPoints() end
                    if row.SetPoint then row:SetPoint("BOTTOMLEFT", host, "BOTTOMLEFT", (index - 1) * 78, 4) end
                    row._enemyCooldownCandidate, row._enemyCooldownHost = candidate, host
                    row._enemyCooldownRow, row._enemyCooldownIndex = row, index
                    setIcon(row, candidate)
                    if row.EnableMouse then row:EnableMouse(false) end
                    if row.SetScript then row:SetScript("OnMouseDown", nil); row:SetScript("OnClick", nil) end
                    if row.text and row.text.SetTextColor then
                        local action = candidate.action
                        if action == "KICK" or action == "STOP" then row.text:SetTextColor(1, 0.45, 0.3)
                        else row.text:SetTextColor(1, 0.83, 0.4) end
                    end
                end
                if updateText then
                    if row.text and row.text.SetText then row.text:SetText(cooldownLabel(candidate, now)) end
                    setDebug(candidate, row, cfg.debug == true, now)
                end
                if row.border and row.border.SetBackdropColor then
                    local action = candidate.action
                    if action == "KICK" or action == "STOP" then row.border:SetBackdropColor(0.9, 0.25, 0.18, 0.9)
                    else row.border:SetBackdropColor(0.95, 0.68, 0.2, 0.9) end
                end
                if row.Show then row:Show() end
            end
        end
    end
    if updateText then entry.textAt = now end
    if intelligence.LayoutHost then intelligence:LayoutHost(host) end
end

function Cooldowns:Refresh(now)
    now = tonumber(now) or GetTime()
    local cfg, learn = config(), learningConfig()
    if not enabled() then self:Clear(); return end
    for guid, state in pairs(BKA.CastLearning.runtime or {}) do
        local unit = BKA.Targets and BKA.Targets:GetUnit(guid)
        if unit and string.match(unit, "^nameplate%d+$") and UnitGUID(unit) == guid and
            (not UnitIsDeadOrGhost or not UnitIsDeadOrGhost(unit)) and
            (cfg.predictedOnly == false or not UnitAffectingCombat or UnitAffectingCombat(unit)) then
            local npcID = state.npcID or BKA:GetNPCID(guid)
            if npcID and BKA.CastLearning.allowed and BKA.CastLearning.allowed[npcID] then
                local entry = self.entries[guid]
                if not entry or entry.unit ~= unit or entry.npcID ~= npcID then
                    if entry then hidden(entry) end
                    entry = { guid = guid, unit = unit, npcID = npcID, state = state,
                        candidates = {}, predictions = {} }
                    self.entries[guid] = entry
                end
                entry.state = state
                collect(entry, now, cfg, learn)
                render(entry, now, cfg)
            end
        end
    end
    for guid, entry in pairs(self.entries) do
        if not BKA.CastLearning.runtime[guid] or UnitGUID(entry.unit) ~= guid or
            (UnitIsDeadOrGhost and UnitIsDeadOrGhost(entry.unit)) or
            (cfg.predictedOnly ~= false and UnitAffectingCombat and not UnitAffectingCombat(entry.unit)) then
            hidden(entry)
            self.entries[guid] = nil
        end
    end
end
