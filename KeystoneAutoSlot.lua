local BKA = BFAKeyAlerts
local AutoSlot = {}
BKA.KeystoneAutoSlot = AutoSlot

local function hasSlottedKey()
    if not C_ChallengeMode then return true end
    if C_ChallengeMode.HasSlottedKeystone then
        return C_ChallengeMode.HasSlottedKeystone()
    end
    if C_ChallengeMode.GetSlottedKeystoneInfo then
        return C_ChallengeMode.GetSlottedKeystoneInfo() ~= nil
    end
    return true -- No reliable state check: do not take the cursor.
end

local function findKey()
    if not (GetContainerNumSlots and GetContainerItemID and GetContainerItemLink) then return end
    for bag = 0, 4 do
        for slot = 1, GetContainerNumSlots(bag) do
            local itemID = GetContainerItemID(bag, slot)
            if itemID then
                local link = GetContainerItemLink(bag, slot)
                if (link and string.find(link, "keystone:", 1, true)) or itemID == 158923 then
                    return bag, slot
                end
            end
        end
    end
end

function AutoSlot:TrySlot(frame)
    if not frame or not frame:IsShown() or frame._bkaAutoSlotAttempted then return end
    frame._bkaAutoSlotAttempted = true
    if not BKA.db or BKA.db.enabled == false or BKA.db.autoInsertKeystone == false
        or InCombatLockdown() or CursorHasItem() or hasSlottedKey()
        or not (C_ChallengeMode and C_ChallengeMode.SlotKeystone and PickupContainerItem) then return end

    local bag, slot = findKey()
    if not bag then return end
    local picked = pcall(PickupContainerItem, bag, slot)
    if not picked then
        if CursorHasItem() and ClearCursor then ClearCursor() end
        return
    end
    if not CursorHasItem() then return end
    local ok = pcall(C_ChallengeMode.SlotKeystone)
    if not ok or CursorHasItem() then
        -- The source bag slot is the safest place to return a failed pickup.
        pcall(PickupContainerItem, bag, slot)
        if CursorHasItem() and ClearCursor then ClearCursor() end
    end
end

function AutoSlot:HookFrame()
    local frame = _G.ChallengesKeystoneFrame
    if not frame or self.hooked then return end
    self.hooked = true
    frame:HookScript("OnHide", function(self) self._bkaAutoSlotAttempted = nil end)
    frame:HookScript("OnShow", function(self)
        -- Blizzard's OnShow may still be populating the receptacle.
        C_Timer.After(0, function() AutoSlot:TrySlot(self) end)
    end)
    if frame:IsShown() then C_Timer.After(0, function() self:TrySlot(frame) end) end
end

function AutoSlot:Initialize()
    if self.initialized then return end
    self.initialized = true
    self:HookFrame()
    local events = CreateFrame("Frame")
    events:RegisterEvent("ADDON_LOADED")
    events:SetScript("OnEvent", function(_, _, name)
        if name == "Blizzard_ChallengesUI" then AutoSlot:HookFrame() end
    end)
    self.events = events
end
