# Project Handoff

## Current Goal

Native-validate v0.7.1.25's Phaser failure reporting for Recipe Preset
25.9003.

## Current Working State

v0.7.1.25 is deployed to the confirmed Update Plugin folder. Presets with an
embedded `PhaserRecipe` now remain on the Phaser parser path even if parsing
fails; they never fall through to the ordinary UI-channel parser. Exact
self-links and incomplete external linked Presets remain fail-closed, with
separate bounded reasons shown in the panel.

## Latest Real-World User Test

The latest supplied image is from v0.7.1.23. Cue 1's Recipe Preset 25.9003
has no purple frame; its ordinary metadata view is empty and its object has a
`PhaserRecipe` child.

## Verified Facts

- Lua 5.4: 87 workflow assertions and 196 show-candidate checks pass.
- Four-reference fixture remains `final_refs=4 missing=0 extra=0`.
- Focused tests prove: embedded structural failure does not trigger an
  ordinary fallback read; self-link and incomplete external link remain
  inconclusive; unknown REL is not closed by a self-link.
- Lua parsing, XML parsing, version consistency, deterministic generation,
  and `git diff --check` pass.
- The deployed v0.7.1.24 files were backed up at
  `C:\tmp\show-rel-backups\Update-Plugin-before-v0.7.1.25-20260929`.
- Source/deployed SHA256 matches for v0.7.1.25 Lua, XML, and referenced
  diagnostic Lua.

## Current Problem

The v0.7.1.23 `ORDINARY_CHANNEL_SUMMARY_UNPROVEN` reason was masking an earlier
Phaser parse failure through Lua's `structural and phaser() or ordinary()`
fallback. v0.7.1.25 removes that fallback and reports self-link or external
link failures separately. The real native reason for 25.9003 is not yet
verified.

## Important Files

- `RecipeTracking_Inspector.lua`
- `tools/templates/show_track_a_runtime.lua`
- `tests/show_candidate.lua`
- `tests/recipe_workflow.lua`
- `recipe_update_diagnostic.xml`

## Current Branch / Commit

Branch `qwen`; current checkpoint subject: `fix: keep embedded Phaser
references on structural path`. v0.7.1.25 awaits real-world validation.

## Exact Next Action

Reload the plugin and confirm the title is v0.7.1.25. Revisit Cue 1 with
Preset 25.9003. If it remains unmarked, send the Resolver/Blocked refs lines;
the reason should now distinguish an unproven self-link from an incomplete
external linked Preset or Phaser structure.
