# Project Handoff

## Current Goal

Develop and real-world validate the grandMA3 2.3.2.0 Recipe Tracking Inspector writer. It now supports updating either the tracking source Recipe or the current Cue, with every operation available as one Oops.

## Current Working State

Version `0.4.1.1` adds green visual emphasis for the resolved Source Cue value and displayed Preset references while preserving white labels and surrounding text.

The button is enabled only when the current selection/Attribute resolves to exactly one Recipe, the programmer supplies exactly one Preset reference, and the new Preset differs from the Recipe's current Values. Clicking UPDATE resolves the context again, shows target/old/new confirmation, explicitly assigns the Preset to the Sequence/Cue/Part/Recipe `Values` property, removes only the contributing Programmer attributes, and verifies `recipe.Values` afterward. All commands share one `CreateUndo`/`CloseUndo` transaction. Unsupported or ambiguous states do not write.

## Latest Real-World User Test

Version `0.2.4.3` passed: compact mode displays the actual Source Cue and opens without the prior clipping. The user approved beginning Update work and required every Update to support Oops (Undo).

The content uses two aligned UIObject text layers because grandMA3 2.3.2 exposes per-object `TextColor`, not verified inline rich-text colors. The base layer blanks only the highlighted spans; a transparent `Global.SuccessText` overlay renders the Source Cue value and each `Preset X.X ...` span. Both compact and detail output use the same transformation. Real grandMA3 visual testing is pending.

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

Branch: `qwen`. Version `0.4.1.1` is committed and pushed as part of the mandatory delivery workflow; check `git log -1 --oneline` for the authoritative commit ID.

## Exact Next Action

Import/run v0.4.1.1. Verify that only the value after `Source Cue:` and the `Preset X.X "Name"` portions are green in both compact and detail views, with no opaque overlay or alignment drift. Continue testing the three update modes afterward.
