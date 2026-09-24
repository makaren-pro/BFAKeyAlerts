local BKA = BFAKeyAlerts
local MinimapButton = {}
BKA.MinimapButton = MinimapButton

local URL = "https://discord.com/users/785141640087207966"
local ICON = "Interface\\AddOns\\" .. BKA.name .. "\\Media\\BFAKeyAlertsIcon"

local function text(parent, size, x, y, width, value)
    local label = BKA.HUD:Text(parent, size, x, y, width)
    label:SetText(value)
    return label
end

function MinimapButton:UpdatePosition()
    if not self.button or not BKA.db then return end
    local angle = math.rad(tonumber(BKA.db.minimap.angle) or 225)
    local radius = (Minimap:GetWidth() or 140) * 0.5 + 7
    self.button:ClearAllPoints()
    self.button:SetPoint("CENTER", Minimap, "CENTER", math.cos(angle) * radius, math.sin(angle) * radius)
    self.button:SetShown(BKA.db.minimap.hide ~= true)
end

function MinimapButton:CreateDiscord()
    if self.dialog then return self.dialog end
    local frame = CreateFrame("Frame", "BFAKeyAlertsDiscordDialog", UIParent)
    frame:SetSize(420, 150)
    frame:SetPoint("CENTER")
    frame:SetFrameStrata("DIALOG")
    frame:EnableMouse(true)
    BKA.HUD:StyleFrame(frame, 0.97)
    text(frame, 16, 18, -17, 360, BKA:L("DISCORD_TITLE"))
    text(frame, 12, 18, -45, 380, BKA:L("DISCORD_CONTACT"))
    text(frame, 11, 18, -67, 380, BKA:L("DISCORD_COPY_HINT"))
    local edit = CreateFrame("EditBox", nil, frame, "InputBoxTemplate")
    edit:SetSize(374, 24)
    edit:SetPoint("TOPLEFT", 22, -88)
    edit:SetAutoFocus(false)
    edit:SetText(URL)
    edit:SetScript("OnEscapePressed", function() frame:Hide() end)
    edit:SetScript("OnEnterPressed", function(self) self:HighlightText() end)
    frame:SetScript("OnShow", function()
        edit:SetText(URL)
        edit:SetFocus()
        edit:HighlightText()
    end)
    local close = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    close:SetSize(90, 22)
    close:SetPoint("BOTTOMRIGHT", -18, 12)
    close:SetText(BKA:L("CLOSE"))
    close:SetScript("OnClick", function() frame:Hide() end)
    frame:Hide()
    tinsert(UISpecialFrames, frame:GetName())
    self.dialog = frame
    return frame
end

function MinimapButton:Initialize()
    if self.button or not BKA.db or not Minimap then return end
    local button = CreateFrame("Button", "BFAKeyAlertsMinimapButton", Minimap)
    button:SetSize(32, 32)
    button:SetFrameStrata("MEDIUM")
    button:SetFrameLevel(Minimap:GetFrameLevel() + 5)
    button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    button:RegisterForDrag("LeftButton")
    local icon = button:CreateTexture(nil, "ARTWORK")
    icon:SetSize(30, 30)
    icon:SetPoint("CENTER")
    icon:SetTexture(ICON)
    icon:SetTexCoord(0, 1, 0, 1)
    button:SetScript("OnEnter", function(self)
        icon:SetVertexColor(1, 0.94, 0.78)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:SetText(BKA:L("ADDON_TITLE"))
        GameTooltip:AddLine(BKA:L("MINIMAP_LEFT"), 0.80, 0.88, 0.95)
        GameTooltip:AddLine(BKA:L("MINIMAP_RIGHT"), 0.80, 0.88, 0.95)
        GameTooltip:Show()
    end)
    button:SetScript("OnLeave", function()
        icon:SetVertexColor(1, 1, 1)
        GameTooltip:Hide()
    end)
    button:SetScript("OnClick", function(_, mouseButton)
        if mouseButton == "RightButton" then
            MinimapButton:CreateDiscord():Show()
        else
            BKA.Options:Open()
        end
    end)
    button:SetScript("OnDragStart", function(self)
        self.dragging = true
        self:SetScript("OnUpdate", function()
            local scale = UIParent:GetEffectiveScale()
            local x, y = GetCursorPosition()
            local cx, cy = Minimap:GetCenter()
            x, y = x / scale - cx, y / scale - cy
            local angle
            if math.atan2 then angle = math.atan2(y, x)
            elseif x == 0 then angle = y >= 0 and math.pi / 2 or -math.pi / 2
            else angle = math.atan(y / x) + (x < 0 and math.pi or 0) end
            BKA.db.minimap.angle = math.deg(angle)
            MinimapButton:UpdatePosition()
        end)
    end)
    button:SetScript("OnDragStop", function(self)
        self.dragging = nil
        self:SetScript("OnUpdate", nil)
    end)
    self.button = button
    self:UpdatePosition()
end
