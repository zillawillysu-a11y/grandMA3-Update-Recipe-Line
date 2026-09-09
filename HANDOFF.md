# Project Handoff

## Current Goal
Diagnose why legacy/cooked Phaser Cues take 6–10 seconds or fail to mark, then design a bounded three-tier resolver. Phaser Recipe direct markers must stay immediate.

## Current Working State
v0.7.0.11 deployed to the grandMA3 plugin directory with matching SHA256 on all three files. It extends the v0.7.0.10 EffectScan instrumentation: per-Part and total `elapsed_ms` (guarded standard-Lua `os.clock`, prints `n/a` when unavailable; the Part clock starts before the native `GetPresetData` read so it includes that cost), a `cancelled` log for scans discarded mid-flight by Cue changes or marker shutdown, and a per-scan memo so reference classification costs one `ToAddr` per unique reference. The final result pass reuses the same memo and therefore performs strictly fewer address lookups than v0.7.0.10. Batch structure (32 records/advance, one advance per tick, one `GetPresetData` per Part), marker behavior, and Recipe handling are unchanged.
REAL-WORLD VALIDATION PENDING. No resolver behavior change has been made.

## Latest Real-World User Test
Phaser Recipe Show markers appear almost instantly. A grandMA3 2.3.2.0 Show with many traditional/cooked Phasers takes 6–10 seconds; some legacy Phasers never mark. This persisted after v0.7.0.9/0.10. No v0.7.0.11 test yet.

## Verified Facts
84 offline assertions pass (83 pre-existing + 1 new diagnostic-evidence check), run via `tools/run_workflow.py` (bundled Lua through lupa; no system Lua installed on this machine). `tools/check_parse.py` covers Lua + XML parse. A 1000-channel Part requires exactly 32 advances at the current batch size. Native latency and actual legacy data shapes remain unverified. The 0.3-second target is NOT native-validated.

## Current Problem
Where the 6 seconds are spent is still unmeasured: batch pacing (advances × ~0.11 s tick) vs native `GetPresetData` cost vs per-channel processing. The v0.7.0.11 `elapsed_ms` fields plus `channels`/`advances`/`first_ref_advance` answer this directly; the next required evidence is the user's real-world diagnostic output in a slow Show.

## Known Failed Attempts
Four Parts per tick blocked large Shows. Repeated full scans wasted work. Render cache retained deleted Recipe rows and was removed. SheetColor.PhaserText yielded black; GroupedProgLayerActive.Phaser works. Do not increase the 32-record batch as a substitute for diagnosis.

## Important Files
RecipeTracking_Inspector.lua, recipe_update_diagnostic.xml, tests/recipe_workflow.lua, tools/run_workflow.py, tools/check_parse.py, docs/cue-effect-markers.md, AGENTS.md.

## Current Branch / Commit
qwen, pushed to origin/qwen. This checkpoint's subject: `perf: add elapsed time and memoized ref classification to EffectScan`. Previous checkpoint subject: `perf: instrument cooked Phaser effect scans`.

## Exact Next Action
In grandMA3, collect `[RecipeTracking][EffectScan]` Command Line History for one fast Phaser Recipe Cue, one slow legacy Cue, and one no-marker legacy Cue. Use `channels`, `advances`, `first_ref_advance`, `elapsed_ms`, and the failure counters to decide the FAST/MEDIUM/SLOW implementation; preserve bounded work and add progressive publish only for confirmed Pool refs.
