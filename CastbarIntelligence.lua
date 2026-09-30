local BKA = BFAKeyAlerts
local Intelligence = { entries = {}, generation = 0 }
BKA.CastbarIntelligence = Intelligence

local GROUP_KEY = "castbarIntelligence"
local FALLBACK_WIDTH = 92
local FALLBACK_HEIGHT = 18

local function finite(value)
    value = tonumber(value)
    if not value or value ~= value or value == math.huge or value == -math.huge then return nil end
    return value
end

local function config()
    return BKA.db and BKA.db.castbarIntelligence or {}
end

local function enabled()
    return config().enabled == true and BKA.active == true and BKA.db and BKA.db.enabled ~= false and
        BKA.db.showNameplates ~= false
end

local function unitGUID(unit)
    if type(UnitGUID) ~= "function" then return nil end
    local ok, guid = pcall(UnitGUID, unit)
    return ok and guid or nil
end

local function validNameplate(unit, guid)
    if type(unit) ~= "string" or not string.match(unit, "^nameplate%d+$") or not guid or
        type(UnitExists) ~= "function" or type(UnitIsDeadOrGhost) ~= "function" or
        type(UnitCanAttack) ~= "function" then return false end
    local existsOK, exists = pcall(UnitExists, unit)
    if not existsOK or not exists then return false end
    if unitGUID(unit) ~= guid then return false end
    local deadOK, dead = pcall(UnitIsDeadOrGhost, unit)
    local attackOK, attackable = pcall(UnitCanAttack, "player", unit)
    return deadOK and not dead and attackOK and attackable == true
end

local function value(frame, key)
    local ok, result = pcall(function() return frame and frame[key] end)
    return ok and result or nil
end

local function invoke(frame, method, ...)
    local fn = value(frame, method)
    if type(fn) ~= "function" then return false end
    return pcall(fn, frame, ...)
end

local function nativeCastBar(unit, guid)
    local plates = BKA.Nameplates
    if not plates or type(plates.GetOverlay) ~= "function" then return nil end
    local overlayOK, overlay = pcall(plates.GetOverlay, plates, unit)
    if not overlayOK or not overlay or unitGUID(unit) ~= guid then return nil end
    local parentOK, plate = invoke(overlay, "GetParent")
    if not parentOK or not plate then return nil end
    local unitFrame = value(plate, "UnitFrame")
    local bar = value(unitFrame, "castBar") or value(unitFrame, "castbar")
    if not bar then return nil end
    local barParentOK, barParent = invoke(bar, "GetParent")
    if not barParentOK or barParent ~= unitFrame then return nil end
    local isForbidden = value(bar, "IsForbidden")
    if type(isForbidden) == "function" then
        local forbiddenOK, forbidden = invoke(bar, "IsForbidden")
        if not forbiddenOK or forbidden then return nil end
    end
    local shownOK, shown = invoke(bar, "IsShown")
    if not shownOK or not shown then return nil end
    local widthOK, width = invoke(bar, "GetWidth")
    local heightOK, height = invoke(bar, "GetHeight")
    width, height = widthOK and finite(width) or nil, heightOK and finite(height) or nil
    if not width or not height or width <= 0 or height <= 0 then return nil end
    local reverse = false
    local reverseOK, value = invoke(bar, "GetReverseFill")
    if reverseOK then reverse = value == true end
    local frameLevelOK, frameLevel = invoke(bar, "GetFrameLevel")
    frameLevel = frameLevelOK and finite(frameLevel) or nil
    return bar, width, height, reverse, frameLevel
end

local function castFrameFor(host, guid)
    if not host or host.ownerGUID ~= guid then return nil end
    local frame = host.castFrame
    if not frame then
        frame = CreateFrame("Frame", nil, host)
        frame:EnableMouse(false)
        frame:SetSize(FALLBACK_WIDTH, FALLBACK_HEIGHT)
        frame.icon = frame:CreateTexture(nil, "ARTWORK")
        frame.icon:SetSize(12, 12)
        frame.icon:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
        frame.badges = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        frame.badges:SetPoint("TOPLEFT", frame.icon, "TOPRIGHT", 3, 0)
        frame.badges:SetPoint("RIGHT", frame, "RIGHT", 0, 0)
        frame.badges:SetJustifyH("LEFT")
        frame.bar = CreateFrame("StatusBar", nil, frame)
        frame.bar:EnableMouse(false)
        frame.bar:SetHeight(3)
        frame.bar:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 0, 1)
        frame.bar:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 1)
        if frame.bar.SetStatusBarTexture then frame.bar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar") end
        frame.tick = CreateFrame("Frame", nil, frame)
        frame.tick:EnableMouse(false)
        frame.tick:SetSize(2, 10)
        frame.tick.texture = frame.tick:CreateTexture(nil, "OVERLAY")
        frame.tick.texture:SetAllPoints(frame.tick)
        frame.tick.texture:SetColorTexture(0.32, 1, 0.82, 0.95)
        local hostLevelOK, hostLevel = invoke(host, "GetFrameLevel")
        frame:SetFrameLevel((hostLevelOK and finite(hostLevel) or 1) + 10)
        host.castFrame = frame
    elseif frame.ownerGUID ~= guid then
        frame:Hide()
        frame.ownerGUID = guid
        frame.layoutMode, frame.layoutAnchor = nil, nil
    end
    frame.ownerGUID = guid
    frame:SetSize(FALLBACK_WIDTH, FALLBACK_HEIGHT)
    frame:Show()
    return frame
end

local function appendBadge(out, seen, key)
    if not seen[key] then
        local text = BKA.L and BKA:L(key) or key
        seen[key] = true
        out[#out + 1] = text
    end
end

local function resolvedBadges(cast, cfg)
    local result, seen = {}, {}
    local resolution = cast.resolution
    local ability = resolution and resolution.ability
    if not cfg.properties or not ability or resolution.suppressAlert or ability.castControl == "IGNORE" or
        (resolution.policy and resolution.policy.policy == "IGNORE") then return "" end

    local interruptible = cast.interruptibilityKnown == true and cast.notInterruptible == false
    if ability.castControl == "KICK" and interruptible then appendBadge(result, seen, "CI_INTERRUPT_BADGE") end
    if ability.ccCapable == true or ability.castControl == "STOP" or resolution.controlAction == "STOP" then
        appendBadge(result, seen, "CI_CC_BADGE")
    end
    if ability.reflectable == true then appendBadge(result, seen, "CI_REFLECT_BADGE") end

    local action = resolution.action
    local mechanic = ability.mechanic
    if ability.purgeable == true or action == "PURGE" or ability.action == "PURGE" or mechanic == "PURGE" then
        appendBadge(result, seen, "CI_PURGE_BADGE")
    end
    if ability.stealable == true or ability.spellstealable == true or action == "SPELLSTEAL" or
        ability.action == "SPELLSTEAL" or mechanic == "SPELLSTEAL" then
        appendBadge(result, seen, "CI_STEAL_BADGE")
    end

    local resolvedFrontal = resolution.nameplateAction == "FRONTAL" or resolution.nameplateAction == "CLEAVE" or
        action == "FRONTAL" or action == "CLEAVE" or ability.primaryAction == "FRONTAL" or
        ability.primaryAction == "CLEAVE" or ability.action == "FRONTAL" or ability.action == "CLEAVE" or
        mechanic == "FRONTAL" or mechanic == "CLEAVE"
    local resolvedAOE = resolution.nameplateAction == "AOE" or action == "AOE" or
        ability.primaryAction == "AOE" or ability.action == "AOE" or mechanic == "AOE"
    if resolvedFrontal then
        appendBadge(result, seen, "CI_FRONTAL_BADGE")
    elseif resolvedAOE then
        appendBadge(result, seen, "CI_AOE_BADGE")
    end
    while #result > 3 do table.remove(result) end
    return table.concat(result, " ")
end

local function configureEntry(entry, cast, cfg)
    if entry.cast == cast and entry.resolution == cast.resolution and entry.propertiesEnabled == cfg.properties and
        entry.tickEnabled == cfg.interruptTick and entry.interruptibilityKnown == cast.interruptibilityKnown and
        entry.notInterruptible == cast.notInterruptible then return end
    entry.cast = cast
    entry.resolution = cast.resolution
    entry.propertiesEnabled, entry.tickEnabled = cfg.properties, cfg.interruptTick
    entry.interruptibilityKnown, entry.notInterruptible = cast.interruptibilityKnown, cast.notInterruptible
    entry.badges = resolvedBadges(cast, cfg)
    local resolution = cast.resolution
    entry.suppressed = resolution and (resolution.suppressAlert or
        (resolution.policy and resolution.policy.policy == "IGNORE") or
        (resolution.ability and resolution.ability.castControl == "IGNORE")) or false
    entry.texture = cast.texture
    if not entry.texture and cast.spellID and type(GetSpellTexture) == "function" then
        local ok, texture = pcall(GetSpellTexture, cast.spellID)
        if ok then entry.texture = texture end
    end
    entry.texture = entry.texture or "Interface\\Icons\\INV_Misc_QuestionMark"
end

local function clearFrame(entry)
    if entry.host and entry.host.castFrame and entry.host.castFrame.ownerGUID == entry.guid then
        entry.host.castFrame:Hide()
        entry.host.castFrame.ownerGUID = nil
    end
    entry.host = nil
end

function Intelligence:Clear()
    for guid, entry in pairs(self.entries) do
        clearFrame(entry)
        self.entries[guid] = nil
    end
end

function Intelligence:RemoveUnit(unit)
    if not unit then return end
    local currentGUID = unitGUID(unit)
    local removedStaleToken = false
    for guid, entry in pairs(self.entries) do
        if entry.unit == unit and guid ~= currentGUID then
            clearFrame(entry)
            self.entries[guid] = nil
            removedStaleToken = true
        end
    end
    if removedStaleToken then return end
    local isGUID = type(unit) == "string" and (string.match(unit, "^Creature%-") or string.match(unit, "^Vehicle%-"))
    local guid = isGUID and unit or currentGUID
    if guid then
        local entry = self.entries[guid]
        if entry then clearFrame(entry); self.entries[guid] = nil end
    end
end

local function renderEntry(entry, cast, now, readyAt, cfg)
    local intelligence = BKA.CombatIntelligence
    if not intelligence or type(intelligence.GetHost) ~= "function" then clearFrame(entry); return end
    local host = intelligence:GetHost(entry.unit)
    if not host or host.ownerGUID ~= entry.guid then clearFrame(entry); return end
    if entry.host and entry.host ~= host then clearFrame(entry) end
    entry.host = host
    local frame = castFrameFor(host, entry.guid)
    if not frame then clearFrame(entry); return end
    configureEntry(entry, cast, cfg)
    local native, nativeWidth, nativeHeight, reverse, nativeLevel = nativeCastBar(entry.unit, entry.guid)
    local startTime, endTime = finite(cast.startTime), finite(cast.endTime)
    local duration = startTime and endTime and endTime - startTime or nil
    local usableTime = duration and duration > 0
    local ability = cast.resolution and cast.resolution.ability
    local showTick = cfg.interruptTick and not entry.suppressed and usableTime and readyAt and
        cast.interruptibilityKnown == true and cast.notInterruptible == false and
        readyAt > now and readyAt > startTime and readyAt < endTime
    local showProperties = cfg.properties and entry.badges ~= ""
    if not showTick and not showProperties then
        frame.tick:Hide()
        frame.bar:Hide()
        frame:Hide()
        return
    end
    frame.icon:SetTexture(entry.texture)
    frame.badges:SetText(showProperties and entry.badges or "")
    local mode = native and "native" or "fallback"
    local anchor = native or host:GetParent()
    if frame.layoutMode ~= mode or frame.layoutAnchor ~= anchor then
        frame:ClearAllPoints()
        if native then frame:SetPoint("TOPLEFT", native, "BOTTOMLEFT", 0, -1)
        else
            local plate = host:GetParent()
            if plate then frame:SetPoint("TOP", plate, "BOTTOM", 0, -2)
            else frame:SetPoint("TOPLEFT", host, "BOTTOMLEFT", 0, -2) end
        end
        frame.layoutMode, frame.layoutAnchor = mode, anchor
    end
    if native then
        frame.bar:Hide()
        frame.tick:SetSize(2, math.max(6, math.min(16, nativeHeight)))
        if nativeLevel then
            local frameLevelOK, frameLevel = invoke(frame, "GetFrameLevel")
            frameLevel = frameLevelOK and finite(frameLevel) or 0
            pcall(frame.tick.SetFrameLevel, frame.tick, math.max(nativeLevel + 5, frameLevel + 1))
        end
    elseif usableTime then
        frame.bar:SetMinMaxValues(0, duration)
        frame.bar:SetValue(math.max(0, math.min(duration, now - startTime)))
        frame.bar:Show()
        frame.tick:SetFrameLevel(frame:GetFrameLevel() + 2)
        nativeWidth = FALLBACK_WIDTH
    else
        frame.bar:Hide()
    end

    if showTick then
        local fraction
        if native then
            fraction = cast.isChannel and (endTime - readyAt) / duration or (readyAt - startTime) / duration
            if reverse then fraction = 1 - fraction end
        else
            fraction = (readyAt - startTime) / duration
        end
        fraction = math.max(0, math.min(1, fraction))
        frame.tick:ClearAllPoints()
        frame.tick:SetPoint("CENTER", native or frame.bar, "LEFT", nativeWidth * fraction, 0)
        frame.tick:Show()
    else
        frame.tick:Hide()
    end
    frame:Show()
end

function Intelligence:Update(now, force)
    now = finite(now) or (GetTime and GetTime()) or 0
    if not enabled() then self:Clear(); return end
    if not force and now < (self.nextUpdate or 0) then return end
    self.nextUpdate = now + 0.10
    local active = BKA.ActiveCasts and BKA.ActiveCasts.byUnit or {}
    local readyAt
    if config().interruptTick and BKA.GroupInterrupts and BKA.GroupInterrupts.GetPlayerInterruptReadyAt then
        readyAt = BKA.GroupInterrupts:GetPlayerInterruptReadyAt(now)
    end
    self.generation = self.generation + 1
    local generation = self.generation
    for unit, cast in pairs(active) do
        local guid = cast and cast.sourceGUID
        local startTime = cast and finite(cast.startTime)
        local endTime = cast and finite(cast.endTime)
        if guid and startTime and endTime and endTime > now and endTime > startTime and validNameplate(unit, guid) then
            local entry = self.entries[guid]
            if not entry then
                entry = { guid = guid, unit = unit }
                self.entries[guid] = entry
            end
            local unitNumber = tonumber(string.match(unit, "^nameplate(%d+)$")) or math.huge
            if entry.seenGeneration ~= generation or unitNumber < (entry.unitNumber or math.huge) then
                entry.unit, entry.unitNumber, entry.currentCast = unit, unitNumber, cast
            end
            entry.seenGeneration = generation
        end
    end
    for guid, entry in pairs(self.entries) do
        if entry.seenGeneration ~= generation or not validNameplate(entry.unit, guid) then
            clearFrame(entry)
            self.entries[guid] = nil
        else
            renderEntry(entry, entry.currentCast, now, readyAt, config())
        end
    end
end

function Intelligence:CastsChanged()
    self:Update((GetTime and GetTime()) or 0, true)
end

function Intelligence:SettingsChanged()
    self:Clear()
    self.nextUpdate = 0
    if enabled() then self:Update((GetTime and GetTime()) or 0, true) end
end
