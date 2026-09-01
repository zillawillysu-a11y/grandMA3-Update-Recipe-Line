# Phase 0 Research: grandMA3 Recipe Update

Research date: 2026-09-01

Target floor: grandMA3 2.3.2.0

Scope: read-only discovery for Phase 1. No production writer behavior is approved by this document.

## Evidence policy

The status labels in this document are deliberate:

- **Documented**: present in the official grandMA3 2.3 manual, or documented before 2.3 and still listed by the official 2.3 Lua API index.
- **Release-note evidence**: named by an official release note, but without a complete public function contract in the 2.3 Lua API index.
- **UI behavior only**: the user-facing behavior is documented, but no stable Lua property/address is documented.
- **Unknown / needs console dump**: do not use for a write operation until verified on real 2.3.2.0 and a later supported version.

## Confirmed findings

### Real-console evidence: grandMA3 2.3.2.0

The following was observed in two System Monitor dumps from an actual 2.3.2.0 onPC installation on 2026-09-01:

- `GetProgPhaser(uiChannelIndex)` is available and returns a table for Programmer channels after calling an ordinary Position preset.
- The returned table contains `abs_preset` as a real `Preset` handle. Its native address identified the pool and preset, for example `ShowData.DataPools.Default.PresetPools.Position.<<<>>>`.
- An ordinary `Group 10; At Preset 2.5` call on 28 fixtures produced one unique `abs_preset` across Pan, Tilt, and PT Speed. `mask_active_phaser=65`, `mask_active_value=2`, `mask_individual=65`, `selective=true`, and `mask_cooked=0` were consistent in this test.
- Calling Position preset 2.4 changed the unique handle to Position preset 4 `Open Tilt`, proving the reference follows the newly called preset rather than only raw Pan/Tilt values.
- With Edit Recipe active, the same phaser shape was visible but `mask_cooked=255`, and `ProgrammerPart():Count()`/Dump showed two `Recipe` children.
- With Edit Recipe disabled and the Programmer cleared, `ProgrammerPart():Count()` was zero and the Dump contained no Recipe children.
- The selected cue handle had a child of class `Part`. The current tracked cue in this test did not itself expose Recipe children, so original-source resolution remains necessary.
- No Lua runtime error occurred in the valid ordinary-Programmer run.

These observations justify a Phase 1 high-confidence summary only when exactly one `abs_preset` handle is found and there are no active phasers without that reference. They do not yet prove original Cue/Part or Recipe-line resolution.

### General read-only Lua primitives

- `Version()` returns the software version. Since 2.2 it can also return numeric version components.
- `SelectedSequence()` returns the selected sequence handle.
- `GetCurrentCue()` returns the last activated cue handle in the selected sequence.
- `SelectionFirst()` and `SelectionNext(index)` enumerate the current selection using zero-based patch indexes, not FIDs/CIDs.
- `GetSubfixture(index)` converts a patch index to a subfixture handle.
- `GetUIChannels(indexOrHandle, true)` returns UI-channel handles for a fixture; official examples expose `INDEX` and `SUBATTRIBUTE` on those handles.
- Object `Children()`, `Count()`, `Get()`, `GetClass()`, `Addr()`/`AddrNative()`, and `Dump()` are official read-only inspection tools. `Dump()` writes object structure, properties, and children to Command Line History.
- `DataPool()`, `Programmer()`, `ProgrammerPart()`, `SelectedFeature()`, `GetSelectedAttribute()`, `GetAttributeByUIChannel()`, and `GetPresetData()` are listed in the official 2.3 object-free API index.

### Recipes and cooking

- Cue recipes live on cue parts, and a cue part can contain multiple recipe lines.
- Documented recipe ingredients include Selection, Values, MAtricks, Filter/World, fade, delay, speed, phase, grid, shuffle, Selection Mode, Enabled, and Lock.
- A Values ingredient can reference a preset. A Selection ingredient can reference a group or `<From Value>`.
- Recipe lines cook data into the cue part. Cooked data can coexist with conventional cue data.
- Officially documented Cook modes in 2.3 are `/Merge`, `/MergeLowPriority`, `/Overwrite`, and `/Remove`.
- `/Overwrite` can delete unrelated destination content and is therefore forbidden for this project unless a future, isolated test proves a safe and necessary use.
- `/MergeLowPriority` is documented as replacing existing cooked data without changing non-cooked data. This is promising for a later writer, but is not exercised in Phase 1.
- Recipe changes may auto-cook when a valid selection is assigned. Exact auto-cook behavior after changing the Values reference still needs an isolated writer test.

### Undo

- `CreateUndo(name)` and `CloseUndo(handle)` are official APIs available before the 2.3 floor.
- `Cmd(command, undoHandle)` can associate supported command actions with one undo group.
- Whether direct object-property writes and a subsequent Cook operation join the same undo group must be tested in Phase 2. Phase 1 does not create an undo handle because it performs no write.

### Programmer phaser data

- Official 2.2 release notes explicitly mention `GetProgPhaser()` and state that its `measure` member changed to an integer percentage.
- `GetProgPhaser()` is not described by a dedicated page in the official 2.3 object-free API index found during this research. Its full signature, active flags, integrated/preset-link representation, and return shape are therefore not treated as stable facts.
- Phase 1 calls it only when the global function exists, wraps every call in `pcall`, and reports bounded table structure for real-console comparison.

## Unknowns and hypotheses

The following are not safe foundations for production writes yet:

- The exact child hierarchy and class names below Cue -> Part -> Recipe on 2.3.2.0.
- The internal Recipe property names for Selection and Values. UI column labels do not prove Lua property names.
- Whether Recipe references are returned as handles, object-number strings, native addresses, or display strings.
- Whether the observed `abs_preset` contract and masks remain identical in 2.4.x and later.
- How relative presets and multi-step/multi-feature programmer data represent their references.
- Whether `integrated` is relevant for preset reference resolution in other preset modes or versions.
- A stable, read-only source for the group that created the current selection.
- A stable Lua API for command history or System Monitor history. Visible history is not proof of programmatic access.
- A stable output-provenance API that maps fixture + attribute at the current cue back to original Cue/Part (`CueAbs` or otherwise).
- A stable Recipe address and Assign syntax that replaces only Values.
- The narrowest safe Cook target and whether changing Values auto-cooks in every supported version.
- Cue Only implementation and restoration semantics.

## Compatibility matrix

| Capability | 2.3.2.0 | 2.4.x / later | Fallback / current policy |
|---|---|---|---|
| Software version | `Version()` documented | Capability-detect same API | Parse text if numeric returns are absent |
| Selected sequence | `SelectedSequence()` documented | Capability-detect | NO-OP if absent/nil |
| Current cue | `GetCurrentCue()` documented | Capability-detect | Inspect selected sequence state only; do not guess cue |
| Current fixture selection | `SelectionFirst/Next`, `GetSubfixture` documented | Capability-detect | NO-OP if selection cannot be enumerated |
| UI channels / attributes | `GetUIChannels()` documented | Capability-detect | Dump fixture and report unavailable |
| Programmer object | Listed in 2.3 API index | Capability-detect and Dump | Report unavailable; never infer active state from output |
| `GetProgPhaser` | Release-note evidence; contract incomplete | Capability-detect | `pcall`; report raw bounded structure; no update |
| `GetProgPhaserValue` | Not confirmed in official 2.3 index | Capability-detect only | Do not require or call in Phase 1 |
| Preset link / `integrated` | Shape unknown | Capability-detect keys | Report `UNRESOLVED` until real dump proves semantics |
| Group source | No stable API confirmed | Capability-detect future API | Future exact reverse match; ambiguous/no match means NO-OP |
| Recipe object access | Recipes under cue parts documented; hierarchy names unknown | Traverse handles and inspect classes | `Children()` + `Dump()` only |
| Recipe Selection | UI concept documented; Lua property unknown | Probe displayed property names read-only | Dump and mark unresolved |
| Recipe Values | UI concept documented; Lua property unknown | Probe displayed property names read-only | Dump and mark unresolved |
| Recipe addressing | Not confirmed | Dump `Addr` and `AddrNative` | No Assign until isolated test |
| Assign preset to Recipe | Not confirmed | Phase 2 capability test | No writer in Phase 1 |
| Original cue / CueAbs source | No official Lua provenance contract confirmed | Future capability probe | Report unresolved; never scan-and-guess as provenance |
| Cook | Keyword and four modes documented | Capability-detect syntax/behavior | No Cook in Phase 1; test `/MergeLowPriority` later |
| TrackingDistance | UI/behavior evidence insufficient for policy | Dump property if present | No Cue Only implementation |
| Cue Only method | Not established | Research native behavior per version | Deferred to Phase 5 |
| Undo | `CreateUndo`, `CloseUndo`, `Cmd(..., undo)` documented | Capability-detect | Phase 2 isolated transaction test |
| Command history | UI exists; stable Lua reader not confirmed | Capability-detect future API | Do not parse System Monitor |
| System Monitor access | Output via `Printf`/`Dump` documented; reading not confirmed | Same | Output diagnostics only |

## Phase 1 diagnostic design

`RecipeUpdate_Diagnostic.lua` is intentionally read-only:

- It never calls `Cmd`, `Assign`, `Set`, `Store`, `Cook`, `Delete`, `Acquire`, `CreateUndo`, or `CloseUndo`.
- It does not assign to object properties.
- It reads version, selected sequence/current cue, selection, UI channels, programmer phaser probes, and object trees.
- It prints every unresolved result as `UNRESOLVED`, `UNAVAILABLE`, or `NEEDS REAL-CONSOLE VERIFICATION`.
- It uses shallow, bounded table output so unexpected API data cannot flood Command Line History indefinitely.
- It dumps the selected sequence, current cue, cue descendants, Programmer, and current ProgrammerPart when available. Dumps are verbose by design in this research build.
- Candidate scoring is not enabled until feature, selection, old preset reference, and original provenance can be read reliably. Printing a guessed candidate number would violate the NO-OP policy.

## Required real-console test

Run these tests first on grandMA3 2.3.2.0, then repeat on one 2.4.x system using a disposable show copy.

1. Create or identify a sequence where Cue 10 Part 0 has a recipe using Group 101 and Position preset 2.1, and Cue 30 tracks it.
2. Go to Cue 30.
3. Clear the programmer, then execute `Group 101` and `At Preset 2.7` (or tap Position 2.7).
4. Import `recipe_update_diagnostic.xml`, then run the `Recipe Update Diagnostic` Plugin.
5. Save the entire Command Line History output, including all `[RecipeUpdate][DIAG]` lines and Dump blocks.
6. Repeat with Color preset 4.3.
7. Repeat with two active feature groups to confirm the diagnostic refuses to resolve a single preset.
8. Repeat with Pan and Tilt coming from different source cues if a test show can be built.
9. Confirm the show reports no changed state after every diagnostic run.

For each version, capture:

- `Version()` result and capability list.
- The exact `GetProgPhaser()` return for active Pan/Tilt or Color UI channels.
- Any key containing `preset`, `integrated`, `link`, `active`, `absolute`, or `measure`.
- Cue, Part, and Recipe class names, native addresses, and Dump property names.
- The actual objects/values behind any Selection and Values properties.
- Whether the current cue handle represents Cue 30 directly and how its parts are exposed.
- Whether any read-only object exposes original cue/part provenance.

## Gate before Phase 2

Do not start the writer until the 2.3.2.0 results establish all of the following:

1. A reliable active single-feature preset reference.
2. A reliable current selection and an unambiguous group strategy.
3. A reliable original Cue/Part source, or a clearly constrained alternative approved after testing.
4. A reliable Recipe line enumeration and Values reference read.
5. Exact isolated addressing for one Recipe Values cell.

Phase 2 must use a disposable test sequence and snapshot every unrelated Recipe property before and after the write.

## Official sources

- [grandMA3 2.3 Lua Object-Free API index](https://help.malighting.com/grandMA3/2.3/HTML/lua_objectfree.html)
- [Version()](https://help.malighting.com/grandMA3/2.3/HTML/lua_objectfree_version.html)
- [SelectedSequence()](https://help.malighting.com/grandMA3/2.3/HTML/lua_objectfree_selectedsequence.html)
- [GetCurrentCue()](https://help.malighting.com/grandMA3/2.0/HTML/lua_objectfree_getcurrentcue.html)
- [GetSubfixture()](https://help.malighting.com/grandMA3/2.3/HTML/lua_objectfree_getsubfixture.html)
- [GetUIChannels()](https://help.malighting.com/grandMA3/2.2/HTML/lua_objectfree_getuichannels.html)
- [Children()](https://help.malighting.com/grandMA3/2.3/HTML/lua_object_children.html)
- [Dump()](https://help.malighting.com/grandMA3/2.3/HTML/lua_object_dump.html)
- [Cue Recipes](https://help.malighting.com/grandMA3/2.3/HTML/cue_recipe.html)
- [Recipes](https://help.malighting.com/grandMA3/2.3/HTML/recipes.html)
- [Cook keyword](https://help.malighting.com/grandMA3/2.3/HTML/keyword_cook.html)
- [CreateUndo()](https://help.malighting.com/grandMA3/2.3/HTML/lua_objectfree_createundo.html)
- [grandMA3 2.2 release notes](https://help.malighting.com/grandMA3/2.3/HTML/key_rn_v2_2.html)
