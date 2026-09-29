# Project Handoff

## Current Goal

Native-validate v0.7.1.20's red/white Group pulse cadence. Separately determine why the Cue 0.5 Preset 2.14 source is not retained at Cue 1 / Cue 7.

## Current Working State

v0.7.1.20 is deployed to the confirmed Update Plugin folder. Track A metadata and reverse-lane work now runs in bounded slices: at most 4 metadata rows or 4 fixture members per refresh; incomplete work returns `PENDING` and the host loop yields for 10 ms. Chunk results are combined before publishing; any unsafe chunk keeps the aggregate fail-closed. Pulse colors and 200 ms red/white phase are unchanged.

## Latest Real-World User Test

The user's v0.7.1.19 recordings (17:44:36 and 17:45:18) still show irregular pulsing. Frame sampling of Group 79 found red phases ranging from about 0.08 s to 1.02 s. The recordings show the tool title v0.7.1.19 and the Cue 0.5 → Cue 1 case.

At Cue 0.5 the panel shows Preset 2.14; at Cue 1 it is not a selected final source. This is separate from the pulse scheduler and remains unresolved.

## Verified Facts

- 87 workflow assertions and 187 show-candidate checks pass; synthetic four-ref result remains refs=4, missing=0, extra=0.
- Lua 5.4 test runner, Lua/XML parse, deterministic build check twice, and `git diff --check` pass.
- v0.7.1.19 deployed files were backed up at `C:\tmp\show-rel-backups\Update-Plugin-before-v0.7.1.20-20260929`; all three backup hashes match.
- v0.7.1.20 source/deployed hashes: Lua `6210C0C71F3B23DD52206E33A8F64C1BECCB7B61E5CD3F07F8DBA1122000E669`; XML `E07F9FC8509A02B6C2D61CF419B63081225D24FF25963AF10BFBECBCF4D21A5E`; unchanged diagnostic Lua `A00C30DD8DCEFF67ACE8F86E423E70742AF74F85FBB4FA2E38514E5AF15B2191`.

## Current Problem

The v0.7.1.19 station-clock change did not fix visible cadence because the large reverse-lane pass still blocked a single refresh. v0.7.1.20 breaks metadata and member work into slices; native cadence is not yet verified. A single slow native API call can still delay a frame.

## Important Files

- `RecipeTracking_Inspector.lua`
- `tools/templates/show_track_a_runtime.lua`
- `tests/show_candidate.lua`
- `tests/recipe_workflow.lua`
- `recipe_update_diagnostic.xml`

## Current Branch / Commit

Detached worktree; current change is ready to commit as `fix: yield between Track A resolver batches to stabilize pulse`. Push to `origin/qwen`.

## Exact Next Action

Reload v0.7.1.20 and verify its title. Observe Group 79 `5 Corner` for 3 seconds; red and white phases should each be about 0.2 s and stay even while Cue 0.5 changes to Cue 1. If cadence still stalls, send a short recording. Separately capture `Source Cue`, `Old Values`, and `Selected source ref` at Cue 0.5 and Cue 1 to continue the 2.14 trace. Native validation is pending.
