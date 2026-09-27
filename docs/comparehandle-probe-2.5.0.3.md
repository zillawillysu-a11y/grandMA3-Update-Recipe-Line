# Generator / Random CompareHandle probe - 2.5.0.3

UI topology follow-up: **PROBE INVALID / RETEST REQUIRED**. Native UI-only calls on database handles and discovery-budget starvation invalidated the previous topology run (914 discovery nodes, 5 grids, truncated). Actual Generator grid was already observed at Display 3.5.3.1.5.1.4.4. No absence or virtualization conclusion is valid. Revision 2 type-gates UI APIs and locates that grid before bounded inspection; see [retest](ui-topology-probe-2.5.0.3.md). CompareHandle production integration remains stopped.


Latest native UI-target result: AllPoolLayoutGrid / Generators / GeneratorRandom found; IsActuallyVisible unavailable, buttons=0 and targets=0 across discovered pools. END NO_VISIBLE_UI_TARGET_HANDLE, ui_targets=0, alias_status=NOT_OBSERVED. **Production integration STOPPED.** Previous early visibility return means these zero counts do not prove virtualization or a childless native grid. Database identity PASS remains valid. Next experiment: [bounded UI topology](ui-topology-probe-2.5.0.3.md).


**DATABASE IDENTITY NATIVE PASS / VISIBLE UI ALIAS VALIDATION PENDING**.
Production matching, tracking, markers and version remain unchanged. The extended source is deployed in the independent Plugin folder. Native UI alias validation remains pending.

## Native evidence

User reports on grandMA3 2.5.0.3:

- Recipe Generator 103: class Random, command address Generator 103.
- CompareHandle(recipe_ref, ObjectList("Generator 103")) = true; reverse = true.
- CompareHandle(recipe_ref, Generator 104) = false.
- Comparison cost approximately 0.001 ms.
- origin = ObjectList Generator 103 (not UI tile evidence).
- Positive pair command_equal=true and native_equal=true.

This establishes database object identity for those controls. It does **not** establish identity of the actual visible Pool target or resolve the production alias failure. No raw complete log, sample count or timing distribution was supplied. Same-text ObjectList controls cannot prove different-representation compatibility.

GetDependencies remains suitable for structural candidate discovery and unsuitable for final active/tracking references; see [native evidence](getdependencies-probe-2.5.0.3.md).

## Source and evidence

- [Lua](../diagnostics/CompareHandle_Probe_2_5_0_3.lua), [XML](../diagnostics/comparehandle_probe_2_5_0_3.xml).
- [Mock tests](../tests/comparehandle_probe.lua), [runner](../tools/run_comparehandle_probe.py).
- [Production extraction](../RecipeTracking_Inspector.lua): refreshPoolMarkers reads displays, UIChildren with Children fallback, visible PoolLayoutGrid, poolbutton excluding pooltitlebutton, grid.PoolObject:Ptr(tonumber(button.ObjectIndex)). The probe copies only these reads; no markers, writes, hooks or commands.
- [2.5.0.3 API dump](../.reference/ma3/DiDiDo-MA3-Developer-Reference/01_API_Dump/MA3_2.5.0.3/grandMA3_lua_functions.json): CompareHandle, Ptr, UIChildren, ObjectList, Parent, AddrNative, BuildDetails.
- MA 2.5 system_test_helping_functions_db.lua:320,338,599 uses CompareHandle for database handles. IsActuallyVisible has MA UI system-test evidence, although absent from this function dump.

Only 2.5.0.3 is accepted. No GetPresetData/GetPresetDataFast/GetDependencies, Show/Recipe/Programmer/UI writes, commands, playback changes, hooks or nested coroutines. Default discovery examines direct Current Cue Recipe rows, not inherited Recipe provenance. Config recipe_addresses can select explicit existing Recipe rows without switching Cue.

## Visible widget vs database target

Discovery follows production, scans displays 1-7 (GetFocusDisplay fallback), and attempts extraction in every visible Pool grid. It no longer requires a presumed Generators pool class or GeneratorRandom Pooltype before extraction. Target Generator/Random classes still determine relevant objects.

Visibility accepts true / Yes / true / 1. Unlike production's permissive unknown case, probe requires explicit grid and widget visibility for UI evidence. Unknown widget visibility records an unaccepted target, not success. Each run rediscovers grids and holds no cross-run UI cache.

- GRID: class/address, visibility, actual pool class/type, button count, accepted Generator target count.
- UI_TILE: widget's own class/address/native/handle, grid, ObjectIndex, visibility, extraction status, linked target number.
- POOL: extracted database target's class/address/native/handle, origin, ui_evidence, expected/other controls.
- RECIPE: reference class/address/native/handle plus Recipe row address, field, raw value/type, enabled and controls.
- PAIR: ref/target indices, forward cold/warm results, reverse, stability, command_equal/native_equal and timings.

ToAddr() and AddrNative() use the same no-argument form as production matching. HandleToStr is diagnostic only; equality is determined by CompareHandle, never by name/index/address/token text.

NO_TARGET_HANDLE / OBJECT_INDEX_UNAVAILABLE explicitly reports unavailable extraction. Nil Ptr might be an empty slot: operator must identify known occupied 103/104 tiles; probe does not guess occupancy. INVALID_OR_NON_GENERATOR_TARGET and WIDGET_VISIBILITY_UNVERIFIED_OR_HIDDEN record separate failures; UNACCEPTED_TARGET logs extracted metadata when available. No ObjectList fallback substitutes for missing tile targets.

ObjectList targets from optional pool_addresses remain controls with ui_evidence=false. A controlled pass requires BOTH an actual visible positive tile and actual visible different negative tile, plus self/expected true, other false, stable forward/warm/reverse comparisons and no capture errors. ObjectList-only evidence cannot pass.

END ui_status=NO_VISIBLE_UI_TARGET_HANDLE means no accepted visible UI target. With valid controls, this produces UNVERIFIED_NO_UI_EVIDENCE. Partial discovery or missing visible negative control gives CONTROLLED_PAIR_FAIL; inspect extraction logs to distinguish discovery failure from equality failure.

alias_status=UI_ALIAS_EQUALITY_OBSERVED requires an actual UI target pair with differing command or native text and stable forward/reverse true. Different Generator false pairs do not qualify. Same-text successful UI pairs yield NOT_OBSERVED: they still do not demonstrate the original alias scenario. DIFFERENT_TEXT_PAIR_ONLY indicates an inconclusive differing-text comparison. Even a passing pair requires operator confirmation of the known intended tile.

## Simple native test

1. On 2.5.0.3, use an existing direct Recipe referencing Generator 103. Show the actual Generator Pool with 103 and known different 104 tiles visible. The probe creates no Show fixtures and changes no playback.
2. Execute the latest source below; omit pool_addresses to keep pair evidence focused on UI targets. Replace example slots if necessary. Optionally provide recipe_addresses to restrict to one known Recipe.

```text
Lua "local f=assert(loadfile([[C:/Users/willy/Downloads/Update-Recipe-Line/grandMA3-Update-Recipe-Line/diagnostics/CompareHandle_Probe_2_5_0_3.lua]])); f()(nil,{expected_generator='Generator 103',other_generator='Generator 104'})"
```

3. Copy Command Line History [CHProbe] START through END. Confirm UI_TILE links to POOL ui_evidence=true; positive forward/reverse true and visible negative forward/reverse false. Examine command_equal/native_equal. Both true means alias representation was not exercised.
4. Repeat for an existing Recipe exposing another Random/Generator representation if available. Never alter address strings to manufacture an alias. If no target can be extracted, send GRID/UI_TILE/UNACCEPTED_TARGET logs rather than substituting ObjectList. Lua errors appear in System Monitor.

Config fields: recipe_addresses (explicit Recipe rows), expected_generator (known positive address), other_generator (different Generator address), pool_addresses (optional database controls only).

## Validation and limits

60 mock assertions PASS, including widget/target separation, different-text same-identity pairs, unknown pool class, Children fallback, Yes visibility, hidden/unknown tiles, nil Ptr, ObjectList-only rejection, missing visible negative control, same-text non-alias and no mutation/cooked calls. Existing dependency suite: 59 assertions PASS. Mocks do not establish native UI reliability.

Run python tools/run_comparehandle_probe.py. Traversal limits: 64 rows, 16 refs, 128 targets/widgets, 6000 UI nodes, depth 20, 32000 protected read calls. Bounds/errors are explicit. Cold/warm are first/repeat comparison calls, not proven cache miss/hit. Timing uses MA Time seconds converted to ms and includes validity reads, excluding discovery/metadata/logging. Missing clocks remain unavailable.

## Earlier independent deployment (2026-09-27)

Folder: C:/ProgramData/MALightingTechnology/gma3_library/datapools/plugins/CompareHandle Probe 2.5.0.3.
Import comparehandle_probe_2_5_0_3.xml. Plugin name: CompareHandle Probe 2.5.0.3.

Earlier source/deployed XML and Lua parsed and SHA256 matched. Production Update Plugin three-file snapshot was unchanged. Historical hashes (NOT hashes of the extended source):

- XML: 4dbf073be1affecb78cc841694c461fa02d821c346b751e7f2b24d2a1f8bb058.
- Earlier Lua: 5ba5cc9dbb25b10635ab8077074b256c16ba20345a255182c723e8ea86f96d6f.

The extended probe has now been deployed independently. Re-import the XML into its existing diagnostic slot if grandMA3 cached the old Lua, or execute the source launch above.

## Extended deployment verification

- comparehandle_probe_2_5_0_3.xml: SHA256 MATCH `4dbf073be1affecb78cc841694c461fa02d821c346b751e7f2b24d2a1f8bb058`; deployed parse PASS.
- CompareHandle_Probe_2_5_0_3.lua: SHA256 MATCH `e25b0c99ee55d4dc94013642f7804553989a55d5f73e36ecf5cbe58ed5e6a789`; deployed parse PASS.

Production Update Plugin three-file snapshot unchanged. Re-import the same independent XML (Plugin name unchanged) to refresh imported Lua. For controlled testing, the source launch above uses the latest probe directly. Native UI identity/alias results remain pending.
