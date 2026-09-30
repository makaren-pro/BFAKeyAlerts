-- Protocol, election, marker allocation, and pull lifecycle checks. Run with Lua 5.1.
LE_PARTY_CATEGORY_INSTANCE = 1
local now = 0
local inGroup = true
local raid = false
local units = { player = true, party1 = true, nameplate1 = true, nameplate2 = true, nameplate3 = true, nameplate4 = true }
local guids = { player = "Player-A", party1 = "Player-B", nameplate1 = "Creature-1",
    nameplate2 = "Creature-2", nameplate3 = "Creature-3", nameplate4 = "Creature-4" }
local names = { player = "Alpha-Realm", party1 = "Bravo-Realm" }
local connected = { player = true, party1 = true }
local combat = { player = false, nameplate1 = true, nameplate2 = true, nameplate3 = true, nameplate4 = true }
local leader = { player = true, party1 = false }
local marks, sentMessages = {}, {}
local difficultyID = 8
wipe = function(value) for key in pairs(value) do value[key] = nil end end
GetTime = function() return now end
GetRealmName = function() return "Realm" end
UnitExists = function(unit) return units[unit] == true end
UnitGUID = function(unit) return guids[unit] end
UnitFullName = function(unit)
    local fullname = names[unit]
    if not fullname then return nil end
    local name, realm = fullname:match("^([^-]+)%-?(.*)$")
    return name, realm
end
UnitIsConnected = function(unit) return connected[unit] end
UnitIsGroupLeader = function(unit) return leader[unit] == true end
UnitIsGroupAssistant = function() return false end
UnitIsDeadOrGhost = function() return false end
UnitAffectingCombat = function(unit) return combat[unit] == true end
UnitCanAttack = function(_, unit) return string.find(unit or "", "^nameplate") ~= nil end
GetInstanceInfo = function() return "Test Dungeon", "party", difficultyID end
IsInGroup = function() return inGroup end
IsInRaid = function() return raid end
GetNumGroupMembers = function() return raid and 2 or 2 end
SetRaidTarget = function(unit, marker) marks[unit] = marker ~= 0 and marker or nil end
GetRaidTargetIndex = function(unit) return marks[unit] end
C_ChatInfo = {
    RegisterAddonMessagePrefix = function() return true end,
    SendAddonMessage = function(prefix, message, channel)
        sentMessages[#sentMessages + 1] = { prefix = prefix, message = message, channel = channel }
    end,
}
CreateFrame = function()
    local frame = {}
    function frame:RegisterEvent() end
    function frame:SetScript(name, fn) self[name] = fn end
    return frame
end

BFAKeyAlerts = {
    active = true,
    activeDungeon = { challengeMapID = 244, abilities = {
        { module = "Trash", sources = { 7 }, severity = "HIGH", castControl = "KICK" },
        { module = "Trash", sources = { 8 }, severity = "CRITICAL", castControl = "NONE" },
        { module = "MDT", sources = { 9 }, severity = "MEDIUM", castControl = "STOP" },
        { module = "Trash", sources = { 10 }, severity = "CRITICAL", castControl = "KICK" },
        { module = "Trash", sources = { 11 }, severity = "HIGH", castControl = "KICK" },
    } },
    db = { autoMarkers = { enabled = true, onlyInKey = true, priority = 1,
        preserveManual = true, sessionCounter = 4 } },
    severityRank = { LOW = 1, MEDIUM = 2, HIGH = 3, CRITICAL = 4 },
    CastLearning = { allowed = { [7] = true, [8] = true, [9] = true, [10] = false, [11] = true } },
    GetInterruptPolicy = function(_, npcID)
        if npcID == 11 then return { policy = "IGNORE", suppressAlert = true } end
        return nil
    end,
    Version = { GetCurrent = function() return "1.7.2" end },
    Targets = { guidToUnit = {
        ["Creature-1"] = "nameplate1", ["Creature-2"] = "nameplate2", ["Creature-3"] = "nameplate3",
    } },
    GetNPCID = function(_, guid)
        if guid == "Creature-1" then return 7 end
        if guid == "Creature-2" then return 8 end
        if guid == "Creature-3" then return 9 end
        if guid == "Creature-4" then return 9 end
    end,
}
dofile("AutoMarkers.lua")
local markers = BFAKeyAlerts.AutoMarkers

local function equal(actual, expected, label)
    assert(actual == expected, label .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual))
end

-- Election is deterministic under shuffled roster order and drops disabled or disconnected peers.
local roster = {
    { guid = "Z", connected = true, assistant = true },
    { guid = "B", connected = true, leader = true },
    { guid = "A", connected = true },
}
equal(markers.ElectCoordinator(roster, { Z = true, B = true, A = true }), "B", "enabled leader elected")
equal(markers.ElectCoordinator({ roster[3], roster[1], roster[2] }, { Z = true, A = true }), "Z", "assistant elected")
equal(markers.ElectCoordinator(roster, { A = true, B = false, Z = false }), "A", "disabled peers excluded")
roster[2].connected = false
equal(markers.ElectCoordinator(roster, { B = true, Z = true }), "Z", "disconnected leader excluded")

-- Severity/control priority and every visible/existing marker reserve their symbol.
local plan = markers.PlanAssignments({
    { guid = "g4", npcID = 4, severity = 4, control = 0 },
    { guid = "g2", npcID = 2, severity = 3, control = 2 },
    { guid = "g3", npcID = 3, severity = 3, control = 1 },
}, { [1] = true, [4] = true }, { old = 2 }, {}, 1, 2)
equal(plan[1].guid, "g4", "severity-first plan")
equal(plan[1].marker, 3, "occupied markers skipped")
local controlPlan = markers.PlanAssignments({
    { guid = "g4", npcID = 4, severity = 4, control = 0 },
    { guid = "g2", npcID = 2, severity = 3, control = 2 },
}, {}, {}, {}, 2, 1)
equal(controlPlan[1].guid, "g2", "control-first plan")

-- Startup fails closed while roster/decode/peer agreement settle.
markers:Initialize()
markers:Update(0)
equal(markers.byNPC[10], nil, "trash module entry for boss source excluded")
equal(markers.byNPC[11], nil, "ignored trash ability excluded")
local initial = markers:GetCoordinationState()
equal(initial.ready, false, "roster debounce blocks writes")
equal(initial.blocked, "roster-debounce", "roster block reason")

local function protocolMessage(kind, guid, epoch, enabled, digest, signature, bits, extra)
    return table.concat({ kind, 1, "1.7.2", guid, epoch, enabled and 1 or 0,
        signature or markers.rosterSignature, bits or "3", digest or "-", extra or "" }, "|")
end

-- Trusted full-realm sender identity and matching GUID are required; partial or stale ACKs block.
local hello = protocolMessage("HELLO", "Player-B", 8, true, "-", markers.rosterSignature, "3")
equal(markers:OnMessage("BKA_MARK", hello, "PARTY", "intruder-Realm", 0.2), false, "unknown sender rejected")
local spoofed = protocolMessage("HELLO", "Player-C", 8, true, "-", markers.rosterSignature, "3")
equal(markers:OnMessage("BKA_MARK", spoofed, "PARTY", "Bravo-Realm", 0.2), false, "spoofed payload GUID rejected")
equal(markers:OnMessage("BKA_MARK", hello, "PARTY", "Bravo-Realm", 0.3), true, "roster peer hello accepted")
markers:Update(3.1)
local digest = markers:GetCoordinationState().digest
local partial = protocolMessage("ACK", "Player-B", 8, true, "wrong-digest", markers.rosterSignature, "3")
markers:OnMessage("BKA_MARK", partial, "PARTY", "Bravo-Realm", 3.2)
markers:Update(3.3)
equal(markers:GetCoordinationState().ready, false, "partial agreement blocks writes")
local ack = protocolMessage("ACK", "Player-B", 8, true, digest, markers.rosterSignature, "3")
markers:OnMessage("BKA_MARK", ack, "PARTY", "Bravo-Realm", 3.4)
markers:Update(3.5)
equal(markers:GetCoordinationState().ready, false, "agreement stability debounce")
marks.nameplate1 = 8
marks.player = 3
marks.party1 = 4
markers:Update(4.6)
equal(markers:GetCoordinationState().ready, true, "matching peer ACK establishes coordinator")

-- Stable deterministic assignment, but existing/manual marks are preserved and latched.
markers.compiledDungeon = 244
markers.byNPC = { [7] = { severity = 3, control = 2 }, [8] = { severity = 4, control = 0 }, [9] = { severity = 2, control = 1 } }
markers:_mark(markers:_eligibleMobs(), 4.7)
equal(marks.nameplate1, 8, "manual marker preserved")
equal(markers.protected["Creature-1"], true, "manual marker latched")
markers:_mark(markers:_eligibleMobs(), 4.8)
equal(marks.nameplate1, 8, "manual marker not reacquired")
equal(marks.nameplate2, 1, "highest severity mob gets first free symbol")
equal(marks.nameplate3, 2, "next mob gets a unique symbol")
equal(markers.claims["Creature-2"] ~= markers.claims["Creature-3"], true, "markers remain unique")
leader.player = false
equal(markers:_canMark(), true, "party member can set raid targets")
raid = true
equal(markers:_canMark(), false, "raid member needs leader or assistant permission")
raid, leader.player = false, true

-- A manual edit after an addon assignment also latches the mob, even if preserveManual is false.
marks.nameplate2 = 7
BFAKeyAlerts.db.autoMarkers.preserveManual = false
markers:_mark(markers:_eligibleMobs(), 5)
equal(markers.protected["Creature-2"], true, "later external edit protected")
equal(marks.nameplate2, 7, "external mark is never overwritten")

-- With preserveManual disabled, an initial manual mark is replaced once using a free symbol.
BFAKeyAlerts.Targets.guidToUnit["Creature-4"] = "nameplate4"
marks.nameplate4 = 6
markers:_mark(markers:_eligibleMobs(), 5.2)
equal(marks.nameplate4, 1, "initial mark replaced once with free symbol")
marks.nameplate4 = 6
markers:_mark(markers:_eligibleMobs(), 5.3)
equal(markers.protected["Creature-4"], true, "subsequent external edit is latched")
equal(marks.nameplate4, 6, "later external mark is retained")

-- Old sessions cannot overwrite a newer handshake. A connected peer timeout blocks;
-- a roster disconnect removes that peer and starts a fresh election debounce.
local stale = protocolMessage("ACK", "Player-B", 7, true, digest, markers.rosterSignature, "3")
equal(markers:OnMessage("BKA_MARK", stale, "PARTY", "Bravo-Realm", 5.1), false, "old session rejected")
markers:Update(17)
equal(markers:GetCoordinationState().ready, false, "connected peer timeout fails closed")
equal(markers:GetCoordinationState().blocked, "peer-uncertain", "timeout reason")
connected.party1 = false
markers:Update(18)
equal(markers:GetCoordinationState().ready, false, "roster departure starts debounce")
equal(markers.peers["Player-B"], nil, "departed peer removed")

-- A fresh module initialization advances the persisted session counter and forgets old ACKs.
local priorEpoch = markers.epoch
markers.frame = nil
dofile("AutoMarkers.lua")
local reloaded = BFAKeyAlerts.AutoMarkers
reloaded:Initialize()
equal(reloaded.epoch > priorEpoch, true, "reload gets a new monotonic session")
equal(reloaded:GetCoordinationState().ready, false, "reload requires fresh agreement")

-- Death clears ownership and releases only a still-matching addon-owned marker.
connected.party1 = true
local release = reloaded
release.localGUID = "Player-A"
release.ownerGUID = "Player-A"
release.digest = "test"
release.claims["Creature-2"] = 1
release.autoOwned["Creature-2"] = 1
marks.nameplate2 = 1
release:OnCombatDeath("Creature-2")
equal(marks.nameplate2, 1, "death does not remove a game marker")
equal(release.claims["Creature-2"], nil, "death clears claim")

-- A death received after coordination loss still releases only local bookkeeping.
marks.nameplate2 = 6
release.autoOwned["Creature-2"] = 1
release.claims["Creature-2"] = 1
release.ready, release.ownerGUID = false, "Player-B"
release:OnCombatDeath("Creature-2")
equal(marks.nameplate2, 6, "death after ownership loss preserves external marker")
equal(release.claims["Creature-2"], nil, "lost coordinator drops dead claim")

-- An out-of-combat observer must still expire invisible claims at pull idle.
reloaded:_refreshRoster(22)
reloaded.ready, reloaded.ownerGUID, reloaded.digest = false, "Player-B", "observer-pull"
local remoteClaim = protocolMessage("CLAIM", "Player-B", 20, true, reloaded.digest,
    reloaded.rosterSignature, "3", "Creature-Unseen|3")
equal(reloaded:OnMessage("BKA_MARK", remoteClaim, "PARTY", "Bravo-Realm", 22), true, "observer accepts coordinator claim")
equal(reloaded.peerClaims["Creature-Unseen"].marker, 3, "staggered observer retains a claim before readiness")
equal(reloaded.ready, false, "claim receipt does not authorize observer writes")
equal(reloaded.pullHadCombat, true, "claim starts the observer pull lifecycle")
local savedOne, savedTwo, savedFour = marks.nameplate1, marks.nameplate2, marks.nameplate4
marks.nameplate1, marks.nameplate2, marks.nameplate4, marks.nameplate3 = 1, 2, 4, nil
for marker = 5, 8 do reloaded.claims["Creature-Reserved-" .. marker] = marker end
reloaded.ready, reloaded.ownerGUID = true, reloaded.localGUID
reloaded:_mark({ { guid = "Creature-3", unit = "nameplate3", npcID = 9, severity = 3, control = 1 } }, 22.1)
equal(marks.nameplate3, nil, "takeover preserves the only remaining symbol for the unseen peer claim")
marks.nameplate1, marks.nameplate2, marks.nameplate4 = savedOne, savedTwo, savedFour
reloaded:_pullUpdate(22, {})
reloaded:_pullUpdate(30.1, {})
equal(next(reloaded.peerClaims), nil, "idle observer releases unseen claims without a death event")

-- A newly elected owner respects externally changed markers from old peer claims.
reloaded.ready, reloaded.ownerGUID = true, reloaded.localGUID
reloaded.peerClaims["Creature-3"] = { marker = 3, owner = "Player-B" }
marks.nameplate3 = nil
reloaded:_mark({}, 30.2)
equal(reloaded.peerClaims["Creature-3"], nil, "observed marker removal releases the old peer reservation")
equal(reloaded.protected["Creature-3"], true, "observed external change remains protected")

-- onlyInKey gates normal-dungeon activation while an explicit override may opt in.
difficultyID = 9
reloaded:Update(22)
equal(reloaded:GetCoordinationState().blocked, "disabled", "normal dungeon blocked by onlyInKey")
BFAKeyAlerts.db.autoMarkers.onlyInKey = false
reloaded:Update(22.5)
equal(reloaded:GetCoordinationState().blocked ~= "disabled", true, "onlyInKey override enables coordination")

-- A group cannot elect a writer when the addon channel is unavailable.
local chatAPI = C_ChatInfo
C_ChatInfo = nil
reloaded:Update(23)
equal(reloaded:GetCoordinationState().ready, false, "missing communication blocks group writes")
equal(reloaded:GetCoordinationState().blocked, "communication-unavailable", "communication absence is explicit")
C_ChatInfo = chatAPI
local sendAPI = chatAPI.SendAddonMessage
chatAPI.SendAddonMessage = function() error("addon channel unavailable") end
reloaded:_sendHello(23.5)
reloaded.ready, reloaded.ownerGUID = true, reloaded.localGUID
equal(reloaded:_canMark(), false, "send failure stops an already elected writer")
chatAPI.SendAddonMessage = sendAPI

chatAPI.RegisterAddonMessagePrefix = function() return false end
dofile("AutoMarkers.lua")
local noPrefix = BFAKeyAlerts.AutoMarkers
noPrefix:Initialize()
noPrefix:Update(24)
equal(noPrefix:GetCoordinationState().ready, false, "failed prefix registration blocks group writes")
equal(noPrefix:GetCoordinationState().blocked, "communication-unavailable", "failed registration is explicit")
chatAPI.RegisterAddonMessagePrefix = function() return true end

-- Multi-client simulation delivers group addon messages out of order and duplicated.
difficultyID = 8
local clients, currentClient, queue, worldMarks, writes = {}, nil, {}, {}, {}
local playerRows = {
    { guid = "Player-A", name = "Alpha-Realm", leader = true },
    { guid = "Player-B", name = "Bravo-Realm", assistant = true },
    { guid = "Player-C", name = "Charlie-Realm" },
}
local function setupClient(index)
    local client = { id = playerRows[index].guid, player = playerRows[index], connected = {}, names = {},
        units = { player = true, nameplate1 = true }, unitGUIDs = { nameplate1 = "Creature-Net-1" },
        unitsByGUID = {}, nameByGUID = {}, db = { autoMarkers = { enabled = true, onlyInKey = true,
            priority = 1, preserveManual = true, sessionCounter = 0 } } }
    client.unitGUIDs.player = client.id
    local partyIndex = 0
    for otherIndex, member in ipairs(playerRows) do
        client.connected[member.guid] = true
        client.nameByGUID[member.guid] = member.name
        if otherIndex ~= index then
            partyIndex = partyIndex + 1
            local partyUnit = "party" .. partyIndex
            client.units[partyUnit] = true
            client.unitGUIDs[partyUnit] = member.guid
            client.unitsByGUID[member.guid] = partyUnit
        end
    end
    client.unitsByGUID[client.id] = "player"
    client.unitsByGUID["Creature-Net-1"] = "nameplate1"
    local bka = {
        name = "BFAKeyAlerts", active = true,
        activeDungeon = { challengeMapID = 244, abilities = {
            { id = 1, module = "Trash", sources = { 7 }, nameplate = true,
                personalOnly = false, severity = "HIGH", castControl = "KICK" },
        } },
        db = client.db, severityRank = { LOW = 1, MEDIUM = 2, HIGH = 3, CRITICAL = 4 },
        Version = { GetCurrent = function() return "1.7.2" end },
        Targets = { guidToUnit = { ["Creature-Net-1"] = "nameplate1" } },
        GetNPCID = function(_, guid) if guid == "Creature-Net-1" or guid == "Creature-Net-2" or guid == "Creature-Net-3" then return 7 end end,
        GetInterruptPolicy = function() return nil end,
    }
    client.bka = bka
    return client
end

for i = 1, 3 do clients[i] = setupClient(i) end
local function clientUnitExists(unit) return currentClient.units[unit] == true end
UnitExists = clientUnitExists
UnitGUID = function(unit) return currentClient.unitGUIDs[unit] end
UnitFullName = function(unit)
    local full = currentClient.nameByGUID[currentClient.unitGUIDs[unit]]
    if not full then return nil end
    return full:match("^([^-]+)%-?(.*)$")
end
UnitIsConnected = function(unit)
    local guid = currentClient.unitGUIDs[unit]
    return currentClient.connected[guid]
end
UnitIsGroupLeader = function(unit)
    local member
    for _, row in ipairs(playerRows) do if row.guid == currentClient.unitGUIDs[unit] then member = row end end
    return member and member.leader == true
end
UnitIsGroupAssistant = function(unit)
    local member
    for _, row in ipairs(playerRows) do if row.guid == currentClient.unitGUIDs[unit] then member = row end end
    return member and member.assistant == true
end
UnitIsDeadOrGhost = function() return false end
UnitAffectingCombat = function(unit) return string.find(unit or "", "^nameplate") ~= nil end
UnitCanAttack = function(_, unit) return string.find(unit or "", "^nameplate") ~= nil end
GetRaidTargetIndex = function(unit) return worldMarks[currentClient.unitGUIDs[unit]] end
SetRaidTarget = function(unit, marker)
    writes[#writes + 1] = currentClient.id
    worldMarks[currentClient.unitGUIDs[unit]] = marker ~= 0 and marker or nil
end
IsInGroup = function() return true end
IsInRaid = function() return false end
GetNumGroupMembers = function() return 3 end
GetInstanceInfo = function() return "Challenge", "party", difficultyID end
CreateFrame = function()
    local frame = {}
    function frame:RegisterEvent() end
    function frame:SetScript(name, fn) self[name] = fn end
    return frame
end
C_ChatInfo = {
    RegisterAddonMessagePrefix = function() return true end,
    SendAddonMessage = function(prefix, message, channel)
        queue[#queue + 1] = { sender = currentClient.id, prefix = prefix, message = message, channel = channel }
    end,
}
local function loadClient(client)
    currentClient = client
    BFAKeyAlerts = client.bka
    dofile("AutoMarkers.lua")
    client.markers = client.bka.AutoMarkers
    client.markers:Initialize()
end
for _, client in ipairs(clients) do loadClient(client) end

local function deliver(reverse)
    local batch = queue
    queue = {}
    if reverse then
        for left = 1, math.floor(#batch / 2) do
            local right = #batch - left + 1
            batch[left], batch[right] = batch[right], batch[left]
        end
    end
    for _, packet in ipairs(batch) do
        local fromName
        for _, source in ipairs(clients) do
            if source.id == packet.sender then fromName = source.nameByGUID[source.id] end
        end
        for _, receiver in ipairs(clients) do
            if receiver.id ~= packet.sender then
                currentClient = receiver
                receiver.markers:OnMessage(packet.prefix, packet.message, packet.channel, fromName, now)
                -- Duplicate delivery must be idempotent.
                receiver.markers:OnMessage(packet.prefix, packet.message, packet.channel, fromName, now)
            end
        end
    end
end
local function tickGroup(at, reverse)
    now = at
    for _, client in ipairs(clients) do
        if client.connected[client.id] then
            currentClient = client
            client.markers:Update(at)
        end
    end
    deliver(reverse)
end

for _, at in ipairs({ 0, 0.5, 1, 3.1, 3.6, 4.2 }) do tickGroup(at, at == 0.5 or at == 3.6) end
for _, client in ipairs(clients) do
    local state = client.markers:GetCoordinationState()
    equal(state.ready, true, "all clients reach shared digest agreement")
    equal(state.owner, "Player-A", "all clients agree on leader coordinator")
end
equal(worldMarks["Creature-Net-1"], 1, "one agreed coordinator marks first mob")
equal(#writes, 1, "only one client writes after consensus")
equal(writes[1], "Player-A", "leader is the sole writer")

-- Reordered old-session packets arriving after a fresh reload are rejected.
local oldEpoch = clients[1].markers.epoch
local oldPacket = { prefix = "BKA_MARK", sender = "Player-A", channel = "PARTY" }
currentClient = clients[1]
oldPacket.message = table.concat({ "ACK", 1, "1.7.2", "Player-A", oldEpoch, 1,
    clients[2].markers.rosterSignature, "7", clients[2].markers.digest }, "|")
local clientA = clients[1]
loadClient(clientA)
equal(clientA.markers.epoch > oldEpoch, true, "reloaded coordinator increments session")
tickGroup(4.7, true)
currentClient = clients[2]
equal(clients[2].markers:OnMessage(oldPacket.prefix, oldPacket.message, oldPacket.channel,
    "Alpha-Realm", 4.8), false, "delayed prior-session ACK rejected")

-- Explicitly disabling the leader re-elects the assistant after all enabled peers agree.
clientA.db.autoMarkers.enabled = false
clientA.markers:SettingsChanged()
tickGroup(5.2, true)
tickGroup(5.7, true)
tickGroup(6.2, true)
tickGroup(6.7, true)
tickGroup(7.2, true)
for _, client in ipairs({ clients[2], clients[3] }) do
    equal(client.markers:GetCoordinationState().owner, "Player-B", "assistant elected after leader disable")
    equal(client.markers:GetCoordinationState().ready, true, "enabled peers agree after disable")
end
clients[2].unitGUIDs.nameplate2, clients[3].unitGUIDs.nameplate2, clientA.unitGUIDs.nameplate2 =
    "Creature-Net-2", "Creature-Net-2", "Creature-Net-2"
for _, client in ipairs(clients) do
    client.units.nameplate2 = true
    client.bka.Targets.guidToUnit["Creature-Net-2"] = "nameplate2"
end
tickGroup(7.7, true)
equal(worldMarks["Creature-Net-2"], 2, "new assistant coordinator marks next mob")
equal(writes[#writes], "Player-B", "assistant is the sole post-disable writer")

-- A connected-to-disconnected roster transition removes the peer and starts a new election debounce.
for _, client in ipairs(clients) do client.connected["Player-B"] = false end
tickGroup(8.2, true)
equal(clients[3].markers:GetCoordinationState().ready, false, "disconnect pauses writes during roster debounce")
equal(clients[3].markers.peers["Player-B"], nil, "disconnected peer discarded")
for _, at in ipairs({ 11.3, 11.8, 12.3, 12.8 }) do tickGroup(at, at == 11.8) end
equal(clients[3].markers:GetCoordinationState().owner, "Player-C", "remaining enabled peer elected")
equal(clients[3].markers:GetCoordinationState().ready, true, "remaining peer reaches consensus")
clients[3].unitGUIDs.nameplate3 = "Creature-Net-3"
clients[3].units.nameplate3 = true
clients[3].bka.Targets.guidToUnit["Creature-Net-3"] = "nameplate3"
currentClient = clients[3]
tickGroup(13.3, true)
equal(worldMarks["Creature-Net-3"], 3, "remaining coordinator continues with a free marker")
equal(writes[#writes], "Player-C", "disconnected leader does not write")

print("auto_markers: PASS")
