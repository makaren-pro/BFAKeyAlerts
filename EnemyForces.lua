local BKA = BFAKeyAlerts
local EnemyForces = {}
BKA.EnemyForces = EnemyForces

local function currentMapID()
    local _, instanceType, difficultyID, _, _, _, _, instanceMapID = GetInstanceInfo()
    if instanceType ~= "party" then return nil end
    if C_ChallengeMode and C_ChallengeMode.GetActiveChallengeMapID then
        local active = C_ChallengeMode.GetActiveChallengeMapID()
        if active and active > 0 then return active end
    end
    -- Mythic dungeon before the countdown; use only the actual instance map.
    if difficultyID ~= 8 and difficultyID ~= 23 then return nil end
    local dungeon = BKA.dungeonByInstanceMap[instanceMapID]
    return dungeon and dungeon.challengeMapID or nil
end

local function onTooltipSetUnit(tooltip)
    if not BKA.db or BKA.db.enabled == false or BKA.db.showEnemyForcesTooltip == false then return end
    local _, unit = tooltip:GetUnit()
    if not unit or not UnitExists(unit) or UnitIsPlayer(unit) or UnitPlayerControlled(unit)
        or UnitIsFriend("player", unit) then return end
    local guid = UnitGUID(unit)
    if not guid or guid ~= UnitGUID("mouseover") or tooltip._bkaForcesGUID == guid then return end
    local mapID = currentMapID()
    local data = mapID and BKA.EnemyForcesData[mapID]
    local value = data and data.npcs[BKA:GetNPCID(guid)]
    if not value then return end
    local total = data.total
    if BKA.Affixes and BKA.Affixes:IsActive(5) and data.teemingTotal then
        total = data.teemingTotal
    end
    if not total or total <= 0 then return end
    tooltip._bkaForcesGUID = guid
    tooltip:AddLine(BKA:L("ENEMY_FORCES_TOOLTIP_FMT", value * 100 / total), 0.40, 0.88, 0.74)
    tooltip:Show()
end

function EnemyForces:Initialize()
    if self.initialized or not GameTooltip then return end
    self.initialized = true
    GameTooltip:HookScript("OnTooltipSetUnit", onTooltipSetUnit)
    GameTooltip:HookScript("OnTooltipCleared", function(tooltip) tooltip._bkaForcesGUID = nil end)
end
