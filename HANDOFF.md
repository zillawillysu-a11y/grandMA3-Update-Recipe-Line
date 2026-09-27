# Project Handoff

## Current Goal
Independent Cue-wide Recipe Reverse Resolver A/B 2.5.0.3. Recipe-only state authoring with Stored Groups and referenced Values is a formal product contract. Target architecture is per-member + feature/layer reverse tracking. Previous cooked feature/footprint optimization paused. Production untouched, ENABLE_CUE_PHASER_MARKERS=false, no main merge.

## Current Working State
Independent reverse engine, native structural adapter, generated standalone XML/Lua, runner, deployer and documentation implemented. Resolve overlaps and static terminators per sf_index; retain source occurrences until membership resolution. Unknown structure blocks older assertions conservatively. Fast path forbids GetPresetData and has no channel scan/batching/waits/markers. Finalize immutable fast identity set, then replay unchanged existing Structural A/B oracle pipeline. Independently deployed. REAL-WORLD VALIDATION PENDING.

## Latest Real-World User Test
No native Recipe Reverse run yet. User reports current Sequence 3841 / Cue 8 cooked oracle has four final refs. Identities/count not hardcoded. Prior Rev4 cooked hybrid matched four refs but was too slow; do not resume that optimization.

## Verified Facts
30 semantic/integration mock checks PASS under Lua 5.4. Deterministic generation, unchanged oracle section fidelity, disabled production flag PASS. XML/component existence and source/deployed Lua 5.4 checks PASS. Standalone source/deployed SHA256 match; production source and deployed Update Plugin folder unchanged. sf_index preserves distinct subfixture identities in mocks; actual native cell Groups not yet validated.

## Current Problem
Native structure may not expose Layer or ordinary Preset motion/static evidence. These cases are unsafe/UNVERIFIED, never assumed absolute/static and never trigger cooked fallback. Advertised Layer metadata semantics and exposed step-tree coverage require native validation. Known standard pool families and exact source/channel Attribute identifiers only; user-authored names excluded. Multi-feature/layer association rejected when ambiguous. Exact identity match with unsafe rows is insufficient for integration.

## Known Failed Attempts
Previous cooked optimizations do not solve the requested architecture. Existing features helper mixes structural metadata with label/address hints and cannot be reused wholesale. No native success claimed for this new experiment.

## Important Files
- tools/templates/cue_wide_recipe_reverse_engine.lua
- tools/templates/cue_wide_recipe_reverse_ab_core.lua
- tools/build_cue_wide_recipe_reverse_ab.py
- tools/run_cue_wide_recipe_reverse_ab.py
- tools/deploy_cue_wide_recipe_reverse_ab.py
- tests/cue_wide_recipe_reverse_engine.lua
- tests/cue_wide_recipe_reverse_ab.lua
- diagnostics/cue_wide_recipe_reverse_resolver_ab_2_5_0_3.xml
- diagnostics/Cue_Wide_Recipe_Reverse_Resolver_AB_2_5_0_3.lua
- docs/cue-wide-recipe-reverse-resolver-ab-2.5.0.3.md

## Current Branch / Commit
qwen; checkpoint subject `test: add independent Recipe member reverse resolver A/B`. Preserve pre-existing staged .gitmodules/shared-reference integration and uncommitted AGENTS.md, README.md and tools/templates/cue_wide_structural_ab_core.lua edits. They are outside this checkpoint. main unmerged.

## Exact Next Action
Import the standalone XML from `C:\ProgramData\MALightingTechnology\gma3_library\datapools\plugins\Cue-wide Recipe Reverse Resolver AB 2.5.0.3`. Select Sequence 3841 / Cue 8. Capture [CueRecipeReverseAB] START through END, especially FAST_FINALIZED, METRICS, UNSAFE metadata, SOURCE/FIRST_NEWER, DIFF_SOURCE/DIFF_LANE and RESULT. Require identical oracle identity set and fast GetPresetData_calls=0; report unsafe Group/member/feature/layer explicitly. Then native multi-Cue, static replacement, re-source, overlap and cell tests before integration. No production fallback or automatic cooked broadening. REAL-WORLD VALIDATION PENDING.
