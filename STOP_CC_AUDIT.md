# BFA Season 1 STOP/CC audit

Scope: Atal'Dazar, Freehold, King's Rest, Shrine of the Storm, Siege of Boralus, Temple of Sethraliss, The MOTHERLODE!!, Tol Dagor, The Underrot, and Waycrest Manor. Runtime spell IDs are used; entries require historical evidence that a normal interrupt is not the intended counter and hard CC or displacement stops the cast/channel.

| Dungeon | NPC | NPC ID | Spell ID | Spell | Reason | Source type |
|---|---|---:|---:|---|---|---|
| Atal'Dazar | Shieldbearer of Zul | 127879 | 253721 | Bulwark of Juju | Hard CC or displacement prevents the protective zone. | [LittleWigs pinned source](https://github.com/BigWigsMods/LittleWigs/blob/336904bf4a4ac84cce14da1818e4f78506d45e37/BfA/AtalDazar/Trash.lua), [BFA dungeon guide](https://www.wowhead.com/guide/ataldazar-dungeon-strategy-guide) |
| King's Rest | Guard Captain Atu | 137473 | 270084 | Jagged Axes | A well-timed stun stops the uninterruptible cast. | [LittleWigs pinned source](https://github.com/BigWigsMods/LittleWigs/blob/336904bf4a4ac84cce14da1818e4f78506d45e37/BfA/KingsRest/Trash.lua), [BFA dungeon guide](https://www.wowhead.com/guide/kings-rest-dungeon-strategy-guide) |
| Siege of Boralus | Snarling Dockhound | 129640 | 256897 | Clamping Jaws | A stun stops the damaging root channel. | [LittleWigs pinned source](https://github.com/BigWigsMods/LittleWigs/blob/336904bf4a4ac84cce14da1818e4f78506d45e37/BfA/SiegeOfBoralus/Trash.lua), [BFA dungeon guide](https://www.wowhead.com/guide/siege-of-boralus-dungeon-strategy-guide) |
| Siege of Boralus | Bilge Rat Cutthroat | 137511 | 272588 | Rotting Wounds | Timed hard CC prevents the disease application. | [BFA dungeon guide](https://www.wowhead.com/guide/siege-of-boralus-dungeon-strategy-guide), [spell record](https://www.wowhead.com/spell=272588/rotting-wounds) |
| Siege of Boralus | Ashvane Destroyer | 137517 | 272888 | Ferocity | Hard CC stops the uninterruptible enrage cast. | [BFA dungeon guide](https://www.wowhead.com/guide/siege-of-boralus-dungeon-strategy-guide), [spell record](https://www.wowhead.com/spell=272888/ferocity) |
| Temple of Sethraliss | Faithless Subjugator | 134364 | 267237 | Drain | Stun, displacement, or hard CC stops the channel. | [LittleWigs pinned source](https://github.com/BigWigsMods/LittleWigs/blob/336904bf4a4ac84cce14da1818e4f78506d45e37/BfA/TempleOfSethraliss/Trash.lua#L52-L54), [BFA dungeon guide](https://www.wowhead.com/guide/temple-of-sethraliss-dungeon-strategy-guide) |
| The MOTHERLODE!! | Mech Jockey | 130488 | 267433 | Activate Mech | Hard CC prevents the mech activation. | [LittleWigs pinned source](https://github.com/BigWigsMods/LittleWigs/blob/336904bf4a4ac84cce14da1818e4f78506d45e37/BfA/TheMotherlode/Trash.lua#L66-L68), [BFA dungeon guide](https://www.wowhead.com/guide/motherlode-dungeon-ability-guide) |
| The MOTHERLODE!! | Hired Assassin | 134232 | 267354 | Fan of Knives | Hard CC stops the uninterruptible area channel. | [BFA dungeon guide](https://www.wowhead.com/guide/motherlode-dungeon-ability-guide), [spell record](https://www.wowhead.com/spell=267354/fan-of-knives) |
| Freehold | Irontide Buccaneer | 130011 | 257870 | Blade Barrage | Hard CC stops the dangerous frontal channel; geometry remains a square while CC is shown as a badge. | BFA dungeon-guide/runtime audit |
| Tol Dagor | Ashvane Jailer / Ashvane Officer | 135699 / 127486 | 258317 | Riot Shield | Area hard CC stops the protective channel. | [BFA dungeon guide](https://www.wowhead.com/guide/tol-dagor-dungeon-strategy-guide), [spell record](https://www.wowhead.com/spell=258317/riot-shield) |
| Waycrest Manor | Deathtouched Slaver | 135552 | 268202 | Death Lens | Stun or displacement stops the lethal channel. | [LittleWigs pinned source](https://github.com/BigWigsMods/LittleWigs/blob/336904bf4a4ac84cce14da1818e4f78506d45e37/BfA/WaycrestManor/GorakTul.lua#L25-L45), [BFA dungeon guide](https://www.wowhead.com/guide/waycrest-manor-dungeon-strategy-guide) |
| The Underrot | Fetid Maggot | 130909 | 265540 | Rotten Bile | The uninterruptible frontal can be stopped with hard CC/displacement; keep square geometry plus CC badge. | BFA dungeon-guide/runtime audit |
| The Underrot | Fallen Deathspeaker | 134284 | 266209 | Wicked Frenzy | Hard CC/displacement can stop the uninterruptible buff before it lands. | BFA dungeon-guide/runtime audit |

No non-speculative STOP/CC entry was added for Shrine of the Storm in this pass. Freehold and The Underrot now include the verified geometry+CC cases listed above. `Repair` (262554) is deliberately not hardcoded as STOP: early guide text conflicts with later BFA behavior and the pinned LittleWigs revision routes it as an interrupt.

## Strategic no-kick policy

| Dungeon | NPC | NPC ID | Spell ID | Spell | Behavior | BFA-era justification |
|---|---|---:|---:|---|---|---|
| Freehold | Irontide Ravager | 130012 | 257899 | Painful Motivation | FULL IGNORE | It intentionally trades enemy damage for substantial enemy health loss and was used to accelerate large pulls. [BFA dungeon guide](https://www.wowhead.com/guide/freehold-dungeon-strategy-guide) |
| Shrine of the Storm | Temple Attendant | 134137 | 267973 | Wash Away | IGNORE KICK, KEEP MOVE | The area is avoided while interrupts are preserved for Water Blast. [BFA dungeon guide](https://www.wowhead.com/guide/shrine-of-the-storm-dungeon-strategy-guide) |
| The MOTHERLODE!! | Wanton Sapper | 130653 | 269313 | Final Blast | IGNORE KICK, KEEP MOVE | Let the Sapper self-destruct; players move out of the explosion. [LittleWigs pinned source](https://github.com/BigWigsMods/LittleWigs/blob/336904bf4a4ac84cce14da1818e4f78506d45e37/BfA/TheMotherlode/Trash.lua#L85-L87), [BFA dungeon guide](https://www.wowhead.com/guide/motherlode-dungeon-ability-guide) |
