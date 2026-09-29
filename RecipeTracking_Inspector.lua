-- grandMA3 Recipe Tracking Inspector and undo-safe Recipe Values updater
-- Target: grandMA3 2.3.2.0+

local signalTable = select(3, ...)
local componentHandle = select(4, ...)

local PLUGIN_VERSION = "0.7.1.11"
local STATE_KEY = "RecipeTrackingInspectorState"
-- Native-proven Track A lane resolver candidate; unknown semantics fail closed.
local ENABLE_TRACK_A_SHOW_CANDIDATE = true
-- Keep the unfinished current-Cue Phaser resolver dormant for live use. This
-- disables its old Pool frames and all automatic Cue/Recipe/cooked-data
-- scanning, while regular current Group/Recipe reference frames keep pulsing.
local ENABLE_CUE_PHASER_MARKERS = false
local MAX_SELECTION = 2048
local MAX_CUES = 512
local MAX_RECIPES = 2048
local REFRESH_SECONDS = 0.1
local PENDING_RESOLVER_REFRESH_SECONDS = 0.01
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

local function contextClock()
    if type(os)=="table" and type(os.clock)=="function" then return safe(os.clock) end
    if callable("Time") then return safe(Time) end
    return nil
end

local function contextElapsed(started)
    local finished=started and contextClock()
    return type(finished)=="number" and (finished-started)*1000 or nil
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

local function groupDisplayLabel(group)
    if group == nil then return "UNRESOLVED" end
    local raw = safe(function() return group:ToAddr() end)
    local number = tonumber(property(group, "No") or property(group, "NO"))
        or tonumber(type(raw) == "string" and raw:match("^Group%s+(%d+)"))
    local name = label(group)
    if number == nil then return tostring(raw or "Group ?") .. " " .. name end
    return string.format("%g %s", number, name)
end

local function groupPanelLines(groups)
    if type(groups)~="table" or #groups==0 then return nil end
    if #groups==1 then return {"Group: "..groupDisplayLabel(groups[1])} end
    local lines={"Groups:"}
    for _,group in ipairs(groups) do lines[#lines+1]=groupDisplayLabel(group) end
    return lines
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

-- Depending on the grandMA3 object/property path, a Recipe link may be
-- exposed either as a handle or as the same address string returned by
-- recipe:Get(). The reference plugin succeeds by resolving those strings
-- through ObjectList, so every Recipe reader here accepts both forms.
local function resolveObjectReference(value)
    if isObjectReference(value) then return value end
    local text = value ~= nil and tostring(value) or ""
    if text == "" or not callable("ObjectList") then return nil end
    local list = safe(ObjectList, text)
    return type(list) == "table" and list[1] or nil
end

local function recipeField(recipe, name)
    local direct = safe(function() return recipe[name] end)
    local object = resolveObjectReference(direct)
    if object then return object, tostring(direct) end
    local raw = safe(function() return recipe:Get(string.upper(name)) end)
    object = resolveObjectReference(raw)
    if object then return object, tostring(raw) end
    local text = raw ~= nil and tostring(raw) or (direct ~= nil and tostring(direct) or "")
    return nil, text
end

local function uiChannelsForMember(handle,state)
    if handle==nil or not callable("GetUIChannels") then return nil end
    local cache=state and state.uiChannelCache
    if state and not cache then cache={}; state.uiChannelCache=cache end
    if cache then
        local cached=cache[handle]
        if cached~=nil then return cached end
    end
    local channels=safe(GetUIChannels,handle,true)
    if cache and type(channels)=="table" then
        local count=state.uiChannelCacheCount or 0
        if count>=8192 then
            cache={}; state.uiChannelCache=cache; state.uiChannelCacheCount=0; count=0
        end
        cache[handle]=channels
        state.uiChannelCacheCount=count+1
    end
    return channels
end

local function readProgrammer(fixtures,state)
    local presets, assignedAttributes, rawCount = {}, {}, 0
    local selectedFeature = normalizeFeature(selectedFeatureLabel())
    if #fixtures == 0 or not callable("GetUIChannels") then
        return { feature = selectedFeature }
    end
    for _, fixture in ipairs(fixtures) do
        local channels = uiChannelsForMember(fixture.handle or fixture.index,state)
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
    if callable("CompareHandle") and safe(CompareHandle, left, right) == true then return true end
    if callable("HandleToInt") then
        local leftId, rightId = safe(HandleToInt, left), safe(HandleToInt, right)
        if type(leftId) == "number" and leftId ~= 0 and leftId == rightId then return true end
    end
    if callable("HandleToStr") then
        local leftId, rightId = safe(HandleToStr, left), safe(HandleToStr, right)
        if type(leftId)=="string" and leftId~="" and leftId==rightId then return true end
    end
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

-- Recipe objects retain their Selection and Values/Generator references even
-- when the cooked channel data is large.  Use that cheap object tree as the
-- medium resolver between the current-Cue direct path and GetPresetData.
-- The supported lanes mirror grandMA3's standard feature Preset pools.
local RECIPE_FEATURES = { "Dimmer", "Position", "Gobo", "Color", "Beam",
    "Focus", "Control", "Shapers", "Other" }
local RECIPE_FEATURE_SET = {
    Dimmer = true, Position = true, Gobo = true, Color = true, Beam = true,
    Focus = true, Control = true, Shapers = true
}
local NUMBERED_PRESET_FEATURES = {
    [1] = "Dimmer", [2] = "Position", [3] = "Gobo", [4] = "Color",
    [5] = "Beam", [6] = "Focus", [7] = "Control", [8] = "Shapers"
}

local function recipeReferenceFeatures(reference)
    local result, seen, all = {}, {}, false
    local function add(feature)
        feature = normalizeFeature(feature)
        if feature ~= "" and feature ~= "UNRESOLVED" and not seen[feature] then
            seen[feature], result[#result + 1] = true, feature
        end
    end
    local function addTextHints(value)
        local text = string.lower(tostring(value or ""))
        if string.find(text, "dimmer", 1, true) then add("Dimmer") end
        if string.find(text, "position", 1, true) or string.find(text, "pan", 1, true)
            or string.find(text, "tilt", 1, true) or string.find(text, "fly", 1, true) then add("Position") end
        if string.find(text, "gobo", 1, true) then add("Gobo") end
        if string.find(text, "color", 1, true) or string.find(text, "colour", 1, true) then add("Color") end
        if string.find(text, "beam", 1, true) or string.find(text, "shutter", 1, true)
            or string.find(text, "strobe", 1, true) then add("Beam") end
        if string.find(text, "focus", 1, true) or string.find(text, "zoom", 1, true) then add("Focus") end
        if string.find(text, "control", 1, true) then add("Control") end
        if string.find(text, "shaper", 1, true) or string.find(text, "blade", 1, true)
            or string.find(text, "framing", 1, true) then add("Shapers") end
    end
    if not isObjectReference(reference) then return result, false end
    local nativeAddress = address(reference)
    local pool = string.match(nativeAddress, "PresetPools%.([^%.]+)%.")
    if pool and string.lower(pool) == "all" then
        all = true
    elseif pool then
        local feature = normalizeFeature(pool)
        if RECIPE_FEATURE_SET[feature] then add(feature) end
    end
    local numberedPool = tonumber(string.match(commandAddress(reference) or "", "^Preset%s+(%d+)%."))
    if numberedPool and NUMBERED_PRESET_FEATURES[numberedPool] then add(NUMBERED_PRESET_FEATURES[numberedPool]) end

    if isRandomGenerator(reference) then
        local channels = safe(function() return reference.RandomChannels end)
        if channels == nil then
            for _, child in ipairs(children(reference)) do
                local kind = string.lower(class(child))
                if kind == "randomchannels" or kind == "generatorchannels" then channels = child; break end
            end
        end
        for _, channel in ipairs(children(channels)) do
            local attribute = safe(function() return channel.Attribute end)
            local name = isObjectReference(attribute) and label(attribute)
                or property(channel, "Attribute") or property(channel, "ATTRIBUTE")
            local normalized = string.lower(tostring(name or "")):match("^%s*(.-)%s*$")
            if normalized == "" or normalized == "none" or normalized == "all" then all = true else add(name) end
        end
    end

    if isPhaserRecipePreset(reference) then
        local visited = 0
        local function visit(node, depth)
            if not node or depth > 6 or visited >= 256 then return end
            visited = visited + 1
            if string.find(string.lower(class(node)), "phaserecipevaluesource", 1, true) then
                for _, key in ipairs({ "Attributes", "Attribute", "Feature" }) do
                    addTextHints(property(node, key))
                end
            end
            for _, child in ipairs(children(node)) do visit(child, depth + 1) end
        end
        visit(reference, 0)
    end
    if #result == 0 and not all then
        addTextHints(nativeAddress)
        addTextHints(label(reference))
    end
    if all then
        result, seen = {}, {}
        for _, feature in ipairs(RECIPE_FEATURES) do add(feature) end
    elseif #result == 0 then
        add("Other")
    end
    return result, all
end

-- This intentionally mirrors the reference plugin's "first hit backwards
-- wins" rule, but it is only a progressive result.  Group overlap, manually
-- stored channels and releases require the later cooked-data resolver.
local function trackedRecipeEffects(sequence, currentCue)
    local result, rows = {}, {}
    if not sequence or not cueNumber(currentCue) then return result end
    local cueCount, recipeCount = 0, 0
    for _, cue in ipairs(children(sequence)) do
        local number = cueNumber(cue)
        if string.lower(class(cue)) == "cue" and number and number <= cueNumber(currentCue) then
            cueCount = cueCount + 1
            if cueCount > MAX_CUES then error("Recipe effect scan exceeds 512 Cues") end
            for _, part in ipairs(children(cue)) do
                if string.lower(class(part)) == "part" then
                    for ordinal, recipe in ipairs(children(part)) do
                        if isStandardRecipe(recipe) and recipeEnabled(recipe) then
                            recipeCount = recipeCount + 1
                            if recipeCount > MAX_RECIPES then error("Recipe effect scan exceeds 2048 Recipes") end
                            rows[#rows + 1] = { cue = cue, part = part, recipe = recipe,
                                index = recipeNumber(recipe, ordinal) or ordinal }
                        end
                    end
                end
            end
        end
    end
    table.sort(rows, function(left, right)
        local lc, rc = cueNumber(left.cue), cueNumber(right.cue)
        if lc ~= rc then return lc > rc end
        local lp, rp = partNumber(left.part), partNumber(right.part)
        if lp ~= rp then return lp > rp end
        return left.index > right.index
    end)
    local decided = {}
    for _, row in ipairs(rows) do
        local group, groupText = recipeField(row.recipe, "Selection")
        local reference = recipeField(row.recipe, "Generator")
        if not reference then reference = recipeField(row.recipe, "Values") end
        local groupKey = commandAddress(group) or (isObjectReference(group) and address(group) or nil)
            or (groupText ~= "" and groupText or nil)
        if groupKey and isObjectReference(reference) then
            local features = recipeReferenceFeatures(reference)
            local activeReference = isPhaserRecipePreset(reference) or isRandomGenerator(reference)
            local publish = false
            for _, feature in ipairs(features) do
                local laneKey = groupKey .. "|" .. feature
                if not decided[laneKey] then
                    decided[laneKey] = true
                    if activeReference then publish = true end
                end
            end
            if publish then
                local key = commandAddress(reference)
                if key then result[key] = {object = reference, fixtures = {}, count = 0, progressive = true} end
            end
        end
    end
    return result
end

-- Resolve only the Recipe references that are still tracked for the currently
-- selected Group. This keeps the useful green Group/Recipe pulse without
-- enabling Cue-wide Phaser markers or touching cooked GetPresetData records.
local function trackedGroupRecipeReferences(sequence, currentCue, wantedGroup)
    local result, rows = {}, {}
    local currentNumber = cueNumber(currentCue)
    if not sequence or not currentNumber or not wantedGroup then return result end
    local cueCount, recipeCount = 0, 0
    for _, cue in ipairs(children(sequence)) do
        local number = cueNumber(cue)
        if string.lower(class(cue)) == "cue" and number and number <= currentNumber then
            cueCount = cueCount + 1
            if cueCount > MAX_CUES then error("Group Recipe scan exceeds 512 Cues") end
            for _, part in ipairs(children(cue)) do
                if string.lower(class(part)) == "part" then
                    for ordinal, recipe in ipairs(children(part)) do
                        if isStandardRecipe(recipe) and recipeEnabled(recipe) then
                            recipeCount = recipeCount + 1
                            if recipeCount > MAX_RECIPES then error("Group Recipe scan exceeds 2048 Recipes") end
                            local group = recipeField(recipe, "Selection")
                            if sameReference(group, wantedGroup) then
                                rows[#rows + 1] = { cue = cue, part = part, recipe = recipe,
                                    index = recipeNumber(recipe, ordinal) or ordinal }
                            end
                        end
                    end
                end
            end
        end
    end
    table.sort(rows, function(left, right)
        local lc, rc = cueNumber(left.cue), cueNumber(right.cue)
        if lc ~= rc then return lc > rc end
        local lp, rp = partNumber(left.part), partNumber(right.part)
        if lp ~= rp then return lp > rp end
        return left.index > right.index
    end)
    local decided = {}
    local function add(object)
        local key = commandAddress(object)
        if key then result[key] = object end
    end
    for _, row in ipairs(rows) do
        local reference = recipeField(row.recipe, "Generator")
        if not reference then reference = recipeField(row.recipe, "Values") end
        if isObjectReference(reference) then
            local wins = false
            for _, feature in ipairs(recipeReferenceFeatures(reference)) do
                if not decided[feature] then decided[feature], wins = true, true end
            end
            if wins then
                for _, name in ipairs({ "Selection", "Values", "MAtricks", "Filter", "World", "Generator" }) do
                    add(recipeField(row.recipe, name))
                end
            end
        end
    end
    return result
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
-- Native-proven canonical member identity (Track A checkpoint:
-- NATIVE_TOADDR_OBJECTLIST_MEMBER_KEY_PROVEN). A Fixture/SubFixture/Cell
-- handle resolves through its command-style ToAddr address, strictly parsed
-- as "Fixture <numeric dotted key>". Anything else fails closed to nil.
-- Never falls back to a parent identity and never uses sf_index.



-- Exact canonical member-identity relations between a Stored Group and the
-- current selection. Parent Fixture, child SubFixture and nested Cell keys
-- never collapse into each other. Grid position never affects identity.
-- Returns: relation, selectionKeys, groupKeys where relation is one of
-- EXACT_COMPLETE, SELECTION_CONTAINS_COMPLETE_GROUP, PARTIAL, DISJOINT, UNPROVEN.

-- Every Stored Group completely contained in the current selection, sorted
-- deterministically by command address so marker output never depends on
-- Pool traversal order.


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
                            local selection = recipeField(recipe, "Selection")
                            -- Standard Generator recipe lines store the usable
                            -- handle in Generator; Values is only the display name.
                            local generator = recipeField(recipe, "Generator")
                            local values = generator or recipeField(recipe, "Values")
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

-- Cheap structural signature for scanTracking's inputs. It notices Recipe row
-- insertion/removal, enable changes, and Selection/Values/Generator relinks,
-- while avoiding the per-row fixture intersection and Feature inspection on
-- every marker pulse.
local function trackingStructureKey(sequence,currentCue)
    local currentNumber=cueNumber(currentCue)
    if not sequence or not currentNumber then return nil end
    local entries={tostring(commandAddress(sequence)),tostring(currentNumber)}
    local cueCount,recipeCount=0,0
    for _,cue in ipairs(children(sequence)) do
        if string.lower(class(cue))=="cue" then
            local number=cueNumber(cue)
            if number and number<=currentNumber then
                cueCount=cueCount+1
                if cueCount>MAX_CUES then return nil end
                entries[#entries+1]=tostring(commandAddress(cue))
                for _,part in ipairs(children(cue)) do
                    if string.lower(class(part))=="part" then
                        entries[#entries+1]=tostring(commandAddress(part))
                        for _,recipe in ipairs(children(part)) do
                            if isStandardRecipe(recipe) then
                                recipeCount=recipeCount+1
                                if recipeCount>MAX_RECIPES then return nil end
                                local group=recipeField(recipe,"Selection")
                                local generator=recipeField(recipe,"Generator")
                                local values=generator or recipeField(recipe,"Values")
                                entries[#entries+1]=table.concat({
                                    tostring(commandAddress(recipe)),tostring(recipeEnabled(recipe)),
                                    tostring(commandAddress(group)),tostring(commandAddress(values)),
                                },"/")
                            end
                        end
                    end
                end
            end
        end
    end
    entries[#entries+1]=tostring(cueCount)
    entries[#entries+1]=tostring(recipeCount)
    return table.concat(entries,"\0")
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

-- Show-release candidate, not the native-proven Track A resolver. This
-- newest-first member/feature walk still lacks reference-level ABS/REL,
-- static-terminator, selective applicability, and 9008 split gates. Keep
-- this distinction explicit until those gates are ported and tested.
-- Returns { classification = "PROVEN", refs = { key = object } } or
-- { classification = "INCONCLUSIVE" }.

-- Recompute proven sources only when semantic input changes (Cue, Recipe
-- Group selection, feature). Emits one bounded shadow line per recompute so
-- the old and new source sets stay comparable without per-tick logging.


local function canCreateRecipe(state)
    return not (state.provenEnabled and #(state.currentGroups or {})>1)
        and state.currentNewPreset and state.currentSequence and state.currentCue
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

local recipePoolReferences
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
    local selectionStarted=contextClock()
    local fixtures = readSelection()
    if state then state.lastSelectionReadMs=contextElapsed(selectionStarted) end
    local programmerStarted=contextClock()
    local info = readProgrammer(fixtures,state)
    if state then state.lastProgrammerMs=contextElapsed(programmerStarted) end
    local sequence = callable("SelectedSequence") and safe(SelectedSequence) or nil
    local currentCue = callable("GetCurrentCue") and safe(GetCurrentCue) or nil
    local direct = directRecipes()
    if state then
        local parts={tostring(commandAddress(sequence)),tostring(cueNumber(currentCue))}
        for _,fixture in ipairs(fixtures) do
            parts[#parts+1]=tostring(fixture.index)
        end
        local contextKey=table.concat(parts,"|")
        if state.markerContextKey~=contextKey then
            state.markerContextKey=contextKey
            state.poolMarkersDirty=true
            if ENABLE_TRACK_A_SHOW_CANDIDATE then
                state.provenSourceKey=nil
                state.provenSources={classification="PENDING",refs={}}
                state.currentGroups={}
                state.markerReferences={}
            end
        end
        if #fixtures==0 or not sequence or not currentCue then
            state.currentGroups={}
            state.markerReferences={}
            state.provenSourceKey=nil
            state.provenSources=nil
            state.markerProbe=nil
            state.markerStatus=nil
            state.completeGroupSelectionKey=nil
            state.completeGroupCandidates=nil
            state.poolMarkersDirty=true
        end
    end
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
            local group = recipeField(recipe, "Selection")
            local values = recipeField(recipe, "Generator") or recipeField(recipe, "Values")
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
            lines[#lines + 1] = "Group: " .. groupDisplayLabel(group)
            lines[#lines + 1] = "Old Values: " .. presetText(values, info.feature)
            lines[#lines + 1] = "New Preset: " .. programmerValueText(info)
            lines[#lines + 1] = "Confidence: DIRECT"
        else
            lines[#lines + 1] = string.format("Status: AMBIGUOUS (%d direct Recipes)", #direct)
        end
    else
        -- Reuse candidate matches while the bounded Cue/Part/Recipe structure
        -- and selection stay unchanged; changed rows or references invalidate
        -- the signature before a stale candidate can be reused.
        local candidates
        if state then
            local parts={tostring(commandAddress(sequence)),tostring(cueNumber(currentCue)),
                tostring(normalizeFeature(info.feature))}
            local memberKeys={}
            for _,fixture in ipairs(fixtures) do memberKeys[#memberKeys+1]=tostring(fixture.index or "?") end
            table.sort(memberKeys)
            for _,key in ipairs(memberKeys) do parts[#parts+1]=key end
            local structureStarted=contextClock()
            local structure=trackingStructureKey(sequence,currentCue)
            state.lastTrackingFingerprintMs=contextElapsed(structureStarted)
            local trackingKey=structure and table.concat(parts,"|").."|"..structure or nil
            if trackingKey and state.trackingScanKey==trackingKey and type(state.trackingScanCandidates)=="table" then
                candidates=state.trackingScanCandidates
                state.lastTrackingScanMs=0
            else
                local trackingStarted=contextClock()
                candidates=scanTracking(sequence,currentCue,fixtures,info)
                state.lastTrackingScanMs=contextElapsed(trackingStarted)
                if trackingKey then
                    state.trackingScanKey=trackingKey
                    state.trackingScanCandidates=candidates
                else
                    state.trackingScanKey=nil
                    state.trackingScanCandidates=nil
                end
            end
            state.matchingCandidates=candidates
        else
            candidates=scanTracking(sequence,currentCue,fixtures,info)
        end
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
            lines[#lines + 1] = "Group: " .. groupDisplayLabel(item.group)
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
            lines[#lines + 1] = "Group: " .. (group and groupDisplayLabel(group) or
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
    if state then
        -- Canonical complete Stored Groups for marker sources. currentGroup
        -- keeps its existing single-choice UX semantics untouched.
        state.lastFixtures = fixtures
        state.lastFeature = info.feature
        state.provenEnabled = ENABLE_TRACK_A_SHOW_CANDIDATE
        if ENABLE_TRACK_A_SHOW_CANDIDATE and #fixtures>0 and sequence and currentCue
            and recipePoolReferences then
            local ok,refs=pcall(recipePoolReferences,state)
            state.markerReferences=ok and refs or {}
        end
    end
    local resolverLines={}
    if state and ENABLE_TRACK_A_SHOW_CANDIDATE and state.provenSources then
        local refKeys={}
        for key in pairs(state.provenSources.refs or {}) do refKeys[#refKeys+1]=key end
        table.sort(refKeys)
        resolverLines[1]=string.format("Resolver: %s | %d refs%s",
            tostring(state.provenSources.classification),#refKeys,
            state.markerStatus and (" | "..state.markerStatus) or "")
        if state.provenSources.classification=="PENDING"
            and state.provenSources.reason=="MEMBER_UI_PENDING"
            and type(state.resolverMembersTotal)=="number" then
            resolverLines[#resolverLines+1]=string.format("Member channels: %d/%d",
                state.resolverMembersWarmed or 0,state.resolverMembersTotal)
        end
        if state.provenSources.classification~="PROVEN" and state.provenSources.reason then
            resolverLines[#resolverLines+1]="Reason: "..tostring(state.provenSources.reason):sub(1,90)
            local blockers=state.provenSources.unsafeRefs or {}
            if #blockers>0 then
                local shown={}
                for index=1,math.min(#blockers,3) do
                    local id=blockers[index]
                    shown[#shown+1]=id.." ("..tostring((state.provenSources.unsafeRefDetails or {})[id] or "UNPROVEN")..")"
                end
                resolverLines[#resolverLines+1]="Blocked refs: "..table.concat(shown,", "):sub(1,220)
            end
        end
        if state.expanded and #refKeys>0 then
            local shown={}
            for index=1,math.min(#refKeys,8) do shown[#shown+1]=refKeys[index] end
            resolverLines[#resolverLines+1]="Refs: "..table.concat(shown,", "):sub(1,180)
        end
        if state.expanded then
            resolverLines[#resolverLines+1]=string.format(
                "Timing ms: select=%s tracking_scan=%s tracking_sig=%s group=%s resolver_slice=%s resolver_total=%s pool=%s",
                tostring(state.lastSelectionReadMs or "?"),
                tostring(state.lastTrackingScanMs or "?"),
                tostring(state.lastTrackingFingerprintMs or "?"),
                tostring(state.lastGroupMatchMs or "?"),
                tostring(state.lastResolverSliceMs or "?"),
                tostring(state.lastResolverTotalMs or "?"),
                tostring(state.lastPoolDiscoveryMs or "?"))
        end
    end
    if state and #state.matchingCandidates > 1 then
        local overview = {
            string.format("%s | %d fixtures | %d matching Groups", tostring(info.feature), #fixtures, #state.matchingCandidates),
            "Current Cue: " .. cueLabel(currentCue),
            "Target: " .. (state.currentGroup and groupDisplayLabel(state.currentGroup) or "Choose SELECT GROUP"),
            "New Preset: " .. programmerValueText(info),
            ""
        }
        for index, item in ipairs(state.matchingCandidates) do
            overview[#overview + 1] = (sameReference(item.group, state.currentGroup) and "> " or "  ") ..
                tostring(index) .. ". " .. groupDisplayLabel(item.group) .. " | Cue " .. cueLabel(item.cue)
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
        local groupLines=state and groupPanelLines(state.currentGroups)
        if groupLines then
            details[1]=groupLines[1]
            for index=2,#groupLines do table.insert(details,index,groupLines[index]) end
        end
        for _,line in ipairs(resolverLines) do details[#details+1]=line end
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
    for _,line in ipairs(resolverLines) do lines[#lines+1]=line end
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

-- BEGIN GENERATED TRACK A RUNTIME
-- Compact Track A runtime. No Cue/Part cooked history or diagnostic oracle.
local function newTrackARuntime(api)
    local function fail(reason) return {classification="INCONCLUSIVE", reason=reason, refs={}} end
    local function count(t) local n=0; for _ in pairs(t or {}) do n=n+1 end; return n end
    local function attrFG(attr)
        if api.class(attr):lower()~="attribute" then return nil end
        local feature=api.safe(function() return attr.Feature end)
        if api.class(feature):lower()~="feature" then return nil end
        local fg=api.safe(function() return feature:Parent() end)
        if api.class(fg):lower()~="featuregroup" then return nil end
        return api.identity(fg)
    end
    local function resolveHandle(value,expected)
        if api.class(value):lower()==expected then return value end
        if type(value)~="string" or not api.objectList then return nil end
        local list=api.safe(api.objectList,value)
        if type(list)=="table" and #list==1 and api.class(list[1]):lower()==expected then return list[1] end
    end
    local function memberUI(handle,cache)
        local id=handle
        if cache[id]~=nil then return cache[id] or nil end
        cache[id]=false
        local channels=api.safe(api.getUIChannels,handle,true)
        if type(channels)~="table" then return nil end
        local result={byFG={},byUI={}}
        cache.__featureGroupByUI=cache.__featureGroupByUI or {}
        local featureGroupByUI=cache.__featureGroupByUI
        local seen=0
        for _,channel in pairs(channels) do
            if type(channel)~="table" and type(channel)~="userdata" then return nil end
            local index=api.safe(function() return channel.INDEX end)
            if type(index)~="number" then index=api.safe(function() return channel:Get("INDEX") end) end
            if type(index)~="number" or index%1~=0 or index<1 then return nil end
            local ui=index-1
            if result.byUI[ui] then return nil end
            local fg=featureGroupByUI[ui]
            if fg==nil then
                local attr=api.safe(api.attributeByUI,ui)
                fg=attrFG(attr)
                if fg then featureGroupByUI[ui]=fg end
            end
            if not fg then return nil end
            result.byUI[ui]=fg; result.byFG[fg]=true; seen=seen+1
            if seen>65536 then return nil end
        end
        if seen==0 then return nil end
        cache[id]=result
        return result
    end
    local function ordinary(ref,cache)
        -- Reference metadata uses UI-channel records. Requesting the fixture
        -- view adds a by_fixtures table that this parser intentionally does
        -- not use for lane semantics.
        local raw=api.safe(api.getPresetData,ref,false,false)
        local rawKey=api.identity(ref)
        cache.__failure=cache.__failure or {}
        local function reject(reason)
            if rawKey then cache.__failure[rawKey]=reason end
            return nil
        end
        if rawKey then cache.__failure[rawKey]="ORDINARY_CHANNEL_SHAPE_UNPROVEN" end
        if rawKey then
            cache.__raw=cache.__raw or {}
            cache.__raw[rawKey]=raw or false
        end
        if type(raw)~="table" then
            if rawKey then cache.__failure[rawKey]="ORDINARY_REFERENCE_DATA_UNAVAILABLE" end
            return nil
        end
        local mode,scope,channels=nil,{},0
        local moving=false
        local knownBits=1|2|4|8|16|32|64|128|256
        for ui,p in pairs(raw) do
            if type(ui)=="number" then
                if rawKey then cache.__failure[rawKey]="ORDINARY_CHANNEL_HEADER_UNPROVEN" end
                if ui%1~=0 or type(p)~="table" then return reject("UI_RECORD_SHAPE") end
                channels=channels+1
                if channels>262144 then return reject("CHANNEL_LIMIT") end
                local pm=p.preset_store_mode or p.pm
                if p.pm~=nil and p.preset_store_mode~=nil and p.pm~=p.preset_store_mode then return reject("PRESET_MODE_FIELDS_CONFLICT") end
                if pm~=1 and pm~=2 and pm~=3 then return reject("PRESET_MODE_FIELD_SHAPE") end
                if mode and pm~=mode then return reject("PRESET_MODE_CHANNEL_CONFLICT") end
                mode=pm
                if pm==1 and p.selective~=true then return reject("SELECTIVE_FLAG_UNPROVEN") end
                if pm~=1 and p.selective==true then return reject("NONSELECTIVE_FLAG_CONFLICT") end
                if p.mask_cooked~=nil and p.mask_cooked~=0 then return reject("COOKED_MASK_ACTIVE") end
                for _,field in ipairs({"speed","phase","measure","nshot_count","fade","delay",
                    "speed_master","abs_generator","rel_generator","generator","abs_preset","rel_preset"}) do
                    local value=p[field]
                    if value~=nil and value~=false and value~=0 then return reject("ACTIVE_CHANNEL_FIELD_"..field) end
                end
                local known={attribute=true,abs_preset=true,rel_preset=true,abs_generator=true,rel_generator=true,generator=true,
                    mask_active_phaser=true,mask_active_value=true,mask_cooked=true,mask_individual=true,mask_integrated=true,
                    dict_flags=true,dict_index=true,gridposmatr=true,gridpos=true,grid=true,phase=true,speed=true,
                    measure=true,fade=true,delay=true,selective=true,preset_store_mode=true,pm=true,ui_channel_index=true,
                    grid_origin=true,grid_matrix=true,nshot_count=true,nshot_flags=true,speed_master=true}
                for k,v in pairs(p) do if type(k)=="string" and not known[k] and v~=nil and v~=false and v~=0 then return reject("UNKNOWN_CHANNEL_FIELD_"..k) end end
                if p.ui_channel_index~=nil and p.ui_channel_index~=ui then return reject("UI_CHANNEL_INDEX_MISMATCH") end
                if type(p.dict_flags)=="table" then for k,v in pairs(p.dict_flags) do
                    if not ({has_absolute=true,has_relative=true,selective=true,blocked=true,blocked_rel=true})[k]
                        and v~=nil and v~=false and v~=0 then return reject("UNKNOWN_DICT_FLAG_"..k) end
                    if (k=="blocked" or k=="blocked_rel") and v~=nil and v~=false and v~=0 then return reject("BLOCKED_DICT_FLAG_"..k) end
                end elseif p.dict_flags~=nil then return reject("DICT_FLAGS_SHAPE") end
                if type(p.dict_flags)=="table" and p.dict_flags.selective~=nil
                    and p.dict_flags.selective~=false and p.dict_flags.selective~=0 and pm~=1 then return reject("DICT_SELECTIVE_MODE_CONFLICT") end
                local phaser=p.mask_active_phaser
                local mask=p.mask_active_value
                if type(phaser)~="number" or math.type(phaser)~="integer" or phaser<0 or phaser & ~knownBits~=0 then return reject("ACTIVE_PHASER_MASK_SHAPE") end
                if type(mask)~="number" or math.type(mask)~="integer" or mask & ~(2|4)~=0 or mask==0 then return reject("ACTIVE_VALUE_MASK_SHAPE") end
                if type(p.dict_flags)=="table" then
                    for _,spec in ipairs({{"has_absolute",2,"absolute"},{"has_relative",4,"relative"}}) do
                        local flag,bit,field=table.unpack(spec)
                        local value=p.dict_flags[flag]
                        if value~=nil and value~=false and value~=0
                            and not ((value==true or value==1) and mask & bit~=0
                                and type(p[1])=="table" and type(p[1][field])=="number") then return reject("DICT_VALUE_CONFLICT_"..flag) end
                    end
                end
                if phaser & (1|2)~=0 then return reject("PHASER_PRESET_DEPENDENCY_ACTIVE") end
                local attr=p.attribute or api.safe(api.attributeByUI,ui)
                if rawKey then cache.__failure[rawKey]="ORDINARY_ATTRIBUTE_FG_UNPROVEN" end
                local fg=attrFG(attr)
                if not fg then return reject("ORDINARY_ATTRIBUTE_FG_UNPROVEN(ui="..tostring(ui)..")") end
                if rawKey then cache.__failure[rawKey]="ORDINARY_STEP_SHAPE_UNPROVEN" end
                local steps,n={},0
                for k,v in pairs(p) do if type(k)=="number" then
                    if k%1~=0 or k<1 or type(v)~="table" then
                        return reject("ORDINARY_STEP_RECORD_SHAPE_UNPROVEN(ui="..tostring(ui)
                            ..",index="..tostring(k)..",type="..type(v)..")")
                    end
                    n=n+1; steps[k]=v
                end end
                if n==0 or n>256 then return reject("ORDINARY_STEP_COUNT_UNPROVEN(ui="..tostring(ui)..",count="..tostring(n)..")") end
                local stepKnown={absolute=true,relative=true,absolute_value=true,abs_release=true,rel_release=true,
                    abs_remove=true,rel_remove=true,abs_preset=true,rel_preset=true,integrated=true,accel=true,
                    decel=true,trans=true,transition=true,width=true,channel_function=true,mask_active=true,
                    mask_individual=true,mask_integrated=true,dict_flags=true}
                for i=1,n do
                    if not steps[i] then return reject("ORDINARY_STEP_INDEX_GAP(ui="..tostring(ui)..",index="..tostring(i)..")") end
                    if steps[i].absolute_value~=nil
                        and (type(steps[i].absolute_value)~="number" or type(steps[i].absolute)~="number"
                            or mask & 2==0) then return reject("ORDINARY_ABSOLUTE_VALUE_SHAPE_UNPROVEN(ui="..tostring(ui)..")") end
                    for k,v in pairs(steps[i]) do
                        if type(k)=="string" and not stepKnown[k] and v~=nil then
                            return reject("ORDINARY_UNKNOWN_STEP_FIELD(ui="..tostring(ui)..",field="..tostring(k)..")")
                        end
                        if (k=="abs_release" or k=="rel_release" or k=="abs_remove" or k=="rel_remove"
                            or k=="abs_preset" or k=="rel_preset" or k=="integrated") and v~=nil and v~=false and v~=0 then
                            return reject("ORDINARY_ACTIVE_STEP_DEPENDENCY(ui="..tostring(ui)..",field="..tostring(k)..")")
                        end
                    end
                end
                local motionBits=4|8|16|32|128|256
                if rawKey then cache.__failure[rawKey]="ORDINARY_LANE_VALUE_UNPROVEN" end
                for _,spec in ipairs({{"ABS","absolute",2},{"REL","relative",4}}) do
                    local layer,field,bit=table.unpack(spec)
                    if mask & bit~=0 then
                        local values={}
                        for i=1,n do
                            local step=steps[i]
                            local value=step and step[field]
                            if type(value)~="number" then
                                return reject("ORDINARY_LANE_VALUE_UNPROVEN(ui="..tostring(ui)
                                    ..",layer="..layer..",type="..type(value)..",mask="..tostring(mask)..")")
                            end
                            if value~=value or math.abs(value)==math.huge then
                                return reject("ORDINARY_LANE_VALUE_NONFINITE(ui="..tostring(ui)
                                    ..",layer="..layer..",mask="..tostring(mask)..")")
                            end
                            values[tostring(value)]=true
                        end
                        local channelMoving=phaser & motionBits~=0 or count(values)>1
                        moving=moving or channelMoving
                        local lane=fg.."|"..layer
                        scope[lane]=scope[lane] or {fg=fg,layer=layer,storedUI={},moving=false}
                        if next(scope[lane].storedUI) and scope[lane].moving~=channelMoving then
                            return reject("ORDINARY_LANE_CONFLICT(ui="..tostring(ui)..",lane="..lane..")")
                        end
                        scope[lane].storedUI[ui]=true
                        scope[lane].moving=channelMoving
                    end
                end
            elseif ui=="by_fixtures" then if raw.by_fixtures~=false then return reject("BY_FIXTURES_SHAPE_UNPROVEN") end
            elseif ui~="count" then return reject("ORDINARY_TOP_LEVEL_FIELD_UNPROVEN("..tostring(ui)..")") end
        end
        if rawKey then cache.__failure[rawKey]="ORDINARY_REFERENCE_SUMMARY_UNPROVEN" end
        if channels==0 or (raw.count~=nil and raw.count~=channels) or not next(scope) then
            return reject("ORDINARY_CHANNEL_SUMMARY_UNPROVEN(channels="..tostring(channels)
                ..",count="..tostring(raw.count)..",lanes="..tostring(count(scope))..")")
        end
        -- Static ordinary references require the proven single-step, no-motion
        -- shape. Moving references require explicit motion bits or step change.
        if not moving then
            for _,p in pairs(raw) do if type(p)=="table" and type(p[1])=="table" then
                local n=0
                for k in pairs(p) do if type(k)=="number" then n=n+1 end end
                if n~=1 then return reject("ORDINARY_STATIC_STEP_COUNT_UNPROVEN(count="..tostring(n)..")") end
            end end
            for _,lane in pairs(scope) do lane.moving=false end
        else
            for laneName,lane in pairs(scope) do if not lane.moving then
                return reject("ORDINARY_MOVING_LANE_CONFLICT(lane="..tostring(laneName)..")")
            end end
        end
        if rawKey then cache.__failure[rawKey]=nil end
        return {kind="ORDINARY",mode=mode,lanes=scope,raw=raw}
    end
    local function propertyMap(node)
        local props={}; local n=api.safe(function() return node:PropertyCount() end)
        if type(n)~="number" or n<0 or n>512 then return nil end
        for i=0,n-1 do
            local name=api.safe(function() return node:PropertyName(i) end)
            if type(name)=="string" then
                local value=api.safe(function() return node[name] end)
                if value==nil then value=api.safe(function() return node:Get(name) end) end
                props[name:lower()]=value
            end
        end
        return props
    end
    local function relZero(node,raw)
        if type(raw)=="string" and raw=="None" then return "ABSENT" end
        if type(raw)=="string" and tonumber(raw) and tonumber(raw)~=0 then return "AUTHORED" end
        if type(raw)~="number" then return "UNKNOWN" end
        if raw~=0 then return "AUTHORED" end
        local direct=api.safe(function() return node.ValueRelative end)
        local getter=api.safe(function() return node:Get("ValueRelative") end)
        local role=((_G.Enums or {}).Roles or {}).Display
        local display=role and api.safe(function() return node:Get("ValueRelative",role) end)
        local function empty(x) return x==nil or type(x)=="string" and x:match("^%s*$")~=nil end
        if empty(direct) and empty(getter) and empty(display) then return "ABSENT" end
        if direct==0 and getter==0 and tonumber(display)==0 then return "AUTHORED" end
        return "UNKNOWN"
    end
    local function phaser(ref,referenceCache)
        local refKey=api.identity(ref)
        referenceCache.__failure=referenceCache.__failure or {}
        if refKey then referenceCache.__failure[refKey]="PHASER_STRUCTURE_UNPROVEN" end
        local steps,linked,features,recipes,stepCount={}, {}, {},0,0
        local mismatch=false; local unknownRel=false
        local function walk(node,step,depth)
            if depth>8 then mismatch=true; return end
            local c=api.class(node):lower()
            if c=="phaserrecipe" then recipes=recipes+1 end
            if c=="phaserrecipestep" then step=node; stepCount=stepCount+1 end
            if c=="phaserrecipevaluesource" then
                if not step then mismatch=true; return end
                local p=propertyMap(node)
                if not p then mismatch=true; return end
                local attr=resolveHandle(p.attributes or p.attribute,"attribute")
                local fg=attrFG(attr)
                if not fg then mismatch=true; return end
                features[fg]=true
                local link=p.preset and resolveHandle(p.preset,"preset")
                if p.preset~=nil and tostring(p.preset)~="" and not link then mismatch=true; return end
                if link then
                    local id=api.identity(link) or link
                    linked[id]=linked[id] or {handle=link,fgs={}}
                    linked[id].fgs[fg]=true
                end
                local function record(layer,value)
                    if type(value)~="number" or value~=value then mismatch=true; return end
                    local key=fg.."|"..layer
                    steps[key]=steps[key] or {fg=fg,layer=layer,values={},stepIds={}}
                    steps[key].values[tostring(value)]=true
                    steps[key].stepIds[step]=true
                end
                local shape=p.shape and resolveHandle(p.shape,"phaserrecipevaluesource")
                if p.shape~=nil and tostring(p.shape)~="" and not shape then mismatch=true; return end
                local inherited=shape and propertyMap(shape) or nil
                local av=p.rawvalueabs
                if (av==nil or av=="") and inherited then av=inherited.rawvalueabs end
                if (type(av)=="number" or type(av)=="string") and tonumber(av) then
                    record("ABS",tonumber(p.valueabsolute) or tonumber(av))
                elseif av~=nil and av~="" and av~="None" then mismatch=true end
                local rv=p.rawvaluerel
                if (rv==nil or rv=="") and inherited then rv=inherited.rawvaluerel end
                local rel=relZero(node,rv)
                if rel=="AUTHORED" then record("REL",tonumber(p.valuerelative) or tonumber(rv))
                elseif rel=="UNKNOWN" and rv~=nil then unknownRel=true end
            end
            for _,child in ipairs(api.children(node)) do walk(child,step,depth+1) end
        end
        walk(ref,nil,0)
        if mismatch or recipes~=1 or stepCount<1 or not next(steps) then return nil end
        local lanes={}; local provenMovingAbs=false
        for key,s in pairs(steps) do
            if count(s.stepIds)~=stepCount then return nil end
            local moving=count(s.values)>1
            lanes[key]={fg=s.fg,layer=s.layer,moving=moving}
            if s.layer=="ABS" and moving then provenMovingAbs=true end
        end
        local linkedCount=0
        if refKey then referenceCache.__failure[refKey]="PHASER_LINKED_PRESET_UNPROVEN" end
        for _,entry in pairs(linked) do
            linkedCount=linkedCount+1
            local handle=entry.handle
            local key=api.identity(handle) or handle
            local meta=referenceCache[key]
            if meta==nil then meta=ordinary(handle,referenceCache); referenceCache[key]=meta or false end
            if type(meta)~="table" or meta.kind~="ORDINARY" or meta.mode==1 then return nil end
            if meta.mode~=2 and meta.mode~=3 then return nil end
            for _,lane in pairs(meta.lanes) do if lane.moving or lane.layer~="ABS" then return nil end end
            for fg in pairs(entry.fgs) do if not meta.lanes[fg.."|ABS"] then return nil end end
        end
        if unknownRel then
            if not provenMovingAbs or count(features)~=1 or linkedCount==0 then return nil end
            if refKey then referenceCache.__failure[refKey]=nil end
            return {kind="PHASER",lanes=lanes,relBarrier=next(features)}
        end
        if refKey then referenceCache.__failure[refKey]=nil end
        return {kind="PHASER",lanes=lanes}
    end
    local function metadata(ref,cache)
        local key=api.identity(ref)
        if not key then return nil end
        if cache[key]~=nil then return cache[key] or nil end
        local c=api.class(ref):lower()
        local m
        if c=="preset" then
            local structural=false
            for _,child in ipairs(api.children(ref)) do if api.class(child):lower()=="phaserrecipe" then structural=true; break end end
            m=structural and phaser(ref,cache) or ordinary(ref,cache)
        elseif c=="random" or c=="generator" or c=="generatorrandom" then
            m={kind="GENERATOR",lanes={}}
            local channels=api.safe(function() return ref.RandomChannels end)
            if channels==nil then for _,child in ipairs(api.children(ref)) do
                if api.class(child):lower()=="randomchannels" then channels=child; break end
            end end
            for _,channel in ipairs(api.children(channels)) do
                local attr=api.safe(function() return channel.Attribute end)
                local fg=attrFG(attr)
                if not fg then m=nil; break end
                m.lanes[fg.."|ABS"]={fg=fg,layer="ABS",moving=true}
            end
            if m and not next(m.lanes) then m=nil end
        elseif c=="phaserrecipe" then m=phaser(ref,cache) end
        cache[key]=m or false
        return m
    end
    -- Preserve only scope which the reference metadata independently proves.
    -- An unknown feature or layer becomes a conservative wildcard barrier.
    local function unsafeScope(ref,cache)
        local id=api.identity(ref)
        local raw=id and cache.__raw and cache.__raw[id]
        local features,layers={},{}
        local featureKnown,layerKnown,seen=true,true,false
        if type(raw)=="table" then for ui,p in pairs(raw) do if type(ui)=="number" then
            seen=true
            if type(p)~="table" then featureKnown=false; layerKnown=false
            else
                local fg=attrFG(p.attribute or api.safe(api.attributeByUI,ui))
                if fg then features[fg]=true else featureKnown=false end
                local mask=p.mask_active_value
                if type(mask)=="number" and math.type(mask)=="integer"
                    and mask>0 and mask & ~(2|4)==0 then
                    if mask & 2~=0 then layers.ABS=true end
                    if mask & 4~=0 then layers.REL=true end
                else layerKnown=false end
            end
        end end
        else
            local function walk(node,depth)
                if depth>8 then featureKnown=false; layerKnown=false; return end
                if api.class(node):lower()=="phaserrecipevaluesource" then
                    seen=true
                    local p=propertyMap(node)
                    if not p then featureKnown=false; layerKnown=false
                    else
                        local attr=resolveHandle(p.attributes or p.attribute,"attribute")
                        local fg=attrFG(attr)
                        if fg then features[fg]=true else featureKnown=false end
                        local shape=p.shape and resolveHandle(p.shape,"phaserrecipevaluesource")
                        local inherited=shape and propertyMap(shape)
                        if p.shape~=nil and tostring(p.shape)~="" and not inherited then layerKnown=false end
                        local av=p.rawvalueabs
                        if (av==nil or av=="") and inherited then av=inherited.rawvalueabs end
                        local rv=p.rawvaluerel
                        if (rv==nil or rv=="") and inherited then rv=inherited.rawvaluerel end
                        if tonumber(av) then layers.ABS=true
                        elseif av~=nil and av~="" and av~="None" then layerKnown=false end
                        local rel=relZero(node,rv)
                        if rel=="AUTHORED" or rel=="UNKNOWN" then layers.REL=true end
                        if av==nil and rv==nil and not inherited then layerKnown=false end
                    end
                end
                for _,child in ipairs(api.children(node)) do walk(child,depth+1) end
            end
            walk(ref,0)
        end
        return seen and featureKnown and next(features) and features or nil,
            seen and layerKnown and next(layers) and layers or nil
    end
    local function run(rows,members,referenceCache,uiCache,targetFG)
        local normalized={}
        for _,source in ipairs(rows) do
            local row={ref=source.ref,refId=api.identity(source.ref),group=source.group,
                members={},lanes={},superseded={}}
            if not row.refId then return fail("REFERENCE_IDENTITY_UNPROVEN") end
            for key,handle in pairs(members) do
                if source.groupMembers[key] then row.members[key]=handle end
            end
            if next(row.members) then
                local meta=metadata(source.ref,referenceCache)
                if not meta then
                    row.unsafe=true
                    row.features,row.layers=unsafeScope(source.ref,referenceCache)
                else
                    for key,handle in pairs(row.members) do
                        local ui=memberUI(handle,uiCache)
                        if not ui then return fail("MEMBER_UI_CAPABILITY_UNPROVEN") end
                        for lane,data in pairs(meta.lanes) do
                            local applicable=ui.byFG[data.fg]
                            if meta.kind=="ORDINARY" and meta.mode==1 then
                                applicable=false
                                for stored in pairs(data.storedUI) do
                                    if ui.byUI[stored]==data.fg then applicable=true; break end
                                end
                            end
                            if applicable then
                                row.lanes[key]=row.lanes[key] or {}
                                row.lanes[key][lane]=data
                            end
                        end
                    end
                    if meta.relBarrier then row.relBarrier=meta.relBarrier end
                end
                normalized[#normalized+1]=row
            end
        end
        local decided,blocked,refs,survivors,assignments,unsafeRows={},{},{},{},{},{}
        local residual={}; local laneWork=0
        local function checkpoint()
            laneWork=laneWork+1
            return laneWork<=1048576
        end
        local function barrierKeys(row)
            local keys={}
            for member in pairs(row.members) do
                if not row.features then keys[member.."\0*"]=true
                else for feature in pairs(row.features) do
                    if not row.layers then keys[member.."\0"..feature.."|*"]=true
                    else for layer in pairs(row.layers) do
                        keys[member.."\0"..feature.."|"..layer]=true
                    end end
                end end
            end
            return keys
        end
        for index,row in ipairs(normalized) do
            row.reverseIndex=index
            if row.unsafe then
                unsafeRows[#unsafeRows+1]=row
                for key in pairs(row.members) do
                    if not checkpoint() then return fail("LANE_WORK_LIMIT") end
                    blocked[key]=blocked[key] or {}
                    if not row.features then blocked[key]["*"]=blocked[key]["*"] or row
                    else for feature in pairs(row.features) do
                        if not row.layers then
                            local lane=feature.."|*"
                            blocked[key][lane]=blocked[key][lane] or row
                        else for layer in pairs(row.layers) do
                            local lane=feature.."|"..layer
                            blocked[key][lane]=blocked[key][lane] or row
                        end end
                    end end
                end
            else
                for key,lanes in pairs(row.lanes) do
                    decided[key]=decided[key] or {}
                    for lane,data in pairs(lanes) do
                        if not checkpoint() then return fail("LANE_WORK_LIMIT") end
                        local old=decided[key][lane]
                        local barrier
                        for _,candidateKey in ipairs({lane,data.fg.."|*","*"}) do
                            local candidate=(blocked[key] or {})[candidateKey]
                            if candidate and (not barrier or candidate.reverseIndex<barrier.reverseIndex) then
                                barrier=candidate
                            end
                        end
                        if old then row.superseded[#row.superseded+1]={member=key,lane=lane,newer=old}
                        elseif barrier then
                            row.superseded[#row.superseded+1]={member=key,lane=lane,newer=barrier,unsafe=true}
                        else
                            decided[key][lane]=row
                            assignments[#assignments+1]={member=key,lane=lane,fg=data.fg,row=row}
                            if data.moving then
                                refs[row.refId]=row.ref
                                survivors[row.refId]=survivors[row.refId] or {}
                                survivors[row.refId][key]=true
                            end
                        end
                    end
                    if row.relBarrier then
                        local lane=row.relBarrier.."|REL"
                        if uiCache[row.members[key]].byFG[row.relBarrier]
                            and not decided[key][lane] and not (blocked[key] or {})[lane] then
                            blocked[key]=blocked[key] or {}
                            local barrier={reverseIndex=index,relResidual=true,
                                member=key,feature=row.relBarrier,layer="REL"}
                            blocked[key][lane]=barrier
                            residual[#residual+1]=barrier
                        end
                    end
                end
            end
        end
        local decidedByKey,unresolvedByKey,victims={},{},{}
        for _,a in ipairs(assignments) do decidedByKey[a.member.."\0"..a.lane]=a.row end
        for member,lanes in pairs(blocked) do for lane,row in pairs(lanes) do
            local key=member.."\0"..lane
            if not decidedByKey[key] then unresolvedByKey[key]=row end
        end end
        for _,row in ipairs(normalized) do for _,sup in ipairs(row.superseded) do
            if sup.unsafe then victims[sup.newer]=(victims[sup.newer] or 0)+1 end
        end end
        local attribution={finalSurviving={},fullySuperseded={},unknown={}}
        for _,row in ipairs(unsafeRows) do
            local keys=barrierKeys(row)
            local total,surviving,neutralized=0,0,0
            for key in pairs(keys) do
                total=total+1
                if unresolvedByKey[key]==row then surviving=surviving+1
                else
                    local decider=decidedByKey[key]
                    local newer=unresolvedByKey[key]
                    if (decider and decider.reverseIndex<row.reverseIndex)
                        or (newer and newer.reverseIndex<row.reverseIndex) then
                        neutralized=neutralized+1
                    end
                end
            end
            if surviving>0 or (victims[row] or 0)>0 or (refs[row.refId] and total>0) then
                attribution.finalSurviving[#attribution.finalSurviving+1]=row
            elseif total>0 and neutralized==total then
                attribution.fullySuperseded[#attribution.fullySuperseded+1]=row
            else attribution.unknown[#attribution.unknown+1]=row end
        end
        if #attribution.finalSurviving>0 or #attribution.unknown>0 then
            local blockers={}
            for _,list in ipairs({attribution.finalSurviving,attribution.unknown}) do
                for _,row in ipairs(list) do
                    local id=row.refId
                    if id then blockers[id]=true end
                end
            end
            local blockerRefs={}
            for id in pairs(blockers) do blockerRefs[#blockerRefs+1]=id end
            table.sort(blockerRefs)
            local blockerDetails={}
            for _,id in ipairs(blockerRefs) do
                blockerDetails[id]=(referenceCache.__failure or {})[id] or "UNSAFE_SCOPE_OR_ATTRIBUTION"
            end
            return {classification="INCONCLUSIVE",reason="UNSAFE_LANE_ATTRIBUTION_BLOCKER",
                refs={},unsafeAttribution=attribution,unsafeRefs=blockerRefs,
                unsafeRefDetails=blockerDetails,
                laneWork=laneWork}
        end
        for _,barrier in ipairs(residual) do
            -- A residual REL barrier may also suppress an older unsafe row.
            -- Its absence from the final reference set is not evidence of safety.
            for _,older in ipairs(unsafeRows) do
                if older.reverseIndex>barrier.reverseIndex and older.members[barrier.member]
                    and (not older.features or older.features[barrier.feature])
                    and (not older.layers or older.layers[barrier.layer]) then
                    return fail("REL_BARRIER_BLOCKS_HISTORY")
                end
            end
            if (victims[barrier] or 0)>0 then return fail("REL_BARRIER_BLOCKS_HISTORY") end
        end
        local sourceGroups={}
        if targetFG then for _,assignment in ipairs(assignments) do
            if assignment.fg==targetFG and assignment.row.group then
                local groupId=api.identity(assignment.row.group)
                if groupId then sourceGroups[groupId]=assignment.row.group end
            end
        end end
        return {classification="PROVEN",refs=refs,refMembers=survivors,
            sourceGroups=sourceGroups,barriers=#residual,
            unsafeAttribution=attribution,laneWork=laneWork,remainingSemanticBlockers=0}
    end
    return {run=run,metadata=metadata,memberUI=memberUI}
end
-- END GENERATED TRACK A RUNTIME

recipePoolReferences = function(state)
    local references = {}
    local function add(object)
        local key = commandAddress(object)
        if key then references[key] = object end
    end
    local function addRecipe(recipe)
        for _, name in ipairs({ "Selection", "Values", "MAtricks", "Filter", "World", "Generator" }) do
            add(recipeField(recipe, name))
        end
    end
    local function canonicalMemberKey(fixture)
    local handle = fixture ~= nil and (fixture.handle or fixture) or nil
    if handle == nil then return nil end
    local raw = nil
    local ok, value = pcall(function()
        local fn = handle.ToAddr
        return type(fn) == "function" and fn(handle) or nil
    end)
    if ok and type(value) == "string" then raw = value end
    if raw == nil and callable("ToAddr") then
        local global = safe(ToAddr, handle)
        if type(global) == "string" then raw = global end
    end
    if type(raw) ~= "string" then return nil end
    local trimmed = string.gsub(string.gsub(raw, "^%s+", ""), "%s+$", "")
    local key = string.match(trimmed, "^Fixture%s+(%d+[%.%d]*)$")
    if not key or string.find(key, "..", 1, true) or string.match(key, "%.$") then return nil end
    -- A parsed display address is only a candidate identity. Native Track A
    -- requires this address to resolve uniquely back to the same handle.
    if not callable("ObjectList") then return nil end
    local resolved = safe(ObjectList, trimmed)
    if type(resolved) ~= "table" or #resolved ~= 1 then return nil end
    if resolved[1] ~= handle then
        local equal = callable("CompareHandle") and safe(CompareHandle, resolved[1], handle)
        if equal ~= true then return nil end
    end
    return key
end
    local function selectionKeys(fixtures)
    local keys, unproven = {}, 0
    for _, fixture in ipairs(fixtures or {}) do
        local key = canonicalMemberKey(fixture)
        if key then keys[key] = true else unproven = unproven + 1 end
    end
    return keys, unproven
end
    local function groupKeys(group)
    local keys, unproven = {}, 0
    local ok, selection = pcall(function() return group.Selection end)
    if not ok or type(selection) ~= "table" then return keys, 1 end
    for _, item in pairs(selection) do
        local key = nil
        if type(item) == "table" then
            if item.handle ~= nil then
                key = canonicalMemberKey(item)
            else
                local index = tonumber(item.sf_index)
                if index and callable("GetSubfixture") then
                    key = canonicalMemberKey(safe(GetSubfixture, index))
                end
            end
        end
        if key then keys[key] = true else unproven = unproven + 1 end
    end
    return keys, unproven
end
    local function relation(group, fixtures)
    if group == nil then return "DISJOINT", {}, {} end
    local selectionKeys, selectionBad = selectionKeys(fixtures)
    local groupKeys, groupBad = groupKeys(group)
    if selectionBad > 0 or groupBad > 0 then return "UNPROVEN", selectionKeys, groupKeys end
    local selectionCount, groupCount, shared = 0, 0, 0
    for _ in pairs(selectionKeys) do selectionCount = selectionCount + 1 end
    for _ in pairs(groupKeys) do groupCount = groupCount + 1 end
    if selectionCount == 0 or groupCount == 0 then return "DISJOINT", selectionKeys, groupKeys end
    for key in pairs(selectionKeys) do if groupKeys[key] then shared = shared + 1 end end
    if shared == selectionCount and shared == groupCount then return "EXACT_COMPLETE", selectionKeys, groupKeys end
    if shared == groupCount then return "SELECTION_CONTAINS_COMPLETE_GROUP", selectionKeys, groupKeys end
    if shared == 0 then return "DISJOINT", selectionKeys, groupKeys end
    return "PARTIAL", selectionKeys, groupKeys
end
    local function completeGroups(fixtures)
    local pool = callable("DataPool") and safe(DataPool) or nil
    local groups = safe(function() return pool.Groups end)
    local matches = {}
    for _, group in ipairs(children(groups)) do
        local relation = relation(group, fixtures)
        if relation == "EXACT_COMPLETE" or relation == "SELECTION_CONTAINS_COMPLETE_GROUP" then
            matches[#matches + 1] = group
        end
    end
    table.sort(matches, function(a, b)
        return tostring(commandAddress(a)) < tostring(commandAddress(b))
    end)
    return matches
end
    local function advanceStagedResolver(task,taskState)
        local cache=taskState.referenceMetadataCache
        local cursor=task.metadataIndex or 1
        while cursor<=#task.rows do
            local row=task.rows[cursor]
            local refKey=commandAddress(row.ref)
            if refKey and cache[refKey]==nil then
                task.runtime.metadata(row.ref,cache)
                task.metadataIndex=cursor+1
                taskState.lastResolverStage="REFERENCE_METADATA"
            end
            cursor=cursor+1
        end
        task.metadataIndex=#task.rows+1
        cursor=task.memberIndex or 1
        -- Selection context is already read on this host refresh. Complete
        -- its bounded Recipe/member pass now so the corresponding frames do
        -- not wait through dozens of polling yields.
        while cursor<=#task.members do
            local member=task.members[cursor]
            if taskState.memberUICache[member.handle]==nil then
                task.runtime.memberUI(member.handle,taskState.memberUICache)
                taskState.lastResolverStage="MEMBER_UI"
            end
            cursor=cursor+1
        end
        task.memberIndex=cursor
        taskState.resolverMembersWarmed=math.min(cursor-1,#task.members)
        taskState.resolverMembersTotal=#task.members
        local ok,result=pcall(task.runtime.run,task.rows,task.selectedMembers,
            taskState.referenceMetadataCache,taskState.memberUICache,task.targetFG)
        if not ok then return {classification="INCONCLUSIVE",reason="TRACK_A_RUNTIME_ERROR",refs={}} end
        if result.classification~="PROVEN" then return result end
        local refs={}
        for id,ref in pairs(result.refs or {}) do refs[id]=ref end
        result.refs=refs
        return result
    end
    local function sources(sequence, currentCue, fixtures, info,completeCandidates,taskState)
    if taskState and taskState.incrementalResolver and taskState.resolverTask
        and taskState.resolverTask.key==taskState.resolverWorkKey then
        return advanceStagedResolver(taskState.resolverTask,taskState)
    end
    if not sequence or not currentCue then
        return { classification = "INCONCLUSIVE" }
    end
    local selectedMembers={}
    for _, fixture in ipairs(fixtures or {}) do
        local key = canonicalMemberKey(fixture)
        if not key then return {classification="INCONCLUSIVE", reason="MEMBER_IDENTITY_UNPROVEN"} end
        selectedMembers[key]=fixture.handle or fixture
    end
    if next(selectedMembers) == nil then return { classification = "INCONCLUSIVE" } end
    local currentNumber = cueNumber(currentCue)
    if currentNumber == nil then return { classification = "INCONCLUSIVE" } end
    local rows, cueCount, recipeCount = {}, 0, 0
    for _, cue in ipairs(children(sequence)) do
        if cueCount >= MAX_CUES or recipeCount >= MAX_RECIPES then break end
        local candidateNumber = cueNumber(cue)
        if string.lower(class(cue)) == "cue"
            and candidateNumber ~= nil and candidateNumber <= currentNumber then
            cueCount = cueCount + 1
            for _, part in ipairs(children(cue)) do
                if string.lower(class(part)) == "part" then
                    for ordinal, recipe in ipairs(children(part)) do
                        if recipeCount >= MAX_RECIPES then break end
                        if isStandardRecipe(recipe) and recipeEnabled(recipe) then
                            recipeCount = recipeCount + 1
                            rows[#rows + 1] = {
                                cue = cue, part = part, recipe = recipe,
                                cueNumber = candidateNumber,
                                partNumber = partNumber(part),
                                recipeIndex = recipeNumber(recipe, ordinal) or ordinal,
                            }
                        end
                    end
                end
            end
        end
    end
    table.sort(rows, function(left, right)
        if left.cueNumber ~= right.cueNumber then return left.cueNumber > right.cueNumber end
        if left.partNumber ~= right.partNumber then return left.partNumber > right.partNumber end
        return left.recipeIndex > right.recipeIndex
    end)
    local scopedRows={}
    for _, row in ipairs(rows) do
        local group=recipeField(row.recipe,"Selection")
        local gid=commandAddress(group)
        if gid==nil then return {classification="INCONCLUSIVE", reason="RECIPE_GROUP_UNPROVEN"} end
        -- Layout selections often contain only some members of a Recipe's
        -- Stored Group. Resolve those selected member lanes; this does not
        -- make the Group a complete UPDATE target.
        local keys, groupBad = groupKeys(group)
        local values = recipeField(row.recipe, "Generator") or recipeField(row.recipe, "Values")
        if groupBad > 0 then return { classification = "INCONCLUSIVE" } end
        local intersects = false
        for key in pairs(selectedMembers) do if keys[key] then intersects = true; break end end
        if intersects then
            if not values then return { classification = "INCONCLUSIVE" } end
            scopedRows[#scopedRows+1]={ref=values,group=group,groupMembers=keys}
        end
    end
    if #scopedRows==0 then return {classification="INCONCLUSIVE", reason="NO_APPLICABLE_RECIPE"} end
    state.referenceMetadataCache=state.referenceMetadataCache or {}
    state.memberUICache=state.memberUICache or {}
    local runtime=newTrackARuntime({safe=safe,class=class,children=children,
        identity=commandAddress,objectList=_G.ObjectList,getPresetData=_G.GetPresetData,
        getUIChannels=function(handle) return uiChannelsForMember(handle,state) end,
        attributeByUI=_G.GetAttributeByUIChannel})
    local selected=callable("GetSelectedAttribute") and safe(GetSelectedAttribute) or nil
    local feature=selected and safe(function() return selected.Feature end)
    if not feature and callable("SelectedFeature") then feature=safe(SelectedFeature) end
    local fg=feature and safe(function() return feature:Parent() end)
    local targetFG=string.lower(class(fg))=="featuregroup" and commandAddress(fg) or nil
    if taskState and taskState.incrementalResolver then
        local members={}
        for key,handle in pairs(selectedMembers) do members[#members+1]={key=key,handle=handle} end
        table.sort(members,function(a,b) return a.key<b.key end)
        local task={key=taskState.resolverWorkKey,rows=scopedRows,
            selectedMembers=selectedMembers,members=members,runtime=runtime,targetFG=targetFG,
            metadataIndex=1,memberIndex=1}
        taskState.resolverTask=task
        return advanceStagedResolver(task,taskState)
    end
    local ok,result=pcall(runtime.run,scopedRows,selectedMembers,
        state.referenceMetadataCache,state.memberUICache,targetFG)
    if not ok then return {classification="INCONCLUSIVE",reason="TRACK_A_RUNTIME_ERROR",refs={}} end
    if result.classification~="PROVEN" then return result end
    local refs={}
    for id,ref in pairs(result.refs) do refs[id]=ref end
    result.refs=refs
    return result
end
    local function refresh(state, sequence, currentCue, fixtures, info)
    if not state then return nil end
    local memberKeys = {}
    for _, fixture in ipairs(fixtures or {}) do
        local key = canonicalMemberKey(fixture)
        if key then memberKeys[#memberKeys + 1] = key end
    end
    table.sort(memberKeys)
    local selectionKey=table.concat(memberKeys, ",")
    state.lastGroupMatchMs=0
    if state.completeGroupSelectionKey~=selectionKey or not state.completeGroupCandidates then
        local groupStarted=contextClock()
        state.completeGroupSelectionKey=selectionKey
        state.completeGroupCandidates=completeGroups(fixtures)
        state.lastGroupMatchMs=contextElapsed(groupStarted)
    end
    local groupKeys = {}
    for _, group in ipairs(state.completeGroupCandidates) do
        groupKeys[#groupKeys + 1] = tostring(commandAddress(group))
    end
    table.sort(groupKeys)
    local cacheKey = tostring(commandAddress(sequence)) .. ":" .. tostring(cueNumber(currentCue))
        .. ":" .. tostring(info and info.feature) .. ":"
        .. table.concat(groupKeys, ",") .. ":" .. table.concat(memberKeys, ",")
        .. ":" .. tostring(commandAddress(state.currentRecipe))
        .. ":" .. tostring(commandAddress(state.currentOldPreset))
        .. ":" .. tostring(#(state.matchingCandidates or {}))
    if state.provenSourceKey == cacheKey then return state.provenSources end
    if state.resolverWorkKey~=cacheKey then
        state.resolverWorkKey=cacheKey
        state.resolverTask=nil
        state.resolverWarmRefIndex=1
        state.resolverWarmUIIndex=1
        state.resolverWorkStarted=contextClock()
    end
    local started = contextClock()
    local result = sources(sequence, currentCue, fixtures, info,state.completeGroupCandidates,state)
    local sliceElapsed = contextElapsed(started) or "UNMEASURED"
    state.lastResolverSliceMs=type(sliceElapsed)=="number" and sliceElapsed or nil
    if result.classification=="PENDING" then
        state.provenSourceKey=nil
        state.provenSources=result
        state.lastResolverMs=state.lastResolverSliceMs
        return result
    end
    local elapsed=contextElapsed(state.resolverWorkStarted) or sliceElapsed
    state.resolverWorkKey=nil
    state.resolverTask=nil
    state.resolverWorkStarted=nil
    state.resolverWarmRefIndex=nil
    state.resolverWarmUIIndex=nil
    local oldKeys, newKeys = {}, {}
    if state.provenSources and state.provenSources.refs then
        for key in pairs(state.provenSources.refs) do oldKeys[#oldKeys + 1] = key end
    end
    if result.refs then for key in pairs(result.refs) do newKeys[#newKeys + 1] = key end end
    table.sort(oldKeys); table.sort(newKeys)
    local oldSet = {}; for _, key in ipairs(oldKeys) do oldSet[key] = true end
    local missing, extra = {}, {}
    for _, key in ipairs(oldKeys) do if not result.refs or not result.refs[key] then missing[#missing + 1] = key end end
    for _, key in ipairs(newKeys) do if not oldSet[key] then extra[#extra + 1] = key end end
    state.provenSourceKey = cacheKey
    state.provenSources = result
    state.lastResolverMs=state.lastResolverSliceMs
    state.lastResolverTotalMs=type(elapsed)=="number" and elapsed or nil
    state.markerProbeSerial=(state.markerProbeSerial or 0)+1
    state.markerProbe={}
    state.markerStatus=nil
    for key in pairs(result.refs or {}) do
        state.markerProbe[key]={finalRef=true,sourceAdmitted=false,poolTileFound=false,
            poolTileVisible=false,identityMatch=false,frameCreated=false}
    end
    state.poolMarkersDirty=true
    if callable("ErrEcho") then
        local finalList=table.concat(newKeys,",")
        if #finalList>256 then finalList=finalList:sub(1,256).."..." end
        safe(ErrEcho, string.format("[RecipeTracking][ResolverShadow] cue=%s groups=%d members=%d final_refs=%d resolver_ms=%s classification=%s refs=%s",
            tostring(cueNumber(currentCue)), #groupKeys, #memberKeys, #newKeys,
            tostring(elapsed), tostring(result.classification), finalList~="" and finalList or "-"))
    end
    return result
end
    if state ~= nil and state.provenHooks == nil then
        state.provenHooks = {
            canonicalMemberKey = canonicalMemberKey,
            selectionKeys = selectionKeys,
            groupKeys = groupKeys,
            relation = relation,
            completeGroups = completeGroups,
            sources = sources,
            refresh = refresh,
            advanceStagedResolver = advanceStagedResolver,
        }
    end
    local flagOn = state ~= nil and state.provenEnabled == true
    if flagOn then
        local provenResult = refresh(state, state.currentSequence, state.currentCue,
            state.lastFixtures, { feature = state.lastFeature })
        state.currentGroups={}
        if provenResult and provenResult.classification == "PROVEN" then
            for _,group in pairs(provenResult.sourceGroups or {}) do
                state.currentGroups[#state.currentGroups+1]=group
            end
            table.sort(state.currentGroups,function(a,b)
                return tostring(commandAddress(a))<tostring(commandAddress(b))
            end)
            for _,group in ipairs(state.currentGroups) do add(group) end
            for _, object in pairs(provenResult.refs) do add(object) end
            for key,probe in pairs(state.markerProbe or {}) do
                probe.sourceAdmitted=references[key]~=nil
            end
            return references
        end
        -- A single selected Attribute's displayed Recipe has a concrete
        -- Stored Group handle even if its Values metadata remains unsafe.
        -- This marks only that displayed Group, never every overlapping Pool
        -- Group. Recipe references themselves still fail closed.
        if state.currentGroup and (state.currentRecipe
            or relation(state.currentGroup,state.lastFixtures)=="EXACT_COMPLETE") then
            state.currentGroups={state.currentGroup}
            add(state.currentGroup)
        end
        return references
    end
    if state.currentRecipe then
        addRecipe(state.currentRecipe)
    else
        for _, item in ipairs(state.matchingCandidates or {}) do addRecipe(item.recipe) end
    end
    add(state.currentGroup)
    local sequenceKey = commandAddress(state.currentSequence) or address(state.currentSequence)
    local groupKey = commandAddress(state.currentGroup) or address(state.currentGroup)
    local referenceKey = sequenceKey .. ":" .. tostring(cueNumber(state.currentCue) or "")
        .. ":" .. groupKey
    if state.groupPoolReferenceKey ~= referenceKey then
        state.poolGridRefreshNeeded = true
        local ok, scoped = pcall(trackedGroupRecipeReferences,
            state.currentSequence, state.currentCue, state.currentGroup)
        state.groupPoolReferenceKey = referenceKey
        state.groupPoolReferences = ok and scoped or {}
        if not ok and callable("ErrEcho") then
            safe(ErrEcho, "[RecipeTracking] " .. tostring(scoped))
        end
    end
    for _, object in pairs(state.groupPoolReferences or {}) do add(object) end
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

-- Diagnostic helpers.  Reference address lookups are memoized once per
-- unique object per scan, so reference classification adds at most one
-- ToAddr per Pool reference instead of one per occurrence.  Elapsed time
-- uses the standard Lua clock only when the host exposes it.
local UNRESOLVED_ADDRESS = {}

local function memoReferenceAddress(scan, ref)
    if ref == nil then return nil end
    local memo = scan.addrMemo
    local cached = memo[ref]
    if cached == nil then
        cached = commandAddress(ref) or UNRESOLVED_ADDRESS
        memo[ref] = cached
    end
    return cached == UNRESOLVED_ADDRESS and nil or cached
end

local function clockSeconds()
    return contextClock()
end

local function elapsedMs(started)
    local now = clockSeconds()
    if started == nil or now == nil then return nil end
    local elapsed = (now - started) * 1000
    return elapsed >= 0 and elapsed or 0
end

local function formatElapsed(value)
    return value ~= nil and string.format("%.1f", value) or "n/a"
end

local function poolPulseColor(kind,on)
    if kind=="recipe" then
        return "SheetColor.PhaserText"
    end
    return on and "Global.SuccessText" or "Global.Selected"
end

local function advancePoolPulse(state)
    if state.poolBlink == false or not state.running then return end
    local now=clockSeconds()
    local pulseChanged=false
    if type(state.poolBlinkDeadline)~="number" then
        state.poolBlinkOn=true
        state.poolBlinkDeadline=now and now+0.125 or nil
        pulseChanged=true
    elseif now and now>=state.poolBlinkDeadline then
        local steps=math.floor((now-state.poolBlinkDeadline)/0.125)+1
        if steps%2==1 then state.poolBlinkOn=not state.poolBlinkOn; pulseChanged=true end
        state.poolBlinkDeadline=state.poolBlinkDeadline+steps*0.125
    end
    if pulseChanged then
        for _,entry in pairs(state.poolMarkers or {}) do
            pcall(function()
                entry.overlay.Visible="Yes"
                entry.overlay.BackColor=poolPulseColor(entry.markerKind,state.poolBlinkOn)
            end)
        end
    end
end

local function newCueEffectScan(sequence, currentCue)
    local scan = {
        tracked = {}, parts = {}, index = 1, work = 0, advanceCalls = 0,
        addrMemo = {},
        diagnostics = {cue = cueLabel(currentCue), parts = {}, fastRefs = 0,
            startedClock = clockSeconds()}
    }
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

-- Keep performance evidence on the scan object.  The fields are counters
-- and memoized lookups only: diagnostics never add a full pass over a
-- large GetPresetData result, and each unique reference costs one ToAddr.
local function newPartScanDiagnostic(part, advance)
    return {
        part = partNumber(part), label = label(part), startedAdvance = advance,
        startedClock = clockSeconds(), elapsedMs = nil,
        channels = 0, numericChannels = 0, movingLayers = 0, emptyRefs = 0,
        unresolvedRefs = 0, uiMissing = 0, rtMissing = 0, attributeMissing = 0,
        recipeFeatureMiss = 0, recipeMembershipMiss = 0, recoveredRefs = 0,
        directRefs = 0, firstRefAdvance = nil
    }
end

local function effectScanLog(message)
    if callable("Printf") then safe(Printf, "[RecipeTracking][EffectScan] " .. message) end
end

local function logAbandonedScan(scan)
    if scan and not scan.done then
        effectScanLog(string.format("cancelled cue=%s advances=%d parts_done=%d",
            tostring(scan.diagnostics.cue), scan.advanceCalls or 0,
            #(scan.diagnostics.parts or {})))
    end
end

local function finishPartScanDiagnostic(scan, part, diagnostic)
    diagnostic.advances = scan.advanceCalls - diagnostic.startedAdvance + 1
    diagnostic.elapsedMs = elapsedMs(diagnostic.startedClock)
    scan.diagnostics.parts[#scan.diagnostics.parts + 1] = diagnostic
    effectScanLog(string.format(
        "cue=%s part=%s channels=%d numeric=%d advances=%d first_ref_advance=%s elapsed_ms=%s moving=%d direct_refs=%d recovered_refs=%d empty_refs=%d unresolved_refs=%d ui_missing=%d rt_missing=%d attribute_missing=%d feature_miss=%d membership_miss=%d",
        tostring(scan.diagnostics.cue), tostring(diagnostic.part), diagnostic.channels,
        diagnostic.numericChannels, diagnostic.advances, tostring(diagnostic.firstRefAdvance or "none"),
        formatElapsed(diagnostic.elapsedMs), diagnostic.movingLayers,
        diagnostic.directRefs, diagnostic.recoveredRefs, diagnostic.emptyRefs,
        diagnostic.unresolvedRefs, diagnostic.uiMissing, diagnostic.rtMissing,
        diagnostic.attributeMissing, diagnostic.recipeFeatureMiss, diagnostic.recipeMembershipMiss))
end

local function scanCueEffectPart(scan, part)
    local pending = scan.pendingPart
    if not pending then
        -- Create the diagnostic before the native read so its elapsed time
        -- includes the potentially expensive GetPresetData call.
        pending = {diagnostic = newPartScanDiagnostic(part, scan.advanceCalls)}
        scan.pendingPart = pending
    end
    local data = pending.data or safe(GetPresetData, part, false, false)
    if type(data) ~= "table" then error("Cue effect data unavailable") end
    pending.data = data
    local recipes = pending.recipes or {}
    if pending.recipes == nil then
    for ordinal, recipe in ipairs(children(part)) do
        scanCheckpoint(scan)
        if isStandardRecipe(recipe) and recipeEnabled(recipe) then
            local group = recipeField(recipe, "Selection")
            local members = safe(function() return group.Selection end)
            local ref = recipeField(recipe, "Generator")
            if not ref then ref = recipeField(recipe, "Values") end
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
    pending.recipes = recipes
    end
    for batch = 1, 32 do
        local index, phaser = next(data, pending.key)
        if index == nil then
            finishPartScanDiagnostic(scan, part, pending.diagnostic)
            scan.pendingPart = nil
            return true
        end
        pending.key = index
        scanCheckpoint(scan)
        pending.diagnostic.channels = pending.diagnostic.channels + 1
        if type(index) == "number" and type(phaser) == "table" then
            pending.diagnostic.numericChannels = pending.diagnostic.numericChannels + 1
            local ui = callable("GetUIChannel") and safe(GetUIChannel, index)
            local rt = ui and callable("GetRTChannel") and safe(GetRTChannel, ui.rt_index)
            if not ui then pending.diagnostic.uiMissing = pending.diagnostic.uiMissing + 1 end
            if ui and not rt then pending.diagnostic.rtMissing = pending.diagnostic.rtMissing + 1 end
            local fixture = rt and (rt.fixture or rt.subfixture)
            local sf = rt and (rt.subfixture or rt.fixture)
            local sfIndex = tonumber(property(sf, "SubfixtureIndex"))
            local attribute = callable("GetAttributeByUIChannel") and safe(GetAttributeByUIChannel, index)
            if not attribute then pending.diagnostic.attributeMissing = pending.diagnostic.attributeMissing + 1 end
            local layers = scan.tracked[index] or {}
            scan.tracked[index] = layers
            for _, layer in ipairs({{"abs", "absolute"}, {"rel", "relative"}}) do
                local touched, moving, refs = cueEffectLayer(phaser, layer[1], layer[2])
                if touched then
                    -- Cooked Phaser Recipe/Generator channels may expose only
                    -- underlying value links. Recover the applied Pool object
                    -- from an enabled row in this same Part and channel feature.
                    if moving then pending.diagnostic.movingLayers = pending.diagnostic.movingLayers + 1 end
                    local recoveredPoolRef = false
                    if moving and attribute then
                        local recovered, recoveredSeen = {}, {}
                        local featureMatched, membershipMatched = false, false
                        for _, recipe in ipairs(recipes) do
                            scanCheckpoint(scan)
                            local feature = normalizeFeature(label(attribute))
                            if recipe.featureMatches[feature] == nil then
                                recipe.featureMatches[feature] = valuesMatchFeature(recipe.ref, feature)
                            end
                            if recipe.featureMatches[feature] then
                                featureMatched = true
                                if sfIndex == nil or recipe.members[sfIndex] then
                                    membershipMatched = true
                                -- The matching StandardRecipe is the Pool object
                                -- the user called. Cooked Phaser data may expose
                                -- only its Shape or integrated step Presets.
                                local key = memoReferenceAddress(scan, recipe.ref)
                                if key and not recoveredSeen[key] then
                                    recoveredSeen[key], recovered[#recovered + 1] = true, recipe.ref
                                end
                                -- With a subfixture identity, the latest matching
                                -- Recipe row is the exact source for this channel.
                                if sfIndex ~= nil then break end
                                end
                            end
                        end
                        if featureMatched and not membershipMatched then
                            pending.diagnostic.recipeMembershipMiss = pending.diagnostic.recipeMembershipMiss + 1
                        elseif #recipes > 0 and not featureMatched then
                            pending.diagnostic.recipeFeatureMiss = pending.diagnostic.recipeFeatureMiss + 1
                        end
                        recoveredPoolRef = #recovered > 0
                        if recoveredPoolRef then
                            refs = recovered
                            pending.diagnostic.recoveredRefs = pending.diagnostic.recoveredRefs + #recovered
                        end
                    end
                    if moving and #refs == 0 then pending.diagnostic.emptyRefs = pending.diagnostic.emptyRefs + 1 end
                    if moving and not recoveredPoolRef then
                        for _, ref in ipairs(refs) do
                            if memoReferenceAddress(scan, ref) then
                                pending.diagnostic.directRefs = pending.diagnostic.directRefs + 1
                            else
                                pending.diagnostic.unresolvedRefs = pending.diagnostic.unresolvedRefs + 1
                            end
                        end
                    end
                    if moving then
                        for _, ref in ipairs(refs) do
                            if memoReferenceAddress(scan, ref) then
                                pending.diagnostic.firstRefAdvance = pending.diagnostic.firstRefAdvance or scan.advanceCalls
                                scan.diagnostics.firstRefAdvance = scan.diagnostics.firstRefAdvance or scan.advanceCalls
                                break
                            end
                        end
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
                local key = memoReferenceAddress(scan, ref)
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
    scan.advanceCalls = scan.advanceCalls + 1
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
                    local ref = recipeField(recipe, "Generator")
                    if not ref then ref = recipeField(recipe, "Values") end
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
    if not ENABLE_CUE_PHASER_MARKERS then
        logAbandonedScan(state.effectScanner)
        state.activeEffects, state.currentCueEffects, state.progressiveEffects = {}, {}, nil
        state.effectScanner, state.recipeScanPending = nil, false
        state.effectScanPending, state.effectWait = false, 0
        return
    end
    local sequence = callable("SelectedSequence") and safe(SelectedSequence)
    local cue = sequence and callable("GetCurrentCue") and safe(GetCurrentCue)
    local sequenceKey = commandAddress(sequence) or address(sequence)
    local cueKey = commandAddress(cue) or (sequenceKey .. ":" .. tostring(cueNumber(cue) or ""))
    local changed = state.effectSequenceKey ~= sequenceKey or state.effectCueKey ~= cueKey
    if changed then
        state.effectSequenceKey, state.effectCueKey = sequenceKey, cueKey
        state.effectSequence, state.effectCue = sequence, cue
        state.currentCueEffects = currentCueRecipeEffects(cue)
        state.progressiveEffects = nil
        if state.effectCacheSequence ~= sequenceKey then
            state.effectCacheSequence, state.effectCache, state.effectCacheOrder = sequenceKey, {}, {}
        end
        local cached = state.effectCache[cueKey]
        state.activeEffects = addCurrentCueRecipeEffects(cached and cached.result or {}, state.currentCueEffects)
        logAbandonedScan(state.effectScanner)
        state.effectScanner = nil
        state.recipeScanPending = cached == nil
        state.effectScanPending, state.effectWait = cached == nil, 1
        state.poolMarkersDirty = true
    end
    -- A selected Sequence can expose a valid Current Cue while its executor is
    -- stopped or being edited. Pool usage follows that Cue, not playback state.
    if state.poolBlink == false or not sequence or not cue then
        logAbandonedScan(state.effectScanner)
        state.activeEffects, state.currentCueEffects, state.effectScanner = {}, {}, nil
        state.recipeScanPending, state.progressiveEffects = false, nil
        state.effectScanPending, state.effectWait = false, 0
        return
    end
    if allowScan == false then return end
    -- Publish inherited Recipe references on their own host tick. Returning
    -- here guarantees the next UI pass can paint them before GetPresetData.
    if state.recipeScanPending then
        state.recipeScanPending = false
        local ok, progressive = pcall(trackedRecipeEffects, sequence, cue)
        if ok then
            state.progressiveEffects = progressive
            state.activeEffects = addCurrentCueRecipeEffects(progressive, state.currentCueEffects)
            state.poolMarkersDirty = true
            local count = 0
            for _ in pairs(progressive) do count = count + 1 end
            effectScanLog(string.format("progressive cue=%s refs=%d", cueLabel(cue), count))
        elseif callable("ErrEcho") then
            effectScanLog(string.format("progressive_abort cue=%s error=%s", cueLabel(cue), tostring(progressive)))
            safe(ErrEcho, "[RecipeTracking] " .. tostring(progressive))
        end
        return
    end
    state.effectWait = (state.effectWait or 0) - 1
    if state.effectScanPending and not state.effectScanner and state.effectWait <= 0 then
        state.effectScanner = newCueEffectScan(sequence, cue)
        for _ in pairs(state.currentCueEffects or {}) do state.effectScanner.diagnostics.fastRefs = state.effectScanner.diagnostics.fastRefs + 1 end
        effectScanLog(string.format("start cue=%s parts=%d fast_refs=%d", cueLabel(cue),
            #state.effectScanner.parts, state.effectScanner.diagnostics.fastRefs))
    end
    if state.effectScanner then
        -- One potentially expensive GetPresetData Part per host tick prevents
        -- large Showfiles from blocking selection and panel refresh for seconds.
        local ok, result = pcall(advanceCueEffectScan, state.effectScanner)
        if not ok or state.effectScanner.done then
            -- A completed cooked scan is authoritative. If it aborts, retain
            -- the progressive Recipe result instead of blanking useful markers.
            local resolved = ok and result or state.progressiveEffects or {}
            state.activeEffects = addCurrentCueRecipeEffects(resolved, state.currentCueEffects)
            local errorText = not ok and tostring(result) or nil
            if not ok then
                effectScanLog(string.format("abort cue=%s advances=%d elapsed_ms=%s error=%s", cueLabel(cue),
                    state.effectScanner.advanceCalls or 0,
                    formatElapsed(elapsedMs(state.effectScanner.diagnostics.startedClock)), errorText))
            else
                local diagnostic = state.effectScanner.diagnostics or {}
                effectScanLog(string.format("finish cue=%s advances=%d first_ref_advance=%s elapsed_ms=%s parts=%d refs=%d fast_refs=%d",
                    cueLabel(cue), state.effectScanner.advanceCalls or 0,
                    tostring(diagnostic.firstRefAdvance or "none"),
                    formatElapsed(elapsedMs(diagnostic.startedClock)), #(diagnostic.parts or {}),
                    (function() local n = 0 for _ in pairs(result or {}) do n = n + 1 end return n end)(),
                    diagnostic.fastRefs or 0))
            end
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
    if (state.provenEnabled==true and #(state.lastFixtures or {})==0)
        or (state.currentRecipe==nil and state.currentGroup==nil
            and #(state.currentGroups or {})==0 and #(state.matchingCandidates or {})==0) then
        clearPoolMarkers(state)
        state.markerReferences=nil
        state.poolMarkersDirty=false
        return
    end
    if state.provenEnabled==true and (#(state.lastFixtures or {})==0
        or not state.currentSequence or not state.currentCue) then
        clearPoolMarkers(state)
        state.currentGroups={}
        state.markerReferences={}
        return
    end
    -- Advance existing overlays before doing any new discovery or tile work.
    advancePoolPulse(state)
    local now=clockSeconds()
    local cachedGridInvalid=false
    if not state.poolMarkersDirty and not state.poolGridRefreshNeeded and now and now<(state.poolLookupDeadline or 0) then
        for _,grid in ipairs(state.poolGrids or {}) do
            if callable("IsObjectValid") and safe(IsObjectValid,grid)==false then
                cachedGridInvalid=true; break
            end
            local visible=safe(function() return grid:IsActuallyVisible() end)
            if visible~=nil then
                local normalized=string.lower(tostring(visible))
                if visible~=true and normalized~="yes" and normalized~="true" and normalized~="1" then
                    cachedGridInvalid=true; break
                end
            end
        end
        if not cachedGridInvalid then return end
        state.poolGridRefreshNeeded=true
    end
    if now then state.poolLookupDeadline=now+0.5 end
    local markerStarted=clockSeconds()
    state.poolMarkersDirty = false
    local references = state.markerReferences or recipePoolReferences(state)
    local markers, found = state.poolMarkers or {}, {}
    state.poolMarkers = markers
    local displayProbe={}
    if state.markerProbe and state.markerProbeReported~=state.markerProbeSerial then
        for refKey,probe in pairs(state.markerProbe) do
            local displayKey=refKey:gsub("%s*%[%#.-%]$","")
            displayProbe[displayKey]=probe
        end
    end
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
    local function actuallyVisible(object)
        if not valid(object) then return false end
        local status = safe(function() return object:IsActuallyVisible() end)
        if status == nil then return true end
        local normalized = string.lower(tostring(status))
        return status == true or normalized == "yes" or normalized == "true" or normalized == "1"
    end
    local discoveryStarted=clockSeconds()
    local grids, needsDiscovery = {}, state.poolGridRefreshNeeded == true
    state.poolGridRefreshNeeded = false
    for _, grid in ipairs(state.poolGrids or {}) do
        if actuallyVisible(grid) then grids[#grids + 1] = grid else needsDiscovery = true end
    end
    if #grids == 0 or needsDiscovery then
        -- Recall View can leave the previous Pool grids valid but hidden. Do
        -- one bounded rediscovery when a cached grid becomes actually hidden,
        -- invalid, or the selected Group/Recipe reference context changes.
        grids = {}
        local visited, budget = {}, 6000
        local function visit(node, depth)
            if not node or visited[node] or depth > 20 or budget <= 0 then return end
            visited[node], budget = true, budget - 1
            if node == state.window then return end
            if string.find(class(node), "PoolLayoutGrid", 1, true) then
                if actuallyVisible(node) then grids[#grids + 1] = node end
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
    state.lastPoolDiscoveryMs=elapsedMs(discoveryStarted)
    local tileStarted=clockSeconds()
    local function scanGrid(node)
        local pool = safe(function() return node.PoolObject end)
        local visited, budget={},2048
        local function visit(button,depth)
            if not button or visited[button] or budget<=0 or depth>5 then return end
            visited[button]=true; budget=budget-1
            local index = isPoolItemButton(button)
                and tonumber(property(button, "ObjectIndex")) or nil
            local object = index and safe(function() return pool:Ptr(index) end) or nil
            local key = commandAddress(object)
            local displayKey=key and key:gsub("%s*%[%#.-%]$","")
            local candidateProbe=displayKey and displayProbe[displayKey]
            if candidateProbe then
                candidateProbe.poolTileFound=true
                candidateProbe.poolTileVisible=actuallyVisible(node) and actuallyVisible(button)
            end
            local matched = key and references[key] or nil
            local identityMethod=matched and "ADDRESS" or nil
            if not matched and object then
                -- Generator Recipe links and Generator Pool targets can expose
                -- different command-address text (Random vs Generator) for the
                -- same native object. Fall back only after the O(1) key lookup.
                for _, reference in pairs(references) do
                    if sameReference(object, reference) then
                        matched = reference; identityMethod="HANDLE"; break
                    end
                end
            end
            if matched then
                local probe=state.markerProbe and state.markerProbe[commandAddress(matched)]
                if probe then
                    probe.poolTileFound=true
                    probe.poolTileVisible=actuallyVisible(node) and actuallyVisible(button)
                    probe.identityMatch=identityMethod~=nil
                    probe.matchMethod=identityMethod
                end
                found[button] = true
                local markerKind=string.lower(class(matched))=="group" and "group" or "recipe"
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
                            overlay.BackColor = poolPulseColor(markerKind,state.poolBlinkOn)
                            overlay.HasHover = "No"
                            overlay.Interactive = "No"
                        end)
                        if ok then
                            entry = { overlay = overlay,markerKind=markerKind }
                            markers[button] = entry
                        else
                            deleteHandle(overlay)
                        end
                    end
                end
                if entry then
                    entry.markerKind=markerKind
                    pcall(function()
                        entry.overlay.W = button.W
                        entry.overlay.H = button.H
                        entry.overlay.Visible = "Yes"
                        entry.overlay.BackColor = poolPulseColor(markerKind,state.poolBlinkOn)
                        entry.overlay.Text = ""
                    end)
                    if probe then probe.frameCreated=true end
                end
            end
            if not index then
                for _,child in ipairs(uiChildren(button)) do visit(child,depth+1) end
            end
        end
        for _,button in ipairs(uiChildren(node)) do visit(button,1) end
    end
    for _, grid in ipairs(grids) do scanGrid(grid) end
    for button, entry in pairs(markers) do
        if not found[button] then deleteHandle(entry.overlay); markers[button] = nil end
    end
    state.lastTileApplyMs=elapsedMs(tileStarted)
    if state.markerProbe and state.markerProbeReported~=state.markerProbeSerial then
        state.markerProbeReported=state.markerProbeSerial
        local keys={}
        for key in pairs(state.markerProbe) do keys[#keys+1]=key end
        table.sort(keys)
        local framed,firstMissing=0,nil
        for _,key in ipairs(keys) do
            local probe=state.markerProbe[key]
            if probe.frameCreated then framed=framed+1
            elseif not firstMissing then
                local stage=not probe.sourceAdmitted and "SOURCE_ADMITTED"
                    or not probe.poolTileFound and "POOL_TILE_FOUND"
                    or not probe.poolTileVisible and "POOL_TILE_VISIBLE"
                    or not probe.identityMatch and "IDENTITY_MATCH"
                    or "FRAME_CREATED"
                firstMissing=key:sub(1,48).." @ "..stage
            end
        end
        state.markerStatus=string.format("%d/%d frames",framed,#keys)
        if firstMissing then state.markerStatus=state.markerStatus.." | Missing "..firstMissing end
        for index=1,math.min(#keys,16) do
            local key=keys[index]; local probe=state.markerProbe[key]
            if callable("ErrEcho") then safe(ErrEcho,string.format(
                "[RecipeTracking][MarkerStage] ref=%s FINAL_REF=1 SOURCE_ADMITTED=%s POOL_TILE_FOUND=%s POOL_TILE_VISIBLE=%s IDENTITY_MATCH=%s FRAME_CREATED=%s method=%s",
                key,tostring(probe.sourceAdmitted),tostring(probe.poolTileFound),tostring(probe.poolTileVisible),
                tostring(probe.identityMatch),tostring(probe.frameCreated),
                tostring(probe.matchMethod or "-"))) end
        end
        if callable("ErrEcho") then safe(ErrEcho,string.format(
            "[RecipeTracking][ContextTiming] selection_ms=%s programmer_ms=%s tracking_scan_ms=%s tracking_sig_ms=%s render_ms=%s group_ms=%s resolver_slice_ms=%s resolver_total_ms=%s discovery_ms=%s tile_apply_ms=%s marker_ms=%s grids=%d refs=%d",
            formatElapsed(state.lastSelectionReadMs),formatElapsed(state.lastProgrammerMs),
            formatElapsed(state.lastTrackingScanMs),formatElapsed(state.lastTrackingFingerprintMs),
            formatElapsed(state.lastRenderMs),
            formatElapsed(state.lastGroupMatchMs),formatElapsed(state.lastResolverSliceMs),
            formatElapsed(state.lastResolverTotalMs),
            formatElapsed(state.lastPoolDiscoveryMs),formatElapsed(state.lastTileApplyMs),
            formatElapsed(elapsedMs(markerStarted)),#grids,#keys)) end
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
    -- The panel loop has already resolved the latest target. Rendering again
    -- here re-runs the full Recipe scan inside the button callback and can
    -- advance native resolver work synchronously while the user waits.
    local function selectionSnapshot(fixtures)
        local indices={}
        for _,fixture in ipairs(fixtures or {}) do
            if type(fixture.index)~="number" then return nil end
            indices[#indices+1]=tostring(fixture.index)
        end
        table.sort(indices)
        return table.concat(indices,",")
    end
    -- Selection indices are used here only to detect a stale button snapshot;
    -- all Group/member matching continues to use canonical dotted identities.
    if selectionSnapshot(readSelection())~=selectionSnapshot(state.lastFixtures)
        or not sameReference(callable("SelectedSequence") and safe(SelectedSequence) or nil,state.currentSequence)
        or not sameReference(callable("GetCurrentCue") and safe(GetCurrentCue) or nil,state.currentCue) then
        state.forceRefresh=true
        return
    end
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
            state.preserveResolverCaches = true
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
    if createRecipe and state.provenEnabled and #(state.currentGroups or {})>1 then
        notify("Recipe Update", "Multiple current Groups are active. Select one target Group before creating a Recipe.")
        return
    end
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

local function stopExistingForLaunch(existing)
    if type(existing) ~= "table" or not existing.running then return false end
    local sameVersion = tostring(existing.version or "") == PLUGIN_VERSION
    existing.running = false
    return sameVersion
end

local function main()
    local existing = _G[STATE_KEY]
    -- Running the same version remains an ON/OFF toggle. After importing an
    -- update, replace the older instance in this same invocation so the user
    -- is not left with the plugin silently stopped and no Pool frames.
    if stopExistingForLaunch(existing) then return end

    local state = { running = true, version = PLUGIN_VERSION,
        incrementalResolver = ENABLE_TRACK_A_SHOW_CANDIDATE == true }
    _G[STATE_KEY] = state
    local panel, err = createPanel(state)
    if not panel then
        _G[STATE_KEY] = nil
        if callable("ErrEcho") then ErrEcho("[RecipeTracking] " .. tostring(err)) end
        return
    end
    if callable("ErrEcho") then safe(ErrEcho, "[RecipeTracking] START v" .. PLUGIN_VERSION) end

    local previous, previousSourceHighlights, previousCurrentHighlights, previousPresetHighlights =
        nil, nil, nil, nil
    while state.running do
        syncTitleWidth(state)
        processPendingVerification(state)
        local forceRefresh = state.forceRefresh
        if forceRefresh then
            state.effectSequenceKey, state.effectCacheSequence = nil, nil
            state.provenSourceKey = nil
            state.resolverWorkKey=nil
            state.resolverTask=nil
            state.resolverWarmRefIndex=nil
            state.resolverWarmUIIndex=nil
            if not state.preserveResolverCaches then
                state.groupPoolReferenceKey = nil
                state.referenceMetadataCache = nil
                state.memberUICache = nil
                state.uiChannelCache = nil
                state.uiChannelCacheCount = 0
            end
            state.preserveResolverCaches=false
        end
        -- Apply due pulse transitions before a synchronous native resolver
        -- slice. The overlay can then repaint at this cycle's coroutine yield.
        advancePoolPulse(state)
        local renderStarted=clockSeconds()
        local ok, text, sourceHighlightText, currentHighlightText, presetHighlightText = pcall(render, state)
        state.lastRenderMs=elapsedMs(renderStarted)
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
        local markersOK = pcall(refreshPoolMarkers, state)
        if not markersOK then clearPoolMarkers(state) end
        if ENABLE_CUE_PHASER_MARKERS then
            -- This dormant path remains available for later development, but
            -- is not entered by the live-safe build.
            local effectsOK = pcall(refreshCueEffects, state, true)
            if not effectsOK then state.activeEffects, state.effectScanner = {}, nil end
        end
        local pendingResolver=state.provenSources
            and state.provenSources.classification=="PENDING"
        coroutine.yield(pendingResolver and PENDING_RESOLVER_REFRESH_SECONDS or REFRESH_SECONDS)
    end

    clearPoolMarkers(state)
    deleteHandle(state.window)
    if _G[STATE_KEY] == state then _G[STATE_KEY] = nil end
end

return main
