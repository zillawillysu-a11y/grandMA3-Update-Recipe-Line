# Project Handoff

## Current Goal

Use native v0.7.1.18 validation to identify why the selected Cue 0.5 / Group 79 `5 Corner` source `Preset 2.14` did not pulse in v0.7.1.17, and verify the requested red/white selected pulse and brighter steady purple tracking frame.

## Current Working State

v0.7.1.18 is deployed to the confirmed Update Plugin folder. It adds a bounded `Selected source ref` stage line (`NOT_FINAL_ASSIGNMENT`, unsafe/unknown attribution, or Pool/frame stage) and changes selected pulses to stock theme red/bright-white colors and steady Recipe frames to the stock brighter Phaser UI color. Resolver rules are unchanged.

## Latest Real-World User Test

User reports v0.7.1.17 was very successful overall, but Cue 0.5 / Group 79 `5 Corner` showed `Preset 2.14` as its old Recipe value and that tile did not flash. v0.7.1.18 has not yet been tested natively.

## Verified Facts

- 176 show-candidate checks pass; integrated synthetic case remains 4 refs, missing=0, extra=0. All 87 workflow assertions pass.
- Lua 5.4, deterministic build check (twice), Lua/XML parse, and `git diff --check` pass.
- v0.7.1.17 deployed files were backed up at `C:\tmp\show-rel-backups\Update-Plugin-before-v0.7.1.18-20260929`; backup hashes matched the deployed originals.
- v0.7.1.18 source/deployed SHA256: Lua `D8C31205E5A7CC3E8C0B9458A3177F724CAC5BBE2806D060BEB2444C94164C31`; XML `B03221CAF8740191CCD4917C01DC06DB0FD9D642B55B6994B37C96E142E46431`; unchanged diagnostic Lua `A00C30DD8DCEFF67ACE8F86E423E70742AF74F85FBB4FA2E38514E5AF15B2191`.
- v0.7.1.17 original hashes: Lua `8FFF0BE172BA85C51C32C53E71F5E90F30AB68F74BDB61DFC37903A044F83075`; XML `7695E197AC4221A314F783D70E0438F7984CE61F27B51A96D20350213CA7E07C`.

## Current Problem

The v0.7.1.17 recording does not expose the first missing marker stage for Preset 2.14. The `.18` panel line is intended to identify whether it is absent from resolved assignments, blocked by unsafe attribution, excluded from selected lanes, or lost in Pool lookup/overlay creation.

## Important Files

- `RecipeTracking_Inspector.lua`
- `recipe_update_diagnostic.xml`
- `tests/show_candidate.lua`
- `tests/recipe_workflow.lua`

## Current Branch / Commit

Worktree is detached at `35c7e5c`; v0.7.1.18 source changes and this handoff are pending commit/push.

## Exact Next Action

Reload v0.7.1.18 and confirm the title. Select the same Cue 0.5 / Group 79 `5 Corner` context and report the `Selected source ref: Preset 2.14 | ...` stage. Also verify selected frames alternate red/bright-white and Sequence tracking frames appear brighter purple. Do not infer native success from the local tests or matching deployment hashes.
