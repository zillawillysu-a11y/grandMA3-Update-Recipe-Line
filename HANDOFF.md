# Project Handoff

## Current Goal

Native validate Rev12.1 ordinary Preset motion/static and member-applicability proofs on Cue 8 in grandMA3 2.5.0.3. Production, Rev7 baseline, oracle, UI marker, and Preset 25.9008 remain unchanged.

## Current Working State

Rev12.1 corrects only the diagnostic ordinary-static observer and its report. The isolated alternate resolver promotes a row only when static motion and member applicability are both proven. Local focused Lua 5.4 tests and deterministic build pass. REAL-WORLD VALIDATION PENDING.

## Latest Real-World User Test

Rev12 Cue 8: Rev7 EXACT_MATCH, refs=4, missing=0, extra=0, unsafe=50, final surviving=19, fully superseded=31, unknown=0. The Rev12 observer reported ordinary_refs=15, static_proven=2, static_unproven=13, eligible_rows=0, projected final surviving=19. Most ordinary static failures carried `ACTIVE_PHASER_MASK_NOT_ZERO`, although bit 64 is vendor grid-position applicability. Selective dictionary metadata also incorrectly blocked motion.

## Verified Facts

- Installed 2.5 vendor `GetPhaserMask`/`PhaserMaskToList` defines 64 as `gridpos`; 4/8/16/32/128/256 as fade/delay/speed/phase/measure/nshot; 1/2 as Preset dependencies.
- The Rev6 field-semantics code already treats active bit 64 as `ACTIVE_GRID_POSITION_APPLICABILITY_UNPROVEN`.
- Rev12.1 local tests show bit 64 and Selective metadata can coexist with static motion proof while member applicability stays unproven. Vendor speed bit 16 and unknown bits block static proof.
- The observer reads only cached reference data, with no extra `GetPresetData` calls.

## Current Problem

Native Rev12.1 must determine how many of the 15 ordinary refs have static motion proven after separating bit 64, and whether member applicability remains the limiting evidence. The projected survivor count must come from the actual diagnostic alternate result, without forcing a decrease.

## Known Failed Attempts

Rev12 used `mask_active_phaser ~= 0` and treated `dict_flags.selective` as an unknown motion flag. Both conflated member applicability with motion. Do not restore either rule or relax the shared Rev7 resolver.

## Important Files

- `tools/templates/cue_wide_recipe_ordinary_static.lua`
- `tools/templates/cue_wide_recipe_reverse_ab_core.lua`
- `tests/cue_wide_recipe_ordinary_static.lua`
- `tests/cue_wide_recipe_reverse_ab.lua`
- `docs/ordinary-static-semantics-rev12.md`

## Current Branch / Commit

`origin/qwen`, Rev12.1 diagnostic checkpoint atop commit subject `test: observe ordinary Preset static semantics in Rev12`. The older dirty `qwen` worktree is untouched.

## Exact Next Action

Run Rev12.1 on native Cue 8. Capture all `ORDINARY_STATIC_PROOF` lines, the separate proof summary, any `ORDINARY_STATIC_ALTERNATE` line, Rev7 final refs/diff, and diagnostic timing. Report static versus member-proof counts and remaining reasons before any production decision.
