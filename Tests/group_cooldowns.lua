-- Focused combat-log and roster replay for GroupCooldowns. Run with Lua 5.1.
local now=0
local unitData={}
local auraData={}
local playerSpec
local knownSpells={}
local spellCooldowns={}

local function unit(guid,class,role,name,connected,dead,raceID)
    unitData[guid]={guid=guid,class=class,role=role,name=name or guid,connected=connected~=false,dead=dead==true,raceID=raceID}
end
local function bind(slot,guid) if guid then unitData[slot]=unitData[guid] else unitData[slot]=nil end end

GetTime=function() return now end
UnitExists=function(u) return unitData[u]~=nil end
UnitGUID=function(u) return unitData[u] and unitData[u].guid end
UnitName=function(u) return unitData[u] and unitData[u].name end
UnitClass=function(u) local d=unitData[u]; return d and d.class,d and d.class end
UnitRace=function(u) local d=unitData[u]; return d and "Race",d and "RACE",d and d.raceID end
UnitGroupRolesAssigned=function(u) return unitData[u] and unitData[u].role end
UnitIsConnected=function(u) return unitData[u] and unitData[u].connected end
UnitIsDeadOrGhost=function(u) return unitData[u] and unitData[u].dead end
GetSpecialization=function() return playerSpec and 1 end
GetSpecializationInfo=function() return playerSpec end
GetInspectSpecialization=function() return 0 end
IsSpellKnown=function(id) return knownSpells[id] end
IsPlayerSpell=function() return false end
GetSpellCooldown=function(id) local c=spellCooldowns[id]; if c then return c[1],c[2],1 end; return 0,0,1 end
GetSpellInfo=function(id) return "Spell "..id end
UnitAura=function(u,index,filter)
    local list=(auraData[u] and auraData[u][filter]) or {}
    local a=list[index]
    if not a then return nil end
    return a.name or ("Aura "..a.id),nil,nil,nil,a.duration or 0,a.expiration or 0,a.caster,nil,nil,a.id
end

local function frameStub()
    local f={}
    function f:RegisterEvent() end
    function f:SetScript() end
    return f
end
CreateFrame=function() return frameStub() end
BFAKeyAlerts={db={enabled=true},L=function(_,key,...)
    if key=="GC_REMAINING_FMT" then return "remaining "..tostring((...)) end
    return key
end}
dofile("GroupCooldowns.lua")
local tracker=BFAKeyAlerts.GroupCooldowns

local function eq(actual,expected,label)
    assert(actual==expected,label..": expected "..tostring(expected)..", got "..tostring(actual))
end
local function find(entries,id)
    for _,entry in ipairs(entries) do if entry.spellID==id then return entry end end
end

unit("disc","PRIEST","HEALER","Dawn")
unit("mage","MAGE","DAMAGER","Frost")
unit("hunter","HUNTER","DAMAGER","Track")
unit("pal","PALADIN","DAMAGER","Light")
unit("tank","WARRIOR","TANK","Wall")
bind("party1","disc"); bind("party2","mage"); bind("party3","hunter"); bind("party4","pal")
tracker:RefreshRoster()

-- Remote priest remains unconfirmed until inspect or an exclusive observed spell.
local initialHealer=tracker:GetHealerCooldownStates()
eq(find(initialHealer,33206).state,"unknown","unknown healer cooldown at challenge start")
local mageDefs=tracker:GetDefensiveStates("party2")
eq(find(mageDefs,45438).state,"unknown","unobserved remote defensive is unknown")

-- One cast plus its target aura is a single cooldown use; timer decays from observed time.
now=10
tracker:HandleCombatLog("SPELL_CAST_SUCCESS","disc",nil,33206)
local readyAt=tracker.members.disc.healer[33206].readyAt
now=10.2
tracker:HandleCombatLog("SPELL_AURA_APPLIED","disc","pal",33206)
eq(tracker.members.disc.healer[33206].readyAt,readyAt,"cast/aura deduplication")
now=20
local discState=find(tracker:GetHealerCooldownStates(),33206)
eq(discState.state,"cooldown","observed healer cooldown")
eq(math.ceil(discState.remaining),170,"healer timer counts down")

-- Roster slot changes retain history by GUID.
bind("party1",nil); bind("party3","disc"); bind("party1","hunter")
tracker:RefreshRoster()
eq(tracker.members.disc.healer[33206].readyAt,readyAt,"GUID history survives roster movement")

-- Ice Block observation, aura state, reset spell, then no fabricated ready state after a reset.
now=30
tracker:HandleCombatLog("SPELL_CAST_SUCCESS","mage",nil,45438)
now=30.1
tracker:HandleCombatLog("SPELL_AURA_APPLIED","mage","mage",45438)
eq(find(tracker:GetDefensiveStates("party2"),45438).state,"active","active defensive aura")
now=39
tracker:HandleCombatLog("SPELL_AURA_REMOVED","mage","mage",45438)
now=40
tracker:HandleCombatLog("SPELL_AURA_REMOVED","mage","mage",45438)
tracker:HandleCombatLog("SPELL_CAST_SUCCESS","mage",nil,235219)
local ice=find(tracker:GetDefensiveStates("party2"),45438)
eq(ice.state,"ready","Cold Snap resets Ice Block cooldown")
eq(ice.remaining,0,"reset cooldown has no remaining time")

-- Feign Death stays active with no guessed recovery start until the aura ends.
now=50
tracker:HandleCombatLog("SPELL_CAST_SUCCESS","hunter",nil,5384)
tracker:HandleCombatLog("SPELL_AURA_APPLIED","hunter","hunter",5384)
local feign=find(tracker:GetDefensiveStates("party1"),5384)
eq(feign.state,"active","Feign Death aura active")
eq(feign.remaining,nil,"Feign Death does not start cooldown at cast")
now=55
tracker:HandleCombatLog("SPELL_AURA_REMOVED","hunter","hunter",5384)
feign=find(tracker:GetDefensiveStates("party1"),5384)
eq(feign.state,"cooldown","Feign Death cooldown begins when aura ends")
eq(math.ceil(feign.remaining),30,"Feign Death recovery timer")

-- Seeing Feign Death after joining a group must also wait for aura removal.
tracker.members.hunter.defensive[5384]=nil
auraData.party1={HELPFUL={{id=5384,duration=360,expiration=415,caster="party1"}}}
tracker:ScanUnitAuras("party1")
feign=find(tracker:GetDefensiveStates("party1"),5384)
eq(feign.state,"active","visible Feign Death aura")
eq(feign.remaining,nil,"visible Feign Death aura has no recovery timer yet")
auraData.party1={HELPFUL={}}
tracker:ScanUnitAuras("party1")
eq(find(tracker:GetDefensiveStates("party1"),5384).remaining,30,"missing removal event falls back to aura scan")

-- Forbearance blocks Divine Shield, and dead/offline units never read as ready.
auraData.party4={HARMFUL={{id=25771,name="Forbearance"}}}
tracker:RefreshRoster()
eq(find(tracker:GetDefensiveStates("party4"),642).state,"blocked","Forbearance blocks Divine Shield")
unitData.mage.dead=true; tracker:RefreshRoster()
eq(find(tracker:GetDefensiveStates("party2"),45438).state,"blocked","dead member cannot display ready")
unitData.mage.dead=false; unitData.mage.connected=false; tracker:RefreshRoster()
eq(find(tracker:GetDefensiveStates("party2"),45438).state,"blocked","offline member cannot display ready")
unitData.mage.connected=true

-- Remote tank starts unknown; observed cooldown is estimated, then retained by GUID.
unit("tank","WARRIOR","TANK","Wall")
bind("party4","tank"); tracker:RefreshRoster()
eq(find(tracker:GetTankStates("party4"),871).state,"unknown","remote tank starts unknown")
now=100
tracker:HandleCombatLog("SPELL_CAST_SUCCESS","tank",nil,871)
eq(find(tracker:GetTankStates("party4"),871).state,"cooldown","tank cooldown from combat log")
eq(math.ceil(find(tracker:GetTankStates("party4"),871).remaining),240,"tank remaining time")

-- Local tank cooldowns use the local API; solo tank spec is enough to identify the panel.
unit("me","PALADIN","NONE","Solo")
bind("player","me"); playerSpec=66; knownSpells[31850]=true; spellCooldowns[31850]={100,40}
tracker:RefreshRoster()
local localTank=find(tracker:GetTankStates("player"),31850)
eq(localTank.state,"cooldown","local tank spell uses GetSpellCooldown")
eq(localTank.remaining,40,"local API cooldown remaining")
eq(localTank.estimated,false,"local API state is factual")

-- A remote two-charge defensive cannot be declared unavailable from one observed use.
unit("bear","DRUID","TANK","Bear"); bind("party4","bear"); tracker:RefreshRoster()
tracker:HandleCombatLog("SPELL_CAST_SUCCESS","bear",nil,61336)
local survival=find(tracker:GetTankStates("party4"),61336)
eq(survival.state,"unknown","remote second charge is unknown")
eq(survival.remaining,180,"observed recharge remains visible")
playerSpec=104;unitData.me.class="DRUID";knownSpells[61336]=true
GetSpellCharges=function(id) if id==61336 then return 1,2,100,180 end end
tracker:RefreshRoster()
survival=find(tracker:GetTankStates("player"),61336)
eq(survival.state,"ready","local remaining charge is ready")
eq(survival.charges,1,"local charge count uses API")
playerSpec=66;unitData.me.class="PALADIN"
bind("party4","tank")

-- A challenge/world reset clears learned timers instead of declaring all abilities ready.
tracker:ResetObservations(); tracker:RefreshRoster()
eq(find(tracker:GetTankStates("player"),31850).state,"cooldown","local API remains authoritative after reset")
eq(find(tracker:GetDefensiveStates("party2"),45438).state,"unknown","remote reset returns to unknown")
print("group_cooldowns: timing, deduplication, reset, unknown, roster, dead/offline and local tank API passed")
