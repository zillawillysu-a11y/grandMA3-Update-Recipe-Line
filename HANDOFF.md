# Project Handoff

## Current Goal

Keep Recipe source tracking correct while making Pool reference markers clear, responsive, and stable.

## Current Working State

v0.6.13.0 is implemented and deployed. Tracking resolves one latest source across overlapping Groups by Cue, Part, then actual Recipe row order. Compact window height follows estimated visible line count. Pool markers use the thick native `frame0`, remain visible, and pulse between two theme colors every 0.25 seconds; Pool tree traversal remains every 0.5 seconds. Generator-backed Recipes are recognized and recipes disabled through either `Enabled` or `Active` are excluded.

## Latest Real-World User Test

User confirmed v0.6.12.0 fixed the stale Cue 9 source and the thick Pool frame looks good. User requested a faster pulse that never fully disappears and asked whether a dashed frame is possible without risking performance or crashes.

## Verified Facts

- 51 offline Lua workflow assertions passed, including Generator handling, source precedence, automatic text height, and always-visible 0.25-second Pool color pulsing.
- Both Lua runtime files parse; XML parses and all referenced components exist.
- `git diff --check` passed.
- XML and both referenced Lua components were copied to the local grandMA3 plugin directory; repository and deployed SHA256 hashes match.

## Current Problem

Native grandMA3 must confirm the faster always-visible Pool pulse is comfortable and stable.

## Known Failed Attempts

The installed texture set has dotted fill textures but no native dashed frame. Emulating dashes with many temporary UIObjects would increase object count per visible Pool reference, so v0.6.13.0 keeps the proven single-frame implementation.

## Important Files

- RecipeTracking_Inspector.lua
- recipe_update_diagnostic.xml
- RecipeUpdate_Diagnostic.lua
- tests/recipe_workflow.lua
- AGENTS.md

## Current Branch / Commit

qwen at f6328ef. v0.6.1 through v0.6.13 are uncommitted pending coherent real-world confirmation.

## Exact Next Action

Run v0.6.13.0 in grandMA3. Observe the Pool marker for several minutes and confirm it changes color faster without disappearing or affecting console responsiveness.
