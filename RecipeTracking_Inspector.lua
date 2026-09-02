-- grandMA3 Recipe Tracking Inspector - persistent read-only prototype
-- Target: grandMA3 2.3.2.0+

local signalTable = select(3, ...)
local componentHandle = select(4, ...)

local STATE_KEY = "RecipeTrackingInspectorState"
local MAX_SELECTION = 2048
local MAX_CUES = 512
local MAX_RECIPES = 2048
local REFRESH_SECONDS = 0.25

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
    return text
end

local function getProgPhaser(index)
    if not callable("GetProgPhaser") then return nil end
    return safe(GetProgPhaser, index, false) or safe(GetProgPhaser, index)
end

local function readProgrammer(fixtures)
    local presets, rawCount = {}, 0
    if #fixtures == 0 or not callable("GetUIChannels") then
        return { feature = normalizeFeature(selectedFeatureLabel()) }
    end
    for _, fixture in ipairs(fixtures) do
        local channels = safe(GetUIChannels, fixture.handle or fixture.index, true)
        if type(channels) == "table" then
            for _, channel in pairs(channels) do
                local uiIndex = tonumber(property(channel, "INDEX") or property(channel, "Index"))
                if uiIndex then
                    local phaser = getProgPhaser(uiIndex - 1)
                    if type(phaser) == "table" then
                        if type(phaser.abs_preset) == "userdata" then
                            presets[address(phaser.abs_preset)] = phaser.abs_preset
                        else
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
    if #keys == 1 and rawCount == 0 then
        local preset = presets[keys[1]]
        return {
            preset = preset,
            presetAddress = keys[1],
            feature = string.match(keys[1], "PresetPools%.([^%.]+)%.")
                or normalizeFeature(selectedFeatureLabel())
        }
    end
    return {
        feature = normalizeFeature(selectedFeatureLabel()),
        ambiguous = #keys > 1 or rawCount > 0,
        presetCount = #keys,
        rawCount = rawCount
    }
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
    local feature = string.lower(info.feature)
    for _, cue in ipairs(children(sequence)) do
        if cueCount >= MAX_CUES or recipeCount >= MAX_RECIPES then break end
        if string.lower(class(cue)) == "cue" then
            cueCount = cueCount + 1
            for _, part in ipairs(children(cue)) do
                if string.lower(class(part)) == "part" then
                    for _, recipe in ipairs(children(part)) do
                        if recipeCount >= MAX_RECIPES then break end
                        if string.find(string.lower(class(recipe)), "recipe", 1, true) then
                            recipeCount = recipeCount + 1
                            local selection = safe(function() return recipe.Selection end)
                            local values = safe(function() return recipe.Values end)
                            local valueIdentity = string.lower(tostring(values or "") .. " " .. address(values))
                            local subset, exact, selectedCount, groupCount = selectionRelation(selection, fixtures)
                            if subset and string.find(valueIdentity, feature, 1, true) then
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
    return candidates
end

local function render()
    local fixtures = readSelection()
    local info = readProgrammer(fixtures)
    local sequence = callable("SelectedSequence") and safe(SelectedSequence) or nil
    local currentCue = callable("GetCurrentCue") and safe(GetCurrentCue) or nil
    local direct = directRecipes()
    local lines = {
        "RECIPE TRACKING INSPECTOR  [READ-ONLY]",
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
            lines[#lines + 1] = "Recipe: " .. indexedLabel(recipe, "INDEX", "Recipe 1")
            lines[#lines + 1] = "Group: " .. label(group)
            lines[#lines + 1] = "Old Values: " .. tostring(values or "UNRESOLVED")
            lines[#lines + 1] = "New Preset: " .. (info.preset and label(info.preset) or "No Programmer value")
            lines[#lines + 1] = "Confidence: DIRECT"
        else
            lines[#lines + 1] = string.format("Status: AMBIGUOUS (%d direct Recipes)", #direct)
        end
    else
        local candidates = scanTracking(sequence, currentCue, fixtures, info)
        if #candidates == 1 then
            local item = candidates[1]
            lines[#lines + 1] = "\nSource Cue: " .. cueLabel(item.cue)
            lines[#lines + 1] = "Part: " .. indexedLabel(item.part, "PART", "Part 0")
            lines[#lines + 1] = "Recipe: " .. indexedLabel(item.recipe, "INDEX", "Recipe 1")
            lines[#lines + 1] = "Group: " .. label(item.group)
            lines[#lines + 1] = string.format("Coverage: %d selected / %d in Group", item.selectedCount, item.groupCount)
            lines[#lines + 1] = "Old Values: " .. tostring(item.values or "UNRESOLVED")
            lines[#lines + 1] = "New Preset: " .. (info.preset and label(info.preset) or "No Programmer value")
            lines[#lines + 1] = "Confidence: INFERRED HIGH"
        elseif #candidates == 0 then
            lines[#lines + 1] = "\nStatus: No matching tracking Recipe"
            lines[#lines + 1] = "New Preset: " .. (info.preset and label(info.preset) or "No Programmer value")
        else
            lines[#lines + 1] = string.format("\nStatus: AMBIGUOUS (%d matching Recipes)", #candidates)
            lines[#lines + 1] = "New Preset: " .. (info.preset and label(info.preset) or "No Programmer value")
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

local function movePanel(state, x, y)
    if not state or not state.panel or not state.stop then return end
    local maxX = math.max(0, (state.displayWidth or 1920) - 520)
    local maxY = math.max(0, (state.displayHeight or 1080) - 360)
    x = math.max(0, math.min(maxX, math.floor(tonumber(x) or 0)))
    y = math.max(0, math.min(maxY, math.floor(tonumber(y) or 0)))
    state.panelX, state.panelY = x, y
    state.panel.X, state.panel.Y = x, y
    state.stop.X, state.stop.Y = x + 420, y + 306
end

signalTable.StartRecipeTrackingDrag = function(_, _, x, y)
    local state = _G[STATE_KEY]
    if not state then return end
    state.drag = {
        pointerX = tonumber(x) or 0,
        pointerY = tonumber(y) or 0,
        panelX = state.panelX or 0,
        panelY = state.panelY or 0
    }
end

signalTable.UpdateRecipeTrackingDrag = function(_, _, x, y)
    local state = _G[STATE_KEY]
    if not state or not state.drag then return end
    movePanel(state,
        state.drag.panelX + (tonumber(x) or state.drag.pointerX) - state.drag.pointerX,
        state.drag.panelY + (tonumber(y) or state.drag.pointerY) - state.drag.pointerY)
end

signalTable.EndRecipeTrackingDrag = function(_, _, x, y)
    local state = _G[STATE_KEY]
    if state and state.drag then
        movePanel(state,
            state.drag.panelX + (tonumber(x) or state.drag.pointerX) - state.drag.pointerX,
            state.drag.panelY + (tonumber(y) or state.drag.pointerY) - state.drag.pointerY)
        state.drag = nil
    end
end

local function createPanel(state)
    local display = callable("GetFocusDisplay") and safe(GetFocusDisplay) or nil
    if display == nil then return nil, "GetFocusDisplay unavailable" end
    local overlay = safe(function() return display.ModalOverlay end)
    if overlay == nil then return nil, "ModalOverlay unavailable" end

    local panel = safe(function() return overlay:Append("Button") end)
    if panel == nil then return nil, "could not append inspector panel" end
    panel.Name = "RecipeTrackingInspectorPanel"
    local displayWidth = tonumber(display.W) or 1920
    local displayHeight = tonumber(display.H) or 1080
    panel.W = "520"
    panel.H = "360"
    panel.X = math.max(0, displayWidth - 540)
    panel.Y = "20"
    panel.HasHover = "Yes"
    panel.Font = "Medium20"
    panel.TextalignmentH = "Left"
    panel.TextalignmentV = "Top"
    panel.TextAutoAdjust = "No"
    panel.Padding = { left = 16, right = 16, top = 14, bottom = 14 }
    panel.BackColor = Root().ColorTheme.ColorGroups.Global.Transparent75
    panel.PluginComponent = componentHandle
    panel.Clicked = ""
    panel.MouseDown = "StartRecipeTrackingDrag"
    -- Capability-safe onPC movement candidate; real 2.3.2.0 confirmation is
    -- still required. Touch screens use the verified signal names below.
    pcall(function() panel.MouseMove = "UpdateRecipeTrackingDrag" end)
    panel.MouseUp = "EndRecipeTrackingDrag"
    panel.TouchStart = "StartRecipeTrackingDrag"
    panel.TouchUpdate = "UpdateRecipeTrackingDrag"
    panel.TouchEnd = "EndRecipeTrackingDrag"

    local stop = safe(function() return overlay:Append("Button") end)
    if stop == nil then deleteHandle(panel) return nil, "could not append stop button" end
    stop.Name = "RecipeTrackingInspectorStop"
    stop.W = "100"
    stop.H = "44"
    stop.X = math.max(0, displayWidth - 120)
    stop.Y = "326"
    stop.Text = "STOP"
    stop.Font = "Medium20"
    stop.PluginComponent = componentHandle
    stop.Clicked = "StopRecipeTrackingInspector"
    state.panel, state.stop = panel, stop
    state.displayWidth, state.displayHeight = displayWidth, displayHeight
    movePanel(state, displayWidth - 540, 20)
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
        local ok, text = pcall(render)
        if not ok then text = "RECIPE TRACKING INSPECTOR  [READ-ONLY]\n\nStatus: ERROR\n" .. tostring(text) end
        if text ~= previous then
            previous = text
            pcall(function() panel.Text = text end)
        end
        coroutine.yield(REFRESH_SECONDS)
    end

    deleteHandle(state.stop)
    deleteHandle(state.panel)
    if _G[STATE_KEY] == state then _G[STATE_KEY] = nil end
end

return main
