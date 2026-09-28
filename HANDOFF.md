# Project Handoff

## Current Goal

Native validation of v0.7.1.8 for pulse cadence, resolver progress, and Recipe Pool reference frames in grandMA3 2.5.0.3.

## Current Working State

v0.7.1.8 is deployed to the confirmed Update Plugin directory. Each resolver refresh now performs at most one member `GetUIChannels` walk; existing Pool overlay pulse transitions are applied before the synchronous resolver slice. The panel shows member-channel warm progress while pending. Track A remains fail-closed; no reference is published until the resolver is PROVEN. Marker colors, texture, Group matching, and metadata semantics are unchanged.

## Latest Real-World User Test

v0.7.1.7: Group 231 frame and SELECT GROUP worked. Pulse cadence still varied and Recipe/Preset frames were absent. Screenshots showed `PENDING | 0 refs`, reason `MEMBER_UI_PENDING`, for a 210-fixture selection; resolver cumulative time ranged about 1.5–12.6 seconds. No completed resolver result was provided, so Pool identity/overlay failure is not established.

## Verified Facts

- Offline suites: 87 workflow assertions and 125 show-candidate checks pass; integrated synthetic result remains 4 refs, missing=0, extra=0.
- Lua parse, deterministic candidate build check, XML parse, and `git diff --check` pass.
- v0.7.1.7 deployed files were backed up at `C:\tmp\show-rel-backups\Update-Plugin-before-v0.7.1.8-20260929`.
- v0.7.1.8 source/deployed SHA256 match: Inspector `7BE63ACF15C939854E091213E7D813780ACE7BC56F1D5A52CB7B56023221CA25`; Diagnostic `A00C30DD8DCEFF67ACE8F86E423E70742AF74F85FBB4FA2E38514E5AF15B2191`; XML `5F4899289D043640FEBE2CECE75E2E86A9BEE628A7C5A20806ADE7A427022D74`.
- No production semantic gate was relaxed; no cooked Cue-history fallback was added.

## Current Problem

Cold resolver work over a 210-member selection is still expensive. v0.7.1.8 bounds each refresh and exposes progress, but native pulse timing and eventual resolver outcome remain unverified. Recipe references remain hidden while classification is pending or inconclusive.

## Important Files

- `RecipeTracking_Inspector.lua`
- `tests/show_candidate.lua`
- `tests/recipe_workflow.lua`
- `recipe_update_diagnostic.xml`

## Current Branch / Commit

Worktree `C:\tmp\show-rel`, branch `qwen`; release checkpoint being committed and pushed.

## Exact Next Action

Load v0.7.1.8 and select the same 210-member Group. Check whether the Group frame and SELECT GROUP stay responsive, whether the pulse cadence is more even, and whether `Member channels` reaches its total. If it completes, report the Resolver classification/reason and whether Recipe/Preset frames appear. Do not infer native success from offline tests or matching hashes.
