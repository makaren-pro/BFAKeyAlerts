local BKA = BFAKeyAlerts
local HUD = {}
BKA.HUD = HUD

local WHITE = "Interface\\Buttons\\WHITE8X8"

local function clamp(value, low, high, fallback)
    value = tonumber(value)
    if not value or value ~= value then value = fallback end
    return math.max(low, math.min(high, value))
end

function HUD:StyleFrame(frame, alpha)
    frame:SetBackdrop({ bgFile = WHITE, edgeFile = WHITE, edgeSize = 1 })
    frame:SetBackdropColor(0.025, 0.035, 0.055, alpha or 0.82)
    frame:SetBackdropBorderColor(0.22, 0.35, 0.43, 0.92)
end

function HUD:SavePosition(settings, frame)
    if not settings or not frame then return end
    local point, _, relativePoint, x, y = frame:GetPoint(1)
    settings.point = point or "CENTER"
    settings.relativePoint = relativePoint or "CENTER"
    settings.x = x or 0
    settings.y = y or 0
end

function HUD:Apply(frame, settings, defaultX, defaultY)
    if not frame or not settings then return end
    settings.scale = clamp(settings.scale, 0.6, 2, 1)
    frame:SetScale(settings.scale)
    -- Do not fight StartMoving() from high-frequency HUD refreshes.
    -- Position is persisted once OnDragStop fires.
    if not frame._bkaDragging then
        frame:ClearAllPoints()
        frame:SetPoint(settings.point or "CENTER", UIParent, settings.relativePoint or "CENTER",
            tonumber(settings.x) or defaultX or 0, tonumber(settings.y) or defaultY or 0)
    end
    if frame.dragHandle then
        if settings.locked ~= false then frame.dragHandle:Hide() else frame.dragHandle:Show() end
    end
end

function HUD:CreatePanel(name, settings, title, defaultX, defaultY)
    local frame = CreateFrame("Frame", name, UIParent)
    self:StyleFrame(frame, settings and settings.backgroundAlpha or 0.82)
    frame:SetFrameStrata("HIGH")
    frame:SetClampedToScreen(true)
    frame:SetMovable(true)
    frame:EnableMouse(false)

    local accent = frame:CreateTexture(nil, "ARTWORK")
    accent:SetPoint("TOPLEFT", 1, -1)
    accent:SetPoint("TOPRIGHT", -1, -1)
    accent:SetHeight(2)
    accent:SetColorTexture(0.40, 0.88, 0.74, 0.95)
    frame.accent = accent

    local handle = CreateFrame("Frame", nil, frame)
    -- The whole header is a generous drag target while unlocked.
    handle:SetPoint("TOPLEFT", 0, 0)
    handle:SetPoint("TOPRIGHT", 0, 0)
    handle:SetHeight(26)
    handle:EnableMouse(true)
    handle:RegisterForDrag("LeftButton")
    local line = handle:CreateTexture(nil, "OVERLAY")
    line:SetPoint("TOPLEFT", 1, -1)
    line:SetPoint("TOPRIGHT", -1, -1)
    line:SetHeight(2)
    line:SetColorTexture(0.35, 0.70, 0.75, 0.55)
    handle:SetScript("OnDragStart", function()
        if settings and settings.locked == false then
            frame._bkaDragging = true
            frame:StartMoving()
        end
    end)
    handle:SetScript("OnDragStop", function()
        frame:StopMovingOrSizing()
        HUD:SavePosition(settings, frame)
        frame._bkaDragging = false
        HUD:Apply(frame, settings, defaultX, defaultY)
    end)
    handle:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText((title or "BFA Key Alerts") .. " | перетащи")
        GameTooltip:Show()
    end)
    handle:SetScript("OnLeave", function() GameTooltip:Hide() end)
    frame.dragHandle = handle

    self:Apply(frame, settings or {}, defaultX, defaultY)
    return frame
end

function HUD:Text(parent, size, x, y, width, template)
    local label = parent:CreateFontString(nil, "OVERLAY", template)
    if not template then label:SetFont(STANDARD_TEXT_FONT, size, "OUTLINE") end
    label:SetPoint("TOPLEFT", x, y)
    if width then label:SetWidth(width) end
    label:SetJustifyH("LEFT")
    label:SetTextColor(0.90, 0.94, 0.98)
    return label
end

function HUD:Bar(parent, x, y, width, height, r, g, b)
    local bar = CreateFrame("StatusBar", nil, parent)
    bar:SetPoint("TOPLEFT", x, y)
    bar:SetSize(width, height or 5)
    bar:SetStatusBarTexture(WHITE)
    bar:SetStatusBarColor(r or 0.40, g or 0.88, b or 0.74)
    bar:SetMinMaxValues(0, 100)
    local bg = bar:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(0.16, 0.20, 0.26, 0.88)
    bar.background = bg
    return bar
end
