local BKA = BFAKeyAlerts
local UI = { predictions = {}, selections = {} }
BKA.CastPredictionUI = UI

local function settings()
    return BKA.db and BKA.db.castLearning or {}
end

local function isAllowed(prediction)
    local db = settings()
    if db.enabled == false or db.predictions == false then return false end
    if (tonumber(prediction.samples) or 0) < (tonumber(db.minimumSamples) or 1) then return false end
    if (tonumber(prediction.confidence) or 0) < (tonumber(db.minimumConfidence) or 0) then return false end
    return true
end

function UI:Show(unit, prediction, ability)
    if not unit or type(prediction) ~= "table" then return false end
    local guid = UnitGUID(unit)
    local sourceGUID = prediction.sourceGUID or prediction.guid or guid
    if not guid or guid ~= sourceGUID then return false end
    if not isAllowed(prediction) then self:Hide(unit); return false end
    local current = self.predictions[sourceGUID]
    local overlay = BKA.Nameplates and BKA.Nameplates.overlays[unit]
    if current and current.unit == unit and current.prediction == prediction and
        overlay and overlay.predictionState and overlay.predictionState.predictionData == prediction then
        return true
    end
    self.predictions[sourceGUID] = { unit = unit, guid = sourceGUID, prediction = prediction, ability = ability }
    if BKA.Nameplates then BKA.Nameplates:ShowPrediction(unit, prediction, ability) end
    return true
end

function UI:Hide(unit, guid)
    local currentGUID = unit and UnitGUID(unit)
    guid = guid or currentGUID
    if guid then self.predictions[guid] = nil end
    if BKA.Nameplates then BKA.Nameplates:HidePrediction(unit, guid) end
end

function UI:Refresh(now)
    now = tonumber(now) or GetTime()
    for guid, entry in pairs(self.predictions) do
        local unit = entry.unit
        local prediction = entry.prediction
        if not unit or UnitGUID(unit) ~= guid then
            self:Hide(unit, guid)
        elseif not isAllowed(prediction) or (tonumber(prediction.expectedTime) or 0) + (tonumber(prediction.lateWindow) or 0) < now then
            self:Hide(unit, guid)
        end
    end
end

function UI:Clear()
    for guid, entry in pairs(self.predictions) do
        if BKA.Nameplates then BKA.Nameplates:HidePrediction(entry.unit, guid) end
        self.predictions[guid] = nil
    end
end

function UI:OnAdded(unit)
    local guid = UnitGUID(unit)
    local entry = guid and self.predictions[guid]
    if entry then
        entry.unit = unit
        if BKA.Nameplates then BKA.Nameplates:ShowPrediction(unit, entry.prediction, entry.ability) end
    end
end

function UI:OnRemoved(unit)
    local guid = UnitGUID(unit)
    if guid then self:Hide(unit, guid) end
end

local function listDungeonIDs()
    local ids, seen = {}, {}
    local learningDB = BKA.db and BKA.db.castLearning
    for dungeonID in pairs(learningDB and learningDB.dungeons or {}) do
        local id = tonumber(dungeonID) or dungeonID
        if not seen[id] then ids[#ids + 1] = id; seen[id] = true end
    end
    for dungeonID in pairs(BKA.CastBaseline or {}) do
        local id = tonumber(dungeonID) or dungeonID
        if not seen[id] then ids[#ids + 1] = id; seen[id] = true end
    end
    table.sort(ids, function(a, b) return tostring(a) < tostring(b) end)
    return ids
end

local function dungeonName(dungeonID)
    for _, dungeon in ipairs(BKA.dungeons or {}) do
        if dungeon.challengeMapID == dungeonID or dungeon.instanceMapID == dungeonID then return dungeon.name or dungeon.key end
    end
    return tostring(dungeonID)
end

local function modelNPCs(dungeonID)
    local dungeons = BKA.db and BKA.db.castLearning and BKA.db.castLearning.dungeons
    local dungeon = dungeons and (dungeons[dungeonID] or dungeons[tostring(dungeonID)])
    local npcs, names, seen = {}, {}, {}
    for npcID in pairs(dungeon and dungeon.npcs or {}) do
        local id = tonumber(npcID) or npcID
        if not seen[id] then npcs[#npcs + 1] = id; seen[id] = true end
    end
    local baseline = BKA.CastBaseline and BKA.CastBaseline[dungeonID]
    for npcID in pairs(baseline and baseline.npcs or {}) do
        local id = tonumber(npcID) or npcID
        if not seen[id] then npcs[#npcs + 1] = id; seen[id] = true end
    end
    table.sort(npcs, function(a, b) return tonumber(a) < tonumber(b) end)
    local def
    for _, dungeon in ipairs(BKA.dungeons or {}) do
        if dungeon.challengeMapID == dungeonID then def = dungeon; break end
    end
    for _, npcID in ipairs(npcs) do
        names[npcID] = def and def.npcNames and def.npcNames[npcID] or tostring(npcID)
    end
    return npcs, names
end

local function modelSpells(dungeonID, npcID)
    local model = BKA.CastPredictor and BKA.CastPredictor:GetModel(dungeonID, npcID)
    local spells = {}
    for spellID in pairs(model and model.spells or model and model.casts or {}) do
        spells[#spells + 1] = tonumber(spellID) or spellID
    end
    table.sort(spells, function(a, b) return tonumber(a) < tonumber(b) end)
    return spells
end

local function spellName(spellID)
    local name = GetSpellInfo and GetSpellInfo(spellID)
    return name and (name .. "  (" .. tostring(spellID) .. ")") or tostring(spellID)
end

local function summaryText(value)
    if type(value) == "string" then return value end
    if type(value) ~= "table" then return BKA:L("CP_NO_DATA") end
    local lines = {}
    local function add(label, item)
        if item ~= nil then lines[#lines + 1] = label .. ": " .. tostring(item) end
    end
    add(BKA:L("CP_STAT_CASTS"), value.casts)
    add(BKA:L("CP_STAT_ANCHOR"), BKA:L("CP_ANCHOR_" .. tostring(value.anchor or "START")))
    add(BKA:L("CP_ANCHOR_CERTAINTY"), string.format("%.0f%%", (value.anchorCertainty or 0) * 100))
    add(BKA:L("CP_STAT_CONFIDENCE"), string.format("%.0f%%", (value.predictionConfidence or 0) * 100))
    add(BKA:L("CP_STAT_STDDEV"), string.format("%.2f", value.stddev or 0))
    for _, key in ipairs({"opening", "interval"}) do
        local stat = value[key]
        if type(stat) == "table" then
            local label = BKA:L(key == "opening" and "CP_STAT_OPENING" or "CP_STAT_INTERVAL")
            add(label .. " " .. BKA:L("CP_STAT_SAMPLES"), stat.n)
            add(label .. " " .. BKA:L("CP_STAT_MEAN"), stat.mean)
        end
    end
    local metrics = value.metrics
    if type(metrics) == "table" then
        add(BKA:L("CP_STAT_OUTCOMES"), metrics.count)
        add(BKA:L("CP_STAT_HITS"), metrics.hit)
        add(BKA:L("CP_STAT_MISSES"), metrics.miss)
        add(BKA:L("CP_STAT_MAE"), metrics.mae)
    end
    local transitions = value.transitions
    if type(transitions) == "table" then
        for index, edge in ipairs(transitions) do
            if index > 5 then break end
            add(BKA:L("CP_STAT_TRANSITION") .. " " .. spellName(edge.spellID),
                string.format("%.0f%%  (%d)", (edge.probability or 0) * 100, edge.count or 0))
        end
    end
    for index, edge in ipairs(value.secondTransitions or {}) do
        if index > 3 then break end
        add(BKA:L("CP_SECOND_TRANSITION") .. " " .. spellName(edge.previousSpellID) .. " → " .. spellName(edge.spellID),
            string.format("%.0f%%  (%d)", (edge.probability or 0) * 100, edge.count or 0))
    end
    if #lines == 0 then
        for key, item in pairs(value) do lines[#lines + 1] = tostring(key) .. ": " .. tostring(item) end
        table.sort(lines)
    end
    return table.concat(lines, "\n")
end

function UI:OpenInspector()
    if not self.inspector then
        local frame = CreateFrame("Frame", "BFAKeyAlertsCastPredictionInspector", UIParent)
        frame:SetSize(510, 370); frame:SetPoint("CENTER"); frame:SetFrameStrata("DIALOG")
        frame:SetMovable(true); frame:EnableMouse(true); frame:SetClampedToScreen(true)
        frame:SetBackdrop({bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1})
        frame:SetBackdropColor(0.025, 0.035, 0.055, 0.98); frame:SetBackdropBorderColor(0.40, 0.88, 0.74, 1)
        local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        title:SetPoint("TOPLEFT", 16, -14); title:SetText(BKA:L("CP_INSPECTOR"))
        local drag = CreateFrame("Frame", nil, frame); drag:SetPoint("TOPLEFT"); drag:SetPoint("TOPRIGHT", -45, 0); drag:SetHeight(45)
        drag:EnableMouse(true); drag:RegisterForDrag("LeftButton"); drag:SetScript("OnDragStart", function() frame:StartMoving() end); drag:SetScript("OnDragStop", function() frame:StopMovingOrSizing() end)
        local close = CreateFrame("Button", nil, frame, "UIPanelCloseButton"); close:SetPoint("TOPRIGHT", -3, -3)
        frame.pickers = {}
        local function picker(key, x, y, width)
            local b = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
            b:SetPoint("TOPLEFT", x, y); b:SetSize(width, 27)
            b:SetScript("OnClick", function()
                local list = UI:GetInspectorChoices(key)
                if #list == 0 then return end
                local current = UI.selections[key]
                local index = 0
                for i, item in ipairs(list) do if item == current then index = i; break end end
                UI.selections[key] = list[index % #list + 1]
                UI:RefreshInspector()
            end)
            frame.pickers[key] = b
        end
        picker("dungeon", 16, -52, 150); picker("npc", 178, -52, 150); picker("spell", 340, -52, 150)
        frame.output = CreateFrame("EditBox", nil, frame)
        frame.output:SetMultiLine(true); frame.output:SetAutoFocus(false); frame.output:EnableMouse(true)
        frame.output:SetFontObject(GameFontHighlightSmall); frame.output:SetWidth(470); frame.output:SetHeight(225)
        frame.output:SetPoint("TOPLEFT", 20, -95); frame.output:SetTextInsets(4, 4, 4, 4)
        frame.output:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
        frame.hint = frame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
        frame.hint:SetPoint("BOTTOMLEFT", 20, 35); frame.hint:SetText(BKA:L("CP_PICK_HINT"))
        BKA.Options:AddSupportLink(frame, "BOTTOMLEFT", "BOTTOMLEFT", 20, 10, 470)
        self.inspector = frame
        tinsert(UISpecialFrames, frame:GetName())
    end
    self:RefreshInspector()
    self.inspector:Show()
end

function UI:GetInspectorChoices(key)
    local dungeonID = self.selections.dungeon
    local npcID = self.selections.npc
    if key == "dungeon" then return listDungeonIDs() end
    if key == "npc" then return dungeonID and modelNPCs(dungeonID) or {} end
    if key == "spell" then return dungeonID and npcID and modelSpells(dungeonID, npcID) or {} end
    return {}
end

function UI:RefreshInspector()
    local frame = self.inspector
    if not frame then return end
    local dungeons = listDungeonIDs()
    local haveDungeon = false
    for _, id in ipairs(dungeons) do if id == self.selections.dungeon then haveDungeon = true; break end end
    if not haveDungeon then self.selections.dungeon = dungeons[1] end
    local npcs = modelNPCs(self.selections.dungeon)
    local haveNPC = false; for _, id in ipairs(npcs) do if id == self.selections.npc then haveNPC = true end end
    if not haveNPC then self.selections.npc = npcs[1] end
    local spells = modelSpells(self.selections.dungeon, self.selections.npc)
    local haveSpell = false; for _, id in ipairs(spells) do if id == self.selections.spell then haveSpell = true end end
    if not haveSpell then self.selections.spell = spells[1] end
    frame.pickers.dungeon:SetText(BKA:L("DUNGEON") .. ": " .. (self.selections.dungeon and dungeonName(self.selections.dungeon) or BKA:L("CP_NONE")))
    local _, names = modelNPCs(self.selections.dungeon)
    frame.pickers.npc:SetText(BKA:L("CP_NPC") .. ": " .. (self.selections.npc and (names[self.selections.npc] or tostring(self.selections.npc)) or BKA:L("CP_NONE")))
    frame.pickers.spell:SetText(BKA:L("CP_SPELL") .. ": " .. (self.selections.spell and spellName(self.selections.spell) or BKA:L("CP_NONE")))
    local stats
    if self.selections.dungeon and self.selections.npc and self.selections.spell and BKA.CastPredictor then
        stats = BKA.CastPredictor:Inspect(self.selections.dungeon, self.selections.npc, self.selections.spell)
    end
    frame.output:SetText(summaryText(stats))
end

function UI:ShowExport(text)
    if not self.exportFrame then
        local frame = CreateFrame("Frame", "BFAKeyAlertsCastLearningExport", UIParent)
        frame:SetSize(560, 400); frame:SetPoint("CENTER"); frame:SetFrameStrata("DIALOG")
        frame:SetMovable(true); frame:EnableMouse(true); frame:SetClampedToScreen(true)
        frame:SetBackdrop({bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1})
        frame:SetBackdropColor(0.025, 0.035, 0.055, 0.98); frame:SetBackdropBorderColor(0.40, 0.88, 0.74, 1)
        local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        title:SetPoint("TOPLEFT", 16, -14); title:SetText(BKA:L("CP_EXPORT"))
        local close = CreateFrame("Button", nil, frame, "UIPanelCloseButton"); close:SetPoint("TOPRIGHT", -3, -3)
        local scroll = CreateFrame("ScrollFrame", nil, frame, "UIPanelScrollFrameTemplate")
        scroll:SetPoint("TOPLEFT", 14, -43); scroll:SetPoint("BOTTOMRIGHT", -34, 40)
        BKA.Options:AddSupportLink(frame, "BOTTOMLEFT", "BOTTOMLEFT", 16, 12, 500)
        local child = CreateFrame("Frame", nil, scroll)
        child:SetWidth(500); child:SetHeight(325); scroll:SetScrollChild(child)
        local edit = CreateFrame("EditBox", nil, child)
        edit:SetMultiLine(true); edit:SetAutoFocus(false); edit:EnableMouse(true); edit:SetFontObject(GameFontHighlightSmall)
        edit:SetWidth(500); edit:SetHeight(325); edit:SetPoint("TOPLEFT", 0, 0); edit:SetTextInsets(5, 5, 5, 5)
        edit:SetScript("OnTextChanged", function(self)
            if self.resizing then return end
            local value = self:GetText() or ""
            local lines = 1
            for _ in string.gmatch(value, "\n") do lines = lines + 1 end
            lines = math.max(lines, math.ceil(string.len(value) / 76))
            local height = math.max(325, lines * 14 + 10)
            self.resizing = true
            self:SetHeight(height); child:SetHeight(height)
            self.resizing = false
        end)
        edit:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
        edit:SetScript("OnEditFocusGained", function(self) self:HighlightText() end)
        frame.edit = edit; frame.scroll = scroll; frame.child = child
        self.exportFrame = frame; tinsert(UISpecialFrames, frame:GetName())
    end
    self.exportFrame.edit:SetText(tostring(text or (BKA.CastLearning and BKA.CastLearning:Export()) or ""))
    self.exportFrame:Show(); self.exportFrame.edit:SetFocus(); self.exportFrame.edit:HighlightText()
end
