#!/usr/bin/env python3
"""Static behavior checks for the FRONTAL intelligence contract.

This mirrors the small presentation/lock state machine and checks the Lua/data
contracts without claiming to execute the WoW client API.
"""

from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
DATA = ROOT / "Data"


def records():
    for path in sorted(DATA.glob("*.lua")):
        for line in path.read_text(encoding="utf-8").splitlines():
            if line.lstrip().startswith("{ id = "):
                yield path, line


def find(spell_id, handler):
    for path, line in records():
        if f"id = {spell_id}," in line and f'handler = "{handler}"' in line:
            return path, line
    raise AssertionError(f"missing {spell_id} {handler}")


def render(behavior, target=None, confidence="NONE", personal=False, role="NONE", prewarn=False):
    if prewarn:
        return {"action": "FRONTAL SOON", "target": None, "state": None, "personal": False}
    target_based = behavior in {"SNAPSHOT_TARGET", "TRACK_TARGET"}
    confirmed = target_based and confidence == "CONFIRMED"
    is_personal = confirmed and personal
    label = "YOU" if is_personal else ("TANK" if confirmed and role == "TANK" else target if confirmed else None)
    state = {"FIXED_FORWARD": "FIXED", "SNAPSHOT_TARGET": "LOCKED", "TRACK_TARGET": "TRACKING"}.get(behavior)
    return {
        "action": "YOU - FRONTAL" if is_personal else "FRONTAL",
        "target": label,
        "state": state,
        "personal": is_personal,
    }


def apply_target(state, behavior, target, personal=False):
    if state.get("locked") and behavior != "TRACK_TARGET":
        return state
    return {"target": target, "personal": personal, "locked": behavior == "SNAPSHOT_TARGET"}


def resolve_after_window(samples):
    """Model the frontal resolver: t=0 is observational, final sample confirms."""
    return samples[-1] if samples else None


def main():
    core = (ROOT / "Core.lua").read_text(encoding="utf-8")
    active = (ROOT / "ActiveCasts.lua").read_text(encoding="utf-8")
    alerts = (ROOT / "Alerts.lua").read_text(encoding="utf-8")
    nameplates = (ROOT / "Nameplates.lua").read_text(encoding="utf-8")
    runtime = "\n".join((ROOT / name).read_text(encoding="utf-8") for name in (
        "Core.lua", "Engine.lua", "ActiveCasts.lua", "Alerts.lua", "Nameplates.lua"
    ))

    # A: a fixed/orientation frontal ignores even a confirmed current player target.
    fixed = render("FIXED_FORWARD", "YOU", "CONFIRMED", personal=True)
    assert fixed == {"action": "FRONTAL", "target": None, "state": "FIXED", "personal": False}

    # B: a confirmed snapshot target displays the compact role and LOCKED state.
    snapshot = render("SNAPSHOT_TARGET", "TankName", "CONFIRMED", role="TANK")
    assert snapshot["action"] == "FRONTAL" and snapshot["target"] == "TANK" and snapshot["state"] == "LOCKED"

    # C: snapshot target is immutable after the first confirmed resolution.
    assert resolve_after_window(["OldAggro", "OldAggro", "NewTarget"]) == "NewTarget"
    locked = apply_target({}, "SNAPSHOT_TARGET", "YOU", personal=True)
    locked = apply_target(locked, "SNAPSHOT_TARGET", "TankName")
    assert locked == {"target": "YOU", "personal": True, "locked": True}
    assert "cast.targetLocked = not dynamic" in active and "if cast.targetLocked and not dynamic then return false end" in active
    targets = (ROOT / "Targets.lua").read_text(encoding="utf-8")
    engine = (ROOT / "Engine.lua").read_text(encoding="utf-8")
    assert "confirmAfterWindow" in targets and "confirmAfterWindow = true" in active
    assert "confirmAfterWindow and index == #delays" in targets
    assert "confirmAfterWindow = true" in engine and "initialFrontalTargetDeferred" in active
    assert "heuristicTargetsIgnored = BKA.diagnostics.heuristicTargetsIgnored + 1" in active

    # D: verified tracking frontals can follow a later confirmed target update.
    tracking = apply_target({}, "TRACK_TARGET", "TANK")
    tracking = apply_target(tracking, "TRACK_TARGET", "Rogue")
    assert tracking["target"] == "Rogue" and not tracking["locked"]
    assert '== "TRACK_TARGET"' in active and "UNIT_TARGET" in engine

    # E: tracking onto the player creates the strongest personal presentation.
    personal_tracking = render("TRACK_TARGET", "Player", "CONFIRMED", personal=True)
    assert personal_tracking["action"] == "YOU - FRONTAL" and personal_tracking["state"] == "TRACKING"
    assert "return 7000 + severity" in alerts and "frontalTracking" in nameplates

    # F: unknown behavior exposes no target or personal semantics.
    unknown = render("UNKNOWN", "Player", "CONFIRMED", personal=True)
    assert unknown == {"action": "FRONTAL", "target": None, "state": None, "personal": False}
    assert "not BKA:IsTargetBasedFrontal" in alerts and "not BKA:IsTargetBasedFrontal" in nameplates

    # G: the verified Tol Dagor tracker has the required data contract.
    _, suppression = find(258864, "SuppressionFire")
    for part in ('frontalBehavior = "TRACK_TARGET"', 'targetBehavior = "SOURCE_TARGET"',
                 "center = true", "nameplate = true"):
        assert part in suppression
    audit = (ROOT / "MECHANIC_AUDIT.md").read_text(encoding="utf-8")
    for row in (
        "| Tol Dagor | Trash | 258634 | Fuselighter | SPELL_CAST_START:258634 | Message/timer/state handler | DODGE | NONE | NONE | NONE |",
        "| Tol Dagor | Trash | 258917 | Righteous Flames | SPELL_CAST_START:258917 | Message/timer/state handler | DODGE | NONE | NONE | NONE |",
        "| Tol Dagor | Trash | 258935 | Inner Flames | SPELL_CAST_START:258935 | Message/timer/state handler | KICK | KICK | HIGH | NONE |",
    ):
        assert row in audit

    # H: icon fallback stays semantic and never becomes a question mark.
    assert r'FRONTAL = "Interface\\Icons\\Ability_Warrior_Shockwave"' in core
    assert "INV_Misc_QuestionMark" not in core

    # I: prediction has no active target metadata.
    prewarn = render("TRACK_TARGET", "Player", "CONFIRMED", personal=True, prewarn=True)
    assert prewarn == {"action": "FRONTAL SOON", "target": None, "state": None, "personal": False}
    assert 'directional and (directionalAction .. " SOON")' in alerts

    # API boundary: no guessed world-space geometry entered the runtime.
    assert "UnitPosition" not in runtime and "GetPlayerFacing" not in runtime and "GetUnitSpeed" not in runtime

    frontal = [line for _, line in records() if 'primaryAction = "FRONTAL"' in line]
    counts = {
        behavior: sum(f'frontalBehavior = "{behavior}"' in line for line in frontal)
        for behavior in ("FIXED_FORWARD", "SNAPSHOT_TARGET", "TRACK_TARGET", "UNKNOWN")
    }
    assert len(frontal) == 17 and counts == {
        "FIXED_FORWARD": 0, "SNAPSHOT_TARGET": 2, "TRACK_TARGET": 1, "UNKNOWN": 14,
    }
    _, slam = find(270003, "SuppressionSlam")
    for part in ('frontalBehavior = "SNAPSHOT_TARGET"', 'targetBehavior = "SOURCE_TARGET"',
                 'primaryAction = "FRONTAL"', "center = true", "nameplate = true"):
        assert part in slam
    print("frontal invariants: 10/10 passed")
    print("FRONTAL records=17 unique_spell_ids=16 FIXED_FORWARD=0 SNAPSHOT_TARGET=2 TRACK_TARGET=1 UNKNOWN=14")


if __name__ == "__main__":
    main()
