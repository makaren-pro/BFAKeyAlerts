local BKA = BFAKeyAlerts
local KeystoneHUD = {}
BKA.KeystoneHUD = KeystoneHUD

local colors = {
    {0.40, 0.88, 0.74}, -- +3
    {0.40, 0.72, 1.00}, -- +2
    {1.00, 0.77, 0.40}, -- +1
}

local function clock(seconds)
    local negative = seconds < 0
    seconds = math.floor(math.abs(seconds))
    return (negative and "-" or "") .. string.format("%02d:%02d", math.floor(seconds / 60), seconds % 60)
end

local function readRun()
    if not (C_ChallengeMode and C_ChallengeMode.GetActiveChallengeMapID and C_Scenario and GetWorldElapsedTimers and GetWorldElapsedTime) then return end
    local mapID = C_ChallengeMode.GetActiveChallengeMapID()
    if not mapID or mapID == 0 then return end
    local name, _, limit = C_ChallengeMode.GetMapUIInfo(mapID)
    if not limit or limit <= 0 then return end

    local elapsed
    for _, id in ipairs({GetWorldElapsedTimers()}) do
        local _, time, timerType = GetWorldElapsedTime(id)
        if timerType == LE_WORLD_ELAPSED_TIMER_TYPE_CHALLENGE_MODE then elapsed = time; break end
    end

    local level, affixes = C_ChallengeMode.GetActiveKeystoneInfo()
    local run = {
        name = name or "Подземелье", limit = limit, elapsed = elapsed, level = level or 0,
        affixes = {}, bosses = {}, bossCount = 0, bossDone = 0,
    }
    for _, id in ipairs(affixes or {}) do
        local title, _, icon = C_ChallengeMode.GetAffixInfo(id)
        run.affixes[#run.affixes + 1] = (icon and ("|T" .. icon .. ":14:14:0:0|t ") or "") .. (title or tostring(id))
    end

    local count = select(3, C_Scenario.GetStepInfo()) or 0
    for i = 1, count do
        local title, _, done, quantity, total, _, _, _, _, _, _, _, weighted = C_Scenario.GetCriteriaInfo(i)
        if title then
            if weighted then
                run.forces = done and 100 or tonumber(quantity)
                if not run.forces and total and total > 0 then run.forces = 100 * (tonumber(quantity) or 0) / total end
            else
                run.bossCount = run.bossCount + 1
                if done then run.bossDone = run.bossDone + 1 else run.bosses[#run.bosses + 1] = "-  " .. title end
            end
        end
    end
    if C_ChallengeMode.GetDeathCount then run.deaths, run.penalty = C_ChallengeMode.GetDeathCount() end
    return run
end

function KeystoneHUD:CreateFrame()
    if self.frame then return self.frame end
    local settings = BKA.db.keystoneHUD
    local f = BKA.HUD:CreatePanel("BFAKeyAlerts_KeystoneHUD", settings, "Таймер ключа", -350, 0)
    f:SetSize(292, 240)
    f.eyebrow = BKA.HUD:Text(f, 9, 12, -10, 268)
    f.title = BKA.HUD:Text(f, 14, 12, -24, 268)
    f.title:SetWordWrap(false)
    f.affixes = BKA.HUD:Text(f, 10, 12, -45, 268)
    f.timers = {}
    for i = 1, 3 do
        local x, c = 12 + (i - 1) * 90, colors[i]
        local tile = {}
        tile.label = BKA.HUD:Text(f, 10, x, -72, 84); tile.label:SetText("+" .. (4 - i)); tile.label:SetTextColor(unpack(c))
        tile.time = BKA.HUD:Text(f, 19, x, -86, 88)
        tile.bar = BKA.HUD:Bar(f, x, -110, 84, 4, unpack(c))
        f.timers[i] = tile
    end
    f.forces = BKA.HUD:Text(f, 11, 12, -128, 268)
    f.forcesBar = BKA.HUD:Bar(f, 12, -145, 268, 4, 0.40, 0.88, 0.74)
    f.bossTitle = BKA.HUD:Text(f, 10, 12, -158, 268)
    f.bosses = BKA.HUD:Text(f, 11, 12, -174, 268); f.bosses:SetSpacing(2)
    f.footer = BKA.HUD:Text(f, 9, 12, -220, 268); f.footer:SetTextColor(0.55, 0.64, 0.73)
    self.frame = f
    return f
end

function KeystoneHUD:SetBlizzardTimerHidden(hidden)
    local block = ScenarioChallengeModeBlock
    if hidden and block then
        if not self.defaultBlock then self.defaultBlock, self.defaultAlpha = block, block:GetAlpha() end
        block:SetAlpha(0)
    elseif self.defaultBlock then
        self.defaultBlock:SetAlpha(self.defaultAlpha or 1)
        self.defaultBlock, self.defaultAlpha = nil, nil
    end
end

function KeystoneHUD:RefreshObjectiveTracker(hide)
    local tracker = ObjectiveTrackerFrame
    if not tracker then return end
    self.hideObjectives = hide and true or false
    if not self.objectiveHooked then
        self.objectiveHooked = true
        tracker:HookScript("OnShow", function(frame)
            if KeystoneHUD.hideObjectives then
                KeystoneHUD.objectiveWasShown = true
                KeystoneHUD:RefreshObjectiveTracker(true)
            end
        end)
    end
    local protected = tracker.IsProtected and tracker:IsProtected() and InCombatLockdown()
    if hide then
        if self.objectiveAlpha == nil then
            self.objectiveAlpha = tracker:GetAlpha()
            self.objectiveWasShown = tracker:IsShown()
        end
        if protected then tracker:SetAlpha(0) else tracker:Hide() end
    elseif self.objectiveAlpha ~= nil then
        if protected then return end
        local wasShown = self.objectiveWasShown
        tracker:SetAlpha(self.objectiveAlpha)
        self.objectiveAlpha, self.objectiveWasShown = nil, nil
        if wasShown then tracker:Show() end
    end
end

function KeystoneHUD:ApplySettings()
    if not BKA.db then return end
    local settings = BKA.db.keystoneHUD
    local f = self:CreateFrame()
    local alpha = tonumber(settings.backgroundAlpha) or 0.75
    alpha = math.max(0, math.min(1, alpha)); settings.backgroundAlpha = alpha
    f:SetBackdropColor(0.025, 0.035, 0.055, alpha)
    f:SetBackdropBorderColor(0.22, 0.35, 0.43, math.max(0.30, alpha))
    f.accent:SetAlpha(math.max(0.35, alpha))
    f.forcesBar.background:SetAlpha(math.max(0.20, alpha))
    for _, tile in ipairs(f.timers) do tile.bar.background:SetAlpha(math.max(0.20, alpha)) end
    BKA.HUD:Apply(f, settings, -350, 0)
end

function KeystoneHUD:Refresh(force)
    if not BKA.db then return end
    local settings = BKA.db.keystoneHUD
    local enabled = BKA.db.enabled ~= false and settings.shown ~= false
    if not enabled then
        if self.frame then self.frame:Hide() end
        self:SetBlizzardTimerHidden(false)
        self:RefreshObjectiveTracker(false)
        return
    end

    local now = GetTime()
    if not force and now < (self.nextUpdate or 0) then return end
    self.nextUpdate = now + 0.20

    local run = not self.finished and readRun() or nil
    local preview = not run and settings.locked == false
    if not run and not preview then
        if self.frame then self.frame:Hide() end
        self:SetBlizzardTimerHidden(false)
        self:RefreshObjectiveTracker(false)
        return
    end

    local f = self:CreateFrame()
    self:ApplySettings()
    run = run or { name = "Таймер ключа", level = 0, limit = 1800, affixes = {}, bosses = {"Разблокировано - перетащи полоску сверху"}, bossCount = 0, bossDone = 0 }
    f.eyebrow:SetText(preview and "MYTHIC+  /  НАСТРОЙКА ПОЗИЦИИ" or "MYTHIC+  /  КЛЮЧ +" .. run.level)
    f.title:SetText(run.name)
    f.affixes:SetText(#run.affixes > 0 and table.concat(run.affixes, "   ") or "Аффиксы появятся после запуска ключа")

    local timerY = -math.max(70, 45 + f.affixes:GetStringHeight() + 10)
    for i, tile in ipairs(f.timers) do
        local threshold = run.limit * ({0.6, 0.8, 1})[i]
        local remaining = threshold - (run.elapsed or 0)
        local c = remaining >= 0 and colors[i] or {0.48, 0.51, 0.57}
        local x = 12 + (i - 1) * 90
        tile.label:ClearAllPoints(); tile.label:SetPoint("TOPLEFT", x, timerY)
        tile.time:ClearAllPoints(); tile.time:SetPoint("TOPLEFT", x, timerY - 14)
        tile.bar:ClearAllPoints(); tile.bar:SetPoint("TOPLEFT", x, timerY - 38)
        tile.time:SetText(run.elapsed and clock(remaining) or "-:-")
        tile.time:SetTextColor(unpack(c))
        tile.bar:SetStatusBarColor(unpack(c))
        tile.bar:SetValue(run.elapsed and math.max(0, remaining / threshold * 100) or 0)
    end

    local y = timerY - 50
    f.forces:ClearAllPoints(); f.forces:SetPoint("TOPLEFT", 12, y)
    f.forces:SetText(run.forces and string.format("Силы %.1f%%  |  осталось %.1f%%", run.forces, math.max(0, 100 - run.forces)) or "СИЛЫ ПРОТИВНИКА   -")
    f.forcesBar:ClearAllPoints(); f.forcesBar:SetPoint("TOPLEFT", 12, y - 17)
    f.forcesBar:SetValue(math.max(0, math.min(100, run.forces or 0)))
    f.bossTitle:ClearAllPoints(); f.bossTitle:SetPoint("TOPLEFT", 12, y - 29)
    f.bossTitle:SetText(string.format("БОССЫ   %d / %d   |   ОСТАЛОСЬ %d", run.bossDone, run.bossCount, run.bossCount - run.bossDone))
    f.bosses:ClearAllPoints(); f.bosses:SetPoint("TOPLEFT", 12, y - 44)
    f.bosses:SetText(#run.bosses > 0 and table.concat(run.bosses, "\n") or (run.bossCount > 0 and "Все боссы повержены" or "Ожидание целей подземелья..."))
    local footerY = y - 44 - f.bosses:GetStringHeight() - 10
    f.footer:ClearAllPoints(); f.footer:SetPoint("TOPLEFT", 12, footerY)
    f.footer:SetText("Прошло " .. (run.elapsed and clock(run.elapsed) or "-:-") .. "   |   Смертей " .. (run.deaths or 0) .. "   |   Штраф " .. clock(run.penalty or 0))
    f:SetHeight(-footerY + 22)
    f:Show()

    local hideDefault = not preview and run.elapsed ~= nil and settings.hideBlizzard ~= false
    self:SetBlizzardTimerHidden(hideDefault)
    self:RefreshObjectiveTracker(hideDefault)
end

function KeystoneHUD:ResetPosition()
    local s = BKA.db.keystoneHUD
    s.point, s.relativePoint, s.x, s.y = "CENTER", "CENTER", -350, 0
    s.scale, s.backgroundAlpha = 1, 0.75
    self:ApplySettings()
    self:Refresh(true)
end

function KeystoneHUD:Initialize()
    if self.initialized then return end
    self.initialized = true
    local driver = CreateFrame("Frame")
    local accumulator = 0
    driver:SetScript("OnUpdate", function(_, elapsed)
        accumulator = accumulator + elapsed
        if accumulator < 0.20 then return end
        accumulator = 0
        KeystoneHUD:Refresh(false)
    end)
    driver:RegisterEvent("CHALLENGE_MODE_START")
    driver:RegisterEvent("CHALLENGE_MODE_COMPLETED")
    driver:RegisterEvent("CHALLENGE_MODE_RESET")
    driver:RegisterEvent("PLAYER_ENTERING_WORLD")
    driver:SetScript("OnEvent", function(_, event)
        KeystoneHUD.finished = event == "CHALLENGE_MODE_COMPLETED"
        KeystoneHUD:Refresh(true)
    end)
    self.driver = driver
    self:Refresh(true)
end
