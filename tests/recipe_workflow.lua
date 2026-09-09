-- Offline regression checks; grandMA3 visual/cooking behavior still needs on-console testing.
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
local function replace(fn, wanted, value)
    for index = 1, 200 do
        local name = debug.getupvalue(fn, index)
        if not name then break end
        if name == wanted then debug.setupvalue(fn, index, value); return end
    end
    error("Missing upvalue " .. wanted)
end
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
local group = object("Group", "Group 1", {Name = "Front", Selection = {{sf_index = 1}}})
local otherGroup = object("Group", "Group 2", {Name = "Other", Selection = {{sf_index = 1}}})
local oldPreset = object("Preset", "Preset 1.1 Dimmer", {Name = "Old"})
local newPreset = object("Preset", "Preset 1.2 Dimmer", {Name = "New"})
local first = object("Recipe", "Sequence 1 Cue 1 Part 0.1", {Index = 1, Selection = group, Values = oldPreset})
local last = object("Recipe", "Sequence 1 Cue 1 Part 0.5", {Index = 5, Selection = group, Values = oldPreset})
local directPhaserRecipe = object("PhaserRecipe", "Programmer Phaser Recipe", {
    Values = object("Shape", "Shape 8", {Name = "Sine 1/2"})
})
local directStandard = object("StandardRecipe", "Programmer Standard Recipe", {
    Index = 1, Selection = group, Values = oldPreset
})
ProgrammerPart = function()
    return object("Part", "Programmer Part", {}, {directPhaserRecipe, directStandard})
end
local directRows = functions.directRecipes()
check(#directRows == 1 and directRows[1] == directStandard,
    "Programmer PhaserRecipe must not be treated as an updateable StandardRecipe")
local rows = {last, first} -- Deliberately unsorted: priority must use row index.
local part = object("Part", "Part 0", {Part = 0}, rows)
local cue = object("Cue", "Cue 1", {No = 1000, Name = "One"}, {part})
local sequence = object("Sequence", "Sequence 1", {}, {cue})
local fixtures = {{index = 1}}
local info = {feature = "Dimmer", preset = newPreset, attributes = {"Dimmer"}, rawCount = 0}
local candidates = functions.scanTracking(sequence, cue, fixtures, info)
check(#candidates == 1 and candidates[1].recipe == last, "Bottom matching row must win")
check(functions.nextRecipeIndex(part) == 6, "New rows must append after highest index, not fill gaps")
rows[#rows + 1] = object("Recipe", "Recipe 6", {Index = 6, Selection = otherGroup, Values = oldPreset})
local latestGroup = functions.scanTracking(sequence, cue, fixtures, info)
check(#latestGroup == 1 and latestGroup[1].recipe == rows[3],
    "Latest row must override an older overlapping Group")
rows[3] = nil
local groupAlias = object("Group", "Group 1 dependency alias", {Name = "Front", Selection = {{sf_index = 1}}})
rows[3] = object("Recipe", "Recipe alias", {Index = 6, Selection = groupAlias, Values = oldPreset})
check(#functions.scanTracking(sequence, cue, fixtures, info) == 1,
    "Equivalent exported Group dependencies must collapse to one source")
rows[3] = nil
SelectedSequence = function() return sequence end
GetCurrentCue = function() return cue end
DataPool = function() return {Groups = object("Groups", "Groups", {}, {group})} end
replace(functions.render, "readSelection", function() return fixtures end)
replace(functions.render, "readProgrammer", function() return info end)
replace(functions.render, "directRecipes", function() return {} end)
local state = {update = {}, selectGroup = {}}
RecipeTrackingInspectorState = state
functions.render(state)
check(state.currentRecipe == last and state.update.Enabled == "Yes", "Resolved row must enable update")
local dialogs, commands, undoCount = {}, {}, 0
local answer = 0
MessageBox = function(args)
    dialogs[#dialogs + 1] = args
    return {success = true, result = answer}
end
CreateUndo = function() undoCount = undoCount + 1; return {} end
CloseUndo = function() return true end
Cmd = function(command)
    commands[#commands + 1] = command
    if command:find('Property "Values"', 1, true) then last.Values = newPreset end
    return "OK"
end
signals.ShowRecipeTrackingUpdateMenu()
check(#dialogs == 1 and #commands == 0, "Cancel must not write")
answer = 1
dialogs = {}
signals.ShowRecipeTrackingUpdateMenu()
check(#dialogs == 1 and undoCount == 1, "Source update must use one menu and one Undo")
check(#commands == 2 and commands[2] == 'Off Attribute "Dimmer"', "Only contributing Attribute is removed")
for _ = 1, 3 do functions.processPendingVerification(state) end
check(#dialogs == 1 and not state.updating, "Successful verification must not open a dialog")
rows[1], rows[2] = nil, nil
functions.render(state)
check(state.currentRecipe == nil and state.currentGroup == group and state.update.Enabled == "Yes",
    "Unique exact Group must enable NEW CONTENT without a source")
answer = 2
dialogs, commands = {}, {}
signals.ShowRecipeTrackingUpdateMenu()
check(#dialogs == 1 and commands[1]:find("Cue 1 Part 0.1", 1, true), "New content must create in current Cue Part 0")
check(commands[2]:find('Property "Selection"', 1, true) ~= nil, "New Recipe must assign its Group")
state.updating, state.pendingVerification = false, nil
DataPool = function() return {Groups = object("Groups", "Groups", {}, {otherGroup})} end
otherGroup.Selection = {{sf_index = 2}}
functions.render(state)
check(state.update.Enabled == "No", "No exact Group must disable new content")
info.ambiguous = true
DataPool = function() return {Groups = object("Groups", "Groups", {}, {group})} end
functions.render(state)
check(state.update.Enabled == "No", "Ambiguous Programmer must not create content")
info.ambiguous = false
-- Failures still surface; successful writes alone are silent.
state.pendingVerification = {checksRemaining = 1, targets = {
    {recipe = first, recipeAddress = "missing", expectedPreset = newPreset, expectedAddress = "new"}
}}
dialogs = {}
functions.processPendingVerification(state)
check(#dialogs == 1 and dialogs[1].title == "Recipe Update Failed", "Verification failure must remain visible")
-- A failed Store must not Assign Values or remove Programmer attributes.
state.updating, state.pendingVerification = false, nil
commands, dialogs, answer = {}, {}, 2
Cmd = function(command)
    commands[#commands + 1] = command
    if command:find("Store ", 1, true) == 1 then return "FAILED" end
    return "OK"
end
signals.ShowRecipeTrackingUpdateMenu()
check(#commands == 2 and commands[2] == "Oops", "Failed creation must only Store then roll back")
check(#dialogs == 2 and dialogs[2].title == "Recipe Update Failed", "Creation failure must be visible")
-- Batch uses one preview and no completion popup.
rows[1], rows[2] = last, first
last.Values = oldPreset
replace(functions.batchUpdateItems, "readAllProgrammerFeatures", function() return {info} end)
state.updating, state.pendingVerification = false, nil
commands, dialogs, answer = {}, {}, 0
signals.UpdateRecipeTrackingBatch()
check(#dialogs == 1 and #commands == 0, "Batch cancel must not write")
check(dialogs[1].message:find("READY: 1", 1, true) ~= nil, "Batch preview must report writable count")
check(dialogs[1].message:find("Recipe 5", 1, true) ~= nil, "Batch must target bottom matching Recipe")
Cmd = function(command)
    commands[#commands + 1] = command
    if command:find('Property "Values"', 1, true) then last.Values = newPreset end
    return "OK"
end
commands, dialogs, answer = {}, {}, 1
signals.UpdateRecipeTrackingBatch()
for _ = 1, 3 do functions.processPendingVerification(state) end
check(#dialogs == 1 and not state.updating, "Batch success must use only its initial preview")
-- A later overlapping Group is the tracked source; older Groups are not ambiguous.
otherGroup.Selection = {{sf_index = 1}}
last.Values = oldPreset
rows[3] = object("Recipe", "Sequence 1 Cue 1 Part 0.6", {Index = 6, Selection = otherGroup, Values = oldPreset})
state.updating, state.pendingVerification, state.targetGroup = false, nil, nil
local latestOverview = functions.render(state)
check(state.currentRecipe == rows[3] and state.currentGroup == otherGroup,
    "Latest overlapping Group must resolve automatically")
check(not latestOverview:find("matching Groups", 1, true),
    "Resolved tracking must not show stale Group candidates")
commands, dialogs, answer = {}, {}, 0
signals.ShowRecipeTrackingUpdateMenu()
check(dialogs[1].commands[2].name == "ORIGINAL CONTENT", "Original Content caption must replace Update Source")
-- A newer Cue overrides an older source even when the Group differs.
local older = object("Recipe", "Old Recipe", {Index = 1, Selection = group, Values = oldPreset})
local olderCue = object("Cue", "Cue 0.5", {No = 500}, {
    object("Part", "Part 0", {Part = 0}, {older})
})
local multiSequence = object("Sequence", "Sequence 2", {}, {
    olderCue, object("Cue", "Cue 1", {No = 1000}, {
        object("Part", "Part 0", {Part = 0}, {rows[3]})
    })
})
local latestCue = functions.scanTracking(multiSequence, cue, fixtures, info)
check(#latestCue == 1 and latestCue[1].recipe == rows[3],
    "Newer Cue must override older overlapping Groups")
local partZeroRecipe = object("Recipe", "Cue 11 Part 0 Recipe 5", {
    Index = 5, Selection = group, Values = oldPreset
})
local partOneRecipe = object("Recipe", "Cue 11 Part 1 Recipe 2", {
    Index = 2, Selection = otherGroup, Values = oldPreset
})
local partPriorityCue = object("Cue", "Cue 11", {No = 11000, Name = "Chorus"}, {
    object("Part", "Part 0", {Part = 0}, {partZeroRecipe}),
    object("Part", "Part 1", {Part = 1}, {partOneRecipe})
})
local partPrioritySequence = object("Sequence", "Sequence Part Priority", {}, {partPriorityCue})
local latestPart = functions.scanTracking(partPrioritySequence, partPriorityCue, fixtures, info)
check(#latestPart == 1 and latestPart[1].recipe == partOneRecipe,
    "Current Cue Part 1 must override Part 0 across overlapping Groups")
-- UI-only markers cover all referenced pool types and are removed on stop/scroll.
local generator = object("Generator", "Generator 1", {Name = "Random"})
local allPreset = object("Preset", "Preset 21.1", {Name = "All"})
rows[3].Generator, rows[3].Values = generator, allPreset
local buttons, titles, pools = {}, {}, {}
for index, target in ipairs({otherGroup, allPreset, generator}) do
    local button = object("PoolButton", "Button " .. index, {
        ObjectIndex = 1, W = 80, H = 80,
        Anchors = {left = index - 1, right = index - 1, top = 0, bottom = 0}
    })
    button.Append = function()
        local overlay = {}
        overlay.CommandDelete = function() overlay.deleted = true end
        return overlay
    end
    buttons[index] = button
    local title = object("PoolTitleButton", "Pool Title " .. index, {ObjectIndex = 1})
    titles[index] = title
    local pool = object("PoolLayoutGrid", "Pool " .. index, {
        PoolObject = {Ptr = function() return target end}
    }, {title, button})
    pool.Append = function()
        local overlay = {}
        overlay.CommandDelete = function() overlay.deleted = true end
        return overlay
    end
    pools[index] = pool
end
local displayLookupCount = 0
GetDisplayByIndex = function(index)
    displayLookupCount = displayLookupCount + 1
    if index == 1 then return object("Display", "Display", {}, pools) end
end
state.running, state.poolBlinkTicks = true, 0
local commandCount = #commands
functions.refreshPoolMarkers(state)
functions.refreshPoolMarkers(state)
check(state.poolMarkers[buttons[1]] and state.poolMarkers[buttons[2]] and state.poolMarkers[buttons[3]],
    "Group, All Preset and Generator must receive markers")
check(state.poolMarkers[titles[1]] == nil,
    "PoolTitleButton must never be treated as an object tile")
local marker = state.poolMarkers[buttons[1]].overlay
check(marker.Interactive == "No" and marker.HasHover == "No" and marker.Texture == "frame0",
    "Markers must use the thick frame without handling input")
check(marker.Anchors and marker.Anchors.left == buttons[1].Anchors.left
        and marker.Anchors.right == buttons[1].Anchors.right,
    "Pool marker must be anchored to the PoolLayoutGrid cell so it renders above the button")
check(#commands == commandCount, "Markers must never issue Show commands")
local firstPulseColor = marker.BackColor
functions.refreshPoolMarkers(state)
check(marker.Visible == "Yes" and marker.BackColor ~= firstPulseColor,
    "Markers must pulse color every tick without disappearing")
functions.refreshPoolMarkers(state)
check(marker.Visible == "Yes" and marker.BackColor == firstPulseColor,
    "Markers must remain visible through the pulse cycle")
check(displayLookupCount == 7,
    "Cached Pool grids must avoid repeating the full display-tree traversal")
state.currentRecipe, state.currentGroup, state.matchingCandidates = nil, nil, {}
functions.refreshPoolMarkers(state)
functions.refreshPoolMarkers(state)
check(marker.deleted and next(state.poolMarkers) == nil, "Selection change must clean up markers")
state.currentRecipe = rows[3]
functions.refreshPoolMarkers(state)
functions.refreshPoolMarkers(state)
marker = state.poolMarkers[buttons[1]].overlay
signals.StopRecipeTrackingInspector()
check(marker.deleted and next(state.poolMarkers) == nil, "Stopping must remove every marker")
-- Real Generator references live in Recipe.Values, with RandomChannels underneath.
local randomRows = {object("RandomChannel", "Channel 1", {Attribute = "Dimmer"})}
local random = object("Random", "Random 103", {
    Name = "S2 Verse", RandomChannels = object("RandomChannels", "Channels", {}, randomRows)
})
check(functions.valuesMatchFeature(random, "Dimmer"), "Random Dimmer channel must match without preset data")
check(not functions.valuesMatchFeature(random, "Position"), "Random must not match unrelated Attributes")
randomRows[1].Attribute = "Pan"
check(functions.valuesMatchFeature(random, "Position"), "Random Attribute must use feature normalization")
randomRows[1].Attribute = nil
check(functions.valuesMatchFeature(random, "Dimmer"), "Unassigned Random channel must cover Dimmer")
randomRows[1].Attribute = "ColorRGB_R"
check(functions.valuesMatchFeature(random, "Color"), "Random RGB channel must resolve Color")
random.Name, randomRows[1].Attribute = "Dimmer Name Only", "Zoom"
check(not functions.valuesMatchFeature(random, "Dimmer"), "Generator name must not override channel Attributes")
randomRows[1].Attribute = "Dimmer"
rows[1], rows[2], rows[3] = last, nil, nil
last.Values = random
last.Generator = random
state.running, state.targetGroup, state.updating = true, nil, false
local rendered = functions.render(state)
check(state.currentRecipe == last and state.currentOldPreset == random and state.currentGroup == group,
    "Generator Values must resolve the Recipe and Group from a single selected fixture")
check(functions.presetText(random, "Dimmer"):find("Generator", 1, true),
    "Generator source must be labelled as Generator")
check(functions.recipePoolReferences(state)["Random 103"] == random,
    "Resolved Values Generator must reach Pool marker references")
local generatorClass = object("Generator", "Generator 104", {
    Name = "Wash Side", RandomChannels = object("GeneratorChannels", "Channels", {}, {
        object("GeneratorChannel", "Channel 1", {Attribute = "Dimmer"})
    })
})
check(functions.valuesMatchFeature(generatorClass, "Dimmer"),
    "Generator class Values must match WASH SIDE by channel Attribute")
check(functions.presetText(generatorClass, "Dimmer"):find("Generator", 1, true),
    "Generator class Values must be labelled as Generator")
local integratedPhaser = {
    [1] = {integrated = generatorClass}
}
check(#functions.phaserReferences(integratedPhaser, 7) == 1
        and functions.phaserReferences(integratedPhaser, 7)[1] == generatorClass,
    "Integrated phaser Generator reference must be discoverable")
local previousGetProgPhaserValue = GetProgPhaserValue
GetProgPhaserValue = function(index, step)
    if index == 7 and step == 0 then return {integrated = generatorClass} end
end
local nilPhaserReferences = functions.phaserReferences(nil, 7)
GetProgPhaserValue = previousGetProgPhaserValue
check(#nilPhaserReferences == 1 and nilPhaserReferences[1] == generatorClass,
    "Generator reference must be discoverable when GetProgPhaser returns nil")
-- Exported Sequence XML embeds the Preset number in Name. It is not the
-- Recipe row number; when Index is absent, Part child order must decide.
local namedOld = object("Preset", "Preset 1.11 Dimmer", {Name = "100"})
local namedLatest = object("Recipe", "Recipe named latest", {
    Name = "[9 'SPOT TOP GRID'/1206 'S2 VER']", Selection = group, Values = namedOld
})
local namedEarlier = object("Recipe", "Recipe named earlier", {
    Name = "[9 'SPOT TOP GRID'/11 '100']", Selection = group, Values = namedOld
})
local namedPart = object("Part", "Part without number", {}, {namedEarlier, namedLatest})
local namedCue = object("Cue", "Cue 11", {No = 11000, Name = "Chorus"}, {namedPart})
local namedSequence = object("Sequence", "Sequence named", {}, {namedCue})
local namedInfo = {feature = "Dimmer", preset = newPreset, attributes = {"Dimmer"}, rawCount = 0}
local namedCandidates = functions.scanTracking(namedSequence, namedCue, fixtures, namedInfo)
check(#namedCandidates == 1 and namedCandidates[1].recipe == namedLatest
        and namedCandidates[1].recipeIndex == 2
        and functions.cueRecipeCommandAddress(namedSequence, namedCue, namedPart, namedLatest, 2)
            == "Sequence named Cue 11 Part 0.2",
    "Part child order and default Part 0 must resolve the latest Recipe row")
local phaserValueSource = object("PhaserRecipeValueSource", "Phaser Value Source", {Attributes = "A: Dimmer"})
local phaserStep = object("PhaserRecipeStep", "Phaser Step", {}, {phaserValueSource})
local phaserSteps = object("PhaserRecipeSteps", "Phaser Steps", {}, {phaserStep})
local phaserRecipe = object("PhaserRecipe", "Phaser Recipe", {}, {phaserSteps})
local phaserPreset = object("Preset", "Preset 25.303", {Name = "Dimmer Speed#3"}, {phaserRecipe})
check(functions.valuesMatchFeature(phaserPreset, "Dimmer")
        and not functions.valuesMatchFeature(phaserPreset, "Position"),
    "Phaser Recipe Preset must resolve its feature from Value Source Attributes")
local oldAll = object("Preset", "ShowData.DataPools.Default.PresetPools.All.Spot", {Name = "Spot"})
local oldAllRow = object("Recipe", "Old All Recipe", {Index = 1, Selection = group, Values = oldAll})
local currentPhaserRow = object("StandardRecipe", "Current Phaser Recipe", {Index = 1, Selection = group, Values = phaserPreset})
currentPhaserRow.Active = "No"
local oldAllPart = object("Part", "Old All Part", {Part = 0}, {oldAllRow})
local currentPhaserPart = object("Part", "Current Phaser Part", {Part = 0}, {currentPhaserRow})
local oldAllCue = object("Cue", "Cue 5", {No = 5000}, {oldAllPart})
local currentPhaserCue = object("Cue", "Cue 16", {No = 16000}, {currentPhaserPart})
local phaserTrackingSequence = object("Sequence", "Phaser Tracking Sequence", {}, {oldAllCue, currentPhaserCue})
local phaserCandidate = functions.scanTracking(phaserTrackingSequence, currentPhaserCue, fixtures, namedInfo)
check(#phaserCandidate == 1 and phaserCandidate[1].recipe == currentPhaserRow,
    "Enabled StandardRecipe with Active=No must override an older matching All Preset")
local disabled = object("Recipe", "Disabled Open", {
    Name = "[8 'S FL'/1195 'Open']", Selection = group, Values = object("Preset", "Preset 5.1 Beam", {Name = "Open"}),
    Enabled = "No"
})
local enabled = object("Recipe", "Enabled Strobe", {
    Name = "[8 'S FL'/1196 'Strobe']", Selection = group, Values = object("Preset", "Preset 5.1 Beam", {Name = "Strobe"}),
    Enabled = "Yes"
})
local beamPart = object("Part", "Part without number", {}, {disabled, enabled})
local beamCue = object("Cue", "Cue 11", {No = 11000, Name = "Chorus"}, {beamPart})
local beamSequence = object("Sequence", "Sequence beam", {}, {beamCue})
local beamInfo = {feature = "Beam", preset = newPreset, attributes = {"Beam"}, rawCount = 0}
local beamCandidates = functions.scanTracking(beamSequence, beamCue, fixtures, beamInfo)
check(#beamCandidates == 1 and beamCandidates[1].recipe == enabled,
    "Disabled Recipe rows must not count as tracking candidates")
check(functions.recipeEnabled(disabled) == false
        and functions.recipeEnabled(object("Recipe", "Disabled boolean", {Enabled = false})) == false,
    "String and boolean disabled states must both be excluded")
local activeNoOpen = object("Recipe", "Active No Open", {
    Name = "[8 'S FL'/1 'Open']", Selection = group,
    Values = object("Preset", "Preset 5.1 Beam", {Name = "Open"}),
    Enabled = "Yes", Active = "No"
})
local activeNoPart = object("Part", "Part without number", {}, {enabled, activeNoOpen})
local activeNoCue = object("Cue", "Cue 11", {No = 11000, Name = "Chorus"}, {activeNoPart})
local activeNoSequence = object("Sequence", "Sequence Active No", {}, {activeNoCue})
local activeNoCandidates = functions.scanTracking(activeNoSequence, activeNoCue, fixtures, beamInfo)
check(#activeNoCandidates == 1 and activeNoCandidates[1].recipe == activeNoOpen,
    "Active=No must remain eligible when the Recipe editor Enabled column is Yes")
local fitState = {window = {H = 0}, expanded = false}
functions.fitCompactWindowToText(fitState, "short")
local shortHeight = fitState.window.H
functions.fitCompactWindowToText(fitState, table.concat({
    "one", "two", "three", "four", "five", "six", "seven", "eight", "nine", "ten"
}, "\n"))
check(fitState.window.H > shortHeight, "Compact window height must grow with visible line count")
-- Cue-wide effects do not depend on selection or Programmer content.
local fxA = object("Preset", "Preset 25.1206", {Name = "S2 VER"})
local fxB = object("Preset", "Preset 25.1192", {Name = "Old Ramp"})
local fixtureA = object("Fixture", "Fixture 1", {SubfixtureIndex = 1})
local fixtureB = object("Fixture", "Fixture 2", {SubfixtureIndex = 2})
GetUIChannel = function(index) return {rt_index = index} end
local function mockGetRTChannel(index)
    local fixture = index == 3 and fixtureB or fixtureA
    return {fixture = fixture, subfixture = fixture}
end
GetRTChannel = mockGetRTChannel
GetAttributeByUIChannel = function() return object("Attribute", "Attribute Dimmer", {Name = "Dimmer"}) end
local function moving(ref)
    return {abs_preset = ref, [1] = {absolute = 0}, [2] = {absolute = 100}}
end
local dataByPart = {}
GetPresetData = function(target) return dataByPart[target] or {} end
local fxPart0 = object("Part", "FX Part 0", {Part = 0})
local fxPart1 = object("Part", "FX Part 1", {Part = 1})
local fxOldPart = object("Part", "FX Old Part", {Part = 0})
local fxOldCue = object("Cue", "FX Cue 9", {No = 9000}, {fxOldPart})
local fxCue = object("Cue", "FX Cue 11", {No = 11000}, {fxPart1, fxPart0})
local futurePart = object("Part", "Future Part", {Part = 0})
local futureCue = object("Cue", "FX Cue 12", {No = 12000}, {futurePart})
local fxSequence = object("Sequence", "FX Sequence", {}, {futureCue, fxCue, fxOldCue})
local function scanCueEffects(sequence, currentCue)
    local scan = functions.newCueEffectScan(sequence, currentCue)
    while not scan.done do functions.advanceCueEffectScan(scan) end
    return scan.result
end
local underlyingDimmer = object("Preset", "Preset 1.5", {Name = "Underlying Dimmer"})
local exportedSongEfx = object("Preset",
    "ShowData.DataPools.Default.PresetPools.Song EFX.Dimmer Speed#3", {Name = "Dimmer Speed#3"},
    {object("PhaserRecipe", "Preset 25.303 PhaserRecipe")})
local phaserCueRow = object("StandardRecipe", "Phaser Cue Row", {
    Index = 1, Selection = group, Values = exportedSongEfx, Active = "No", Enabled = "Yes"
})
local phaserCuePart = object("Part", "Phaser Cue Part", {Part = 0}, {phaserCueRow})
local phaserCueOnly = object("Cue", "Phaser Cue 16", {No = 16000}, {phaserCuePart})
local phaserCueSequence = object("Sequence", "Phaser Cue Sequence", {}, {phaserCueOnly})
phaserCueSequence.IsRunningPlayback = function() return true end
dataByPart[phaserCuePart] = {[1] = moving(underlyingDimmer)}
GetRTChannel = function() return {fixture = fixtureA} end
local phaserCueEffects = scanCueEffects(phaserCueSequence, phaserCueOnly)
check(phaserCueEffects["ShowData.DataPools.Default.PresetPools.Song EFX.Dimmer Speed#3"]
        and not phaserCueEffects["Preset 1.5"],
    "Cue scan must recover a custom-pool StandardRecipe with only an RT fixture handle")
GetRTChannel = function() return {} end
phaserCueEffects = scanCueEffects(phaserCueSequence, phaserCueOnly)
check(phaserCueEffects["ShowData.DataPools.Default.PresetPools.Song EFX.Dimmer Speed#3"] ~= nil,
    "Cue scan must recover a Phaser Recipe without RT fixture identity when counts are hidden")
GetRTChannel = mockGetRTChannel
dataByPart[fxOldPart] = {[1] = moving(fxB), [2] = moving(fxB), [3] = moving(fxB)}
dataByPart[fxPart0] = {[1] = { [1] = {absolute = 100} }}
dataByPart[fxPart1] = {[1] = moving(fxA), [2] = moving(fxA)}
dataByPart[futurePart] = {[3] = { [1] = {absolute = 100} }}
local effects = scanCueEffects(fxSequence, fxCue)
check(effects["Preset 25.1206"].count == 1,
    "One fixture with two moving Attributes must count once")
check(effects["Preset 25.1192"].count == 1,
    "Older effect must survive only on fixtures not overwritten; future Cue excluded")
dataByPart[fxPart1][3] = { [1] = {abs_release = true} }
check(scanCueEffects(fxSequence, fxCue)["Preset 25.1192"] == nil,
    "Release must remove tracked effect")
dataByPart[fxPart1][1] = { [1] = {absolute = 100} }
dataByPart[fxPart1][2] = { [1] = {absolute = 50} }
check(next(scanCueEffects(fxSequence, fxCue)) == nil,
    "Static current Cue data must stop previous multistep effects")
dataByPart[fxOldPart][1] = {rel_preset = fxB, [1] = {relative = -10}, [2] = {relative = 10}}
effects = scanCueEffects(fxSequence, fxCue)
check(effects["Preset 25.1192"].count == 1,
    "Static Absolute must not erase tracked Relative Phaser")
dataByPart[fxPart1][1].rel_preset = fxA
dataByPart[fxPart1][1][1].rel_release = true
check(next(scanCueEffects(fxSequence, fxCue)) == nil,
    "Released layer must not retain its Preset reference")
local genRecipe = object("Recipe", "Generator Recipe", {Selection = group, Generator = random, Values = "S2 Verse"})
fxPart1.Children = function() return {genRecipe} end
dataByPart[fxPart1][1] = moving(nil)
effects = scanCueEffects(fxSequence, fxCue)
check(effects["Random 103"] and effects["Random 103"].count == 1,
    "Cooked multistep channel must recover Generator from its enabled Recipe")
genRecipe.Enabled = "No"
check(scanCueEffects(fxSequence, fxCue)["Random 103"] == nil,
    "Disabled Recipe must not recover a Generator reference")
dataByPart[fxPart1][1] = {abs_generator = random, [1] = {absolute = 50}}
check(scanCueEffects(fxSequence, fxCue)["Random 103"].count == 1,
    "Direct Generator reference must work without multi-step data or a Recipe")
fxSequence.IsRunningPlayback = function() return false end
fxSequence.HasActivePlayback = function() error("Deprecated playback API must not be called on 2.5") end
check(scanCueEffects(fxSequence, fxCue)["Random 103"] ~= nil,
    "Current Cue effect markers must remain available while playback is stopped")
fxSequence.IsRunningPlayback = function() return true end
check(scanCueEffects(fxSequence, fxCue)["Random 103"] ~= nil,
    "Current Cue effect markers must remain available while playback is running")
local workerState = {}
SelectedSequence = function() return fxSequence end
GetCurrentCue = function() return fxCue end
local originalGetPresetData, workerDataCalls = GetPresetData, 0
GetPresetData = function(...)
    workerDataCalls = workerDataCalls + 1
    return originalGetPresetData(...)
end
for _ = 1, 8 do functions.refreshCueEffects(workerState) end
check(workerState.activeEffects["Random 103"] ~= nil, "Incremental scan must publish finished effects")
local completedDataCalls = workerDataCalls
for _ = 1, 20 do functions.refreshCueEffects(workerState) end
check(workerDataCalls == completedDataCalls,
    "An unchanged Cue must not restart the expensive cooked-data scan")
SelectedSequence = function() return phaserCueSequence end
GetCurrentCue = function() return phaserCueOnly end
local directCueState = {}
functions.refreshCueEffects(directCueState)
check(directCueState.activeEffects["ShowData.DataPools.Default.PresetPools.Song EFX.Dimmer Speed#3"] ~= nil,
    "Current Cue Phaser Recipe must publish immediately without waiting for cooked-data scanning")
GetCurrentCue = function() return nil end
functions.refreshCueEffects(directCueState)
check(next(directCueState.activeEffects) == nil, "Leaving Cue must discard old scan and effects")
local purpleState = {running = true, activeEffects = {["Preset 21.1"] = {object = allPreset, count = 8}}}
functions.refreshPoolMarkers(purpleState)
functions.refreshPoolMarkers(purpleState)
local purple = purpleState.poolMarkers[buttons[2]].overlay
check(purple.BackColor == "GroupedProgLayerActive.Phaser" and purple.Text == "",
    "Active effects must have a purple frame without fixture-count text")
functions.refreshPoolMarkers(purpleState)
check(purple.BackColor == "GroupedProgLayerActive.Phaser" and purple.Visible == "Yes",
    "Active-only frame must stay purple throughout pulse ticks")
purpleState.currentGroup = allPreset
functions.refreshPoolMarkers(purpleState)
check(purple.BackColor == "GroupedProgLayerActive.Phaser" and purple.Text == "",
    "Active effect purple must take priority over the Recipe selection pulse")
purpleState.currentGroup = nil
functions.refreshPoolMarkers(purpleState)
functions.refreshPoolMarkers(purpleState)
check(purple.BackColor == "GroupedProgLayerActive.Phaser", "Deselecting must restore persistent purple")
purpleState.activeEffects = {}
functions.refreshPoolMarkers(purpleState)
functions.refreshPoolMarkers(purpleState)
check(purple.deleted, "Inactive effects must lose their Pool frame")
-- Large Part processing must yield without rereading native cooked data.
local largePart = object("Part", "Large Part", {Part = 0})
local largeCue = object("Cue", "Large Cue", {No = 1000}, {largePart})
local largeSequence = object("Sequence", "Large Sequence", {}, {largeCue})
local largeData, largeReads = {}, 0
for i = 1, 1000 do largeData[i] = moving(fxA) end
GetPresetData = function(target)
    largeReads = largeReads + 1
    return largeData
end
local boundedScan = functions.newCueEffectScan(largeSequence, largeCue)
functions.advanceCueEffectScan(boundedScan)
check(not boundedScan.done and boundedScan.pendingPart ~= nil,
    "A 1000-channel Part must yield after a bounded channel batch")
while not boundedScan.done do functions.advanceCueEffectScan(boundedScan) end
check(largeReads == 1 and boundedScan.result["Preset 25.1206"] ~= nil,
    "Resuming batches must reuse one native Part read and retain effects")
SelectedSequence = function() return largeSequence end
GetCurrentCue = function() return largeCue end
local cachedState = {}
for i = 1, 40 do functions.refreshCueEffects(cachedState) end
local warmReads = largeReads
GetCurrentCue = function() return nil end
functions.refreshCueEffects(cachedState)
GetCurrentCue = function() return largeCue end
functions.refreshCueEffects(cachedState, false)
check(cachedState.activeEffects["Preset 25.1206"] ~= nil and largeReads == warmReads,
    "Revisiting a scanned Cue must publish cached effects before any native data read")
print("PASS: " .. count .. " workflow assertions")
