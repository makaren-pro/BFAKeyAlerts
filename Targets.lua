local BKA = BFAKeyAlerts
local Targets = { guidToUnit = {}, unitToGUID = {} }
BKA.Targets = Targets

function Targets:AddUnit(unit)
    if UnitExists(unit) then
        local guid = UnitGUID(unit)
        if guid then
            local oldGUID = self.unitToGUID[unit]
            if oldGUID and oldGUID ~= guid and self.guidToUnit[oldGUID] == unit then
                self.guidToUnit[oldGUID] = nil
            end
            self.guidToUnit[guid] = unit
            self.unitToGUID[unit] = guid
        end
    end
end

function Targets:RemoveUnit(unit)
    local guid = self.unitToGUID[unit] or UnitGUID(unit)
    if guid and self.guidToUnit[guid] == unit then
        self.guidToUnit[guid] = nil
    end
    self.unitToGUID[unit] = nil
end

function Targets:RefreshBossUnits()
    for i = 1, 5 do
        self:AddUnit("boss" .. i)
    end
end

function Targets:GetUnit(sourceGUID)
    local unit = self.guidToUnit[sourceGUID]
    if unit and UnitExists(unit) and UnitGUID(unit) == sourceGUID then
        return unit
    end
    self.guidToUnit[sourceGUID] = nil
    self:RefreshBossUnits()
    return self.guidToUnit[sourceGUID]
end

local function targetContext(unit)
    local target = unit and (unit .. "target")
    if not target or not UnitExists(target) then
        return nil
    end
    local guid = UnitGUID(target)
    local name = UnitName(target)
    return {
        unit = target,
        guid = guid,
        name = name,
        isPlayer = UnitIsUnit(target, "player"),
        isParty = BKA:IsPlayerOrPartyGUID(guid),
        role = UnitGroupRolesAssigned and UnitGroupRolesAssigned(target) or "NONE",
    }
end

function Targets:GetCurrentTarget(sourceGUID)
    return targetContext(self:GetUnit(sourceGUID))
end

function Targets:ResolveSourceTarget(sourceGUID, callback, options)
    local delays = {0, 0.05, 0.15, 0.30, 0.40}
    local confirmAfterWindow = options and options.confirmAfterWindow
    local finished = false
    local function attempt(index)
        if finished or not BKA.active then
            return
        end
        local context = Targets:GetCurrentTarget(sourceGUID)
        if context and not confirmAfterWindow then
            finished = true
            callback(context)
        elseif confirmAfterWindow and index == #delays then
            finished = true
            if context then callback(context) end
        elseif index < #delays then
            C_Timer.After(delays[index + 1] - delays[index], function() attempt(index + 1) end)
        end
    end
    attempt(1)
end

function Targets:Clear()
    wipe(self.guidToUnit)
    wipe(self.unitToGUID)
end
