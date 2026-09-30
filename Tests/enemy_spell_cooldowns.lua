-- Synthetic prediction and nameplate-cache checks. Run from the addon directory.
local now = 0
local shownRows, hiddenGroups = {}, 0
local guidUnits = {}
GetTime = function() return now end
UnitGUID = function(unit) return guidUnits[unit] end
GetSpellTexture = function(spellID) return 100000 + spellID end
wipe = function(value) for key in pairs(value) do value[key] = nil end end

local function row()
    local result = { icon = {}, text = {}, border = {} }
    function result:ClearAllPoints() end
    function result:SetPoint() end
    function result:EnableMouse(value) self.mouseEnabled = value end
    function result:SetScript() end
    function result:Show() self.shown = true end
    function result:Hide() self.shown = false end
    function result.icon:SetTexture(value) self.texture = value end
    function result.icon:SetVertexColor(...) self.color = {...} end
    function result.text:SetText(value) self.value = value end
    function result.text:SetTextColor(...) self.color = {...} end
    function result.border:SetBackdropColor(...) self.color = {...} end
    return result
end

local host = { ownerGUID = "Creature-A" }
BFAKeyAlerts = {
    active = true,
    activeDungeon = { challengeMapID = 1 },
    activeAbilities = {
        { id = 101, sources = { 7 } }, { id = 102, sources = { 7 } },
    },
    db = {
        enabled = true,
        showNameplates = true,
        castLearning = { enabled = true, predictions = true, minimumSamples = 3,
            minimumConfidence = 0.85, leadTime = 2, importantOnly = false },
        enemySpellCooldowns = { enabled = true, minSeverity = 3, maxAbilities = 2,
            predictedOnly = true, debug = true },
    },
    CastBaseline = {},
    Nameplates = { overlays = {} },
    Targets = { GetUnit = function(_, guid) return guid == "Creature-A" and "nameplate1" or "nameplate2" end },
    CombatIntelligence = {
        GetHost = function(_, unit)
            if UnitGUID(unit) == "Creature-A" then return host end
            return { ownerGUID = UnitGUID(unit) }
        end,
        GetRows = function(_, _, _, count)
            shownRows = {}
            for i = 1, count do shownRows[i] = row() end
            return shownRows
        end,
        HideRows = function() hiddenGroups = hiddenGroups + 1; shownRows = {} end,
    },
    GetNPCID = function() return 7 end,
}
local bka = BFAKeyAlerts
bka.CastLearning = {
    allowed = { [7] = true },
    runtime = {},
    GetModel = function() return nil end,
    ResolveAbility = function(_, npcID, spellID)
        if npcID ~= 7 or (spellID ~= 101 and spellID ~= 102) then return nil end
        return { id = spellID, nameplate = true, severity = "CRITICAL", icon = 9000 + spellID }, "KICK", "KICK"
    end,
}
dofile("CastPredictor.lua")
dofile("EnemySpellCooldowns.lua")

local predictor, cooldowns = bka.CastPredictor, bka.EnemySpellCooldowns
local stat = { n = 5, mean = 10, m2 = 0 }
local model = { total = 10, spells = {
    [101] = { intervals = stat, anchors = { START = stat }, anchorErrors = {}, casts = 10, metrics = {} },
    [102] = { intervals = stat, anchors = { START = stat }, anchorErrors = {}, casts = 10, metrics = {} },
}, transitions = { [101] = {
    [102] = { n = 5, timing = stat },
} }, second = {} }
bka.CastBaseline[1] = { npcs = { [7] = model } }

local state = { npcID = 7, cc = { active = false }, ccSinceCast = false, casts = 5,
    lastCast = { spellID = 101, start = 0 }, lastBySpell = { [101] = { start = 0 } },
    recentIntervals = { [101] = { 10, 10, 10 } } }
bka.CastLearning.runtime["Creature-A"] = state
guidUnits.nameplate1 = "Creature-A"
guidUnits.nameplate2 = "Creature-B"

local function equal(actual, expected, label)
    assert(actual == expected, label .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual))
end

-- Candidate collection retains the transition prediction and the same-spell timer;
-- Predict still chooses the transition using the legacy precedence.
local collected = predictor:CollectPredictions(model, state, now, bka.db.castLearning)
local found101, found102 = false, false
for _, candidate in ipairs(collected) do
    if candidate.spellID == 101 and candidate.source == "same-spell" then found101 = true end
    if candidate.spellID == 102 and candidate.source == "transition" then found102 = true end
end
equal(found101, true, "same-spell candidate collected")
equal(found102, true, "transition candidate collected")
equal(predictor:Predict(model, state, now, bka.db.castLearning).spellID, 102, "legacy selected spell")

-- The existing single-prediction path keeps its early return in dense packs.
local lastBySpell = state.lastBySpell
state.lastBySpell = setmetatable({}, { __index = function() error("unexpected same-spell scan on fast path") end })
equal(predictor:Predict(model, state, now, bka.db.castLearning).source, "transition", "transition returns before scanning other spells")
state.previousCast = { spellID = 101 }
model.second["101:101"] = model.transitions[101]
equal(predictor:Predict(model, state, now, bka.db.castLearning).source, "second-order", "second-order returns before scanning other spells")
state.lastBySpell, state.previousCast, model.second["101:101"] = lastBySpell, nil, nil

-- Candidate rows are bounded, GUID scoped, and mouse transparent.
cooldowns:Refresh(now)
equal(#shownRows, 2, "two timer rows")
equal(cooldowns.entries["Creature-A"].candidates[1].action, "KICK", "multi-return ability action retained")
equal(cooldowns.entries["Creature-B"], nil, "unrelated GUID has no shared candidate cache")
equal(shownRows[1].mouseEnabled, false, "rows do not capture mouse")
equal(shownRows[1].icon.texture ~= nil, true, "spell icon populated")

-- A displayed ghost suppresses only the matching timer; the other prediction stays.
state.prediction = { spellID = 102, expectedTime = 10, wasDisplayed = true,
    guid = "Creature-A", unit = "nameplate1" }
bka.Nameplates.overlays.nameplate1 = { ownerGUID = "Creature-A",
    predictionState = { predictionData = state.prediction } }
now = 8.5
cooldowns:Refresh(now)
equal(#shownRows, 1, "other spell timer retained after ghost display")

-- CC invalidates all guessed timers immediately. With predictedOnly=false, static
-- spell icons remain available without fabricated countdown values.
state.cc.active = true
now = 8.7
cooldowns:Refresh(now)
equal(#shownRows, 0, "CC clears predicted rows")
bka.db.enemySpellCooldowns.predictedOnly = false
cooldowns:Refresh(now)
equal(#shownRows, 2, "static ability icons shown during CC")
equal(shownRows[1].text.value, "", "static abilities have no guessed timer")

-- Expired predictions stay gone, and runtime removal/recycled GUIDs clear the cache.
state.cc.active = false
state.prediction = nil
bka.db.enemySpellCooldowns.predictedOnly = true
now = 30
cooldowns:Refresh(now)
equal(#shownRows, 0, "expired predictions hidden")
guidUnits.nameplate1 = "Creature-Recycled"
cooldowns:Refresh(now + 0.2)
equal(cooldowns.entries["Creature-A"], nil, "recycled nameplate GUID clears old cache")
guidUnits.nameplate1 = "Creature-A"
bka.CastLearning.runtime["Creature-A"] = nil
cooldowns:Refresh(now)
equal(cooldowns.entries["Creature-A"], nil, "removed learner state clears GUID cache")
cooldowns:Clear()
-- A combat reset must not resurrect forecasts from old per-GUID anchors.
bka.CastLearning.runtime["Creature-A"] = state
guidUnits.nameplate1 = "Creature-A"
now = 1
UnitAffectingCombat = function() return false end
cooldowns:Refresh(now)
equal(next(cooldowns.entries), nil, "out-of-combat old anchors hidden")
UnitAffectingCombat = nil
UnitIsDeadOrGhost = function() return true end
cooldowns:Refresh(now)
equal(next(cooldowns.entries), nil, "dead enemy forecasts hidden")
UnitIsDeadOrGhost = nil

print("enemy_spell_cooldowns: PASS")
