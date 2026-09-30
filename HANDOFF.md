# Project Handoff

## Current Goal
Apply Cue-delta continuity to all Preset/Phaser/Generator classes, then background reconciliation; <=300 ms native first-frame target remains unmeasured. Phaser parser repairs remain paused.

## Current Working State
v0.7.1.39 locally validated and deployed. v38 delta preview preserved. Snapshot now merges independently proven refs and exact group/lane contributions even when overall result is INCONCLUSIVE, alongside unresolved non-excluded candidates. Previously that branch stored only preview candidates, dropping ordinary inherited Presets first discovered by partial proof at the next Cue. All reference classes share the snapshot path. Red attribution, writes and Phaser parser unchanged. Original MUSE report remains untracked and untouched.

## Latest Real-World User Test
User praises v38 delta concept but reports ordinary Presets still go dark then return, while Phaser Recipe behaves correctly. Requests the same continuity for all. Failure reproduced offline with inherited static/moving Presets beside unresolved Phaser; v39 passes the regression. User now reports v39 perfect; purple continuity and speed accepted. Older Show opened in 2.5.0.3 displays Phaser purple but selected Group does not produce red; supplied new video and exports for research only.

## Verified Facts
- v39: 89 workflow assertions, 266 Track A checks, 269 extended probe checks pass. Lua/XML parsing, generated-runtime consistency and diff whitespace validation pass.
- Behavioral tests cover current-only cold preview with history access made to throw; same-Group replacement; retained unrelated lanes/Groups; shared Preset protection; selective/unknown scope; layer remainder; newly warmed scope; exact proven snapshot; backward/skip and deletion reset.
- XML and both referenced Lua files copied to local Update Plugin; all SHA256 values match. Backup: C:/tmp/update-plugin-pre-0.7.1.39. This verifies file identity only.
- v36 bounded steps and task identity memo preserved. No numeric native speed claim.
- 8909 has three direct PhaserRecipes; current parser admits one. Older raw Phaser exports contain Measure and native mask failures. Diagnoses recorded; parser unchanged.

## Current Problem
v39 ordinary-Preset continuity is user confirmed. Next research: immediate selection-to-SELECT GROUP/red and legacy raw Phaser red attribution. New metadata can be unknown on first render; same-Group pruning then happens when background metadata warms. Distinct/overlapping Groups remain background work. Structure fingerprint and Pool discovery still cost native time. Background proof can add genuine inherited survivors after a cold jump; it never adds all historical candidates upfront.

## Known Failed Attempts
v38 failed to carry ordinary refs first discovered by partial proof. v37 previews all enabled historical refs and flashes too many frames before removing them. v35 optimizations alone too slow. v33 grid discovery lost purple frames; v34 correction preserved.

## Important Files
- RecipeTracking_Inspector.lua
- recipe_update_diagnostic.xml
- tests/show_candidate.lua
- tools/templates/show_track_a_runtime.lua
- docs/ordinary-preset-continuity-0.7.1.39.md
- docs/phaser-8909-export-diagnosis-2026-09-30.md

## Current Branch / Commit
C:/tmp/show-rel detached worktree; checkpoint subject: fix: carry partially proven Presets across Cue transitions, pushed to origin/qwen. Verify current Git state. No automatic main merge. Old Documents worktree untouched.

## Exact Next Action
Research selection-to-SELECT GROUP/red latency and older raw Phaser attribution using 2026-09-30 13-47-02.mp4, NEWSEQREF.xml and NEWPHASERREF.xml. Publish durable implementation-ready findings to origin/qwen. No runtime changes this turn; purple speed accepted and further optimization deferred.
