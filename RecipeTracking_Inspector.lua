-- grandMA3 Recipe Tracking Inspector and undo-safe Recipe Values updater
-- Target: grandMA3 2.3.2.0+

local signalTable = select(3, ...)
local componentHandle = select(4, ...)

local PLUGIN_VERSION = "0.7.0.9"
local STATE_KEY = "RecipeTrackingInspectorState"
local PHASER_MARKER_COLOR = "GroupedProgLayerActive.Phaser"
local MAX_SELECTION = 2048
local MAX_CUES = 512
local MAX_RECIPES = 2048
local REFRESH_SECONDS = 0.1
local PANEL_WIDTH = 640
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

local function isRandomGenerator(object)
    local kind = string.lower(class(object))
    return kind == "random" or kind == "generator" or kind == "generatorrandom"
        or safe(function() return object.RandomChannels end) ~= nil
end

local function presetText(object, fallbackFeature)
    if object == nil then return "No Preset" end
    local pool = isRandomGenerator(object) and "Generator"
        or string.match(address(object), "PresetPools%.([^%.]+)") or fallbackFeature
    local reference = tostring(object)
    local name = property(object, "Name") or property(object, "NAME")
    local parts = {}
    if pool and pool ~= "" and pool ~= "UNRESOLVED" then parts[#parts + 1] = pool end
    parts[#parts + 1] = reference
    if name and name ~= "" and name ~= reference then parts[#parts + 1] = '"' .. name .. '"' end
    return table.concat(parts, " | ")
end

local commandAddress
local children
local recipeNumber

local function cueNumber(cue)
    return cue and tonumber(property(cue, "No") or property(cue, "NO")) or nil
end

local function cueRecipeCommandAddress(sequence, cue, part, recipe, fallbackRecipeIndex)
    local sequenceAddress = commandAddress(sequence)
    local rawCue = cueNumber(cue)
    local partNumber = tonumber(property(part, "Part") or property(part, "PART")) or 0
    local recipeIndex = recipeNumber(recipe, fallbackRecipeIndex)
    if not sequenceAddress or not rawCue or partNumber == nil or recipeIndex == nil then return nil end
    return string.format("%s Cue %g Part %g.%g", sequenceAddress, rawCue / 1000,
        partNumber, recipeIndex)
end

local function partNumber(part)
    return tonumber(property(part, "Part") or property(part, "PART")) or 0
end

recipeNumber = function(recipe, fallback)
    local value = tonumber(property(recipe, "Index") or property(recipe, "INDEX")
        or property(recipe, "No") or property(recipe, "NO"))
    return value or fallback
end

local function findCuePart(cue, wantedPart)
    for _, part in ipairs(children(cue)) do
        if string.lower(class(part)) == "part" and partNumber(part) == wantedPart then return part end
    end
    return nil
end

local function nextRecipeIndex(part)
    local highest = 0
    for ordinal, recipe in ipairs(children(part)) do
        if string.find(string.lower(class(recipe)), "recipe", 1, true) then
            local index = recipeNumber(recipe, ordinal)
            if index then highest = math.max(highest, index) end
        end
    end
    return highest + 1
end

local function newCueRecipeCommandAddress(sequence, cue, wantedPart, recipeIndex)
    local sequenceAddress, rawCue = commandAddress(sequence), cueNumber(cue)
    if not sequenceAddress or not rawCue or wantedPart == nil or not recipeIndex then return nil end
    return string.format("%s Cue %g Part %g.%g", sequenceAddress, rawCue / 1000,
        wantedPart, recipeIndex)
end

local function indexedLabel(object, key, fallback)
    return property(object, key) or property(object, string.upper(key)) or fallback
end

local function recipeLabel(recipe, fallback, fallbackRecipeIndex)
    return tostring(recipeNumber(recipe, fallbackRecipeIndex) or indexedLabel(recipe, "INDEX", fallback))
end

local function enabledFlag(object, key)
    local value = safe(function() return object[key] end)
    if value == nil then value = property(object, key) end
    if value == false then return false end
    local normalized = string.lower(tostring(value or "yes"))
    return normalized ~= "no" and normalized ~= "false" and normalized ~= "0" and normalized ~= "off"
end

local function recipeEnabled(recipe)
    -- StandardRecipe.Active is not the editor's Enabled column. grandMA3 2.5
    -- exports valid, cooked Recipe rows as Active="No", Enabled="Yes".
    return enabledFlag(recipe, "Enabled")
end

local function isStandardRecipe(recipe)
    local kind = string.lower(class(recipe))
    return kind == "recipe" or kind == "standardrecipe"
end

children = function(object)
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
    if compact == "rgb" or compact == "colorrgb" or compact == "colourrgb"
        or string.find(compact, "color", 1, true) or string.find(compact, "colour", 1, true) then return "Color" end
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

local function getProgPhaserValue(index, step)
    if not callable("GetProgPhaserValue") then return nil end
    return safe(GetProgPhaserValue, index, step)
end

local generatorHasFeature
local phaserReferences

local function programmerReferenceMatchesFeature(reference, feature)
    if reference == nil then return false end
    if isRandomGenerator(reference) then return generatorHasFeature(reference, feature) end
    local referenceAddress = address(reference)
    local pool = string.match(referenceAddress, "PresetPools%.([^%.]+)%.")
    return pool == feature or pool == "All"
end

local function isObjectReference(value)
    if type(value) == "userdata" then return true end
    if type(value) ~= "table" then return false end
    return type(value.GetClass) == "function" or type(value.ToAddr) == "function"
end

local function readProgrammer(fixtures)
    local presets, assignedAttributes, rawCount = {}, {}, 0
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
                    local references = phaserReferences(phaser, uiIndex - 1)
                    if type(phaser) == "table" or #references > 0 then
                        local attribute = callable("GetAttributeByUIChannel")
                            and safe(GetAttributeByUIChannel, uiIndex - 1) or nil
                        local attributeName = attribute and label(attribute)
                            or property(channel, "SUBATTRIBUTE")
                            or property(channel, "SubAttribute") or property(channel, "Name")
                        local channelFeature = normalizeFeature(attributeName)
                        local reference = nil
                        for _, candidate in ipairs(references) do
                            if programmerReferenceMatchesFeature(candidate, channelFeature) then
                                reference = candidate
                                break
                            end
                        end
                        if reference ~= nil then
                            local referenceAddress = address(reference)
                            if channelFeature == selectedFeature then
                                presets[referenceAddress] = reference
                                if attributeName and attributeName ~= "" then assignedAttributes[attributeName] = true end
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
    local attributes = {}
    for name in pairs(assignedAttributes) do attributes[#attributes + 1] = name end
    table.sort(attributes)
    if #keys == 1 then
        local preset = presets[keys[1]]
        return {
            preset = preset,
            presetAddress = keys[1],
            feature = selectedFeature,
            attributes = attributes,
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

local function readAllProgrammerFeatures(fixtures)
    local buckets = {}
    if #fixtures == 0 or not callable("GetUIChannels") then return {} end
    for _, fixture in ipairs(fixtures) do
        local channels = safe(GetUIChannels, fixture.handle or fixture.index, true)
        if type(channels) == "table" then
            for _, channel in pairs(channels) do
                local uiIndex = tonumber(property(channel, "INDEX") or property(channel, "Index"))
                if uiIndex then
                    local phaser = getProgPhaser(uiIndex - 1)
                    local references = phaserReferences(phaser, uiIndex - 1)
                    if type(phaser) == "table" or #references > 0 then
                        local attribute = callable("GetAttributeByUIChannel")
                            and safe(GetAttributeByUIChannel, uiIndex - 1) or nil
                        local attributeName = attribute and label(attribute)
                            or property(channel, "SUBATTRIBUTE")
                            or property(channel, "SubAttribute") or property(channel, "Name")
                        local feature = normalizeFeature(attributeName)
                        local bucket = buckets[feature]
                        if not bucket then
                            bucket = { feature = feature, presets = {}, attributeSet = {}, rawCount = 0 }
                            buckets[feature] = bucket
                        end
                        if attributeName and attributeName ~= "" then bucket.attributeSet[attributeName] = true end
                        local reference = nil
                        for _, candidate in ipairs(references) do
                            if programmerReferenceMatchesFeature(candidate, feature) then
                                reference = candidate
                                break
                            end
                        end
                        if reference ~= nil then
                            local referenceAddress = address(reference)
                            if referenceAddress ~= "" then
                                bucket.presets[referenceAddress] = reference
                            else
                                bucket.rawCount = bucket.rawCount + 1
                            end
                            if type(phaser[2]) == "table" then bucket.rawCount = bucket.rawCount + 1 end
                        else
                            bucket.rawCount = bucket.rawCount + 1
                        end
                    end
                end
            end
        end
    end
    local result = {}
    for _, bucket in pairs(buckets) do
        local keys, attributes = {}, {}
        for key in pairs(bucket.presets) do keys[#keys + 1] = key end
        for name in pairs(bucket.attributeSet) do attributes[#attributes + 1] = name end
        table.sort(keys)
        table.sort(attributes)
        bucket.attributes = attributes
        bucket.presetCount = #keys
        bucket.ambiguous = #keys > 1 or bucket.rawCount > 0
        if #keys == 1 then
            bucket.presetAddress = keys[1]
            bucket.preset = bucket.presets[keys[1]]
        end
        result[#result + 1] = bucket
    end
    table.sort(result, function(left, right) return tostring(left.feature) < tostring(right.feature) end)
    return result
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
    return "Apply a Preset in Programmer"
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

local function isPhaserRecipePreset(values)
    if not isObjectReference(values) then return false end
    if string.find(string.lower(address(values)), "presetpools.phaser", 1, true) then return true end
    for _, child in ipairs(children(values)) do
        if string.lower(class(child)) == "phaserrecipe" then return true end
    end
    return false
end

local function phaserRecipeHasFeature(values, feature)
    if not isPhaserRecipePreset(values) then return false end
    local wanted = string.lower(tostring(normalizeFeature(feature)))
    local foundAttribute, matched, visited = false, false, 0
    local function visit(node, depth)
        if not node or depth > 6 or visited >= 256 or matched then return end
        visited = visited + 1
        local kind = string.lower(class(node))
        if string.find(kind, "phaserecipevaluesource", 1, true) then
            for _, key in ipairs({"Attributes", "Attribute", "Feature"}) do
                local value = property(node, key)
                if value and value ~= "" and string.lower(value) ~= "none" then
                    foundAttribute = true
                    if string.find(string.lower(value), wanted, 1, true) then matched = true; return end
                end
            end
        end
        for _, child in ipairs(children(node)) do visit(child, depth + 1) end
    end
    visit(values, 0)
    if foundAttribute then return matched end
    -- Some user Phaser presets expose no readable Value Source Attributes. A
    -- feature word in that Phaser Preset's own name is the bounded fallback.
    return string.find(string.lower(label(values)), wanted, 1, true) ~= nil
end

generatorHasFeature = function(values, feature)
    local channels = safe(function() return values.RandomChannels end)
    -- Native 2.3 Random objects contain GeneratorConfigurations and RandomChannels.
    if channels == nil then
        for _, child in ipairs(children(values)) do
            local kind = string.lower(class(child))
            if kind == "randomchannels" or kind == "generatorchannels" then channels = child; break end
        end
    end
    for _, channel in ipairs(children(channels)) do
        local attribute = safe(function() return channel.Attribute end)
        local name
        if type(attribute) == "userdata" or type(attribute) == "table" then
            name = label(attribute)
        else
            name = property(channel, "Attribute") or property(channel, "ATTRIBUTE")
        end
        -- An unassigned Random Channel applies to all Attributes (MA 2.0+).
        local normalized = string.lower(tostring(name or "")):match("^%s*(.-)%s*$")
        if normalized == "" or normalized == "none" or normalized == "all" then return true end
        if normalizeFeature(name) == feature then return true end
    end
    return false
end

phaserReferences = function(phaser, uiIndex)
    local result, seen = {}, {}
    local function add(value)
        if isObjectReference(value) and not seen[value] then
            seen[value] = true
            result[#result + 1] = value
        end
    end
    if type(phaser) == "table" then
        -- Normal preset calls use abs_preset; Generator calls may expose a
        -- generator/integrated reference in the top-level or step table.
        for _, key in ipairs({ "abs_preset", "abs_generator", "generator", "integrated", "value" }) do
            add(phaser[key])
        end
        for _, step in pairs(phaser) do
            if type(step) == "table" then
                for _, key in ipairs({ "abs_preset", "abs_generator", "generator", "integrated", "value" }) do
                    add(step[key])
                end
            end
        end
    end
    for _, stepIndex in ipairs({ 0, 1 }) do
        local step = getProgPhaserValue(uiIndex, stepIndex)
        if type(step) == "table" then
            for _, key in ipairs({ "abs_preset", "abs_generator", "generator", "integrated", "value" }) do
                add(step[key])
            end
        end
    end
    return result
end

local function valuesMatchFeature(values, feature)
    if isRandomGenerator(values) then return generatorHasFeature(values, feature) end
    if isPhaserRecipePreset(values) then return phaserRecipeHasFeature(values, feature) end
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
        if isStandardRecipe(child) and recipeEnabled(child) then
            result[#result + 1] = child
        end
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
                    for ordinal, recipe in ipairs(children(part)) do
                        if recipeCount >= MAX_RECIPES then break end
                        if isStandardRecipe(recipe) and recipeEnabled(recipe) then
                            recipeCount = recipeCount + 1
                            local selection = safe(function() return recipe.Selection end)
                            -- Standard Generator recipe lines store the usable
                            -- handle in Generator; Values is only the display name.
                            local generator = safe(function() return recipe.Generator end)
                            local values = generator or safe(function() return recipe.Values end)
                            local subset, exact, selectedCount, groupCount = selectionRelation(selection, fixtures)
                            if subset and valuesMatchFeature(values, info.feature) then
                                candidates[#candidates + 1] = {
                                    cue = cue, part = part, recipe = recipe, group = selection,
                                    values = values, exact = exact, selectedCount = selectedCount,
                                    groupCount = groupCount, current = cue == currentCue,
                                    recipeIndex = recipeNumber(recipe, ordinal)
                                }
                            end
                        end
                    end
                end
            end
        end
    end
    -- Every candidate contains every selected fixture. Therefore a later
    -- Cue/Part/row overrides an earlier candidate even when its Group differs.
    -- This mirrors the tracked value visible on the selected fixture instead
    -- of presenting stale sources from overlapping Groups.
    local latest = nil
    for _, item in ipairs(candidates) do
        if latest == nil
            or cueNumber(item.cue) > cueNumber(latest.cue)
            or (cueNumber(item.cue) == cueNumber(latest.cue)
                and (partNumber(item.part) > partNumber(latest.part)
                    or (partNumber(item.part) == partNumber(latest.part)
                        and item.recipeIndex > latest.recipeIndex))) then
            latest = item
        end
    end
    return latest and { latest } or {}
end

local function exactSelectionGroups(fixtures)
    local pool = callable("DataPool") and safe(DataPool) or nil
    local groups = safe(function() return pool.Groups end)
    local matches = {}
    for _, group in ipairs(children(groups)) do
        local _, exact = selectionRelation(group, fixtures)
        if exact then matches[#matches + 1] = group end
    end
    return matches
end

local function canCreateRecipe(state)
    return state.currentNewPreset and state.currentSequence and state.currentCue
        and (state.currentGroup or #(state.newGroupCandidates or {}) > 0)
        and type(state.currentAssignedAttributes) == "table" and #state.currentAssignedAttributes > 0
end

local function coloredTextLayers(text)
    local baseLines, sourceLines, currentLines, presetLines = {}, {}, {}, {}
    for line in (tostring(text or "") .. "\n"):gmatch("(.-)\n") do
        local first, last, layer
        local _, sourcePrefixEnd = string.find(line, "^%s*Source Cue:%s*")
        if sourcePrefixEnd then
            first = sourcePrefixEnd + 1
            last = #line
            layer = "source"
        else
            local _, currentPrefixEnd = string.find(line, "^%s*Current Cue:%s*")
            if currentPrefixEnd then
                first = currentPrefixEnd + 1
                last = #line
                layer = "current"
            else
                first = string.find(line, "Preset%s+[%d%.]+")
                if first then
                    last = #line
                    layer = "preset"
                end
            end
        end
        if first and last and last >= first then
            baseLines[#baseLines + 1] = line:sub(1, first - 1)
            sourceLines[#sourceLines + 1] = layer == "source" and line:sub(first, last) or ""
            currentLines[#currentLines + 1] = layer == "current" and line:sub(first, last) or ""
            presetLines[#presetLines + 1] = layer == "preset" and line:sub(first, last) or ""
        else
            baseLines[#baseLines + 1] = line
            sourceLines[#sourceLines + 1] = ""
            currentLines[#currentLines + 1] = ""
            presetLines[#presetLines + 1] = ""
        end
    end
    return table.concat(baseLines, "\n"), table.concat(sourceLines, "\n"),
        table.concat(currentLines, "\n"), table.concat(presetLines, "\n")
end

local function render(state)
    if state then
        state.currentGroup = nil
        state.currentRecipe = nil
        state.currentOldPreset = nil
        state.currentNewPreset = nil
        state.currentRecipeCommand = nil
        state.currentAssignedAttributes = nil
        state.currentSequence = nil
        state.currentCue = nil
        state.currentSourceCue = nil
        state.currentSourceIsCurrent = false
        state.currentPart = nil
        state.newGroupCandidates = {}
        state.matchingCandidates = {}
    end
    local fixtures = readSelection()
    local info = readProgrammer(fixtures)
    local sequence = callable("SelectedSequence") and safe(SelectedSequence) or nil
    local currentCue = callable("GetCurrentCue") and safe(GetCurrentCue) or nil
    local direct = directRecipes()
    if state then
        local context = tostring(commandAddress(sequence)) .. ":" .. tostring(cueNumber(currentCue)) .. ":" .. tostring(info.feature)
        if state.targetContext ~= context then state.targetGroup = nil; state.targetContext = context end
    end
    if state then
        state.currentSequence = sequence
        state.currentCue = currentCue
    end
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
            local values = safe(function() return recipe.Generator end)
                or safe(function() return recipe.Values end)
            if state then
                state.currentGroup = group
                state.currentRecipe = recipe
                state.currentOldPreset = values
                state.currentNewPreset = info.preset
                state.currentRecipeCommand = commandAddress(recipe)
                state.currentAssignedAttributes = info.attributes
                state.currentSourceCue = currentCue
                state.currentSourceIsCurrent = true
            end
            lines[#lines + 1] = "Recipe: " .. recipeLabel(recipe, "Recipe 1")
            lines[#lines + 1] = "Group: " .. label(group)
            lines[#lines + 1] = "Old Values: " .. presetText(values, info.feature)
            lines[#lines + 1] = "New Preset: " .. programmerValueText(info)
            lines[#lines + 1] = "Confidence: DIRECT"
        else
            lines[#lines + 1] = string.format("Status: AMBIGUOUS (%d direct Recipes)", #direct)
        end
    else
        -- Rescan every refresh: Recipe rows can be added or removed in the
        -- Cue editor while the inspector is open. Caching candidates by
        -- (sequence, Cue, feature, selection) kept deleted rows visible as
        -- the source and blocked NEW CONTENT.
        local candidates = scanTracking(sequence, currentCue, fixtures, info)
        if state then state.matchingCandidates = candidates end
        local chosen = #candidates == 1 and candidates[1] or nil
        if state and #candidates > 1 then
            for _, candidate in ipairs(candidates) do
                if sameReference(candidate.group, state.targetGroup) then
                    if chosen then chosen = nil; break end
                    chosen = candidate
                end
            end
        end
        if chosen then
            local item = chosen
            if state then
                state.currentGroup = item.group
                state.currentRecipe = item.recipe
                state.currentOldPreset = item.values
                state.currentNewPreset = info.preset
                state.currentRecipeCommand = cueRecipeCommandAddress(sequence, item.cue, item.part, item.recipe,
                    item.recipeIndex)
                state.currentAssignedAttributes = info.attributes
                state.currentSourceCue = item.cue
                state.currentSourceIsCurrent = item.current
                state.currentPart = item.part
            end
            lines[#lines + 1] = "\nSource Cue: " .. cueLabel(item.cue)
            lines[#lines + 1] = "Part: " .. indexedLabel(item.part, "PART", "Part 0")
            lines[#lines + 1] = "Recipe: " .. recipeLabel(item.recipe, "Recipe 1", item.recipeIndex)
            lines[#lines + 1] = "Group: " .. label(item.group)
            lines[#lines + 1] = string.format("Coverage: %d selected / %d in Group", item.selectedCount, item.groupCount)
            lines[#lines + 1] = "Old Values: " .. presetText(item.values, info.feature)
            lines[#lines + 1] = "New Preset: " .. programmerValueText(info)
            lines[#lines + 1] = "Confidence: INFERRED HIGH"
        elseif #candidates == 0 then
            local groups = exactSelectionGroups(fixtures)
            local group = #groups == 1 and groups[1] or nil
            for _, candidate in ipairs(groups) do
                if state and sameReference(candidate, state.creationGroupOverride) then group = candidate end
            end
            if state then
                state.newGroupCandidates = groups
                state.currentGroup = group
                state.currentNewPreset = not info.ambiguous and info.preset or nil
                state.currentAssignedAttributes = info.attributes
                state.currentPart = findCuePart(currentCue, 0)
            end
            lines[#lines + 1] = "Source Cue: NONE"
            lines[#lines + 1] = "Group: " .. (group and label(group) or
                (#groups > 1 and "Choose Group in UPDATE" or "Select a complete stored Group"))
            lines[#lines + 1] = "Old Values: No source Recipe"
            lines[#lines + 1] = "New Preset: " .. programmerValueText(info)
            lines[#lines + 1] = "Status: " .. (#groups > 0 and "NEW CONTENT available with one Preset" or
                "No exact Group matches the selection")
        else
            lines[#lines + 1] = "Status: Multiple Groups - choose SELECT GROUP"
            lines[#lines + 1] = "New Preset: " .. programmerValueText(info)
        end
    end
    if state and #state.matchingCandidates > 1 then
        local overview = {
            string.format("%s | %d fixtures | %d matching Groups", tostring(info.feature), #fixtures, #state.matchingCandidates),
            "Current Cue: " .. cueLabel(currentCue),
            "Target: " .. (state.currentGroup and label(state.currentGroup) or "Choose SELECT GROUP"),
            "New Preset: " .. programmerValueText(info),
            ""
        }
        for index, item in ipairs(state.matchingCandidates) do
            overview[#overview + 1] = (sameReference(item.group, state.currentGroup) and "> " or "  ") ..
                tostring(index) .. ". " .. label(item.group) .. " | Cue " .. cueLabel(item.cue)
            overview[#overview + 1] = "     Part " .. tostring(partNumber(item.part)) .. " / Recipe " ..
                tostring(item.recipeIndex or recipeNumber(item.recipe) or "?") .. " | " .. presetText(item.values, info.feature)
        end
        if state.selectGroup then state.selectGroup.Enabled = "Yes" end
        if state.update then
            local changed = state.currentRecipe and state.currentNewPreset
                and type(state.currentAssignedAttributes) == "table" and #state.currentAssignedAttributes > 0
                and not sameReference(state.currentOldPreset, state.currentNewPreset)
            state.update.Enabled = not state.updating and (changed or canCreateRecipe(state)) and "Yes" or "No"
        end
        state.overviewCount = #state.matchingCandidates
        return table.concat(overview, "\n"), "", "", ""
    elseif state and state.overviewCount then
        state.overviewCount = nil
        if state.window then state.window.H = state.expanded and DETAIL_HEIGHT or COMPACT_HEIGHT end
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
            "Current Cue: " .. cueLabel(currentCue),
            "Source Cue: " .. tostring(sourceCue or "DIRECT"),
            "Old Preset: " .. oldValue,
            "New Preset: " .. newValue
        } or { status or (lines[#lines] or "") }
        if state and state.selectGroup then
            pcall(function() state.selectGroup.Enabled = state.currentGroup and "Yes" or "No" end)
        end
        if state and state.update then
            local changed = state.currentRecipe and state.currentNewPreset
                and type(state.currentAssignedAttributes) == "table" and #state.currentAssignedAttributes > 0
                and commandAddress(state.currentOldPreset) ~= commandAddress(state.currentNewPreset)
            local canCreate = canCreateRecipe(state)
            pcall(function() state.update.Enabled = (not state.updating and (changed or canCreate)) and "Yes" or "No" end)
        end
        return coloredTextLayers(table.concat({
            string.format("%s | %d fixture%s", tostring(info.feature or "UNRESOLVED"),
                #fixtures, #fixtures == 1 and "" or "s"),
            table.concat(details, "\n")
        }, "\n"))
    end
    if state and state.selectGroup then
        pcall(function() state.selectGroup.Enabled = state.currentGroup and "Yes" or "No" end)
    end
    if state and state.update then
        local changed = state.currentRecipe and state.currentNewPreset
            and type(state.currentAssignedAttributes) == "table" and #state.currentAssignedAttributes > 0
            and commandAddress(state.currentOldPreset) ~= commandAddress(state.currentNewPreset)
        local canCreate = canCreateRecipe(state)
        pcall(function() state.update.Enabled = (not state.updating and (changed or canCreate)) and "Yes" or "No" end)
    end
    return coloredTextLayers(table.concat(lines, "\n"))
end

local function deleteHandle(handle)
    if handle == nil then return end
    pcall(function()
        if type(handle.CommandDelete) == "function" then handle:CommandDelete()
        elseif type(handle.close) == "function" then handle:close() end
    end)
end

local function stopState(state)
    if state then
        state.running = false
        for _, entry in pairs(state.poolMarkers or {}) do deleteHandle(entry.overlay) end
        state.poolMarkers = {}
    end
end

local function recipePoolReferences(state)
    local references = {}
    local function add(object)
        local key = commandAddress(object)
        if key then references[key] = object end
    end
    local function addRecipe(recipe)
        for _, name in ipairs({ "Selection", "Values", "MAtricks", "Filter", "World", "Generator" }) do
            add(safe(function() return recipe[name] end))
        end
    end
    if state.currentRecipe then
        addRecipe(state.currentRecipe)
    else
        for _, item in ipairs(state.matchingCandidates or {}) do addRecipe(item.recipe) end
    end
    add(state.currentGroup)
    return references
end

local function clearPoolMarkers(state)
    for _, entry in pairs(state.poolMarkers or {}) do deleteHandle(entry.overlay) end
    state.poolMarkers = {}
end

-- Read stored/cooked Cue data, never Programmer data or commands. Resolve each
-- channel layer independently so a static absolute value keeps a relative FX.
local function cueEffectLayer(phaser, prefix, valueKey)
    local touched, released, steps = phaser[prefix .. "_preset"] ~= nil, false, 0
    local refs, seen = {}, {}
    local function add(ref)
        if isObjectReference(ref) and not seen[ref] then
            seen[ref], refs[#refs + 1] = true, ref
        end
    end
    add(phaser[prefix .. "_preset"])
    add(phaser[prefix .. "_generator"])
    if prefix == "abs" then add(phaser.generator) end
    if #refs > 0 then touched = true end
    for index, step in pairs(phaser) do
        if type(index) == "number" and type(step) == "table" then
            if step[valueKey] ~= nil or step[prefix .. "_release"] or step[prefix .. "_remove"] then
                touched = true
                steps = steps + 1
            end
            if step[prefix .. "_release"] or step[prefix .. "_remove"] then released = true end
            add(step[prefix .. "_preset"])
            if prefix == "abs" and isObjectReference(step.integrated) then
                touched = true
                add(step.integrated)
            end
        end
    end
    local moving = steps > 1
    for _, ref in ipairs(refs) do if isRandomGenerator(ref) then moving = true end end
    return touched, moving and not released, refs
end

local function newCueEffectScan(sequence, currentCue)
    local scan = {tracked = {}, parts = {}, index = 1, work = 0}
    if not sequence or not cueNumber(currentCue) or not callable("GetPresetData") then
        scan.done, scan.result = true, {}
        return scan
    end
    local cues = {}
    for _, cue in ipairs(children(sequence)) do
        local number = cueNumber(cue)
        if string.lower(class(cue)) == "cue" and number and number <= cueNumber(currentCue) then
            cues[#cues + 1] = cue
        end
    end
    if #cues > MAX_CUES then error("Cue effect scan exceeds 512 Cues") end
    table.sort(cues, function(a, b) return cueNumber(a) < cueNumber(b) end)
    for _, cue in ipairs(cues) do
        local parts = {}
        for _, part in ipairs(children(cue)) do
            if string.lower(class(part)) == "part" then parts[#parts + 1] = part end
        end
        table.sort(parts, function(a, b) return partNumber(a) < partNumber(b) end)
        for _, part in ipairs(parts) do scan.parts[#scan.parts + 1] = part end
    end
    return scan
end

local function scanCheckpoint(scan)
    scan.work = scan.work + 1
    if scan.work > 131072 then error("Cue effect scan limit exceeded") end
end

local function scanCueEffectPart(scan, part)
    local pending = scan.pendingPart
    local data = pending and pending.data or safe(GetPresetData, part, false, false)
    if type(data) ~= "table" then error("Cue effect data unavailable") end
    local recipes = pending and pending.recipes or {}
    if not pending then
    for ordinal, recipe in ipairs(children(part)) do
        scanCheckpoint(scan)
        if isStandardRecipe(recipe) and recipeEnabled(recipe) then
            local group = safe(function() return recipe.Selection end)
            local members = safe(function() return group.Selection end)
            local ref = safe(function() return recipe.Generator end)
            if not isObjectReference(ref) then ref = safe(function() return recipe.Values end) end
            if type(members) == "table" and isObjectReference(ref) then
                local selection = {}
                for _, member in pairs(members) do
                    scanCheckpoint(scan)
                    if type(member) == "table" and tonumber(member.sf_index) then
                        selection[tonumber(member.sf_index)] = true
                    end
                end
                recipes[#recipes + 1] = {
                    ref = ref, members = selection, featureMatches = {}, index = recipeNumber(recipe, ordinal)
                }
            end
        end
    end
    table.sort(recipes, function(a, b) return a.index > b.index end)
    pending = {data = data, recipes = recipes}
    scan.pendingPart = pending
    end
    for batch = 1, 32 do
        local index, phaser = next(data, pending.key)
        if index == nil then scan.pendingPart = nil; return true end
        pending.key = index
        scanCheckpoint(scan)
        if type(index) == "number" and type(phaser) == "table" then
            local ui = callable("GetUIChannel") and safe(GetUIChannel, index)
            local rt = ui and callable("GetRTChannel") and safe(GetRTChannel, ui.rt_index)
            local fixture = rt and (rt.fixture or rt.subfixture)
            local sf = rt and (rt.subfixture or rt.fixture)
            local sfIndex = tonumber(property(sf, "SubfixtureIndex"))
            local attribute = callable("GetAttributeByUIChannel") and safe(GetAttributeByUIChannel, index)
            local layers = scan.tracked[index] or {}
            scan.tracked[index] = layers
            for _, layer in ipairs({{"abs", "absolute"}, {"rel", "relative"}}) do
                local touched, moving, refs = cueEffectLayer(phaser, layer[1], layer[2])
                if touched then
                    -- Cooked Phaser Recipe/Generator channels may expose only
                    -- underlying value links. Recover the applied Pool object
                    -- from an enabled row in this same Part and channel feature.
                    if moving and attribute then
                        local recovered, recoveredSeen = {}, {}
                        for _, recipe in ipairs(recipes) do
                            scanCheckpoint(scan)
                            local feature = normalizeFeature(label(attribute))
                            if recipe.featureMatches[feature] == nil then
                                recipe.featureMatches[feature] = valuesMatchFeature(recipe.ref, feature)
                            end
                            if (sfIndex == nil or recipe.members[sfIndex])
                                and recipe.featureMatches[feature] then
                                -- The matching StandardRecipe is the Pool object
                                -- the user called. Cooked Phaser data may expose
                                -- only its Shape or integrated step Presets.
                                local key = commandAddress(recipe.ref)
                                if key and not recoveredSeen[key] then
                                    recoveredSeen[key], recovered[#recovered + 1] = true, recipe.ref
                                end
                                -- With a subfixture identity, the latest matching
                                -- Recipe row is the exact source for this channel.
                                if sfIndex ~= nil then break end
                            end
                        end
                        if #recovered > 0 then refs = recovered end
                    end
                    layers[layer[1]] = moving and {refs = refs, fixture = fixture} or nil
                end
            end
        end
    end
end

local function finishCueEffectScan(scan)
    local result = {}
    for _, layers in pairs(scan.tracked) do
        scanCheckpoint(scan)
        for _, item in pairs(layers) do
            for _, ref in ipairs(item.refs) do
                local key = commandAddress(ref)
                if key then
                    local entry = result[key] or {object = ref, fixtures = {}, count = 0}
                    result[key] = entry
                    if item.fixture then
                        local fixtureKey = address(item.fixture)
                        if not entry.fixtures[fixtureKey] then
                            entry.fixtures[fixtureKey], entry.count = true, entry.count + 1
                        end
                    end
                end
            end
        end
    end
    scan.done, scan.result = true, result
    return result
end

local function advanceCueEffectScan(scan)
    if scan.done then return scan.result end
    local part = scan.parts[scan.index]
    if part then
        if scanCueEffectPart(scan, part) then scan.index = scan.index + 1 end
    end
    if scan.index > #scan.parts then return finishCueEffectScan(scan) end
    return nil
end

-- A Phaser Recipe or Generator stored directly in the current Cue is already
-- authoritative for its Pool object. Publish it immediately instead of making
-- the UI wait for (or depend entirely on) the cooked tracking-data scan.
local function currentCueRecipeEffects(cue)
    local result = {}
    if not cue then return result end
    for _, part in ipairs(children(cue)) do
        if string.lower(class(part)) == "part" then
            for _, recipe in ipairs(children(part)) do
                if isStandardRecipe(recipe) and recipeEnabled(recipe) then
                    local ref = safe(function() return recipe.Generator end)
                    if not isObjectReference(ref) then ref = safe(function() return recipe.Values end) end
                    if isObjectReference(ref) and (isPhaserRecipePreset(ref) or isRandomGenerator(ref)) then
                        local key = commandAddress(ref)
                        if key then result[key] = {object = ref, fixtures = {}, count = 0} end
                    end
                end
            end
        end
    end
    return result
end

local function addCurrentCueRecipeEffects(result, direct)
    result = type(result) == "table" and result or {}
    for key, entry in pairs(direct or {}) do
        if result[key] == nil then result[key] = entry end
    end
    return result
end

local function refreshCueEffects(state, allowScan)
    local sequence = callable("SelectedSequence") and safe(SelectedSequence)
    local cue = sequence and callable("GetCurrentCue") and safe(GetCurrentCue)
    local sequenceKey = commandAddress(sequence) or address(sequence)
    local cueKey = commandAddress(cue) or (sequenceKey .. ":" .. tostring(cueNumber(cue) or ""))
    local changed = state.effectSequenceKey ~= sequenceKey or state.effectCueKey ~= cueKey
    if changed then
        state.effectSequenceKey, state.effectCueKey = sequenceKey, cueKey
        state.effectSequence, state.effectCue = sequence, cue
        state.currentCueEffects = currentCueRecipeEffects(cue)
        if state.effectCacheSequence ~= sequenceKey then
            state.effectCacheSequence, state.effectCache, state.effectCacheOrder = sequenceKey, {}, {}
        end
        local cached = state.effectCache[cueKey]
        state.activeEffects = addCurrentCueRecipeEffects(cached and cached.result or {}, state.currentCueEffects)
        state.effectScanner = nil
        state.effectScanPending, state.effectWait = cached == nil, 1
        state.poolMarkersDirty = true
    end
    -- A selected Sequence can expose a valid Current Cue while its executor is
    -- stopped or being edited. Pool usage follows that Cue, not playback state.
    if state.poolBlink == false or not sequence or not cue then
        state.activeEffects, state.currentCueEffects, state.effectScanner = {}, {}, nil
        state.effectScanPending, state.effectWait = false, 0
        return
    end
    if allowScan == false then return end
    state.effectWait = (state.effectWait or 0) - 1
    if state.effectScanPending and not state.effectScanner and state.effectWait <= 0 then
        state.effectScanner = newCueEffectScan(sequence, cue)
    end
    if state.effectScanner then
        -- One potentially expensive GetPresetData Part per host tick prevents
        -- large Showfiles from blocking selection and panel refresh for seconds.
        local ok, result = pcall(advanceCueEffectScan, state.effectScanner)
        if not ok or state.effectScanner.done then
            state.activeEffects = addCurrentCueRecipeEffects(ok and result or {}, state.currentCueEffects)
            local errorText = not ok and tostring(result) or nil
            if errorText and state.effectError ~= errorText and callable("ErrEcho") then
                safe(ErrEcho, "[RecipeTracking] " .. errorText)
            end
            state.effectError = errorText
            if ok then
                state.effectCache[cueKey] = {result = state.activeEffects}
                state.effectCacheOrder[#state.effectCacheOrder + 1] = cueKey
                if #state.effectCacheOrder > 32 then
                    state.effectCache[table.remove(state.effectCacheOrder, 1)] = nil
                end
                state.poolMarkersDirty = true
            end
            -- Do not continuously rescan an unchanged Cue. The previous 2-second
            -- restart loop dominated plugin time in large Showfiles.
            state.effectScanner, state.effectScanPending, state.effectWait = nil, false, 0
        end
    end
end

local function refreshPoolMarkers(state)
    if state.poolBlink == false or not state.running then clearPoolMarkers(state); return end
    state.poolBlinkTicks = (state.poolBlinkTicks or 0) + 1
    -- Pulse existing frames at 4 Hz without rescanning the UI tree. Pool lookup
    -- remains at 2 Hz, so the faster animation does not double traversal cost.
    state.poolBlinkOn = not state.poolBlinkOn
    local pulseColor = state.poolBlinkOn and "Global.SuccessText" or "Global.Selected"
    for _, entry in pairs(state.poolMarkers or {}) do
        pcall(function()
            entry.overlay.Visible = "Yes"
            entry.overlay.BackColor = entry.activeEffect and PHASER_MARKER_COLOR or pulseColor
        end)
    end
    if state.poolBlinkTicks % 2 ~= 0 and not state.poolMarkersDirty then return end
    state.poolMarkersDirty = false
    local references = recipePoolReferences(state)
    local effects = state.activeEffects or {}
    local markers, found = state.poolMarkers or {}, {}
    state.poolMarkers = markers
    local function uiChildren(object)
        local result = safe(function() return object:UIChildren() end)
        return type(result) == "table" and result or children(object)
    end
    local function isPoolItemButton(object)
        local kind = string.lower(class(object))
        return string.find(kind, "poolbutton", 1, true) ~= nil
            and string.find(kind, "pooltitlebutton", 1, true) == nil
    end
    local function valid(object)
        if object == nil then return false end
        if not callable("IsObjectValid") then return true end
        local status = safe(IsObjectValid, object)
        return status ~= nil and status ~= false
    end
    local grids = {}
    for _, grid in ipairs(state.poolGrids or {}) do
        if valid(grid) then grids[#grids + 1] = grid end
    end
    if #grids == 0 then
        -- Discover the expensive display tree only on startup or after every
        -- cached Pool grid becomes invalid. Visible buttons still update at 2 Hz.
        grids = {}
        local visited, budget = {}, 6000
        local function visit(node, depth)
            if not node or visited[node] or depth > 20 or budget <= 0 then return end
            visited[node], budget = true, budget - 1
            if node == state.window then return end
            if string.find(class(node), "PoolLayoutGrid", 1, true) then
                grids[#grids + 1] = node
                return
            end
            for _, child in ipairs(uiChildren(node)) do visit(child, depth + 1) end
        end
        if callable("GetDisplayByIndex") then
            for index = 1, 7 do visit(safe(GetDisplayByIndex, index), 0) end
        elseif callable("GetFocusDisplay") then
            visit(safe(GetFocusDisplay), 0)
        end
        state.poolGrids = grids
    else
        state.poolGrids = grids
    end
    local function scanGrid(node)
        local pool = safe(function() return node.PoolObject end)
        for _, button in ipairs(uiChildren(node)) do
            local index = isPoolItemButton(button)
                and tonumber(property(button, "ObjectIndex")) or nil
            local object = index and safe(function() return pool:Ptr(index) end) or nil
            local key = commandAddress(object)
            if key and (references[key] or effects[key]) then
                found[button] = true
                local entry = markers[button]
                if entry and not valid(entry.overlay) then markers[button], entry = nil, nil end
                if not entry then
                    -- Put the frame on the grid after its buttons so the Pool item
                    -- cannot paint over it. Preserve the button's cell anchors.
                    local overlay = safe(function() return node:Append("UIObject") end)
                    local onGrid = overlay ~= nil
                    if not overlay then overlay = safe(function() return button:Append("UIObject") end) end
                    if overlay then
                        local ok = pcall(function()
                            overlay.Name = "RecipeTrackingPoolMarker"
                            overlay.Anchors = onGrid and button.Anchors
                                or { left = 0, right = 0, top = 0, bottom = 0 }
                            overlay.Texture = "frame0"
                            overlay.BackColor = pulseColor
                            overlay.HasHover = "No"
                            overlay.Interactive = "No"
                        end)
                        if ok then
                            entry = { overlay = overlay }
                            markers[button] = entry
                        else
                            deleteHandle(overlay)
                        end
                    end
                end
                if entry then
                    entry.activeEffect = effects[key] ~= nil
                    pcall(function()
                        entry.overlay.W = button.W
                        entry.overlay.H = button.H
                        entry.overlay.Visible = "Yes"
                        entry.overlay.BackColor = entry.activeEffect and PHASER_MARKER_COLOR or pulseColor
                        entry.overlay.Text = ""
                    end)
                end
            end
        end
    end
    for _, grid in ipairs(grids) do scanGrid(grid) end
    for button, entry in pairs(markers) do
        if not found[button] then deleteHandle(entry.overlay); markers[button] = nil end
    end
end

signalTable.StopRecipeTrackingInspector = function()
    stopState(_G[STATE_KEY])
end

local notify

signalTable.ToggleRecipeTrackingDetails = function()
    local state = _G[STATE_KEY]
    if not state then return end
    state.expanded = not state.expanded
    state.autoFitLines = nil
    if state.detail then state.detail.Text = state.expanded and "COMPACT" or "DETAIL" end
    if state.window then state.window.H = state.expanded and DETAIL_HEIGHT or COMPACT_HEIGHT end
    state.forceRefresh = true
end

local function fitCompactWindowToText(state, text)
    if not state or not state.window or state.expanded then return end
    local visualLines = 0
    for line in (tostring(text or "") .. "\n"):gmatch("(.-)\n") do
        visualLines = visualLines + math.max(1, math.ceil(#line / 58))
    end
    if state.autoFitLines ~= visualLines then
        state.window.H = math.min(720, math.max(COMPACT_HEIGHT, 92 + visualLines * 20))
        state.autoFitLines = visualLines
    end
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

signalTable.ShowRecipeTrackingBatchPreview = function()
    local fixtures = readSelection()
    if #fixtures == 0 then
        notify("Batch Preview", "Select one or more fixtures first.")
        return
    end
    local sequence = callable("SelectedSequence") and safe(SelectedSequence) or nil
    local currentCue = callable("GetCurrentCue") and safe(GetCurrentCue) or nil
    local features = readAllProgrammerFeatures(fixtures)
    local lines = {
        "READ-ONLY BATCH PREVIEW",
        string.format("Selection: %d fixture%s", #fixtures, #fixtures == 1 and "" or "s"),
        "Current Cue: " .. cueLabel(currentCue),
        ""
    }
    if #features == 0 then
        lines[#lines + 1] = "No active Programmer attributes found."
    end
    for index, info in ipairs(features) do
        if index > 12 then
            lines[#lines + 1] = string.format("...and %d more feature%s", #features - 12,
                (#features - 12) == 1 and "" or "s")
            break
        end
        lines[#lines + 1] = string.format("%d) %s", index, tostring(info.feature))
        lines[#lines + 1] = "   New: " .. programmerValueText(info)
        if info.ambiguous or not info.preset then
            lines[#lines + 1] = "   Status: REVIEW ONLY - raw, Phaser, or ambiguous Programmer data"
        else
            local candidates = scanTracking(sequence, currentCue, fixtures, info)
            if #candidates == 1 then
                local item = candidates[1]
                lines[#lines + 1] = string.format("   Source: Cue %s | %s | %s",
                    cueLabel(item.cue), label(item.group), presetText(item.values, info.feature))
                lines[#lines + 1] = "   Available: ORIGINAL | " ..
                    (item.current and "CURRENT CUE | " or "") .. "NEW CONTENT"
            elseif #candidates == 0 then
                lines[#lines + 1] = "   Status: NO MATCHING TRACKING RECIPE"
            else
                lines[#lines + 1] = string.format("   Status: AMBIGUOUS (%d matching Recipes)", #candidates)
            end
        end
        lines[#lines + 1] = ""
    end
    notify("Batch Preview v" .. PLUGIN_VERSION, table.concat(lines, "\n"))
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
    if not state or state.updating then return end
    render(state)
    local candidates = state.matchingCandidates or {}
    local group = state.currentGroup
    if #candidates > 1 then
        local commands = { { value = 0, name = "CANCEL" } }
        for index, item in ipairs(candidates) do
            commands[#commands + 1] = {
                value = index,
                name = (groupCommand(item.group) or "Group") .. " " .. label(item.group)
            }
        end
        local result = safe(MessageBox, {
            title = "Select Group",
            message = "Choose the Group to select and use for ORIGINAL CONTENT / NEW CONTENT.",
            commands = commands
        })
        if type(result) ~= "table" or result.success ~= true or not candidates[result.result] then return end
        group = candidates[result.result].group
    end
    local command = groupCommand(group)
    if command and callable("Cmd") then
        safe(Cmd, "ClearSelection")
        local result = safe(Cmd, "SelectFixtures " .. command)
        if result == "OK" then
            state.targetGroup = group
            state.creationGroupOverride = group
            state.forceRefresh = true
        end
    end
end

notify = function(title, message)
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

local function updateRecipeTrackingValue(updateMode)
    local state = _G[STATE_KEY]
    if not state or state.updating then return end

    -- Resolve again at click time. Never write using a stale target from an
    -- earlier refresh cycle.
    render(state)
    local recipe, oldPreset, newPreset = state.currentRecipe,
        state.currentOldPreset, state.currentNewPreset
    local assignedAttributes = state.currentAssignedAttributes
    local recipeAddress, oldAddress, newAddress = state.currentRecipeCommand,
        commandAddress(oldPreset), commandAddress(newPreset)
    if updateMode == "current" and not state.currentSourceIsCurrent then
        notify("Recipe Update", "UPDATE CURRENT CUE is only available when the resolved Recipe already belongs to the current Cue. Use UPDATE NEW CONTENT to create a new Recipe here.")
        return
    end
    local createRecipe, createCommand, groupAssignCommand = updateMode == "new", nil, nil
    if createRecipe then
        local wantedPart = partNumber(state.currentPart) or 0
        local currentPart = wantedPart ~= nil and findCuePart(state.currentCue, wantedPart) or nil
        local recipeIndex = currentPart and nextRecipeIndex(currentPart) or 1
        recipeAddress = newCueRecipeCommandAddress(state.currentSequence, state.currentCue,
            wantedPart, recipeIndex)
        local groupAddress = groupCommand(state.currentGroup)
        if recipeAddress and groupAddress then
            createRecipe = true
            createCommand = "Store " .. recipeAddress ..
                " /Selection \"No\" /PhaserData \"No\" /Matricks \"No\" /NoConfirmation"
            groupAssignCommand = "Assign " .. groupAddress .. " At " .. recipeAddress ..
                " Property \"Selection\""
            oldPreset, oldAddress = nil, nil
        else
            recipeAddress = nil
        end
    end
    if not recipeAddress or not newAddress or oldAddress == newAddress
        or type(assignedAttributes) ~= "table" or #assignedAttributes == 0 then
        notify("Recipe Update", "UPDATE is unavailable. Select a uniquely resolved Recipe and call one new Preset for the selected Attribute.")
        return
    end
    if not callable("CreateUndo") or not callable("CloseUndo") or not callable("Cmd") then
        notify("Recipe Update", "This grandMA3 session does not expose the required Undo APIs. No update was performed.")
        return
    end

    state.updating = true
    local undo = safe(CreateUndo, "Update Recipe Values")
    if undo == nil then
        state.updating = false
        notify("Recipe Update", "Could not create an Undo transaction. No update was performed.")
        return
    end

    local createFeedback, groupFeedback = "OK", "OK"
    if createRecipe then
        createFeedback = safe(Cmd, createCommand, undo)
        if createFeedback == "OK" then groupFeedback = safe(Cmd, groupAssignCommand, undo) end
    end
    local command = "Assign " .. newAddress .. " At " .. recipeAddress .. " Property \"Values\""
    local assignFeedback = (createFeedback == "OK" and groupFeedback == "OK")
        and safe(Cmd, command, undo) or "SKIPPED"
    local clearFeedback, clearCommand = "OK", nil
    for _, attributeName in ipairs(assignFeedback == "OK" and assignedAttributes or {}) do
        local safeName = string.gsub(tostring(attributeName), "[\"\r\n]", "")
        local attributeCommand = "Off Attribute \"" .. safeName .. "\""
        local result = safe(Cmd, attributeCommand, undo)
        clearCommand = clearCommand and (clearCommand .. "; " .. attributeCommand) or attributeCommand
        if result ~= "OK" then clearFeedback = result end
    end
    local closed = safe(CloseUndo, undo)
    state.forceRefresh = true

    if createFeedback == "OK" and groupFeedback == "OK"
        and assignFeedback == "OK" and clearFeedback == "OK" and closed == true then
        -- Recipe cooking and its object model refresh can finish after Cmd()
        -- returns. Verify from the normal refresh loop instead of reading the
        -- old Recipe handle immediately inside this button callback.
        state.pendingVerification = {
            targets = {
                {
                    recipe = createRecipe and nil or recipe,
                    recipeAddress = recipeAddress,
                    expectedPreset = newPreset,
                    expectedGroup = createRecipe and state.currentGroup or nil,
                    expectedAddress = newAddress
                }
            },
            command = command,
            clearCommand = clearCommand,
            checksRemaining = 3
        }
        return
    end

    local rollback = nil
    if closed == true then rollback = safe(Cmd, "Oops") end
    state.updating = false
    notify("Recipe Update Failed", table.concat({
        "grandMA3 did not complete both undo-safe commands, so the transaction was rolled back when possible.",
        "Assign feedback: " .. tostring(assignFeedback),
        "Create feedback: " .. tostring(createFeedback),
        "Group feedback: " .. tostring(groupFeedback),
        "Programmer cleanup feedback: " .. tostring(clearFeedback),
        "Undo close: " .. tostring(closed),
        "Rollback feedback: " .. tostring(rollback)
    }, "\n"))
end


signalTable.UpdateRecipeTrackingValue = function()
    updateRecipeTrackingValue("original")
end

signalTable.UpdateCurrentCueRecipe = function()
    updateRecipeTrackingValue("current")
end

signalTable.UpdateNewCueRecipe = function()
    updateRecipeTrackingValue("new")
end

signalTable.ShowRecipeTrackingUpdateMenu = function()
    local state = _G[STATE_KEY]
    if not state or state.updating then return end
    render(state)
    if not state.currentGroup and #(state.newGroupCandidates or {}) > 1 then
        local choices = { { value = 0, name = "CANCEL" } }
        local groups = state.newGroupCandidates
        for index, group in ipairs(groups) do
            choices[#choices + 1] = { value = index, name = groupCommand(group) .. " " .. label(group) }
        end
        local choice = safe(MessageBox, {
            title = "Choose Group",
            message = "These Groups contain the same selected fixtures. Choose the Group for NEW CONTENT.",
            commands = choices
        })
        if type(choice) ~= "table" or choice.success ~= true or not groups[choice.result] then return end
        state.creationGroupOverride = groups[choice.result]
        render(state)
    end
    local commands = { { value = 0, name = "CANCEL" } }
    local hasPreset = state.currentRecipe and state.currentNewPreset
        and type(state.currentAssignedAttributes) == "table" and #state.currentAssignedAttributes > 0
    if hasPreset and commandAddress(state.currentOldPreset) ~= commandAddress(state.currentNewPreset) then
        commands[#commands + 1] = { value = 1, name = "ORIGINAL CONTENT" }
    end
    if canCreateRecipe(state) and state.currentGroup then
        commands[#commands + 1] = { value = 2, name = "NEW CONTENT" }
    end
    local result = safe(MessageBox, {
        title = "Update Recipe",
        message = "Group: " .. label(state.currentGroup) ..
            "\nSource Cue: " .. (state.currentRecipe and cueLabel(state.currentSourceCue) or "NONE") ..
            "\nCurrent Cue: " .. cueLabel(state.currentCue) ..
            "\nOld: " .. presetText(state.currentOldPreset) ..
            "\nNew: " .. presetText(state.currentNewPreset) ..
            "\n\nORIGINAL CONTENT replaces the source Recipe." ..
            "\nNEW CONTENT appends a Recipe in the current Cue, Part " .. tostring(partNumber(state.currentPart) or 0) .. "." ..
            "\nChoose an action to apply now. Use Oops once to undo.",
        commands = commands
    })
    if type(result) ~= "table" or result.success ~= true then return end
    if result.result == 1 then updateRecipeTrackingValue("original")
    elseif result.result == 2 then updateRecipeTrackingValue("new") end
end

signalTable.ShowRecipeTrackingMoreMenu = function()
    local state = _G[STATE_KEY]
    if not state then return end
    local result = safe(MessageBox, {
        title = "Display Options",
        message = "View: " .. (state.expanded and "Detailed" or "Compact") ..
            "\nBackground: " .. STYLE_LABELS[state.styleIndex or 1],
        commands = {
            { value = 1, name = state.expanded and "SHOW COMPACT" or "SHOW DETAILS" },
            { value = 2, name = "CYCLE BACKGROUND" },
            { value = 3, name = state.poolBlink == false and "POOL BLINK ON" or "POOL BLINK OFF" },
            { value = 0, name = "CLOSE" }
        }
    })
    if type(result) ~= "table" or result.success ~= true then return end
    if result.result == 1 then signalTable.ToggleRecipeTrackingDetails()
    elseif result.result == 2 then signalTable.CycleRecipeTrackingStyle()
    elseif result.result == 3 then
        state.poolBlink = state.poolBlink == false
        if not state.poolBlink then clearPoolMarkers(state) end
    end
end

local function batchUpdateItems(sequence, currentCue, fixtures)
    local writable, notes, seenRecipe = {}, {}, {}
    for _, info in ipairs(readAllProgrammerFeatures(fixtures)) do
        if info.ambiguous or not info.preset then
            notes[#notes + 1] = tostring(info.feature) .. ": REVIEW ONLY (raw, Phaser, or ambiguous)"
        else
            local candidates = scanTracking(sequence, currentCue, fixtures, info)
            local state = _G[STATE_KEY]
            if state and state.targetGroup and #candidates > 1 then
                local filtered = {}
                for _, candidate in ipairs(candidates) do
                    if sameReference(candidate.group, state.targetGroup) then filtered[#filtered + 1] = candidate end
                end
                if #filtered > 0 then candidates = filtered end
            end
            if #candidates == 1 then
                local item = candidates[1]
                if sameReference(item.values, info.preset) then
                    notes[#notes + 1] = tostring(info.feature) .. ": NO CHANGE (new Preset matches current Values)"
                elseif seenRecipe[item.recipe] then
                    notes[#notes + 1] = string.format("%s: SKIPPED (same Recipe already taken by %s)",
                        tostring(info.feature), seenRecipe[item.recipe])
                else
                    seenRecipe[item.recipe] = tostring(info.feature)
                    writable[#writable + 1] = { info = info, item = item }
                end
            elseif #candidates == 0 then
                notes[#notes + 1] = tostring(info.feature) .. ": NO MATCHING TRACKING RECIPE"
            else
                notes[#notes + 1] = string.format("%s: %d matching Groups - choose SELECT GROUP",
                    tostring(info.feature), #candidates)
            end
        end
    end
    return writable, notes
end

local function updateRecipeTrackingBatch()
    local state = _G[STATE_KEY]
    if not state or state.updating then return end
    local fixtures = readSelection()
    if #fixtures == 0 then
        notify("Batch Update", "Select one or more fixtures first.")
        return
    end
    local sequence = callable("SelectedSequence") and safe(SelectedSequence) or nil
    local currentCue = callable("GetCurrentCue") and safe(GetCurrentCue) or nil
    local writable, notes = batchUpdateItems(sequence, currentCue, fixtures)
    if #writable == 0 then
        notify("Batch Update", table.concat({
            "No writable features found.",
            table.concat(notes, "\n")
        }, "\n"))
        return
    end
    if not callable("CreateUndo") or not callable("CloseUndo") or not callable("Cmd") then
        notify("Batch Update", "This grandMA3 session does not expose the required Undo APIs. No update was performed.")
        return
    end

    local removeAttributes, seenAttribute = {}, {}
    local lines = {
        "READY: " .. #writable .. "    SKIPPED: " .. #notes .. "\nMode: Update source Recipes"
    }
    for index, item in ipairs(writable) do
        local info = item.info
        local newAddress = commandAddress(info.preset)
        local recipeAddress = commandAddress(item.item.recipe)
        if not newAddress or not recipeAddress then
            notify("Batch Update", tostring(info.feature) .. ": could not resolve command addresses. No update was performed.")
            return
        end
        lines[#lines + 1] = ""
        lines[#lines + 1] = string.format("%d. %s | Cue %s | Part %s | Recipe %s", index,
            tostring(info.feature), cueLabel(item.item.cue), tostring(partNumber(item.item.part)),
            tostring(item.item.recipeIndex or recipeNumber(item.item.recipe) or "?"))
        lines[#lines + 1] = "   Group: " .. label(item.item.group)
        lines[#lines + 1] = "   " .. presetText(item.item.values, info.feature) .. "  ->  " .. presetText(info.preset, info.feature)
        for _, attributeName in ipairs(info.attributes or {}) do
            if not seenAttribute[attributeName] then
                seenAttribute[attributeName] = true
                removeAttributes[#removeAttributes + 1] = attributeName
            end
        end
    end
    table.sort(removeAttributes)
    lines[#lines + 1] = ""
    lines[#lines + 1] = "Remove from Programmer: " .. (table.concat(removeAttributes, ", ") or "none")
    for _, note in ipairs(notes) do
        lines[#lines + 1] = "Skipped: " .. note
    end
    lines[#lines + 1] = ""
    lines[#lines + 1] = "All Assigns and Programmer cleanup will be available as one Oops (Undo)."

    local confirmation = safe(MessageBox, {
        title = "Batch Preview",
        message = table.concat(lines, "\n"),
        commands = {
            { value = 1, name = "APPLY ALL" },
            { value = 0, name = "CANCEL" }
        }
    })
    if type(confirmation) ~= "table" or confirmation.success ~= true or confirmation.result ~= 1 then return end

    state.updating = true
    local undo = safe(CreateUndo, "Update Recipe Values (batch)")
    if undo == nil then
        state.updating = false
        notify("Batch Update Failed", "Could not create an Undo transaction. No update was performed.")
        return
    end

    local commands, feedbacks = {}, {}
    local failed = false
    for _, item in ipairs(writable) do
        local command = "Assign " .. commandAddress(item.info.preset)
            .. " At " .. commandAddress(item.item.recipe) .. " Property \"Values\""
        commands[#commands + 1] = command
        local result = safe(Cmd, command, undo)
        if result ~= "OK" then
            failed = true
            feedbacks[#feedbacks + 1] = tostring(item.info.feature) .. ": " .. tostring(result)
        end
    end
    local clearCommands = {}
    for _, attributeName in ipairs(removeAttributes) do
        local safeName = string.gsub(tostring(attributeName), "[\"\r\n]", "")
        local attributeCommand = "Off Attribute \"" .. safeName .. "\""
        clearCommands[#clearCommands + 1] = attributeCommand
        local result = safe(Cmd, attributeCommand, undo)
        if result ~= "OK" then
            failed = true
            feedbacks[#feedbacks + 1] = "clear " .. safeName .. ": " .. tostring(result)
        end
    end
    local closed = safe(CloseUndo, undo)
    state.forceRefresh = true

    if not failed and closed == true then
        local targets = {}
        for _, item in ipairs(writable) do
            targets[#targets + 1] = {
                recipe = item.item.recipe,
                recipeAddress = commandAddress(item.item.recipe),
                expectedPreset = item.info.preset,
                expectedAddress = commandAddress(item.info.preset),
                expectedGroup = nil
            }
        end
        state.pendingVerification = {
            targets = targets,
            command = table.concat(commands, "; "),
            clearCommand = table.concat(clearCommands, "; "),
            checksRemaining = 3
        }
        return
    end

    local rollback = nil
    if closed == true then rollback = safe(Cmd, "Oops") end
    state.updating = false
    notify("Batch Update Failed", table.concat({
        "grandMA3 did not complete the undo-safe commands, so the transaction was rolled back when possible.",
        table.concat(feedbacks, "\n"),
        "Undo close: " .. tostring(closed),
        "Rollback feedback: " .. tostring(rollback)
    }, "\n"))
end

signalTable.UpdateRecipeTrackingBatch = function()
    updateRecipeTrackingBatch()
end

local function processPendingVerification(state)
    local pending = state and state.pendingVerification
    if not pending then return end
    pending.checksRemaining = (pending.checksRemaining or 1) - 1
    if pending.checksRemaining > 0 then return end

    state.pendingVerification = nil
    local failures = {}
    for _, target in ipairs(pending.targets or {}) do
        local freshRecipe = target.recipe
        if callable("ObjectList") then
            local resolved = safe(ObjectList, target.recipeAddress)
            if type(resolved) == "table" and resolved[1] ~= nil then freshRecipe = resolved[1] end
        end
        local actualPreset = safe(function() return freshRecipe.Values end)
        local groupVerified = true
        if target.expectedGroup ~= nil then
            local actualGroup = safe(function() return freshRecipe.Selection end)
            groupVerified = sameReference(actualGroup, target.expectedGroup)
        end
        if not (sameReference(actualPreset, target.expectedPreset) and groupVerified) then
            failures[#failures + 1] = string.format("Recipe %s: expected %s, actual %s",
                tostring(target.recipeAddress),
                tostring(target.expectedAddress),
                tostring(commandAddress(actualPreset) or actualPreset or "nil"))
        end
    end
    if #failures == 0 then
        state.updating = false
        state.forceRefresh = true
        if callable("Printf") then Printf("[RecipeTracking] Updated %d Recipe(s). Use Oops once to undo.", #(pending.targets or {})) end
        return
    end

    -- The Assign commands were accepted and their Undo group closed, so one
    -- Oops targets this update. Restore it when delayed verification fails.
    local rollback = safe(Cmd, "Oops")
    state.updating = false
    state.forceRefresh = true
    notify("Recipe Update Failed", table.concat({
        "The delayed verification did not match, so the update was rolled back with Oops.",
        table.concat(failures, "\n"),
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

    local sourceHighlights = safe(function() return window:Append("UIObject") end)
    if sourceHighlights == nil then deleteHandle(window) return nil, "could not append Source Cue layer" end
    sourceHighlights.Name = "RecipeTrackingInspectorSourceHighlights"
    sourceHighlights.Anchors = { left = 0, right = 0, top = 1, bottom = 1 }
    sourceHighlights.Font = "Medium20"
    sourceHighlights.TextalignmentH = "Left"
    sourceHighlights.TextalignmentV = "Top"
    sourceHighlights.TextAutoAdjust = "No"
    sourceHighlights.Padding = { left = 122, right = 12, top = 8, bottom = 8 }
    pcall(function() sourceHighlights.HasHover = "No" end)
    pcall(function() sourceHighlights.BackColor = "Global.Transparent" end)
    pcall(function() sourceHighlights.TextColor = "Global.SuccessText" end)

    local currentHighlights = safe(function() return window:Append("UIObject") end)
    if currentHighlights == nil then deleteHandle(window) return nil, "could not append Current Cue layer" end
    currentHighlights.Name = "RecipeTrackingInspectorCurrentHighlights"
    currentHighlights.Anchors = { left = 0, right = 0, top = 1, bottom = 1 }
    currentHighlights.Font = "Medium20"
    currentHighlights.TextalignmentH = "Left"
    currentHighlights.TextalignmentV = "Top"
    currentHighlights.TextAutoAdjust = "No"
    currentHighlights.Padding = { left = 122, right = 12, top = 8, bottom = 8 }
    pcall(function() currentHighlights.HasHover = "No" end)
    pcall(function() currentHighlights.BackColor = "Global.Transparent" end)
    pcall(function() currentHighlights.TextColor = "Global.Text" end)

    local presetHighlights = safe(function() return window:Append("UIObject") end)
    if presetHighlights == nil then deleteHandle(window) return nil, "could not append Preset layer" end
    presetHighlights.Name = "RecipeTrackingInspectorPresetHighlights"
    presetHighlights.Anchors = { left = 0, right = 0, top = 1, bottom = 1 }
    presetHighlights.Font = "Medium20"
    presetHighlights.TextalignmentH = "Left"
    presetHighlights.TextalignmentV = "Top"
    presetHighlights.TextAutoAdjust = "No"
    presetHighlights.Padding = { left = 200, right = 12, top = 8, bottom = 8 }
    pcall(function() presetHighlights.HasHover = "No" end)
    pcall(function() presetHighlights.BackColor = "Global.Transparent" end)
    pcall(function() presetHighlights.TextColor = "Global.SuccessText" end)

    local footer = safe(function() return window:Append("UILayoutGrid") end)
    if footer == nil then deleteHandle(window) return nil, "could not append toolbar" end
    footer.Anchors = { left = 0, right = 0, top = 2, bottom = 2 }
    footer.Columns = 4
    footer.Rows = 1

    local buttons = {}
    local definitions = {
        { "SelectGroup", "SELECT GROUP", "SelectRecipeTrackingGroup" },
        { "Update", "UPDATE", "ShowRecipeTrackingUpdateMenu" },
        { "Batch", "BATCH", "UpdateRecipeTrackingBatch" },
        { "More", "MORE", "ShowRecipeTrackingMoreMenu" }
    }
    for index, definition in ipairs(definitions) do
        local button = safe(function() return footer:Append("Button") end)
        if button == nil then deleteHandle(window) return nil, "could not append toolbar button" end
        button.Name = "RecipeTrackingInspector" .. definition[1]
        button.Anchors = { left = index - 1, right = index - 1, top = 0, bottom = 0 }
        button.Text = definition[2]
        button.Font = "Medium20"
        button.PluginComponent = componentHandle
        button.Clicked = definition[3]
        buttons[index] = button
    end
    buttons[2].Enabled = "No"
    local resize = safe(function() return window:Append("ResizeCorner") end)
    if resize ~= nil then
        resize.Name = "Resizer"
        resize.Anchors = { left = 0, right = 0, top = 2, bottom = 2 }
        resize.AlignmentH = "Right"
        resize.AlignmentV = "Bottom"
    end
    state.window, state.panel = window, panel
    state.sourceHighlights, state.currentHighlights, state.presetHighlights =
        sourceHighlights, currentHighlights, presetHighlights
    state.selectGroup, state.update, state.batch = buttons[1], buttons[2], buttons[3]
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

    local previous, previousSourceHighlights, previousCurrentHighlights, previousPresetHighlights =
        nil, nil, nil, nil
    while state.running do
        syncTitleWidth(state)
        processPendingVerification(state)
        local forceRefresh = state.forceRefresh
        if forceRefresh then state.effectSequenceKey, state.effectCacheSequence = nil, nil end
        local ok, text, sourceHighlightText, currentHighlightText, presetHighlightText = pcall(render, state)
        if not ok then
            text = "RECIPE TRACKING INSPECTOR v" .. PLUGIN_VERSION ..
                "\n\nStatus: ERROR\n" .. tostring(text)
            sourceHighlightText, currentHighlightText, presetHighlightText = "", "", ""
        end
        fitCompactWindowToText(state, text)
        if text ~= previous or sourceHighlightText ~= previousSourceHighlights
            or currentHighlightText ~= previousCurrentHighlights
            or presetHighlightText ~= previousPresetHighlights or forceRefresh then
            state.forceRefresh = false
            previous = text
            previousSourceHighlights = sourceHighlightText
            previousCurrentHighlights = currentHighlightText
            previousPresetHighlights = presetHighlightText
            pcall(function() panel.Text = text end)
            pcall(function() state.sourceHighlights.Text = sourceHighlightText or "" end)
            pcall(function() state.currentHighlights.Text = currentHighlightText or "" end)
            pcall(function() state.presetHighlights.Text = presetHighlightText or "" end)
        end
        -- Publish direct Cue effects and all regular UI changes before the
        -- potentially expensive single-Part background scan.
        local effectsOK = pcall(refreshCueEffects, state, false)
        if not effectsOK then state.activeEffects, state.effectScanner = {}, nil end
        local markersOK = pcall(refreshPoolMarkers, state)
        if not markersOK then clearPoolMarkers(state) end
        coroutine.yield(0.01)
        effectsOK = pcall(refreshCueEffects, state, true)
        if not effectsOK then state.activeEffects, state.effectScanner = {}, nil end
        coroutine.yield(REFRESH_SECONDS)
    end

    clearPoolMarkers(state)
    deleteHandle(state.window)
    if _G[STATE_KEY] == state then _G[STATE_KEY] = nil end
end

return main
