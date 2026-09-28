# Project Handoff

## Current Goal
Run Rev7 `7_RAW_REL_ZERO_SEMANTICS_PROOF` as an independent grandMA3 2.5.0.3 diagnostic for Sequence 3841 / Cue 8.

## Current Working State
Rev7 follows native-only, Rev4, Rev5, and Rev6 baselines. It audits existing Phaser ValueSources and linked Presets from the run-local reference cache, then finalizes its own reverse result before the cooked oracle. Numeric RawValueRel zero remains unsafe. Production, reverse engine, member applicability, and markers are unchanged. Local Lua 5.4 regressions, deterministic build, and XML checks pass. The independent diagnostic was deployed with matching source/deployed SHA256; native Rev7 validation is pending.

## Latest Real-World User Test
Rev6: 15 ordinary Presets (2 static proven), 5 linked normalized (2 static complete), 10 Phaser refs (4 motion proven). Metadata COMPLETE=6, PARTIAL=19, UNKNOWN=0. Reverse rows=96, lanes=850, static terminators=4, moving rows=0, unsafe rows=69, final refs=0. Oracle refs=4, missing 25.9006, 25.9007, 25.9009, 25.9010, extra=0.

## Verified Facts
Installed 2.5 vendor keypad maps ValueRelative to RawValueRel. Vendor system tests define cooked active value bits ABS=2 and REL=4, and can expect active relative zero. Shipped Shape XML contains RawValueRel=0. No available source establishes whether a numeric zero on a particular PhaserRecipeValueSource is authored or a default. Rev7 logs bounded raw/getter/Layer/linked comparisons and never promotes zero from its value alone.

## Current Problem
Need native Rev7 pattern observations to see whether an independent ValueSource REL discriminator exists. Separately, linked Preset member applicability remains unsafe and is outside Rev7.

## Known Failed Attempts
Rev5 and Rev6 cannot safely promote numeric zero. A Layer label or linked Preset mask alone does not define the local ValueSource's authored REL state.

## Important Files
- `tools/templates/cue_wide_recipe_raw_rel_zero.lua`
- `tools/templates/cue_wide_recipe_reverse_ab_core.lua`
- `tools/build_cue_wide_recipe_reverse_ab.py`
- `tests/cue_wide_recipe_raw_rel_zero.lua`
- `docs/cue-wide-recipe-raw-rel-zero-rev7.md`
- `diagnostics/cue_wide_recipe_reverse_resolver_ab_2_5_0_3.xml`

## Current Branch / Commit
`rev6-native`, Rev7 checkpoint subject `test: add Rev7 raw relative zero semantics audit`. The older dirty `qwen` worktree is untouched.

## Exact Next Action
Import the independent Rev7 diagnostic, run Sequence 3841 / Cue 8, and capture START, RAW_REL_ZERO_PATTERN_SUMMARY and patterns, RAW_REL_ZERO_PROOF_SUMMARY, REV7 summaries/final, and oracle-last DIFF/RESULT. Use the native observations to decide whether zero can ever be promoted with independent evidence. Do not integrate into production.

REAL-WORLD VALIDATION PENDING
