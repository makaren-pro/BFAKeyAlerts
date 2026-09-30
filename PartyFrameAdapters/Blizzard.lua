local BKA = BFAKeyAlerts
local Targets = BKA.PartyFrameTargets
local Adapter = { name = "Blizzard", priority = 3 }

local function frameForUnit(frame, unit, guid)
    if Targets:ValidateUnitFrame(frame, unit, guid) then return frame end
end

local function indexedFrames(prefix, first, last, suffix)
    local list = {}
    for index = first, last do
        local frame = _G[prefix .. index .. (suffix or "")]
        if frame then list[#list + 1] = frame end
    end
    return list
end

function Adapter:IsAvailable()
    return true
end

function Adapter:FindFrameForUnit(unit, guid)
    local frame = _G.PlayerFrame
    if frameForUnit(frame, unit, guid) then return frame end
    for _, candidate in ipairs(indexedFrames("PartyMemberFrame", 1, 4)) do
        if frameForUnit(candidate, unit, guid) then return candidate end
    end
    for _, candidate in ipairs(indexedFrames("CompactPartyFrameMember", 1, 5)) do
        if frameForUnit(candidate, unit, guid) then return candidate end
    end
    for group = 1, 8 do
        for member = 1, 5 do
            local candidate = _G["CompactRaidGroup" .. group .. "Member" .. member]
            if frameForUnit(candidate, unit, guid) then return candidate end
        end
    end
    for _, candidate in ipairs(indexedFrames("CompactRaidFrame", 1, 40)) do
        if frameForUnit(candidate, unit, guid) then return candidate end
    end
    for _, candidate in ipairs(indexedFrames("raidframe", 1, 40)) do
        if frameForUnit(candidate, unit, guid) then return candidate end
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
