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
local buttons, pools = {}, {}
for index, target in ipairs({otherGroup, allPreset, generator}) do
    local button = object("PoolButton", "Button " .. index, {ObjectIndex = 1, W = 80, H = 80})
    button.Append = function()
        local overlay = {}
        overlay.CommandDelete = function() overlay.deleted = true end
        return overlay
    end
    buttons[index] = button
    local pool = object("PoolLayoutGrid", "Pool " .. index, {
        PoolObject = {Ptr = function() return target end}
    }, {button})
    pools[index] = pool
end
GetDisplayByIndex = function(index)
    if index == 1 then return object("Display", "Display", {}, pools) end
end
state.running, state.poolBlinkTicks = true, 0
local commandCount = #commands
functions.refreshPoolMarkers(state)
functions.refreshPoolMarkers(state)
check(state.poolMarkers[buttons[1]] and state.poolMarkers[buttons[2]] and state.poolMarkers[buttons[3]],
    "Group, All Preset and Generator must receive markers")
local marker = state.poolMarkers[buttons[1]].overlay
check(marker.Interactive == "No" and marker.HasHover == "No" and marker.Texture == "frame0",
    "Markers must use the thick frame without handling input")
check(#commands == commandCount, "Markers must never issue Show commands")
local firstPulseColor = marker.BackColor
functions.refreshPoolMarkers(state)
check(marker.Visible == "Yes" and marker.BackColor ~= firstPulseColor,
    "Markers must pulse color every tick without disappearing")
functions.refreshPoolMarkers(state)
check(marker.Visible == "Yes" and marker.BackColor == firstPulseColor,
    "Markers must remain visible through the pulse cycle")
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
local inactiveOpen = object("Recipe", "Inactive Open", {
    Name = "[8 'S FL'/1 'Open']", Selection = group,
    Values = object("Preset", "Preset 5.1 Beam", {Name = "Open"}),
    Enabled = "Yes", Active = "No"
})
local inactivePart = object("Part", "Part without number", {}, {inactiveOpen, enabled})
local inactiveCue = object("Cue", "Cue 11", {No = 11000, Name = "Chorus"}, {inactivePart})
local inactiveSequence = object("Sequence", "Sequence inactive", {}, {inactiveCue})
local inactiveCandidates = functions.scanTracking(inactiveSequence, inactiveCue, fixtures, beamInfo)
check(#inactiveCandidates == 1 and inactiveCandidates[1].recipe == enabled,
    "Active=No rows must be excluded even when Enabled=Yes")
local fitState = {window = {H = 0}, expanded = false}
functions.fitCompactWindowToText(fitState, "short")
local shortHeight = fitState.window.H
functions.fitCompactWindowToText(fitState, table.concat({
    "one", "two", "three", "four", "five", "six", "seven", "eight", "nine", "ten"
}, "\n"))
check(fitState.window.H > shortHeight, "Compact window height must grow with visible line count")
print("PASS: " .. count .. " workflow assertions")
