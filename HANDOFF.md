# Project Handoff

## Current Goal

Native validation of v0.7.1.10 in grandMA3 2.5.0.3; confirm the ordinary Preset metadata path completes and Recipe Pool frames appear.

## Current Working State

v0.7.1.10 is deployed. The native v0.7.1.9 capture completed resolution but returned `INCONCLUSIVE`, with `BY_FIXTURES_SHAPE_UNPROVEN` on ordinary Presets. Production ordinary metadata now calls the previously validated UI-channel form `GetPresetData(reference, false, false)` instead of requesting the unsupported `by_fixtures` view. It still applies the same fail-closed channel/lane checks. Pending resolver responsiveness from v0.7.1.9 is retained.

## Latest Real-World User Test

v0.7.1.9: Group frame and SELECT GROUP were immediate; pulse was steady after warmup. Recipe/Preset/Phaser frames remained absent. The panel showed `INCONCLUSIVE | 0 refs`, reason `UNSAFE_LANE_ATTRIBUTION_BLOCKER`, with `BY_FIXTURES_SHAPE_UNPROVEN` on Preset 1.1, Preset 25.9010, and Preset 4.4. Resolver total showed about 27.8 seconds.

## Verified Facts

- Offline: 87 workflow assertions, 125 show-candidate checks; four-ref synthetic case stays 4 refs, missing=0, extra=0.
- Lua parse, deterministic build/version check, XML parse, and `git diff --check` pass.
- v0.7.1.9 deployment backed up at `C:\tmp\show-rel-backups\Update-Plugin-before-v0.7.1.10-20260929`.
- v0.7.1.10 source/deployed SHA256 match: Inspector `0EF45928C365FDC421EAA33A7BFF1E92899556AD9247AA340D9B3FDA1CC6E6A2`; Diagnostic `A00C30DD8DCEFF67ACE8F86E423E70742AF74F85FBB4FA2E38514E5AF15B2191`; XML `96CBC7BC927E848DF95C25C003D0E214549D133C080699DDAD7C5495E74CB3F8`.
- Metadata-call arguments are asserted by the offline candidate fixture. No cooked Cue-history fallback was added and no safety gate was relaxed.

## Current Problem

The new metadata argument shape has not yet been validated on console. If it passes but refs remain absent, use the new exact blocker details to identify the next failed semantic gate. Native performance remains under review.

## Important Files

- `RecipeTracking_Inspector.lua`
- `tools/templates/show_track_a_runtime.lua`
- `tests/show_candidate.lua`
- `recipe_update_diagnostic.xml`

## Current Branch / Commit

Worktree `C:\tmp\show-rel`, branch `qwen`; checkpoint pending.

## Exact Next Action

Load v0.7.1.10 and repeat Cue 8 with the same Group/selection. Confirm the version, wait for resolver completion, and report whether Preset/Phaser frames appear plus the final Resolver classification and blocker reasons if any.
