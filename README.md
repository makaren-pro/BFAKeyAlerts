# BFA Key Alerts

Standalone Mythic+ alerts and UI for Battle for Azeroth 8.3 / Firestorm BFA.

## Features

- Dungeon mechanic alerts for BFA Mythic+ dungeons
- Nameplate warnings and clickable mob alerts
- Group interrupt / hard-CC tracker
- Custom +3 / +2 / +1 keystone timer with forces, bosses, deaths and penalty
- BFA Season 1 affix support, including Infested markers
- Per-action sounds and movable UI

## Install

1. Download the release ZIP.
2. Extract `BFAKeyAlerts` into `World of Warcraft/_retail_/Interface/AddOns/` (or the matching Firestorm BFA AddOns folder).
3. Restart the game or reload the UI.
4. Open settings with `/bka config`.

## Commands

`/bka config` opens settings. The help command in game lists the remaining runtime toggles.

## Updates

World of Warcraft addons cannot make arbitrary HTTPS requests to GitHub. BFA Key Alerts therefore cannot poll GitHub directly from Lua. Version 1.5.0 exchanges its version with other BFA Key Alerts users in your party/raid. If the addon has seen a newer version, it prints one update notice per game session and points to the GitHub releases page.

Repository: https://github.com/makaren-pro/BFAKeyAlerts

## Compatibility

Target interface: `80300` (Battle for Azeroth 8.3). The addon is primarily maintained for Firestorm BFA behavior and APIs.
