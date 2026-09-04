# Project Handoff

## Current Goal

Develop and real-world validate Phase 2 of the grandMA3 2.3.2.0 Recipe Tracking Inspector: update the uniquely resolved Recipe Values preset safely, with every write available as one Oops (Undo).

## Current Working State

Version `0.3.0.2` addresses the next real-world finding: v0.3.0.1 delayed verification correctly proved that `Assign` returned `OK` without changing the intended Recipe (`Expected Preset 2.5`, `Actual Preset 2.7`). The likely cause was a context-relative Recipe `ToAddr()` target.

The button is enabled only when the current selection/Attribute resolves to exactly one Recipe, the programmer supplies exactly one Preset reference, and the new Preset differs from the Recipe's current Values. Clicking UPDATE resolves the context again, shows target/old/new confirmation, performs one `Assign <Preset:ToAddr()> At <Recipe:ToAddr()>` command inside `CreateUndo`/`CloseUndo`, and verifies `recipe.Values` afterward. A successful update is one Oops entry. Unsupported or ambiguous states do not write.

## Latest Real-World User Test

Version `0.2.4.3` passed: compact mode displays the actual Source Cue and opens without the prior clipping. The user approved beginning Update work and required every Update to support Oops (Undo).

Version `0.3.0.2` constructs the target explicitly as `Sequence <n> Cue <n> Part <part>.<recipe> Property "Values"`. It retains delayed verification and automatic Oops on failure, and now reports the complete command when verification fails. Real grandMA3 retesting is pending.

The XML and both referenced Lua components were deployed locally, and all three source/deployment SHA-256 hashes matched.

## Verified Facts

- Persistent non-modal UI, native title dragging, resize behavior, compact/detail, styles, tracking resolution, All preset/Phaser inspection, and SELECT GROUP have passed prior real-world tests.
- Installed grandMA3 2.3.2 system tests use `Assign <Preset:ToAddr()> At <Recipe:ToAddr()>` to replace Recipe Values and verify the operation with Undo (`shared/resource/lib_plugins/systemtests/db/system_test_prog_cook.lua`).
- The official Lua API supports grouping `Cmd` operations into one Oops entry with `CreateUndo` and `CloseUndo`.
- Raw programmer values or a raw Phaser without one unambiguous Preset reference are deliberately not writable in this first version.
- Deployment destination: `C:\ProgramData\MALightingTechnology\gma3_library\datapools\plugins\Update Plugin`.

## Current Problem

The new writer needs a controlled real-world test on grandMA3 2.3.2.0. Confirm that UPDATE changes only the displayed Recipe Values reference, the cooked output follows it, and one Oops restores the prior Recipe Values.

## Known Failed Attempts

- Direct Lua property assignment such as `recipe.Values = preset` is not used for production writes because it has not been shown to join an Undo transaction.
- Do not permit updates when tracking is unresolved/ambiguous or when the programmer has no unique Preset reference.

## Important Files

- `RecipeTracking_Inspector.lua`
- `RecipeUpdate_Diagnostic.lua`
- `recipe_update_diagnostic.xml`
- `AGENTS.md`

## Current Branch / Commit

Branch: `qwen`. Version `0.3.0.2` is committed and pushed as part of the mandatory delivery workflow; check `git log -1 --oneline` for the authoritative commit ID.

## Exact Next Action

Import/run v0.3.0.2 in grandMA3 2.3.2.0. Repeat the known test update, wait for the success dialog, then press Oops once and verify the original Values preset returns. If delayed verification still fails, capture Expected/Actual/Command and dump the system monitor.
