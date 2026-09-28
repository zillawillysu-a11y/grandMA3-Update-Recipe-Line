# Project Handoff

## Current Goal

Fix native Group and Recipe Pool markers plus selection response in grandMA3 2.5.0.3 without weakening Track A reference gates.

## Current Working State

`C:\tmp\show-rel` is authoritative. v0.7.1.4 keeps Track A fail closed, canonical Fixture/SubFixture/Cell identity, original `frame0` theme marker appearance, and Cue Phaser scanner disabled. On selection change the panel and known displayed Recipe Group are painted first; expensive reference resolution runs on the next normal tick with old refs cleared. Ordinary header failures now identify the exact rejected native field or mask. Source/deployed hashes and backup are available from the deployment record and Git. Offline release checks passed.

## Latest Real-World User Test

v0.7.1.3 native screenshot: Group 231 lights, but after a noticeable delay. Panel shows 3 selected fixtures, `UNSAFE_LANE_ATTRIBUTION_BLOCKER`, ordinary Presets 1.1 and 25.9010 rejected at `ORDINARY_CHANNEL_HEADER_UNPROVEN`. Measured native timing: selection 0.0 ms, tracking about 67 ms, group 0.0 ms, resolver about 612 ms, Pool 0.0 ms. User says no further native steps needed for that screenshot.

## Verified Facts

- One Group tile can be framed independently of unresolved Recipe Values. Preset/EFX frames remain absent because resolver returns INCONCLUSIVE.
- The first panel update was delayed by synchronous Track A metadata resolution inside `render()`. v0.7.1.4 defers only that resolution one tick, clears stale refs on the context-change tick, and frames the displayed Group immediately. Native response time is not yet measured after this patch.
- All ordinary header checks still fail closed; v0.7.1.4 replaces a broad stage code with specific field-level reasons. No native rule was relaxed.
- Two-Group source attribution remains unresolved; old `scanTracking()` is single-source and name/subset heuristics cannot safely prove both current Groups.
- Offline: 86 workflow assertions and 105 show candidate checks pass, synthetic four refs exact; Lua/XML parse, deterministic build, and diff check pass.

## Current Problem

Native ordinary header rejection detail is needed to correct the production parser. The two-Group UI and actual Preset/EFX frames still require semantic proof. Do not claim show-ready.

## Important Files

- `RecipeTracking_Inspector.lua`
- `tools/templates/show_track_a_runtime.lua`
- `tests/show_candidate.lua`
- `recipe_update_diagnostic.xml`

## Current Branch / Commit

Detached `C:\tmp\show-rel` worktree on origin/qwen; inspect Git status and log.

## Exact Next Action

Load v0.7.1.4 in grandMA3. Select the same three fixtures in Cue 8 once; check whether Group 231 appears before the resolver settles and capture one panel screenshot showing the new detailed `Blocked refs:` reason. Use that exact native field result to correct metadata parsing; do not guess. Then address the two-Group display and remaining delay with measured evidence.
