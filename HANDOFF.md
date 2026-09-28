# Project Handoff

## Current Goal

Native validation of v0.7.1.2 in grandMA3 2.5.0.3. Restore exact Group marker response and identify Cue 8's unsafe lane blockers without guessing Recipe refs.

## Current Working State

`C:\tmp\show-rel` is the authoritative worktree. v0.7.1.2 keeps Track A fail-closed gates, canonical Fixture/SubFixture/Cell identity, marker appearance (`frame0`, existing theme colors), and old Cue Phaser scanner disabled. Layout selections may resolve selected member lanes of a partially selected Stored Group; this does not make that Group a complete UPDATE target. When Recipe proof fails, an exact current Group may be framed independently. A bounded `Blocked refs:` panel line identifies unsafe references.

## Latest Real-World User Test

v0.7.1.1 native screenshots: selecting 210 fixtures showed Group 231 and `UNSAFE_LANE_ATTRIBUTION_BLOCKER`, but no frames; selecting 24 fixtures showed Group 80 and the same blocker; selecting two Layout fixtures showed `NO_APPLICABLE_RECIPE` and no two-Group list. Clear was immediate. Selection to panel response felt close to one second. No Cue 8 EFX Pool tile had a frame.

## Verified Facts

- The two-light Recipe scope was excluded before the resolver because only wholly contained Stored Groups were admitted. v0.7.1.2 intersects each Recipe Group with selected canonical members.
- v0.7.1.1 cleared all Group marker sources when Track A returned INCONCLUSIVE. v0.7.1.2 admits only an independently exact current Group in that case, never guessed Recipe refs or overlapping subset Groups.
- Native `UNSAFE_LANE_ATTRIBUTION_BLOCKER` remains unresolved. The new panel line exposes up to four blocking reference identities. Do not weaken semantics before inspecting this evidence.
- Offline checks: 86 workflow assertions and 100 show candidate checks passed, including synthetic four refs exactly. Lua parse, deterministic build, XML parse, and diff check passed.

## Current Problem

Actual Cue 8 Recipe reference tiles still lack native proof. Group 231 frame and two-light multi-Group behavior require native retest. The approximately one-second latency has no reliable native stage measurement yet; do not claim it is fixed.

## Important Files

- `RecipeTracking_Inspector.lua`
- `tools/templates/show_track_a_runtime.lua`
- `tests/show_candidate.lua`
- `recipe_update_diagnostic.xml`

## Current Branch / Commit

Detached `C:\tmp\show-rel` worktree based on origin/qwen. Check Git status and log before work.

## Exact Next Action

In grandMA3 load v0.7.1.2. On Cue 8 select Group 231 exactly and verify its tile frame, then select the same two Layout lights and inspect the Group list and Resolver line. If Recipe frames remain absent, capture the visible `Blocked refs:` line and one `ContextTiming` line if available. Clear and verify frames disappear immediately. Continue from those native facts; do not infer unsafe metadata semantics from names.
