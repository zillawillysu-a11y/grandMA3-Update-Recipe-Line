# Project Handoff

## Current Goal
Rev6 `6_REFERENCE_FIELD_SEMANTICS_PROOF`: independent Recipe Reverse diagnostic for grandMA3 2.5.0.3. Production and reverse engine untouched; marker flag false; no main merge.

## Current Working State
The diagnostic finalizes NATIVE_ONLY, Rev4 BASELINE_METADATA, unchanged Rev5 bridge baseline, then Rev6 semantics-proven bridge/reverse. The cooked oracle runs last for comparison only. Rev6 reuses the same run-local stable-identity reference cache; no Cue/Part/Sequence GetPresetData and no cooked-history fallback. Unsupported field/member/layer semantics remain unsafe. REAL-WORLD VALIDATION PENDING.

## Latest Real-World User Test
Rev5 on Sequence 3841/Cue 8: 25 direct Recipe refs, 5 linked dependencies, 28 unique reference reads, 103 cache hits, native GetPresetData about 5.906 ms. Rev5 candidate refs 0, oracle refs 4, missing 4. Phaser structure and effective step differences were visible; linked Presets and raw zero layer semantics blocked completeness. Ordinary Presets exposed useful ABS channels but dictionary, preset-mode, and matrix fields blocked proof. Do not rerun Rev5 unchanged.

## Verified Facts
Shared MA3 2.5.0.3 API index defines GetPresetData signature, not dictionary field semantics. Installed MA3 2.5 system tests define active value masks, `pm` mode, selective per-fixture data, and step absolute/absolute_value use. Numeric relative zero can be authored. Rev6 uses these references conservatively, audits bounded native distributions, and treats nonempty grid/matrix or selective applicability as unsafe. Local full Recipe Reverse suite, Lua 5.4 syntax, deterministic build, XML parse, and source/deployed SHA checks must be distinguished from native behavior.

## Current Problem
Rev6 native field distributions and reference identity result have not yet been observed. It is unknown whether native rows expose an explicit ValueSource Layer and whether all linked ordinary Presets become COMPLETE. Exact oracle match, static termination, and removal of any older superseded moving reference require native validation.

## Known Failed Attempts
Rev4 direct Phaser GetPresetData was empty. Rev5 linked Preset metadata remained PARTIAL and zero raw REL remained ambiguous. Neither result justifies production integration or cooked-history fallback.

## Important Files
- `tools/templates/cue_wide_recipe_field_semantics.lua`
- `tools/templates/cue_wide_recipe_metadata_bridge.lua`
- `tools/templates/cue_wide_recipe_reverse_ab_core.lua`
- `tools/templates/cue_wide_recipe_reverse_engine.lua` (unchanged)
- `tools/build_cue_wide_recipe_reverse_ab.py`
- `tests/cue_wide_recipe_field_semantics.lua`
- `diagnostics/cue_wide_recipe_reverse_resolver_ab_2_5_0_3.xml`
- `docs/cue-wide-recipe-field-semantics-rev6.md`

## Current Branch / Commit
`qwen`; checkpoint subject `test: add Rev6 reference field semantics proof`. Preserve staged `.gitmodules` and shared reference; preserve uncommitted `AGENTS.md`, structural A/B template, and `README.md`. Main unmerged.

## Exact Next Action
Import the independent Rev6 diagnostic XML, run Sequence 3841/Cue 8, capture START, FIELD_SEMANTICS distributions, RAW_LAYER_SEMANTICS_SUMMARY, static/linked/motion proof, REV6_BRIDGED_REVERSE_FINAL, oracle-last DIFF/RESULT. Report exact unresolved field and Recipe/Group/member/layer when it remains unsafe. Do not change production before multi-Cue native validation.

REAL-WORLD VALIDATION PENDING
