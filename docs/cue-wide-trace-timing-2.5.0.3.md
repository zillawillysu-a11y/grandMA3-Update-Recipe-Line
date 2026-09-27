# Cue-wide Marker Trace + Timing — grandMA3 2.5.0.3

## Scope and native operation

REAL-WORLD VALIDATION PENDING. Independent read-only replay of production v0.7.0.17's dormant scanner. Production ENABLE_CUE_PHASER_MARKERS remains false. No rendering, flash, commands, Show/Recipe/Programmer writes, Pool/View changes, Recall experiment or CompareHandle integration.

Track B is paused: user's completed native Marker Pipeline confirms discovery, visible AllPoolButton → ObjectIndex → PoolObject:Ptr target and sameReference/identity. Cue 8 TILE_MATCH_MISS disappeared when Preset 25.9009 became visible. Purple Cue-wide markers historically were **not reliably working**. This probe does not establish or restore a purple baseline.

1. On **2.5.0.3**, select the Sequence and Current Cue to examine; keep relevant Pool tiles visible. The inspector need not run. Do not change Cue/Sequence/Pool/View during the probe.
2. Import `cue_wide_trace_timing_2_5_0_3.xml` from `C:/ProgramData/MALightingTechnology/gma3_library/datapools/plugins/Cue-wide Marker Trace Timing 2.5.0.3`.
3. Execute **Cue-wide Marker Trace Timing 2.5.0.3** once. It performs first-observed and repeated full scans, then a separate completed-cache check. It does not actually wait between batches.
4. Copy **Command Line History** `[CueWideTrace] START` through `END`, including both SUMMARY lines, READ, BATCH/BATCH_COST and REFERENCE_FINAL/PUBLICATION/EXTRACT. Check `context_stable=true`, `output_capped=false` and error/UNVERIFIED indicators.

## Production fidelity

`tools/build_cue_wide_trace.py` copies eleven production sections, adds private trace hooks and appends `tools/templates/cue_wide_trace_core.lua`. Generated Lua records source version and normalized-source SHA256. Deterministic regeneration/SHA/disabled production flag/ten instrumentation anchors are verified. It never executes production main or replaces global/native APIs. Its local true gate enables only the **private copied scanner**.

Copied functions include trackedRecipeEffects, cueEffectLayer, newCueEffectScan, scanCueEffectPart, finishCueEffectScan, advanceCueEffectScan, currentCueRecipeEffects, addCurrentCueRecipeEffects, refreshCueEffects and reference/Enabled/feature helpers.

- FAST enabled current-Cue StandardRecipe Phaser/Generator references and MEDIUM provisional structural Group/feature winners execute on **host tick 0** in the actual current function. The historical comment saying MEDIUM runs on the next tick does not match invocation order.
- First cooked advance is tick 1, then one per host call. Cues ascend No through Current Cue, Parts ascend Part, recovery Recipes descend index. Channel order is unsorted native Lua `next`, captured exactly.
- Each advance consumes at most **32 entries**, including nonnumeric metadata; one Part per advance. `GetPresetData(part,false,false)` is called once per Part, retaining its table across advances. Exact multiples of 32 need an extra EOF advance. Empty Parts still take one advance.
- Absolute/relative touched layers track independently. Static/release clears only its layer. Enabled same-Part Recipe recovery uses feature and Selection sf_index; known fixture takes the newest match. Completion deduplicates survivors by command address, then merges direct current-Cue Phaser/Generator references even when absent from cooked results. This merge is preserved, **not proof of active playback**.
- Abort retains provisional/direct results; cache capacity, original Cue/work limits, predicates and no unchanged-Cue rescan are retained. Warm full replay is not the production completed-cache hit, separately checked by CACHE_MODEL.
- The existing `memoReferenceAddress` expression `cached == UNRESOLVED_ADDRESS and nil or cached` returns the sentinel table for an unavailable address. A non-string final key is disclosed as SOURCE_MISS, without repairing production or claiming a native occurrence.

## Trace and interpretation

CUE_SCAN records exact Cue/Part order. READ records each cooked Part or supplementary feature native read, first/repeat request, wall duration, count, cumulative native time and error. Completed Part counts reuse scanner counters; incomplete counts remain UNAVAILABLE. Feature result counts use a separate bounded table count with overhead excluded, without another native read.

EXTRACT includes source Cue/Part/Recipe, raw reference/class/command/native/DB handle, direct/history origin, acceptance/rejection reason, feature/layer, occurrences/duplicates, supersession and surviving origin/final inclusion. Identical events aggregate with a representative channel. BATCH captures exact record-key order. Anonymous moving channels without Pool references are counted, not invented as missing Presets. Unresolved Recipe addresses and raw strings ignored by the actual cooked parser are explicit.

BATCH/BATCH_COST report records, advance count/tick, measured native/processing/trace overhead and cumulative wall estimate. PUBLICATION distinguishes earliest provisional/direct publication from final snapshot; first cooked raw discovery is not publication. Original production counters retain os.clock elapsed fields, explicitly labelled **not wall timing**.

GRID/TILE/REFERENCE_FINAL use the native-validated grid/AllPoolButton/ObjectIndex/Ptr/sameReference path read-only. Production cache/discovery branch, Display 1–7, 6000 shared budget/depth20, empty-success UIChildren behavior and command-first fallback are retained. Relevant pool ancestry is a hint, not a new production filter. UI-only methods require UIObject derivation; database targets are not traversal nodes. Visible/IsVisible/IsActuallyVisible evidence is checked separately; uncertainty does not prove absence. ObjectList only resolves production source strings and never substitutes for a tile.

**Consumer limitation:** current refreshPoolMarkers uses recipePoolReferences only, without activeEffects. Scanner → visible tile comparison here is a conditional diagnostic consumer, not proof of purple rendering. Enabling the feature flag alone is not a demonstrated fix.

## Timing components

Primary clock is **MA Time() seconds → milliseconds**, following installed official 2.5 `lib_plugins/systemtests/help/system_test_helping_functions_db.lua:1926` (wait compares Time to start + seconds). Shared 2.5.0.3 API dump confirms the used APIs. Missing/nonmonotonic timing is UNAVAILABLE/UNVERIFIED, never synthesized with os.clock.

- Native total includes every GetPresetData call, including valuesMatchFeature supplementary `GetPresetData(reference,true,false)` reads when required.
- Reference processing = measured host-call wall time minus native GetPresetData and measured hook/counting overhead. Other native MA getters remain in this residual; it is **not pure Lua CPU**. Timer fences, instrumentation/GC interactions cannot be fully removed.
- Estimated loop wait = final host tick × actual REFRESH_SECONDS (100 ms). First tick is separately deferred; internal scanner waits exclude it. No sleep/coroutine cadence is executed.
- Estimated Cue-to-final = corrected core + modeled waits. Actual pass/replay/probe durations are separate. Metadata, UI matching and output run outside core timing; total probe includes them. Other production UI refresh/render work is not measured. The estimate cannot certify <=300 ms native interactivity or explain historical ~6 seconds alone.
- COLD is **first observed request in this probe**, without native cache flushing. WARM is a second full replay with fresh private scanner state; CACHE_MODEL separately measures completed same-Cue refresh without data reads.

Functional classifications: CUE_WIDE_REFERENCE_PATH_COMPLETE, CUE_WIDE_SOURCE_MISS, CUE_WIDE_TILE_MISS, UNVERIFIED. Above 300 ms estimated core+wait, the largest component determines CUE_WIDE_PERFORMANCE_BOTTLENECK_NATIVE_READ / BATCH_WAIT / PROCESSING. Below threshold performance reports CUE_WIDE_REFERENCE_PATH_COMPLETE for this scanner model only; functional status is separate. Compare all totals and dominant share; largest does not mean sole cause.

Bounds: original 512 Cues/131072 work units; diagnostic 8192 host calls, 1024 references/8192 aggregated events, 64 grids/2048 children per grid, 64 raw step samples, 12000 output lines. Relevant bounds/context changes cause UNVERIFIED. Feature counts above 131072 are count_limited. No entire UI dump, generic inventory or extra cooked scan for counts.

## Local validation

`python tools/run_cue_wide_trace_timing.py`: 93 mock assertions plus deterministic generation, source SHA, disabled flag and ten hook anchors PASS. Covers independent layers, tracking/static/release, batch EOF/read reuse, Recipe recovery/direct Phaser/Generator merge, supplementary reads, timing components, missing source/clock/pool/tile, errors/context/version and forbidden calls/production mutation.

`python tools/run_workflow.py`: 86 existing workflow assertions PASS. XML/Lua parse and source/deployed SHA256 verified at deployment. Offline checks do not prove Show-specific correctness, timings or purple behavior. Native evidence is pending.

`python tools/deploy_cue_wide_trace_timing.py` copied only the diagnostic XML/Lua, parsed both source and deployment, checked component existence and matching SHA256, and compared the complete production-folder snapshot before/after. Production source blobs still match HEAD. Deployment hashes:

- XML: `1a6dc64e26d62485129140938560063c35388dc5e024ab8a99e2ec351f544f08`
- Lua: `41ecc7f02a6f2ad44182954d282b25f036e6ab8d90460b566e8351fedab85024`
