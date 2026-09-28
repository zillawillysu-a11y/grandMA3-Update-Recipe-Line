# Project Handoff

## Current Goal

Finish the Fast-Track show release: native-proven Track A resolver, exact Fixture/SubFixture/Cell Stored Group matching, multiple complete Groups, existing Pool marker pulse, and production candidate deployment. Real-world validation is pending.

## Current Working State

Muse's uncommitted v0.7.1.0 candidate is preserved in the show-rel worktree. It adds canonical dotted Fixture keys, complete Group collection, a lightweight newest-first Recipe source walk, and Group/Recipe Pool marker wiring. It preserves the existing Global.SuccessText/Global.Selected frame0 pulse, hidden-grid rediscovery, and bounded Pool traversal. Offline workflow and candidate tests pass. Do not deploy this candidate yet.

## Latest Real-World User Test

The native Track A checkpoint passed: member identity, Global ordinary, Selective, and Preset 25.9008 known ABS are proven; 9008 unknown REL is safe noncontributing. Four final references match the oracle with no missing or extra references. The current production candidate has not been tested in grandMA3.

## Verified Facts

- Native identity is strict ToAddr(handle) -> Fixture <numeric dotted key>, with unique ObjectList(ToAddr()) round-trip. Parent and child remain distinct.
- The candidate's Group matcher admits every complete contained Stored Group and rejects partial Groups.
- Candidate tests exercise Group, Preset, Phaser, and Generator marker sources, multiple complete Groups, parent/child distinction, override, Recipe deletion cache invalidation, and no cooked-history scan.
- Existing marker colors, frame texture, Recall View hidden-grid handling, and bounded discovery were not changed.

## Current Problem

The candidate's sources function is not the native-proven Track A production resolver. It uses member plus Feature name hints, but does not implement reference-level ABS/REL lane semantics, ordinary static terminators, Selective member applicability, or the 9008 known-ABS/unknown-REL split. Its PROVEN label and green offline tests must not be treated as release evidence. The production deployment gate is blocked until these semantics are ported and a Cue 8 fixture proves exactly four references with missing=0/extra=0.

## Known Failed Attempts

Muse's initial candidate only resolved the Programmer-selected Feature. This was exposed by a new two-Feature test and corrected. Parsed ToAddr text alone was accepted without the native unique-handle round-trip; this was corrected. The resolver cache also ignored Recipe deletion; the candidate now includes current Recipe/source context in its key.

## Important Files

- RecipeTracking_Inspector.lua
- recipe_update_diagnostic.xml
- tests/show_candidate.lua
- tests/recipe_workflow.lua
- tools/run_workflow.py
- tools/templates/cue_wide_recipe_reverse_engine.lua

## Current Branch / Commit

Detached show-rel worktree based on origin/qwen; see Git for the latest checkpoint. The older dirty qwen worktree is untouched.

## Exact Next Action

Port the already-proven Track A reference/lane gates into a small production resolver using cached reference metadata, without diagnostic observers or cooked Cue history. Add release tests for ordinary static terminators, Global and Selective applicability, 9008 ABS/REL split, exact four Cue 8 references, and source-cache invalidation. Then run the full workflow suite, Lua 5.4, deterministic build, XML, and diff checks. Deploy only after the release gate passes; verify source/deployed SHA256 and request native test.
