# Project Handoff

## Current Goal
Rev4 standalone Cue-wide Structural A/B: full history Part coverage with candidate-key-only detailed semantics on grandMA3 2.5.0.3. Production immutable, purple flag false, Track B paused.

## Current Working State
4_FULL_HISTORY_SPARSE deployed independently. One read/table iteration per history Part, shared candidate-key union, cheap unrelated filtering, copied semantics on matches only. No Hybrid32-record batches/waits. Bounds512Parts/131072actual entries/32768matching+feature entries/512calls/30s. Oracle last. Candidate transition counters and FIRST_DECISIVE removal provenance; later reappearance resets old loss evidence. Added eligible-construction native/cache counters. 688 A/B mocks default+Lua5.4, timing93/workflow86, deterministic/source fidelity, XML/Lua/hash PASS. REAL-WORLD VALIDATION PENDING.

## Latest Real-World User Test
Rev3 Sequence3841/Cue8 valid Hybrid:6Parts/7calls/2517inspected/2319processed/~856.643ms. Structural~1068.254ms, candidate~1924.897ms vs baseline~5973.058ms/22764records, ~89.81% processed reduction. Still5refs vs4, missing0, sole extra25.9004/#4000166C survives selected scope;25/31Parts omitted. Eligible stage945.316ms dominates Structural; native baseline37calls/~96.951ms.

## Verified Facts
Rev3 sparse execution works but intermediate history coverage gap remains. Rev4 covers the same whole relevant history window and retains candidate scope limits. Misleading ORACLE direct-merge label was pre-oracle direct Recipe lookup, renamed without behavioral change. Scope completeness beyond candidate keys not proven. Native equality only per tested snapshot.

## Current Problem
Native Rev4 must prove full Part coverage, cooked transition justifying extra removal if appropriate, identity equality and measured eligible/semantic/filtering costs. Do not infer success from local mocks or expected four refs.

## Known Failed Attempts
Rev1/2 diagnostics aborted before Hybrid. Rev3 selected scopes omitted decisive intermediate history. Do not hardcode candidates, remove unsupported candidates, enable production or optimize production cadence.

## Important Files
Core tools/templates/cue_wide_structural_ab_core.lua; generator tools/build_cue_wide_structural_ab.py; diagnostic diagnostics/Cue_Wide_Structural_Resolver_AB_2_5_0_3.lua; tests/cue_wide_structural_ab.lua; tools/run_cue_wide_structural_ab.py; tools/deploy_cue_wide_structural_ab.py; docs/cue-wide-structural-resolver-ab-2.5.0.3.md.

## Current Branch / Commit
qwen; checkpoint subject `test: trace full-history sparse candidate transitions`. Preserve unrelated uncommitted Reference integration. No main merge.

## Exact Next Action
Re-import standalone XML, same Show/Cue unchanged, START4_FULL_HISTORY_SPARSE. Copy START-END incl TRANSITIONS/FIRST_DECISIVE/SCOPE_WORK/PART_STREAM/METRICS/DIFF/RESULT. Native correctness and latency pending.
