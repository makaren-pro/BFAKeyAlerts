-- Synthetic CLEU replay. Run from the addon directory with a Lua interpreter.
local now = 0
local hidden = 0
GetTime = function() return now end
wipe = function(value) for key in pairs(value) do value[key] = nil end end
bit = { band = function(value, mask) return value % (mask * 2) >= mask and mask or 0 end }
COMBATLOG_OBJECT_REACTION_HOSTILE = 0x40

BFAKeyAlerts = {
    db = { castLearning = { version = 1, enabled = true, predictions = false, dungeons = {} } },
    activeDungeon = { challengeMapID = 1 },
    CastBaseline = {},
    GroupInterrupts = { IsHardCCAura = function(_, id) return id == 118905 or id == 132168 end },
    CastPredictionUI = { Hide = function() hidden = hidden + 1 end, Clear = function() end,
        Refresh = function() end },
    GetNPCID = function() return 7 end,
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
BFAKeyAlertsDB = { castLearning = { version = 1, predictions = false, dungeons = { [1] = { npcs = {} } } } }
bka:InitDB()
equal(bka.db.castLearning.predictions, false, "saved preference preserved")
assert(bka.db.castLearning.dungeons[1], "saved learning data preserved")

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

print("cast_learning_replay: A-K, preferences, outcomes, and runtime reset passed")
