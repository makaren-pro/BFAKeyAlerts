local BKA = BFAKeyAlerts
local Options = {}
BKA.Options = Options

local isRussian = BKA.locale == "ruRU"
local L = isRussian and {
    title = "BFA Key Alerts",
    rootDescription = "Настройки разделены по разделам. Выберите нужный пункт слева или откройте его кнопкой ниже.",
    general = "Основное", mechanics = "Механики", nameplates = "Неймплейты",
    kicks = "Кики группы", keystone = "Таймер ключа", sounds = "Звуки",

    generalDescription = "Основное состояние аддона и отдельное управление центральными предупреждениями.",
    mechanicsDescription = "Фильтры механик по ролям и сезонным аффиксам.",
    nameplatesDescription = "Отдельное включение и поведение предупреждений на неймплейтах мобов.",
    kicksDescription = "Компактная панель киков и контроля группы: основной кик и дополнительные способности контроля.",
    keystoneDescription = "Mythic+ таймер из ProtPixelBFA: +3/+2/+1, силы, боссы, смерти и штраф.",
    soundsDescription = "Глобальный звук, отдельные голосовые действия и ручное прослушивание.",

    enabled = "Включить BFA Key Alerts",
    enableAlerts = "Показывать центральные Alerts",
    enableNameplates = "Показывать BKA-неймплейты",
    globalSound = "Включить боевые звуки",
    centerAlerts = "Центральные предупреждения",
    preview = "Показать превью", hidePreview = "Скрыть превью",
    unlock = "Разблокировать", lock = "Закрепить", reset = "Сбросить положение",
    scale = "Масштаб", width = "Ширина", opacity = "Прозрачность фона", panelOpacity = "Прозрачность панели",
    style = "Стиль предупреждений", bar = "Полоса", icon = "Иконка",
    tank = "Танковые предупреждения", healer = "Хилерские предупреждения",
    infested = "Показывать метки Г'ууна (заражённые мобы + Spawn)",
    roleFilters = "Ролевые фильтры", seasonal = "Сезонные механики",
    frontalTarget = "Показывать цель и режим FRONTAL",
    clickableNameplateAlerts = "Клик по BKA-алерту выбирает моба",
    nameplateBehavior = "Поведение неймплейтов",
    showKickTracker = "Показывать панель киков группы",
    onlyInKey = "Показывать только в активном ключе",
    kickTracker = "Кики + контроль",
    kickHint = "Слева - игрок, иконка основного кика и полоса КД. Справа - до 4 компактных иконок дополнительных киков/СС. ? означает, что талант пока не подтверждён по боевому логу.",
    showKeystone = "Показывать новый таймер ключа",
    hideBlizzard = "Скрывать стандартный таймер и Objective Tracker в активном ключе",
    keystoneHint = "Сними закрепление, чтобы увидеть превью вне ключа и перетащить таймер голубой полоской сверху.",
    soundActions = "Звуки действий", testAllSounds = "Прослушать все звуки", resetCombatSounds = "Сбросить боевые звуки",
    soundHint = "Галочка включает звук действия; кнопка справа воспроизводит его вручную.",
    hint = "Нажмите кнопку Разблокировать, затем перетащите голубую область мышью.",

    rootGeneralHint = "Главный переключатель и центральные Alerts.",
    rootMechanicsHint = "Танк/хил фильтры и 4-й сезонный аффикс.",
    rootNameplatesHint = "Геометрия AOE/CLEAVE, FRONTAL и кликабельные маркеры.",
    rootKicksHint = "Кики и дополнительные способности контроля всей группы.",
    rootKeystoneHint = "Новый Mythic+ таймер вместо стандартного.",
    rootSoundsHint = "Глобальный звук и отдельные голосовые команды.",
} or {
    title = "BFA Key Alerts",
    rootDescription = "Settings are split into sections. Pick a category on the left or use the buttons below.",
    general = "General", mechanics = "Mechanics", nameplates = "Nameplates",
    kicks = "Group kicks", keystone = "Keystone timer", sounds = "Sounds",

    generalDescription = "Master addon state and independent center-alert visibility.",
    mechanicsDescription = "Role and seasonal-affix filters.",
    nameplatesDescription = "Independent enable switch and behavior for enemy nameplate alerts.",
    kicksDescription = "Compact party interrupts and control: primary kick and additional CC.",
    keystoneDescription = "ProtPixelBFA Mythic+ timer: +3/+2/+1, forces, bosses, deaths, and penalty.",
    soundsDescription = "Global combat sound, per-action voice alerts, and manual previews.",

    enabled = "Enable BFA Key Alerts", enableAlerts = "Show center alerts", enableNameplates = "Show BKA nameplates",
    globalSound = "Enable combat sounds", centerAlerts = "Center alerts",
    preview = "Show preview", hidePreview = "Hide preview", unlock = "Unlock", lock = "Lock", reset = "Reset position",
    scale = "Scale", width = "Width", opacity = "Background opacity", panelOpacity = "Panel opacity",
    style = "Alert style", bar = "Bar", icon = "Icon",
    tank = "Tank alerts", healer = "Healer alerts", infested = "Show G'huun markers (infested mobs + Spawn)",
    roleFilters = "Role filters", seasonal = "Seasonal mechanics",
    frontalTarget = "Show FRONTAL target and mode", clickableNameplateAlerts = "Click BKA nameplate alert to target mob",
    nameplateBehavior = "Nameplate behavior",
    showKickTracker = "Show group kick tracker", onlyInKey = "Show only during an active keystone", kickTracker = "Interrupts + control",
    kickHint = "Player, main-kick icon and cooldown bar are on the left. Up to 4 compact extra-kick/CC icons are on the right. ? means an optional talent has not been confirmed from combat log yet.",
    showKeystone = "Show custom keystone timer", hideBlizzard = "Hide Blizzard timer and Objective Tracker during an active key",
    keystoneHint = "Unlock to preview outside a key and drag using the blue handle above the panel.",
    soundActions = "Action sounds", testAllSounds = "Preview all sounds", resetCombatSounds = "Reset combat sounds",
    soundHint = "The checkbox enables that combat sound; the button previews it.",
    hint = "Click Unlock, then drag the blue area with the mouse.",

    rootGeneralHint = "Master switch and center alerts.", rootMechanicsHint = "Tank/healer filters and seasonal affix.",
    rootNameplatesHint = "AOE/CLEAVE geometry, FRONTAL details and clickable mob alerts.",
    rootKicksHint = "Party kicks and CC in one compact HUD.", rootKeystoneHint = "Custom Mythic+ timer replacing Blizzard presentation.",
    rootSoundsHint = "Global sound and individual voice actions.",
}

local function createButton(parent, text, width, x, y, callback)
    local button = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    button:SetSize(width, 24); button:SetPoint("TOPLEFT", x, y); button:SetText(text); button:SetScript("OnClick", callback)
    return button
end

local function createSlider(parent, name, label, minValue, maxValue, step, x, y, callback)
    local slider = CreateFrame("Slider", name, parent, "OptionsSliderTemplate")
    slider:SetPoint("TOPLEFT", x, y); slider:SetWidth(280); slider:SetMinMaxValues(minValue, maxValue); slider:SetValueStep(step)
    _G[name .. "Text"]:SetText(label); _G[name .. "Low"]:SetText(tostring(minValue)); _G[name .. "High"]:SetText(tostring(maxValue))
    slider.valueText = parent:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    slider.valueText:SetPoint("LEFT", slider, "RIGHT", 18, 0)
    slider:SetScript("OnValueChanged", callback)
    return slider
end

local function createCheckbox(parent, label, x, y, callback)
    local check = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    check:SetPoint("TOPLEFT", x, y); check:SetSize(24, 24)
    check.label = parent:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    check.label:SetPoint("LEFT", check, "RIGHT", 4, 0); check.label:SetText(label)
    check:SetScript("OnClick", callback)
    return check
end

local function createTitle(panel, titleText, descriptionText)
    local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -16); title:SetText(titleText)
    local description = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    description:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -10); description:SetPoint("RIGHT", panel, "RIGHT", -20, 0)
    description:SetJustifyH("LEFT"); description:SetText(descriptionText or "")
    return title, description
end

local function createSectionTitle(panel, text, x, y)
    local label = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    label:SetPoint("TOPLEFT", x, y); label:SetText(text); return label
end

local function createHint(panel, text, x, y, width)
    local label = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    label:SetPoint("TOPLEFT", x, y)
    if width then label:SetWidth(width); label:SetJustifyH("LEFT") end
    label:SetText(text); label:SetTextColor(0.72, 0.76, 0.82); return label
end

local function createChildPanel(name)
    local panel = CreateFrame("Frame", nil, InterfaceOptionsFramePanelContainer)
    panel.name = name; panel.parent = L.title; InterfaceOptions_AddCategory(panel); return panel
end

local function refreshCombatPresentation(clearCenter)
    if clearCenter and BKA.Alerts then BKA.Alerts:Clear() end
    if BKA.Nameplates and BKA.Nameplates.RefreshAll then BKA.Nameplates:RefreshAll() end
end

function Options:Initialize()
    if self.panel then return end

    local root = CreateFrame("Frame", "BFAKeyAlertsOptionsPanel", InterfaceOptionsFramePanelContainer)
    root.name = L.title
    createTitle(root, L.title, L.rootDescription)
    local sections = {
        { key = "general", label = L.general, hint = L.rootGeneralHint },
        { key = "mechanics", label = L.mechanics, hint = L.rootMechanicsHint },
        { key = "nameplates", label = L.nameplates, hint = L.rootNameplatesHint },
        { key = "kicks", label = L.kicks, hint = L.rootKicksHint },
        { key = "keystone", label = L.keystone, hint = L.rootKeystoneHint },
        { key = "sounds", label = L.sounds, hint = L.rootSoundsHint },
    }
    for index, section in ipairs(sections) do
        local y = -82 - (index - 1) * 69
        createButton(root, section.label, 180, 18, y, function() Options:Open(section.key) end)
        createHint(root, section.hint, 216, y - 4, 360)
    end
    root:SetScript("OnShow", function() Options:Refresh() end)
    InterfaceOptions_AddCategory(root); self.panel = root

    -- General -----------------------------------------------------------------
    local general = createChildPanel(L.general)
    createTitle(general, L.title .. " - " .. L.general, L.generalDescription)
    self.enabledCheck = createCheckbox(general, L.enabled, 18, -86, function(check)
        BKA.db.enabled = check:GetChecked() and true or false
        BKA:RefreshActivation()
        if not BKA.db.enabled and BKA.Alerts then BKA.Alerts:Clear() end
        if BKA.Nameplates then BKA.Nameplates:RefreshAll(); BKA.Nameplates:RefreshClickTargeting() end
        if BKA.GroupInterrupts then BKA.GroupInterrupts:Refresh(true) end
        if BKA.KeystoneHUD then BKA.KeystoneHUD:Refresh(true) end
    end)
    createSectionTitle(general, L.centerAlerts, 18, -130)
    self.alertsEnabledCheck = createCheckbox(general, L.enableAlerts, 18, -154, function(check)
        BKA.db.showAlerts = check:GetChecked() and true or false
        if not BKA.db.showAlerts then BKA.Alerts:Clear() end
    end)
    self.previewButton = createButton(general, L.preview, 145, 18, -194, function() Options:TogglePreview() end)
    self.moveButton = createButton(general, L.unlock, 145, 172, -194, function() BKA.Alerts:SetUnlocked(not BKA.Alerts.unlocked) end)
    self.resetButton = createButton(general, L.reset, 170, 326, -194, function() Options:ResetLayout() end)
    createHint(general, L.hint, 20, -228, 560)
    createSectionTitle(general, L.style, 18, -266)
    self.barButton = createButton(general, L.bar, 90, 172, -260, function() Options:SetStyle("BAR") end)
    self.iconButton = createButton(general, L.icon, 90, 267, -260, function() Options:SetStyle("ICON") end)
    self.scaleSlider = createSlider(general, "BFAKeyAlertsScaleSlider", L.scale, 0.6, 1.6, 0.05, 22, -322, function(_, value)
        if Options.updating then return end
        BKA.db.layout.scale = math.floor(value * 20 + 0.5) / 20; BKA.Alerts:ApplyLayout(); Options:UpdateSliderLabels()
    end)
    self.widthSlider = createSlider(general, "BFAKeyAlertsWidthSlider", L.width, 280, 520, 10, 22, -386, function(_, value)
        if Options.updating then return end
        BKA.db.layout.width = math.floor(value / 10 + 0.5) * 10; BKA.Alerts:ApplyLayout(); Options:UpdateSliderLabels()
    end)
    general:SetScript("OnShow", function() Options:Refresh() end); self.generalPanel = general

    -- Mechanics ---------------------------------------------------------------
    local mechanics = createChildPanel(L.mechanics)
    createTitle(mechanics, L.title .. " - " .. L.mechanics, L.mechanicsDescription)
    createSectionTitle(mechanics, L.roleFilters, 18, -92)
    self.tankCheck = createCheckbox(mechanics, L.tank, 18, -120, function(check)
        BKA.db.showTankAlerts = check:GetChecked() and true or false; refreshCombatPresentation(true)
    end)
    self.healerCheck = createCheckbox(mechanics, L.healer, 18, -154, function(check)
        BKA.db.showHealerAlerts = check:GetChecked() and true or false; refreshCombatPresentation(true)
    end)
    createSectionTitle(mechanics, L.seasonal, 18, -208)
    self.infestedCheck = createCheckbox(mechanics, L.infested, 18, -236, function(check)
        BKA.db.showInfestedAdds = check:GetChecked() and true or false; refreshCombatPresentation(true)
    end)
    mechanics:SetScript("OnShow", function() Options:Refresh() end); self.mechanicsPanel = mechanics

    -- Nameplates --------------------------------------------------------------
    local nameplates = createChildPanel(L.nameplates)
    createTitle(nameplates, L.title .. " - " .. L.nameplates, L.nameplatesDescription)
    createSectionTitle(nameplates, L.nameplateBehavior, 18, -92)
    self.nameplatesEnabledCheck = createCheckbox(nameplates, L.enableNameplates, 18, -120, function(check)
        BKA.db.showNameplates = check:GetChecked() and true or false
        if BKA.db.showNameplates then BKA.Nameplates:RefreshAll() else BKA.Nameplates:Clear() end
        BKA.Nameplates:RefreshClickTargeting()
    end)
    self.frontalTargetCheck = createCheckbox(nameplates, L.frontalTarget, 18, -154, function(check)
        BKA.db.showFrontalTarget = check:GetChecked() and true or false; refreshCombatPresentation(false)
    end)
    self.clickableNameplateCheck = createCheckbox(nameplates, L.clickableNameplateAlerts, 18, -188, function(check)
        BKA.db.clickableNameplateAlerts = check:GetChecked() and true or false; BKA.Nameplates:RefreshClickTargeting()
    end)
    nameplates:SetScript("OnShow", function() Options:Refresh() end); self.nameplatesPanel = nameplates

    -- Group kicks -------------------------------------------------------------
    local kicks = createChildPanel(L.kicks)
    createTitle(kicks, L.title .. " - " .. L.kicks, L.kicksDescription)
    self.kicksShownCheck = createCheckbox(kicks, L.showKickTracker, 18, -92, function(check)
        BKA.db.kickTracker.shown = check:GetChecked() and true or false; BKA.GroupInterrupts:Refresh(true)
    end)
    self.kicksOnlyInKeyCheck = createCheckbox(kicks, L.onlyInKey, 18, -126, function(check)
        BKA.db.kickTracker.onlyInKey = check:GetChecked() and true or false; BKA.GroupInterrupts:Refresh(true)
    end)
    createSectionTitle(kicks, L.kickTracker, 18, -168)
    self.kicksLockButton = createButton(kicks, L.unlock, 145, 18, -194, function()
        BKA.db.kickTracker.locked = not BKA.db.kickTracker.locked; BKA.GroupInterrupts:ApplySettings(); Options:UpdateButtons()
    end)
    self.kicksResetButton = createButton(kicks, L.reset, 170, 172, -194, function()
        BKA.GroupInterrupts:ResetPosition(); Options:Refresh()
    end)
    self.kicksScaleSlider = createSlider(kicks, "BFAKeyAlertsKickScaleSlider", L.scale, 0.6, 2.0, 0.05, 22, -250, function(_, value)
        if Options.updating then return end
        BKA.db.kickTracker.scale = math.floor(value * 20 + 0.5) / 20; BKA.GroupInterrupts:ApplySettings(); Options:UpdateSliderLabels()
    end)
    self.kicksWidthSlider = createSlider(kicks, "BFAKeyAlertsKickWidthSlider", L.width, 280, 480, 10, 22, -308, function(_, value)
        if Options.updating then return end
        BKA.db.kickTracker.width = math.floor(value / 10 + 0.5) * 10; BKA.GroupInterrupts:ApplySettings(); BKA.GroupInterrupts:Refresh(true); Options:UpdateSliderLabels()
    end)
    self.kicksAlphaSlider = createSlider(kicks, "BFAKeyAlertsKickAlphaSlider", L.panelOpacity, 0.20, 1.00, 0.05, 22, -366, function(_, value)
        if Options.updating then return end
        BKA.db.kickTracker.alpha = math.floor(value * 20 + 0.5) / 20; BKA.GroupInterrupts:ApplySettings(); Options:UpdateSliderLabels()
    end)
    createHint(kicks, L.kickHint, 20, -420, 560)
    kicks:SetScript("OnShow", function() Options:Refresh() end); self.kicksPanel = kicks

    -- Keystone timer ----------------------------------------------------------
    local keystone = createChildPanel(L.keystone)
    createTitle(keystone, L.title .. " - " .. L.keystone, L.keystoneDescription)
    self.keystoneShownCheck = createCheckbox(keystone, L.showKeystone, 18, -92, function(check)
        BKA.db.keystoneHUD.shown = check:GetChecked() and true or false; BKA.KeystoneHUD:Refresh(true)
    end)
    self.hideBlizzardCheck = createCheckbox(keystone, L.hideBlizzard, 18, -126, function(check)
        BKA.db.keystoneHUD.hideBlizzard = check:GetChecked() and true or false; BKA.KeystoneHUD:Refresh(true)
    end)
    self.keystoneLockButton = createButton(keystone, L.unlock, 145, 18, -170, function()
        BKA.db.keystoneHUD.locked = not BKA.db.keystoneHUD.locked; BKA.KeystoneHUD:ApplySettings(); BKA.KeystoneHUD:Refresh(true); Options:UpdateButtons()
    end)
    self.keystoneResetButton = createButton(keystone, L.reset, 170, 172, -170, function()
        BKA.KeystoneHUD:ResetPosition(); Options:Refresh()
    end)
    self.keystoneScaleSlider = createSlider(keystone, "BFAKeyAlertsKeyScaleSlider", L.scale, 0.6, 2.0, 0.05, 22, -236, function(_, value)
        if Options.updating then return end
        BKA.db.keystoneHUD.scale = math.floor(value * 20 + 0.5) / 20; BKA.KeystoneHUD:ApplySettings(); BKA.KeystoneHUD:Refresh(true); Options:UpdateSliderLabels()
    end)
    self.keystoneAlphaSlider = createSlider(keystone, "BFAKeyAlertsKeyAlphaSlider", L.opacity, 0, 1, 0.05, 22, -300, function(_, value)
        if Options.updating then return end
        BKA.db.keystoneHUD.backgroundAlpha = math.floor(value * 20 + 0.5) / 20; BKA.KeystoneHUD:ApplySettings(); Options:UpdateSliderLabels()
    end)
    createHint(keystone, L.keystoneHint, 20, -356, 560)
    keystone:SetScript("OnShow", function() Options:Refresh() end); self.keystonePanel = keystone

    -- Sounds ------------------------------------------------------------------
    local sounds = createChildPanel(L.sounds)
    createTitle(sounds, L.title .. " - " .. L.sounds, L.soundsDescription)
    self.soundEnabledCheck = createCheckbox(sounds, L.globalSound, 18, -86, function(check) BKA.db.sound = check:GetChecked() and true or false end)
    createSectionTitle(sounds, L.soundActions, 18, -130); createHint(sounds, L.soundHint, 18, -154, 570)
    local actions = BKA.Sounds:GetActions(); self.soundChecks = {}
    for index, action in ipairs(actions) do
        local column, row = math.floor((index - 1) / 7), (index - 1) % 7
        local x, y = 18 + column * 180, -178 - row * 31
        local check = CreateFrame("CheckButton", nil, sounds, "UICheckButtonTemplate")
        check:SetPoint("TOPLEFT", x, y); check:SetSize(24, 24)
        check:SetScript("OnClick", function(button) BKA.db.soundActions[action] = button:GetChecked() and true or false end)
        self.soundChecks[action] = check
        createButton(sounds, BKA:LocalizeAction(action), 142, x + 28, y, function() BKA.Sounds:Preview(action) end)
    end
    createButton(sounds, L.resetCombatSounds, 190, 18, -416, function() BKA.Sounds:ResetActions(); Options:Refresh() end)
    createButton(sounds, L.testAllSounds, 180, 218, -416, function() BKA.Sounds:PreviewAll() end)
    sounds:SetScript("OnShow", function() Options:Refresh() end); self.soundsPanel = sounds

    self:Refresh()
end

function Options:Refresh()
    if not self.panel or not BKA.db then return end
    self.updating = true
    if self.enabledCheck then self.enabledCheck:SetChecked(BKA.db.enabled ~= false) end
    if self.alertsEnabledCheck then self.alertsEnabledCheck:SetChecked(BKA.db.showAlerts ~= false) end
    if self.nameplatesEnabledCheck then self.nameplatesEnabledCheck:SetChecked(BKA.db.showNameplates ~= false) end
    if self.soundEnabledCheck then self.soundEnabledCheck:SetChecked(BKA.db.sound ~= false) end
    if self.scaleSlider then self.scaleSlider:SetValue(BKA.db.layout.scale) end
    if self.widthSlider then self.widthSlider:SetValue(BKA.db.layout.width) end
    if self.tankCheck then self.tankCheck:SetChecked(BKA.db.showTankAlerts) end
    if self.healerCheck then self.healerCheck:SetChecked(BKA.db.showHealerAlerts) end
    if self.infestedCheck then self.infestedCheck:SetChecked(BKA.db.showInfestedAdds ~= false) end
    if self.frontalTargetCheck then self.frontalTargetCheck:SetChecked(BKA.db.showFrontalTarget ~= false) end
    if self.clickableNameplateCheck then self.clickableNameplateCheck:SetChecked(BKA.db.clickableNameplateAlerts ~= false) end

    if self.kicksShownCheck then self.kicksShownCheck:SetChecked(BKA.db.kickTracker.shown ~= false) end
    if self.kicksOnlyInKeyCheck then self.kicksOnlyInKeyCheck:SetChecked(BKA.db.kickTracker.onlyInKey == true) end
    if self.kicksScaleSlider then self.kicksScaleSlider:SetValue(BKA.db.kickTracker.scale or 1) end
    if self.kicksWidthSlider then self.kicksWidthSlider:SetValue(BKA.db.kickTracker.width or 320) end
    if self.kicksAlphaSlider then self.kicksAlphaSlider:SetValue(BKA.db.kickTracker.alpha or 0.92) end
    if self.keystoneShownCheck then self.keystoneShownCheck:SetChecked(BKA.db.keystoneHUD.shown ~= false) end
    if self.hideBlizzardCheck then self.hideBlizzardCheck:SetChecked(BKA.db.keystoneHUD.hideBlizzard ~= false) end
    if self.keystoneScaleSlider then self.keystoneScaleSlider:SetValue(BKA.db.keystoneHUD.scale or 1) end
    if self.keystoneAlphaSlider then self.keystoneAlphaSlider:SetValue(BKA.db.keystoneHUD.backgroundAlpha or 0.75) end

    for action, check in pairs(self.soundChecks or {}) do check:SetChecked(BKA.db.soundActions[action] ~= false) end
    self.updating = false
    self:UpdateSliderLabels(); self:UpdateButtons()
end

function Options:UpdateSliderLabels()
    if self.scaleSlider and self.scaleSlider.valueText then self.scaleSlider.valueText:SetFormattedText("%.2fx", BKA.db.layout.scale) end
    if self.widthSlider and self.widthSlider.valueText then self.widthSlider.valueText:SetFormattedText("%d px", BKA.db.layout.width) end
    if self.kicksScaleSlider and self.kicksScaleSlider.valueText then self.kicksScaleSlider.valueText:SetFormattedText("%.2fx", BKA.db.kickTracker.scale or 1) end
    if self.kicksWidthSlider and self.kicksWidthSlider.valueText then self.kicksWidthSlider.valueText:SetFormattedText("%d px", BKA.db.kickTracker.width or 320) end
    if self.kicksAlphaSlider and self.kicksAlphaSlider.valueText then self.kicksAlphaSlider.valueText:SetFormattedText("%d%%", math.floor((BKA.db.kickTracker.alpha or 0.92) * 100 + 0.5)) end
    if self.keystoneScaleSlider and self.keystoneScaleSlider.valueText then self.keystoneScaleSlider.valueText:SetFormattedText("%.2fx", BKA.db.keystoneHUD.scale or 1) end
    if self.keystoneAlphaSlider and self.keystoneAlphaSlider.valueText then self.keystoneAlphaSlider.valueText:SetFormattedText("%d%%", math.floor((BKA.db.keystoneHUD.backgroundAlpha or 0.75) * 100 + 0.5)) end
end

function Options:UpdateButtons()
    if not self.panel then return end
    if self.previewButton then self.previewButton:SetText(BKA.Alerts.previewVisible and L.hidePreview or L.preview) end
    if self.moveButton then self.moveButton:SetText(BKA.Alerts.unlocked and L.lock or L.unlock) end
    if self.barButton then self.barButton:SetText((BKA.db.alertStyle == "BAR" and "[ " or "") .. L.bar .. (BKA.db.alertStyle == "BAR" and " ]" or "")) end
    if self.iconButton then self.iconButton:SetText((BKA.db.alertStyle == "ICON" and "[ " or "") .. L.icon .. (BKA.db.alertStyle == "ICON" and " ]" or "")) end
    if self.kicksLockButton then self.kicksLockButton:SetText(BKA.db.kickTracker.locked == false and L.lock or L.unlock) end
    if self.keystoneLockButton then self.keystoneLockButton:SetText(BKA.db.keystoneHUD.locked == false and L.lock or L.unlock) end
end

function Options:SetStyle(style)
    BKA.db.alertStyle = style == "ICON" and "ICON" or "BAR"; BKA.Alerts:ApplyLayout(); self:UpdateButtons()
end

function Options:TogglePreview(forceShow, withSound)
    if forceShow or not BKA.Alerts.previewVisible then BKA.Alerts:ShowPreview(withSound) else BKA.Alerts:HidePreview() end
    self:UpdateButtons()
end

function Options:ResetLayout()
    local layout = BKA.db.layout
    layout.point, layout.relativePoint, layout.x, layout.y, layout.scale, layout.width = "TOP", "TOP", 0, -155, 1, 370
    BKA.Alerts:ApplyLayout(); self:Refresh()
end

function Options:GetPanel(section)
    if section == "general" then return self.generalPanel end
    if section == "mechanics" then return self.mechanicsPanel end
    if section == "nameplates" then return self.nameplatesPanel end
    if section == "kicks" then return self.kicksPanel end
    if section == "keystone" then return self.keystonePanel end
    if section == "sounds" then return self.soundsPanel end
    return self.generalPanel or self.panel
end

function Options:Open(section)
    self:Initialize()
    local panel = self:GetPanel(section)
    InterfaceOptionsFrame_OpenToCategory(panel)
    InterfaceOptionsFrame_OpenToCategory(panel)
end
