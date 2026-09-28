# Project Handoff

## Current Goal
Rev5 = `5_REFERENCE_METADATA_BRIDGE`, independent Recipe Reverse diagnostic for grandMA3 2.5.0.3. Production untouched; ENABLE_CUE_PHASER_MARKERS=false; no marker drawing/waits; no main merge.

## Current Working State
Native-only result finalizes first, unchanged Rev4 BASELINE_METADATA second. New ordinary GetPresetData + native PhaserRecipe/ValueSource + cached linked-Preset candidate finalizes third, using the existing member/lane reverse engine. Cooked oracle runs last for identity comparison only. No Cue/Part/Sequence metadata reads and no cooked-history fallback. Same run-local stable DB cache holds direct and linked references; one native read per identity. Partial/unknown references are barriers, not guesses. REAL-WORLD VALIDATION PENDING.

## Latest Real-World User Test
Rev4 on Sequence 3841/Cue 8: 25 direct references/read calls, 71 hits, native GetPresetData 4.871 ms total (0.195 average, 0.393 max); normalization 205.458 ms, cache 225.638 ms, reverse 95.910 ms, total metadata path 321.553 ms. COMPLETE 0, PARTIAL 15, UNKNOWN 10. Recipe metadata refs 0, oracle refs 4, missing 4. Ordinary Presets have 58-channel/other useful ABS records but unknown masks/dictionary fields; direct Phaser reference data is empty despite native PhaserRecipe children. IDs are evidence only, never hardcoded.

## Verified Facts
Installed grandMA3 2.5 system tests document active Phaser/value/cooked masks and blocked dictionary flags. New Rev5 audit checks values/types and logs compact per-record patterns. It distinguishes Phaser structure from motion proof, checks enumerated raw vs getter defaults, actual Attribute/Feature/FeatureGroup links, linked Preset feature/layer agreement and effective step differences. Mocks pass 17 engine, 187 integration, 42 Rev4 metadata, 16 Rev5 bridge and 6 Rev3 audit assertions; Lua 5.4/deterministic XML checks pass. Local mocks are not native correctness.

## Current Problem
Native Rev5 metadata patterns and bridge completeness need validation. Unknown masks/flags, nonempty grid matrix, raw zero without linked-layer proof, unreadable ValueSources or dependencies remain unsafe. A match still requires multi-Cue native proof before production. Performance counts reuse the direct-reference cache and exclude Rev3 audit and comparison-only Rev4 reverse.

## Known Failed Attempts
Rev1 stringified native Attribute handles and spammed logs. Rev2/3 native-only feature proof worked but layer/ordinary static termination did not. Rev4 reference-only GetPresetData is cheap, but direct Phaser references are empty and ordinary records need semantic interpretation. Do not rerun unchanged Rev4 or return to cooked-history scanning.

## Important Files
- tools/templates/cue_wide_recipe_metadata_bridge.lua
- tools/templates/cue_wide_recipe_reference_metadata.lua (Rev4 normalization unchanged; raw cache/dependency extension)
- tools/templates/cue_wide_recipe_reverse_ab_core.lua
- tools/templates/cue_wide_recipe_reverse_engine.lua (unchanged)
- tools/build_cue_wide_recipe_reverse_ab.py
- tools/run_cue_wide_recipe_reverse_ab.py
- tools/deploy_cue_wide_recipe_reverse_ab.py
- tests/cue_wide_recipe_metadata_bridge.lua
- tests/cue_wide_recipe_reverse_ab.lua
- diagnostics/cue_wide_recipe_reverse_resolver_ab_2_5_0_3.xml
- docs/cue-wide-recipe-metadata-bridge-rev5.md

## Current Branch / Commit
qwen; checkpoint subject `test: add Rev5 reference metadata bridge candidate`. Preserve staged .gitmodules/shared-reference and uncommitted AGENTS.md, structural A/B template, README.md. main unmerged.

## Exact Next Action
Re-import the independent XML. On Sequence 3841/Cue 8 confirm START revision=5_REFERENCE_METADATA_BRIDGE, capture compact ordinary record patterns, Phaser source/linked-Preset evidence, direct versus dependency read counts, bridge proof/safety summaries, BRIDGED_REVERSE_FINAL, rejected-overlap trace, oracle last, DIFF and RESULT. If ambiguity remains, use exact native fields to refine only the affected source/record. Test multiple Cues before production.

REAL-WORLD VALIDATION PENDING
