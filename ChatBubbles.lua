local BKA = BFAKeyAlerts
local ChatBubbles = { visualAlphas = {} }
BKA.ChatBubbles = ChatBubbles

function ChatBubbles:IsSuppressionEnabled()
    if not BKA.db or BKA.db.enabled == false or BKA.db.hideChatBubblesInKey == false or not IsInInstance then
        return false
    end
    local inside, kind = IsInInstance()
    return inside and kind == "party" or false
end

function ChatBubbles:RestoreVisuals()
    for bubble, alpha in pairs(self.visualAlphas) do
        local ok, forbidden = pcall(bubble.IsForbidden, bubble)
        if ok and not forbidden then
            pcall(bubble.SetAlpha, bubble, alpha)
        end
        self.visualAlphas[bubble] = nil
    end
end

local function isUsableBubble(bubble)
    if not bubble or type(bubble.IsForbidden) ~= "function"
        or type(bubble.GetAlpha) ~= "function" or type(bubble.SetAlpha) ~= "function" then
        return false
    end
    local ok, forbidden = pcall(bubble.IsForbidden, bubble)
    if not ok or forbidden then return false end
    return true
end

function ChatBubbles:UpdateVisuals()
    local api = C_ChatBubbles
    if not api or type(api.GetAllChatBubbles) ~= "function" then
        self:RestoreVisuals()
        return
    end
    local ok, bubbles = pcall(api.GetAllChatBubbles, false)
    if not ok or type(bubbles) ~= "table" then
        self:RestoreVisuals()
        return
    end

    local current = {}
    for _, bubble in pairs(bubbles) do
        if isUsableBubble(bubble) then
            current[bubble] = true
            if self.visualAlphas[bubble] == nil then
                local alphaOK, alpha = pcall(bubble.GetAlpha, bubble)
                if alphaOK and type(alpha) == "number" then
                    self.visualAlphas[bubble] = alpha
                    pcall(bubble.SetAlpha, bubble, 0)
                end
            else
                -- Keep suppression in place if the client or another addon resets a pooled frame.
                local alphaOK, alpha = pcall(bubble.GetAlpha, bubble)
                if alphaOK and alpha ~= 0 then pcall(bubble.SetAlpha, bubble, 0) end
            end
        end
    end

    -- Restore pooled frames that disappeared from the API's active list.
    for bubble, alpha in pairs(self.visualAlphas) do
        if not current[bubble] then
            local safe = isUsableBubble(bubble)
            if safe then pcall(bubble.SetAlpha, bubble, alpha) end
            self.visualAlphas[bubble] = nil
        end
    end
end

function ChatBubbles:Refresh(forceRestore)
    local hide = not forceRestore and self:IsSuppressionEnabled()
    local db = BKA.db
    if db and GetCVar and SetCVar then
        local saved = db.chatBubblesBeforeKey
        if hide then
            if type(saved) ~= "table" then
                saved = {}
                db.chatBubblesBeforeKey = saved
            end
            -- Keep the original values across reloads while reasserting suppression
            -- if another addon changes either CVar during the run.
            for _, name in ipairs({ "chatBubbles", "chatBubblesParty" }) do
                local current = GetCVar(name)
                if current ~= nil then
                    if saved[name] == nil then saved[name] = current end
                    if current ~= "0" then SetCVar(name, "0") end
                end
            end
        elseif type(saved) == "table" then
            for name, value in pairs(saved) do
                -- Preserve a value changed by the user or another addon.
                if GetCVar(name) == "0" then SetCVar(name, value) end
            end
            db.chatBubblesBeforeKey = nil
        end
    end

    self.suppressionActive = hide == true
    if self.suppressionActive then
        self:UpdateVisuals()
    else
        self:RestoreVisuals()
    end
end

function ChatBubbles:PrintStatus()
    self:Refresh()
    local inside, kind
    if IsInInstance then inside, kind = IsInInstance() end
    local difficultyID = GetInstanceInfo and select(3, GetInstanceInfo())
    local count = 0
    for _ in pairs(self.visualAlphas) do count = count + 1 end
    BKA:Print(string.format("bubbles: active=%s instance=%s/%s difficulty=%s cvars=%s/%s frames=%d",
        tostring(self.suppressionActive), tostring(inside), tostring(kind), tostring(difficultyID),
        tostring(GetCVar and GetCVar("chatBubbles")), tostring(GetCVar and GetCVar("chatBubblesParty")), count))
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("PLAYER_ENTERING_WORLD")
frame:RegisterEvent("PLAYER_LOGOUT")
frame:SetScript("OnEvent", function(_, event)
    ChatBubbles.loggingOut = event == "PLAYER_LOGOUT"
    ChatBubbles:Refresh(ChatBubbles.loggingOut)
end)

local stateElapsed, visualElapsed = 0, 0
frame:SetScript("OnUpdate", function(_, elapsed)
    if ChatBubbles.loggingOut then return end
    stateElapsed = stateElapsed + elapsed
    visualElapsed = visualElapsed + elapsed
    local stateInterval = ChatBubbles.suppressionActive and 0.5 or 1
    if stateElapsed >= stateInterval then
        stateElapsed = 0
        ChatBubbles:Refresh()
    elseif ChatBubbles.suppressionActive and visualElapsed >= 0.1 then
        visualElapsed = 0
        ChatBubbles:UpdateVisuals()
    end
    if visualElapsed >= 0.1 then visualElapsed = 0 end
end)
