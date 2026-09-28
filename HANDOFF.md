# Project Handoff

## Current Goal

Fix native v0.7.1.x Group/Recipe Pool markers and selection response in grandMA3 2.5.0.3 without weakening Track A reference gates.

## Current Working State

`C:\tmp\show-rel` is authoritative. v0.7.1.3 is a bounded native diagnostic/UX candidate. It keeps Track A fail closed, canonical Fixture/SubFixture/Cell identity, `frame0` and original theme colors, and the old Cue Phaser scanner disabled. Layout selected members may participate in a Recipe Stored Group without treating the entire Group as selected for UPDATE. A displayed single Recipe's Group may be framed independently while unsafe Values refs stay closed. The panel now shows stage-specific parser failure per blocking ref and stage timings in expanded detail. Offline tests pass.

## Latest Real-World User Test

v0.7.1.2 loaded. One fixture displayed Group 231 but no frame until manual SELECT GROUP, with about two seconds delay. Selecting two Layout fixtures displayed no Group numbers. Panel selection response generally took one to two seconds. No Preset/EFX tiles lit. Native screenshots show `UNSAFE_LANE_ATTRIBUTION_BLOCKER`; blocked refs include ordinary Presets 1.1, 4.4, 21.5 and Phaser 25.9009/25.9010 depending on the selected fixture.

## Verified Facts

- v0.7.1.2 partial Group row admission removed `NO_APPLICABLE_RECIPE`, but metadata still failed closed. The fallback required an exact full Group, so it could not mark Group 231 for one selected fixture. v0.7.1.3 also admits the singular Group already shown by the current Recipe UI.
- Multiple Group labels still depend on native-proven source attribution. Current `scanTracking()` is single-source and its old UI heuristic cannot safely prove two Groups for different selected members. Do not assert those Groups from name/subset overlap.
- The common metadata failure stage for ordinary and Phaser references remains unknown until the visible v0.7.1.3 stage reasons are read. No Preset marker correctness or latency improvement has been native-verified.
- Offline: 86 workflow assertions, 102 show candidate checks, synthetic four refs exact; Lua/XML parse, deterministic build, and diff check pass.

## Current Problem

Actual Cue 8 reference metadata is still rejected; this blocks all Recipe/EFX frames. Group 231 marker and its latency need native retest. Two-Group UI and one-to-two-second selection response remain unresolved. Avoid claiming show-ready.

## Important Files

- `RecipeTracking_Inspector.lua`
- `tools/templates/show_track_a_runtime.lua`
- `tests/show_candidate.lua`
- `recipe_update_diagnostic.xml`

## Current Branch / Commit

Detached `C:\tmp\show-rel` worktree on origin/qwen; inspect Git status and log.

## Exact Next Action

In grandMA3 load v0.7.1.3. Select one fixture whose panel shows Group 231 and check whether Group 231 frames without SELECT GROUP. On Cue 8 capture the visible `Blocked refs:` stage labels; press MORE for the `Timing ms:` line. Check a two-fixture selection. Use these native facts to correct the parser and latency hot stage; do not release guessed Preset refs.
