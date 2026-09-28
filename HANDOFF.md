# Project Handoff

## Current Goal

Native validate a diagnostic cooked member-key representation probe for the 1,176 lanes blocked by member identity. Production, Rev7, attribution, Rev13 eligibility, Selective Presets, UI marker, Group matching, Attribute capability, and Preset 25.9008 are out of scope.

## Current Working State

Wildcard-to-ABS truth refinement passed natively. The new side observer collects all problematic members, their parent hierarchy, candidate native cooked keys, and bounded `by_fixtures` key distributions. A shape is proven only when exactly one candidate relation covers every case with expected Attribute evidence and has no member-key collision. It reuses the truth observer's cooked Part cache and cannot alter truth, Rev7, or Rev13.

## Latest Real-World User Test

Latest native Cue 8 truth probe: 1,406 surviving lanes, all 1,406 refined to ABS, zero refinement failures and zero different-Preset lanes. The 15 rows remain INCONCLUSIVE: five Preset 4.4 rows account for 1,176 `MEMBER_KEY_UNPROVEN` lanes (112, 210, 210, 336, 308); the other 183 unresolved lanes are `ATTRIBUTE_CAPABILITY_UNPROVEN`. Four unique source CueParts were read. Rev7 and Rev13 remain unchanged.

## Verified Facts

- Existing `RecipeUpdate_Diagnostic.lua` reads Group `Selection[*].sf_index` and `Selection[*].grid.{x,y,z}` without changing selection.
- Installed vendor tests use `GetSubfixture(sf_index)` and `GetPresetData(CuePart, false, true)` for cooked fixture/Attribute records.
- `GetPresetData(Preset, false, true)` is a storage view, not an all-applicable-members list.
- The new probe fails closed on unresolved Cue Part, ambiguous member identity, missing grid coordinates, incompatible Preset mode, Recipe link mismatch, and cooked mapping uncertainty.

## Current Problem

Native rerun must reveal whether the 1,176 member-key lanes have a unique cooked bucket relation. The 183 Attribute-capability lanes remain separately unresolved. No production or Group matcher change is authorized.

## Known Failed Attempts

Treating Global grid/individual metadata as automatically harmless has no native member-applicability proof. Do not promote Global rows into Rev7 based on this probe alone.

## Important Files

- `tools/templates/cue_wide_recipe_member_key_probe.lua`
- `tools/templates/cue_wide_recipe_global_truth.lua`
- `tools/templates/cue_wide_recipe_reverse_ab_core.lua`
- `tests/cue_wide_recipe_member_key_probe.lua`
- `tools/run_cue_wide_recipe_reverse_ab.py`
- `tools/deploy_cue_wide_recipe_reverse_ab.py`

## Current Branch / Commit

`origin/qwen` atop baseline `78f3d4e`; the older dirty `qwen` worktree is untouched.

## Exact Next Action

Run the updated independent Cue-wide diagnostic on grandMA3 2.5.0.3 Cue 8. Review `COOKED_PART_KEY_SHAPE`, `COOKED_MEMBER_KEY_SHAPE/SAMPLE/SUMMARY`, optional alternate, and unchanged original truth/Rev7/Rev13 summaries.
