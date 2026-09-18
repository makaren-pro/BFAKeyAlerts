#!/usr/bin/env python3
from pathlib import Path
import re
ROOT = Path(__file__).resolve().parents[1]

def read(name): return (ROOT/name).read_text(encoding='utf-8')

def main():
    config=read('Config.lua'); alerts=read('Alerts.lua'); plates=read('Nameplates.lua')
    options=read('Options.lua'); kicks=read('GroupInterrupts.lua'); key=read('KeystoneHUD.lua')
    toc=read('BFAKeyAlerts.toc'); engine=read('Engine.lua')
    assert 'showAlerts = true' in config and 'showNameplates = true' in config
    assert 'kickTracker = {' in config and 'keystoneHUD = {' in config
    assert 'onlyInKey = false' in config and 'alpha = 0.92' in config and 'showBoltGun = true' not in config
    assert 'BKA.db.showAlerts == false' in alerts
    assert 'soundHandled' in alerts and 'Center visibility is independent from combat audio' in alerts
    assert 'BKA.db.showNameplates == false' in plates
    m=re.search(r'local CIRCLE_SIZE = (\d+)',plates); assert m and int(m.group(1)) >= 100
    assert r'Media\\aoe_ring.tga' in plates and r'Media\\aoe_pulse.tga' in plates
    assert 'MiniMap-TrackingBorder' not in plates
    assert 'overlay.circle.pulseFrame.anim' in plates
    assert (ROOT/'Media'/'aoe_ring.tga').exists() and (ROOT/'Media'/'aoe_pulse.tga').exists()
    assert 'C_NamePlate.GetNamePlates' in plates
    assert 'GroupInterrupts.lua' in toc and 'KeystoneHUD.lua' in toc and 'HUD.lua' in toc
    assert 'self.GroupInterrupts:Initialize()' in engine and 'self.KeystoneHUD:Initialize()' in engine
    for id in [1766,96231,6552,47528,106839,183752,116705,57994,2139,147362,15487,19647]:
        assert f'[{id}]' in kicks
    assert 'COMBAT_LOG_EVENT_UNFILTERED' in kicks and 'SPELL_INTERRUPT' in kicks
    assert 'BOLT_GUN_ITEM_ID' not in kicks and 'boltGun' not in kicks and 'GetItemCooldown' not in kicks
    for id in [853,119381,91800,19577,113724,115078,115750]: assert f'[{id}]' in kicks
    assert 'row.bar:SetValue' in kicks and 'READY' in kicks
    assert 'row.bar:SetHeight(6)' in kicks and 'row:SetHeight(44)' in kicks
    assert 'UTILITY_SLOT_COUNT = 4' in kicks and 'row.spell' not in kicks
    assert 'self.db.kickTracker.showBoltGun = nil' in config and 'boltGunSpellID = nil' in config
    assert 'settings.onlyInKey ~= true or challengeActive()' in kicks and 'f:SetAlpha(settings.alpha)' in kicks
    assert 'UI-ActionButton-Border' not in kicks and 'SetBlendMode("ADD")' not in kicks
    assert 'frame._bkaDragging = true' in read('HUD.lua') and 'if not frame._bkaDragging then' in read('HUD.lua')
    assert 'C_ChallengeMode.GetActiveChallengeMapID' in key
    assert 'GetWorldElapsedTime' in key and 'C_Scenario.GetCriteriaInfo' in key
    assert '({0.6, 0.8, 1})[i]' in key
    assert 'GetDeathCount' in key and 'hideBlizzard' in key
    assert 'BFAKeyAlerts_KeystoneHUD' in key and 'ProtPixelBFA_KeystoneHUD' not in key
    assert 'key = "kicks"' in options and 'key = "keystone"' in options
    assert 'kicksOnlyInKeyCheck' in options and 'kicksAlphaSlider' in options and 'kicksBoltGunCheck' not in options
    assert 'enableAlerts' in options and 'enableNameplates' in options
    assert 'INFESTED_BADGE_SIZE' in plates and 'RefreshInfestedMarker' in plates and 'achievement_nazmir_boss_ghuun' in plates
    affixes=read('Affixes.lua'); assert '[277242] = true' in affixes and 'BKA.Nameplates:RefreshAll()' in affixes and 'GRIEVOUS' not in affixes
    version=read('Version.lua'); assert 'BKA_VERSION' in version and 'latestSeenVersion' in version and 'releases/latest' in version
    assert 'self.notified = true' in version and 'PLAYER_ENTERING_WORLD' in version and 'CHAT_MSG_ADDON' in version
    logger=read('Logger.lua'); assert 'ShowDump' not in logger and 'BuildDump' not in logger and 'BFAKeyAlertsDumpFrame' not in logger
    all_runtime='\n'.join(p.read_text(encoding='utf-8') for p in ROOT.rglob('*.lua') if 'Tools' not in p.parts)
    assert all_runtime.count('db.debug') == 1 and 'self.db.debug = nil' in config and 'soundtest' not in all_runtime and 'CombatTest' not in all_runtime
    runtime='\n'.join(read(name) for name in ['Alerts.lua','HUD.lua','KeystoneHUD.lua','GroupInterrupts.lua','Options.lua','SpecialHandlers.lua'])
    for char in '—–−•·…→←×': assert char not in runtime
    print('ui invariants: enhanced kick/CC/Infested checks passed')

if __name__=='__main__': main()
