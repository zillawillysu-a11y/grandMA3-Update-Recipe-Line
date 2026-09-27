# Project Handoff

## Current Goal
Rev3 independent Structural Resolver A/B on grandMA3 2.5.0.3: Part-first sparse Hybrid and exclusive substage timing. Production unchanged, purple flag false. Track B paused; no main merge.

## Current Working State
3_PART_FIRST_STREAMING: one cooked table/read per selected Part, filter actual returned numeric keys against eligible set, bounded 128 inspected / original 32 matching slots per advance. 8 Parts, 16384 actual inspected, 8192 eligible+feature processed, 20s Hybrid elapsed guard. Projected positions do not gate execution. Structural family address evaluated once per row. Oracle last, candidate state seeded; witnessed removals only. REAL-WORLD VALIDATION PENDING.

## Latest Real-World User Test
Rev2 Sequence3841/Cue8: Structural5 vs oracle4; sole extra25.9004. Structural ~3343.8ms vs Rev1~341.7ms, zero cooked calls. Hybrid never executed: DIAGNOSTIC_HYBRID_PLAN_LIMIT, 6 Parts / 37 chunks / 17972 projected keys, zero calls/records. Rev1 oracle31Parts/22764records/37calls/~5962.993ms. No valid Hybrid native result yet.

## Verified Facts
Rev2 per-key projected plan was the immediate blocker. Rev3 streams only selected tables and separately bounds actual traversal/matching processing. Substage timings are required to explain remaining Structural cost. Structural/Hybrid scope completeness remains unproven; exact match means this oracle snapshot only. GetDependencies is not tracking truth. No reliable production purple baseline.

## Current Problem
Native retest must show Hybrid calls >0, actual returned/filtered records within bounds, cooked-supported candidate changes and identity comparison. No production integration based on one match.

## Known Failed Attempts
Rev1 channel scope cap globally aborted. Rev2 projected lookup cap aborted before reads. Do not raise bounds, full-scan history in Hybrid, hardcode refs, remove absent candidates without witnesses or optimize production cadence.

## Important Files
Core tools/templates/cue_wide_structural_ab_core.lua; generator tools/build_cue_wide_structural_ab.py; diagnostic diagnostics/Cue_Wide_Structural_Resolver_AB_2_5_0_3.lua; tests/cue_wide_structural_ab.lua; tools/run_cue_wide_structural_ab.py; tools/deploy_cue_wide_structural_ab.py; docs/cue-wide-structural-resolver-ab-2.5.0.3.md.

## Current Branch / Commit
qwen; checkpoint subject `fix: stream selected Part evidence in Hybrid diagnostic`. Preserve unrelated uncommitted Reference integration.

## Exact Next Action
Re-import standalone XML and run same native case unchanged. START must show3_PART_FIRST_STREAMING. Copy START-END with STAGE_TIMING/PART_STREAM/HYBRID_EXECUTION/CANDIDATE_CHANGE/FINAL_SET/DIFF/RESULT. Verify stable uncapped valid oracle and completed Hybrid. Native correctness/performance pending.
