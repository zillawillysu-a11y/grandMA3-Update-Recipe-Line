# Project Handoff

## Current Goal

Preserve v0.7.1.34's confirmed marker behavior, improve performance for Shows with over 10× the current fixture count, and diagnose missing Phaser markers in older Shows.

## Current Working State

v0.7.1.34 invalidates the cached visible PoolLayoutGrid list when the Sequence/Cue context or final marker reference set changes. v0.7.1.33 could keep valid but stale grid handles and miss tiles in newly opened or switched Pools. The resolver/indexing and timing changes from v0.7.1.33 remain in place. v0.7.1.34 is deployed and source/deployed SHA256 hashes match. Backup: `C:/tmp/update-plugin-pre-0.7.1.34-20260930-001236`.

## Latest Real-World User Test

The user reports v0.7.1.34 restores purple frames and feels about 2× faster. Their largest Show may have over 10× the current fixture count. In an older Show without Phaser Recipes, Phaser markers do not light; the user wonders whether Cue Recipe fade settings are related. This is an unverified hypothesis.

## Verified Facts

- The v0.7.1.34 grid rediscovery fix is real-world confirmed for purple-frame restoration and perceived speed improvement.
- The approximately 2× improvement and >10× scale are user estimates, not measured timings/counts.
- The Phaser-marker issue is reported only for an older Show without Phaser Recipes; the effect of Cue Recipe fades is unknown.
- Local checks passed before deployment: 89 workflow assertions, 209 Track A candidate checks, Lua/XML parsing, candidate generation consistency, and `git diff --check`.
- Exact Cue-to-purple timing is unknown; the <=300 ms target remains unmeasured.

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

## Current Branch / Commit

Worktree `C:/tmp/show-rel` is clean on `origin/qwen` at checkpoint `docs: record large-show and Phaser follow-up`.

## Exact Next Action

When the user returns, provide a scaling/performance plan and a Phaser diagnostic plan based on the >10× Show and legacy no-Phaser-Recipe observations; then collect concrete reproduction details and investigate while preserving v0.7.1.34 behavior.
