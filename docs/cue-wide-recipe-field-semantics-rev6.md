# Rev6 reference field semantics proof (grandMA3 2.5.0.3)

The independent diagnostic now runs native-only, unchanged Rev4 metadata,
unchanged Rev5 bridge, then a new Rev6 candidate. Each result is finalized
before the cooked oracle starts. The reverse engine and production plugin are
unchanged. Rev6 uses only the run-local reference cache already populated by
Rev5, so it adds no GetPresetData calls and never reads cooked Cue/Part history.

## Evidence used

- The shared 2.5.0.3 API index
  `.reference/ma3/DiDiDo-MA3-Developer-Reference/01_API_Dump/MA3_2.5.0.3/MA3_2.5.0.3_API_INDEX.md:86`
  documents the GetPresetData signature. It does **not** define the returned
  dictionary fields. No definition for `dict_flags.has_absolute`,
  `dict_flags.has_relative`, `gridposmatr`, or raw ValueSource zero encoding
  was found in the shared reference.
- Installed MA3 2.5 system tests
  `help/system_test_helping_functions_db.lua:182-264` define active Phaser
  masks and active value bits (ABS=2, REL=4). Lines 322-335 and 640-671
  distinguish selective/global/universal preset modes, including `pm` 1/2/3.
  Lines 577-578 compare `absolute_value` as a step value independently of
  `absolute`. The tests do not define its encoding.
- `db/system_test_cue_copy_p5.lua` uses `ui_channel_index` as a channel index;
  Rev6 additionally requires it to equal the numeric GetPresetData record key.
- `db/system_test_preset_recipe.lua:343-353` demonstrates that `selective=true`
  is per-fixture data. Rev6 leaves selective member applicability unsafe.
- `db/system_test_prog_xyz.lua:2544-2545` includes an active relative value of
  numeric zero. Thus numeric zero alone cannot prove an un-authored REL layer.

## Candidate proof rules

Every ordinary channel still requires a native Attribute → Feature →
FeatureGroup chain, explicit effective step, and active layer mask. One
effective step with no active motion fields can be static. `pm` 2/3 and a
matching `ui_channel_index` are accepted as metadata; selective mode 1,
individual masks, an active gridpos mask bit 64, and nonempty grid
positions/matrices remain unsafe for
member applicability. `absolute_value` is accepted only when an effective
numeric `absolute` step and active ABS bit independently prove the lane.
`dict_flags.has_absolute/has_relative` lack a direct vendor definition and
are conditionally nonblocking only when their truth agrees with the active
value bit and effective step. A disagreement remains unsafe.

For a Phaser ValueSource, linked Preset metadata must be complete. Raw numeric
zero remains ambiguous even if the ValueSource has an apparently explicit
Layer property selecting the other layer: the local 2.5 reference does not
define that property's semantics or raw zero encoding. A two-step effective
value difference is still distinct from PhaserRecipe structural presence.
The Rev6 bridge promotes motion only after every contributing ValueSource
and linked dependency is complete. These are intentionally conservative
rules; native validation may leave some references unsafe.

The diagnostic reports bounded per-field type/value distributions, variation
across channels and Presets, native evidence class, raw-layer proof states,
ordinary static proof, linked-Preset completeness, Phaser motion proof,
Rev6 final references, and after-the-fact oracle difference. It does not
hardcode the native target or expected references.

Local Lua 5.4 mocks prove the candidate rules, reverse overlap/static
termination, and finalization order. Native correctness is pending.
