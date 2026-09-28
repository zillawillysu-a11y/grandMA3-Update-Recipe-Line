-- Show candidate checks: canonical member identity, multi-group matcher,
-- proven resolver and marker sources. Offline only; on-console testing still
-- required. Runs after tests/recipe_workflow.lua via tools/run_workflow.py.
local signals = {}
local main = assert(loadfile("RecipeTracking_Inspector.lua"))(nil, nil, signals, {})
local functions, seen = {}, {}
local function collect(fn)
    if seen[fn] then return end
    seen[fn] = true
    for index = 1, 200 do
        local name, value = debug.getupvalue(fn, index)
        if not name then break end
        if type(value) == "function" then functions[name] = value; collect(value) end
    end
end
collect(main)
for _, fn in pairs(signals) do collect(fn) end
local count = 0
local function check(value, message)
    assert(value, message)
    count = count + 1
end
local function object(kind, addr, fields, contents)
    local result = fields or {}
    result.GetClass = function() return kind end
    result.ToAddr = function() return addr end
    result.Children = function() return contents or {} end
    return setmetatable(result, { __tostring = function() return addr end })
end

local subfixtureByIndex = {
    [101] = object("SubFixture", "Fixture 101"),
    [201] = object("Fixture", "Fixture 201"),
    [202] = object("SubFixture", "Fixture 201.1"),
    [203] = object("SubFixture", "Fixture 201.1.1"),
}
_G.GetSubfixture = function(index) return subfixtureByIndex[tonumber(index)] end
_G.ObjectList = function(addr)
    local found = {}
    for _, handle in pairs(subfixtureByIndex) do
        if handle:ToAddr() == addr then found[#found + 1] = handle end
    end
    return found
end
local function selectedFixture(index)
    return { index = index, handle = subfixtureByIndex[index], grid = { x = 0, y = 0, z = 0 } }
end
local cellGroup = object("Group", "Group 3", {Name = "Cells", Selection = {{sf_index = 203}}})
local parentGroup = object("Group", "Group 4", {Name = "Parent", Selection = {{sf_index = 201}}})
local mixedGroup = object("Group", "Group 5", {Name = "Mixed", Selection = {{sf_index = 101}, {sf_index = 203}}})
local groupPool = {}
groupPool.Children = function() return { mixedGroup, parentGroup, cellGroup } end
_G.DataPool = function() return { Groups = groupPool } end
local hookState = {}
functions.recipePoolReferences(hookState)
local provenApi = hookState.provenHooks
assert(type(provenApi) == "table", "proven hook table must be attached")

-- 1. canonical member keys for Fixture / SubFixture / nested Cell.
check(provenApi.canonicalMemberKey(selectedFixture(101)) == "101", "fixture key must be 101")
check(provenApi.canonicalMemberKey(selectedFixture(202)) == "201.1", "subfixture key must be 201.1")
check(provenApi.canonicalMemberKey(selectedFixture(203)) == "201.1.1", "cell key must be 201.1.1")
check(provenApi.canonicalMemberKey({ index = 1 }) == nil, "missing handle must fail closed")
check(provenApi.canonicalMemberKey(object("Group", "Group 1")) == nil, "non-Fixture address must fail closed")
check(provenApi.canonicalMemberKey(object("SubFixture", "Fixture 201.")) == nil, "trailing dot must fail closed")
local forged = object("SubFixture", "Fixture 201.1")
check(provenApi.canonicalMemberKey(forged) == nil, "address text without the native handle round-trip must fail closed")

-- 2-3. child-only and nested-cell exact matches.
check(provenApi.relation(cellGroup, { selectedFixture(203) }) == "EXACT_COMPLETE",
    "child-only Group must match exactly")
local relSel, selKeys, grpKeys = provenApi.relation(mixedGroup, { selectedFixture(101), selectedFixture(203) })
check(relSel == "EXACT_COMPLETE" and selKeys["101"] and grpKeys["201.1.1"], "mixed Group must match exactly")

-- 4-5. parent/child identities never collapse.
check(provenApi.relation(cellGroup, { selectedFixture(201) }) == "DISJOINT",
    "parent selection must not satisfy child-only Group")
check(provenApi.relation(parentGroup, { selectedFixture(203) }) == "DISJOINT",
    "child selection must not collapse to parent Group")

-- 6-9. multiple complete Groups, partial exclusion, deterministic order.
local both = provenApi.completeGroups({ selectedFixture(201), selectedFixture(203) })
check(#both == 2 and both[1] == cellGroup and both[2] == parentGroup,
    "selection containing two complete Groups must return both sorted")
local partial = provenApi.completeGroups({ selectedFixture(101) })
for _, found in ipairs(partial) do check(found ~= mixedGroup, "partial Group must not be admitted") end
check(provenApi.relation(mixedGroup, { selectedFixture(101) }) == "PARTIAL",
    "fragment of a Group is PARTIAL, not complete")

-- 10. currentGroup compatibility: matcher is pure, existing assignment untouched.
local compatState = { currentGroup = parentGroup, provenEnabled = true }
functions.recipePoolReferences(compatState)
check(compatState.currentGroup == parentGroup, "currentGroup compatibility must not be overwritten")

-- Resolver fixtures: one cue, one part, standard recipes.
local showPreset = object("Preset", "Preset 1.1 Dimmer", {Name = "Show"})
local showPhaser = object("PhaserRecipe", "Preset 25.2 Dimmer", {Name = "Mover"})
local genChannels = object("RandomChannels", "Generator 1 Channels", {},
    { object("Channel", "Generator 1 Channel 1") })
local showGenerator = object("Generator", "Generator 1", {Name = "Gen"}, { genChannels })
local showGroup = object("Group", "Group 6", {Name = "Show", Selection = {{sf_index = 101}}})
groupPool.Children = function() return { mixedGroup, parentGroup, cellGroup, showGroup } end
local function showTree(recipes)
    local showPart = object("Part", "Part 0", {Part = 0}, recipes)
    local showCue = object("Cue", "Cue 1", {No = 1000, Name = "One"}, {showPart})
    return object("Sequence", "Sequence 9", {}, {showCue}), showCue
end
local function showRecipe(ref, values, index)
    return object("Recipe", "R" .. index, {Index = index, Selection = ref, Values = values})
end
local showSeq, showCue = showTree({ showRecipe(showGroup, showPreset, 1) })
local showInfo = { feature = "Dimmer" }
local showFixtures = { selectedFixture(101) }
local function markerState(seq, cue, groups, fixtures)
    return { currentSequence = seq, currentCue = cue, currentGroups = groups,
        lastFixtures = fixtures, lastFeature = "Dimmer", provenEnabled = true }
end

-- 17. Global ordinary proven path.
local proven = provenApi.sources(showSeq, showCue, showFixtures, showInfo)
check(proven.classification == "PROVEN" and proven.refs["Preset 1.1 Dimmer"] == showPreset,
    "ordinary Preset row must resolve")

-- 11-14. marker sources include Group, Preset, Phaser and Generator tiles.
local markerRefs = functions.recipePoolReferences(markerState(showSeq, showCue, { showGroup }, showFixtures))
check(markerRefs["Group 6"] == showGroup, "matched Group tile must pulse")
check(markerRefs["Preset 1.1 Dimmer"] == showPreset, "surviving Preset tile must pulse")
local secondPreset = object("Preset", "Preset 1.2 Dimmer", {Name = "Second"})
local multiSeq, multiCue = showTree({
    showRecipe(showGroup, showPreset, 1), showRecipe(cellGroup, secondPreset, 2)
})
local multiFixtures = {selectedFixture(101), selectedFixture(203)}
local multiRefs = functions.recipePoolReferences(markerState(multiSeq, multiCue,
    {showGroup, cellGroup}, multiFixtures))
check(multiRefs["Group 6"] == showGroup and multiRefs["Group 3"] == cellGroup
        and multiRefs["Preset 1.1 Dimmer"] == showPreset
        and multiRefs["Preset 1.2 Dimmer"] == secondPreset,
    "two complete Groups must keep both surviving Recipe sources")
local positionPreset = object("Preset", "Preset 2.2 Position", {Name = "Pan"})
local featureSeq, featureCue = showTree({
    showRecipe(showGroup, showPreset, 1), showRecipe(showGroup, positionPreset, 2)
})
local featureRefs = functions.recipePoolReferences(markerState(featureSeq, featureCue,
    {showGroup}, showFixtures))
check(featureRefs["Preset 1.1 Dimmer"] == showPreset
        and featureRefs["Preset 2.2 Position"] == positionPreset,
    "surviving Recipe sources must not depend on the Programmer-selected Feature")
local editedState = markerState(showSeq, showCue, {showGroup}, showFixtures)
editedState.currentRecipe = showCue:Children()[1]:Children()[1]
editedState.currentOldPreset = showPreset
check(functions.recipePoolReferences(editedState)["Preset 1.1 Dimmer"] == showPreset,
    "initial Recipe reference must be cached")
showCue:Children()[1].Children = function() return {} end
editedState.currentRecipe, editedState.currentOldPreset = nil, nil
check(functions.recipePoolReferences(editedState)["Preset 1.1 Dimmer"] == nil,
    "deleting a Recipe must invalidate the marker source cache")
local phaserSeq, phaserCue = showTree({ showRecipe(showGroup, showPhaser, 1) })
local phaserRefs = functions.recipePoolReferences(markerState(phaserSeq, phaserCue, { showGroup }, showFixtures))
check(phaserRefs["Preset 25.2 Dimmer"] == showPhaser, "surviving Phaser tile must pulse")
local genSeq, genCue = showTree({ showRecipe(showGroup, showGenerator, 1) })
local genRefs = functions.recipePoolReferences(markerState(genSeq, genCue, { showGroup }, showFixtures))
check(genRefs["Generator 1"] == showGenerator, "surviving Generator tile must pulse")

-- 15. newer static Preset overrides older moving Phaser for the same lane.
local overSeq, overCue = showTree({ showRecipe(showGroup, showPreset, 5), showRecipe(showGroup, showPhaser, 1) })
local overRefs = functions.recipePoolReferences(markerState(overSeq, overCue, { showGroup }, showFixtures))
check(overRefs["Preset 1.1 Dimmer"] == showPreset and overRefs["Preset 25.2 Dimmer"] == nil,
    "overridden older Phaser must not pulse")

-- 16+19. unknown semantics fail closed; REL lanes are never invented.
local unknownSeq, unknownCue = showTree({ object("Recipe", "Rx", {Index = 1, Selection = showGroup}) })
local unknownResult = provenApi.sources(unknownSeq, unknownCue, showFixtures, showInfo)
check(unknownResult.classification == "INCONCLUSIVE", "unreadable row must fail closed")
local unknownRefs = functions.recipePoolReferences(markerState(unknownSeq, unknownCue, { showGroup }, showFixtures))
check(unknownRefs["Group 6"] == showGroup and unknownRefs["Preset 1.1 Dimmer"] == nil,
    "inconclusive resolver keeps Group tiles without inventing refs")

-- 18. selective-flagged rows still resolve through the same lane logic.
local selectiveValues = object("Preset", "Preset 3.1 Dimmer", {Name = "Sel", selective = true})
local selSeq, selCue = showTree({ showRecipe(showGroup, selectiveValues, 1) })
local selResult = provenApi.sources(selSeq, selCue, showFixtures, showInfo)
check(selResult.classification == "PROVEN" and selResult.refs["Preset 3.1 Dimmer"] == selectiveValues,
    "selective row must resolve, not drop")

-- 20+23. marker source deduplication and freshness across source changes.
local dupSeq, dupCue = showTree({ showRecipe(showGroup, showPreset, 5), showRecipe(showGroup, showPreset, 1) })
local dupRefs, dupCount = functions.recipePoolReferences(markerState(dupSeq, dupCue, { showGroup }, showFixtures)), 0
for _ in pairs(dupRefs) do dupCount = dupCount + 1 end
check(dupCount == 2, "duplicate surviving refs must deduplicate to Group plus Preset")
local freshRefs = functions.recipePoolReferences(markerState(showSeq, showCue, { cellGroup }, { selectedFixture(203) }))
check(freshRefs["Group 3"] == cellGroup and freshRefs["Group 6"] == nil,
    "source sets must not accumulate across changes")

-- 25. steady marker pulse performs zero diagnostic GetPresetData reads.
local presetReads = 0
_G.GetPresetData = function() presetReads = presetReads + 1 end
functions.recipePoolReferences(markerState(showSeq, showCue, { showGroup }, showFixtures))
functions.recipePoolReferences(markerState(showSeq, showCue, { showGroup }, showFixtures))
provenApi.sources(showSeq, showCue, showFixtures, showInfo)
check(presetReads == 0, "marker pulse must not scan cooked history")
_G.GetPresetData = nil

print("PASS: show candidate canonical Groups, multi-match, proven resolver, marker sources (" .. count .. " checks)")
