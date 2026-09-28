# Project Handoff

## Current Goal
Rev8 `8_RAW_REL_GROUND_TRUTH_CONTROL`: locate the native or serialized difference between a known blank Relative cell and a persistently authored Relative zero in grandMA3 2.5.0.3.

## Current Working State
An independent read-only observer compares every matching PhaserRecipeValueSource in the two user-designated Presets. It logs all enumerated property differences, especially REL/value/layer/mask/active/storage evidence, without invoking the reverse engine or cooked oracle. An offline comparer can read existing XML exports, but the observer never exports or mutates show data. The independent plugin was deployed with matching source/deployed hashes; production and the Rev7 zero gate remain unchanged. Ground-truth native validation is pending.

## Latest Real-World User Test
Rev7 on Sequence 3841 / Cue 8: 20 ValueSources in 7 patterns; REL_AUTHORED_PROVEN=0, REL_NOT_AUTHORED_PROVEN=1, REL_AMBIGUOUS=19. Numeric RawValueRel=0 with empty ValueRelative getter, absent Layer/ValueLayer, and complete ABS-only linked Preset remained correctly ambiguous. Rev7 final refs=0; oracle refs=4. The user then copied Preset 25.9009 to 25.9013 and explicitly authored Relative=0 in the copy. After closing/reopening the editor, 25.9013 still displays 0 while untouched 25.9009 remains blank.

## Verified Facts
The two Presets have known different REL authoring histories; neither has been changed by Rev8. Installed MA3 2.5 resources document direct ValueSource `ValueRelative` editing, its `RawValueRel` mapping, and Preset export. The shared developer-reference checkout is absent from this worktree. The persistent UI difference does not identify the storage field.

## Current Problem
The exact native or serialized field distinguishing un-authored REL from authored zero is unknown. No matching XML exports were present locally. Rev8 must be run natively on the two existing controls; an export comparison is optional if the user supplies exports.

## Known Failed Attempts
Rev7's linked ABS-only Preset, empty ValueRelative getter, absent Layer, and numeric zero did not independently distinguish authored from default REL zero. Do not infer from those signals or weaken the zero gate.

## Important Files
- `docs/raw-rel-ground-truth-rev8.md`
- `tools/templates/raw_rel_ground_truth.lua`
- `diagnostics/raw_rel_ground_truth_control_2_5_0_3.xml`
- `tools/compare_raw_rel_ground_truth_exports.py`
- `tests/raw_rel_ground_truth.lua`
- `tools/run_raw_rel_ground_truth.py`

## Current Branch / Commit
`rev6-native`, based on the Rev7 raw relative zero semantics audit; Rev8 checkpoint subject `test: add Rev8 raw REL ground truth control`. The older dirty `qwen` worktree is untouched.

## Exact Next Action
Run the independent Rev8 observer in the existing grandMA3 2.5.0.3 show and capture all `GROUND_TRUTH_*` and `RAW_REL_GROUND_TRUTH_RESULT` lines. Compare every matched Step/ValueSource. If XML exports are supplied, run the offline comparer. Report exact differences before changing any resolver classification.

GROUND-TRUTH VALIDATION PENDING
