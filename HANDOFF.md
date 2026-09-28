# Project Handoff

## Current Goal

Keep the Group UI and marker pulse responsive while the native-proven Track A resolver reads references; resolve remaining ordinary metadata blockers.

## Current Working State

`C:\tmp\show-rel` is authoritative. v0.7.1.5 candidate incrementally resumes Track A in a coroutine, yielding after each native `GetPresetData` and `GetUIChannels` read. Pulse color now follows elapsed-time schedule; Pool discovery remains bounded at 500 ms unless dirty. `SELECT GROUP` preserves metadata caches while recomputing changed selection context. The panel shows exact ordinary header failure fields and reports per-slice plus total resolver time. Marker look, canonical member keys, and fail-closed reference gate remain.

## Latest Real-World User Test

v0.7.1.4 native screenshot: Group 231 frame appears immediately, then pulse and SELECT GROUP response pause about 600 ms. Tracking measured 82 ms, resolver 612 ms. Parser reports ordinary `PresetMode` mismatch for Preset 1.1 and channel-shape failure for Preset 25.9010. The user confirms the pulse waits until resolver finishes. No v0.7.1.5 native test yet.

## Verified Facts

- The synchronous resolver was inside the UI loop. v0.7.1.5 now yields at native metadata reads; offline coroutine test proves it resumes to the same synthetic final ref.
- `SELECT GROUP` previously set `forceRefresh`, clearing reference and member caches. It now preserves those caches for this action.
- Flash rate previously toggled once per loop, so synchronous work changed its cadence. v0.7.1.5 schedules 250 ms color toggles and 500 ms Pool lookups.
- Offline validation: 86 workflow checks, 107 show candidate checks, synthetic four refs exact; Lua/XML parse, deterministic build, and diff check pass.
- Native ordinary mode disagreement is still unresolved. v0.7.1.5 reports `pm` and object `PresetMode` values in its bounded blocker detail; do not remove consistency checks without examining them.

## Current Problem

Need test coroutine scheduling, SELECT GROUP cache behavior, pulse cadence, and detailed ordinary parser reasons in grandMA3. Recipe refs remain fail closed; two-Group context is not yet solved.

## Important Files

- `RecipeTracking_Inspector.lua`
- `tools/templates/show_track_a_runtime.lua`
- `tests/show_candidate.lua`
- `tests/recipe_workflow.lua`
- `recipe_update_diagnostic.xml`

## Current Branch / Commit

Detached `C:\tmp\show-rel` worktree on origin/qwen; inspect Git status and log.

## Exact Next Action

Deploy/test v0.7.1.5 on the same Cue 8 selection. Verify steady pulse while resolver is pending and SELECT GROUP does not restart all reference reads. Capture `Blocked refs:` and expanded `Timing ms:` including resolver slice/total values. Use those details to finish parsing ordinary native metadata.
