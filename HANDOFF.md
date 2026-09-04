# Project Handoff

## Current Goal

Develop and real-world validate the grandMA3 2.3.2.0 Recipe Tracking Inspector, including safe single-Attribute updates and a multi-Attribute workflow.

## Current Working State

Version `0.5.0.0` adds the first read-only multi-Attribute batch preview. `BATCH`, immediately right of `SELECT GROUP`, scans active Programmer data for the selected fixtures, groups it by feature, and reports each new Preset, unique source Cue/Group/old Preset, available update destinations, or a safe review-only reason. Existing single-Attribute update behavior is unchanged.

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

Batch preview is validated. Next milestone: multi-Attribute batch UPDATE (writing) is intentionally not enabled yet and needs user go-ahead, since it writes multiple Attributes in one Undo transaction.

## Known Failed Attempts

- Direct Lua property assignment such as `recipe.Values = preset` is not used for production writes because it has not been shown to join an Undo transaction.
- Do not permit updates when tracking is unresolved/ambiguous or when the programmer has no unique Preset reference.

## Important Files

- `RecipeTracking_Inspector.lua`
- `RecipeUpdate_Diagnostic.lua`
- `recipe_update_diagnostic.xml`
- `AGENTS.md`

## Current Branch / Commit

Branch: `qwen`. Version `0.5.0.0` committed and pushed (`dd0db78`); this handoff update is the next commit.

## Exact Next Action

Await user go-ahead for batch writing, then implement multi-Attribute batch UPDATE: resolve all writable features, show combined target/old/new confirmation, apply all `Assign` operations inside one `CreateUndo`/`CloseUndo` transaction, verify every `recipe.Values` afterward, and remove only the contributing Programmer attributes.
