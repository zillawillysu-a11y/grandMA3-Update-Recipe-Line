# Project Handoff

## Current Goal

Native-validate the v0.7.1.13 stage-wide purple Recipe reference markers in grandMA3 2.5.0.3.

## Current Working State

v0.7.1.13 is deployed to the confirmed Update Plugin directory. Purple markers now use the stock theme UI Color `RecipeEditing.PhaserRecipe`; the resolver supplies final tracked references across the selected Sequence's Recipe Groups through the current Cue, including static Presets, Phasers/Phaser Recipes, and Generators. Selection remains the separate Group pulse scope. No native result exists for v0.7.1.13 yet.

## Latest Real-World User Test

v0.7.1.12 showed immediate Group selection frames/Select Group, but no visible Recipe/Preset/Phaser/Generator purple frames. User confirms the show is built from Recipe Lines and each Cue's Recipe rows specify the Groups in the selected Sequence.

## Verified Facts

- Offline tests: 87 workflow assertions; 146 show-candidate checks. Synthetic four-reference fixture: missing=0, extra=0.
- Lua 5.4 parse, deterministic build/check, XML/version validation, and `git diff --check` pass.
- Source/deployed SHA256 match for all three plugin files. Deployed Lua SHA256: `63133B7EF0BAB077CD620732F449FBB27E81BAF6B0CB140250B611AA2E00B0F4`.
- Pre-deploy v0.7.1.12 files backed up at `C:\tmp\show-rel-backups\Update-Plugin-before-v0.7.1.13-20260929`.

## Current Problem

Confirm native purple frames render on still-tracked Presets, Phasers/Phaser Recipes, and Generators; confirm killed/overridden references disappear. Native response time remains unverified.

## Important Files

- `RecipeTracking_Inspector.lua`
- `tools/templates/show_track_a_runtime.lua`
- `tests/show_candidate.lua`
- `recipe_update_diagnostic.xml`

## Current Branch / Commit

Branch `qwen`; latest repository checkpoint is the v0.7.1.13 candidate (see `git log`).

## Exact Next Action

Reload v0.7.1.13. In one selected Sequence, verify a still-tracked static Preset (for example 4.4) and active Phaser/Phaser Recipe/Generator tiles are steadily purple, while only the actually selected complete Group pulses. Then advance to a Cue that overrides/kills a reference and confirm its purple frame clears.
