# Project Handoff

## Current Goal

Show all independently proven surviving Recipe tracking refs in purple, even when another historical lane keeps the overall resolver inconclusive; keep unresolved refs unmarked and pulse selected-member refs.

## Current Working State

Candidate `0.7.1.17` is deployed. The resolver preserves only already-decided reverse-lane assignments as `provenActiveRefs` when unsafe attribution leaves the overall result `INCONCLUSIVE`. Pool markers consume those refs; unresolved refs remain excluded. The panel labels the partial count and retains the unsafe blocker details.

The overlay regression now covers this partial-safe path end to end: a proven ref gets the steady purple frame, and becomes the existing selected-member pulse when its member is selected.

## Latest Real-World User Test

Video `2026-09-29 15-58-41.mp4` explicitly shows UI version `.16`, with `Resolver: INCONCLUSIVE | 0 refs | 0 overlays`, blocked by `Preset 2.2 (ORDINARY_LANE_CONFLICT, UI 2795, FeatureGroup 2|ABS)` and `Preset 25.9003 (ORDINARY_CHANNEL_SUMMARY_UNPROVEN, channels=0/count=0)`. Group pulse remained visible because Group marking is independent. This recording predates `.17` deployment and does not validate the partial-safe fix.

## Verified Facts

- Tests: 87 workflow assertions; 169 candidate checks; Lua 5.4 passes both suites; synthetic result remains 4 refs, missing=0, extra=0.
- Partial-safe marker regression confirms safe refs reach Pool identity and frame creation while unsafe refs remain excluded.
- Lua 5.4, deterministic build, XML/component/version check, and `git diff --check` pass.
- Before `.17`, `.16` files were backed up at `C:\tmp\show-rel-backups\Update-Plugin-before-v0.7.1.17-20260929` and hashes verified.
- Deployed `.17` source/target Lua SHA256: `8FFF0BE172BA85C51C32C53E71F5E90F30AB68F74BDB61DFC37903A044F83075`.
- Deployed `.17` source/target XML SHA256: `7695E197AC4221A314F783D70E0438F7984CE61F27B51A96D20350213CA7E07C`.
- Diagnostic Lua is unchanged and source/target SHA256 is `A00C30DD8DCEFF67ACE8F86E423E70742AF74F85FBB4FA2E38514E5AF15B2191`.

## Current Problem

The two `.16` native blocker semantics remain unresolved. `.17` should restore markers for unaffected proven lanes, but complete Sequence-wide coverage and Phaser/Generator display need native confirmation.

## Important Files

- `RecipeTracking_Inspector.lua`
- `tools/templates/show_track_a_runtime.lua`
- `tests/show_candidate.lua`
- `recipe_update_diagnostic.xml`

## Current Branch / Commit

Worktree `C:\tmp\show-rel` is detached at the same commit as `origin/qwen`; the new focused overlay regression and this handoff update are pending checkpoint commit/push.

## Exact Next Action

Reload `.17` and confirm the window title is `v0.7.1.17`. Verify proven Sequence refs remain purple despite `INCONCLUSIVE`, unresolved blocker refs stay unmarked, and selecting their member changes only those refs to the existing pulse. If no purple frame appears, capture the `.17` resolver line and list the expected Pool refs that remain absent.
