local BKA = BFAKeyAlerts
local Timers = { active = {} }
BKA.Timers = Timers

local LEAD_TIME = 5

function Timers:Schedule(ability, delay, sourceGUID, label)
    if not delay or delay <= 0 then
        return
    end
    local policy = BKA:GetInterruptPolicy(nil, ability.id)
    if policy and policy.policy == "IGNORE" and policy.suppressAlert then
        return
    end
    local key = tostring(ability.id) .. ":" .. tostring(sourceGUID or "global")
    self:Cancel(key)
    local due = GetTime() + delay
    local wait = math.max(0, delay - LEAD_TIME)
    local timer = C_Timer.NewTimer(wait, function()
        Timers.active[key] = nil
        if not BKA.active then
            return
        end
        local timerAbility = ability
        if not ability.center then
            timerAbility = {
                id = ability.id,
                action = ability.primaryAction or ability.action,
                primaryAction = ability.primaryAction,
                mechanic = ability.mechanic,
                severity = ability.severity == "LOW" and "MEDIUM" or ability.severity,
                center = true,
                sound = false,
            }
        end
        if policy and policy.policy == "IGNORE" and policy.action then
            timerAbility = {
                id = ability.id, action = policy.action, mechanic = policy.action,
                severity = ability.severity, center = true, sound = ability.sound,
                role = ability.role,
            }
        end
        BKA.Alerts:Show(timerAbility, {
            key = "timer:" .. key,
            sourceGUID = sourceGUID,
            spellName = label,
            action = policy and policy.action or ability.primaryAction or ability.action,
            startTime = due - LEAD_TIME,
            endTime = due,
            duration = LEAD_TIME,
            alertState = "PREWARN",
            silent = not ability.sound,
        })
    end)
    self.active[key] = { timer = timer, sourceGUID = sourceGUID, abilityID = ability.id, due = due }
end

function Timers:CancelPrewarning(abilityID, sourceGUID)
    if not abilityID then return end
    local key = tostring(abilityID) .. ":" .. tostring(sourceGUID or "global")
    self:Cancel(key)
    if sourceGUID then
        self:Cancel(tostring(abilityID) .. ":global")
    end
    BKA.Alerts:Hide("timer:" .. key)
    if sourceGUID then
        BKA.Alerts:Hide("timer:" .. tostring(abilityID) .. ":global")
    end
    BKA.Alerts:HidePrewarning(abilityID, sourceGUID)
end

function Timers:Cancel(key)
    local entry = self.active[key]
    if entry then
        if entry.timer and entry.timer.Cancel then
            entry.timer:Cancel()
        end
        self.active[key] = nil
    end
end

function Timers:CancelSource(sourceGUID)
    for key, entry in pairs(self.active) do
        if entry.sourceGUID == sourceGUID then
            self:Cancel(key)
        end
    end
end

function Timers:CancelAbility(abilityID)
    for key, entry in pairs(self.active) do
        if entry.abilityID == abilityID then
            self:Cancel(key)
        end
    end
    BKA.Alerts:HidePrewarning(abilityID)
end

function Timers:GetRemaining(abilityID)
    local now = GetTime()
    for _, entry in pairs(self.active) do
        if entry.abilityID == abilityID and entry.due then
            return math.max(0, entry.due - now)
        end
    end
    return 0
end

function Timers:Clear()
    for key in pairs(self.active) do
        self:Cancel(key)
    end
end
