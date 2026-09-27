# Cue-wide Structural Resolver A/B ? grandMA3 2.5.0.3

Revision `5_FINAL_CANDIDATE_FOOTPRINTS`. REAL-WORLD VALIDATION PENDING. Production v0.7.0.17 and `ENABLE_CUE_PHASER_MARKERS=false` unchanged. Read-only diagnostic; no markers, commands, Programmer, Show, Pool or View changes. Track B paused. No main merge.

## Native evidence and failed attempts

Sequence 3841 / Cue 8 Rev1 oracle: Preset 25.9009, 25.9010, 25.9006, 25.9007; 31 Parts, 22764 cooked records, 37 calls, ~146.254 ms native + 5816.739 ms Lua/other reads = 5962.993 ms. Structural: 96 Recipe rows, zero cooked reads, ~341.732 ms, 5 candidates, missing 0, only extra Preset 25.9004. Scope completeness was not proven: DIAGNOSTIC_CHANNEL_SCOPE_LIMIT. Hybrid never ran; its zero references were invalid evidence.

Rev2 loaded `2_CHUNKED_SEEDED`, Structural ~3343.8 ms / zero cooked calls, still 5 candidates with the same sole extra. Hybrid aborted `DIAGNOSTIC_HYBRID_PLAN_LIMIT`: 6 selected Parts, 37 planned chunks, 0 used, 0 calls, 0 inspected/returned records. Source witnesses: Cue 2 Part 0=2752 keys; Cue 7 Part 0=130; Cue 7 Part 4=372. Current evidence: Cue 8 Parts 0/1/2=4556/4556/5606. Total projected positions 17972 exceeded 16384 lookup-plan guard. This is a diagnostic planning failure, not a Hybrid correctness result.

Earlier timing trace ~9.4 sec processing/native and ~73.1 sec additive cadence model did not identify GetPresetData as the dominant bottleneck. Different runs/instrumentation must not be treated as enabled production latency. There is no reliable working purple-marker baseline.

## Native Rev3 evidence

Sequence3841/Cue8: revision3_PART_FIRST_STREAMING correctly loaded, Hybrid executed/result_valid=true; 6 Parts, 7 calls (6 Part cooked + 1 supplementary feature), 2517 actual entries inspected, 2319 matches processed. Hybrid ~856.643ms, Structural ~1068.254ms, candidate total ~1924.897ms versus baseline ~5973.058ms / 22764 records (~89.81% processed-record reduction). Baseline 37calls/~96.951ms native. Structural5 and Hybrid5 vs oracle4: missing0, sole extra Preset25.9004 Dimmer Strobe#4 / #4000166C. Retention SURVIVES_SELECTED_SCOPES_INTERMEDIATE_HISTORY_UNVERIFIED; 25/31 Parts omitted. Faster sparse processing is real evidence for this case, but EXTRA_REFERENCE remains incorrect.

Structural substages: history80.583ms, selection41.972ms, eligible construction945.316ms, resolution0.364ms. Eligible construction dominates; no assumption that native cooked read is the bottleneck.

## Native Rev4: correctness established for this snapshot, performance unacceptable

Sequence3841/Cue8: Structural5, oracle4, Hybrid4, missing0/extra0, HYBRID_EXACT_MATCH. Previous extra Preset25.9004 / #4000166C had source Cue2Part0; SUPERSEDED at Cue3Part0, STATIC_TERMINATOR also at Cue3Part1; FIRST_DECISIVE Cue3Part0 / abs Dimmer / UI10238. Full history transition coverage is promising functional evidence for this case only.

Structural1446.234ms (eligible construction1327.075ms); Hybrid31/31Parts, 22764 actual inspected, 22643 detailed processed, only121 unrelated discarded, ~104.872ms GetPresetData, ~8101.111ms total. Candidate total9547.345ms vs baseline5945.996ms. Transition processing6623.713ms. Universe6838keys, mapping63253iterations, family reads96, mapping1265calls/9621hits, attributes7123calls/56130hits. Rev4 was effectively a heavyweight full-record scan despite membership filtering; it is not acceptable as a performance implementation.

## Rev5 architecture

B retains the full structural Recipe/history walk, existing Group/feature lane candidate generation and pre-oracle Current Cue direct Recipe merge. Only AFTER the Structural final set is frozen are footprints built. Every enabled structural source row for each final DB identity is retained, including older and later re-source events and multiple Groups. Historical moving references absent from the final set, and their static terminator rows, cannot widen tracking scope.

Each final candidate owns a separate UI/channel-key set built only from its source Groups. Feature scope uses the same verified pool-family/explicit attribute metadata rules as Rev4; Name is not used to narrow footprints. Unknown metadata includes all Group channels conservatively. Abs/rel cannot be proven structurally, so both layers are retained and logged. Source rows remain separate from cached membership/key data. No hardcoded references, Cue numbers, Groups, handles or expected result set.

One reverse key ? owning-final-candidates index provides cheap routing. C reads ALL Parts in the original relevant history window once and streams each returned table once. Nonowned numeric keys and nonnumeric entries are discarded before UI/RT/attribute and cooked layer resolution. Relevant records execute copied cooked interpretation once per key; candidates sharing a channel reuse that interpretation. Witnesses/events and final support are attributed only to that key's owning final candidates. Detailed recovery still sees enabled Recipe rows in a matching Part, including nonfinal replacement references, because those can legitimately supersede a final candidate. They generate neither footprints nor new final candidates.

The private final-result reducer collects only candidate-owned support by DB identity and omits irrelevant fixture counting/address reads; copied layer/Recipe recovery semantics remain. Current direct merge behavior is unchanged and labeled PRE_ORACLE_CURRENT_CUE_DIRECT_RECIPE_MERGE. No production32-record batches or100ms waits. Hybrid advances count Parts, not production batches; only BASELINE reports the old cadence model. Oracle A runs LAST with eleven production sections unchanged except existing diagnostic metadata hooks; candidates never consume its state.

Re-sources are never stopped after first superseding. Full history processing can restore the same candidate through later source rows, including another Group/key. SOURCE/STILL_ACTIVE/SUPERSEDED/RELEASED/STATIC_TERMINATOR/NO_EFFECT, TRANSITION_DETAIL and FIRST_DECISIVE remain. Final removal needs positive scoped witnesses, all witnessed support cleared/replaced, no surviving candidate-owned support and cooked loss evidence. A later reappearance resets that lane's earlier loss; unsupported candidates remain ambiguous. FIRST_DECISIVE identifies the earliest decisive loss among the final supported lifetimes, with source/decisive Cue/Part, key, feature/layer, previous/replacement reference and release state; it is not alone proof of global absence.

## Cache and instrumentation

Caches exist only for this invocation and assume Show/selection data stays unchanged: native Group identity ? Selection members; subfixture ? raw UI keys; Group ? raw unique keys; channel ? normalized attribute feature; Group + verified feature-scope signature ? filtered keys. Each candidate reads its reference family/explicit features once. Identical candidate/Group/filter sets merge once without discarding any source row. Different candidate features sharing a Group must have different filters. No cross-run cached Show state or invalidation scheme is introduced.

CANDIDATE_FOOTPRINT reports candidate DB identity, source row/Group counts, independent unique keys and feature/layer scope. CANDIDATE_SOURCE lists every enabled source row. FINAL_CANDIDATE_SCOPE reports reverse-index unique keys, unique cooked records routed, candidate-record routes and candidate layer operations. A shared record counts once as processed but once per owning candidate in route operations; layer operations count each owning-candidate/abs-or-rel interpretation opportunity. They are not native API-call counts.

KEY_CONSTRUCTION separates B footprint/reverse-index construction from C reverse-key-copy cost and their combined key time. STAGE_TIMING covers the original substages; SCOPE_WORK/FOOTPRINT_CACHE quantify membership, mapping, attributes and scope-filter cache reuse. SCOPE_ITERATIONS separates raw mapping entries, feature-filter keys, candidate Group merge keys and reverse-index links from total bounded scope work, so raw mapping_iterations remains comparable to Rev4. Matching semantic timing includes copied interpretation, instrumentation and other native read APIs; unrelated filtering and Part GetPresetData are excluded. METRICS/CANDIDATE_TOTAL report native calls/time, actual inspected entries, detailed records, processing residual, Hybrid total and combined B+C elapsed. Always compare actual inspection and detailed-processing counts separately.

## Correctness limitations and bounds

Structural final candidates are NOT proven to be a superset for arbitrary Shows: ordinary moving Presets, manual content or heuristic lane decisions can be missing. After A only, STRUCTURAL_SUPERSET_LIMITATION logs exact missing DB identities; snapshot_superset_status is ORACLE_SNAPSHOT_SUPERSET_ONLY, STRUCTURAL_NOT_SUPERSET_OF_ORACLE or UNVERIFIED. Missing candidates are never imported from oracle. Hybrid is limited to final candidates and may deliberately expose MISSING_REFERENCE where Rev4's broad scope recovered another object.

Even if the final set contains an object, its structural footprint may omit manual/out-of-Group usage. Candidate support seen on another candidate's key is not accepted as its own. OUTSIDE_CANDIDATE_FOOTPRINT logs that observation when encountered in routed records; unrelated discarded records cannot establish absence. DIFF vs the last-running oracle remains decisive for this snapshot. Exact equality does not prove global completeness, latency, stability or readiness for production.

Finite bounds unchanged from Rev4:512historyParts,131072actual inspected entries,32768processed matching+feature entries,512native reads,30sHybrid elapsed,32768distinct scoped keys,262144bounded scope construction operations and now explicitly262144membership entries,2048Recipe rows. Count errors explicitly invalidate Hybrid. Elapsed checks run every256actual entries, around Part advances/native returns and after final resolution; native calls cannot be preempted. Missing timer means unavailable timing, with count bounds still active. No full heavyweight fallback. The complete oracle still reads/resolves the full history last.

## Native retest

1. Re-import `cue_wide_structural_resolver_ab_2_5_0_3.xml` from `C:/ProgramData/MALightingTechnology/gma3_library/datapools/plugins/Cue-wide Structural Resolver AB 2.5.0.3` into the standalone diagnostic entry.
2. Select the same Sequence/Cue, leave Show data unchanged, run **Cue-wide Structural Resolver A/B 2.5.0.3** once. START must show `5_FINAL_CANDIDATE_FOOTPRINTS`.
3. Copy Command Line History `[CueStructAB] START` through END, especially CANDIDATE_FOOTPRINT/CANDIDATE_SOURCE, FINAL_CANDIDATE_SCOPE, FOOTPRINT_CACHE/SCOPE_ITERATIONS/KEY_CONSTRUCTION, METRICS/PART_STREAM, TRANSITIONS/FIRST_DECISIVE, FINAL_SET/DIFF/RESULT/CANDIDATE_TOTAL and any scope limitation.

Verify full31Part coverage in the same case, dramatically fewer detailed records than22643, and HYBRID_EXACT_MATCH only on actual DB-set equality with stable valid uncapped oracle. Any regression remains diagnostic evidence; production integration is not authorized.

## Local validation

Mocks cover final-only scope pruning, all source rows, multi-Group re-source, duplicate caches, distinct feature filters sharing Group keys, unknown metadata inclusion, nonfinal replacement interpretation, middle-history termination, later release provenance, manual/out-of-footprint limitations, native failure, exact-version gate and safety bounds. Local mocks do not prove native performance/correctness. Deployment verification and final SHA256 are recorded below.

741 A/B assertions passed default runtime and Lua5.4; eleven original oracle section fidelity, disabled production flag/source SHA and deterministic generation passed. Timing93/workflow86 assertions passed. Source and deployed Lua5.4/XML parse and component checks passed; SHA256 Lua `15f18d087e5631416b23917c2713eae7b24ba00c845d7b78a1bcb28e7de0d366`, XML `b0f3267bb0e88d2d3cd599137c40057b9af88a24dae519ecdefbf77c528f9aa6` matched. Actual deployment completed in the independent folder; production source and entire Update Plugin deployed-directory snapshot unchanged. REAL-WORLD VALIDATION PENDING.
