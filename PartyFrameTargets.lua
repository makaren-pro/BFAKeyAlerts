local BKA = BFAKeyAlerts
local Targets = {
    adapters = {}, adapterByName = {}, bindings = {}, candidates = {}, freeOverlays = {}, dirty = true,
    initialized = false, elapsed = 0, lastUpdate = 0,
    nextDiscoveryAt = 0,
}
BKA.PartyFrameTargets = Targets

local function config()
    return BKA.db and BKA.db.partyFrameTargets or {}
end

local function enabled()
    return BKA.active == true and BKA.db and BKA.db.enabled ~= false and config().enabled == true
end

local function safeCall(object, method, ...)
    if not object then return nil, false end
    local fieldOK, fn = pcall(function() return object[method] end)
    if not fieldOK or type(fn) ~= "function" then return nil, false end
    local ok, value = pcall(fn, object, ...)
    if ok then return value, true end
    return nil, false
end

local function unitTokenForGUID(guid)
    if not guid then return nil end
    if UnitGUID and UnitGUID("player") == guid then return "player" end
    if IsInRaid and IsInRaid() then
        local count = GetNumGroupMembers and GetNumGroupMembers() or 40
        for i = 1, math.min(count, 40) do
            local unit = "raid" .. i
            if UnitExists(unit) and UnitGUID(unit) == guid then return unit end
        end
    else
        for i = 1, 4 do
            local unit = "party" .. i
            if UnitExists(unit) and UnitGUID(unit) == guid then return unit end
        end
    end
end

function Targets:GetUnitForGUID(guid)
    return unitTokenForGUID(guid)
end

function Targets:ValidateUnitFrame(frame, unit, guid)
    if not frame or not unit or not guid then return false end
    local frameType = type(frame)
    if frameType ~= "table" and frameType ~= "userdata" then return false end
    local fieldOK, isForbidden = pcall(function() return frame.IsForbidden end)
    if not fieldOK then return false end
    if isForbidden then
        local ok, forbidden = pcall(isForbidden, frame)
        if not ok or forbidden then return false end
    end
    local currentGUID = UnitGUID and UnitGUID(unit)
    if currentGUID ~= guid then return false end
    local visible, canCheckVisibility = safeCall(frame, "IsVisible")
    if not canCheckVisibility or visible == false then return false end
    local shown, canCheckShown = safeCall(frame, "IsShown")
    if not canCheckShown or shown == false then return false end
    local actualUnit
    local attributeOK, getAttribute = pcall(function() return frame.GetAttribute end)
    if not attributeOK then return false end
    if type(getAttribute) == "function" then
        local ok, value = pcall(getAttribute, frame, "unit")
        if ok and type(value) == "string" then actualUnit = value end
    end
    local ok, displayedUnit = pcall(function() return frame.displayedUnit end)
    local fieldOK, fieldUnit = pcall(function() return frame.unit end)
    actualUnit = actualUnit or (ok and displayedUnit) or (fieldOK and fieldUnit)
    if type(actualUnit) ~= "string" or actualUnit == "" then return false end
    local isSame
    if UnitIsUnit then
        local ok, value = pcall(UnitIsUnit, actualUnit, unit)
        if ok then isSame = value end
    end
    if isSame == true then return true end
    local ok, actualGUID = pcall(UnitGUID, actualUnit)
    return ok and actualGUID == guid
end

function Targets:RegisterAdapter(adapter)
    if not adapter or not adapter.name or type(adapter.FindFrameForUnit) ~= "function" then return false end
    if self.adapterByName[adapter.name] then return false end
    self.adapters[#self.adapters + 1] = adapter
    self.adapterByName[adapter.name] = adapter
    table.sort(self.adapters, function(a, b) return (a.priority or 99) < (b.priority or 99) end)
    self.dirty = true
    return true
end

local function createOverlay()
    local overlay = CreateFrame("Frame", nil, UIParent)
    overlay:EnableMouse(false)
    if overlay.SetMouseClickEnabled then overlay:SetMouseClickEnabled(false) end
    overlay.rows = {}
    for i = 1, 3 do
        local row = CreateFrame("Frame", nil, overlay)
        row:EnableMouse(false)
        row.icon = row:CreateTexture(nil, "ARTWORK")
        row.icon:SetAllPoints(row)
        row.borders = {}
        for edge = 1, 4 do
            local border = row:CreateTexture(nil, "OVERLAY")
            row.borders[edge] = border
        end
        row.count = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        row.count:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", 2, -2)
        row.count:SetTextColor(1, 1, 1, 1)
        row.count:SetShadowOffset(1, -1)
        row:Hide()
        overlay.rows[i] = row
    end
    overlay:Hide()
    return overlay
end

function Targets:AttachOverlay(frame, unit, guid)
    if not self:ValidateUnitFrame(frame, unit, guid) then return nil end
    local overlay = (self.bindings[guid] and self.bindings[guid].overlay) or table.remove(self.freeOverlays) or createOverlay()
    overlay:ClearAllPoints()
    overlay:SetParent(UIParent)
    overlay:SetFrameStrata(frame.GetFrameStrata and frame:GetFrameStrata() or "MEDIUM")
    overlay:SetFrameLevel((frame.GetFrameLevel and frame:GetFrameLevel() or 1) + 5)
    local anchor = tonumber(config().anchor) or 1
    if anchor == 2 then
        overlay:SetPoint("BOTTOM", frame, "TOP", 0, 2)
    elseif anchor == 3 then
        overlay:SetPoint("LEFT", frame, "RIGHT", 2, 0)
    else
        overlay:SetPoint("TOP", frame, "BOTTOM", 0, -2)
    end
    overlay.sourceFrame, overlay.ownerGUID, overlay.unit = frame, guid, unit
    overlay:Show()
    return overlay
end

function Targets:DetachOverlay(guid, overlay)
    if not overlay then return end
    for _, row in ipairs(overlay.rows or {}) do
        row:Hide()
        row._castID, row._texture, row._severity = nil, nil, nil
    end
    overlay:Hide()
    overlay.sourceFrame, overlay.ownerGUID, overlay.unit = nil, nil, nil
    if #self.freeOverlays < 40 then self.freeOverlays[#self.freeOverlays + 1] = overlay end
    if self.bindings[guid] and self.bindings[guid].overlay == overlay then self.bindings[guid] = nil end
end

local function severityRank(cast)
    local ability = cast.resolution and cast.resolution.ability
    local severity = (cast.resolution and cast.resolution.severity) or (ability and ability.severity)
    return BKA.severityRank and BKA.severityRank[severity] or 0
end

local function identity(cast)
    if cast.identity then return tostring(cast.identity) end
    return table.concat({ tostring(cast.sourceGUID or "?"), tostring(cast.spellID or "?"),
        tostring(math.floor((cast.startTime or 0) * 100 + 0.5)) }, ":")
end

function Targets:_collect(now)
    wipe(self.candidates)
    if not enabled() or not BKA.ActiveCasts then return end
    local unitByGUID, seen, liveSources = {}, {}, {}
    for unit, cast in pairs(BKA.ActiveCasts.byUnit or {}) do
        if unit and UnitExists(unit) and UnitGUID(unit) == cast.sourceGUID then liveSources[cast] = true end
    end
    for _, cast in pairs(BKA.ActiveCasts.byUnit or {}) do
        local targetGUID = cast.targetGUID
        local ability = cast.resolution and cast.resolution.ability
        local severity = severityRank(cast)
        if liveSources[cast] and cast.targetConfidence == "CONFIRMED" and targetGUID and ability and
            not (cast.resolution and cast.resolution.suppressAlert) and
            severity >= (tonumber(config().minSeverity) or 3) and
            (cast.endTime or 0) > now and not seen[identity(cast)] then
            seen[identity(cast)] = true
            local unit = unitByGUID[targetGUID] or unitTokenForGUID(targetGUID)
            if unit then
                unitByGUID[targetGUID] = unit
                local group = self.candidates[targetGUID]
                if not group then group = { unit = unit, casts = {} }; self.candidates[targetGUID] = group end
                local texture = cast.texture or cast._partyFrameTexture
                if not texture and BKA.ResolveIcon then
                    texture = BKA:ResolveIcon(ability, cast)
                    cast._partyFrameTexture = texture
                end
                group.casts[#group.casts + 1] = {
                    id = identity(cast), sourceGUID = cast.sourceGUID, spellID = cast.spellID,
                    startTime = cast.startTime or 0, endTime = cast.endTime, severity = severity,
                    texture = texture, cast = cast,
                    severityName = (cast.resolution and cast.resolution.severity) or ability.severity,
                }
            end
        end
    end
    for _, group in pairs(self.candidates) do
        table.sort(group.casts, function(a, b)
            if a.severity ~= b.severity then return a.severity > b.severity end
            if a.endTime ~= b.endTime then return a.endTime < b.endTime end
            if a.sourceGUID ~= b.sourceGUID then return tostring(a.sourceGUID) < tostring(b.sourceGUID) end
            if a.spellID ~= b.spellID then return (a.spellID or 0) < (b.spellID or 0) end
            return a.id < b.id
        end)
    end
end

local function renderOverlay(overlay, casts, now)
    local cfg = config()
    local size = math.max(12, math.min(28, tonumber(cfg.iconSize) or 18))
    local count = math.min(3, math.max(1, tonumber(cfg.maxSpells) or 3), #casts)
    local anchor = tonumber(cfg.anchor) or 1
    local horizontal = anchor ~= 3
    local layoutKey = table.concat({ size, count, anchor }, ":")
    if overlay._layoutKey ~= layoutKey then
        overlay:SetSize(horizontal and (count * size + (count - 1) * 2) or size,
            horizontal and size or (count * size + (count - 1) * 2))
        overlay._layoutKey = layoutKey
    end
    for index, row in ipairs(overlay.rows) do
        local cast = casts[index]
        if index <= count and cast then
            local rowLayoutKey = layoutKey .. ":" .. index
            if row._layoutKey ~= rowLayoutKey then
                row:ClearAllPoints()
                if horizontal then row:SetPoint("LEFT", overlay, "LEFT", (index - 1) * (size + 2), 0)
                else row:SetPoint("TOP", overlay, "TOP", 0, -(index - 1) * (size + 2)) end
                row:SetSize(size, size)
                row._layoutKey = rowLayoutKey
            end
            if row._castID ~= cast.id or row._texture ~= cast.texture then
                row.icon:SetTexture(cast.texture)
                row._castID = cast.id
                row._texture = cast.texture
            end
            if row._severity ~= cast.severityName then
                local color = BKA.colors and BKA.colors[cast.severityName] or { 1, 1, 1 }
                for _, border in ipairs(row.borders) do border:SetColorTexture(color[1], color[2], color[3], 1) end
                row.borders[1]:ClearAllPoints(); row.borders[1]:SetPoint("TOPLEFT", row, "TOPLEFT"); row.borders[1]:SetPoint("TOPRIGHT", row, "TOPRIGHT"); row.borders[1]:SetHeight(1)
                row.borders[2]:ClearAllPoints(); row.borders[2]:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT"); row.borders[2]:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT"); row.borders[2]:SetHeight(1)
                row.borders[3]:ClearAllPoints(); row.borders[3]:SetPoint("TOPLEFT", row, "TOPLEFT"); row.borders[3]:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT"); row.borders[3]:SetWidth(1)
                row.borders[4]:ClearAllPoints(); row.borders[4]:SetPoint("TOPRIGHT", row, "TOPRIGHT"); row.borders[4]:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT"); row.borders[4]:SetWidth(1)
                row.count:SetTextColor(color[1], color[2], color[3], 1)
                row._severity = cast.severityName
            end
            if cfg.countdown ~= false then
                local remaining = cast.endTime - now
                row.count:SetText(remaining > 0 and string.format("%.1f", remaining) or "")
                row.count:Show()
            else row.count:SetText(""); row.count:Hide() end
            row:Show()
        else
            row:Hide()
        end
    end
    overlay:Show()
end

function Targets:Refresh()
    self.dirty = true
    for _, adapter in ipairs(self.adapters) do if adapter.Refresh then adapter:Refresh() end end
    if self.initialized then self:Update(GetTime and GetTime() or 0, true) end
end

function Targets:CastsChanged()
    self.dirty = true
    if self.initialized then self:Update(GetTime and GetTime() or 0, true) end
end

function Targets:Update(now, force)
    if not self.initialized then return end
    now = tonumber(now) or (GetTime and GetTime()) or 0
    if not force and now - self.lastUpdate < 0.1 then return end
    self.lastUpdate = now
    local needsDiscovery = false
    for guid in pairs(self.candidates) do if not self.bindings[guid] then needsDiscovery = true; break end end
    if needsDiscovery and now >= self.nextDiscoveryAt then
        self.nextDiscoveryAt = now + 2
        for _, adapter in ipairs(self.adapters) do if adapter.Refresh then adapter:Refresh() end end
        self.dirty = true
    end
    if not self.dirty then
        for _, group in pairs(self.candidates) do
            for _, cast in ipairs(group.casts) do
                if cast.endTime <= now then self.dirty = true; break end
            end
            if self.dirty then break end
        end
    end
    if self.dirty or force then
        self:_collect(now)
        for guid, group in pairs(self.candidates) do
            local selectedAdapter, selectedFrame
            for _, adapter in ipairs(self.adapters) do
                if not adapter.IsAvailable or adapter:IsAvailable() then
                    local frame = adapter:FindFrameForUnit(group.unit, guid)
                    if self:ValidateUnitFrame(frame, group.unit, guid) then
                        selectedAdapter, selectedFrame = adapter, frame
                        break
                    end
                end
            end
            local binding = self.bindings[guid]
            if binding and (binding.adapter ~= selectedAdapter or binding.sourceFrame ~= selectedFrame) then
                binding.adapter:DetachOverlay(guid, binding.overlay)
                binding = nil
            end
            if selectedAdapter and selectedFrame then
                if not binding then
                    local overlay = selectedAdapter:AttachOverlay(selectedFrame, group.unit, guid)
                    if overlay then
                        binding = { adapter = selectedAdapter, sourceFrame = selectedFrame, overlay = overlay }
                        self.bindings[guid] = binding
                    end
                end
                if binding then binding.unit = group.unit; renderOverlay(binding.overlay, group.casts, now) end
            elseif binding then
                binding.adapter:DetachOverlay(guid, binding.overlay)
                self.bindings[guid] = nil
            end
        end
        for guid, binding in pairs(self.bindings) do
            if not self.candidates[guid] or not self:ValidateUnitFrame(binding.sourceFrame, binding.unit, guid) then
                binding.adapter:DetachOverlay(guid, binding.overlay)
                self.bindings[guid] = nil
            end
        end
        self.dirty = false
    end
    for guid, binding in pairs(self.bindings) do
        local group = self.candidates[guid]
        if not group or not self:ValidateUnitFrame(binding.sourceFrame, binding.unit, guid) then
            binding.adapter:DetachOverlay(guid, binding.overlay)
            self.bindings[guid] = nil
            self.dirty = true
        else
            renderOverlay(binding.overlay, group.casts, now)
        end
    end
end

function Targets:Clear()
    for guid, binding in pairs(self.bindings) do
        binding.adapter:DetachOverlay(guid, binding.overlay)
        self.bindings[guid] = nil
    end
    wipe(self.candidates)
    self.dirty = true
end

function Targets:Initialize()
    if self.initialized then return end
    self.initialized = true
    local frame = CreateFrame("Frame")
    self.frame = frame
    frame:RegisterEvent("GROUP_ROSTER_UPDATE")
    frame:RegisterEvent("ADDON_LOADED")
    frame:RegisterEvent("PLAYER_ENTERING_WORLD")
    frame:RegisterEvent("PLAYER_REGEN_ENABLED")
    frame:SetScript("OnEvent", function(_, event, addonName)
        self.dirty = true
        for _, adapter in ipairs(self.adapters) do if adapter.Refresh then adapter:Refresh(event, addonName) end end
        self:Update(GetTime and GetTime() or 0, true)
    end)
    self:Refresh()
end

Targets:Initialize()
