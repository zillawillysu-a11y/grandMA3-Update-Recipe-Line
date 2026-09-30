# Project Handoff

## Current Goal

Preserve v0.7.1.34's confirmed marker behavior, improve performance for Shows with over 10× the current fixture count, and diagnose missing Phaser markers in older Shows.

## Current Working State

v0.7.1.34 invalidates the cached visible PoolLayoutGrid list when the Sequence/Cue context or final marker reference set changes. v0.7.1.33 could keep valid but stale grid handles and miss tiles in newly opened or switched Pools. The resolver/indexing and timing changes from v0.7.1.33 remain in place. v0.7.1.34 is deployed and source/deployed SHA256 hashes match. Backup: `C:/tmp/update-plugin-pre-0.7.1.34-20260930-001236`. The user's MUSE report `docs/scale-phaser-followup-2026-09-30.md` remains untracked and byte-for-byte untouched; the review and reproducible offline probe are checkpointed separately.

## Latest Real-World User Test

The user reports v0.7.1.34 restores purple frames and feels about 2× faster. Their largest Show may have over 10× the current fixture count. In an older Show without Phaser Recipes, Phaser markers do not light; the user wonders whether Cue Recipe fade settings are related. This is an unverified hypothesis.

## Verified Facts

- The v0.7.1.34 grid rediscovery fix is real-world confirmed for purple-frame restoration and perceived speed improvement.
- The approximately 2× improvement and >10× scale are user estimates, not measured timings/counts.
- The Phaser-marker issue is reported only for an older Show without Phaser Recipes; the effect of Cue Recipe fades is unknown.
- Local checks passed before deployment: 89 workflow assertions, 209 Track A candidate checks, Lua/XML parsing, candidate generation consistency, and `git diff --check`.
- Exact Cue-to-purple timing is unknown; the <=300 ms target remains unmeasured.
- Review probe confirms 12,650 synthetic members at slice size 250 need 51 advances (500 ms between advances by the configured yield), and empty-selection PENDING scans visit 318,750 assignments. This is offline workload evidence, not native timing.
- Raw multi-step Presets without PhaserRecipe children can already be admitted; the review reproduces rejection when a nonzero measure field is added. Same-task selection changes require projection invalidation. Details: `docs/scale-phaser-review-2026-09-30.md`.

## Current Problem

Performance still needs work at much larger fixture counts. Separately, find why Phaser markers are absent in an older Show with Cue Recipe fade settings. Preserve the confirmed v0.7.1.34 purple-frame behavior; measure cold and cached Cue visits separately.

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

## Current Branch / Commit

Worktree `C:/tmp/show-rel` is detached at the `qwen` checkpoint. Research review checkpoint: `docs: review scale and raw Phaser optimization opportunities`; verify the current commit and `origin/qwen` against Git. Runtime remains v0.7.1.34; no runtime changes or deployment in the review. See `docs/scale-phaser-review-2026-09-30.md` and `tools/review_scale_phaser.py`. REAL-WORLD VALIDATION PENDING for all proposed optimizations and raw timing compatibility.

## Exact Next Action

Research review is complete. If implementation is requested, first remove empty-selection PENDING scans and per-row Group count/scope duplication, then introduce bounded multi-slice scheduling with selection-change projection invalidation. Preserve all existing checks and atomic purple publication. Obtain a read-only native dump of Preset 25.2001 before changing timing validation: raw multi-step presets already work for some schemas, but nonzero measure is rejected. Measure cold and warm Cue latency separately; no native speed claim follows from the synthetic probe.
