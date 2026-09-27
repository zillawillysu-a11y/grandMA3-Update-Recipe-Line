# UI topology probe - grandMA3 2.5.0.3

Latest native follow-up: UI Topology revision 2 PASS. Direct AllPoolButton 103/104 exist and PoolObject:Ptr(ObjectIndex) returns real Random/Generator targets; 103 target handle #2BC0001F7 equals the earlier Recipe reference handle. No alias mismatch reproduced. Earlier invalid run remains invalid historically, but retest now succeeded. Current experiment is [generic Pool Recall View lifecycle](recall-view-lifecycle-observer-2.5.0.3.md); 103/104 are fixtures only. Production matching unchanged; Track A PAUSED.


**Previous native run: PROBE INVALID / RETEST REQUIRED.** Revision 2 is a standalone read-only repair. Production matching/tracking/markers/version unchanged; CompareHandle production integration remains STOPPED.

## Native failure and interpretation

User reports the first topology run repeatedly called UIChildren, GetUIChildrenCount and GetUIChild on non-UI handles. grandMA3 rejected these with type UIObject (or derived) requirements. Run ended NO_GENERATOR_GRID, discovery_nodes=914, discovered_grids=5, truncated=true.

That run is INVALID; it proves neither missing Generator grids nor virtualization. Previous CompareHandle probe already found `Display 3.5.3.1.5.1.4.4`, class AllPoolLayoutGrid, pool_class Generators, pool_type GeneratorRandom. Global discovery/read budgets could starve Display 3. The old mock suite failed to model native UI type restrictions.

Earlier CompareHandle database identity controls remain PASS (Generator 103 positive/reverse true; Generator 104 false; about 0.001 ms). UI target extraction and differing-text alias identity remain unverified. The CompareHandle probe's zero button count after an unavailable visibility guard did not prove childless grids either.

## Revision 2: locate first, inspect second

1. Directly locate the previously proven UI grid with documented FromAddr, then GetObject only as a fallback for that same UI grid address. Verify native validity, UIObject derivation, AllPoolLayoutGrid class and actual PoolObject/type. These resolvers do NOT resolve database tiles or substitute for extraction; no ObjectList is called.
2. Check GetDisplayByIndex for every index 1-7, including Display 3. Log each root. Native FindRecursive("", "AllPoolLayoutGrid") gives an additional candidate per root without manually crawling a whole object/database tree. It may return the first Pool grid only; it is not exhaustive proof that a display has no Generator grid. The direct known-address lookup has priority.
3. There is no shared node/read cap during this finite locator phase. Detailed node/depth/read limits start afterward, so early display traversal cannot consume Generator inspection budget. If lookup fails, report PROBE_INVALID_RETEST_REQUIRED, never an absence/virtualization conclusion. Native FindRecursive search cost is not known and is not claimed constant-time.
4. Inspect Generator neighborhood first. One Group/Preset candidate from other display roots or immediate siblings may be inspected as control. Both controls and all visibility values are observations, not assumed known-working.

Revision 2 START marker: `revision=2-ui-type-guard-direct-grid`. If it is missing, re-import the updated XML rather than testing cached old Lua.

## Strict UI/database separation

The central method guard verifies native class with documented `IsClassDerivedFrom(class, "UIObject")` before UIChildren, GetUIChild, GetUIChildrenCount, IsVisible or IsActuallyVisible. Unknown type fails closed; method presence is never a type test. No guessed class-name whitelist is used. Missing IsClassDerivedFrom aborts safely. GridGetBase/Data/ScrollOffset additionally require UIGrid derivation, not just UIObject; unsupported AllPoolLayoutGrid calls are skipped as NOT_UI_GRID.

Only verified UIObject-derived nodes are traversed/inspected. Children/Ptr results are filtered by the same native type test before becoming traversal nodes. PoolObject, database targets, non-UI children and GridData/Base results are metadata only, tagged DATABASE_CHILD_NOT_TRAVERSED / DATABASE_NOT_TRAVERSED / DATABASE_GRID_RESULT_NOT_TRAVERSED. They receive no UI traversal, visibility or UI child-count calls. Ptr on the database pool is used only for a discovered widget's ObjectIndex target lookup and does not traverse that pool.

## Detailed scope, logs and limits

From Generator grid: log grid, parent, grandparent, direct siblings and parent's siblings; recursively inspect grid descendants up to depth 5. Ancestor/sibling subtrees are not recursively dumped. UIChildren / Children / GetUIChild with GetUIChildrenCount / Ptr with Count paths are merged; nil counts permit only an explicitly tagged 1..8 indexed sample. UI nodes are deduplicated within each neighborhood. No ObjectList or GetPresetData/GetPresetDataFast, commands, hooks, Show/Recipe/Programmer/UI writes or playback changes.

Each NODE records depth/relation, class/name/address/native/handle, Visible property, IsVisible/IsActuallyVisible, UI count/Count, ObjectIndex and PoolObject. PROPERTY records exposed name/type and relevant object/target/pool/index/visible/cell/scroll/row/column value. Exposed valid database handles are described, not inspected. TILE_EVIDENCE records widget and pool Ptr target separately, ObjectIndex and visibility. Index 103/104 is only a hint; verify the actual target class/address/native and widget visibility. Unknown visibility never establishes a visible tile.

GRID_LOCATED and DISPLAY_ROOT record locator evidence. SECTION GENERATOR must occur before evaluating empty tile results. END reports generator_found, displays_checked=7, discovery_reads, inspection counts/remaining reads/truncation. Detailed truncation does not mean discovery was truncated. If detailed inspection is incomplete, zero tiles is still not evidence of virtualization.

Limits AFTER locator: 160 inspected UI nodes overall, descendant depth 5, 48 children per path, 80 properties per object, 24000 protected reads, 1100 detailed lines plus END, strings limited to 180 characters. Generator runs before control and shares these detailed caps. Caps/errors are explicit. Native virtualization remains UNVERIFIED; only a valid located grid and completed bounded child inspection justify investigating alternate cell paths.

## Evidence

- [2.5.0.3 dump](../.reference/ma3/DiDiDo-MA3-Developer-Reference/01_API_Dump/MA3_2.5.0.3/grandMA3_lua_functions.json): IsClassDerivedFrom(derived_name, base_name), FromAddr, GetObject, FindRecursive, Parent, UIChildren, GetUIChildrenCount/GetUIChild, IsVisible, Count/Ptr and PropertyCount/Name/Type/Get.
- Installed MA 2.5 lib_menus/include/content_column_set.lua:10,15,19 uses IsClassDerivedFrom with GetClass and base-class strings, supporting native derived-type verification.
- MA 2.5 systemtests/ui/system_test_ui_all_pool_layout_grid_scrolling.lua:89-94 reads grid:Ptr(5) and Ptr(4+samplePosition).ObjectIndex.
- systemtests/help/system_test_helping_functions_db.lua:1548-1551 enumerates properties zero-based.
- [Production reference](../RecipeTracking_Inspector.lua) and [CompareHandle probe](../diagnostics/CompareHandle_Probe_2_5_0_3.lua) use display roots, PoolLayoutGrid and pool.Ptr(ObjectIndex). This repair prioritizes the actual previously located UI grid; it copies only read-only neighborhood paths and never production marker writes.

## Simple native retest

1. On **2.5.0.3**, keep Generator Pool visible with 103/104; optionally also Group/Preset Pool. Keep the same view while running.
2. Re-import `ui_topology_probe_2_5_0_3.xml` from the independent UI Topology Probe 2.5.0.3 folder into its diagnostic slot, refreshing cached Lua.
3. Press **UI Topology Probe 2.5.0.3** once.
4. Copy Command Line History [UITopo] START through END. Confirm revision 2, GRID_LOCATED/SECTION GENERATOR and all seven DISPLAY_ROOT logs. Include any native syntax errors or truncation. No UI type errors are acceptable; if one occurs, the run remains invalid.

Deployment folder: `C:/ProgramData/MALightingTechnology/gma3_library/datapools/plugins/UI Topology Probe 2.5.0.3`.

[Lua](../diagnostics/UI_Topology_Probe_2_5_0_3.lua), [XML](../diagnostics/ui_topology_probe_2_5_0_3.xml), [tests](../tests/ui_topology_probe.lua), [runner](../tools/run_ui_topology_probe.py).

23 offline assertions PASS, with native-like non-UI API traps, database child rejection, direct known-grid priority, all roots including Display 3/7, unknown type fail-closed, depth/call/log bounds, 103/104 widget vs target metadata and wrong build rejection. Offline passing does not prove native syntax correctness or actual grid recovery. Revision 2 native results pending.

## Revision 2 deployment verification

- ui_topology_probe_2_5_0_3.xml: parse PASS; source/deployed SHA256 MATCH `8699615476db5840694da5b2b4cddc8a002942418edf1c98c30afcad14d18e13`.
- UI_Topology_Probe_2_5_0_3.lua: parse PASS; source/deployed SHA256 MATCH `cf45660d5c693c855cc43af1df9676c2c7a2c9b7be8e1aed9bd2183dd982d2bd`.

Actual isolated copy executed; production Update Plugin snapshot unchanged and production source equals HEAD after Git filtering. Existing 60 CompareHandle and 86 workflow assertions PASS. Revision 2 native syntax/grid recovery RETEST REQUIRED.
