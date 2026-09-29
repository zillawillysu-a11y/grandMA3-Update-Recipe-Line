# Project Handoff

## Current Goal

Restore Sequence-wide purple Pool frames while continuing to reduce Cue-to-marker latency.

## Current Working State

v0.7.1.34 invalidates the cached visible PoolLayoutGrid list when the Sequence/Cue context or final marker reference set changes. v0.7.1.33 could keep valid but stale grid handles and miss tiles in newly opened or switched Pools. The resolver/indexing and timing changes from v0.7.1.33 remain in place. v0.7.1.34 is deployed and source/deployed SHA256 hashes match. Backup: `C:/tmp/update-plugin-pre-0.7.1.34-20260930-001236`.

## Latest Real-World User Test

The v0.7.1.33 video shows Cue 4 PROVEN with 13 refs but only 4/13 overlays; Preset 1.1 reports VISIBLE_POOL_TILE_NOT_FOUND. The user reports the purple frames for Pool 9001–9012 no longer appear. This is a real regression relative to the prior video.

## Verified Facts

- v0.7.1.34 local checks pass: 89 workflow assertions, 209 Track A candidate checks, Lua/XML parsing, candidate generation consistency, and `git diff --check`.
- v0.7.1.34 is deployed; real console behavior is not yet verified.
- Previous v0.7.1.33 console timing varied by Cue; the 100–200 ms target remains open.

## Current Problem

The stale Pool-grid cache is the working root-cause hypothesis. The user still needs to confirm that 9001–9012 purple frames return, then check resolver and Pool scan timings.

## Known Failed Attempts

v0.7.1.29 through v0.7.1.33 performance changes did not meet the 100–200 ms goal. v0.7.1.33 also failed the latest purple-frame real-world test.

## Important Files

- `RecipeTracking_Inspector.lua`
- `tools/templates/show_track_a_runtime.lua`
- `recipe_update_diagnostic.xml`
- `tests/recipe_workflow.lua`
- `docs/track-a-marker-latency-research.md`

## Current Branch / Commit

Worktree `C:/tmp/show-rel` contains checkpoint commit `fix: refresh Pool grids when stage references change`, prepared for push to `origin/qwen`. Real-world validation is pending.

## Exact Next Action

Reload v0.7.1.34 on grandMA3 2.5.0.3 and confirm whether purple frames return on Pool 9001–9012; report resolver total and Pool scan timings.
