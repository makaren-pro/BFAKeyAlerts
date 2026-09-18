local BKA = BFAKeyAlerts

BKA.defaults = {
    enabled = true,
    sound = true,
    soundActions = {
        KICK = true, STOP = true, TURN = true, AOE = true, FRONTAL = true, MOVE = true, YOU = true,
        DISPEL = true, PURGE = true, SOOTHE = true, DEFENSIVE = true, HEAL = true,
        SOAK = true, SPREAD = true, STACK = true, LOS = true, RUN = true,
        KITE = true, PREPARE = true,
    },
    roleFilter = false,
    alertStyle = "BAR",
    showAlerts = true,
    showNameplates = true,
    showTankAlerts = true,
    showHealerAlerts = true,
    showInfestedAdds = true,
    showFrontalTarget = true,
    clickableNameplateAlerts = true,
    kickTracker = {
        shown = true, locked = true, scale = 1, width = 320, alpha = 0.92, onlyInKey = false,
        point = "CENTER", relativePoint = "CENTER", x = 350, y = -160,
    },
    keystoneHUD = {
        shown = true, locked = true, scale = 1, backgroundAlpha = 0.75, hideBlizzard = true,
        point = "CENTER", relativePoint = "CENTER", x = -350, y = 0,
    },
    layout = {
        point = "TOP",
        relativePoint = "TOP",
        x = 0,
        y = -155,
        scale = 1,
        width = 370,
    },
    firestorm = {},
}

function BKA:InitDB()
    if type(BFAKeyAlertsDB) ~= "table" then
        BFAKeyAlertsDB = {}
    end
    self.db = BFAKeyAlertsDB
    for key, value in pairs(self.defaults) do
        if self.db[key] == nil then
            self.db[key] = type(value) == "table" and {} or value
        end
    end
    if type(self.db.firestorm) ~= "table" then
        self.db.firestorm = {}
    end
    if type(self.db.soundActions) ~= "table" then
        self.db.soundActions = {}
    end
    for key, value in pairs(self.defaults.soundActions) do
        if self.db.soundActions[key] == nil then self.db.soundActions[key] = value end
    end
    local nested = { "layout", "kickTracker", "keystoneHUD" }
    for _, tableKey in ipairs(nested) do
        if type(self.db[tableKey]) ~= "table" then self.db[tableKey] = {} end
        for key, value in pairs(self.defaults[tableKey]) do
            if self.db[tableKey][key] == nil then self.db[tableKey][key] = value end
        end
    end

    -- Remove obsolete settings left by pre-1.5 profiles.
    self.db.unknown = nil
    self.db.debug = nil
    self.db.kickTracker.showBoltGun = nil
    if self.db.firestorm then self.db.firestorm.boltGunSpellID = nil end
end

local function setBoolean(key, value, label)
    BKA.db[key] = value
    BKA:Print(label .. " " .. BKA:L(value and "ON" or "OFF"))
end

SLASH_BFAKEYALERTS1 = "/bka"
SlashCmdList.BFAKEYALERTS = function(input)
    local command, argument = string.match(string.lower(input or ""), "^%s*(%S*)%s*(.-)%s*$")
    if command == "on" then
        setBoolean("enabled", true, BKA:L("ADDON"))
        BKA:RefreshActivation()
        if BKA.Nameplates and BKA.Nameplates.RefreshClickTargeting then BKA.Nameplates:RefreshClickTargeting() end
        if BKA.GroupInterrupts then BKA.GroupInterrupts:Refresh(true) end
        if BKA.KeystoneHUD then BKA.KeystoneHUD:Refresh(true) end
    elseif command == "off" then
        setBoolean("enabled", false, BKA:L("ADDON"))
        BKA:RefreshActivation()
        if BKA.Nameplates and BKA.Nameplates.RefreshClickTargeting then BKA.Nameplates:RefreshClickTargeting() end
        if BKA.GroupInterrupts then BKA.GroupInterrupts:Refresh(true) end
        if BKA.KeystoneHUD then BKA.KeystoneHUD:Refresh(true) end
    elseif command == "alerts" and (argument == "on" or argument == "off") then
        setBoolean("showAlerts", argument == "on", BKA:L("CENTER_ALERTS"))
        if argument == "off" and BKA.Alerts then BKA.Alerts:Clear() end
    elseif command == "plates" and (argument == "on" or argument == "off") then
        setBoolean("showNameplates", argument == "on", BKA:L("NAMEPLATES"))
        if BKA.Nameplates then
            if argument == "off" then BKA.Nameplates:Clear() else BKA.Nameplates:RefreshAll() end
            BKA.Nameplates:RefreshClickTargeting()
        end
    elseif command == "kicks" and (argument == "on" or argument == "off") then
        BKA.db.kickTracker.shown = argument == "on"
        if BKA.GroupInterrupts then BKA.GroupInterrupts:Refresh(true) end
        BKA:Print(BKA:L("GROUP_KICKS") .. " " .. BKA:L(argument == "on" and "ON" or "OFF"))
    elseif command == "keytimer" and (argument == "on" or argument == "off") then
        BKA.db.keystoneHUD.shown = argument == "on"
        if BKA.KeystoneHUD then BKA.KeystoneHUD:Refresh(true) end
        BKA:Print(BKA:L("KEYSTONE_TIMER") .. " " .. BKA:L(argument == "on" and "ON" or "OFF"))
    elseif command == "sound" and (argument == "on" or argument == "off") then
        setBoolean("sound", argument == "on", BKA:L("SOUND"))
    elseif command == "frontal" and (argument == "on" or argument == "off") then
        setBoolean("showFrontalTarget", argument == "on", BKA:L("FRONTAL_DETAILS"))
    elseif command == "plateclick" and (argument == "on" or argument == "off") then
        setBoolean("clickableNameplateAlerts", argument == "on", BKA:L("CLICKABLE_NAMEPLATES"))
        if BKA.Nameplates and BKA.Nameplates.RefreshClickTargeting then
            BKA.Nameplates:RefreshClickTargeting()
        end
    elseif command == "plateclick" and argument == "status" then
        if BKA.Nameplates and BKA.Nameplates.PrintClickTargetingStatus then
            BKA.Nameplates:PrintClickTargetingStatus()
        end
    elseif command == "config" then
        BKA.Options:Open()
    elseif command == "soundpreview" then
        if argument == "" then
            BKA.Options:Open("sounds")
        elseif argument == "all" then
            BKA.Sounds:PreviewAll()
        elseif argument == "keyupgrade" or argument == "upgrade" or argument == "victory" then
            BKA.Sounds:PlayKeyUpgrade(true)
        elseif BKA.Sounds:Normalize(argument) then
            BKA.Sounds:Preview(argument)
        else
            BKA:Print("soundpreview: " .. table.concat(BKA.Sounds:GetActions(), ", "))
        end
    elseif command == "soundreset" then
        BKA.Sounds:ResetActions()
        if BKA.Options and BKA.Options.Refresh then BKA.Options:Refresh() end
        BKA:Print(BKA:L("SOUND_RESET_DONE"))
    elseif command == "unlock" then
        BKA.Alerts:SetUnlocked(true)
    elseif command == "lock" then
        BKA.Alerts:SetUnlocked(false)
    else
        BKA:Print(BKA:L("SLASH_HELP"))
    end
end
