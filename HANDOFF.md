# Project Handoff

## Current Goal
Validate the isolated Generator/Random CompareHandle probe on grandMA3 2.5.0.3. Do not change production identity, tracking or marker logic.

## Current Working State
Production remains v0.7.0.17 with `ENABLE_CUE_PHASER_MARKERS = false`. GetDependencies native evidence is documented: direct structural candidate discovery is suitable, final active/tracking references are not. The new CompareHandle probe has standalone Lua/XML and mock tests; it reads Recipe links and visible Generator Pool tile objects, preserves address differences and requires positive/negative controls. It is deployed independently to the grandMA3 library Plugin folder `CompareHandle Probe 2.5.0.3`. Source/deployed XML and Lua parse passed and SHA256 matched; the production Update Plugin directory snapshot is unchanged. CompareHandle REAL-WORLD VALIDATION PENDING.

## Latest Real-World User Test
User tested GetDependencies on 2.5.0.3: direct Recipe Cue/Part exposes Preset, StandardRecipe and Group. Sequence 14 Cue 2 tracks Cue 1 but Cue/Part 0 graphs each have nodes=1, edges=0; tracked Preset 1.11 and prior Recipe are missing. Timings: Cue cold ~0.063 ms/warm ~0.025 ms; Part cold ~0.022 ms/warm ~0.019 ms. Raw logs/sample counts not supplied. Previous production Generator/Recall View verification remains pending.

## Verified Facts
User native evidence proves GetDependencies is insufficient playback provenance; it must not replace tracking scans. Production source is unchanged. GetDependencies probe was deployed independently previously. CompareHandle mock validation does not establish native reliability. Both probes issue no Show/Recipe/Programmer/playback commands and call no cooked-data API; unspecified controls remain UNVERIFIED.

## Current Problem
Need CompareHandle native pairs from Recipe and actual visible Generator Pool tiles, including different address representations, a distinct Generator negative control, and fresh targets after Recall View. No production replacement is approved by mock success.

## Known Failed Attempts
GetDependencies Current Cue/Part graph misses inherited Recipe/Preset references. v0.7.0.16 used validity-only UI caching and exact command-address matching; hidden grids and Generator aliases caused missing flashes. Do not restore Cue-wide scanning or treat dependency absence as no active effect.

## Important Files
diagnostics/CompareHandle_Probe_2_5_0_3.lua, diagnostics/comparehandle_probe_2_5_0_3.xml, tests/comparehandle_probe.lua, tools/run_comparehandle_probe.py, docs/comparehandle-probe-2.5.0.3.md, docs/getdependencies-probe-2.5.0.3.md, docs/ma3-2.5-capability-audit.md. Production: RecipeTracking_Inspector.lua, recipe_update_diagnostic.xml.

## Current Branch / Commit
qwen. Deployment checkpoint subject: `docs: record isolated CompareHandle probe deployment`. Identity experiment subject: `test: add isolated Generator CompareHandle probe`. Native evidence subject: `docs: record native GetDependencies tracking limits`. Earlier Shared Reference integration changes remain uncommitted and must be preserved. Never merge to main without explicit user approval.

## Exact Next Action
Run the standalone CompareHandle probe on 2.5.0.3 with a visible Generator Pool and a known Recipe Generator; supply expected_generator and a distinct other_generator for controlled checks. Record [CHProbe] START through END with raw/resolved handles, tile origin and address differences. See docs/comparehandle-probe-2.5.0.3.md. Import `comparehandle_probe_2_5_0_3.xml` from the independent deployment folder. Use the controlled Lua launch documented in the probe guide to supply a negative control.
