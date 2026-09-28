# Project Handoff

## Current Goal

Native validate the Rev13.1 signature delta observer for four Global ordinary Presets versus Preset 4.4. Production, Rev7, Rev13 classification and compatibility gate, oracle, Selective Presets, and Preset 25.9008 are out of scope.

## Current Working State

Rev13 target wiring passed natively. Rev13.1 adds only a cached-metadata observer that compares component signatures for Presets 4.1, 4.23, 6.10, and 21.5 against 4.4. It separates key identity, value, structure, and cardinality differences. The Rev13 classifier, eligible rows, compatibility gate, and Rev7 remain unchanged. Native Rev13.1 rerun is pending.

## Latest Real-World User Test

Latest Rev13 native Cue 8 run: target summary expected=5, found=5, classified=5, pass=true. Rev7 remained four refs, missing=0, extra=0, final-surviving unsafe=19. All five are Global, non-selective, motion-static proven, with the same printed masks, single step, and ABS layer. Preset 4.4 matches its control signature; the other four differ in unprinted signature components. No rows were promoted.

## Verified Facts

- Existing `RecipeUpdate_Diagnostic.lua` reads Group `Selection[*].sf_index` and `Selection[*].grid.{x,y,z}` without changing selection.
- Installed vendor tests use `GetSubfixture(sf_index)` and `GetPresetData(CuePart, false, true)` for cooked fixture/Attribute records.
- `GetPresetData(Preset, false, true)` is a storage view, not an all-applicable-members list.
- The new probe fails closed on unresolved Cue Part, ambiguous member identity, missing grid coordinates, incompatible Preset mode, Recipe link mismatch, and cooked mapping uncertainty.

## Current Problem

Identify which cached metadata components cause the four Rev13 signature mismatches. No production gate change is authorized.

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

`origin/qwen` atop baseline `b8c9552`; the older dirty `qwen` worktree is untouched.

## Exact Next Action

Run the updated independent Cue-wide diagnostic on grandMA3 2.5.0.3 Cue 8. Review four `GLOBAL_SIGNATURE_DELTA` summaries and bounded component lines, alongside unchanged Rev13 alternate and Rev7 results. Do not change classifier semantics from observer output alone.
