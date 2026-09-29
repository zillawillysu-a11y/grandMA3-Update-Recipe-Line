# Project Handoff

## Current Goal

Native-validate v0.7.1.14 startup stage scan, immediate Group pulse, and steady purple tracking references in grandMA3 2.5.0.3.

## Current Working State

v0.7.1.14 is deployed. With a valid selected Sequence/Cue, the Track A resolver now scans Recipe history even when no fixtures are selected. Purple frames represent final surviving Recipe lanes across Recipe Groups and Attributes through the current Cue. Group pulse scope is derived from surviving lanes for the selected members, independent of the current Attribute tab. Clearing fixture selection removes Group pulses but leaves valid stage-tracking purple refs; losing Sequence/Cue clears both.

## Latest Real-World User Test

Video `2026-09-29 14-37-12.mp4` on v0.7.1.13 shows plugin startup with zero fixtures and no resolver scan; after selecting fixtures, Group/Purple markers appear late. A red error names grandMA3's own `lib_menus/ui/bars/encoder_bar.lua:142`, where `OnMAtrickschange` dereferences nil `caller`; the plugin does not issue `_FrameSelection` commands.

## Verified Facts

- Offline: 87 workflow assertions; 152 show-candidate checks; synthetic refs=4, missing=0, extra=0.
- Lua 5.4 parse, deterministic build/check, XML/version consistency, and `git diff --check` pass.
- v0.7.1.13 was backed up at `C:\tmp\show-rel-backups\Update-Plugin-before-v0.7.1.14-20260929`.
- v0.7.1.14 source/deployed hashes match. Inspector Lua SHA256: `656C7A951D03B1A61C5FE7928495B787607E42E389D2073CAC78025FAB746F17`; XML SHA256: `9930B0E2315FC6F24538D4EA359F549B992F5452B8AC0324F505D317B60CA267`.

## Current Problem

Native startup scan timing and visible frame timing are unverified. The vendor encoder-bar nil-caller error is outside this plugin's Lua files.

## Important Files

- `RecipeTracking_Inspector.lua`
- `tools/templates/show_track_a_runtime.lua`
- `tests/show_candidate.lua`
- `recipe_update_diagnostic.xml`

## Current Branch / Commit

Branch `qwen`; latest checkpoint is v0.7.1.14 (see `git log`).

## Exact Next Action

Reload v0.7.1.14. With Sequence/Cue selected and no fixtures selected, verify tracked Preset/Phaser/Generator tiles become purple. Then select fixtures without pressing SELECT GROUP and verify the corresponding active Recipe Group pulses immediately; confirm Recipe markers persist until superseded. Report whether `encoder_bar.lua:142` still appears.
