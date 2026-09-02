# Project Handoff

## Current objective

Complete Phase 0 research and Phase 1 of the grandMA3 Recipe Update project: deliver a strictly read-only diagnostic plugin for grandMA3 2.3.2.0+ and wait for real-console evidence before any writer work.

## Current status

**Phase 0 complete; Phase 1 substantially validated on real grandMA3 2.3.2.0.** Both Edit Recipe and ordinary Programmer are required supported workflows. Position/Color preset resolution plus Cue/Part/Recipe hierarchy and Recipe property reads are evidence-backed. Ordinary-mode original Cue/Part provenance, Group matching, and exact isolated Recipe Values addressing remain unresolved. Do not begin Phase 2 writer work.

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

## What remains

- Repeat on a 2.4.x installation.
- Use controlled tracking tests to resolve original Cue/Part provenance and an unambiguous Group strategy.
- Establish exact isolated addressing for one Recipe Values cell without relying on display text.
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
- No confirmed official Lua contract has yet been found for original tracking provenance, Group source, command-history reading, or Recipe Selection/Values internal property names.
- `abs_preset` is confirmed for ordinary Position and Color calls on 2.3.2.0, but pure-relative, multi-feature, and 2.4.x shapes remain unverified.
- `GetProgPhaserValue`, UIChannel round-trip, and ChannelFunction results vary by phaser/attribute shape and are not universal writer contracts.
- Static validation cannot prove runtime compatibility with grandMA3's embedded Lua environment.

## Failed approaches that should not be repeated

- `npm exec --package luaparse -- node -e ...` did not expose the temporary package to Node's `require()` path. Use the working direct CLI command `npx --yes luaparse RecipeUpdate_Diagnostic.lua` instead.
- Do not infer internal Recipe properties from the UI's visible column names.
- Do not treat System Monitor visibility as proof that Lua can read command history.
- Do not reject Edit Recipe mode: ProgrammerPart Recipe children are direct target candidates. Keep its target-resolution path separate from ordinary tracked-cue mode.

## Relevant files

- `RecipeUpdate_Diagnostic.lua`: Phase 1 read-only diagnostic plugin.
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
- Local Lua deployment source/destination SHA-256 comparison: passed for diagnostic 0.1.4.0 (`86B781F70B48CC0467E0EAA1D6D802D4D9FA04C5661206E5BA382548CA687EF1`).
- XML descriptor parse/reference validation: passed; one referenced Lua component exists.
- XML deployment source/destination SHA-256 comparison: passed for descriptor 0.1.4.0 (`9DDC76FD01199302C606E7387192D04417742EEC83DB1285C8E40F634991CFB3`).
- grandMA3 2.3.2.0 runtime coverage: partial; Position ordinary Programmer passed, remaining cases below are pending.
- grandMA3 2.3.2.0 ordinary Position preset resolution: passed from DumpLog evidence.
- grandMA3 2.3.2.0 diagnostic 0.1.1.0 compact Position summary: passed for Position 2.7 `Full` and Position 2.5 `<<<>>>`.
- Diagnostic 0.1.2.0 new read-only API probes: locally syntax/static validated and exercised on real 2.3.2.0.
- Diagnostic 0.1.2.0 Position and Color probes on 2.3.2.0: passed; no runtime errors. UIChannel/ChannelFunction results are shape-dependent and remain unsuitable as universal writer assumptions.
- Diagnostic 0.1.3.0 ProgrammerPart Recipe-child traversal: Lua syntax/static safety/XML validation passed and local deployment hashes matched; real-console output pending.
- Diagnostic 0.1.4.0 dual-workflow classification: Lua syntax/static safety/XML validation passed and local deployment hashes matched; real-console output pending.
- grandMA3 2.4.x runtime comparison: pending user real-console run.

## Current branch

`main`

## Latest relevant commit

Phase 0/1 implementation and API-reference probe update will be represented by the current `HEAD`; use `git log -1 --oneline` after commit for its authoritative hash.

## Push status

Complete. The Phase 0/1 implementation was pushed to `origin/main`, and local `main` is synchronized with its upstream branch.

## Recommended next steps

1. Run diagnostic 0.1.4.0 once with Edit Recipe open to capture the direct ProgrammerPart Recipe child properties.
2. Exit Edit Recipe, clear the Programmer, then rerun the controlled Cue 3 tracking case to capture the ordinary tracked-target path.
3. Repeat the same Position and Color tests on 2.4.x if available.
4. Use the controlled tracked-cue result to investigate original Cue/Part provenance and Group matching.
5. Do not implement Phase 2 until all five items in the research document's Phase 2 gate are satisfied for both workflows.
