# Project Handoff

## Current Goal

Improve Cue-to-reference response and make surviving Recipe/Phaser/Generator Pool markers visibly purple in the large native Show.

## Current Working State

v0.7.1.12 is deployed to the confirmed Update Plugin directory. Stored Group canonical member sets cache by Group handle plus a sorted native member-address signature; a membership change forces canonical keys to be rebuilt. Cue history Recipe rows cache against the existing structural signature. Resolver timing is split into cue scan, scope, GetPresetData, member UI, and remaining engine time. Recipe overlays use `SheetColor.Phaser` (native Phaser background color); status says overlays rather than claiming rendered frames. Track A rules, Group pulse appearance, and old Cue Phaser scanner state are unchanged. Deployed Inspector SHA256: `1645C5E2DA15CF1C12126B9CBC366930633C5C5AFDD1A1E3DEBC12BE702A2F11`; Diagnostic SHA256: `A00C30DD8DCEFF67ACE8F86E423E70742AF74F85FBB4FA2E38514E5AF15B2191`; XML SHA256: `DFA387170C301BD25ADF8F2F4E1A7D8FAE87BFB1338366E6ECC77D28FA7F0EAD`. Source/deployed hashes match.

## Latest Real-World User Test

v0.7.1.11 screenshot for 210 selected fixtures: Resolver PROVEN with one final ref, Preset 25.9010; resolver time 643 ms. User reports Recipe/Phaser Pool markers still appear black or absent. This misses the requested 100 ms response target. v0.7.1.12 has not yet been native-tested.

## Verified Facts

- Offline: 87 workflow assertions and 141 show-candidate checks pass; synthetic Track A fixture remains four refs, missing=0, extra=0.
- Lua 5.4 syntax, deterministic build check, XML parse/version consistency, and `git diff --check` pass.
- Local tests confirm Group identity cache reuse when selection changes and direct surviving PhaserRecipe references reach the marker source set.
- v0.7.1.11 native marker painting and <=100 ms target are NOT VERIFIED; v0.7.1.12 native behavior remains pending.

## Current Problem

Need native evidence whether `SheetColor.Phaser` renders a visible purple frame and whether remaining resolver-engine/scope time can meet the response target. Need verify whether all expected active Phaser-bearing Recipe refs enter final refs for the tested Cue/member/attribute set. The previous 643 ms total is still the only native timing measurement.

## Important Files

- `RecipeTracking_Inspector.lua`
- `tests/show_candidate.lua`
- `tests/recipe_workflow.lua`
- `recipe_update_diagnostic.xml`

## Current Branch / Commit

Branch `qwen` (worktree detached at the pushed v0.7.1.12 candidate checkpoint); native validation is pending.

## Exact Next Action

Reload v0.7.1.12 in grandMA3 2.5.0.3. Test the same 210-fixture Cue and report the split Timing line plus a close Pool screenshot showing Preset 25.9010 and any Phaser-bearing source tile. Previous files are backed up at `C:\tmp\show-rel-backups\Update-Plugin-before-v0.7.1.12-20260929`.
