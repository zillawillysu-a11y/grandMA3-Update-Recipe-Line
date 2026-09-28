# Project Handoff

## Current Goal

Native validate the diagnostic-only Rev13 Global ordinary applicability classifier and isolated alternate. Production, shared Rev7 semantics, oracle, UI marker, Selective Presets, and Preset 25.9008 are out of scope.

## Current Working State

The controlled Global Grid A/B probe passed natively. Rev13 now inspects final-surviving Global ordinary refs using cached metadata, comparing their semantic signatures with Preset 4.4. Fixture/Attribute compatibility for Cue 8 is not established by the A/B test, so this independent gate remains fail-closed and no row is promoted on shape alone. Rev13 computes an isolated alternate and leaves baseline Rev7 untouched. Native Rev13 validation is pending.

## Latest Real-World User Test

Global Grid A/B native run passed: same seven canonical members, different grid hashes, `GLOBAL_AB_PRECHECK pass=true`, `GRID_NO_OBSERVED_MEMBER_EFFECT`, 42 comparable attributes, 21 absent on both sides, and all seven members with comparable Preset 4.4 links. This only establishes the controlled Preset 4.4 / fixture type case.

## Verified Facts

- Existing `RecipeUpdate_Diagnostic.lua` reads Group `Selection[*].sf_index` and `Selection[*].grid.{x,y,z}` without changing selection.
- Installed vendor tests use `GetSubfixture(sf_index)` and `GetPresetData(CuePart, false, true)` for cooked fixture/Attribute records.
- `GetPresetData(Preset, false, true)` is a storage view, not an all-applicable-members list.
- The new probe fails closed on unresolved Cue Part, ambiguous member identity, missing grid coordinates, incompatible Preset mode, Recipe link mismatch, and cooked mapping uncertainty.

## Current Problem

Rev13 native Cue 8 metadata shapes and fixture/attribute compatibility remain to be reviewed. No production gate change is authorized.

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

`origin/qwen` atop baseline `4ceef49a`; the older dirty `qwen` worktree is untouched.

## Exact Next Action

Run the updated independent Cue-wide diagnostic on grandMA3 2.5.0.3 Cue 8 and review each `GLOBAL_APPLICABILITY_CLASS`, `REV13_GLOBAL_ALTERNATE`, and remaining unsafe refs. Determine what additional native compatibility evidence is needed before any promotion.
