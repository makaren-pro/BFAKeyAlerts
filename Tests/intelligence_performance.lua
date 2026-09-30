-- A 20-visible-nameplate workload. This checks work bounds, not WoW FPS.
local now, lookups, merged, rowsCreated = 0, 0, 0, 0
local guids, hosts = {}, {}
GetTime = function() return now end
UnitGUID = function(unit) return guids[unit] end
UnitAffectingCombat = function() return true end
UnitIsDeadOrGhost = function() return false end
GetSpellTexture = function(id) lookups = lookups + 1; return id end
local model = { spells = {}, total = 50, transitions = {}, second = {} }
for id = 1, 3 do
    local stat = { n = 20, mean = 15 + id * 4, m2 = 0 }
    model.spells[id] = { intervals = stat, anchors = { START = stat }, casts = 30, metrics = {} }
end
BFAKeyAlerts = {
    active = true, activeDungeon = { challengeMapID = 1 }, CastBaseline = {},
    db = { enabled = true, showNameplates = true,
        castLearning = { enabled = true, minimumSamples = 5, minimumConfidence = .85, leadTime = 3 },
        enemySpellCooldowns = { enabled = true, predictedOnly = true, minSeverity = 3, maxAbilities = 2 } },
    CastLearning = { runtime = {}, allowed = { [7] = true }, GetModel = function() return model end,
        ResolveAbility = function(_, _, id) return { id = id, nameplate = true, severity = "HIGH" }, "KICK" end },
    Targets = { GetUnit = function(_, guid) return "nameplate" .. guid:match("(%d+)$") end },
    CombatIntelligence = {
        GetHost = function(_, unit) return hosts[unit] end,
        HideRows = function() end,
        GetRows = function(_, host, _, count)
            for i = #host.rows + 1, count do
                rowsCreated = rowsCreated + 1
                local row = { icon = {}, text = {} }
                local noop = function() end
                row.ClearAllPoints, row.SetPoint, row.EnableMouse, row.SetScript, row.Show, row.Hide = noop, noop, noop, noop, noop, noop
                row.icon.SetTexture, row.icon.SetVertexColor = noop, noop
                row.text.SetText, row.text.SetTextColor = noop, noop
                host.rows[i] = row
            end
            return host.rows
        end,
    },
}
for i = 1, 20 do
    local unit, guid = "nameplate" .. i, "Creature-" .. i
    guids[unit] = guid
    hosts[unit] = { ownerGUID = guid, rows = {} }
    BFAKeyAlerts.CastLearning.runtime[guid] = { npcID = 7, cc = { active = false }, casts = 10,
        lastCast = { spellID = 1, start = 0 }, lastBySpell = { [1] = { start = 0 }, [2] = { start = 0 }, [3] = { start = 0 } }, recentIntervals = {} }
end
dofile("CastPredictor.lua")
local predictor = BFAKeyAlerts.CastPredictor
local getModel = predictor.GetModel
function predictor:GetModel(...) merged = merged + 1; return getModel(self, ...) end
dofile("EnemySpellCooldowns.lua")
local cooldowns = BFAKeyAlerts.EnemySpellCooldowns
cooldowns:Refresh(0)
assert(merged == 20 and rowsCreated == 40)
local initialLookups = lookups
for i = 1, 9 do now = i * .1; cooldowns:Refresh(now) end
assert(merged == 20, "no model rebuild on countdown ticks")
assert(lookups == initialLookups, "no spell API lookup on countdown ticks")
assert(rowsCreated == 40, "no row allocations on countdown ticks")
now = 1.01; cooldowns:Refresh(now)
assert(merged == 40 and rowsCreated == 40, "bounded one-second fallback and stable pool")
print("intelligence_performance: 20 plates, 40 cached rows; no model/icon/row work on countdown ticks")
