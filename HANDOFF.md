# Project Handoff

## Current Goal
Purple frames within 0.3 seconds of Cue changes, responsive selection/panel, no crashes. Counts deferred. Commit/push for agent interchange.

## Current Working State
v0.7.0.9 performance checkpoint: 0.1-second loop wait, immediate Cue marker lookup, 32 cooked records per batch with one native read per Part, per-Recipe feature memoization, 32 completed Cue snapshots cached. Render source cache remains removed to preserve Recipe deletion / NEW CONTENT.
REAL-WORLD VALIDATION PENDING. The 0.3-second requirement is NOT yet proven, especially cold inherited effects.

## Latest Real-World User Test
Purple works, but large Shows delay frames 6-10 seconds plus selection blinking and panel updates. Another Show is fast. Supersedes earlier handoff claim of no v0.7.0.7 feedback.

## Verified Facts
82 offline assertions pass, including bounded 1000-channel processing, one native read across batches, and cached revisit publication without reads. Native speed/crash freedom remain unverified.

## Current Problem
Cold tracking needs historical scanning; native GetPresetData cannot be preempted. Render source tracking is synchronous. External edits at identical addresses require restart to invalidate effect cache. New Pool windows require restart while cached grids survive.

## Known Failed Attempts
Four Parts per tick blocked large Shows. Repeated full scans wasted work. Render cache retained deleted Recipe rows and was removed. SheetColor.PhaserText yielded black; GroupedProgLayerActive.Phaser works.

## Important Files
RecipeTracking_Inspector.lua, recipe_update_diagnostic.xml, tests/recipe_workflow.lua, docs/cue-effect-markers.md, AGENTS.md.

## Current Branch / Commit
qwen; checkpoint subject: perf: bound cue effect processing and reuse completed snapshots. Verify HEAD/remote with Git.

## Exact Next Action
Native-test v0.7.0.9 in slow Show: first visit vs revisit, selection, fast Cue changes, plugin stop/restart and Recipe deletion. If cold latency exceeds 0.3 seconds, profile native calls and build invalidated precomputed snapshots. Do not merely shorten sleeps or claim complete.
