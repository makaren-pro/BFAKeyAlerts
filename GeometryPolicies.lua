local BKA = BFAKeyAlerts

-- Runtime geometry/response audit for BFA Season 1.  The generated Data/* files
-- stay close to their source imports; this policy layer records verified geometry
-- that those imports cannot reliably infer from LittleWigs/MDT semantics alone.
BKA.GeometryPolicies = {
    byHandler = {
        -- Atal'Dazar
        TerrifyingScreech = { action = "AOE", plateShape = "CIRCLE", severity = "HIGH", castControl = "KICK", kickPriority = "HIGH", voiceAction = "KICK", sound = true },
        FrenziedCharge = { action = "CLEAVE", plateShape = "SQUARE", targetBehavior = "SOURCE_TARGET", frontalBehavior = "SNAPSHOT_TARGET", severity = "HIGH", center = true, sound = true, voiceAction = "YOU" },
        ToxicLeap = { action = "AOE", plateShape = "CIRCLE", targetBehavior = "SOURCE_TARGET", severity = "HIGH", center = true, sound = true, voiceAction = "YOU" },
        MDT253239 = { action = "AOE", plateShape = "CIRCLE", targetBehavior = "SOURCE_TARGET", severity = "HIGH", center = true, sound = true, voiceAction = "YOU", ccCapable = true, note = "Merciless Assault lands in an 8-yard area around the selected player." },
        MDT251187 = { action = "AOE", plateShape = "CIRCLE", severity = "HIGH", center = true, sound = true, voiceAction = "AOE", note = "Leaping Thrash splashes players close to the leap target." },
        MDT256882 = { action = "AOE", plateShape = "CIRCLE", severity = "HIGH", center = true, sound = true, voiceAction = "AOE", note = "Wild Thrash is a close-range whirlwind around the caster." },

        -- Freehold
        Charrrrrge = { action = "CLEAVE", plateShape = "SQUARE", targetBehavior = "SOURCE_TARGET", frontalBehavior = "SNAPSHOT_TARGET", severity = "HIGH", center = true, sound = true, voiceAction = "YOU" },
        GrapeShot = { action = "FRONTAL", plateShape = "SQUARE", severity = "HIGH", role = "ALL", center = true, sound = true, voiceAction = "FRONTAL", frontalBehavior = "FIXED_FORWARD" },
        BarrelSmash = { action = "AOE", plateShape = "CIRCLE", severity = "HIGH", center = true, sound = true, voiceAction = "AOE", note = "Captain Raoul repeatedly hits and knocks back players close to him." },
        WhirlpoolofBlades = { action = "AOE", plateShape = "CIRCLE", severity = "HIGH", center = true, sound = true, voiceAction = "AOE", note = "Captain Jolly's spinning saber damages nearby players." },
        Sharknado = { action = "AOE", plateShape = "CIRCLE", severity = "HIGH", center = true, sound = true, voiceAction = "AOE", note = "Trothak's Shark Tornado is a melee-range danger around the boss." },
        VileBombardment = { action = "AOE", plateShape = "CIRCLE", severity = "HIGH", voiceAction = "AOE" },
        SwiftwindSaber = { action = "CLEAVE", plateShape = "SQUARE", severity = "HIGH", voiceAction = "FRONTAL" },
        CannonBarrage = { action = "AOE", plateShape = "CIRCLE", severity = "HIGH", center = true, sound = true, voiceAction = "AOE" },
        AzeriteGrenade = { action = "AOE", plateShape = "CIRCLE", targetBehavior = "SOURCE_TARGET", severity = "HIGH", center = true, sound = true, voiceAction = "YOU" },
        BoulderThrow = { action = "AOE", plateShape = "CIRCLE", targetBehavior = "SOURCE_TARGET", severity = "HIGH", center = true, sound = true, voiceAction = "YOU" },
        BrutalBackhand = { action = "FRONTAL", plateShape = "SQUARE", severity = "HIGH" },
        GroundShatter = { action = "AOE", plateShape = "CIRCLE", severity = "HIGH", voiceAction = "AOE" },
        GoinBananas = { action = "AOE", plateShape = "CIRCLE", severity = "HIGH", center = true, sound = true, voiceAction = "AOE", ccCapable = true, note = "Close-range spinning danger; hard CC can stop the mob." },
        MDT257757 = { action = "AOE", plateShape = "CIRCLE", severity = "HIGH", center = true, sound = true, voiceAction = "AOE", ccCapable = true, note = "Alternate/impact spell for Goin' Bananas retained by the MDT import." },
        MDT257747 = { action = "AOE", plateShape = "CIRCLE", severity = "HIGH", center = true, sound = true, voiceAction = "AOE", note = "Earth Shaker is a close-range area hit around the Blacktooth Brute." },
        BladeBarrage = { action = "AOE", plateShape = "CIRCLE", severity = "HIGH", center = true, sound = true, voiceAction = "AOE", ccCapable = true, note = "Firestorm S1 runtime override: Buccaneer Blade Barrage behaves as the spinning melee danger players must leave/stop." },
        MDT257871 = { action = "AOE", plateShape = "CIRCLE", severity = "HIGH", center = true, sound = true, voiceAction = "AOE", ccCapable = true, note = "Blade Barrage secondary/damage spell; classify it too because private-server combat logs can expose this ID." },
        ThunderingSquall = { action = "AOE", plateShape = "CIRCLE", severity = "HIGH", castControl = "KICK", kickPriority = "HIGH", voiceAction = "KICK", sound = true },

        -- King's Rest
        SuppressionSlam = { action = "FRONTAL", plateShape = "SQUARE", targetBehavior = "SOURCE_TARGET", frontalBehavior = "SNAPSHOT_TARGET", severity = "HIGH" },
        AxeBarrage = { action = "AOE", plateShape = "CIRCLE", severity = "HIGH" },
        ChannelLightning = { action = "AOE", plateShape = "CIRCLE", severity = "HIGH", voiceAction = "AOE" },
        PoisonBarrage = { action = "FRONTAL", plateShape = "SQUARE", targetBehavior = "SOURCE_TARGET", frontalBehavior = "TRACK_TARGET", severity = "HIGH", voiceAction = "YOU", sound = true },
        GroundCrush = { action = "FRONTAL", plateShape = "SQUARE", severity = "HIGH" },
        WhirlingAxes = { action = "AOE", plateShape = "CIRCLE", severity = "HIGH", center = true, sound = true, voiceAction = "AOE" },
        Bladestorm = { action = "AOE", plateShape = "CIRCLE", severity = "HIGH", center = true, nameplate = true, sound = true, voiceAction = "AOE", note = "King Timalji's Bladestorm is a proximity danger around the moving caster." },
        ShadowWhirl = { action = "AOE", plateShape = "CIRCLE", severity = "HIGH", center = true, sound = true, voiceAction = "AOE", note = "Shadow Whirl damages around its destination." },
        MDT269935 = { action = "AOE", plateShape = "CIRCLE", severity = "HIGH", center = true, sound = true, voiceAction = "AOE", note = "Seismic Upheaval is a large proximity area around the Ghostly Brute." },

        -- Shrine of the Storm
        HeavingBlow = { action = "FRONTAL", plateShape = "SQUARE", targetBehavior = "SOURCE_TARGET", frontalBehavior = "SNAPSHOT_TARGET", severity = "HIGH" },
        WhirlingSlam = { action = "AOE", plateShape = "CIRCLE", severity = "HIGH", voiceAction = "AOE" },
        MentalAssault = { action = "FRONTAL", plateShape = "SQUARE", targetBehavior = "SOURCE_TARGET", frontalBehavior = "SNAPSHOT_TARGET", severity = "HIGH" },
        HinderingCleave = { action = "FRONTAL", plateShape = "SQUARE" },
        SurgingRush = { action = "FRONTAL", plateShape = "SQUARE", severity = "HIGH", center = true, sound = true, voiceAction = "FRONTAL", frontalBehavior = "FIXED_FORWARD" },

        -- Siege of Boralus
        ViscousSlobber = { action = "FRONTAL", plateShape = "SQUARE", targetBehavior = "SOURCE_TARGET", frontalBehavior = "TRACK_TARGET", severity = "HIGH" },
        BananaRampage = { action = "AOE", plateShape = "CIRCLE", severity = "HIGH", voiceAction = "AOE" },
        SlobberKnocker = { action = "FRONTAL", plateShape = "SQUARE", targetBehavior = "SOURCE_TARGET", frontalBehavior = "TRACK_TARGET", severity = "HIGH", voiceAction = "YOU", sound = true },
        MDT257292 = { action = "FRONTAL", plateShape = "SQUARE", targetBehavior = "SOURCE_TARGET", frontalBehavior = "SNAPSHOT_TARGET", severity = "HIGH", center = true, sound = true },
        MDT272874 = { action = "CLEAVE", plateShape = "SQUARE", targetBehavior = "SOURCE_TARGET", frontalBehavior = "SNAPSHOT_TARGET", severity = "HIGH", center = true, sound = true, voiceAction = "YOU" },
        SteelTempest = { action = "AOE", plateShape = "CIRCLE", severity = "HIGH", center = true, sound = true, voiceAction = "AOE", note = "10-yard proximity danger around Sergeant Bainbridge." },
        GoreCrash = { action = "AOE", plateShape = "CIRCLE", severity = "HIGH", center = true, sound = true, voiceAction = "AOE", note = "10-yard proximity danger around Chopper Redhook." },
        SavageTempest = { action = "AOE", plateShape = "CIRCLE", severity = "HIGH", center = true, sound = true, voiceAction = "AOE", note = "Nearby area damage around the Irontide Waveshaper." },
        SavageTempestSuccess = { center = false, nameplate = false, sound = false, note = "Presentation is handled on SPELL_CAST_START; suppress the duplicate success event." },

        -- Temple of Sethraliss
        PowerShot = { action = "CLEAVE", plateShape = "SQUARE", targetBehavior = "SOURCE_TARGET", frontalBehavior = "TRACK_TARGET", severity = "HIGH", center = true, sound = true, voiceAction = "YOU" },
        BladeFlurry = { action = "CLEAVE", plateShape = "SQUARE", severity = "HIGH" },
        NoxiousBreath = { action = "FRONTAL", plateShape = "SQUARE", targetBehavior = "SOURCE_TARGET", frontalBehavior = "SNAPSHOT_TARGET", severity = "HIGH" },
        MDT272655 = { action = "FRONTAL", plateShape = "SQUARE", severity = "HIGH", center = true, sound = true },
        MDT265966 = { action = "AOE", plateShape = "CIRCLE", severity = "HIGH", center = true, sound = true, voiceAction = "AOE", note = "Ground Pound is a large proximity knock-up around the Sandfury Stonefist." },
        PyrrhicBlast = { action = "AOE", plateShape = "CIRCLE", severity = "HIGH", center = true, sound = true, voiceAction = "AOE", ccCapable = true },
        CycloneStrike = { action = "FRONTAL", plateShape = "SQUARE", targetBehavior = "SOURCE_TARGET", frontalBehavior = "SNAPSHOT_TARGET", severity = "HIGH", center = true, sound = true, voiceAction = "FRONTAL" },

        -- The MOTHERLODE!!
        ConcussionCharge = { action = "AOE", plateShape = "CIRCLE", targetBehavior = "SOURCE_TARGET", severity = "HIGH", center = true, sound = true, voiceAction = "YOU" },
        MiningCharge = { action = "AOE", plateShape = "CIRCLE", severity = "HIGH", center = true, voiceAction = "AOE" },
        EchoBlade = { action = "FRONTAL", plateShape = "SQUARE", targetBehavior = "SOURCE_TARGET", frontalBehavior = "TRACK_TARGET", severity = "HIGH" },
        ForceCannon = { action = "FRONTAL", plateShape = "SQUARE", targetBehavior = "SOURCE_TARGET", frontalBehavior = "SNAPSHOT_TARGET", severity = "HIGH" },
        Blowtorch = { action = "FRONTAL", plateShape = "SQUARE", severity = "HIGH" },
        PowerThrough = { action = "FRONTAL", plateShape = "SQUARE", severity = "HIGH" },
        MDT268417 = { action = "FRONTAL", plateShape = "SQUARE", severity = "HIGH", center = true },
        FinalBlast = { action = "AOE", plateShape = "CIRCLE", severity = "HIGH", center = true },
        MDT262804 = { action = "CLEAVE", plateShape = "SQUARE", severity = "HIGH", center = true, sound = true, voiceAction = "FRONTAL", note = "Leech Globule: dark orb travels in a straight line and drains players near its path." },
        MDT262794 = { action = "TARGETED", targetBehavior = "SOURCE_TARGET", severity = "HIGH", center = true, sound = true, voiceAction = "YOU", note = "Mind Lash is a high-damage channel on a selected player." },
        MDT267354 = { action = "AOE", plateShape = "CIRCLE", severity = "HIGH" },
        TectonicSmash = { action = "FRONTAL", plateShape = "SQUARE", severity = "HIGH", center = true, sound = true, voiceAction = "FRONTAL", frontalBehavior = "FIXED_FORWARD" },

        -- Tol Dagor
        SuppressionFire = { action = "FRONTAL", plateShape = "SQUARE", targetBehavior = "SOURCE_TARGET", frontalBehavior = "TRACK_TARGET", severity = "HIGH" },
        RighteousFlames = { action = "AOE", plateShape = "CIRCLE", severity = "HIGH", voiceAction = "AOE" },
        MDT259711 = { action = "AOE", plateShape = "CIRCLE", severity = "HIGH" },
        MassiveBlast = { action = "FRONTAL", plateShape = "SQUARE", severity = "HIGH", center = true, sound = true, voiceAction = "FRONTAL", frontalBehavior = "FIXED_FORWARD" },
        Cinderflame = { action = "FRONTAL", plateShape = "SQUARE", severity = "CRITICAL", center = true, sound = true, voiceAction = "FRONTAL", frontalBehavior = "FIXED_FORWARD" },

        -- The Underrot
        Charge = { action = "CLEAVE", plateShape = "SQUARE", targetBehavior = "SOURCE_TARGET", frontalBehavior = "SNAPSHOT_TARGET", severity = "HIGH", center = true, sound = true, voiceAction = "YOU" },
        Indigestion = { action = "FRONTAL", plateShape = "SQUARE", targetBehavior = "SOURCE_TARGET", frontalBehavior = "TRACK_TARGET", severity = "HIGH", voiceAction = "FRONTAL" },
        CreepingRot = { action = "CLEAVE", plateShape = "SQUARE", severity = "HIGH", voiceAction = "FRONTAL" },
        SanguineFeast = { action = "AOE", plateShape = "CIRCLE", targetBehavior = "SOURCE_TARGET", severity = "HIGH", center = true, sound = true, voiceAction = "YOU" },
        BoundlessRot = { action = "AOE", plateShape = "CIRCLE", severity = "MEDIUM", voiceAction = "AOE" },
        Shockwave = { action = "FRONTAL", plateShape = "SQUARE", targetBehavior = "SOURCE_TARGET", frontalBehavior = "TRACK_TARGET", severity = "HIGH", voiceAction = "FRONTAL" },
        RottenBile = { action = "FRONTAL", plateShape = "SQUARE", severity = "HIGH" },
        SavageCleave = { action = "FRONTAL", plateShape = "SQUARE", severity = "HIGH" },
        MaddeningGaze = { action = "FRONTAL", plateShape = "SQUARE", severity = "HIGH" },
        VileExpulsion = { action = "FRONTAL", plateShape = "SQUARE", severity = "CRITICAL", center = true, sound = true, voiceAction = "FRONTAL", frontalBehavior = "FIXED_FORWARD" },

        -- Waycrest Manor
        RottenExpulsion = { action = "CLEAVE", plateShape = "SQUARE", severity = "HIGH", center = true, voiceAction = "FRONTAL" },
        DinnerBell = { action = "AOE", plateShape = "CIRCLE", severity = "HIGH", castControl = "KICK", kickPriority = "HIGH", voiceAction = "KICK", sound = true },
        Retch = { action = "FRONTAL", plateShape = "SQUARE", targetBehavior = "SOURCE_TARGET", frontalBehavior = "TRACK_TARGET", severity = "HIGH" },
        MarkingCleave = { action = "FRONTAL", plateShape = "SQUARE", targetBehavior = "SOURCE_TARGET", frontalBehavior = "TRACK_TARGET", severity = "HIGH" },
        Shatter = { action = "AOE", plateShape = "CIRCLE", severity = "HIGH", voiceAction = "AOE" },
        MDT265372 = { action = "FRONTAL", plateShape = "SQUARE", targetBehavior = "SOURCE_TARGET", frontalBehavior = "TRACK_TARGET", severity = "HIGH", center = true },
        DeathLens = { sources = {131864, 135552}, note = "Death Lens is cast by Deathtouched Slavers summoned during Gorak Tul; keep both boss-module and actual caster NPC IDs for Firestorm/runtime matching." },
        CleartheDeck = { action = "FRONTAL", plateShape = "SQUARE", severity = "HIGH", center = true, sound = true, voiceAction = "FRONTAL", frontalBehavior = "FIXED_FORWARD" },
    },

    -- Known abilities that are present in the BFA dungeon scripts but absent from
    -- the generated import as a standalone cast entry.
    extras = {
        KingsRest = {
            {
                id = 270503, triggers = {{ event = "SPELL_CAST_START", spell = 270503 }},
                sources = {137487, 135192}, mechanic = "FRONTAL", action = "FRONTAL", primaryAction = "FRONTAL",
                castControl = "NONE", kickPriority = "NONE", voiceAction = "YOU", targetBehavior = "SOURCE_TARGET",
                severity = "HIGH", target = "SOURCE_TARGET", role = "ALL", center = true, nameplate = true,
                plateShape = "SQUARE", sound = true, personalOnly = false, throttle = 0.6,
                frontalBehavior = "SNAPSHOT_TARGET", source = "BFA-audit", handler = "HuntingLeapCast", module = "Trash",
                auditNote = "Hunting Leap channels repeated cones toward the initial selected-player location.",
            },
        },
        SiegeOfBoralus = {
            {
                id = 272711, triggers = {{ event = "SPELL_CAST_START", spell = 272711 }},
                sources = {135245}, mechanic = "FRONTAL", action = "FRONTAL", primaryAction = "FRONTAL",
                castControl = "NONE", kickPriority = "NONE", voiceAction = "FRONTAL", targetBehavior = "SOURCE_TARGET",
                severity = "HIGH", target = "SOURCE_TARGET", role = "ALL", center = true, nameplate = true,
                plateShape = "SQUARE", sound = true, personalOnly = false, throttle = 0.6,
                frontalBehavior = "SNAPSHOT_TARGET", source = "BFA-audit", handler = "CrushingSlamCast", module = "Trash",
                auditNote = "Crushing Slam is an uninterruptible cone/line directed at the tank location.",
            },
        },
    },
}

local function cloneValue(value)
    if type(value) ~= "table" then return value end
    local out = {}
    for key, child in pairs(value) do out[key] = cloneValue(child) end
    return out
end

function BKA:ApplyGeometryExtras(dungeon)
    if not dungeon or dungeon._geometryExtrasApplied then return end
    local extras = self.GeometryPolicies.extras[dungeon.key]
    if extras then
        for _, ability in ipairs(extras) do dungeon.abilities[#dungeon.abilities + 1] = cloneValue(ability) end
    end
    dungeon._geometryExtrasApplied = true
end

function BKA:ApplyGeometryPolicy(ability)
    if not ability then return end
    local policy = self.GeometryPolicies.byHandler[ability.handler]
    if not policy then return end

    if policy.action then
        ability.mechanic = policy.action
        ability.action = policy.action
        ability.primaryAction = policy.action
    end
    for _, field in ipairs({
        "plateShape", "targetBehavior", "frontalBehavior", "severity", "voiceAction",
        "castControl", "kickPriority", "center", "nameplate", "sound", "ccCapable", "role", "sources",
    }) do
        if policy[field] ~= nil then ability[field] = policy[field] end
    end
    if policy.targetBehavior then ability.target = policy.targetBehavior end
    if policy.center == true then ability.centerPolicy = "ALWAYS" end
    if policy.note then ability.geometryAuditNote = policy.note end
end
