# Project Handoff

## Current Goal
Revise only independent Cue-wide Structural Resolver A/B on 2.5.0.3 so bounded seeded Hybrid executes. Preserve Structural logic/logging, oracle-after-B/C, production purple flag false. Track B paused; no main merge.

## Current Working State
Revision2_CHUNKED_SEEDED: 512-key chunks, one native read/private Recipe cache per Part, 8 selected-Part cap, 16384 sparse lookups/8192 processed-record caps. C begins with Structural refs; current-Cue scoped evidence plus explicit historical candidate SOURCE_WITNESS. Remove only when witnessed layers clear/replace; retain ambiguous candidates. Unexecuted C has no meaningful missing/extra/speedup. 128 A/B assertions/source fidelity, timing93/workflow86, Lua5.4 parse PASS. REAL-WORLD RETEST PENDING.

## Latest Real-World User Test
Revision1 Sequence3841/Cue8 oracle4 refs:25.9009/.9010/.9006/.9007,31 Parts,22764 records,37 calls,146.254ms native+5816.739ms processing=5962.993ms. Structural96 rows/0calls/341.732ms,5 candidates,only extra25.9004 Dimmer Strobe#4 fromCue2. Scope cap2049 interrupted; plannedCurrentParts0/1/2 keys807/999/2049. Hybrid0reads DID NOT EXECUTE; empty result is not correctness evidence.

## Verified Facts
Old2048 key cap globally blocked valid sparse plan. Structural candidate set/lane semantics preserved. Source cooked witness required to infer old layer support safely; unknown/uncleared support stays ambiguous. Intermediate history is unscanned and not globally excluded; exact match is current oracle snapshot only. GetDependencies not tracking truth. No reliable purple baseline; Track B path healthy and paused.

## Current Problem
Native retest must confirm chunks execute, source witness exists, extra candidate removed only with static/release/superseding evidence, exact 4 DB refs vs oracle and timings/reductions. No production integration from one match.

## Known Failed Attempts
Revision1 globally aborted at2049keys; 0-ref Hybrid invalid. Do not enable production, change cadence, full-scan31Parts in Hybrid, hardcode expected refs or remove candidates merely for absent current evidence. Track B broad hypotheses remain downgraded.

## Important Files
diagnostics/Cue_Wide_Structural_Resolver_AB_2_5_0_3.lua; tools/templates/cue_wide_structural_ab_core.lua; tools/build_cue_wide_structural_ab.py; tests/cue_wide_structural_ab.lua; tools/run_cue_wide_structural_ab.py; tools/deploy_cue_wide_structural_ab.py; docs/cue-wide-structural-resolver-ab-2.5.0.3.md.

## Current Branch / Commit
qwen; checkpoint subject `fix: execute bounded seeded Hybrid diagnostic`. Preserve pre-existing Reference integration uncommitted changes. Never merge main.

## Exact Next Action
REAL-WORLD RETEST PENDING: re-import updated independent diagnostic XML, select3841/Cue8, leave Show unchanged, run once. START must show2_CHUNKED_SEEDED. Copy START-END including FALLBACK_SCOPE/HYBRID_EXECUTION/CHUNK/CANDIDATE_CHANGE/METRICS/FINAL_SET/DIFF/RESULT/REDUCTION/CANDIDATE_TOTAL. Verify hybrid_executed/result_valid, uncapped stable oracle. Production unchanged.
