local BKA = BFAKeyAlerts
local Sounds = {
    played = {}, playedCount = 0, lastAny = 0, lastPriority = 0,
    nextSemanticAt = {}, pendingCombatSounds = {}, previewGeneration = 0,
    victorySoundHandle = nil,
    lastCombatDecision = nil,
}
BKA.Sounds = Sounds

local FILES = {
    KICK = "kick.ogg", STOP = "stop.ogg", TURN = "turn.ogg", AOE = "aoe.ogg",
    FRONTAL = "frontal.ogg", MOVE = "move.ogg", YOU = "you.ogg",
    DISPEL = "dispel.ogg", PURGE = "purge.ogg", SOOTHE = "soothe.ogg",
    DEFENSIVE = "defensive.ogg", HEAL = "heal.ogg", SOAK = "soak.ogg",
    SPREAD = "spread.ogg", STACK = "stack.ogg", LOS = "los.ogg",
    RUN = "run.ogg", KITE = "kite.ogg", PREPARE = "prepare.ogg",
}

local ALIASES = {
    INTERRUPT = "KICK", KICK = "KICK", STOP = "STOP", CC = "STOP",
    TURN = "TURN",
    AOE = "AOE", BURSTING = "AOE", FRONTAL = "FRONTAL", CLEAVE = "FRONTAL",
    DODGE = "MOVE", MOVE = "MOVE", MOVE_MOBS = "MOVE", GTFO = "MOVE",
    DISPEL = "DISPEL", PURGE = "PURGE",
    SOOTHE = "SOOTHE", DEF = "DEFENSIVE", DEFENSIVE = "DEFENSIVE",
    TANK = "DEFENSIVE", HEAL = "HEAL", HEALER = "HEAL", SOAK = "SOAK",
    SPREAD = "SPREAD", STACK = "STACK", STACKS = "STACK", LOS = "LOS", FIXATE = "RUN",
    RUN = "RUN", KITE = "KITE", PREWARN = "PREPARE", PREPARE = "PREPARE",
}

local PRIORITY = {
    YOU = 100, KICK = 90, STOP = 90, TURN = 85, MOVE = 80, RUN = 80,
    DEFENSIVE = 70, DISPEL = 60, PURGE = 60, SOOTHE = 60,
    SOAK = 50, SPREAD = 50, STACK = 50, AOE = 40, FRONTAL = 40,
    LOS = 40, KITE = 40, HEAL = 30, PREPARE = 10,
}

local ORDER = {
    "KICK", "STOP", "TURN", "AOE", "FRONTAL", "MOVE", "YOU",
    "DISPEL", "PURGE", "SOOTHE", "DEFENSIVE", "HEAL", "SOAK",
    "SPREAD", "STACK", "LOS", "RUN", "KITE", "PREPARE",
}

function Sounds:Normalize(action, context)
    if context and context.alertState == "PREWARN" then return "PREPARE" end
    local confirmedPersonal = context and context.isPlayer and context.targetConfidence == "CONFIRMED"
    action = string.upper(tostring(action or ""))
    action = string.match(action, "^[A-Z]+") or action
    if action == "YOU" or action == "TARGETED" then
        if confirmedPersonal or not context or (context.forcePreview or context.route == "soundcombat") then return "YOU" end
        return nil
    end
    return ALIASES[action]
end

function Sounds:CancelCastIdentity(castIdentity, keepAction)
    local pending = castIdentity and self.pendingCombatSounds[castIdentity]
    if not pending or (keepAction and pending.semanticAction == keepAction) then return false end
    self.pendingCombatSounds[castIdentity] = nil
    return true
end

function Sounds:CancelAllPendingCombat()
    wipe(self.pendingCombatSounds)
    wipe(self.nextSemanticAt)
end

function Sounds:GetActions()
    return ORDER
end

local function dedupeKeys(semantic, context)
    local weak
    if context.sourceGUID and context.spellID then
        weak = table.concat({ semantic, "weak", tostring(context.sourceGUID), tostring(context.spellID) }, ":")
    elseif context.key then
        weak = semantic .. ":weak:" .. tostring(context.key)
    end
    if context.castIdentity then return semantic .. ":" .. tostring(context.castIdentity), weak, context.stableIdentity ~= false end
    if context.castGUID then return semantic .. ":cast:" .. tostring(context.castGUID), weak, true end
    if context.sourceGUID and context.spellID and context.startTimeMS then
        local stable = table.concat({ semantic, "runtime", tostring(context.sourceGUID), tostring(context.spellID), tostring(math.floor(context.startTimeMS + 0.5)) }, ":")
        return stable, weak, true
    end
    return weak, weak, false
end

local function playFile(key, fileName)
    local path = "Interface\\AddOns\\BFAKeyAlerts\\Sounds\\" .. fileName
    local played = PlaySoundFile and PlaySoundFile(path, "Master")
    if played then return true, "custom" end
    if PlaySound then
        local fallback = SOUNDKIT and (key == "PREPARE" and SOUNDKIT.READY_CHECK or SOUNDKIT.RAID_WARNING) or 8959
        PlaySound(fallback, "Master")
        return true, "fallback"
    end
    return false, "unavailable"
end

function Sounds:RecordDecision(action, semantic, context, reason, played)
    if context and context.forcePreview then return end
    self.lastCombatDecision = {
        action = action, semantic = semantic, spellID = context and context.spellID,
        route = context and context.route or "combat", reason = reason,
        played = played and true or false, timestamp = GetTime(),
    }
end

local function finish(self, played, reason, action, semantic, context)
    self:RecordDecision(action, semantic, context, reason, played)
    return played, reason
end

function Sounds:PlayMechanic(action, context)
    context = context or {}
    local key = self:Normalize(action, context)
    if not BKA.db or ((not BKA.db.enabled or not BKA.db.sound) and not context.forcePreview) or context.silent then
        return finish(self, false, "disabled", action, key, context)
    end
    local fileName = key and FILES[key]
    if not fileName then return finish(self, false, "unmapped", action, key, context) end
    if context.castIdentity then self:CancelCastIdentity(context.castIdentity, key) end
    if not context.forcePreview and BKA.db.soundActions and BKA.db.soundActions[key] == false then
        return finish(self, false, "action disabled", action, key, context)
    end

    local now = GetTime()
    local priority = PRIORITY[key] or 20
    local eventKey, weakKey, stable = dedupeKeys(key, context)
    if eventKey and not context.bypassDedupe then
        local previous = self.played[eventKey]
        local window = stable and 8 or 0.8
        if previous and now - previous < window then return finish(self, false, "duplicate", action, key, context) end
        if stable and weakKey and weakKey ~= eventKey then
            local weakPrevious = self.played[weakKey]
            if weakPrevious and now - weakPrevious < 0.8 then
                self.played[eventKey] = now
                return finish(self, false, "duplicate", action, key, context)
            end
        end
        self.played[eventKey] = now
        if weakKey then self.played[weakKey] = now end
        self.playedCount = self.playedCount + 1
        if self.playedCount > 200 then
            for oldKey, playedAt in pairs(self.played) do
                if now - playedAt > 10 then self.played[oldKey] = nil end
            end
            self.playedCount = 0
        end
    elseif not context.criticalPersonal and now - (self.lastAny or 0) < 0.08 and priority < (self.lastPriority or 0) then
        return finish(self, false, "priority", action, key, context)
    end

    self.lastAny = now
    self.lastPriority = priority
    if stable and priority >= 80 and not context.criticalPersonal then
        local playAt = math.max(now, self.nextSemanticAt[key] or 0)
        self.nextSemanticAt[key] = playAt + 0.2
        if playAt > now then
            local castIdentity = context.castIdentity
            if castIdentity then
                self:CancelCastIdentity(castIdentity, key)
                local token = {}
                self.pendingCombatSounds[castIdentity] = {
                    token = token, semanticAction = key, scheduledAt = playAt,
                }
                C_Timer.After(playAt - now, function()
                    local pending = Sounds.pendingCombatSounds[castIdentity]
                    if not pending or pending.token ~= token then return end
                    if not BKA.ActiveCasts or not BKA.ActiveCasts:IsIdentityActive(castIdentity) then
                        Sounds.pendingCombatSounds[castIdentity] = nil
                        return
                    end
                    Sounds.pendingCombatSounds[castIdentity] = nil
                    local played, route = playFile(key, fileName)
                    Sounds:RecordDecision(action, key, context, route, played)
                end)
            else
                C_Timer.After(playAt - now, function() playFile(key, fileName) end)
            end
            return finish(self, true, "queued", action, key, context)
        end
    end
    local played, route = playFile(key, fileName)
    return finish(self, played, route, action, key, context)
end

function Sounds:ResetActions()
    BKA.db.soundActions = BKA.db.soundActions or {}
    for _, action in ipairs(ORDER) do BKA.db.soundActions[action] = true end
end

function Sounds:PlayKeyUpgrade(forcePreview)
    if not forcePreview and (not BKA.db or not BKA.db.enabled or not BKA.db.sound) then
        return false, "disabled"
    end
    if forcePreview and self.victorySoundHandle and StopSound then
        StopSound(self.victorySoundHandle)
        self.victorySoundHandle = nil
    end
    local played, handle = PlaySoundFile and PlaySoundFile("Interface\\AddOns\\BFAKeyAlerts\\Sounds\\key_upgrade.ogg", "Master")
    if played then
        if handle then self.victorySoundHandle = handle end
        return true, "custom"
    end
    return false, "unavailable"
end

function Sounds:Play(action, context)
    return self:PlayMechanic(action, context)
end

function Sounds:Preview(action)
    local played, route = self:PlayMechanic(action, { forcePreview = true, bypassDedupe = true })
    return played, route
end

function Sounds:PreviewAll()
    self.previewGeneration = self.previewGeneration + 1
    local generation = self.previewGeneration
    for index, action in ipairs(ORDER) do
        C_Timer.After((index - 1) * 1.0, function()
            if Sounds.previewGeneration == generation then Sounds:Preview(action) end
        end)
    end
end

function Sounds:Clear()
    wipe(self.played)
    self.playedCount = 0
    self.lastAny = 0
    self.lastPriority = 0
    self:CancelAllPendingCombat()
    self.previewGeneration = self.previewGeneration + 1
end
