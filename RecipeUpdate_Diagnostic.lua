-- grandMA3 Recipe Update - Phase 1 read-only diagnostic
-- Minimum target: grandMA3 2.3.2.0
--
-- SAFETY CONTRACT:
-- This plugin never calls Cmd, Store, Assign, Set, Cook, Delete, Acquire,
-- CreateUndo, CloseUndo, or writes an object property. It only reads handles,
-- enumerates tables/children, and prints/Dumps diagnostic data.

local PLUGIN_TAG = "[RecipeUpdate][DIAG]"
local MAX_SELECTION = 256
local MAX_TABLE_DEPTH = 3
local MAX_TABLE_ITEMS = 80
local MAX_OBJECT_DEPTH = 3
local MAX_OBJECTS = 120

local Compat = {}

local function log(fmt, ...)
    local ok, message = pcall(string.format, fmt, ...)
    Printf("%s %s", PLUGIN_TAG, ok and message or tostring(fmt))
end

local function warn(fmt, ...)
    local ok, message = pcall(string.format, fmt, ...)
    local text = ok and message or tostring(fmt)
    if type(ErrPrintf) == "function" then
        ErrPrintf("%s %s", PLUGIN_TAG, text)
    else
        Printf("%s WARNING: %s", PLUGIN_TAG, text)
    end
end

local function callable(name)
    return type(_G[name]) == "function"
end

local function safeCall(label, fn, ...)
    if type(fn) ~= "function" then
        return nil, label .. " unavailable"
    end
    local results = { pcall(fn, ...) }
    if not results[1] then
        return nil, tostring(results[2])
    end
    table.remove(results, 1)
    return results, nil
end

local function objectText(object, property)
    if object == nil then return nil end

    local directOk, directValue = pcall(function() return object[property] end)
    if directOk and directValue ~= nil then return tostring(directValue) end

    local getOk, getValue = pcall(function() return object:Get(property) end)
    if getOk and getValue ~= nil then return tostring(getValue) end

    return nil
end

local function objectClass(object)
    if object == nil then return "nil" end
    local ok, value = pcall(function() return object:GetClass() end)
    if ok and value ~= nil then return tostring(value) end
    return objectText(object, "Class") or "unknown"
end

local function objectAddress(object)
    if object == nil then return "nil" end
    local methods = { "AddrNative", "Addr", "ToAddr" }
    for _, method in ipairs(methods) do
        local ok, value = pcall(function()
            local fn = object[method]
            if type(fn) == "function" then return fn(object) end
            return nil
        end)
        if ok and value ~= nil then return tostring(value) end
    end
    if callable("ToAddr") then
        local ok, value = pcall(ToAddr, object)
        if ok and value ~= nil then return tostring(value) end
    end
    return "address unavailable"
end

local function objectLabel(object)
    if object == nil then return "nil" end
    local name = objectText(object, "Name") or objectText(object, "name") or "unnamed"
    local no = objectText(object, "No") or objectText(object, "NO") or objectText(object, "Index")
    if no then return string.format("%s %s", no, name) end
    return name
end

local function sortedKeys(value)
    local keys = {}
    for key in pairs(value) do keys[#keys + 1] = key end
    table.sort(keys, function(a, b)
        if type(a) == type(b) then return tostring(a) < tostring(b) end
        return type(a) < type(b)
    end)
    return keys
end

local function printTable(value, prefix, depth, state)
    prefix = prefix or "value"
    depth = depth or 0
    state = state or { items = 0, seen = {} }

    if type(value) ~= "table" then
        log("%s = %s (%s)", prefix, tostring(value), type(value))
        return
    end
    if state.seen[value] then
        log("%s = <cycle>", prefix)
        return
    end
    if depth >= MAX_TABLE_DEPTH then
        log("%s = <table; depth limit>", prefix)
        return
    end

    state.seen[value] = true
    for _, key in ipairs(sortedKeys(value)) do
        state.items = state.items + 1
        if state.items > MAX_TABLE_ITEMS then
            log("%s = <table output truncated at %d items>", prefix, MAX_TABLE_ITEMS)
            break
        end
        local child = value[key]
        local path = string.format("%s[%s]", prefix, tostring(key))
        if type(child) == "table" then
            printTable(child, path, depth + 1, state)
        elseif type(child) == "userdata" then
            log("%s = %s (%s; %s)", path, objectLabel(child), objectClass(child), objectAddress(child))
        else
            log("%s = %s (%s)", path, tostring(child), type(child))
        end
    end
    state.seen[value] = nil
end

function Compat.getVersion()
    if not callable("Version") then return "UNAVAILABLE", nil end
    local results, err = safeCall("Version", Version)
    if not results then return "ERROR: " .. err, nil end
    return tostring(results[1] or "unknown"), results
end

function Compat.getSelectedSequence()
    if not callable("SelectedSequence") then return nil, "SelectedSequence unavailable" end
    local results, err = safeCall("SelectedSequence", SelectedSequence)
    return results and results[1] or nil, err
end

function Compat.getCurrentCue()
    if not callable("GetCurrentCue") then return nil, "GetCurrentCue unavailable" end
    local results, err = safeCall("GetCurrentCue", GetCurrentCue)
    return results and results[1] or nil, err
end

function Compat.getProgrammerPhaser(uiChannelIndex)
    if not callable("GetProgPhaser") then
        return nil, "GetProgPhaser unavailable (not in confirmed 2.3 API index)"
    end
    local results, err = safeCall("GetProgPhaser", GetProgPhaser, uiChannelIndex, false)
    if results then return results[1], nil end

    -- Compatibility fallback: the already-verified 2.3.2.0 installation also
    -- accepted a one-argument call, while the v2.2 HelpLua dump lists the
    -- phaser_only boolean explicitly.
    local fallbackResults, fallbackErr = safeCall("GetProgPhaser", GetProgPhaser, uiChannelIndex)
    return fallbackResults and fallbackResults[1] or nil,
        fallbackResults and nil or string.format("two-arg: %s; one-arg: %s", tostring(err), tostring(fallbackErr))
end

function Compat.getProgrammerPhaserValue(uiChannelIndex, step)
    if not callable("GetProgPhaserValue") then return nil, "GetProgPhaserValue unavailable" end
    local results, err = safeCall("GetProgPhaserValue", GetProgPhaserValue, uiChannelIndex, step)
    return results and results[1] or nil, err
end

function Compat.getPresetData(preset)
    if not callable("GetPresetData") then return nil, "GetPresetData unavailable" end
    local results, err = safeCall("GetPresetData", GetPresetData, preset, true, false)
    return results and results[1] or nil, err
end

local function printCapabilities()
    local names = {
        "Version", "SelectedSequence", "GetCurrentCue", "SelectionFirst",
        "SelectionNext", "GetSubfixture", "GetUIChannels", "Programmer",
        "ProgrammerPart", "SelectedFeature", "GetSelectedAttribute",
        "GetAttributeByUIChannel", "GetProgPhaser", "GetProgPhaserValue",
        "GetPresetData", "GetUIChannelIndex", "GetChannelFunction",
        "GetChannelFunctionIndex", "SetProgPhaser", "SetProgPhaserValue",
        "ObjectList", "DataPool", "MessageBox"
    }
    log("=== CAPABILITIES ===")
    for _, name in ipairs(names) do
        log("%-24s %s", name, callable(name) and "AVAILABLE" or "UNAVAILABLE")
    end
end

local function readSelection()
    log("=== CURRENT FIXTURES ===")
    if not callable("SelectionFirst") or not callable("SelectionNext") then
        warn("Selection enumeration UNAVAILABLE")
        return {}
    end

    local firstResults, firstErr = safeCall("SelectionFirst", SelectionFirst)
    local patchIndex = firstResults and firstResults[1] or nil
    local gridX = firstResults and firstResults[2] or nil
    local gridY = firstResults and firstResults[3] or nil
    local gridZ = firstResults and firstResults[4] or nil
    if firstErr then
        warn("SelectionFirst failed: %s", firstErr)
        return {}
    end
    if patchIndex == nil then
        warn("No fixtures selected")
        return {}
    end

    local fixtures = {}
    while patchIndex ~= nil and #fixtures < MAX_SELECTION do
        local fixture = nil
        if callable("GetSubfixture") then
            local fixtureResults = safeCall("GetSubfixture", GetSubfixture, patchIndex)
            fixture = fixtureResults and fixtureResults[1] or nil
        end
        fixtures[#fixtures + 1] = {
            index = patchIndex,
            handle = fixture,
            grid = { x = gridX, y = gridY, z = gridZ }
        }
        log("Selection %d: patchIndex=%s grid=%s/%s/%s fixture=%s class=%s address=%s",
            #fixtures, tostring(patchIndex), tostring(gridX), tostring(gridY), tostring(gridZ),
            objectLabel(fixture), objectClass(fixture), objectAddress(fixture))

        local nextResults, nextErr = safeCall("SelectionNext", SelectionNext, patchIndex)
        if nextErr then
            warn("SelectionNext failed after patch index %s: %s", tostring(patchIndex), nextErr)
            break
        end
        patchIndex = nextResults and nextResults[1] or nil
        gridX = nextResults and nextResults[2] or nil
        gridY = nextResults and nextResults[3] or nil
        gridZ = nextResults and nextResults[4] or nil
    end
    if #fixtures >= MAX_SELECTION then warn("Selection output truncated at %d fixtures", MAX_SELECTION) end
    log("Selected fixture count reported by traversal: %d", #fixtures)
    return fixtures
end

local function readProgrammer(fixtures)
    log("=== PROGRAMMER PRESET REFERENCE PROBES ===")
    if #fixtures == 0 then
        warn("Programmer probe skipped: no selection")
        return
    end
    if not callable("GetUIChannels") then
        warn("GetUIChannels UNAVAILABLE")
        return
    end

    local uniqueFindings = {}
    local presetByAddress = {}
    local attributeCounts = {}
    local phaserCount = 0
    local rawPhaserCount = 0
    local samplePrinted = false
    for fixtureNumber, fixtureInfo in ipairs(fixtures) do
        local input = fixtureInfo.handle or fixtureInfo.index
        local channelResults, channelErr = safeCall("GetUIChannels", GetUIChannels, input, true)
        local channels = channelResults and channelResults[1] or nil
        if channelErr or type(channels) ~= "table" then
            warn("Fixture %d UI channels unavailable: %s", fixtureNumber, channelErr or "non-table result")
        else
            for _, channel in pairs(channels) do
                local uiIndex = tonumber(objectText(channel, "INDEX") or objectText(channel, "Index"))
                if uiIndex then uiIndex = uiIndex - 1 end
                local attribute = objectText(channel, "SUBATTRIBUTE")
                    or objectText(channel, "SubAttribute")
                    or objectText(channel, "Name")
                    or "unknown"
                if uiIndex ~= nil then
                    local phaser, phaserErr = Compat.getProgrammerPhaser(uiIndex)
                    if phaserErr then
                        uniqueFindings[phaserErr] = true
                    elseif phaser ~= nil then
                        phaserCount = phaserCount + 1
                        attributeCounts[attribute] = (attributeCounts[attribute] or 0) + 1
                        local preset = phaser.abs_preset
                        if type(preset) == "userdata" then
                            local address = objectAddress(preset)
                            presetByAddress[address] = preset
                        else
                            rawPhaserCount = rawPhaserCount + 1
                        end

                        if not samplePrinted then
                            samplePrinted = true
                            log("Sample GetProgPhaser: fixture=%d attribute=%s uiChannel=%d", fixtureNumber, attribute, uiIndex)
                            printTable(phaser, "sample_phaser")

                            local stepValue, stepErr = Compat.getProgrammerPhaserValue(uiIndex, 1)
                            if stepValue then
                                log("Sample GetProgPhaserValue: uiChannel=%d step=1", uiIndex)
                                printTable(stepValue, "sample_step")
                            else
                                warn("GetProgPhaserValue sample unavailable: %s", tostring(stepErr))
                            end

                            local attributeIndex = nil
                            if callable("GetAttributeByUIChannel") then
                                local attrResults, attrErr = safeCall(
                                    "GetAttributeByUIChannel", GetAttributeByUIChannel, uiIndex)
                                local attrHandle = attrResults and attrResults[1] or nil
                                if attrHandle then
                                    log("Sample Attribute identity: %s | class=%s | address=%s",
                                        objectLabel(attrHandle), objectClass(attrHandle), objectAddress(attrHandle))
                                    local indexOk, indexValue = pcall(function() return attrHandle:Index() end)
                                    if indexOk and indexValue ~= nil then
                                        attributeIndex = tonumber(indexValue)
                                        log("Sample Attribute index: %s", tostring(indexValue))
                                        if attributeIndex and callable("GetUIChannelIndex") then
                                            local roundTripResults, roundTripErr = safeCall(
                                                "GetUIChannelIndex", GetUIChannelIndex,
                                                fixtureInfo.index, attributeIndex)
                                            if roundTripResults and roundTripResults[1] ~= nil then
                                                log("GetUIChannelIndex round trip: source=%d resolved=%s match=%s",
                                                    uiIndex, tostring(roundTripResults[1]),
                                                    tostring(tonumber(roundTripResults[1]) == uiIndex))
                                            else
                                                warn("GetUIChannelIndex round trip unresolved: %s",
                                                    tostring(roundTripErr))
                                            end
                                        end
                                    end
                                else
                                    warn("GetAttributeByUIChannel sample unavailable: %s", tostring(attrErr))
                                end
                            end

                            local channelFunction = type(phaser[1]) == "table"
                                and tonumber(phaser[1].channel_function) or nil
                            if channelFunction ~= nil then
                                log("Sample channel_function raw index: %d", channelFunction)
                            end
                            if attributeIndex ~= nil then
                                if callable("GetChannelFunction") then
                                    local cfResults, cfErr = safeCall(
                                        "GetChannelFunction", GetChannelFunction, uiIndex, attributeIndex)
                                    local cfHandle = cfResults and cfResults[1] or nil
                                    if cfHandle then
                                        log("GetChannelFunction probe: %s | class=%s | address=%s",
                                            objectLabel(cfHandle), objectClass(cfHandle), objectAddress(cfHandle))
                                    else
                                        warn("GetChannelFunction probe unresolved: %s", tostring(cfErr))
                                    end
                                end
                                if callable("GetChannelFunctionIndex") then
                                    local cfiResults, cfiErr = safeCall(
                                        "GetChannelFunctionIndex", GetChannelFunctionIndex,
                                        uiIndex, attributeIndex)
                                    if cfiResults and cfiResults[1] ~= nil then
                                        log("GetChannelFunctionIndex probe result: %s", tostring(cfiResults[1]))
                                    else
                                        warn("GetChannelFunctionIndex probe unresolved: %s", tostring(cfiErr))
                                    end
                                end
                                log("ChannelFunction probe semantics: API-dump-shaped but UNVERIFIED; no writer assumption allowed")
                            end
                        end
                    end
                end
            end
        end
    end

    for finding in pairs(uniqueFindings) do warn("%s", finding) end
    local attributes = {}
    for attribute, count in pairs(attributeCounts) do
        attributes[#attributes + 1] = string.format("%s(%d)", attribute, count)
    end
    table.sort(attributes)
    log("Programmer phaser channels: %d; attributes: %s", phaserCount,
        #attributes > 0 and table.concat(attributes, ", ") or "none")

    local presetAddresses = {}
    for address in pairs(presetByAddress) do presetAddresses[#presetAddresses + 1] = address end
    table.sort(presetAddresses)
    log("Unique absolute preset references: %d; phasers without abs_preset: %d",
        #presetAddresses, rawPhaserCount)

    if #presetAddresses == 1 and rawPhaserCount == 0 then
        local address = presetAddresses[1]
        local preset = presetByAddress[address]
        local feature = string.match(address, "PresetPools%.([^%.]+)%.") or "UNRESOLVED"
        log("Active Feature: %s", feature)
        log("Current Preset Reference: %s | class=%s | address=%s",
            objectLabel(preset), objectClass(preset), address)
        log("Preset resolution confidence: HIGH for this 2.3.2.0 observed shape")

        local presetData, presetDataErr = Compat.getPresetData(preset)
        if presetData then
            log("=== GET PRESET DATA SAMPLE (phasers_only=true, by_fixtures=false) ===")
            printTable(presetData, "preset_data")
        else
            warn("GetPresetData sample unavailable: %s", tostring(presetDataErr))
        end
        return { feature = feature, preset = preset, presetAddress = address }
    elseif #presetAddresses == 0 then
        warn("Current Preset Reference: UNRESOLVED - no abs_preset handle found")
    else
        warn("Current Preset Reference: AMBIGUOUS - %d preset references and %d raw phasers; NO-OP",
            #presetAddresses, rawPhaserCount)
        for _, address in ipairs(presetAddresses) do
            log("Preset candidate: %s | %s", objectLabel(presetByAddress[address]), address)
        end
    end
end

local RECIPE_PROPERTY_PROBES = {
    "Selection", "Values", "Value", "MAtricks", "Filter", "World",
    "Enabled", "SelectionMode", "TrackingDistance", "FadeFrom", "FadeTo",
    "DelayFrom", "DelayTo"
}

local function inspectObject(object, depth, state)
    local objectLimit = state.max or MAX_OBJECTS
    if object == nil or state.count >= objectLimit then return end
    state.count = state.count + 1
    local indent = string.rep("  ", depth)
    log("%sObject %d: label=%s class=%s address=%s", indent, state.count,
        objectLabel(object), objectClass(object), objectAddress(object))

    for _, property in ipairs(RECIPE_PROPERTY_PROBES) do
        local value = objectText(object, property)
        if value ~= nil then log("%s  property[%s]=%s", indent, property, value) end
        if property == "Selection" then
            local rawOk, rawValue = pcall(function() return object[property] end)
            if rawOk and type(rawValue) == "table" then
                log("%s  property[%s] raw table:", indent, property)
                printTable(rawValue, indent .. "selection", 0)
            end
        end
    end

    local classText = string.lower(objectClass(object))
    if string.find(classText, "recipe", 1, true) then
        log("%s  Candidate Recipe object found; score=DISABLED pending verified fields", indent)
        local ok, err = pcall(function() object:Dump() end)
        if not ok then warn("Recipe Dump failed: %s", tostring(err)) end
    end

    if depth >= MAX_OBJECT_DEPTH then return end
    local ok, children = pcall(function() return object:Children() end)
    if not ok or type(children) ~= "table" then return end
    for _, child in ipairs(children) do
        if state.count >= objectLimit then
            warn("Object traversal truncated at %d objects", objectLimit)
            return
        end
        inspectObject(child, depth + 1, state)
    end
end

local function dumpNamedObject(label, object)
    if object == nil then
        warn("%s unavailable", label)
        return
    end
    log("=== %s DUMP START ===", label)
    local ok, err = pcall(function() object:Dump() end)
    if not ok then warn("%s Dump failed: %s", label, tostring(err)) end
    log("=== %s DUMP END ===", label)
end

local function inspectContext(sequence, cue)
    log("=== PLAYBACK CONTEXT ===")
    if sequence then
        log("Current Sequence: %s | class=%s | address=%s", objectLabel(sequence), objectClass(sequence), objectAddress(sequence))
    else
        warn("Current Sequence: UNRESOLVED")
    end
    if cue then
        log("Current Cue: %s | class=%s | address=%s", objectLabel(cue), objectClass(cue), objectAddress(cue))
    else
        warn("Current Cue: UNRESOLVED")
    end
    log("Current Part: UNRESOLVED - inspect cue child classes/properties")
    log("Original Cue: UNRESOLVED - no confirmed provenance API")
    log("Original Part: UNRESOLVED - no confirmed provenance API")

    if cue then
        log("=== CURRENT CUE OBJECT TREE ===")
        inspectObject(cue, 0, { count = 0 })
    end
end

local function dumpProgrammerObjects()
    if callable("Programmer") then
        local results = safeCall("Programmer", Programmer)
        dumpNamedObject("PROGRAMMER", results and results[1] or nil)
    end
    if callable("ProgrammerPart") then
        local results = safeCall("ProgrammerPart", ProgrammerPart)
        local part = results and results[1] or nil
        dumpNamedObject("PROGRAMMER PART", part)
        if part then
            log("=== PROGRAMMER PART OBJECT TREE ===")
            inspectObject(part, 0, { count = 0 })
        end
    end
    return nil
end

local function inspectGroupPool(fixtures)
    if #fixtures == 0 then
        warn("Possible Group: UNRESOLVED - no current fixture selection")
        return
    end
    if not callable("DataPool") then
        warn("Group pool inspection unavailable: DataPool unavailable")
        return
    end
    local results, err = safeCall("DataPool", DataPool)
    local dataPool = results and results[1] or nil
    if not dataPool then
        warn("Group pool inspection unavailable: %s", err or "no DataPool handle")
        return
    end
    local ok, groups = pcall(function() return dataPool.Groups end)
    if not ok or groups == nil then
        warn("Group pool inspection unavailable: Groups handle unresolved")
        return
    end
    local childrenOk, groupObjects = pcall(function() return groups:Children() end)
    if not childrenOk or type(groupObjects) ~= "table" then
        warn("Possible Group: UNRESOLVED - Groups children unavailable")
        return
    end

    local selected = {}
    local selectedCount = 0
    for _, fixture in ipairs(fixtures) do
        local index = tonumber(fixture.index)
        if index ~= nil and not selected[index] then
            selected[index] = true
            selectedCount = selectedCount + 1
        end
    end

    local matches = {}
    local scanned = 0
    for _, group in ipairs(groupObjects) do
        if scanned >= 2048 then
            warn("Group matching truncated at 2048 Group objects")
            break
        end
        scanned = scanned + 1
        local selectionOk, selection = pcall(function() return group.Selection end)
        if selectionOk and type(selection) == "table" then
            local members = {}
            local memberGrid = {}
            local memberCount = 0
            for _, item in pairs(selection) do
                local index = type(item) == "table" and tonumber(item.sf_index) or nil
                if index ~= nil and not members[index] then
                    members[index] = true
                    memberCount = memberCount + 1
                    local grid = item.grid
                    if type(grid) == "table" then
                        memberGrid[index] = {
                            x = tonumber(grid.x), y = tonumber(grid.y), z = tonumber(grid.z)
                        }
                    end
                end
            end
            if memberCount == selectedCount then
                local exact = true
                for index in pairs(selected) do
                    if not members[index] then
                        exact = false
                        break
                    end
                end
                if exact then matches[#matches + 1] = { handle = group, grid = memberGrid } end
            end
        end
    end

    log("Group exact-set scan: selected=%d groups_scanned=%d exact_matches=%d",
        selectedCount, scanned, #matches)
    if #matches == 0 then
        warn("Possible Group: UNRESOLVED - no exact sf_index set match")
        return
    end

    local function normalizedGrid(gridByIndex)
        local minX, minY, minZ = nil, nil, nil
        for index in pairs(selected) do
            local grid = gridByIndex[index]
            if not grid or grid.x == nil or grid.y == nil or grid.z == nil then return nil end
            minX = minX == nil and grid.x or math.min(minX, grid.x)
            minY = minY == nil and grid.y or math.min(minY, grid.y)
            minZ = minZ == nil and grid.z or math.min(minZ, grid.z)
        end
        local normalized = {}
        for index in pairs(selected) do
            local grid = gridByIndex[index]
            normalized[index] = string.format("%s/%s/%s", grid.x - minX, grid.y - minY, grid.z - minZ)
        end
        return normalized
    end

    local currentGrid = {}
    for _, fixture in ipairs(fixtures) do currentGrid[tonumber(fixture.index)] = fixture.grid end
    local normalizedCurrent = normalizedGrid(currentGrid)
    local gridMatches = {}
    if normalizedCurrent then
        for _, candidate in ipairs(matches) do
            local normalizedCandidate = normalizedGrid(candidate.grid)
            local equal = normalizedCandidate ~= nil
            if equal then
                for index in pairs(selected) do
                    if normalizedCandidate[index] ~= normalizedCurrent[index] then equal = false break end
                end
            end
            if equal then gridMatches[#gridMatches + 1] = candidate end
        end
    end

    log("Group grid-fingerprint scan: set_candidates=%d grid_matches=%d", #matches, #gridMatches)
    if #gridMatches == 1 then
        local group = gridMatches[1].handle
        log("Possible Group: %s | class=%s | address=%s | confidence=HIGH exact sf_index+normalized-grid match",
            objectLabel(group), objectClass(group), objectAddress(group))
    else
        local candidates = #gridMatches > 1 and gridMatches or matches
        local reason = normalizedCurrent and "grid fingerprint not unique" or "current grid coordinates unavailable"
        warn("Possible Group: AMBIGUOUS - %d candidates; %s", #candidates, reason)
        for _, candidate in ipairs(candidates) do
            local group = candidate.handle
            log("Group candidate: %s | %s", objectLabel(group), objectAddress(group))
        end
    end
end

local function selectionSetMatches(group, fixtures)
    if group == nil or #fixtures == 0 then return false end
    local ok, selection = pcall(function() return group.Selection end)
    if not ok or type(selection) ~= "table" then return false end
    local selected, members = {}, {}
    local selectedCount, memberCount = 0, 0
    for _, fixture in ipairs(fixtures) do
        local index = tonumber(fixture.index)
        if index ~= nil and not selected[index] then selected[index] = true selectedCount = selectedCount + 1 end
    end
    for _, item in pairs(selection) do
        local index = type(item) == "table" and tonumber(item.sf_index) or nil
        if index ~= nil and not members[index] then members[index] = true memberCount = memberCount + 1 end
    end
    if selectedCount ~= memberCount then return false end
    for index in pairs(selected) do if not members[index] then return false end end
    return true
end

local function scanRecipeProvenance(sequence, currentCue, fixtures, programmerInfo)
    log("=== TRACKING PROVENANCE CANDIDATE SCAN ===")
    if not sequence or #fixtures == 0 or not programmerInfo or not programmerInfo.feature then
        warn("Tracking provenance candidates: UNRESOLVED - missing sequence, selection, or Programmer feature")
        return {}
    end
    local childrenOk, cueObjects = pcall(function() return sequence:Children() end)
    if not childrenOk or type(cueObjects) ~= "table" then
        warn("Tracking provenance candidates: UNRESOLVED - Sequence children unavailable")
        return {}
    end

    local candidates, cuesScanned, recipesScanned = {}, 0, 0
    local featureLower = string.lower(programmerInfo.feature)
    for _, cue in ipairs(cueObjects) do
        if cuesScanned >= 512 or recipesScanned >= 2048 then break end
        if string.lower(objectClass(cue)) == "cue" then
            cuesScanned = cuesScanned + 1
            local partsOk, parts = pcall(function() return cue:Children() end)
            if partsOk and type(parts) == "table" then
                for _, part in ipairs(parts) do
                    if string.lower(objectClass(part)) == "part" then
                        local recipesOk, recipes = pcall(function() return part:Children() end)
                        if recipesOk and type(recipes) == "table" then
                            for _, recipe in ipairs(recipes) do
                                if recipesScanned >= 2048 then break end
                                if string.find(string.lower(objectClass(recipe)), "recipe", 1, true) then
                                    recipesScanned = recipesScanned + 1
                                    local selectionOk, selectionGroup = pcall(function() return recipe.Selection end)
                                    local valuesOk, values = pcall(function() return recipe.Values end)
                                    local valuesText = valuesOk and tostring(values) or ""
                                    local valuesAddress = valuesOk and objectAddress(values) or ""
                                    local featureMatches = string.find(string.lower(valuesText), featureLower, 1, true)
                                        or string.find(string.lower(valuesAddress), featureLower, 1, true)
                                    if selectionOk and selectionSetMatches(selectionGroup, fixtures) and featureMatches then
                                        candidates[#candidates + 1] = {
                                            cue = cue, part = part, recipe = recipe, group = selectionGroup,
                                            values = values, current = cue == currentCue
                                        }
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end
    end

    log("Tracking candidate scan: cues=%d recipes=%d matches=%d", cuesScanned, recipesScanned, #candidates)
    for index, candidate in ipairs(candidates) do
        log("Tracking candidate %d: Cue=%s | Part=%s | Recipe=%s | Group=%s | Values=%s | currentCue=%s",
            index, objectLabel(candidate.cue), objectLabel(candidate.part), objectLabel(candidate.recipe),
            objectLabel(candidate.group), tostring(candidate.values), tostring(candidate.current))
        log("Tracking candidate %d addresses: cue=%s | part=%s | recipe=%s | group=%s | values=%s",
            index, objectAddress(candidate.cue), objectAddress(candidate.part), objectAddress(candidate.recipe),
            objectAddress(candidate.group), objectAddress(candidate.values))
    end
    if #candidates == 1 then
        log("Tracking provenance: INFERRED HIGH - one Recipe matches exact fixture set and feature; console-native source proof still unavailable")
    elseif #candidates == 0 then
        warn("Tracking provenance: UNRESOLVED - no Recipe matches exact fixture set and feature")
    else
        warn("Tracking provenance: AMBIGUOUS - %d Recipe candidates match", #candidates)
    end
    return candidates
end

local function showTrackingSummary(currentCue, programmerInfo, candidates)
    if not callable("MessageBox") then
        warn("Tracking summary popup unavailable: MessageBox unavailable")
        return
    end
    local message
    if #candidates == 1 then
        local candidate = candidates[1]
        message = string.format(
            "Current: %s\n\nSource: %s / %s / %s\nGroup: %s\nOld Values: %s\nNew Preset: %s\n\nConfidence: INFERRED HIGH\nREAD-ONLY - no update performed",
            objectLabel(currentCue), objectLabel(candidate.cue), objectLabel(candidate.part),
            objectLabel(candidate.recipe), objectLabel(candidate.group), tostring(candidate.values),
            objectLabel(programmerInfo.preset))
    elseif #candidates == 0 then
        message = "No matching tracking Recipe was found.\n\nREAD-ONLY - no update performed"
    else
        local lines = { string.format("%d tracking Recipe candidates found:", #candidates) }
        for index, candidate in ipairs(candidates) do
            if index > 8 then lines[#lines + 1] = "...additional candidates omitted" break end
            lines[#lines + 1] = string.format("%d. %s / %s / %s / %s", index,
                objectLabel(candidate.cue), objectLabel(candidate.part), objectLabel(candidate.recipe),
                objectLabel(candidate.group))
        end
        lines[#lines + 1] = "\nAMBIGUOUS - no update performed"
        message = table.concat(lines, "\n")
    end
    local ok, err = pcall(MessageBox, {
        title = "Recipe Tracking Source",
        message = message,
        commands = { { value = 1, name = "OK" } },
        backColor = "Window.Plugins"
    })
    if not ok then warn("Tracking summary popup failed: %s", tostring(err)) end
end

local function inspectProgrammerMode()
    if not callable("ProgrammerPart") then
        warn("Programmer mode: UNRESOLVED - ProgrammerPart unavailable")
        return "unresolved"
    end
    local results, err = safeCall("ProgrammerPart", ProgrammerPart)
    local part = results and results[1] or nil
    if not part then
        warn("Programmer mode: UNRESOLVED - %s", err or "no ProgrammerPart handle")
        return "unresolved"
    end
    local ok, children = pcall(function() return part:Children() end)
    if not ok or type(children) ~= "table" then
        warn("Programmer mode: UNRESOLVED - ProgPart Children failed")
        return "unresolved"
    end
    local recipeCount = 0
    for _, child in ipairs(children) do
        if string.find(string.lower(objectClass(child)), "recipe", 1, true) then
            recipeCount = recipeCount + 1
        end
    end
    if recipeCount > 0 then
        log("Programmer mode: EDIT RECIPE (%d direct Recipe candidates); supported workflow, inspect exact target",
            recipeCount)
        return "edit_recipe"
    end
    log("Programmer mode: NORMAL (ProgPart Recipe children=0); supported workflow, resolve tracked target")
    return "normal"
end

local function main()
    log("============================================================")
    log("grandMA3 Recipe Update - Phase 1 READ-ONLY diagnostic")
    log("No Showfile write commands or property assignments are present")

    local version, versionParts = Compat.getVersion()
    log("MA3 Version: %s", version)
    if versionParts then
        for index = 2, #versionParts do
            log("Version numeric return %d: %s", index - 1, tostring(versionParts[index]))
        end
    end

    printCapabilities()

    local sequence, sequenceErr = Compat.getSelectedSequence()
    if sequenceErr then warn("SelectedSequence: %s", sequenceErr) end
    local cue, cueErr = Compat.getCurrentCue()
    if cueErr then warn("GetCurrentCue: %s", cueErr) end
    inspectContext(sequence, cue)

    local fixtures = readSelection()
    local programmerMode = inspectProgrammerMode()
    local programmerInfo = readProgrammer(fixtures)
    dumpProgrammerObjects()

    log("=== GROUP RESOLUTION ===")
    inspectGroupPool(fixtures)
    log("Command-history hint: DISABLED - no confirmed stable reader")

    local trackingCandidates = nil
    if programmerMode == "normal" then
        trackingCandidates = scanRecipeProvenance(sequence, cue, fixtures, programmerInfo)
        showTrackingSummary(cue, programmerInfo or {}, trackingCandidates or {})
    end

    log("=== RECIPE RESOLUTION ===")
    if programmerMode == "edit_recipe" then
        log("Candidate Recipe: DIRECT ProgrammerPart Recipe candidates available - inspect object tree; no write in diagnostic")
    elseif trackingCandidates and #trackingCandidates == 1 then
        log("Candidate Recipe: INFERRED HIGH - %s", objectAddress(trackingCandidates[1].recipe))
        log("Current Recipe Reference: %s", tostring(trackingCandidates[1].values))
    else
        log("Candidate Recipe: UNRESOLVED - tracked-target scoring intentionally disabled")
    end
    if not (trackingCandidates and #trackingCandidates == 1) then
        log("Current Recipe Reference: UNRESOLVED - inspect Recipe Dumps")
    end
    log("NO-OP: this diagnostic cannot and will not update the Showfile")
    log("Copy this complete output for 2.3.2.0 vs 2.4.x comparison")
    log("============================================================")
end

return main
