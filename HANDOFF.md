# Project Handoff

## Current Goal
Prove native linked-Preset Universal/Global versus Selective applicability using the user-prepared grandMA3 2.5.0.3 controls, without resolver integration.

## Current Working State
An independent read-only observer inspects Preset 25.9014's two linked ValueSources and four designated linked Presets. It records native Preset properties, `GetPresetData` UI-channel and by-fixtures views, mode/flag/mask/attribute/member fields, and bounded step data. No Cue/Part scan, marker, wait, production or resolver change. Native validation is pending.

## Latest Real-World User Test
Rev8.1 established stable `ValueRelative` empty versus numeric zero on controlled PhaserRecipeValueSources. The new control Preset 25.9014 links Universal/Global Dimmer.100 in Step 1 and Selective Dimmer.23 in Step 2; XML reports stored selective members 130–147. Linked Presets 1.28 and 1.14 are XML-verified Universal controls for remaining Cue 8 cases.

## Verified Facts
XML authoring ground truth is user-supplied. No native applicability discriminator or typed member reconstruction has yet been proven. IDs are selectors, never classifier inputs.

## Current Problem
Determine which native mode/flag fields correlate with XML and whether the by-fixtures/native view reconstructs selective members while preserving fixture/subfixture/cell identity.

## Known Failed Attempts
Rev6/Rev7 treated linked selective/member applicability as unsafe. ABS-only linked metadata or Preset names must not determine applicability.

## Important Files
- `tools/templates/linked_preset_applicability.lua`
- `diagnostics/linked_preset_applicability_2_5_0_3.xml`
- `tools/run_linked_preset_applicability.py`
- `tests/linked_preset_applicability.lua`

## Current Branch / Commit
`rev6-native`, independent applicability checkpoint. Superseded uncommitted Rev9 raw-REL integration is preserved in a local stash; the older dirty `qwen` worktree is untouched.

## Exact Next Action
Run the independent Linked Preset Applicability Control plugin in grandMA3 2.5.0.3; capture all `[LinkedApplicability]` lines. Compare cases A/B/C/D against XML, especially `PRESET_MEMBER_VIEW`, and do not integrate into the resolver before review.

REAL-WORLD VALIDATION PENDING
