# Project Handoff

## Current Goal

Validate v0.7.1.7 in grandMA3 2.5.0.3 for Group response, regular pulse, and Recipe Pool references.

## Current Working State

v0.7.1.7 is deployed in the confirmed Update Plugin directory. `SELECT GROUP` now uses the last rendered target and returns without invoking a full synchronous render; it checks the current selection/Cue snapshot before issuing commands. Tracking candidates are cached against Cue/Part/Recipe structure and relevant reference identities. Pool pulse is driven by elapsed-time deadlines. Ordinary mode uses vendor-proven `GetPresetData.pm` instead of comparing it to an unproven handle `PresetMode` string. Unknown lane/step shapes still fail closed and now report specific bounded blocker details. Marker style is unchanged; Cue Phaser scanner remains disabled.

## Latest Real-World User Test

v0.7.1.6 did not meet the interaction goal. Screenshots showed `MEMBER_UI_PENDING`, later `INCONCLUSIVE | 0 refs`; blockers included `PRESET_MODE_NATIVE_MISMATCH`, `ORDINARY_LANE_VALUE_UNPROVEN`, and `ORDINARY_CHANNEL_SHAPE_UNPROVEN`. Displayed tracking work was about 82??46 ms and resolver total about 600 ms. v0.7.1.7 has not yet had native validation.

## Verified Facts

- Offline: 87 workflow assertions and 124 candidate checks pass; synthetic four-ref result is final_refs=4, missing=0, extra=0.
- Lua parse, XML parse, deterministic build check, and git diff check pass.
- v0.7.1.7 source/deployed SHA256 match: Inspector `098CF1770E09861A17D5E1A870416F7780793F950EEAEF4691CDC715FE1325F9`, Diagnostic `A00C30DD8DCEFF67ACE8F86E423E70742AF74F85FBB4FA2E38514E5AF15B2191`, XML `5BF1223D9DFCA209BD3CAA2D8C2029432295533847F6D7DB29D1EB83546F9886`.
- v0.7.1.6 deployment backed up at `C:\tmp\show-rel-backups\Update-Plugin-before-v0.7.1.7-20260929`.
- No resolver coroutine yielding and no cooked Cue-history GetPresetData path.

## Current Problem

Native behavior is unverified. Remaining ordinary metadata blocker details need the next native readout; no safety gate was relaxed for them.

## Important Files

- `RecipeTracking_Inspector.lua`
- `tools/templates/show_track_a_runtime.lua`
- `tests/show_candidate.lua`
- `recipe_update_diagnostic.xml`

## Current Branch / Commit

Worktree `C:\tmp\show-rel`, detached from `origin/qwen`; checkpoint pending.

## Exact Next Action

Load v0.7.1.7 and repeat the same Cue 8 selection once. Confirm SELECT GROUP response and pulse cadence. Read the new `resolver_slice`/`resolver_total` timing and exact blocker details. If it crashes, restore the v0.7.1.6 backup immediately.
