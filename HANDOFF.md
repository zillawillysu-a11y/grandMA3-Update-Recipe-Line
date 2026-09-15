# Project Handoff

## Current Goal
Provide a live-safe Recipe update plugin with automatic current-Cue Phaser highlighting disabled, while restoring the selected Group's tracked All/Phaser/Phaser Recipe Pool-frame pulses.

## Current Working State
v0.7.0.16 is deployed. It keeps `ENABLE_CUE_PHASER_MARKERS = false`, so the main loop does not enter FAST/MEDIUM/SLOW Cue-wide effect resolution. It adds a separate cached Recipe-object-only resolver for the currently selected Group, restoring its tracked All, Phaser Recipe, Generator and ancillary Recipe references without cooked `GetPresetData`. REAL-WORLD VALIDATION PENDING.

## Latest Real-World User Test
In v0.7.0.15, the Cue-wide purple markers were removed as requested, but selecting a Group no longer made its All, Phaser and Phaser Recipe items flash. Therefore v0.7.0.15 is unsuccessful for the retained Group-pulse requirement. v0.7.0.16 has not yet been tested in grandMA3.

## Verified Facts
Lua and XML parse checks pass. 85 offline workflow assertions pass. They cover Cue-wide effects remaining disabled, no cooked-data read by the selected-Group resolver, tracked All/Phaser Recipe/Generator references reaching Pool markers, and one cached object-tree scan per Sequence/Cue/Group. All three deployed SHA256 hashes match repository sources. Offline checks cannot prove native performance, marker appearance, or crash freedom.

## Current Problem
Confirm on grandMA3 that v0.7.0.16 restores flashing for the selected Group's All, Phaser and Phaser Recipe items without restoring Cue-wide purple frames or affecting live performance.

## Known Failed Attempts
v0.7.0.15 removed both Cue-wide effects and the Pool marker consumption of `activeEffects`; it preserved only the single resolved Recipe, so other tracked references for the selected Group stopped flashing. Earlier cooked-data work could block large Shows. Do not re-enable Cue-wide scanning for live use.

## Important Files
RecipeTracking_Inspector.lua, recipe_update_diagnostic.xml, tests/recipe_workflow.lua, docs/cue-effect-markers.md, AGENTS.md.

## Current Branch / Commit
qwen. Latest checkpoint subject: `fix: restore selected group recipe pulses`. Never merge to main without explicit user approval.

## Exact Next Action
Import and execute v0.7.0.16, select a known Group, and verify that its All, Phaser and Phaser Recipe items pulse while unrelated current-Cue Phaser items remain unmarked.
