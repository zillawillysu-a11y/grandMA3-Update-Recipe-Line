# HelpLua/API Reference Comparison

Research date: 2026-09-01

Scope: Update Recipe Cue Phase 0/1 only. This compares current official research and real grandMA3 2.3.2.0 observations with the requested read-only secondary reference:

- Repository: <https://github.com/patopesto/GrandMA3-Plugins>
- Versioned v2.2 dump: <https://github.com/patopesto/GrandMA3-Plugins/blob/master/website/src/content/docs/reference/v2.2/data/grandMA3_lua_functions.txt>

No production plugin code was copied. The repository dump is not treated as stronger evidence than real grandMA3 behavior or official MA documentation.

## Confidence order

1. Real hardware/software test
2. Official MA documentation and HelpLua
3. Versioned API dump in the reference repository
4. Forum examples
5. Explicitly labeled inference

## Signature comparison

| API | v2.2 dump evidence | Existing project evidence | Current decision |
|---|---|---|---|
| `GetProgPhaser` | `(ui_channel_index, phaser_only)`; returns top-level preset/timing/masks and step tables | Real 2.3.2.0 accepted one argument and returned `abs_preset`, masks, and step 1 | Diagnostic now tries the two-argument signature first and falls back to one argument |
| `GetProgPhaserValue` | `(ui_channel_index, step)`; returns one step including `channel_function` and `integrated` | Capability existed on real 2.3.2.0 but was not called | Add one bounded, read-only step-1 probe |
| `GetPresetData` | `(preset_handle, phasers_only=false, by_fixtures=true)` returns phaser data | Official MA 2.0+ page documents the same argument concept; not yet tested in this project | Add one bounded, read-only call for the uniquely resolved preset |
| `GetUIChannels` | `(subfixture index or handle, return_as_handles)` | Officially documented and verified on 2.3.2.0 | Continue as primary fixture-to-channel enumeration |
| `GetAttributeByUIChannel` | `(ui_channel_index)` returns Attribute handle | Listed officially; not previously inspected | Add identity/address/index probe for one sample channel |
| `GetUIChannelIndex` | `(subfixture_index, attribute_index)` | Listed officially; not previously tested | Add one round-trip probe and compare with enumerated UI channel |
| `GetChannelFunction` | `(ui_channel_index, attribute_index)` returns handle | Not yet tested | Probe only after resolving the Attribute object's index; semantics remain unverified |
| `GetChannelFunctionIndex` | `(ui_channel_index, attribute_index)` returns index | Not yet tested | Same bounded probe; compare with step `channel_function` only after real output |
| `SetProgPhaser` | Writer accepts top-level references/timing plus step data including `channel_function` and `integrated` | Not tested and forbidden in Phase 1 | Document only; never call before isolated Phase 2 test and approval gate |
| `SetProgPhaserValue` | Writer accepts one step and includes `channel_function` and `integrated` | Not tested and forbidden in Phase 1 | Document only; Recipe writer should preferably replace a Recipe reference rather than translate Programmer raw data |

## Answers to the seven research questions

### 1. Programmer source data per fixture/attribute

The strongest current path is:

`SelectionFirst/Next` -> patch index -> `GetUIChannels` -> UI channel index -> `GetProgPhaser`.

Real 2.3.2.0 tests showed `GetProgPhaser` returned data only for Pan, Tilt, and PT Speed after a Position preset call, across all 28 selected fixtures. This provides fixture/channel-specific Programmer data. The new `GetProgPhaserValue(ui, 1)` probe will test whether the step-only API is a cleaner view of the same data.

### 2. Preset-linked versus integrated values

The v2.2 dump separates them structurally:

- `abs_preset` and `rel_preset` are top-level phaser references.
- `integrated` is a per-step preset handle.

Real ordinary-Programmer Position tests confirmed `abs_preset`. They did not show `integrated`; the sample step had `mask_integrated=0`. Therefore:

- `abs_preset` is evidence-backed for ordinary absolute preset calls on 2.3.2.0.
- `rel_preset` and `integrated` remain unverified for this project.
- The plugin must not treat `integrated` as synonymous with the top-level called preset.

### 3. `GetPresetData` as a cleaner preset inspector

Potentially yes. Both official documentation and the v2.2 dump describe a dedicated preset-data table, including a `by_fixtures` view. It may avoid object-tree guessing for the contents of a known Preset.

It does not replace Recipe inspection: it reads Preset data, not a Cue Part's Recipe Selection/Values properties. The diagnostic will call it only after resolving exactly one preset reference and will print a bounded sample for real-console verification.

### 4. Preserving `channel_function`

The v2.2 dump includes `channel_function` in the step schemas of all four Programmer getter/setter APIs. This is strong evidence that raw Programmer phaser translation must preserve it to avoid changing which channel function interprets the numeric value.

V1 should not translate raw Programmer data into Recipe Values at all. Replacing a Recipe preset reference avoids this risk. If the future Store As Recipe feature ever writes raw/embedded data, `channel_function` becomes a required fidelity field and must be validated across fixture types.

### 5. Duplicate Attribute names

Names alone are insufficient. A robust identity should retain at least:

- fixture/subfixture patch index;
- UI channel index;
- Attribute handle/index from `GetAttributeByUIChannel`;
- ChannelFunction identity when the fixture type exposes multiple functions.

This is an inference supported by the API's index-based design, not yet a completed real-console proof. The new round-trip and ChannelFunction probes are intended to test it.

### 6. Original Cue/Part provenance

None of the listed signatures contains Cue, Part, Sequence, source, tracking, or provenance fields. `GetPresetData` is about Preset contents; Programmer phaser APIs are about current Programmer data.

Conclusion: there is no evidence in this API set that it directly identifies the original tracking Cue/Part. Original-source research must continue separately through Cue/track data, object structure, or another confirmed API. Do not infer provenance from `abs_preset`.

### 7. Version compatibility

Compatibility guards are required:

- The v2.2 dump lists a required-looking `phaser_only` argument, while real 2.3.2.0 accepted the existing one-argument call.
- Official 2.2 release notes state that `measure` changed to an integer percentage, while the v2.2 dump describes it as float in the getter and number in the setter.
- Real 2.3.2.0 returned additional fields not shown in the v2.2 signature, including `mask_cooked`, `gridposmatr`, `selective`, and `ui_channel_index`.

Every function remains capability-detected and wrapped with `pcall`. Higher-level logic must consume only fields validated for the current version/shape.

## Diagnostic additions

Diagnostic version 0.1.2.0 adds bounded, read-only probes for:

- `GetProgPhaser(ui, false)` with a one-argument compatibility fallback;
- `GetProgPhaserValue(ui, 1)`;
- `GetPresetData(uniquePreset, true, false)`;
- `GetAttributeByUIChannel(ui)` and Attribute index;
- `GetUIChannelIndex(subfixture, attribute)` round trip;
- `GetChannelFunction(ui, attribute)` and `GetChannelFunctionIndex(ui, attribute)`.

The 2026-09-02 2.3.2.0 DumpLogs showed that these APIs are shape-dependent: Position's UI-channel round trip changed index 9 to 10 and its ChannelFunction probes returned `nil`; Color's round trip returned `nil`, but `GetChannelFunction` resolved `Color Index` and `GetChannelFunctionIndex` returned 67. `GetProgPhaserValue(ui, 1)` returned a step for the multi-step Position sample and `nil` for the single-step Color sample. These results are useful read evidence, but none is a universal writer identity contract. `SetProgPhaser` and `SetProgPhaserValue` remain capability-reported and are never invoked.

## Next real-console tests

1. If safe test presets exist, separately test a pure relative preset, an integrated preset value, and controlled single-step/multi-step presets.
2. Repeat the Position and Color read-only tests on 2.4.x before converting any result into compatibility logic.
3. Build a disposable tracking test where the recipe source Cue/Part is known and the current cue only tracks it, then inspect for a reliable provenance mechanism.
