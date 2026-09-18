local BKA = BFAKeyAlerts
local Alerts = {}
BKA.Alerts = Alerts

local MAX_ROWS = 7
local BAR_HEIGHT, ICON_SIZE, ROW_GAP = 45, 64, 7

local function alertRank(ability, state, personal, persistent)
    local severity = BKA.severityRank[ability and ability.severity] or 1
    if personal and state == "ACTIVE" then return 7000 + severity end
    if state == "ACTIVE" and severity >= BKA.severityRank.CRITICAL then return 6000 + severity end
    if state == "ACTIVE" and severity >= BKA.severityRank.HIGH then return 5000 + severity end
    if state == "ACTIVE" and not persistent then return 4000 + severity end
    if persistent then return 3000 + severity end
    if state == "PREWARN" then return 2000 + severity end
    return 1000 + severity
end

local function createGlow(row)
    local glow = CreateFrame("Frame", nil, row)
    glow:SetAllPoints()
    glow:SetFrameLevel(row:GetFrameLevel() + 8)
    glow.lines = {}
    local points = {
        {"TOPLEFT", "TOPRIGHT", 3, 0, 0, -3},
        {"BOTTOMLEFT", "BOTTOMRIGHT", 3, 0, 0, 3},
        {"TOPLEFT", "BOTTOMLEFT", 0, -3, 3, 0},
        {"TOPRIGHT", "BOTTOMRIGHT", 0, 3, -3, 0},
    }
    for i, p in ipairs(points) do
        local texture = glow:CreateTexture(nil, "OVERLAY")
        texture:SetColorTexture(1, 0.85, 0.15, 0.95)
        texture:SetPoint(p[1], glow, p[1], p[3], p[4])
        texture:SetPoint(p[2], glow, p[2], p[5], p[6])
        glow.lines[i] = texture
    end
    glow.anim = glow:CreateAnimationGroup()
    glow.anim:SetLooping("BOUNCE")
    local alpha = glow.anim:CreateAnimation("Alpha")
    alpha:SetFromAlpha(0.35)
    alpha:SetToAlpha(1)
    alpha:SetDuration(0.55)
    glow:Hide()
    return glow
end

local function createRow(anchor, index)
    local row = CreateFrame("Frame", nil, anchor)
    row:SetFrameStrata("HIGH")
    row:Hide()

    row.bar = CreateFrame("Frame", nil, row)
    row.bar:SetAllPoints()
    row.bar.background = row.bar:CreateTexture(nil, "BACKGROUND")
    row.bar.background:SetAllPoints()
    row.bar.icon = row.bar:CreateTexture(nil, "ARTWORK")
    row.bar.icon:SetSize(39, 39)
    row.bar.icon:SetPoint("LEFT", 8, 0)
    row.bar.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    row.bar.accent = row.bar:CreateTexture(nil, "ARTWORK")
    row.bar.accent:SetPoint("TOPLEFT")
    row.bar.accent:SetPoint("BOTTOMLEFT")
    row.bar.accent:SetWidth(5)
    row.bar.action = row.bar:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
    row.bar.action:SetPoint("LEFT", row.bar.icon, "RIGHT", 9, 7)
    row.bar.youBadge = CreateFrame("Frame", nil, row.bar)
    row.bar.youBadge:SetSize(54, 26)
    row.bar.youBadge:SetPoint("LEFT", row.bar.icon, "RIGHT", 8, 4)
    row.bar.youBadge.background = row.bar.youBadge:CreateTexture(nil, "BACKGROUND")
    row.bar.youBadge.background:SetAllPoints()
    row.bar.youBadge.background:SetColorTexture(0.95, 0.04, 0.02, 0.95)
    row.bar.youBadge.text = row.bar.youBadge:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
    row.bar.youBadge.text:SetPoint("CENTER")
    row.bar.youBadge.text:SetText("YOU")
    row.bar.youBadge.text:SetTextColor(1, 1, 0.2)
    row.bar.youBadge:Hide()
    row.bar.detail = row.bar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.bar.detail:SetPoint("LEFT", row.bar.icon, "RIGHT", 9, -10)
    row.bar.detail:SetPoint("RIGHT", -52, 0)
    row.bar.detail:SetJustifyH("LEFT")
    row.bar.detail:SetWordWrap(false)
    row.bar.countdown = row.bar:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    row.bar.countdown:SetPoint("RIGHT", -8, 0)
    row.bar.progress = CreateFrame("StatusBar", nil, row.bar)
    row.bar.progress:SetPoint("BOTTOMLEFT", 5, 0)
    row.bar.progress:SetPoint("BOTTOMRIGHT", -5, 0)
    row.bar.progress:SetHeight(3)
    row.bar.progress:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")

    row.icon = CreateFrame("Frame", nil, row)
    row.icon:SetAllPoints()
    row.icon.background = row.icon:CreateTexture(nil, "BACKGROUND")
    row.icon.background:SetAllPoints()
    row.icon.texture = row.icon:CreateTexture(nil, "ARTWORK")
    row.icon.texture:SetPoint("TOPLEFT", 4, -4)
    row.icon.texture:SetPoint("BOTTOMRIGHT", -4, 4)
    row.icon.texture:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    row.icon.cooldown = CreateFrame("Cooldown", nil, row.icon, "CooldownFrameTemplate")
    row.icon.cooldown:SetPoint("TOPLEFT", row.icon.texture)
    row.icon.cooldown:SetPoint("BOTTOMRIGHT", row.icon.texture)
    row.icon.action = row.icon:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    row.icon.action:SetPoint("BOTTOM", row.icon, "TOP", 0, 2)
    row.icon.youBadge = row.icon:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
    row.icon.youBadge:SetPoint("BOTTOM", row.icon.action, "TOP", 0, 1)
    row.icon.youBadge:SetText("YOU")
    row.icon.youBadge:SetTextColor(1, 0.12, 0.05)
    row.icon.youBadge:Hide()
    row.icon.countdown = row.icon:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
    row.icon.countdown:SetPoint("CENTER")
    row.icon.detail = row.icon:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.icon.detail:SetPoint("TOP", row.icon, "BOTTOM", 0, -2)
    row.icon.detail:SetWidth(110)
    row.icon.detail:SetWordWrap(false)

    row.glow = createGlow(row)
    row.index = index
    return row
end

function Alerts:Initialize()
    if self.rows then return end
    local layout = BKA.db.layout
    self.anchor = CreateFrame("Frame", "BFAKeyAlertsAnchor", UIParent)
    self.anchor:SetPoint(layout.point, UIParent, layout.relativePoint, layout.x, layout.y)
    self.anchor:SetScale(layout.scale)
    self.anchor:SetMovable(true)
    self.anchor:SetClampedToScreen(true)
    self.anchor:SetFrameStrata("HIGH")
    self.anchor:Show()
    self.anchor.guide = self.anchor:CreateTexture(nil, "BACKGROUND", nil, -1)
    self.anchor.guide:SetAllPoints()
    self.anchor.guide:SetColorTexture(0.08, 0.62, 1.00, 0.16)
    self.anchor.guide:Hide()
    self.anchor.guideText = self.anchor:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    self.anchor.guideText:SetPoint("BOTTOM", self.anchor, "TOP", 0, 18)
    self.anchor.guideText:SetText("BFA Key Alerts - drag")
    self.anchor.guideText:SetTextColor(0.25, 0.78, 1)
    self.anchor.guideText:Hide()
    self.anchor:SetScript("OnDragStart", function(frame) frame:StartMoving() end)
    self.anchor:SetScript("OnDragStop", function(frame)
        frame:StopMovingOrSizing()
        Alerts:SavePosition()
    end)
    self.rows = {}
    for i = 1, MAX_ROWS do self.rows[i] = createRow(self.anchor, i) end
    self:ApplyLayout()
end

function Alerts:SavePosition()
    local point, _, relativePoint, x, y = self.anchor:GetPoint(1)
    local layout = BKA.db.layout
    layout.point, layout.relativePoint = point or "TOP", relativePoint or point or "TOP"
    layout.x, layout.y = math.floor((x or 0) + 0.5), math.floor((y or 0) + 0.5)
end

function Alerts:ApplyLayout()
    if not self.anchor then return end
    local layout = BKA.db.layout
    local iconStyle = BKA.db.alertStyle == "ICON"
    local width, height = iconStyle and ICON_SIZE or layout.width, iconStyle and ICON_SIZE or BAR_HEIGHT
    self.anchor:ClearAllPoints()
    self.anchor:SetPoint(layout.point, UIParent, layout.relativePoint, layout.x, layout.y)
    self.anchor:SetScale(layout.scale)
    self.anchor:SetSize(width, MAX_ROWS * height + (MAX_ROWS - 1) * ROW_GAP)
    for i, row in ipairs(self.rows) do
        row:SetSize(width, height)
        row:ClearAllPoints()
        row:SetPoint("TOP", self.anchor, "TOP", 0, -((i - 1) * (height + ROW_GAP)))
        row.bar:SetShown(not iconStyle)
        row.icon:SetShown(iconStyle)
    end
    self:SortRows()
end

function Alerts:SetUnlocked(unlocked)
    self:Initialize()
    self.unlocked = unlocked and true or false
    self.anchor:EnableMouse(self.unlocked)
    self.anchor:SetFrameStrata(self.unlocked and "DIALOG" or "HIGH")
    if self.unlocked then
        self.anchor:RegisterForDrag("LeftButton")
        self.anchor.guide:Show()
        self.anchor.guideText:Show()
    else
        self.anchor:RegisterForDrag()
        self.anchor.guide:Hide()
        self.anchor.guideText:Hide()
    end
    if BKA.Options and BKA.Options.UpdateButtons then BKA.Options:UpdateButtons() end
end

function Alerts:Release(row)
    row:Hide()
    row.key, row.preview, row.ownerUnit, row.ownerGeneration = nil, nil, nil, nil
    row.sourceGUID, row.spellID, row.baseAction, row.spellName = nil, nil, nil, nil
    row.alertState, row.stackAmount, row.persistent, row.personal = nil, nil, nil, nil
    row.targetConfidence, row.targetName, row.targetRole, row.targetIsPlayer, row.presentationTier = nil, nil, nil, nil, nil
    row.glow.anim:Stop()
    row.glow:Hide()
    row:SetAlpha(1)
    row.bar.icon:SetDesaturated(false)
    row.icon.texture:SetDesaturated(false)
    row.icon.cooldown:SetCooldown(0, 0)
    row.bar.youBadge:Hide()
    row.icon.youBadge:Hide()
end

function Alerts:SortRows()
    if not self.rows or not self.anchor then return end
    local ordered = {}
    for _, row in ipairs(self.rows) do ordered[#ordered + 1] = row end
    table.sort(ordered, function(a, b)
        local aShown, bShown = a:IsShown(), b:IsShown()
        if aShown ~= bShown then return aShown end
        if not aShown then return a.index < b.index end
        if (a.rank or 0) ~= (b.rank or 0) then return (a.rank or 0) > (b.rank or 0) end
        if (a.expires or math.huge) ~= (b.expires or math.huge) then return (a.expires or math.huge) < (b.expires or math.huge) end
        return a.index < b.index
    end)
    local height = BKA.db.alertStyle == "ICON" and ICON_SIZE or BAR_HEIGHT
    for position, row in ipairs(ordered) do
        row:ClearAllPoints()
        row:SetPoint("TOP", self.anchor, "TOP", 0, -((position - 1) * (height + ROW_GAP)))
    end
end

function Alerts:ApplyPersonalStyle(row, personal, color)
    row.personal = personal and true or false
    row.bar.youBadge:SetShown(row.personal)
    row.icon.youBadge:SetShown(row.personal)
    row.bar.action:ClearAllPoints()
    if row.personal then
        row.bar.action:SetPoint("LEFT", row.bar.youBadge, "RIGHT", 8, 7)
        row.bar.background:SetColorTexture(0.42, 0.015, 0.01, 0.97)
        row.icon.background:SetColorTexture(0.42, 0.015, 0.01, 0.97)
        row.bar.accent:SetColorTexture(1, 0.85, 0.05, 1)
        row.bar.action:SetTextColor(1, 0.92, 0.18)
        row.icon.action:SetTextColor(1, 0.92, 0.18)
        row.glow:Show()
        if not row.glow.anim:IsPlaying() then row.glow.anim:Play() end
    else
        row.bar.action:SetPoint("LEFT", row.bar.icon, "RIGHT", 9, 7)
        row.bar.background:SetColorTexture(color[1] * 0.10, color[2] * 0.10, color[3] * 0.10, 0.92)
        row.icon.background:SetColorTexture(color[1] * 0.10, color[2] * 0.10, color[3] * 0.10, 0.92)
        row.bar.accent:SetColorTexture(color[1], color[2], color[3], 1)
        row.bar.action:SetTextColor(color[1], color[2], color[3])
        row.icon.action:SetTextColor(color[1], color[2], color[3])
        row.glow.anim:Stop()
        row.glow:Hide()
    end
end

function Alerts:ApplyPresentation(row, color)
    local action = string.gsub(row.baseAction or "CAST", "_", " ")
    local state = row.alertState or "ACTIVE"
    local directional = row.baseAction == "FRONTAL" or row.baseAction == "CLEAVE"
    local directionalAction = row.baseAction == "CLEAVE" and "CLEAVE" or "FRONTAL"
    local context = {
        alertState = state,
        targetName = row.targetName,
        targetRole = row.targetRole,
        targetConfidence = row.targetConfidence,
        isPlayer = row.targetIsPlayer,
    }
    local personal = row.targetIsPlayer and row.targetConfidence == "CONFIRMED"
    if directional and not BKA:IsTargetBasedFrontal(row.ability) then personal = false end
    if row.stackAmount then action = action .. " - x" .. tostring(row.stackAmount) end

    local barDetail = row.spellName or ""
    local iconDetail = row.spellName or ""
    local frontalState
    if state == "PREWARN" then
        action = directional and (directionalAction .. " SOON") or ("SOON - " .. action)
    elseif directional then
        action = personal and ("YOU - " .. directionalAction) or directionalAction
        local targetLabel = BKA:GetFrontalTargetLabel(row.ability, context)
        frontalState = BKA:GetFrontalStateLabel(row.ability, context)
        local metadata = {}
        if targetLabel and targetLabel ~= "YOU" then metadata[#metadata + 1] = "-> " .. targetLabel end
        if frontalState then metadata[#metadata + 1] = frontalState end
        if #metadata > 0 then
            local compact = table.concat(metadata, "  -  ")
            barDetail = barDetail ~= "" and (barDetail .. "  -  " .. compact) or compact
            iconDetail = table.concat(metadata, " - ")
        end
    else
        if personal and state == "ACTIVE" then action = "YOU - " .. action end
        if row.targetName and row.targetName ~= "" then barDetail = barDetail .. "  -  " .. row.targetName end
        if personal then iconDetail = row.spellName or "YOU" end
    end

    row.bar.action:SetText(action)
    row.icon.action:SetText(action)
    row.bar.detail:SetText(barDetail)
    row.icon.detail:SetText(iconDetail)
    self:ApplyPersonalStyle(row, personal and state ~= "PREWARN", color)
    if frontalState == "TRACKING" and state == "ACTIVE" and not personal then
        for _, line in ipairs(row.glow.lines or {}) do line:SetColorTexture(1, 0.42, 0.06, 0.85) end
        row.glow:Show()
        if not row.glow.anim:IsPlaying() then row.glow.anim:Play() end
    elseif personal then
        for _, line in ipairs(row.glow.lines or {}) do line:SetColorTexture(1, 0.85, 0.15, 0.95) end
    end
    row.personal = personal and state ~= "PREWARN"
end

function Alerts:HideCastPresentation(sourceGUID, identityKeys)
    local removed = false
    for _, row in ipairs(self.rows or {}) do
        local key = row.spellID and tostring(sourceGUID) .. ":" .. tostring(row.spellID)
        if row:IsShown() and not row.preview and not row.ownerGeneration and row.sourceGUID == sourceGUID and key and identityKeys[key] then
            self:Release(row)
            removed = true
        end
    end
    if removed then self:SortRows(); self:UpdateDriver() end
    return removed
end

function Alerts:Acquire(rank, key)
    local lowest
    for _, row in ipairs(self.rows) do
        if row.key == key then return row end
        if not row:IsShown() then return row end
        if not lowest or row.rank < lowest.rank or (row.rank == lowest.rank and row.expires > lowest.expires) then lowest = row end
    end
    if lowest and rank >= lowest.rank then self:Release(lowest); return lowest end
end

function Alerts:GetKey(ability, context)
    local key = tostring(ability.id) .. ":" .. tostring(context.sourceGUID or "")
    if (ability.targetBehavior == "DESTINATION" or ability.target == "DESTINATION") and context.destGUID then key = key .. ":" .. tostring(context.destGUID) end
    return key
end

function Alerts:Hide(key, ownerGeneration)
    for _, row in ipairs(self.rows or {}) do
        if row.key == key and (not ownerGeneration or row.ownerGeneration == ownerGeneration) then
            self:Release(row)
            self:SortRows()
            self:UpdateDriver()
            return true
        end
    end
end

function Alerts:HidePrewarning(abilityID, sourceGUID)
    local removed = false
    for _, row in ipairs(self.rows or {}) do
        if row:IsShown() and row.alertState == "PREWARN" and row.ability and row.ability.id == abilityID and (not sourceGUID or not row.sourceGUID or row.sourceGUID == sourceGUID) then
            self:Release(row)
            removed = true
        end
    end
    if removed then self:SortRows(); self:UpdateDriver() end
    return removed
end

function Alerts:Resync(key, ownerGeneration, startTime, endTime, texture)
    for _, row in ipairs(self.rows or {}) do
        if row.key == key and row.ownerGeneration == ownerGeneration then
            row.startTime, row.endTime, row.expires = startTime, endTime, endTime
            if texture then row.bar.icon:SetTexture(texture); row.icon.texture:SetTexture(texture) end
            row.icon.cooldown:SetCooldown(startTime, math.max(0.01, endTime - startTime))
            return true
        end
    end
end

function Alerts:SetTarget(key, ownerGeneration, targetName, isPlayer, targetConfidence, targetRole)
    for _, row in ipairs(self.rows or {}) do
        if row.key == key and row.ownerGeneration == ownerGeneration then
            row.targetName, row.targetRole, row.targetIsPlayer = targetName, targetRole, isPlayer and true or false
            row.targetConfidence = targetConfidence or "NONE"
            local personal = row.targetIsPlayer and row.targetConfidence == "CONFIRMED"
            if (row.baseAction == "FRONTAL" or row.baseAction == "CLEAVE") and not BKA:IsTargetBasedFrontal(row.ability) then personal = false end
            row.rank = alertRank(row.ability, row.alertState, personal, row.persistent)
            self:ApplyPresentation(row, BKA.colors[row.ability.severity] or BKA.colors.LOW)
            self:SortRows()
            return true
        end
    end
end

function Alerts:Show(ability, context)
    context = context or {}
    local normalizedAction = BKA:NormalizeAction(context.action or ability.primaryAction or ability.action, ability.mechanic)
    local personal = BKA:IsConfirmedPersonal(context)
    if (normalizedAction == "FRONTAL" or normalizedAction == "CLEAVE") and not BKA:IsTargetBasedFrontal(ability) then personal = false end
    if context.alertState == "PREWARN" then personal = false end
    local shouldCenter, promoted = BKA:ShouldCenterAbility(ability, context.action, context)
    if context.forceCenter then shouldCenter = true end
    if (not BKA.db.enabled and not context.preview) or (not context.preview and not shouldCenter) then return end
    if promoted and not context.safetyNetCounted then
        BKA.diagnostics.centerSafetyNetPromotions = BKA.diagnostics.centerSafetyNetPromotions + 1
        context.safetyNetCounted = true
    end
    if not context.preview and BKA.RoleCenterAllows and not BKA:RoleCenterAllows(ability, personal, context.action) then return end
    -- Center visibility is independent from combat audio. If a caller delegates
    -- sound playback to Alerts:Show, preserve that sound even when the visual
    -- alert layer is disabled. Callers that already played audio set soundHandled.
    if not context.preview and BKA.db.showAlerts == false then
        if ability.sound and not context.silent and not context.soundHandled then
            BKA.Sounds:PlayMechanic(normalizedAction, {
                alertState = context.alertState or "ACTIVE", isPlayer = personal, targetConfidence = context.targetConfidence,
                personalFatal = personal and ability.severity == "CRITICAL", criticalPersonal = personal and ability.severity == "CRITICAL",
                sourceGUID = context.sourceGUID, spellID = context.spellID or ability.id, key = context.key,
            })
        end
        return
    end
    self:Initialize()
    local state = context.alertState or "ACTIVE"
    local rank = alertRank(ability, state, personal, context.persistent)
    local key = context.key or self:GetKey(ability, context)
    local row = self:Acquire(rank, key)
    if not row then return end
    local spellName = context.spellName or GetSpellInfo(context.spellID or ability.id) or ("Spell " .. tostring(ability.id))
    local baseAction = normalizedAction
    local color = BKA.colors[ability.severity] or BKA.colors.LOW
    local texture = BKA:ResolveIcon(ability, context)
    row.key, row.rank, row.ability = key, rank, ability
    row.preview, row.alertState = context.preview or false, state
    row.stackAmount, row.persistent = context.stackAmount, context.persistent and true or false
    row.targetConfidence, row.presentationTier = context.targetConfidence or "NONE", ability.presentationTier
    row.targetName, row.targetRole, row.targetIsPlayer = context.targetName, context.targetRole, context.isPlayer and true or false
    row.ownerUnit, row.ownerGeneration = context.ownerUnit, context.ownerGeneration
    row.sourceGUID = context.sourceGUID
    row.spellID = context.spellID or ability.id
    row.baseAction, row.spellName = baseAction, spellName
    row.startTime = context.startTime or GetTime()
    row.endTime = context.endTime
    local severityRank = BKA.severityRank[ability.severity] or 1
    row.expires = context.persistent and math.huge or context.endTime or (GetTime() + (context.duration or (severityRank >= 3 and 3.2 or 2.2)))
    row.bar.icon:SetTexture(texture)
    row.icon.texture:SetTexture(texture)
    row.bar.progress:SetStatusBarColor(color[1], color[2], color[3], 1)
    local prewarn = state == "PREWARN"
    row:SetAlpha(prewarn and 0.48 or 1)
    row.bar.icon:SetDesaturated(prewarn)
    row.icon.texture:SetDesaturated(prewarn)
    self:ApplyPresentation(row, color)
    if row.endTime then row.icon.cooldown:SetCooldown(row.startTime, math.max(0.01, row.endTime - row.startTime)) else row.icon.cooldown:SetCooldown(0, 0) end
    row:Show()
    if ability.sound and not context.silent and not context.soundHandled then
        BKA.Sounds:PlayMechanic(baseAction, {
            alertState = state, isPlayer = personal, targetConfidence = context.targetConfidence,
            personalFatal = personal and ability.severity == "CRITICAL",
            criticalPersonal = personal and ability.severity == "CRITICAL",
            sourceGUID = context.sourceGUID, spellID = context.spellID or ability.id,
            key = context.key, forcePreview = context.forcePreview,
        })
    end
    self:SortRows()
    self:UpdateDriver()
end

function Alerts:ShowPreview(withSound)
    self:Initialize()
    self:HidePreview()
    self:SetUnlocked(true)
    local now = GetTime()
    local playerName = UnitName("player") or "Player"
    local previews = {
        { id = 257337, action = "FRONTAL", severity = "HIGH", spell = "Fixed frontal", frontalBehavior = "FIXED_FORWARD" },
        { id = 264923, action = "FRONTAL", severity = "HIGH", spell = "Frontal on teammate", frontalBehavior = "SNAPSHOT_TARGET", target = "Tank-Realm", targetRole = "TANK", confirmed = true },
        { id = 264923, action = "FRONTAL", severity = "CRITICAL", spell = "Personal locked frontal", frontalBehavior = "SNAPSHOT_TARGET", target = playerName, personal = true, confirmed = true },
        { id = 258864, action = "FRONTAL", severity = "CRITICAL", spell = "Personal tracking frontal", frontalBehavior = "TRACK_TARGET", target = playerName, personal = true, confirmed = true },
        { id = 258864, action = "FRONTAL", severity = "HIGH", spell = "Frontal prediction", frontalBehavior = "TRACK_TARGET", state = "PREWARN" },
        { id = 255371, action = "KICK", severity = "HIGH", spell = "Active interrupt" },
        { id = 269972, action = "AOE", severity = "HIGH", spell = "Group damage" },
    }
    for index, preview in ipairs(previews) do
        self:Show({ id = preview.id, action = preview.action, mechanic = preview.action, severity = preview.severity, center = true, sound = false, role = "ALL", frontalBehavior = preview.frontalBehavior }, {
            key = "preview:" .. index, spellName = preview.spell, targetName = preview.target, targetRole = preview.targetRole,
            isPlayer = preview.personal, startTime = now, endTime = now + 30 - index,
            targetConfidence = preview.confirmed and "CONFIRMED" or "NONE",
            alertState = preview.state or "ACTIVE",
            preview = true, silent = true,
        })
    end
    if withSound then
        local actions = { "FRONTAL", "KICK", "PREWARN" }
        for index, action in ipairs(actions) do
            C_Timer.After((index - 1) * 1.0, function()
                if Alerts.previewVisible then BKA.Sounds:Preview(action) end
            end)
        end
    end
    self.previewVisible = true
end

function Alerts:HidePreview()
    for _, row in ipairs(self.rows or {}) do if row.preview then self:Release(row) end end
    self.previewVisible = false
    self:SortRows()
    self:UpdateDriver()
end

function Alerts:UpdateDriver()
    local any = false
    for _, row in ipairs(self.rows or {}) do if row:IsShown() then any = true break end end
    BKA.eventFrame:SetScript("OnUpdate", any and function() Alerts:OnUpdate() end or nil)
end

function Alerts:OnUpdate()
    local now, any, anyPreview, released = GetTime(), false, false, false
    for _, row in ipairs(self.rows) do
        if row:IsShown() then
            if now >= row.expires then
                if row.ownerUnit and row.ownerGeneration and BKA.ActiveCasts then
                    BKA.ActiveCasts:Expire(row.ownerUnit, row.ownerGeneration)
                else
                    self:Release(row)
                    released = true
                end
            else
                any, anyPreview = true, anyPreview or row.preview
                if row.endTime then
                    local remaining = math.max(0, row.endTime - now)
                    local duration = math.max(0.01, row.endTime - row.startTime)
                    row.bar.countdown:SetFormattedText("%.1f", remaining)
                    row.icon.countdown:SetFormattedText("%.1f", remaining)
                    row.bar.progress:SetMinMaxValues(0, duration)
                    row.bar.progress:SetValue(remaining)
                    row.bar.progress:Show()
                elseif row.stackAmount then
                    row.bar.countdown:SetText("x" .. tostring(row.stackAmount))
                    row.icon.countdown:SetText("x" .. tostring(row.stackAmount))
                    row.bar.progress:Hide()
                else
                    row.bar.countdown:SetText("")
                    row.icon.countdown:SetText("")
                    row.bar.progress:Hide()
                end
            end
        end
    end
    if released then self:SortRows() end
    if not any then BKA.eventFrame:SetScript("OnUpdate", nil) end
    if self.previewVisible and not anyPreview then
        self.previewVisible = false
        if BKA.Options and BKA.Options.UpdateButtons then BKA.Options:UpdateButtons() end
    end
end

function Alerts:Clear()
    for _, row in ipairs(self.rows or {}) do self:Release(row) end
    self.previewVisible = false
    BKA.eventFrame:SetScript("OnUpdate", nil)
end
