# Project Handoff

## Current Goal
Bounded native UI topology research on grandMA3 2.5.0.3. CompareHandle production integration STOPPED; do not change production matching/tracking/markers.

## Current Working State
Independent UI Topology Probe Lua/XML deployed to library plugins/UI Topology Probe 2.5.0.3; source/deployed parse PASS and SHA256 MATCH, production Update Plugin snapshot unchanged. 15 topology mock assertions PASS. Inspects discovered Generator Pool grid, ancestors, siblings, depth-5 descendants, multiple child paths and exposed properties. No ObjectList/cooked reads/writes. Production v0.7.0.17 with Cue-wide markers disabled unchanged. UI topology REAL-WORLD VALIDATION PENDING.

## Latest Real-World User Test
CompareHandle database control PASS: Recipe Random/Generator 103 vs ObjectList 103 forward/reverse true, 104 false, ~0.001 ms. Native UI-target extraction failed: AllPoolLayoutGrid/Generators/GeneratorRandom discovered but visible=UNAVAILABLE, buttons=0, targets=0; other grids similar. ui_status NO_VISIBLE_UI_TARGET_HANDLE, ui_targets=0, alias_status NOT_OBSERVED.

## Verified Facts
Prior probe returned before button enumeration on unavailable IsActuallyVisible; zero counts do not prove virtualization. MA 2.5 vendor Pool scrolling test reads grid:Ptr(5).ObjectIndex. GetUIChild/GetUIChildrenCount, Ptr/Count and IsVisible are documented reads. Database identity is not UI alias evidence. GetDependencies remains unsuitable for final tracking references.

## Current Problem
Need actual native hierarchy/cell-target evidence for visible Generator 103/104; topology and virtualization unverified.

## Known Failed Attempts
UIChildren plus strict IsActuallyVisible filtering yielded no UI targets. ObjectList control is not tile extraction proof. GetDependencies tracking-only Cue misses inherited Recipe/Preset references.

## Important Files
diagnostics/UI_Topology_Probe_2_5_0_3.lua, diagnostics/ui_topology_probe_2_5_0_3.xml, tests/ui_topology_probe.lua, tools/run_ui_topology_probe.py, docs/ui-topology-probe-2.5.0.3.md, docs/comparehandle-probe-2.5.0.3.md, RecipeTracking_Inspector.lua.

## Current Branch / Commit
qwen; checkpoint subject `test: add bounded grandMA3 UI topology diagnostic`. Earlier Shared Reference integration changes remain uncommitted and must be preserved. Never merge main automatically.

## Exact Next Action
Import UI Topology Probe XML into a separate slot, show Generator 103/104 and optionally Group/Preset Pool, press diagnostic once and copy [UITopo] START through END. Native topology validation pending; do not integrate CompareHandle into production.
