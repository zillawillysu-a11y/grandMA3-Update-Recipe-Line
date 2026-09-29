# Project Handoff

## Current Goal

Native-validate v0.7.1.23: confirm selection changes reuse the active
Sequence resolver pass, and capture the bounded native metadata shape for
Recipe Preset 25.9003.

## Current Working State

v0.7.1.23 is deployed to the confirmed Update Plugin directory. A selection
change now updates the in-flight task's selected-member projection and moves
newly selected, unprocessed members to the next resolver slice. Selection-only
changes no longer clear the Sequence-wide purple reference set. Empty ordinary
Preset metadata remains fail-closed; the UI now shows bounded top-level key
types and child classes for that failure.

## Latest Real-World User Test

The 2026-09-29 v0.7.1.22 Cue 1 image shows Recipe Preset 25.9003 with no purple
frame. The panel reports `ORDINARY_CHANNEL_SUMMARY_UNPROVEN(channels=0,count=0,
lanes=0)`, so it is blocked in semantic parsing before Pool tile discovery.

## Verified Facts

- Lua 5.4: 87 workflow assertions and 193 show-candidate checks pass.
- Synthetic four-reference result remains `final_refs=4 missing=0 extra=0`.
- Deterministic build, Lua parsing, XML/component/version checks, and
  `git diff --check` pass.
- v0.7.1.22 deployed files were backed up at
  `C:\tmp\show-rel-backups\Update-Plugin-before-v0.7.1.23-20260929`.
- v0.7.1.23 deployed/source Lua SHA256:
  `EA116F5AC0F6240AE272FBA12B8642B937AE300EB2518C0110A16BFCCF065DFC`.
- v0.7.1.23 deployed/source XML SHA256:
  `E22016B726DB92012BD62E8C0F8EE27F13B62C8DD349A2E99C7D9F281EE4C54C`.
- Diagnostic component remains unchanged at SHA256
  `A00C30DD8DCEFF67ACE8F86E423E70742AF74F85FBB4FA2E38514E5AF15B2191`.

## Current Problem

The existing native log does not reveal whether 25.9003 has truly empty
`GetPresetData` UI-channel data or another child representation. v0.7.1.23
surfaces a bounded `Metadata shape:` line; no semantic gate was weakened.

## Important Files

- `RecipeTracking_Inspector.lua`
- `tools/templates/show_track_a_runtime.lua`
- `tests/show_candidate.lua`
- `recipe_update_diagnostic.xml`

## Current Branch / Commit

Worktree is detached at the current `origin/qwen` checkpoint with the v0.7.1.23
release changes staged for a coherent commit/push; real-world validation is
pending.

## Exact Next Action

Reload the Update Plugin and confirm the title is v0.7.1.23. Reopen Cue 1 where
Preset 25.9003 is referenced and report the `Metadata shape:` line. Also change
fixture selection while the resolver is pending and verify the selected
member's frames appear without restarting the Sequence pass or clearing the
purple tracked references.
