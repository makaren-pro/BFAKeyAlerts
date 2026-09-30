local BKA = BFAKeyAlerts

local Policies = {
    -- Only these exact, observed aura spell IDs can produce mechanic state.
    auras = {
        -- Tectonic Barrier: a real aura that shields and blocks interrupts only.
        [263215] = { shield = true, interruptImmune = true },
        -- Earth Shield: a real shield; P is allowed only when its live aura says Magic.
        [268709] = { shield = true },
        -- Lightning Shield: display shield state, with no assumed dispel behavior.
        [263246] = { shield = true },
        -- Bone Shield: display only while this exact aura is present.
        [266201] = { shield = true },
        -- Protective Aura: the observed aura reduces damage by 75%.
        [267981] = { damageReduction = 75 },
    },
    -- Earth Shield is a verified Magic buff; require UnitAura's live dispelType too.
    magicPurge = { [268709] = true },
    power = {
        -- Adderis uses the unit's default power type.
        [133379] = { label = "CI_POWER_BADGE" },
        -- Galvazzt uses alternate power (type 10).
        [133389] = { label = "CI_POWER_BADGE", powerType = 10 },
    },
    -- King Dazar's native health bar receives ticks at the observed thresholds.
    healthThresholds = { [136160] = { 80, 60, 40 } },
    -- Black Powder Bomb fixate; max age is only stale-record cleanup, not an aura duration.
    fixateSpellID = 257314,
    fixateMaxAge = 30,
}

BKA.MobStatePolicies = Policies
