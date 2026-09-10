# Cue Effect Pool Markers

v0.7.0.9 adds selected-Sequence Cue usage markers independent of fixture selection.

- Purple `GroupedProgLayerActive.Phaser` frame for referenced moving Presets and Generators. This is a valid ColorGroups entry and resolves to RGBA `A34CB4FF` in the grandMA3 2.5 default themes.
- Fixture-count text is currently hidden so the marker only changes the Pool item's frame.
- A Phaser Recipe or Generator stored in the current Cue is marked immediately. Active effects stay purple even when the same Pool item is also the current Recipe reference; other Recipe references keep the existing 0.25-second green pulse.
- Visible buttons in cached Pool grids are checked every 0.5 seconds, with one overlay per matching button. The full display tree is discovered only on startup or after the cached grids become invalid. No Show objects or fixture selection are modified.

Markers are appended to the PoolLayoutGrid after its buttons and retain the matched button's cell Anchors, so they render above native button content on onPC builds that clip or paint over button children. Only classes ending in `PoolButton` are considered; Pool title and context buttons are excluded. If Grid:Append is rejected, the plugin falls back to a button child.

## Read Model

GetPresetData(part, false, false) reads numeric UI-channel Phaser records. Cues and Parts are sorted through the current Cue. Absolute and Relative replacements are resolved independently. Static replacements and release/remove flags clear that layer. Multi-step records or explicit Generator references identify effects. Preset/Generator and integrated step references identify Pool objects.

Phaser Recipe objects are `Preset` objects containing `PhaserRecipe` descendants; they are not Generators and do not need to live in a pool named `Phaser`. Their `PhaserRecipeValueSource.Attributes` fields establish the affected feature when those descendants are readable. A custom-pool Preset name/address remains a bounded feature fallback.

Only `StandardRecipe`/`Recipe` children are treated as editable Recipe rows. A `PhaserRecipe` found under the Programmer or a Preset must never become the inspector's direct source. The Recipe editor's `Enabled` property controls row eligibility. The exported `Active` property is not used because grandMA3 2.5 exports valid cooked StandardRecipe rows with `Active="No"` and `Enabled="Yes"`.

When an enabled StandardRecipe in the same Cue Part applies a matching value to a cooked multi-step channel's fixture and feature, that Recipe's Preset or Generator is the displayed Pool reference. It takes precedence over cooked Shape or `integrated` links to underlying value Presets.

GetUIChannel followed by GetRTChannel supplies fixture/subfixture identity when available. Missing identity falls back to matching enabled Phaser Recipes by feature because fixture counts are hidden. One Part is scanned per host-owned plugin tick; native APIs are never called from a manually created nested coroutine. Complete snapshots publish atomically. Cue/Sequence changes discard stale snapshots and trigger one scan; an unchanged Cue is not scanned again. Usage follows the selected Sequence's Current Cue even when its executor is stopped or being edited. More than 512 Cues or 131072 work units fails closed and logs an error.

## Native Test Limits

These are stored Cue indicators, not final-output telemetry. Other Sequences, Programmer priority, fades, delayed Parts, filters, special tracking modes and live suppression are not arbitrated. Group/feature fallback cannot prove every manually edited cooked channel's provenance. Raw Phasers without a Pool reference have no Pool tile to mark. Actual Generator/cooked reference shapes and visual placement need testing in the user's Show.

## Local API Evidence

Installed vendor files under gma3_2.3.2/shared/resource:

- lib_plugins/systemtests/db/system_test_cue_block.lua: GetPresetData(Cue Part) returns stored channel records, including empty tracking Cues.
- lib_plugins/systemtests/help/system_test_helping_functions_db.lua: abs_release/rel_release and GetUIChannel-to-RT lookup.
- lib_plugins/systemtests/db/system_test_api_tests.lua: Absolute/Relative Preset links and UI-channel tables.
- lib_color_themes/defaultDAYLIGHT.xml: SheetColor.PhaserText definition.

The official [GetRTChannel documentation](https://help.malighting.com/grandMA3/2.3/HTML/lua_objectfree_getrtchannel.html) describes fixture/subfixture handles in RT-channel metadata.

The user's grandMA3 2.5.0.3 `FAG.xml` export confirms Cue 16 has an enabled StandardRecipe for Group `H1 Top V` with Values `Song EFX.Dimmer Speed#3` (pool 25, slot 303), while its cooked Dimmer channels have two integrated steps (`Dimmer.100` and `Dimmer.20`). The Preset dependency contains a `PhaserRecipe` whose Shape is `Sine 1/2`. This is why reading the nested PhaserRecipe directly produced the incorrect Shape 8 result, while the StandardRecipe is the correct Pool source.

## Performance checkpoint

v0.7.0.12 uses three resolver tiers. FAST publishes Phaser Recipes/Generators stored directly in the current Cue before the first yield. MEDIUM runs on the next host tick and walks only the bounded Cue/Part/Recipe object tree; newest Recipe per exact Group and feature wins, so inherited Phaser Recipe references publish without `GetPresetData`, while a newer static Recipe in the same lane terminates them. SLOW then reads cooked channel data in batches and replaces the progressive MEDIUM result with its authoritative snapshot; if SLOW aborts, the useful progressive result remains. This ordering guarantees a UI paint opportunity between MEDIUM and the first potentially expensive native read. MEDIUM is intentionally provisional because overlapping Groups, releases and manually stored channels require SLOW.

The 0.1-second loop waits, batches of 32 cooked records, one native read per Part, and memoized Recipe feature matching remain unchanged. Up to 32 completed cooked Cue snapshots are reused within a Sequence. Plugin force-refresh invalidates snapshots. Restart after external edits or Show replacement at identical addresses. Reference address lookups are memoized once per unique object per scan (the final result pass reuses the same memo, so it performs strictly fewer address lookups than v0.7.0.10).

For native diagnosis, every uncached scan writes `[RecipeTracking][EffectScan]` records to Command Line History: one `start`, one line per completed Part, and `finish`, `abort`, or `cancelled` (scan discarded mid-flight by a Cue change or marker shutdown, with advance and completed-Part counts). A Part line reports its exact returned record count (`channels`), numeric channel count, bounded `advances`, `first_ref_advance`, `elapsed_ms`, moving layers, direct and Recipe-recovered references, empty/unresolvable references, missing UI/RT/Attribute mapping, and failed Recipe feature or membership recovery. `abort` includes the caught error, advance count, and `elapsed_ms`; `finish` adds total scan `elapsed_ms`. The per-Part diagnostic is created before the native Part read, so its elapsed time includes `GetPresetData`. These counters reuse the existing traversal; the only added native touch is a memoized `ToAddr` once per unique reference object. No additional `GetPresetData` passes, `GetUIChannel`/`GetRTChannel` reads, or batch-structure change are introduced. `elapsed_ms` uses the standard Lua `os.clock` when the host exposes it and prints `n/a` otherwise; on hosts where `os.clock` reports CPU time it is a lower bound on wall time.

The 0.3-second target is NOT native-validated. Cold inherited effects still await historical scanning; GetPresetData is synchronous and cannot be preempted. Render source tracking remains synchronous. New Pool windows require restart while cached grids remain valid.
