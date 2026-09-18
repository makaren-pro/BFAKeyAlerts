from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
special = (ROOT / "SpecialHandlers.lua").read_text(encoding="utf-8")
geometry = (ROOT / "GeometryPolicies.lua").read_text(encoding="utf-8")
core = (ROOT / "Core.lua").read_text(encoding="utf-8")
toc = (ROOT / "BFAKeyAlerts.toc").read_text(encoding="utf-8")

required_rules = {
    "AtalDazar:Transfusion:255577": "SOAK - TAINTED BLOOD",
    "AtalDazar:GildedClaws:255579": "PURGE - CLAWS",
    "Freehold:CritBrew:265088": "SOAK - GOOD CRIT BREW",
    "Freehold:HasteBrew:264608": "SOAK - GOOD HASTE BREW",
    "Freehold:CausticBrew:265168": "MOVE - BAD BREW",
    "KingsRest:EntombApplied:267702": "FIND - COFFIN",
    "ShrineOfTheStorm:WakentheVoid:269097": "KITE - VOID ORBS",
    "ShrineOfTheStorm:AncientMindbenderApplied:269131": "BREAK - MINDBENDER",
    "TempleOfSethraliss:LightningShield:263246": "SWAP - SHIELDED BOSS",
    "TempleOfSethraliss:Conduction:263371": "SPREAD - 8Y",
    "TheMotherlode:FootbombLauncher:269493": "PUNT - BOMBS",
    "TheMotherlode:CallEarthrager:257593": "CC - EARTHRAGER",
    "TolDagor:AzeriteRoundsIncendiary:256198": "DEFENSIVE - FIRE ROUNDS",
    "TolDagor:AzeriteRoundsBlast:256199": "MOVE - KNOCKBACK ROUNDS",
    "TolDagor:Ignition:256970": "MOVE - BARRELS",
    "Underrot:CleansingLight:269310": "SOAK - CLEANSE BLOOD",
    "Underrot:FesteringHarvest:259732": "CLEAR - SPORES",
    "WaycrestManor:FocusingIris:260805": "FOCUS - IRIS BOSS",
    "WaycrestManor:ConsumeAll:264734": "KILL - SERVANTS",
    "SiegeOfBoralus:TidalSurge:276068": "LOS - STATUE",
}
for key, action in required_rules.items():
    assert f'["{key}"]' in special, f"missing boss assist key {key}"
    assert action in special, f"missing action {action}"

for handler in ("GrapeShot", "SurgingRush", "CycloneStrike", "TectonicSmash", "MassiveBlast", "Cinderflame", "VileExpulsion", "CleartheDeck"):
    assert f'{handler} = {{' in geometry, f"missing boss geometry {handler}"
assert 'Indigestion = { action = "FRONTAL"' in geometry
assert 'applyBossAssist(dungeon.key, entry)' in special
assert 'BKA.version = "1.5.0"' in core
assert '## Version: 1.5.0' in toc
print("boss assist invariants: 24/24 passed")
