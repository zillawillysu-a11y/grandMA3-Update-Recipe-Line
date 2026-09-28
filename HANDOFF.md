# Project Handoff

## Current Goal

Native validate the diagnostic Global Recipe applicability truth probe on the 15 final-surviving Global ordinary rows. Production, Rev7, Rev13 classifier and eligibility, oracle, Selective Presets, UI marker, and Preset 25.9008 are out of scope.

## Current Working State

Rev13.2 found all five Global refs have matching semantic cores; dict_index remains unproven or cardinality-dependent. The new truth observer reads the cooked view of each surviving row's source CuePart once per unique Part, then evaluates only Rev11.1 surviving member/feature/layer keys. Absent cooked Attributes remain INCONCLUSIVE unless fixture capability is independently proven absent. The observer cannot change Rev7/Rev13 results. Native truth probe is pending.

## Latest Real-World User Test

Latest Rev13.2 native Cue 8 run: all five surviving Global refs have `semantic_core_match=true`. Preset 4.1 and 4.4 each have 66 unique dict_index values with UNPROVEN classification; Presets 4.23, 6.10, and 21.5 are CARDINALITY_DEPENDENT. Attribute and storage-source relations remain unproven. Rev7 remains four refs, missing=0, extra=0, final-surviving unsafe=19; Rev13 eligible_global_rows=0.

## Verified Facts

- Existing `RecipeUpdate_Diagnostic.lua` reads Group `Selection[*].sf_index` and `Selection[*].grid.{x,y,z}` without changing selection.
- Installed vendor tests use `GetSubfixture(sf_index)` and `GetPresetData(CuePart, false, true)` for cooked fixture/Attribute records.
- `GetPresetData(Preset, false, true)` is a storage view, not an all-applicable-members list.
- The new probe fails closed on unresolved Cue Part, ambiguous member identity, missing grid coordinates, incompatible Preset mode, Recipe link mismatch, and cooked mapping uncertainty.

## Current Problem

Native cooked evidence is needed to distinguish linked, unsupported, mismatched, and unresolved surviving lanes. No production gate change is authorized.

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

`origin/qwen` atop baseline `10a59ce`; the older dirty `qwen` worktree is untouched.

## Exact Next Action

Run the updated independent Cue-wide diagnostic on grandMA3 2.5.0.3 Cue 8. Review 15 `GLOBAL_RECIPE_APPLICABILITY_ROW` lines, its summary/reference lines, cooked Part read count, and unchanged Rev7/Rev13 results. Do not generalize beyond these surviving lanes.
