# Project Handoff

## Current Goal

Native-validate v0.7.1.21's early Recipe marker delivery and low-load static marker colors.

## Current Working State

v0.7.1.21 is deployed to the confirmed Update Plugin directory. Completed member chunks publish only their independently proven Recipe refs while the Sequence resolver remains `PENDING`; the final ref set stays withheld until the full pass completes. Selected members are processed first. Warm metadata rows no longer consume artificial polling slices. Sequence tracking stays purple; selected Group/Recipe frames stay solid red while timer-driven flashing is paused.

## Latest Real-World User Test

The 2026-09-29 18:02:26 recording ran v0.7.1.20. After Cue changes, purple/Recipe frames took several seconds to appear and the observed flashing cadence slowed. The panel showed staged `PENDING`/partial resolver status.

## Verified Facts

- v0.7.1.21 passes 87 workflow assertions, 187 show-candidate checks, Lua 5.4 parsing, XML parsing, two deterministic build checks, and `git diff --check`.
- Synthetic four-ref case remains `refs=4`, `missing=0`, `extra=0`.
- Focused tests verify an early selected Recipe frame is created from the first completed member chunk while `final refs` remain empty/PENDING.
- Deployed Lua SHA256: `EF0610FC29C40184192CFD0FBF7A5686787798E0A316EDE8BDF54121ECA1B4E7`.
- Deployed XML SHA256: `061609F44D6AE77165841A21D0D3ED3B245E0EAB954D6CE07CF5A825775DDA9C`.
- Pre-deploy v0.7.1.20 files are backed up at `C:\tmp\show-rel-backups\Update-Plugin-before-v0.7.1.21-20260929`; backup hashes matched the deployed originals.

## Current Problem

Native latency and stable visibility of the full Sequence tracking set remain unverified. Static red selection frames are an intentional temporary load reduction; no blinking should be expected in this build.

## Known Failed Attempt

v0.7.1.20 sliced resolver work but withheld every Recipe reference until all metadata/member slices completed. Its pulse writes also continued while resolver work competed for the same coroutine.

## Important Files

- `RecipeTracking_Inspector.lua`
- `recipe_update_diagnostic.xml`
- `tests/show_candidate.lua`
- `tests/recipe_workflow.lua`

## Current Branch / Commit

Branch `qwen`; checkpoint pending for the v0.7.1.21 responsiveness change.

## Exact Next Action

Reload v0.7.1.21 and confirm the title. Change Cue while the Sequence is active and check that the first proven selected Preset frame appears promptly, additional tracked Presets appear as their member chunks prove, tracking frames remain purple, and selected Group/Recipe frames remain solid red. Verify Clear removes selected red frames immediately. Report measured Cue-to-first-frame delay and whether the full Sequence set settles; native validation is pending.
