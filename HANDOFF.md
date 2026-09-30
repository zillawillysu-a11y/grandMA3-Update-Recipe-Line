# Project Handoff

## Current Goal
Reduce native Cue-to-purple latency toward 300 ms. User prioritizes speed; Phaser fixes are deferred while supplied exports are diagnosed read-only.

## Current Working State
v0.7.1.36 implemented, locally validated and deployed. Task-scoped positive identity cache (4096 entries) reduces repeated native address reads. Resolver can advance up to four bounded steps per render within an 8 ms soft budget; unavailable/unreliable native clock falls back to one step. No nested native coroutines. Selection reprioritization runs only on changes. Phaser parser unchanged. Original MUSE report remains untracked and untouched.

## Latest Real-World User Test
User rejects v0.7.1.35 speed. Video shows completed panel totals of 1620.1 and 2071.6 ms, and smaller Cues at 386.7/461.6 ms; these are panel observations, not GO-to-purple wall measurements. Screenshot Cue4 shows 510.3 ms and 25.8909 blocked. Older Show opened in 2.5 shows measure/mask rejection. v0.7.1.36 REAL-WORLD VALIDATION PENDING.

## Verified Facts
- v36 local validation: 89 workflow assertions, 226 Track A checks, 229 extended probe checks; Lua/XML parse and generated candidate consistency pass.
- Intended XML and both referenced Lua files copied; all source/deployed SHA256 values match. Backup: C:/tmp/update-plugin-pre-0.7.1.36-20260930-124847. Hash equality proves deployment identity only.
- Offline controlled-clock model reduces 12,650-member scheduling from 51 ticks to 13; native speed remains unknown.
- RRR/SEQREF confirm Shutter Shuffle is referenced in enabled Cue4 Recipes and has three direct PhaserRecipes (3/2/2 steps). Parser accepts exactly one, explaining rejection if native structure matches XML.
- Additional older and range exports parsed successfully; diagnostic notes record their structure. No Show data changed.

## Current Problem
Native v36 latency and marker equivalence need user testing. Scope preparation (94?155 ms in video) may remain a bottleneck. Multi-recipe and raw-measure Phaser failures require distinct proofs; neither is fixed in v36.

## Known Failed Attempts
v35 empty-selection and repeated-Group optimization alone remains too slow. v33 lost purple frames; v34 grid rediscovery restored them and is preserved.

## Important Files
- RecipeTracking_Inspector.lua
- recipe_update_diagnostic.xml
- tests/show_candidate.lua
- tools/review_scale_phaser.py
- tools/templates/show_track_a_runtime.lua
- docs/scale-optimization-0.7.1.36.md
- docs/phaser-8909-export-diagnosis-2026-09-30.md

## Current Branch / Commit
C:/tmp/show-rel detached worktree; checkpoint subject: perf: cache stage identities and budget resolver steps, pushed to origin/qwen. Verify hashes against Git. Do not automatically merge main. Old Documents worktree has pre-existing changes and remains untouched.

## Exact Next Action
User imports v36 and repeats Cue21?24 and Cue2?4 in the same Show, measuring cold/warm GO-to-purple and DETAIL total/scope/engine/steps per tick. Check purple/Group frames, selection changes, Recipe deletion and NEW CONTENT. Use new native timing to choose scope/index or engine work next. Resume per-recipe Phaser proof only after speed priority is satisfied or user changes priority.
