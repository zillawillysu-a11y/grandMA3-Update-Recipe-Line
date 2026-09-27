# Project Handoff

## Current Goal
Track B only: generic Pool UI lifecycle / Recall View cache observer on 2.5.0.3. Generator 103/104 are controlled fixtures, not Generator-specific root-cause scope. Track A PAUSED; no scanner research/changes. Production unchanged.

## Current Working State
Revision 2 observer only: controlled ObjectIndex lookup stops after 103/104; NEW grid child count >128 no longer sets global lifecycle capped. Optional inventory limits separated from read/output caps, with reason counters logged. 31 mock assertions PASS including NEW 211-child replacement. Production and Track A untouched. Revision 2 redeployed independently; XML/Lua parse and source/deployed SHA256 MATCH, production directory unchanged. Final native retest pending.

## Latest Real-World User Test
Actual different View replacement completed: BEFORE OLD #21320018D9 valid/cache_accept true, 103/104 present; AFTER OLD invalid/cache_accept false, buttons absent; NEW #8632000D2F valid/current visible, both controls present, saved database targets equal NEW targets. This controlled case does NOT reproduce stale-valid-grid retention. Revision 1 output UNVERIFIED/capped=true was a diagnostic cap issue.

## Verified Facts
Revision 1 children() set global capped above 128 entries; NEW 211 UI children necessarily triggered it, and AFTER forced UNVERIFIED. Offline exact-shaped replay reproduced this. Revision 2 separates inventory limits and checks only controlled pair for target metadata; same fixture returns LIFECYCLE_NOT_REPRODUCED. Other read/output cap triggers were not proven absent in the old native run; new counters identify them. No broader lifecycle conclusion.

## Current Problem
Need one final native retest of the SAME replacement scenario with revision 2, not a new investigation.

## Known Failed Attempts
Revision 1 global child inventory cap incorrectly overrode decisive invalid/rejected OLD evidence. Stale-valid cache hypothesis not reproduced by this native case.

## Important Files
diagnostics/Recall_View_Observer_2_5_0_3.lua, diagnostics/recall_view_observer_2_5_0_3.xml, tests/recall_view_observer.lua, tools/run_recall_view_observer.py, docs/recall-view-lifecycle-observer-2.5.0.3.md, RecipeTracking_Inspector.lua.

## Current Branch / Commit
qwen; checkpoint subject `fix: keep Recall lifecycle classification independent of child inventory`. Preserve earlier Shared Reference integration uncommitted changes. Never merge main automatically.

## Exact Next Action
Re-import updated independent observer XML. Confirm revision=2-controlled-lookup, run BEFORE, manually Recall the same replacement View, run AFTER and copy [RecallLife] output. Expected LIFECYCLE_NOT_REPRODUCED if OLD invalid/rejected again. No production changes or investigation expansion; Track A remains paused.
