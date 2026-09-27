# Rev3 reference semantics audit

Revision: `3_REFERENCE_SEMANTICS_AUDIT`. Same independent diagnostic and deployment directory. Production, pure reverse engine, Rev2 ValueSource proof gates and copied oracle sections remain unchanged.

Native Rev2 showed valid Attribute -> Feature -> FeatureGroup handles, 96 unsafe rows, zero fast GetPresetData calls, and zero references. Layer/effective linked-Preset semantics and ordinary opaque Preset termination remain unresolved. Timing optimization is deliberately deferred.

Rev3 inspects each distinct referenced object once after the immutable Recipe-only result is finalized and before the cooked oracle. It enumerates typed properties on the reference, its actual parent pool, Recipe row, and descendants. It reports direct native object links, getter results separately from enumerated property existence, step and ValueSource parent paths, raw/effective values, Shape handles, Attribute chains and read-only GetDependencies results. Missing APIs remain UNAVAILABLE. Property names/values are evidence, never object-name or pool-number rules.

A pool link is reported as a pool relationship, not proof of the complete stored feature set. Dependency existence does not prove motion. Native-only feature/layer and MOTION_PROVEN/STATIC_PROVEN counts reuse existing complete proof gates; other cases are MOTION_UNPROVEN. No newly observed evidence feeds the primary result in this revision. This audit collects evidence; it cannot establish unreadable semantics before the native run.

Patterns retain exact property values to avoid merging unlike evidence. At most 80 patterns are printed, with at most eight representative Step/ValueSource entries per pattern; fields are capped at 6000 characters, descendant inspection at 512 nodes/depth eight. Summary counts remain complete. Earlier ValueSource logs remain compact. START, final metrics, DIFF, RESULT and END have reserved unbounded summary output. Large reference patterns may require a focused follow-up because detailed fields can truncate.

Optional REFERENCE_METADATA_GETPRESETDATA is not enabled. Count and milliseconds are explicitly zero / NOT_RUN. All GetPresetData remains oracle-only; no Cue/Part fallback is introduced.

Validation: Lua 5.4 deterministic generation, 48 existing semantic/integration checks, and Rev3 audit tests cover getter-default distinction, safe dependencies, observation-only results and conservative classification. Native correctness is pending. Re-import the same standalone XML, select Sequence 3841 / Cue 8, and capture START-END including REFERENCE_SEMANTICS_AUDIT_PROPERTIES / STRUCTURE / STEP and REFERENCE_SEMANTICS_SUMMARY. Do not integrate into production before native multi-Cue validation.
