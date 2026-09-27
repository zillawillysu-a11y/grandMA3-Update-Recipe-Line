# Cue-wide Structural Resolver A/B - grandMA3 2.5.0.3

Revision 2: bounded chunked Hybrid seeded from Structural candidates. REAL-WORLD RETEST PENDING. Production v0.7.0.17 / ENABLE_CUE_PHASER_MARKERS=false unchanged. No drawing, commands, Show/Recipe/Programmer/Pool/View writes, GetDependencies or production CompareHandle integration. Track B remains paused.

## Native revision 1 evidence: Sequence 3841 / Cue 8

User-reported cooked oracle: Preset 25.9009, 25.9010, 25.9006, 25.9007; 31 Parts, 22764 records, 37 GetPresetData calls, native ~146.254 ms, processing ~5816.739 ms, total ~5962.993 ms.

Structural inspected 96 Recipe rows, zero GetPresetData, ~341.732 ms, 5 candidates: missing 0, exactly one extra Preset 25.9004 Dimmer Strobe#4 from Cue 2. Layer/manual override/release/overlap remained unproven. DIAGNOSTIC_CHANNEL_SCOPE_LIMIT at 2049 keys interrupted scope construction. Planned Current Cue fallback Parts 0/1/2 had 807/999/2049 keys. Hybrid performed ZERO cooked calls; its empty set was NOT a meaningful correctness result.

Earlier timing trace measured ~9.4 sec corrected scanner and ~73.1 sec additive batch-wait model. Different instrumentation/order produced different A/B core timings; neither represents enabled production purple latency. These findings motivate pruning, not merely larger batches/removing waits.

## Simple native retest

1. Re-import the updated `cue_wide_structural_resolver_ab_2_5_0_3.xml` from `C:/ProgramData/MALightingTechnology/gma3_library/datapools/plugins/Cue-wide Structural Resolver AB 2.5.0.3`. Replace only this diagnostic's Pool entry, not Update Plugin.
2. Select Sequence 3841 / Current Cue 8; keep Show data unchanged during the run. No inspector or View operation required.
3. Execute **Cue-wide Structural Resolver A/B 2.5.0.3** once. START must show `diagnostic_revision=2_CHUNKED_SEEDED`.
4. Copy Command Line History `[CueStructAB] START` through END, including FALLBACK_SCOPE, HYBRID_EXECUTION, CHUNK, CANDIDATE_CHANGE, METRICS, FINAL_SET, DIFF, RESULT, REDUCTION, CANDIDATE_TOTAL and AMBIGUITY. Original oracle EffectScan logs may occur between them. Full oracle still takes seconds; no actual cadence sleeps.

## B -> C -> A isolation

Structural candidate/lane decisions and existing logging are preserved. No cooked data in B; its wrapper rejects accidental calls. Group/reference equality is DB handle identity/HandleToStr/CompareHandle, never labels or command-only equality. Ordinary Presets and abs/rel/release/overlap remain ambiguous. Only scope-budget handling changes: 2049 keys causes bounded splitting, not global abort. Separate finite mapping and total-scope caps remain.

C starts with a copy of Structural's candidate set, not an empty set. A executes only AFTER B+C, exactly once as the permitted full oracle. No previous probe global, oracle result, oracle record count or expected reference address influences C. Historical 22764/731 are output denominators only. No reference-specific hardcode.

Eleven production sections are copied for A, including the successful final resolver merge and its current semantics. Removing two metadata hooks reproduces those sections exactly, tested locally. Oracle errors/non-string sentinel keys invalidate comparison. The oracle is the existing algorithm's result, not proof of final live-output provenance.

## Explicit sparse fallback plan and candidate evidence

C selects Current Cue Parts with cumulative eligible Recipe channel scopes. For a historical Structural candidate not already protected by current-Cue direct merge, the newest contributing structural lane source Part is also explicitly selected as SOURCE_WITNESS. Its eligible keys are added to the relevant Current Cue scopes. This small source read is necessary to establish concrete abs/rel witnesses: empty starting channel state cannot prove that an older candidate was released.

Only these planned Parts are cooked; intermediate history is not silently scanned. Maximum 8 unique Hybrid Parts. FALLBACK_SCOPE identifies every Current-Cue evidence/source-witness Part and its key/chunk counts. Adding source-witness keys may conservatively expand the old partial 807/999/2049 plan; logs are authoritative. All source selection is independently derived from Recipe rows, not oracle membership.

Group.Selection sf_index -> documented GetUIChannels(sf_index,false) -> native feature-family/explicit Generator or PhaserRecipeValueSource metadata builds scopes. Unknown/all/unavailable metadata widens them. Names do not narrow C. Standard source recovery predicates are preserved, including the production helper's different `phaserecipevaluesource` substring. Actual dump class is PhaserRecipeValueSource; property accessor availability is runtime evidence. No production repair.

Each Part's sorted eligible keys split into at most 512-key work units. Original 32-record per-advance cooked worker, layer tracking, static/release logic and recovery remain. Chunk boundary EOF may add advances; it does not change batch cadence. Cached native Part tables and private recovery Recipe arrays are reused across chunks, so a Part is natively read once. No globally cached production state or Show mutation. Cache lifetime is this one invocation and assumes no edits.

A positive SOURCE_WITNESS moving layer supports a candidate at a specific channel/abs-or-rel layer. Later scoped cooked evidence can clear it (static/release/remove) or replace its references. Only when all observed supporting layers disappear and transitions are recorded is the candidate removed. Relative support survives an absolute-only override. Without positive witness/conclusive clearing, retain the candidate with ambiguity. Direct current-Cue references retain the existing oracle's merge behavior, not a claim of live activity. Added references require moving references surviving selected cooked scopes or the explicit direct merge.

CANDIDATE_CHANGE logs exact DB handle, removed/added/retained action, witness count and COOKED_STATIC_LAYER / COOKED_RELEASE_OR_REMOVE / SUPERSEDED_BY_COOKED_REFERENCE counts. No absence-only removal or forced four-reference result. Skipped middle-Cue changes and references outside Recipe scope can still cause EXTRA/MISSING against A; `scope_completeness_proven=false` always remains.

## Bounded work and reporting

Bounds: 512 structural Parts/2048 rows, 32768 total mapped channels/262144 mapping operations, 512 keys per chunk, 8192 keys per selected Part, 8 unique Hybrid Parts, 128 chunks, 16384 inspected sparse keys and 8192 combined Part/feature records. Original work limits and 8192 advances, 512 native reads per phase, 6000 output lines and bounded metadata traversal remain. Genuine total limits stop C; no full cooked fallback. 2049 keys fit five chunks.

GetPresetData still returns a COMPLETE selected Part table; this is processing pruning, not a native partial read. READ reports returned records via bounded key-only counting (131072 keys/table), count-limited indicators and overhead. Full values are inspected only through eligible keys. Returned-table counts are separate from sparse keys inspected/records processed; counting cost is included in total Hybrid time and separately logged. It is not hidden as speedup.

METRICS separates B/C/A native GetPresetData, residual Lua/other read APIs and total wall time. MA Time() seconds -> ms; missing timer is UNAVAILABLE. CANDIDATE_TOTAL is B+C including planning/counting. CHUNK reports inspected/processed/completed. HYBRID_EXECUTION reports candidates before/after, selected Parts, chunks, returned/processed counts and cache reuses. REDUCTION compares record/advance counts with current oracle and historical 22764/731. Native A may be warmer because C runs first; no cache flush or equal cold-cache assertion.

RESULT uses exact DB identity sets. STRUCTURAL_EXACT_MATCH / HYBRID_EXACT_MATCH mean equality for this stable oracle snapshot only. Missing and extra exact handles are independent. An unexecuted/aborted C never produces an empty-set correctness result: candidate_result_valid=false, missing/extra and reduction percentages UNAVAILABLE; AMBIGUOUS_REQUIRES_FULL_COOKED or UNVERIFIED is explicit. Keep context/data stable: pointer checks cannot detect edits within the same Cue. Capped output/failed oracle invalidates interpretation. One native match is not permission to change production.

## Evidence and local verification

Shared 2.5.0.3 API index documents GetUIChannels, CompareHandle, GetPresetData and channel/clock APIs. Installed MA system_test_helping_functions_db.lua:848-857 uses numeric UI-index arrays (only this read mapping is reused, not Programmer calls). Shared object dump confirms PhaserRecipeValueSource class; official predefined_phaser_recipes.xml contains Attributes/Shape, not proof of a Lua property schema. Shared repository remains read-only.

128 A/B mock assertions PASS, including exact 807/999/2049 Current-Cue scopes plus source witness: 5 Structural candidates become 4 Hybrid candidates via static evidence, with 4 native Part reads/11 chunks/4662 sparse lookups/808 processed records. A 2050-key case performs one Part read over 5 chunks. Missing source witness retains ambiguity, relative support survives, actual per-Part safety cap prevents execution and does not report fake missing refs. These are mock results only; native removal of the user's extra reference is pending.

Eleven-section oracle fidelity, deterministic generation, current source SHA/disabled flag, existing timing 93 assertions/workflow86 assertions and Lua 5.4 parse PASS. XML/Lua deployment parse and SHA256 are checked by `tools/deploy_cue_wide_structural_ab.py`, including complete Update Plugin snapshot before/after and production source comparison with HEAD. Native retest remains pending.

Revision 2 deployment: XML `b0f3267bb0e88d2d3cd599137c40057b9af88a24dae519ecdefbf77c528f9aa6`; Lua `81e3c5136a9ab06c6b0e1f18dfdb997e1bc36fb8a551fc2c07e68b5a517f2fb0`. Both match source/deployed copies. Import the same independent XML again to reload the changed diagnostic Lua; confirm the revision marker in START.
