# Project Handoff

## Current Goal
Validate the isolated Generator/Random CompareHandle probe on grandMA3 2.5.0.3. Do not change production identity, tracking or marker logic.

## Current Working State
Production v0.7.0.17 and ENABLE_CUE_PHASER_MARKERS=false unchanged. Extended CompareHandle source is independently deployed in CompareHandle Probe 2.5.0.3; XML/Lua parse and source/deployed SHA256 match. Production Update Plugin three-file snapshot unchanged. Probe separately logs UI widget and production Ptr target, requires visible positive/negative tiles, and distinguishes ObjectList controls. 60 mock assertions PASS. UI alias REAL-WORLD VALIDATION PENDING; database control native PASS.

## Latest Real-World User Test
CompareHandle database control PASS on 2.5.0.3: Recipe Generator 103 class Random/address Generator 103; ObjectList Generator 103 forward/reverse true; Generator 104 false; cost ~0.001 ms. Origin explicitly ObjectList (not UI tile evidence), command_equal/native_equal both true. Does not establish production alias reliability. Earlier GetDependencies native test misses tracking-only Cue/Part references.

## Verified Facts
User native evidence proves GetDependencies is insufficient playback provenance; it must not replace tracking scans. Production source is unchanged. GetDependencies probe was deployed independently previously. CompareHandle mock validation does not establish native reliability. Both probes issue no Show/Recipe/Programmer/playback commands and call no cooked-data API; unspecified controls remain UNVERIFIED.

## Current Problem
Need CompareHandle native pairs from Recipe and actual visible Generator Pool tiles, including different address representations, a distinct Generator negative control, and fresh targets after Recall View. No production replacement is approved by mock success.

## Known Failed Attempts
GetDependencies Current Cue/Part graph misses inherited Recipe/Preset references. v0.7.0.16 used validity-only UI caching and exact command-address matching; hidden grids and Generator aliases caused missing flashes. Do not restore Cue-wide scanning or treat dependency absence as no active effect.

## Important Files
diagnostics/CompareHandle_Probe_2_5_0_3.lua, diagnostics/comparehandle_probe_2_5_0_3.xml, tests/comparehandle_probe.lua, tools/run_comparehandle_probe.py, docs/comparehandle-probe-2.5.0.3.md, docs/getdependencies-probe-2.5.0.3.md, docs/ma3-2.5-capability-audit.md. Production: RecipeTracking_Inspector.lua, recipe_update_diagnostic.xml.

## Current Branch / Commit
qwen. Current experiment subject: `test: separate visible Generator tile and target identity`. Identity experiment subject: `test: add isolated Generator CompareHandle probe`. Native evidence subject: `docs: record native GetDependencies tracking limits`. Earlier Shared Reference integration changes remain uncommitted and must be preserved. Never merge to main without explicit user approval.

## Exact Next Action
Re-import independent XML to refresh cached Lua, or run latest source command, with visible Generator 103 and 104 tiles and Recipe 103, using expected_generator/other_generator. See source launch in docs/comparehandle-probe-2.5.0.3.md. Copy START through END including GRID, UI_TILE, POOL and PAIR; ui_evidence=true required. Missing Ptr or unknown visibility is not success. Seek an actual same-identity pair with different text; ObjectList and same-text UI pairs cannot prove alias solved.
