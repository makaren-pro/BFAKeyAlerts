-- Minimal WoW UI stubs for the central alert layout and priority.
local now = 13
GetTime = function() return now end
GetSpellInfo = function(id) return "Spell " .. tostring(id) end

local function frame()
    local value = { shown = true, alpha = 1 }
    function value:CreateTexture() return frame() end
    function value:CreateFontString() return frame() end
    function value:CreateAnimationGroup() return frame() end
    function value:CreateAnimation() return frame() end
    function value:Show() self.shown = true end
    function value:Hide() self.shown = false end
    function value:SetShown(shown) self.shown = shown end
    function value:IsShown() return self.shown end
    function value:SetAlpha(alpha) self.alpha = alpha end
    function value:SetDesaturated(desaturated) self.desaturated = desaturated end
    function value:SetTexture(texture) self.texture = texture end
    function value:SetText(text) self.text = text end
    function value:SetFormattedText(format, ...) self.text = string.format(format, ...) end
    function value:SetCooldown(startTime, duration) self.startTime, self.duration = startTime, duration end
    function value:SetScript(_, script) self.script = script end
    function value:GetFrameLevel() return 1 end
    function value:IsPlaying() return false end
    return setmetatable(value, { __index = function(_, key)
        if string.match(key, "^[A-Z]") then return function() end end
    end })
end
CreateFrame = function() return frame() end
UIParent = frame()

BFAKeyAlerts = {
    db = { enabled = true, showAlerts = true, alertStyle = "BAR",
        castLearning = { showPredictionAlerts = true },
        layout = { point = "TOP", relativePoint = "TOP", x = 0, y = 0, scale = 1, width = 370 } },
    eventFrame = frame(),
    severityRank = { LOW = 1, MEDIUM = 2, HIGH = 3, CRITICAL = 4 },
    colors = { LOW = { 1, 1, 1 }, HIGH = { 1, 0.4, 0.2 } },
    L = function(_, key) return key end,
    NormalizeAction = function(_, action) return action end,
    LocalizeAction = function(_, action) return action end,
    LocalizeDetail = function(_, detail) return detail end,
    IsConfirmedPersonal = function() return false end,
    ShouldCenterAbility = function() return true, false end,
    RoleCenterAllows = function() return true end,
    ResolveIcon = function(_, ability) return "icon:" .. tostring(ability.id) end,
}
dofile("Alerts.lua")

local bka, alerts = BFAKeyAlerts, BFAKeyAlerts.Alerts
local ability = { id = 101, action = "KICK", severity = "HIGH", center = true, sound = false }
local function prediction(guid)
    return { guid = guid, sourceGUID = guid, spellID = 101, expectedTime = 16,
        lateWindow = 1, action = "KICK", ability = ability }
end
local function count(state)
    local total = 0
    for _, row in ipairs(alerts.rows) do
        if row:IsShown() and (not state or row.alertState == state) then total = total + 1 end
    end
    return total
end

local first = prediction("mob-1")
assert(alerts:ShowPrediction(first), "BAR prediction shown")
local row = first.alertRow
assert(#alerts.rows == 7 and row.bar.shown and not row.icon.shown, "BAR uses existing rows")
assert(row.alpha == 0.42 and row.bar.icon.desaturated and row.icon.texture.desaturated, "prediction appearance")
assert(row.bar.action.text == "KICK" and row.bar.detail.text == "Spell 101", "known action and spell")
assert(row.bar.icon.texture == "icon:101", "known spell icon")
alerts:OnUpdate()
assert(row.bar.countdown.text == "~3.0" and row.icon.countdown.text == "~3.0", "prediction countdown")
assert(row.expires == 17, "late window retained for cleanup")
first.expectedTime = 16.5
assert(alerts:SyncPrediction(first) and row.endTime == 16.5 and row.expires == 17.5, "same row resynchronized")

bka.db.alertStyle = "ICON"
alerts:ApplyLayout()
assert(not row.bar.shown and row.icon.shown, "ICON uses existing row")
assert(row.icon.action.text == "KICK" and row.icon.detail.text == "Spell 101", "ICON content")
alerts:Show(ability, { sourceGUID = "mob-1", spellID = 101, alertState = "ACTIVE", endTime = 18 })
assert(count("PREDICTED") == 0 and count("ACTIVE") == 1, "real cast replaces matching prediction")
assert(first.alertShown == nil and first.alertRow == nil, "real cast clears prediction runtime display state")

alerts:Clear()
for index = 1, 7 do assert(alerts:ShowPrediction(prediction("mob-" .. index)), "prediction capacity") end
assert(count("PREDICTED") == 7, "seven predicted rows use fixed stack")
alerts:Show(ability, { sourceGUID = "other-mob", spellID = 101, alertState = "ACTIVE", endTime = 18 })
assert(count("ACTIVE") == 1 and count("PREDICTED") == 6, "real alert evicts lower rank prediction")
assert(#alerts.rows == 7, "no permanent frame growth")

bka.db.showAlerts = false
assert(not alerts:ShowPrediction(prediction("disabled")), "master alert toggle respected")
print("prediction_alert_layout: BAR, ICON, countdown, priority, and master toggle passed")
