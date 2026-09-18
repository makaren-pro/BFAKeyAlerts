# BFA Season 1 AoE/nameplate audit — v1.4.1

Goal: a round marker above a unit means **danger centered on/around that caster (or its landing point)**. Ground zones spawned under players, line/cone attacks and unavoidable party-wide damage intentionally do not get the same circle, because that would communicate the wrong geometry.

Sources used for the audit: the pinned BFA-era LittleWigs import already used by the addon, the BFA MDT import, legacy BFA dungeon guides/spell records, and Firestorm runtime observations. Generated `Data/*` stays untouched; corrections live in `GeometryPolicies.lua`.

## Atal'Dazar
Added/confirmed circles for Merciless Assault (`253239`), Leaping Thrash (`251187`), Wild Thrash (`256882`), Toxic Leap and Terrifying Screech. Frenzied Charge remains directional.

## Freehold
Added/confirmed circles for Barrel Smash, Whirlpool of Blades, Shark Tornado, Goin' Bananas (`257756` plus MDT alternate `257757`), Earth Shaker (`257747`), Ground Shatter, Thundering Squall and Blade Barrage (`257870` plus MDT/private-core alternate `257871`).

Retail BFA documentation describes Blade Barrage as a short frontal cone. Firestorm S1 behavior reported in live testing is a spinning melee danger, so the runtime policy deliberately uses the safer circular marker on this server. Keeping both `257870` and `257871` prevents a missing marker when the private core exposes the secondary/damage spell ID instead of the LittleWigs cast ID.

## King's Rest
Added/confirmed circles for Whirling Axes, King Timalji Bladestorm, Shadow Whirl, Seismic Upheaval, Axe Barrage and Channel Lightning. Targeted/directional leaps and barrages retain their existing geometry.

## Shrine of the Storm
Whirling Slam remains circular. Heaving Blow, Mental Assault, Hindering Cleave and Surging Rush remain directional. Slicing Hurricane is a ground zone spawned at a player location, so a circle above the caster would be misleading and is intentionally not used.

## Siege of Boralus
Added circles for Steel Tempest, Gore Crash and Savage Tempest; Banana Rampage remains circular. Savage Tempest's duplicate `SPELL_CAST_SUCCESS` presentation is suppressed so the marker is created once from cast start.

## Temple of Sethraliss
Added Ground Pound (`265966`) as a circular proximity warning. Pyrrhic Blast remains circular. Power Shot, Noxious Breath, Blade Flurry and Cyclone Strike keep directional/cleave semantics.

## The MOTHERLODE!!
Existing circular policies already cover Concussion Charge, Mining Charge, Final Blast and Fan of Knives. Static Pulse/group-wide damage is intentionally not represented as a caster-radius circle.

## Tol Dagor
Existing circular policies cover Lockdown and Righteous Flames. Debilitating Shout is effectively group-wide and therefore not represented as a move-out radius.

## The Underrot
Existing circular policies cover Sanguine Feast and Boundless Rot. Charge, Shockwave, Rotten Bile, Savage Cleave and Vile Expulsion remain directional. Ground pools/death effects are not mislabeled as caster-centered circles.

## Waycrest Manor
Existing circular policies cover Dinner Bell and Shatter. Rotten Expulsion/Retch/Marking Cleave remain directional; party-wide volleys and player-position ground effects do not get a caster-radius circle.

## Renderer fix
`Nameplates.lua` now honors explicit `ability.plateShape` before inferring shape from the action label. This keeps geometry independent from cast-control semantics: an AoE can still be marked as KICK/STOP while retaining its round danger marker.
