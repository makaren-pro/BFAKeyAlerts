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
    BKA:Print(label .. (value and " ON" or " OFF"))
end

SLASH_BFAKEYALERTS1 = "/bka"
SlashCmdList.BFAKEYALERTS = function(input)
    local command, argument = string.match(string.lower(input or ""), "^%s*(%S*)%s*(.-)%s*$")
    if command == "on" then
        setBoolean("enabled", true, "addon")
        BKA:RefreshActivation()
        if BKA.Nameplates and BKA.Nameplates.RefreshClickTargeting then BKA.Nameplates:RefreshClickTargeting() end
        if BKA.GroupInterrupts then BKA.GroupInterrupts:Refresh(true) end
        if BKA.KeystoneHUD then BKA.KeystoneHUD:Refresh(true) end
    elseif command == "off" then
        setBoolean("enabled", false, "addon")
        BKA:RefreshActivation()
        if BKA.Nameplates and BKA.Nameplates.RefreshClickTargeting then BKA.Nameplates:RefreshClickTargeting() end
        if BKA.GroupInterrupts then BKA.GroupInterrupts:Refresh(true) end
        if BKA.KeystoneHUD then BKA.KeystoneHUD:Refresh(true) end
    elseif command == "alerts" and (argument == "on" or argument == "off") then
        setBoolean("showAlerts", argument == "on", "center alerts")
        if argument == "off" and BKA.Alerts then BKA.Alerts:Clear() end
    elseif command == "plates" and (argument == "on" or argument == "off") then
        setBoolean("showNameplates", argument == "on", "nameplates")
        if BKA.Nameplates then
            if argument == "off" then BKA.Nameplates:Clear() else BKA.Nameplates:RefreshAll() end
            BKA.Nameplates:RefreshClickTargeting()
        end
    elseif command == "kicks" and (argument == "on" or argument == "off") then
        BKA.db.kickTracker.shown = argument == "on"
        if BKA.GroupInterrupts then BKA.GroupInterrupts:Refresh(true) end
        BKA:Print("group kicks " .. string.upper(argument))
    elseif command == "keytimer" and (argument == "on" or argument == "off") then
        BKA.db.keystoneHUD.shown = argument == "on"
        if BKA.KeystoneHUD then BKA.KeystoneHUD:Refresh(true) end
        BKA:Print("key timer " .. string.upper(argument))
    elseif command == "sound" and (argument == "on" or argument == "off") then
        setBoolean("sound", argument == "on", "sound")
    elseif command == "frontal" and (argument == "on" or argument == "off") then
        setBoolean("showFrontalTarget", argument == "on", "frontal target details")
    elseif command == "plateclick" and (argument == "on" or argument == "off") then
        setBoolean("clickableNameplateAlerts", argument == "on", "clickable nameplate alerts")
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
        BKA:Print("combat sound actions reset to ON")
    elseif command == "unlock" then
        BKA.Alerts:SetUnlocked(true)
    elseif command == "lock" then
        BKA.Alerts:SetUnlocked(false)
    else
        BKA:Print("/bka config, alerts on|off, plates on|off, kicks on|off, keytimer on|off, frontal on|off, plateclick on|off|status, soundpreview <name|all|keyupgrade>, soundreset, unlock, lock, on|off, sound on|off")
    end
end
