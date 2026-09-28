# Rev12 ordinary Preset static semantics

The Rev12 diagnostic observes cached, UI-channel-indexed `GetPresetData` for ordinary Presets only. It does not change production, Rev7 metadata gates, the Rev7 result, or the cooked oracle. The native Cue 8 result is still pending.

## Existing evidence and minimum static proof

The installed grandMA3 2.5 vendor system tests cited in `cue-wide-recipe-field-semantics-rev6.md` define `mask_active_phaser` as the active Phaser mask and `mask_active_value` bits 2/4 as ABS/REL. The same evidence uses the effective `absolute` step and identifies Preset modes 1/2/3 as Selective/Global/Universal. The observer requires, for every UI channel:

- `mask_active_phaser == 0`, an integer active-value mask containing only ABS/REL bits, and exactly one contiguous effective step;
- every active ABS/REL bit to have a finite effective numeric step value, with no extra effective layer;
- no active generator, dependency, timing, release, remove, or unknown step/Phaser field that could hide motion;
- consistent record count and UI channel identity, when those fields exist.

The proof is per reference and fails closed if any channel fails. `mask_active_value == 2` plus a numeric `absolute` step proves an ABS value lane under the vendor mask semantics. Numeric `absolute_value` can be ignored for motion only when that independent ABS evidence exists; its encoding is not presumed. An active `dict_flags.has_absolute` does not create motion when the mask and effective step already prove the lane. Other active unknown dictionary flags still block the observer.

`gridpos` and `gridposmatr` affect which members receive a value. They do not by themselves demonstrate movement. `selective`, `pm`, `preset_store_mode`, and `mask_individual` are kept separate from motion. A Selective Preset may therefore report `static_proven=true`, while its member mapping remains unsafe. Only Global/Universal mode with no Selective or individual marker is eligible for the diagnostic alternate Rev7 run. The existing Rev11 linked Preset member rule supplies that eligibility; this observer does not invent a new membership rule.

The alternate result clones Rev7 rows, promotes only eligible proven ordinary references to static terminators, and reruns the reverse resolver on the clones. It reports oracle missing/extra and unsafe attribution separately. The baseline Rev7 rows and result remain untouched. The native run must establish the actual count and time overhead. If any of the 18 rows fail the static proof, `blocking_reasons` identifies the missing semantic or shape evidence.
