# Project Handoff

## Current Goal
Track A: independent read-only Cue-wide Marker Trace + Timing Probe, target grandMA3 2.5.0.3. Replay current disabled scanner; separate native/processing/modeled loop waits and conditionally match visible tiles. Track B paused. No production changes or main merge.

## Current Working State
Production v0.7.0.17 unchanged, ENABLE_CUE_PHASER_MARKERS=false. Standalone generated replay preserves order, 32-record batching, tracking/recovery/direct merge/cache and supplementary reads. 93 mock assertions, deterministic generation/source SHA/ten hook anchors and 86 workflow assertions PASS. Independent deployment folder/name: Cue-wide Marker Trace Timing 2.5.0.3. REAL-WORLD VALIDATION PENDING.

## Latest Real-World User Test
Selected-group Marker Pipeline healthy: discovery, visible AllPoolButton/ObjectIndex/Ptr and sameReference/identity work. Cue 8 TILE_MATCH_MISS disappeared when Preset 25.9009 became visible. Stop broad UI/Recall/cache probing. Cue-wide purple markers historically NOT reliably working and currently disabled; no working before/after baseline.

## Verified Facts
GetDependencies misses tracking-only references. Two Recall replacements invalidate OLD; 12 child paths agree; discovery finds all 12 at 1950/6000 nodes. Generic hypotheses downgraded. refreshPoolMarkers consumes selected-group references, not activeEffects. FAST/MEDIUM execute on scanner host tick 0; cooked begins tick 1. Loop wait modeled only.

## Current Problem
Need native component timings and source/reference trace for one Current Cue, without assuming native reads dominate or purple behavior works. Other production render work excluded; processing residual includes other MA getters. Native cache not flushed; full-repeat replay differs from completed result-cache hit.

## Known Failed Attempts
No proven alias mismatch, stale-valid grid, empty UIChildren or shared-budget root cause in tested Shows. No CompareHandle production integration. Empty Generator tile indices are not bug evidence and remain uninvestigated.

## Important Files
diagnostics/Cue_Wide_Trace_Timing_2_5_0_3.lua; diagnostics/cue_wide_trace_timing_2_5_0_3.xml; tools/build_cue_wide_trace.py; tools/templates/cue_wide_trace_core.lua; tests/cue_wide_trace_timing.lua; tools/run_cue_wide_trace_timing.py; docs/cue-wide-trace-timing-2.5.0.3.md.

## Current Branch / Commit
qwen; checkpoint subject `test: add read-only Cue-wide scanner timing replay`. Preserve pre-existing Shared Reference integration uncommitted changes. Never merge main.

## Exact Next Action
REAL-WORLD VALIDATION PENDING: select Sequence/Current Cue with relevant tiles visible, import independent cue_wide_trace_timing_2_5_0_3.xml, run once without changing context and copy [CueWideTrace] START-END. Compare both SUMMARY native/processing/wait totals, earliest publication vs final tick, source/tile results. Reject capped/unstable/unverified evidence. Do not enable production or claim purple restoration.
