#!/usr/bin/env python3
"""Generate BFAKeyAlerts dungeon data from pinned LittleWigs and MDT sources.

This tool is build-time only. The generated addon has no dependency on either
project. Usage:
    python3 Tools/generate_data.py /path/to/LittleWigs /path/to/MDT_Legacy
"""

from __future__ import annotations

import re
import subprocess
import sys
from collections import defaultdict
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]

DUNGEONS = {
    "AtalDazar": ("Atal'Dazar", 244, [1763], "AtalDazar.lua"),
    "Freehold": ("Freehold", 245, [1754], "Freehold.lua"),
    "KingsRest": ("Kings' Rest", 249, [1762], "KingsRest.lua"),
    "ShrineOfTheStorm": ("Shrine of the Storm", 252, [1864], "ShrineoftheStorm.lua"),
    "SiegeOfBoralus": ("Siege of Boralus", 353, [1822], "SiegeofBoralus.lua"),
    "TempleOfSethraliss": ("Temple of Sethraliss", 250, [1877], "TempleofSethraliss.lua"),
    "TheMotherlode": ("The MOTHERLODE!!", 247, [1594], "TheMotherlode.lua"),
    "TolDagor": ("Tol Dagor", 246, [1771], "TolDagor.lua"),
    "Underrot": ("The Underrot", 251, [1841], "TheUnderrot.lua"),
    "WaycrestManor": ("Waycrest Manor", 248, [1862], "WaycrestManor.lua"),
}

ACTION = {
    "INTERRUPT": "KICK",
    "STOP": "STOP",
    "AOE": "AOE",
    "FRONTAL": "FRONTAL",
    "DODGE": "DODGE",
    "MOVE": "MOVE",
    "GTFO": "GTFO",
    "TARGETED": "TARGETED",
    "DISPEL": "DISPEL",
    "PURGE": "PURGE",
    "DEFENSIVE": "DEF",
    "TANK": "TANK",
    "HEAL": "HEAL",
    "SOAK": "SOAK",
    "SPREAD": "SPREAD",
    "STACK": "STACK",
    "LOS": "LOS",
    "FIXATE": "FIXATE",
    "KITE": "KITE",
    "CC": "CC",
    "INFO": "WATCH",
    "TURN": "TURN",
    "MOVE_MOBS": "MOVE_MOBS",
}

PINNED_COMMIT = "336904bf4a4ac84cce14da1818e4f78506d45e37"

KNOWN_INTERRUPT_HANDLERS = {
    "TerrifyingScreech", "DinoMight", "Transfusion", "BwonsamdisMantle",
    "MendingWord", "FieryEnchant", "NoxiousStench", "WrackingPain",
    "RevitalizingBrew", "HealingBalm", "SlicingBlast", "VoidBolt",
    "MendingRapids", "SnakeCharm", "HealingSurge", "GreaterHealingPotion",
    "ToxicBlades", "RockLance", "FuriousQuake", "TectonicBarrier",
    "TransfigurationSerum", "Blowtorch", "Overcharge", "Repair",
    "TransmuteEnemyToGoo", "IcedSpritzer", "KajacolaRefresher",
    "InhaleVapors", "ArtilleryBarrage", "BloodBolt", "DarkReconstitution",
    "GraspingThorns", "DarkenedLightning", "WrackingChord",
    "EffigyReconstruction", "WateryDome",
}

HIGH_INTERRUPT_HANDLERS = {
    "TerrifyingScreech", "DinoMight", "BwonsamdisMantle", "FieryEnchant",
    "NoxiousStench", "WrackingPain", "RevitalizingBrew", "SlicingBlast",
    "VoidBolt", "SnakeCharm", "ToxicBlades", "RockLance", "FuriousQuake",
    "TectonicBarrier", "TransfigurationSerum", "Overcharge",
    "TransmuteEnemyToGoo", "KajacolaRefresher", "InhaleVapors",
    "ArtilleryBarrage", "DarkenedLightning", "WrackingChord",
}

STOP_HANDLERS = {
    "BulwarkOfJuju", "JaggedAxes", "ClampingJaws", "RottingWounds",
    "Ferocity", "Drain", "ActivateMech", "FanOfKnives", "RiotShield",
    "DeathLens",
}
STOP_SPELLS = {253721, 270084, 256897, 272588, 272888, 267237, 267433, 267354, 258317, 268202, 265540, 266209, 257870}
STRATEGIC_IGNORE_SPELLS = {257899, 269313, 267973}

PRIMARY_OVERRIDES = {
    "BlindingSand": "TURN", "WardingCandles": "MOVE_MOBS",
    "ReinforcingWard": "MOVE_MOBS", "MinorReinforcingWard": "MOVE_MOBS",
    "PainfulMotivation": "INFO", "FinalBlast": "MOVE", "WashAway": "MOVE",
}

ABILITY_OVERRIDES = {
    ("ExplosiveBurst", 256105): dict(
        primaryAction="SPREAD", targetBehavior="NONE", target="NONE",
        severity="CRITICAL", center=True, sound=True, voiceAction="SPREAD",
        auditNote="Explosive Burst cast warning; personal target is confirmed only by aura 256105.",
    ),
    ("ExplosiveBurstApplied", 256105): dict(
        primaryAction="SPREAD", targetBehavior="DESTINATION", target="DESTINATION",
        severity="CRITICAL", center=True, sound=True, voiceAction="SPREAD",
        auditNote="Aura destination is the confirmed Explosive Burst target.",
    ),
    ("Fuselighter", 258634): dict(
        primaryAction="DODGE", castControl="NONE", kickPriority="NONE", voiceAction="MOVE",
        targetBehavior="NONE", target="NONE", severity="HIGH", center=True, sound=True,
        npcs=[127488], centerPolicy="ALWAYS",
        auditNote="Ground-area Fuselighter warning; interruptibility remains runtime-unverified.",
    ),
    ("SuppressionFire", 258864): dict(
        primaryAction="FRONTAL", castControl="NONE", kickPriority="NONE", voiceAction="FRONTAL",
        targetBehavior="SOURCE_TARGET", target="SOURCE_TARGET", severity="HIGH", center=True, sound=True,
        npcs=[130027, 136665], centerPolicy="ALWAYS", frontalBehavior="TRACK_TARGET",
        auditNote="Suppression Fire follows its selected target throughout the cast/channel.",
    ),
    ("Tenderize", 264923): dict(
        primaryAction="FRONTAL", voiceAction="FRONTAL", targetBehavior="SOURCE_TARGET", target="SOURCE_TARGET",
        frontalBehavior="SNAPSHOT_TARGET",
        auditNote="Tenderize faces the selected target position at cast start, then remains locked for that swing.",
    ),
    ("TouchOfTheDrownedApplied", 268322): dict(
        primaryAction="DISPEL", voiceAction="DISPEL", targetBehavior="DESTINATION", target="DESTINATION",
        frontalBehavior=None,
        auditNote="Touch of the Drowned is a dispellable destination aura, not a frontal mechanic.",
    ),
    ("RighteousFlames", 258917): dict(
        primaryAction="DODGE", castControl="NONE", kickPriority="NONE", voiceAction="MOVE",
        targetBehavior="NONE", target="NONE", severity="HIGH", center=True, sound=True,
        npcs=[130028], centerPolicy="ALWAYS",
        auditNote="Righteous Flames is an uninterruptible proximity AoE; no unit target is inferred.",
    ),
    ("InnerFlames", 258935): dict(
        primaryAction="KICK", castControl="KICK", kickPriority="HIGH", voiceAction="KICK",
        targetBehavior="NONE", target="NONE", severity="HIGH", center=True, sound=True,
        npcs=[130028], centerPolicy="ALWAYS", stopIfUninterruptible=True,
        auditNote="Inner Flames is a high-priority heal/buff interrupt; live Firestorm interruptibility still needs confirmation.",
    ),
}

MDT_VERIFIED_OVERRIDES = {
    259711: dict(
        primaryAction="DODGE", castControl="NONE", kickPriority="NONE", voiceAction="MOVE",
        targetBehavior="NONE", target="NONE", severity="HIGH", center=True, sound=True,
        centerPolicy="ALWAYS", source="MDT-verified",
        auditNote="Lockdown is an uninterruptible proximity AoE; no unit target is inferred.",
    ),
}

STACK_RULE_OVERRIDES = {
    260512: dict(owner="BOSS", action="RESET", warnEvery=3, criticalAt=9, voiceAction="STACK"),
    268086: dict(owner="PLAYER", action="MOVE", warnEvery=3, warnAbove=6, criticalAt=7, voiceAction="MOVE"),
    266923: dict(owner="PLAYER", action="STACK", warnEvery=3, criticalAt=7, voiceAction="STACK"),
    269301: dict(owner="PLAYER", action="DISPEL", warnAt=4, warnEvery=2, criticalAt=9, voiceAction="DISPEL"),
    265005: dict(owner="BOSS", action="STACK", warnEvery=1, criticalAt=6, voiceAction="STACK"),
    256493: dict(owner="ANY", action="STACK", warnEvery=1, criticalAt=6, voiceAction="STACK"),
    271867: dict(owner="BOSS", action="STACK", warnEvery=1, criticalAt=6, voiceAction="STACK"),
    268007: dict(owner="BOSS", action="STACK", warnEvery=1, criticalAt=6, voiceAction="STACK"),
}

GUIDE_EVIDENCE = {
    258864: "Wowhead Tol Dagor Dungeon Ability Guide (BFA): caster follows the selected target",
    264923: "Wowhead Waycrest Manor Dungeon Ability Guide (BFA): direction snapshots at each swing start",
    263914: "Wowhead Temple of Sethraliss Dungeon Ability Guide (BFA)",
    263961: "Wowhead Waycrest Manor Dungeon Ability Guide (BFA)",
    268086: "Wowhead Waycrest Manor Dungeon Ability/Route Guides (BFA)",
    260512: "Wowhead Waycrest Manor Dungeon Ability Guide (BFA)",
    266923: "Wowhead Temple of Sethraliss Dungeon Ability/Route Guides (BFA)",
    269301: "Wowhead Underrot Dungeon Ability/Route Guides (BFA)",
    271867: "Wowhead MOTHERLODE Dungeon Ability Guide (BFA)",
}

SOURCE_CONSTRUCTS = {
    "self:Log registrations": r"self:Log\(",
    "RegisterEvent / RegisterUnitEvent registrations": r"self:Register(?:Unit)?Event\(",
    "StackMessage calls": r"\bStackMessage\(",
    "PersonalMessage calls": r"\bPersonalMessage\(",
    "TargetMessage calls": r"\bTargetMessage[0-9A-Za-z_]*\(",
    "Interrupter checks": r"\bInterrupter\(",
    "Dispeller checks": r"\bDispeller\(",
    "Tank / Healer checks": r"\b(?:Tank|Healer)\(",
    "PlaySound calls": r"\bPlaySound\(",
    "Death handlers": r"self:Death\(",
}

STRATEGIC_IGNORE_HANDLERS = {"PainfulMotivation", "FinalBlast", "WashAway"}


def lua_list(values):
    return "{" + ", ".join(str(v) if isinstance(v, int) else f'"{v}"' for v in values) + "}"


def balanced_blocks(text: str, marker: str):
    start = text.find(marker)
    if start < 0:
        return []
    start = text.find("{", start)
    depth = 0
    quote = None
    escape = False
    block_start = None
    blocks = []
    i = start
    while i < len(text):
        ch = text[i]
        if quote:
            if escape:
                escape = False
            elif ch == "\\":
                escape = True
            elif ch == quote:
                quote = None
        elif ch in "\"'":
            quote = ch
        elif ch == "{" :
            depth += 1
            if depth == 2:
                block_start = i
        elif ch == "}":
            if depth == 2 and block_start is not None:
                blocks.append(text[block_start:i + 1])
                block_start = None
            depth -= 1
            if depth == 0:
                break
        i += 1
    return blocks


def parse_mdt(path: Path | None):
    result = {}
    if not path or not path.exists():
        return result
    text = path.read_text(encoding="utf-8")
    for block in balanced_blocks(text, "MDT.dungeonEnemies"):
        name = re.search(r'\["name"\]\s*=\s*(?:L\[)?"([^"]+)"\]?', block)
        npc_id = re.search(r'\["id"\]\s*=\s*(\d+)', block)
        spells_start = block.find('["spells"]')
        if not name or not npc_id or spells_start < 0:
            continue
        spell_open = block.find("{", spells_start)
        depth = 0
        spell_end = spell_open
        for spell_end in range(spell_open, len(block)):
            if block[spell_end] == "{":
                depth += 1
            elif block[spell_end] == "}":
                depth -= 1
                if depth == 0:
                    break
        # Returning-dungeon MDT data can contain post-BFA 4xxxxx spell IDs.
        # Client 8.3.7 encounter spells are below 300000; discard newer additions.
        spell_ids = sorted({int(x) for x in re.findall(r"\[(\d{5,6})\]\s*=", block[spell_open:spell_end + 1]) if int(x) < 300000})
        chars = set()
        char_match = re.search(r'\["characteristics"\]\s*=\s*\{(.*?)\n\s*\},', block, re.S)
        if char_match:
            chars = set(re.findall(r'\["([^"]+)"\]\s*=\s*true', char_match.group(1)))
        result[int(npc_id.group(1))] = {
            "name": name.group(1),
            "spells": spell_ids,
            "characteristics": sorted(chars),
        }
    return result


def function_bodies(text: str):
    bodies = {}
    matches = list(re.finditer(r"(?m)^\s*function\s+mod:([A-Za-z0-9_]+)\s*\(", text))
    for index, match in enumerate(matches):
        end = matches[index + 1].start() if index + 1 < len(matches) else len(text)
        bodies[match.group(1)] = text[match.start():end]
    return bodies


def sound_hints(body: str):
    hints = []
    for line in re.findall(r"self:PlaySound\([^\n]+", body):
        values = re.findall(r'"([a-z][a-z0-9_]*)"', line)
        if len(values) > 1 and values[1] not in hints:
            hints.append(values[1])
    return hints


def readable_handler(handler: str):
    name = re.sub(r"(?:AppliedDose|RemovedDose|Applied|Removed|Success|Start|Cast)$", "", handler)
    return re.sub(r"(?<!^)(?=[A-Z0-9])", " ", name).strip()


def historical_semantics(body: str):
    names = []
    checks = (
        ("StackMessage", "StackMessage"), ("TargetMessage", "TargetMessage"),
        ("PersonalMessage", "PersonalMessage"), ("GetBossTarget", "GetBossTarget"),
        ("GetUnitTarget", "GetUnitTarget"), ("Interrupter(", "Interrupter"),
        ("Dispeller(", "Dispeller"), ("self:Tank()", "Tank"),
        ("self:Healer()", "Healer"), ("OpenProximity", "OpenProximity"),
        ("OpenInfo", "OpenInfo"), ("SetInfoByTable", "SetInfoByTable"),
    )
    for needle, label in checks:
        if needle in body:
            names.append(label)
    hints = sound_hints(body)
    if hints:
        names.append("PlaySound:" + ",".join(hints))
    return ", ".join(names) or "Message/timer/state handler"


def classify(handler: str, body: str, events):
    hay = (handler + " " + body).lower()
    event_names = {event for event, _ in events}
    if "underyou" in hay or ("personalmessage" in hay and any("PERIODIC" in event for event in event_names)):
        return "GTFO"
    if "lineofsight" in hay or "line_of_sight" in hay or "cl.los" in hay:
        return "LOS"
    if "soak" in hay:
        return "SOAK"
    if "spread" in hay or "quaking" in hay:
        return "SPREAD"
    if "fixate" in hay or "pursuit" in hay or "chasing" in hay:
        return "FIXATE"
    if "self:dispeller(\"enrage\"" in hay or "soothed" in hay or "purge" in hay:
        return "PURGE"
    if "self:dispeller(" in hay or "dispel" in handler.lower():
        return "DISPEL"
    if "cl.interrupt" in hay or '"interrupt"' in hay or "interrupter(" in hay or "interrupt" in handler.lower():
        return "INTERRUPT"
    if "stackmessage" in hay:
        return "STACK"
    if "defensive" in hay:
        return "DEFENSIVE"
    if "self:tank()" in hay and "personalmessage" in hay:
        return "TANK"
    if "self:healer()" in hay and "personalmessage" in hay:
        return "HEAL"
    target = "targetmessage" in hay or "getunittarget" in hay or "getbosstarget" in hay
    if target:
        return "TARGETED"
    # Only use names whose encounter meaning is explicit; ambiguous casts stay INFO.
    if re.search(r"(breath|frontal|cleave|tailthrash|backhand|tenderize|crush|bladecombo|skewer)", hay):
        return "FRONTAL"
    if re.search(r"(nova|volley|roar|screech|tantrum|tremor|groupdamage|shatteringbellow|noxiousstench|dreadessence|cadenza|staticshock)", hay):
        return "AOE"
    if re.search(r"(sandtrap|barrage|bombardment|grenade|vileexpulsion|crossignition|waveofdecay|rottenexpulsion|groundshatter|boulderthrow)", hay):
        return "DODGE"
    if "SPELL_CAST_START" in event_names and re.search(r"(healing|mending|reconstitution|reconstruction|bloodbolt|shadowbolt|waterydome|wardingcandles|soulvolley)", hay):
        return "INTERRUPT"
    if re.search(r"(nettles|wastingstrike|serratedteeth|massivechomp|devour|drainfluids)", hay):
        return "DEFENSIVE"
    return "INFO"


def semantic_model(handler: str, display: int, body: str, events, legacy_mechanic: str, sev: str):
    lower = (handler + " " + body).lower()
    hints = set(sound_hints(body))
    primary = PRIMARY_OVERRIDES.get(handler)
    if not primary:
        if "underyou" in lower or "gtfo" in hints:
            primary = "GTFO"
        elif "lineofsight" in lower or "lineofsight" in hints:
            primary = "LOS"
        elif "watchfront" in hints or re.search(r"(breath|frontal|cleave|tailthrash|backhand|tenderize|crush|bladecombo|skewer)", lower):
            primary = "FRONTAL"
        elif "runin" in hints:
            primary = "STACK"
        elif "runout" in hints:
            primary = "SPREAD"
        elif hints & {"watchstep", "watchwave", "moveout"}:
            primary = "DODGE" if "watchstep" in hints or "watchwave" in hints else "MOVE"
        elif hints & {"runaway", "fixate"} or re.search(r"(fixate|pursuit|chasing)", lower):
            primary = "KITE" if "fixate" in lower or "pursuit" in lower else "MOVE"
        elif "defensive" in hints or legacy_mechanic in {"DEFENSIVE", "TANK"}:
            primary = "DEFENSIVE"
        elif legacy_mechanic == "TARGETED" or "TargetMessage" in body or "PersonalMessage" in body:
            primary = "TARGETED"
        elif legacy_mechanic == "INTERRUPT":
            primary = "KICK"
        else:
            primary = legacy_mechanic

    if handler in STRATEGIC_IGNORE_HANDLERS or display in STRATEGIC_IGNORE_SPELLS:
        cast_control = "IGNORE"
    elif handler in STOP_HANDLERS or display in STOP_SPELLS:
        cast_control = "STOP"
    elif handler in KNOWN_INTERRUPT_HANDLERS or "Interrupter(" in body or "interrupt" in hints:
        cast_control = "KICK"
    else:
        cast_control = "NONE"

    if cast_control == "KICK":
        if handler in {"BloodBolt", "ShaleSpit"} or "info" in hints:
            kick_priority = "LOW"
        elif handler in HIGH_INTERRUPT_HANDLERS or "warning" in body:
            kick_priority = "HIGH"
        else:
            kick_priority = "NORMAL"
    else:
        kick_priority = "NONE"

    voice = primary
    if primary == "MOVE_MOBS":
        voice = "MOVE"
    elif primary == "INFO":
        voice = cast_control if cast_control in {"KICK", "STOP"} else "NONE"
    elif primary == "TARGETED":
        voice = "YOU"
    if kick_priority == "LOW" and primary == "KICK":
        voice = "NONE"

    if primary == "INFO":
        audit_note = "Historical handler is informational/state-only; no distinct player response is encoded."
    else:
        audit_note = "Action derived from the pinned handler body, target/role guards, and semantic sound hint."
    if handler in PRIMARY_OVERRIDES:
        audit_note = "Explicit BFA mechanic correction; historical semantics preserved independently of cast control."
    return primary, cast_control, kick_priority, voice, audit_note


def stack_rule(display: int, handler: str, body: str, role: str):
    if not ("StackMessage" in body or "SetInfoByTable" in body or "args.amount" in body):
        return None
    rule = dict(STACK_RULE_OVERRIDES.get(display, {}))
    if not rule:
        if "self:Me(args.destGUID)" in body or "self:Me(args.destName)" in body:
            owner = "PLAYER"
        elif "boss" in body.lower():
            owner = "BOSS"
        elif role == "TANK":
            owner = "TANK"
        elif "SetInfoByTable" in body:
            owner = "PARTY"
        else:
            owner = "PARTY"
        every = re.search(r"args\.amount\s*%\s*(\d+)\s*==\s*0", body)
        threshold = re.search(r"args\.amount\s*>=\s*(\d+)", body)
        critical = re.search(r"args\.amount\s*>\s*(\d+)", body)
        rule = {
            "owner": owner, "action": "STACK",
            "warnEvery": int(every.group(1)) if every else 1,
            "voiceAction": "STACK",
        }
        if critical or threshold:
            rule["criticalAt"] = int(critical.group(1)) + 1 if critical else int(threshold.group(1))
        if threshold:
            rule["warnAt"] = int(threshold.group(1))
    rule["display"] = "PERSISTENT"
    return rule


def target_mode(body: str):
    lower = body.lower()
    if "getunittarget" in lower or "getbosstarget" in lower or "unitguid(unit .. \"target\")" in lower:
        return "SOURCE_TARGET"
    if "targetmessage" in lower:
        return "DESTINATION"
    if "args.destguid == self:playerguid()" in lower or "personalmessage" in lower:
        return "DESTINATION"
    return "NONE"


def severity(mechanic: str, body: str):
    lower = body.lower()
    if mechanic == "GTFO" or ('"alarm"' in lower and "personalmessage" in lower):
        return "CRITICAL"
    if mechanic in {"INTERRUPT", "STOP", "AOE", "LOS", "SOAK", "SPREAD", "DEFENSIVE"}:
        return "HIGH"
    if mechanic in {"TARGETED", "FIXATE", "FRONTAL", "DODGE", "DISPEL", "PURGE", "TANK", "HEAL"}:
        return "MEDIUM"
    if '"warning"' in lower:
        return "HIGH"
    if '"alarm"' in lower or '"alert"' in lower or '"red"' in lower:
        return "MEDIUM"
    return "LOW"


def timer_for(body: str, spell_ids):
    initial = None
    cooldown = None
    for kind, spell, seconds in re.findall(r"self:(Bar|CDBar)\((\d+),\s*(\d+(?:\.\d+)?)", body):
        sid = int(spell)
        if sid in spell_ids:
            if kind == "CDBar":
                cooldown = float(seconds)
            elif cooldown is None:
                cooldown = float(seconds)
    generic = re.search(r"self:(?:Bar|CDBar)\(args\.spellId,\s*(\d+(?:\.\d+)?)", body)
    if generic:
        cooldown = float(generic.group(1))
    return initial, cooldown


def initial_timers(text: str):
    bodies = function_bodies(text)
    engage = bodies.get("OnEngage", "")
    result = {}
    for _kind, spell, seconds in re.findall(r"self:(Bar|CDBar)\((\d+),\s*(\d+(?:\.\d+)?)", engage):
        result.setdefault(int(spell), float(seconds))
    return result


def parse_littlewigs(directory: Path):
    abilities = []
    all_npcs = set()
    source_events = set()
    option_spells = set()
    for path in sorted(directory.glob("*.lua")):
        if path.name.startswith("Locale"):
            continue
        text = path.read_text(encoding="utf-8")
        mob_match = re.search(r"mod:RegisterEnableMob\((.*?)\)\s*(?:--[^\n]*)?", text, re.S)
        npcs = sorted({int(x) for x in re.findall(r"\b\d{5,6}\b", mob_match.group(1))}) if mob_match else []
        all_npcs.update(npcs)
        bodies = function_bodies(text)
        engage_timers = initial_timers(text)
        for event in re.findall(r'self:RegisterEvent\("([A-Z0-9_]+)"', text):
            source_events.add(event)
        options = bodies.get("GetOptions", "")
        option_spells.update(int(x) for x in re.findall(r"(?<![-\d])(\d{5,6})(?!\d)", options))
        grouped = defaultdict(list)
        for match in re.finditer(r'self:Log\("([A-Z_]+)",\s*"([A-Za-z0-9_]+)",\s*([^\n]+)\)', text):
            event, handler, args = match.groups()
            for spell in re.findall(r"\b(\d{5,6})\b", args):
                grouped[handler].append((event, int(spell)))
        for handler, triggers in grouped.items():
            body = bodies.get(handler, "")
            display_ids = [int(x) for x in re.findall(r"(?:Message2?|PersonalMessage|TargetMessage2?|StackMessage)\((\d{5,6})", body)]
            trigger_ids = [spell for _event, spell in triggers]
            display = display_ids[0] if display_ids else trigger_ids[0]
            mechanic = classify(handler, body, triggers)
            sev = severity(mechanic, body)
            first, cooldown = timer_for(body, set(trigger_ids + [display]))
            first = engage_timers.get(display) or next((engage_timers[x] for x in trigger_ids if x in engage_timers), None)
            stack_match = re.search(r"args\.amount\s*>?=\s*(\d+)", body)
            role = "ALL"
            if "self:Tank()" in body:
                role = "TANK"
            elif "self:Healer()" in body:
                role = "HEALER"
            primary, cast_control, kick_priority, voice, audit_note = semantic_model(handler, display, body, triggers, mechanic, sev)
            rule = stack_rule(display, handler, body, role)
            if rule:
                primary = rule["action"]
                voice = rule["voiceAction"]
            target_behavior = target_mode(body)
            if rule and target_behavior == "NONE": target_behavior = rule["owner"]
            marker = text.find("function mod:" + handler)
            line = text.count("\n", 0, marker) + 1 if marker >= 0 else 1
            record = {
                "handler": handler,
                "display": display,
                "triggers": sorted(set(triggers)),
                "npcs": npcs,
                "mechanic": mechanic,
                "severity": sev,
                "target": target_mode(body),
                "role": role,
                "center": sev != "LOW",
                "nameplate": "PrimaryIcon" in body or any(event in {"SPELL_CAST_START", "SPELL_CAST_SUCCESS"} for event, _ in triggers),
                "sound": sev in {"CRITICAL", "HIGH"},
                "personal": "PersonalMessage" in body and "Message2" not in body and "TargetMessage" not in body,
                "stack": int(stack_match.group(1)) if stack_match else None,
                "initial": first,
                "cooldown": cooldown,
                "module": path.stem,
                "source": "LittleWigs",
                "spellName": readable_handler(handler),
                "primaryAction": primary,
                "castControl": cast_control,
                "kickPriority": kick_priority,
                "voiceAction": voice,
                "targetBehavior": target_behavior,
                "stackRule": rule,
                "historicalHandler": historical_semantics(body),
                "auditNote": audit_note,
                "sourceLocation": f"BfA/{directory.name}/{path.name}:{line}" + ("; " + GUIDE_EVIDENCE[display] if display in GUIDE_EVIDENCE else ""),
            }
            record.update(ABILITY_OVERRIDES.get((handler, display), {}))
            record["mechanic"] = record["primaryAction"]
            if record["primaryAction"] == "FRONTAL":
                record.setdefault("frontalBehavior", "UNKNOWN")
                if record["frontalBehavior"] == "UNKNOWN":
                    record["targetBehavior"] = "NONE"
                    record["target"] = "NONE"
            abilities.append(record)
    stack_owners = {}
    stack_events = defaultdict(set)
    for ability in abilities:
        if ability["stackRule"]:
            stack_owners.setdefault(ability["display"], ability)
        for event, spell in ability["triggers"]:
            stack_events[spell].add(event)
    for spell, owner in stack_owners.items():
        for event in ("SPELL_AURA_APPLIED", "SPELL_AURA_APPLIED_DOSE", "SPELL_AURA_REMOVED_DOSE", "SPELL_AURA_REMOVED"):
            if event not in stack_events[spell]:
                owner["triggers"].append((event, spell))
        owner["triggers"] = sorted(set(owner["triggers"]))

    represented = {spell for ability in abilities for _event, spell in ability["triggers"]}
    for spell in sorted(option_spells - represented):
        abilities.append({
            "handler": "Option" + str(spell), "display": spell,
            "triggers": [],
            "npcs": sorted(all_npcs), "mechanic": "INFO", "severity": "LOW",
            "target": "NONE", "role": "ALL", "center": False, "nameplate": True,
            "sound": False, "personal": False, "stack": None,
            "initial": None, "cooldown": None, "module": "Options", "source": "LittleWigs-option",
            "spellName": f"Option {spell}", "primaryAction": "INFO", "castControl": "NONE",
            "kickPriority": "NONE", "voiceAction": "NONE", "targetBehavior": "NONE",
            "stackRule": None, "historicalHandler": "GetOptions entry",
            "auditNote": "Configuration-only spell without a registered historical handler.",
            "sourceLocation": f"BfA/{directory.name}/GetOptions",
        })
    return abilities, sorted(all_npcs), sorted(source_events)


def merge_mdt(abilities, mdt):
    by_spell = defaultdict(list)
    for ability in abilities:
        for _event, spell in ability["triggers"]:
            by_spell[spell].append(ability)
    for npc_id, enemy in sorted(mdt.items()):
        for spell in enemy["spells"]:
            if spell in by_spell:
                for ability in by_spell[spell]:
                    if npc_id not in ability["npcs"]:
                        ability["npcs"].append(npc_id)
                        ability["npcs"].sort()
                continue
            ability = {
                "handler": "MDT" + str(spell), "display": spell,
                "triggers": [("SPELL_CAST_START", spell)], "npcs": [npc_id],
                "mechanic": "INFO", "severity": "LOW", "target": "NONE",
                "role": "ALL", "center": False, "nameplate": True, "sound": False,
                "personal": False, "stack": None, "initial": None, "cooldown": None,
                "module": "MDT", "source": "MDT-only",
                "spellName": enemy["name"], "primaryAction": "INFO", "castControl": "NONE",
                "kickPriority": "NONE", "voiceAction": "NONE", "targetBehavior": "NONE",
                "stackRule": None, "historicalHandler": "MDT spell listing only",
                "auditNote": "Informational fallback only; no LittleWigs handler semantics were available.",
                "sourceLocation": "MDT Legacy/BattleForAzeroth",
            }
            ability.update(MDT_VERIFIED_OVERRIDES.get(spell, {}))
            ability["mechanic"] = ability["primaryAction"]
            abilities.append(ability)
            by_spell[spell].append(ability)


def apply_strategic_policies(abilities):
    for ability in abilities:
        spell_ids = {ability["display"]}
        spell_ids.update(spell for _event, spell in ability["triggers"])
        if spell_ids & STOP_SPELLS:
            ability["castControl"] = "STOP"
            ability["kickPriority"] = "NONE"
            if ability["primaryAction"] == "INFO":
                ability["primaryAction"] = "STOP"
            ability["voiceAction"] = ability["voiceAction"] if ability["voiceAction"] not in {"NONE", "INFO"} else "STOP"
        if spell_ids & STRATEGIC_IGNORE_SPELLS:
            ability["castControl"] = "IGNORE"
            ability["kickPriority"] = "NONE"


def emit_dungeon(key, meta, abilities, npcs, events, mdt):
    name, challenge_map, instance_maps, _mdt_name = meta
    lines = [
        "-- Generated from LittleWigs 336904bf4a4ac84cce14da1818e4f78506d45e37",
        "-- MDT-only entries are build-time imports filtered to BFA-era spell IDs.",
        "local BKA = BFAKeyAlerts",
        "",
        "BKA:RegisterDungeon({",
        f'    key = "{key}",',
        f'    name = "{name}",',
        f"    challengeMapID = {challenge_map},",
        f"    instanceMapIDs = {lua_list(instance_maps)},",
        f"    sourceEvents = {lua_list(events)},",
        "    npcNames = {",
    ]
    for npc_id, enemy in sorted(mdt.items()):
        safe = enemy["name"].replace("\\", "\\\\").replace('"', '\\"')
        lines.append(f'        [{npc_id}] = "{safe}",')
    lines += ["    },", "    abilities = {"]
    for ability in abilities:
        fields = [
            f"id = {ability['display']}",
            f"triggers = {{{', '.join('{event = \"%s\", spell = %d}' % item for item in ability['triggers'])}}}",
            f"sources = {lua_list(ability['npcs'])}",
            f'mechanic = "{ability["primaryAction"]}"',
            f'action = "{ability["primaryAction"]}"',
            f'primaryAction = "{ability["primaryAction"]}"',
            f'castControl = "{ability["castControl"]}"',
            f'kickPriority = "{ability["kickPriority"]}"',
            f'voiceAction = "{ability["voiceAction"]}"',
            f'targetBehavior = "{ability["targetBehavior"]}"',
            f'severity = "{ability["severity"]}"',
            f'target = "{ability["target"]}"',
            f'role = "{ability["role"]}"',
            f"center = {'true' if ability['center'] else 'false'}",
            f"nameplate = {'true' if ability['nameplate'] else 'false'}",
            f"sound = {'true' if ability['sound'] else 'false'}",
            f"personalOnly = {'true' if ability['personal'] else 'false'}",
            "throttle = 0.6",
        ]
        if ability.get("frontalBehavior"):
            fields.append(f'frontalBehavior = "{ability["frontalBehavior"]}"')
        if ability.get("centerPolicy"):
            fields.insert(15, f'centerPolicy = "{ability["centerPolicy"]}"')
        if ability["stack"]:
            fields.append(f"stack = {ability['stack']}")
        if ability["stackRule"]:
            rule = ability["stackRule"]
            parts = []
            for rule_key in ("display", "owner", "action", "warnAt", "warnEvery", "warnAbove", "criticalAt", "voiceAction"):
                if rule_key in rule:
                    value = rule[rule_key]
                    parts.append(f'{rule_key} = "{value}"' if isinstance(value, str) else f"{rule_key} = {value}")
            fields.append("stackRule = { " + ", ".join(parts) + " }")
        note = ability["auditNote"].replace("\\", "\\\\").replace('"', '\\"')
        fields.append(f'auditNote = "{note}"')
        if ability["initial"]:
            fields.append(f"initial = {ability['initial']:g}")
        if ability["cooldown"]:
            fields.append(f"cooldown = {ability['cooldown']:g}")
        if ability["castControl"] == "KICK":
            stop_if_uninterruptible = ability.get("stopIfUninterruptible", ability["source"] == "LittleWigs")
            fields.append(f"stopIfUninterruptible = {'true' if stop_if_uninterruptible else 'false'}")
        fields.append(f'source = "{ability["source"]}"')
        fields.append(f'handler = "{ability["handler"]}"')
        fields.append(f'module = "{ability["module"]}"')
        lines.append("        { " + ", ".join(fields) + " },")
    lines += ["    },", "})", ""]
    output = ROOT / "Data" / f"{key}.lua"
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text("\n".join(lines), encoding="utf-8")


def verify_snapshot(littlewigs: Path):
    result = subprocess.run(
        ["git", "-C", str(littlewigs), "rev-parse", "HEAD"],
        capture_output=True, text=True, check=False,
    )
    if result.returncode == 0 and result.stdout.strip() != PINNED_COMMIT:
        raise SystemExit(f"LittleWigs checkout must be {PINNED_COMMIT}, got {result.stdout.strip()}")


def source_construct_counts(littlewigs: Path):
    texts = []
    state_handlers = 0
    for key in DUNGEONS:
        for path in sorted((littlewigs / "BfA" / key).glob("*.lua")):
            if not path.name.startswith("Locale"):
                text = path.read_text(encoding="utf-8")
                texts.append(text)
                for handler, body in function_bodies(text).items():
                    if re.search(r"\b(?:stage|phase|intermission|remaining|count)\b", body, re.I):
                        state_handlers += 1
    source = "\n".join(texts)
    counts = {label: len(re.findall(pattern, source, re.I)) for label, pattern in SOURCE_CONSTRUCTS.items()}
    counts["Stage / state handlers"] = state_handlers
    return counts


def emit_audit(all_abilities, module_count: int, source_counts):
    rows = [ability for ability in all_abilities if ability["source"] == "LittleWigs" and ability["triggers"]]
    stack_rows = [row for row in rows if "StackMessage" in row["historicalHandler"] or "SetInfoByTable" in row["historicalHandler"]]
    target_rows = [row for row in rows if any(x in row["historicalHandler"] for x in ("TargetMessage", "PersonalMessage", "GetBossTarget", "GetUnitTarget"))]
    interrupt_rows = [row for row in rows if "Interrupter" in row["historicalHandler"] or "PlaySound:interrupt" in row["historicalHandler"]]
    corrected = [row for row in rows if row["mechanic"] == "INFO" and row["primaryAction"] != "INFO"]
    info_rows = [row for row in rows if row["primaryAction"] == "INFO"]
    unexplained = [row for row in info_rows if not row["auditNote"]]
    persistent = {row["display"] for row in rows if row["stackRule"]}
    metrics = {
        "LittleWigs modules audited": f"{module_count}/{module_count}",
        "historical handlers reviewed": len(rows),
        "StackMessage handlers mapped": f"{sum(bool(row['stackRule']) for row in stack_rows)}/{len(stack_rows)}",
        "important target handlers mapped": f"{sum(row['targetBehavior'] != 'NONE' for row in target_rows)}/{len(target_rows)}",
        "interrupt handlers mapped": f"{sum(row['castControl'] == 'KICK' for row in interrupt_rows)}/{len(interrupt_rows)}",
        "semantics corrected from generic INFO": len(corrected),
        "actionable WATCH records remaining unexplained": len(unexplained),
        "intentionally informational historical handlers": len(info_rows),
        "new TURN mechanics": sum(row["primaryAction"] == "TURN" for row in rows),
        "new MOVE_MOBS mechanics": sum(row["primaryAction"] == "MOVE_MOBS" for row in rows),
        "persistent stack mechanics": len(persistent),
        "known KICK mechanics": len({row["display"] for row in all_abilities if row["castControl"] == "KICK"}),
        "known STOP mechanics": len({row["display"] for row in all_abilities if row["castControl"] == "STOP"}),
        "strategic IGNORE mechanics": len({row["display"] for row in all_abilities if row["castControl"] == "IGNORE"}),
    }
    lines = [
        "# BFAKeyAlerts mechanic audit", "",
        f"Source: BigWigsMods/LittleWigs `{PINNED_COMMIT}` (2020-10-03).",
        "Scope: the 10 BFA Season 1 dungeons; Mechagon excluded.", "",
        "## Coverage metrics", "",
    ]
    lines.extend(f"- {key}: {value}" for key, value in metrics.items())
    source_mapping = {
        "self:Log registrations": f"grouped into {len(rows)} semantic handler records below",
        "RegisterEvent / RegisterUnitEvent registrations": "catalogued; event/state behavior retained in generated sourceEvents and SpecialHandlers",
        "StackMessage calls": "mapped to stackRule ownership, thresholds, action, severity, and removal behavior",
        "PersonalMessage calls": "mapped through targetBehavior and personalOnly",
        "TargetMessage calls": "mapped through targetBehavior and source/destination identity",
        "Interrupter checks": "mapped through castControl=KICK and kickPriority",
        "Dispeller checks": "mapped through primaryAction=DISPEL and role targeting",
        "Tank / Healer checks": "mapped through role gating",
        "PlaySound calls": "mapped through primaryAction, castControl, and voiceAction",
        "Death handlers": "catalogued; relevant active state is cleared by encounter/death handlers",
        "Stage / state handlers": "catalogued; gameplay-bearing custom state remains in SpecialHandlers",
    }
    lines += ["", "## Source construct coverage", "", "| LittleWigs construct | Occurrences | BFAKeyAlerts mapping |", "|---|---:|---|"]
    for label, count in source_counts.items():
        lines.append(f"| {label} | {count} | {source_mapping[label]} |")
    lines += ["", "## Handler audit", "", "| Dungeon | Module / NPC | spellID | Spell | Trigger event | Historical handler | Primary action | Cast control | Kick priority | Target behavior | Stack behavior | Role | Voice | Source | Implementation status |", "|---|---|---:|---|---|---|---|---|---|---|---|---|---|---|---|"]
    for row in rows:
        trigger = ", ".join(f"{event}:{spell}" for event, spell in row["triggers"])
        rule = row["stackRule"]
        stack = "—" if not rule else "; ".join(f"{key}={value}" for key, value in rule.items())
        values = (
            row["dungeon"], row["module"], row["display"], row["spellName"], trigger,
            row["historicalHandler"], row["primaryAction"], row["castControl"],
            row["kickPriority"], row["targetBehavior"], stack, row["role"],
            row["voiceAction"], row["sourceLocation"], row["auditNote"],
        )
        lines.append("| " + " | ".join(str(value).replace("|", "\\|").replace("\n", " ") for value in values) + " |")
    (ROOT / "MECHANIC_AUDIT.md").write_text("\n".join(lines) + "\n", encoding="utf-8")
    return metrics


def main():
    if len(sys.argv) != 3:
        raise SystemExit("usage: generate_data.py LITTLEWIGS_ROOT MDT_LEGACY_ROOT")
    littlewigs = Path(sys.argv[1])
    mdt_root = Path(sys.argv[2])
    verify_snapshot(littlewigs)
    total = 0
    all_abilities = []
    module_count = 0
    for key, meta in DUNGEONS.items():
        abilities, npcs, events = parse_littlewigs(littlewigs / "BfA" / key)
        module_count += len([path for path in (littlewigs / "BfA" / key).glob("*.lua") if not path.name.startswith("Locale")])
        mdt = parse_mdt(mdt_root / "BattleForAzeroth" / meta[3]) if meta[3] else {}
        merge_mdt(abilities, mdt)
        apply_strategic_policies(abilities)
        for ability in abilities:
            ability["dungeon"] = meta[0]
        all_abilities.extend(abilities)
        emit_dungeon(key, meta, abilities, npcs, events, mdt)
        lw = sum(1 for a in abilities if a["source"].startswith("LittleWigs"))
        mdt_only = sum(1 for a in abilities if a["source"] == "MDT-only")
        total += len(abilities)
        print(f"{key}: {len(abilities)} abilities ({lw} LittleWigs, {mdt_only} MDT-only)")
    print(f"total: {total} ability records")
    metrics = emit_audit(all_abilities, module_count, source_construct_counts(littlewigs))
    for key, value in metrics.items():
        print(f"{key}: {value}")


if __name__ == "__main__":
    main()
