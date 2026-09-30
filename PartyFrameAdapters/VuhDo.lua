local BKA = BFAKeyAlerts
local Targets = BKA.PartyFrameTargets
local Adapter = { name = "VuhDo", priority = 1 }

function Adapter:IsAvailable()
    if not IsAddOnLoaded then return false end
    local ok, loaded = pcall(IsAddOnLoaded, "VuhDo")
    return ok and loaded == true
end

local function candidateList(unit)
    local buttons
    if type(_G.VUHDO_getUnitButtons) == "function" then
        local ok, value = pcall(_G.VUHDO_getUnitButtons, unit)
        if ok and type(value) == "table" then buttons = value end
    end
    local index = _G.VUHDO_UNIT_BUTTONS
    if not buttons and type(index) == "table" then
        local ok, value = pcall(function() return index[unit] end)
        if ok then buttons = value end
    end
    return buttons
end

function Adapter:FindFrameForUnit(unit, guid)
    if not self:IsAvailable() then return nil end
    local buttons = candidateList(unit)
    if type(buttons) ~= "table" then return nil end
    for _, frame in ipairs(buttons) do
        if Targets:ValidateUnitFrame(frame, unit, guid) then return frame end
    end
end

function Adapter:AttachOverlay(frame, unit, guid)
    return Targets:AttachOverlay(frame, unit, guid)
end

function Adapter:DetachOverlay(guid, overlay)
    return Targets:DetachOverlay(guid, overlay)
end

function Adapter:Refresh() end

Targets:RegisterAdapter(Adapter)
