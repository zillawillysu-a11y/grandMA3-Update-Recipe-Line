# Project Handoff

## Current Goal

Validate v0.7.1.35's first performance changes in grandMA3 while preserving v0.7.1.34's confirmed markers. Then reduce multi-slice scheduling delay and diagnose Preset 25.2001's timing rejection from a native read-only dump.

## Current Working State

v0.7.1.35 is deployed to the local Update Plugin directory; XML and both referenced Lua files were copied and source/deployment SHA256 matches passed. Backup: `C:/tmp/update-plugin-pre-0.7.1.35-20260930-121434`. Empty-selection PENDING no longer scans assignments. Group count/signature preparation and handles union happen once per distinct Group per scope call, retaining last-row handle precedence. No new persistent cache, no multi-slice scheduling change, no Phaser parser changes. REAL-WORLD VALIDATION PENDING. The user's original MUSE report remains untracked and untouched.

## Latest Real-World User Test

The user reports v0.7.1.34 restores purple frames and feels about 2× faster. Their largest Show may have over 10× the current fixture count. In an older Show without Phaser Recipes, Phaser markers do not light; the user wonders whether Cue Recipe fade settings are related. This is an unverified hypothesis.

## Verified Facts

- The v0.7.1.34 grid rediscovery fix is real-world confirmed for purple-frame restoration and perceived speed improvement.
- The approximately 2× improvement and >10× scale are user estimates, not measured timings/counts.
- The Phaser-marker issue is reported only for an older Show without Phaser Recipes; the effect of Cue Recipe fades is unknown.
- v0.7.1.35 local checks passed: 89 workflow assertions, 215 Track A candidate checks, 218 checks through the extended probe, Lua/XML parsing, candidate generation consistency, and `git diff --check`.
- Exact Cue-to-purple timing is unknown; the <=300 ms target remains unmeasured.
- At 12,650 synthetic members/slice 250, empty-selection PENDING assignment inspections fell from 318,750 to 0. Advances remain 51 (about 500 ms configured inter-advance wait). This is offline workload evidence, not native timing or a <=300 ms success claim.
- Raw multi-step Presets without PhaserRecipe children can already be admitted; the review reproduces rejection when a nonzero measure field is added. Same-task selection changes require projection invalidation. Details: `docs/scale-phaser-review-2026-09-30.md`.

## Current Problem

First confirm v0.7.1.35 marker equivalence and actual native timing. The one-slice-per-tick wait still limits large Shows. Nonempty-selection projection still uses the original full scan. Preset 25.2001 remains blocked by nonzero measure; obtain native data before changing parser safety rules.

## Known Failed Attempts

v0.7.1.33 lost visible purple frames for Pool 9001–9012; v0.7.1.34 restored them after forcing grid rediscovery on stage/reference changes.

## Important Files

- `RecipeTracking_Inspector.lua`
- `tools/templates/show_track_a_runtime.lua`
- `recipe_update_diagnostic.xml`
- `tests/recipe_workflow.lua`
- `docs/track-a-marker-latency-research.md`
- `docs/scale-phaser-review-2026-09-30.md`
- `tools/review_scale_phaser.py`
- `docs/scale-optimization-0.7.1.35.md`
- `tests/show_candidate.lua`

## Current Branch / Commit

Worktree `C:/tmp/show-rel` is detached; checkpoint to `origin/qwen`: `perf: reduce pending projection and repeated Group scope work`. Verify the current commit and remote against Git. v0.7.1.35 is locally validated and deployed, REAL-WORLD VALIDATION PENDING. Do not merge main automatically.

## Exact Next Action

User imports v0.7.1.35 into grandMA3 and tests empty/general selection, selection changes during resolution, purple/Group frames, Recipe deletion and NEW CONTENT. Compare cold start and warm Cue revisits, using DETAIL/ContextTiming plus Cue-to-purple wall time. If markers remain correct, implement bounded multi-slice scheduling next. For the Phaser BUG, collect a read-only 25.2001 native dump including children, timing types/values, masks and steps before altering validation.
