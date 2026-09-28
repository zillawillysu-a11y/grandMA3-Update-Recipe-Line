# Project Handoff

## Current Goal

Native validate the independent Global Grid Applicability A/B probe on grandMA3 2.5.0.3, focused on Preset 4.4. Production, Rev7 baseline, oracle, UI marker, Selective mapping, and Preset 25.9008 are out of scope.

## Current Working State

The new Plugin reads Group 85/86, Sequence 3858 Cue 1/2, and Preset 4.4. It resolves a Cue only when exactly one child Part has Recipe content, then compares canonical `sf_index` member sets, stored grid positions, and cooked per-member Attribute/Preset links. It changes no showfile state. Missing or ambiguous paths produce `GLOBAL_AB_PROBE_CONFIGURATION_REQUIRED`. Focused Lua 5.4, deterministic build, and XML validation pass. It is deployed to its own `Global Grid Applicability AB 2.5.0.3` Plugin folder with source/deployed SHA256 equality; production source/folder snapshots are unchanged. REAL-WORLD VALIDATION PENDING.

## Latest Real-World User Test

Rev12.1 Cue 8: Rev7 EXACT_MATCH, four refs, missing=0, extra=0, unsafe=50, final surviving=19, fully superseded=31, unknown=0. All 15 ordinary refs are motion-static proven; only two are member-applicability proven. Fifteen final-surviving Global ordinary rows remain blocked by grid/individual metadata; three Selective ordinary rows and Preset 25.9008 remain out of scope.

## Verified Facts

- Existing `RecipeUpdate_Diagnostic.lua` reads Group `Selection[*].sf_index` and `Selection[*].grid.{x,y,z}` without changing selection.
- Installed vendor tests use `GetSubfixture(sf_index)` and `GetPresetData(CuePart, false, true)` for cooked fixture/Attribute records.
- `GetPresetData(Preset, false, true)` is a storage view, not an all-applicable-members list.
- The new probe fails closed on unresolved Cue Part, ambiguous member identity, missing grid coordinates, incompatible Preset mode, Recipe link mismatch, and cooked mapping uncertainty.

## Current Problem

Native A/B output is needed to determine whether changing Group grid position affects cooked applicability for the controlled Preset 4.4 case. User supplied Group 85/86 and Sequence 3858 Cue 1/2; native unique Part resolution remains to be verified.

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

Run this independent Plugin on native grandMA3 2.5.0.3 and capture `GLOBAL_AB_PRECHECK`, both Group/member sections, cooked member lines, Preset metadata, `GLOBAL_AB_DIFF`, optional `GLOBAL_AB_RESULT`, and timing. If native object addressing differs, update the four CONFIG paths and redeploy. Review before any Rev13 resolver rule.
