# Cue-wide Recipe Reverse Resolver A/B 2.5.0.3

Independent read-only experiment. Production remains dormant and unchanged. The
previous cooked footprint optimization is paused. No merge to main.

## Supported authoring contract

Cue state is authored through Recipe rows using Stored Groups and referenced
Presets, Phasers, Generators or equivalent objects. Arbitrary manual Cue values
are outside the supported product model. Structurally unreadable cases are
unsupported/unsafe; they must never silently trigger a cooked-history fallback.
The intended production architecture is Recipe/Group reverse tracking, subject
to successful native multi-Cue validation. Cooked machinery in this artifact is
only an after-the-fact correctness oracle.

## Algorithm and identity

Cues, Parts and Recipe indices are visited newest first. Each Stored Group is
expanded once per invocation into a set of native `sf_index` identities. This
preserves distinct subfixtures/cells represented by those indices; it never
collapses membership to a parent fixture or Group identity. Native cell coverage
still requires tests with actual cell Groups. No cache persists between runs, so
Group/Recipe edits and deletions are observed on the next invocation.

For each member + feature + layer, the first safe Recipe decides its assignment.
Moving references survive if any member remains. Static rows resolve members
without adding a moving reference. Newer overlap only covers shared members.
References are deduplicated after occurrence-specific membership resolution.
Unknown newer selections block historical claims globally; unknown feature or
layer evidence blocks the corresponding member scope. Known newer assignments
are preserved. Symbolic unresolved lanes use `*` where exact scope is unreadable.

History is exhausted rather than stopped early: the full relevant member universe
is not known until the object-tree traversal completes. This performs no cooked
channel enumeration, UI-channel expansion, waits, markers or 32-record batching.
The private GetPresetData wrapper raises if the fast path attempts a read.

## Structural evidence audit and current limits

The existing `recipeReferenceFeatures` helper includes label/address text hints
and broad `all` expansion. The fast path does **not** call it. It reuses only the
numbered standard Preset-family mapping. Phaser Value Source / Generator channel
Attribute identifiers are recognized by exact tokens; unknown identifiers or
unassigned/all channels are unsafe. User-authored object names never infer scope.
Family-level resolution follows the requested algorithm; attribute-level
replacements within one family need native validation before integration.

Native object properties are enumerated through `PropertyCount`/`PropertyName`,
which are present in the shared 2.5.0.3 API dump. An explicitly advertised Layer
value of Absolute/Relative is required on the Recipe or every relevant source.
There is no assumed absolute default. These per-object Layer exposures have not
yet been demonstrated in the target Show; missing exposure is reported unsafe.
Mixed feature/layer associations that would require a Cartesian-product guess
are rejected unless an explicit Recipe layer scopes the whole row.

Motion is established by Generator class, or one structurally exposed Phaser
Recipe with multiple step objects. One exposed step with readable sources is a
static terminator. Ordinary opaque Presets, multiple nested Phaser Recipes and
equivalent objects whose motion cannot be read are UNVERIFIED. An ordinary
Preset's pool alone does not prove it static. No GetPresetData is used to decide
these cases. Native metadata printed in UNSAFE records is evidence for the next
bounded structural improvement; it is not an API claim.

No source means `FAST_PATH_UNSAFE_NON_RECIPE_DATA` for an oracle-only identity;
the exact member/feature/layer remains UNVERIFIED rather than guessed. A missing
reference with Recipe sources prints those Groups and their members, feature,
layer, unsafe reason and newer superseding Recipe. The oracle never repairs or
widens the finalized fast result.

## Reports and interpretation

`FAST_FINALIZED` precedes any oracle read. Metrics include walked Cues/Parts,
inspected rows (including disabled rows), resolved Groups, expansion count,
resolved lanes, empty effective rows, static terminators, contributing moving
rows, unsafe rows, symbolic unresolved lanes and unknown-selection rows. ACTIVE
and SOURCE show unique surviving members and source Cue/Part/Recipe/Group.
FIRST_NEWER reports the first newer decider for each rejected overlap. DIFF
prints exact missing/extra identity sets and available member attribution.

All requested classifications are supported, including simultaneous unsafe and
identity-match statuses. EXACT_MATCH proves only this snapshot's identity set;
an exact match with unsafe rows does not establish a safe architecture. Final
production eligibility is deliberately false until native multi-Cue validation.
Oracle replay uses the same unchanged `refreshCueEffects` pipeline as the
existing Structural A/B diagnostic, including current-Cue merge and recovery.
The oracle's own cooked batching is confined to this last phase.

## Validation and native run

Run `python tools/build_cue_wide_recipe_reverse_ab.py`, then
`python tools/run_cue_wide_recipe_reverse_ab.py`. The runner checks Lua 5.4,
deterministic generation, unchanged production oracle sections, the disabled
production flag, membership semantic mocks and full diagnostic mocks.
`python tools/deploy_cue_wide_recipe_reverse_ab.py` validates XML/components/Lua,
copies only the two independent runtime files, compares deployed SHA256 and
checks that production source and deployed production folder stayed unchanged.

Import `cue_wide_recipe_reverse_resolver_ab_2_5_0_3.xml` from the separate
`Cue-wide Recipe Reverse Resolver AB 2.5.0.3` plugin folder. Select Sequence 3841
and Current Cue 8, then run the plugin and capture START through END. The observed
cooked result has four references, but neither the count nor identities are
hardcoded. Required native result: same identity set with fast GetPresetData
calls zero. Report unsafe structure even when identity sets match. Then test
multiple Cues, Group overlaps, static replacements, re-sources and actual cells
before considering integration. REAL-WORLD VALIDATION PENDING.
