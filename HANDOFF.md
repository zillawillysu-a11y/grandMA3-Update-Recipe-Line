# Project Handoff

## Current Goal

Native-validate v0.7.1.27 after the v0.7.1.26 Cue 1 / Group 79 test.

## Current Working State

v0.7.1.27 is deployed in the confirmed Update Plugin folder. It keeps
Sequence-wide purple publication atomic, uses bounded 32-member resolver
slices, throttles repeated Recipe-structure fingerprints to 100 ms, and
deletes old Pool overlays/window state immediately when replacing a running
plugin instance. The panel now shows compact linked-Phaser failure causes
for blocked references.

## Latest Real-World User Test

On v0.7.1.26, purple frames appeared together but too late. Preset 25.9003
and 25.9006 associated with Group 79 `5 Corner` still appeared unmarked. The
panel showed a truncated linked-Preset blocker for 25.9003. Reloading the
plugin left old frames until the Show was reloaded. The user requires tracking
to use only the currently selected Sequence.

## Verified Facts

- Offline workflow suite: 88 assertions passed.
- Show-candidate suite: 199 checks passed; synthetic fixture is
  `final_refs=4 missing=0 extra=0`.
- Lua parse, XML parse, deterministic build check, and `git diff --check`
  passed.
- Regression coverage confirms unselected Sequence references do not enter
  the selected Sequence result.
- The installed plugin folder is the confirmed Update Plugin folder and
  reports v0.7.1.27 in Lua/XML. Source/deployed SHA256 matches:
  `RecipeTracking_Inspector.lua` `6BEE5EB622A36CA2D1FDC7A8001A39FAC7DC1AE8D4AF9AA5830D39380A054305`,
  `recipe_update_diagnostic.xml` `1B077FB8557CF07D346C5B14743149054B217FE3B0FCF212F162D77AD7CBBC15`,
  and unchanged `RecipeUpdate_Diagnostic.lua`
  `A00C30DD8DCEFF67ACE8F86E423E70742AF74F85FBB4FA2E38514E5AF15B2191`.
- The previous v0.7.1.26 deployment is backed up at
  `C:\tmp\show-rel-backups\v0.7.1.26-before-v0.7.1.27-20260929-211707`.

## Current Problem

The v0.7.1.26 image does not expose the exact linked-Preset gate for 25.9003,
so the precise reason 25.9003/25.9006 lack purple frames remains unverified.
The v0.7.1.27 panel exposes the bounded cause; native latency and marker
coverage still require grandMA3 validation.

## Important Files

- `RecipeTracking_Inspector.lua`
- `tools/templates/show_track_a_runtime.lua`
- `tests/show_candidate.lua`
- `tests/recipe_workflow.lua`
- `recipe_update_diagnostic.xml`

## Current Branch / Commit

Branch `origin/qwen`, checkpoint subject `fix: speed atomic recipe markers
and expose blockers`. The local continuation worktree `C:\tmp\show-rel` is
detached at that checkpoint; v0.7.1.27 awaits native validation.

## Exact Next Action

Ask the user to reload v0.7.1.27 and revisit Cue 1 / Group 79. Capture the
compact blocker cause for Preset 25.9003 and 25.9006, confirm old frames are
removed on plugin replacement, and measure whether purple publication is
within 0.3 seconds. Do not infer native performance from offline tests.
