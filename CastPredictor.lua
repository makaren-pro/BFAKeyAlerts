local BKA = BFAKeyAlerts
local Predictor = {}
BKA.CastPredictor = Predictor
BKA.CastBaseline = BKA.CastBaseline or {}

local abs, max, min, sqrt = math.abs, math.max, math.min, math.sqrt

local function deviation(stat)
    if not stat or (stat.n or 0) < 2 then return 0 end
    return sqrt(max(0, (stat.m2 or 0) / (stat.n - 1)))
end

function Predictor:Add(stat, value)
    if not value or value <= 0 or value > 90 then return false end
    if stat.n and stat.n >= 8 then
        local limit = max(3, deviation(stat) * 4, stat.mean * 0.55)
        if abs(value - stat.mean) > limit then
            stat.rejected = (stat.rejected or 0) + 1
            return false
        end
    end
    local n = (stat.n or 0) + 1
    local delta = value - (stat.mean or 0)
    stat.mean = (stat.mean or 0) + delta / n
    stat.m2 = (stat.m2 or 0) + delta * (value - stat.mean)
    stat.n = n
    stat.min = min(stat.min or value, value)
    stat.max = max(stat.max or value, value)
    return true
end

local function newStat() return { n = 0, mean = 0, m2 = 0 } end

function Predictor:MergeStats(a, b)
    if not a then return b end
    if not b then return a end
    local an, bn = a.n or 0, b.n or 0
    local n = an + bn
    if n == 0 then return newStat() end
    local delta = (b.mean or 0) - (a.mean or 0)
    return { n = n, mean = (a.mean or 0) + delta * bn / n,
        m2 = (a.m2 or 0) + (b.m2 or 0) + delta * delta * an * bn / n,
        min = a.min and b.min and min(a.min, b.min) or a.min or b.min,
        max = a.max and b.max and max(a.max, b.max) or a.max or b.max,
        rejected = (a.rejected or 0) + (b.rejected or 0) }
end

local function mergeErrors(a, b)
    if not a then return b end
    if not b then return a end
    local an, bn = a.n or 0, b.n or 0
    local n = an + bn
    return { n = n, mae = n > 0 and ((a.mae or 0) * an + (b.mae or 0) * bn) / n or 0 }
end

local function mergeMetrics(a, b)
    if not a then return b end
    if not b then return a end
    local an, bn = a.count or 0, b.count or 0
    local n = an + bn
    return { count = n, hit = (a.hit or 0) + (b.hit or 0), miss = (a.miss or 0) + (b.miss or 0),
        mae = n > 0 and ((a.mae or 0) * an + (b.mae or 0) * bn) / n or 0,
        recentHit = b.recentHit or a.recentHit, recentMiss = b.recentMiss or a.recentMiss,
        INVALIDATED_BY_CC = (a.INVALIDATED_BY_CC or 0) + (b.INVALIDATED_BY_CC or 0),
        MOB_DIED = (a.MOB_DIED or 0) + (b.MOB_DIED or 0) }
end

local function mergeSpell(a, b)
    if not a then return b end
    if not b then return a end
    local spell = { casts = (a.casts or 0) + (b.casts or 0),
        ccExcluded = (a.ccExcluded or 0) + (b.ccExcluded or 0),
        opening = Predictor:MergeStats(a.opening, b.opening),
        intervals = Predictor:MergeStats(a.intervals, b.intervals),
        anchors = {}, anchorErrors = {}, rotations = {},
        metrics = mergeMetrics(a.metrics, b.metrics) }
    for key, stat in pairs(a.anchors or {}) do spell.anchors[key] = Predictor:MergeStats(stat, b.anchors and b.anchors[key]) end
    for key, stat in pairs(b.anchors or {}) do
        if not spell.anchors[key] then spell.anchors[key] = stat end
    end
    for key, errors in pairs(a.anchorErrors or {}) do spell.anchorErrors[key] = mergeErrors(errors, b.anchorErrors and b.anchorErrors[key]) end
    for key, errors in pairs(b.anchorErrors or {}) do
        if not spell.anchorErrors[key] then spell.anchorErrors[key] = errors end
    end
    for length, rotation in pairs(a.rotations or {}) do spell.rotations[length] = rotation end
    for length, rotation in pairs(b.rotations or {}) do
        -- A sufficiently observed Firestorm cycle wins; conflicting cycles are never averaged.
        if not spell.rotations[length] or (rotation.n or 0) >= 5 then spell.rotations[length] = rotation end
    end
    return spell
end

local function mergeEdges(a, b)
    local result = {}
    for from, row in pairs(a or {}) do
        local mergedRow = {}
        result[from] = mergedRow
        for to, edge in pairs(row) do
            local localEdge = b and b[from] and b[from][to]
            mergedRow[to] = localEdge and {
                n = (edge.n or 0) + (localEdge.n or 0),
                timing = Predictor:MergeStats(edge.timing, localEdge.timing),
            } or edge
        end
    end
    for from, row in pairs(b or {}) do
        if not result[from] then result[from] = {} end
        for to, edge in pairs(row) do
            if not result[from][to] then result[from][to] = edge end
        end
    end
    return result
end

function Predictor:GetModel(dungeonID, npcID)
    local localModel = BKA.CastLearning and BKA.CastLearning:GetModel(dungeonID, npcID)
    local dungeon = BKA.CastBaseline[dungeonID]
    local baseline = dungeon and dungeon.npcs and dungeon.npcs[npcID]
    if not baseline or not localModel then return baseline or localModel end
    local model = { spells = {}, total = (baseline.total or 0) + (localModel.total or 0),
        transitions = mergeEdges(baseline.transitions, localModel.transitions),
        second = mergeEdges(baseline.second, localModel.second) }
    for spellID, spell in pairs(baseline.spells or {}) do
        model.spells[spellID] = mergeSpell(spell, localModel.spells and localModel.spells[spellID])
    end
    for spellID, spell in pairs(localModel.spells or {}) do
        if not model.spells[spellID] then model.spells[spellID] = spell end
    end
    return model
end

local function addAnchor(spell, key, delay)
    local stat = spell.anchors[key]
    local errors = spell.anchorErrors[key]
    if not errors then errors = { n = 0, mae = 0 }; spell.anchorErrors[key] = errors end
    local previousN, previousMean = stat.n, stat.mean
    if Predictor:Add(stat, delay) and previousN >= 3 then
        local error = abs(delay - previousMean)
        errors.n = errors.n + 1
        errors.mae = errors.mae + (error - errors.mae) / errors.n
    end
end

local function addTransition(map, from, to, delay, cap)
    if not from or not to or not delay or delay <= 0 or delay > 90 then return end
    local row = map[from]
    if not row then row = {}; map[from] = row end
    local edge = row[to]
    if not edge then
        local size = 0
        for _ in pairs(row) do size = size + 1 end
        if size >= cap then return end
        edge = { n = 0, timing = newStat() }
        row[to] = edge
    end
    edge.n = edge.n + 1
    Predictor:Add(edge.timing, delay)
end

local function gapCode(value)
    return math.floor(value * 2 + 0.5)
end

local function cycleStart(reference, observed, length)
    if not reference then return nil end
    for start = 1, length do
        local matches = true
        for i = 1, length do
            if reference[(start + i - 2) % length + 1] ~= observed[i] then
                matches = false
                break
            end
        end
        if matches then return start end
    end
end

local function observeRotation(spell, recent)
    -- A bounded, quantized two-cycle witness prevents a multi-modal cooldown
    -- from being collapsed into one misleading average.
    if #recent < 4 then return end
    spell.rotations = spell.rotations or {}
    for length = 2, 4 do
        if #recent >= length * 2 then
            local same, parts, codes = true, {}, {}
            local low, high = 100, 0
            for i = 1, length do
                local a = recent[#recent - length * 2 + i]
                local b = recent[#recent - length + i]
                if abs(a - b) > max(0.6, a * 0.15) then same = false; break end
                codes[i] = gapCode(b)
                parts[i] = tostring(codes[i])
                low, high = min(low, b), max(high, b)
            end
            if same and high - low >= 0.8 then
                local key = table.concat(parts, ",")
                local candidate = spell.rotations[length]
                local start = candidate and cycleStart(candidate.codes, codes, length)
                if not candidate or start then
                    if not candidate then
                        candidate = { key = key, codes = codes, n = 0, intervals = {} }
                        spell.rotations[length] = candidate
                        start = 1
                    end
                    candidate.n = candidate.n + 1
                    for i = 1, length do
                        local index = (start + i - 2) % length + 1
                        local stat = candidate.intervals[index] or newStat()
                        candidate.intervals[index] = stat
                        Predictor:Add(stat, recent[#recent - length + i])
                    end
                end
            end
        end
    end
end

function Predictor:EnsureSpell(model, spellID)
    local spell = model.spells[spellID]
    if not spell then
        local count = 0
        for _ in pairs(model.spells) do count = count + 1 end
        if count >= 20 then return nil end
        spell = { casts = 0, opening = newStat(), intervals = newStat(), anchors = {
            START = newStat(), SUCCESS = newStat(), INTERRUPT = newStat(),
        }, anchorErrors = {}, metrics = { count = 0, hit = 0, miss = 0, mae = 0 } }
        model.spells[spellID] = spell
    end
    return spell
end

function Predictor:Observe(model, state, spellID, now)
    local spell = self:EnsureSpell(model, spellID)
    if not spell then return false end
    spell.casts = (spell.casts or 0) + 1
    if state.ccSinceCast then spell.ccExcluded = (spell.ccExcluded or 0) + 1 end
    model.total = (model.total or 0) + 1
    if not state.lastCast and state.combatStartReliable and state.combatStart then
        self:Add(spell.opening, now - state.combatStart)
    end
    local previous = state.lastBySpell[spellID]
    if previous and not previous.failed and not state.ccSinceCast then
        local interval = now - previous.start
        if self:Add(spell.intervals, interval) then
            local recent = state.recentIntervals[spellID] or {}
            state.recentIntervals[spellID] = recent
            recent[#recent + 1] = interval
            if #recent > 12 then table.remove(recent, 1) end
            observeRotation(spell, recent)
        end
        addAnchor(spell, "START", interval)
        if previous.success then addAnchor(spell, "SUCCESS", now - previous.success) end
        if previous.interrupt then addAnchor(spell, "INTERRUPT", now - previous.interrupt) end
    end
    if state.lastCast and not state.ccSinceCast then
        addTransition(model.transitions, state.lastCast.spellID, spellID, now - state.lastCast.start, 12)
        if state.previousCast then
            local key = tostring(state.previousCast.spellID) .. ":" .. tostring(state.lastCast.spellID)
            local contexts = 0
            for _ in pairs(model.second) do contexts = contexts + 1 end
            if model.second[key] or contexts < 40 then
                addTransition(model.second, key, spellID, now - state.lastCast.start, 8)
            end
        end
    end
    return true
end

function Predictor:PreferredAnchor(spell, minimum)
    local anchors = spell and spell.anchors or {}
    local start = anchors.START or spell and spell.intervals
    if not start or (start.n or 0) < minimum then return "START", 0 end
    local errors = spell.anchorErrors or {}
    local startError = errors.START
    local chosen = "START"
    local best = startError and startError.n >= 5 and startError.mae or deviation(start)
    local certainty = 1
    for _, key in ipairs({"SUCCESS", "INTERRUPT"}) do
        local stat = anchors[key]
        if stat and stat.n >= max(8, minimum) and stat.n >= start.n * 0.35 then
            local error = errors[key]
            local score = error and error.n >= 5 and error.mae or deviation(stat)
            if score < best * 0.78 then
                chosen, best = key, score
                certainty = min(1, stat.n / max(12, start.n * 0.5))
            end
        end
    end
    return chosen, certainty
end

local function winningEdge(row, minimum)
    if not row then return nil end
    local total, best, runner = 0, nil, 0
    for id, edge in pairs(row) do
        total = total + (edge.n or 0)
        if not best or edge.n > best.edge.n then
            runner = best and best.edge.n or 0
            best = { id = id, edge = edge }
        elseif edge.n > runner then runner = edge.n end
    end
    if not best or best.edge.n < minimum or total < minimum then return nil end
    local probability = best.edge.n / total
    if probability < 0.82 or (best.edge.n - runner) / total < 0.25 then return nil end
    return best.id, best.edge.timing, probability, best.edge.n
end

local function rotationPrediction(spell, state, spellID, minimum)
    local recent = state.recentIntervals[spellID]
    if not recent then return nil end
    for length = 2, 4 do
        local candidate = spell.rotations and spell.rotations[length]
        if candidate and candidate.n >= minimum and #recent >= length then
            local codes = {}
            for i = 1, length do
                codes[i] = gapCode(recent[#recent - length + i])
            end
            local start = cycleStart(candidate.codes, codes, length)
            if start then return candidate.intervals[start], candidate.n end
        end
    end
end

local function confidence(stat, samples, probability, minimum, metrics, anchorCertainty, spell)
    if not stat or (stat.n or 0) < minimum or samples < minimum then return 0 end
    local cv = deviation(stat) / max(stat.mean, 0.2)
    if cv > 0.18 then return 0 end
    local count = 0.82 + 0.18 * min(1, max(0, samples - minimum) / (minimum * 2))
    local stability = max(0, 1 - cv * 1.5)
    local accuracy = 1
    if metrics and (metrics.count or 0) > 0 then
        accuracy = ((metrics.recentHit or metrics.hit or 0) + 10) /
            ((metrics.recentHit or metrics.hit or 0) + (metrics.recentMiss or metrics.miss or 0) + 10)
    end
    local ccFactor = 1
    if spell and (spell.casts or 0) > 0 then
        ccFactor = 1 - min(0.2, ((spell.ccExcluded or 0) / spell.casts) * 0.25)
    end
    return min(1, count * probability * stability * accuracy * (anchorCertainty or 1) * ccFactor)
end

function Predictor:Predict(model, state, now, settings)
    if not model or state.cc.active or state.ccSinceCast then return nil end
    local minimum = max(3, tonumber(settings.minimumSamples) or 5)
    local threshold = tonumber(settings.minimumConfidence) or 0.85
    local function makePrediction(id, stat, probability, samples, source, anchorTime, anchor, certainty)
        if not id or not stat or not anchorTime then return nil end
        local spell = model.spells[id]
        local score = confidence(stat, samples, probability or 1, minimum, spell and spell.metrics, certainty, spell)
        if score < threshold then return nil end
        local window = max(0.25, deviation(stat) * 2, stat.mean * 0.05)
        local late = max(0.45, deviation(stat) * 2.5, stat.mean * 0.12)
        local expected = anchorTime + stat.mean
        if expected + late <= now then return nil end
        return { spellID = id, expectedTime = expected, earlyWindow = window,
            lateWindow = late, confidence = score, source = source, samples = samples,
            stddev = deviation(stat), anchor = anchor or "START", probability = probability or 1 }
    end
    local last = state.lastCast
    if last and state.previousCast then
        local key = tostring(state.previousCast.spellID) .. ":" .. tostring(last.spellID)
        local id, stat, probability, samples = winningEdge(model.second[key], minimum)
        local result = makePrediction(id, stat, probability, samples, "second-order", last.start)
        if result then return result end
    end
    if last then
        local id, stat, probability, samples = winningEdge(model.transitions[last.spellID], minimum)
        local result = makePrediction(id, stat, probability, samples, "transition", last.start)
        if result then return result end
    end
    if last then
        local best, ambiguous
        for spellID, spell in pairs(model.spells) do
            local previous = state.lastBySpell[spellID]
            if previous then
                local rotationStat, rotationSamples = rotationPrediction(spell, state, spellID, minimum)
                local chosen, certainty = self:PreferredAnchor(spell, minimum)
                if rotationStat then chosen, certainty = "START", math.min(1, rotationSamples / (minimum * 2)) end
                local candidate = rotationStat or (spell.anchors and spell.anchors[chosen]) or spell.intervals
                local base = chosen == "START" and previous.start or previous[string.lower(chosen)]
                local result = candidate and makePrediction(spellID, candidate, 1, rotationSamples or candidate.n,
                    rotationStat and "rotation" or "same-spell", base, chosen, certainty)
                if result then
                    if not best or result.expectedTime < best.expectedTime then
                        if best and math.abs(result.expectedTime - best.expectedTime) <=
                            math.max(result.earlyWindow, best.earlyWindow) + 0.3 then ambiguous = true end
                        best = result
                    elseif math.abs(result.expectedTime - best.expectedTime) <=
                        math.max(result.earlyWindow, best.earlyWindow) + 0.3 then
                        ambiguous = true
                    end
                end
            end
        end
        if best and not ambiguous then return best end
    end
    if not last and state.combatStartReliable then
        local total, best, runner = 0, nil, 0
        for spellID, spell in pairs(model.spells) do
            local n = spell.opening and spell.opening.n or 0
            total = total + n
            if n >= minimum and (not best or n > best.n) then
                runner = best and best.n or 0
                best = { id = spellID, n = n, stat = spell.opening }
            elseif n > runner then runner = n end
        end
        if best and total >= minimum and best.n / total >= 0.82 and (best.n - runner) / total >= 0.25 then
            return makePrediction(best.id, best.stat, best.n / total, best.n, "opening", state.combatStart)
        end
    end
end

function Predictor:RecordOutcome(model, prediction, outcome, actualTime)
    local spell = model and self:EnsureSpell(model, prediction.spellID)
    if not spell then return end
    local metrics = spell.metrics or { count = 0, hit = 0, miss = 0, mae = 0 }
    spell.metrics = metrics
    if outcome == "INVALIDATED_BY_CC" or outcome == "MOB_DIED" then
        metrics[outcome] = (metrics[outcome] or 0) + 1
        return
    end
    if outcome == "HIT" or outcome == "MISS" then
        metrics.count = (metrics.count or 0) + 1
        metrics[outcome == "HIT" and "hit" or "miss"] = (metrics[outcome == "HIT" and "hit" or "miss"] or 0) + 1
        metrics.recentHit = (metrics.recentHit or 0) * 0.9 + (outcome == "HIT" and 1 or 0)
        metrics.recentMiss = (metrics.recentMiss or 0) * 0.9 + (outcome == "MISS" and 1 or 0)
        if actualTime then
            local error = abs(actualTime - prediction.expectedTime)
            metrics.mae = (metrics.mae or 0) + (error - (metrics.mae or 0)) / metrics.count
        end
    end
end

function Predictor:Inspect(dungeonID, npcID, spellID)
    local model = self:GetModel(dungeonID, npcID)
    local spell = model and model.spells[spellID]
    if not spell then return nil end
    local anchor, certainty = self:PreferredAnchor(spell, 5)
    local transitions, secondTransitions, total = {}, {}, 0
    for _, edge in pairs(model.transitions[spellID] or {}) do total = total + (edge.n or 0) end
    for nextID, edge in pairs(model.transitions[spellID] or {}) do
        transitions[#transitions + 1] = { spellID = nextID, count = edge.n,
            probability = total > 0 and edge.n / total or 0,
            meanDelay = edge.timing and edge.timing.mean, stddev = deviation(edge.timing) }
    end
    table.sort(transitions, function(a, b) return a.count > b.count end)
    for key, row in pairs(model.second or {}) do
        local previous, current = string.match(key, "^(%d+):(%d+)$")
        if tonumber(current) == spellID then
            local rowTotal = 0
            for _, edge in pairs(row) do rowTotal = rowTotal + (edge.n or 0) end
            for nextID, edge in pairs(row) do
                secondTransitions[#secondTransitions + 1] = { previousSpellID = tonumber(previous), spellID = nextID,
                    count = edge.n, probability = rowTotal > 0 and edge.n / rowTotal or 0 }
            end
        end
    end
    table.sort(secondTransitions, function(a, b) return a.count > b.count end)
    local intervals = spell.intervals or newStat()
    return { spellID = spellID, casts = spell.casts, opening = spell.opening,
        interval = intervals, stddev = deviation(intervals), anchor = anchor,
        anchorCertainty = certainty, anchorErrors = spell.anchorErrors, metrics = spell.metrics,
        predictionConfidence = confidence(intervals, intervals.n or 0, 1, 5, spell.metrics, certainty, spell),
        transitions = transitions, secondTransitions = secondTransitions, rotations = spell.rotations }
end
