# Discovery Budget Probe — grandMA3 2.5.0.3

## Scope / native instructions

Track B only; production unchanged, Track A paused. Native validation complete; see larger-Show evidence below. This tests generic Pool grid discovery, not tile contents or Generator ObjectIndex.

1. On 2.5.0.3 keep the larger Show's usual Pool windows visible across displays.
2. Import discovery_budget_probe_2_5_0_3.xml from C:/ProgramData/MALightingTechnology/gma3_library/datapools/plugins/Discovery Budget Probe 2.5.0.3.
3. Press **Discovery Budget Probe 2.5.0.3** once. Keep windows/View unchanged throughout the run.
4. Copy Command Line History from [DiscoveryBudget] START to END, including API errors. Include the per-Display summaries and GRID records.

No Recall, markers, target comparison or Show modification. Production may remain stopped for a cold discovery experiment. If running, its globally exposed cache/window are read only and their branch decision is logged separately.

## Production replay fidelity

Baseline: RecipeTracking_Inspector.lua v0.7.0.17, refreshPoolMarkers():1633-1683; children():183-187, class():69-73. Display 1 to 7 (focus-only fallback if index API absent), depth-first ipairs order, shared visited handles, shared 6000-node budget, depth limit 20, count before window exclusion, class containing PoolLayoutGrid, accept via valid/IsActuallyVisible (nil accepted), and return without traversing grid children. UIChildren returning any table wins; Children is used only otherwise. No fallback change.

Replay is explicitly COLD_DISCOVERY (empty local cache). A separate read-only snapshot of production poolGrids/poolGridRefreshNeeded/window logs cache acceptance and whether the copied cache branch would initiate discovery. No mutation or invocation of production refresh occurs, and warm-cache acceptance is not claimed to be a discovery-budget failure. Refresh tick/running gates and marker painting are outside this experiment. If production state is unavailable, window is nil and this limitation is logged.

For safety, UIObject derivation is checked before UI-only calls. If this guard prevents a call the production algorithm would make, classification is UNVERIFIED rather than claiming an exact replay. Expected unavailable IsActuallyVisible is preserved as production's accepted nil.

The production replay is the first 6000 nodes of a bounded same-algorithm continuation. Continuing beyond 6000 proves reachability without the shared cap, preserving order/filter/depth/window conditions. It has at most 20000 nodes per Display and a shared visited set. The prefix is identical to the cold production traversal; later continuation is diagnostic only, not an alternative production algorithm. Repeated handles are counted once. Exhaustion logs the Display/address of node 6000. A non-discovered grid has UNAVAILABLE replay position/nodes and a separate continuation position if reached.

## Independent ground-truth inventory

A separate typed UI traversal merges UIChildren, Children, GetUIChildrenCount/GetUIChild and Count/Ptr, reusing the validated diagnostic child paths. It has its own visited set and per-Display limits: 20000 nodes, depth 30, 1024 entries per child path. It does not share the production budget. All display roots are checked. It stops at grids, never enumerating Pool tiles or reading ObjectIndex/targets. No empty-table fallback change is made in production replay.

Visible evidence requires an explicit true IsActuallyVisible/IsVisible/Visible signal, no explicit hidden ancestor, and UI ancestry reaching an active display root. Unknown visibility stays unknown. GRID records include handle/address/native, pool type/class/name, display, replay and ground-truth traversal positions/node counts, presence in each inventory, raw visibility and miss reason. DISPLAY records give production/continuation/ground-truth node counts and later-display starvation. No whole-tree object dump.

Ground truth means the independent bounded observed inventory, not an unlimited census. Any reached bound, unknown grid visibility, unsafe replay deviation or more than 200 grid output records prevents a definitive classification. A stable screen/Show is required: UI changes during sequential reads invalidate a comparison and require rerunning. This probe does not eliminate every possible native UI visibility ambiguity.

## Classification / causality

- DISCOVERY_BUDGET_OK: at least one ground-truth visible grid, sufficient uncapped evidence, and production prefix discovers every visible ground-truth grid.
- DISCOVERY_BUDGET_MISS_CONFIRMED: a visible ground-truth grid is absent from the prefix but reached and accepted by the exact same production algorithm beyond position 6000. This proves a cap-related miss in the cold replay, not that a real warm cache currently misses it. Other misses remain separately logged.
- DISCOVERY_LOGIC_MISMATCH: visible grid absent from replay for another reason, with sufficient uncapped continuation/inventory evidence and no budget-related misses. Filtering/window exclusion/depth/path differences are distinct from shared-budget causality.
- UNVERIFIED: limits, insufficient visibility/inventory, guarded non-UI production traversal, zero visible evidence or unavailable prerequisites.

A later Display is explicitly starved when production consumes zero nodes there while continuation reaches nodes after shared-budget exhaustion. A partially visited Display is assessed by grid position/miss reason rather than that boolean alone.

## Safety and validation

Only local diagnostic tables and Printf output; read-only snapshot of exposed production state. No commands, Show/Sequence/Cue/Recipe/Programmer/playback/UI writes, hooks, timers, nested coroutines, GetPresetData, ObjectList or CompareHandle. No Recall lifecycle, child fallback change, Generator index investigation or Cue-wide scanner research. Target locked to 2.5.0.3.

[Lua](../diagnostics/Discovery_Budget_Probe_2_5_0_3.lua), [XML](../diagnostics/discovery_budget_probe_2_5_0_3.xml), [mocks](../tests/discovery_budget_probe.lua), [runner](../tools/run_discovery_budget_probe.py).

22 offline assertions cover shared budget starvation, independent inventory, counts/order, empty-table logic mismatch, depth/window stopping, cache branch/refresh, grid child stop, limits/visibility/guard failure and version lock. They cannot establish native discovery misses or performance.

## Deployment verification

Actual independent Lua/XML copy completed. Source/deployed parse PASS and SHA256 MATCH; XML component exists. Forbidden-call check PASS; no ObjectIndex access. Production directory snapshot unchanged (3 files); production source equals HEAD after Git filtering. 22 probe mock assertions and 86 existing workflow assertions PASS. Native evidence subsequently received below.

- Discovery_Budget_Probe_2_5_0_3.lua: `e8fc32e92fe4af0f2a5a374ec053fd5254053c715a8406b67b0267e2ffc27390`.
- discovery_budget_probe_2_5_0_3.xml: `8c255c95a4675c059540e2e0420debb0df4d9fc8babb99e8d6b374aa70e84546`.

## Native evidence: larger multi-display Show

User reports DISCOVERY_BUDGET_OK on grandMA3 2.5.0.3: visible_ground_truth=12 and production replay found all 12. Display 1 consumed 566 nodes, Display 2 426, Display 3 958; global_production_nodes=1950/6000. exhausted=false, budget_misses=0, logic_misses=0; no display starvation.

Shared 6000-node discovery-budget hypothesis is downgraded: not reproduced in this Show, not a confirmed generic marker root cause. No production change. Broad generic UI-discovery probing stops here; the next isolated experiment traces one selected Group through its existing source/grid/tile/marker pipeline. Track A remains paused.
