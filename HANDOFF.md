# Project Handoff

## Current Goal
Independent Recipe Reverse A/B Rev3 `3_REFERENCE_SEMANTICS_AUDIT` on 2.5.0.3. Formal Group + Recipe authoring contract. Production untouched, ENABLE_CUE_PHASER_MARKERS=false, cooked optimization paused, main unmerged.

## Current Working State
Rev3 adds observational inspection of distinct references, actual parent pools, enumerated typed properties versus getter defaults, Recipe/Step/ValueSource structure and read-only dependencies. Existing reverse engine and Rev2 proof gates unchanged; audits never feed primary result. Optional reference metadata GetPresetData not enabled. Oracle last. Compact pattern limits and summaries. REAL-WORLD VALIDATION PENDING.

## Latest Real-World User Test
Rev2 ran 10 Cues / 31 Parts / 96 rows / 17 Groups, zero fast GetPresetData calls, refs=0, unsafe_rows=96, resolved lanes=0, ~2731.775 ms. Native Attribute -> Feature -> FeatureGroup resolution works (FG:12 example). Layer and opaque ordinary Preset metadata remain blockers; effective step/dependency motion unresolved for some refs. Oracle contains four refs, never hardcoded.

## Verified Facts
Local Lua 5.4 deterministic generation, unchanged oracle sections, 48 prior semantic/integration checks plus Rev3 audit tests pass. Native feature chain is user verified. New audit explicitly distinguishes absent enumerated properties from default getter results. Pool links/dependencies are observations, not complete content or motion proof. Independent deployer verifies XML, runtime hashes and unchanged production.

## Current Problem
Need native Rev3 reference/pool and layer properties to determine whether ordinary static Presets and linked motion/layer semantics can be proven structurally. Audit reports unreadable cases rather than broadening to cooked Cue history. Subfixture/cell semantics and multi-Cue native acceptance remain pending.

## Known Failed Attempts
Rev1 lost Attribute handles and spammed per-member logs. Rev2 feature proof succeeded but raw/effective layers and opaque Presets remain unsafe. Do not assume Shape means motion or raw numeric field alone establishes authored layer.

## Important Files
- tools/templates/cue_wide_recipe_reference_semantics.lua
- tools/templates/cue_wide_recipe_reverse_ab_core.lua
- tools/templates/cue_wide_recipe_value_source.lua (unchanged)
- tools/templates/cue_wide_recipe_reverse_engine.lua (unchanged)
- tools/build_cue_wide_recipe_reverse_ab.py
- tools/run_cue_wide_recipe_reverse_ab.py
- tools/deploy_cue_wide_recipe_reverse_ab.py
- diagnostics/cue_wide_recipe_reverse_resolver_ab_2_5_0_3.xml
- docs/cue-wide-recipe-reference-semantics-rev3.md

## Current Branch / Commit
qwen; checkpoint subject `test: add Rev3 native reference semantics audit`. Preserve unrelated staged shared-reference integration and AGENTS.md, README.md, structural A/B template edits. main unmerged.

## Exact Next Action
Re-import independent XML from ProgramData plugins / Cue-wide Recipe Reverse Resolver AB 2.5.0.3. Select Sequence 3841 / Cue 8. START must say revision=3_REFERENCE_SEMANTICS_AUDIT. Capture reference properties, parent pool links, Recipe/Step/ValueSource probes and SUMMARY, then Recipe-only/oracle identities, DIFF and END. No exact match is claimed; use only proven native semantics in a subsequent change. REAL-WORLD VALIDATION PENDING.
