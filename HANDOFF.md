# Project Handoff

## Current Goal

Native validate Rev12 ordinary Preset static semantics on Cue 8 in grandMA3 2.5.0.3, without changing production or Rev7 gates.

## Current Working State

Rev12 adds a cached ordinary Preset static observer and an isolated alternate reverse result for proven Global/Universal static references. It leaves the Rev7 baseline, oracle, production, UI markers, and Preset 25.9008 unchanged. Local Lua 5.4 integration and deterministic build validation pass. The independent diagnostic was copied to its own grandMA3 Plugin folder; source/deployed SHA256 matches and production source/folder snapshots are unchanged. Native Rev12 validation is pending.

## Latest Real-World User Test

Rev11.1 Cue 8: Rev7 final references exactly 25.9006, 25.9007, 25.9009, 25.9010; missing=0, extra=0; reverse about 188.6 ms, total path about 331.3 ms. Of 50 unsafe rows, 31 fully superseded and 19 final surviving. The 19 are 18 ordinary Preset rows and one Phaser reference, 25.9008. All have `ref_in_final=false`.

## Verified Facts

- Installed 2.5 vendor system tests define active Phaser mask and ABS/REL active value bits 2/4. They identify Preset mode 1/2/3 as Selective/Global/Universal.
- Existing Rev11 linked Preset rule can excuse member applicability evidence for Universal/Global but keeps Selective member mapping unsafe.
- The Rev12 observer reads only the existing reference metadata cache and adds no `GetPresetData` calls.
- Local tests cover ordinary static, active Phaser and multistep negatives, unknown active dictionary flag, Selective motion proof with unsafe membership, and unchanged Rev7 final refs.

## Current Problem

Native Rev12 output must show whether all 18 ordinary final surviving rows satisfy the per-channel static proof, whether the isolated alternate result keeps the four final refs with missing=0/extra=0, and the performance overhead. Local mocks cannot establish those Cue 8 facts.

## Known Failed Attempts

Rev11.1 completeness combined static motion evidence with member applicability evidence, leaving ordinary rows unsafe. Do not weaken the shared resolver gate or infer Selective membership from a static step.

## Important Files

- `tools/templates/cue_wide_recipe_ordinary_static.lua`
- `tools/templates/cue_wide_recipe_reverse_ab_core.lua`
- `tests/cue_wide_recipe_ordinary_static.lua`
- `tests/cue_wide_recipe_reverse_ab.lua`
- `docs/ordinary-static-semantics-rev12.md`

## Current Branch / Commit

Rev12 diagnostic checkpoint atop `origin/qwen` baseline 5d6c255. The older dirty `qwen` worktree is untouched.

## Exact Next Action

Run the Rev12 diagnostic on Cue 8 in grandMA3 2.5.0.3. Capture every `ORDINARY_STATIC_PROOF`, `ORDINARY_STATIC_PROOF_SUMMARY`, and `ORDINARY_STATIC_ALTERNATE` line, plus the existing Rev7 final refs, diff, and timing. Compare static proof counts, projected final surviving unsafe rows, final reference set, missing/extra, and observer/alternate overhead. Stop before any production integration.
