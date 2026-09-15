# Project Handoff

## Current Goal
Provide a live-safe Recipe update plugin with automatic current-Cue Phaser highlighting temporarily disabled, while retaining the current Group/Recipe Pool-frame pulse.

## Current Working State
v0.7.0.15 is deployed. It disables the automatic Cue Phaser runtime path behind `ENABLE_CUE_PHASER_MARKERS = false`. The main loop does not enter FAST/MEDIUM/SLOW effect resolution, and Pool markers ignore dormant `activeEffects`. Current Group/Recipe references still pulse. REAL-WORLD VALIDATION PENDING.

## Latest Real-World User Test
The user needs the plugin for a live show and requested removal of all current-Cue Phaser purple markers because that unfinished feature may affect console performance. The Group pulse must remain. v0.7.0.15 has not yet been tested in grandMA3.

## Verified Facts
Lua and XML parse checks pass. 82 offline workflow assertions pass, including no cooked-data read or purple marker while disabled and a continuing non-purple current-Group pulse. All three deployed SHA256 hashes match repository sources. Offline checks cannot prove native performance, marker appearance, or crash freedom.

## Current Problem
Confirm on grandMA3 that v0.7.0.15 shows no Cue-derived purple frames, retains the current Group pulse, and behaves safely in the production Show.

## Known Failed Attempts
v0.7.0.12 produced no purple frames in the user's real Show. Earlier cooked-data work could block large Shows, and the complete Cue Phaser feature remains unfinished. Do not re-enable it for live use until development resumes.

## Important Files
RecipeTracking_Inspector.lua, recipe_update_diagnostic.xml, tests/recipe_workflow.lua, docs/cue-effect-markers.md, AGENTS.md.

## Current Branch / Commit
qwen. Latest checkpoint subject: `chore: disable cue phaser markers for live use`. Never merge to main without explicit user approval.

## Exact Next Action
Import and execute v0.7.0.15 once, then confirm in the production Show that Cue Phaser Pool items never receive purple frames and the currently resolved Group still pulses.
