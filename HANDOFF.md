# Project Handoff

## Current Goal

Native-validate v0.7.1.28 on the confirmed grandMA3 Update Plugin installation.

## Current Working State

v0.7.1.28 is deployed. It fixes expanded Detail's `formatElapsed` scope error,
reduces sparse Recipe/Group lane normalization work, treats per-channel Global
and Universal modes through the native-proven nonselective capability path,
and retains independently proven lanes when an REL barrier still makes the
overall resolver inconclusive. Unknown REL history remains fail-closed.

## Latest Real-World User Test

v0.7.1.27 footage showed Detail erroring on `formatElapsed`, slow purple
publication, and missing 25.9003, 25.9006, and Preset 2.14. The 25 EFX Pool
was visible; the Position Pool containing 2.14 was not visible in the shown
display set.

## Verified Facts

- Focused/workflow tests: 88 workflow assertions and 208 show-candidate checks
  passed; synthetic fixture remains `final_refs=4 missing=0 extra=0`.
- Lua 5.4 parse, XML parse/component existence, deterministic build check,
  discovery (22), Recall View (31), UI topology (23), marker pipeline (41),
  and `git diff --check` passed.
- v0.7.1.28 is installed under the user-confirmed Update Plugin directory.
  Source/deployed Lua SHA256:
  `59A7D20C0F9BA24926DF0CDB72D60F8674A23EA91D3BA1BD38D20C34A20FA228`.
  Source/deployed XML SHA256:
  `F8E3180BAD59F0939A8EC2F728889B35D90B64942C4961F271473A931961BCA0`.
- The exact previous v0.7.1.27 deployed Lua/XML are backed up at
  `C:\tmp\show-rel-backups\v0.7.1.27-before-v0.7.1.28-20260929-214906`.
- 25.9003's prior blocker was a linked Preset channel-mode conflict. A 2/3
  Global/Universal mix now follows the proven nonselective path; Selective
  mixed with Global/Universal stays inconclusive. The compact panel reports
  the conflicting mode pair if it still blocks.
- 25.9006's residual REL barrier still blocks older history and keeps the
  overall result inconclusive; proven independent ABS assignments are retained
  for publication.
- Preset 2.14 could not be matched to a tile in the visible Pool grids in the
  supplied footage. Detail now labels this `VISIBLE_POOL_TILE_NOT_FOUND`.
- No v0.7.1.28 native validation has occurred yet.

## Current Problem

Confirm native Detail rendering, cue-to-purple latency, the 25.9003 linked
mode case, 25.9006 ABS publication, and Pool tile discovery when the relevant
Position Pool is visible.

## Important Files

- `RecipeTracking_Inspector.lua`
- `tools/templates/show_track_a_runtime.lua`
- `tests/show_candidate.lua`
- `recipe_update_diagnostic.xml`

## Current Branch / Commit

Continuation worktree: `C:\tmp\show-rel`, detached after the pushed
`fix: unblock proven recipe marker lanes` checkpoint on `origin/qwen`. The
separate Documents worktree's older local `qwen` branch was left untouched.

## Exact Next Action

Reload the plugin and confirm title v0.7.1.28. Check Cue 1 / Group 79 with its
Position Pool page visible and Cue 5 / Group 79 with the 25 EFX Pool visible.
Open Detail once to verify timings and blocker status; report whether 9003,
9006, and 2.14 frame, plus cue-to-purple time.
