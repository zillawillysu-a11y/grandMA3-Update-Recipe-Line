# Project Handoff

## Current Goal
Rev8.1: validate the native `ValueRelative` discriminator between a known blank Relative cell and persistently authored Relative zero in grandMA3 2.5.0.3, without resolver integration.

## Current Working State
The independent read-only observer now compares normalized semantic property observations, excluding transient `PropertyInfo` table addresses. It repeat-reads RawValueRel and ValueRelative, checks ABS semantic equality and Step 1 blank-REL negative controls, and recognizes the controlled Step 2 empty-versus-numeric-zero pattern. Local regressions pass. No resolver, production plugin, or show data changed. Rev8.1 native validation is pending.

## Latest Real-World User Test
Two independent Rev8 runs in the same native log observed Step 2 RawValueRel numeric 0 in both controls, but ValueRelative direct/Get/display empty strings on untouched 25.9009 and numeric 0/numeric 0/`0.00` on authored-zero 25.9013. Rev8 incorrectly returned INCONCLUSIVE because `PropertyInfo` produced new Lua table addresses and created false ABS differences.

## Verified Facts
The two Presets have known different REL authoring histories and are untouched. Native Step 2 `ValueRelative` is the observed discriminator; `RawValueRel` alone is not. The Rev8.1 patch is only a validation observer and does not promote any resolver state.

## Current Problem
Rev8.1 must confirm stable repeat reads and Step 1 negative controls in a fresh native run. No matching XML exports were present locally; export comparison remains optional.

## Known Failed Attempts
Rev7's linked ABS-only Preset, absent Layer, and numeric RawValueRel zero did not independently distinguish authored from default REL zero. Rev8's comparator mistakenly included transient `PropertyInfo` table identities. Do not infer from RawValueRel alone or weaken the zero gate.

## Important Files
- `docs/raw-rel-ground-truth-rev8.md`
- `tools/templates/raw_rel_ground_truth.lua`
- `diagnostics/raw_rel_ground_truth_control_2_5_0_3.xml`
- `tools/compare_raw_rel_ground_truth_exports.py`
- `tests/raw_rel_ground_truth.lua`
- `tools/run_raw_rel_ground_truth.py`

## Current Branch / Commit
`rev6-native`, Rev8.1 diagnostic checkpoint in progress. The older dirty `qwen` worktree is untouched.

## Exact Next Action
Run the updated independent Rev8.1 observer in grandMA3 2.5.0.3 and capture `GROUND_TRUTH_REPEAT_READ`, `GROUND_TRUTH_PROPERTY_DIFF`, and `RAW_REL_GROUND_TRUTH_RESULT`. Confirm Step 1 blank in both controls, Step 2 stable empty versus numeric zero, and no ABS difference. Do not integrate into resolver yet.

GROUND-TRUTH VALIDATION PENDING
