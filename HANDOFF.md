# Project Handoff

## Current objective

Complete Phase 0 research and Phase 1 of the grandMA3 Recipe Update project: deliver a strictly read-only diagnostic plugin for grandMA3 2.3.2.0+ and wait for real-console evidence before any writer work.

## Current status

**Phase 0 complete; Phase 1 partially validated on real grandMA3 2.3.2.0.** Ordinary-Programmer Position preset resolution is now evidence-backed. Original Cue/Part, Group, and Recipe-line resolution remain unresolved. Do not begin Phase 2.

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

## What remains

- Import and run diagnostic version 0.1.1.0 on grandMA3 2.3.2.0 using the Position and Color test cases in `docs/research.md`.
- Repeat on a 2.4.x installation.
- Collect the complete `[RecipeUpdate][DIAG]` and object Dump output and confirm that running the plugin does not mark the show changed.
- Use those results to resolve actual programmer preset-link, original Cue/Part provenance, Cue/Part/Recipe class hierarchy, and Recipe Selection/Values property names.
- Wait for user-provided real-console results before Phase 2.

## Important technical decisions

- Official MA Lighting documentation is the baseline; UI labels are not assumed to be Lua property names.
- `GetProgPhaser` is only release-note evidenced in the researched official material, so calls are capability-detected and protected with `pcall`.
- The diagnostic never mutates selection to reverse-match groups because that would violate its strict read-only/no-show-change contract.
- Recipe candidate scoring stays disabled until feature, group/selection, original source, and old Values reference can all be read reliably.
- Dumps are intentionally verbose in the development diagnostic but traversal and table printing are bounded.
- Phase 1 contains no command execution or Undo creation because it performs no write.

## Known issues or blockers

- No grandMA3 runtime is available in this development environment, so object hierarchy and return shapes cannot be validated locally.
- No confirmed official Lua contract has yet been found for original tracking provenance, Group source, command-history reading, or Recipe Selection/Values internal property names.
- `abs_preset` is confirmed for ordinary Position calls on 2.3.2.0, but Color, relative, multi-feature, and 2.4.x shapes remain unverified.
- Static validation cannot prove runtime compatibility with grandMA3's embedded Lua environment.

## Failed approaches that should not be repeated

- `npm exec --package luaparse -- node -e ...` did not expose the temporary package to Node's `require()` path. Use the working direct CLI command `npx --yes luaparse RecipeUpdate_Diagnostic.lua` instead.
- Do not infer internal Recipe properties from the UI's visible column names.
- Do not treat System Monitor visibility as proof that Lua can read command history.

## Relevant files

- `RecipeUpdate_Diagnostic.lua`: Phase 1 read-only diagnostic plugin.
- `recipe_update_diagnostic.xml`: grandMA3 Plugin descriptor referencing the diagnostic Lua component.
- `C:\ProgramData\MALightingTechnology\gma3_library\datapools\plugins\Update Plugin\RecipeUpdate_Diagnostic.lua`: synchronized local test copy (repository-external).
- `C:\ProgramData\MALightingTechnology\gma3_library\datapools\plugins\Update Plugin\recipe_update_diagnostic.xml`: synchronized local descriptor (repository-external).
- `docs/research.md`: Phase 0 evidence, compatibility matrix, and real-console test procedure.
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
- Local Lua deployment source/destination SHA-256 comparison: passed (`62F4F7FB0EF50BD58155F4ADDC28CC30B09CE4EF85C0EB7D6BB484F63D481F99`).
- XML descriptor parse/reference validation: passed; one referenced Lua component exists.
- XML deployment source/destination SHA-256 comparison: passed (`5C5E92B1BE652E66FA77984D246B407F7ED77CE6D4CC3138F7F1FA271C38BFE3`).
- grandMA3 2.3.2.0 runtime coverage: partial; Position ordinary Programmer passed, remaining cases below are pending.
- grandMA3 2.3.2.0 ordinary Position preset resolution: passed from DumpLog evidence.
- grandMA3 2.4.x runtime comparison: pending user real-console run.

## Current branch

`main`

## Latest relevant commit

Phase 0/1 implementation and real-console refinement will be represented by the current `HEAD`; use `git log -1 --oneline` after commit for its authoritative hash.

## Push status

Complete. The Phase 0/1 implementation was pushed to `origin/main`, and local `main` is synchronized with its upstream branch.

## Recommended next steps

1. Import/reload diagnostic version 0.1.1.0 and run the ordinary Programmer Position test once to verify the new compact summary.
2. Run the ordinary Programmer Color test and provide the new DumpLog path.
3. Repeat the same tests on 2.4.x if available.
4. Review and encode only observed version differences in `Compat`.
5. Do not implement Phase 2 until all five items in the research document's Phase 2 gate are satisfied.
