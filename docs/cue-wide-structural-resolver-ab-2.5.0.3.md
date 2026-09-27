# Cue-wide Structural Resolver A/B ? grandMA3 2.5.0.3

Revision `4_FULL_HISTORY_SPARSE`. REAL-WORLD VALIDATION PENDING. Production v0.7.0.17 and `ENABLE_CUE_PHASER_MARKERS=false` unchanged. Read-only diagnostic; no markers, commands, Programmer, Show, Pool or View changes. Track B paused. No main merge.

## Native evidence and failed attempts

Sequence 3841 / Cue 8 Rev1 oracle: Preset 25.9009, 25.9010, 25.9006, 25.9007; 31 Parts, 22764 cooked records, 37 calls, ~146.254 ms native + 5816.739 ms Lua/other reads = 5962.993 ms. Structural: 96 Recipe rows, zero cooked reads, ~341.732 ms, 5 candidates, missing 0, only extra Preset 25.9004. Scope completeness was not proven: DIAGNOSTIC_CHANNEL_SCOPE_LIMIT. Hybrid never ran; its zero references were invalid evidence.

Rev2 loaded `2_CHUNKED_SEEDED`, Structural ~3343.8 ms / zero cooked calls, still 5 candidates with the same sole extra. Hybrid aborted `DIAGNOSTIC_HYBRID_PLAN_LIMIT`: 6 selected Parts, 37 planned chunks, 0 used, 0 calls, 0 inspected/returned records. Source witnesses: Cue 2 Part 0=2752 keys; Cue 7 Part 0=130; Cue 7 Part 4=372. Current evidence: Cue 8 Parts 0/1/2=4556/4556/5606. Total projected positions 17972 exceeded 16384 lookup-plan guard. This is a diagnostic planning failure, not a Hybrid correctness result.

Earlier timing trace ~9.4 sec processing/native and ~73.1 sec additive cadence model did not identify GetPresetData as the dominant bottleneck. Different runs/instrumentation must not be treated as enabled production latency. There is no reliable working purple-marker baseline.

## Native Rev3 evidence

Sequence3841/Cue8: revision3_PART_FIRST_STREAMING correctly loaded, Hybrid executed/result_valid=true; 6 Parts, 7 calls (6 Part cooked + 1 supplementary feature), 2517 actual entries inspected, 2319 matches processed. Hybrid ~856.643ms, Structural ~1068.254ms, candidate total ~1924.897ms versus baseline ~5973.058ms / 22764 records (~89.81% processed-record reduction). Baseline 37calls/~96.951ms native. Structural5 and Hybrid5 vs oracle4: missing0, sole extra Preset25.9004 Dimmer Strobe#4 / #4000166C. Retention SURVIVES_SELECTED_SCOPES_INTERMEDIATE_HISTORY_UNVERIFIED; 25/31 Parts omitted. Faster sparse processing is real evidence for this case, but EXTRA_REFERENCE remains incorrect.

Structural substages: history80.583ms, selection41.972ms, eligible construction945.316ms, resolution0.364ms. Eligible construction dominates; no assumption that native cooked read is the bottleneck.

## Rev4: complete Part coverage, sparse semantics

Order B Structural ? C full-history sparse ? A exact cooked oracle. Structural remains independent candidate generator; oracle last. One shared membership set unions keys from every enabled Structural candidate row, including all moving rows and ordinary/static row scopes conservatively retained from prior diagnostics. This intentional superset preserves recovery/override opportunities. No expected reference, Show, Cue, Group or handle is hardcoded.

Every Part in the existing production-relevant history window through Current Cue is planned exactly once. One native table/read and one iterator per Part. Every returned entry gets cheap numeric-key/set membership filtering; only matching entries execute the copied cooked tracking/layer/release/override and reference-recovery semantics. Unrelated entries never invoke per-channel UI/RT/attribute resolution. There is no 32-record Hybrid batching, no actual cadence sleep, no nested coroutine. Production and the last-running oracle retain their original algorithm; timing models are separate from diagnostic execution.

Finite bounds now match the full-history architecture: 512 Parts, 131072 actual inspected entries, 32768 matching plus supplementary feature processed entries, 512 total native calls, 30s Hybrid elapsed checked during filtering/between Part calls/after calls and final resolution. Native API calls cannot be interrupted. Exceeding any limit explicitly invalidates Hybrid; no silent full-heavyweight fallback. These are full-window diagnostic caps, not production changes. Structural bounds remain 32768 distinct keys, 262144 mapping iterations, 2048 rows, 512 Parts. Missing timer yields unavailable timings; count caps remain enforceable.

Candidates are seeded from Structural. Cooked source witnesses and final per-key abs/rel support govern removal; all witnessed support must end replaced/cleared and no final survivor can remain. Unsupported candidates stay ambiguous. SOURCE/STILL_ACTIVE/NO_EFFECT/SUPERSEDED/RELEASED/STATIC_TERMINATOR events are counted by DB identity; TRANSITION_DETAIL also groups evidence by history Part, layer and event, with source/key/feature samples; SUPERSEDED covers a cooked replacement/override by another moving reference. Per-record stdout is avoided. FIRST_DECISIVE prints every removed candidate's first decisive loss among final supported lifetimes: original source Cue/Part, decisive Cue/Part, UI key, layer, feature, previous reference, replacement, release state and exact reason. A later reappearance invalidates that lane's earlier loss; final removal still depends on all witnessed layers, not one transition.

Complete history Part coverage does not prove candidate-key completeness for unrelated manual content. HYBRID_EXACT_MATCH means only identity equality with this stable valid oracle snapshot. Missing/outside-scope references remain visible in DIFF; no success is inferred from API existence or speed.

## Scope performance instrumentation and provenance audit

STAGE_TIMING separates history, selection, eligible construction, witness/union selection, Part-plan construction, candidate resolution and streaming. SCOPE_WORK adds mapping iterations, GetUIChannels calls/cache hits/native time, attribute calls/cache hits/read+label time, invariant family-address reads, unique union keys, union construction time and matching semantic processing time. Counters quantify existing per-subfixture and per-channel cache reuse; no new cross-run Group/key cache is added. Eligible stage minus measured native subcomponents still includes hash/set work, overlap, row iteration and other getters; do not label that residual pure CPU. Native retest identifies whether reusable Group-level scopes are worth a later experiment.

Matching semantic timing wraps the copied detailed processing for an eligible returned entry; it includes instrumentation and other read APIs, excludes Part GetPresetData and unrelated filtering. Full C elapsed includes union planning, all native reads, filtering and final candidate resolution. Reduction of matching records must be read together with actual inspected count; it is not a reduction of all table traversal.

`EXISTING_ORACLE_CURRENT_RECIPE_MERGE` was a misleading label: code invokes currentCueRecipeEffects before A, reads current Cue Recipe objects directly and never consumes baseline final state. Renamed to `PRE_ORACLE_CURRENT_CUE_DIRECT_RECIPE_MERGE`, preserving behavior. Direct merge remains an existing scanner rule, not active-playback provenance proven by this diagnostic.

## Native steps

1. Re-import `cue_wide_structural_resolver_ab_2_5_0_3.xml` from `C:/ProgramData/MALightingTechnology/gma3_library/datapools/plugins/Cue-wide Structural Resolver AB 2.5.0.3` into the standalone diagnostic entry.
2. Select the same Sequence/Cue and leave Show data unchanged. Run **Cue-wide Structural Resolver A/B 2.5.0.3** once. START must show `4_FULL_HISTORY_SPARSE`.
3. Copy Command Line History `[CueStructAB] START` through END, especially TRANSITION_DETAIL, METRICS, STAGE_TIMING, SCOPE_WORK, PART_STREAM, HYBRID_EXECUTION, TRANSITIONS, FIRST_DECISIVE, CANDIDATE_CHANGE, FINAL_SET, DIFF, RESULT and CANDIDATE_TOTAL.

Check planned/read/completed history Parts agree, no missing/uninspected Parts, stable uncapped valid oracle and valid Hybrid. FIRST_DECISIVE must justify any removed candidate; no native exact-match claim before this retest.

## Local validation and deployment

688 A/B mock assertions passed default runtime and Lua5.4, including middle-history static termination, later reappearance/release provenance, full Part coverage, projected-scope independence, actual inspected/processed bounds and elapsed guard. Eleven oracle sections/source fidelity, deterministic generation, timing93/workflow86 assertions passed. Source/deployed XML/components and Lua parse passed; entire production source/deployed directory unchanged. No markers or Show edits. SHA256 Lua `e4f592a565027170dc78a0bec031be577c2bc23432b0b62fc9e7a58a265dab1f`, XML `b0f3267bb0e88d2d3cd599137c40057b9af88a24dae519ecdefbf77c528f9aa6` matched. REAL-WORLD VALIDATION PENDING; local mocks cannot establish native correctness, speed or crash freedom.
