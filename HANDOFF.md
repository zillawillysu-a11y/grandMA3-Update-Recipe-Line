# Project Handoff

## Current Goal

Develop and real-world validate Phase 2 of the grandMA3 2.3.2.0 Recipe Tracking Inspector: update the uniquely resolved Recipe Values preset safely, with every write available as one Oops (Undo).

## Current Working State

Version `0.3.0.4` implements the clarified Programmer cleanup requirement. The user wants the assigned Attribute removed from the Programmer, not merely deactivated, while unrelated Attributes remain untouched.

The button is enabled only when the current selection/Attribute resolves to exactly one Recipe, the programmer supplies exactly one Preset reference, and the new Preset differs from the Recipe's current Values. Clicking UPDATE resolves the context again, shows target/old/new confirmation, explicitly assigns the Preset to the Sequence/Cue/Part/Recipe `Values` property, removes only the contributing Programmer attributes, and verifies `recipe.Values` afterward. All commands share one `CreateUndo`/`CloseUndo` transaction. Unsupported or ambiguous states do not write.

## Latest Real-World User Test

Version `0.2.4.3` passed: compact mode displays the actual Source Cue and opens without the prior clipping. The user approved beginning Update work and required every Update to support Oops (Undo).

Version `0.3.0.4` collects the concrete subattributes contributing the selected Feature/Preset (for example the RGB attributes for Color), then runs `Off Attribute "<name>"` for each after Assign. These commands affect the current fixture selection and share the same Undo group as the Recipe update. `ClearActive` is no longer used, so unrelated Programmer attributes are preserved. Real grandMA3 retesting of targeted removal and the combined Oops is pending.

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

Branch: `qwen`. Version `0.3.0.4` is committed and pushed as part of the mandatory delivery workflow; check `git log -1 --oneline` for the authoritative commit ID.

## Exact Next Action

Import/run v0.3.0.4 in grandMA3 2.3.2.0. Keep another Feature active in the Programmer, update the intended Feature, and verify only the assigned subattributes disappear while the unrelated Feature remains. Then press Oops once and verify both the original Recipe Values preset and removed Programmer data return.
