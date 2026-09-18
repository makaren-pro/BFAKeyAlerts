local BKA = BFAKeyAlerts
local Version = {}
BKA.Version = Version

local PREFIX = "BKA_VERSION"
local REPOSITORY = "https://github.com/makaren-pro/BFAKeyAlerts"

local function parse(version)
    local parts = {}
    for value in tostring(version or "0"):gmatch("(%d+)") do
        parts[#parts + 1] = tonumber(value) or 0
        if #parts == 4 then break end
    end
    return parts
end

local function isNewer(candidate, current)
    local a, b = parse(candidate), parse(current)
    for i = 1, 4 do
        local av, bv = a[i] or 0, b[i] or 0
        if av ~= bv then return av > bv end
    end
    return false
end

local function registerPrefix()
    if C_ChatInfo and C_ChatInfo.RegisterAddonMessagePrefix then
        return C_ChatInfo.RegisterAddonMessagePrefix(PREFIX)
    elseif RegisterAddonMessagePrefix then
        return RegisterAddonMessagePrefix(PREFIX)
    end
end

local function sendMessage(message, channel)
    if C_ChatInfo and C_ChatInfo.SendAddonMessage then
        C_ChatInfo.SendAddonMessage(PREFIX, message, channel)
    elseif SendAddonMessage then
        SendAddonMessage(PREFIX, message, channel)
    end
end

function Version:GetCurrent()
    if GetAddOnMetadata and BKA.name then
        return GetAddOnMetadata(BKA.name, "Version") or BKA.version or "0"
    end
    return BKA.version or "0"
end

function Version:Remember(version)
    if not BKA.db or not isNewer(version, self:GetCurrent()) then return false end
    local known = BKA.db.latestSeenVersion
    if not known or isNewer(version, known) then BKA.db.latestSeenVersion = version end
    return true
end

function Version:NotifyIfNeeded(version)
    if self.notified or not version or not isNewer(version, self:GetCurrent()) then return end
    self.notified = true
    BKA:Print("Доступна новая версия " .. tostring(version) .. ". GitHub: " .. REPOSITORY .. "/releases/latest")
end

function Version:Broadcast()
    local version = self:GetCurrent()
    if IsInGroup and IsInGroup(LE_PARTY_CATEGORY_INSTANCE) then
        sendMessage(version, "INSTANCE_CHAT")
    elseif IsInRaid and IsInRaid() then
        sendMessage(version, "RAID")
    elseif IsInGroup and IsInGroup() then
        sendMessage(version, "PARTY")
    end
end

function Version:OnMessage(prefix, message, _, sender)
    if prefix ~= PREFIX or not message or sender == UnitName("player") then return end
    if self:Remember(message) then self:NotifyIfNeeded(message) end
end

function Version:Initialize()
    if self.initialized then return end
    self.initialized = true
    registerPrefix()

    local frame = CreateFrame("Frame")
    frame:RegisterEvent("PLAYER_ENTERING_WORLD")
    frame:RegisterEvent("GROUP_ROSTER_UPDATE")
    frame:RegisterEvent("CHAT_MSG_ADDON")
    frame:SetScript("OnEvent", function(_, event, ...)
        if event == "PLAYER_ENTERING_WORLD" then
            C_Timer.After(2, function()
                if BKA.db then
                    Version:NotifyIfNeeded(BKA.db.latestSeenVersion)
                    Version:Broadcast()
                end
            end)
        elseif event == "GROUP_ROSTER_UPDATE" then
            C_Timer.After(1, function() Version:Broadcast() end)
        elseif event == "CHAT_MSG_ADDON" then
            Version:OnMessage(...)
        end
    end)
    self.frame = frame
end
