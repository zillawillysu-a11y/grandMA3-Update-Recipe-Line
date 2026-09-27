# Rev4 Recipe reference metadata cache

Revision: `4_REFERENCE_METADATA_CACHE`; grandMA3 target 2.5.0.3. Standalone diagnostic only. Production is untouched, marker flag is false, no marker drawing or waits, and main is not merged.

Native Rev3: 10 Cues, 31 Parts, 96 Recipe rows, 17 Groups, 25 distinct references (15 opaque ordinary Presets / 10 ValueSource references). Native feature proof succeeded for 10, layer/motion/static proof for zero. Recipe-only refs=0, oracle refs=4, missing=4. No runtime rule uses these counts, object IDs, names or validation target.

## Three isolated stages

1. Existing native-only proof gates run with zero GetPresetData calls. The result is copied into NATIVE_ONLY_FINAL and NATIVE_ONLY_FINALIZED before the metadata factory/cache exists. Native proof adapter and membership engine remain unchanged.
2. Recipe row references are registered in a fresh run-local allowlist. Each stable identity is read at most once with GetPresetData(reference, false, false): all stored reference phasers, UI-channel indexing. COMPLETE/PARTIAL/UNKNOWN metadata is cached, including failed reads. Repeated row requests are hits. Independent row copies feed the same recipeReverseResolve engine newest to oldest. METADATA_REVERSE_FINALIZED freezes the active identity set.
3. Only then ORACLE_START enables the unchanged copied cooked oracle. It compares both finalized sets; it cannot supply or repair metadata. No Cue/Part cooked fallback exists in either primary path.

## Identity / target guard

The 2.5 API dump documents HandleToInt integer handles and HandleToStr H#... native handles. The cache prefers a nonzero Lua integer identity, then a validated H# hex handle string. Display names, command addresses, pool/index strings and tostring(table pointers) are rejected. CompareHandle and native integer equality also identify aliases in the shared set-identity helper. No identity means UNKNOWN and zero reads; unresolved handles are counted as observations rather than used as DB cache keys.

Only registered Recipe reference identities in Preset / Generator / RandomGenerator classes are eligible. Cue, Part, CuePart and Sequence targets raise a diagnostic error before any native call. Unregistered Presets are rejected. The runtime read wrapper independently checks phase, class and Recipe allowlist. Each actual call prints target class and DB identity. Generator GetPresetData behavior still requires native verification; unreadable returns remain unsafe.

## Defensive normalization

Accept the observed API family of numeric UI-channel keys with table phasers and numeric step children; tolerate documented count/by_fixtures headers, verify count consistency and require UI-oriented data. Unknown shapes/fields, wrong types, unreadable Attributes, sparse steps, opaque value-less dependencies, remove semantics and mixed layer/motion patterns remain unsafe.

Feature scope comes from the record's typed Attribute handle or GetAttributeByUIChannel(actual record index), then native Attribute.Feature and Feature:Parent() with class-checked FeatureGroup and stable identity. No label or pool-number decisions. Bounded handle-chain evidence is logged. No full channel enumeration is performed: only indices returned in the referenced object's data are visited.

ABS/REL come from finite numeric step.absolute / step.relative values or explicit boolean abs_release / rel_release. Numeric zero is present; missing values never default to ABS. Supported complete release-only data terminates the appropriate layer; remove and mixed release steps remain unsafe. More than one effective numeric step proves a moving layer; a complete one-step layer is static. Shape, phase or speed presence alone never proves motion. Typed Generator dependencies/classes can prove generator classification only with complete exposed layer data. Linked Preset records without complete effective values remain unsafe, with no recursive cooked read.

Lanes retain per-feature/per-layer motion, avoiding an ABS/REL Cartesian-product error. Contradictory static/moving records inside one feature/layer are PARTIAL. Unknown feature or layer scope blocks older assertions conservatively via the existing engine. COMPLETE is the parser's supported-schema classification, not native correctness or universal fixture coverage acceptance.

## Membership and timing

Same Stored Group sf_index member sets are reused without converting fixture/subfixture/cell IDs. Native rows, metadata rows and results are separate. Overlap, partial overlap, static termination and re-source still resolve membership before reference identity collapse.

Cache timing covers allowlist registration, reference reads/normalization and preparation of metadata rows. Reverse timing covers the second pure engine run. TOTAL_METADATA_PATH_ELAPSED_MS sums that path; it excludes native-only history/group preparation and all Rev3 audit/logging. Shared history/member counts are reported, not remeasured or misrepresented as a fresh history scan. Native read count/total/average/max and normalization time are separate. Missing clocks print UNVERIFIED. Cache exists only in this invocation; no ShowData, file writes or persistent invalidation.

## Validation / native run

Full Lua 5.4 suite: 17 engine checks, 176 integration checks, 42 metadata checks and 6 Rev3 audit assertions. Tests cover the requested identity aliases, 100 rows/one read, forbidden target classes, failed reads, missing identity, static termination, overlap, re-source, independent features/layers, unsafe barriers, member identity and finalization order. Build deterministic; original oracle sections match production source; production marker flag false; XML manifest and referenced component present; git diff --check passes. Independent deployer verifies Lua/XML hashes and snapshots the production folder before/after without writing it.

Standalone XML remains `C:\ProgramData\MALightingTechnology\gma3_library\datapools\plugins\Cue-wide Recipe Reverse Resolver AB 2.5.0.3\cue_wide_recipe_reverse_resolver_ab_2_5_0_3.xml`.

Re-import, select the requested native validation Cue, verify START revision, capture NATIVE_ONLY_FINAL, REFERENCE_METADATA_CACHE, REFERENCE_METADATA_NORMALIZED, METADATA_REVERSE, METADATA_REVERSE_FINAL, ORACLE_START/FINAL, both DIFFs, RESULT and END. Exact identity equality alone never hides unsafe/completeness counters. No native exact match or latency acceptance is claimed.

REAL-WORLD VALIDATION PENDING
