# Project Handoff

## Current Goal
Prove native linked-Preset Universal/Global versus Selective applicability using the user-prepared grandMA3 2.5.0.3 controls, without resolver integration.

## Current Working State
Rev10.1 observer acquires A/B directly from Preset 25.9014's ValueSource linked handles: it reports handle identity, class, Name, Index, native address, parent chain, ValueSource Preset property type, GetDependencies, and CompareHandle pool validation, then runs the same C/D applicability inspection. No ShowData path resolution, no Cue/Part scan, marker, wait, production or resolver change. Local regressions pass. Native validation is pending.

## Latest Real-World User Test
Rev10 native run was INCONCLUSIVE: A/B acquisition via `ObjectList('ShowData.DataPools...')` failed with `API_ObjectList: Invalid Syntax`, so both cases were UNAVAILABLE. The linked handles themselves were observed (Step 1 `#40000C7D` known Universal/Global, Step 2 `#5400041A2` known Selective). Cases C (1.28) and D (1.14) confirmed Universal natively: PRESETMODE=Universal, preset_store_mode=3, selective=false.

## Verified Facts
XML authoring ground truth is user-supplied. Universal C/D still produced by-fixtures entries, so by-fixtures key presence alone must not prove Selective membership. No native applicability discriminator or typed member reconstruction has yet been proven. IDs are selectors, never classifier inputs.

## Current Problem
Acquire A/B natively from linked handles; determine whether `#5400041A2` is the Preset, a proxy, or another reference representation; determine which native mode/flag fields discriminate Universal/Global from Selective and whether the native view reconstructs Selective members 130-147 while preserving fixture/subfixture/cell identity.

## Known Failed Attempts
Rev6/Rev7 treated linked selective/member applicability as unsafe. ABS-only linked metadata or Preset names must not determine applicability. Rev10 re-resolved A/B from exported ShowData path strings; grandMA3 rejected that syntax natively. Do not re-resolve linked handles from export paths.

## Important Files
- `tools/templates/linked_preset_applicability.lua`
- `diagnostics/linked_preset_applicability_2_5_0_3.xml`
- `tools/run_linked_preset_applicability.py`
- `tests/linked_preset_applicability.lua`

## Current Branch / Commit
`rev6-native`, Rev10.1 acquisition-fix checkpoint. Superseded uncommitted Rev9 raw-REL integration is preserved in a local stash; the older dirty `qwen` worktree is untouched.

## Exact Next Action
Run the updated Linked Preset Applicability Control plugin in grandMA3 2.5.0.3; capture all `[LinkedApplicability]` lines, especially `LINKED_HANDLE`, `LINK_PARENT`, `LINK_DEPENDENCY`, `LINK_RESOLUTION`, `LINK_VALIDATION`, and case B `PRESET_MEMBER_VIEW` against members 130-147. Do not integrate into the resolver before review.

REAL-WORLD VALIDATION PENDING
