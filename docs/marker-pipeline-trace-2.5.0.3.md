# Marker Pipeline Trace — grandMA3 2.5.0.3

## Scope and native operation

Track B only, selected-group marker pipeline. Native validation pending. Production stays v0.7.0.17 unchanged; Track A paused. Generic UI-discovery probing is stopped.

1. Keep the existing Update Plugin inspector open in the normal state showing the ONE Group whose markers you want to examine. Keep its selected Sequence/Cue and relevant Pool windows unchanged. The diagnostic does not start or operate production.
2. Import marker_pipeline_trace_2_5_0_3.xml from C:/ProgramData/MALightingTechnology/gma3_library/datapools/plugins/Marker Pipeline Trace 2.5.0.3.
3. Press **Marker Pipeline Trace 2.5.0.3** once.
4. Copy Command Line History [MarkerTrace] START through END, including errors. For a missing marker, identify its SOURCE ref number and include its POOL_DISCOVERY, TILE and DECISION records.

Selected Group means production's currentGroup, not an invented MA selected-group API. The probe reads RecipeTrackingInspectorState from the shared Lua global environment. If this state/currentGroup is unavailable or version mismatches, it reports UNVERIFIED; it does not guess a Group from fixture selection, invoke render or access cooked data. Native accessibility of this snapshot still requires confirmation in this probe's first run. No automatic selection, Recall or View change.

## Source trace

The snapshot copies scalar state and its reference/cache/grid/marker maps; referenced native objects and marker entries are read only. No writes to production tables. Context records Group, Sequence, current/source Cue, Part, Recipe, raw reference, resolved type/class/command/native/DB handle and source selection. Preset, Phaser and Generator/Random are traced when present; Selection/MAtricks/Filter/World are retained because production publishes them too.

Nine relevant helper sections are copied verbatim from RecipeTracking_Inspector.lua and checked against current repository source by the runner: safe/property/address/class/identity helpers, Cue/Part/Recipe numbers, Enabled and Children, normalizeFeature, object/string reference resolution, commandAddress/sameReference, Phaser classification, and recipeReferenceFeatures/constants. No GetPresetData path is copied or called. ObjectList is used only where production recipeField resolves a source string; it never stands in for a UI tile target.

Production recipePoolReferences():1127-1162 merges currentRecipe fields (or matchingCandidates when no currentRecipe), currentGroup and scoped references. It recomputes scoped references only when Sequence/Cue/Group context key changes. Trace reproduces that branch on local copies. Independently, it recomputes selected-group structural Recipe lane winners using trackedGroupRecipeReferences():712-768: Cues <= current Cue, Enabled StandardRecipe, sameReference selection, descending Cue/Part/Recipe, first feature lane wins; publish all six fields from a winning row.

Fresh winners are compared to the actual cache-dependent final reference set. A fresh reference omitted by retained source cache is marked SOURCE_RESOLUTION_MISS with that exact reason. Cache-only objects whose current source cannot be established have CACHED_SOURCE_UNKNOWN provenance. Rejected/disabled rows are labelled candidate-only and sampled up to eight rows; they are not asserted active. Detailed SOURCE_ROW output is limited to the first 32 rows. These optional detail limits do not cap the winning references.

Direct/tracked labels describe structural source-Cue comparison from the snapshot/object tree, not current playback provenance. No claim about cooked channel override/release is made. currentRecipe and matchingCandidates admission is preserved as production implements it, including branches lacking an Enabled/group gate. source_selection/source_group_match expose the source separately. Empty/unassigned fields imply no expected marker; readable display names that cannot be verified as object links stay UNVERIFIED. An address-like unresolved link is SOURCE_RESOLUTION_MISS. The probe cannot invent references absent from both the snapshot and readable Recipe objects.

## Grid and tile trace

Reuse the production cache/rediscovery branch from refreshPoolMarkers():1633-1683, including copied IsActuallyVisible acceptance of nil, source-key refresh flag, Display 1-7 order, shared 6000-node budget, depth 20, window exclusion and stop at PoolLayoutGrid. This is only the discovery needed for this pipeline invocation; no independent broad inventory or new budget experiment. A cached grid set is retained when production would retain it.

Each grid logs handle/address/native/display, pool type/target, production acceptance and separate visibility signals. Expected pool family is a diagnostic hint. Parent/owner association (up to three database ancestors) or an actual target match identifies relevant grids; it is not added as a production filter. Unknown source pool association/visibility stays UNVERIFIED.

scanGrid():1685-1741 is replayed read only: production UIChildren selection, poolbutton class substring excluding pooltitlebutton, numeric ObjectIndex, actual PoolObject:Ptr(ObjectIndex), command-key lookup then sameReference fallback over final references. Targets are taken from actual native pool Ptr, never ObjectList. Diagnostic extraction from a rejected-class widget with ObjectIndex is logged separately; production would not perform that extraction or accept it. Production only traverses its existing child path; no fallback fix is tested.

TILE separates widget handle/class from DB target class/address/native/handle. It logs Lua equality, HandleToStr equality, command/native equality, production sameReference and match path. No CompareHandle call or integration. Textual equality alone cannot establish MARKER_PATH_COMPLETE. ObjectIndex samples are only this tile's observed metadata; no Generator-index investigation or assumption about empty tiles.

DECISION gives reference acceptance, visible source pool, target match, matched visible buttons, native identity matches, running/blink gate, next tick's pulse-only shortcut and function/rejection reason. Replay evaluates the next eligible lookup, not a promise that the next timer tick discovers/repaints. Production has no button visibility gate; a hidden matched button is reported as accepted-but-visibility-unverified, not falsely called a production rejection.

## Marker creation limit

Production found[button]=true is knowable from the read-only match. Existing valid marker entries are logged as reusable, with overlay visibility and button/overlay dimensions. New marker insertion is CONDITIONAL_APPEND_AND_CONFIGURATION_NOT_EXECUTED because Append/configuration and paint cannot be verified without writes. Marker texture/anchor/layer/rendering success is not proven. MARKER_PATH_COMPLETE means all read-side source-to-visible-tile gates pass with target DB identity; it does not certify flashing or drawing. If every expected reference is complete but the marker is visually absent, the remaining unknown is creation/configuration/paint, not a newly proven discovery failure.

## Per-reference classifications

- MARKER_PATH_COMPLETE: final source reference accepted; confirmed visible grid/button; production matching accepts that target; Lua handle equality or identical native handle string confirms source/target identity. Render not executed.
- SOURCE_RESOLUTION_MISS: address-like Recipe link unresolved, invalid source DB handle, or fresh scoped winner absent from reused production source cache.
- POOL_DISCOVERY_MISS: source pool association known but production grid set has no confirmed visible matching source pool.
- TILE_MATCH_MISS: expected visible source pool exists but no corresponding native target is found through production's child/index/Ptr path; failure reason includes unresolved Ptr where directly evidenced.
- MARKER_DECISION_REJECTED: known reference rejected by exact production source admission, feature/Enabled rule, command-address key, running/blink gate or button/matching predicate.
- UNVERIFIED: missing snapshot, display metadata mistaken for links, visibility/pool association unknown, textual match without DB identity, limits/guard deviation or insufficient evidence.

Records are source occurrences, not an artificial deduplicated playback set; repeated references retain provenance while production's final command-key map deduplicates. A miss is an observed stage in this layout/state, not automatically a defect: a tile may be absent from the displayed bank/page.

## Safety / validation

Only diagnostic locals and Printf output. No production/source/version changes, commands, selection/programmer/playback writes, UI creation/updates, marker drawing, hooks, timers, nested coroutines, GetPresetData or CompareHandle. All UI-only calls require UIObject derivation; guard deviation invalidates replay certainty.

Bounds: 160 source occurrence records, 4096 source Recipe entries, production 512-Cue/2048-enabled-Recipe limits, 64 grids, 2048 direct children per grid, 150000 calls through the safe helper, and 1800 tagged detail lines with an unconditional final END. Copied direct pcall helpers are additionally bounded by these source/node/child limits; the safe counter is not a total native-call or timing measurement. Limit/guard failures are UNVERIFIED. Keep native context stable for the whole one-shot run.

[Lua](../diagnostics/Marker_Pipeline_Trace_2_5_0_3.lua), [XML](../diagnostics/marker_pipeline_trace_2_5_0_3.xml), [mocks](../tests/marker_pipeline_trace.lua), [runner](../tools/run_marker_pipeline_trace.py).

41 offline assertions cover complete Preset/Group/Phaser/Generator paths, source-string resolution and unavailable addresses, invalid handles, cache omission, structural tracking/override/disabled rules, exact grid/target/button rejection stages, hidden signals, metadata vs reference, textual vs DB identity, valid existing marker reads, snapshot immutability, limits on optional detail, target version and forbidden API guards. Nine copied helper sections match production. Native break point remains unverified until user returns the trace.

## Deployment verification

Actual independent Lua/XML copy completed. XML components exist; source/deployed Lua and XML parse PASS; SHA256 MATCH. Static mutation/cooked/CompareHandle guard PASS. All three production sources equal HEAD after Git filtering; production directory snapshot unchanged. Source/deployed production files also match. 41 trace mock assertions, nine helper fidelity checks and 86 existing workflow assertions PASS. REAL-WORLD VALIDATION PENDING.

- Marker_Pipeline_Trace_2_5_0_3.lua: `68ed93754c6506cae61791dd0bdf3af7e654b808103bf6948545931065b7e085`.
- marker_pipeline_trace_2_5_0_3.xml: `c30088f6f2f3e3391f4fb466dbbc079cb29ccc585dd28f0946f3ba7fec13df41`.
