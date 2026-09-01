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
    local results, err = safeCall("GetProgPhaser", GetProgPhaser, uiChannelIndex)
    return results and results[1] or nil, err
end

local function printCapabilities()
    local names = {
        "Version", "SelectedSequence", "GetCurrentCue", "SelectionFirst",
        "SelectionNext", "GetSubfixture", "GetUIChannels", "Programmer",
        "ProgrammerPart", "SelectedFeature", "GetSelectedAttribute",
        "GetAttributeByUIChannel", "GetProgPhaser", "GetProgPhaserValue",
        "ObjectList", "DataPool"
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
        fixtures[#fixtures + 1] = { index = patchIndex, handle = fixture }
        log("Selection %d: patchIndex=%s fixture=%s class=%s address=%s",
            #fixtures, tostring(patchIndex), objectLabel(fixture), objectClass(fixture), objectAddress(fixture))

        local nextResults, nextErr = safeCall("SelectionNext", SelectionNext, patchIndex)
        if nextErr then
            warn("SelectionNext failed after patch index %s: %s", tostring(patchIndex), nextErr)
            break
        end
        patchIndex = nextResults and nextResults[1] or nil
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
    local activeLikeCount = 0
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
                log("Fixture %d UIChannel=%s Attribute=%s", fixtureNumber, tostring(uiIndex), attribute)

                if uiIndex ~= nil then
                    local phaser, phaserErr = Compat.getProgrammerPhaser(uiIndex)
                    if phaserErr then
                        uniqueFindings[phaserErr] = true
                    elseif phaser ~= nil then
                        log("GetProgPhaser result: fixture=%d attribute=%s uiChannel=%d", fixtureNumber, attribute, uiIndex)
                        printTable(phaser, "phaser")
                        local text = string.lower(tostring(phaser.active or phaser.is_active or phaser.integrated or ""))
                        if text ~= "" and text ~= "false" and text ~= "0" and text ~= "nil" then
                            activeLikeCount = activeLikeCount + 1
                        end
                    end
                end
            end
        end
    end

    for finding in pairs(uniqueFindings) do warn("%s", finding) end
    log("Active Feature: UNRESOLVED (active-like probes=%d)", activeLikeCount)
    log("Current Preset Reference: UNRESOLVED - inspect phaser keys on real console")
    log("Multiple-feature policy: NO-OP until preset-link semantics are verified")
end

local RECIPE_PROPERTY_PROBES = {
    "Selection", "Values", "Value", "MAtricks", "Filter", "World",
    "Enabled", "SelectionMode", "TrackingDistance", "FadeFrom", "FadeTo",
    "DelayFrom", "DelayTo"
}

local function inspectObject(object, depth, state)
    if object == nil or state.count >= MAX_OBJECTS then return end
    state.count = state.count + 1
    local indent = string.rep("  ", depth)
    log("%sObject %d: label=%s class=%s address=%s", indent, state.count,
        objectLabel(object), objectClass(object), objectAddress(object))

    for _, property in ipairs(RECIPE_PROPERTY_PROBES) do
        local value = objectText(object, property)
        if value ~= nil then log("%s  property[%s]=%s", indent, property, value) end
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
        if state.count >= MAX_OBJECTS then
            warn("Object traversal truncated at %d objects", MAX_OBJECTS)
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
        dumpNamedObject("PROGRAMMER PART", results and results[1] or nil)
    end
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
    readProgrammer(fixtures)
    dumpProgrammerObjects()

    log("=== GROUP RESOLUTION ===")
    log("Possible Group: UNRESOLVED - no confirmed non-mutating membership API")
    log("Command-history hint: DISABLED - no confirmed stable reader")

    log("=== RECIPE RESOLUTION ===")
    log("Candidate Recipe: UNRESOLVED - scoring intentionally disabled")
    log("Current Recipe Reference: UNRESOLVED - inspect Recipe Dumps")
    log("NO-OP: this diagnostic cannot and will not update the Showfile")
    log("Copy this complete output for 2.3.2.0 vs 2.4.x comparison")
    log("============================================================")
end

return main
