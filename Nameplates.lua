local BKA = BFAKeyAlerts
local Nameplates = { overlays = {}, freeOverlays = {} }
BKA.Nameplates = Nameplates

local DEFAULT_LIFETIME = 2.2
local OVERLAY_WIDTH = 132
local OVERLAY_HEIGHT = 31
local OVERLAY_GAP = 3
local CLICK_PADDING = 4
local HOVER_SCALE = 1.08
local HOVER_CHECK_INTERVAL = 0.03
local CIRCLE_SIZE = 104
local CIRCLE_PULSE_SIZE = 126
local CIRCLE_ICON_SIZE = 56
local SQUARE_SIZE = 52
local CONTROL_BADGE_WIDTH = 42
local CONTROL_BADGE_HEIGHT = 16
local INFESTED_BADGE_SIZE = 24

local function clickAPIAvailable()
    return C_NamePlate
        and C_NamePlate.GetNamePlateEnemyClickThrough
        and C_NamePlate.SetNamePlateEnemyClickThrough
        and C_NamePlate.GetNamePlateEnemyPreferredClickInsets
        and C_NamePlate.SetNamePlateEnemyPreferredClickInsets
end

function Nameplates:CaptureClickTargetingDefaults()
    if self.clickDefaultsCaptured then return true end
    if not clickAPIAvailable() then return false end

    local left, right, top, bottom = C_NamePlate.GetNamePlateEnemyPreferredClickInsets()
    local width = nil
    if C_NamePlate.GetNamePlateEnemySize then
        width = C_NamePlate.GetNamePlateEnemySize()
    end
    self.clickDefaults = {
        clickThrough = C_NamePlate.GetNamePlateEnemyClickThrough() and true or false,
        left = tonumber(left) or 0,
        right = tonumber(right) or 0,
        top = tonumber(top) or 0,
        bottom = tonumber(bottom) or 0,
        width = tonumber(width),
    }
    self.clickDefaultsCaptured = true
    return true
end

function Nameplates:GetDesiredClickInsets()
    local defaults = self.clickDefaults or {}
    local nativeWidth = defaults.width or OVERLAY_WIDTH
    local horizontalExtension = math.max(0, (OVERLAY_WIDTH - nativeWidth) * 0.5) + CLICK_PADDING
    local topExtension = math.max(OVERLAY_HEIGHT, CIRCLE_SIZE + 10, SQUARE_SIZE + 10) + OVERLAY_GAP + CLICK_PADDING

    -- Negative insets expand the preferred native nameplate click region.
    -- Preserve a larger click region if another nameplate addon already configured one.
    local left = math.min(tonumber(defaults.left) or 0, -horizontalExtension)
    local right = math.min(tonumber(defaults.right) or 0, -horizontalExtension)
    local top = math.min(tonumber(defaults.top) or 0, -topExtension)
    local bottom = tonumber(defaults.bottom) or 0
    return left, right, top, bottom
end

function Nameplates:RefreshClickTargeting()
    if not self:CaptureClickTargetingDefaults() then
        self.clickTargetingApplied = false
        return false
    end

    local enabled = BKA.db and BKA.db.enabled ~= false and BKA.db.showNameplates ~= false and BKA.db.clickableNameplateAlerts ~= false
    if enabled then
        local left, right, top, bottom = self:GetDesiredClickInsets()
        C_NamePlate.SetNamePlateEnemyClickThrough(false)
        C_NamePlate.SetNamePlateEnemyPreferredClickInsets(left, right, top, bottom)
        self.appliedClickInsets = { left, right, top, bottom }
        self.clickTargetingApplied = true
    else
        local defaults = self.clickDefaults
        C_NamePlate.SetNamePlateEnemyClickThrough(defaults.clickThrough)
        C_NamePlate.SetNamePlateEnemyPreferredClickInsets(defaults.left, defaults.right, defaults.top, defaults.bottom)
        self.appliedClickInsets = nil
        self.clickTargetingApplied = false
    end
    return self.clickTargetingApplied
end

function Nameplates:EnsureClickTargeting()
    if BKA.db and BKA.db.enabled ~= false and BKA.db.showNameplates ~= false and BKA.db.clickableNameplateAlerts ~= false then
        return self:RefreshClickTargeting()
    end
    return false
end

function Nameplates:PrintClickTargetingStatus()
    if not clickAPIAvailable() then
        BKA:Print("plateclick: BFA nameplate click API unavailable")
        return
    end
    self:CaptureClickTargetingDefaults()
    local left, right, top, bottom = C_NamePlate.GetNamePlateEnemyPreferredClickInsets()
    BKA:Print("plateclick: enabled=" .. tostring(BKA.db and BKA.db.clickableNameplateAlerts ~= false) ..
        ", applied=" .. tostring(self.clickTargetingApplied == true) ..
        ", clickThrough=" .. tostring(C_NamePlate.GetNamePlateEnemyClickThrough()) ..
        ", insets=" .. string.format("%.1f/%.1f/%.1f/%.1f", tonumber(left) or 0, tonumber(right) or 0, tonumber(top) or 0, tonumber(bottom) or 0))
end

local function priority(action, severity, persistent)
    local rank = BKA.severityRank[severity] or 1
    if action == "STOP" or action == "CC" then return 800 + rank end
    if action == "KICK" then return 700 + rank end
    if action == "YOU" or string.find(action or "", "YOU", 1, true) then return 650 + rank end
    if action == "FRONTAL" or action == "AOE" or action == "CLEAVE" then return 560 + rank end
    if action == "GTFO" or action == "TURN" or action == "MOVE" or action == "MOVE_MOBS" or action == "MOVE MOBS" or action == "DODGE" or action == "DEF" then return 500 + rank end
    if persistent then return 100 + rank end
    return 300 + rank
end

local function createOverlay(plate)
    local overlay = CreateFrame("Frame", nil, plate)
    overlay:SetSize(OVERLAY_WIDTH, OVERLAY_HEIGHT)
    overlay:SetPoint("BOTTOM", plate, "TOP", 0, 3)
    overlay:SetFrameStrata("HIGH")
    overlay:EnableMouse(false)
    overlay.background = overlay:CreateTexture(nil, "BACKGROUND")
    overlay.background:SetAllPoints()
    overlay.icon = overlay:CreateTexture(nil, "ARTWORK")
    overlay.icon:SetSize(23, 23)
    overlay.icon:SetPoint("LEFT", 1, 0)
    overlay.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    overlay.label = overlay:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    overlay.label:SetJustifyH("LEFT")
    overlay.detail = overlay:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    overlay.detail:SetJustifyH("LEFT")
    overlay.countdown = overlay:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    overlay.countdown:SetPoint("RIGHT", -4, 0)
    overlay.circle = CreateFrame("Frame", nil, overlay)
    overlay.circle:SetSize(CIRCLE_SIZE, CIRCLE_SIZE)
    overlay.circle:SetPoint("CENTER", overlay, "CENTER", 0, 0)

    -- Custom AOE marker. Blizzard's minimap tracking border has large transparent
    -- padding, so its apparent circle stays tiny even when the region grows.
    -- These addon textures have no dead space: the rendered ring is the real size.
    overlay.circle.shadow = overlay.circle:CreateTexture(nil, "BACKGROUND")
    overlay.circle.shadow:SetTexture("Interface\\AddOns\\BFAKeyAlerts\\Media\\aoe_ring.tga")
    overlay.circle.shadow:SetSize(CIRCLE_SIZE + 5, CIRCLE_SIZE + 5)
    overlay.circle.shadow:SetPoint("CENTER", 0, -1)
    overlay.circle.shadow:SetVertexColor(0, 0, 0, 0.82)

    overlay.circle.icon = overlay.circle:CreateTexture(nil, "ARTWORK")
    overlay.circle.icon:SetSize(CIRCLE_ICON_SIZE, CIRCLE_ICON_SIZE)
    overlay.circle.icon:SetPoint("CENTER", 0, 1)
    overlay.circle.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    overlay.circle.ring = overlay.circle:CreateTexture(nil, "OVERLAY")
    overlay.circle.ring:SetTexture("Interface\\AddOns\\BFAKeyAlerts\\Media\\aoe_ring.tga")
    overlay.circle.ring:SetSize(CIRCLE_SIZE, CIRCLE_SIZE)
    overlay.circle.ring:SetPoint("CENTER", 0, 0)

    -- Only the outer halo breathes. The icon and main ring stay perfectly stable,
    -- keeping the marker readable in dense high-key pulls.
    overlay.circle.pulseFrame = CreateFrame("Frame", nil, overlay.circle)
    overlay.circle.pulseFrame:SetSize(CIRCLE_PULSE_SIZE, CIRCLE_PULSE_SIZE)
    overlay.circle.pulseFrame:SetPoint("CENTER", 0, 0)
    overlay.circle.pulse = overlay.circle.pulseFrame:CreateTexture(nil, "BACKGROUND")
    overlay.circle.pulse:SetTexture("Interface\\AddOns\\BFAKeyAlerts\\Media\\aoe_pulse.tga")
    overlay.circle.pulse:SetAllPoints()
    overlay.circle.pulse:SetBlendMode("ADD")
    overlay.circle.pulseFrame.anim = overlay.circle.pulseFrame:CreateAnimationGroup()
    overlay.circle.pulseFrame.anim:SetLooping("BOUNCE")
    local circleAlpha = overlay.circle.pulseFrame.anim:CreateAnimation("Alpha")
    circleAlpha:SetFromAlpha(0.16)
    circleAlpha:SetToAlpha(0.62)
    circleAlpha:SetDuration(0.36)

    overlay.circle.countdown = overlay.circle:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    overlay.circle.countdown:SetPoint("CENTER", 0, 0)
    overlay.circle.countdown:SetShadowOffset(1, -1)
    overlay.circle.countdown:SetShadowColor(0, 0, 0, 1)
    overlay.circle.label = overlay.circle:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    overlay.circle.label:SetPoint("TOP", overlay.circle, "BOTTOM", 0, 5)
    overlay.circle.label:SetWidth(132)
    overlay.circle.label:SetJustifyH("CENTER")
    overlay.circle.label:SetShadowOffset(1, -1)
    overlay.circle.label:SetShadowColor(0, 0, 0, 1)
    overlay.circle:Hide()

    -- Geometry language: AOE = circle, FRONTAL/CLEAVE = square.
    -- The cast-control layer (KICK / CC) is rendered independently as a badge.
    overlay.square = CreateFrame("Frame", nil, overlay)
    overlay.square:SetSize(SQUARE_SIZE, SQUARE_SIZE)
    overlay.square:SetPoint("CENTER", overlay, "CENTER", 0, 0)
    overlay.square.background = overlay.square:CreateTexture(nil, "BACKGROUND")
    overlay.square.background:SetAllPoints()
    overlay.square.background:SetColorTexture(0.02, 0.02, 0.02, 0.92)
    overlay.square.icon = overlay.square:CreateTexture(nil, "ARTWORK")
    overlay.square.icon:SetSize(36, 36)
    overlay.square.icon:SetPoint("CENTER", 0, 1)
    overlay.square.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    overlay.square.lines = {}
    local squareEdges = {
        {"TOPLEFT", "TOPRIGHT", 2, 0, 0, -2},
        {"BOTTOMLEFT", "BOTTOMRIGHT", 2, 0, 0, 2},
        {"TOPLEFT", "BOTTOMLEFT", 0, -2, 2, 0},
        {"TOPRIGHT", "BOTTOMRIGHT", 0, 2, -2, 0},
    }
    for _, points in ipairs(squareEdges) do
        local line = overlay.square:CreateTexture(nil, "OVERLAY")
        line:SetPoint(points[1], overlay.square, points[1], points[3], points[4])
        line:SetPoint(points[2], overlay.square, points[2], points[5], points[6])
        overlay.square.lines[#overlay.square.lines + 1] = line
    end
    overlay.square.pulse = CreateFrame("Frame", nil, overlay.square)
    overlay.square.pulse:SetPoint("TOPLEFT", overlay.square, "TOPLEFT", -4, 4)
    overlay.square.pulse:SetPoint("BOTTOMRIGHT", overlay.square, "BOTTOMRIGHT", 4, -4)
    overlay.square.pulse.lines = {}
    for _, points in ipairs(squareEdges) do
        local line = overlay.square.pulse:CreateTexture(nil, "OVERLAY")
        line:SetPoint(points[1], overlay.square.pulse, points[1], points[3], points[4])
        line:SetPoint(points[2], overlay.square.pulse, points[2], points[5], points[6])
        overlay.square.pulse.lines[#overlay.square.pulse.lines + 1] = line
    end
    overlay.square.pulse.anim = overlay.square.pulse:CreateAnimationGroup()
    overlay.square.pulse.anim:SetLooping("BOUNCE")
    local squareAlpha = overlay.square.pulse.anim:CreateAnimation("Alpha")
    squareAlpha:SetFromAlpha(0.18)
    squareAlpha:SetToAlpha(0.95)
    squareAlpha:SetDuration(0.24)
    overlay.square.countdown = overlay.square:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    overlay.square.countdown:SetPoint("CENTER", 0, 0)
    overlay.square.label = overlay.square:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    overlay.square.label:SetPoint("TOP", overlay.square, "BOTTOM", 0, 4)
    overlay.square.label:SetWidth(118)
    overlay.square.label:SetJustifyH("CENTER")
    overlay.square:Hide()

    overlay.controlBadge = CreateFrame("Frame", nil, overlay)
    overlay.controlBadge:SetSize(CONTROL_BADGE_WIDTH, CONTROL_BADGE_HEIGHT)
    overlay.controlBadge:SetFrameLevel(overlay:GetFrameLevel() + 12)
    overlay.controlBadge.bg = overlay.controlBadge:CreateTexture(nil, "BACKGROUND")
    overlay.controlBadge.bg:SetAllPoints()
    overlay.controlBadge.bg:SetColorTexture(0.03, 0.03, 0.03, 0.96)
    overlay.controlBadge.text = overlay.controlBadge:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    overlay.controlBadge.text:SetPoint("CENTER", 0, 0)
    overlay.controlBadge.lines = {}
    for _, points in ipairs(squareEdges) do
        local line = overlay.controlBadge:CreateTexture(nil, "OVERLAY")
        line:SetPoint(points[1], overlay.controlBadge, points[1], points[3], points[4])
        line:SetPoint(points[2], overlay.controlBadge, points[2], points[5], points[6])
        overlay.controlBadge.lines[#overlay.controlBadge.lines + 1] = line
    end
    overlay.controlBadge.anim = overlay.controlBadge:CreateAnimationGroup()
    overlay.controlBadge.anim:SetLooping("BOUNCE")
    local badgeAlpha = overlay.controlBadge.anim:CreateAnimation("Alpha")
    badgeAlpha:SetFromAlpha(0.60)
    badgeAlpha:SetToAlpha(1)
    badgeAlpha:SetDuration(0.22)
    overlay.controlBadge:Hide()

    overlay.glow = CreateFrame("Frame", nil, overlay)
    overlay.glow:SetAllPoints()
    overlay.glow:SetFrameLevel(overlay:GetFrameLevel() + 5)
    overlay.glow.lines = {}
    local glowPoints = {
        {"TOPLEFT", "TOPRIGHT", 2, 0, 0, -2},
        {"BOTTOMLEFT", "BOTTOMRIGHT", 2, 0, 0, 2},
        {"TOPLEFT", "BOTTOMLEFT", 0, -2, 2, 0},
        {"TOPRIGHT", "BOTTOMRIGHT", 0, 2, -2, 0},
    }
    for _, points in ipairs(glowPoints) do
        local line = overlay.glow:CreateTexture(nil, "OVERLAY")
        line:SetColorTexture(1, 0.12, 0.04, 1)
        line:SetPoint(points[1], overlay.glow, points[1], points[3], points[4])
        line:SetPoint(points[2], overlay.glow, points[2], points[5], points[6])
        overlay.glow.lines[#overlay.glow.lines + 1] = line
    end
    overlay.glow.anim = overlay.glow:CreateAnimationGroup()
    overlay.glow.anim:SetLooping("BOUNCE")
    local alpha = overlay.glow.anim:CreateAnimation("Alpha")
    alpha:SetFromAlpha(0.2)
    alpha:SetToAlpha(1)
    alpha:SetDuration(0.32)
    overlay.glow:Hide()

    -- Dedicated Season 1 Infested marker. It is a sibling of the alert overlay, so
    -- it stays visible even when there is no active BKA cast alert and never covers
    -- the native nameplate.
    overlay.infestedMarker = CreateFrame("Frame", nil, plate)
    overlay.infestedMarker:SetSize(INFESTED_BADGE_SIZE, INFESTED_BADGE_SIZE)
    overlay.infestedMarker:SetFrameStrata("HIGH")
    overlay.infestedMarker:SetFrameLevel(overlay:GetFrameLevel() + 14)
    overlay.infestedMarker:EnableMouse(false)
    overlay.infestedMarker:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
    overlay.infestedMarker:SetBackdropColor(0.018, 0.014, 0.026, 0.94)
    overlay.infestedMarker:SetBackdropBorderColor(0.65, 0.36, 0.92, 0.96)
    overlay.infestedMarker.icon = overlay.infestedMarker:CreateTexture(nil, "ARTWORK")
    overlay.infestedMarker.icon:SetPoint("TOPLEFT", 2, -2)
    overlay.infestedMarker.icon:SetPoint("BOTTOMRIGHT", -2, 2)
    overlay.infestedMarker.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    overlay.infestedMarker.pip = overlay.infestedMarker:CreateTexture(nil, "OVERLAY")
    overlay.infestedMarker.pip:SetSize(5, 5)
    overlay.infestedMarker.pip:SetPoint("TOPRIGHT", 1, 1)
    overlay.infestedMarker.pip:SetColorTexture(0.83, 0.48, 1.00, 1)
    overlay.infestedMarker:Hide()

    overlay.hovered = false
    overlay.hoverElapsed = 0
    overlay.currentScale = 1
    overlay.targetScale = 1
    overlay:Hide()
    return overlay
end

local function updateInfestedMarkerAnchor(overlay, hasMainAlert)
    local marker = overlay and overlay.infestedMarker
    if not marker then return end
    marker:ClearAllPoints()
    if hasMainAlert and overlay:IsShown() then
        marker:SetPoint("BOTTOM", overlay, "TOP", 0, 5)
    else
        local plate = overlay:GetParent()
        if plate then marker:SetPoint("BOTTOM", plate, "TOP", 0, 7) end
    end
end

function Nameplates:RefreshInfestedMarker(unit)
    if not BKA.db or BKA.db.enabled == false or BKA.db.showNameplates == false then return end
    local overlay = self:GetOverlay(unit)
    if not overlay or not overlay.infestedMarker then return end

    local show = BKA.db.showInfestedAdds ~= false and BKA.Affixes and BKA.Affixes:IsActive(16)
    local spellID
    if show and BKA.Affixes.GetInfestedAura then spellID = BKA.Affixes:GetInfestedAura(unit) end
    if spellID then
        overlay.infestedMarker.icon:SetTexture((GetSpellTexture and GetSpellTexture(spellID)) or "Interface\\Icons\\achievement_nazmir_boss_ghuun")
        updateInfestedMarkerAnchor(overlay, overlay.activeState or overlay.temporaryState or overlay.persistentState)
        overlay.infestedMarker:Show()
    else
        overlay.infestedMarker:Hide()
    end
end

local function setGlow(overlay, shown)
    if shown then
        overlay.glow:Show()
        if not overlay.glow.anim:IsPlaying() then overlay.glow.anim:Play() end
    else
        overlay.glow.anim:Stop()
        overlay.glow:Hide()
    end
end


local function stopShapeAnimations(overlay)
    if overlay.circle.pulseFrame.anim:IsPlaying() then overlay.circle.pulseFrame.anim:Stop() end
    if overlay.square.pulse.anim:IsPlaying() then overlay.square.pulse.anim:Stop() end
end

local function setControlBadge(overlay, controlAction, shape, color)
    controlAction = string.upper(tostring(controlAction or ""))
    local geometric = shape == "CIRCLE" or shape == "SQUARE"
    if not geometric or (controlAction ~= "KICK" and controlAction ~= "STOP" and controlAction ~= "CC") then
        overlay.controlBadge.anim:Stop()
        overlay.controlBadge:Hide()
        return
    end

    local text = controlAction == "KICK" and "KICK" or "CC"
    local badgeColor = controlAction == "KICK" and {1.00, 0.86, 0.16} or {1.00, 0.28, 0.12}
    overlay.controlBadge.text:SetText(text)
    overlay.controlBadge.text:SetTextColor(badgeColor[1], badgeColor[2], badgeColor[3])
    for _, line in ipairs(overlay.controlBadge.lines or {}) do
        line:SetColorTexture(badgeColor[1], badgeColor[2], badgeColor[3], 1)
    end
    overlay.controlBadge:ClearAllPoints()
    if shape == "CIRCLE" then
        overlay.controlBadge:SetPoint("BOTTOM", overlay.circle, "TOP", 0, -1)
    else
        overlay.controlBadge:SetPoint("BOTTOM", overlay.square, "TOP", 0, -1)
    end
    overlay.controlBadge:Show()
    if not overlay.controlBadge.anim:IsPlaying() then overlay.controlBadge.anim:Play() end
end

local function setShapeMode(overlay, shape, state, color)
    stopShapeAnimations(overlay)
    overlay.circle:Hide()
    overlay.square:Hide()

    if shape == "CIRCLE" then
        overlay:SetSize(CIRCLE_SIZE + 10, CIRCLE_SIZE + 10)
        overlay.background:Hide()
        overlay.icon:Hide()
        overlay.label:Hide()
        overlay.detail:Hide()
        overlay.countdown:Hide()
        overlay.circle.icon:SetTexture(BKA:ResolveIcon(state.ability, state))
        overlay.circle.label:SetText(string.gsub(state.label or state.action or "", "_", " "))
        overlay.circle.label:SetTextColor(color[1], color[2], color[3])
        overlay.circle.ring:SetVertexColor(color[1], color[2], color[3], 1)
        overlay.circle.pulse:SetVertexColor(color[1], color[2], color[3], 0.90)
        overlay.circle:Show()
        if not overlay.circle.pulseFrame.anim:IsPlaying() then overlay.circle.pulseFrame.anim:Play() end
    elseif shape == "SQUARE" then
        overlay:SetSize(SQUARE_SIZE + 10, SQUARE_SIZE + 10)
        overlay.background:Hide()
        overlay.icon:Hide()
        overlay.label:Hide()
        overlay.detail:Hide()
        overlay.countdown:Hide()
        overlay.square.icon:SetTexture(BKA:ResolveIcon(state.ability, state))
        overlay.square.label:SetText(string.gsub(state.label or state.action or "", "_", " "))
        overlay.square.label:SetTextColor(color[1], color[2], color[3])
        for _, line in ipairs(overlay.square.lines or {}) do
            line:SetColorTexture(color[1], color[2], color[3], 1)
        end
        for _, line in ipairs(overlay.square.pulse.lines or {}) do
            line:SetColorTexture(color[1], color[2], color[3], 0.92)
        end
        overlay.square:Show()
        overlay.square.pulse.anim:Play()
    else
        overlay:SetSize(OVERLAY_WIDTH, OVERLAY_HEIGHT)
        overlay.background:Show()
        overlay.icon:Show()
        overlay.label:Show()
        overlay.detail:Show()
        overlay.countdown:Show()
    end

    setControlBadge(overlay, state.controlAction, shape, color)
end

local function resetHoverVisual(overlay)
    overlay.hovered = false
    overlay.hoverElapsed = 0
    overlay.currentScale = 1
    overlay.targetScale = 1
    overlay:SetScale(1)
    if overlay.baseColor then
        local color = overlay.baseColor
        overlay.background:SetColorTexture(color[1] * 0.13, color[2] * 0.13, color[3] * 0.13, 0.94)
    end
end

function Nameplates:UpdateHoverVisual(overlay, elapsed)
    if not overlay or not overlay:IsShown() then return end
    overlay.hoverElapsed = (overlay.hoverElapsed or 0) + (elapsed or 0)
    if overlay.hoverElapsed < HOVER_CHECK_INTERVAL and overlay.currentScale == overlay.targetScale then
        return
    end
    overlay.hoverElapsed = 0

    local hoverEnabled = self.clickTargetingApplied == true and BKA.db and BKA.db.enabled ~= false and BKA.db.showNameplates ~= false and BKA.db.clickableNameplateAlerts ~= false
    local hovered = hoverEnabled and MouseIsOver(overlay) and true or false
    overlay.targetScale = hovered and HOVER_SCALE or 1
    overlay.hovered = hovered

    local current = overlay.currentScale or 1
    local target = overlay.targetScale or 1
    local step = math.min(1, (elapsed or HOVER_CHECK_INTERVAL) * 14)
    if math.abs(current - target) < 0.005 then
        current = target
    else
        current = current + (target - current) * step
    end
    overlay.currentScale = current
    overlay:SetScale(current)

    local color = overlay.baseColor or BKA.colors.LOW
    local t = 0
    if HOVER_SCALE > 1 then
        t = math.max(0, math.min(1, (current - 1) / (HOVER_SCALE - 1)))
    end
    local multiplier = 0.13 + 0.07 * t
    local alpha = 0.94 + 0.06 * t
    overlay.background:SetColorTexture(color[1] * multiplier, color[2] * multiplier, color[3] * multiplier, alpha)
end

function Nameplates:GetOverlay(unit)
    if not BKA.db or BKA.db.enabled == false or BKA.db.showNameplates == false then return nil end
    local overlay = self.overlays[unit]
    if overlay then
        local guid = UnitGUID(unit)
        if overlay.ownerGUID ~= guid then
            overlay.ownerGUID = guid
            overlay.generation = (overlay.generation or 0) + 1
            overlay.persistentState, overlay.temporaryState, overlay.activeState = nil, nil, nil
            overlay:SetScript("OnUpdate", nil)
            setGlow(overlay, false)
            if overlay.infestedMarker then overlay.infestedMarker:Hide() end
            resetHoverVisual(overlay)
        end
        return overlay
    end
    local plate = C_NamePlate.GetNamePlateForUnit(unit)
    if not plate then return nil end
    overlay = table.remove(self.freeOverlays)
    if overlay then
        overlay:SetParent(plate)
        overlay:ClearAllPoints()
        overlay:SetPoint("BOTTOM", plate, "TOP", 0, 3)
        if overlay.infestedMarker then
            overlay.infestedMarker:SetParent(plate)
            overlay.infestedMarker:Hide()
            updateInfestedMarkerAnchor(overlay, false)
        end
    else
        overlay = createOverlay(plate)
    end
    overlay.ownerGUID = UnitGUID(unit)
    overlay.generation = (overlay.generation or 0) + 1
    overlay.persistentState = nil
    overlay.temporaryState = nil
    overlay.activeState = nil
    overlay:SetScript("OnUpdate", nil)
    resetHoverVisual(overlay)
    self.overlays[unit] = overlay
    return overlay
end

function Nameplates:Render(unit)
    local overlay = self.overlays[unit]
    if not overlay then return end
    if overlay.ownerGUID ~= UnitGUID(unit) then
        overlay.activeState = nil
        overlay.temporaryState = nil
        overlay.persistentState = nil
        setGlow(overlay, false)
        stopShapeAnimations(overlay)
        overlay.circle:Hide()
        overlay.square:Hide()
        overlay.controlBadge.anim:Stop()
        overlay.controlBadge:Hide()
        if overlay.infestedMarker then overlay.infestedMarker:Hide() end
        resetHoverVisual(overlay)
        overlay:Hide()
        return
    end
    local state = overlay.activeState or overlay.temporaryState or overlay.persistentState
    if not state then
        overlay:SetScript("OnUpdate", nil)
        setGlow(overlay, false)
        stopShapeAnimations(overlay)
        overlay.circle:Hide()
        overlay.square:Hide()
        overlay.controlBadge.anim:Stop()
        overlay.controlBadge:Hide()
        resetHoverVisual(overlay)
        updateInfestedMarkerAnchor(overlay, false)
        overlay:Hide()
        return
    end
    local color = BKA.colors[state.severity] or BKA.colors.LOW
    local normalized = BKA:NormalizeAction(state.action or state.label, state.action or state.label)
    local explicitShape = state.ability and state.ability.plateShape
    local shape = "RECTANGLE"
    if explicitShape == "CIRCLE" or explicitShape == "SQUARE" or explicitShape == "RECTANGLE" then
        shape = explicitShape
    elseif normalized == "AOE" then
        shape = "CIRCLE"
    elseif normalized == "FRONTAL" or normalized == "CLEAVE" then
        shape = "SQUARE"
    end
    setShapeMode(overlay, shape, state, color)
    overlay.icon:SetTexture(BKA:ResolveIcon(state.ability, state))
    overlay.label:ClearAllPoints()
    overlay.label:SetPoint("LEFT", overlay.icon, "RIGHT", 5, state.detail and 6 or 0)
    overlay.label:SetPoint("RIGHT", -31, state.detail and 6 or 0)
    overlay.detail:ClearAllPoints()
    overlay.detail:SetPoint("LEFT", overlay.icon, "RIGHT", 5, -7)
    overlay.detail:SetPoint("RIGHT", -31, -7)
    overlay.label:SetText(state.label)
    overlay.detail:SetText(state.detail or "")
    overlay.label:SetTextColor(color[1], color[2], color[3])
    overlay.detail:SetTextColor(1, state.frontalTracking and 0.62 or 0.82, state.frontalTracking and 0.18 or 0.82)
    overlay.baseColor = color
    resetHoverVisual(overlay)
    overlay.countdown:SetText("")
    local personal = state == overlay.activeState and state.isPlayer and state.targetConfidence == "CONFIRMED"
    local tracking = state == overlay.activeState and state.frontalTracking
    for _, line in ipairs(overlay.glow.lines or {}) do
        if personal then
            line:SetColorTexture(1, 0.12, 0.04, 1)
        else
            line:SetColorTexture(1, 0.42, 0.06, 1)
        end
    end
    setGlow(overlay, (personal or tracking) and shape == "RECTANGLE")
    overlay:Show()
    updateInfestedMarkerAnchor(overlay, true)
    overlay:SetScript("OnUpdate", function(_, elapsed)
        Nameplates:UpdateHoverVisual(overlay, elapsed)
        local current = overlay.activeState
        if not current then
            overlay.countdown:SetText("")
            overlay.circle.countdown:SetText("")
            overlay.square.countdown:SetText("")
            return
        end
        local remaining = current.endTime - GetTime()
        if remaining <= 0 then
            BKA.ActiveCasts:Expire(unit, current.generation)
        else
            overlay.countdown:SetFormattedText("%.1f", remaining)
            overlay.circle.countdown:SetFormattedText("%.1f", remaining)
            overlay.square.countdown:SetFormattedText("%.1f", remaining)
        end
    end)
end

function Nameplates:Display(unit, spellID, label, severity, persistent, duration, controlAction)
    if not BKA.db or BKA.db.showNameplates == false then return end
    local overlay = self:GetOverlay(unit)
    if not overlay then return end
    label = BKA:NormalizeAction(label, label)
    label = string.gsub(label, "_", " ")
    local state = {
        spellID = spellID, label = label, action = label,
        ability = BKA:GetAbilityForUnitSpell(BKA:GetNPCID(UnitGUID(unit)), spellID),
        severity = severity or "LOW", persistent = persistent and true or false,
        controlAction = controlAction,
    }
    state.priority = priority(state.action, state.severity, state.persistent)
    if controlAction == "STOP" or controlAction == "CC" then
        state.priority = state.priority + 240
    elseif controlAction == "KICK" then
        state.priority = state.priority + 180
    end
    if state.persistent then
        overlay.persistentState = state
        if not overlay.activeState and not overlay.temporaryState then self:Render(unit) end
        return
    end
    if overlay.activeState then return end
    if overlay.temporaryState and overlay.temporaryState.priority > state.priority then return end
    overlay.temporaryState = state
    overlay.generation = (overlay.generation or 0) + 1
    local generation = overlay.generation
    self:Render(unit)
    C_Timer.After(duration or DEFAULT_LIFETIME, function()
        if BKA.active and Nameplates.overlays[unit] == overlay and overlay.generation == generation and not overlay.activeState then
            overlay.temporaryState = nil
            Nameplates:RestorePersistent(unit)
        end
    end)
end

function Nameplates:ShowActive(cast, resolution, unit)
    unit = unit or cast.unit
    if not BKA.db or BKA.db.showNameplates == false then
        local existing = self.overlays[unit]
        if existing then existing:Hide() end
        return
    end
    local overlay = self:GetOverlay(unit)
    if not overlay then return end
    local personal = cast.targetIsPlayer and cast.targetConfidence == "CONFIRMED"
    if resolution and resolution.ability and not BKA:RoleNotificationAllows(resolution.ability, resolution.action, personal) then
        overlay.activeState = nil
        self:RestorePersistent(unit)
        return
    end
    local action = BKA:NormalizeAction(resolution.nameplateAction or resolution.action or "CAST", resolution.ability and resolution.ability.mechanic)
    local label = string.gsub(action, "_", " ")
    local detail
    local frontalTracking = false
    if action == "FRONTAL" or action == "CLEAVE" then
        if not BKA:IsTargetBasedFrontal(resolution.ability) then personal = false end
        local context = {
            targetName = cast.targetName, targetRole = cast.targetRole,
            isPlayer = personal, targetConfidence = cast.targetConfidence,
            alertState = "ACTIVE",
        }
        local targetLabel = BKA:GetFrontalTargetLabel(resolution.ability, context)
        if targetLabel then label = action .. " - " .. targetLabel end
        detail = BKA:GetFrontalStateLabel(resolution.ability, context, true)
        frontalTracking = detail == "TRACK"
    elseif personal then
        label = label .. " - YOU"
    end
    overlay.activeState = {
        ability = resolution.ability, spellID = cast.spellID, texture = cast.texture,
        label = label, action = resolution.nameplateAction or resolution.action, severity = resolution.severity,
        detail = detail, frontalTracking = frontalTracking,
        controlAction = resolution.controlAction or (resolution.ability and resolution.ability.ccCapable and "CC" or nil),
        startTime = cast.startTime, endTime = cast.endTime, castGUID = cast.castGUID,
        castIdentity = cast.identity,
        generation = cast.generation,
        isPlayer = personal,
        targetConfidence = cast.targetConfidence,
        priority = priority(resolution.nameplateAction or resolution.action, resolution.severity, false)
            + ((resolution.controlAction == "STOP" or resolution.controlAction == "CC") and 240 or (resolution.controlAction == "KICK" and 180 or 0))
            + (personal and 1000 or 0),
    }
    overlay.temporaryState = nil
    self:Render(unit)
end

function Nameplates:ClearActive(unit, generation)
    local overlay = self.overlays[unit]
    if not overlay or not overlay.activeState then return end
    if generation and overlay.activeState.generation ~= generation then return end
    overlay.activeState = nil
    overlay:SetScript("OnUpdate", nil)
    self:RestorePersistent(unit)
end

function Nameplates:RestorePersistent(unit, skipAffixScan)
    if not BKA.db or BKA.db.showNameplates == false then return end
    local overlay = self:GetOverlay(unit)
    if not overlay then return end
    self:RefreshInfestedMarker(unit)
    if overlay.activeState then return end
    overlay.temporaryState = nil
    local npcID = BKA:GetNPCID(UnitGUID(unit))
    local state
    if npcID == 141851 and BKA.Affixes:IsActive(16) and BKA.db.showInfestedAdds ~= false then
        state = { label = "CC / STOP", action = "CC", severity = "CRITICAL", persistent = true }
    elseif npcID == 120651 and BKA.Affixes:IsActive(13) then
        state = { label = "ORB", action = "ORB", severity = "HIGH", persistent = true }
    elseif not skipAffixScan then
        local marker, spellID = BKA.Affixes:GetNameplateMarker(unit)
        if marker then
            state = { spellID = spellID, label = marker.label, action = marker.label, severity = marker.severity, persistent = true }
        end
    end
    if state then state.priority = priority(state.action, state.severity, true) end
    overlay.persistentState = state
    self:Render(unit)
end

function Nameplates:InspectUnitCast(unit, event)
    if event == "UNIT_SPELLCAST_DELAYED" or event == "UNIT_SPELLCAST_CHANNEL_UPDATE" then
        return BKA.ActiveCasts:Resync(unit, nil, nil, event == "UNIT_SPELLCAST_CHANNEL_UPDATE")
    end
    return BKA.ActiveCasts:Start(unit, nil, nil, event == "UNIT_SPELLCAST_CHANNEL_START")
end

function Nameplates:OnAdded(unit)
    if BKA.db and BKA.db.showNameplates ~= false then self:EnsureClickTargeting() end
    BKA.Targets:AddUnit(unit)
    self:RestorePersistent(unit)
    if BKA:GetNPCID(UnitGUID(unit)) == 141851 and BKA.Affixes:IsActive(16) and BKA.db.showInfestedAdds ~= false then
        BKA.Alerts:Show({
            id = 0, mechanic = "CC", action = "CC SPAWN", severity = "CRITICAL",
            center = true, nameplate = true, sound = true, throttle = 1,
        }, { spellName = UnitName(unit), sourceGUID = UnitGUID(unit), duration = 2 })
    end
    BKA.ActiveCasts:Start(unit)
end

function Nameplates:OnRemoved(unit)
    BKA.ActiveCasts:UnitGone(unit)
    BKA.Targets:RemoveUnit(unit)
    local overlay = self.overlays[unit]
    if overlay then
        overlay.generation = (overlay.generation or 0) + 1
        overlay:SetScript("OnUpdate", nil)
        setGlow(overlay, false)
        stopShapeAnimations(overlay)
        overlay.circle:Hide()
        overlay.square:Hide()
        overlay.controlBadge.anim:Stop()
        overlay.controlBadge:Hide()
        resetHoverVisual(overlay)
        if overlay.infestedMarker then
            overlay.infestedMarker:Hide()
            overlay.infestedMarker:SetParent(nil)
        end
        overlay:Hide()
        overlay:SetParent(nil)
        overlay.persistentState = nil
        overlay.temporaryState = nil
        overlay.activeState = nil
        self.overlays[unit] = nil
        self.freeOverlays[#self.freeOverlays + 1] = overlay
    end
end


function Nameplates:RefreshAll()
    if not BKA.db or BKA.db.showNameplates == false then
        self:Clear()
        self:RefreshClickTargeting()
        return
    end
    -- Re-discover already visible nameplates when the feature is toggled back on.
    if C_NamePlate and C_NamePlate.GetNamePlates then
        for _, plate in ipairs(C_NamePlate.GetNamePlates() or {}) do
            local unit = plate and plate.namePlateUnitToken
            if unit and UnitExists(unit) and not UnitIsFriend("player", unit) then
                BKA.Targets:AddUnit(unit)
                local cast = BKA.ActiveCasts and BKA.ActiveCasts:Get(unit)
                if cast and cast.resolution then self:ShowActive(cast, cast.resolution, unit) else self:RestorePersistent(unit) end
            end
        end
    end
    for unit in pairs(self.overlays) do
        if UnitExists(unit) then
            local cast = BKA.ActiveCasts and BKA.ActiveCasts:Get(unit)
            if cast and cast.resolution then
                self:ShowActive(cast, cast.resolution, unit)
            else
                self:RestorePersistent(unit)
            end
        end
    end
end

function Nameplates:Clear()
    for unit, overlay in pairs(self.overlays) do
        overlay.generation = (overlay.generation or 0) + 1
        overlay:SetScript("OnUpdate", nil)
        setGlow(overlay, false)
        stopShapeAnimations(overlay)
        overlay.circle:Hide()
        overlay.square:Hide()
        overlay.controlBadge.anim:Stop()
        overlay.controlBadge:Hide()
        resetHoverVisual(overlay)
        if overlay.infestedMarker then
            overlay.infestedMarker:Hide()
            overlay.infestedMarker:SetParent(nil)
        end
        overlay:Hide()
        overlay:SetParent(nil)
        overlay.persistentState = nil
        overlay.temporaryState = nil
        overlay.activeState = nil
        self.freeOverlays[#self.freeOverlays + 1] = overlay
        self.overlays[unit] = nil
    end
end
