local BKA = BFAKeyAlerts

-- Strategic exceptions are keyed by the actual runtime spell ID.  These are
-- intentionally separate from display aliases and ordinary mechanic metadata.
BKA.InterruptPolicies = {
    [257899] = {
        policy = "IGNORE",
        suppressAlert = true,
        npcID = 130012,
        reason = "Painful Motivation damages affected trash while buffing it.",
    },
    [269313] = {
        policy = "IGNORE",
        suppressAlert = false,
        action = "MOVE",
        sound = true,
        npcID = 130653,
        reason = "Final Blast should finish so the Wanton Sapper self-destructs.",
    },
    [267973] = {
        policy = "IGNORE", suppressAlert = false, action = "MOVE", sound = true, npcID = 134137,
        reason = "Wash Away is avoided while interrupts are preserved for Water Blast.",
    },
}

BKA.StopPolicies = {
    [253721] = { dungeon = "Atal'Dazar", npc = "Shieldbearer of Zul", npcID = 127879, spell = "Bulwark of Juju", reason = "Hard CC or displacement prevents the protective zone." },
    [270084] = { dungeon = "King's Rest", npc = "Guard Captain Atu", npcID = 137473, spell = "Jagged Axes", reason = "A well-timed stun stops the uninterruptible cast." },
    [256897] = { dungeon = "Siege of Boralus", npc = "Snarling Dockhound", npcID = 129640, spell = "Clamping Jaws", reason = "The damaging root channel is stopped by stun." },
    [272588] = { dungeon = "Siege of Boralus", npc = "Bilge Rat Cutthroat", npcID = 137511, spell = "Rotting Wounds", reason = "A well-timed stun prevents the disease application." },
    [272888] = { dungeon = "Siege of Boralus", npc = "Ashvane Destroyer", npcID = 137517, spell = "Ferocity", reason = "Hard CC stops the uninterruptible enrage cast." },
    [267237] = { dungeon = "Temple of Sethraliss", npc = "Faithless Subjugator", npcID = 134364, spell = "Drain", reason = "Stun, displacement, or hard CC stops the channel." },
    [267433] = { dungeon = "The MOTHERLODE!!", npc = "Mech Jockey", npcID = 130488, spell = "Activate Mech", reason = "Hard CC prevents the activation." },
    [267354] = { dungeon = "The MOTHERLODE!!", npc = "Hired Assassin", npcID = 134232, spell = "Fan of Knives", reason = "Hard CC stops the uninterruptible area cast." },
    [258317] = { dungeon = "Tol Dagor", npc = "Ashvane Jailer / Officer", spell = "Riot Shield", reason = "Hard CC stops the shield cast." },
    [268202] = { dungeon = "Waycrest Manor", npc = "Deathtouched Slaver", npcID = 135552, spell = "Death Lens", reason = "Hard CC stops the lethal channel." },
    [265540] = { dungeon = "The Underrot", npc = "Fetid Maggot", npcID = 130909, spell = "Rotten Bile", reason = "The uninterruptible frontal can be stopped with stun, displacement, or hard CC." },
    [266209] = { dungeon = "The Underrot", npc = "Fallen Deathspeaker", npcID = 134284, spell = "Wicked Frenzy", reason = "The uninterruptible buff cast can be stopped with stun or displacement." },
    [257870] = { dungeon = "Freehold", npc = "Irontide Buccaneer", npcID = 130011, spell = "Blade Barrage", reason = "The dangerous frontal channel can be stopped with stun or other hard crowd control." },
}

function BKA:GetInterruptPolicy(npcID, spellID)
    local entry = spellID and self.InterruptPolicies[spellID]
    if not entry then
        return nil
    end
    if entry.npcID and npcID and entry.npcID ~= npcID then
        return nil
    end
    return entry
end

function BKA:GetStopPolicy(npcID, spellID)
    local entry = spellID and self.StopPolicies[spellID]
    if not entry then return nil end
    if entry.npcID and npcID and entry.npcID ~= npcID then return nil end
    return entry
end
