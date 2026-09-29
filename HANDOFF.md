# Project Handoff

## Current Goal

Native-validate v0.7.1.24's Phaser metadata routing fix, especially Recipe
Preset 25.9003.

## Current Working State

v0.7.1.24 is deployed to the confirmed Update Plugin folder. A Preset with an
embedded `PhaserRecipe` now stays on the Phaser parser path even when that
parse fails; it no longer falls through to the ordinary UI-channel parser.
Exact self-links use the already parsed Phaser tree and do not count as
independent linked-Preset proof for an unknown REL barrier. Distinct external
linked Presets retain the existing complete-metadata gate.

## Latest Real-World User Test

The v0.7.1.23 Cue 1 screenshot shows Preset 25.9003 unmarked. Its diagnostic
shape has zero ordinary UI-channel records and one `PhaserRecipe` child.

## Verified Facts

- Lua 5.4: 87 workflow assertions and 196 show-candidate checks pass.
- Four-reference fixture remains `final_refs=4 missing=0 extra=0`.
- New tests cover embedded self-link resolution, unknown REL remaining blocked,
  and distinct incomplete external links remaining fail-closed.
- Lua parsing, XML parsing, version consistency, deterministic generation, and
  `git diff --check` pass.
- The exact deployed v0.7.1.23 files were backed up at
  `C:\tmp\show-rel-backups\Update-Plugin-before-v0.7.1.24-20260929`.
- Source/deployed SHA256 matches for v0.7.1.24 Lua, XML, and referenced
  diagnostic Lua.

## Current Problem

The native screenshot's ordinary-summary reason was caused by structural
Phaser parse failure falling through into `ordinary()`, which masked the
Phaser failure and performed an extra metadata read. v0.7.1.24 fixes that
routing. Native Cue 1 behavior is not yet verified.

## Important Files

- `RecipeTracking_Inspector.lua`
- `tools/templates/show_track_a_runtime.lua`
- `tests/show_candidate.lua`
- `tests/recipe_workflow.lua`
- `recipe_update_diagnostic.xml`

## Current Branch / Commit

Branch `qwen`; current checkpoint subject: `fix: keep embedded Phaser
references on structural path`. v0.7.1.24 is deployed and awaits real-world
validation.

## Exact Next Action

Reload the plugin and confirm the title is v0.7.1.24. Revisit Cue 1 with
Preset 25.9003. Check whether its Pool tile is marked; if not, capture the
Resolver/Blocked refs lines, which should now report the actual Phaser gate
instead of an ordinary-channel summary.
