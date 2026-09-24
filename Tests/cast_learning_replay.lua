-- Synthetic CLEU replay. Run from the addon directory with a Lua interpreter.
local now = 0
local hidden = 0
local shown = 0
local centralShown, centralHidden, centralSynced = 0, 0, 0
GetTime = function() return now end
wipe = function(value) for key in pairs(value) do value[key] = nil end end
bit = { band = function(value, mask) return value % (mask * 2) >= mask and mask or 0 end }
COMBATLOG_OBJECT_REACTION_HOSTILE = 0x40
CreateFrame = function()
    return {
        Show = function() end, Hide = function() end,
        SetScript = function(self, _, fn) self.script = fn end,
    }
end

BFAKeyAlerts = {
    db = { castLearning = { version = 1, enabled = true, predictions = false, dungeons = {} } },
    activeDungeon = { challengeMapID = 1 },
    CastBaseline = {},
    GroupInterrupts = { IsHardCCAura = function(_, id) return id == 118905 or id == 132168 end },
    CastPredictionUI = { Hide = function() hidden = hidden + 1 end, Clear = function() end,
        Refresh = function() end, Show = function() shown = shown + 1; return true end },
    Alerts = {
        ShowPrediction = function(_, prediction)
            centralShown = centralShown + 1
            prediction.alertRow = { prediction = prediction }
            prediction.alertKey = "prediction:" .. prediction.guid
            return true
        end,
        SyncPrediction = function(_, prediction)
            centralSynced = centralSynced + 1
            return prediction.alertRow and prediction.alertRow.prediction == prediction
        end,
        HidePrediction = function(_, prediction)
            if prediction and prediction.alertKey then centralHidden = centralHidden + 1 end
            if prediction then prediction.alertKey, prediction.alertRow, prediction.alertShown = nil, nil, nil end
        end,
    },
    GetNPCID = function() return 7 end,
    GetInterruptPolicy = function() return nil end,
    GetAbilityForUnitSpell = function(_, spellID) return { id = spellID, nameplate = true, severity = "MEDIUM" } end,
    NormalizeAction = function(_, action) return action or "KICK" end,
    IsGeometryAction = function() return false end,
}
dofile("CastPredictor.lua")
dofile("CastLearning.lua")

local bka = BFAKeyAlerts
local learning, predictor = bka.CastLearning, bka.CastPredictor
local guid = "Creature-0-0-0-0-7-1"
learning.allowed = { [7] = true }

local function event(time, name, spellID, sourceGUID, destGUID)
    now = time
    learning:OnCombatLog(name, sourceGUID or guid, 0x40, destGUID, 0, spellID)
end

local function reset()
    bka.db.castLearning.dungeons = {}
    learning:ResetRuntime()
    bka.CastBaseline = {}
    bka.active = false
    bka.Targets = nil
    hidden, shown, centralShown, centralHidden, centralSynced = 0, 0, 0, 0, 0
    now = 0
end

local function model()
    return learning:GetModel(1, 7)
end

local function equal(actual, expected, label)
    assert(actual == expected, label .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual))
end

local function near(actual, expected, label)
    assert(math.abs(actual - expected) < 0.00001, label .. ": expected " .. expected .. ", got " .. tostring(actual))
end

-- A: CC-crossing interval is excluded, then the next clean interval is learned.
event(1, "SPELL_CAST_START", 101)
event(9, "SPELL_CAST_START", 101)
event(17, "SPELL_CAST_START", 101)
equal(model().spells[101].intervals.n, 2, "clean intervals")
event(18, "SPELL_AURA_APPLIED", 118905, "Player-1", guid)
event(23, "SPELL_AURA_REMOVED", 118905, "Player-1", guid)
event(30, "SPELL_CAST_START", 101)
equal(model().spells[101].intervals.n, 2, "CC interval excluded")
event(38, "SPELL_CAST_START", 101)
equal(model().spells[101].intervals.n, 3, "post-CC interval")
near(model().spells[101].intervals.mean, 8, "clean mean")

-- B: overlapping auras remain active until the last aura is removed.
reset()
event(1, "SPELL_AURA_APPLIED", 118905, "Player-1", guid)
event(2, "SPELL_AURA_APPLIED", 132168, "Player-2", guid)
event(3, "SPELL_AURA_REMOVED", 118905, "Player-1", guid)
equal(learning.runtime[guid].cc.active, true, "overlap retained")
event(4, "SPELL_AURA_REMOVED", 132168, "Player-2", guid)
equal(learning.runtime[guid].cc.active, false, "overlap cleared")
event(5, "SPELL_AURA_APPLIED", 118905, "Player-1", guid)
event(6, "SPELL_AURA_APPLIED", 118905, "Player-2", guid)
event(7, "SPELL_AURA_REMOVED", 118905, "Player-1", guid)
equal(learning.runtime[guid].cc.active, true, "same-ID overlap retained")
event(8, "SPELL_AURA_REMOVED", 118905, "Player-2", guid)
equal(learning.runtime[guid].cc.active, false, "same-ID overlap cleared")
bka.db.castLearning.debug = true
event(9, "SPELL_AURA_APPLIED", 999001, "Player-1", guid)
equal(learning.runtime[guid].recentAuras[1], 999001, "unknown aura available for debug dump")
bka.db.castLearning.debug = false

-- C-E: START/SUCCESS is one cast, success-only is a cast, and sequence keeps it.
reset()
event(1, "SPELL_CAST_START", 101)
event(2, "SPELL_CAST_SUCCESS", 101)
equal(model().total, 1, "START/SUCCESS deduplicated")
event(2.1, "SPELL_CAST_SUCCESS", 101)
equal(model().total, 1, "repeated SUCCESS deduplicated")
event(4, "SPELL_CAST_SUCCESS", 103)
equal(model().total, 2, "instant observed")
event(6, "SPELL_CAST_START", 102)
event(7, "SPELL_CAST_SUCCESS", 102)
equal(model().total, 3, "three cast observations")
equal(model().transitions[101][103].n, 1, "A to instant C")
equal(model().transitions[103][102].n, 1, "C to B")
assert(not model().transitions[101][102], "spurious A to B")
equal(model().second["101:103"][102].n, 1, "second-order A,C to B")

-- F-G: first observed cast has no opening; first hostile hit can anchor one.
equal(model().spells[101].opening.n, 0, "unknown engage has no opening")
reset()
event(1, "SPELL_CAST_START", 101)
event(1.5, "SPELL_CAST_SUCCESS", 103)
event(2, "SPELL_CAST_SUCCESS", 101)
equal(model().total, 2, "interleaved instant does not duplicate active cast")
equal(learning.runtime[guid].activeCast, nil, "active cast completed after instant")
reset()
event(1, "SWING_DAMAGE", nil, "Player-1", guid)
event(4.2, "SPELL_CAST_START", 101)
equal(model().spells[101].opening.n, 1, "reliable opening sample")
near(model().spells[101].opening.mean, 3.2, "opening delay")

-- H-I: pooled Welford moments and transition counts leave baseline untouched.
reset()
local baselineStat = { n = 50, mean = 8, m2 = 49 }
bka.CastBaseline[1] = { npcs = { [7] = {
    total = 50, spells = { [101] = { casts = 50, intervals = baselineStat } },
    transitions = { [101] = {
        [102] = { n = 40, timing = { n = 40, mean = 8, m2 = 0 } },
        [103] = { n = 10, timing = { n = 10, mean = 8, m2 = 0 } },
    } }, second = {},
} } }
local localModel = learning:GetOrCreateModel(1, 7)
localModel.total = 10
localModel.spells[101] = { casts = 10, intervals = { n = 10, mean = 10, m2 = 9 } }
localModel.transitions[101] = {
    [102] = { n = 2, timing = { n = 2, mean = 10, m2 = 0 } },
    [103] = { n = 8, timing = { n = 8, mean = 10, m2 = 0 } },
}
local merged = predictor:GetModel(1, 7)
equal(merged.spells[101].intervals.n, 60, "pooled count")
near(merged.spells[101].intervals.mean, 500 / 60, "pooled mean")
equal(baselineStat.n, 50, "baseline count unchanged")
equal(baselineStat.mean, 8, "baseline mean unchanged")
equal(merged.transitions[101][102].n, 42, "merged A-B count")
equal(merged.transitions[101][103].n, 18, "merged A-C count")

-- J-K: CC and death invalidate without counting a miss.
reset()
event(1, "SPELL_CAST_START", 101)
local state = learning.runtime[guid]
local function pending()
    state.prediction = { guid = guid, dungeonID = 1, spellID = 101, unit = "nameplate1" }
end
pending()
event(2, "SPELL_AURA_APPLIED", 118905, "Player-1", guid)
equal(state.prediction, nil, "CC prediction removed")
equal(hidden, 1, "CC ghost hidden")
equal(model().spells[101].metrics.INVALIDATED_BY_CC, 1, "CC invalidation counted")
equal(model().spells[101].metrics.miss, 0, "CC is not MISS")
pending()
event(3, "UNIT_DIED", nil, "Creature-0-0-0-0-8-1", guid)
equal(learning.runtime[guid], nil, "dead mob runtime removed")
equal(hidden, 2, "death ghost hidden")
equal(model().spells[101].metrics.MOB_DIED, 1, "death invalidation counted")
equal(model().spells[101].metrics.miss, 0, "death is not MISS")

-- New profiles show predictions; an explicit SavedVariables choice is retained.
SlashCmdList = {}
dofile("Config.lua")
BFAKeyAlertsDB = {}
bka:InitDB()
equal(bka.db.castLearning.predictions, true, "new profile prediction default")
equal(bka.db.castLearning.showPredictionAlerts, true, "new profile central prediction default")
BFAKeyAlertsDB = { castLearning = { version = 1, predictions = false, dungeons = { [1] = { npcs = {} } } } }
bka:InitDB()
equal(bka.db.castLearning.predictions, false, "saved preference preserved")
equal(bka.db.castLearning.showPredictionAlerts, true, "missing central preference defaults on")
assert(bka.db.castLearning.dungeons[1], "saved learning data preserved")
BFAKeyAlertsDB.castLearning.showPredictionAlerts = false
bka:InitDB()
equal(bka.db.castLearning.showPredictionAlerts, false, "saved central preference preserved")

-- HIT and expiry MISS are recorded once; a runtime reset keeps aggregate samples.
reset()
event(1, "SPELL_CAST_START", 101)
state = learning.runtime[guid]
state.prediction = { guid = guid, dungeonID = 1, spellID = 101, unit = "nameplate1",
    expectedTime = 8, earlyWindow = 0.5, lateWindow = 0.5 }
learning:Feedback(state, 101, 8, model())
equal(model().spells[101].metrics.hit, 1, "HIT recorded")
state.prediction = { guid = guid, dungeonID = 1, spellID = 101, unit = "nameplate1",
    expectedTime = 9, earlyWindow = 0.5, lateWindow = 0.5 }
bka.active = true
bka.Targets = { GetUnit = function() return nil end }
bka.db.castLearning.predictions = true
learning:UpdatePredictions(10)
learning:UpdatePredictions(11)
equal(model().spells[101].metrics.miss, 1, "expiry MISS recorded once")
local savedModel = model()
learning:ResetRuntime()
equal(learning:GetModel(1, 7), savedModel, "aggregate survives runtime reset")

-- L: scheduled same-spell survives unrelated casts and only matching A resolves it.
reset()
event(1, "SPELL_CAST_START", 101)
state = learning.runtime[guid]
state.prediction = { guid = guid, dungeonID = 1, spellID = 101, source = "same-spell",
    mode = predictor.MODE_SCHEDULED, expectedTime = 17, earlyWindow = 0.5, lateWindow = 0.5 }
learning:Feedback(state, 102, 6, model())
assert(state.prediction, "scheduled prediction survives B")
local scheduled = state.prediction
local savedPredict = predictor.Predict
predictor.Predict = function()
    return { spellID = 102, expectedTime = 7, earlyWindow = 0.4, lateWindow = 0.5,
        confidence = 0.99, source = "transition", samples = 10, mode = predictor.MODE_NEXT }
end
learning:Schedule(state, guid, model(), 6)
assert(state.prediction == scheduled, "intermediate cast scheduling cannot replace scheduled A")
predictor.Predict = savedPredict
learning:Feedback(state, 103, 11, model())
assert(state.prediction, "scheduled prediction survives C")
learning:Feedback(state, 101, 17, model())
equal(state.prediction, nil, "scheduled prediction resolved by matching A")
equal(model().spells[101].metrics.hit, 1, "scheduled matching cast is HIT")
equal(model().spells[101].metrics.miss, 0, "unrelated casts are not scheduled MISS")

-- M: scheduled prediction expires only after its late window.
state.prediction = { guid = guid, dungeonID = 1, spellID = 101, source = "same-spell",
    mode = predictor.MODE_SCHEDULED, expectedTime = 20, earlyWindow = 0.5, lateWindow = 0.5 }
bka.active = true
bka.Targets = { GetUnit = function() return nil end }
bka.db.castLearning.predictions = true
learning:UpdatePredictions(20.4)
assert(state.prediction, "scheduled prediction alive inside late window")
learning:UpdatePredictions(20.6)
equal(state.prediction, nil, "scheduled prediction expired after late window")
equal(model().spells[101].metrics.miss, 1, "scheduled expiry is MISS")

-- N-O: NEXT_CAST resolves on the next observed cast.
state.prediction = { guid = guid, dungeonID = 1, spellID = 101, source = "transition",
    mode = predictor.MODE_NEXT, expectedTime = 25, earlyWindow = 1, lateWindow = 1 }
learning:Feedback(state, 102, 25, model())
equal(state.prediction, nil, "wrong next cast closes NEXT prediction")
equal(model().spells[101].metrics.miss, 2, "wrong next cast is MISS")
state.prediction = { guid = guid, dungeonID = 1, spellID = 101, source = "transition",
    mode = predictor.MODE_NEXT, expectedTime = 26, earlyWindow = 1, lateWindow = 1 }
learning:Feedback(state, 101, 26, model())
equal(model().spells[101].metrics.hit, 2, "correct next cast is HIT")

-- P: matching scheduled spell far too early supersedes without MISS and can re-anchor.
local missBeforeEarly = model().spells[101].metrics.miss
state.prediction = { guid = guid, dungeonID = 1, spellID = 101, source = "same-spell",
    mode = predictor.MODE_SCHEDULED, expectedTime = 40, earlyWindow = 1, lateWindow = 1 }
learning:Feedback(state, 101, 30, model())
equal(state.prediction, nil, "early matching scheduled cast supersedes old prediction")
equal(model().spells[101].metrics.miss, missBeforeEarly, "early supersede is not MISS")
equal(model().spells[101].metrics.EARLY_SUPERSEDED, 1, "early supersede is tracked separately")
local earlySummary = learning:GetSummary()
equal(earlySummary.hits, 2, "summary keeps HIT count")
equal(earlySummary.misses, 2, "invalidated prediction is excluded from MISS count")
near(earlySummary.accuracy, 0.5, "accuracy uses HIT and MISS only")

-- Q: duplicate Schedule is one unique prediction opportunity.
reset()
bka.db.castLearning.predictions = true
local localModel = learning:GetOrCreateModel(1, 7)
localModel.spells[101] = { casts = 10, intervals = { n = 10, mean = 16, m2 = 0 },
    anchors = {}, anchorErrors = {}, metrics = { count = 0, hit = 0, miss = 0, mae = 0 } }
state = learning:State(guid, 7, 1)
state.lastCast = { spellID = 101, start = 1 }
state.lastBySpell[101] = state.lastCast
local originalPredict = predictor.Predict
predictor.Predict = function()
    return { spellID = 101, expectedTime = 17, earlyWindow = 0.5, lateWindow = 1,
        confidence = 0.99, source = "same-spell", samples = 10, mode = predictor.MODE_SCHEDULED }
end
local first = learning:Schedule(state, guid, localModel, 1)
local second = learning:Schedule(state, guid, localModel, 2)
assert(first == second and state.prediction == first, "duplicate Schedule refreshes existing prediction")
equal(localModel.predictionMetrics.created, 1, "duplicate Schedule increments created once")
equal(localModel.highConfidence, 1, "legacy counter increments once")

-- R: START + SUCCESS rescheduling of the same opportunity is not duplicated.
learning:ResetRuntime()
localModel.predictionMetrics = { created = 0, displayed = 0, invalidated = 0 }
localModel.highConfidence = 0
event(3, "SPELL_CAST_START", 101)
event(4, "SPELL_CAST_SUCCESS", 101)
equal(localModel.predictionMetrics.created, 1, "START+SUCCESS creates one prediction")
assert(learning.runtime[guid].prediction, "START+SUCCESS prediction remains active")
predictor.Predict = originalPredict

-- S: displayed increments only on first visible transition into the lead window.
reset()
bka.db.castLearning.predictions = true
localModel = learning:GetOrCreateModel(1, 7)
localModel.spells[101] = { casts = 1, metrics = { count = 0, hit = 0, miss = 0, mae = 0 } }
state = learning:State(guid, 7, 1)
state.prediction = { guid = guid, sourceGUID = guid, dungeonID = 1, spellID = 101, source = "same-spell",
    mode = predictor.MODE_SCHEDULED, expectedTime = 11, earlyWindow = 0.5, lateWindow = 1,
    confidence = 0.99, samples = 10, ability = { nameplate = true } }
bka.active = true
bka.db.castLearning.leadTime = 1
bka.Targets = { GetUnit = function() return "nameplate1" end }
UnitGUID = function(unit) if unit == "nameplate1" then return guid end end
learning:UpdatePredictions(9.9)
local pm = localModel.predictionMetrics or { created = 0, displayed = 0 }
equal(pm.displayed or 0, 0, "not displayed before lead window")
learning:UpdatePredictions(10.0)
equal(localModel.predictionMetrics.displayed, 1, "displayed once on lead-window entry")
learning:UpdatePredictions(10.2)
equal(localModel.predictionMetrics.displayed, 1, "displayed not incremented every refresh")

-- A visible nameplate is not enough: UI must confirm that the ghost was rendered.
state.prediction.wasDisplayed = nil
state.prediction.expectedTime = 13
local displayedBeforeFailedShow = localModel.predictionMetrics.displayed
local savedShow = bka.CastPredictionUI.Show
bka.CastPredictionUI.Show = function() return false end
learning:UpdatePredictions(12.0)
equal(localModel.predictionMetrics.displayed, displayedBeforeFailedShow, "failed render does not increment displayed")
bka.CastPredictionUI.Show = savedShow

-- Central output shares the ghost's lead-window transition and prediction object.
reset()
bka.db.castLearning.predictions = true
bka.db.castLearning.showPredictionAlerts = true
bka.db.showAlerts = true
bka.db.castLearning.leadTime = 3
bka.active = true
bka.Targets = { GetUnit = function() return "nameplate1" end }
localModel = learning:GetOrCreateModel(1, 7)
localModel.spells[101] = { casts = 1, metrics = { count = 0, hit = 0, miss = 0, mae = 0 } }
state = learning:State(guid, 7, 1)
local function centralPrediction(expected)
    state.prediction = { guid = guid, sourceGUID = guid, dungeonID = 1, spellID = 101,
        source = "same-spell", mode = predictor.MODE_SCHEDULED, expectedTime = expected,
        earlyWindow = 0.5, lateWindow = 1, confidence = 0.99, samples = 10,
        ability = { id = 101, nameplate = true } }
    return state.prediction
end
local firstCentral = centralPrediction(16)
learning:UpdatePredictions(12.9)
equal(centralShown, 0, "A: central hidden before lead")
learning:UpdatePredictions(13)
equal(centralShown, 1, "B: central shown at lead")
equal(state.prediction, firstCentral, "central uses existing prediction")
local firstRow = firstCentral.alertRow
learning:UpdatePredictions(13.2)
equal(centralShown, 1, "C: central not duplicated on tick")
equal(firstCentral.alertRow, firstRow, "C: same central row")
assert(centralSynced > 0, "C: central row synchronized")
learning:Feedback(state, 101, 16, localModel)
equal(centralHidden, 1, "D: real cast removes central prediction")
centralPrediction(20)
learning:UpdatePredictions(17)
learning:UpdatePredictions(21.1)
equal(centralHidden, 2, "E: expiry removes central prediction")
centralPrediction(25)
learning:UpdatePredictions(22)
event(22.1, "SPELL_AURA_APPLIED", 118905, "Player-1", guid)
equal(centralHidden, 3, "F: CC removes central prediction")
event(22.2, "SPELL_AURA_REMOVED", 118905, "Player-1", guid)
centralPrediction(30)
learning:UpdatePredictions(27)
event(27.1, "UNIT_DIED", nil, "Creature-0-0-0-0-8-1", guid)
equal(centralHidden, 4, "G: death removes central prediction")
state = learning:State(guid, 7, 31)
centralPrediction(34)
bka.db.castLearning.showPredictionAlerts = false
local ghostBefore = shown
learning:UpdatePredictions(31)
assert(shown > ghostBefore, "H: ghost remains when central setting off")
equal(centralShown, 4, "H: central setting off")
bka.db.castLearning.showPredictionAlerts = true
bka.db.showAlerts = false
learning:UpdatePredictions(31.1)
equal(centralShown, 4, "I: master alerts toggle off")
bka.db.showAlerts = true

-- T: metrics-only reset preserves learned timings and transition data.
localModel.total = 100
localModel.spells[101].casts = 100
localModel.spells[101].intervals = { n = 50, mean = 16, m2 = 2 }
localModel.spells[101].opening = { n = 12, mean = 2, m2 = 1 }
localModel.spells[101].anchors = { START = { n = 50, mean = 16, m2 = 2 }, SUCCESS = { n = 20, mean = 14, m2 = 1 } }
localModel.spells[101].rotations = { [2] = { n = 6, codes = { 30, 34 }, intervals = { { n = 6, mean = 15, m2 = 0 }, { n = 6, mean = 17, m2 = 0 } } } }
localModel.spells[101].ccExcluded = 7
localModel.spells[101].metrics = { count = 7, hit = 4, miss = 3, mae = 0.4, recentHit = 2, recentMiss = 1 }
localModel.transitions = { [101] = { [102] = { n = 8, timing = { n = 8, mean = 5, m2 = 0 } } } }
localModel.second = { ["101:102"] = { [103] = { n = 6, timing = { n = 6, mean = 4, m2 = 0 } } } }
localModel.highConfidence = 9
localModel.predictionMetrics = { created = 9, displayed = 4, invalidated = 2 }
learning:ResetPredictionMetrics()
equal(localModel.total, 100, "metrics reset preserves casts")
equal(localModel.spells[101].intervals.n, 50, "metrics reset preserves intervals")
equal(localModel.spells[101].opening.n, 12, "metrics reset preserves opening")
equal(localModel.spells[101].anchors.SUCCESS.n, 20, "metrics reset preserves anchors")
equal(localModel.spells[101].rotations[2].n, 6, "metrics reset preserves rotations")
equal(localModel.spells[101].ccExcluded, 7, "metrics reset preserves CC statistics")
equal(localModel.transitions[101][102].n, 8, "metrics reset preserves transitions")
equal(localModel.second["101:102"][103].n, 6, "metrics reset preserves second-order transitions")
equal(localModel.spells[101].metrics.hit, 0, "metrics reset clears hits")
equal(localModel.spells[101].metrics.miss, 0, "metrics reset clears misses")
equal(localModel.predictionMetrics.created, 0, "metrics reset clears created")
equal(localModel.predictionMetrics.displayed, 0, "metrics reset clears displayed")
equal(localModel.highConfidence, 0, "metrics reset clears legacy prediction counter")

print("cast_learning_replay: lifecycle, dedupe, display metrics, and metrics-only reset passed")
