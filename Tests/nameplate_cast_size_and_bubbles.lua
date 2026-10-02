-- Run from the workspace root: lua BFAKeyAlerts/Tests/nameplate_cast_size_and_bubbles.lua
-- Synthetic frames validate state/scale transitions; real click targeting requires the client.
local frames, pending = {}, {}
local bubbleFrame
CreateFrame = function()
    local f = {}
    function f:RegisterEvent() end
    function f:SetScript(name, fn) self[name] = fn end
    frames[#frames + 1] = f
    return f
end
C_Timer = { After = function(_, fn) pending[#pending + 1] = fn end }
local function flush()
    local q = pending; pending = {}; for _, fn in ipairs(q) do fn() end
    if bubbleFrame and bubbleFrame.OnUpdate then bubbleFrame.OnUpdate(nil, 1) end
end
local inside = false
IsInInstance = function() return inside, inside and 'party' or 'none' end
local values = {chatBubbles = '1', chatBubblesParty = '0'}
GetCVar = function(name) return values[name] end
SetCVar = function(name, value) values[name] = value end
BFAKeyAlerts = {db = {enabled = true, hideChatBubblesInKey = true}}
dofile('BFAKeyAlerts/ChatBubbles.lua'); bubbleFrame = frames[#frames]
local bubbles, event = BFAKeyAlerts.ChatBubbles, bubbleFrame.OnEvent
bubbles:Refresh(); assert(values.chatBubbles == '1')
inside = true; event(nil, 'PLAYER_ENTERING_WORLD'); flush()
assert(values.chatBubbles == '0' and values.chatBubblesParty == '0')
inside = false; event(nil, 'PLAYER_ENTERING_WORLD')
assert(values.chatBubbles == '1' and values.chatBubblesParty == '0')
print('chat bubbles: dungeon entry and exit passed')

local BKA = BFAKeyAlerts
BKA.db = {enabled = true, showNameplates = true, clickableNameplateAlerts = true, emphasizeInterruptibleCasts = false}
BKA.colors = {LOW = {0.72, 0.76, 0.82}}
BKA.severityRank = {LOW = 1}
function BKA:NormalizeAction(action) return action end
function BKA:ResolveIcon() return 'icon' end
function BKA:LocalizeAction(action) return action end
function BKA:RoleNotificationAllows() return true end
GetTime = function() return 10 end
UnitGUID = function() return 'Creature-A' end
UnitExists = function() return true end
local hovered = false
MouseIsOver = function() return hovered end
dofile('BFAKeyAlerts/Nameplates.lua')
local plates = BKA.Nameplates
local state = {castIdentity = 'cast-1', interruptibilityKnown = true, notInterruptible = false}
assert(plates:GetCastScale(state) == 1)
BKA.db.emphasizeInterruptibleCasts = true
assert(plates:GetCastScale(state) == 1.3)
state.notInterruptible = true; assert(plates:GetCastScale(state) == 0.8)
state.interruptibilityKnown = false; assert(plates:GetCastScale(state) == 1)
assert(plates:GetCastScale({prediction = true}) == 1)
local function visual()
    return setmetatable({shown = false}, {__index = function(_, key)
        if key:match('State$') or key == 'predictionData' or key == 'castSuppressed' then return nil end
        if key == 'Show' then return function(self) self.shown = true end end
        if key == 'Hide' then return function(self) self.shown = false end end
        if key == 'IsShown' or key == 'IsVisible' then return function(self) return self.shown end end
        if key == 'IsPlaying' then return function() return false end end
        if key == 'SetAlpha' then return function(self, value) self.alpha = value end end
        if key == 'SetScale' then return function(self, value) self.scale = value end end
        if key == 'SetScript' then return function(self, name, fn) self[name] = fn end end
        return function() end
    end})
end
local function makeOverlay(guid)
local overlay = visual()
overlay.infestedMarker = false
overlay.generation = 0
for _, key in ipairs({'background','icon','label','detail','countdown','glow','circle','square','controlBadge'}) do overlay[key] = visual() end
for _, shape in ipairs({overlay.circle, overlay.square}) do
    shape.icon, shape.label, shape.countdown, shape.pulse = visual(), visual(), visual(), visual()
    shape.pulseFrame = {anim = visual()}; shape.pulse.anim = visual(); shape.ring = visual()
end
overlay.glow.lines, overlay.square.lines, overlay.square.pulse.lines, overlay.controlBadge.lines = {}, {}, {}, {}
overlay.glow.anim, overlay.controlBadge.anim = visual(), visual()
overlay.controlBadge.text = visual(); overlay.ownerGUID = guid
return overlay
end
local overlay = makeOverlay('Creature-A')
plates.overlays.nameplate1 = overlay
local cast = {unit = 'nameplate1', identity = 'cast-1', notInterruptible = false, interruptibilityKnown = true, generation = 1}
local resolution = {action = 'KICK', nameplateAction = 'KICK', severity = 'LOW'}
plates:ShowActive(cast, resolution); assert(overlay.scale == 1.3)
plates.clickTargetingApplied = true; hovered = true; plates:UpdateHoverVisual(overlay, 1)
assert(math.abs(overlay.scale - 1.404) < 0.00001)
hovered = false; plates:UpdateHoverVisual(overlay, 1); assert(overlay.scale == 1.3)
cast.notInterruptible = true; plates:ShowActive(cast, resolution); assert(overlay.scale == 0.8)
for _, shape in ipairs({'CIRCLE', 'SQUARE'}) do
    overlay.activeState.ability = {plateShape = shape}; plates:Render('nameplate1'); assert(overlay.scale == 0.8)
end
overlay.activeState = nil; overlay.predictionState = {prediction = true, action = 'KICK', label = 'KICK', severity = 'LOW'}
plates:Render('nameplate1'); assert(overlay.scale == 1)
overlay.predictionState = nil; plates:ShowActive(cast, resolution)
BKA.db.emphasizeInterruptibleCasts = false; plates:Render('nameplate1'); assert(overlay.scale == 1)
BKA.db.emphasizeInterruptibleCasts = true
cast.interruptibilityKnown = false; plates:ShowActive(cast, resolution); assert(overlay.scale == 1)
cast.interruptibilityKnown = true; plates:ShowActive(cast, resolution)
BKA.ActiveCasts = {UnitGone = function() end}; BKA.Targets = {RemoveUnit = function() end}
plates:OnRemoved('nameplate1'); assert(overlay.scale == 1 and not overlay:IsShown())
plates.clickDefaults = {width = 132}
local left, right, top = plates:GetDesiredClickInsets()
assert(left <= -(132 * 1.404 - 132)/2 and top <= -(114 * 1.404))
BKA.db.emphasizeInterruptibleCasts = false
left, right, top = plates:GetDesiredClickInsets(); assert(left == -4 and top == -121)
print('cast markers: rendering, runtime changes, hover, recycling, click bounds passed')

local inCombat, writes = true, 0
InCombatLockdown = function() return inCombat end
C_NamePlate = {}
C_NamePlate.GetNamePlateEnemyClickThrough = function() return false end
C_NamePlate.GetNamePlateEnemyPreferredClickInsets = function() return 0, 0, 0, 0 end
C_NamePlate.SetNamePlateEnemyClickThrough = function() writes = writes + 1 end
C_NamePlate.SetNamePlateEnemyPreferredClickInsets = function() writes = writes + 1 end
BKA.db.emphasizeInterruptibleCasts = true
plates:RefreshClickTargeting(); assert(writes == 0 and plates.clickTargetingPending)
inCombat = false; frames[#frames].OnEvent(nil, 'PLAYER_REGEN_ENABLED')
assert(writes == 2 and not plates.clickTargetingPending)
print('click targeting: protected writes deferred until combat ends passed')

-- Multiple overlapping casts: all uninterruptible markers return only after
-- the final kickable cast disappears, without stopping hidden countdowns.
local guids = {nameplate1 = 'Creature-A', nameplate2 = 'Creature-B', nameplate3 = 'Creature-C'}
UnitGUID = function(unit) return guids[unit] end
local kick1, kick2 = makeOverlay('Creature-B'), makeOverlay('Creature-C')
plates.overlays = {nameplate1 = overlay, nameplate2 = kick1, nameplate3 = kick2}
local unkick = {unit = 'nameplate1', identity = 'unkick', generation = 2, endTime = 20, notInterruptible = true, interruptibilityKnown = true}
local k1 = {unit = 'nameplate2', identity = 'kick1', generation = 3, endTime = 15, notInterruptible = false, interruptibilityKnown = true}
local k2 = {unit = 'nameplate3', identity = 'kick2', generation = 4, endTime = 17, notInterruptible = false, interruptibilityKnown = true}
plates:ShowActive(unkick, resolution); plates:ShowActive(k1, resolution)
assert(overlay.alpha == 1) -- default disabled
BKA.db.hideUninterruptibleDuringKick = true; plates:RefreshCastVisibility()
assert(overlay.alpha == 0 and overlay:IsShown() and type(overlay.OnUpdate) == 'function')
assert(kick1.alpha == 1)
kick1:Hide(); plates:RefreshCastVisibility(); assert(overlay.alpha == 1)
kick1:Show(); plates:RefreshCastVisibility(); assert(overlay.alpha == 0)
plates:ShowActive(k2, resolution)
local restorePersistent = plates.RestorePersistent
plates.RestorePersistent = function(self, unit) self:Render(unit) end
plates:ClearActive('nameplate2', 3); assert(overlay.alpha == 0)
plates:ClearActive('nameplate3', 999); assert(overlay.alpha == 0) -- stale STOP
plates:ClearActive('nameplate3', 4); assert(overlay.alpha == 1)
plates:ShowActive(k1, resolution); assert(overlay.alpha == 0)
k1.notInterruptible = true; plates:ShowActive(k1, resolution); assert(overlay.alpha == 1)
k1.notInterruptible = false; plates:ShowActive(k1, resolution)
unkick.interruptibilityKnown = false; plates:ShowActive(unkick, resolution); assert(overlay.alpha == 1)
unkick.interruptibilityKnown = true; plates:ShowActive(unkick, resolution)
BKA.db.hideUninterruptibleDuringKick = false; plates:RefreshCastVisibility(); assert(overlay.alpha == 1)
BKA.db.hideUninterruptibleDuringKick = true; plates:RefreshCastVisibility(); assert(overlay.alpha == 0)
-- A hidden cast must still expire; expiry does not restore an ended marker.
BKA.ActiveCasts.Expire = function(_, unit, generation) plates:ClearActive(unit, generation) end
GetTime = function() return 21 end
overlay.OnUpdate(nil, 0.1); assert(not overlay:IsShown() and not overlay.activeState)
GetTime = function() return 10 end
plates:ShowActive(unkick, resolution); assert(overlay.alpha == 0)
plates:OnRemoved('nameplate2'); assert(overlay.alpha == 1)
plates.RestorePersistent = restorePersistent
-- Forecasts never trigger suppression, and retain their own opacity.
overlay.activeState = nil; overlay.predictionState = {prediction = true, action = 'KICK', label = 'KICK', severity = 'LOW'}
plates:Render('nameplate1'); assert(overlay.alpha == 0.30)
print('cast focus: overlapping casts, stale STOP, interruptibility, expiry, removal, predictions passed')
