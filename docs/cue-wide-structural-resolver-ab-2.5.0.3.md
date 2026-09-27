# Cue-wide Structural Resolver A/B — grandMA3 2.5.0.3

REAL-WORLD VALIDATION PENDING. Independent read-only algorithmic pruning experiment. Production v0.7.0.17 / ENABLE_CUE_PHASER_MARKERS=false stays unchanged. No drawing, Show/Recipe/Programmer writes, commands, Pool/View changes, GetDependencies or production CompareHandle integration. Track B remains paused.

## Reason for this experiment

Native Sequence 3841 Cue 8: cooked oracle found 4 final refs, all visible; 31 Parts / 22764 records / 731 advances. Warm native reads ~211.622 ms; processing ~9193.526 ms; corrected core ~9405.148 ms. Modeled waits 73100 ms (~88.6% of 82505.148 ms estimate). Thus native GetPresetData is not the main measured cost here. Removing waits would still leave ~9.4 sec. Large ~4476-record static chunks cost ~140 advances without moving layers. This experiment changes record selection, **not batch size or cadence**.

## Simple native steps

1. Select Sequence 3841 / Current Cue 8 (or the context being tested), leave Show data unchanged during the run. No inspector required and no View operation.
2. Import `cue_wide_structural_resolver_ab_2_5_0_3.xml` from `C:/ProgramData/MALightingTechnology/gma3_library/datapools/plugins/Cue-wide Structural Resolver AB 2.5.0.3`.
3. Execute **Cue-wide Structural Resolver A/B 2.5.0.3** once.
4. Copy Command Line History `[CueStructAB] START` through `END`, including METRICS, FINAL_SET, DIFF, RESULT, REDUCTION, CANDIDATE_TOTAL and AMBIGUITY. Original oracle `[RecipeTracking][EffectScan]` counters may appear between them. No actual cadence sleeps occur; the full oracle can still take seconds.

## A / B / C design and evidence isolation

Execution is deliberately **B → C → A**: structural and hybrid cannot use oracle handles, cooked tables, counts, source provenance or previous probe globals to choose scope. No fixture-specific reference addresses. A is the permitted full cooked oracle and executes only once, last; there is **no full cooked fallback in C**. The historical 22764/731 constants are output denominators only.

**A — exact successful cooked resolver oracle.** Eleven relevant production sections are copied. The current refreshCueEffects state machine runs privately with current source limits, predicates, source-string resolution, sorting, per-layer tracking, same-Part recovery, address-key deduplication and final direct current-Cue merge. The private gate alone is true. Two metadata hooks preserve source Part on private moving-layer items and count supplementary feature records. Removing those hooks reproduces the original sections exactly, checked locally. No semantic repairs to oracle helpers. Failure/non-string sentinel result keys invalidate oracle comparison.

BASELINE FINAL_SET logs DB identity, class/command/native/handle and Preset/Phaser/Generator type. ORACLE_LAYER aggregates surviving source Cue/Part/layer with channel count/sample. ORACLE_DIRECT_MERGE records direct current-Cue Recipe additions even when absent from cooked data. Oracle is the existing algorithm's result, **not a claim of final live-output correctness**.

**B — structural-only tentative result.** Walk ascending history/Parts and inspect all StandardRecipe rows, Enabled, Selection/Group, Values/Generator, raw values and metadata. Group and reference deduplication uses native handle identity/HandleToStr/CompareHandle, never labels or matching command text. Newest exact Group/feature lanes are provisional; abs/rel layer, ordinary Preset moving/static state, Group overlap, manual overrides/releases are explicitly ambiguous. Ordinary Presets are not asserted moving or reliable static terminators. Current-Cue Phaser/Generator direct merge reproduces the oracle's structural behavior. No GetPresetData in B; its local wrapper rejects any accidental call.

All enabled rows, including older and uncertain/static candidates, contribute to C's scope. A provisional lane winner never discards an older row from the fallback scope. Structural set is a tentative comparison hypothesis, **not asserted final active references**.

**C — sparse hybrid.** Read actual Group.Selection sf_index and documented GetUIChannels(sf_index,false). Native feature-family metadata or explicit Generator attributes / PhaserRecipeValueSource Attributes narrow the scope; unknown/all/unsupported metadata widens it. Name/command feature hints used in B are not sufficient to narrow C. The actual 2.5 dump class spelling `PhaserRecipeValueSource` is used for scope metadata. Original production recovery helper semantics remain preserved in A/C, including its different `phaserecipevaluesource` substring; this probe does not repair production.

For each eligible UI channel, retain its earliest candidate Part position. Select only Parts at or after that position with eligible keys. Later non-Recipe Parts must remain because they may override/release a candidate; no API currently proves they are irrelevant. Both abs/rel layers are replayed. This is a conservative subset **within the chosen structural scope**, not a claim of globally minimal or complete Show provenance.

The sparse worker differs from the copied Part worker only at its iterator: direct `data[ui_index]` lookups replace the full `next(data,key)` walk. Missing keys are skipped; actual records use the same channel/layer/recovery and final functions. 32 records per advance and 100 ms modeled cadence remain. GetPresetData still materializes a **complete selected Part table**; the improvement under test is reduced Lua record processing, not a native partial-data API. Supplementary original feature reads are timed/counted separately. No GetPresetDataFast, phasers_only reinterpretation or data from A is reused.

Unavailable Selection/channel mapping or limits abort C with AMBIGUOUS_REQUIRES_FULL_COOKED; it does not read the entire history instead. Manual references outside all Recipe selections, unknown selection expansion and feature/layer coverage remain unresolved. They can yield concrete MISSING_REFERENCE against A. This limitation is mandatory even if this Show gives an exact match.

## A/B comparison and timing

Per phase: structural row count, cooked Parts/read count, cooked numeric records processed, sparse key lookups, supplementary feature records, GetPresetData calls/time, processing residual, total elapsed, advances and unchanged modeled cadence. B's structural row count is shared scope metadata, not a count of every repeated recovery inspection in A/C. CANDIDATE_TOTAL adds B+C time. REDUCTION compares C's Part records/advances to current A and historical 22764/731 separately. This run's A timings can differ from the prior trace because instrumentation/native warmness/order differ.

MA Time() seconds provides wall timing, as confirmed by official installed system-test wait implementation; missing timer yields UNAVAILABLE. Processing includes other MA getters and diagnostic accounting, not pure Lua CPU. Phase output/identity-diff metadata are outside measured core. Because C executes first, it may warm A's native caches; the probe does not assert comparable cold-cache conditions or flush caches. Keep Show data stable: Sequence/Cue pointer checks cannot detect same-Cue edits during the run.

Classification per candidate set: STRUCTURAL_EXACT_MATCH / HYBRID_EXACT_MATCH mean **this stable oracle snapshot has equal DB identity sets**; both missing and extra sets must be empty. MISSING_REFERENCE and EXTRA_REFERENCE log exact handles independently, including simultaneous missing+extra. Hard scope limits/unknowns return AMBIGUOUS_REQUIRES_FULL_COOKED; failed oracle/context/identity/error/output-cap evidence returns UNVERIFIED. All results explicitly say `scope_completeness_proven=false`. One exact native match is experimental evidence, not universal proof or production approval.

Limits: 512 structural Parts, 2048 Recipe rows, 2048 scoped channels, 8192 sparse lookups, 2048 combined Part/feature records, 512 data calls per phase, 8192 advances, 6000 output lines, bounded Phaser metadata traversal. Exceeding a C limit aborts instead of silently falling back to the full 22k walk. Original oracle work/Cue limits are retained; an oracle diagnostic cap makes comparison UNVERIFIED.

## API evidence and local validation

- Shared 2.5.0.3 API index: GetUIChannels(subfixture_index or handle[,return_as_handles]), CompareHandle, GetPresetData, GetUIChannel/GetRTChannel/GetAttributeByUIChannel and Time.
- Installed MA 2.5 `lib_plugins/systemtests/help/system_test_helping_functions_db.lua:848–857` uses GetUIChannels(sfIdx) as an array of numeric UI indices; only that read-only mapping pattern is reused, **not its Programmer calls**.
- Shared object dump confirms class PhaserRecipeValueSource only, not a full property schema. Installed official `lib_presets/predefined_phaser_recipes.xml` contains Attributes/Shape fields; existing production probes read Attributes. Direct Lua availability/type remains runtime evidence: absent/unknown access widens scope instead of inventing a field. Shared reference remains read-only.
- `python tools/run_cue_wide_structural_ab.py`: 87 mock assertions, eleven-section source fidelity, deterministic regeneration, source SHA and disabled flag PASS. Mocks show 4477 baseline records / 141 advances vs 2 sparse records / 2 advances with exact identity agreement; outside-scope manual reference correctly reports MISSING_REFERENCE. These numbers are **mock evidence only**.
- Existing timing probe 93 assertions and workflow 86 assertions remain PASS. Native A/B equality and performance are pending.

Independent deployment verified with `python tools/deploy_cue_wide_structural_ab.py`: source/deployed XML/Lua parse, component existence and SHA256 agreement; complete Update Plugin folder snapshot unchanged and production source blobs match HEAD.

- XML SHA256: `b0f3267bb0e88d2d3cd599137c40057b9af88a24dae519ecdefbf77c528f9aa6`
- Lua SHA256: `c5ca267177ed7bda3f04bda14ba32253e42977ec888adf2ef4bd8245b5f6d082`
