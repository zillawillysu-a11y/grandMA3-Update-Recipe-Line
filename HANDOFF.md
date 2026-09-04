# Project Handoff

## Current Goal

Develop and real-world validate the grandMA3 2.3.2.0 Recipe Tracking Inspector, including safe single-Attribute updates and a multi-Attribute workflow.

## Current Working State

Version `0.6.0.0` adds multi-Attribute batch writing. `BATCH UPDATE`, right of `BATCH`, re-resolves every active Programmer feature at click time, writes each writable feature's Preset into its uniquely resolved Recipe `Values`, removes the union of contributing Programmer attributes, and wraps all Assigns and cleanups in one `CreateUndo`/`CloseUndo` transaction with combined delayed verification (any mismatch rolls back the whole batch with one Oops). Features that are raw/Phaser/ambiguous, NO CHANGE, ambiguous tracking, or whose Recipe is already taken by another feature are skipped with explicit reasons. Read-only `BATCH` preview and single-Attribute updates are unchanged (shared delayed verification now targets a list).

The button is enabled only when the current selection/Attribute resolves to exactly one Recipe, the programmer supplies exactly one Preset reference, and the new Preset differs from the Recipe's current Values. Clicking UPDATE resolves the context again, shows target/old/new confirmation, explicitly assigns the Preset to the Sequence/Cue/Part/Recipe `Values` property, removes only the contributing Programmer attributes, and verifies `recipe.Values` afterward. All commands share one `CreateUndo`/`CloseUndo` transaction. Unsupported or ambiguous states do not write.

## Latest Real-World User Test

v0.4.1.5 passed earlier (larger Update captions, layout/tracking). v0.5.0.0 batch preview passed: 36 fixtures, 7 features reported independently with correct per-feature sources — Color new Preset 4.6 "D GOLD" sourced from Cue 0.5 original Preset (Available: ORIGINAL | NEW CONTENT, no CURRENT CUE), Dimmer sourced from Song EFX Preset in current Cue 5.3, Position sourced from current Cue 5.3 (both include CURRENT CUE). Focus1/PT Speed/Shutter1/Zoom (Programmer Phaser / multi-step) correctly shown as REVIEW ONLY.

## Verified Facts

- Persistent non-modal UI, native title dragging, resize behavior, compact/detail, styles, tracking resolution, All preset/Phaser inspection, and SELECT GROUP have passed prior real-world tests.
- Installed grandMA3 2.3.2 system tests use `Assign <Preset:ToAddr()> At <Recipe:ToAddr()>` to replace Recipe Values and verify the operation with Undo (`shared/resource/lib_plugins/systemtests/db/system_test_prog_cook.lua`).
- The official Lua API supports grouping `Cmd` operations into one Oops entry with `CreateUndo` and `CloseUndo`.
- Raw programmer values or a raw Phaser without one unambiguous Preset reference are deliberately not writable in this first version.
- Deployment destination: `C:\ProgramData\MALightingTechnology\gma3_library\datapools\plugins\Update Plugin`.

## Current Problem

v0.6.0.0 batch writing is implemented and deployed but not yet real-world tested.

## Known Failed Attempts

- Direct Lua property assignment such as `recipe.Values = preset` is not used for production writes because it has not been shown to join an Undo transaction.
- Do not permit updates when tracking is unresolved/ambiguous or when the programmer has no unique Preset reference.

## Important Files

- `RecipeTracking_Inspector.lua`
- `RecipeUpdate_Diagnostic.lua`
- `recipe_update_diagnostic.xml`
- `AGENTS.md`

## Current Branch / Commit

Branch: `qwen`. Version `0.5.0.0` validated (`dd0db78`); v0.6.0.0 batch writing lands in the next commit.

## Exact Next Action

Import/run v0.6.0.0, repeat the 36-fixture test scenario, press `BATCH UPDATE`, and verify: the confirmation lists each writable feature's target/old/new plus skipped reasons, one Oops reverts all written Recipes and Programmer removals, and delayed verification passes (or rolls back with a clear failure list).
