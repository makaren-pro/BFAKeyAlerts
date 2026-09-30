local BKA = BFAKeyAlerts
local AutoMarkers = {
    prefix = "BKA_MARK", protocol = 1, peers = {}, claims = {}, protected = {}, autoOwned = {},
    replacedInitial = {}, peerClaims = {}, roster = {}, byGUID = {}, bySender = {},
    gossip = {}, elapsed = 0, heartbeat = 0, rosterChangedAt = 0,
}
BKA.AutoMarkers = AutoMarkers

local MARKER_COUNT = 8
local HEARTBEAT = 4
local PEER_TIMEOUT = 12
local ROSTER_STABLE = 3
local AGREEMENT_STABLE = 1
local PULL_GRACE = 8
local CHANNEL_INSTANCE = LE_PARTY_CATEGORY_INSTANCE

local function settings()
    return BKA.db and BKA.db.autoMarkers or {}
end

local function enabledNow()
    local cfg = settings()
    if cfg.enabled ~= true or BKA.active ~= true or not BKA.activeDungeon then return false end
    if cfg.onlyInKey == false then return true end
    local challengeMapID = C_ChallengeMode and C_ChallengeMode.GetActiveChallengeMapID and
        C_ChallengeMode.GetActiveChallengeMapID()
    if challengeMapID and challengeMapID > 0 then
        return challengeMapID == BKA.activeDungeon.challengeMapID
    end
    if GetInstanceInfo then
        local _, _, difficultyID = GetInstanceInfo()
        return difficultyID == 8
    end
    return false
end

local function connected(unit)
    return not UnitIsConnected or UnitIsConnected(unit) ~= false
end

local function fullName(unit)
    local name, realm
    if UnitFullName then name, realm = UnitFullName(unit) end
    if not name and UnitName then name = UnitName(unit) end
    if not name then return nil end
    if type(name) == "string" and string.find(name, "-", 1, true) then return name end
    realm = realm and realm ~= "" and realm or (GetRealmName and GetRealmName()) or ""
    return realm ~= "" and (name .. "-" .. realm) or name
end

local function canonicalSender(sender)
    if not sender or sender == "" then return nil end
    if not string.find(sender, "-", 1, true) then
        local realm = (GetNormalizedRealmName and GetNormalizedRealmName()) or (GetRealmName and GetRealmName()) or ""
        if realm ~= "" then sender = sender .. "-" .. realm end
    end
    local name, realm = sender:match("^([^-]+)%-(.*)$")
    if name then return string.lower(name) .. "-" .. string.gsub(string.lower(realm), "%s", "") end
    return string.lower(sender)
end

local function hash(value)
    local number = 0
    for i = 1, #value do number = (number * 33 + string.byte(value, i)) % 2147483647 end
    return string.format("%08x", number)
end

local function sortedKeys(set)
    local keys = {}
    for key, value in pairs(set or {}) do if value then keys[#keys + 1] = key end end
    table.sort(keys)
    return keys
end

local function rosterSignature(roster)
    local parts = {}
    for _, member in ipairs(roster) do
        parts[#parts + 1] = table.concat({ member.guid, member.connected and "1" or "0",
            member.leader and "L" or "-", member.assistant and "A" or "-" }, ":")
    end
    return hash(table.concat(parts, ";"))
end

local function encodeBits(roster, set)
    local nibbles, nibble, bitIndex = {}, 0, 0
    for _, member in ipairs(roster) do
        if set[member.guid] then nibble = nibble + 2 ^ bitIndex end
        bitIndex = bitIndex + 1
        if bitIndex == 4 then
            nibbles[#nibbles + 1] = string.format("%x", nibble)
            nibble, bitIndex = 0, 0
        end
    end
    if bitIndex > 0 then nibbles[#nibbles + 1] = string.format("%x", nibble) end
    return table.concat(nibbles)
end

local function decodeBits(roster, encoded)
    local set, index = {}, 1
    for i = 1, #encoded do
        local value = tonumber(string.sub(encoded, i, i), 16) or 0
        for bitIndex = 0, 3 do
            local member = roster[index]
            if member and math.floor(value / (2 ^ bitIndex)) % 2 == 1 then set[member.guid] = true end
            index = index + 1
        end
    end
    return set
end

local function activeUnitRoster()
    local units = { "player" }
    if IsInRaid and IsInRaid() then
        local count = GetNumGroupMembers and GetNumGroupMembers() or 0
        for i = 1, count do units[#units + 1] = "raid" .. i end
    else
        for i = 1, 4 do
            local unit = "party" .. i
            if UnitExists and UnitExists(unit) then units[#units + 1] = unit end
        end
    end
    local roster, seen = {}, {}
    for _, unit in ipairs(units) do
        if not UnitExists or UnitExists(unit) then
            local guid = UnitGUID and UnitGUID(unit)
            if guid and not seen[guid] then
                seen[guid] = true
                roster[#roster + 1] = {
                    unit = unit, guid = guid, name = fullName(unit), connected = unit == "player" or connected(unit),
                    leader = UnitIsGroupLeader and UnitIsGroupLeader(unit) or false,
                    assistant = UnitIsGroupAssistant and UnitIsGroupAssistant(unit) or false,
                }
            end
        end
    end
    table.sort(roster, function(a, b) return a.guid < b.guid end)
    return roster
end

local function normalizeRoster(roster)
    local copy = {}
    for _, member in ipairs(roster or {}) do
        copy[#copy + 1] = { guid = member.guid, connected = member.connected ~= false,
            leader = member.leader == true, assistant = member.assistant == true,
            enabled = member.enabled == true, unit = member.unit, name = member.name }
    end
    table.sort(copy, function(a, b) return a.guid < b.guid end)
    return copy
end

function AutoMarkers.ElectCoordinator(roster, enabled)
    roster = normalizeRoster(roster)
    local leader, assistants, others = nil, {}, {}
    for _, member in ipairs(roster) do
        if member.connected and enabled[member.guid] then
            if member.leader then
                if not leader or member.guid < leader then leader = member.guid end
            elseif member.assistant then
                assistants[#assistants + 1] = member.guid
            else
                others[#others + 1] = member.guid
            end
        end
    end
    table.sort(assistants)
    table.sort(others)
    return leader or assistants[1] or others[1]
end

local function sortCandidates(sorted, priority)
    table.sort(sorted, function(a, b)
        if a.guid == b.guid then return false end
        local aControl, bControl = tonumber(a.control or 0) or 0, tonumber(b.control or 0) or 0
        local aSeverity, bSeverity = tonumber(a.severity or 0) or 0, tonumber(b.severity or 0) or 0
        if priority == 2 then
            if aControl ~= bControl then return aControl > bControl end
            if aSeverity ~= bSeverity then return aSeverity > bSeverity end
        else
            if aSeverity ~= bSeverity then return aSeverity > bSeverity end
            if aControl ~= bControl then return aControl > bControl end
        end
        if a.npcID ~= b.npcID then return a.npcID < b.npcID end
        return a.guid < b.guid
    end)
end

function AutoMarkers.PlanAssignments(candidates, occupied, claims, protected, priority, maximum)
    occupied, claims, protected = occupied or {}, claims or {}, protected or {}
    local sorted = {}
    for _, candidate in ipairs(candidates or {}) do sorted[#sorted + 1] = candidate end
    sortCandidates(sorted, priority)
    local used = {}
    for marker in pairs(occupied or {}) do used[marker] = true end
    for guid, marker in pairs(claims or {}) do if not (protected and protected[guid]) then used[marker] = true end end
    local plan = {}
    for _, candidate in ipairs(sorted) do
        if #plan >= (maximum or MARKER_COUNT) then break end
        if not protected[candidate.guid] and not claims[candidate.guid] then
            local marker
            for index = 1, MARKER_COUNT do
                if not used[index] then marker = index; break end
            end
            if marker then
                plan[#plan + 1] = { guid = candidate.guid, npcID = candidate.npcID, marker = marker }
                used[marker] = true
            end
        end
    end
    return plan
end

local function send(message)
    local channel
    if IsInGroup and CHANNEL_INSTANCE and IsInGroup(CHANNEL_INSTANCE) then channel = "INSTANCE_CHAT"
    elseif IsInRaid and IsInRaid() then channel = "RAID"
    elseif IsInGroup and IsInGroup() then channel = "PARTY" end
    if not channel then AutoMarkers.sendFailed = #AutoMarkers.roster > 1; return false end
    local fn = C_ChatInfo and C_ChatInfo.SendAddonMessage or SendAddonMessage
    if type(fn) ~= "function" then AutoMarkers.sendFailed = true; return false end
    local ok, result = pcall(fn, AutoMarkers.prefix, message, channel)
    AutoMarkers.sendFailed = not ok or result == false
    return not AutoMarkers.sendFailed
end

local function registerPrefix()
    local fn = C_ChatInfo and C_ChatInfo.RegisterAddonMessagePrefix or RegisterAddonMessagePrefix
    if type(fn) ~= "function" then return false end
    local ok, registered = pcall(fn, AutoMarkers.prefix)
    return ok and registered == true
end

local function enabledPeerSet(self, now)
    local set, uncertain, incompatible = {}, false, false
    local localGUID = UnitGUID and UnitGUID("player")
    local localEnabled = enabledNow()
    if localGUID and localEnabled then set[localGUID] = true end
    local live = {}
    for _, member in ipairs(self.roster) do live[member.guid] = member.connected end
    for guid, peer in pairs(self.peers) do
        if not live[guid] or not live[guid] then
            self.peers[guid] = nil
            self.gossip[guid] = nil
        elseif peer.enabled then
            if peer.protocol ~= self.protocol then incompatible = true end
            if now - (peer.lastSeen or 0) > PEER_TIMEOUT then uncertain = true
            else set[guid] = true end
        end
    end
    for guid, peer in pairs(self.peers) do
        if peer.enabled and now - (peer.lastSeen or 0) <= PEER_TIMEOUT then
            local gossip = peer.gossip or {}
            for peerGUID in pairs(gossip) do
                if live[peerGUID] then
                    local direct = self.peers[peerGUID]
                    if peerGUID == localGUID then
                        set[peerGUID] = true
                    elseif direct and not direct.enabled and now - (direct.lastSeen or 0) <= PEER_TIMEOUT then
                        -- A fresh explicit disable overrides older peer-list gossip.
                    elseif direct and direct.protocol ~= self.protocol and direct.enabled then
                        incompatible = true
                    elseif not direct or now - (direct.lastSeen or 0) > PEER_TIMEOUT then
                        uncertain = true
                    else
                        set[peerGUID] = true
                    end
                end
            end
        end
    end
    local keys = sortedKeys(set)
    return set, table.concat(keys, ","), uncertain, incompatible
end

local function coordinatorFor(self, peers)
    local roster = {}
    for _, member in ipairs(self.roster) do
        roster[#roster + 1] = { guid = member.guid, connected = member.connected,
            leader = member.leader, assistant = member.assistant }
    end
    return AutoMarkers.ElectCoordinator(roster, peers)
end

function AutoMarkers:GetCoordinationState()
    return { digest = self.digest, owner = self.ownerGUID, ready = self.ready == true,
        blocked = self.blocked, agreementSince = self.agreementSince, rosterSignature = self.rosterSignature }
end

function AutoMarkers:_refreshRoster(now)
    local roster = activeUnitRoster()
    local signature = rosterSignature(roster)
    if signature ~= self.rosterSignature then
        self.roster = roster
        self.rosterSignature = signature
        self.byGUID, self.bySender = {}, {}
        for _, member in ipairs(roster) do
            self.byGUID[member.guid] = member
            local senderName = canonicalSender(member.name)
            if senderName then self.bySender[senderName] = member end
        end
        self.rosterChangedAt = now
        self.agreementSince, self.agreementDigest = nil, nil
        self.acknowledgedDigest = nil
    else
        self.roster = roster
        -- Unit tokens can change while the stable GUID roster remains the same.
        self.byGUID, self.bySender = {}, {}
        for _, member in ipairs(roster) do
            self.byGUID[member.guid] = member
            local senderName = canonicalSender(member.name)
            if senderName then self.bySender[senderName] = member end
        end
    end
end

local function messageHeader(self, kind, digest)
    local bits = encodeBits(self.roster, self.localPeerSet or {})
    return table.concat({ kind, self.protocol, self.version or "0", self.localGUID or "",
        self.epoch or 0, enabledNow() and 1 or 0, self.rosterSignature or "0", bits,
        digest or self.digest or "-" }, "|")
end

function AutoMarkers:_sendHello(now)
    local msg = messageHeader(self, "HELLO", self.digest)
    send(msg)
    self.lastHello, self.lastHeartbeat = now, now
end

function AutoMarkers:_sendAck(now)
    if not self.digest then return end
    send(messageHeader(self, "ACK", self.digest))
    self.acknowledgedDigest, self.lastAck = self.digest, now
end

function AutoMarkers:_sendOwner(now)
    if self.ownerGUID ~= self.localGUID or not self.digest then return end
    send(messageHeader(self, "OWNER", self.digest) .. "|" .. self.ownerGUID)
    self.lastOwner, self.lastOwnerDigest = now, self.digest
end

local function split(message)
    local parts = {}
    for value in string.gmatch(message, "([^|]+)") do parts[#parts + 1] = value end
    return parts
end

function AutoMarkers:OnMessage(prefix, message, _, sender, now)
    if prefix ~= self.prefix or type(message) ~= "string" then return false end
    now = tonumber(now) or (GetTime and GetTime()) or 0
    local fields = split(message)
    local kind, protocol = fields[1], tonumber(fields[2])
    if kind ~= "HELLO" and kind ~= "ACK" and kind ~= "OWNER" and kind ~= "CLAIM" then return false end
    if not protocol or not fields[4] or not fields[5] then return false end
    local member = self.bySender[canonicalSender(sender)]
    local guid, epoch = fields[4], tonumber(fields[5])
    if not member or member.guid ~= guid or not member.connected or not epoch then return false end
    local peer = self.peers[guid] or { guid = guid, epoch = -1 }
    local priorEpoch, priorProtocol, priorVersion = peer.epoch, peer.protocol, peer.version
    local priorEnabled, priorRoster, priorDigest = peer.enabled, peer.rosterSignature, peer.digest
    local priorAck = peer.ackDigest
    local priorBits = peer.gossipBits
    if epoch < peer.epoch then return false end
    local version, active = fields[3], tonumber(fields[6]) == 1
    if epoch > peer.epoch then
        peer.session = epoch
        peer.ackDigest, peer.ackAt = nil, nil
        peer.gossip = {}
    end
    peer.epoch, peer.protocol, peer.version = epoch, protocol, version
    peer.enabled, peer.lastSeen = active, now
    peer.rosterSignature = fields[7]
    peer.digest = fields[9]
    if fields[7] == self.rosterSignature then
        peer.gossip = decodeBits(self.roster, fields[8] or "")
    else
        peer.gossip = {}
    end
    peer.gossipBits = fields[8] or ""
    self.peers[guid] = peer
    if kind == "ACK" then
        peer.ackDigest, peer.ackAt = fields[9], now
    elseif kind == "OWNER" then
        local advertisedOwner = fields[10]
        peer.ownerGUID, peer.ownerDigest = advertisedOwner, fields[9]
    elseif kind == "CLAIM" then
        local mobGUID, marker = fields[10], tonumber(fields[11])
        if self.ownerGUID == guid and protocol == self.protocol and active and
            fields[7] == self.rosterSignature and fields[9] == self.digest and
            mobGUID and #mobGUID <= 80 and marker and marker == math.floor(marker) and
            marker >= 0 and marker <= MARKER_COUNT then
            peer.claims = peer.claims or {}
            if marker == 0 then self.peerClaims[mobGUID] = nil
            else
                self.peerClaims[mobGUID] = { marker = marker, owner = guid, digest = fields[9], at = now }
                -- Observers may receive a claim before seeing the pull themselves.
                self.pullHadCombat, self.pullIdleSince = true, nil
            end
        end
    end
    local changed = priorEpoch ~= peer.epoch or priorProtocol ~= peer.protocol or priorVersion ~= peer.version or
        priorEnabled ~= peer.enabled or priorRoster ~= peer.rosterSignature or priorDigest ~= peer.digest or
        priorBits ~= peer.gossipBits or priorAck ~= peer.ackDigest
    if changed then
        self.agreementSince, self.agreementDigest = nil, nil
        self.acknowledgedDigest = nil
    end
    return true
end

function AutoMarkers:_nextCoordination(now)
    local peers, peerList, uncertain, incompatible = enabledPeerSet(self, now)
    self.localPeerSet = peers
    local digest = hash(self.rosterSignature .. ":" .. peerList)
    local owner = coordinatorFor(self, peers)
    local staleAck, missingHello = false, false
    for guid in pairs(peers) do
        if guid ~= self.localGUID then
            local peer = self.peers[guid]
            if not peer or now - (peer.lastSeen or 0) > PEER_TIMEOUT then
                missingHello = true
            elseif peer.protocol ~= self.protocol then
                incompatible = true
            elseif peer.rosterSignature ~= self.rosterSignature or peer.ackDigest ~= digest or
                now - (peer.ackAt or 0) > PEER_TIMEOUT then
                staleAck = true
            end
        end
    end
    if self.rosterSignature ~= self.lastReadyRoster then
        self.lastReadyRoster = self.rosterSignature
        self.agreementSince, self.agreementDigest = nil, nil
    end
    local blocked
    if not enabledNow() then blocked = "disabled"
    elseif #self.roster > 1 and (self.prefixRegistered ~= true or self.sendFailed or
        type(C_ChatInfo and C_ChatInfo.SendAddonMessage or SendAddonMessage) ~= "function") then blocked = "communication-unavailable"
    elseif uncertain or missingHello then blocked = "peer-uncertain"
    elseif incompatible then blocked = "protocol-mismatch"
    elseif staleAck then blocked = "peer-agreement"
    elseif now - (self.rosterChangedAt or now) < ROSTER_STABLE then blocked = "roster-debounce"
    end
    if blocked then
        self.ready, self.blocked = false, blocked
        self.agreementSince, self.agreementDigest = nil, nil
    else
        if self.agreementDigest ~= digest or not self.agreementSince then
            self.agreementDigest, self.agreementSince = digest, now
        end
        self.ready = now - self.agreementSince >= AGREEMENT_STABLE
        self.blocked = self.ready and nil or "agreement-debounce"
    end
    self.digest, self.ownerGUID = digest, owner
    return digest, owner, peers
end

local function compileAbilities(dungeon)
    local byNPC = {}
    for _, ability in ipairs(dungeon and dungeon.abilities or {}) do
        if (ability.module == "Trash" or ability.module == "MDT") and ability.nameplate ~= false and
            not ability.personalOnly then
            local control = 0
            if ability.castControl == "KICK" then control = 2 end
            if ability.castControl == "STOP" then control = 1 end
            local severity = BKA.severityRank and BKA.severityRank[ability.severity] or 0
            if severity >= (BKA.severityRank and BKA.severityRank.HIGH or 3) or control > 0 then
                for _, npcID in ipairs(ability.sources or {}) do
                    local allowed = not BKA.CastLearning or not BKA.CastLearning.allowed or BKA.CastLearning.allowed[npcID]
                    local policy = BKA.GetInterruptPolicy and BKA:GetInterruptPolicy(npcID, ability.id)
                    if allowed and not (policy and policy.policy == "IGNORE" and policy.suppressAlert) then
                        local record = byNPC[npcID]
                        if not record then record = { severity = 0, control = 0 }; byNPC[npcID] = record end
                        if severity > record.severity then record.severity = severity end
                        if control > record.control then record.control = control end
                    end
                end
            end
        end
    end
    return byNPC
end

function AutoMarkers:_unitsForReservation()
    local units, seen = self.unitScratch or {}, {}
    wipe(units)
    self.unitScratch = units
    local function add(unit)
        if unit and not seen[unit] then seen[unit] = true; units[#units + 1] = unit end
    end
    add("player"); add("target"); add("focus")
    for _, member in ipairs(self.roster) do add(member.unit) end
    for guid, unit in pairs(BKA.Targets and BKA.Targets.guidToUnit or {}) do
        if UnitGUID(unit) == guid then add(unit) end
    end
    for i = 1, 5 do add("boss" .. i) end
    return units
end

function AutoMarkers:_readOccupied()
    local occupied, byGUID, unitByGUID = {}, {}, {}
    for _, unit in ipairs(self:_unitsForReservation()) do
        if UnitExists and UnitExists(unit) then
            local guid = UnitGUID and UnitGUID(unit)
            local marker = GetRaidTargetIndex and GetRaidTargetIndex(unit)
            if guid then
                unitByGUID[guid] = unit
                if marker and marker >= 1 and marker <= MARKER_COUNT then
                    occupied[marker] = occupied[marker] or {}
                    occupied[marker][guid] = true
                    byGUID[guid] = marker
                end
            end
        end
    end
    return occupied, byGUID, unitByGUID
end

local function isEngaged(unit)
    if not unit or not UnitExists or not UnitExists(unit) or UnitIsDeadOrGhost and UnitIsDeadOrGhost(unit) then return false end
    if UnitCanAttack and not UnitCanAttack("player", unit) then return false end
    return UnitAffectingCombat and UnitAffectingCombat(unit) == true
end

function AutoMarkers:_eligibleMobs()
    local candidates = {}
    local targets = BKA.Targets and BKA.Targets.guidToUnit or {}
    for guid, unit in pairs(targets) do
        local npcID = BKA:GetNPCID(guid)
        local record = npcID and self.byNPC[npcID]
        if record and isEngaged(unit) and UnitGUID(unit) == guid then
            candidates[#candidates + 1] = { guid = guid, npcID = npcID,
                severity = record.severity, control = record.control, unit = unit }
        end
    end
    local priority = tonumber(settings().priority) == 2 and 2 or 1
    table.sort(candidates, function(a, b)
        if priority == 2 then
            if a.control ~= b.control then return a.control > b.control end
            if a.severity ~= b.severity then return a.severity > b.severity end
        else
            if a.severity ~= b.severity then return a.severity > b.severity end
            if a.control ~= b.control then return a.control > b.control end
        end
        if a.npcID ~= b.npcID then return a.npcID < b.npcID end
        return a.guid < b.guid
    end)
    return candidates
end

function AutoMarkers:_canMark()
    if not enabledNow() or self.ownerGUID ~= self.localGUID or not self.ready then return false end
    if #self.roster > 1 and (self.prefixRegistered ~= true or self.sendFailed or
        type(C_ChatInfo and C_ChatInfo.SendAddonMessage or SendAddonMessage) ~= "function") then return false end
    if IsInRaid and IsInRaid() then
        return UnitIsGroupLeader and UnitIsGroupLeader("player") == true or
            UnitIsGroupAssistant and UnitIsGroupAssistant("player") == true
    end
    return true
end

function AutoMarkers:_sendClaim(mobGUID, marker)
    if self.ownerGUID ~= self.localGUID or not self.ready or not self.digest then return end
    send(messageHeader(self, "CLAIM", self.digest) .. "|" .. mobGUID .. "|" .. tostring(marker))
end

function AutoMarkers:_mark(candidates, now)
    if not self:_canMark() then return end
    local cfg = settings()
    local occupied, byGUID, unitByGUID = self:_readOccupied()
    for guid, marker in pairs(self.claims) do
        if not self.protected[guid] then
            occupied[marker] = occupied[marker] or {}
            occupied[marker][guid] = true
        end
    end
    for guid, claim in pairs(self.peerClaims) do
        if unitByGUID[guid] and byGUID[guid] ~= claim.marker then
            self.peerClaims[guid] = nil
            self.protected[guid] = true
        elseif claim.marker and claim.marker > 0 then
            occupied[claim.marker] = occupied[claim.marker] or {}
            occupied[claim.marker][guid] = true
        end
    end
    for guid, marker in pairs(self.claims) do
        local current = byGUID[guid]
        if current and current ~= marker then
            self.protected[guid] = true
            self.claims[guid] = nil
            occupied[marker] = occupied[marker] or {}
            occupied[marker][guid] = nil
        elseif unitByGUID[guid] and not current then
            self.protected[guid] = true
            self.claims[guid] = nil
            occupied[marker] = occupied[marker] or {}
            occupied[marker][guid] = nil
        end
    end
    for _, candidate in ipairs(candidates) do
        local guid = candidate.guid
        if not self.protected[guid] then
            local current = byGUID[guid]
            if current and self.claims[guid] == current then
                -- Our stable claim is already visible.
            elseif current and cfg.preserveManual ~= false then
                self.protected[guid] = true
            elseif current and self.replacedInitial[guid] then
                self.protected[guid] = true
            end
        end
    end
    local cfgPriority = tonumber(cfg.priority) == 2 and 2 or 1
    local plan = AutoMarkers.PlanAssignments(candidates, occupied, self.claims, self.protected, cfgPriority, MARKER_COUNT)
    local candidateByGUID = {}
    for _, candidate in ipairs(candidates) do candidateByGUID[candidate.guid] = candidate end
    for _, assignment in ipairs(plan) do
        if not self:_canMark() then break end
        local candidate = candidateByGUID[assignment.guid]
        local unit = candidate and candidate.unit
        local current = byGUID[assignment.guid]
        if unit and SetRaidTarget and isEngaged(unit) and UnitGUID(unit) == assignment.guid then
            local ok = pcall(SetRaidTarget, unit, assignment.marker)
            if ok and GetRaidTargetIndex(unit) == assignment.marker then
                self.claims[assignment.guid], self.autoOwned[assignment.guid] = assignment.marker, assignment.marker
                self.protected[assignment.guid] = nil
                if current then self.replacedInitial[assignment.guid] = true end
                if current then
                    occupied[current] = occupied[current] or {}
                    occupied[current][assignment.guid] = nil
                end
                occupied[assignment.marker] = occupied[assignment.marker] or {}
                occupied[assignment.marker][assignment.guid] = true
                byGUID[assignment.guid], unitByGUID[assignment.guid] = assignment.marker, unit
                self:_sendClaim(assignment.guid, assignment.marker)
            end
        end
    end
end

function AutoMarkers:OnCombatDeath(guid)
    if not guid then return end
    self.claims[guid], self.protected[guid], self.replacedInitial[guid], self.autoOwned[guid] = nil, nil, nil, nil
    self.peerClaims[guid] = nil
    self:_sendClaim(guid, 0)
end

function AutoMarkers:OnCombatLog(...)
    local event, destGUID
    if select("#", ...) >= 2 then
        event, destGUID = ...
    elseif CombatLogGetCurrentEventInfo then
        local _, subevent, _, _, _, _, _, destinationGUID = CombatLogGetCurrentEventInfo()
        event, destGUID = subevent, destinationGUID
    end
    if event == "UNIT_DIED" or event == "PARTY_KILL" then self:OnCombatDeath(destGUID) end
end

function AutoMarkers:ClearOwnership(sendRelease)
    if sendRelease then
        for guid in pairs(self.claims) do self:_sendClaim(guid, 0) end
    end
    wipe(self.claims); wipe(self.protected); wipe(self.replacedInitial); wipe(self.autoOwned); wipe(self.peerClaims)
end

function AutoMarkers:ResetPull()
    self.pullHadCombat, self.pullIdleSince = false, nil
    self:ClearOwnership(true)
end

function AutoMarkers:_pullUpdate(now, candidates)
    local active = UnitAffectingCombat and UnitAffectingCombat("player") == true
    for _, candidate in ipairs(candidates) do
        if isEngaged(candidate.unit) then active = true; break end
    end
    if active then
        self.pullHadCombat, self.pullIdleSince = true, nil
    elseif self.pullHadCombat then
        self.pullIdleSince = self.pullIdleSince or now
        if now - self.pullIdleSince >= PULL_GRACE then
            self:ClearOwnership(true)
            self.pullHadCombat, self.pullIdleSince = false, nil
        end
    end
end

function AutoMarkers:Update(now)
    now = tonumber(now) or GetTime()
    self:_refreshRoster(now)
    local cfg = settings()
    if not enabledNow() then
        self.ready, self.blocked, self.agreementSince = false, "disabled", nil
        if self.lastEnabled ~= false then
            self:ClearOwnership(false)
            self:_sendHello(now)
        end
        self.lastEnabled = false
        return
    end
    if self.lastEnabled ~= true then
        -- Activation can happen without a roster event (for example, entering a key
        -- while already inside the same dungeon). Start a fresh discovery window.
        self.ready, self.blocked = false, "roster-debounce"
        self.rosterChangedAt = now
        self.agreementSince, self.agreementDigest = nil, nil
        self.acknowledgedDigest, self.digest, self.ownerGUID = nil, nil, nil
        self.lastHello, self.lastAck, self.lastOwner = nil, nil, nil
        self:_sendHello(now)
    end
    self.lastEnabled = true
    self.byNPC = self.byNPC or {}
    local dungeonID = BKA.activeDungeon and BKA.activeDungeon.challengeMapID
    if self.compiledDungeon ~= dungeonID then
        self.byNPC = compileAbilities(BKA.activeDungeon)
        self.compiledDungeon = dungeonID
    end
    local guid = UnitGUID and UnitGUID("player")
    self.localGUID = guid
    local counter = tonumber(cfg.sessionCounter) or 0
    if not self.sessionInitialized then
        counter = counter + 1
        cfg.sessionCounter = counter
        self.epoch = counter
        self.version = BKA.Version and BKA.Version:GetCurrent() or BKA.version or "0"
        self.sessionInitialized = true
        self.rosterChangedAt = now
    end
    local digest, owner, peers = self:_nextCoordination(now)
    if self.acknowledgedDigest ~= digest or now - (self.lastAck or 0) >= HEARTBEAT then self:_sendAck(now) end
    if not self.lastHello or now - self.lastHello >= HEARTBEAT then self:_sendHello(now) end
    if self.ready and owner == self.localGUID and
        (self.lastOwnerDigest ~= digest or now - (self.lastOwner or 0) >= HEARTBEAT) then self:_sendOwner(now) end
    local candidates = self:_eligibleMobs()
    self:_pullUpdate(now, candidates)
    if self.ready and owner == self.localGUID then self:_mark(candidates, now) end
end

function AutoMarkers:SettingsChanged()
    self.ready, self.blocked, self.agreementSince = false, "settings-changed", nil
    self.acknowledgedDigest, self.digest, self.ownerGUID = nil, nil, nil
    self.lastHello, self.lastAck, self.lastOwner = nil, nil, nil
    self:_refreshRoster(GetTime and GetTime() or 0)
    self.rosterChangedAt = GetTime and GetTime() or 0
    if not enabledNow() then self:ClearOwnership(false) end
end

function AutoMarkers:Initialize()
    if self.frame then return end
    self.prefixRegistered = registerPrefix()
    local cfg = settings()
    if cfg then
        cfg.sessionCounter = (tonumber(cfg.sessionCounter) or 0) + 1
        self.epoch = cfg.sessionCounter
    end
    self.version = BKA.Version and BKA.Version:GetCurrent() or BKA.version or "0"
    self.localGUID = UnitGUID and UnitGUID("player")
    self.sessionInitialized = true
    self.rosterChangedAt = GetTime and GetTime() or 0
    self:_refreshRoster(self.rosterChangedAt)
    local frame = CreateFrame("Frame")
    self.frame = frame
    frame:RegisterEvent("GROUP_ROSTER_UPDATE")
    frame:RegisterEvent("CHAT_MSG_ADDON")
    frame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
    frame:RegisterEvent("PLAYER_ENTERING_WORLD")
    frame:RegisterEvent("CHALLENGE_MODE_RESET")
    frame:RegisterEvent("CHALLENGE_MODE_COMPLETED")
    frame:SetScript("OnEvent", function(_, event, ...)
        if event == "CHAT_MSG_ADDON" then self:OnMessage(...)
        elseif event == "COMBAT_LOG_EVENT_UNFILTERED" then self:OnCombatLog()
        elseif event == "CHALLENGE_MODE_RESET" or event == "CHALLENGE_MODE_COMPLETED" then self:ResetPull()
        elseif event == "PLAYER_ENTERING_WORLD" then
            wipe(self.peers); wipe(self.gossip)
            self.ready, self.blocked, self.agreementSince = false, "world-entry", nil
            self.rosterChangedAt = GetTime()
        else self:_refreshRoster(GetTime()) end
    end)
    frame:SetScript("OnUpdate", function(_, elapsed)
        self.elapsed = self.elapsed + elapsed
        if self.elapsed < 0.5 then return end
        self.elapsed = 0
        self:Update(GetTime())
    end)
end
