# Project Handoff

## Current Goal

Preserve the native-correct Recipe/Fixture/SubFixture/Cell results while
bringing selection/Cue/marker response into the user's acceptable 100–200 ms
range. Separate warm-cache behavior from cold Cue resolution.

## Current Working State

v0.7.1.29 implements Pool reference identity indexing, avoids marking the Pool
dirty on every empty-selection refresh, and skips unchanged overlay writes.
Lua/XML static parsing and `git diff --check` passed. The three intended plugin
files were deployed to the Update Plugin directory and their SHA256 hashes
match. Offline assertions and native behavior have not been run for this
change. REAL-WORLD VALIDATION PENDING.

## Latest Real-World User Test

On v0.7.1.28 the user confirmed correct contents but reported 2–3 second
responses. Detail samples recorded 2220.5 and 4331.1 ms resolver elapsed for
43 rows / 1295 members; they are not native API lower bounds. v0.7.1.29 has not
yet been tested on grandMA3.

## Verified Facts

- The implementation indexes command/native addresses and HandleToInt /
  HandleToStr tokens. It verifies indexed candidates with `sameReference` and
  retains a Generator/Random alias fallback.
- Existing marked buttons still validate `ObjectIndex` through `PoolObject:Ptr`
  on each refresh; grid visibility and bounded rediscovery remain in place.
- Current steady marker colors allow W/H/Visible/BackColor/Text writes to be
  skipped when the cached overlay properties are unchanged.
- Research call-count tool expectations were updated for the new index but
  were not executed. No tests were added or run in this change.
- Existing native evidence observed the Recipe reference and visible Generator
  tile returning the same handle for Generator 103. Other alias forms and
  handle-conversion behavior still need on-console confirmation.
- Deployment backup: `C:/tmp/update-plugin-pre-0.7.1.29-20260929-225201`.

## Current Problem

This bounded Pool/UI change does not remove the staged Sequence resolver's
multi-second cold work. Cache invalidation and identity equivalence beyond the
observed Generator case need native validation before broader warm-path reuse.

## Known Failed Attempts

Increasing resolver slices or shortening yields alone did not remove total
work. Current 2–4 second samples mix scheduler waits and processing; they do
not establish a platform lower bound.

## Important Files

- `RecipeTracking_Inspector.lua`
- `recipe_update_diagnostic.xml`
- `tools/research_marker_call_counts.py`
- `docs/track-a-marker-latency-research.md`
- `tools/templates/show_track_a_runtime.lua`

## Current Branch / Commit

Worktree: `C:/tmp/show-rel`, detached from `origin/qwen` at the research
checkpoint subject `docs: investigate Track A marker latency and native API
options`. v0.7.1.29 changes are local and not yet committed or pushed.

## Exact Next Action

User tests v0.7.1.29 on grandMA3 2.5.0.3: verify marker equivalence for
Generator 103 and other visible references, empty-selection stability, Pool
scroll/View Recall recycling, and hidden-grid cleanup. Capture end-to-end
selection/Cue-to-final-frame latency and `tile_apply_ms`. Then continue with a
warm stage-cache shortcut only after its dependency invalidation is proven.
