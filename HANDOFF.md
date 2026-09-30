# Project Handoff

## Current Goal
Reduce native Cue-to-purple latency toward 300 ms. User prioritizes immediate candidate purple frames followed by background tracking reconciliation; Phaser fixes remain paused.

## Current Working State
v0.7.1.37 locally validated and deployed. New production candidate preview scans enabled Recipe Values/Generator references through current Cue without Group-member, metadata or reverse-lane work, publishes on its own render, then continues v36 bounded resolver. While PENDING candidates remain display-only. Complete PROVEN result removes killed candidates; INCONCLUSIVE removes references with explicit reference-wide exclusion proof while retaining unknown ones. Candidate purple can temporarily include overwritten history; unresolved lanes retain candidates. Selected red attribution and UPDATE safety still use proven data. Cue/structure/forceRefresh rebuild preview. Original MUSE report untouched and untracked.

## Latest Real-World User Test
User rejects v0.7.1.35 speed. Video shows completed panel totals of 1620.1 and 2071.6 ms, and smaller Cues at 386.7/461.6 ms; these are panel observations, not GO-to-purple wall measurements. Screenshot Cue4 shows 510.3 ms and 25.8909 blocked. Older Show opened in 2.5 shows measure/mask rejection. User reports v36 is faster but still insufficient. New 39.55-second video inspected: at 12 s panel is PENDING, 705/1295 members, 446.1 ms. User requests optimistic purple then background removal. v37 REAL-WORLD VALIDATION PENDING.

## Verified Facts
- v37 local validation: 89 workflow assertions, 241 Track A checks, 244 extended probe checks; Lua/XML parse and generated candidate consistency pass. Preview-before-native-reads, no guessed red attribution, background kill removal, Recipe deletion, unresolved retention and Cue switching covered.
- Intended XML and both referenced Lua files copied; all source/deployed SHA256 values match. Backup: C:/tmp/update-plugin-pre-0.7.1.37. Hash equality proves deployment identity only.
- Offline controlled-clock model reduces 12,650-member scheduling from 51 ticks to 13; native speed remains unknown.
- RRR/SEQREF confirm Shutter Shuffle is referenced in enabled Cue4 Recipes and has three direct PhaserRecipes (3/2/2 steps). Parser accepts exactly one, explaining rejection if native structure matches XML.
- Additional older and range exports parsed successfully; diagnostic notes record their structure. No Show data changed.

## Current Problem
Native v37 preview latency and reconciliation need user testing. Candidate history may be broad and unresolved frames may persist; complete proof latency is unchanged by preview. Scope preparation (94?155 ms in video) may remain a bottleneck. Multi-recipe and raw-measure Phaser failures require distinct proofs; neither is fixed in v36.

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
C:/tmp/show-rel detached worktree; checkpoint subject: perf: preview candidate frames before background tracking, pushed to origin/qwen. Verify hashes against Git. Do not automatically merge main. Old Documents worktree has pre-existing changes and remains untouched.

## Exact Next Action
User imports v37, repeats same Cue transitions and records first-purple latency separately from final convergence. Check overwritten candidates disappear after complete proof, quick Cue changes do not retain previous preview, selected red remains correct, Recipe deletion and NEW CONTENT. If preview is still slow, measure fingerprint/history/Pool work before further optimization. Phaser repair remains paused.
