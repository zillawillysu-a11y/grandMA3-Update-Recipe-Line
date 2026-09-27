# Cue-wide Recipe Reverse Resolver A/B 2.5.0.3

Current diagnostic revision: **2_VALUE_SOURCE_AUDIT**. See [Rev2 evidence and proof gates](cue-wide-recipe-value-source-rev2.md) for the native failure, verified MA 2.5 source semantics, supported subset and compact output.

## Supported product contract

Cue state is authored through Recipe rows using Stored Groups and referenced Presets, Phasers, Generators or equivalent objects. Arbitrary hard/manual Cue state is outside the supported authoring model. The intended production architecture is Recipe/Group structural reverse tracking. Structurally unreadable cases are unsupported/unsafe and never silently trigger cooked fallback. Production remains unchanged and dormant until native multi-Cue validation.

## Resolution

Visit Current Cue history newest first, including every Part and enabled Recipe row. Expand each Group once per run into a native sf_index member set. Distinct subfixture/cell indices are never collapsed to parent fixture or exact Group identity. For each proven member + FeatureGroup identity + layer lane, newer rows win only on their overlapping members. Static rows terminate older moving rows without adding a marker reference. Re-sourced references retain their occurrence ownership until membership resolution and only then deduplicate by database identity.

Rev2 uses source-correlated feature/layer pairs, never a Cartesian product. Unsafe newer rows block older assertions conservatively. Unknown selection blocks historical claims globally. Unknown feature/layer scope uses symbolic wildcard barriers. No cache persists between runs, so Group/Recipe edits and deletions are observed on the next invocation. Actual cell selection inheritance remains a native acceptance item.

## Fast path and oracle

The fast path has no cooked channel scan, GetPresetData calls, waits, marker drawing or production batching. Its private GetPresetData wrapper raises on attempted reads, and successful finalization requires the call count to remain zero. The fast result is frozen before running the existing copied Structural A/B oracle pipeline, including its current-Cue merge and Recipe recovery. That last-running oracle can compare but never repair or broaden the fast result.

All requested match/missing/extra/unsafe/UNVERIFIED classifications remain available. EXACT_MATCH establishes only the current snapshot identity set; unsafe rows still prevent a production-completeness claim. The four observed native oracle identities are not embedded in code.

## Local verification and deployment

- `python tools/build_cue_wide_recipe_reverse_ab.py`
- `python tools/run_cue_wide_recipe_reverse_ab.py`
- `python tools/deploy_cue_wide_recipe_reverse_ab.py`

The runner checks Lua 5.4, mocks, deterministic generation, unchanged oracle-source fidelity and the disabled production flag. The independent deployer validates XML, referenced component existence, source/deployed Lua 5.4 parsing and matching SHA256. It copies only the standalone XML/Lua and proves production source and the deployed Update Plugin folder remain unchanged.

## Native run

Import `cue_wide_recipe_reverse_resolver_ab_2_5_0_3.xml` from the separate `Cue-wide Recipe Reverse Resolver AB 2.5.0.3` plugin folder. Select Sequence 3841 / Cue 8 and run the diagnostic. START must show `revision=2_VALUE_SOURCE_AUDIT`.

Capture START through END, including FAST_PATH_METRICS, VALUE_SOURCE_AUDIT, aggregated UNSAFE/UNRESOLVED, Recipe-only final refs, oracle final refs, DIFF and RESULT. Require identical identity sets and zero fast GetPresetData calls. If a difference remains, use the exact source/dependency audit and aggregated Group/member/lane attribution to improve only the unproven structural case. Do not broaden into cooked history. Then test multiple Cues, static replacements, re-sources, overlapping Groups and actual cells before integration. REAL-WORLD VALIDATION PENDING.
