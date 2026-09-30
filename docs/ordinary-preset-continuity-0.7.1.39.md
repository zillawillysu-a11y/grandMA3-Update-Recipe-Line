# v0.7.1.39 ordinary Preset continuity

User confirms v38 Cue delta concept but reports ordinary Presets go dark before returning. Diagnosis: INCONCLUSIVE publication adds independently proven stage references, while its continuity snapshot stored only old candidate references. Ordinary inherited Presets first discovered by background proof were visible but absent from the next Cue baseline.

Regression was reproduced before modifying runtime: inherited static Dimmer and moving Position Presets beside an unrelated unresolved reference are published after partial proof, then disappear from the adjacent next Cue preview. The test failed on v38.

The snapshot now stores proven group/lane contributions for both PROVEN and INCONCLUSIVE results. Independently proven ordinary, structural Phaser and Generator references join unresolved non-excluded candidates. Known lanes become fixed baseline scopes; unresolved rows are retained without overwriting those scopes. Explicit exclusions still remove dead refs. v38 cold/current-only preview, same-Group/layer replacement, shared Group/layer protection, bounded background resolver, selection and write safety are preserved. No Phaser parser change or Show mutation.

Validation: 89 workflow assertions, 266 Track A checks, 269 extended probe checks. Regression includes static and moving ordinary references plus Generator, actual Pool overlay identity preserved across the preview render, and later same-Group ordinary replacement while unrelated references remain. All pass after the change. Lua/XML parsing, generated runtime consistency and diff whitespace checks pass; source diff reviewed.

Deployment: manifest and both referenced Lua files copied to local Update Plugin, all SHA256 values match. Backup: C:/tmp/update-plugin-pre-0.7.1.39. REAL-WORLD VALIDATION PENDING; mocked overlay continuity cannot prove native UI timing.
