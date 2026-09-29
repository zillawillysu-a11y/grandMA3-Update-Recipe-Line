# Project Handoff

## Current Goal

Continue native validation of v0.7.1.10, including full Group 231 selection and Phaser/other surviving references.

## Current Working State

v0.7.1.10 is deployed. Ordinary reference reads use the validated UI-channel form `GetPresetData(reference, false, false)`. Resolver stays fail-closed until PROVEN; pending work is staged one member per refresh with a 10 ms pending yield. Group tile and Pool marker appearance are unchanged.

## Latest Real-World User Test

Video `2026-09-29 13-06-11.mp4` shows Cue 8 / Change-H1, Part 2, Recipe 1, Group 231. As selection grows, the resolver restarts and shows member warmup progress. At the end, selection is 77 of the Group's 210 members; panel reports `Resolver: PROVEN | 1 refs | 1/1 frames`, `Refs: Preset 25.9010`, and Pool tile 9010 has a visible bright outline. This confirms the v0.7.1.10 metadata path passed the former BY_FIXTURES blocker and created a Recipe Pool marker for this partial selection. It does not validate all 210 members or Phaser markers; no Phaser reference appears in this final one-ref result.

## Verified Facts

- Offline: 87 workflow assertions, 125 show-candidate checks; synthetic four-ref fixture remains 4 refs, missing=0, extra=0.
- Lua parse, deterministic build/version check, XML parse, and `git diff --check` passed for v0.7.1.10.
- v0.7.1.10 source/deployed hashes match: Inspector `0EF45928C365FDC421EAA33A7BFF1E92899556AD9247AA340D9B3FDA1CC6E6A2`; Diagnostic `A00C30DD8DCEFF67ACE8F86E423E70742AF74F85FBB4FA2E38514E5AF15B2191`; XML `96CBC7BC927E848DF95C25C003D0E214549D133C080699DDAD7C5495E74CB3F8`.
- No production semantic gate was relaxed and no cooked Cue-history fallback was added.

## Current Problem

Need a stable full 210-member Group 231 run to verify expected final references and markers, plus a context where a Phaser reference is expected. Native cold resolution still takes several seconds while selection changes restart the work.

## Important Files

- `RecipeTracking_Inspector.lua`
- `tools/templates/show_track_a_runtime.lua`
- `tests/show_candidate.lua`
- `recipe_update_diagnostic.xml`

## Current Branch / Commit

Worktree `C:\tmp\show-rel`, branch `qwen`; native result checkpoint pending.

## Exact Next Action

With v0.7.1.10, use SELECT GROUP once to select all of Group 231, then leave selection and Cue unchanged until resolution completes. Check that Resolver is PROVEN and record the final ref list/visible tiles. Then test a known Cue/selection whose surviving source includes a Phaser and report its final refs/frame status.
