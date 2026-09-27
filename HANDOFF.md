# Project Handoff

## Current Goal
Track A: independent read-only Cue-wide Structural Resolver A/B, grandMA3 2.5.0.3. Exact dormant cooked resolver as oracle; test structural Recipe scope plus bounded sparse-key hybrid. No production/cadence changes. Track B paused; never merge main.

## Current Working State
Production v0.7.0.17 unchanged, purple flag false. Candidate B/C run before oracle A to prevent evidence leakage. B has zero cooked calls; C only touches Group/feature UI indices in ambiguous suffix Parts, with original 32-record batching. Limits abort instead of full fallback. 87 A/B mock assertions and eleven original source sections verified; prior timing 93/workflow86 assertions PASS. REAL-WORLD VALIDATION PENDING.

## Latest Real-World User Test
Sequence 3841 Cue 8:31/31 Parts,22764 records,731 advances,4 final refs/all4 visible,no source/tile misses. Warm native GetPresetData211.622ms, processing9193.526ms, core9405.148ms, modeled waits73100ms, estimate82505.148ms (88.6% wait). Native reads not main measured cost; no-wait still9.4sec. Static4476-record chunks/140advances waste processing.

## Verified Facts
Selected-group Track B path healthy. No stable purple baseline historically. GetDependencies misses tracking-only references. Recipe structure cannot exclude manual stored channels/release or prove abs/rel layers. GetUIChannels mapping is documented/vendor-tested. C direct-key lookup still receives a complete selected Part table. Exact match means current oracle identity set only, scope_completeness_proven=false.

## Current Problem
Need native B/C vs A exact missing/extra handles, data/advance reductions and wall timings. Full cooked walk exists only in A oracle. Unknown membership/limits fail C closed; out-of-scope manual refs produce misses. No production approval from one match.

## Known Failed Attempts
Generic Track B hypotheses downgraded. Do not resume UI/Recall/cache probing, integrate CompareHandle into production, change cadence, or assume purple reliability. Ordinary Preset static/moving state cannot be guessed without cooked evidence.

## Important Files
diagnostics/Cue_Wide_Structural_Resolver_AB_2_5_0_3.lua; diagnostics/cue_wide_structural_resolver_ab_2_5_0_3.xml; tools/build_cue_wide_structural_ab.py; tools/templates/cue_wide_structural_ab_core.lua; tools/run_cue_wide_structural_ab.py; tools/deploy_cue_wide_structural_ab.py; tests/cue_wide_structural_ab.lua; docs/cue-wide-structural-resolver-ab-2.5.0.3.md; docs/cue-wide-trace-timing-2.5.0.3.md.

## Current Branch / Commit
qwen; checkpoint subject `test: compare structural sparse resolver against cooked oracle`. Preserve existing Shared Reference integration uncommitted changes.

## Exact Next Action
REAL-WORLD VALIDATION PENDING: import independent Cue-wide Structural Resolver AB 2.5.0.3 XML, select Sequence3841/Cue8, leave Show unchanged, run once, copy [CueStructAB] START-END with METRICS/FINAL_SET/DIFF/RESULT/REDUCTION/CANDIDATE_TOTAL/AMBIGUITY. Check context/output/oracle validity. Production flag stays false; no main merge.
