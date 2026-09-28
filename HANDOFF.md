# Project Handoff

## Current Goal

Native validation of v0.7.1.9 for Pool pulse cadence, pending resolver progress, and Recipe reference frames in grandMA3 2.5.0.3.

## Current Working State

v0.7.1.9 is deployed to the confirmed Update Plugin directory. During resolver warmup, each refresh performs at most one native `GetUIChannels` member walk, updates existing overlays before resolver work, and yields at 10 ms instead of the normal 100 ms. The panel reports `Member channels: done/total`. Stable/nonpending operation retains the normal 100 ms loop. Track A still fails closed until PROVEN; no resolver gate or marker appearance changed.

## Latest Real-World User Test

v0.7.1.7 showed the Group 231 frame immediately and SELECT GROUP worked. Pool pulse still varied and no Recipe/Preset frames appeared. Screenshots showed `PENDING | 0 refs`, `MEMBER_UI_PENDING`, and up to 210 selected members; cumulative resolver work displayed about 1.5–12.6 seconds. The resolver never showed a completed classification in the supplied captures.

## Verified Facts

- Offline: 87 workflow assertions, 125 show-candidate checks; synthetic four-ref fixture remains refs=4, missing=0, extra=0.
- Lua parse, deterministic build/version check, XML parse, and `git diff --check` pass.
- v0.7.1.8 deployed files were backed up at `C:\tmp\show-rel-backups\Update-Plugin-before-v0.7.1.9-20260929`.
- v0.7.1.9 source/deployed SHA256 match: Inspector `09E4995903BC95A5E7987E8ED9B06EBF3299AC2C7E705490271923B51DA1F95D`; Diagnostic `A00C30DD8DCEFF67ACE8F86E423E70742AF74F85FBB4FA2E38514E5AF15B2191`; XML `9856F0945CA7084B12436DF9B2BDD1FA53118AF561E5E85AFCCBE9FE8BBFF557`.
- No cooked Cue-history fallback or production semantic relaxation was introduced.

## Current Problem

The large native member scan is still expected to take seconds; the faster pending yield only removes avoidable idle delay and bounds each blocking slice. Recipe references remain hidden while resolver is pending/inconclusive. Native cadence and final resolver result are not verified.

## Important Files

- `RecipeTracking_Inspector.lua`
- `tests/show_candidate.lua`
- `tests/recipe_workflow.lua`
- `recipe_update_diagnostic.xml`

## Current Branch / Commit

Worktree `C:\tmp\show-rel`, branch `qwen`; checkpoint pending.

## Exact Next Action

Load v0.7.1.9 and repeat the same 210-member selection. Confirm Group frame/SELECT GROUP response, pulse regularity, and whether `Member channels` reaches its total. If complete, report Resolver classification/reason and whether Recipe/Preset frames appear. This native validation is still pending.
