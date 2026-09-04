# Project Handoff

## Current Goal

Develop and real-world validate the grandMA3 2.3.2.0 Recipe Tracking Inspector writer. It now supports updating either the tracking source Recipe or the current Cue, with every operation available as one Oops.

## Current Working State

Version `0.4.1.5` restores the three Update action captions to the readable `Medium20` font while retaining the 640 px default width and two-row control layout.

The button is enabled only when the current selection/Attribute resolves to exactly one Recipe, the programmer supplies exactly one Preset reference, and the new Preset differs from the Recipe's current Values. Clicking UPDATE resolves the context again, shows target/old/new confirmation, explicitly assigns the Preset to the Sequence/Cue/Part/Recipe `Values` property, removes only the contributing Programmer attributes, and verifies `recipe.Values` afterward. All commands share one `CreateUndo`/`CloseUndo` transaction. Unsupported or ambiguous states do not write.

## Latest Real-World User Test

Version `0.2.4.3` passed: compact mode displays the actual Source Cue and opens without the prior clipping. The user approved beginning Update work and required every Update to support Oops (Undo).

The user reported the `Regular14` Update captions in v0.4.1.4 were too small. At the new 640 px width each action has enough space, so v0.4.1.5 restores `Medium20` without changing the aligned Cue/Preset layers. Real grandMA3 visual retesting is pending.

The XML and both referenced Lua components were deployed locally for v0.4.1.5, and all three source/deployment SHA-256 hashes matched:

- `recipe_update_diagnostic.xml`: `3BCCCFDED91367B18CAB89148794CF2DA7C08A1B10FA18AC4423C23EDA2FE089`
- `RecipeTracking_Inspector.lua`: `DD9C8138C27FBD2021BA12F3A05D5BE25422756F55161A03EB788898DA802507`
- `RecipeUpdate_Diagnostic.lua`: `1A2D7101FC29BEC449F43B7CE092CE2975A0869A14C99E13F7931BE332F7C428`

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

Branch: `qwen`. Version `0.4.1.5` is committed and pushed as part of the mandatory delivery workflow; check `git log -1 --oneline` for the authoritative commit ID.

## Exact Next Action

Import/run v0.4.1.5. Verify all three Update captions are readable at `Medium20` and do not overlap at the 640 px default width.
