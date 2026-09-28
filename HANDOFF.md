# Project Handoff

## Current Goal

Fix native Group and Recipe Pool markers in grandMA3 2.5.0.3 without weakening Track A proof.

## Current Working State

Production Plugin was rolled back to v0.7.1.4 after v0.7.1.5 crashed when selecting a fixture. The v0.7.1.5 coroutine resolver commit is reverted on qwen. Current source is v0.7.1.4. Keep Track A fail closed, canonical Fixture/SubFixture/Cell identity, current marker style, and Cue Phaser scanner disabled.

## Latest Real-World User Test

v0.7.1.5 crashed immediately when the user selected a fixture. Production files were restored from the exact pre-v0.7.1.5 backup. Earlier v0.7.1.4 showed Group 231 immediately, but `SELECT GROUP` and pulse paused about 600 ms during resolver work. Parser failures included `PRESET_MODE_NATIVE_MISMATCH` and ordinary channel shape blockers. No v0.7.1.5 native behavior is accepted.

## Verified Facts

- Deployed rollback versions/hashes: Inspector v0.7.1.4 SHA256 `CE52E326C57EC3B2118F45DF23BC026D917A7BA256D65ADBB051B66DB61A996E`, Diagnostic `A00C30DD8DCEFF67ACE8F86E423E70742AF74F85FBB4FA2E38514E5AF15B2191`, XML `DEC1473D7AA113DC50E7BE196866DDBB22451FBCB9E555B7DDC5B14844EC9D40`.
- Backup used: `C:\tmp\show-rel-backups\Update-Plugin-before-v0.7.1.5-20260929-004341`.
- Most likely crash trigger is coroutine yielding while native API reads execute; not independently confirmed. Do not use coroutine-based resolver yielding again.
- v0.7.1.4 still has the synchronous ~612 ms resolver delay, ordinary metadata blockers, missing Recipe refs, and unresolved multi-Group UI.

## Current Problem

Need redesign incremental resolver without yielding across native API boundaries, or otherwise keep resolution synchronous and avoid the crash. Determine exact PresetMode/ordinary blockers from native evidence before changing safety gates.

## Important Files

- `RecipeTracking_Inspector.lua`
- `tools/templates/show_track_a_runtime.lua`
- `tests/show_candidate.lua`
- `recipe_update_diagnostic.xml`

## Current Branch / Commit

Detached `C:\tmp\show-rel` worktree at rollback commit; see Git status/log.

## Exact Next Action

First confirm the user restarted/reloaded the plugin and v0.7.1.4 no longer crashes. Then implement any resolver work as explicit per-reference steps across normal refresh ticks, with no coroutine yield inside or around native API calls.
