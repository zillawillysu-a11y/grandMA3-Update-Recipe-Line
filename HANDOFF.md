# Project Handoff

## Current Goal
Diagnose why legacy/cooked Phaser Cues take 6–10 seconds or fail to mark, then design a bounded three-tier resolver. Phaser Recipe direct markers must stay immediate.

## Current Working State
v0.7.0.10 adds low-cost EffectScan instrumentation. It retains the 32-record batch and one native `GetPresetData` read per Part. Each scan logs exact per-Part record count, advances, first resolved reference advance, direct/recovered refs, and failure-mode counters; no additional native calls or full table pass is added.
REAL-WORLD VALIDATION PENDING. No resolver behavior change has been made.

## Latest Real-World User Test
Phaser Recipe Show markers appear almost instantly. A grandMA3 2.3.2.0 Show with many traditional/cooked Phasers takes 6–10 seconds; some legacy Phasers never mark. This persists after v0.7.0.9.

## Verified Facts
83 offline assertions pass. A 1000-channel Part requires exactly 32 advances at the current batch size; at a 0.25-second host cadence that alone is 8 seconds. Existing direct current-Cue Phaser Recipe lookup publishes before any cooked scan. Native latency and actual legacy data shapes remain unverified.

## Current Problem
Complete cooked scan publishes atomically, so a reference found mid-scan is not yet visible. Need measured native evidence before introducing MEDIUM direct legacy metadata recovery and SLOW cooked reconstruction with progressive publishing.

## Known Failed Attempts
Four Parts per tick blocked large Shows. Repeated full scans wasted work. Render cache retained deleted Recipe rows and was removed. SheetColor.PhaserText yielded black; GroupedProgLayerActive.Phaser works. Do not increase the 32-record batch as a substitute for diagnosis.

## Important Files
RecipeTracking_Inspector.lua, recipe_update_diagnostic.xml, tests/recipe_workflow.lua, docs/cue-effect-markers.md, AGENTS.md.

## Current Branch / Commit
qwen; uncommitted v0.7.0.10 diagnostic instrumentation. Last checkpoint subject: perf: bound cue effect processing and reuse completed snapshots.

## Exact Next Action
Deploy v0.7.0.10 and collect `[RecipeTracking][EffectScan]` history for one fast Phaser Recipe Cue, one slow legacy Cue, and one no-marker legacy Cue. Use `channels`, `advances`, `first_ref_advance`, and failure counters to decide FAST/MEDIUM/SLOW implementation; preserve bounded work and add progressive publish only for confirmed Pool refs.
