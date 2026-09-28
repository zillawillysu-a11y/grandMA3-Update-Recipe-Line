# Rev7 raw relative zero semantics proof

Target: grandMA3 2.5.0.3, independent Recipe Reverse diagnostic. Rev7 follows the Rev6 baseline and finalizes before the cooked oracle. Production, reverse engine, Group expansion, and member applicability rules are unchanged.

## Local reference audit

The shared `.reference/ma3/DiDiDo-MA3-Developer-Reference` checkout is absent from this worktree. Rev6's recorded audit of its 2.5.0.3 API index establishes only the `GetPresetData` signature, with no ValueSource raw-zero schema. The installed 2.5.0 resources provide these exact observations:

- `shared/resource/lib_menus/ui/setup/grid_context_numeric_keypad_values.lua:6-10` maps `VALUERELATIVE` to `RawValueRel` and `VALUEABSOLUTE` to `RawValueAbs`.
- `shared/resource/lib_plugins/systemtests/help/system_test_helping_functions_db.lua:242-250` defines active value mask bits ABS=2 and REL=4 for Phaser data. It does not define a ValueSource active lane mask.
- `shared/resource/lib_plugins/systemtests/db/system_test_prog_xyz.lua:2544-2545` expects active relative values of numeric zero. This is cooked Phaser data, so it prevents a zero-means-inactive inference but does not prove how a ValueSource raw zero was authored.
- `shared/resource/lib_shapes/default_shapes.xml:107` ships a `PhaserRecipeValueSource` with `RawValueAbs=0` and `RawValueRel=0`; other ValueSources in that file also have relative zero. Zero therefore exists in authored vendor Shape material.

No installed reference found here documents a ValueSource `Layer` or `ValueLayer` discriminator, `ValueRelative` inactive representation, or a zero-versus-empty raw storage rule. Property labels alone are not proof.

## Native comparison and candidate

Rev7 groups existing structural ValueSources by raw ABS/REL type and value, effective direct/getter values, Layer/ValueLayer observations, Shape presence, and linked Preset layer/mask/effective evidence. It records one representative stable identity, Step, Attribute, FeatureGroup, and linked Preset per pattern. Linked Preset evidence is normalized from the existing reference cache. There are no additional `GetPresetData` calls.

Numeric `RawValueRel=0` always remains `REL_AMBIGUOUS`. Neither an opposite Layer label, getter zero, nor a complete linked Preset without REL establishes whether the ValueSource's own zero was authored. Empty raw display also stays ambiguous because getter fallback has not been ruled out. Explicit `None` is reported as no local REL lane; nonzero numeric raw REL is reported as authored by the vendor keypad mapping. These control classifications do not promote a zero-ambiguous candidate.

Rev7 reuses the Rev6 reference metadata and runs the same reverse resolver on separate candidate rows. It prints compact pattern/proof summaries, Rev7 metadata/reverse counts, timing, and an oracle-last difference. The native comparison is needed to decide whether a future independent discriminator exists; local tests cannot establish the Show's result.

REAL-WORLD VALIDATION PENDING
