-- grandMA3 Recipe Tracking Inspector and undo-safe Recipe Values updater
-- Target: grandMA3 2.3.2.0+

local signalTable = select(3, ...)
local componentHandle = select(4, ...)

local PLUGIN_VERSION = "0.3.0.2"
local STATE_KEY = "RecipeTrackingInspectorState"
local MAX_SELECTION = 2048
local MAX_CUES = 512
local MAX_RECIPES = 2048
local REFRESH_SECONDS = 0.25
local PANEL_WIDTH = 520
local COMPACT_HEIGHT = 260
local DETAIL_HEIGHT = 520

local function callable(name)
    return type(_G[name]) == "function"
end

local function safe(fn, ...)
    if type(fn) ~= "function" then return nil end
    local result = { pcall(fn, ...) }
    if not result[1] then return nil end
    table.remove(result, 1)
    return table.unpack(result)
end

local function property(object, name)
    if object == nil then return nil end
    local ok, value = pcall(function() return object[name] end)
    if not ok or value == nil then
        ok, value = pcall(function() return object:Get(name) end)
    end
    if not ok or value == nil then return nil end
    local text = tostring(value)
    if string.match(text, "^function:") then return nil end
    return text
end

local function address(object)
    if object == nil then return "" end
    -- AddrNative exposes the full PresetPools.<Feature> path on 2.3.2.0.
    -- ToAddr alone may collapse it to a display address such as "Preset 2.8",
    -- which loses the Position/Color identity needed for Recipe matching.
    for _, method in ipairs({ "AddrNative", "Addr", "ToAddr" }) do
        local ok, value = pcall(function()
            local fn = object[method]
            return type(fn) == "function" and fn(object) or nil
        end)
        if ok and value ~= nil then return tostring(value) end
    end
    if callable("ToAddr") then
        local value = safe(ToAddr, object)
        if value ~= nil then return tostring(value) end
    end
    return tostring(object)
end

local function label(object)
    if object == nil then return "UNRESOLVED" end
    return property(object, "Name") or property(object, "NAME") or address(object)
end

local function class(object)
    if object == nil then return "" end
    local ok, value = pcall(function() return object:GetClass() end)
    return ok and tostring(value or "") or ""
end

local function cueLabel(cue)
    if cue == nil then return "UNRESOLVED" end
    local number = tonumber(property(cue, "No") or property(cue, "NO"))
    -- grandMA3 2.3.2.0 exposes Cue.No in thousandths: Cue 1 = 1000,
    -- Cue 0.5 = 500, and Cue 8.5 = 8500.
    if number then number = number / 1000 end
    return string.format("%s - %s", number and string.format("%g", number) or "?", label(cue))
end

local function presetText(object, fallbackFeature)
    if object == nil then return "No Programmer value" end
    local pool = string.match(address(object), "PresetPools%.([^%.]+)") or fallbackFeature
    local reference = tostring(object)
    local name = property(object, "Name") or property(object, "NAME")
    local parts = {}
    if pool and pool ~= "" and pool ~= "UNRESOLVED" then parts[#parts + 1] = pool end
    parts[#parts + 1] = reference
    if name and name ~= "" and name ~= reference then parts[#parts + 1] = '"' .. name .. '"' end
    return table.concat(parts, " | ")
end

local commandAddress

local function cueNumber(cue)
    return cue and tonumber(property(cue, "No") or property(cue, "NO")) or nil
end

local function cueRecipeCommandAddress(sequence, cue, part, recipe)
    local sequenceAddress = commandAddress(sequence)
    local rawCue = cueNumber(cue)
    local partNumber = tonumber(property(part, "Part") or property(part, "PART"))
    local recipeIndex = tonumber(property(recipe, "Index") or property(recipe, "INDEX"))
    if not sequenceAddress or not rawCue or partNumber == nil or recipeIndex == nil then return nil end
    return string.format("%s Cue %g Part %g.%g", sequenceAddress, rawCue / 1000,
        partNumber, recipeIndex)
end

local function indexedLabel(object, key, fallback)
    return property(object, key) or property(object, string.upper(key)) or fallback
end

local function children(object)
    if object == nil then return {} end
    local ok, value = pcall(function() return object:Children() end)
    return ok and type(value) == "table" and value or {}
end

local function readSelection()
    local fixtures = {}
    if not callable("SelectionFirst") or not callable("SelectionNext") then return fixtures end
    local index, x, y, z = safe(SelectionFirst)
    while index ~= nil and #fixtures < MAX_SELECTION do
        fixtures[#fixtures + 1] = {
            index = tonumber(index),
            handle = callable("GetSubfixture") and safe(GetSubfixture, index) or nil,
            grid = { x = x, y = y, z = z }
        }
        index, x, y, z = safe(SelectionNext, index)
    end
    return fixtures
end

local function selectedFeatureLabel()
    if callable("SelectedFeature") then
        local feature = safe(SelectedFeature)
        if feature ~= nil then return label(feature) end
    end
    if callable("GetSelectedAttribute") then
        local attribute = safe(GetSelectedAttribute)
        if attribute ~= nil then return label(attribute) end
    end
    return "UNRESOLVED"
end

local function normalizeFeature(name)
    local text = tostring(name or "UNRESOLVED")
    local compact = string.lower(string.gsub(text, "[%s_/%-]", ""))
    if compact == "pantilt" or compact == "pan" or compact == "tilt" then return "Position" end
    if compact == "rgb" or compact == "colorrgb" or compact == "colourrgb" then return "Color" end
    if compact == "r" or compact == "g" or compact == "b" or compact == "red"
        or compact == "green" or compact == "blue" then return "Color" end
    if compact == "dim" or compact == "dimmer" then return "Dimmer" end
    if string.find(compact, "gobo", 1, true) then return "Gobo" end
    return text
end

local function getProgPhaser(index)
    if not callable("GetProgPhaser") then return nil end
    return safe(GetProgPhaser, index, false) or safe(GetProgPhaser, index)
end

local function readProgrammer(fixtures)
    local presets, rawCount = {}, 0
    local selectedFeature = normalizeFeature(selectedFeatureLabel())
    if #fixtures == 0 or not callable("GetUIChannels") then
        return { feature = selectedFeature }
    end
    for _, fixture in ipairs(fixtures) do
        local channels = safe(GetUIChannels, fixture.handle or fixture.index, true)
        if type(channels) == "table" then
            for _, channel in pairs(channels) do
                local uiIndex = tonumber(property(channel, "INDEX") or property(channel, "Index"))
                if uiIndex then
                    local phaser = getProgPhaser(uiIndex - 1)
                    if type(phaser) == "table" then
                        local channelFeature = normalizeFeature(property(channel, "SUBATTRIBUTE")
                            or property(channel, "SubAttribute") or property(channel, "Name"))
                        if type(phaser.abs_preset) == "userdata" then
                            local presetAddress = address(phaser.abs_preset)
                            local pool = string.match(presetAddress, "PresetPools%.([^%.]+)%.")
                            if pool == selectedFeature or pool == "All" then
                                presets[presetAddress] = phaser.abs_preset
                                if type(phaser[2]) == "table" then rawCount = rawCount + 1 end
                            end
                        elseif channelFeature == selectedFeature then
                            rawCount = rawCount + 1
                        end
                    end
                end
            end
        end
    end
    local keys = {}
    for key in pairs(presets) do keys[#keys + 1] = key end
    table.sort(keys)
    if #keys == 1 then
        local preset = presets[keys[1]]
        return {
            preset = preset,
            presetAddress = keys[1],
            feature = selectedFeature,
            rawCount = rawCount
        }
    end
    return {
        feature = selectedFeature,
        ambiguous = #keys > 1 or rawCount > 0,
        presetCount = #keys,
        rawCount = rawCount
    }
end

commandAddress = function(object)
    if object == nil then return nil end
    local value = safe(function() return object:ToAddr() end)
    if value == nil or tostring(value) == "" then return nil end
    return tostring(value)
end

local function sameReference(left, right)
    if left == nil or right == nil then return false end
    local ok, equal = pcall(function() return left == right end)
    if ok and equal then return true end
    local leftCommand, rightCommand = commandAddress(left), commandAddress(right)
    if leftCommand and rightCommand and leftCommand == rightCommand then return true end
    local leftAddress, rightAddress = address(left), address(right)
    return leftAddress ~= "" and rightAddress ~= "" and leftAddress == rightAddress
end

local function programmerValueText(info)
    if info.preset then
        local text = presetText(info.preset, info.feature)
        if (info.rawCount or 0) > 0 then text = text .. " + Phaser/multi-step" end
        return text
    end
    if (info.rawCount or 0) > 0 then return "Programmer Phaser / multi-step" end
    return "No Programmer value"
end

local function presetDataHasFeature(values, feature)
    if values == nil or not callable("GetPresetData") or not callable("GetAttributeByUIChannel") then return false end
    local data = safe(GetPresetData, values, true, false)
    if type(data) ~= "table" then return false end
    for uiIndex in pairs(data) do
        local numericIndex = tonumber(uiIndex)
        if numericIndex ~= nil then
            local attribute = safe(GetAttributeByUIChannel, numericIndex)
            if attribute and normalizeFeature(label(attribute)) == feature then return true end
        end
    end
    return false
end

local function valuesMatchFeature(values, feature)
    local identity = string.lower(tostring(values or "") .. " " .. address(values))
    if string.find(identity, string.lower(feature), 1, true) then return true end
    if presetDataHasFeature(values, feature) then return true end
    return string.find(identity, "presetpools.all", 1, true) ~= nil
end

local function selectionRelation(group, fixtures)
    if group == nil or #fixtures == 0 then return false, false, 0, 0 end
    local ok, selection = pcall(function() return group.Selection end)
    if not ok or type(selection) ~= "table" then return false, false, 0, 0 end
    local selected, members, selectedCount, memberCount = {}, {}, 0, 0
    for _, fixture in ipairs(fixtures) do
        local index = tonumber(fixture.index)
        if index and not selected[index] then selected[index], selectedCount = true, selectedCount + 1 end
    end
    for _, item in pairs(selection) do
        local index = type(item) == "table" and tonumber(item.sf_index) or nil
        if index and not members[index] then members[index], memberCount = true, memberCount + 1 end
    end
    for index in pairs(selected) do
        if not members[index] then return false, false, selectedCount, memberCount end
    end
    return true, selectedCount == memberCount, selectedCount, memberCount
end

local function directRecipes()
    if not callable("ProgrammerPart") then return {} end
    local result = {}
    for _, child in ipairs(children(safe(ProgrammerPart))) do
        if string.find(string.lower(class(child)), "recipe", 1, true) then result[#result + 1] = child end
    end
    return result
end

local function scanTracking(sequence, currentCue, fixtures, info)
    if not sequence or #fixtures == 0 or not info.feature or info.feature == "UNRESOLVED" then return {} end
    local candidates, cueCount, recipeCount = {}, 0, 0
    local currentNumber = cueNumber(currentCue)
    for _, cue in ipairs(children(sequence)) do
        if cueCount >= MAX_CUES or recipeCount >= MAX_RECIPES then break end
        local candidateNumber = cueNumber(cue)
        -- Tracking provenance can only originate at or before the current Cue.
        -- If either number cannot be read, fail closed instead of admitting a
        -- future or otherwise unverified source candidate.
        if string.lower(class(cue)) == "cue"
            and currentNumber ~= nil and candidateNumber ~= nil
            and candidateNumber <= currentNumber then
            cueCount = cueCount + 1
            for _, part in ipairs(children(cue)) do
                if string.lower(class(part)) == "part" then
                    for _, recipe in ipairs(children(part)) do
                        if recipeCount >= MAX_RECIPES then break end
                        if string.find(string.lower(class(recipe)), "recipe", 1, true) then
                            recipeCount = recipeCount + 1
                            local selection = safe(function() return recipe.Selection end)
                            local values = safe(function() return recipe.Values end)
                            local subset, exact, selectedCount, groupCount = selectionRelation(selection, fixtures)
                            if subset and valuesMatchFeature(values, info.feature) then
                                candidates[#candidates + 1] = {
                                    cue = cue, part = part, recipe = recipe, group = selection,
                                    values = values, exact = exact, selectedCount = selectedCount,
                                    groupCount = groupCount, current = cue == currentCue
                                }
                            end
                        end
                    end
                end
            end
        end
    end
    -- Older matching Recipes have been superseded. Only the closest matching
    -- Cue at or before the current Cue can be the active tracking source.
    local latestNumber = nil
    for _, item in ipairs(candidates) do
        local number = cueNumber(item.cue)
        if number ~= nil and (latestNumber == nil or number > latestNumber) then latestNumber = number end
    end
    if latestNumber == nil then return {} end
    local latest = {}
    for _, item in ipairs(candidates) do
        if cueNumber(item.cue) == latestNumber then latest[#latest + 1] = item end
    end
    return latest
end

local function render(state)
    if state then
        state.currentGroup = nil
        state.currentRecipe = nil
        state.currentOldPreset = nil
        state.currentNewPreset = nil
        state.currentRecipeCommand = nil
    end
    local fixtures = readSelection()
    local info = readProgrammer(fixtures)
    local sequence = callable("SelectedSequence") and safe(SelectedSequence) or nil
    local currentCue = callable("GetCurrentCue") and safe(GetCurrentCue) or nil
    local direct = directRecipes()
    local lines = {
        "RECIPE TRACKING INSPECTOR v" .. PLUGIN_VERSION,
        string.format("Selection: %d fixture%s", #fixtures, #fixtures == 1 and "" or "s"),
        "Attribute: " .. tostring(info.feature or "UNRESOLVED"),
        "Current Cue: " .. cueLabel(currentCue)
    }

    if #fixtures == 0 then
        lines[#lines + 1] = "\nStatus: Select one or more fixtures"
    elseif #direct > 0 then
        lines[#lines + 1] = "\nMode: EDIT RECIPE"
        if #direct == 1 then
            local recipe = direct[1]
            local group = safe(function() return recipe.Selection end)
            local values = safe(function() return recipe.Values end)
            if state then
                state.currentGroup = group
                state.currentRecipe = recipe
                state.currentOldPreset = values
                state.currentNewPreset = info.preset
                state.currentRecipeCommand = commandAddress(recipe)
            end
            lines[#lines + 1] = "Recipe: " .. indexedLabel(recipe, "INDEX", "Recipe 1")
            lines[#lines + 1] = "Group: " .. label(group)
            lines[#lines + 1] = "Old Values: " .. presetText(values, info.feature)
            lines[#lines + 1] = "New Preset: " .. programmerValueText(info)
            lines[#lines + 1] = "Confidence: DIRECT"
        else
            lines[#lines + 1] = string.format("Status: AMBIGUOUS (%d direct Recipes)", #direct)
        end
    else
        local candidates = scanTracking(sequence, currentCue, fixtures, info)
        if #candidates == 1 then
            local item = candidates[1]
            if state then
                state.currentGroup = item.group
                state.currentRecipe = item.recipe
                state.currentOldPreset = item.values
                state.currentNewPreset = info.preset
                state.currentRecipeCommand = cueRecipeCommandAddress(sequence, item.cue, item.part, item.recipe)
            end
            lines[#lines + 1] = "\nSource Cue: " .. cueLabel(item.cue)
            lines[#lines + 1] = "Part: " .. indexedLabel(item.part, "PART", "Part 0")
            lines[#lines + 1] = "Recipe: " .. indexedLabel(item.recipe, "INDEX", "Recipe 1")
            lines[#lines + 1] = "Group: " .. label(item.group)
            lines[#lines + 1] = string.format("Coverage: %d selected / %d in Group", item.selectedCount, item.groupCount)
            lines[#lines + 1] = "Old Values: " .. presetText(item.values, info.feature)
            lines[#lines + 1] = "New Preset: " .. programmerValueText(info)
            lines[#lines + 1] = "Confidence: INFERRED HIGH"
        elseif #candidates == 0 then
            lines[#lines + 1] = "\nStatus: No matching tracking Recipe"
            lines[#lines + 1] = "New Preset: " .. programmerValueText(info)
        else
            lines[#lines + 1] = string.format("\nStatus: AMBIGUOUS (%d matching Recipes)", #candidates)
            lines[#lines + 1] = "New Preset: " .. programmerValueText(info)
            for index, item in ipairs(candidates) do
                if index > 3 then
                    lines[#lines + 1] = string.format("...and %d more", #candidates - 3)
                    break
                end
                lines[#lines + 1] = string.format("%d) Cue %s / %s / %s%s", index,
                    cueLabel(item.cue), indexedLabel(item.part, "PART", "Part 0"),
                    indexedLabel(item.recipe, "INDEX", "Recipe 1"),
                    item.current and " [CURRENT]" or "")
                lines[#lines + 1] = string.format("   %s | %s | %d/%d", label(item.group),
                    tostring(item.values or "UNRESOLVED"), item.selectedCount, item.groupCount)
            end
        end
    end
    if not state or not state.expanded then
        local oldValue, newValue, status, sourceCue
        local group
        for _, line in ipairs(lines) do
            oldValue = oldValue or string.match(line, "^Old Values:%s*(.+)$")
            newValue = newValue or string.match(line, "^New Preset:%s*(.+)$")
            status = status or string.match(line, "^%s*Status:%s*(.+)$")
            group = group or string.match(line, "^Group:%s*(.+)$")
            sourceCue = sourceCue or string.match(line, "^%s*Source Cue:%s*(.+)$")
        end
        local details = oldValue and newValue and {
            "Group: " .. tostring(group or "UNRESOLVED"),
            "Source Cue: " .. tostring(sourceCue or "DIRECT") .. " | Current Cue: " .. cueLabel(currentCue),
            "Old Preset: " .. oldValue,
            "New Preset: " .. newValue
        } or { status or (lines[#lines] or "") }
        if state and state.selectGroup then
            pcall(function() state.selectGroup.Enabled = state.currentGroup and "Yes" or "No" end)
        end
        if state and state.update then
            local changed = state.currentRecipe and state.currentNewPreset
                and commandAddress(state.currentOldPreset) ~= commandAddress(state.currentNewPreset)
            pcall(function() state.update.Enabled = changed and "Yes" or "No" end)
        end
        return table.concat({
            string.format("%s | %d fixture%s", tostring(info.feature or "UNRESOLVED"),
                #fixtures, #fixtures == 1 and "" or "s"),
            table.concat(details, "\n")
        }, "\n")
    end
    if state and state.selectGroup then
        pcall(function() state.selectGroup.Enabled = state.currentGroup and "Yes" or "No" end)
    end
    if state and state.update then
        local changed = state.currentRecipe and state.currentNewPreset
            and commandAddress(state.currentOldPreset) ~= commandAddress(state.currentNewPreset)
        pcall(function() state.update.Enabled = changed and "Yes" or "No" end)
    end
    return table.concat(lines, "\n")
end

local function deleteHandle(handle)
    if handle == nil then return end
    pcall(function()
        if type(handle.CommandDelete) == "function" then handle:CommandDelete()
        elseif type(handle.close) == "function" then handle:close() end
    end)
end

local function stopState(state)
    if state then state.running = false end
end

signalTable.StopRecipeTrackingInspector = function()
    stopState(_G[STATE_KEY])
end

signalTable.ToggleRecipeTrackingDetails = function()
    local state = _G[STATE_KEY]
    if not state then return end
    state.expanded = not state.expanded
    if state.detail then state.detail.Text = state.expanded and "COMPACT" or "DETAIL" end
    if state.window then state.window.H = state.expanded and DETAIL_HEIGHT or COMPACT_HEIGHT end
    state.forceRefresh = true
end

local STYLE_KEYS = { "Transparent75", "Transparent50", "Background" }
local STYLE_LABELS = { "STYLE 75", "STYLE 50", "STYLE SOLID" }

local function styleColor(index)
    local key = STYLE_KEYS[index] or STYLE_KEYS[1]
    local color = "Global." .. key
    local groups = safe(function() return Root().ColorTheme.ColorGroups.Global end)
    if type(groups) == "table" then
        local named = safe(function() return groups[key] end)
        if named ~= nil then color = named end
    end
    return color
end

signalTable.CycleRecipeTrackingStyle = function()
    local state = _G[STATE_KEY]
    if not state or not state.panel then return end
    state.styleIndex = ((state.styleIndex or 1) % 3) + 1
    local color = styleColor(state.styleIndex)
    if state.window then pcall(function() state.window.BackColor = color end) end
    pcall(function() state.panel.BackColor = color end)
    if state.style then state.style.Text = STYLE_LABELS[state.styleIndex] end
end

local function groupCommand(group)
    if group == nil then return nil end
    local number = tonumber(property(group, "No") or property(group, "NO"))
    if number ~= nil then return "Group " .. string.format("%g", number) end
    local parsed = string.match(tostring(group), "^%s*(%d+)")
    if parsed then return "Group " .. parsed end
    local shortAddress = safe(function() return group:ToAddr() end)
    if shortAddress and string.find(string.lower(tostring(shortAddress)), "group", 1, true) then
        return tostring(shortAddress)
    end
    return nil
end

signalTable.SelectRecipeTrackingGroup = function()
    local state = _G[STATE_KEY]
    local command = state and groupCommand(state.currentGroup) or nil
    if command and callable("Cmd") then safe(Cmd, command) end
end

local function notify(title, message)
    if callable("MessageBox") then
        return safe(MessageBox, {
            title = title,
            message = message,
            commands = { { value = 1, name = "OK" } }
        })
    end
    if callable("Printf") then Printf("[RecipeTracking] %s: %s", title, message) end
    return nil
end

signalTable.UpdateRecipeTrackingValue = function()
    local state = _G[STATE_KEY]
    if not state or state.updating then return end

    -- Resolve again at click time. Never write using a stale target from an
    -- earlier refresh cycle.
    render(state)
    local recipe, oldPreset, newPreset = state.currentRecipe,
        state.currentOldPreset, state.currentNewPreset
    local recipeAddress, oldAddress, newAddress = state.currentRecipeCommand,
        commandAddress(oldPreset), commandAddress(newPreset)
    if not recipeAddress or not newAddress or oldAddress == newAddress then
        notify("Recipe Update", "UPDATE is unavailable. Select a uniquely resolved Recipe and call one new Preset for the selected Attribute.")
        return
    end
    if not callable("CreateUndo") or not callable("CloseUndo") or not callable("Cmd") then
        notify("Recipe Update", "This grandMA3 session does not expose the required Undo APIs. No update was performed.")
        return
    end

    local confirmation = safe(MessageBox, {
        title = "Confirm Recipe Update",
        message = table.concat({
            "Target: " .. recipeAddress,
            "Old: " .. presetText(oldPreset),
            "New: " .. presetText(newPreset),
            "",
            "This change will be available as one Oops (Undo)."
        }, "\n"),
        commands = {
            { value = 1, name = "UPDATE" },
            { value = 0, name = "CANCEL" }
        }
    })
    if type(confirmation) ~= "table" or confirmation.success ~= true or confirmation.result ~= 1 then return end

    state.updating = true
    local undo = safe(CreateUndo, "Update Recipe Values")
    if undo == nil then
        state.updating = false
        notify("Recipe Update", "Could not create an Undo transaction. No update was performed.")
        return
    end

    local command = "Assign " .. newAddress .. " At " .. recipeAddress .. " Property \"Values\""
    local feedback = safe(Cmd, command, undo)
    local closed = safe(CloseUndo, undo)
    state.forceRefresh = true

    if feedback == "OK" and closed == true then
        -- Recipe cooking and its object model refresh can finish after Cmd()
        -- returns. Verify from the normal refresh loop instead of reading the
        -- old Recipe handle immediately inside this button callback.
        state.pendingVerification = {
            recipe = recipe,
            recipeAddress = recipeAddress,
            command = command,
            expectedPreset = newPreset,
            expectedAddress = newAddress,
            checksRemaining = 3
        }
        return
    end

    state.updating = false
    notify("Recipe Update Failed", table.concat({
        "grandMA3 did not complete the undo-safe command.",
        "Command feedback: " .. tostring(feedback),
        "Undo close: " .. tostring(closed)
    }, "\n"))
end

local function processPendingVerification(state)
    local pending = state and state.pendingVerification
    if not pending then return end
    pending.checksRemaining = (pending.checksRemaining or 1) - 1
    if pending.checksRemaining > 0 then return end

    state.pendingVerification = nil
    local freshRecipe = pending.recipe
    if callable("ObjectList") then
        local resolved = safe(ObjectList, pending.recipeAddress)
        if type(resolved) == "table" and resolved[1] ~= nil then freshRecipe = resolved[1] end
    end
    local actualPreset = safe(function() return freshRecipe.Values end)
    if sameReference(actualPreset, pending.expectedPreset) then
        state.updating = false
        state.forceRefresh = true
        notify("Recipe Updated", "Recipe Values updated successfully.\nUse Oops once to undo this update.")
        return
    end

    -- The Assign command was accepted and its Undo group closed, so one Oops
    -- targets this update. Restore it when delayed verification still fails.
    local rollback = safe(Cmd, "Oops")
    state.updating = false
    state.forceRefresh = true
    notify("Recipe Update Failed", table.concat({
        "The delayed verification still did not match, so the update was rolled back with Oops.",
        "Expected: " .. tostring(pending.expectedAddress),
        "Actual: " .. tostring(commandAddress(actualPreset) or actualPreset or "nil"),
        "Command: " .. tostring(pending.command),
        "Rollback feedback: " .. tostring(rollback)
    }, "\n"))
end

local function syncTitleWidth(state)
    if not state or not state.window or not state.titleButton then return end
    local rawWidth = safe(function() return state.window.W end)
    local width = tonumber(rawWidth) or tonumber(string.match(tostring(rawWidth or ""), "[%d%.]+"))
    if not width or width < 100 or width == state.lastWindowWidth then return end
    state.lastWindowWidth = width
    local titleWidth = tostring(math.max(64, math.floor(width - 36)))
    pcall(function() state.titleButton.W = titleWidth end)
    pcall(function() state.titleButton.MinSize = titleWidth .. ",36" end)
    pcall(function() state.titleButton.MaxSize = titleWidth .. ",36" end)
end

local function createPanel(state)
    local display = callable("GetFocusDisplay") and safe(GetFocusDisplay) or nil
    if display == nil then return nil, "GetFocusDisplay unavailable" end
    local overlay = safe(function() return display.Fullscreen end)
        or safe(function() return display.ModalOverlay end)
    if overlay == nil then return nil, "Fullscreen/ModalOverlay unavailable" end

    local window = safe(function() return overlay:Append("BaseInput") end)
    if window == nil then return nil, "could not append BaseInput" end
    window.Name = "RecipeTrackingInspectorWindow"
    pcall(function() window.Title = "Cue Recipe Update Tool v" .. PLUGIN_VERSION end)
    pcall(function() window.HasHover = "No" end)
    window.W = PANEL_WIDTH
    window.H = COMPACT_HEIGHT
    window.Columns = 1
    window.Rows = 3
    window[1][1].SizePolicy = "Fixed"
    window[1][1].Size = "36"
    window[1][2].SizePolicy = "Stretch"
    window[1][3].SizePolicy = "Fixed"
    window[1][3].Size = "44"
    window.AutoClose = "No"
    window.CloseOnEscape = "No"
    pcall(function() window.WantsModal = "0" end)

    local title = safe(function() return window:Append("TitleBar") end)
    if title == nil then deleteHandle(window) return nil, "could not append TitleBar" end
    title.Name = "TitleBar"
    title.Anchors = { left = 0, right = 0, top = 0, bottom = 0 }
    pcall(function() title.HasHover = "No" end)
    title.Columns = 1
    title.Rows = 1
    title[1][1].SizePolicy = "Stretch"

    local titleWidth = tostring(PANEL_WIDTH - 36)
    local titleButton = safe(function() return title:Append("TitleButton") end)
    if titleButton == nil then deleteHandle(window) return nil, "could not append TitleButton" end
    titleButton.Anchors = { left = 0, right = 0, top = 0, bottom = 0 }
    pcall(function() titleButton.AlignmentH = "Left" end)
    pcall(function() titleButton.AlignmentV = "Center" end)
    pcall(function() titleButton.W = titleWidth end)
    pcall(function() titleButton.H = "36" end)
    pcall(function() titleButton.MinSize = titleWidth .. ",36" end)
    pcall(function() titleButton.MaxSize = titleWidth .. ",36" end)
    titleButton.Text = "Cue Recipe Update Tool v" .. PLUGIN_VERSION
    pcall(function() titleButton.Font = "Medium20" end)
    pcall(function() titleButton.Texture = "corner1" end)
    titleButton.TextalignmentH = "Left"
    pcall(function() titleButton.Padding = { left = 10, right = 36, top = 0, bottom = 0 } end)

    local close = safe(function() return title:Append("CloseButton") end)
    if close ~= nil then
        close.Anchors = { left = 0, right = 0, top = 0, bottom = 0 }
        pcall(function() close.AlignmentH = "Right" end)
        pcall(function() close.AlignmentV = "Center" end)
        pcall(function() close.W = "36" end)
        pcall(function() close.H = "36" end)
        pcall(function() close.MinSize = "36,36" end)
        pcall(function() close.MaxSize = "36,36" end)
        pcall(function() close.Text = "X" end)
        pcall(function() close.Font = "Regular14" end)
        pcall(function() close.Texture = "corner2" end)
        close.PluginComponent = componentHandle
        close.Clicked = "StopRecipeTrackingInspector"
    end

    local panel = safe(function() return window:Append("UIObject") end)
    if panel == nil then deleteHandle(window) return nil, "could not append content" end
    panel.Name = "RecipeTrackingInspectorContent"
    panel.Anchors = { left = 0, right = 0, top = 1, bottom = 1 }
    panel.Font = "Medium20"
    panel.TextalignmentH = "Left"
    panel.TextalignmentV = "Top"
    panel.TextAutoAdjust = "No"
    panel.Padding = { left = 12, right = 12, top = 8, bottom = 8 }
    pcall(function() panel.HasHover = "No" end)
    pcall(function() panel.BackColor = styleColor(1) end)

    local footer = safe(function() return window:Append("UILayoutGrid") end)
    if footer == nil then deleteHandle(window) return nil, "could not append footer" end
    footer.Anchors = { left = 0, right = 0, top = 2, bottom = 2 }
    footer.Columns = 5
    footer.Rows = 1

    local detail = safe(function() return footer:Append("Button") end)
    if detail == nil then deleteHandle(window) return nil, "could not append detail button" end
    detail.Name = "RecipeTrackingInspectorDetail"
    detail.Anchors = { left = 2, right = 2, top = 0, bottom = 0 }
    detail.Text = "DETAIL"
    detail.Font = "Medium20"
    detail.PluginComponent = componentHandle
    detail.Clicked = "ToggleRecipeTrackingDetails"

    local style = safe(function() return footer:Append("Button") end)
    if style == nil then deleteHandle(window) return nil, "could not append style button" end
    style.Name = "RecipeTrackingInspectorStyle"
    style.Anchors = { left = 3, right = 3, top = 0, bottom = 0 }
    style.Text = "STYLE 75"
    style.Font = "Medium20"
    style.PluginComponent = componentHandle
    style.Clicked = "CycleRecipeTrackingStyle"

    local selectGroup = safe(function() return footer:Append("Button") end)
    if selectGroup == nil then deleteHandle(window) return nil, "could not append select Group button" end
    selectGroup.Name = "RecipeTrackingInspectorSelectGroup"
    selectGroup.Anchors = { left = 0, right = 0, top = 0, bottom = 0 }
    selectGroup.Text = "SELECT GROUP"
    selectGroup.Font = "Medium20"
    selectGroup.PluginComponent = componentHandle
    selectGroup.Clicked = "SelectRecipeTrackingGroup"

    local update = safe(function() return footer:Append("Button") end)
    if update == nil then deleteHandle(window) return nil, "could not append update button" end
    update.Name = "RecipeTrackingInspectorUpdate"
    update.Anchors = { left = 1, right = 1, top = 0, bottom = 0 }
    update.Text = "UPDATE"
    update.Font = "Medium20"
    update.PluginComponent = componentHandle
    update.Clicked = "UpdateRecipeTrackingValue"
    update.Enabled = "No"

    local stop = safe(function() return footer:Append("Button") end)
    if stop == nil then deleteHandle(window) return nil, "could not append stop button" end
    stop.Name = "RecipeTrackingInspectorStop"
    stop.Anchors = { left = 4, right = 4, top = 0, bottom = 0 }
    stop.Text = "STOP"
    stop.Font = "Medium20"
    stop.PluginComponent = componentHandle
    stop.Clicked = "StopRecipeTrackingInspector"
    local resize = safe(function() return window:Append("ResizeCorner") end)
    if resize ~= nil then
        resize.Name = "Resizer"
        resize.Anchors = { left = 0, right = 0, top = 2, bottom = 2 }
        resize.AlignmentH = "Right"
        resize.AlignmentV = "Bottom"
    end

    state.window, state.panel, state.detail, state.style, state.selectGroup, state.update, state.stop =
        window, panel, detail, style, selectGroup, update, stop
    state.titleButton = titleButton
    state.expanded = false
    state.styleIndex = 1
    return panel
end

local function main()
    local existing = _G[STATE_KEY]
    if type(existing) == "table" and existing.running then
        existing.running = false
        return
    end

    local state = { running = true }
    _G[STATE_KEY] = state
    local panel, err = createPanel(state)
    if not panel then
        _G[STATE_KEY] = nil
        if callable("ErrEcho") then ErrEcho("[RecipeTracking] " .. tostring(err)) end
        return
    end

    local previous = nil
    while state.running do
        syncTitleWidth(state)
        processPendingVerification(state)
        local ok, text = pcall(render, state)
        if not ok then text = "RECIPE TRACKING INSPECTOR v" .. PLUGIN_VERSION ..
            "\n\nStatus: ERROR\n" .. tostring(text) end
        if text ~= previous or state.forceRefresh then
            state.forceRefresh = false
            previous = text
            pcall(function() panel.Text = text end)
        end
        coroutine.yield(REFRESH_SECONDS)
    end

    deleteHandle(state.window)
    if _G[STATE_KEY] == state then _G[STATE_KEY] = nil end
end

return main
