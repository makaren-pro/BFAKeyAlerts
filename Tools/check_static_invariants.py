#!/usr/bin/env python3
"""Focused static checks for BFAKeyAlerts runtime invariants.

These checks validate source/data contracts without pretending to execute the WoW API.
"""

from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
DATA = ROOT / "Data"


def records():
    for path in sorted(DATA.glob("*.lua")):
        for line_number, line in enumerate(path.read_text(encoding="utf-8").splitlines(), 1):
            if line.lstrip().startswith("{ id = "):
                yield path, line_number, line


def find(spell_id, handler=None):
    needle = f"id = {spell_id},"
    for path, line_number, line in records():
        if needle in line and (handler is None or f'handler = "{handler}"' in line):
            return path, line_number, line
    raise AssertionError(f"missing record {spell_id} {handler or ''}".strip())


def require(line, *parts):
    missing = [part for part in parts if part not in line]
    assert not missing, f"missing {missing}: {line}"


def main():
    core = (ROOT / "Core.lua").read_text(encoding="utf-8")
    active = (ROOT / "ActiveCasts.lua").read_text(encoding="utf-8")
    engine = (ROOT / "Engine.lua").read_text(encoding="utf-8")
    alerts = (ROOT / "Alerts.lua").read_text(encoding="utf-8")
    nameplates = (ROOT / "Nameplates.lua").read_text(encoding="utf-8")
    stacks = (ROOT / "Stacks.lua").read_text(encoding="utf-8")
    affixes = (ROOT / "Affixes.lua").read_text(encoding="utf-8")
    options = (ROOT / "Options.lua").read_text(encoding="utf-8")
    generator = (ROOT / "Tools" / "generate_data.py").read_text(encoding="utf-8")
    all_data = list(records())

    # A/B/N: NONE and unknown casts never use the caster's current target for YOU.
    assert "cast.targetGUID, cast.targetName, cast.targetIsPlayer = targetContext(unit)" not in active
    assert 'cast.targetBehavior ~= "SOURCE_TARGET"' in active
    assert 'targetConfidence == "CONFIRMED"' in alerts and 'targetConfidence == "CONFIRMED"' in nameplates
    mdt = [line for _, _, line in all_data if 'source = "MDT-only"' in line]
    mdt_derived = [line for _, _, line in all_data if 'source = "MDT-only"' in line or 'source = "MDT-verified"' in line]
    assert mdt and all('targetBehavior = "NONE"' in line for line in mdt)
    assert all('target = "NONE"' in line for line in mdt)
    assert '"targetBehavior": "NONE"' in generator and '"target": "NONE"' in generator

    # C/D/F: verified SOURCE_TARGET acquisition locks the resolved target to the cast.
    assert 'cast.targetBehavior ~= "SOURCE_TARGET"' in active
    assert 'cast.targetConfidence = "CONFIRMED"' in active
    assert "cast.targetLocked = not dynamic" in active
    assert "if cast.targetLocked and not dynamic then return end" in active

    # E: documented CLEU destination paths explicitly confirm destination identity.
    assert "ConfirmDestination" in active and 'targetConfidence = destinationConfirmed and "CONFIRMED"' in engine

    # G/J: named Tol Dagor corrections.
    lockdown = find(259711, "MDT259711")[2]
    require(lockdown, 'primaryAction = "AOE"', 'voiceAction = "MOVE"', 'targetBehavior = "NONE"',
            'severity = "HIGH"', "center = true", "nameplate = true", 'plateShape = "CIRCLE"')
    righteous = find(258917, "RighteousFlames")[2]
    require(righteous, 'sources = {130028}', 'primaryAction = "DODGE"', 'voiceAction = "MOVE"',
            'targetBehavior = "NONE"', "center = true", "nameplate = true")
    inner = find(258935, "InnerFlames")[2]
    require(inner, 'sources = {130028}', 'primaryAction = "KICK"', 'castControl = "KICK"',
            'kickPriority = "HIGH"', "center = true", "nameplate = true")
    suppression = find(258864, "SuppressionFire")[2]
    require(suppression, 'sources = {130027, 136665}', 'primaryAction = "FRONTAL"',
            'targetBehavior = "SOURCE_TARGET"', "center = true", "nameplate = true")

    # K/L/M: center ownership, semantic icons, and personal priority.
    assert 'ability.center and action ~= "CAST"' not in engine
    assert "ShouldCenterAbility" in core and "forceCenter = resolution.center" in active
    assert "INV_Misc_QuestionMark" not in core
    assert "return 7000 + severity" in alerts
    assert 'if ability.primaryAction == "YOU" then ability.primaryAction = "TARGETED" end' in engine
    assert 'local personalVoice = voiceAction == "YOU"' in engine
    assert 'not personalVoice or alertContext.isPlayer' in engine
    assert 'not personalVoice or personal' in active
    assert '[209859]' not in affixes
    assert 'showInfestedAdds' in (ROOT / "Config.lua").read_text(encoding="utf-8")
    assert 'BKA.db.showInfestedAdds ~= false' in nameplates
    assert 'BKA:RoleNotificationAllows(ability, action, isPlayer)' in stacks
    assert 'role = "TANK", tankOnly = true' in affixes
    assert '[274400] = true' in engine and '[260512] = true' in engine
    role_gate = engine.index('local tankOnly = ability.role == "TANK"')
    global_gate = engine.index('if self:IsGlobalAction(action, isPlayer) then return true end', role_gate)
    assert role_gate < global_gate
    assert 'BKA.Nameplates:RefreshAll()' in options
    assert r'Interface\\AddOns\\BFAKeyAlerts\\Media\\aoe_ring.tga' in nameplates
    assert r'Interface\\Minimap\\MiniMap-TrackingBorder' not in nameplates

    mdt_source_target = sum('targetBehavior = "SOURCE_TARGET"' in line for line in mdt)
    center_info = sum(
        'event = "SPELL_CAST_START"' in line and "center = true" in line and 'primaryAction = "INFO"' in line
        for _, _, line in all_data
    )
    source_target = sum('targetBehavior = "SOURCE_TARGET"' in line for _, _, line in all_data)
    primary_you = sum('primaryAction = "YOU"' in line for _, _, line in all_data)
    print("static invariants: 22/22 passed")
    print(f"records={len(all_data)} MDT-derived={len(mdt_derived)} MDT-only={len(mdt)} MDT-only_SOURCE_TARGET={mdt_source_target}")
    print(f"center_INFO_CAST_START={center_info} confirmed_SOURCE_TARGET={source_target} primaryAction_YOU={primary_you}")


if __name__ == "__main__":
    main()
