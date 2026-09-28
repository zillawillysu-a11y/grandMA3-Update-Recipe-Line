# Project Handoff

## Current Goal

Validate candidate v0.7.1.6 in grandMA3 2.5.0.3 after v0.7.1.5 crashed.

## Current Working State

v0.7.1.6 is deployed in the confirmed Update Plugin directory. It removes coroutine-based resolver yielding and stages native metadata preparation across normal refresh calls. Prepared Cue rows/runtime are cached during the staged operation to avoid rescanning Cue history every 100 ms. At most one uncached reference metadata read and four member UI reads occur in each resolver slice. Track A remains fail closed; no semantic gate was weakened.

## Latest Real-World User Test

User rolled back to v0.7.1.4 and confirmed fixture selection no longer crashes. Prior observation: Group frame appears, while SELECT GROUP / pulse can pause around 600 ms; Recipe refs remain inconclusive with native metadata blockers. v0.7.1.6 native validation is pending.

## Verified Facts

- Offline: 86 workflow assertions and 109 show-candidate checks pass; synthetic four-ref result is final_refs=4, missing=0, extra=0.
- Lua parse, XML parse, deterministic build check, and git diff check pass.
- v0.7.1.6 source/deployed SHA256 match: Inspector `6D0A704E2DC068AAC1BE207E5B94D29A524174A2757FD89914103E27B6415894`, Diagnostic `A00C30DD8DCEFF67ACE8F86E423E70742AF74F85FBB4FA2E38514E5AF15B2191`, XML `AF8AD866BF673BBF071DFDB897452EE58720524C974E05A5E756B7262E283C1D`.
- v0.7.1.4 deployment backed up at `C:\tmp\show-rel-backups\Update-Plugin-before-v0.7.1.6-20260929`.
- No coroutine resolver yielding and no full cooked Cue-history reads in the Track A runtime.

## Current Problem

Native crash freedom, selection response, pulse cadence, and resolver outcome for v0.7.1.6 are unverified. Native API duration cannot be validated offline.

## Important Files

- `RecipeTracking_Inspector.lua`
- `tools/templates/show_track_a_runtime.lua`
- `tests/show_candidate.lua`
- `recipe_update_diagnostic.xml`

## Current Branch / Commit

Worktree `C:\tmp\show-rel`, detached from `origin/qwen`; checkpoint pending.

## Exact Next Action

Load v0.7.1.6 and run one focused Cue 8 check: select the same fixture/Group, observe immediate panel and Group frame, use SELECT GROUP, and report whether it crashes, whether flashing stays regular, and the displayed Resolver reason/ref count. If it crashes, restore the v0.7.1.4 backup immediately.
