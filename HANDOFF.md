# Project Handoff

## Current Goal
Track B only: generic Pool UI lifecycle / Recall View cache observer on 2.5.0.3. Generator 103/104 are controlled fixtures, not Generator-specific root-cause scope. Track A PAUSED; no scanner research/changes. Production unchanged.

## Current Working State
Standalone Recall View Observer Lua/XML deployed independently; XML/Lua source/deployed parse PASS and SHA256 MATCH. Production Update Plugin snapshot unchanged. 22 observer mocks PASS. First press stores BEFORE; operator manually recalls View; second press logs OLD/NEW and classifies stale-cache/not-reproduced/unverified. Only diagnostic memory/Printf writes, no markers/cooked reads/commands. Production v0.7.0.17 and CompareHandle integration unchanged. Lifecycle REAL-WORLD VALIDATION PENDING.

## Latest Real-World User Test
UI topology revision 2 native PASS: direct AllPoolButton 103/104, Visible and IsVisible true, IsActuallyVisible unavailable. Targets Random/Generator 103 #2BC0001F7 and 104 #2BC0001FF. Recipe 103 previously had same handle. Extraction valid; alias mismatch not reproduced; normal native children exist.

## Verified Facts
Production IsActuallyVisible nil is accepted; strict CompareHandle probe rejected nil. Read-only in-memory audit reproduced retained old grid despite IsVisible=false and absent IsActuallyVisible. This is a lifecycle candidate, not Cue-wide latency cause. Actual Recall lifecycle still untested. Observer snapshots parent/grandparent visibility and copied production predicate without modifying it.

## Current Problem
Need controlled BEFORE/manual Recall/AFTER evidence of valid accepted OLD grid that is no longer current. Child fallback and display discovery costs are outside this classification.

## Known Failed Attempts
First topology run invalid (UI-only calls on database handles/global discovery starvation); revision 2 native retest passed. ObjectList identity controls never prove UI tile extraction. Alias matching not reproduced in successful native case.

## Important Files
diagnostics/Recall_View_Observer_2_5_0_3.lua, diagnostics/recall_view_observer_2_5_0_3.xml, tests/recall_view_observer.lua, tools/run_recall_view_observer.py, docs/recall-view-lifecycle-observer-2.5.0.3.md, RecipeTracking_Inspector.lua.

## Current Branch / Commit
qwen; checkpoint subject `test: add read-only Recall View lifecycle observer`. Preserve earlier Shared Reference integration uncommitted changes. Never merge main automatically.

## Exact Next Action
Import independent Recall View Observer XML, show one Generator Pool with 103/104, press BEFORE, manually Recall replacement View, press SAME Plugin AFTER; copy [RecallLife] START through END. Do not re-import/restart/change Show between phases. Lifecycle native validation pending; keep production and Track A untouched.
