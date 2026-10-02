local BKA = BFAKeyAlerts
local Intelligence = { entries = {}, generation = 0 }
BKA.CastbarIntelligence = Intelligence

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

local function suppressed(cast)
    local resolution = cast and cast.resolution
    local ability = resolution and resolution.ability
    return resolution and (resolution.suppressAlert or
        (resolution.policy and resolution.policy.policy == "IGNORE") or
        (ability and ability.castControl == "IGNORE")) or false
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
    return frame
end

local function clearFrame(entry)
    if entry.host and entry.host.castFrame and entry.host.castFrame.ownerGUID == entry.guid then
        entry.host.castFrame:Hide()
        entry.host.castFrame.tick:Hide()
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
    local native, nativeWidth, nativeHeight, reverse, nativeLevel = nativeCastBar(entry.unit, entry.guid)
    if not native then clearFrame(entry); return end
    local frame = castFrameFor(host, entry.guid)
    if not frame then clearFrame(entry); return end
    local startTime, endTime = finite(cast.startTime), finite(cast.endTime)
    local duration = startTime and endTime and endTime - startTime or nil
    local usableTime = duration and duration > 0
    local showTick = cfg.interruptTick and not suppressed(cast) and usableTime and readyAt and
        cast.interruptibilityKnown == true and cast.notInterruptible == false and
        readyAt > now and readyAt > startTime and readyAt < endTime
    if not showTick then
        frame.tick:Hide()
        frame:Hide()
        return
    end
    if frame.layoutAnchor ~= native then
        frame:ClearAllPoints()
        frame:SetPoint("TOPLEFT", native, "TOPLEFT", 0, 0)
        frame:SetSize(nativeWidth, nativeHeight)
        frame.layoutAnchor = native
    end
    frame.tick:SetSize(2, math.max(6, math.min(16, nativeHeight)))
    if nativeLevel then
        local frameLevelOK, frameLevel = invoke(frame, "GetFrameLevel")
        frameLevel = frameLevelOK and finite(frameLevel) or 0
        pcall(frame.tick.SetFrameLevel, frame.tick, math.max(nativeLevel + 5, frameLevel + 1))
    end

    local fraction
    if cast.isChannel then fraction = (endTime - readyAt) / duration
    else fraction = (readyAt - startTime) / duration end
    if reverse then fraction = 1 - fraction end
    fraction = math.max(0, math.min(1, fraction))
    frame.tick:ClearAllPoints()
    frame.tick:SetPoint("CENTER", native, "LEFT", nativeWidth * fraction, 0)
    frame.tick:Show()
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
