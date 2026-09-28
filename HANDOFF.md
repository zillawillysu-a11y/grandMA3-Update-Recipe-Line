# Project Handoff

## Current Goal

Native validate the independent Global Grid Applicability A/B probe on grandMA3 2.5.0.3, focused on Preset 4.4. Production, Rev7 baseline, oracle, UI marker, Selective mapping, and Preset 25.9008 are out of scope.

## Current Working State

The independent Plugin reads Group 85/86, Sequence 3858 Cue 1/2, and Preset 4.4 without changing showfile state. Cooked comparison treats an Attribute absent on both sides as non-comparable while requiring at least one comparable Preset-linked Attribute per member. Focused tests, Lua 5.4, deterministic build, and XML validation pass. Production is unchanged. PATCH NATIVE RETEST PENDING.

## Latest Real-World User Test

Latest native Global Grid A/B run: Group A/B have the same seven canonical members (FID 101–107), different grid hashes, and Preset 4.4 cooked Color attributes present and linked on both sides. CID normalization works. `GLOBAL_AB_PRECHECK` failed solely because CRI, CTO, and ColorRGB_W were absent on both sides for this fixture type.

## Verified Facts

- Existing `RecipeUpdate_Diagnostic.lua` reads Group `Selection[*].sf_index` and `Selection[*].grid.{x,y,z}` without changing selection.
- Installed vendor tests use `GetSubfixture(sf_index)` and `GetPresetData(CuePart, false, true)` for cooked fixture/Attribute records.
- `GetPresetData(Preset, false, true)` is a storage view, not an all-applicable-members list.
- The new probe fails closed on unresolved Cue Part, ambiguous member identity, missing grid coordinates, incompatible Preset mode, Recipe link mismatch, and cooked mapping uncertainty.

## Current Problem

Rerun native A/B after the absent-both comparison patch. No final A/B conclusion exists yet.

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

`origin/qwen` atop baseline `71f1789`; the older dirty `qwen` worktree is untouched.

## Exact Next Action

Rerun the independent Plugin on grandMA3 2.5.0.3 and review `GLOBAL_AB_PRECHECK`, comparable/absent-both counts, `GLOBAL_AB_DIFF`, and result. Do not infer a Rev13 rule from local validation.
