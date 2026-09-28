# Project Handoff

## Current Goal

Native validate a read-only hierarchical Fixture address probe for the 1,176 lanes blocked by member identity. Production, Rev7, attribution, Rev13 eligibility, Selective Presets, UI marker, Group matching, Attribute capability, and Preset 25.9008 are out of scope.

## Current Working State

The side observer now compares display-derived hierarchical Fixture addresses with independent native address properties and parent-child ordinal evidence. It requires cooked bucket Attribute evidence and unique reverse mapping; display-only matches remain diagnostic. It reports the 16 old-candidate residual cases separately and reuses the truth observer's cooked Part cache. Truth, Rev7, and Rev13 remain unchanged.

## Latest Real-World User Test

Latest native Cue 8 member-key probe: cooked `by_fixtures` keys are strings such as `216.1.10`; problematic SubFixtures have direct FID/CID nil while parent or ancestor Fixtures carry FID. The old candidates mapped no proven shape; 16 cases had some old candidate evidence and 1,160 were unmapped. Truth refined all 1,406 lanes to ABS; 183 Attribute-capability lanes remain out of scope. Rev7 and Rev13 remain unchanged.

## Verified Facts

- Existing `RecipeUpdate_Diagnostic.lua` reads Group `Selection[*].sf_index` and `Selection[*].grid.{x,y,z}` without changing selection.
- Installed vendor tests use `GetSubfixture(sf_index)` and `GetPresetData(CuePart, false, true)` for cooked fixture/Attribute records.
- `GetPresetData(Preset, false, true)` is a storage view, not an all-applicable-members list.
- The new probe fails closed on unresolved Cue Part, ambiguous member identity, missing grid coordinates, incompatible Preset mode, Recipe link mismatch, and cooked mapping uncertainty.

## Current Problem

Native rerun must show whether handle Addr/AddrNative/ToAddr plus FromAddr round-trip prove the 1,176 member-key lanes as canonical cooked-bucket identity. Bucket-exists and Attribute-present are evaluated separately; Attribute-absent stays an Attribute-capability problem. The 16 sf_index residuals are rechecked as accidental other-bucket collisions. No production, Rev7, attribution, Rev13, eligibility, truth, Selective, Preset 25.9008, Attribute-capability, Group matcher, or UI change is authorized.

## Known Failed Attempts

Treating Global grid/individual metadata as automatically harmless has no native member-applicability proof. Do not promote Global rows into Rev7 based on this probe alone.

## Important Files

- `tools/templates/cue_wide_recipe_member_key_probe.lua`
- `tools/templates/cue_wide_recipe_hierarchical_key_probe.lua`
- `tools/templates/cue_wide_recipe_global_truth.lua`
- `tools/templates/cue_wide_recipe_reverse_ab_core.lua`
- `tests/cue_wide_recipe_member_key_probe.lua`
- `tests/cue_wide_recipe_hierarchical_key_probe.lua`
- `tools/run_cue_wide_recipe_reverse_ab.py`
- `tools/deploy_cue_wide_recipe_reverse_ab.py`

## Current Branch / Commit

`origin/qwen` atop baseline `95e69a6`; the older dirty `qwen` worktree is untouched.

## Exact Next Action

Run the updated independent Cue-wide diagnostic on grandMA3 2.5.0.3 Cue 8 and review NATIVE_MEMBER_ADDRESS_SAMPLE/SUMMARY plus OLD_SF_INDEX_COLLISION_SUMMARY. Also review `COOKED_HIERARCHICAL_ADDRESS_SHAPE/SAMPLE/SUMMARY`, `COOKED_OLD_CANDIDATE_RESIDUAL`, optional alternate, and unchanged original truth/Rev7/Rev13 summaries. Member identity closed (ObjectList PROVEN 1176/1176). Attribute capability intersection probe added (GetUIChannels/GetAttributeByUIChannel, convention proven, cached per handle, cooked compared on intersection only); deployed Lua SHA256 4bf5c5c6; runner green incl. 295 integration checks. INDEX-1 single-convention fix deployed (Lua SHA256 8eee906c): dual-candidate logic removed, channel/enumeration diagnostics added. Selective member applicability probe added (UI-ownership intersection, superseded excluded, rows_expected=3); deployed Lua SHA256 d5573184; runner green incl. 296 integration checks. Wildcard-barrier scope fix deployed (Lua SHA256 be595da6): FG+ABS scope derived from referenceRaw, expanded semantic lanes, row-count alternate accounting. Phaser 9008 partial-split probe deployed (Lua SHA256 132bd21c): safe ABS clone + REL barrier alternate vs oracle, cooked cross-check only. Gate/safety fix deployed (Lua SHA256 8d7bcf16): linked gate uses Rev12 ordinary proof, attribution row-count reporting, lane-based Path A/B. Reporting fix deployed (Lua SHA256 fdcd57b0): Path B excludes synthetic barrier by identity, TRACK_A requires empty blockers.
