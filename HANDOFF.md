# Project Handoff

## Current Goal

Continue development of the grandMA3 Recipe Tracking Inspector on grandMA3 2.3.2.0.

Current focus is the persistent Inspector UI and interaction behavior.

Do not begin Phase 2 Recipe writer work yet.

---

## Current Working State

Primary implementation:

* `RecipeTracking_Inspector.lua`
* `recipe_update_diagnostic.xml`

Legacy/read-only research implementation:

* `RecipeUpdate_Diagnostic.lua`

The persistent Inspector uses a non-modal native-style grandMA3 UI hierarchy and is deployed for real onPC testing.

Repository state and actual source files are authoritative.

Always run:

* `git status --short --branch`
* `git log -5 --oneline`

before continuing.

---

## Latest Real-World User Test

The latest Inspector UI still has problems:

1. Close `X` still visually looks like a separate inset button.

   * User wants the X visually integrated into the title bar like a normal window close control.
   * The X glyph itself may be small while retaining a usable click area.

2. Title text is too small.

   * It should be larger and visually belong to the title bar.

3. Transparency behavior is wrong.

   * Current transparency appears dependent on mouse hover/pointer being inside the window.
   * User wants the intended transparency to remain without requiring hover.

4. `Cue Recipe Update Tool` should not appear centered as unwanted content.

   * Determine which UI element creates this text and remove/reposition it appropriately.

5. `STYLE` still does not produce the required visible behavior.

   * Changing only button text is not sufficient.
   * The actual window/panel style or transparency must change.

These observations override assumptions from previous UI commits.

---

## Verified Facts

* The persistent Inspector can run as a non-modal grandMA3 UI.
* Native title-bar dragging has worked in real grandMA3 2.3.2.0 testing.
* Read-only Recipe/source resolution research is substantially validated for the current Phase 0/1 scope.
* Local deployment path is:

`C:\ProgramData\MALightingTechnology\gma3_library\datapools\plugins\Update Plugin`

* Deployment must include XML plus referenced Lua components.
* Repository/deployment SHA256 equality verifies file identity only; it does not verify UI correctness.
* No Phase 2 writer implementation should begin yet.

---

## Current Problem

The current task is not deployment verification.

The current task is to change the Inspector implementation so that the latest real-world UI feedback is actually addressed.

Do not simply redeploy the existing implementation.

A new requested UI behavior change should produce a relevant source diff before deployment.

---

## Known Failed Attempt

The previous UI adjustment reduced/repositioned the close button and changed styling, but the real grandMA3 result still did not satisfy the requested visual behavior.

Do not repeat the same close-button sizing approach without first inspecting the UI hierarchy.

Previous successful SHA256 deployment verification does not mean the UI requirement passed.

---

## Important Files

### Current implementation

* `RecipeTracking_Inspector.lua`
* `recipe_update_diagnostic.xml`

### Supporting research

* `docs/research.md`
* `docs/api-reference-comparison.md`
* `docs/pool-window-research.md`

### Project rules/state

* `AGENTS.md`
* `HANDOFF.md`

Read supporting research only when needed to answer a specific implementation question.

---

## Current Branch / Commit

Do not trust an old handoff value.

Run:

`git branch --show-current`

and:

`git log -1 --oneline`

to determine the authoritative current branch and commit.

Preserve any existing uncommitted work.

---

## Exact Next Action

Inspect the current `RecipeTracking_Inspector.lua` implementation for:

* title-bar hierarchy
* close/X control
* title text/font/layout
* STYLE callback
* transparency/background properties
* mouse/hover bindings
* any UI element producing `Cue Recipe Update Tool`

Determine why the latest real-world result differs from the requested behavior.

Then:

1. make a new relevant source-code change
2. inspect `git diff`
3. run available local validation
4. deploy the changed files
5. verify source/deployment hashes
6. stop for user testing only when the new implementation is actually deployed

Do not stop after describing these steps.

Do not commit merely because deployment succeeded; for visual grandMA3 changes, prefer user validation before committing the final coherent state.