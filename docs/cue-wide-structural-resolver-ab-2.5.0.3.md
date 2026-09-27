# Cue-wide Structural Resolver A/B ? grandMA3 2.5.0.3

Revision `3_PART_FIRST_STREAMING`. REAL-WORLD VALIDATION PENDING. Production v0.7.0.17 and `ENABLE_CUE_PHASER_MARKERS=false` unchanged. Read-only diagnostic; no markers, commands, Programmer, Show, Pool or View changes. Track B paused. No main merge.

## Native evidence and failed attempts

Sequence 3841 / Cue 8 Rev1 oracle: Preset 25.9009, 25.9010, 25.9006, 25.9007; 31 Parts, 22764 cooked records, 37 calls, ~146.254 ms native + 5816.739 ms Lua/other reads = 5962.993 ms. Structural: 96 Recipe rows, zero cooked reads, ~341.732 ms, 5 candidates, missing 0, only extra Preset 25.9004. Scope completeness was not proven: DIAGNOSTIC_CHANNEL_SCOPE_LIMIT. Hybrid never ran; its zero references were invalid evidence.

Rev2 loaded `2_CHUNKED_SEEDED`, Structural ~3343.8 ms / zero cooked calls, still 5 candidates with the same sole extra. Hybrid aborted `DIAGNOSTIC_HYBRID_PLAN_LIMIT`: 6 selected Parts, 37 planned chunks, 0 used, 0 calls, 0 inspected/returned records. Source witnesses: Cue 2 Part 0=2752 keys; Cue 7 Part 0=130; Cue 7 Part 4=372. Current evidence: Cue 8 Parts 0/1/2=4556/4556/5606. Total projected positions 17972 exceeded 16384 lookup-plan guard. This is a diagnostic planning failure, not a Hybrid correctness result.

Earlier timing trace ~9.4 sec processing/native and ~73.1 sec additive cadence model did not identify GetPresetData as the dominant bottleneck. Different runs/instrumentation must not be treated as enabled production latency. There is no reliable working purple-marker baseline.

## Rev3 execution

Order remains B Structural ? C Hybrid ? A exact production cooked oracle. Oracle runs last and cannot supply candidate decisions. Structural Recipe/reference, Group/feature lane, scope and logging semantics remain; abs/rel/release/overlap and manual content remain explicitly ambiguous.

Hybrid begins with Structural candidates. Selected source-witness and current-Cue Part scopes use the same eligibility rules as Rev2. Each selected Part stores a membership set; it has ONE native cooked read and ONE streaming iteration of that table. Numeric record keys are the UI/channel keys used by the existing scanner. Only eligible numeric entries enter its original moving/layer/reference processing. Nonmatching and nonnumeric entries are filtered but consume actual traversal budget. No sorted key lookup schedule, per-key table lookup plan, duplicate Part chunks or separate full returned-count pass exists.

Each advance inspects at most 128 actual entries and processes at most the original 32 eligible slots. A yielded stream retains the table, cursor and tracking state; the next advance resumes without another native Part read. This bounds diagnostic work; it does not optimize production cadence or claim production latency. Actual waits are absent and modeled separately.

Finite safeguards: 8 selected Parts / at most 8 Part cooked reads; 16384 actual returned entries inspected across selected Parts; 8192 processed eligible plus supplementary feature entries; 8192 advances; 512 total native reads (including original supplementary feature checks); 20-second Hybrid elapsed guard between advances and after a native read. Native calls cannot be interrupted. Missing Time yields unavailable timing; finite count guards still apply. Structural mapping retains 32768 distinct channels, 262144 mapping iterations, 2048 rows, 512 history Parts. Large projected eligible sets alone cannot abort execution. Guard failure is explicit, invalidates Hybrid comparison/reduction, and never invokes full-history fallback. Full oracle remains separate and may still take seconds.

Source-witness layers support removal only if all witnessed support is cleared/replaced, no survivor remains, and cooked transitions substantiate that change. Missing positive witness retains an ambiguous candidate. Surviving moving references can be recovered from selected scopes; direct current Recipe merge follows the existing oracle. No reference/Show/Group identity is hardcoded. Intermediate omitted history and non-Recipe scope completeness are still unproven.

## Structural regression investigation

Exclusive `STAGE_TIMING` reports Recipe/history walk, Group/selection expansion, eligible-key construction, witness-Part selection, chunk/plan construction (Part plans only), candidate resolution and cooked stream filtering. `ran=false` stages were not executed. Lua processing includes other read APIs, not only pure CPU.

Rev2 redundantly evaluated the same reference native address and Preset pool family inside every channel mapping iteration. Rev3 evaluates this invariant once per Recipe row; `SCOPE_WORK family_address_reads` makes the reduction visible. This is a plausible source of the regression, not a proven explanation of the native 3.3-second measurement. Next native substages must establish remaining costs; no API timing is invented.

## Native steps

1. Re-import `cue_wide_structural_resolver_ab_2_5_0_3.xml` from `C:/ProgramData/MALightingTechnology/gma3_library/datapools/plugins/Cue-wide Structural Resolver AB 2.5.0.3`. Replace only this diagnostic entry.
2. Select the same Sequence/Cue and keep Show data unchanged. Run **Cue-wide Structural Resolver A/B 2.5.0.3** once.
3. START must show `diagnostic_revision=3_PART_FIRST_STREAMING`.
4. Copy Command Line History `[CueStructAB] START` through END: FALLBACK_SCOPE, PART_STREAM, STAGE_TIMING, SCOPE_WORK, HYBRID_EXECUTION, READ, FEATURE_WORK, CANDIDATE_CHANGE, FINAL_SET, DIFF, RESULT, METRICS, REDUCTION and CANDIDATE_TOTAL.

`PART_STREAM` separates eligible scope size, actual returned entries, processed matches and filtered entries. READ returned count is known only after that Part finishes streaming; aborted counts are unavailable rather than fabricated. HYBRID_EXECUTION separates projected positions from actual traversal. Hybrid must execute, complete without safety failures and compare DB identity sets against a valid stable uncapped oracle before `HYBRID_EXACT_MATCH` is meaningful. One match proves only this snapshot, not general tracking completeness or permission to modify production.

## Local verification

Deterministic generation and eleven original oracle sections are checked against production. Mocks cover sparse/current/source witnesses, static/release/relative support, missing references, duplicate identity, empty Parts, >2048 scope, >16384 projected positions with small returned data, actual inspected/processed limits, elapsed overrun, native failures, strict version and read-only behavior. Lua 5.4 parse/mock, XML/component validation and source/deployed SHA256 checks are required. Local tests do not establish native performance or reference correctness.

Validation completed: 162 A/B mock assertions under Lua 5.4 and default runtime; eleven original section fidelity and deterministic generation; timing93/workflow86 assertions; source/deployed XML and Lua parse; entire production deployment unchanged. SHA256 Lua `e47c9f1bc2b8d22e3049ec12e3087009ae6a1fc23fbcb24b2a46d06b1abcf51c`, XML `b0f3267bb0e88d2d3cd599137c40057b9af88a24dae519ecdefbf77c528f9aa6` matched source and deployed. Native Rev3 correctness/performance remains pending.
