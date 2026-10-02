local BKA = BFAKeyAlerts
local Options = { pages = {}, controls = {} }
BKA.Options = Options

local WHITE = "Interface\\Buttons\\WHITE8X8"
local ACCENT = {0.40, 0.88, 0.74}
local SUPPORT_URL = "https://www.donationalerts.com/r/makarenr"
local SECTIONS = {"general", "mechanics", "nameplates", "prediction", "intelligence", "kicks", "cooldowns", "keystone", "sounds"}

function Options:ShowSupportLink()
    if self.frame then self.frame:Hide() end
    if BKA.CastPredictionUI then
        if BKA.CastPredictionUI.inspector then BKA.CastPredictionUI.inspector:Hide() end
        if BKA.CastPredictionUI.exportFrame then BKA.CastPredictionUI.exportFrame:Hide() end
    end
    if BKA.MinimapButton and BKA.MinimapButton.dialog then BKA.MinimapButton.dialog:Hide() end
    if GameTooltip then GameTooltip:Hide() end
    if not self.supportDialog then
        local frame = CreateFrame("Frame", "BFAKeyAlertsSupportDialog", UIParent)
        frame:SetSize(500, 145); frame:SetPoint("CENTER"); frame:SetFrameStrata("DIALOG")
        frame:EnableMouse(true)
        BKA.HUD:StyleFrame(frame, 0.97)
        local title = BKA.HUD:Text(frame, 16, 18, -17, 450)
        title:SetText(BKA:L("SUPPORT_TITLE"))
        local hint = BKA.HUD:Text(frame, 11, 18, -47, 460)
        hint:SetText(BKA:L("SUPPORT_COPY_HINT"))
        local edit = CreateFrame("EditBox", nil, frame, "InputBoxTemplate")
        edit:SetSize(450, 24); edit:SetPoint("TOPLEFT", 22, -78)
        edit:SetAutoFocus(false)
        edit:SetScript("OnEscapePressed", function() frame:Hide() end)
        edit:SetScript("OnEnterPressed", function(self) self:HighlightText() end)
        local close = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
        close:SetSize(90, 22); close:SetPoint("BOTTOMRIGHT", -18, 12)
        close:SetText(BKA:L("CLOSE"))
        close:SetScript("OnClick", function() frame:Hide() end)
        frame.edit = edit
        frame:Hide()
        tinsert(UISpecialFrames, frame:GetName())
        self.supportDialog = frame
    end
    local edit = self.supportDialog.edit
    edit:SetText(SUPPORT_URL)
    self.supportDialog:Show()
    edit:SetFocus()
    edit:HighlightText()
end

function Options:AddSupportLink(parent, point, relativePoint, x, y, width)
    local link = CreateFrame("Button", nil, parent)
    link:SetSize(width, 18)
    link:SetPoint(point, parent, relativePoint, x, y)
    link:SetFrameLevel(parent:GetFrameLevel() + 2)
    link:EnableMouse(true)
    link:RegisterForClicks("LeftButtonUp")
    local text = link:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    text:SetAllPoints(link)
    text:SetJustifyH("LEFT")
    text:SetWordWrap(false)
    text:SetText(BKA:L("SUPPORT_LINK") .. "  " .. SUPPORT_URL)
    text:SetTextColor(unpack(ACCENT))
    link:SetScript("OnEnter", function(self)
        text:SetTextColor(0.72, 1, 0.90)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText(BKA:L("SUPPORT_CLICK_HINT"))
        GameTooltip:Show()
    end)
    link:SetScript("OnLeave", function()
        text:SetTextColor(unpack(ACCENT))
        GameTooltip:Hide()
    end)
    link:SetScript("OnClick", function() Options:ShowSupportLink() end)
    return link
end

local function style(frame, alpha)
    frame:SetBackdrop({ bgFile = WHITE })
    frame:SetBackdropColor(0.025, 0.035, 0.055, alpha)
end

local function label(parent, size, x, y, width, value, color)
    local fs = BKA.HUD:Text(parent, size, x, y, width)
    local displaySize = size == 10 and 11 or size == 12 and 13 or size
    fs:SetFont(STANDARD_TEXT_FONT, displaySize)
    fs:SetShadowColor(0, 0, 0, 1)
    fs:SetShadowOffset(1, -1)
    fs:SetText(value or "")
    fs:SetWordWrap(true)
    if color then fs:SetTextColor(unpack(color)) end
    return fs
end

local function panel(parent, x, y, width, height, alpha)
    local f = CreateFrame("Frame", nil, parent)
    f:SetPoint("TOPLEFT", x, y)
    f:SetSize(width, height)
    style(f, alpha or 0.48)
    return f
end

local function updateButtonVisual(b)
    local bg, border, text
    if b.isToggle then
        if b.isOn then
            bg, border, text = {0.08,0.22,0.20,0.98}, {0.36,0.78,0.63,1}, {0.55,1,0.82}
        else
            bg, border, text = {0.055,0.075,0.10,0.92}, {0.24,0.34,0.40,1}, {0.68,0.74,0.79}
        end
    elseif b.selected then
        bg, border, text = {0.08,0.20,0.21,0.98}, {0.39,0.76,0.65,1}, ACCENT
    else
        bg, border, text = {0.055,0.09,0.12,0.94}, {0.20,0.38,0.44,1}, {0.90,0.94,0.98}
    end
    if b.isDown then
        bg, border = {0.035,0.13,0.15,1}, {0.46,0.91,0.76,1}
    elseif b.hovered then
        bg, border = {0.10,0.20,0.22,1}, {0.35,0.65,0.62,1}
    end
    b:SetBackdropColor(unpack(bg))
    b:SetBackdropBorderColor(unpack(border))
    b.text:SetTextColor(unpack(text))
end

local function button(parent, title, x, y, width, height, callback)
    local b = CreateFrame("Button", nil, parent)
    b:SetPoint("TOPLEFT", x, y)
    b:SetSize(width, height or 28)
    b:EnableMouse(true)
    b:RegisterForClicks("LeftButtonUp")
    b:SetHitRectInsets(0, 0, 0, 0)
    style(b, 0.84)
    b:SetBackdrop({bgFile=WHITE,edgeFile=WHITE,edgeSize=1,insets={left=1,right=1,top=1,bottom=1}})
    b.text = label(b, 11, 0, 0, width, title)
    b.text:ClearAllPoints()
    b.text:SetPoint("CENTER")
    b.text:SetJustifyH("CENTER")
    b.hovered, b.isDown = false, false
    b:SetScript("OnEnter", function(self) self.hovered=true; updateButtonVisual(self) end)
    b:SetScript("OnLeave", function(self) self.hovered=false; self.isDown=false; updateButtonVisual(self) end)
    b:SetScript("OnMouseDown", function(self) self.isDown=true; updateButtonVisual(self) end)
    b:SetScript("OnMouseUp", function(self) self.isDown=false; updateButtonVisual(self) end)
    b:SetScript("OnClick", callback)
    updateButtonVisual(b)
    return b
end

local function get(path)
    local root, key = string.match(path, "^([^.]+)%.(.+)$")
    if root then return BKA.db[root][key] end
    return BKA.db[path]
end

local function set(path, value)
    local root, key = string.match(path, "^([^.]+)%.(.+)$")
    if root then BKA.db[root][key] = value else BKA.db[path] = value end
end

local function refreshCombat(clear)
    if clear and BKA.Alerts then BKA.Alerts:Clear() end
    if BKA.Nameplates then BKA.Nameplates:RefreshAll() end
end

local function onChanged(path)
    if string.match(path, "^enemySpellCooldowns%.") or string.match(path, "^autoMarkers%.") or
        string.match(path, "^partyFrameTargets%.") or string.match(path, "^mobState%.") or string.match(path, "^castbarIntelligence%.") then
        if BKA.CombatIntelligence then BKA.CombatIntelligence:SettingsChanged(path) end
    elseif string.match(path, "^castLearning%.") then
        if BKA.CastLearning and BKA.CastLearning.SettingsChanged then BKA.CastLearning:SettingsChanged() end
        if BKA.CastPredictionUI then
            BKA.CastPredictionUI:Refresh()
        end
        if BKA.Nameplates then BKA.Nameplates:RefreshAll() end
    elseif path == "enabled" then
        BKA:RefreshActivation()
        if BKA.ChatBubbles then BKA.ChatBubbles:Refresh() end
        if BKA.db.enabled == false and BKA.Alerts then BKA.Alerts:Clear() end
        if BKA.Nameplates then BKA.Nameplates:RefreshAll(); BKA.Nameplates:RefreshClickTargeting() end
        BKA.GroupInterrupts:Refresh(true)
        if BKA.GroupCooldowns then BKA.GroupCooldowns:Refresh(true) end
        BKA.KeystoneHUD:Refresh(true)
    elseif path == "showAlerts" then
        if BKA.db.showAlerts == false then BKA.Alerts:Clear() end
    elseif path == "showNameplates" then
        if BKA.db.showNameplates == false then BKA.Nameplates:Clear() else BKA.Nameplates:RefreshAll() end
        BKA.Nameplates:RefreshClickTargeting()
    elseif path == "hideChatBubblesInKey" then
        BKA.ChatBubbles:Refresh()
    elseif path == "hideUninterruptibleDuringKick" then
        BKA.Nameplates:RefreshCastVisibility()
    elseif path == "emphasizeInterruptibleCasts" then
        BKA.Nameplates:RefreshAll()
        BKA.Nameplates:RefreshClickTargeting()
    elseif path == "clickableNameplateAlerts" then
        BKA.Nameplates:RefreshClickTargeting()
    elseif path == "showTankAlerts" or path == "showHealerAlerts" or path == "showInfestedAdds" then
        refreshCombat(true)
    elseif path == "showFrontalTarget" then
        refreshCombat(false)
    elseif string.match(path, "^healerHUD%.") or string.match(path, "^tankHUD%.") or string.match(path, "^defensiveHUD%.") then
        BKA.GroupCooldowns:ApplySettings()
        BKA.GroupCooldowns:Refresh(true)
    elseif string.match(path, "^kickTracker%.") then
        BKA.GroupInterrupts:ApplySettings()
        BKA.GroupInterrupts:Refresh(true)
    elseif string.match(path, "^keystoneHUD%.") then
        BKA.KeystoneHUD:ApplySettings()
        BKA.KeystoneHUD:Refresh(true)
    elseif path == "minimap.hide" and BKA.MinimapButton then
        BKA.MinimapButton:UpdatePosition()
    elseif path == "alertStyle" or string.match(path, "^layout%.") then
        BKA.Alerts:ApplyLayout()
    end
    Options:Refresh()
end

local function page(section)
    local scroll = CreateFrame("ScrollFrame", nil, Options.content, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 0, 0)
    scroll:SetPoint("BOTTOMRIGHT", -24, 0)
    local child = CreateFrame("Frame", nil, scroll)
    child:SetSize(606, 1)
    scroll:SetScrollChild(child)
    scroll:Hide()
    Options.pages[section] = {scroll = scroll, child = child, y = -16}
    label(child, 19, 12, -8, 580, BKA:L("OPT_" .. string.upper(section)))
    Options.pages[section].y = -50
    return Options.pages[section]
end

local function heading(p, key)
    label(p.child, 12, 12, p.y, 580, BKA:L(key), ACCENT)
    p.y = p.y - 28
end

local function toggle(p, path, titleKey, descKey, height, warning)
    height = height or 58
    local row = panel(p.child, 12, p.y, 580, height, 0.47)
    label(row, 12, 12, -10, 410, BKA:L(titleKey))
    if descKey then label(row, 10, 12, -29, 420, BKA:L(descKey), {0.76, 0.82, 0.86}) end
    if warning then
        label(row, 10, 12, -53, 545, BKA:L("OPT_EXPERIMENTAL") .. "  •  " .. BKA:L(type(warning) == "string" and warning or "OPT_CLICK_WARNING"), {0.98, 0.76, 0.39})
    end
    local control = button(row, "", 470, -15, 94, 28, function()
        set(path, get(path) == false)
        onChanged(path)
    end)
    control.isToggle = true
    Options.controls[#Options.controls + 1] = function()
        local active = path == "minimap.hide" and get(path) ~= true or
            (path ~= "minimap.hide" and get(path) ~= false)
        control.text:SetText(BKA:L(active and "ON" or "OFF"))
        control.isOn = active
        updateButtonVisual(control)
    end
    p.y = p.y - height - 7
    return row
end

local function slider(p, path, titleKey, minValue, maxValue, step, format)
    local row = panel(p.child, 12, p.y, 580, 52, 0.47)
    label(row, 12, 12, -11, 270, BKA:L(titleKey))
    local valueText = label(row, 11, 280, -12, 90, "", ACCENT)
    local s = CreateFrame("Slider", nil, row)
    s:SetPoint("TOPLEFT", 380, -15)
    s:SetSize(175, 16)
    s:SetOrientation("HORIZONTAL")
    s:SetMinMaxValues(minValue, maxValue)
    s:SetValueStep(step)
    s:SetThumbTexture("Interface\\Buttons\\UI-SliderBar-Button-Horizontal")
    local track = s:CreateTexture(nil, "BACKGROUND")
    track:SetPoint("LEFT", 0, 0); track:SetPoint("RIGHT", 0, 0); track:SetHeight(3)
    track:SetTexture(WHITE); track:SetVertexColor(0.25, 0.37, 0.43)
    s:SetScript("OnValueChanged", function(_, value)
        if Options.updating then return end
        value = math.floor(value / step + 0.5) * step
        set(path, value)
        onChanged(path)
    end)
    Options.controls[#Options.controls + 1] = function()
        s:SetValue(tonumber(get(path)) or minValue)
        local displayed = tonumber(get(path)) or minValue
        if string.match(path, "%.alpha$") or string.match(path, "%.backgroundAlpha$") or path == "castLearning.minimumConfidence" then displayed = displayed * 100 end
        valueText:SetText(string.format(format, displayed))
    end
    p.y = p.y - 59
end

local function actions(p, first, second, third)
    local row = panel(p.child, 12, p.y, 580, 48, 0.47)
    local defs = {first, second, third}
    for i, def in ipairs(defs) do
        if def then button(row, BKA:L(def[1]), 10 + (i - 1) * 185, -10, 175, 28, def[2]) end
    end
    p.y = p.y - 55
end

local function buildGeneral()
    local p = page("general")
    toggle(p, "enabled", "OPT_ENABLED", "OPT_ENABLED_DESC")
    toggle(p, "showAlerts", "OPT_ALERTS", "OPT_ALERTS_DESC")
    toggle(p, "minimap.hide", "OPT_MINIMAP_VISIBLE", "OPT_MINIMAP_DESC")
    heading(p, "OPT_ALERT_LAYOUT")
    actions(p,
        {"OPT_BAR", function() set("alertStyle", "BAR"); onChanged("alertStyle") end},
        {"OPT_ICON", function() set("alertStyle", "ICON"); onChanged("alertStyle") end})
    slider(p, "layout.scale", "OPT_SCALE", 0.6, 1.6, 0.05, "%.2fx")
    slider(p, "layout.width", "OPT_WIDTH", 280, 520, 10, "%d px")
    actions(p,
        {"OPT_LOCK_TOGGLE", function() BKA.Alerts:SetUnlocked(not BKA.Alerts.unlocked); Options:Refresh() end},
        {"OPT_RESET_POSITION", function() Options:ResetLayout() end})
end

local function buildMechanics()
    local p = page("mechanics")
    heading(p, "OPT_ROLE_FILTERS")
    toggle(p, "showTankAlerts", "OPT_TANK", "OPT_TANK_DESC")
    toggle(p, "showHealerAlerts", "OPT_HEALER", "OPT_HEALER_DESC")
    heading(p, "OPT_DUNGEON_INFO")
    toggle(p, "showInfestedAdds", "OPT_INFESTED", "OPT_INFESTED_DESC")
    toggle(p, "showEnemyForcesTooltip", "OPT_FORCES_TOOLTIP", "OPT_FORCES_TOOLTIP_DESC")
end

local function buildNameplates()
    local p = page("nameplates")
    toggle(p, "showNameplates", "OPT_NAMEPLATES", "OPT_NAMEPLATES_DESC")
    toggle(p, "showFrontalTarget", "OPT_FRONTAL", "OPT_FRONTAL_DESC")
    toggle(p, "emphasizeInterruptibleCasts", "OPT_KICK_SIZE", "OPT_KICK_SIZE_DESC", 82)
    toggle(p, "hideUninterruptibleDuringKick", "OPT_KICK_FOCUS", nil, 116, "OPT_KICK_FOCUS_DESC")
    toggle(p, "hideChatBubblesInKey", "OPT_HIDE_BUBBLES", "OPT_HIDE_BUBBLES_DESC", 82)
    toggle(p, "clickableNameplateAlerts", "OPT_CLICKABLE", nil, 116, true)
end

local function buildIntelligence()
    local p = page("intelligence")
    toggle(p, "enemySpellCooldowns.enabled", "CI_COOLDOWNS", "CI_COOLDOWNS_DESC")
    slider(p, "enemySpellCooldowns.minSeverity", "CI_SEVERITY", 1, 4, 1, "%d")
    slider(p, "enemySpellCooldowns.maxAbilities", "CI_MAX_ABILITIES", 1, 3, 1, "%d")
    toggle(p, "enemySpellCooldowns.predictedOnly", "CI_PREDICTED_ONLY", "CI_PREDICTED_ONLY_DESC")
    toggle(p, "enemySpellCooldowns.debug", "CI_CONFIDENCE")
    toggle(p, "autoMarkers.enabled", "CI_MARKERS", "CI_MARKERS_DESC")
    toggle(p, "autoMarkers.onlyInKey", "CI_ONLY_KEY")
    slider(p, "autoMarkers.priority", "CI_MARK_PRIORITY", 1, 2, 1, "%d")
    label(p.child, 10, 24, p.y, 550, BKA:L("CI_MARK_PRIORITY_DESC")); p.y = p.y - 36
    toggle(p, "autoMarkers.preserveManual", "CI_PRESERVE_MANUAL", "CI_PRESERVE_MANUAL_DESC")
    toggle(p, "partyFrameTargets.enabled", "CI_PARTY", "CI_PARTY_DESC")
    local previewRow = panel(p.child, 12, p.y, 580, 64, 0.47)
    label(previewRow, 10, 202, -10, 358, BKA:L("CI_PARTY_PREVIEW_DESC"), {0.76, 0.82, 0.86})
    local preview = button(previewRow, "", 10, -18, 180, 28, function()
        if BKA.PartyFrameTargets then
            BKA.PartyFrameTargets:SetPreview(not BKA.PartyFrameTargets:IsPreviewEnabled())
        end
        Options:Refresh()
    end)
    Options.controls[#Options.controls + 1] = function()
        local active = BKA.PartyFrameTargets and BKA.PartyFrameTargets:IsPreviewEnabled() or false
        preview.isToggle, preview.isOn = true, active
        preview.text:SetText(BKA:L(active and "CI_PARTY_PREVIEW_OFF" or "CI_PARTY_PREVIEW_ON"))
        updateButtonVisual(preview)
    end
    p.y = p.y - 71
    slider(p, "partyFrameTargets.maxSpells", "CI_MAX_SPELLS", 1, 3, 1, "%d")
    slider(p, "partyFrameTargets.minSeverity", "CI_SEVERITY", 1, 4, 1, "%d")
    slider(p, "partyFrameTargets.iconSize", "CI_ICON_SIZE", 12, 28, 1, "%d px")
    slider(p, "partyFrameTargets.anchor", "CI_ANCHOR", 1, 3, 1, "%d")
    label(p.child, 10, 24, p.y, 550, BKA:L("CI_ANCHOR_DESC")); p.y = p.y - 36
    toggle(p, "partyFrameTargets.countdown", "CI_COUNTDOWN")
    toggle(p, "mobState.enabled", "CI_MOB_STATE")
    toggle(p, "mobState.absorb", "CI_ABSORB")
    toggle(p, "mobState.power", "CI_POWER")
    toggle(p, "mobState.immunity", "CI_IMMUNITY")
    toggle(p, "mobState.fixate", "CI_FIXATE")
    toggle(p, "mobState.thresholds", "CI_THRESHOLDS")
    toggle(p, "mobState.purge", "CI_PURGE")
    toggle(p, "castbarIntelligence.enabled", "CI_CASTBAR")
    toggle(p, "castbarIntelligence.interruptTick", "CI_INTERRUPT_TICK")
end

local function buildPrediction()
    local p = page("prediction")
    heading(p, "CP_SETTINGS")
    toggle(p, "castLearning.enabled", "CP_ENABLED", "CP_ENABLED_DESC")
    toggle(p, "castLearning.predictions", "CP_PREDICTIONS", "CP_PREDICTIONS_DESC")
    toggle(p, "castLearning.showPredictionAlerts", "CP_PREDICTION_ALERTS", "CP_PREDICTION_ALERTS_DESC")
    toggle(p, "castLearning.importantOnly", "CP_IMPORTANT", "CP_IMPORTANT_DESC")
    toggle(p, "castLearning.debug", "CP_DEBUG", "CP_DEBUG_DESC")
    slider(p, "castLearning.leadTime", "CP_LEAD_TIME", 0.3, 3.0, 0.1, "%.1fs")
    slider(p, "castLearning.minimumSamples", "CP_MIN_SAMPLES", 3, 20, 1, "%d")
    slider(p, "castLearning.minimumConfidence", "CP_MIN_CONFIDENCE", 0, 1, 0.05, "%.0f%%")
    heading(p, "CP_STATISTICS")
    local statsRow = panel(p.child, 12, p.y, 580, 58, 0.47)
    local statsText = label(statsRow, 11, 12, -10, 550, "", ACCENT)
    Options.controls[#Options.controls + 1] = function()
        local stats = BKA.CastLearning and BKA.CastLearning:GetSummary() or {}
        local accuracy = tonumber(stats.accuracy) or 0
        if accuracy <= 1 then accuracy = accuracy * 100 end
        statsText:SetText(BKA:L("CP_STATS_FMT", tostring(stats.dungeonID or "-"),
            tonumber(stats.observations) or 0, tonumber(stats.npcs) or 0,
            tonumber(stats.spells) or 0, tonumber(stats.entries) or 0,
            tonumber(stats.created) or 0, tonumber(stats.displayed) or 0,
            tonumber(stats.hits) or 0, tonumber(stats.misses) or 0, accuracy))
    end
    p.y = p.y - 65
    actions(p,
        {"CP_INSPECTOR", function() BKA.CastPredictionUI:OpenInspector() end},
        {"CP_EXPORT", function()
            local text = BKA.CastLearning and BKA.CastLearning:Export() or ""
            BKA.CastPredictionUI:ShowExport(text)
        end})
    heading(p, "CP_PREVIEW")
    local preview = panel(p.child, 12, p.y, 580, 147, 0.47)
    label(preview, 10, 12, -5, 550, BKA:L("OPT_ENEMY"), {0.76, 0.82, 0.86})
    local ghost = panel(preview, 12, -29, 260, 48, 0.45)
    local real = panel(preview, 294, -29, 270, 48, 0.78)
    ghost:SetAlpha(0.30)
    local ghostIcon = ghost:CreateTexture(nil, "ARTWORK")
    ghostIcon:SetSize(26, 26); ghostIcon:SetPoint("LEFT", 9, 0)
    ghostIcon:SetTexture("Interface\\Icons\\Ability_Kick"); ghostIcon:SetDesaturated(true)
    local realIcon = real:CreateTexture(nil, "ARTWORK")
    realIcon:SetSize(26, 26); realIcon:SetPoint("LEFT", 9, 0)
    realIcon:SetTexture("Interface\\Icons\\Ability_Kick")
    label(ghost, 10, 42, -8, 208, BKA:L("CP_GHOST_PREVIEW") .. " " .. BKA:LocalizeAction("KICK") .. "  ~0.8", ACCENT)
    label(real, 10, 42, -8, 218, BKA:L("CP_REAL_PREVIEW") .. " " .. BKA:LocalizeAction("KICK") .. "  0.8", ACCENT)
    local central = panel(preview, 12, -84, 552, 45, 0.78)
    central:SetAlpha(0.42)
    local centralIcon = central:CreateTexture(nil, "ARTWORK")
    centralIcon:SetSize(29, 29); centralIcon:SetPoint("LEFT", 8, 0)
    centralIcon:SetTexture("Interface\\Icons\\Ability_Kick"); centralIcon:SetDesaturated(true)
    label(central, 11, 47, -7, 440, BKA:L("CP_ALERT_PREVIEW") .. "  " .. BKA:LocalizeAction("KICK") .. "  -  " .. (GetSpellInfo(255371) or BKA:L("CP_GHOST_PREVIEW")), ACCENT)
    label(central, 14, 492, -12, 52, "~0.8", ACCENT)
    p.y = p.y - 155
end

local function buildKicks()
    local p = page("kicks")
    toggle(p, "kickTracker.shown", "OPT_KICKS", "OPT_KICKS_DESC")
    toggle(p, "kickTracker.onlyInKey", "OPT_ONLY_IN_KEY", "OPT_ONLY_IN_KEY_DESC")
    slider(p, "kickTracker.scale", "OPT_SCALE", 0.6, 2.0, 0.05, "%.2fx")
    slider(p, "kickTracker.width", "OPT_WIDTH", 240, 480, 10, "%d px")
    slider(p, "kickTracker.alpha", "OPT_ALPHA", 0.20, 1.00, 0.05, "%.0f%%")
    actions(p,
        {"OPT_LOCK_TOGGLE", function() set("kickTracker.locked", get("kickTracker.locked") == false); onChanged("kickTracker.locked") end},
        {"OPT_RESET_POSITION", function() BKA.GroupInterrupts:ResetPosition(); Options:Refresh() end})
end

local function buildCooldowns()
    local p = page("cooldowns")
    for _, kind in ipairs({"healer", "tank", "defensive"}) do
        local prefix = kind .. "HUD."
        local title = kind == "healer" and "GC_HEALER" or kind == "tank" and "GC_TANK" or "GC_DEFENSIVE"
        heading(p, title)
        toggle(p, prefix .. "shown", title, "GC_PANEL_DESC")
        toggle(p, prefix .. "onlyInKey", "OPT_ONLY_IN_KEY", "OPT_ONLY_IN_KEY_DESC")
        slider(p, prefix .. "scale", "OPT_SCALE", 0.6, 2, 0.05, "%.2fx")
        slider(p, prefix .. "alpha", "GC_ALPHA", 0.10, 1, 0.05, "%.0f%%")
        slider(p, prefix .. "backgroundAlpha", "OPT_ALPHA", 0, 1, 0.05, "%.0f%%")
        slider(p, prefix .. "iconSize", "CI_ICON_SIZE", 20, 56, 2, "%d px")
        if kind ~= "defensive" then
            slider(p, prefix .. "columns", "GC_COLUMNS", 1, 10, 1, "%d")
        end
        actions(p,
            {"OPT_LOCK_TOGGLE", function() set(prefix .. "locked", get(prefix .. "locked") == false); onChanged(prefix .. "locked") end},
            {"OPT_RESET_POSITION", function() BKA.GroupCooldowns:ResetPosition(kind); Options:Refresh() end})
    end
end

local function buildKeystone()
    local p = page("keystone")
    toggle(p, "keystoneHUD.shown", "OPT_KEY_HUD", "OPT_KEY_HUD_DESC")
    toggle(p, "keystoneHUD.hideBlizzard", "OPT_HIDE_BLIZZARD", "OPT_HIDE_BLIZZARD_DESC")
    toggle(p, "autoInsertKeystone", "OPT_AUTO_INSERT", "OPT_AUTO_INSERT_DESC")
    slider(p, "keystoneHUD.scale", "OPT_SCALE", 0.6, 2.0, 0.05, "%.2fx")
    slider(p, "keystoneHUD.backgroundAlpha", "OPT_ALPHA", 0, 1, 0.05, "%.0f%%")
    actions(p,
        {"OPT_LOCK_TOGGLE", function() set("keystoneHUD.locked", get("keystoneHUD.locked") == false); onChanged("keystoneHUD.locked") end},
        {"OPT_RESET_POSITION", function() BKA.KeystoneHUD:ResetPosition(); Options:Refresh() end})
end

local function buildSounds()
    local p = page("sounds")
    toggle(p, "sound", "OPT_SOUND", "OPT_SOUND_DESC")
    heading(p, "OPT_PER_ACTION")
    label(p.child, 10, 16, p.y, 550, BKA:L("OPT_SOUND_HINT"), {0.76, 0.82, 0.86})
    p.y = p.y - 34
    local soundActions = BKA.Sounds:GetActions()
    for i, action in ipairs(soundActions) do
        local column = (i - 1) % 3
        local row = math.floor((i - 1) / 3)
        local x, y = 12 + column * 196, p.y - row * 43
        local box = panel(p.child, x, y, 187, 36, 0.47)
        local toggleSound = button(box, "", 5, -5, 112, 26, function()
            BKA.db.soundActions[action] = BKA.db.soundActions[action] == false
            Options:Refresh()
        end)
        button(box, "▶", 123, -5, 58, 26, function() BKA.Sounds:Preview(action) end)
        Options.controls[#Options.controls + 1] = function()
            local active = BKA.db.soundActions[action] ~= false
            toggleSound.text:SetText(BKA:LocalizeAction(action) .. " " .. BKA:L(active and "ON" or "OFF"))
        end
    end
    p.y = p.y - math.ceil(#soundActions / 3) * 43 - 10
    actions(p,
        {"OPT_PLAY_ALL", function() BKA.Sounds:PreviewAll() end},
        {"OPT_RESET_SOUNDS", function() BKA.Sounds:ResetActions(); Options:Refresh() end},
        {"OPT_PLAY_VICTORY", function() BKA.Sounds:PlayKeyUpgrade(true) end})
end

function Options:Initialize()
    if self.frame then return end
    local frame = CreateFrame("Frame", "BFAKeyAlertsSettingsHUD", UIParent)
    frame:SetSize(850, 540)
    frame:SetPoint("CENTER")
    frame:SetScale(1)
    frame:SetFrameStrata("DIALOG")
    frame:SetClampedToScreen(true)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    style(frame, 0.97)
    local accent = frame:CreateTexture(nil, "ARTWORK")
    accent:SetTexture(WHITE); accent:SetVertexColor(unpack(ACCENT))
    accent:SetPoint("TOPLEFT", 1, -1); accent:SetPoint("TOPRIGHT", -1, -1); accent:SetHeight(2)
    local header = CreateFrame("Frame", nil, frame)
    header:SetPoint("TOPLEFT", 0, 0); header:SetPoint("TOPRIGHT", -48, 0); header:SetHeight(51)
    header:EnableMouse(true); header:RegisterForDrag("LeftButton")
    header:SetScript("OnDragStart", function() frame:StartMoving() end)
    header:SetScript("OnDragStop", function() frame:StopMovingOrSizing() end)
    label(frame, 17, 18, -18, 350, BKA:L("ADDON_TITLE"))
    label(frame, 10, 20, -42, 350, BKA:L("OPT_SUBTITLE"), {0.76, 0.82, 0.86})
    self:AddSupportLink(frame, "TOPRIGHT", "TOPRIGHT", -61, -30, 385)
    local close = button(frame, "×", 806, -11, 32, 30, function() frame:Hide() end)
    close:SetFrameLevel(header:GetFrameLevel() + 1)
    local separator = frame:CreateTexture(nil, "BACKGROUND")
    separator:SetTexture(WHITE); separator:SetVertexColor(0.20, 0.31, 0.37)
    separator:SetPoint("TOPLEFT", 184, -55); separator:SetPoint("BOTTOMLEFT", 184, 12); separator:SetWidth(1)
    self.content = CreateFrame("Frame", nil, frame)
    self.content:SetPoint("TOPLEFT", 198, -63)
    self.content:SetSize(630, 465)
    self.nav = {}
    for i, section in ipairs(SECTIONS) do
        local nav = button(frame, BKA:L("OPT_" .. string.upper(section)), 12, -74 - (i - 1) * 44, 160, 35, function() Options:ShowSection(section) end)
        self.nav[section] = nav
    end
    self.frame = frame
    buildGeneral(); buildMechanics(); buildNameplates(); buildPrediction(); buildIntelligence(); buildKicks(); buildCooldowns(); buildKeystone(); buildSounds()
    for _, item in pairs(self.pages) do
        item.child:SetHeight(math.max(465, -item.y + 16))
    end
    frame:SetScript("OnHide", function()
        if BKA.Sounds then BKA.Sounds.previewGeneration = BKA.Sounds.previewGeneration + 1 end
    end)
    frame:Hide()
    tinsert(UISpecialFrames, frame:GetName())
    self:ShowSection("general")
end

function Options:ShowSection(section)
    section = self.pages[section] and section or "general"
    self.section = section
    for key, item in pairs(self.pages) do item.scroll:SetShown(key == section) end
    for key, nav in pairs(self.nav) do
        nav.selected = key == section
        updateButtonVisual(nav)
    end
    self:Refresh()
end

function Options:Refresh()
    if not self.frame or not BKA.db then return end
    self.updating = true
    for _, refresh in ipairs(self.controls) do refresh() end
    self.updating = false
end

function Options:ResetLayout()
    local layout = BKA.db.layout
    layout.point, layout.relativePoint, layout.x, layout.y, layout.scale, layout.width = "TOP", "TOP", 0, -155, 1, 370
    BKA.Alerts:ApplyLayout()
    self:Refresh()
end

function Options:Open(section)
    self:Initialize()
    self:ShowSection(section or self.section or "general")
    self.frame:Show()
end
