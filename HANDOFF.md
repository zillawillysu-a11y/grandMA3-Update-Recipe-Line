# Project Handoff

## Current Goal

Native validate the independent Global Grid Applicability A/B probe on grandMA3 2.5.0.3, focused on Preset 4.4. Production, Rev7 baseline, oracle, UI marker, Selective mapping, and Preset 25.9008 are out of scope.

## Current Working State

The independent Plugin reads Group 85/86, Sequence 3858 Cue 1/2, and Preset 4.4 without changing showfile state. The CID patch accepts only nil, numeric 0, and exact string `None` as parent-fixture NO_CID; other representations fail closed. Five focused CID cases, Lua 5.4, deterministic build, and XML validation pass. It is deployed to its own `Global Grid Applicability AB 2.5.0.3` folder with matching source/deployed SHA256; production is unchanged. CID PATCH NATIVE RETEST PENDING.

## Latest Real-World User Test

First native Global Grid A/B run: `GLOBAL_AB_PRECHECK pass=false` with `COOKED_SUBFIXTURE_KEY_UNPROVEN`, `GROUP_GRID_NOT_PROVEN_DIFFERENT`, and `GROUP_MEMBER_SET_DIFFERENT_OR_UNPROVEN`. Native parent fixture CID was exact string `None`. User will make Group 86 members equal Group 85 Fixtures 101–107, changing only grid positions.

## Verified Facts

- Existing `RecipeUpdate_Diagnostic.lua` reads Group `Selection[*].sf_index` and `Selection[*].grid.{x,y,z}` without changing selection.
- Installed vendor tests use `GetSubfixture(sf_index)` and `GetPresetData(CuePart, false, true)` for cooked fixture/Attribute records.
- `GetPresetData(Preset, false, true)` is a storage view, not an all-applicable-members list.
- The new probe fails closed on unresolved Cue Part, ambiguous member identity, missing grid coordinates, incompatible Preset mode, Recipe link mismatch, and cooked mapping uncertainty.

## Current Problem

Repeat native A/B after user corrects Group 86. The CID representation blocker is patched locally; no A/B conclusion exists yet.

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

`origin/qwen`, diagnostic checkpoint atop commit subject `test: separate ordinary Preset motion and member proof`. The older dirty `qwen` worktree is untouched.

## Exact Next Action

After Group 86 matches Group 85 Fixtures 101–107 with different Selection Grid positions, rerun the deployed independent Plugin on grandMA3 2.5.0.3 and review native `GLOBAL_AB_PRECHECK`, Group/cooked member lines, `GLOBAL_AB_DIFF`, and result. Do not infer a Rev13 rule from local validation.
