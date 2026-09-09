# Project Handoff

## Current Goal

Show Phaser Recipe and Generator Pool usage for the selected Sequence's current Cue with a persistent purple frame. Fixture-count display is deferred. Preserve the existing green pulse for ordinary Recipe references.

## Current Working State

v0.7.0.8 is in the working tree, locally validated, deployed to `Update Plugin`, and checkpointed on `qwen`. It keeps the v0.7.0.7 purple `GroupedProgLayerActive.Phaser` frame, immediate current-Cue Phaser/Generator publication, and the incremental one-Part-per-tick cooked scan. The render-time tracking candidate cache was removed: it kept deleted Recipe rows visible as the source and blocked NEW CONTENT, failing the offline assertion. Tracking now rescans every refresh, matching the field-validated v0.6.13.0 behavior.

**REAL-WORLD VALIDATION PENDING** for v0.7.0.8.

## Latest Real-World User Test

v0.7.0.6 opens on grandMA3 onPC 2.5.0.3. The intended Pool item receives a frame, proving current-Cue effect detection and overlay placement work, but the frame is black because `SheetColor.PhaserText` is a ColorDef rather than a usable ColorGroups path. Effects inherited from older Cues were not visibly marked and the behavior felt intermittent. v0.7.0.7 was deployed but has no native test report yet.

## Verified Facts

- All 79 offline workflow assertions pass, including "Unique exact Group must enable NEW CONTENT without a source".
- Both plugin Lua files and the test file parse; the Plugin XML parses and both referenced Lua components exist.
- `git diff --check` reports no errors (LF to CRLF warnings only).
- The v0.7.0.8 XML and both referenced Lua files are deployed to `Update Plugin`; all source/deployed SHA256 pairs match.
- The stale-cache regression was introduced in the v0.7 working tree; baseline 35bb0f9 passed the same test with a per-render scan, so the fix restores field-validated behavior without reverting v0.7 features.
- The v0.6.13.0 baseline is commit 35bb0f9.

## Current Problem

Native grandMA3 testing must confirm that v0.7.0.8 renders the frame purple, keeps current plus inherited Phaser Recipe/Generator markers visible while walking Cues, and falls back to NEW CONTENT after a matching Recipe row is deleted from the current Cue.

## Known Failed Attempts

v0.7.0.1 chose an older All Preset. v0.7.0.2 chose the nested Shape and rejected the correct StandardRecipe because `Active="No"`. v0.7.0.3 button-child overlays were invisible. v0.7.0.4 put Grid overlays at cell 0,0 and lit Pool headers. v0.7.0.5 fixed placement but produced no purple. v0.7.0.6 used an invalid BackColor path, producing a black frame; inherited scan recovery still required RT subfixture identity. A v0.7 render-time tracking cache (keyed on sequence, Cue, feature, selection) showed stale sources after in-place Cue edits and failed the NEW CONTENT offline assertion; v0.7.0.8 removes the cache and passes.

## Important Files

- RecipeTracking_Inspector.lua
- recipe_update_diagnostic.xml
- RecipeUpdate_Diagnostic.lua
- tests/recipe_workflow.lua
- docs/cue-effect-markers.md
- AGENTS.md

## Current Branch / Commit

qwen, pushed to origin/qwen. The v0.7.0.8 checkpoint commit "checkpoint: continue v0.7 development pending MA3 validation" holds this state; native confirmation is still outstanding.

## Exact Next Action

Import/call deployed v0.7.0.8 in grandMA3. Confirm direct current-Cue Phaser Recipes have bright purple frames; walk several Cues and confirm inherited markers stay visible; delete a matching Recipe row in the current Cue and confirm the inspector drops to NEW CONTENT for the unique exact Group.
