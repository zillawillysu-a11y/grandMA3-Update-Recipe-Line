# Project Handoff

## Current Goal

Native validate the diagnostic-only Rev13 Global ordinary applicability classifier and isolated alternate. Production, shared Rev7 semantics, oracle, UI marker, Selective Presets, and Preset 25.9008 are out of scope.

## Current Working State

The controlled Global Grid A/B probe passed natively. Rev13 target selection now resolves five Preset paths to native handles and joins by `metadataCache.identity`, with exactly-five sanity output. Missing or duplicate targets make its alternate INCONCLUSIVE. The classifier and fixture/Attribute compatibility gate are unchanged; Rev7 remains untouched. Native rerun is pending.

## Latest Real-World User Test

Latest Rev13 native Cue 8 run: Rev7 remained four refs, missing=0, extra=0, final-surviving unsafe=19. Rev13 alternate reported zero eligible rows and 19 survivors, but printed no `GLOBAL_APPLICABILITY_CLASS`. Native `desc(ref)` includes a `[#...]` suffix, so full display-string equality missed all five targets.

## Verified Facts

- Existing `RecipeUpdate_Diagnostic.lua` reads Group `Selection[*].sf_index` and `Selection[*].grid.{x,y,z}` without changing selection.
- Installed vendor tests use `GetSubfixture(sf_index)` and `GetPresetData(CuePart, false, true)` for cooked fixture/Attribute records.
- `GetPresetData(Preset, false, true)` is a storage view, not an all-applicable-members list.
- The new probe fails closed on unresolved Cue Part, ambiguous member identity, missing grid coordinates, incompatible Preset mode, Recipe link mismatch, and cooked mapping uncertainty.

## Current Problem

Rev13 must natively confirm all five targets are found/classified. The corrected target wiring is locally tested, not yet native verified. No production gate change is authorized.

## Known Failed Attempts

Treating Global grid/individual metadata as automatically harmless has no native member-applicability proof. Do not promote Global rows into Rev7 based on this probe alone.

## Important Files

- `tools/templates/global_grid_ab.lua`
- `diagnostics/global_grid_applicability_ab_2_5_0_3.xml`
- `tools/run_global_grid_ab.py`
- `tools/deploy_global_grid_ab.py`
- `tests/global_grid_ab.lua`
- `docs/global-grid-ab-probe.md`

## Current Branch / Commit

`origin/qwen` atop baseline `4e098ed`; the older dirty `qwen` worktree is untouched.

## Exact Next Action

Run the updated independent Cue-wide diagnostic on grandMA3 2.5.0.3 Cue 8. Confirm `REV13_GLOBAL_TARGET_SUMMARY expected=5 found=5 classified=5 pass=true`, five `GLOBAL_APPLICABILITY_CLASS` lines, and unchanged Rev7 results. Review shape reasons before any further rule.
