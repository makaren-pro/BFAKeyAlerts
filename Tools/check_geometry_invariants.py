from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[1]
policy = (ROOT / "GeometryPolicies.lua").read_text(encoding="utf-8")
engine = (ROOT / "Engine.lua").read_text(encoding="utf-8")
plates = (ROOT / "Nameplates.lua").read_text(encoding="utf-8")
active = (ROOT / "ActiveCasts.lua").read_text(encoding="utf-8")
targets = (ROOT / "Targets.lua").read_text(encoding="utf-8")
sounds = (ROOT / "Sounds.lua").read_text(encoding="utf-8")
stops = (ROOT / "InterruptPolicies.lua").read_text(encoding="utf-8")
core = (ROOT / "Core.lua").read_text(encoding="utf-8")


def entry(name):
    m = re.search(rf'^\s*{re.escape(name)}\s*=\s*\{{([^\n]+)\}},?\s*$', policy, re.M)
    assert m, f"missing geometry policy: {name}"
    return m.group(0)


def has(name, *parts):
    row = entry(name)
    for part in parts:
        assert part in row, f"{name}: missing {part}"


# Shape language: area effects circle, direction/line mechanics square.
for name in (
    "TerrifyingScreech", "MDT253239", "MDT251187", "MDT256882",
    "BarrelSmash", "WhirlpoolofBlades", "Sharknado", "GroundShatter",
    "GoinBananas", "MDT257757", "MDT257747", "BladeBarrage", "MDT257871",
    "WhirlingAxes", "Bladestorm", "ShadowWhirl", "MDT269935",
    "WhirlingSlam", "SteelTempest", "GoreCrash", "SavageTempest",
    "MDT265966", "ConcussionCharge", "SanguineFeast", "RighteousFlames", "DinnerBell",
):
    has(name, 'action = "AOE"', 'plateShape = "CIRCLE"')
for name in ("BrutalBackhand", "PoisonBarrage", "HeavingBlow", "SuppressionFire", "RottenBile", "Indigestion"):
    has(name, 'action = "FRONTAL"', 'plateShape = "SQUARE"')
for name in ("FrenziedCharge", "PowerShot", "Charge", "MDT262804"):
    has(name, 'action = "CLEAVE"', 'plateShape = "SQUARE"')

# Explicit requested MOTHERLODE mechanic.
has("MDT262804", 'center = true', 'sound = true', 'voiceAction = "FRONTAL"')
has("MDT262794", 'action = "TARGETED"', 'voiceAction = "YOU"', 'center = true')
has("DeathLens", 'sources = {131864, 135552}')

# Nameplate renderer must keep geometry and cast-control independent.
assert 'local explicitShape = state.ability and state.ability.plateShape' in plates
assert 'explicitShape == "CIRCLE" or explicitShape == "SQUARE" or explicitShape == "RECTANGLE"' in plates
assert 'if explicitShape == "CIRCLE"' in plates
assert 'elseif normalized == "AOE" then' in plates and 'shape = "CIRCLE"' in plates
assert 'normalized == "FRONTAL" or normalized == "CLEAVE"' in plates and 'shape = "SQUARE"' in plates
assert 'local shape = "RECTANGLE"' in plates
assert 'overlay.controlBadge' in plates and 'text = controlAction == "KICK" and "KICK" or "CC"' in plates
assert 'resolution.controlAction' in plates
assert 'controlAction = controlAction or (ability and ability.ccCapable and "CC" or nil)' in engine
assert 'self:IsGeometryAction(primary) and primary or controlAction or action' in engine

# YOU: delay target truth, and create both center alert and sound after confirmed player GUID.
assert 'personalVoice' in active and 'forceCenter = true' in active
assert 'BKA.Sounds:PlayMechanic("YOU"' in active
assert 'confirmAfterWindow = true' in active
assert '0.40' in targets
assert 'personal and ability and ability.voiceAction == "YOU"' in core

# CC-stop audit: key hard-CC-only casts and geometry+CC coexistence.
for spell in ("257870", "265540", "266209", "267354", "267237", "268202", "270084"):
    assert f'[{spell}]' in stops, f"missing stop policy {spell}"
assert 'CLEAVE = "FRONTAL"' in sounds

# Policy matrix itself must never contradict the requested visual grammar.
for line in policy.splitlines():
    if 'action = "AOE"' in line and 'plateShape' in line:
        assert 'plateShape = "CIRCLE"' in line, line
    if ('action = "FRONTAL"' in line or 'action = "CLEAVE"' in line) and 'plateShape' in line:
        assert 'plateShape = "SQUARE"' in line, line

print("geometry invariants: audited BFA AoE/shape checks passed")
