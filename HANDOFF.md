# Project Handoff

## Current Goal
Keep automatic current-Cue purple highlighting disabled while making selected-Group All/Phaser/Phaser Recipe/Generator pulses survive Generator address aliases and Recall View.

## Current Working State
v0.7.0.17 is deployed. It keeps `ENABLE_CUE_PHASER_MARKERS = false`. Selected-Group references still use the cached Recipe-object-only resolver without cooked `GetPresetData`. Pool grid caching now rejects actually hidden grids after Recall View, triggers one bounded rediscovery, and falls back from command-address lookup to native-object identity for Generator/Random aliases. REAL-WORLD VALIDATION PENDING.

## Latest Real-World User Test
v0.7.0.16 resolves and displays Generator 103 `S2 Verse` in the panel, but its visible Generator Pool tile does not flash. A Phaser tile can flash initially, then stops after the user recalls the View. This proves Recipe resolution works and the remaining failure is Pool tile/grid matching across Generator aliases and View replacement.

## Verified Facts
Lua and XML parse checks pass. 86 offline workflow assertions pass. They cover Cue-wide effects remaining disabled, no cooked-data read by the selected-Group resolver, tracked Group references, cached Recipe scans, valid-but-hidden grid replacement, and Generator native-address fallback. All three deployed SHA256 hashes match repository sources. Offline checks cannot prove native performance, marker appearance, or crash freedom.

## Current Problem
Confirm on grandMA3 that v0.7.0.17 makes Generator 103 flash and restores Phaser flashing shortly after Recall View, without restoring Cue-wide purple frames or causing live-performance issues.

## Known Failed Attempts
v0.7.0.16 cached Pool grids solely by `IsObjectValid`; Recall View can leave old grids valid but hidden. Exact command-address-only matching also misses Generator links represented differently by Recipe and Pool objects. Do not re-enable Cue-wide scanning for live use.

## Important Files
RecipeTracking_Inspector.lua, recipe_update_diagnostic.xml, tests/recipe_workflow.lua, docs/cue-effect-markers.md, AGENTS.md.

## Current Branch / Commit
qwen. Latest checkpoint subject: `fix: refresh pool markers after view recall`. Never merge to main without explicit user approval.

## Exact Next Action
Import/execute v0.7.0.17, verify Generator 103 flashes for the shown Group, then recall the View and confirm its Phaser marker resumes within the next UI refresh.
