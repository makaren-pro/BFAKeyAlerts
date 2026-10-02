local BKA = BFAKeyAlerts
local MobState = { entries = {}, fixates = {}, lastRosterSync = 0, lastUpdate = 0 }
BKA.MobState = MobState

local AURA_SCAN_INTERVAL = 2
local AURA_EVENT_DELAY = 0.1
local STATE_INTERVAL = 0.5
local MAX_AURAS = 3
local GROUP_KEY = "mobState"
local FALLBACK_FIXATE_ICON = 134400
local FALLBACK_ABSORB_ICON = 136051
local FALLBACK_POWER_ICON = 136045

local function finiteNumber(value)
    local number = tonumber(value)
    if not number or number ~= number or number == math.huge or number == -math.huge then return nil end
    return number
end

local function enabled()
    return BKA.active == true and BKA.db and BKA.db.enabled ~= false and BKA.db.showNameplates ~= false and
        BKA.db.mobState and BKA.db.mobState.enabled == true
end

local function option(name)
    local config = BKA.db and BKA.db.mobState
    return not config or config[name] ~= false
end

local function policies()
    return BKA.MobStatePolicies or {}
end

local function unitForGUID(guid)
    local targets = BKA.PartyFrameTargets
    return targets and targets.GetUnitForGUID and targets:GetUnitForGUID(guid)
end

local function validEnemyUnit(unit, guid)
    if not unit or not guid or type(UnitExists) ~= "function" or type(UnitGUID) ~= "function" or
        type(UnitCanAttack) ~= "function" or not UnitExists(unit) then return false end
    local okGUID, currentGUID = pcall(UnitGUID, unit)
    if not okGUID or currentGUID ~= guid or type(UnitIsDeadOrGhost) ~= "function" then return false end
    local okDead, dead = pcall(UnitIsDeadOrGhost, unit)
    if not okDead or dead then return false end
    local okAttack, attackable = pcall(UnitCanAttack, "player", unit)
    return okAttack and attackable == true
end

local function label(key)
    return BKA.L and BKA:L(key) or key
end

local function shortValue(value)
    if value >= 1000000 then return string.format("%.1fm", value / 1000000) end
    if value >= 10000 then return string.format("%.0fk", value / 1000) end
    return tostring(math.floor(value + 0.5))
end

local function shortName(unit)
    if not UnitName then return "?" end
    local ok, name = pcall(UnitName, unit)
    if not ok or not name then return "?" end
    return BKA.ShortUnitName and BKA:ShortUnitName(name) or (string.match(name, "^([^-]+)") or name)
end

local function classColor(unit)
    if type(UnitClass) ~= "function" then return nil end
    local ok, _, classToken = pcall(UnitClass, unit)
    local colors = _G.RAID_CLASS_COLORS or _G.CUSTOM_CLASS_COLORS
    local color = ok and classToken and colors and colors[classToken]
    if not color then return nil end
    local r, g, b = finiteNumber(color.r), finiteNumber(color.g), finiteNumber(color.b)
    if not r or not g or not b then return nil end
    return { math.max(0, math.min(1, r)), math.max(0, math.min(1, g)), math.max(0, math.min(1, b)) }
end

local function hideEntry(entry)
    local intelligence = BKA.CombatIntelligence
    if entry.host and intelligence and intelligence.HideRows then
        intelligence:HideRows(entry.host, GROUP_KEY)
    end
    if entry.host and entry.host.stateFrame and entry.host.stateFrame.ownerGUID == entry.guid then
        entry.host.stateFrame:Hide()
        entry.host.stateFrame.ownerGUID = nil
    end
    entry.host, entry.rows = nil, nil
end

local function auraState(spellID, icon, dispelType, isStealable)
    local policy = policies().auras and policies().auras[spellID]
    local tags = {}
    if policy and option("immunity") then
        if option("immunity") and policy.immunity then tags[#tags + 1] = label("CI_IMMUNE_BADGE") end
        if option("immunity") and policy.interruptImmune then tags[#tags + 1] = label("CI_INTERRUPT_IMMUNE_BADGE") end
        if policy.damageReduction then tags[#tags + 1] = label("CI_DR_BADGE") .. " " .. tostring(policy.damageReduction) .. "%" end
        if policy.shield then tags[#tags + 1] = label("CI_SHIELD_BADGE") end
    end
    if option("purge") then
        if isStealable == true or isStealable == 1 then
            tags[#tags + 1] = label("CI_STEAL_BADGE")
        elseif policy and policies().magicPurge and policies().magicPurge[spellID] and dispelType == "Magic" then
            tags[#tags + 1] = label("CI_PURGE_BADGE")
        end
    end
    if #tags == 0 then return nil end
    local rank = policy and policy.immunity and option("immunity") and 5 or
        (policy and policy.damageReduction and option("immunity") and 4 or
        (policy and policy.interruptImmune and option("immunity") and 3 or
        (policy and policy.shield and option("immunity") and 2 or 1)))
    return { spellID = spellID, icon = icon, text = table.concat(tags, " "), rank = rank }
end

local function scanAuras(unit)
    local result, seen = {}, {}
    if type(UnitAura) ~= "function" then return result end
    for index = 1, 40 do
        local ok, name, icon, _, dispelType, _, _, source, isStealable, _, spellID =
            pcall(UnitAura, unit, index, "HELPFUL")
        if not ok or not name then break end
        spellID = tonumber(spellID)
        if spellID and not seen[spellID] then
            local state = auraState(spellID, icon, dispelType, isStealable)
            if state then
                seen[spellID] = true
                state.sourceUnit = source
                result[#result + 1] = state
            end
        end
    end
    table.sort(result, function(a, b)
        if a.rank ~= b.rank then return a.rank > b.rank end
        return a.spellID < b.spellID
    end)
    while #result > MAX_AURAS do table.remove(result) end
    return result
end

local function findAura(unit, spellID, filter)
    if type(UnitAura) ~= "function" then return nil end
    for index = 1, 40 do
        local ok, name, _, _, _, _, expiration, source, _, _, foundSpellID =
            pcall(UnitAura, unit, index, filter)
        if not ok or not name then return false end
        if tonumber(foundSpellID) == spellID then
            local sourceGUID
            if source and UnitGUID then
                local sourceOK, value = pcall(UnitGUID, source)
                if sourceOK then sourceGUID = value end
            end
            return true, finiteNumber(expiration), sourceGUID
        end
    end
    return false
end

local function readAbsorbs(unit)
    if type(UnitGetTotalAbsorbs) ~= "function" then return nil end
    local ok, value = pcall(UnitGetTotalAbsorbs, unit)
    value = ok and finiteNumber(value) or nil
    if value and value >= 0 then return value end
end

local function readPower(unit, npcID)
    local policy = policies().power and policies().power[npcID]
    if not policy or type(UnitPower) ~= "function" or type(UnitPowerMax) ~= "function" then return nil end
    local okCurrent, current
    local okMax, maximum
    if policy.powerType == nil then
        okCurrent, current = pcall(UnitPower, unit)
        okMax, maximum = pcall(UnitPowerMax, unit)
    else
        okCurrent, current = pcall(UnitPower, unit, policy.powerType)
        okMax, maximum = pcall(UnitPowerMax, unit, policy.powerType)
    end
    current, maximum = okCurrent and finiteNumber(current) or nil, okMax and finiteNumber(maximum) or nil
    if current and maximum and current >= 0 and maximum > 0 then
        return { current = current, maximum = maximum, label = label(policy.label or "CI_POWER_BADGE") }
    end
end

local function getNativeHealthBar(unit)
    if not BKA.Nameplates or not BKA.Nameplates.GetOverlay then return nil end
    local callOK, overlay = pcall(BKA.Nameplates.GetOverlay, BKA.Nameplates, unit)
    if not callOK or not overlay then return nil end
    local parentMethodOK, getParent = pcall(function() return overlay and overlay.GetParent end)
    if not parentMethodOK or type(getParent) ~= "function" then return nil end
    local parentOK, plate = pcall(getParent, overlay)
    if not parentOK or not plate then return nil end
    local unitFrame
    if plate then
        local ok, value = pcall(function() return plate.UnitFrame end)
        if ok then unitFrame = value end
    end
    if not unitFrame then return nil end
    local ok, healthBar = pcall(function() return unitFrame.healthBar or unitFrame.HealthBar end)
    if not ok or not healthBar then return nil end
    local widthMethodOK, getWidth = pcall(function() return healthBar.GetWidth end)
    local parentMethodOK2, getBarParent = pcall(function() return healthBar.GetParent end)
    if not widthMethodOK or type(getWidth) ~= "function" or not parentMethodOK2 or type(getBarParent) ~= "function" then return nil end
    local parentOK, parent = pcall(getBarParent, healthBar)
    if not parentOK or parent ~= unitFrame then return nil end
    local forbiddenOK, isForbidden = pcall(function() return healthBar.IsForbidden end)
    if forbiddenOK and type(isForbidden) == "function" then
        local ok, forbidden = pcall(isForbidden, healthBar)
        if not ok or forbidden then return nil end
    end
    local shownOK, isShown = pcall(function() return healthBar.IsShown end)
    if not shownOK or type(isShown) ~= "function" then return nil end
    local okShown, shown = pcall(isShown, healthBar)
    if not okShown or not shown then return nil end
    local widthOK, width = pcall(getWidth, healthBar)
    width = widthOK and finiteNumber(width) or nil
    if not width or width <= 0 then return nil end
    return healthBar, width
end

local function stateFrameFor(host, guid, unit)
    if not host or host.ownerGUID ~= guid then return nil end
    local frame = host.stateFrame
    if not frame then
        frame = CreateFrame("Frame", nil, host)
        frame:EnableMouse(false)
        frame.ownerGUID = guid
        host.stateFrame = frame
    elseif frame.ownerGUID ~= guid then
        frame:Hide()
        frame.ownerGUID = guid
    end
    frame:ClearAllPoints()
    frame:SetPoint("BOTTOMLEFT", host, "BOTTOMLEFT", 0, 0)
    frame:SetSize(270, 1)
    frame:Show()
    return frame
end

local function thresholdWidgets(entry, host, stateFrame)
    local thresholds = policies().healthThresholds and policies().healthThresholds[entry.npcID]
    if not thresholds then
        for _, tick in ipairs(stateFrame.thresholdTicks or {}) do tick:Hide() end
        return false
    end
    if not option("thresholds") then
        for _, tick in ipairs(stateFrame.thresholdTicks or {}) do tick:Hide() end
        return false
    end
    local healthBar, width = getNativeHealthBar(entry.unit)
    if not healthBar or not width then
        for _, tick in ipairs(stateFrame.thresholdTicks or {}) do tick:Hide() end
        return false
    end
    stateFrame.thresholdTicks = stateFrame.thresholdTicks or {}
    for index, threshold in ipairs(thresholds) do
        local tick = stateFrame.thresholdTicks[index]
        if not tick then
            tick = CreateFrame("Frame", nil, stateFrame)
            tick:EnableMouse(false)
            tick:SetSize(2, 9)
            tick.texture = tick:CreateTexture(nil, "OVERLAY")
            tick.texture:SetAllPoints(tick)
            tick.texture:SetColorTexture(1, 0.82, 0.24, 0.95)
            stateFrame.thresholdTicks[index] = tick
        end
        local reverse = false
        if type(healthBar.GetReverseFill) == "function" then
            local reverseOK, value = pcall(healthBar.GetReverseFill, healthBar)
            reverse = reverseOK and value == true
        end
        local fraction = threshold / 100
        if reverse then fraction = 1 - fraction end
        fraction = math.max(0, math.min(1, fraction))
        tick:ClearAllPoints()
        tick:SetPoint("CENTER", healthBar, "LEFT", width * fraction, 0)
        if type(healthBar.GetFrameLevel) == "function" and type(tick.SetFrameLevel) == "function" then
            local levelOK, level = pcall(healthBar.GetFrameLevel, healthBar)
            level = levelOK and finiteNumber(level) or nil
            if level then pcall(tick.SetFrameLevel, tick, level + 5) end
        end
        tick:Show()
    end
    for index = #thresholds + 1, #stateFrame.thresholdTicks do stateFrame.thresholdTicks[index]:Hide() end
    return true
end

local function render(entry)
    local intelligence = BKA.CombatIntelligence
    if not intelligence or not intelligence.GetHost or not intelligence.GetRows then hideEntry(entry); return end
    local host = intelligence:GetHost(entry.unit)
    if not host or host.ownerGUID ~= entry.guid then hideEntry(entry); return end
    if entry.host and entry.host ~= host then hideEntry(entry) end
    entry.host = host
    local stateFrame = stateFrameFor(host, entry.guid, entry.unit)
    if not stateFrame then hideEntry(entry); return end
    local hasThresholds = thresholdWidgets(entry, host, stateFrame)

    local auraCount = math.min(MAX_AURAS, #entry.auras)
    local status = {}
    if option("absorb") and entry.absorbs and entry.absorbs > 0 then
        status[#status + 1] = { key = "absorb", text = label("CI_SHIELD_BADGE") .. " " .. shortValue(entry.absorbs), icon = FALLBACK_ABSORB_ICON }
    end
    if option("power") and entry.power then
        status[#status + 1] = { key = "power", text = shortValue(entry.power.current) .. "/" .. shortValue(entry.power.maximum), icon = FALLBACK_POWER_ICON }
    end
    local fixate = entry.fixate
    local fixateUnit = fixate and unitForGUID(fixate.targetGUID)
    if option("fixate") and fixate and fixateUnit then
        local color = fixate.targetColor
        local targetName = fixate.targetName
        if color then targetName = string.format("|cff%02x%02x%02x%s|r", math.floor(color[1] * 255), math.floor(color[2] * 255), math.floor(color[3] * 255), targetName) end
        status[#status + 1] = { key = "fixate", text = label("CI_FIXATE_BADGE") .. " " .. targetName, icon = fixate.icon or FALLBACK_FIXATE_ICON }
    end
    local rowCount = math.min(6, auraCount + #status)
    if rowCount == 0 and not hasThresholds then
        intelligence:HideRows(host, GROUP_KEY)
        stateFrame:Hide()
        if stateFrame.powerBar then stateFrame.powerBar:Hide() end
        return
    end
    if rowCount == 0 then
        intelligence:HideRows(host, GROUP_KEY)
        if stateFrame.powerBar then stateFrame.powerBar:Hide() end
        stateFrame:SetSize(1, 1)
        stateFrame:Show()
        return
    end
    local rows = intelligence:GetRows(host, GROUP_KEY, rowCount, 16)
    local lineCount = (auraCount > 0 and 1 or 0) + (#status > 0 and 1 or 0)
    stateFrame:SetSize(math.max(auraCount, #status) * 90, lineCount * 20 + (entry.power and option("power") and 4 or 0))
    for index = 1, rowCount do
        local row, aura = rows[index], entry.auras[index]
        local texture, text, stateKey
        if index <= auraCount then
            aura = entry.auras[index]
            texture, text, stateKey = aura.icon, aura.text, "aura:" .. aura.spellID
        else
            local state = status[index - auraCount]
            texture, text, stateKey = state.icon, state.text, state.key
        end
        row:ClearAllPoints()
        row:SetParent(stateFrame)
        local column = index <= auraCount and index - 1 or index - auraCount - 1
        local line = index <= auraCount and 0 or (auraCount > 0 and 1 or 0)
        row:SetSize(90, 16)
        row:SetPoint("TOPLEFT", stateFrame, "TOPLEFT", column * 90, -line * 20)
        if row.text.SetWidth then row.text:SetWidth(68) end
        if row.text.SetWordWrap then row.text:SetWordWrap(false) end
        row.icon:SetTexture(texture)
        row.text:SetText(text)
        if stateKey == "power" and entry.power then
            local bar = stateFrame.powerBar
            if not bar then
                bar = CreateFrame("StatusBar", nil, stateFrame)
                bar:EnableMouse(false)
                bar:SetSize(64, 4)
                if bar.SetStatusBarTexture then bar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar") end
                stateFrame.powerBar = bar
            end
            bar:SetMinMaxValues(0, entry.power.maximum)
            bar:SetValue(entry.power.current)
            bar:ClearAllPoints()
            bar:SetPoint("TOPLEFT", row, "BOTTOMLEFT", 19, -1)
            if bar.SetStatusBarColor then bar:SetStatusBarColor(0.25, 0.7, 1, 0.9) end
            bar:Show()
        end
        if row.EnableMouse then row:EnableMouse(false) end
        row:Show()
        row.mobStateKey = stateKey
    end
    for index = rowCount + 1, #(host.groups[GROUP_KEY] or {}) do host.groups[GROUP_KEY][index]:Hide() end
    if not entry.power or not option("power") then
        if stateFrame.powerBar then stateFrame.powerBar:Hide() end
    end
end

local function scanFixateTarget(fixate, now)
    if not fixate or now < (fixate.nextCheck or 0) then return end
    fixate.nextCheck = now + AURA_SCAN_INTERVAL
    local unit = unitForGUID(fixate.targetGUID)
    if not unit then return false end
    local present, expiration, sourceGUID = findAura(unit, policies().fixateSpellID, "HARMFUL")
    if present == false then return false end
    if present == true then
        if sourceGUID and sourceGUID ~= fixate.sourceGUID then return false end
        if expiration and expiration > now then fixate.expiresAt = math.min(fixate.hardExpiresAt, expiration) end
    end
    return true
end

function MobState:_scanAuras(entry, now)
    entry.auras = scanAuras(entry.unit)
    entry.auraDirty = false
    entry.nextAuraScan = now + AURA_SCAN_INTERVAL
end

local function readEntry(entry, now)
    if entry.auraDirty or now >= (entry.nextAuraScan or 0) then MobState:_scanAuras(entry, now) end
    entry.absorbs = option("absorb") and readAbsorbs(entry.unit) or nil
    entry.power = option("power") and readPower(entry.unit, entry.npcID) or nil
    local fixate = MobState.fixates[entry.guid]
    entry.fixate = nil
    if option("fixate") and fixate then
        if now >= fixate.expiresAt or scanFixateTarget(fixate, now) == false then
            MobState.fixates[entry.guid] = nil
        else
            entry.fixate = fixate
        end
    else
        entry.fixate = nil
    end
    entry.stateAt = now
end

function MobState:Refresh()
    if not enabled() then self:Clear(); return end
    local visible, desired = BKA.Targets and BKA.Targets.guidToUnit or {}, {}
    for guid, unit in pairs(visible) do
        if validEnemyUnit(unit, guid) then
            local npcID = BKA.GetNPCID and BKA:GetNPCID(guid)
            if npcID then
                desired[guid] = unit
                local entry = self.entries[guid]
                if not entry then
                    entry = { guid = guid, unit = unit, npcID = npcID, auras = {}, auraDirty = true, nextAuraScan = 0 }
                    self.entries[guid] = entry
                else
                    entry.unit = unit
                end
            end
        end
    end
    for guid, entry in pairs(self.entries) do
        if not desired[guid] or not validEnemyUnit(entry.unit, guid) then self:RemoveUnit(guid) end
    end
    self.lastRosterSync = GetTime and GetTime() or self.lastRosterSync
end

function MobState:RemoveUnit(unit)
    local removedStaleToken = false
    if unit and not (type(unit) == "string" and string.find(unit, "^Creature%-")) then
        local currentGUID
        if UnitGUID then local ok, value = pcall(UnitGUID, unit); if ok then currentGUID = value end end
        for entryGUID, entry in pairs(self.entries) do
            if entry.unit == unit and entryGUID ~= currentGUID then
                hideEntry(entry)
                self.entries[entryGUID] = nil
                self.fixates[entryGUID] = nil
                removedStaleToken = true
                for sourceGUID, fixate in pairs(self.fixates) do
                    if fixate.targetGUID == entryGUID then self.fixates[sourceGUID] = nil end
                end
            end
        end
    end
    if removedStaleToken then return end
    local isGUID = type(unit) == "string" and (string.match(unit, "^Creature%-") or string.match(unit, "^Vehicle%-") or
        string.match(unit, "^Pet%-") or string.match(unit, "^GameObject%-"))
    local guid
    if isGUID then guid = unit elseif unit and UnitGUID then
        local ok, value = pcall(UnitGUID, unit)
        if ok then guid = value end
    end
    if guid then
        local entry = self.entries[guid]
        if entry then hideEntry(entry); self.entries[guid] = nil end
        self.fixates[guid] = nil
        for sourceGUID, fixate in pairs(self.fixates) do
            if fixate.targetGUID == guid then self.fixates[sourceGUID] = nil end
        end
    elseif unit then
        for entryGUID, entry in pairs(self.entries) do
            if entry.unit == unit then hideEntry(entry); self.entries[entryGUID] = nil end
        end
    end
end

function MobState:Clear()
    for guid, entry in pairs(self.entries) do hideEntry(entry); self.entries[guid] = nil end
    for guid in pairs(self.fixates) do self.fixates[guid] = nil end
end

function MobState:SettingsChanged()
    if not enabled() then self:Clear(); return end
    for guid, entry in pairs(self.entries) do hideEntry(entry); self.entries[guid] = nil end
    if not option("fixate") then for guid in pairs(self.fixates) do self.fixates[guid] = nil end end
    self.lastRosterSync = 0
    self:Refresh()
end

function MobState:OnEvent(event, unit)
    if event == "UNIT_AURA" then
        local guid = unit and UnitGUID and UnitGUID(unit)
        local entry = guid and self.entries[guid]
        if entry and entry.unit == unit then
            if not entry.auraDirty then entry.auraDue = ((GetTime and GetTime()) or 0) + AURA_EVENT_DELAY end
            entry.auraDirty = true
        end
        if guid then
            for sourceGUID, fixate in pairs(self.fixates) do
                if fixate.targetGUID == guid then
                    fixate.nextCheck = 0
                    local sourceEntry = self.entries[sourceGUID]
                    if sourceEntry then sourceEntry.stateDirty = true end
                end
            end
        end
    elseif event == "UNIT_HEALTH" or event == "UNIT_HEALTH_FREQUENT" or event == "UNIT_POWER_UPDATE" or
        event == "UNIT_POWER_FREQUENT" or event == "UNIT_ABSORB_AMOUNT_CHANGED" then
        local guid = unit and UnitGUID and UnitGUID(unit)
        local entry = guid and self.entries[guid]
        if entry and entry.unit == unit then entry.stateDirty = true end
    elseif event == "GROUP_ROSTER_UPDATE" or event == "ADDON_LOADED" or event == "PLAYER_REGEN_ENABLED" then
        self:Refresh()
    end
end

function MobState:OnCombatLog(event, sourceGUID, destGUID, spellID)
    local policy = policies()
    if event == "UNIT_DIED" then
        if destGUID then self:RemoveUnit(destGUID) end
        return
    end
    if tonumber(spellID) ~= policy.fixateSpellID then
        if destGUID and (event == "SPELL_AURA_APPLIED" or event == "SPELL_AURA_REMOVED" or event == "SPELL_AURA_REFRESH") then
            local entry = self.entries[destGUID]
            if entry then entry.auraDirty = true end
        end
        return
    end
    if not option("fixate") then return end
    if event == "SPELL_AURA_APPLIED" or event == "SPELL_AURA_REFRESH" then
        if not sourceGUID or not destGUID or sourceGUID == destGUID or not unitForGUID(destGUID) then return end
        local entry = self.entries[sourceGUID]
        if not entry or not validEnemyUnit(entry.unit, sourceGUID) then return end
        local now = GetTime and GetTime() or 0
        local hardExpiry = now + (tonumber(policy.fixateMaxAge) or 30)
        self.fixates[sourceGUID] = {
            sourceGUID = sourceGUID, targetGUID = destGUID, targetName = shortName(unitForGUID(destGUID)),
            targetColor = classColor(unitForGUID(destGUID)),
            icon = GetSpellTexture and GetSpellTexture(policy.fixateSpellID) or nil,
            appliedAt = now, expiresAt = hardExpiry, hardExpiresAt = hardExpiry, nextCheck = now + 1,
        }
        entry.stateDirty = true
    elseif event == "SPELL_AURA_REMOVED" or event == "SPELL_AURA_REMOVED_DOSE" then
        local fixate = sourceGUID and self.fixates[sourceGUID]
        if fixate and (not destGUID or fixate.targetGUID == destGUID) then
            self.fixates[sourceGUID] = nil
            local entry = self.entries[sourceGUID]
            if entry then entry.stateDirty = true end
        end
    end
end

function MobState:Update(now)
    now = tonumber(now) or (GetTime and GetTime()) or 0
    if not enabled() then
        if next(self.entries) or next(self.fixates) then self:Clear() end
        return
    end
    local didFastAura = false
    for guid, entry in pairs(self.entries) do
        if entry.auraDirty and now >= (entry.auraDue or 0) and validEnemyUnit(entry.unit, guid) then
            self:_scanAuras(entry, now)
            entry.stateDirty = true
            didFastAura = true
        end
    end
    if now - (self.lastUpdate or 0) < STATE_INTERVAL then
        if didFastAura then
            for _, entry in pairs(self.entries) do
                if entry.stateDirty then render(entry); entry.stateDirty = false end
            end
        end
        return
    end
    self.lastUpdate = now
    if now - (self.lastRosterSync or 0) >= STATE_INTERVAL then self:Refresh() end
    for guid, entry in pairs(self.entries) do
        if not validEnemyUnit(entry.unit, guid) then
            self:RemoveUnit(guid)
        else
            if entry.stateDirty or now - (entry.stateAt or 0) >= STATE_INTERVAL then
                readEntry(entry, now)
                render(entry)
                entry.stateDirty = false
            end
        end
    end
end
