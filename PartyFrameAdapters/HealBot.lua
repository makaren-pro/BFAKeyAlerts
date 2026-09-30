local BKA = BFAKeyAlerts
local Targets = BKA.PartyFrameTargets
local Adapter = { name = "HealBot", priority = 2, frames = {}, lastScan = -math.huge, missing = true }

function Adapter:IsAvailable()
    if not IsAddOnLoaded then return false end
    local ok, loaded = pcall(IsAddOnLoaded, "HealBot")
    return ok and loaded == true
end

local function healBotName(frame, hint)
    local name = hint
    local fieldOK, getName = pcall(function() return frame and frame.GetName end)
    if not name and fieldOK and type(getName) == "function" then
        local ok, value = pcall(getName, frame)
        if ok then name = value end
    end
    return type(name) == "string" and string.find(string.lower(name), "healbot", 1, true) ~= nil
end

local function collectLibFrames(adapter, unit)
    if not LibStub then return end
    local ok, library = pcall(LibStub, "LibGetFrame-1.0", true)
    local fieldOK, getUnitFrame = pcall(function() return library and library.GetUnitFrame end)
    if not ok or not library or not fieldOK or type(getUnitFrame) ~= "function" then return end
    local callOK, frames = pcall(getUnitFrame, unit, { returnAll = true })
    if not callOK or type(frames) ~= "table" then return end
    for frame, hint in pairs(frames) do
        if (type(frame) == "table" or type(frame) == "userdata") and healBotName(frame, hint) then adapter.frames[frame] = true end
    end
end

local function cacheUnitButtons(adapter, value)
    local valueType = type(value)
    if valueType ~= "table" and valueType ~= "userdata" then return end
    local fieldOK, getAttribute = pcall(function() return value.GetAttribute end)
    if fieldOK and type(getAttribute) == "function" then
        adapter.frames[value] = true
        return
    end
    if valueType == "table" then
        for _, frame in ipairs(value) do cacheUnitButtons(adapter, frame) end
    end
end

function Adapter:Refresh(event, addonName)
    if not self:IsAvailable() then return end
    local now = GetTime and GetTime() or 0
    local force = event == "ADDON_LOADED" and (not addonName or string.lower(addonName) == "healbot")
    if not force and now - self.lastScan < 2 then return end
    self.lastScan = now
    for name, frame in pairs(_G) do
        local typeOfFrame = type(frame)
        if type(name) == "string" and string.match(name, "^HealBot_") and
            (typeOfFrame == "table" or typeOfFrame == "userdata") then
            local fieldOK, getAttribute = pcall(function() return frame.GetAttribute end)
            if fieldOK and type(getAttribute) == "function" then self.frames[frame] = true end
        end
    end
end

function Adapter:FindFrameForUnit(unit, guid)
    if not self:IsAvailable() then return nil end
    self:Refresh()
    local indexed = _G.HealBot_Unit_Button
    if type(indexed) == "table" then
        cacheUnitButtons(self, indexed[unit])
        for alias, frame in pairs(indexed) do
            if type(alias) == "string" and string.find(alias, unit, 1, true) then cacheUnitButtons(self, frame) end
        end
    end
    collectLibFrames(self, unit)
    for frame in pairs(self.frames) do
        if healBotName(frame) and Targets:ValidateUnitFrame(frame, unit, guid) then
            self.missing = false
            return frame
        end
    end
    self.missing = true
end

function Adapter:AttachOverlay(frame, unit, guid)
    return Targets:AttachOverlay(frame, unit, guid)
end

function Adapter:DetachOverlay(guid, overlay)
    return Targets:DetachOverlay(guid, overlay)
end

Targets:RegisterAdapter(Adapter)
