# Child Enumeration Probe — grandMA3 2.5.0.3

## Scope

Track B only: generic Pool direct-child enumeration. Native run complete; see native evidence below. Production unchanged; Track A paused. Production uiChildren() (RecipeTracking_Inspector.lua:1633) chooses any successful UIChildren table, including empty, falling back to Children only for non-table/error. This is a code risk, not a confirmed native defect.

## Native steps

1. On 2.5.0.3 show Generator, Group, Preset and Phaser pools where available. Ordinary visible tiles suffice; 103/104 are not required.
2. Import child_enumeration_probe_2_5_0_3.xml from C:/ProgramData/MALightingTechnology/gma3_library/datapools/plugins/Child Enumeration Probe 2.5.0.3.
3. Press **Child Enumeration Probe 2.5.0.3** once.
4. Copy Command Line History from [ChildEnum] START to [ChildEnum] END, including API errors. Confirm GRID records cover desired pools. If a desired pool is not located, rerun with that window alone. Absence from this limited locator proves nothing about child enumeration.

No Recall, lifecycle comparison or marker drawing.

## Evidence

GRID logs pool type/class/name, handle/class/address/native and raw IsActuallyVisible/IsVisible/Visible. Unknown visibility is UNVERIFIED. UI-only APIs require UIObject derivation; database objects are never UI traversal nodes.

PATH independently records UIChildren(), Children(), GetUIChildrenCount()/GetUIChild(index), and Count()/Ptr(index): count, inspected count, first six classes, unique usable AllPoolButton count, first eight ObjectIndex samples, success/completeness and errors.

Usable sets are valid AllPoolButton-derived UI widgets with positive ObjectIndex and available HandleToStr identity; PoolTitleButton is excluded. Comparison uses widget token plus ObjectIndex within the same grid. Order and extra non-button children do not create mismatch. This focuses on AllPoolButton, not every possible production button subclass. No database target resolution or CompareHandle test.

RESULT emulates production: any returned UIChildren table wins, including empty; otherwise choose Children. production_would_miss=true requires a complete selected path and a button actually exposed by another path that the selected set lacks. False requires all paths complete. Missing evidence stays UNAVAILABLE.

## Classifications

- CHILD_PATHS_AGREE: all four paths complete, equivalent usable sets, at least one usable button.
- EMPTY_UICHILDREN_FALLBACK_NEEDED: complete empty UIChildren table and an alternative exposes usable buttons. Presence suffices even if another alternative is incomplete.
- CHILD_PATH_MISMATCH: complete UIChildren and an alternative expose different usable sets. Inspect production_would_miss separately; a smaller alternative does not imply production misses buttons.
- UNVERIFIED: unknown visibility, unavailable/incomplete paths, all-zero usable sets or bounded inspection.

Established locator checks displays 1–7, the proven grid address, first native AllPoolLayoutGrid matches and nearby sibling windows. Maximum 16 grids; not exhaustive. No whole-tree scan or discovery-budget fix. Maximum 512 entries inspected per child path; larger counts logged as incomplete. Protected reads bounded per grid. Limits cannot prove child absence beyond inspected entries.

## Safety / validation

Only Printf output. No Show, Sequence, Cue, Recipe, Programmer, playback or UI writes; no commands, hooks, background work, GetPresetData, ObjectList, CompareHandle or production cache changes. Exact target 2.5.0.3.

Sources: [Lua](../diagnostics/Child_Enumeration_Probe_2_5_0_3.lua), [XML](../diagnostics/child_enumeration_probe_2_5_0_3.xml), [mocks](../tests/child_enumeration_probe.lua), [runner](../tools/run_child_enumeration_probe.py).

21 offline assertions cover agreement, empty-table fallback, differing sets, production choice, unavailable paths, visibility rejection, generic Group/Preset/Phaser, 214-child grids, database UI guards, incomplete indexed reads, bounds and version rejection. Native evidence is required before changing production fallback.

## Deployment verification

Actual isolated Lua/XML copy completed. Source and deployed XML/Lua parse PASS; component exists; forbidden-call check PASS. Production directory SHA256 snapshot unchanged (3 files); production source equals HEAD after Git filtering. 21 probe mock assertions and 86 existing workflow assertions PASS. Native evidence subsequently received below.

- Child_Enumeration_Probe_2_5_0_3.lua: source/deployed SHA256 MATCH `f35a92e2c9e1fca0d0a9e9447e5b3550d5ead108a92000ecc1c9d31739fc89d0`.
- child_enumeration_probe_2_5_0_3.xml: source/deployed SHA256 MATCH `7efd429a512829cc7d3adbe3d3686750bb1ad09de7e34775d900c5f3a27676ac`.

## Native evidence: larger Show

User reports 12 visible Pool grids tested on 2.5.0.3. All returned CHILD_PATHS_AGREE and production_would_miss=false. Preset, Group, Sequence and GeneratorRandom exposed equivalent usable AllPoolButtons through all paths. Empty-UIChildren fallback hypothesis is downgraded: not reproduced in this Show. No production fallback change follows; this does not establish agreement in every Show.

Separate observation only: GeneratorRandom exposed 17 buttons per path; initial ObjectIndex samples were 4294967296. This was another Show with Generator 103/104 empty. The value may represent empty/unassigned tiles; it is not evidence of a Generator bug or generic marker root cause. Target resolution was outside this experiment, and no investigation of this value is performed. Path agreement remains valid.
