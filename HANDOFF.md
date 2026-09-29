# Project Handoff

## Current Goal

Ensure steady purple markers cover all surviving Recipe tracking references from Cue 1 through the active Cue, while selected-member references and exact current Groups pulse.

## Current Working State

The uncommitted `0.7.1.16` candidate passes offline regression. Its incremental resolver now runs across the union of all members in enabled Recipe rows up to the active Cue (`stageMembers`); fixture selection is applied only afterward to derive pulse refs. Sequence-wide stage refs remain available with no selected fixtures.

## Latest Real-World User Test

The user reports that purple tracking markers still do not cover all expected Sequence tracking content. Recent onPC screenshots show plugin title `0.7.1.19`.

## Verified Facts

- Source regression: 87 workflow assertions and 160 show-candidate checks pass; synthetic resolver remains 4 refs, 0 missing, 0 extra.
- Lua 5.4 suites, candidate build consistency, XML/component/version checks, and `git diff --check` pass.
- Local confirmed Update Plugin directory currently contains Lua/XML version `0.7.1.15`; its hashes match the earlier `.15` deployment. No local `.19` source was found.
- The `.16` source changes have not been deployed. Do not overwrite until the `.19` source/worktree mismatch is resolved.

## Current Problem

The tracked source available here is based on `c54dcbb` and does not include the code shown as `0.7.1.19` in native screenshots. The stage-wide correction is locally test-proven but not native-tested in the currently reported build.

## Important Files

- `RecipeTracking_Inspector.lua`
- `tests/show_candidate.lua`
- `tests/recipe_workflow.lua`
- `recipe_update_diagnostic.xml`

## Current Branch / Commit

Worktree `C:\tmp\show-rel` is detached from the `qwen` candidate history; this validated patch is intended as a `qwen` checkpoint.

## Exact Next Action

Obtain or identify the source/worktree for the onPC-tested `0.7.1.19`, then port the tested `stageMembers` scope fix onto that version, rerun validation, and deploy only the resulting newer candidate to the confirmed active plugin path.
