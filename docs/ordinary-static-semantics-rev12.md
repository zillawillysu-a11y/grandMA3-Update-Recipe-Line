# Rev12 ordinary Preset static semantics

The Rev12 diagnostic observes cached, UI-channel-indexed `GetPresetData` for ordinary Presets only. It does not change production, Rev7 metadata gates, the Rev7 result, or the cooked oracle.

## Existing evidence and minimum static proof

The installed grandMA3 2.5 vendor system tests cited in `cue-wide-recipe-field-semantics-rev6.md` define `mask_active_phaser` as the active Phaser mask and `mask_active_value` bits 2/4 as ABS/REL. The same evidence uses the effective `absolute` step and identifies Preset modes 1/2/3 as Selective/Global/Universal. The observer requires, for every UI channel:

- an integer active Phaser mask with no non-grid timing/motion or opaque Preset dependency bits, an integer active-value mask containing only ABS/REL bits, and exactly one contiguous effective step;
- every active ABS/REL bit to have a finite effective numeric step value, with no extra effective layer;
- no active generator, dependency, timing, release, remove, or unknown step/Phaser field that could hide motion;
- consistent record count and UI channel identity, when those fields exist.

The proof is per reference and fails closed if any channel fails. `mask_active_value == 2` plus a numeric `absolute` step proves an ABS value lane under the vendor mask semantics. Numeric `absolute_value` can be ignored for motion only when that independent ABS evidence exists; its encoding is not presumed. An active `dict_flags.has_absolute` does not create motion when the mask and effective step already prove the lane. Other active unknown dictionary flags still block the observer.

## Rev12.1 correction after native Cue 8

Rev12 native result: Rev7 remains EXACT_MATCH with four refs, missing=0, extra=0, 50 unsafe rows, 19 final surviving, 31 fully superseded, unknown=0. The Rev12 observer reported 15 ordinary refs, only two static proven, and zero eligible rows. The principal false blocker was `ACTIVE_PHASER_MASK_NOT_ZERO` on mask 64. Selective ordinary Presets also acquired `UNKNOWN_ACTIVE_DICTIONARY_FLAG_selective` as a motion blocker.

The installed 2.5 `GetPhaserMask` and `PhaserMaskToList` define bit 64 as `gridpos`, bits 4/8/16/32/128/256 as fade/delay/speed/phase/measure/nshot, and bits 1/2 as Preset dependencies. Rev12.1 moves bit 64 to member applicability, blocks the known non-grid timing/motion bits for static proof, and fails closed on unmapped bits. Preset dependency bits remain static-proof blockers. `dict_flags.selective`, `selective`, `pm`, `preset_store_mode`, `mask_individual`, `gridpos`, and `gridposmatr` are evaluated separately for member applicability. A Selective Preset can report `motion_static_proven=true` and `member_applicability_proven=false`.

The diagnostic alternate Rev7 run requires both proofs, plus the existing Feature and Layer evidence. Nonempty grid-position/matrix evidence is not silently excused. Rev12.1 native Cue 8 counts and performance are pending.

The alternate result clones Rev7 rows, promotes only eligible proven ordinary references to static terminators, and reruns the reverse resolver on the clones. It reports oracle missing/extra and unsafe attribution separately. The baseline Rev7 rows and result remain untouched. If any of the 18 rows fail, the separate motion/member blocking reasons identify the missing evidence.
