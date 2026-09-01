# Project Handoff

## Current objective

Complete Phase 0 research and Phase 1 of the grandMA3 Recipe Update project: deliver a strictly read-only diagnostic plugin for grandMA3 2.3.2.0+ and wait for real-console evidence before any writer work.

## Current status

**Phase 0 implementation complete; Phase 1 awaiting real-console validation.** Research and the read-only diagnostic are implemented and locally validated. Do not begin Phase 2 until the requested grandMA3 2.3.2.0 and 2.4.x diagnostic output has been reviewed.

## What has been completed

- Researched official grandMA3 documentation for the 2.3 target generation.
- Added `docs/research.md` with confirmed APIs, unknowns, compatibility matrix, console test plan, Phase 2 gate, and official source links.
- Added `RecipeUpdate_Diagnostic.lua`, a modular, capability-detected, bounded read-only diagnostic.
- Diagnostic reports version, capabilities, selected sequence/current cue, selected fixtures, UI channels, `GetProgPhaser` probes, Programmer/ProgrammerPart Dumps, and bounded Cue descendant inspection.
- Unverified group, preset-link, provenance, Recipe property, and candidate results are explicitly reported as unresolved. Candidate scoring is intentionally disabled.
- Confirmed by static scan that the Lua file contains no executable calls to `Cmd`, `Store`, `Assign`, `Cook`, `Delete`, `Acquire`, `CreateUndo`, or `CloseUndo`.

## What remains

- Import and run `RecipeUpdate_Diagnostic.lua` on grandMA3 2.3.2.0 using the Position and Color test cases in `docs/research.md`.
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
- `GetProgPhaser` signature/shape and `integrated`/preset-link semantics need actual 2.3.2.0 output.
- Static validation cannot prove runtime compatibility with grandMA3's embedded Lua environment.

## Failed approaches that should not be repeated

- `npm exec --package luaparse -- node -e ...` did not expose the temporary package to Node's `require()` path. Use the working direct CLI command `npx --yes luaparse RecipeUpdate_Diagnostic.lua` instead.
- Do not infer internal Recipe properties from the UI's visible column names.
- Do not treat System Monitor visibility as proof that Lua can read command history.

## Relevant files

- `RecipeUpdate_Diagnostic.lua`: Phase 1 read-only diagnostic plugin.
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
- grandMA3 2.3.2.0 runtime test: pending user real-console run.
- grandMA3 2.4.x runtime comparison: pending user real-console run.

## Current branch

`main`

## Latest relevant commit

Phase 0/1 implementation: `c1f7cde feat: add read-only recipe diagnostics`. The final handoff-status commit is the current `HEAD`; use `git log -1 --oneline` for its authoritative hash.

## Push status

Complete. The Phase 0/1 implementation was pushed to `origin/main`, and local `main` is synchronized with its upstream branch.

## Recommended next steps

1. Follow `docs/research.md` section "Required real-console test" on grandMA3 2.3.2.0.
2. Send back the complete Command Line History output; screenshots alone may omit Dump fields.
3. Repeat the same test on 2.4.x if available.
4. Review and encode only observed version differences in `Compat`.
5. Do not implement Phase 2 until all five items in the research document's Phase 2 gate are satisfied.
