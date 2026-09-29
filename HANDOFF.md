# Project Handoff

## Current Goal

Preserve the native-correct v0.7.1.28 Recipe/Fixture/SubFixture/Cell and marker
results; target end-to-end selection/Cue/marker response <=100 ms. Latest task
is research and a measurable cold/warm architecture, not another speculative
production deployment.

## Current Working State

Production is unchanged at v0.7.1.28. Added an API/source research document and
an offline call-count tool. Read the report before implementing. Runtime
latency optimizations have NOT been deployed. REAL-WORLD PERFORMANCE
VALIDATION PENDING.

## Latest Real-World User Test

User confirms contents are completely correct in the September 29 22:01/22:03
videos, but results take 2-3 seconds. Detail samples: resolver elapsed 2220.5
and 4331.1 ms, 43 rows/1295 members, scope 77.4-95.2 ms, Pool tile work
126.6-274.6 ms. These are not isolated native API lower bounds.

## Verified Facts

- Official documented GetUIChannels takes one member, not a member array.
  Exact 2.5.0.3 API descriptors still need a native read-only check.
- MA-supplied 2.5.0 Pool wrappers use PoolObject:Ptr(button.ObjectIndex).
  Scrolling tests confirm recycled buttons change ObjectIndex.
- Unmodified production closures, 200 mock tiles/13 refs: 2431 unsuccessful
  CompareHandle calls plus thousands of identity conversions per full scan.
  A stable non-dirty scan before deadline performs only 13 Ptr checks.
- render marks Pool dirty on every empty-selection refresh, bypassing throttle.
- A warm 1295-member groupKeys hit still calls GetSubfixture and ToAddr 1295
  times each. The offline tool asserts this; it does not measure native speed.
- Workflow: 88 assertions passed; call-count assertions passed on Lua 5.4.
- Existing show_candidate.lua fails Lua 5.4 parsing at line 1155 (200-local
  limit); file unchanged. Repair test scopes before the next runtime change.
- Runtime/XML hashes still match the deployed Update Plugin files. No Show
  commands or MA system tests were executed.

## Current Problem

100 ms is not established for cold or warm paths. Current elapsed timers mix
scheduler waits, normalization, panel/programmer work and Pool matching. Do
not call current 2-4 seconds an unavoidable platform limit without isolating
the necessary native calls. Native hook coverage and alternative numeric UI
channel equivalence need validation before cache invalidation is changed.

## Known Failed Attempts

Larger slices or shorter yields alone do not remove total work. Pool discovery
was already cheap in the captured samples; per-tile matching was not. A cache
that fingerprints all members before every hit still incurs native read cost.

## Important Files

- docs/track-a-marker-latency-research.md
- tools/research_marker_call_counts.py
- RecipeTracking_Inspector.lua
- tools/templates/show_track_a_runtime.lua
- tests/show_candidate.lua

## Current Branch / Commit

Authoritative continuation worktree: C:/tmp/show-rel, detached, pushed to
origin/qwen. Research checkpoint subject: docs: investigate Track A marker
latency and native API options. Verify actual status with Git. The older
Documents worktree remains untouched.

## Exact Next Action

Implement the report's first bounded optimization: eliminate all-ref identity
fallback for unmatched tiles through validated identity indexing; remove
unchanged empty-selection dirty and unchanged overlay writes. Preserve native
recycle/hidden-grid checks and Generator aliases. Add equivalence/invalidations
coverage, then measure native matching/apply time separately. In parallel in
the implementation plan (not delegated agents), design dependency epochs and
measure necessary capability calls before choosing a cold-path strategy.
