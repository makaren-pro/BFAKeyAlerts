-- Run from the workspace root: lua BFAKeyAlerts/Tests/bursting_removed.lua
local shownAlerts, unknownLogs = {}, 0
local playerGUID = "Player-1"
unpack = unpack or table.unpack

function wipe(value)
    for key in pairs(value) do value[key] = nil end
end
function GetTime() return 10 end
function GetSpellInfo(spellID) return "Spell " .. tostring(spellID) end
function UnitGUID(unit) return unit == "player" and playerGUID or unit end
function UnitIsUnit(first, second) return first == second end

local affixes = {11, 14, 4, 8}
C_ChallengeMode = {
    GetActiveKeystoneInfo = function() return 20, affixes end,
    GetActiveChallengeMapID = function() return 252 end,
    GetMapUIInfo = function() return "Test Dungeon", nil, 1000 end,
    GetAffixInfo = function(id) return ({[11] = "Bursting", [14] = "Quaking", [4] = "Necrotic", [8] = "Sanguine"})[id], nil, 1000 + id end,
}
LE_WORLD_ELAPSED_TIMER_TYPE_CHALLENGE_MODE = 1
function GetWorldElapsedTimers() return 1 end
function GetWorldElapsedTime() return 1, 100, LE_WORLD_ELAPSED_TIMER_TYPE_CHALLENGE_MODE end
C_Scenario = {
    GetStepInfo = function() return nil, nil, 0 end,
    GetCriteriaInfo = function() end,
}

local function textObject()
    local object = {value = ""}
    function object:SetText(value) self.value = value end
    function object:GetText() return self.value end
    function object:SetWordWrap() end
    function object:SetSpacing() end
    function object:SetTextColor() end
    function object:ClearAllPoints() end
    function object:SetPoint() end
    function object:GetStringHeight() return 10 end
    return object
end
local function barObject()
    local object = {background = {SetAlpha = function() end}}
    function object:ClearAllPoints() end
    function object:SetPoint() end
    function object:SetValue() end
    function object:SetStatusBarColor() end
    return object
end
local hud = {}
function hud:CreatePanel()
    local frame = {accent = {SetAlpha = function() end}}
    function frame:SetSize() end
    function frame:SetBackdropColor() end
    function frame:SetBackdropBorderColor() end
    function frame:Hide() self.hidden = true end
    function frame:Show() self.hidden = false end
    function frame:SetHeight() end
    return frame
end
function hud:Text() return textObject() end
function hud:Bar() return barObject() end
function hud:Apply() end

BFAKeyAlerts = {
    active = true,
    db = {firestorm = {}, keystoneHUD = {shown = true, locked = true, backgroundAlpha = 0.75}},
    HUD = hud,
    Alerts = {
        Show = function(_, ability) shownAlerts[#shownAlerts + 1] = ability end,
        Hide = function() end,
    },
    Sounds = {},
    Nameplates = {RefreshAll = function() end},
    L = function(_, key, ...) return string.format(key, ...) end,
    IsSpellAlias = function() return false end,
    IsPlayerOrPartyGUID = function(_, guid) return guid == playerGUID end,
    RoleNotificationAllows = function() return true end,
}
dofile("BFAKeyAlerts/Affixes.lua")
dofile("BFAKeyAlerts/KeystoneHUD.lua")

local affixModule = BFAKeyAlerts.Affixes
affixModule:Refresh()
assert(not affixModule:IsActive(11), "Bursting is absent from addon affix state")
assert(affixModule:IsActive(14) and affixModule:IsActive(4), "other affix state is preserved")
assert(affixModule:GetKnownAbility(240443) == nil, "Bursting aura spell has no alert ability")

-- Engine returns immediately when an affix handler reports true, before unknown-cast logging.
local handled = affixModule:HandleCombatLog("SPELL_CAST_START", 240443, "Bursting", "Creature-1", "Orb", 0)
if not handled then unknownLogs = unknownLogs + 1 end
assert(handled and unknownLogs == 0, "old Bursting spell is consumed before generic unknown logging")
assert(#shownAlerts == 0, "Bursting produces no alert")

-- Existing affix aura alerts remain available.
assert(affixModule:HandleCombatLog("SPELL_AURA_APPLIED", 240447, "Quaking", playerGUID, "Player", 0))
assert(affixModule:HandleCombatLog("SPELL_AURA_APPLIED", 209858, "Necrotic", playerGUID, "Player", 20))
assert(affixModule:HandleCombatLog("SPELL_DAMAGE", 226512, "Sanguine", playerGUID, "Player", 1))
assert(#shownAlerts == 3, "Quaking, Necrotic and Sanguine alerts remain supported")

-- The live Keystone HUD retains other affixes while omitting ID 11.
BFAKeyAlerts.KeystoneHUD:Refresh(true)
local affixText = BFAKeyAlerts.KeystoneHUD.frame.affixes:GetText()
assert(not string.find(affixText, "Bursting", 1, true), "HUD omits Bursting")
assert(string.find(affixText, "Quaking", 1, true) and string.find(affixText, "Necrotic", 1, true),
    "HUD retains other affix names")

print("bursting_removed: no affix state, alert, or unknown log; other affix alerts and HUD names preserved")
