# Project Handoff

## Current Goal

Native validate the truth observer's wildcard-layer refinement for the 15 final-surviving Global ordinary rows. Production, Rev7, Rev13 classifier and eligibility, oracle, Selective Presets, UI marker, and Preset 25.9008 are out of scope.

## Current Working State

The truth observer now refines `FG:<id>|*` to `FG:<id>|ABS` only when cached Rev12.1 proof shows motion-static, exactly one authored/effective ABS layer and one step per channel, and the feature maps to reference Attributes. It does not mutate attribution keys. It separates lane, reference Attribute, cooked view, and member-key failures. Native rerun is pending; Rev7/Rev13 are unchanged.

## Latest Real-World User Test

Latest native Cue 8 truth probe: all 15 rows checked, all INCONCLUSIVE, 1,406 surviving lanes all unresolved, four unique cooked Part reads. All row reasons were `LANE_OR_COOKED_VIEW_UNPROVEN`. Attribution retained wildcard layers while Rev12.1 already proved unique ABS motion-static semantics for the five Global references. Rev7 and Rev13 alternate remained unchanged.

## Verified Facts

- Existing `RecipeUpdate_Diagnostic.lua` reads Group `Selection[*].sf_index` and `Selection[*].grid.{x,y,z}` without changing selection.
- Installed vendor tests use `GetSubfixture(sf_index)` and `GetPresetData(CuePart, false, true)` for cooked fixture/Attribute records.
- `GetPresetData(Preset, false, true)` is a storage view, not an all-applicable-members list.
- The new probe fails closed on unresolved Cue Part, ambiguous member identity, missing grid coordinates, incompatible Preset mode, Recipe link mismatch, and cooked mapping uncertainty.

## Current Problem

Native rerun must show which lanes pass refinement and whether remaining blockers are reference Attribute mapping, cooked view, member identity, or fixture capability. No production gate change is authorized.

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

`origin/qwen` atop baseline `11dedc6`; the older dirty `qwen` worktree is untouched.

## Exact Next Action

Run the updated independent Cue-wide diagnostic on grandMA3 2.5.0.3 Cue 8. Review `GLOBAL_RECIPE_LAYER_REFINEMENT` samples, `layer_refined_lanes`, `layer_refinement_failed_lanes`, split unresolved reasons, and unchanged Rev7/Rev13 results.
