# Project Handoff

## Current Goal
Rev4 = `4_REFERENCE_METADATA_CACHE`, independent Recipe Reverse A/B on grandMA3 2.5.0.3. Formal Stored Group + Recipe authoring contract. Production untouched, marker flag false, no main merge.

## Current Working State
Three isolated paths: native-only Rev3 proof gates (zero GetPresetData) finalize first; fresh reference-only metadata cache plus second existing reverse engine finalize next; unchanged oracle last. Stable native HandleToInt / H# HandleToStr identities share cache across aliases. One read maximum per registered Recipe reference per run, failed reads cached. No Cue/Part metadata GetPresetData, no cooked-history fallback, no markers/waits. COMPLETE/PARTIAL/UNKNOWN and unsafe classifications retained even on exact comparison.

## Latest Real-World User Test
Rev3: 10 Cues / 31 Parts / 96 rows / 17 Groups, 25 distinct refs (15 ordinary, 10 ValueSource), native Feature proof 10, Layer/MOTION/STATIC proof zero. Native-only refs zero, oracle four, missing four, safe integration false. Native Attribute -> Feature -> FeatureGroup works. Strict zero GetPresetData is no longer mandatory for the new reference-only cache.

## Verified Facts
Local Lua 5.4 suite passes: 17 engine checks, 176 integration checks, 42 metadata checks, 6 Rev3 audit assertions. Deterministic generation, copied oracle fidelity, XML component validation and disabled production marker flag pass. Metadata parser uses actual UI-index record Attribute chains and effective numeric ABS/REL steps, conservatively rejects incomplete/unknown shapes. Unit/integration evidence is not native correctness. Independent deploy script verifies source/deployed hashes and unchanged production folder/source.

## Current Problem
Native Rev4 return schema, reference coverage, layer/motion classification, equality and elapsed times require user validation. COMPLETE means supported parsed schema only. Unreadable Generators, opaque dependencies, unknown fields, mixed feature-layer motion, remove and mixed release semantics stay unsafe. Metadata total excludes reused native history/group preparation and Rev3 audit overhead.

## Known Failed Attempts
Rev1 stringified handles and spammed member logs. Rev2/3 structural Feature proof succeeded but native layer/ordinary Preset metadata remained unreadable. No name/pool-number inference; no return to cooked history optimization.

## Important Files
- tools/templates/cue_wide_recipe_reference_metadata.lua
- tools/templates/cue_wide_recipe_reverse_ab_core.lua
- tools/templates/cue_wide_recipe_reverse_engine.lua (unchanged)
- tools/templates/cue_wide_recipe_value_source.lua (unchanged)
- tools/build_cue_wide_recipe_reverse_ab.py
- tools/run_cue_wide_recipe_reverse_ab.py
- tools/deploy_cue_wide_recipe_reverse_ab.py
- tests/cue_wide_recipe_reference_metadata.lua
- tests/cue_wide_recipe_reverse_ab.lua
- diagnostics/cue_wide_recipe_reverse_resolver_ab_2_5_0_3.xml
- docs/cue-wide-recipe-reference-metadata-rev4.md

## Current Branch / Commit
qwen; checkpoint subject `test: add Rev4 reference metadata cache reverse path`. Preserve unrelated staged .gitmodules/shared-reference and uncommitted AGENTS.md, structural A/B template, README.md. main unmerged.

## Exact Next Action
Re-import the same independent XML from ProgramData plugins / Cue-wide Recipe Reverse Resolver AB 2.5.0.3. Select Sequence 3841 / Cue 8 as native validation target only. START must say revision=4_REFERENCE_METADATA_CACHE. Capture native-only final, cache call/hit/completeness/timing metrics, normalized evidence, metadata reverse final and surviving counts, oracle last, comparisons and RESULT/END. Confirm at most one read per DB identity and no Cue/Part metadata targets. Validate more Cues before considering production.

REAL-WORLD VALIDATION PENDING
