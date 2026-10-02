local BKA = BFAKeyAlerts
local Tracker = { members = {}, byUnit = {}, panels = {} }
BKA.GroupCooldowns = Tracker

local UNITS = { "player", "party1", "party2", "party3", "party4" }
local PARTY_ONLY = { "party1", "party2", "party3", "party4" }
local FORBEARANCE = 25771

-- Keep these registries aligned with the source BfA 8.3 tracker. Foreign
-- cooldowns are estimates based on observations, never remote API reads.
local HEALER_SPELLS = {
    [270] = {
        { id=216113, cd=60, duration=15, optional=true },
        { id=116849, cd=120, duration=12 }, { id=115310, cd=180 },
    },
    [105] = { { id=740, cd=180, duration=8 }, { id=102342, cd=60, duration=12 } },
    [65] = { { id=31821, cd=180, duration=8 }, { id=31884, cd=120, duration=20, procAura=true } },
    [256] = { { id=33206, cd=180, duration=8 }, { id=62618, cd=180, duration=10 } },
    [257] = { { id=64843, cd=180, duration=8 }, { id=47788, cd=180, duration=10 } },
    [264] = { { id=98008, cd=180, duration=6 }, { id=108280, cd=180, duration=10, procAura=true } },
}

local SPEC_CLASS = { [270]="MONK", [105]="DRUID", [65]="PALADIN", [256]="PRIEST", [257]="PRIEST", [264]="SHAMAN" }
local CLASS_SPEC = { MONK=270, DRUID=105, PALADIN=65, SHAMAN=264 }
local HEALER_BY_ID, INFER_SPEC = {}, {}
for specID, list in pairs(HEALER_SPELLS) do
    for _, info in ipairs(list) do
        info.specID = specID
        HEALER_BY_ID[info.id] = info
        -- Avenging Wrath is shared across paladin specs; it cannot identify a healer.
        if info.id ~= 31884 and not info.optional then INFER_SPEC[info.id] = specID end
    end
end

local DEFENSIVES = {
    [45438] = { name="Ice Block", class="MAGE", cd=240 },
    [110959] = { name="Greater Invisibility", class="MAGE", cd=120, spec=62, aura=110960, optional=true },
    [642] = { name="Divine Shield", class="PALADIN", cd=300, forbearance=true },
    [5384] = { name="Feign Death", class="HUNTER", cd=30, startsOnAuraRemoved=true },
    [186265] = { name="Aspect of the Turtle", class="HUNTER", cd=180 },
    [1856] = { name="Vanish", class="ROGUE", cd=120 },
    [58984] = { name="Shadowmeld", raceID=4, cd=120 },
    [196555] = { name="Netherwalk", class="DEMONHUNTER", cd=120, optional=true },
}
local DEFENSIVE_RESETS = { [235219] = { 45438 } }
-- Base cooldowns from https://gist.github.com/tobilen/d8deffc06dbadb68a752f067b564677f
local TANK_DEFENSIVES = {
    WARRIOR={{871,240},{12975,180}},
    PALADIN={{31850,120},{86659,300}},
    DEATHKNIGHT={{55233,90},{48792,180},{48707,60},{49028,120}},
    DRUID={{22812,60},{61336,180,charges=2}}, MONK={{115203,420},{115176,300}},
    DEMONHUNTER={{187827,180},{204021,60}},
}
local TANK_BY_ID={}
local TANK_AURA_ALIASES={ [212641]=86659,[81256]=49028 }
local TANK_SPEC_CLASS={ [66]="PALADIN",[73]="WARRIOR",[250]="DEATHKNIGHT",[104]="DRUID",[268]="MONK",[581]="DEMONHUNTER" }
for class, list in pairs(TANK_DEFENSIVES) do
    for _, entry in ipairs(list) do
        entry.class,entry.id,entry.cd=class,entry[1],entry[2]
        TANK_BY_ID[entry.id]=entry
    end
end
local DEFENSIVE_AURAS = {}
for id, info in pairs(DEFENSIVES) do DEFENSIVE_AURAS[id] = id; if info.aura then DEFENSIVE_AURAS[info.aura] = id end end

local function now() return GetTime and GetTime() or 0 end
local function spellName(id, fallback) return (GetSpellInfo and GetSpellInfo(id)) or fallback or tostring(id) end
local function getMember(guid, create)
    if not guid then return nil end
    local member = Tracker.members[guid]
    if not member and create then member = { guid=guid, healer={}, defensive={}, seen=false }; Tracker.members[guid]=member end
    return member
end
local function localSpec()
    if not (GetSpecialization and GetSpecializationInfo) then return nil end
    local index = GetSpecialization()
    return index and GetSpecializationInfo(index) or nil
end
local function setSpec(member, specID)
    if not member or not SPEC_CLASS[specID] or member.class ~= SPEC_CLASS[specID] then return end
    if member.specID ~= specID then member.healer = {}; member.specID = specID end
end
local function unitStatus(unit)
    if not UnitExists or not UnitExists(unit) then return false, "missing" end
    if UnitIsConnected and not UnitIsConnected(unit) then return false, "offline" end
    if UnitIsDeadOrGhost and UnitIsDeadOrGhost(unit) then return false, "dead" end
    return true
end
local function currentMember(unit)
    local guid = UnitGUID and UnitGUID(unit)
    local member = guid and Tracker.members[guid]
    if not member or Tracker.byUnit[unit] ~= guid then return nil end
    return member
end
local function challengeActive()
    if not (C_ChallengeMode and C_ChallengeMode.GetActiveChallengeMapID) then return false end
    local id = C_ChallengeMode.GetActiveChallengeMapID()
    return id and id > 0 or false
end

function Tracker:RefreshRoster(scanAuras)
    local byUnit = {}
    for _, unit in ipairs(UNITS) do
        if UnitExists and UnitExists(unit) then
            local guid = UnitGUID and UnitGUID(unit)
            if guid then
                local member = getMember(guid, true)
                local class, raceID
                if UnitClass then local _, token = UnitClass(unit); class = token end
                if UnitRace then local _, _, id = UnitRace(unit); raceID = id end
                member.unit, member.name, member.class, member.raceID = unit, (UnitName and UnitName(unit)) or unit, class, raceID
                member.connected = not UnitIsConnected or UnitIsConnected(unit)
                member.dead = UnitIsDeadOrGhost and UnitIsDeadOrGhost(unit) or false
                member.healer = member.healer or {}
                member.defensive = member.defensive or {}
                member.isHealer = UnitGroupRolesAssigned and UnitGroupRolesAssigned(unit) == "HEALER" or false
                member.isTank = UnitGroupRolesAssigned and UnitGroupRolesAssigned(unit) == "TANK" or false
                if unit == "player" then
                    local spec=localSpec()
                    if HEALER_SPELLS[spec] then
                        member.isHealer=true; member.isTank=false; setSpec(member,spec)
                    elseif TANK_SPEC_CLASS[spec] then
                        member.isTank=true; member.isHealer=false
                    else
                        member.isHealer=false; member.isTank=false
                    end
                elseif member.isHealer and CLASS_SPEC[class] then
                    setSpec(member,CLASS_SPEC[class])
                elseif member.isHealer and not member.specID and class=="PRIEST" and GetInspectSpecialization
                    and now()>=(member.nextInspectCheck or 0) then
                    local inspected=GetInspectSpecialization(unit)
                    member.nextInspectCheck=now()+5
                    if inspected==256 or inspected==257 then setSpec(member,inspected) end
                elseif member.specID and SPEC_CLASS[member.specID] ~= class then
                    member.specID, member.healer = nil, {}
                end
                member.seen = true
                byUnit[unit] = guid
            end
        end
    end
    self.byUnit = byUnit
    if scanAuras ~= false then for _, unit in ipairs(UNITS) do self:ScanUnitAuras(unit) end end
end

local function recordUse(state, timestamp, cooldown, duration, active)
    if not state.lastUsed or timestamp - state.lastUsed > 1 then
        state.lastUsed = timestamp
        state.readyAt = timestamp + cooldown
    end
    if active then state.active = true; state.activeUntil = duration and timestamp + duration or state.activeUntil end
    state.estimated = true
end
local function hasActiveTarget(state, timestamp)
    local active = false
    for guid, expiration in pairs(state.activeTargets or {}) do
        if type(expiration) == "number" and expiration <= timestamp then state.activeTargets[guid] = nil
        else active = true end
    end
    state.active=active
    return active
end

function Tracker:ScanUnitAuras(unit)
    if not (UnitExists and UnitExists(unit) and UnitAura and UnitGUID) then return end
    local seenDefensives={}
    for index = 1, 40 do
        local name, _, _, _, duration, expiration, caster, _, _, auraID = UnitAura(unit, index, "HELPFUL")
        if not name then break end
        local ownerGUID = caster and UnitGUID(caster)
        local healer = ownerGUID and getMember(ownerGUID, false)
        local healerInfo = HEALER_BY_ID[auraID]
        if healer and healerInfo and healer.isHealer then
            setSpec(healer, healerInfo.specID)
            local state = healer.healer[auraID] or {}; healer.healer[auraID] = state
            state.activeTargets = state.activeTargets or {}
            state.activeTargets[UnitGUID(unit)] = expiration and expiration>0 and expiration or true
            state._auraSeen = true
            if not healerInfo.procAura and not state.lastUsed and expiration and expiration > 0 and duration and duration > 0 then
                state.lastUsed = expiration-duration
                state.readyAt = state.lastUsed + healerInfo.cd
                state.estimated = true
            end
        end
        local defensiveID = DEFENSIVE_AURAS[auraID]
        local defensiveOwner = UnitGUID(unit)
        local owner = defensiveOwner and getMember(defensiveOwner, false)
        if defensiveID and owner then
            local state = owner.defensive[defensiveID] or {}; owner.defensive[defensiveID] = state
            state.active = not expiration or expiration <= 0 or expiration > now()
            state.activeUntil = expiration
            state.auraSeenAt=now(); seenDefensives[defensiveID]=true
            state.observed = true
            if DEFENSIVES[defensiveID].startsOnAuraRemoved then
                state.readyAt = nil
            elseif not state.lastUsed and expiration and expiration > 0 and duration and duration > 0 then
                state.lastUsed = expiration-duration
                state.readyAt = state.lastUsed + DEFENSIVES[defensiveID].cd
                state.estimated = true
            end
        end
        local tankInfo=TANK_BY_ID[TANK_AURA_ALIASES[auraID] or auraID]
        local tankOwnerGUID=ownerGUID or defensiveOwner
        local tankOwner=tankOwnerGUID and getMember(tankOwnerGUID,false)
        if tankInfo and tankOwner and tankOwner.class==tankInfo.class then
            local state=tankOwner.defensive[tankInfo.id] or {}; tankOwner.defensive[tankInfo.id]=state
            state.active=not expiration or expiration<=0 or expiration>now(); state.activeUntil=expiration; state.observed=true; state.auraSeenAt=now(); seenDefensives[tankInfo.id]=true
            if not state.lastUsed and expiration and expiration>0 and duration and duration>0 then
                state.lastUsed=expiration-duration; state.readyAt=state.lastUsed+tankInfo.cd; state.estimated=true
            end
        end
    end
    local owner=currentMember(unit)
    if owner then
        for id,state in pairs(owner.defensive) do
            if state.active and state.auraSeenAt and not seenDefensives[id] then
                state.active=false; state.activeUntil=nil
                if DEFENSIVES[id] and DEFENSIVES[id].startsOnAuraRemoved then
                    state.readyAt=now()+DEFENSIVES[id].cd; state.lastUsed=now(); state.estimated=true; state.observed=true
                end
            elseif state.activeUntil and state.activeUntil<=now() then state.active=false end
        end
    end
    local unitGUID = UnitGUID(unit)
    for _, healer in pairs(self.members) do
        for _, state in pairs(healer.healer or {}) do
            if state.activeTargets and unitGUID and state.activeTargets[unitGUID] and not state._auraSeen then
                state.activeTargets[unitGUID] = nil
            end
            state._auraSeen = nil
            state.active = state.activeTargets and next(state.activeTargets) ~= nil or false
        end
    end
    -- Forbearance is a debuff and blocks Divine Shield while present.
    local owner = currentMember(unit)
    if owner and UnitAura then
        owner.forbearance = false
        for index = 1, 40 do
            local name, _, _, _, _, _, _, _, _, id = UnitAura(unit, index, "HARMFUL")
            if not name then break end
            if id == FORBEARANCE then owner.forbearance = true; break end
        end
    end
end

function Tracker:GetHealerCooldownStates()
    local entries = {}
    local timestamp = now()
    for _, unit in ipairs(UNITS) do
        local member = currentMember(unit)
        if member and member.isHealer then
            local ok = unitStatus(unit)
            local known = {}
            if member.specID then
                for _, info in ipairs(HEALER_SPELLS[member.specID] or {}) do known[#known + 1] = info end
            elseif member.class == "PRIEST" then
                for _, info in ipairs(HEALER_SPELLS[256]) do known[#known + 1] = info end
                for _, info in ipairs(HEALER_SPELLS[257]) do known[#known + 1] = info end
            end
            for _, info in ipairs(known) do
                local state = member.healer[info.id]
                local entry = { spellID=info.id, name=spellName(info.id), owner=member.name, ownerGUID=member.guid, cooldown=info.cd, state="unknown" }
                local active = state and (state.activeTargets and hasActiveTarget(state, timestamp) or state.active)
                if not ok then entry.state="blocked"; entry.hint=BKA:L("GC_BLOCKED")
                elseif unit == "player" then
                    local readyAt, duration
                    local known
                    if IsSpellKnown or IsPlayerSpell then
                        known=(IsSpellKnown and IsSpellKnown(info.id)) or (IsPlayerSpell and IsPlayerSpell(info.id)) or false
                    end
                    if active then entry.state="active"
                    elseif known == false then entry.state="unknown"
                    elseif GetSpellCooldown then
                        local start, length, enabled = GetSpellCooldown(info.id)
                        if enabled == 1 and start and length and start >= 0 and length >= 0 then
                            duration = length
                            if length > 1.5 then readyAt = start + length else readyAt = timestamp end
                        end
                    end
                    if readyAt then
                        entry.remaining = math.max(0, readyAt - timestamp)
                        entry.state = entry.remaining > 0 and "cooldown" or "ready"
                        entry.cooldown = duration > 1.5 and duration or info.cd
                        entry.estimated = false
                    elseif state and known ~= false then
                        entry.remaining = state.readyAt and math.max(0, state.readyAt-timestamp) or nil
                        entry.state = active and "active" or (entry.remaining and (entry.remaining>0 and "cooldown" or "ready") or "unknown")
                        entry.estimated = true
                    end
                elseif state then
                    entry.remaining = state.readyAt and math.max(0, state.readyAt-timestamp) or nil
                    entry.state = active and "active" or (entry.remaining and (entry.remaining>0 and "cooldown" or "ready") or "unknown")
                    entry.estimated = true
                end
                if info.optional and entry.state == "unknown" then entry.hint=BKA:L("GC_UNKNOWN") end
                entries[#entries + 1] = entry
            end
        end
    end
    return entries
end

local function defensiveMatches(member, info)
    if info.class and member.class ~= info.class then return false end
    if info.raceID and member.raceID ~= info.raceID then return false end
    return true
end

function Tracker:GetDefensiveStates(unit)
    local entries, member = {}, currentMember(unit)
    if not member then return entries end
    local ok = unitStatus(unit)
    local timestamp = now()
    for id, info in pairs(DEFENSIVES) do
        if defensiveMatches(member, info) then
            local state = member.defensive[id]
            local item = { spellID=id, name=spellName(id, info.name), owner=member.name, ownerGUID=member.guid,
                cooldown=info.cd, state="unknown" }
            if not ok then
                item.state="blocked"; item.hint=BKA:L("GC_BLOCKED")
            elseif info.spec and member.specID and member.specID ~= info.spec then
                -- Ineligible after specialization is known.
            elseif info.spec and not member.specID and not (state and state.observed) then
                item.state="unknown"
            elseif info.optional and not (state and state.observed) then
                item.state="unknown"
            elseif info.forbearance and member.forbearance then
                item.state="blocked"
            elseif state then
                item.remaining = state.readyAt and math.max(0, state.readyAt-timestamp) or nil
                item.state = state.active and "active" or (item.remaining and (item.remaining>0 and "cooldown" or "ready") or "unknown")
                item.estimated = state.estimated == true
            end
            entries[#entries + 1] = item
        end
    end
    table.sort(entries, function(a,b) return a.spellID < b.spellID end)
    return entries
end

function Tracker:GetTankStates(unit)
    local entries, member = {}, currentMember(unit)
    if not member or not member.isTank then return entries end
    local ok = unitStatus(unit)
    local timestamp = now()
    for _, info in ipairs(TANK_DEFENSIVES[member.class] or {}) do
        local state = member.defensive[info.id]
        local entry = { spellID=info.id, name=spellName(info.id), owner=member.name, ownerGUID=member.guid,
            cooldown=info.cd, state="unknown" }
        if not ok then entry.state="blocked"; entry.hint=BKA:L("GC_BLOCKED")
        elseif unit=="player" and state and state.active then entry.state="active"
        elseif unit=="player" and (IsSpellKnown or IsPlayerSpell) and not ((IsSpellKnown and IsSpellKnown(info.id)) or (IsPlayerSpell and IsPlayerSpell(info.id))) then entry.state="unknown"
        elseif unit=="player" and info.charges and GetSpellCharges then
            local charges, maximum, start, duration = GetSpellCharges(info.id)
            if charges and maximum and maximum > 0 and start and duration then
                entry.charges = charges
                entry.remaining = charges == 0 and math.max(0, start+duration-timestamp) or 0
                entry.cooldown = duration > 0 and duration or info.cd
                entry.state = charges > 0 and "ready" or "cooldown"
                entry.estimated = false
            end
        elseif unit=="player" and GetSpellCooldown then
            local start,length,enabled=GetSpellCooldown(info.id)
            if enabled==1 and start and length and start>=0 and length>=0 then
                local readyAt=length>1.5 and start+length or timestamp
                entry.remaining=math.max(0,readyAt-timestamp)
                entry.cooldown=length>1.5 and length or info.cd
                entry.state=entry.remaining>0 and "cooldown" or "ready"
                entry.estimated=false
            elseif state then
                entry.remaining=state.readyAt and math.max(0,state.readyAt-timestamp) or nil
                entry.state=state.active and "active" or (entry.remaining and (entry.remaining>0 and "cooldown" or "ready") or "unknown")
                entry.estimated=true
            end
        elseif state then
            entry.remaining=state.readyAt and math.max(0,state.readyAt-timestamp) or nil
            entry.state=state.active and "active" or (entry.remaining and (entry.remaining>0 and "cooldown" or "ready") or "unknown")
            entry.estimated=true
        end
        -- Observing one remote charge does not reveal whether another is available.
        if unit ~= "player" and info.charges and entry.state ~= "active" and entry.state ~= "blocked" then
            entry.state = "unknown"
        end
        entries[#entries+1]=entry
    end
    return entries
end

function Tracker:HandleCombatLog(subevent, sourceGUID, destGUID, spellID)
    if not spellID then return end
    local info = HEALER_BY_ID[spellID]
    if info then
        local member = getMember(sourceGUID, false)
        if member and member.isHealer then
            if member.specID and member.specID ~= info.specID then return end
            if not member.specID and INFER_SPEC[spellID] then setSpec(member, INFER_SPEC[spellID]) end
            if not member.specID and member.class == "PRIEST" then setSpec(member, info.specID) end
            if member.specID == info.specID then
                local state = member.healer[spellID] or {}; member.healer[spellID] = state
                if subevent == "SPELL_CAST_SUCCESS" or subevent == "SPELL_AURA_APPLIED" or subevent == "SPELL_AURA_REFRESH" then
                    if subevent == "SPELL_CAST_SUCCESS" or not info.procAura then recordUse(state, now(), info.cd, info.duration, false) end
                    if subevent ~= "SPELL_CAST_SUCCESS" then
                        state.activeTargets=state.activeTargets or {}
                        state.activeTargets[destGUID]=info.duration and (now()+info.duration) or true
                        state.active=true
                    end
                elseif subevent == "SPELL_AURA_REMOVED" then
                    if state.activeTargets then state.activeTargets[destGUID]=nil end
                    state.active=state.activeTargets and next(state.activeTargets) ~= nil or false
                end
            end
        end
    end

    local defensiveID = DEFENSIVE_AURAS[spellID]
    local tankID=TANK_AURA_ALIASES[spellID] or spellID
    local tankInfo=TANK_BY_ID[tankID]
    if tankInfo then
            local member=getMember(sourceGUID,false)
        if member and member.class==tankInfo.class and member.isTank then
            local state=member.defensive[tankID] or {}; member.defensive[tankID]=state
            if subevent=="SPELL_CAST_SUCCESS" then
                recordUse(state,now(),tankInfo.cd,nil,false); state.observed=true
            elseif subevent=="SPELL_AURA_APPLIED" or subevent=="SPELL_AURA_REFRESH" then
                if not state.lastUsed then recordUse(state,now(),tankInfo.cd,nil,false) end
                state.active=true; state.activeDest=destGUID; state.observed=true
            elseif subevent=="SPELL_AURA_REMOVED" and (not state.activeDest or state.activeDest==destGUID) then
                state.active=false; state.activeDest=nil
            end
        end
    end
    if subevent == "SPELL_CAST_SUCCESS" and DEFENSIVE_RESETS[spellID] then
        local member = getMember(sourceGUID, false)
        if member then
            for _, id in ipairs(DEFENSIVE_RESETS[spellID]) do
                local state=member.defensive[id] or {}
                state.readyAt=now(); state.estimated=true; state.observed=true
                member.defensive[id]=state
            end
        end
    end
    if defensiveID then
        local defInfo = DEFENSIVES[defensiveID]
        if subevent == "SPELL_CAST_SUCCESS" then
            local member = getMember(sourceGUID, false)
            if member and defensiveMatches(member, defInfo) then
                local state = member.defensive[defensiveID] or {}; member.defensive[defensiveID] = state
                state.observed=true
                if defInfo.startsOnAuraRemoved then state.active=true; state.readyAt=nil; state.estimated=true
                else recordUse(state, now(), defInfo.cd, nil, false); state.observed=true end
                if defensiveID == 110959 then member.specID=62 end
            end
        elseif subevent == "SPELL_AURA_APPLIED" or subevent == "SPELL_AURA_REFRESH" then
            local member = getMember(destGUID, false)
            if member and defensiveMatches(member, defInfo) then
                local state = member.defensive[defensiveID] or {}; member.defensive[defensiveID] = state
                state.observed=true; state.active=true
                if defInfo.startsOnAuraRemoved then state.readyAt=nil
                elseif not state.lastUsed then recordUse(state, now(), defInfo.cd, nil, false) end
                state.observed=true
            end
        elseif subevent == "SPELL_AURA_REMOVED" and defInfo.startsOnAuraRemoved then
            local member = getMember(destGUID, false)
            if member then
                local state = member.defensive[defensiveID] or {}; member.defensive[defensiveID] = state
                state.active=false; state.readyAt=now()+defInfo.cd; state.lastUsed=now(); state.estimated=true; state.observed=true
            end
        elseif subevent == "SPELL_AURA_REMOVED" then
            local member = getMember(destGUID, false)
            local state = member and member.defensive[defensiveID]
            if state then state.active=false; state.activeUntil=nil end
        end
    end
end

local STATE_COLORS = {
    unknown={0.40,0.43,0.48,1}, ready={0.31,0.88,0.69,1}, active={0.34,0.91,0.76,1},
    cooldown={0.98,0.62,0.18,1}, blocked={0.90,0.30,0.18,1},
}
local function tooltip(tile, entry)
    tile.entry = entry
    tile.icon:SetTexture((GetSpellTexture and GetSpellTexture(entry.spellID)) or "Interface\\Icons\\INV_Misc_QuestionMark")
    tile.cooldownText:SetText(entry.remaining and entry.remaining > 0 and tostring(math.ceil(entry.remaining)) or "")
    local color = STATE_COLORS[entry.state] or STATE_COLORS.unknown
    tile:SetBackdropBorderColor(unpack(color))
    tile.icon:SetDesaturated(entry.state == "unknown" or entry.state == "blocked")
    tile.icon:SetAlpha(entry.state == "unknown" and 0.45 or 1)
    if entry.remaining and entry.remaining > 0 and entry.cooldown then
        tile.sweep:SetCooldown(now()+entry.remaining-entry.cooldown, entry.cooldown)
        tile.sweep:Show()
    else tile.sweep:Hide() end
    tile:SetScript("OnEnter", function(self)
        local item=self.entry
        GameTooltip:SetOwner(self,"ANCHOR_TOP")
        GameTooltip:SetText(item.name or spellName(item.spellID))
        if item.owner then GameTooltip:AddLine(item.owner,0.65,0.8,0.85) end
        GameTooltip:AddLine(BKA:L("GC_" .. string.upper(item.state or "unknown")),0.85,0.85,0.85,true)
        if item.remaining and item.remaining > 0 then GameTooltip:AddLine(BKA:L("GC_REMAINING_FMT",math.ceil(item.remaining)),1,1,1) end
        if item.estimated then GameTooltip:AddLine(BKA:L("GC_ESTIMATE"),0.75,0.75,0.65,true) end
        GameTooltip:Show()
    end)
    tile:SetScript("OnLeave", function() GameTooltip:Hide() end)
end

local function createTile(parent, kind)
    local tile = CreateFrame("Frame",nil,parent)
    tile:SetSize(32,32)
    if kind == "defensive" then BKA.HUD:StyleFrame(tile,0.8) end
    tile:EnableMouse(true)
    tile.icon=tile:CreateTexture(nil,"ARTWORK"); tile.icon:SetPoint("TOPLEFT",2,-2); tile.icon:SetPoint("BOTTOMRIGHT",-2,2); tile.icon:SetTexCoord(0.08,0.92,0.08,0.92)
    tile.sweep=CreateFrame("Cooldown",nil,tile,"CooldownFrameTemplate"); tile.sweep:SetAllPoints(tile.icon); tile.sweep:SetDrawEdge(false); tile.sweep:SetHideCountdownNumbers(true); tile.sweep:SetSwipeColor(0,0,0,0.65); tile.sweep:EnableMouse(false)
    tile.cooldownText=tile:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall"); tile.cooldownText:SetPoint("CENTER"); tile.cooldownText:SetTextColor(1,1,1)
    return tile
end

local function settings(kind) return BKA.db[kind .. "HUD"] end

local function saveDraggedPanel(frame, s, kind)
    frame:StopMovingOrSizing()
    BKA.HUD:SavePosition(s,frame)
    frame._bkaDragging=false
    BKA.HUD:Apply(frame,s,kind == "defensive" and 350 or 0,kind == "tank" and 330 or 170)
    if kind ~= "defensive" and frame.dragHandle then frame.dragHandle:Hide() end
end

local function startPanelDrag(frame, s)
    if s.locked == false then frame._bkaDragging=true; frame:StartMoving() end
end

local function configurePanelDrag(frame, s, kind)
    local iconOnly=kind == "healer" or kind == "tank"
    if iconOnly then
        frame:EnableMouse(s.locked == false)
        frame:RegisterForDrag("LeftButton")
        frame:SetScript("OnDragStart",function() startPanelDrag(frame,s) end)
        frame:SetScript("OnDragStop",function() saveDraggedPanel(frame,s,kind) end)
        if frame.accent then frame.accent:Hide() end
        if frame.dragHandle then frame.dragHandle:Hide() end
        for _,tile in ipairs(frame.tiles or {}) do
            tile:RegisterForDrag("LeftButton")
            tile:SetScript("OnDragStart",function() startPanelDrag(frame,s) end)
            tile:SetScript("OnDragStop",function() saveDraggedPanel(frame,s,kind) end)
        end
    else
        frame:EnableMouse(false)
        if frame.dragHandle then frame.dragHandle:SetHeight(8) end
    end
end

local function makePanel(kind)
    local title = BKA:L(kind == "healer" and "GC_HEALER" or kind == "tank" and "GC_TANK" or "GC_DEFENSIVE")
    local s = settings(kind)
    local defaultY=kind == "healer" and 170 or kind == "tank" and 330 or 170
    local defaultX=kind == "defensive" and 350 or 0
    local frame = BKA.HUD:CreatePanel("BFAKeyAlerts_GroupCooldowns_" .. kind,s,title,defaultX,defaultY)
    frame.title=BKA.HUD:Text(frame,10,10,-8,240); frame.title:SetText(title)
    if kind == "healer" or kind == "tank" or kind == "defensive" then frame.title:Hide() end
    frame.tiles,frame.owners={},{}
    Tracker.panels[kind]=frame
    return frame
end

function Tracker:ApplySettings(kind)
    local kinds = kind and {kind} or {"healer","defensive","tank"}
    for _, panelKind in ipairs(kinds) do
        local frame=self.panels[panelKind]
        if frame then
            local s=settings(panelKind)
            BKA.HUD:Apply(frame,s,panelKind == "defensive" and 350 or 0,panelKind == "tank" and 330 or 170)
            frame:SetAlpha(tonumber(s.alpha) or 1)
            if panelKind == "healer" or panelKind == "tank" then
                BKA.HUD:StyleFrame(frame,tonumber(s.backgroundAlpha) or 0.75)
                configurePanelDrag(frame,s,panelKind)
            else
                BKA.HUD:StyleFrame(frame,tonumber(s.backgroundAlpha) or 0.82)
                configurePanelDrag(frame,s,panelKind)
            end
        end
    end
    self:Refresh(true)
end

function Tracker:ResetPosition(kind)
    local s=settings(kind)
    s.point,s.relativePoint,s.x,s.y="CENTER","CENTER",kind == "defensive" and 350 or 0,kind == "tank" and 330 or 170
    self:ApplySettings(kind)
end

local function render(kind, rows)
    local frame=Tracker.panels[kind] or makePanel(kind)
    local s=settings(kind)
    if not BKA.db.enabled or not s.shown or (s.onlyInKey and not challengeActive()) then frame:Hide(); return end
    frame:SetAlpha(tonumber(s.alpha) or 1)
    if kind == "healer" or kind == "tank" then
        BKA.HUD:StyleFrame(frame,tonumber(s.backgroundAlpha) or 0.75)
        configurePanelDrag(frame,s,kind)
    else
        BKA.HUD:StyleFrame(frame,tonumber(s.backgroundAlpha) or 0.82)
    end
    local size=math.max(20,math.min(56,tonumber(s.iconSize) or 32))
    local columns=math.max(1,math.min(12,math.floor(tonumber(s.columns) or (kind == "healer" and 6 or 5))))
    local rowIndex,used,contentWidth,visualRow=0,0,0,0
    local gap=math.max(2,math.floor(size*0.125))
    for _, row in ipairs(rows) do
        if #row.entries > 0 then
            rowIndex=rowIndex+1
            if kind == "defensive" then
                local label=frame.owners[rowIndex]
                if not label then label=BKA.HUD:Text(frame,9,8,0,90); frame.owners[rowIndex]=label end
                label:ClearAllPoints(); label:SetPoint("TOPLEFT",frame,8,-10-visualRow*(size+gap)); label:SetWidth(90); label:SetText(row.name); label:Show()
            end
            local rowStart=used
            for entryIndex, entry in ipairs(row.entries) do
                used=used+1
                local tile=frame.tiles[used] or createTile(frame,kind); frame.tiles[used]=tile
                tile:SetSize(size,size)
                local iconIndex=kind == "defensive" and entryIndex-1 or used-1
                local col=iconIndex%columns
                local localRow=math.floor(iconIndex/columns)
                local offsetX=kind == "defensive" and 104 or 5
                local yOffset=kind == "defensive" and 10+(visualRow+localRow)*(size+gap) or 5+localRow*(size+gap)
                tile:ClearAllPoints(); tile:SetPoint("TOPLEFT",frame,offsetX+col*(size+gap),-yOffset)
                if kind == "healer" or kind == "tank" then
                    tile:RegisterForDrag("LeftButton")
                    tile:SetScript("OnDragStart",function() startPanelDrag(frame,s) end)
                    tile:SetScript("OnDragStop",function() saveDraggedPanel(frame,s,kind) end)
                end
                tooltip(tile,entry); tile:Show()
                contentWidth=math.max(contentWidth,offsetX+col*(size+gap)+size+(kind == "defensive" and 8 or 5))
            end
            if kind == "defensive" then visualRow=visualRow+math.ceil((used-rowStart)/columns) end
        end
    end
    for i=used+1,#frame.tiles do frame.tiles[i]:Hide() end
    for i=rowIndex+1,#frame.owners do frame.owners[i]:Hide() end
    local contentRows=kind == "defensive" and visualRow or math.ceil(used/columns)
    local minWidth=kind == "defensive" and 230 or size+10
    local height=kind == "defensive" and math.max(size,10+contentRows*(size+gap))
        or math.max(size+10,10+contentRows*size+math.max(0,contentRows-1)*gap)
    frame:SetSize(math.max(minWidth,contentWidth),height)
    frame.title:SetWidth(math.max(210,contentWidth-20))
    if used > 0 or not s.locked then frame:Show() else frame:Hide() end
end

function Tracker:Refresh(force, scanAuras)
    if not self.initialized and not force then return end
    self:RefreshRoster(scanAuras)
    local healerRows={{entries=self:GetHealerCooldownStates()}}
    render("healer",healerRows)
    local defensiveRows,tankRows={},{}
    for _,unit in ipairs(PARTY_ONLY) do
        local member=currentMember(unit)
        if member then
            defensiveRows[#defensiveRows+1]={name=member.name,entries=self:GetDefensiveStates(unit)}
            if member.isTank then tankRows[#tankRows+1]={name=member.name,entries=self:GetTankStates(unit)} end
        end
    end
    local player=currentMember("player")
    if player and player.isTank then
        table.insert(tankRows,1,{name=player.name,entries=self:GetTankStates("player")})
    end
    render("defensive",defensiveRows)
    render("tank",tankRows)
end

function Tracker:Initialize()
    if self.initialized then return end
    self.initialized=true
    self.panels.healer=makePanel("healer")
    self.panels.defensive=makePanel("defensive")
    self.panels.tank=makePanel("tank")
    self:ApplySettings()
    local eventFrame=CreateFrame("Frame")
    for _,event in ipairs({"COMBAT_LOG_EVENT_UNFILTERED","GROUP_ROSTER_UPDATE","PLAYER_ENTERING_WORLD","CHALLENGE_MODE_START","CHALLENGE_MODE_RESET","PLAYER_SPECIALIZATION_CHANGED","UNIT_AURA"}) do eventFrame:RegisterEvent(event) end
    eventFrame:SetScript("OnEvent",function(_,event,...)
        if event == "COMBAT_LOG_EVENT_UNFILTERED" then
            local _,subevent,_,sourceGUID,_,_,_,destGUID,_,_,_,spellID=CombatLogGetCurrentEventInfo()
            Tracker:HandleCombatLog(subevent,sourceGUID,destGUID,spellID)
            return
        elseif event == "PLAYER_ENTERING_WORLD" or event == "CHALLENGE_MODE_START" or event == "CHALLENGE_MODE_RESET" then
            Tracker:ResetObservations()
        elseif event == "UNIT_AURA" then
            local unit=(...)
            if unit=="player" or string.match(unit or "","^party%d$") then Tracker:ScanUnitAuras(unit) end
            return
        end
        Tracker:Refresh(true,true)
    end)
    local elapsed=0
    eventFrame:SetScript("OnUpdate",function(_,dt)
        elapsed=elapsed+dt
        if elapsed<0.25 then return end
        elapsed=0; Tracker:Refresh(false,false)
    end)
    self.eventFrame=eventFrame
    self:Refresh(true,true)
end

function Tracker:ResetObservations()
    self.members,self.byUnit={},{}
end
