# Project Handoff

## Current Goal
Track B only: standalone read-only Child Enumeration Probe, grandMA3 2.5.0.3. Track A PAUSED. Production unchanged.

## Current Working State
Independent Child Enumeration Probe compares UIChildren, Children, GetUIChildrenCount/GetUIChild and Count/Ptr usable AllPoolButton sets; emulates production empty-table selection. Native evidence pending. 21 mock assertions PASS. Deployment/checkpoint details in docs/child-enumeration-probe-2.5.0.3.md.

## Latest Real-World User Test
TWO controlled Recall View replacements: OLD invalid and cache rejected; NEW found with 103/104, database targets preserved; LIFECYCLE_NOT_REPRODUCED, capped=false. Stale-valid cache hypothesis downgraded, not confirmed.

## Verified Facts
Production uiChildren accepts successful empty UIChildren table without fallback. Native topology previously found direct AllPoolButtons. These do not prove an actual child-path mismatch. No production change authorized before this experiment's native evidence.

## Current Problem
Determine whether real visible generic Pool grids expose usable buttons through alternative child paths while UIChildren is empty or materially different.

## Known Failed Attempts
Initial lifecycle cap invalidated classification; repaired diagnostic and final native tests complete. Alias mismatch not reproduced. No confirmed generic Pool root cause yet.

## Important Files
 diagnostics/Child_Enumeration_Probe_2_5_0_3.lua, diagnostics/child_enumeration_probe_2_5_0_3.xml, tests/child_enumeration_probe.lua, tools/run_child_enumeration_probe.py, docs/child-enumeration-probe-2.5.0.3.md, docs/recall-view-lifecycle-observer-2.5.0.3.md.

## Current Branch / Commit
qwen; checkpoint subject `test: add read-only Pool child enumeration probe`. Preserve earlier uncommitted Shared Reference integration. Never merge main.

## Exact Next Action
REAL-WORLD VALIDATION PENDING: import independent Child Enumeration XML; show desired Pool windows; run once; copy [ChildEnum] START–END. Decide production fallback only after native evidence. No Recall, CompareHandle integration or Cue-wide scanner work.
