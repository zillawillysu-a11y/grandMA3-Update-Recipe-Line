# Project Handoff

## Current Goal
Deliver a useful three-tier Cue effect resolver: immediate Recipe markers, fast inherited Recipe tracking, and bounded cooked/legacy fallback. Cue-to-purple target is <= 0.3 seconds where Recipe object evidence exists.

## Current Working State
v0.7.0.12 is deployed to the grandMA3 plugin directory. FAST publishes Phaser Recipes/Generators stored in the current Cue before the first yield. MEDIUM runs on the next host tick, scans only the bounded Cue/Part/Recipe object tree, and applies newest Recipe per exact Group+feature. SLOW retains the existing bounded `GetPresetData` channel scan and replaces the provisional result when complete; an abort retains MEDIUM markers. Completed cooked snapshots are still cached. REAL-WORLD VALIDATION PENDING.

## Latest Real-World User Test
The user's external `recipes-highlight.xml` switches almost instantly because it reads only Recipe `SELECTION`/`VALUES` object references and never calls `GetPresetData`. Our v0.7.0.11 already marked current-Cue Phaser Recipes almost instantly, but traditional/cooked Phasers took 6-10 seconds and some never marked. v0.7.0.12 has not yet been tested in grandMA3.

## Verified Facts
87 offline workflow assertions pass, including inherited Recipe publication before the first `GetPresetData`, same-Group/feature static termination, and isolation from other Groups. Lua and XML parse checks pass. The deployed Lua, diagnostic Lua, and Plugin XML SHA256 hashes match repository sources. Offline tests cannot prove native latency or crash freedom.

## Current Problem
MEDIUM should make current and inherited Recipe-based Phaser markers appear within roughly one 0.1-second UI cycle, but native validation is required. Truly traditional/cooked Phasers with no Recipe object evidence still depend on SLOW; the existing diagnostics are needed to locate their 6-10 second cost and unresolved shapes.

## Known Failed Attempts
Four Parts per tick blocked large Shows. Repeated full scans wasted work. Render cache retained deleted Recipe rows and was removed. SheetColor.PhaserText yielded black; GroupedProgLayerActive.Phaser works. Do not increase the 32-record cooked batch as a substitute for diagnosis. MEDIUM exact-Group tracking is provisional because overlapping Groups, releases, and manually stored channels require SLOW correction.

## Important Files
RecipeTracking_Inspector.lua, recipe_update_diagnostic.xml, tests/recipe_workflow.lua, tools/run_workflow.py, tools/check_parse.py, docs/cue-effect-markers.md, AGENTS.md.

## Current Branch / Commit
qwen, checkpoint subject: `perf: add progressive recipe effect resolver`. Never merge to main without explicit user approval.

## Exact Next Action
Reload/import v0.7.0.12 in grandMA3 and cold-test: (1) a Phaser Recipe in the current Cue, (2) an inherited Phaser Recipe from an earlier Cue, (3) a later static Recipe in the same Group+feature, and (4) one traditional/cooked Phaser with no Recipe row. Confirm Recipe cases reach purple within <=0.3 seconds and collect `[RecipeTracking][EffectScan]` history for the traditional case. Also revisit each Cue once to distinguish cached timing.
