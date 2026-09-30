-- Existing overlay pool ownership, independent visibility and settings merge.
local guid = "Creature-A"
local frames = {}
local function frame(parent)
    local f = { parent = parent, shown = false }
    function f:SetParent(p) self.parent = p end
    function f:GetParent() return self.parent end
    function f:EnableMouse(v) self.mouse = v end
    function f:SetSize() end
    function f:SetPoint() end
    function f:ClearAllPoints() end
    function f:Show() self.shown = true end
    function f:Hide() self.shown = false end
    function f:SetShown(v) self.shown = v end
    function f:RegisterEvent() end
    function f:SetScript(k, v) self[k] = v end
    function f:CreateTexture() return frame(self) end
    function f:CreateFontString() return frame(self) end
    frames[#frames + 1] = f
    return f
end
CreateFrame = function(_, _, parent) return frame(parent) end
UnitExists = function() return true end
UnitGUID = function() return guid end
UnitIsDeadOrGhost = function() return false end
UnitCanAttack = function() return true end
GetTime = function() return 0 end
SlashCmdList = {}
local plate, overlay = frame(), frame()
overlay:SetParent(plate)
BFAKeyAlerts = { active = true, Nameplates = { GetOverlay = function() return overlay end } }
dofile("Config.lua")
for _, key in ipairs({ "enemySpellCooldowns", "autoMarkers", "partyFrameTargets", "mobState", "castbarIntelligence" }) do
    assert(BFAKeyAlerts.defaults[key].enabled == true, key .. " enabled by default")
end
BFAKeyAlertsDB = { enemySpellCooldowns = { enabled = false }, castLearning = { leadTime = 3 } }
BFAKeyAlerts:InitDB()
local bka = BFAKeyAlerts
assert(bka.db.enemySpellCooldowns.enabled == false, "explicit false preserved")
assert(bka.db.autoMarkers.enabled and bka.db.partyFrameTargets.enabled and bka.db.mobState.enabled and bka.db.castbarIntelligence.enabled)
assert(bka.db.castLearning.enabled and bka.db.castLearning.predictions and bka.db.castLearning.showPredictionAlerts)
assert(bka.db.castLearning.leadTime == 3 and bka.db.castLearning.importantOnly == false and bka.db.castLearning.version == 1)
dofile("CombatIntelligence.lua")
local ci = bka.CombatIntelligence
local host = ci:GetHost("nameplate1")
assert(host:GetParent() == plate and host:GetParent() ~= overlay and host.shown, "satellite independent of hidden primary")
local rows = ci:GetRows(host, "test", 2, 18)
rows[1]:Show(); rows[2]:Show()
assert(rows[1].mouse == false and host.mouse == false)
ci:RemoveUnit("nameplate1")
assert(not host.shown and not rows[1].shown and not rows[2].shown and not host.ownerGUID)
guid = "Creature-B"
local rebound = ci:GetHost("nameplate1")
assert(rebound == host and host.ownerGUID == guid and not rows[1].shown, "recycle clears old GUID rows")
assert(ci:GetRows(host, "test", 1, 18) == rows and not rows[2].shown, "bounded row reuse")
ci:Initialize()
ci.frame:Show()
local partyCleared = false
bka.PartyFrameTargets = { Clear = function() partyCleared = true end }
local markerChanged, mobChanged = false, false
bka.AutoMarkers = { SettingsChanged = function() markerChanged = true end }
bka.MobState = { SettingsChanged = function() mobChanged = true end }
ci:SettingsChanged("autoMarkers.priority")
assert(markerChanged and not mobChanged and not partyCleared and host.shown, "marker settings preserve presentation")
ci:SettingsChanged("mobState.power")
assert(mobChanged and not partyCleared and host.shown, "settings affect only their presentation layer")
ci:ClearNameplates()
assert(not partyCleared and ci.frame.shown, "nameplate toggle preserves party overlay updates")
ci:Clear()
assert(partyCleared, "full deactivation clears party overlays")
assert(not host.shown and next(ci.hosts) == nil and not ci.frame.shown)
bka.active = false
assert(ci:GetHost("nameplate1") == nil)
print("intelligence_pool: defaults, independent satellite, recycle and cleanup passed")
