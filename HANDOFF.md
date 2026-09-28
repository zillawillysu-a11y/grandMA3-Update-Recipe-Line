# Project Handoff

## Current Goal
Integrate the proven Rev8.1 Relative rule and linked-Preset PRESETMODE classification into the Recipe Reverse resolver for the Cue 8 diagnostic walk, without changing the oracle or production.

## Current Working State
Rev11 templates built into the Reverse Resolver AB diagnostic; all local regressions green (Rev3-Rev8.1, both A/B suites, applicability observer). No production, resolver-oracle, marker, wait, Cue/Part history, or show-data change. Native validation is pending.

## Latest Real-World User Test
Rev10.1 native run proved on 2.5.0.3: case A PRESETMODE=Universal, case B PRESETMODE=Selective, C/D Universal, case B member_count=18 keys 130-147 matching XML. Case A linked object is class=Preset name="100" index=11 toaddr="Preset 1.11"; the validation-only "Preset 1.100" lookup did not CompareHandle-match, so the DIRECT linked handle is authoritative. Rev8.1 proved the ValueRelative triple rule: un-authored REL shows RawValueRel 0 with empty direct/Get/display; authored REL zero shows numeric zero with 0.00 display.

## Verified Facts
Only the two proven rules are integrated. PRESETMODE is the primary discriminator; record flags are corroborating evidence only. Selective member applicability stays unsafe; by-fixtures keys are not canonical fixture/subfixture/cell identities. ABS zero stays unpromoted. Unknown/unreadable mode stays unsafe.

## Current Problem
Confirm exact Cue 8 agreement (25.9006/25.9007/25.9009/25.9010) in a real grandMA3 native Rev11 run: 25.9006/25.9007 via Universal linked 1.28/1.14, 25.9009/25.9010 via the ValueRelative rule.

## Known Failed Attempts
Rev6/Rev7 treated linked selective/member applicability as unsafe. Rev10 re-resolved A/B from exported ShowData path strings; grandMA3 rejected that syntax. Do not re-resolve linked handles from export paths or use the failed pool-label lookup as evidence.

## Important Files
- `tools/templates/cue_wide_recipe_field_semantics.lua`
- `tools/templates/cue_wide_recipe_metadata_bridge.lua`
- `tools/templates/cue_wide_recipe_reverse_ab_core.lua`
- `diagnostics/cue_wide_recipe_reverse_resolver_ab_2_5_0_3.xml`
- `tools/run_cue_wide_recipe_reverse_ab.py`
- `tests/cue_wide_recipe_reverse_ab.lua`

## Current Branch / Commit
`rev6-native`, Rev11 integration checkpoint. Superseded uncommitted Rev9 raw-REL integration is preserved in a local stash; the older dirty `qwen` worktree is untouched.

## Exact Next Action
Deploy the rebuilt Reverse Resolver AB diagnostic and run it natively against Cue 8 on 2.5.0.3; capture the RESULT/REV6_RESULT/REV7_RESULT classifications, BRIDGED/REV6/REV7 diff sets, blocker reasons, and the timing/GetPresetData summary lines. Compare final refs against 25.9006/25.9007/25.9009/25.9010. Do not integrate into production before review.

REAL-WORLD VALIDATION PENDING
