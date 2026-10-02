-- Run from the workspace root: lua BFAKeyAlerts/Tests/chat_bubbles_visibility.lua
-- Synthetic frame pool and challenge-state checks; Firestorm visibility still needs an in-game check.
local frame
CreateFrame = function()
    frame = { events = {} }
    function frame:RegisterEvent(event) self.events[event] = true end
    function frame:SetScript(name, fn) self[name] = fn end
    return frame
end

local inside, kind, difficulty = false, 'none', 1
local values = { chatBubbles = "1", chatBubblesParty = "0" }
local writes = 0
GetCVar = function(name) return values[name] end
SetCVar = function(name, value) writes = writes + 1; values[name] = value end
IsInInstance = function() return inside, kind end
GetInstanceInfo = function() return 'Dungeon', kind, difficulty end
-- The scope must not rely on challenge APIs: this reproduces the user's pre-key state.
C_ChallengeMode = { GetActiveChallengeMapID = function() error('unexpected challenge query') end }
C_ChatBubbles = nil
BFAKeyAlerts = { db = { enabled = true, hideChatBubblesInKey = true } }
dofile("BFAKeyAlerts/ChatBubbles.lua")
local bubbles, update = BFAKeyAlerts.ChatBubbles, frame.OnUpdate
frame.OnEvent(frame, 'PLAYER_ENTERING_WORLD')
assert(values.chatBubbles == '1', 'open world remains unchanged')
inside, kind = true, 'party'
for _, id in ipairs({1, 2, 23, 8}) do
    difficulty = id
    frame.OnEvent(frame, 'PLAYER_ENTERING_WORLD')
    assert(values.chatBubbles == '0' and values.chatBubblesParty == '0', 'all dungeon difficulties hide bubbles')
end
assert(BFAKeyAlerts.db.chatBubblesBeforeKey.chatBubbles == '1')
values.chatBubbles = '1' -- Another addon resets the CVar inside the dungeon.
local beforeReassert = writes
update(frame, 0.5)
assert(values.chatBubbles == '0' and writes == beforeReassert + 1, 'active CVar reassertion')
update(frame, 0.1)
assert(writes == beforeReassert + 1, 'avoid redundant CVar writes')

local function bubble(alpha, forbidden, protected)
    local b = { alpha = alpha, forbidden = forbidden or false, protected = protected or false, sets = 0 }
    function b:IsForbidden() return self.forbidden end
    function b:IsProtected() return self.protected end
    function b:GetAlpha() return self.alpha end
    function b:SetAlpha(value) self.alpha = value; self.sets = self.sets + 1 end
    return b
end
local a, b, forbidden, protected = bubble(0.7), bubble(0.45), bubble(1, true), bubble(1, false, true)
local active = { a, forbidden, protected }
C_ChatBubbles = { GetAllChatBubbles = function(includeForbidden)
    assert(includeForbidden == false, "forbidden bubbles must be excluded")
    return active
end }
bubbles:UpdateVisuals()
assert(a.alpha == 0 and forbidden.alpha == 1 and protected.alpha == 0, "hide usable frames including protected alpha")
active = { a, b }
bubbles:UpdateVisuals()
assert(a.alpha == 0 and b.alpha == 0, "hide newly pooled frame")
assert(protected.alpha == 1, "restore protected bubble after pool removal")
a.alpha = 0.8
bubbles:UpdateVisuals()
assert(a.alpha == 0 and bubbles.visualAlphas[a] == 0.7, "re-hide a frame reset while still pooled")
active = { b }
bubbles:UpdateVisuals()
assert(a.alpha == 0.7 and b.alpha == 0, "restore disappeared pooled frame")
a.alpha = 0.8 -- A reused pooled frame now has a new original alpha.
active = { a, b }
bubbles:UpdateVisuals()
assert(a.alpha == 0 and bubbles.visualAlphas[a] == 0.8, "capture alpha again after pool reuse")

-- Turning the feature off restores every tracked bubble and original CVar.
BFAKeyAlerts.db.hideChatBubblesInKey = false
bubbles:Refresh()
assert(values.chatBubbles == "1" and values.chatBubblesParty == "0", "restore CVars when disabled")
assert(a.alpha == 0.8 and b.alpha == 0.45 and next(bubbles.visualAlphas) == nil, "restore bubble alphas")
assert(BFAKeyAlerts.db.chatBubblesBeforeKey == nil)

-- Leaving restores both CVars and alpha, even when still in an instance such as a raid.
BFAKeyAlerts.db.hideChatBubblesInKey = true
bubbles:Refresh()
kind = 'raid'; frame.OnEvent(frame, 'PLAYER_ENTERING_WORLD')
assert(values.chatBubbles == '1' and values.chatBubblesParty == '0' and a.alpha == 0.8)
assert(not bubbles.suppressionActive, 'raids remain outside dungeon scope')
kind = 'party'; frame.OnEvent(frame, 'PLAYER_ENTERING_WORLD')
assert(bubbles.suppressionActive)
inside, kind = false, 'none'; frame.OnEvent(frame, 'PLAYER_ENTERING_WORLD')
assert(values.chatBubbles == '1' and not bubbles.suppressionActive)

-- A reload in a dungeon must not capture the applied zero as the original value.
inside, kind = true, 'party'
C_ChatBubbles = nil
frame.OnEvent(frame, 'PLAYER_ENTERING_WORLD')
assert(values.chatBubbles == '0')
dofile('BFAKeyAlerts/ChatBubbles.lua')
bubbles, update = BFAKeyAlerts.ChatBubbles, frame.OnUpdate
frame.OnEvent(frame, 'PLAYER_ENTERING_WORLD')
assert(BFAKeyAlerts.db.chatBubblesBeforeKey.chatBubbles == '1', 'reload preserves original CVar')
frame.OnEvent(frame, 'PLAYER_LOGOUT'); update(frame, 1)
assert(values.chatBubbles == '1' and values.chatBubblesParty == '0' and not bubbles.suppressionActive)
assert(next(bubbles.visualAlphas) == nil, 'logout restores without poll resuppression')

-- The global addon switch restores settings too.
frame.OnEvent(frame, 'PLAYER_ENTERING_WORLD')
BFAKeyAlerts.db.enabled = false; bubbles:Refresh()
assert(values.chatBubbles == '1' and not bubbles.suppressionActive)
print('chat_bubbles_visibility: every dungeon difficulty, CVar reassertion, alpha pool, exit, raid, reload and logout passed')
