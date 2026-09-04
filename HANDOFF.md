# Project Handoff

## Current Goal

Continue development of the grandMA3 Recipe Tracking Inspector on grandMA3 2.3.2.0.

The persistent Inspector UI is real-world verified at plugin version `0.2.3.4`. Version `0.2.3.5` adds consistent visible version labels and awaits visual confirmation.

Phase 2 Recipe writer work has not started yet; it awaits user approval.

---

## Current Working State

Primary implementation:

* `RecipeTracking_Inspector.lua`
* `recipe_update_diagnostic.xml` (plugin version `0.2.3.4`)

Legacy/read-only research implementation:

* `RecipeUpdate_Diagnostic.lua`

The persistent Inspector uses a non-modal native-style grandMA3 UI hierarchy and is deployed for real onPC testing. Version `0.2.3.5` is shown in the imported Plugin name, Inspector title/content, and Diagnostic startup output.

Repository state and actual source files are authoritative.

Always run:

* `git status --short --branch`
* `git log -5 --oneline`

before continuing.

---

## Latest Real-World User Test

Version `0.2.3.4` is confirmed PASS on real grandMA3 2.3.2.0 (user report, after the v0.2.3.2/v0.2.3.3 failures). All requirements of that round are met:

1. Close `X` is visually integrated into the title bar: proven `CloseButton` element with `corner2` texture at the right edge, full 36 px bar height.
2. X height matches the title bar height (36 px).
3. Title font is larger (`Medium20`) and the full title text renders because the `TitleButton` is forced to an explicit 484x36 size (PANEL_WIDTH - 36).
4. Transparency no longer depends on mouse hover (`HasHover = "No"` on window, title bar, and panel).
5. No centered `Cue Recipe Update Tool` text (`window.Text` assignment removed; only `window.Title` remains for the native title bar).
6. `STYLE` now changes the actual window/panel background, not only button text (`window.BackColor` and `panel.BackColor` are set to the resolved `Root().ColorTheme.ColorGroups.Global` color object with `Global.*` string fallback).

The coherent change is committed and pushed to the `qwen` branch.

---

## Verified Facts

* The persistent Inspector can run as a non-modal grandMA3 UI.
* Native title-bar dragging has worked in real grandMA3 2.3.2.0 testing.
* The proven title-bar geometry is a single-cell `TitleBar` (`Columns = 1`, children anchored `0,0,0,0`) with explicit `W/H/MinSize/MaxSize`: `TitleButton` at 484x36 left-aligned, `CloseButton` at 36x36 with `AlignmentH = "Right"`. `TitleButton` does not stretch to fill its cell, so explicit sizing is required.
* `HasHover` is a real grandMA3 element property and suppresses hover-state rendering on the elements it is set on.
* The `CloseButton` element type is the proven close control (used with `corner2` texture since v0.2.2).
* `Global.Transparent75/50/Background` back-color cycling changes the visible window/panel style on real 2.3.2.0 (user-confirmed with v0.2.3.4).
* Read-only Recipe/source resolution research is substantially validated for the current Phase 0/1 scope.
* Local deployment path is:

`C:\ProgramData\MALightingTechnology\gma3_library\datapools\plugins\Update Plugin`

* Deployment must include XML plus referenced Lua components.
* Repository/deployment SHA256 equality verifies file identity only; it does not verify UI correctness.
* No Phase 2 writer implementation has begun.

---

## Current Problem

None outstanding. The inspector UI is at a user-confirmed good state.

---

## Known Failed Attempts (do not repeat without new evidence)

* v0.2.3.2: single-cell layout with a 28x28 default-textured close `Button` - X looked like a separate inset button, X height did not match the bar, title truncated, transparency stayed hover-dependent, and `window.Text` rendered the title centered in the window.
* v0.2.3.3: two-column title-bar grid (`title.Columns = 2`) with the close anchored to column 2 and `AlignmentH = "Center"` - the X left the right edge and rendered toward the middle; the title stayed truncated; two unguarded property assignments (`titleButton.Font`, `close.Texture`) risked hard errors during panel creation.

The fix that worked (v0.2.3.4): proven 0.2.3.2 placement (single cell, `AlignmentH = "Right"`, explicit sizes), explicit full-width `TitleButton` sizing, proven `CloseButton` element type, and capability-guarded element-specific properties.

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

The real-world-verified v0.2.3.4 state is committed and pushed to `qwen`.

Next:

1. If the user approves starting Phase 2, begin the Recipe writer research/planning (separate from the read-only inspector).
2. If further UI feedback arrives, follow the standard workflow: inspect the new observation, produce a relevant source diff, local validation, deploy, SHA256 verification, user real-world test, then commit the coherent confirmed state.
