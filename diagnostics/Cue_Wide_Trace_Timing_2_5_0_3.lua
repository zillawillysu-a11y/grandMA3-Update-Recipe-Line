-- Generated independent read-only replay; production file is never executed.
-- Source version 0.7.0.17, normalized-source SHA256 a6e15338449ef365fa152ef6400fe849d084f20a32d363b5bc8d6159314230b6.
return function()
local commandAddress, children, recipeNumber, generatorHasFeature
local GetPresetData, SelectedSequence, GetCurrentCue
local tracePartOrder, tracePartBegin, traceRecord, traceRawLayer, traceLayer
local traceMediumLane, traceMediumRow, traceDirect, traceProductionLog, traceRecoveryCandidate
-- Private diagnostic gate only. The production flag remains FALSE.
local ENABLE_CUE_PHASER_MARKERS = true
local MAX_CUES, MAX_RECIPES, REFRESH_SECONDS = 512, 2048, 0.1
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

local function cueNumber(cue)
    return cue and tonumber(property(cue, "No") or property(cue, "NO")) or nil
end

local function partNumber(part)
    return tonumber(property(part, "Part") or property(part, "PART")) or 0
end

recipeNumber = function(recipe, fallback)
    local value = tonumber(property(recipe, "Index") or property(recipe, "INDEX")
        or property(recipe, "No") or property(recipe, "NO"))
    return value or fallback
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
                traceMediumLane(row, reference, feature, laneKey, decided[laneKey], activeReference)
                if not decided[laneKey] then
                    decided[laneKey] = true
                    if activeReference then publish = true end
                end
            end
            traceMediumRow(row, reference, features, publish, groupKey)
            if publish then
                local key = commandAddress(reference)
                if key then result[key] = {object = reference, fixtures = {}, count = 0, progressive = true} end
            end
        end
    end
    return result
end

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
    if type(os) == "table" and type(os.clock) == "function" then
        local ok, value = pcall(os.clock)
        if ok then return value end
    end
    return nil
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
        for _, part in ipairs(parts) do scan.parts[#scan.parts + 1] = part; tracePartOrder(scan, cue, part) end
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
    traceProductionLog(message)
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
    tracePartBegin(scan, part)
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
                    ref = ref, members = selection, featureMatches = {}, index = recipeNumber(recipe, ordinal), probeRecipe = recipe
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
        traceRecord(scan, part, index, phaser)
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
                traceRawLayer(scan, part, index, layer[1], touched, moving, refs)
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
                            traceRecoveryCandidate(scan, part, index, feature, recipe, sfIndex)
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
                    traceLayer(scan, part, index, layer[1], moving, refs, recoveredPoolRef, layers[layer[1]])
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
                        traceDirect(part, recipe, ref, key)
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

-- Core template; appended after instrumented production functions by builder.
local rawAPI={data=_G.GetPresetData,sequence=_G.SelectedSequence,cue=_G.GetCurrentCue,time=_G.Time}
local build=safe(BuildDetails)
assert(type(build)=='table' and build.BigVersion=='2.5.0.3','Requires grandMA3 2.5.0.3')
assert(type(rawAPI.data)=='function' and type(rawAPI.sequence)=='function' and type(rawAPI.cue)=='function','Read-only Cue APIs required')
local sequence,currentCue=safe(rawAPI.sequence),safe(rawAPI.cue)
assert(sequence and currentCue and cueNumber(currentCue),'Select a Sequence with a readable Current Cue')
SelectedSequence=function() return sequence end
GetCurrentCue=function() return currentCue end
local clockMode=type(rawAPI.time)=='function' and 'MA_Time_SECONDS_WALL' or 'UNAVAILABLE'
local function now() local v=safe(rawAPI.time); return type(v)=='number' and v or nil end
local function delta(a,b) if a and b and b>=a then return (b-a)*1000 end end
local function text(v) return v==nil and 'UNAVAILABLE' or tostring(v):gsub('[\r\n]',' '):sub(1,190) end
local outputLines,outputLimited=0,false
local function log(f,...) if outputLines>=12000 then outputLimited=true; return end; outputLines=outputLines+1; Printf('[CueWideTrace] '..f,...) end
local function method(h,k,...) return safe(function(...) return h[k](h,...) end,...) end
local function token(h) return h and safe(HandleToStr,h) or nil end
local function describe(h)
 if not isObjectReference(h) then return 'raw='..text(h)..' type='..type(h) end
 return 'class='..text(class(h))..' address='..text(commandAddress(h))..' native='..text(method(h,'AddrNative'))..' DB_handle='..text(token(h))
end
local function refType(h)
 if isRandomGenerator(h) then return 'Generator' end
 if isPhaserRecipePreset(h) then return 'Phaser' end
 return class(h):lower()=='preset' and 'Preset' or class(h)
end
local function bool(v) local n=tostring(v):lower(); if v==true or n=='yes' or n=='true' or n=='1' then return true end; if v==false or n=='no' or n=='false' or n=='0' then return false end end
local pass; local allPasses={}; local seenRequests={}
local function event(ref,part,stage,layer,reason,recipe,channel)
 if ref==nil then return end
 local entry=pass.refs[ref]
 if not entry then
  if pass.refCount>=1024 then pass.traceLimited=true; return end
  pass.refCount=pass.refCount+1; entry={id=pass.refCount,ref=ref,events={},count=0}; pass.refs[ref]=entry
 end
 local perPart=entry.events[part or false]; if not perPart then perPart={}; entry.events[part or false]=perPart end
 local key=stage..'|'..layer..'|'..reason
 local e=perPart[key]
 if not e then
  if pass.eventCount>=8192 then pass.traceLimited=true; return end
  pass.eventCount=pass.eventCount+1; e={part=part,stage=stage,layer=layer,reason=reason,count=0,recipe=recipe,channel=channel}; perPart[key]=e
 end
 e.count=e.count+1; entry.count=entry.count+1
end
local function hook(fn)
 return function(...)
  local a=now(); fn(...); local ms=delta(a,now())
  if ms then pass.overhead=pass.overhead+ms else pass.timingInvalid=true end
 end
end
tracePartOrder=hook(function(scan,cue,part)
 pass.owners[part]=cue; pass.order[#pass.order+1]={cue=cue,part=part}
end)
tracePartBegin=hook(function(scan,part) pass.part=part; pass.scan=scan end)
traceRecord=hook(function(scan,part,index,phaser)
 local advance=pass.currentAdvance
 if advance then advance.keys[#advance.keys+1]=index; advance.records=advance.records+1 end
 pass.currentPhaser=phaser
end)
traceRawLayer=hook(function(scan,part,index,prefix,touched,moving,refs)
 pass.previous[prefix]=(scan.tracked[index] or {})[prefix]
 local included={}; for _,ref in ipairs(refs) do included[ref]=true; event(ref,part,'COOKED_RAW',prefix,moving and 'MOVING_LAYER_CANDIDATE' or 'STATIC_RELEASED_OR_UNTOUCHED_LAYER',nil,index) end
 local phaser=pass.currentPhaser
 if type(phaser)=='table' then
  local function inspect(container,key,path)
   local value=container[key]; local addressLike=type(value)=='string' and (value:lower():match('^preset%s+%d') or value:lower():match('^generator%s+%d'))
   if (isObjectReference(value) or addressLike) and not included[value] then
    event(value,part,'RAW_LINK_IGNORED',prefix,'cueEffectLayer_did_not_accept_'..path,nil,index)
    if moving and #refs==0 and addressLike then pass.ignoredLinks[value]=true end
   end
  end
  for _,key in ipairs({prefix..'_preset',prefix..'_generator'}) do inspect(phaser,key,'top.'..key) end
  if prefix=='abs' then for _,key in ipairs({'generator','integrated','value'}) do inspect(phaser,key,'top.'..key) end end
  local steps=0
  for key,step in pairs(phaser) do if type(key)=='number' and type(step)=='table' then
   steps=steps+1; if steps>64 then pass.traceLimited=true; break end
   inspect(step,prefix..'_preset','step.'..prefix..'_preset')
   if prefix=='abs' then for _,field in ipairs({'integrated','generator','value'}) do inspect(step,field,'step.'..field) end end
  end end
 end
end)
traceLayer=hook(function(scan,part,index,prefix,moving,refs,recovered,item)
 local previous=pass.previous[prefix]
 if previous then for _,ref in ipairs(previous.refs) do event(ref,previous.probePart,'TRACKING',prefix,'SUPERSEDED_BY_LATER_TOUCHED_LAYER',previous.probeRecipe,index) end end
 if item then item.probePart=part; item.probeIndex=index; item.probeLayer=prefix; item.probeRecovered=recovered end
 for _,ref in ipairs(refs) do
  local recipe
  if recovered then for _,row in ipairs((scan.pendingPart or {}).recipes or {}) do if row.ref==ref then recipe=row.probeRecipe; break end end end
  if item and recipe then item.probeRecipe=recipe end
  event(ref,part,recovered and 'RECIPE_RECOVERY' or 'COOKED_LAYER',prefix,moving and 'ACCEPTED_IN_LAYER_PENDING_TRACKING' or 'REJECTED_NOT_MOVING_OR_RELEASED',recipe,index)
 end
end)
traceRecoveryCandidate=hook(function(scan,part,index,feature,recipe,sfIndex)
 local reason=not recipe.featureMatches[feature] and 'REJECTED_FEATURE_MISMATCH' or (sfIndex~=nil and not recipe.members[sfIndex] and 'REJECTED_FIXTURE_MEMBERSHIP' or 'RECOVERY_ELIGIBLE')
 event(recipe.ref,part,'RECIPE_RECOVERY_CANDIDATE',feature,reason,recipe.probeRecipe,index)
end)
traceMediumLane=hook(function(row,ref,feature,key,decided,active)
 event(ref,row.part,'PROGRESSIVE_GROUP_FEATURE_LANE',feature,decided and 'REJECTED_ALREADY_DECIDED' or (active and 'PROVISIONAL_LANE_WIN' or 'STATIC_LANE_TERMINATOR'),row.recipe)
 pass.owners[row.part]=row.cue
end)
traceMediumRow=hook(function(row,ref,features,publish,groupKey)
 event(ref,row.part,'PROGRESSIVE',table.concat(features,','),publish and 'PROVISIONAL_PUBLISH' or 'REJECTED_NO_NEW_MOVING_LANE',row.recipe)
 if publish then pass.publications[ref]=pass.publications[ref] or {tick=pass.tick,stage='PROGRESSIVE'} end
end)
traceDirect=hook(function(part,recipe,ref,key)
 pass.owners[part]=currentCue
 event(ref,part,'CURRENT_CUE_RECIPE','direct',key and 'DIRECT_RECIPE_PUBLISH' or 'REJECTED_NO_COMMAND_ADDRESS',recipe)
 if key then pass.publications[ref]=pass.publications[ref] or {tick=pass.tick,stage='DIRECT_CURRENT_RECIPE'} end
end)
traceProductionLog=hook(function(message) pass.productionLogs[#pass.productionLogs+1]=message end)
-- Wrap source reader locally, never a native/global function.
local originalRecipeField=recipeField
recipeField=function(recipe,name)
 local o,rawValue=originalRecipeField(recipe,name)
 local extraStart=now()
 if pass and (name=='Values' or name=='Generator') and o then
  pass.rawFields[recipe]=pass.rawFields[recipe] or {}; pass.rawFields[recipe][name]=rawValue
 end
 if pass and (name=='Values' or name=='Generator') and not o then
  local v=tostring(rawValue or ''):lower()
  if v:match('^preset%s+%d') or v:match('^generator%s+%d') or v:find('showdata.',1,true) then
   pass.unresolved[recipe]=pass.unresolved[recipe] or {}; pass.unresolved[recipe][name]=rawValue
  end
 end
 local extra=delta(extraStart,now()); if pass and extra then pass.overhead=pass.overhead+extra elseif pass then pass.timingInvalid=true end
 return o,rawValue
end
GetPresetData=function(target,phasers,fixtures)
 local wrapperStart=now()
 local byArgs=seenRequests[target]; if not byArgs then byArgs={}; seenRequests[target]=byArgs end
 local signature=tostring(phasers)..':'..tostring(fixtures); local first=not byArgs[signature]; byArgs[signature]=true
 local start=now(); local ok,data=pcall(rawAPI.data,target,phasers,fixtures); local finish=now(); local ms=delta(start,finish)
 if ms then pass.nativeMs=pass.nativeMs+ms else pass.timingInvalid=true end
 local e={target=target,part=pass.part,kind=phasers==false and 'PART_COOKED' or 'FEATURE_REFERENCE',first=first,ms=ms,ok=ok,error=not ok and data or nil,returnType=type(data),cumulative=pass.nativeMs,cumulativeReplay=delta(pass.startedWall,finish)}
 pass.reads[#pass.reads+1]=e
 if e.kind=='PART_COOKED' then pass.partReads[target]=e
 elseif ok and type(data)=='table' then
  -- Supplementary feature reads may short-circuit. Count their returned table
  -- separately, track/exclude this diagnostic overhead, never reread natively.
  local a=now(); local n=0
  for _ in pairs(data) do n=n+1; if n>131072 then break end end
  if n<=131072 then e.count=n else e.countLimited=true end
  local overhead=delta(a,now()); if not overhead then pass.timingInvalid=true end
 end
 local wrapperElapsed=delta(wrapperStart,now()); if wrapperElapsed and ms then pass.overhead=pass.overhead+math.max(0,wrapperElapsed-ms) else pass.timingInvalid=true end
 if not ok then error(data,0) end
 return data
end
local originalAdvance=advanceCueEffectScan
advanceCueEffectScan=function(scan)
 if scan.done then return originalAdvance(scan) end
 local a={number=scan.advanceCalls+1,records=0,keys={},part=scan.parts[scan.index],tick=pass.tick}
 pass.advances[#pass.advances+1]=a; pass.currentAdvance=a; local start=now()
 local nativeBefore,overheadBefore=pass.nativeMs,pass.overhead
 local ok,result=pcall(originalAdvance,scan); a.ms=delta(start,now()); pass.currentAdvance=nil
 a.nativeMs=pass.nativeMs-nativeBefore; a.overhead=pass.overhead-overheadBefore
 a.processingMs=a.ms and math.max(0,a.ms-a.nativeMs-a.overhead) or nil
 if not ok then error(result,0) end
 return result
end
local function count(t) local n=0; for _ in pairs(t or {}) do n=n+1 end; return n end
local function run(label)
 pass={label=label,refs={},refCount=0,eventCount=0,owners={},order={},previous={},reads={},partReads={},advances={},productionLogs={},publications={},rawFields={},unresolved={},ignoredLinks={},nativeMs=0,overhead=0,coreMs=0,tick=0,timingInvalid=false}
 allPasses[#allPasses+1]=pass
 local state={poolBlink=true,running=true}; pass.state=state
 local start=now(); pass.startedWall=start
 for tick=0,8191 do
  pass.tick=tick; local a=now(); local ok,err=pcall(refreshCueEffects,state,true); local elapsed=delta(a,now())
  if elapsed then pass.coreMs=pass.coreMs+elapsed else pass.timingInvalid=true end
  if pass.advances[#pass.advances] then pass.advances[#pass.advances].cumulativeEstimate=pass.coreMs-pass.overhead+tick*REFRESH_SECONDS*1000 end
  if not ok then pass.error=tostring(err); break end
  if not state.recipeScanPending and not state.effectScanPending and not state.effectScanner then break end
  if tick==8191 then pass.traceLimited=true; pass.error='DIAGNOSTIC_HOST_CALL_LIMIT' end
 end
 pass.actualMs=delta(start,now()); pass.error=pass.error or state.effectError
 pass.result=state.activeEffects or {}; pass.finalOrigins={}
 for _,entry in pairs(pass.result) do pass.publications[entry.object]=pass.publications[entry.object] or {tick=pass.tick,stage='FINAL_COOKED_OR_DIRECT_MERGE'} end
 local scan=pass.scan
 if scan then
  for ordinal,d in ipairs(scan.diagnostics.parts) do
   local part=scan.parts[ordinal]; local r=pass.partReads[part]; if r then r.count=d.channels end
  end
  for index,layers in pairs(scan.tracked) do for prefix,item in pairs(layers) do
   for _,ref in ipairs(item.refs) do
    event(ref,item.probePart,'FINAL_SURVIVING_COOKED_LAYER',prefix,'SURVIVES_CHANNEL_TRACKING',item.probeRecipe,index)
    pass.finalOrigins[ref]=pass.finalOrigins[ref] or {}; pass.finalOrigins[ref][item.probePart or false]=true
   end
  end end
 end
 pass.waitMs=pass.tick*REFRESH_SECONDS*1000
 pass.correctedCore=math.max(0,pass.coreMs-pass.overhead)
 pass.processingMs=math.max(0,pass.correctedCore-pass.nativeMs)
 pass.estimate=pass.correctedCore+pass.waitMs
end
local wholeStart=now()
log('START target=2.5.0.3 scanner_source_version=0.7.0.17 production_flag=false private_replay_only=true clock=%s sequence={%s} cue={%s} batch=32 cadence_seconds=%g waits=MODEL_ONLY',clockMode,describe(sequence),describe(currentCue),REFRESH_SECONDS)
run('COLD_FIRST_OBSERVED_NOT_FLUSHED')
run('WARM_FULL_REPLAY_REPEAT_NOT_PRODUCTION_CACHE_HIT')
local warm=pass
-- Model actual scanner result-cache hit separately: it must issue no data reads.
local before=#warm.reads; local cacheStart=now(); refreshCueEffects(warm.state,true); local cacheMs=delta(cacheStart,now()); local cacheReads=#warm.reads-before
local contextStable=safe(rawAPI.sequence)==sequence and safe(rawAPI.cue)==currentCue
-- Reuse validated production grid/button/Ptr/identity path. No UI writes.
local uiUnverified=false; local derived={}
local function valid(h) return h~=nil and safe(IsObjectValid,h)==true end
local function isUI(h)
 if not valid(h) then return false end
 local k=class(h); if derived[k]==nil then derived[k]=k=='UIObject' or safe(IsClassDerivedFrom,k,'UIObject')==true end
 return derived[k]
end
local function ui(h,k,...) if not isUI(h) then uiUnverified=true; return nil end; return method(h,k,...) end
local function uiChildren(h) local list=ui(h,'UIChildren'); return type(list)=='table' and list or children(h) end
local function visible(h)
 if not isUI(h) then return nil end
 local a,b,c=bool(ui(h,'IsActuallyVisible')),bool(ui(h,'IsVisible')),bool(rawget(type(h)=='table' and h or {},'Visible') or safe(function() return h.Visible end))
 if a==false or b==false or c==false then return false end
 return a==true or b==true or c==true or nil
end
local function actual(h) if not valid(h) then return false end; local v=ui(h,'IsActuallyVisible'); return v==nil or bool(v)==true end
local production=rawget(_G,'RecipeTrackingInspectorState'); local grids={}; local needs=type(production)=='table' and production.poolGridRefreshNeeded==true
if type(production)=='table' then for _,g in ipairs(production.poolGrids or {}) do if actual(g) then grids[#grids+1]=g else needs=true end end end
if #grids==0 or needs then
 grids={}; local visited,budget={},6000
 local function visit(h,depth)
  if not h or visited[h] or depth>20 or budget<=0 then return end
  visited[h],budget=true,budget-1
  if type(production)=='table' and h==production.window then return end
  if class(h):find('PoolLayoutGrid',1,true) then if actual(h) then grids[#grids+1]=h end; return end
  for _,c in ipairs(uiChildren(h)) do visit(c,depth+1) end
 end
 if callable('GetDisplayByIndex') then for i=1,7 do visit(safe(GetDisplayByIndex,i),0) end elseif callable('GetFocusDisplay') then visit(safe(GetFocusDisplay),0) end
 if budget<=0 then uiUnverified=true end
end
local gridData={}; local tileLimited=#grids>64
for i=1,math.min(#grids,64) do
 local g=grids[i]; local p=safe(function() return g.PoolObject end); local entry={grid=g,pool=p,visible=visible(g),tiles={}}
 gridData[#gridData+1]=entry
 local display=g; for _=1,24 do if not display or class(display)=='Display' then break end; display=method(display,'Parent') end
 log('GRID grid={%s} display={%s} pool_type=%s pool={%s} visible=%s',describe(g),describe(display),text(property(g,'Pooltype')),describe(p),text(entry.visible))
 for j,b in ipairs(uiChildren(g)) do
  if j>2048 then tileLimited=true; break end
  local k=class(b):lower(); local idx=k:find('poolbutton',1,true) and not k:find('pooltitlebutton',1,true) and tonumber(property(b,'ObjectIndex')) or nil
  if idx then entry.tiles[#entry.tiles+1]={button=b,index=idx,target=safe(function() return p:Ptr(idx) end),visible=visible(b)} end
 end
end
for _,p in ipairs(allPasses) do
 pass=p; local sourceMisses=count(p.unresolved)+count(p.ignoredLinks); local anonymousMoving=0
 if p.scan then for _,d in ipairs(p.scan.diagnostics.parts) do anonymousMoving=anonymousMoving+d.emptyRefs; sourceMisses=sourceMisses+d.unresolvedRefs end end
 log('PASS label=%s raw_getpresetdata_calls=%d advances=%d host_calls=%d context_stable=%s error=%s',p.label,#p.reads,#p.advances,p.tick+1,text(contextStable),text(p.error))
 for i,o in ipairs(p.order) do log('CUE_SCAN pass=%s position=%d cue={%s} part={%s} origin=%s',p.label,i,describe(o.cue),describe(o.part),o.cue==currentCue and 'CURRENT_CUE' or 'CUE_HISTORY') end
 for i,r in ipairs(p.reads) do
  log('READ pass=%s read=%d kind=%s request_access=%s source_cue={%s} part={%s} target={%s} GetPresetData_ms=%s returned_record_count=%s return_type=%s cumulative_native_ms=%s success=%s error=%s count_limited=%s cumulative_actual_replay_ms=%s',p.label,i,r.kind,r.first and 'FIRST_OBSERVED_REQUEST' or 'REPEAT_REQUEST',describe(p.owners[r.part]),describe(r.part),describe(r.target),text(r.ms),text(r.count),r.returnType,p.timingInvalid and 'UNAVAILABLE' or text(r.cumulative),text(r.ok),text(r.error),text(r.countLimited),text(r.cumulativeReplay))
 end
 for _,a in ipairs(p.advances) do
  local keys={}; for _,k in ipairs(a.keys) do keys[#keys+1]=tostring(k) end
  log('BATCH pass=%s advance=%d host_tick=%d part={%s} records_processed=%d next_key_order=%s advance_elapsed_ms_including_native_and_trace=%s cadence_wait_before_ms=%g',p.label,a.number,a.tick,describe(a.part),a.records,table.concat(keys,','),text(a.ms),REFRESH_SECONDS*1000)
 end
 local matched,noPool,noTile,identityUnknown=0,0,0,0
 for key,e in pairs(p.result) do
  if type(key)~='string' then sourceMisses=sourceMisses+1; log('SOURCE_MISS pass=%s reason=NON_STRING_RESULT_KEY_ADDRESS_MEMO_SENTINEL_BEHAVIOR key_type=%s reference={%s} production_behavior_preserved=true',p.label,type(key),describe(e.object)) end
  local ref=e.object; local owners={}; local parent=method(ref,'Parent')
  for _=1,3 do if not valid(parent) then break end; owners[#owners+1]=parent; parent=method(parent,'Parent') end
  local pools,tiles,identity=0,0,0
  for _,g in ipairs(gridData) do
   local poolMatch=false; for _,o in ipairs(owners) do if sameReference(o,g.pool) then poolMatch=true; break end end
   for _,t in ipairs(g.tiles) do
    local targetKey=commandAddress(t.target); local productionMatch=targetKey and p.result[targetKey] or nil
    if not productionMatch and t.target then for _,candidate in pairs(p.result) do if sameReference(t.target,candidate.object) then productionMatch=candidate; break end end end
    if sameReference(t.target,ref) then
     poolMatch=true
     local identical=t.target==ref or (token(ref)~=nil and token(ref)==token(t.target))
     log('TILE pass=%s reference={%s} expected_pool_hint={%s} grid={%s} grid_visible=%s button_handle=%s ObjectIndex=%s button_visible=%s target={%s} sameReference=true DB_identity=%s production_matching_accepted=%s diagnostic_consumer_only=true',p.label,describe(ref),describe(method(ref,'Parent')),describe(g.grid),text(g.visible),text(token(t.button)),text(t.index),text(t.visible),describe(t.target),text(identical),text(productionMatch~=nil))
     if g.visible==nil or t.visible==nil then identityUnknown=identityUnknown+1 end
     if g.visible==true and t.visible==true and productionMatch then tiles=tiles+1; if identical then identity=identity+1 end end
    end
   end
   if poolMatch and g.visible==true then pools=pools+1 elseif poolMatch and g.visible==nil then identityUnknown=identityUnknown+1 end
  end
  if identity>0 then matched=matched+1 elseif tiles>0 then identityUnknown=identityUnknown+1 elseif pools==0 then noPool=noPool+1 else noTile=noTile+1 end
  log('REFERENCE_FINAL pass=%s key=%s reference={%s} accepted_reason=COOKED_RESULT_OR_DIRECT_CURRENT_RECIPE_MERGE visible_pools=%d visible_tiles=%d identity_matches=%d direct_merge_preserves_refs_even_when_absent_from_cooked=true',p.label,text(key),describe(ref),pools,tiles,identity)
  local publication=p.publications[ref]
  log('PUBLICATION pass=%s reference_type=%s reference={%s} first_publish_stage=%s first_publish_tick=%d first_publish_wait_model_ms=%g final_snapshot_tick=%d provisional_is_not_final_playback_provenance=true',p.label,refType(ref),describe(ref),publication.stage,publication.tick,publication.tick*REFRESH_SECONDS*1000,p.tick)
 end
 local refs={}; for ref,entry in pairs(p.refs) do refs[#refs+1]=entry end; table.sort(refs,function(a,b) return a.id<b.id end)
 for _,entry in ipairs(refs) do
  local finalKey=isObjectReference(entry.ref) and commandAddress(entry.ref) or nil
  local final=finalKey and p.result[finalKey]~=nil or false
  for part,events in pairs(entry.events) do for _,e in pairs(events) do
   local cue=p.owners[part]; local origin=cue==currentCue and 'DIRECT_CURRENT_CUE' or (cue and 'TRACKED_HISTORY_CANDIDATE' or 'UNKNOWN')
   local survives=p.finalOrigins[entry.ref] and p.finalOrigins[entry.ref][part] or false
   log('EXTRACT pass=%s ref_id=%d source_cue={%s} source_part={%s} recipe={%s} origin=%s layer_or_feature=%s stage=%s raw_reference=%s reference={%s} reason=%s occurrences=%d duplicates=%d survives_cooked_origin=%s included_in_final_key_set=%s channel_sample=%s',p.label,entry.id,describe(cue),describe(part),describe(e.recipe),origin,e.layer,e.stage,text(entry.ref),describe(entry.ref),e.reason,e.count,math.max(0,e.count-1),text(survives),text(final),text(e.channel))
   if e.recipe then local fields=p.rawFields[e.recipe] or {}; log('RECIPE_RAW pass=%s ref_id=%d reference_type=%s recipe={%s} raw_values=%s raw_generator=%s resolved_reference={%s}',p.label,entry.id,refType(entry.ref),describe(e.recipe),text(fields.Values),text(fields.Generator),describe(entry.ref)) end
  end end
 end
 for recipe,fields in pairs(p.unresolved) do for field,rawValue in pairs(fields) do log('SOURCE_MISS pass=%s recipe={%s} field=%s raw_reference=%s reason=recipeField_address_string_unresolved',p.label,describe(recipe),field,text(rawValue)) end end
 for _,message in ipairs(p.productionLogs) do log('PRODUCTION_COUNTERS pass=%s original_elapsed_is_os_clock_not_wall=true %s',p.label,message) end
 for _,a in ipairs(p.advances) do log('BATCH_COST pass=%s advance=%d native_ms=%s processing_excluding_native_and_trace_ms=%s trace_overhead_ms=%s cumulative_estimated_production_ms=%s',p.label,a.number,p.timingInvalid and 'UNAVAILABLE' or text(a.nativeMs),text(a.processingMs),p.timingInvalid and 'UNAVAILABLE' or text(a.overhead),p.timingInvalid and 'UNAVAILABLE' or text(a.cumulativeEstimate)) end
 local records=0; for _,a in ipairs(p.advances) do records=records+a.records end
 log('SCAN_TOTAL pass=%s parts_planned=%d parts_completed=%d records_generated_and_processed=%d reference_records_final=%d',p.label,#p.order,p.scan and #p.scan.diagnostics.parts or 0,records,count(p.result))
 local function metric(v) return not p.timingInvalid and text(v) or 'UNAVAILABLE' end
 local functional='CUE_WIDE_REFERENCE_PATH_COMPLETE'
 if not contextStable or p.traceLimited or uiUnverified or tileLimited or identityUnknown>0 or outputLimited then functional='UNVERIFIED'
 elseif p.error then functional=(p.error:lower():find('limit') or p.error:find('exceeds')) and 'UNVERIFIED' or 'CUE_WIDE_SOURCE_MISS'
 elseif sourceMisses>0 then functional='CUE_WIDE_SOURCE_MISS'
 elseif noPool+noTile>0 then functional='CUE_WIDE_TILE_MISS' end
 local performance='UNVERIFIED'; local dominant='UNAVAILABLE'; local share
 if not p.timingInvalid and not p.traceLimited and not outputLimited and clockMode=='MA_Time_SECONDS_WALL' and not p.error and contextStable then
  local value=p.nativeMs; dominant='NATIVE_GETPRESETDATA'; performance='CUE_WIDE_PERFORMANCE_BOTTLENECK_NATIVE_READ'
  if p.waitMs>value then value=p.waitMs; dominant='BATCH_CADENCE_WAIT_MODEL'; performance='CUE_WIDE_PERFORMANCE_BOTTLENECK_BATCH_WAIT' end
  if p.processingMs>value then value=p.processingMs; dominant='REFERENCE_PROCESSING_INCLUDING_OTHER_READ_APIS'; performance='CUE_WIDE_PERFORMANCE_BOTTLENECK_PROCESSING' end
  share=p.estimate>0 and value/p.estimate*100 or 0
  if p.estimate<=300 then performance='CUE_WIDE_REFERENCE_PATH_COMPLETE' end
 end
 log('SUMMARY pass=%s functional_classification=%s performance_classification=%s total_native_GetPresetData_ms=%s Lua_reference_processing_including_other_read_APIs_ms=%s estimated_loop_wait_ms=%g corrected_scanner_replay_ms=%s raw_scanner_replay_ms=%s actual_pass_ms=%s diagnostic_hook_counting_overhead_ms=%s estimated_cue_to_final_ms=%s dominant_component=%s dominant_share_percent=%s references_discovered=%d references_matched_visible=%d no_visible_pool=%d no_visible_tile=%d identity_unverified=%d source_resolution_misses=%d anonymous_moving_empty_refs=%d advances=%d first_ref_advance=%s initial_defer_wait_ms=%g scanner_internal_wait_ms=%g other_production_render_work=NOT_MEASURED purple_render_bridge=ABSENT_FROM_CURRENT_MARKER_CONSUMER',p.label,functional,performance,metric(p.nativeMs),metric(p.processingMs),p.waitMs,metric(p.correctedCore),metric(p.coreMs),text(p.actualMs),metric(p.overhead),metric(p.estimate),dominant,text(share),count(p.result),matched,noPool,noTile,identityUnknown,sourceMisses,anonymousMoving,#p.advances,text(p.scan and p.scan.diagnostics.firstRefAdvance),math.min(p.tick,1)*REFRESH_SECONDS*1000,math.max(p.tick-1,0)*REFRESH_SECONDS*1000)
 p.functional=functional; p.performance=performance; p.matched=matched; p.noPool=noPool; p.noTile=noTile
end
log('CACHE_MODEL unchanged_cue_refresh_ms=%s GetPresetData_reads=%d completed_snapshot_reused=%s warm_full_replay_above_is_not_cache_hit=true',text(cacheMs),cacheReads,text(cacheReads==0))
if outputLimited then for _,p in ipairs(allPasses) do p.functional='UNVERIFIED'; p.performance='UNVERIFIED' end end
Printf('[CueWideTrace] END passes=%d total_probe_elapsed_ms=%s context_stable=%s output_capped=%s overall_evidence=%s production_modified=false markers_drawn=false no_actual_cadence_waits=true',#allPasses,text(delta(wholeStart,now())),text(contextStable),text(outputLimited),outputLimited and 'UNVERIFIED' or 'SEE_PASS_SUMMARIES')
return {passes=allPasses,cache_reads=cacheReads,contextStable=contextStable,outputLimited=outputLimited}
end
