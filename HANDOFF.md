# Project Handoff

## Current Goal

Ensure steady purple markers cover all surviving Recipe tracking references from Cue 1 through the active Cue, while selected-member references and exact current Groups pulse.

## Current Working State

The `0.7.1.16` candidate is deployed to the confirmed Update Plugin directory. Its incremental resolver runs across the union of all members in enabled Recipe rows up to the active Cue (`stageMembers`); fixture selection is applied only afterward to derive pulse refs. Sequence-wide stage refs remain available with no selected fixtures.

## Latest Real-World User Test

The user reports that purple tracking markers still do not cover all expected Sequence tracking content. The onPC screenshot version is `0.7.1.14`.

## Verified Facts

- Source regression: 87 workflow assertions and 160 show-candidate checks pass; synthetic resolver remains 4 refs, 0 missing, 0 extra.
- Lua 5.4 suites, candidate build consistency, XML/component/version checks, and `git diff --check` pass.
- Local confirmed Update Plugin directory currently contains Lua/XML version `0.7.1.15`; its hashes match the `.15` deployment.
- `.15` files were backed up at `C:\tmp\show-rel-backups\Update-Plugin-before-v0.7.1.16-20260929`; all three backup files match the pre-deploy target hashes.
- Deployed `.16` Lua SHA256: `296FCDEDCDE7CAAC703AB165334240FFCB45A968BE7B94FF562CAF90AB1E06E3`; XML SHA256: `BA336CAD4CBEB93DE2E435076287B54896EE576E91114253B8B0F517368DB89B`. Source and deployed hashes match.

## Current Problem

The stage-wide correction is locally test-proven but not native-tested. The most recent screenshot showed `.14`; the confirmed plugin directory now contains `.16`.

## Important Files

- `RecipeTracking_Inspector.lua`
- `tests/show_candidate.lua`
- `tests/recipe_workflow.lua`
- `recipe_update_diagnostic.xml`

## Current Branch / Commit

Worktree `C:\tmp\show-rel` is detached from the `qwen` candidate history; this validated patch is intended as a `qwen` checkpoint.

## Exact Next Action

Reload the plugin and confirm its title is `.16`; with the active Sequence/Cue and no fixtures selected, verify the full set of surviving tracking refs is purple, then select fixtures and verify only their active Recipe refs pulse.
