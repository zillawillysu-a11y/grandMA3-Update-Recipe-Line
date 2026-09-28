# Project Handoff

## Current Goal
Attribute the 50 Rev7 unsafe rows from the proven Rev11 Cue 8 walk with an observation-only diagnostic, without changing resolver behavior, gates, refs, or the oracle.

## Current Working State
Rev11.1 adds a Rev7 unsafe-attribution pass reusing reverse-walk member/feature/layer barrier state (no second scan, pcall-isolated, capped output). Local targeted regressions green. No production, gate, ref-set, lane, motion, classification, marker, wait, history, or show-data change. Native validation is pending.

## Latest Real-World User Test
Rev11 native Cue 8 on 2.5.0.3: Rev6/Rev7 final refs exactly 25.9006/25.9007/25.9009/25.9010, missing=0 extra=0, both EXACT_MATCH. Rev7 rows=96 lanes=1119 static=4 moving=6 unsafe=50 final=4 reverse≈188ms total≈334ms. REV7_REFERENCE_UNSAFE with safe_integration=false still blocks production integration.

## Verified Facts
Unsafe rows never decide lanes; they only register member/feature/layer barriers. Unresolved blocked lanes and barrier-superseded safe rows are the resolver's own surviving-influence records. Selective member mapping stays unproven; B/C attributions are observation only, never resolver safety.

## Current Problem
Determine for each unsafe row whether its lanes can still affect the Cue 8 final marker state (A), are fully superseded by newer decisions (B), contribute nothing structural (C), or cannot be determined (D, fail-closed).

## Known Failed Attempts
Rev6/Rev7 treated linked selective/member applicability as unsafe. Rev10 re-resolved A/B from exported ShowData paths; rejected natively. Do not re-resolve linked handles from export paths or use the failed pool-label lookup as evidence.

## Important Files
- `tools/templates/cue_wide_recipe_field_semantics.lua`
- `tools/templates/cue_wide_recipe_reverse_ab_core.lua`
- `tools/build_cue_wide_recipe_reverse_ab.py`
- `diagnostics/cue_wide_recipe_reverse_resolver_ab_2_5_0_3.xml`
- `tools/run_cue_wide_recipe_reverse_ab.py`
- `tests/cue_wide_recipe_reverse_ab.lua`

## Current Branch / Commit
`rev6-native`, Rev11.1 attribution checkpoint. Superseded uncommitted Rev9 raw-REL integration is preserved in a local stash; the older dirty `qwen` worktree is untouched.

## Exact Next Action
Deploy the rebuilt Reverse Resolver AB diagnostic and run it natively against Cue 8 on 2.5.0.3; capture UNSAFE_ATTRIBUTION_SUMMARY, UNSAFE_REASON_SUMMARY, UNSAFE_REFERENCE_SUMMARY, FINAL_SURVIVING_UNSAFE_ROW, and ATTRIBUTION_UNKNOWN_ROW lines. Answer the six attribution questions from that output. Do not integrate into production before review.

REAL-WORLD VALIDATION PENDING
