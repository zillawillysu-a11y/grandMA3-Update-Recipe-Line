# Project Handoff

## Current Goal
Deliver a useful three-tier Cue effect resolver: immediate Recipe markers, fast inherited Recipe tracking, and bounded cooked/legacy fallback. Cue-to-purple target is <= 0.3 seconds where Recipe object evidence exists.

## Current Working State
v0.7.0.13 is deployed to the grandMA3 plugin directory. It retains the three-tier resolver but now resolves Recipe `Selection`, `Values`, and `Generator` links whether grandMA3 exposes them as handles or address strings; strings use the reference plugin's proven `recipe:Get()` + `ObjectList()` path. MEDIUM logs its reference count or abort. SLOW retains the bounded `GetPresetData` scan. REAL-WORLD VALIDATION PENDING.

## Latest Real-World User Test
v0.7.0.12 produced no purple frames at all in the user's real Show, so that implementation is unsuccessful. The external `recipes-highlight.xml` switches almost instantly using `recipe:Get("SELECTION")`, `recipe:Get("VALUES")`, and `ObjectList(address)`. Inspection identified that v0.7.0.12's new MEDIUM path admitted only object handles, so native string links were skipped. v0.7.0.13 has not yet been tested.

## Verified Facts
89 offline workflow assertions pass, including native-shaped `Get()` address strings resolved through `ObjectList` for both current-Cue and progressive Recipe paths. Lua and XML parse checks pass. All three deployed SHA256 hashes match repository sources. Offline tests cannot prove native latency or marker visibility.

## Current Problem
Confirm whether address-string resolution restores purple frames in the real Show. If not, `progressive cue=... refs=N` versus `progressive_abort` separates Recipe discovery from Pool UI overlay failure. Traditional/cooked Phasers with no Recipe evidence still depend on SLOW.

## Known Failed Attempts
v0.7.0.12's handle-only MEDIUM resolver produced no purple frames in the real Show. Four Parts per tick blocked large Shows. Repeated full scans wasted work. Render cache retained deleted Recipe rows and was removed. SheetColor.PhaserText yielded black; GroupedProgLayerActive.Phaser works. Do not increase the 32-record cooked batch as a substitute for diagnosis.

## Important Files
RecipeTracking_Inspector.lua, recipe_update_diagnostic.xml, tests/recipe_workflow.lua, tools/run_workflow.py, tools/check_parse.py, docs/cue-effect-markers.md, AGENTS.md.

## Current Branch / Commit
qwen. Pending checkpoint subject: `fix: resolve native Recipe address strings`. Never merge to main without explicit user approval.

## Exact Next Action
Reload/import v0.7.0.13 and cold-test one Cue that should be purple. If it still is not, report the `[RecipeTracking][EffectScan] progressive cue=... refs=N` line (or `progressive_abort`) from Command Line History; this is the minimum evidence needed for the next source change.
