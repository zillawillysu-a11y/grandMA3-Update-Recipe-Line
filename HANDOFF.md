# Project Handoff

## Current Goal
Validate a standalone read-only Cue/Part GetDependencies probe on grandMA3 2.5.0.3. Distinguish database candidates from final active references without changing production behavior.

## Current Working State
Production remains v0.7.0.17 with `ENABLE_CUE_PHASER_MARKERS = false`; no runtime changes or deployment in this task. An external-file diagnostic now preserves separate Cue/Part/Recipe/historical dependency graphs, CompareHandle identity, ground-truth checks and first/repeated read timings. Ten mock scenarios plus failure guards pass. User has no native case/reference mapping yet. Probe conclusion: PARTIAL ONLY; REAL-WORLD VALIDATION PENDING.

## Latest Real-World User Test
v0.7.0.16 resolves and displays Generator 103 `S2 Verse` in the panel, but its visible Generator Pool tile does not flash. A Phaser tile can flash initially, then stops after the user recalls the View. This proves Recipe resolution works and the remaining failure is Pool tile/grid matching across Generator aliases and View replacement.

## Verified Facts
Production Lua/XML parse and 86 offline workflow assertions pass. Probe mock assertions pass; they do not prove native GetDependencies behavior. Production files match the prior Git baseline. The diagnostic issues no Show/Recipe/Programmer/playback commands and calls no cooked-data API. Unconfigured truth remains UNVERIFIED. Historical deployment hashes were verified previously, not rechecked in this task.

## Current Problem
Need native 2.5.0.3 ground truth and logs for direct/inherited/override/release/disabled/Phaser/Generator/multi-Part/empty/duplicate cases. API existence and mock success cannot establish active filtering or latency. v0.7.0.17 Generator/Recall View real-world verification also remains pending.

## Known Failed Attempts
v0.7.0.16 cached Pool grids solely by `IsObjectValid`; Recall View can leave old grids valid but hidden. Exact command-address-only matching also misses Generator links represented differently by Recipe and Pool objects. Do not re-enable Cue-wide scanning for live use.

## Important Files
diagnostics/GetDependencies_Probe_2_5_0_3.lua, tests/getdependencies_probe.lua, tools/run_getdependencies_probe.py, docs/getdependencies-probe-2.5.0.3.md, docs/ma3-2.5-capability-audit.md. Production: RecipeTracking_Inspector.lua, recipe_update_diagnostic.xml, tests/recipe_workflow.lua.

## Current Branch / Commit
qwen. Probe checkpoint subject: `test: add read-only grandMA3 2.5.0.3 dependency probe`. Earlier Shared Reference integration changes remain uncommitted and must be preserved. Never merge to main without explicit user approval.

## Exact Next Action
Operator supplies native case mappings, loads the standalone external Lua probe on 2.5.0.3, and records the ten case graphs and cold/warm observations per docs/getdependencies-probe-2.5.0.3.md. Do not auto-create a Show or switch playback, restore purple markers, or replace GetPresetData. Review native logs before upgrading the PARTIAL ONLY conclusion.
