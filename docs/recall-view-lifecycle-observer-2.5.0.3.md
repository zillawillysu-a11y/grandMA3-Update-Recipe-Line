# Recall View lifecycle observer - grandMA3 2.5.0.3

Scope: **generic Pool marker UI lifecycle / Recall View cache behavior**. Generator 103/104 are controlled fixtures, NOT a claim that any defect is Generator-specific. Track A is PAUSED; this experiment never reads or studies the Cue-wide scanner. Production unchanged; CompareHandle production integration stopped.

## Latest native evidence

User reports UI Topology revision 2 native PASS on 2.5.0.3. A visible Generator Pool has normal direct AllPoolButton children:

- 103: ObjectIndex 103, Visible=true, IsVisible=true, IsActuallyVisible unavailable; database target class Random, address Generator 103, native ShowData.DataPools.Default.GeneratorTypes.Generators.103, handle #2BC0001F7.
- 104: ObjectIndex 104, database target Generator 104, handle #2BC0001FF.
- Earlier Recipe reference 103 had the same handle #2BC0001F7.

UI extraction is valid in this case; alias mismatch was not reproduced. Direct native buttons exist; virtualization is not established. Earlier database CompareHandle positive/reverse/negative controls remain PASS. Lifecycle remains untested until BEFORE/AFTER evidence is collected.

## Operator workflow: two presses

1. On **grandMA3 2.5.0.3**, show a Generator Pool with 103 and 104 visible. For an unambiguous controlled experiment, keep only one visible Generator Pool. Keep the same Show throughout.
2. Import `recall_view_observer_2_5_0_3.xml` from the independent folder and press **Recall View Observer 2.5.0.3** once: BEFORE saves native grid/button/target references in its own diagnostic memory and prints a PAUSE prompt. It then returns normally; no background polling, nested coroutine or blocking dialog.
3. Manually Recall a View that replaces/switches that Pool window. The diagnostic never invokes Recall. Prefer a View that also shows Generator 103/104 for positive/negative fixture comparison.
4. Press the **same diagnostic Plugin** again: AFTER rechecks retained OLD handles, locates current candidate grids, compares OLD/NEW and prints classification. It clears diagnostic memory; the next press starts a new BEFORE.
5. Copy Command Line History `[RecallLife] START phase=BEFORE` through `[RecallLife] END phase=AFTER`. Also include any native API errors. Errors/incomplete evidence require another run, not a production fix.

Do not re-import/restart/change Shows between the two presses. If BEFORE is UNVERIFIED, nothing is saved: correct the visible fixture and press again. Optional string argument `reset` clears only this diagnostic's own pending memory; it does not modify production state or Show.

## What is recorded

BEFORE, OLD_AFTER and NEW_AFTER record grid handle, class, address/native, validity, IsActuallyVisible, IsVisible, Visible, active-display ancestry, parent/grandparent visibility, UIChildren count, discovered direct 103/104 AllPoolButton handles, ObjectIndex and actual PoolObject:Ptr(ObjectIndex) target handles. Saved button/target handles are independently revalidated even if no longer returned by OLD children. BEFORE values are frozen metadata, not recomputed aliases; AFTER snapshots do not overwrite them.

COMPARE reports old_equals_new using native CompareHandle (diagnostic only), OLD valid/cache acceptance/current visibility, NEW found/103/104, old address/native unchanged. COMPARE_BUTTON reports whether OLD still contains the original button, whether it contains NEW's button and whether the saved target matches NEW's target. Pool target handles are metadata only: no database UI traversal.

The copied production cache predicate is from [actuallyVisible](../RecipeTracking_Inspector.lua):1648-1653, v0.7.0.17: reject invalid; a nil/failed IsActuallyVisible result is accepted; otherwise accept true / Yes / true / 1. It does not use IsVisible, Visible or ancestor visibility. Observer separately computes visibility signals, so cache acceptance is not confused with current visibility. The observer does not read/write production caches or draw frames.

Current visibility is false on explicit hidden grid/parent/grandparent signals or detached ancestry. Parent membership is separately checked: a complete, uncapped enumeration of all four parent child paths with no matching grid can establish that a still-valid back-pointer is stale; any found member wins and incomplete evidence stays unknown. This attachment check does not assert or fix a production child-fallback defect. Otherwise it requires an explicit grid visibility signal and ancestry reaching an active display root; unavailable evidence stays unknown. This is an observational test, not a proposed production visibility implementation. Higher unknown ancestor conditions can still make native effective visibility inconclusive; compare raw logs with the actual screen.

## Locator and child inventory limits

All display roots 1-7 are fetched first. Prefer FromAddr of the previously proven grid address (BEFORE: Display 3.5.3.1.5.1.4.4; AFTER: saved grid address), then inspect first native AllPoolLayoutGrid per display and local immediate sibling grids. Every candidate is checked for native UIObject derivation and actual Generators pool. This controlled locator is not an exhaustive census of every window: no located candidate never proves absence. Multiple visible candidates are ambiguous and do not automatically imply replacement. A changed View can move the window outside these candidates; report UNVERIFIED rather than guessing a target.

Typed direct child inventory unions UIChildren/Children/GetUIChild/Ptr (at most 128 entries per path). This does not change production child fallback and is not a child-fallback root-cause experiment. No cross-display budget conclusion is drawn. The run has 24000 protected read calls and at most 400 tagged lines; cap exhaustion prevents a lifecycle conclusion. IsClassDerivedFrom guards every UI-only call; unknown/non-UI objects fail closed. Expected unavailable IsActuallyVisible is logged, never called on database handles.

## Classification

- **LIFECYCLE_STALE_CACHE_CONFIRMED**: a previously verified visible OLD grid remains valid and the copied production predicate accepts it, while explicit current-UI evidence shows OLD hidden/detached; or one unambiguous current NEW grid is different while OLD current visibility is not established true. Tile disappearance alone NEVER causes this classification. If OLD and a different NEW are both visibly current, do not infer staleness.
- **LIFECYCLE_NOT_REPRODUCED**: OLD becomes invalid, or is demonstrably hidden and the production predicate rejects it, so the production cache-validation branch would request rediscovery. This does not prove production discovery/painting succeeds; those are separate issues.
- **UNVERIFIED**: BEFORE fixture was not established, view did not replace the same visible grid, multiple candidates, unknown identity/type/visibility, budgets capped or evidence otherwise insufficient.

Classification concerns generic Pool lifecycle, not Generator resolution, alias matching, child fallback, display-scan performance or Cue-wide active reference discovery. CompareHandle is used solely to compare captured handles; no production integration.

## Safety and validation

Only diagnostic memory and Printf output are written. No Show/Sequence/Cue/Recipe/Programmer/playback/UI writes, no marker drawing, no automatic Recall, no commands, no GetPresetData/GetPresetDataFast, no ObjectList, no hooks and no background worker. Only 2.5.0.3 accepted.

[Lua](../diagnostics/Recall_View_Observer_2_5_0_3.lua), [XML](../diagnostics/recall_view_observer_2_5_0_3.xml), [mock tests](../tests/recall_view_observer.lua), [runner](../tools/run_recall_view_observer.py).

22 mock assertions PASS: two presses/state reset, valid-hidden stale cache, invalid/rejected grids, explicit actual false, hidden parent, unchanged/ambiguous view, missing fixture, positive/negative targets, retained handles and no non-UI API/mutation calls. These are offline only; lifecycle native results pending.

Deployment folder: `C:/ProgramData/MALightingTechnology/gma3_library/datapools/plugins/Recall View Observer 2.5.0.3`.

## Deployment verification

- recall_view_observer_2_5_0_3.xml: parse PASS; source/deployed SHA256 MATCH `31e2a831299cc5499d95fd3893903abb6cd00a44dab6abe9f490dd1a7f5216e4`.
- Recall_View_Observer_2_5_0_3.lua: parse PASS; source/deployed SHA256 MATCH `fb6ade38a8081a5216068763e8d7b6121ccee5ad4d2bb7abc3eda4f7ec5887ee`.

Actual isolated copy executed. Production Update Plugin snapshot unchanged; production source equals HEAD after Git filtering. 22 observer assertions, 23 topology assertions and 86 workflow assertions PASS (offline). Lifecycle native test PENDING.
