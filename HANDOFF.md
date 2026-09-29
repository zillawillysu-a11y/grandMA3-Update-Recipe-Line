# Project Handoff

## Current Goal

Native-test v0.7.1.11 for <=100 ms Cue-to-reference feedback and correct marker semantics.

## Current Working State

v0.7.1.11 is deployed to the confirmed Update Plugin directory. Resolver now processes the current Recipe/member set in one refresh instead of one member per polling cycle. Stable member UI-channel lists and UI-index-to-FeatureGroup mappings are cached. Group tiles keep the existing green/gold pulse. Final surviving references from Cue 1 Tracking through the current Cue use a steady native Phaser-purple frame. No Track A semantic gate was weakened.

## Latest Real-World User Test

Video `2026-09-29 13-08-43.mp4`: full selection of 210 fixtures stayed pending at 209/210; Preset/Phaser/Generator frames were not visible. User clarified that purple means Cue 1 Tracking references still surviving at the current Cue; only the currently matched Group frame pulses.

## Verified Facts

- Offline Lua 5.4: 87 workflow assertions and 128 show-candidate checks passed.
- Synthetic four-reference case remains 4 refs, missing=0, extra=0.
- Lua parse, deterministic build check, XML validation, and `git diff --check` passed.
- Deployed v0.7.1.11 SHA256: Inspector `E1C502E290538CE946275DE1CA62DE5AB823B2DA3A81B416B1CCB4FEDBEC6F1C`; Diagnostic `A00C30DD8DCEFF67ACE8F86E423E70742AF74F85FBB4FA2E38514E5AF15B2191`; XML `A938BB9AEF639F5DBF1B1A90B497538558C8730AD15ACF95AF18B20DB5CBDE42`. Source/deployed hashes match.
- Previous v0.7.1.10 deployment backed up at `C:\tmp\show-rel-backups\Update-Plugin-before-v0.7.1.11-20260929`.

## Current Problem

The 100 ms native response target is not yet verified. Synchronous full resolution removes the many-poll delay but may exceed 100 ms on a cold 210-member selection. Confirm native resolver timing and whether surviving Preset/Phaser/Generator tiles receive steady purple frames.

## Important Files

- `RecipeTracking_Inspector.lua`
- `tools/templates/show_track_a_runtime.lua`
- `tests/show_candidate.lua`
- `recipe_update_diagnostic.xml`

## Current Branch / Commit

`qwen`; v0.7.1.11 work is the current uncommitted candidate pending native validation.

## Exact Next Action

Reload v0.7.1.11 in grandMA3 2.5.0.3. Select all 210 Group 231 fixtures once, expand Timing, and report selection-to-purple time plus `resolver_slice_ms`/`resolver_total_ms`. Confirm the Group frame pulses and the Cue 1-to-current surviving reference frames stay purple and do not pulse.
