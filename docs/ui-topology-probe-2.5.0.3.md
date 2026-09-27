# Bounded UI topology diagnostic - grandMA3 2.5.0.3

Status: READ-ONLY DIAGNOSTIC / NATIVE TOPOLOGY RESULTS PENDING.
CompareHandle production integration is stopped. Production matching, markers, tracking and version remain unchanged.

## Latest native observation

User found AllPoolLayoutGrid with pool_class=Generators and pool_type=GeneratorRandom in the extended CompareHandle test, but visible=UNAVAILABLE, buttons=0, targets=0. Other discovered Pool grids had the same pattern. END: NO_VISIBLE_UI_TARGET_HANDLE, ui_targets=0, alias_status=NOT_OBSERVED.

This is a UI extraction/discovery failure, not a CompareHandle failure. The earlier database ObjectList identity positive/reverse/negative controls remain PASS, approximately 0.001 ms. No visible target or differing-text alias pair has been proven.

Important interpretation: the previous probe returned before button enumeration when IsActuallyVisible was unavailable. Therefore buttons=0 does NOT prove a childless grid, virtualization, or missing tiles. Both visibility APIs and multiple child paths must be inspected independently.

## Evidence and read paths

- [2.5.0.3 API dump](../.reference/ma3/DiDiDo-MA3-Developer-Reference/01_API_Dump/MA3_2.5.0.3/grandMA3_lua_functions.json): UIChildren, Children, GetUIChildrenCount, GetUIChild (1-based), Count, Ptr (1-based), Parent, IsVisible, PropertyCount/Name/Type, Get, GridGetBase, GridGetData, GridGetScrollOffset.
- MA installed 2.5 systemtests/ui/system_test_ui_all_pool_layout_grid_scrolling.lua:52-53 uses FindRecursive to obtain AllPoolLayoutGrid and AllPoolTitleButton. Lines 70-71 read GetFocus().ObjectIndex; 89-94 access poolLayoutGrid:Ptr(5) and Ptr(4+samplePosition), then ObjectIndex. This is direct vendor evidence for indexed native Pool button children; it does not prove the live Generator grid path.
- systemtests/help/system_test_helping_functions_db.lua:1548-1551 enumerates PropertyName/Get using indices 0 through PropertyCount()-1.
- [Production source](../RecipeTracking_Inspector.lua) refreshPoolMarkers uses display discovery, UIChildren with Children fallback, PoolObject:Ptr(button.ObjectIndex). The diagnostic copies reads only and inspects alternatives rather than changing production.

No new undocumented target properties are invented: property names/types are enumerated from the actual object. Values are read only for exposed names concerning object, target, pool, index, visibility, cell, scroll, rows or columns. Name, Visible, ObjectIndex and PoolObject are individually attempted and absence is explicit. All calls are protected and counted.

## Scope and bounds

The probe rediscovers the same native PoolLayoutGrid handles from displays, quietly (no entire-tree dump), and selects one non-explicitly-hidden Generator/Random grid. It prefers an explicitly visible candidate if present; unavailable visibility is permitted for topology inspection and logged, NOT taken as proof of visibility. Operator must show the intended Generator Pool. One Group/Presets grid may be inspected as comparison if found, with its visibility likewise recorded rather than assumed.

From the selected grid, inspect parent, grandparent, direct siblings and parent's siblings (no sibling recursive subtree dump), and descendants up to depth 5. All child paths are compared and merged by native Lua handle; cycles are skipped. UIChildren/Children can be empty while GetUIChild/Ptr expose actual widgets. If indexed counts are unavailable, only indices 1..8 are sampled and tagged INDEXED_SAMPLE.

Limits: 4000 silent discovery nodes, discovery depth 20, 160 detailed inspected objects overall, descendant depth 5, at most 48 children per path per object, 80 exposed properties per object, 24000 protected reads, 1100 tagged detailed lines plus final END. Truncation/depth/child/property caps are reported. There is no unlimited tree Dump() or table serialization. Property values and strings are limited to 180 characters. Both comparison neighborhoods share limits.

GRID_API tries documented read-only GridGetBase/GridGetData/GridGetScrollOffset on grid objects. Result handles receive bounded metadata/property inspection, without following arbitrary database handles recursively. Unsupported calls/errors are recorded; UIGrid API availability is not assumed for AllPoolLayoutGrid.

Virtualization remains UNVERIFIED until native evidence supports it. Empty lists alone cannot establish virtualized cells. Vendor indexed Ptr is the first evidence-backed alternative path to test. GridGetData/Base existence alone does not establish a cell-to-database-object mapping. No synthetic cell/index mapping is invented.

## Logs and identity limitations

- DISCOVERED: candidate grid, pool class/type and both visibility APIs.
- NODE: depth/relation, class/name/address/native/handle, Visible property, IsVisible, IsActuallyVisible, UI count/Count, ObjectIndex and PoolObject.
- CHILD_PATH: each API count, cap and error; REVISIT documents overlapping paths/cycles.
- PROPERTY: actual property name/type and relevant value (handle metadata if a valid object).
- GRID_API: alternative native read path and returned object/error.
- TILE_EVIDENCE: actual discovered widget, ObjectIndex, pool Ptr target and visibility. Index 103/104 is only a hint; verify target command/native address and widget visibility. No ObjectList is called or used as evidence.
- END: nodes/read budget/truncation and virtualization=UNVERIFIED.

Objects identified through ancestors/siblings retain relation tags. An ancestor's child enumeration is metadata only; other windows' subtrees are not recursively dumped. Grid PoolObject is inherited only for descendant lookup; ancestors/siblings require their own exposed PoolObject. TILE_EVIDENCE must still be evaluated with relation, target class/address and visibility.

## Very simple native test

1. Use grandMA3 2.5.0.3. Open Generator Pool and make Generator 103 and 104 visible. If convenient, also leave a known working Group or Preset Pool visible.
2. Import ui_topology_probe_2_5_0_3.xml from the independent deployment folder below into a new diagnostic Plugin slot.
3. Press **UI Topology Probe 2.5.0.3** once. No config or command is required. Do not change views while it runs.
4. Copy Command Line History from [UITopo] START to END, including caps/errors. Lua failures appear in System Monitor.

The diagnostic only reads UI/database metadata and prints. It creates no fixtures, changes no Sequence/Cue/Recipe/Programmer/playback/UI, registers no hooks, and calls no ObjectList/GetPresetData/GetPresetDataFast. Clicking this Plugin is operator action; the probe itself sends no playback command.

Files: [Lua](../diagnostics/UI_Topology_Probe_2_5_0_3.lua), [XML](../diagnostics/ui_topology_probe_2_5_0_3.xml), [tests](../tests/ui_topology_probe.lua), [runner](../tools/run_ui_topology_probe.py).

Deployment folder: C:/ProgramData/MALightingTechnology/gma3_library/datapools/plugins/UI Topology Probe 2.5.0.3.

Mock tests cover unavailable IsActuallyVisible, visible IsVisible, empty UIChildren with actual indexed tiles, ancestors/comparison grids, property introspection, depth limits, missing Ptr targets, unavailable count sampling, output bounds, wrong build and forbidden API traps. These are offline assertions, not native proof.

## Deployment validation

- ui_topology_probe_2_5_0_3.xml: source/deployed SHA256 MATCH `8699615476db5840694da5b2b4cddc8a002942418edf1c98c30afcad14d18e13`; parse PASS.
- UI_Topology_Probe_2_5_0_3.lua: source/deployed SHA256 MATCH `1d9bb44c11e54aa02b5924a5444cfef4916a17d9be5ae3cd44770cf12b97cc23`; parse PASS.

Actual independent copy executed; production Update Plugin three-file snapshot unchanged, production source equals HEAD after Git filtering. 15 topology mock assertions, 60 CompareHandle assertions and 86 existing workflow assertions PASS. Native topology is pending.
