# Project Handoff

## Current Goal

Keep v0.7.1.34's restored purple Pool frames and faster response; resume triage of the remaining user-reported bugs when the user has quota again.

## Current Working State

v0.7.1.34 invalidates the cached visible PoolLayoutGrid list when the Sequence/Cue context or final marker reference set changes. v0.7.1.33 could keep valid but stale grid handles and miss tiles in newly opened or switched Pools. The resolver/indexing and timing changes from v0.7.1.33 remain in place. v0.7.1.34 is deployed and source/deployed SHA256 hashes match. Backup: `C:/tmp/update-plugin-pre-0.7.1.34-20260930-001236`.

## Latest Real-World User Test

The user confirms v0.7.1.34 restores the purple frames and feels much faster. There are still some bugs, but details and exact timing were not provided because the user is out of quota.

## Verified Facts

- The v0.7.1.34 grid rediscovery fix is real-world confirmed for purple-frame restoration and perceived speed improvement.
- Local checks passed before deployment: 89 workflow assertions, 209 Track A candidate checks, Lua/XML parsing, candidate generation consistency, and `git diff --check`.
- Exact Cue-to-purple timing is unknown; the <=300 ms target remains unmeasured.

## Current Problem

Several bugs remain but are not yet described. Preserve the confirmed v0.7.1.34 behavior while investigating each reported repro; measure cold and cached Cue visits separately.

## Known Failed Attempts

v0.7.1.33 lost visible purple frames for Pool 9001–9012; v0.7.1.34 restored them after forcing grid rediscovery on stage/reference changes.

## Important Files

- `RecipeTracking_Inspector.lua`
- `tools/templates/show_track_a_runtime.lua`
- `recipe_update_diagnostic.xml`
- `tests/recipe_workflow.lua`
- `docs/track-a-marker-latency-research.md`

## Current Branch / Commit

Worktree `C:/tmp/show-rel` is clean on `origin/qwen` at checkpoint `docs: record v0.7.1.34 console confirmation`.

## Exact Next Action

When the user returns, ask for the remaining bugs' visible symptoms, reproduction steps, and any new video; then inspect and fix without disturbing the confirmed purple-frame behavior.
