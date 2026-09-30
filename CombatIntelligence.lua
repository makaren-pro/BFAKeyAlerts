local BKA = BFAKeyAlerts
local CI = { hosts = {}, elapsed = 0 }
BKA.CombatIntelligence = CI

-- Satellite frames belong to the existing nameplate pool, but remain visible
-- when the primary mechanic overlay has no winning state.
function CI:GetHost(unit)
    if not BKA.active or not BKA.db or BKA.db.enabled == false or BKA.db.showNameplates == false then return nil end
    if not UnitExists(unit) or UnitIsDeadOrGhost(unit) or not UnitCanAttack("player", unit) then return nil end
    local overlay = BKA.Nameplates:GetOverlay(unit)
    if not overlay then return nil end
    local plate = overlay:GetParent()
    if not plate then return nil end
    local host = overlay.intelligenceHost
    if not host then
        host = CreateFrame("Frame", nil, plate)
        host:EnableMouse(false)
        host:SetSize(1, 1)
        host.groups = {}
        overlay.intelligenceHost = host
    end
    local guid = UnitGUID(unit)
    if host.ownerGUID ~= guid or host:GetParent() ~= plate then
        for key in pairs(host.groups) do self:HideRows(host, key) end
        if host.stateFrame then host.stateFrame:Hide() end
        if host.castFrame then host.castFrame:Hide() end
        host.ownerGUID = guid
        host:SetParent(plate)
        host:ClearAllPoints()
        host:SetPoint("BOTTOM", plate, "TOP", 0, 3)
    end
    host.unit = unit
    host:Show()
    self.hosts[unit] = host
    return host
end

function CI:GetRows(host, key, count, size)
    local rows = host.groups[key]
    if not rows then rows = {}; host.groups[key] = rows end
    for i = 1, count do
        local row = rows[i]
        if not row then
            row = CreateFrame("Frame", nil, host)
            row:EnableMouse(false)
            row.icon = row:CreateTexture(nil, "ARTWORK")
            row.icon:SetPoint("LEFT")
            row.text = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            row.text:SetPoint("LEFT", row.icon, "RIGHT", 3, 0)
            rows[i] = row
        end
        row:SetSize(size + 58, size)
        row.icon:SetSize(size, size)
    end
    for i = count + 1, #rows do rows[i]:Hide() end
    return rows
end

function CI:HideRows(host, key)
    for _, row in ipairs(host.groups[key] or {}) do row:Hide() end
end

function CI:RemoveUnit(unit)
    local host = self.hosts[unit]
    if host then
        for key in pairs(host.groups) do self:HideRows(host, key) end
        if host.stateFrame then host.stateFrame:Hide() end
        if host.castFrame then host.castFrame:Hide() end
        host:Hide()
        host.ownerGUID, host.unit = nil, nil
        self.hosts[unit] = nil
    end
    for _, name in ipairs({"EnemySpellCooldowns", "MobState", "CastbarIntelligence"}) do
        local module = BKA[name]
        if module and module.RemoveUnit then module:RemoveUnit(unit) end
    end
end

function CI:ClearNameplates()
    for unit in pairs(self.hosts) do self:RemoveUnit(unit) end
    for _, name in ipairs({"EnemySpellCooldowns", "MobState", "CastbarIntelligence"}) do
        local module = BKA[name]
        if module and module.Clear then module:Clear() end
    end
end

function CI:Clear()
    self:ClearNameplates()
    if BKA.PartyFrameTargets then BKA.PartyFrameTargets:Clear() end
    if self.frame then self.frame:Hide() end
end

function CI:RefreshEnabled()
    if not self.frame then return end
    local db = BKA.db
    local enabled = BKA.active and db and db.enabled ~= false and
        ((db.enemySpellCooldowns and db.enemySpellCooldowns.enabled) or
         (db.partyFrameTargets and db.partyFrameTargets.enabled) or
         (db.mobState and db.mobState.enabled) or
         (db.castbarIntelligence and db.castbarIntelligence.enabled))
    self.frame:SetShown(enabled and true or false)
    if not enabled then self:Clear() end
end

function CI:SettingsChanged(path)
    local section = path and string.match(path, "^([^.]+)%.")
    local modules = {
        enemySpellCooldowns = "EnemySpellCooldowns", mobState = "MobState",
        partyFrameTargets = "PartyFrameTargets", castbarIntelligence = "CastbarIntelligence",
    }
    local module = section and BKA[modules[section] or ""]
    if module then
        if module.SettingsChanged then module:SettingsChanged()
        elseif module.Clear then module:Clear() end
        if section == "partyFrameTargets" and module.Refresh then module:Refresh() end
    elseif not section then
        self:Clear()
        if BKA.PartyFrameTargets then BKA.PartyFrameTargets:Refresh() end
    end
    self:RefreshEnabled()
    if section == "autoMarkers" and BKA.AutoMarkers then BKA.AutoMarkers:SettingsChanged() end
end

function CI:Initialize()
    if self.frame then return end
    local frame = CreateFrame("Frame")
    self.frame = frame
    for _, event in ipairs({"UNIT_AURA", "UNIT_HEALTH", "UNIT_POWER_UPDATE", "UNIT_POWER_FREQUENT", "UNIT_ABSORB_AMOUNT_CHANGED", "UNIT_TARGET", "GROUP_ROSTER_UPDATE", "ADDON_LOADED", "PLAYER_REGEN_ENABLED"}) do
        -- Some Firestorm builds omit events as well as API functions.
        pcall(frame.RegisterEvent, frame, event)
    end
    frame:SetScript("OnEvent", function(_, event, unit)
        if not BKA.active then return end
        if BKA.MobState and BKA.MobState.OnEvent then BKA.MobState:OnEvent(event, unit) end
    end)
    frame:SetScript("OnUpdate", function(_, elapsed)
        CI.elapsed = CI.elapsed + elapsed
        if CI.elapsed < 0.10 then return end
        CI.elapsed = 0
        local now = GetTime()
        for unit, host in pairs(CI.hosts) do
            if UnitGUID(unit) ~= host.ownerGUID or not UnitExists(unit) or UnitIsDeadOrGhost(unit) then CI:RemoveUnit(unit) end
        end
        if BKA.EnemySpellCooldowns then BKA.EnemySpellCooldowns:Refresh(now) end
        if BKA.PartyFrameTargets then BKA.PartyFrameTargets:Update(now) end
        if BKA.MobState then BKA.MobState:Update(now) end
        if BKA.CastbarIntelligence then BKA.CastbarIntelligence:Update(now) end
    end)
    frame:Hide()
end
