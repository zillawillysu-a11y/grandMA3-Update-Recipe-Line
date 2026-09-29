# Project Handoff

## Current Goal

Native-validate the fixed red/white pulse cadence and determine why selected source Preset 2.14 is not a final tracked assignment at Cue 7.

## Current Working State

v0.7.1.19 is deployed to the confirmed Update Plugin folder. Pulse timing now uses grandMA3 station uptime (`Time()`) instead of Lua process CPU time, with 200 ms per color phase aligned to the 100 ms refresh loop. Resolver/reference semantics and marker colors are unchanged from v0.7.1.18.

## Latest Real-World User Test

v0.7.1.18 red/white pulse and brighter purple tracking frame look correct. For Cue 7, selected Group 79 `5 Corner`, Old Values shows source Cue 0.5 / Preset 2.14, while `Selected source ref` reports `NOT_FINAL_ASSIGNMENT`. The user observes the Preset shown at Cue 0.5 but gone by Cue 1. This places 2.14 before Pool lookup, but does not yet prove which later row/barrier removes it. Resolver was `INCONCLUSIVE`, with 12 partial refs and blocker Preset 25.9003; 7/12 marker overlays were created, with Preset 1.1 separately missing at `POOL_TILE_FOUND`.

The 17:32:32 recording was sampled at 60 fps. The Group 79 border alternated with observed runs from about 0.10 s to 0.48 s, instead of the intended 0.125 s phase.

## Verified Facts

- 182 show-candidate checks pass; synthetic result remains 4 refs, missing=0, extra=0. All 87 workflow assertions pass.
- Lua 5.4, deterministic build check twice, Lua/XML parse, and `git diff --check` pass.
- v0.7.1.18 deployment was backed up at `C:\tmp\show-rel-backups\Update-Plugin-before-v0.7.1.19-20260929`; hashes matched before replacement.
- v0.7.1.19 source/deployed SHA256: Lua `D2CF03ED6C0CF88B97079A32EDFE087C646102A4208D9996A2328692551C00F7`; XML `8A1D1A1B2932FFC24FCACB65263145CDB261EB4DE7F3982965E17CF0FAE8405D`; unchanged diagnostic Lua `A00C30DD8DCEFF67ACE8F86E423E70742AF74F85FBB4FA2E38514E5AF15B2191`.

## Current Problem

2.14 is excluded from the resolver's final assignments; this is not a Pool tile lookup failure. Need distinguish a newer Recipe lane from an unsafe barrier or a scope mismatch. v0.7.1.19 pulse behavior is not yet native-tested.

## Important Files

- `RecipeTracking_Inspector.lua`
- `tests/show_candidate.lua`
- `tests/recipe_workflow.lua`
- `recipe_update_diagnostic.xml`

## Current Branch / Commit

Worktree is detached at `fix: stabilize recipe marker pulse timing`, matching `origin/qwen`. v0.7.1.19 is deployed and pushed; native validation is pending.

## Exact Next Action

Reload v0.7.1.19 and verify the title. Observe Group 79 for at least 3 seconds; each red or white phase should last about 0.2 s with a stable rhythm. With the same fixture and Group 79 Position context, compare the panel at Cue 0.5, Cue 1, and Cue 7, recording `Source Cue`, `Old Values`, and `Selected source ref` at each cue. Do not treat local validation as native success.
