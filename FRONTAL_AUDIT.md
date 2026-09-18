# BFAKeyAlerts FRONTAL audit

Scope: every record classified as `FRONTAL` before this focused pass in the 10 BFA Season 1 dungeon data files. No world-space cone, facing angle, radar, or inferred geometry is implemented.

Behavior is classified as `SNAPSHOT_TARGET` or `TRACK_TARGET` only when the historical source explicitly distinguishes it. A generic cast warning, `watchfront` cue, tank hit, cone description, or caster's current target is not enough; those records remain `UNKNOWN`.

| Dungeon | NPC | spellID | Spell | frontalBehavior | targetBehavior | target source | evidence | implemented |
|---|---|---:|---|---|---|---|---|---|
| Atal'Dazar | Yazma | 249919 | Skewer | UNKNOWN | NONE | none | Pinned LittleWigs `Yazma.lua:82` warns for the cast but does not encode lock/tracking behavior. | yes |
| Freehold | Irontide Enforcer | 257426 | Brutal Backhand | UNKNOWN | NONE | none | Pinned LittleWigs `Trash.lua:212`; BFA Wowhead confirms a frontal cone but does not establish whether direction locks or tracks. | yes |
| Kings' Rest | Aka'ali the Conqueror | 266237 | Debilitating Backhand | UNKNOWN | NONE | none | Pinned LittleWigs `Council.lua:173`; BFA guide describes a tank hit, not directional lock/tracking semantics. | yes |
| Kings' Rest | King Dazar | 268586 | Blade Combo | UNKNOWN | NONE | none | Pinned LittleWigs `Dazar.lua:132` contains only a generic tank warning. | yes |
| Kings' Rest | Golden Serpent | 265910 | Tail Thrash | UNKNOWN | NONE | none | Pinned LittleWigs `GoldenSerpent.lua:83`; BFA guide confirms a tank hit but not target-direction behavior. | yes |
| Kings' Rest | Spectral Brute | 270514 | Ground Crush | UNKNOWN | NONE | none | Pinned LittleWigs `Trash.lua:599` contains a generic cast warning only. | yes |
| Shrine of the Storm | Brother Ironhull | 267899 | Hindering Cleave | UNKNOWN | NONE | none | Pinned LittleWigs `Council.lua:121`; BFA guide says it is aimed toward the tank but does not establish snapshot versus tracking. | yes |
| Shrine of the Storm | Shrine trash | 268322 | Touch of the Drowned aura | not FRONTAL | DESTINATION | CLEU aura destination | Pinned LittleWigs `Trash.lua:360` handles a dispellable destination aura. The previous `FRONTAL` classification came from “Unending Breath” text and was false. | corrected to DISPEL |
| Temple of Sethraliss | Merektha | 263912 | Noxious Breath | UNKNOWN | NONE | none | Pinned LittleWigs `Merektha.lua:52` and Dungeon Journal confirm a cone/breath but not lock/tracking behavior. | yes |
| Temple of Sethraliss | Sand-Sworn Rider | 272657 | Noxious Breath | UNKNOWN | NONE | none | Pinned LittleWigs `Trash.lua:153`; BFA guide confirms a tank frontal but not lock/tracking behavior. | yes |
| The MOTHERLODE!! | Coin-Operated Crowd Pummeler | 257337 | Shocking Claw | UNKNOWN | NONE | none | Pinned LittleWigs `CrowdPummeler.lua:79` uses `watchfront`; that proves the response, not whether direction locks or tracks. | yes |
| Tol Dagor | Ashvane Marine / Ashvane Spotter | 258864 | Suppression Fire | TRACK_TARGET | SOURCE_TARGET | bounded caster `UNIT_TARGET`, CONFIRMED | Pinned LittleWigs `Trash.lua:149`; BFA Wowhead explicitly says the caster follows the tank's movement to keep the target in the cone. | yes |
| The Underrot | Chosen Blood Matron | 265019 | Savage Cleave cast | UNKNOWN | NONE | none | Pinned LittleWigs `Trash.lua:193` remembers the preceding charge target for a proximity warning, but does not prove cast-direction lock/tracking. | yes |
| The Underrot | Chosen Blood Matron | 265019 | Savage Cleave aura | UNKNOWN | NONE | none for frontal direction | Pinned LittleWigs `Trash.lua:204` confirms the damage recipient only after impact; it is not evidence of cast direction. | yes |
| Waycrest Manor | Soulbound Goliath | 260508 | Crush | UNKNOWN | NONE | none | Pinned LittleWigs `Goliath.lua:94` contains a generic cast warning only. | yes |
| Waycrest Manor | Raal the Gluttonous | 264923 | Tenderize | SNAPSHOT_TARGET | SOURCE_TARGET | bounded caster `UNIT_TARGET`, CONFIRMED | BFA Wowhead says each cone faces the target position at the time that swing begins. | yes |
| Waycrest Manor | Heartsbane Runeweaver | 263905 | Marking Cleave | UNKNOWN | NONE | none | Pinned LittleWigs `Trash.lua:218` contains a generic cast warning only. | yes |

## Totals after correction

- FRONTAL records: 16 (15 unique spell IDs).
- `FIXED_FORWARD`: 0.
- `SNAPSHOT_TARGET`: 1.
- `TRACK_TARGET`: 1.
- `UNKNOWN`: 14.
- False FRONTAL records corrected: 1 (`Touch of the Drowned` aura → `DISPEL`).

Sources:

- LittleWigs pinned commit: `336904bf4a4ac84cce14da1818e4f78506d45e37`.
- BFA Wowhead: Tol Dagor Dungeon Ability Guide; Waycrest Manor Dungeon Ability Guide; the relevant BFA dungeon guides for generic cone/tank-hit confirmation.
