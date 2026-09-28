# Project Handoff

## Current Goal

Validate the deployed v0.7.1.0 Track A show candidate in grandMA3 2.5.0.3: Cue 8 final references and Fixture/SubFixture/Cell plus multi-Group marker behavior.

## Current Working State

The `C:\tmp\show-rel` worktree contains the v0.7.1.0 candidate. The compact Track A runtime now keeps unsafe historical rows as member + FeatureGroup + layer barriers, runs reverse resolution, and attributes fully superseded versus final surviving/unknown unsafe rows. Only proven fully superseded rows are omitted; unresolved rows fail closed. Ordinary, Global/Universal, Selective, Phaser ABS/REL, linked metadata, and Generator gates remain in the runtime. The live Track A switch is `true`; the old Cue Phaser scanner switch remains `false`. Existing Group/member matching and Pool marker appearance are unchanged.

## Latest Real-World User Test

The native Track A checkpoint passed: member identity, Global ordinary, Selective, and Preset 25.9008 known ABS are proven; 9008 unknown REL is safe noncontributing. Four final references match the oracle with no missing or extra references. The current production candidate has not been tested in grandMA3.

## Verified Facts

- Native identity is strict ToAddr(handle) -> Fixture <numeric dotted key>, with unique ObjectList(ToAddr()) round-trip. Parent and child remain distinct.
- The candidate's Group matcher admits every complete contained Stored Group and rejects partial Groups.
- Offline tests passed: 86 legacy workflow assertions plus 76 enabled show candidate checks. The synthetic four-reference fixture includes superseded unsafe history and reports missing=0, extra=0, remaining semantic blockers=0. Lua parser, deterministic build, XML validation, and `git diff --check` passed.
- Candidate tests exercise Group, Preset, Phaser, and Generator marker sources, multiple complete Groups, parent/child distinction, override, Recipe deletion cache invalidation, no cooked-history scan, and steady metadata caching.
- Existing marker colors, frame texture, Recall View hidden-grid handling, and bounded discovery were not changed.
- v0.7.1.0 was deployed to the user-confirmed active `Update Plugin` folder. Source/deployed SHA256: Inspector `6027673DF01738C260D080ED7ADB7AD423467B09B81C42DDCACAF916FF8314EF`, Diagnostic `A00C30DD8DCEFF67ACE8F86E423E70742AF74F85FBB4FA2E38514E5AF15B2191`, XML `17326FA1DE0070CEA86EE5A71D7781A5C4E257D480D16690CB68A31DD88A13B0`. Backup: `C:\tmp\show-rel-backups\Update-Plugin-before-v0.7.1.0-20260928-232532`.

## Current Problem

Native validation of the production candidate is pending. Offline synthetic tests cannot prove the actual Cue 8 showfile reference set or visual marker placement. Do not claim show-ready until the user's grandMA3 test passes.

## Known Failed Attempts

Muse's initial candidate only resolved the Programmer-selected Feature. This was exposed by a new two-Feature test and corrected. Parsed ToAddr text alone was accepted without the native unique-handle round-trip; this was corrected. The resolver cache also ignored Recipe deletion; the candidate now includes current Recipe/source context in its key.

## Important Files

- RecipeTracking_Inspector.lua
- recipe_update_diagnostic.xml
- tests/show_candidate.lua
- tests/recipe_workflow.lua
- tools/run_workflow.py
- tools/templates/cue_wide_recipe_reverse_engine.lua
- tools/templates/show_track_a_runtime.lua
- tools/build_show_candidate.py

## Current Branch / Commit

Detached `C:\tmp\show-rel` worktree based on `origin/qwen`; see Git for the new checkpoint after commit/push. Before deployment the confirmed old XML was v0.2.5.4; old Inspector SHA256 `489588FA0B32F988503D7DEB410AF52E80F4EF87F01D9236398241C227498458`, old XML SHA256 `A1C34F1AEA2052626E24732683738033104A8714035F10AA049BE04F7EEA20E1`.

## Exact Next Action

In grandMA3 2.5.0.3 load the deployed v0.7.1.0 Plugin, select the known Cue 8 test context and inspect the bounded `[RecipeTracking][ResolverShadow]` line: require `classification=PROVEN`, `final_refs=4`, and exactly Preset 25.9006/9007/9009/9010. Then select a complete child/Cell Group and multiple complete Groups: exact Group and surviving Recipe Pool tiles should pulse with the existing frame; partial or parent-only matches must not. Report the native log and marker observations before declaring the release complete.
