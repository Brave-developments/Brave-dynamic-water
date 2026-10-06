# Code Review — Brave-dynamic-water-main

Dynamic water/disaster system: swaps the map water file via `data_file 'WATER_FILE' 'flood.xml'`, token-guarded disaster threads (flood rise/fall), weather tie-in, vehicle submersion damage, ped drowning flags.

## Overview
- [config.lua](config.lua), [client/dynamic-water.lua](client/dynamic-water.lua), [server/main.lua](server/main.lua), [fxmanifest.lua](fxmanifest.lua), `flood.xml`.

## Issues

### Bugs
1. **`Config.Weather` is referenced but never defined.** The code falls back to `'CLEAR'` when the key is missing — an accidental silent default. Add `Config.Weather = 'CLEAR'` (or the intended type) to config so the behavior is explicit.
2. **`Config.Debug = true` shipped.** Debug spams console on every server; default false.
3. **`/flood` client command is available to all players.** It's local-visual only (per the code), but on a roleplay server any player toggling a flood visual is confusion/grief adjacent. ACE-restrict it or remove for release builds.

### Performance
4. **Vehicle submersion sweep every 1.5 s over all vehicles + ped flagging every 5 s.** With busy streets, iterating all vehicles/players at these cadences is noticeable. Use `GetGamePool('CVehicle')` with a distance filter from the flood zone, and skip entirely when water level is at baseline.
5. Token-guarded disaster threads are a good pattern (prevents duplicate floods after restarts) — keep and extend it to the weather loop.

### Code quality
6. **fxmanifest author/description mismatch** (`'tofu-dynamic-water'` vs the Brave/Zindro branding) — rebrand consistently.
7. Water-level transitions are linear interpolation with fixed steps; a config-driven curve would look better, but current behavior is functional.
8. No persistence/scheduling of floods (manual only) — if events are desired, add a scheduler config.

## Improvements / Recommendations
1. Define `Config.Weather`, set `Debug = false`, restrict `/flood`.
2. Gate the sweep loops on active flood state and distance to the zone.
3. Fix the manifest branding; document the `flood.xml` edit path for custom maps (it's a data-file replacement that must match the map's water quads).
4. Add server-side event controls (start/stop flood command with ACE) so admins don't rely on client visuals.

**Severity summary:** Works as designed; issues are a missing config key (#1), default-on debug (#2), public command (#3), and loop cost (#4).
