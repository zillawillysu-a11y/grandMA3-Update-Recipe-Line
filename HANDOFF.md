# Project Handoff

## Current objective

Complete Phase 0/1 read-only resolution and prototype a persistent, non-blocking Recipe Tracking Inspector for grandMA3 2.3.2.0+.

## Current status

**Persistent Inspector prototype 0.2.0.0 implemented and locally deployed; real-console UI validation is pending.** Phase 0 is complete and Phase 1 resolution is substantially validated on real grandMA3 2.3.2.0. Do not begin Phase 2 writer work.

## What has been completed

- Researched official grandMA3 documentation for the 2.3 target generation.
- Added `docs/research.md` with confirmed APIs, unknowns, compatibility matrix, console test plan, Phase 2 gate, and official source links.
- Added `RecipeUpdate_Diagnostic.lua`, a modular, capability-detected, bounded read-only diagnostic.
- Diagnostic reports version, capabilities, selected sequence/current cue, selected fixtures, UI channels, `GetProgPhaser` probes, Programmer/ProgrammerPart Dumps, and bounded Cue descendant inspection.
- Unverified group, preset-link, provenance, Recipe property, and candidate results are explicitly reported as unresolved. Candidate scoring is intentionally disabled.
- Confirmed by static scan that the Lua file contains no executable calls to `Cmd`, `Store`, `Assign`, `Cook`, `Delete`, `Acquire`, `CreateUndo`, or `CloseUndo`.
- Added the required local grandMA3 Plugin deployment path to `AGENTS.md`.
- Synchronized `RecipeUpdate_Diagnostic.lua` to `C:\ProgramData\MALightingTechnology\gma3_library\datapools\plugins\Update Plugin` for real-console/onPC testing.
- Added `recipe_update_diagnostic.xml`, modeled on an installed 2.3.2 Plugin descriptor, and updated deployment rules to require XML plus referenced Lua components.
- Analyzed real 2.3.2.0 DumpLogs for both Edit Recipe and ordinary Programmer tests.
- Confirmed `GetProgPhaser()` returns an `abs_preset` handle and reliably followed Position preset 2.5 then 2.4 across 28 selected fixtures.
- Confirmed ordinary Programmer has zero ProgPart Recipe children while the Edit Recipe test had two, providing a read-only mode safety check.
- Updated the diagnostic to summarize a unique preset/feature, reject ambiguous/raw phasers, detect Recipe content in ProgrammerPart, and avoid thousands of repetitive per-fixture lines.
- Verified diagnostic 0.1.1.0 on 2.3.2.0 with ordinary Programmer Position 2.7 and 2.5 calls; both compact summaries resolved the correct unique preset with high confidence and no runtime error.
- Added `docs/api-reference-comparison.md`, comparing the requested read-only patopesto v2.2 HelpLua/API dump against official research and observed 2.3.2.0 behavior.
- Added capability-guarded, bounded read-only probes for `GetProgPhaserValue`, `GetPresetData`, Attribute/UIChannel identity, and ChannelFunction identity. `SetProgPhaser*` remains capability-report-only and is never invoked.
- Recreated the missing local deployment directory on 2026-09-02 and resynchronized diagnostic 0.1.2.0 after validating the XML component reference.
- Analyzed 2026-09-02 2.3.2.0 Position and Color DumpLogs. Both resolved exactly one absolute preset with high confidence and no runtime error; Color resolved `Color Index` ChannelFunction/index 67.
- Confirmed on 2.3.2.0 that the current object tree exposes `Cue -> Part -> Recipe` and readable Recipe properties `Selection=Group 401` and `Values=Preset 1.1`.
- Analyzed the 2026-09-02 14:11 DumpLog: Sequence 8 Cue 3 was current, ProgrammerPart contained one Recipe, and phasers had `mask_cooked=255`, identifying Edit Recipe mode. No provenance field appeared in the parent ProgPart Dump.
- Updated diagnostic 0.1.3.0 to traverse and Dump ProgrammerPart Recipe children, so a subsequent Recipe-content run captures their properties instead of only listing the child name.
- Recorded the product requirement that the final Plugin work both with and without Edit Recipe. Diagnostic 0.1.4.0 now treats both as supported workflows: direct ProgrammerPart Recipe candidates in Edit Recipe mode, tracked-target resolution in normal mode.
- Verified diagnostic 0.1.4.0 in Edit Recipe mode on 2.3.2.0. It found the direct Programmer Recipe at `...Programmer.Part Zero.Recipe 1` and read `INDEX=1`, `SELECTION=Group 9`, `PRESET=Position 2.4`, `VALUES=FeatureGroup 2 Position.Preset 4`, `TYPE=Preset`, `PRESETMODE=Selective`, and `ENABLED=Yes`. The full Dump contained no Cue/Part/source/origin mapping property.
- Verified diagnostic 0.1.4.0 ordinary mode on Sequence 8 Cue 3: ProgrammerPart had zero Recipe children, Position 2.8 `Full` resolved across 40 Pan/Tilt phasers, and no direct provenance or Group field appeared. Cue 3 Part 0 exposed `Selection` as an unexpanded Lua table.
- Updated diagnostic 0.1.5.0 to print raw Selection tables and inspect a bounded 24-object Group-pool sample without mutating the selection.
- Diagnostic 0.1.5.0 confirmed Group `Selection[*].sf_index` supports read-only set comparison. Do not infer counts from its bounded text output: the 80-field printer truncated Group 9, which the user confirmed actually contains all 20 fixtures. Diagnostic 0.1.6.0 compares the complete live Lua tables instead.
- Updated diagnostic 0.1.6.0 to scan up to 2048 Groups compactly and accept only one unique exact `sf_index` set match; zero or multiple matches remain unresolved/ambiguous.
- Diagnostic 0.1.6.0 scanned 63 Groups and correctly reported three identical 20-fixture set candidates: Group 2 `S TOP ALL`, Group 9 `SPOT TOP GRID`, and Group 261 `S TOP SNAKE`.
- Updated diagnostic 0.1.7.0 to capture X/Y/Z from `SelectionFirst/Next` and compare translation-normalized grid fingerprints after exact fixture-set matching, allowing groups with identical members but different layouts/orders to be distinguished read-only.
- Updated diagnostic 0.1.8.0 with a bounded ordinary-mode provenance candidate scan across the selected Sequence's Cue/Part/Recipe hierarchy. It lists only Recipes whose Selection Group exactly matches the current fixture set and whose Values match the Programmer feature; a unique result is labeled `INFERRED HIGH`, not native provenance proof.
- Verified 0.1.8.0 on 2.3.2.0: grid fingerprint uniquely resolved Group 9; scanning five Cues/two Recipes uniquely inferred Sequence 8 Cue 1 Part 0 Recipe 1, Group 9, old Position 2.4 as the source for Cue 3's selected Position data.
- Updated diagnostic 0.1.9.0 to show the inferred Current/Source/Group/Old/New chain in a read-only MessageBox and to report the unique candidate in the final Recipe summary instead of the stale `UNRESOLVED` line.
- User visually verified the 0.1.9.0 MessageBox. Source resolution was correct, but generic object labels exposed `function: 000...` pointers for Part/Recipe and made the source line too long. Diagnostic 0.1.10.0 adds clean Cue/Part/Recipe display helpers and one field per line.
- User visually checked 0.1.10.0: line layout was fixed, but Cue numbers rendered as `3.0/1.0` and Recipe `Index` collided with an object method. Diagnostic 0.1.11.0 uses `%g` Cue formatting and uppercase Dump properties `PART`/`INDEX` with function-pointer rejection.
- User visually verified the final 0.1.11.0 MessageBox on 2.3.2.0: Current Cue 3, Source Cue 1, Part 0, Recipe 1, Group 9, old Position 2.4, new Position 2.8, confidence, and read-only status all render correctly and legibly.
- Tested one selected fixture (patch index 79) from the 20-fixture Group 9 in ordinary mode. Exact-set Group and Recipe matching correctly returned zero. Diagnostic 0.1.12.0 changes provenance matching to Recipe-first subset containment plus feature matching, and displays fixture coverage such as `1 selected / 20 in Group`.
- Final UI requirement: replace modal run-on-demand MessageBox UX with a non-blocking persistent `Recipe Tracking Inspector` that refreshes when fixture selection, Attribute/Feature, Programmer preset, current Cue, or Edit Recipe mode changes. It needs explicit Start/Stop, hook cleanup, duplicate-instance prevention, and ambiguous/no-source states. The documented `HookObjectChange` API is the preferred event mechanism; docked/custom UI creation remains a version-sensitive prototype area.
- Added `RecipeTracking_Inspector.lua` as a separate component. It creates a bounded overlay panel on the focused display, refreshes every 0.25 seconds, updates text only when content changes, supports ordinary Programmer and Edit Recipe, shows selection/Attribute/current Cue/source Cue/Part/Recipe/Group/coverage/old/new/confidence, and renders unresolved or ambiguous states.
- Inspector lifecycle is explicit: the STOP button sets a state flag, rerunning the component toggles an existing instance off, a global state prevents duplicate active instances, and cleanup deletes only the two UI handles created by the Inspector. No Show data is written.
- Updated the XML descriptor to 0.2.0.0 with separate diagnostic and Inspector components.
- After the first UI test launched the legacy diagnostic MessageBox from component 1, reordered descriptor 0.2.0.1 so `recipe_tracking_inspector` is the first/default component and renamed the Plugin `Recipe Tracking Inspector`; the legacy diagnostic remains component 2.
- First live Inspector test showed that selection refresh worked (`Selection: 1 fixture`) but feature matching failed: the panel showed `PanTilt` and no Recipe while the Programmer preset was Position 2.8 Full. Inspector 0.2.0.2 now resolves object addresses using the diagnostic's proven `AddrNative` -> `Addr` -> `ToAddr` order, preserving `PresetPools.Position` instead of a collapsed display address and allowing the existing one-of-20 subset match.
- User requested a draggable panel. Version 0.2.0.3 emits one bounded Dump of the created panel on startup so the real 2.3.2 UI object's supported gesture/signal properties can be identified; remove this temporary probe after native dragging is implemented.
- The 0.2.0.3 real-console panel Dump confirmed native `TOUCHSTART`, `TOUCHUPDATE`, and `TOUCHEND` signals with pointer X/Y arguments. Version 0.2.1.0 wires these signals to bounded panel movement, keeps STOP aligned with the panel, and removes the temporary Dump probe.
- Version 0.2.1.0 no longer requires a Programmer preset to resolve tracking. Selecting fixtures plus an Attribute scans matching Recipe sources and displays `New Preset: No Programmer value` when appropriate. It normalizes the observed `PanTilt` UI feature to Recipe feature group `Position`.
- Live 0.2.1.0 validation passed selection, Attribute-only source resolution, and no-Programmer-value behavior, but onPC mouse dragging did not start. Version 0.2.1.1 additionally binds the confirmed `MOUSEDOWN`/`MOUSEUP` signals, enables hover interaction, and clears the panel Button's default click action while retaining touch bindings.

## What remains

- Repeat on a 2.4.x installation.
- Validate the persistent Inspector's position, dimensions, STOP callback, refresh behavior, and cleanup on real grandMA3 2.3.2.0.
- Use controlled tracking tests to resolve original Cue/Part provenance and an unambiguous Group strategy.
- Establish and undo-test exact isolated assignment behavior for the direct Edit Recipe `Values` property and for an ordinary Cue Recipe `Values` property without relying on display text.
- Wait for user-provided real-console results before Phase 2.

## Important technical decisions

- Official MA Lighting documentation is the baseline; UI labels are not assumed to be Lua property names.
- `GetProgPhaser` is only release-note evidenced in the researched official material, so calls are capability-detected and protected with `pcall`.
- The diagnostic never mutates selection to reverse-match groups because that would violate its strict read-only/no-show-change contract.
- Recipe candidate scoring stays disabled until feature, group/selection, original source, and old Values reference can all be read reliably.
- Dumps are intentionally verbose in the development diagnostic but traversal and table printing are bounded.
- Phase 1 contains no command execution or Undo creation because it performs no write.
- Reference confidence order is real test, official MA docs/HelpLua, requested versioned repository dump, forum evidence, then explicit inference.
- The v2.2 dump's second `GetProgPhaser` argument is tried first; the verified one-argument 2.3.2.0 form is retained as fallback.

## Known issues or blockers

- No grandMA3 runtime is available in this development environment, so object hierarchy and return shapes cannot be validated locally.
- `ModalOverlay` button creation is evidenced by installed 2.3.2 system plugins, but this custom panel and callback must still be exercised on the user's console/onPC. Polling is used because no single verified hook target covers fixture selection, Attribute, Programmer, Cue, and Edit Recipe changes.
- No confirmed official Lua contract has yet been found for original tracking provenance, Group source, command-history reading, or Recipe Selection/Values internal property names.
- `abs_preset` is confirmed for ordinary Position and Color calls on 2.3.2.0, but pure-relative, multi-feature, and 2.4.x shapes remain unverified.
- `GetProgPhaserValue`, UIChannel round-trip, and ChannelFunction results vary by phaser/attribute shape and are not universal writer contracts.
- Static validation cannot prove runtime compatibility with grandMA3's embedded Lua environment.

## Failed approaches that should not be repeated

- `npm exec --package luaparse -- node -e ...` did not expose the temporary package to Node's `require()` path. Use the working direct CLI command `npx --yes luaparse RecipeUpdate_Diagnostic.lua` instead.
- Do not infer internal Recipe properties from the UI's visible column names.
- Do not treat System Monitor visibility as proof that Lua can read command history.
- Do not reject Edit Recipe mode: ProgrammerPart Recipe children are direct target candidates. Keep its target-resolution path separate from ordinary tracked-cue mode.
- Do not reconstruct Group membership counts from bounded `printTable` output; it truncates by fields, not fixtures. Compare the complete live `Selection` tables.

## Relevant files

- `RecipeUpdate_Diagnostic.lua`: Phase 1 read-only diagnostic plugin.
- `RecipeTracking_Inspector.lua`: persistent read-only tracking panel prototype.
- `recipe_update_diagnostic.xml`: grandMA3 Plugin descriptor referencing the diagnostic Lua component.
- `C:\ProgramData\MALightingTechnology\gma3_library\datapools\plugins\Update Plugin\RecipeUpdate_Diagnostic.lua`: synchronized local test copy (repository-external).
- `C:\ProgramData\MALightingTechnology\gma3_library\datapools\plugins\Update Plugin\recipe_update_diagnostic.xml`: synchronized local descriptor (repository-external).
- `docs/research.md`: Phase 0 evidence, compatibility matrix, and real-console test procedure.
- `docs/api-reference-comparison.md`: secondary v2.2 API dump comparison and seven-question analysis.
- `2.3.2.0_26-09-02T14.01.txt`: complete 2026-09-02 Position and Color real-console DumpLog evidence (matches the system_monitor source SHA-256).
- `AGENTS.md`: repository-wide agent instructions.
- `HANDOFF.md`: current continuation record.

## Commands used

- `git status --short --branch`
- `git log -5 --oneline --decorate`
- `git diff --check`
- `rg -n --glob '*.lua' '(?i)(^|[^A-Za-z])(Cmd|Store|Assign|Cook|Delete|Acquire|CreateUndo|CloseUndo)\s*\('`
- `npx --yes luaparse RecipeUpdate_Diagnostic.lua`

## Test/build/validation status

- Lua 5.3 syntax parse with `luaparse`: passed.
- Forbidden write/command call static scan: passed (no matches).
- `git diff --check`: passed.
- Documentation/manual code review: passed.
- Local Lua deployment source/destination SHA-256 comparison: passed for diagnostic 0.1.12.0 (`F9167D6F271145D045BA848768C0F5A747F7AA46676E61FC9C82C170D8E8C157`).
- Inspector deployment source/destination SHA-256 comparison: passed (`7345FD4937BB4682376F41CD01F7098FA346B0F32A53411FDD8E3877B15EE0E0`).
- XML descriptor parse/reference validation: passed; both referenced Lua components exist.
- XML deployment source/destination SHA-256 comparison: passed for descriptor 0.1.12.0 (`EB56A3DF9778DF685FD9625BB2775EBF7709ADBA98B51FDAFA401262B2A730EE`).
- XML 0.2.0.0 deployment source/destination SHA-256 comparison: passed (`ED17916893272BC03E7F03FA6241C3865DED0542FA3724597C3BB42BC13EAA00`).
- grandMA3 2.3.2.0 runtime coverage: partial; Position ordinary Programmer passed, remaining cases below are pending.
- grandMA3 2.3.2.0 ordinary Position preset resolution: passed from DumpLog evidence.
- grandMA3 2.3.2.0 diagnostic 0.1.1.0 compact Position summary: passed for Position 2.7 `Full` and Position 2.5 `<<<>>>`.
- Diagnostic 0.1.2.0 new read-only API probes: locally syntax/static validated and exercised on real 2.3.2.0.
- Diagnostic 0.1.2.0 Position and Color probes on 2.3.2.0: passed; no runtime errors. UIChannel/ChannelFunction results are shape-dependent and remain unsuitable as universal writer assumptions.
- Diagnostic 0.1.3.0 ProgrammerPart Recipe-child traversal: Lua syntax/static safety/XML validation passed and local deployment hashes matched; real-console output pending.
- Diagnostic 0.1.4.0 dual-workflow classification: Lua syntax/static safety/XML validation and Edit Recipe real-console validation passed; ordinary tracked-target run remains pending.
- Diagnostic 0.1.4.0 Edit Recipe classification and direct Recipe-child inspection on 2.3.2.0: passed; exact address and Recipe fields captured with no runtime error.
- Diagnostic 0.1.5.0 Selection-table and bounded Group-pool probes: Lua syntax/static safety/XML validation passed and local deployment hashes matched; real-console output pending.
- Diagnostic 0.1.6.0 compact exact Group matcher: Lua syntax/static safety/XML and real-console validation passed; correctly preserved ambiguity across three identical fixture sets.
- Diagnostic 0.1.7.0 normalized grid-fingerprint matcher: Lua syntax/static safety/XML validation passed and local deployment hashes matched; real-console output pending.
- Diagnostic 0.1.8.0 bounded tracking provenance candidate scan: Lua syntax/static safety/XML and real-console validation passed; one expected source Recipe was inferred.
- Diagnostic 0.1.9.0 visual tracking summary: Lua syntax/static safety/XML and real-console MessageBox validation passed; label/layout cleanup followed in 0.1.10.0.
- Diagnostic 0.1.10.0 cleaned visual labels/layout: Lua syntax/static safety/XML and real-console visual validation passed; numeric/property label cleanup followed in 0.1.11.0.
- Diagnostic 0.1.11.0 numeric/property label cleanup: Lua syntax/static safety/XML, deployment hash, and real-console visual validation passed.
- Diagnostic 0.1.12.0 Recipe-first subset provenance matching: Lua syntax/static safety/XML validation passed and local deployment hashes matched; real-console single-fixture result pending.
- Inspector 0.2.0.0 Lua syntax, `git diff --check`, XML reference, read-only command scan, and local deployment hash validation passed; real-console UI/lifecycle validation pending.
- grandMA3 2.4.x runtime comparison: pending user real-console run.

## Current branch

`main`

## Latest relevant commit

Phase 0/1 implementation and API-reference probe update will be represented by the current `HEAD`; use `git log -1 --oneline` after commit for its authoritative hash.

## Push status

Complete. The Phase 0/1 implementation was pushed to `origin/main`, and local `main` is synchronized with its upstream branch.

## Recommended next steps

1. Import/reload Plugin 0.2.0.0, run component `recipe_tracking_inspector`, and visually verify that the right-side panel does not block normal operation.
2. Select different fixture subsets and Position/Color presets; confirm immediate source/Group changes and capture any System Monitor error.
3. Press STOP, then rerun twice to verify cleanup and duplicate-instance prevention.
4. Repeat on 2.4.x if available. Do not implement the production writer until all Phase 2 gates are satisfied.
