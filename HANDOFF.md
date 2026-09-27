# Project Handoff

## Current Goal
Bounded native UI topology research on grandMA3 2.5.0.3. CompareHandle production integration STOPPED; do not change production matching/tracking/markers.

## Current Working State
Revision 2 standalone UI topology repair added: native IsClassDerivedFrom guards every UI-only call; database handles are logged only. Direct known-grid lookup precedes per-display class search; all 1-7 roots checked before detailed read/node/depth caps start. Generator neighborhood first, optional Group/Preset control. 23 mock assertions PASS. Production v0.7.0.17 unchanged. Revision 2 independently deployed; source/deployed XML/Lua parse PASS and SHA256 MATCH, production Update Plugin snapshot unchanged. Native validation PENDING; integration STOPPED.

## Latest Real-World User Test
UI topology run PROBE INVALID / RETEST REQUIRED: native errors from UIChildren/GetUIChildrenCount/GetUIChild on non-UI handles; NO_GENERATOR_GRID at 914 discovery nodes, 5 grids, truncated=true. Generator AllPoolLayoutGrid previously found at Display 3.5.3.1.5.1.4.4 with Generators/GeneratorRandom. Earlier database CompareHandle control remains PASS; no UI alias evidence.

## Verified Facts
Prior probe returned before button enumeration on unavailable IsActuallyVisible; zero counts do not prove virtualization. MA 2.5 vendor Pool scrolling test reads grid:Ptr(5).ObjectIndex. GetUIChild/GetUIChildrenCount, Ptr/Count and IsVisible are documented reads. Database identity is not UI alias evidence. GetDependencies remains unsuitable for final tracking references.

## Current Problem
Need actual native hierarchy/cell-target evidence for visible Generator 103/104; topology and virtualization unverified.

## Known Failed Attempts
Old topology called UI APIs on non-UI objects and shared global discovery cap starved later displays; run invalid. CompareHandle visibility guard yielded no UI targets. ObjectList control is not tile extraction proof. GetDependencies tracking-only Cue misses inherited Recipe/Preset references.

## Important Files
diagnostics/UI_Topology_Probe_2_5_0_3.lua, diagnostics/ui_topology_probe_2_5_0_3.xml, tests/ui_topology_probe.lua, tools/run_ui_topology_probe.py, docs/ui-topology-probe-2.5.0.3.md, docs/comparehandle-probe-2.5.0.3.md, RecipeTracking_Inspector.lua.

## Current Branch / Commit
qwen; checkpoint subject `fix: guard UI topology types and locate Generator grid first`. Earlier Shared Reference integration changes remain uncommitted and must be preserved. Never merge main automatically.

## Exact Next Action
Re-import updated independent UI Topology XML and press diagnostic with 103/104 visible. Confirm revision=2-ui-type-guard-direct-grid, seven display roots, GRID_LOCATED and SECTION GENERATOR; copy START through END plus any native errors. No type syntax errors acceptable. Native retest pending; do not infer virtualization from an invalid/incomplete run or integrate CompareHandle into production.
