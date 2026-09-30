# Project Handoff

## Current Goal
Immediate Cue-delta purple frames, then background tracking reconciliation; <=300 ms native first-frame target remains unmeasured. Phaser parser repairs remain paused.

## Current Working State
v0.7.1.38 implemented, locally validated and deployed. Cold/backward/skipped/other-Sequence/edit/forceRefresh preview starts only from current Cue enabled Values/Generator Recipes. Adjacent forward Cue carries the previous visible rows and adds current Cue rows. Same Group plus known cached FeatureGroup/layer coverage removes replaced candidates before member resolution. Unknown/selective new scope waits for background proof. A Preset surviving another Group/layer remains visible. Proven baseline stores actual surviving lanes, not original full Preset scope. Preview never seeds from all historical Recipe rows; background still resolves history through current Cue. Red attribution and write safety unchanged. Original MUSE report remains untracked and untouched.

## Latest Real-World User Test
v36 was faster but still insufficient. User accepts v37 optimistic concept but rejects the mass history flash: requested comparing consecutive Cue Groups and immediately replacing their Preset markers, adding only new Cue Recipe references. Supplied 35.28 s / 60 fps video 2026-09-30 13-12-36.mp4 was inspected. v38 REAL-WORLD VALIDATION PENDING.

## Verified Facts
- v38: 89 workflow assertions, 258 Track A checks, 261 extended probe checks pass. Lua/XML parsing, generated-runtime consistency and diff whitespace validation pass.
- Behavioral tests cover current-only cold preview with history access made to throw; same-Group replacement; retained unrelated lanes/Groups; shared Preset protection; selective/unknown scope; layer remainder; newly warmed scope; exact proven snapshot; backward/skip and deletion reset.
- XML and both referenced Lua files copied to local Update Plugin; all SHA256 values match. Backup: C:/tmp/update-plugin-pre-0.7.1.38. This verifies file identity only.
- v36 bounded steps and task identity memo preserved. No numeric native speed claim.
- 8909 has three direct PhaserRecipes; current parser admits one. Older raw Phaser exports contain Measure and native mask failures. Diagnoses recorded; parser unchanged.

## Current Problem
Native first-purple speed and Cue-delta correctness require user test. New metadata can be unknown on first render; same-Group pruning then happens when background metadata warms. Distinct/overlapping Groups remain background work. Structure fingerprint and Pool discovery still cost native time. Background proof can add genuine inherited survivors after a cold jump; it never adds all historical candidates upfront.

## Known Failed Attempts
v37 previews all enabled historical refs and flashes too many frames before removing them. v35 optimizations alone too slow. v33 grid discovery lost purple frames; v34 correction preserved.

## Important Files
- RecipeTracking_Inspector.lua
- recipe_update_diagnostic.xml
- tests/show_candidate.lua
- tools/templates/show_track_a_runtime.lua
- docs/cue-delta-preview-0.7.1.38.md
- docs/phaser-8909-export-diagnosis-2026-09-30.md

## Current Branch / Commit
C:/tmp/show-rel detached worktree; checkpoint subject: perf: preview consecutive Cue recipe deltas, pushed to origin/qwen. Verify current Git state. No automatic main merge. Old Documents worktree untouched.

## Exact Next Action
User imports v38 and repeats same transitions. Check only current Cue candidates appear initially; adjacent same-Group replacements remove old frames promptly; different Group/layer survivors remain; first-purple latency separately from final convergence; red selection, rapid GO/back/jump, deletion and NEW CONTENT. Use native feedback to optimize remaining signature/Pool or cold metadata latency. Phaser fix stays paused.
