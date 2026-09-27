# Project Handoff

## Current Goal
Track B only: standalone read-only Discovery Budget Probe for grandMA3 2.5.0.3. Track A PAUSED. Production unchanged.

## Current Working State
Faithful cold production discovery prefix (6000 shared nodes) plus bounded same-algorithm continuation and separate typed per-Display visible grid inventory. Exposed production cache/window snapshot read only; cache branch logged separately. 22 mock assertions PASS. Deployment details in docs/discovery-budget-probe-2.5.0.3.md.

## Latest Real-World User Test
Larger Show: 12 visible grids all CHILD_PATHS_AGREE and production_would_miss=false (Preset/Group/Sequence/GeneratorRandom). Empty-UIChildren hypothesis downgraded. GeneratorRandom samples 4294967296 in another Show with 103/104 empty: possible empty/unassigned tile representation, not a bug/root cause; no index investigation.

## Verified Facts
Two controlled Recall replacements LIFECYCLE_NOT_REPRODUCED/capped=false; stale-valid cache downgraded. Production shared discovery budget 6000 across Display 1-7, depth 20, stops at grids. No native budget evidence yet.

## Current Problem
Determine whether earlier Displays exhaust shared budget and prevent reachable visible grids on later Displays from discovery.

## Known Failed Attempts
Stale-valid cache and empty-child fallback not reproduced in controlled native tests. No confirmed generic Pool-marker cause. Alias mismatch not reproduced.

## Important Files
 diagnostics/Discovery_Budget_Probe_2_5_0_3.lua, diagnostics/discovery_budget_probe_2_5_0_3.xml, tests/discovery_budget_probe.lua, tools/run_discovery_budget_probe.py, docs/discovery-budget-probe-2.5.0.3.md, docs/child-enumeration-probe-2.5.0.3.md.

## Current Branch / Commit
qwen; checkpoint subject `test: add read-only cross-display discovery budget probe`. Preserve earlier uncommitted Shared Reference integration. Never merge main.

## Exact Next Action
REAL-WORLD VALIDATION PENDING: import independent Discovery Budget XML; retain normal multi-display Pool layout; press once; copy [DiscoveryBudget] START-END. No production change until native evidence; Track A paused.
