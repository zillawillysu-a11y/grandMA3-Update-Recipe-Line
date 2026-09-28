# Project Handoff

## Current Goal

Validate the deployed v0.7.1.1 native bugfix candidate in grandMA3 2.5.0.3: selected Attribute's actual contributing Groups, Clear response, and Recipe/EFX Pool frames.

## Current Working State

The `C:\tmp\show-rel` worktree contains v0.7.1.1. Track A reverse-lane resolver gates remain intact. Group Pool markers now come only from surviving lanes in the selected Attribute's FeatureGroup, including static terminators; full-set containment alone no longer paints every overlapping Group. Complete Group candidates are cached per selection and reused on steady marker pulses. Clear resets current Groups/refs and removes frames on the next refresh. Pool button lookup supports nested buttons and native handle identity fallback. The panel shows numbered current Groups, resolver classification/ref count, frame count, and bounded missing-stage detail. `ENABLE_TRACK_A_SHOW_CANDIDATE=true`; `ENABLE_CUE_PHASER_MARKERS=false`. Existing theme pulse colors and `frame0` are unchanged.

## Latest Real-World User Test

The user loaded v0.7.1.0 in grandMA3 2.5.0.3 and confirmed its visible title. Native UX failures: many overlapping Groups lit; Group number absent; Group marker and Clear felt slow; two Layout-selected lights did not show both active Attribute Groups; none of the expected Cue 8 Recipe/EFX Pool tiles had frames (not just 25.9009). The old Command Line History did not expose ResolverShadow. v0.7.1.1 has not yet been tested natively.

## Verified Facts

- Native identity is strict ToAddr(handle) -> Fixture <numeric dotted key>, with unique ObjectList(ToAddr()) round-trip. Parent and child remain distinct.
- The candidate still uses complete Stored Group membership to admit Recipe rows, then marks only Groups owning surviving lanes for the selected Attribute FeatureGroup. Partial Groups remain excluded; parent and child stay exact.
- Offline tests passed: 86 legacy workflow assertions plus 97 enabled show candidate checks. Synthetic four refs remain missing=0, extra=0, blockers=0. Lua parser, deterministic build, XML validation, and diff check passed. Version mismatch was independently shown to fail the build guard.
- Selection context changes mark Pool refs dirty in the same loop; cached Group candidate matching runs once per selected member set. Bounded context timing measures selection/programmer/tracking, Group match, resolver, Pool discovery, and tile application on native semantic recompute.
- Existing marker colors, frame texture, Recall View hidden-grid handling, and bounded discovery were not changed.
- v0.7.1.1 was deployed to the confirmed active folder. Source/deployed SHA256: Inspector `01B806BB7920F9BF1C90998EF3E6247CE743E1006A17DB9B837AA1AFE88BBA02`, Diagnostic `A00C30DD8DCEFF67ACE8F86E423E70742AF74F85FBB4FA2E38514E5AF15B2191`, XML `7963F2EA3B7A44C8015E80B2D83983CDBB852577DF9E18E2B2DC740FD510A418`. The exact v0.7.1.0 files were backed up at `C:\tmp\show-rel-backups\Update-Plugin-before-v0.7.1.1-20260928-235939`.

## Current Problem

The first missing stage for actual Cue 8 Recipe/EFX frames is still unknown. The v0.7.1.1 panel now reports resolver status/ref count and frame count; if refs are present but frames missing, it shows the first missing marker stage. Do not infer the 9009 root cause from synthetic tests. Native stage timings are pending; no reliable before/after milliseconds can be claimed yet. Do not claim show-ready.

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

Detached `C:\tmp\show-rel` worktree based on origin/qwen; see Git for the new v0.7.1.1 checkpoint after commit/push. Before this deployment the confirmed v0.7.1.0 Inspector SHA256 was `6027673DF01738C260D080ED7ADB7AD423467B09B81C42DDCACAF916FF8314EF` and XML SHA256 was `17326FA1DE0070CEA86EE5A71D7781A5C4E257D480D16690CB68A31DD88A13B0`.

## Exact Next Action

In grandMA3 2.5.0.3 load v0.7.1.1, select Cue 8 and the two lights/Attribute from the reported case. Read the visible `Resolver` and `frames` panel line (DETAIL shows bounded ref list), then check Group number+name and EFX Pool frames. Press Clear and verify the panel and old frames disappear on the next refresh. If any frames remain missing, report the visible `Reason` or `Missing ... @ STAGE` text; Command Line History is not required. Then test parent versus child Cell and two different current Attribute Groups. Only after native success remove temporary marker-stage logging and consider show-ready.
