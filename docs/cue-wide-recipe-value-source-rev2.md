# Recipe Reverse A/B Rev2 — native ValueSource evidence

Production is unchanged. This revision addresses the native Rev1 failure on
Sequence 3841 / Cue 8: all four cooked references were missing despite valid
Stored Groups and concrete memberships. Their ValueSources exposed Attributes,
Preset, RawValueAbs/Rel and Shape. Rev1 stringified Attribute handles and required
a Layer property that these objects did not expose. It also sent numeric varargs
to native Printf and printed one unresolved record for every member.

## Evidence actually checked

The read-only shared 2.5.0.3 API dump establishes `Get` without a role can return
an object handle, whereas role-based Get returns text. PropertyCount/Name/Type/Info,
ObjectList and Parent are present. The dump's object tree establishes the Phaser
Recipe / Steps / Step / ValueSource and Feature / FeatureGroup classes; it is not
a complete property schema. The installed MA 2.5 vendor files below supply the
property semantics missing from the tree. These are source-code observations,
not claims that vendor tests were run on the user's Show.

Read-only vendor root:
`C:/ProgramData/MALightingTechnology/gma3_2.5.0/shared/resource/`

- `lib_plugins/systemtests/db/system_test_phaser_recipe_shapes.lua:22–43` stores
  two steps, asserts two native Step objects, compares `.Attributes` directly
  with an Attribute handle and checks `.ValueAbsolute` numerically.
- `lib_plugins/systemtests/ui/system_test_ui_misc.lua:188–189` reads
  `GetSelectedAttribute().Feature:Parent()` as the selected FeatureGroup and
  `.Feature` as its Feature. Rev2 validates both native classes and resolves by
  handle identity; it never uses the labels accessed by that vendor UI test.
- `lib_menus/ui/setup/grid_context_numeric_keypad_values.lua:6–10` maps
  VALUEABSOLUTE to RawValueAbs and VALUERELATIVE to RawValueRel. Its special-value
  setter and adjacent uixml expose None, Release, Remove and other specials.
- `lib_plugins/systemtests/db/system_test_phaser_recipe_basic.lua:68–115`
  demonstrates that assigning Presets at a ValueSource changes effective step
  values. Therefore a RawValueAbs field alone is not sufficient when a Preset
  dependency is present; Rev2 also requires a numeric effective ValueAbsolute
  (or ValueRelative for a relative lane).
- `lib_menus/ui/popups/phaser_editor_value_source_popup.lua:7–10,41–52`
  lists actual ValueSource handles inside Shape steps for assignment. This proves
  a source link can be an exact ValueSource, not just a Shape pool object.
- `lib_shapes/default_shapes.xml` supplies numeric RawValueAbs and RawValueRel
  examples inside separate Step objects. This file ships with 2.5 but has an older
  DataVersion, so it corroborates the keypad mapping rather than proving it alone.
- The 2.5 API enums include PhaserRecipeValueSpecialsRaw. Only the native enum's
  own mapping is consumed for numeric None; other special encodings remain unsafe.

The official [Recipe Editor](https://help.malighting.com/grandMA3/2.5/HTML/recipe-sheet.html)
describes absolute and relative cells, None as no applied value, and local values
overriding values inherited from Shape. The URL is 2.5, but the retrieved body
labels itself 2.4; Rev2 uses the installed 2.5 vendor code above as the primary
version evidence. The [Shapes](https://help.malighting.com/grandMA3/2.5/HTML/shapes.html)
page describes per-step absolute and relative authoring. Neither document is an
API guarantee that an opaque Preset exposes all its cooked content structurally.

## Consumed supported subset

Read each advertised native property without string conversion. Accept a direct
Attribute handle, or resolve an exact numeric command identity such as
`Attribute 1` via ObjectList and verify the unique result has class Attribute.
Attribute 1 is never mapped to Dimmer by number. Follow `.Feature` to a Feature
handle and its parent to FeatureGroup. The family lane uses the FeatureGroup's
database identity. Attribute, Feature and FeatureGroup paths are printed for
inspection; their names do not determine any result.

Numeric authored RawValueAbs/RawValueRel cells establish the corresponding lane
through the vendor keypad mapping. Zero is a value. Empty cells can inherit only
from an exact linked ValueSource; explicit None suppresses that lane and does not
inherit. A linked Shape object's existence, class or label cannot imply motion.
The exact source chain is traversed with cycle/depth guards, without importing
its siblings or treating the linked source's parent step count as local motion.
Unresolved Shape links and Shape links with Preset dependencies stay unsafe.

For Preset-linked sources, numeric effective ValueAbsolute/ValueRelative metadata
must corroborate the numeric raw layer; otherwise the lane is unsafe. A source
with a single step and an opaque Preset dependency cannot prove static motion.
Generator class establishes its type, but does not prove channel layer semantics;
Generator lanes stay unsafe in Rev2. Equivalent opaque references also stay unsafe.

For one fully exposed PhaserRecipe, count distinct authored Step objects per
Attribute + layer. More than one establishes the diagnostic's moving-reference
classification; one establishes a static lane only without an opaque Preset
dependency. A family containing conflicting per-Attribute motion is unsafe.
Multiple nested Recipes, unreadable children, unknown Attribute handles, special
Release/Remove/raw encodings and incomplete effective layers remain unsafe.
An unverified `Layer` property is printed but never overrides these proof gates.

Only complete supported evidence is handed to the membership resolver. Each lane
retains its source's actual feature/layer association; it cannot form a cross
product from row-wide feature/layer unions. A reference is published only if at
least one moving-lane member survives. Static lanes can terminate history without
publishing a reference. Unknown newer rows remain conservative barriers.

`PROVEN_SUPPORTED_SUBSET` identifies rules backed by these sources and satisfied
by the native structure inspected. It is not a claim of successful native Cue
validation. Ordinary opaque Presets remain unverified; no cooked reads are added
to learn their missing semantics. Actual fixture/subfixture/cell inheritance and
partial attribute availability require separate native acceptance before production.

## Output and Printf correction

The private Printf bridge formats in Lua and calls native Printf with `%s` plus
one string. It covers the copied oracle logs as well as Rev2's own records.
Mocks reject numeric native varargs, reproducing the former binding limitation.
False values remain `false`, so motion status cannot vanish as UNAVAILABLE.

VALUE_SOURCE_AUDIT emits one representative per distinct structural pattern,
with an occurrence count. It includes Recipe, Group, reference/native classes,
ValueSource, exact Attributes property, raw type/value, resolved Attribute path,
Feature/FeatureGroup, raw/effective layers, Shape/source chain, Preset/dependency
metadata, any Layer, proposed interpretation, proof and unsafe reasons. Numeric
value differences are grouped as one numeric pattern. At most 120 audit patterns
are printed; omitted pattern count is explicit and does not alter resolution.

UNRESOLVED is aggregated by source Recipe/Group + feature/layer, with total member
count and five sorted member samples. DIFF_LANE is similarly grouped by newer
Recipe and lane. No per-member lines are emitted. General details have a 500-line
budget, DIFF attribution a separate 150-line budget and copied oracle trace 40
lines. Essential identity snapshots and START, FAST_PATH_METRICS, summaries,
DIFF, RESULT and END bypass these budgets. Identity snapshot detail is capped at
128 refs with explicit omission counts; comparison sets and counts stay exact.
The resulting output is bounded below DumpLog /Limit=3000 even during detail floods.

## Run and acceptance

Use the existing build, test and independent deploy scripts. Import the refreshed
standalone XML from the `Cue-wide Recipe Reverse Resolver AB 2.5.0.3` folder.
The START line must contain `revision=2_VALUE_SOURCE_AUDIT`. Select Sequence 3841
/ Cue 8 and capture START through END. Compare the Recipe-only set with the last
oracle set; the previous observed oracle identities are not embedded in code.
Required fast calls: zero. If matching fails, inspect VALUE_SOURCE_AUDIT and
DIFF_SOURCE/DIFF_LANE; do not broaden into cooked history. Production remains
untouched until native multi-Cue validation. REAL-WORLD VALIDATION PENDING.
