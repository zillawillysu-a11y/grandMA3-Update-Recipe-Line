# Rev8 raw REL ground truth control

Rev8 is a standalone read-only grandMA3 2.5.0.3 observer. It compares the two user-designated Presets at every matching `PhaserRecipeValueSource` by Phaser Recipe, Step, and ValueSource index. The preset numbers select samples only; they do not determine a result. The reverse engine, production plugin, and Rev7 numeric-zero gate remain unchanged.

## Known controls

- A: Preset 25.9009. Original Dimmer Phaser, Absolute Steps 100 and 0. The Relative cells were never authored and remain blank.
- B: Preset 25.9013. Copied directly from A with all other settings intentionally unchanged. Relative numeric zero was explicitly authored. After closing and reopening the editor, its Relative cell still displays zero. It is not used in Cue tracking.

The persistent UI difference is ground-truth authoring evidence, but its storage location remains unknown. Do not change either Preset.

## Installed 2.5.0.3 syntax evidence

The shared `.reference/ma3/DiDiDo-MA3-Developer-Reference` checkout is absent from this worktree. Installed resources establish the object structure and relevant authoring path:

- `lib_plugins/systemtests/db/system_test_phaser_recipe_shapes.lua:443-450` edits `ValueRelative` on a `PhaserRecipeValueSource`; lines 166-167 do the same for `ValueAbsolute`.
- `lib_menus/ui/setup/grid_context_numeric_keypad_values.lua:6-9,43-68` maps `ValueRelative` to `RawValueRel` and sends numeric and special edits to the ValueSource.
- `lib_menus/ui/setup/grid_context_numeric_keypad_values.uixml:35` contains the `None` special control.
- `lib_plugins/systemtests/db/system_test_phaser_recipe_import_export.lua:77-94` traverses Preset Phaser Recipes through Steps to ValueSources and demonstrates Preset XML export. The observer itself never exports or edits anything.

## Native observation

Run the independent `Raw REL Ground Truth Control 2.5.0.3` plugin in the show containing the two existing controls. It requires exactly one native Preset at each designated address. It walks all matching Phaser Recipe Steps and ValueSources, reads each enumerated property twice, and logs raw/direct/Get/display/string representations, property type and info, Attribute/FeatureGroup, linked Preset, Shape, and dependencies. It logs all property differences, including hidden fields. The focused property list includes raw, value, REL, ABS, layer, mask, active, mode, storage, author, flag, and ownership names.

Capture `RAW_REL_GROUND_TRUTH_START`, `GROUND_TRUTH_CASE`, `GROUND_TRUTH_PROPERTY`, `GROUND_TRUTH_PROPERTY_DIFF`, and `RAW_REL_GROUND_TRUTH_RESULT`. A difference is a candidate discriminator only if it is stable on repeated reads, occurs on matched ValueSources, and is related to REL/value/layer/active/storage state. Differences in absolute values or control links make the comparison inconclusive. A lack of native property differences remains inconclusive until serialization is examined.

## Optional serialization comparison

No matching XML exports were present locally. Rev8 does not issue `Export` or read the live show database. If already exported files for A and B are available, run the offline comparer with `--a <A.xml> --b <B.xml>`. It compares every matching ValueSource subtree and reports each differing serialized field. Optional `--a-repeat` and `--b-repeat` accept a second export of each unchanged Preset to check stability. Existing MA3 system tests use `Export <Preset> "stem" /nc`; any export must be initiated manually by the user if desired. Missing or unavailable exports do not block the native observer.

Do not integrate a resolver rule from this experiment alone. Report the exact field/value differential and its limits first.

GROUND-TRUTH VALIDATION PENDING
