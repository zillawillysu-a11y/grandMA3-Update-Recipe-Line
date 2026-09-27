# Project Handoff

## Current Goal
Rev5 standalone Structural A/B on2.5.0.3: FINAL-CANDIDATE-SPECIFIC FOOTPRINTS, full history coverage, sparse candidate semantics. Production unchanged, purple flag false, Track B paused; no main merge.

## Current Working State
5_FINAL_CANDIDATE_FOOTPRINTS: existing Structural candidate generation; only final candidates' enabled source rows build separate feature/Group footprints. Reverse key index routes full history table streams. Candidate-owned witnesses/survivors only; nonfinal refs still participate as cooked replacements, never expand scope/final set. Re-source and FIRST_DECISIVE retained. Per-run Group membership/key/filter and attribute caches; independent scope/cache/work metrics. 741 A/B assertions default+Lua5.4, timing93/workflow86, source fidelity/determinism and source/deployed XML/Lua5.4/SHA256 PASS; independently deployed, production source/folder unchanged. REAL-WORLD VALIDATION PENDING.

## Latest Real-World User Test
Rev4 Sequence3841/Cue8 HYBRID_EXACT_MATCH:5Structural?4Hybrid=4oracle, missing0/extra0. Extra25.9004 sourceCue2Part0, supersededCue3Part0 / absDimmer / key10238, staticCue3Part1. Performance unacceptable:31Parts/22764inspected/22643processed/121discarded,104.872ms native,8101.111ms Hybrid+1446.234ms Structural=9547.345ms vs5945.996ms baseline. Eligible1327.075ms,6838keys/63253mappingiterations; processing6623.713ms.

## Verified Facts
Full history transitions work for this snapshot, Rev4 scope was effectively broad/full. Rev5 final-only footprints preserve all known structural re-sources, expose missing Structural candidates after last-running oracle and out-of-footprint limitations. Current direct merge is pre-oracle. No global superset/completeness assumption.

## Current Problem
Native Rev5 must preserve same-Cue identity equality/full31Part coverage and dramatically reduce22643 detailed records; measure per-candidate keys and cache/scope construction costs. Native latency/crash freedom not proven offline.

## Known Failed Attempts
Rev1/2 blocked before execution; Rev3 omitted decisive intermediate history; Rev4 exact but slower than baseline. Never hardcode expected refs, use oracle for candidates, silently broaden to nonfinal historical scope or enable production.

## Important Files
Core tools/templates/cue_wide_structural_ab_core.lua; generator tools/build_cue_wide_structural_ab.py; diagnostics/Cue_Wide_Structural_Resolver_AB_2_5_0_3.lua; tests/cue_wide_structural_ab.lua; tools/run_cue_wide_structural_ab.py; tools/deploy_cue_wide_structural_ab.py; docs/cue-wide-structural-resolver-ab-2.5.0.3.md.

## Current Branch / Commit
qwen; checkpoint subject `test: scope sparse history trace to final candidates`. Preserve unrelated uncommitted Reference integration. No main merge.

## Exact Next Action
Re-import standalone XML and run same unchanged native Show/Cue. START5_FINAL_CANDIDATE_FOOTPRINTS. Copy START-END with per-candidate footprints/sources, FINAL_CANDIDATE_SCOPE, cache/key/iteration metrics, transitions/FIRST_DECISIVE and DIFF/RESULT. REAL-WORLD VALIDATION PENDING.
