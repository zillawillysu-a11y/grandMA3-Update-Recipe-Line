# Project Handoff

## Current Goal
Deliver a useful three-tier Cue effect resolver: immediate Recipe markers, fast inherited Recipe tracking, and bounded cooked/legacy fallback. Cue-to-purple target is <= 0.3 seconds where Recipe object evidence exists.

## Current Working State
v0.7.0.14 is deployed to the grandMA3 plugin directory. It resolves Recipe links as handles or address strings and now records the running version. Executing a newly imported version stops and replaces an older instance in one invocation; executing the same version remains an ON/OFF toggle. MEDIUM logs its reference count or abort. REAL-WORLD VALIDATION PENDING.

## Latest Real-World User Test
v0.7.0.12 produced no purple frames at all in the user's real Show, so that implementation is unsuccessful. Two concrete causes were corrected: native Recipe links can be address strings requiring `recipe:Get()` + `ObjectList()`, and the first execution after importing over a running old instance only toggled the old plugin off. v0.7.0.14 has not yet been tested.

## Verified Facts
91 offline workflow assertions pass, covering native-shaped address strings and old-version replacement versus same-version toggle. Lua and XML parse checks pass. All three deployed SHA256 hashes match repository sources. Offline tests cannot prove native latency or marker visibility.

## Current Problem
Confirm whether v0.7.0.14 restores purple frames in the real Show. If not, `progressive cue=... refs=N` versus `progressive_abort` separates Recipe discovery from Pool UI overlay failure. Traditional/cooked Phasers with no Recipe evidence still depend on SLOW.

## Known Failed Attempts
v0.7.0.12's handle-only MEDIUM resolver produced no purple frames in the real Show. Four Parts per tick blocked large Shows. Repeated full scans wasted work. Render cache retained deleted Recipe rows and was removed. SheetColor.PhaserText yielded black; GroupedProgLayerActive.Phaser works. Do not increase the 32-record cooked batch as a substitute for diagnosis.

## Important Files
RecipeTracking_Inspector.lua, recipe_update_diagnostic.xml, tests/recipe_workflow.lua, tools/run_workflow.py, tools/check_parse.py, docs/cue-effect-markers.md, AGENTS.md.

## Current Branch / Commit
qwen. Pending checkpoint subject: `fix: replace stale plugin instance on upgrade`. Never merge to main without explicit user approval.

## Exact Next Action
Import and execute v0.7.0.14 once; it should replace the running older instance without requiring a second execution. Cold-test one Cue that should be purple. If it still is not, report the `[RecipeTracking][EffectScan] progressive cue=... refs=N` line (or `progressive_abort`) from Command Line History.
