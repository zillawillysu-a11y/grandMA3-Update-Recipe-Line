-- Independent read-only structural/sparse vs exact dormant scanner oracle.
-- Production 0.7.0.17; normalized-source SHA256 a6e15338449ef365fa152ef6400fe849d084f20a32d363b5bc8d6159314230b6.
return function()
local commandAddress, children, recipeNumber, generatorHasFeature
local GetPresetData, SelectedSequence, GetCurrentCue, sparseNext, sparseRecipes, rememberSparseRecipes, captureOrigin, captureFeatureRecord, captureNoEffect, finishFinalCandidateScan
local MAX_CUES, MAX_RECIPES, REFRESH_SECONDS = 512, 2048, 0.1
local ENABLE_CUE_PHASER_MARKERS = true -- private copy only; production stays false
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
        captureFeatureRecord()
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
                    captureOrigin(part, layers[layer[1]])
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
local function sparseScanCueEffectPart(scan, part)
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
    pending.recipes = pending.recipes or sparseRecipes(part)
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
    rememberSparseRecipes(part, recipes)
    end
    while true do
        local index, phaser = sparseNext(scan, part, data)
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
                captureNoEffect(part, scan, index, layer[1], touched)
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
                    local probePrevious = layers[layer[1]]
                    layers[layer[1]] = moving and {refs = refs, fixture = fixture} or nil
                    captureOrigin(part, layers[layer[1]], scan, index, layer[1], phaser, probePrevious)
                end
            end
        end
    end
end

local function sparseAdvanceCueEffectScan(scan)
    if scan.done then return scan.result end
    scan.advanceCalls = scan.advanceCalls + 1
    local part = scan.parts[scan.index]
    if part then
        if sparseScanCueEffectPart(scan, part) then scan.index = scan.index + 1 end
    end
    if scan.index > #scan.parts then return finishFinalCandidateScan(scan) end
    return nil
end


local rawAPI={data=_G.GetPresetData,sequence=_G.SelectedSequence,cue=_G.GetCurrentCue}
assert((safe(BuildDetails) or {}).BigVersion=='2.5.0.3','Requires grandMA3 2.5.0.3')
assert(type(rawAPI.data)=='function','GetPresetData required for oracle')
local sequence,currentCue=safe(rawAPI.sequence),safe(rawAPI.cue)
assert(sequence and currentCue and cueNumber(currentCue),'Select readable Sequence/Current Cue')
SelectedSequence=function() return sequence end; GetCurrentCue=function() return currentCue end
local function now() local n=safe(Time); return type(n)=='number' and n or nil end
local function elapsed(a,b) return a and b and b>=a and (b-a)*1000 or nil end
local function text(v) return v==nil and 'UNAVAILABLE' or tostring(v):gsub('[\r\n]',' '):sub(1,220) end
local function token(h) return h and safe(HandleToStr,h) or nil end
local function method(h,k,...) return safe(function(...) return h[k](h,...) end,...) end
local function describe(h) return 'class='..text(class(h))..' command='..text(commandAddress(h))..' native='..text(method(h,'AddrNative'))..' DB_handle='..text(token(h)) end
local function kind(h) return isRandomGenerator(h) and 'Generator' or (isPhaserRecipePreset(h) and 'Phaser' or 'Preset') end
local outputCount,outputCapped=0,false
local function log(f,...) if outputCount>=6000 then outputCapped=true; return end; outputCount=outputCount+1; Printf('[CueStructAB] '..f,...) end
local identities,identityCache,identityUnverified={},{},false
local function dbEqual(a,b)
 if a==b then return true end
 local aa,bb=token(a),token(b); if aa and bb and aa==bb then return true end
 local v=safe(CompareHandle,a,b); if type(v)=='boolean' then return v end
 identityUnverified=true; return false
end
local function id(h)
 if not isObjectReference(h) then return nil end
 if identityCache[h] then return identityCache[h] end
 for i,v in ipairs(identities) do if dbEqual(h,v) then identityCache[h]=i; return i end end
 identities[#identities+1]=h; identityCache[h]=#identities; return #identities
end
local function setFrom(result)
 local list={}; local bad=false
 for key,e in pairs(result or {}) do
  local ref=e.object; local keyId=id(ref)
  if type(key)~='string' or not keyId then bad=true end
  if keyId then list[keyId]=ref end
 end
 return list,bad
end
local function count(t) local n=0; for _ in pairs(t or {}) do n=n+1 end; return n end
local LIMIT={channels=32768,mappingWork=262144,seconds=30,
 lookups=131072,records=32768,hybridParts=512,
 reads=512,advances=8192,rows=2048}
local phase,profiles={},{}
local footprints,reverseIndex={},{}
local function profile(name)
 local p={name=name,reads={},nativeMs=0,records=0,featureRecords=0,lookups=0,advances=0,parts=0,started=now(),timingInvalid=false,dataCache={},chunks={},witnesses={},transitions={},returnedCountMs=0,stages={},partReads={},events={},eventRows={},outsideFootprint={},decisive={},losses={},semanticMs=0,scopeStats={mappingCalls=0,mappingHits=0,attributeCalls=0,attributeHits=0,mappingMs=0,attributeMs=0,iterations=0,groupMembershipReads=0,groupMembershipHits=0,membersVisited=0,groupKeyBuilds=0,groupKeyHits=0,filteredScopeBuilds=0,filteredScopeHits=0,rawMappingIterations=0,filterIterations=0,mergeIterations=0,indexOperations=0}}
 profiles[name]=p; phase=p; return p
end
local function stage(p,name)
 local t=now()
 if p.stageName then
  local ms=elapsed(p.stageStarted,t)
  if ms then p.stages[p.stageName]=(p.stages[p.stageName] or 0)+ms else p.timingInvalid=true end
 end
 p.stageName=name; p.stageStarted=t
end
local function finishProfile(p)
 stage(p,nil)
 p.totalMs=elapsed(p.started,now()); if not p.totalMs then p.timingInvalid=true end
 p.processingMs=p.totalMs and math.max(0,p.totalMs-p.nativeMs) or nil
end
local function transition(p,rid,event,scan,part,index,prefix,source)
 if not (reverseIndex[index] or {})[rid] then return end
 p.events[rid]=p.events[rid] or {}; p.events[rid][event]=(p.events[rid][event] or 0)+1
 local key=rid..'|'..scan.index..'|'..prefix..'|'..event
 local row=p.eventRows[key]
 if not row then row={rid=rid,event=event,part=part,index=index,prefix=prefix,source=source,count=0}; p.eventRows[key]=row end
 row.count=row.count+1
end
captureOrigin=function(part,item,scan,index,prefix,phaser,previous)
 if item then item.probePart=part end
 if phase.name~='HYBRID' or not scan then return end
 local unit=phase.units[scan.index]
 if item then for _,ref in ipairs(item.refs) do
  local rid=id(ref); if footprints[rid] and not (reverseIndex[index] or {})[rid] then
   local observed=phase.outsideFootprint[rid] or {count=0,index=index,part=part,prefix=prefix}; phase.outsideFootprint[rid]=observed; observed.count=observed.count+1
  end
  if (reverseIndex[index] or {})[rid] then
  phase.witnesses[rid]=phase.witnesses[rid] or {}
  phase.witnesses[rid][index]=phase.witnesses[rid][index] or {}; phase.witnesses[rid][index][prefix]=true
 end end end
 if item then for _,ref in ipairs(item.refs) do
  local rid=id(ref); if (reverseIndex[index] or {})[rid] then
  phase.events[rid]=phase.events[rid] or {}; local same=false
  for _,old in ipairs(previous and previous.refs or {}) do if dbEqual(old,ref) then same=true end end
  item.probeSources=item.probeSources or {}; item.probeSources[rid]=same and ((previous.probeSources or {})[rid] or previous.probePart) or part
  if not same and phase.losses[rid] and phase.losses[rid][index] then phase.losses[rid][index][prefix]=nil end
  local event=same and 'STILL_ACTIVE' or 'SOURCE'; transition(phase,rid,event,scan,part,index,prefix,item.probeSources[rid])
 end end end
 if previous then for _,ref in ipairs(previous.refs) do
  local rid=id(ref); if (reverseIndex[index] or {})[rid] then
  local retained=false
  if item then for _,v in ipairs(item.refs) do if dbEqual(ref,v) then retained=true; break end end end
  if not retained then
   local released=false
   for key,step in pairs(phaser) do if type(key)=='number' and type(step)=='table' and (step[prefix..'_release'] or step[prefix..'_remove']) then released=true end end
   local reason=item and 'SUPERSEDED_BY_COOKED_REFERENCE' or (released and 'COOKED_RELEASE_OR_REMOVE' or 'COOKED_STATIC_LAYER')
   phase.losses[rid]=phase.losses[rid] or {}; phase.losses[rid][index]=phase.losses[rid][index] or {}
   phase.losses[rid][index][prefix]={ref=ref,source=(previous.probeSources or {})[rid] or previous.probePart,part=part,position=scan.index,index=index,prefix=prefix,reason=reason,replacement=item and item.refs or {},released=released}
   phase.events[rid]=phase.events[rid] or {}; local e=phase.events[rid]
   local event=released and 'RELEASED' or (not item and 'STATIC_TERMINATOR' or 'SUPERSEDED')
   transition(phase,rid,event,scan,part,index,prefix,(previous.probeSources or {})[rid] or previous.probePart)
   phase.transitions[rid]=phase.transitions[rid] or {}; phase.transitions[rid][reason]=(phase.transitions[rid][reason] or 0)+1
  end
 end end end
end
captureNoEffect=function(part,scan,index,prefix,touched)
 if phase.name~='HYBRID' then return end
 phase.transitionOperations=(phase.transitionOperations or 0)+count(reverseIndex[index])
 if touched then return end
 local old=(scan.tracked[index] or {})[prefix]
 for _,ref in ipairs(old and old.refs or {}) do local rid=id(ref); phase.events[rid]=phase.events[rid] or {}; transition(phase,rid,'NO_EFFECT',scan,part,index,prefix,(old.probeSources or {})[rid] or old.probePart) end
end
captureFeatureRecord=function()
 phase.featureRecords=phase.featureRecords+1
 if phase.name=='HYBRID' and phase.records+phase.featureRecords>LIMIT.records then error('DIAGNOSTIC_SPARSE_PLUS_FEATURE_RECORD_LIMIT') end
end
GetPresetData=function(target,phasers,fixtures)
 if phase.name=='STRUCTURAL' then error('STRUCTURAL_MUST_NOT_READ_COOKED') end
 if #phase.reads>=LIMIT.reads then error('DIAGNOSTIC_NATIVE_READ_LIMIT') end
 local cached=phase.name=='HYBRID' and phasers==false and phase.dataCache[target]
 if cached then phase.cacheReuses=(phase.cacheReuses or 0)+1; return cached end
 local a=now(); local ok,data=pcall(rawAPI.data,target,phasers,fixtures); local ms=elapsed(a,now())
 if ms then phase.nativeMs=phase.nativeMs+ms else phase.timingInvalid=true end
 local record={target=target,kind=phasers==false and 'PART_COOKED' or 'FEATURE_REFERENCE',ms=ms,ok=ok,flags=tostring(phasers)..','..tostring(fixtures)}
 phase.reads[#phase.reads+1]=record
 if phase.name=='HYBRID' and ok and type(data)=='table' and phasers==false then
  phase.dataCache[target]=data; phase.partReads[target]=record
 end
 if not ok then error(data,0) end
 return data
end
local baselineAdvance=advanceCueEffectScan
advanceCueEffectScan=function(scan)
 phase.scan=scan; local result=baselineAdvance(scan); phase.advances=scan.advanceCalls
 return result
end
local contexts,owners,order={}, {}, {}
local structural,structuralRows,ambiguous,candidateRows,firstByChannel,groupIds={}, {}, {}, {}, {}, {}
local hardBlocked=false
local function explicitFeatures(ref)
 local found,unknown,all={},false,false
 local function add(value)
  if isObjectReference(value) then value=label(value) end
  local s=tostring(value or ''):lower()
  if s=='' or s=='none' or s=='all' then all=true; return end
  for word in s:gmatch('[%w_]+') do
   local f=normalizeFeature(word)
   if RECIPE_FEATURE_SET[f] then found[f]=true else unknown=true end
  end
 end
 if isRandomGenerator(ref) then
  local channels=safe(function() return ref.RandomChannels end)
  for _,channel in ipairs(children(channels)) do add(safe(function() return channel.Attribute end)) end
 else
  local seen=0
  local function visit(node,depth)
   if not node or depth>6 or seen>=256 then unknown=true; return end
   seen=seen+1
   if class(node):lower()=='phaserrecipevaluesource' then
    local value=property(node,'Attributes') or property(node,'Attribute') or property(node,'Feature')
    if value then add(value) end
   end
   for _,child in ipairs(children(node)) do visit(child,depth+1) end
  end
  visit(ref,0)
 end
 if all or unknown or next(found)==nil then return nil end
 return found
end
local function ambiguity(reason,row,detail,hard)
 if #ambiguous>=4096 then hardBlocked=true; return end
 ambiguous[#ambiguous+1]={reason=reason,row=row,detail=detail,hard=hard}
 if hard then hardBlocked=true end
end
-- B runs before C and A: no access to oracle records/results/prior globals.
log('START target=2.5.0.3 diagnostic_revision=5_FINAL_CANDIDATE_FOOTPRINTS production_version=0.7.0.17 production_flag=false execution_order=B_STRUCTURAL,C_SPARSE_HYBRID,A_ORACLE oracle_not_available_to_candidates=true sequence={%s} cue={%s}',describe(sequence),describe(currentCue))
local b=profile('STRUCTURAL')
local okB,errorB=pcall(function()
 stage(b,'Recipe_history_walk')
 local model=newCueEffectScan(sequence,currentCue)
 if #model.parts>512 then error('DIAGNOSTIC_STRUCTURAL_PART_LIMIT') end
 for i,part in ipairs(model.parts) do
  order[part]=i; owners[part]=method(part,'Parent'); contexts[i]={part=part,cue=owners[part]}
  for ordinal,recipe in ipairs(children(part)) do if isStandardRecipe(recipe) then
   if #structuralRows>=LIMIT.rows then error('DIAGNOSTIC_RECIPE_ROW_LIMIT') end
   local group,rawGroup=recipeField(recipe,'Selection'); local ref,rawRef=recipeField(recipe,'Generator'); local field='Generator'
   if not ref then ref,rawRef=recipeField(recipe,'Values'); field='Values' end
   local row={recipe=recipe,cue=owners[part],part=part,position=i,index=recipeNumber(recipe,ordinal),enabled=recipeEnabled(recipe),group=group,ref=ref,rawGroup=rawGroup,rawRef=rawRef,field=field}
   structuralRows[#structuralRows+1]=row
   if row.enabled and ref then
    row.groupId=id(group); row.refId=id(ref); row.features=recipeReferenceFeatures(ref)
    row.moving=isPhaserRecipePreset(ref) or isRandomGenerator(ref)
    candidateRows[#candidateRows+1]=row
    ambiguity('RECIPE_LAYER_AND_MANUAL_OVERRIDE_NOT_STRUCTURALLY_PROVEN',row,'abs/rel/release/overlap require cooked evidence',false)
    if not row.moving then ambiguity('ORDINARY_PRESET_MOVING_OR_STATIC_UNKNOWN',row,'do not assume static terminator',false) end
   elseif row.enabled and tostring(rawRef or '')~='' and tostring(rawRef):lower()~='none' then
    ambiguity('UNRESOLVED_RECIPE_REFERENCE',row,rawRef,true)
   end
  end end
 end
 stage(b,'candidate_resolution')
 -- Provisional exact DB Group + feature lane decisions; layer unknown is explicit.
 table.sort(candidateRows,function(a,c) if a.position~=c.position then return a.position>c.position end; return a.index>c.index end)
 local lanes={}
 for _,row in ipairs(candidateRows) do
  for _,feature in ipairs(row.features) do
   local key=tostring(row.groupId)..'|'..feature
   row.lanes=row.lanes or {}; row.lanes[feature]=lanes[key] and 'OLDER_LANE_CANDIDATE' or 'NEWEST_STRUCTURAL_LANE'
   if not lanes[key] then
    lanes[key]=row
    if row.moving then structural[row.refId]=row.ref end
   end
  end
 end
 local direct=currentCueRecipeEffects(currentCue)
 for _,entry in pairs(direct) do structural[id(entry.object)]=entry.object end
 -- Only FINAL candidates own footprints; all their enabled history source rows are retained.
 local sourceRows={}
 for rid,ref in pairs(structural) do footprints[rid]={ref=ref,rows={},keys={},features={},groupIds={}} end
 for _,row in ipairs(candidateRows) do local fp=footprints[row.refId]; if fp then
  fp.rows[#fp.rows+1]=row; sourceRows[#sourceRows+1]=row
 end end
 stage(b,'group_selection_membership_expansion')
 local groupMembers={}
 for _,row in ipairs(sourceRows) do
  local cached=row.groupId and groupMembers[row.groupId]
  if cached then row.members=cached; b.scopeStats.groupMembershipHits=b.scopeStats.groupMembershipHits+1
  else
   b.scopeStats.groupMembershipReads=b.scopeStats.groupMembershipReads+1
   local selection=safe(function() return row.group.Selection end)
   if not row.groupId or type(selection)~='table' then ambiguity('SELECTION_MEMBERSHIP_UNAVAILABLE',row,row.rawGroup,true)
   else
    local members={}; row.members=members; groupMembers[row.groupId]=members; groupIds[row.groupId]=row.group
    for _,member in pairs(selection) do
     b.scopeStats.membersVisited=b.scopeStats.membersVisited+1; if b.scopeStats.membersVisited>LIMIT.mappingWork then error('DIAGNOSTIC_MEMBERSHIP_WORK_LIMIT') end
     local sf=type(member)=='table' and tonumber(member.sf_index) or nil
     if not sf then ambiguity('SELECTION_MEMBER_INDEX_UNAVAILABLE',row,text(member),true) else members[sf]=true end
    end
   end
  end
 end
 stage(b,'eligible_key_set_construction')
 local mapped,channelFeatures,groupKeys,filteredScopes={},{},{},{}
 local scopedCount,mappingWork=0,0
 local function checkpoint(kind)
  if kind then b.scopeStats[kind]=b.scopeStats[kind]+1 end
  mappingWork=mappingWork+1; b.scopeStats.iterations=mappingWork
  if mappingWork>LIMIT.mappingWork then error('DIAGNOSTIC_MAPPING_WORK_LIMIT') end
 end
 local function attributeFeature(index)
  if channelFeatures[index]==nil then
   local t=now(); local attr=safe(GetAttributeByUIChannel,index); channelFeatures[index]=attr and normalizeFeature(label(attr)) or false
   local ms=elapsed(t,now()); b.scopeStats.attributeCalls=b.scopeStats.attributeCalls+1; if ms then b.scopeStats.attributeMs=b.scopeStats.attributeMs+ms end
  else b.scopeStats.attributeHits=b.scopeStats.attributeHits+1 end
  return channelFeatures[index] or nil
 end
 for rid,fp in pairs(footprints) do
  local family=string.match(address(fp.ref),'PresetPools%.([^%.]+)%.')
  fp.definitiveFamily=family and RECIPE_FEATURE_SET[normalizeFeature(family)] and normalizeFeature(family)
  fp.explicitFeatures=explicitFeatures(fp.ref)
  b.familyAddressReads=(b.familyAddressReads or 0)+1
  local featureNames={}; for feature in pairs(fp.explicitFeatures or {}) do featureNames[#featureNames+1]=feature end; table.sort(featureNames)
  fp.scopeSignature=fp.definitiveFamily and ('POOL:'..fp.definitiveFamily) or (#featureNames>0 and ('EXPLICIT:'..table.concat(featureNames,',')) or 'ALL_UNKNOWN')
  fp.features=fp.definitiveFamily and {[fp.definitiveFamily]=true} or fp.explicitFeatures or {}
  for _,row in ipairs(fp.rows) do
   row.explicitFeatures=fp.explicitFeatures
   local gid=row.groupId
   if gid and row.members then
    fp.groupIds[gid]=true
    local keys=groupKeys[gid]
    if keys then b.scopeStats.groupKeyHits=b.scopeStats.groupKeyHits+1
    else
     b.scopeStats.groupKeyBuilds=b.scopeStats.groupKeyBuilds+1; keys={}; groupKeys[gid]=keys
     for sf in pairs(row.members) do
      if not mapped[sf] then
       local t=now(); mapped[sf]=safe(GetUIChannels,sf,false); local ms=elapsed(t,now())
       b.scopeStats.mappingCalls=b.scopeStats.mappingCalls+1; if ms then b.scopeStats.mappingMs=b.scopeStats.mappingMs+ms end
      else b.scopeStats.mappingHits=b.scopeStats.mappingHits+1 end
      local channels=mapped[sf]
      if type(channels)~='table' or #channels==0 then ambiguity('GETUICHANNELS_UNAVAILABLE_OR_EMPTY',row,sf,true)
      else for _,value in ipairs(channels) do
       checkpoint('rawMappingIterations'); local index=tonumber(value)
       if not index then ambiguity('NON_NUMERIC_UI_CHANNEL_MAPPING',row,text(value),true) else keys[index]=true end
      end end
     end
    end
    local cacheKey=gid..'|'..fp.scopeSignature; local selected=filteredScopes[cacheKey]
    if selected then b.scopeStats.filteredScopeHits=b.scopeStats.filteredScopeHits+1
    else
     b.scopeStats.filteredScopeBuilds=b.scopeStats.filteredScopeBuilds+1; selected={}; filteredScopes[cacheKey]=selected
     for index in pairs(keys) do
      checkpoint('filterIterations'); local feature=attributeFeature(index); local keep=true
      if fp.definitiveFamily and feature then keep=feature==fp.definitiveFamily
      elseif fp.explicitFeatures and feature then keep=fp.explicitFeatures[feature]==true end
      if not feature then ambiguity('ATTRIBUTE_MAPPING_UNKNOWN_INCLUDE_ALL',row,index,false) end
      if keep then selected[index]=true end
     end
    end
    row.keys=selected
    -- Same candidate/group/filter is merged once, without losing any source row/event.
    fp.mergedGroups=fp.mergedGroups or {}
    if not fp.mergedGroups[cacheKey] then
     fp.mergedGroups[cacheKey]=true
     for index in pairs(selected) do checkpoint('mergeIterations'); fp.keys[index]=true end
    end
   end
  end
  if #fp.rows==0 then ambiguity('FINAL_CANDIDATE_SOURCE_ROWS_UNAVAILABLE',nil,commandAddress(fp.ref),true) end
  for index in pairs(fp.keys) do
   checkpoint('indexOperations')
   reverseIndex[index]=reverseIndex[index] or {}; reverseIndex[index][rid]=fp
   if firstByChannel[index]==nil then scopedCount=scopedCount+1 end
   firstByChannel[index]=true
   if scopedCount>LIMIT.channels then error('DIAGNOSTIC_TOTAL_CHANNEL_SCOPE_LIMIT') end
  end
 end
 b.finalSourceRows=#sourceRows
 ambiguity('NON_RECIPE_CHANNELS_AND_SCOPE_COMPLETENESS_UNKNOWN',nil,'no structural API proves absence of manual moving channels outside this scope',false)
end)
finishProfile(b); b.error=not okB and tostring(errorB) or nil
if not okB then hardBlocked=true end
-- C consumes final-candidate footprints and scans every relevant history Part.
local h=profile('HYBRID'); local hybrid={}; for key,ref in pairs(structural) do hybrid[key]=ref end
h.candidatesBefore=count(hybrid); h.changes={}; h.units={}; h.recipeCache={}
sparseRecipes=function(part) return h.recipeCache[part] end
rememberSparseRecipes=function(part,recipes) h.recipeCache[part]=recipes end
local selectedParts,keysByPart,planned={}, {}, {}
stage(h,'witness_Part_selection')
local directSet=setFrom(currentCueRecipeEffects(currentCue))
local candidateKeys={}
local keyStart=now()
for key in pairs(reverseIndex) do candidateKeys[key]=true end
h.keyConstructionMs=elapsed(keyStart,now())
stage(h,'chunk_plan_construction') -- one plan per history Part, shared candidate key set.
local planningError; local plannedLookups=0
if #contexts>LIMIT.hybridParts then planningError='DIAGNOSTIC_SELECTED_PART_LIMIT' end
for _,ctx in ipairs(contexts) do
 selectedParts[#selectedParts+1]=ctx.part; keysByPart[ctx.part]=candidateKeys
 planned[ctx.part]={stage='FULL_HISTORY',keys=candidateKeys}
 h.units[#h.units+1]={part=ctx.part,stage='FULL_HISTORY',keys=candidateKeys,eligibleCount=count(candidateKeys)}
 plannedLookups=plannedLookups+count(candidateKeys)
end
sparseNext=function(scan,part,data)
 local pending=scan.pendingPart; local unit=h.units[scan.index]
 if h.semanticStart then local ms=elapsed(h.semanticStart,now()); if ms then h.semanticMs=h.semanticMs+ms end; h.semanticStart=nil end
 if not unit.started then unit.started=true; h.chunks[#h.chunks+1]=unit end
 while true do
  if phase.lookups%256==0 then
   local ms=elapsed(h.started,now()); if ms and ms>LIMIT.seconds*1000 then error('DIAGNOSTIC_HYBRID_ELAPSED_LIMIT') end
  end
  local index,record=next(data,pending.streamKey)
  if index==nil then
   unit.completed=true
   local read=h.partReads[part]; if read then read.returned=unit.inspected or 0; read.countComplete=true end
   return nil
  end
  pending.streamKey=index
  h.advanceVisited=(h.advanceVisited or 0)+1
  phase.lookups=phase.lookups+1; unit.inspected=(unit.inspected or 0)+1
  if phase.lookups>LIMIT.lookups then error('DIAGNOSTIC_ACTUAL_COOKED_RECORD_LIMIT') end
  if type(index)=='number' and unit.keys[index] then
   phase.records=phase.records+1; unit.records=(unit.records or 0)+1
   if phase.records+phase.featureRecords>LIMIT.records then error('DIAGNOSTIC_SPARSE_RECORD_LIMIT') end
   h.routeOperations=(h.routeOperations or 0)+count(reverseIndex[index]); h.semanticStart=now(); return index,record
  end
 end
end
finishFinalCandidateScan=function(scan)
 local result,final={},{}
 for index,layers in pairs(scan.tracked) do
  local ownersForKey=reverseIndex[index] or {}
  for _,item in pairs(layers) do for _,ref in ipairs(item.refs) do
   local rid=id(ref)
   if ownersForKey[rid] then
    local key=memoReferenceAddress(scan,ref)
    if type(key)~='string' then error('HYBRID_INVALID_NON_STRING_RESULT_KEY') end
    final[rid]=ref; result['DB_ID:'..rid]={object=ref}
   end
  end end
 end
 scan.finalCandidates=final; scan.result=result; scan.done=true; return result
end
local okH,errorH=pcall(function()
 if hardBlocked then error('AMBIGUOUS_SCOPE_REQUIRES_FULL_COOKED_NO_HYBRID_FALLBACK') end
 if planningError then error(planningError) end
 stage(h,'cooked_stream_filtering')
 local scan=newCueEffectScan(sequence,currentCue); scan.parts={}; h.scan=scan
 for _,unit in ipairs(h.units) do scan.parts[#scan.parts+1]=unit.part end
 if #scan.parts==0 then scan.done=true; scan.result={} end
 while not scan.done do
  if scan.advanceCalls>=LIMIT.advances then error('DIAGNOSTIC_ADVANCE_LIMIT') end
  if elapsed(h.started,now()) and elapsed(h.started,now())>LIMIT.seconds*1000 then error('DIAGNOSTIC_HYBRID_ELAPSED_LIMIT') end
  h.advanceVisited=0
  sparseAdvanceCueEffectScan(scan)
  if elapsed(h.started,now()) and elapsed(h.started,now())>LIMIT.seconds*1000 then error('DIAGNOSTIC_HYBRID_ELAPSED_LIMIT') end
 end
 h.advances=scan.advanceCalls
 stage(h,'candidate_resolution')
 local cooked={}
 for rid,ref in pairs(scan.finalCandidates or {}) do cooked[rid]=ref end
 -- The pre-oracle current Recipe merge is unchanged and restricted to final candidates.
 for rid,ref in pairs(directSet) do if footprints[rid] then cooked[rid]=ref end end
 for rid,ref in pairs(structural) do if not cooked[rid] then
  local witnesses=h.witnesses[rid]; local seen,survives=0,false
  for index,layers in pairs(witnesses or {}) do for prefix in pairs(layers) do
   seen=seen+1; local final=(scan.tracked[index] or {})[prefix]
   if final then for _,v in ipairs(final.refs) do if dbEqual(v,ref) then survives=true end end end
  end end
  if seen>0 and not survives and h.transitions[rid] then
   for index,layers in pairs(h.losses[rid] or {}) do for _,d in pairs(layers) do
    if not h.decisive[rid] or d.position<h.decisive[rid].position then h.decisive[rid]=d end
   end end
   hybrid[rid]=nil; h.changes[#h.changes+1]={action='REMOVED',ref=ref,reason='ALL_SCOPED_SOURCE_WITNESS_LAYERS_REPLACED_OR_CLEARED',witnessLayers=seen,reasons=h.transitions[rid]}
  else
   ambiguity('STRUCTURAL_CANDIDATE_RETAINED_WITHOUT_CONCLUSIVE_COOKED_REMOVAL',nil,commandAddress(ref),false)
   h.changes[#h.changes+1]={action='RETAINED_AMBIGUOUS',ref=ref,reason='NO_POSITIVE_SOURCE_WITNESS_OR_UNCLEARED_LAYER',witnessLayers=seen}
  end
 else
  h.changes[#h.changes+1]={action=directSet[rid] and 'RETAINED_DIRECT_MERGE' or 'RETAINED_SCOPED_COOKED',ref=ref,reason=directSet[rid] and 'PRE_ORACLE_CURRENT_CUE_DIRECT_RECIPE_MERGE' or 'SURVIVES_FULL_HISTORY_CANDIDATE_SCOPE'}
 end end
 for rid,ref in pairs(cooked) do if not hybrid[rid] then
  hybrid[rid]=ref; h.changes[#h.changes+1]={action='ADDED',ref=ref,reason=directSet[rid] and 'PRE_ORACLE_CURRENT_CUE_DIRECT_RECIPE_MERGE' or 'MOVING_REFERENCE_SURVIVES_FULL_HISTORY_CANDIDATE_SCOPE'}
 end end
 if elapsed(h.started,now()) and elapsed(h.started,now())>LIMIT.seconds*1000 then error('DIAGNOSTIC_HYBRID_ELAPSED_LIMIT') end
end)
if h.semanticStart then local ms=elapsed(h.semanticStart,now()); if ms then h.semanticMs=h.semanticMs+ms end; h.semanticStart=nil end
if h.scan then
 h.advances=h.scan.advanceCalls
 local completed={}
 for _,unit in ipairs(h.units) do if completed[unit.part]==nil then completed[unit.part]=true end; if not unit.completed then completed[unit.part]=false end end
 for _,allDone in pairs(completed) do if allDone then h.parts=h.parts+1 end end
end
h.executed=#h.chunks>0; h.resultValid=okH and h.executed
finishProfile(h); h.error=not okH and tostring(errorH) or nil
-- A runs LAST. Full cooked walk exists ONLY as the permitted oracle.
local a=profile('BASELINE'); local baseline={}; local baselineBad=false
local okA,errorA=pcall(function()
 local state={poolBlink=true,running=true}
 for tick=0,LIMIT.advances do
  a.tick=tick; refreshCueEffects(state,true)
  if state.effectError then error(state.effectError) end
  if not state.recipeScanPending and not state.effectScanPending and not state.effectScanner then
   baseline,baselineBad=setFrom(state.activeEffects); return
  end
 end
 error('DIAGNOSTIC_BASELINE_ADVANCE_LIMIT')
end)
if a.scan then a.parts=#a.scan.diagnostics.parts; for _,d in ipairs(a.scan.diagnostics.parts) do a.records=a.records+d.channels end end
finishProfile(a); a.error=not okA and tostring(errorA) or nil
local stable=safe(rawAPI.sequence)==sequence and safe(rawAPI.cue)==currentCue
local comparisons={}
local function compare(name,candidate,success)
 local missing,extra={},{}
 if success and okA then
  for key,ref in pairs(baseline) do if not candidate[key] then missing[key]=ref end end
  for key,ref in pairs(candidate) do if not baseline[key] then extra[key]=ref end end
 end
 local classification=name=='STRUCTURAL' and 'STRUCTURAL_EXACT_MATCH' or 'HYBRID_EXACT_MATCH'
 if not okA or baselineBad or not stable or identityUnverified then classification='UNVERIFIED'
 elseif not success then
  local e=name=='STRUCTURAL' and b.error or h.error
  classification=(hardBlocked or (e and (e:find('LIMIT') or e:find('AMBIGUOUS_SCOPE')))) and 'AMBIGUOUS_REQUIRES_FULL_COOKED' or 'UNVERIFIED'
 elseif count(missing)>0 then classification='MISSING_REFERENCE'
 elseif count(extra)>0 then classification='EXTRA_REFERENCE' end
 comparisons[name]={classification=classification,missing=missing,extra=extra,candidateValid=success and okA}
 return comparisons[name]
end
compare('STRUCTURAL',structural,okB); compare('HYBRID',hybrid,h.resultValid)
local structuralMissing={}
if okA and not baselineBad and stable and okB then for rid,ref in pairs(baseline) do if not structural[rid] then structuralMissing[rid]=ref end end end
-- All output/metadata work occurs after phase timing.
log('RESULTS oracle_executed_after_candidates=true scope_channels=%d selected_cooked_Parts=%d total_history_Parts=%d',count(firstByChannel),#selectedParts,#contexts)
for _,p in ipairs({b,h,a}) do
 local cooked,featureReads=0,0
 for _,r in ipairs(p.reads) do if r.kind=='PART_COOKED' then cooked=cooked+1 else featureReads=featureReads+1 end end
 local metric=function(v) return p.timingInvalid and 'UNAVAILABLE' or text(v) end
 local waitTicks=p.name=='BASELINE' and (p.tick or 0) or 0
 log('METRICS phase=%s Recipe_rows_inspected_by_structural_scope=%d cooked_Parts_read=%d completed_Parts=%d cooked_records_processed=%d actual_cooked_entries_inspected=%d GetPresetData_calls=%d supplementary_feature_reads=%d GetPresetData_ms=%s Lua_processing_including_other_read_APIs_ms=%s total_elapsed_ms=%s advances=%d cadence_unchanged_seconds=%g actual_waits=false estimated_wait_ms=%g error=%s',p.name,#structuralRows,cooked,p.parts,p.records,p.lookups,#p.reads,featureReads,metric(p.nativeMs),metric(p.processingMs),metric(p.totalMs),p.advances,REFRESH_SECONDS,waitTicks*REFRESH_SECONDS*1000,text(p.error))
 for _,r in ipairs(p.reads) do log('READ phase=%s kind=%s target={%s} source_cue={%s} flags=%s elapsed_ms=%s success=%s returned_record_count=%s count_limited=%s',p.name,r.kind,describe(r.target),describe(owners[r.target]),r.flags,text(r.ms),text(r.ok),text(r.returned),text(r.countLimited==true)) end
 log('FEATURE_WORK phase=%s supplementary_feature_records_processed=%d combined_Part_and_feature_records=%d',p.name,p.featureRecords,p.records+p.featureRecords)
end
local returned,returnedKnown=0,true
for _,read in ipairs(h.reads) do if read.kind=='PART_COOKED' then if read.returned then returned=returned+read.returned else returnedKnown=false end end end
log('HYBRID_EXECUTION mode=FINAL_CANDIDATE_FOOTPRINTS executed=%s result_valid=%s candidates_before=%d candidates_after=%d selected_Parts=%d Parts_started=%d stream_advances_used=%d projected_eligible_key_positions=%d actual_cooked_records_inspected=%d sparse_keys_actually_inspected=%d cooked_records_returned=%s actual_record_limit=%d total_processed_record_limit=%d production_32_record_batching=false elapsed_limit_seconds=%d',text(h.executed),text(h.resultValid),h.candidatesBefore,count(hybrid),#selectedParts,#h.chunks,h.advances,plannedLookups,h.lookups,h.records,returnedKnown and text(returned) or 'UNAVAILABLE',LIMIT.lookups,LIMIT.records,LIMIT.seconds)
for _,p in ipairs({b,h}) do
 for _,name in ipairs({'Recipe_history_walk','group_selection_membership_expansion','eligible_key_set_construction','witness_Part_selection','chunk_plan_construction','candidate_resolution','cooked_stream_filtering'}) do
  log('STAGE_TIMING phase=%s stage=%s elapsed_ms=%s ran=%s exclusive=true',p.name,name,p.timingInvalid and 'UNAVAILABLE' or text(p.stages[name] or 0),text(p.stages[name]~=nil))
 end
end
log('SCOPE_WORK family_address_reads=%d mapping_calls=%d mapping_cache_hits=%d mapping_native_ms=%s attribute_calls=%d attribute_cache_hits=%d attribute_read_and_label_ms=%s mapping_iterations=%d unique_candidate_keys=%d key_construction_ms=%s candidate_transition_processing_ms=%s unrelated_records_discarded=%d',b.familyAddressReads or 0,b.scopeStats.mappingCalls,b.scopeStats.mappingHits,b.timingInvalid and 'UNAVAILABLE' or text(b.scopeStats.mappingMs),b.scopeStats.attributeCalls,b.scopeStats.attributeHits,b.timingInvalid and 'UNAVAILABLE' or text(b.scopeStats.attributeMs),b.scopeStats.rawMappingIterations,count(candidateKeys),text(h.keyConstructionMs),h.timingInvalid and 'UNAVAILABLE' or text(h.semanticMs),h.lookups-h.records)
log('FINAL_CANDIDATE_SCOPE final_candidate_count=%d source_Recipe_rows=%d reverse_index_unique_keys=%d candidate_record_routes=%d candidate_transition_operations=%d structural_superset_globally_proven=false snapshot_superset_status=%s',count(structural),b.finalSourceRows or 0,count(reverseIndex),h.routeOperations or 0,h.transitionOperations or 0,(okA and not baselineBad and stable and okB) and (count(structuralMissing)==0 and 'ORACLE_SNAPSHOT_SUPERSET_ONLY' or 'STRUCTURAL_NOT_SUPERSET_OF_ORACLE') or 'UNVERIFIED')
for _,ref in pairs(structuralMissing) do log('STRUCTURAL_SUPERSET_LIMITATION missing_final_candidate={%s} candidate_not_added_from_oracle=true',describe(ref)) end
for rid,fp in pairs(footprints) do
 local featureNames={}; for feature in pairs(fp.features) do featureNames[#featureNames+1]=feature end; table.sort(featureNames)
 log('CANDIDATE_FOOTPRINT DB_identity_id=%d candidate={%s} source_Recipe_rows=%d unique_UI_keys=%d source_Groups=%d feature_scope=%s layers=ABS_AND_REL layer_scope_structurally_unproven=true',rid,describe(fp.ref),#fp.rows,count(fp.keys),count(fp.groupIds),#featureNames>0 and table.concat(featureNames,',') or 'UNKNOWN_INCLUDE_ALL')
 for _,row in ipairs(fp.rows) do log('CANDIDATE_SOURCE candidate={%s} cue={%s} part={%s} recipe={%s} Group={%s} row_scope_UI_keys=%d all_source_events_retained=true',describe(fp.ref),describe(row.cue),describe(row.part),describe(row.recipe),describe(row.group),count(row.keys)) end
end
for rid,observed in pairs(h.outsideFootprint) do log('OUTSIDE_CANDIDATE_FOOTPRINT candidate={%s} observations=%d UI_key_sample=%s cue={%s} part={%s} layer_sample=%s candidate_support_not_inferred=true',describe(identities[rid]),observed.count,text(observed.index),describe(owners[observed.part]),describe(observed.part),observed.prefix) end
log('KEY_CONSTRUCTION candidate_footprint_and_reverse_index_ms=%s reverse_key_copy_ms=%s combined_key_construction_ms=%s total_candidate_transition_processing_ms=%s',b.timingInvalid and 'UNAVAILABLE' or text(b.stages.eligible_key_set_construction),text(h.keyConstructionMs),text(b.stages.eligible_key_set_construction and h.keyConstructionMs and b.stages.eligible_key_set_construction+h.keyConstructionMs),h.timingInvalid and 'UNAVAILABLE' or text(h.semanticMs))
log('SCOPE_ITERATIONS raw_mapping_entries=%d feature_filter_keys=%d candidate_group_merge_keys=%d reverse_index_links=%d total_bounded_scope_work=%d membership_entries=%d',b.scopeStats.rawMappingIterations,b.scopeStats.filterIterations,b.scopeStats.mergeIterations,b.scopeStats.indexOperations,b.scopeStats.iterations,b.scopeStats.membersVisited)
log('FOOTPRINT_CACHE group_membership_reads=%d group_membership_hits=%d group_key_builds=%d group_key_hits=%d filtered_scope_builds=%d filtered_scope_hits=%d per_invocation_only=true',b.scopeStats.groupMembershipReads,b.scopeStats.groupMembershipHits,b.scopeStats.groupKeyBuilds,b.scopeStats.groupKeyHits,b.scopeStats.filteredScopeBuilds,b.scopeStats.filteredScopeHits)
log('SKIPPED_HISTORY planned_history_Parts=%d selected_Parts=%d unselected_history_Parts=%d full_history_Part_coverage=true candidate_key_scope_completeness_unproven=true',#contexts,#selectedParts,#contexts-#selectedParts)
for i,unit in ipairs(h.units) do log('PART_STREAM number=%d stage=%s cue={%s} part={%s} eligible_keys=%d actual_returned_entries_inspected=%d matching_records_processed=%d filtered_out=%d completed=%s',i,unit.stage,describe(owners[unit.part]),describe(unit.part),unit.eligibleCount,unit.inspected or 0,unit.records or 0,(unit.inspected or 0)-(unit.records or 0),text(unit.completed==true)) end
for _,change in ipairs(h.changes) do
 local reasons={}; for reason,n in pairs(change.reasons or {}) do reasons[#reasons+1]=reason..':'..n end; table.sort(reasons)
 log('CANDIDATE_CHANGE action=%s reference={%s} reason=%s witnessed_layers=%s cooked_transition_reasons=%s applies_to_completed_hybrid=%s',change.action,describe(change.ref),change.reason,text(change.witnessLayers),table.concat(reasons,','),text(h.resultValid))
end
for rid,events in pairs(h.events) do for event,n in pairs(events) do log('TRANSITIONS candidate={%s} event=%s count=%d',describe(identities[rid]),event,n) end end
for _,event in pairs(h.eventRows) do
 log('TRANSITION_DETAIL candidate={%s} event=%s cue={%s} part={%s} source_cue={%s} source_part={%s} layer=%s UI_key_sample=%s matching_channels=%d feature={%s}',describe(identities[event.rid]),event.event,describe(owners[event.part]),describe(event.part),describe(owners[event.source]),describe(event.source),event.prefix,text(event.index),event.count,describe(safe(GetAttributeByUIChannel,event.index)))
end
for _,change in ipairs(h.changes) do if change.action=='REMOVED' then
 local d=h.decisive[id(change.ref)]
 if d then
  local replacements={}; for _,ref in ipairs(d.replacement) do replacements[#replacements+1]=describe(ref) end
  log('FIRST_DECISIVE candidate={%s} source_cue={%s} source_part={%s} decisive_cue={%s} decisive_part={%s} UI_key=%s layer=%s feature={%s} previous_reference={%s} replacement=%s released=%s exact_reason=%s first_decisive_loss_of_final_supported_layers=true all_witness_layers_cleared=true',describe(d.ref),describe(owners[d.source]),describe(d.source),describe(owners[d.part]),describe(d.part),text(d.index),d.prefix,describe(safe(GetAttributeByUIChannel,d.index)),describe(d.ref),table.concat(replacements,';'),text(d.released),d.reason)
 end
end end
for _,row in ipairs(structuralRows) do
 log('RECIPE source_cue={%s} source_part={%s} recipe={%s} Enabled=%s selection_raw=%s selection={%s} reference_field=%s raw_reference=%s reference={%s} DB_group_id=%s features=%s candidate_moving_type=%s layer=UNKNOWN group_overlap_possible=true',describe(row.cue),describe(row.part),describe(row.recipe),text(row.enabled),text(row.rawGroup),describe(row.group),row.field,text(row.rawRef),describe(row.ref),text(row.groupId),table.concat(row.features or {},','),text(row.moving))
 for feature,decision in pairs(row.lanes or {}) do log('LANE recipe={%s} feature=%s decision=%s status=PROVISIONAL_LAYER_UNPROVEN',describe(row.recipe),feature,decision) end
 local scoped={}; for feature in pairs(row.explicitFeatures or {}) do scoped[#scoped+1]=feature end; table.sort(scoped)
 log('SCOPE_FEATURES recipe={%s} explicit_value_source_or_generator_features=%s unknown_metadata_widens_scope=true Name_not_used_to_narrow=true',describe(row.recipe),#scoped>0 and table.concat(scoped,',') or 'UNKNOWN_OR_ALL')
end
for _,part in ipairs(selectedParts) do log('FALLBACK_SCOPE stage=%s cue={%s} part={%s} eligible_UI_keys=%d chunks=%d layers=ABS_AND_REL reason=explicit_ambiguous_current_scope_or_candidate_source_witness',planned[part].stage,describe(owners[part]),describe(part),count(keysByPart[part]),0) end
for _,issue in ipairs(ambiguous) do local row=issue.row or {}; log('AMBIGUITY reason=%s cue={%s} part={%s} recipe={%s} detail=%s blocks_hybrid=%s',issue.reason,describe(row.cue),describe(row.part),describe(row.recipe),text(issue.detail),text(issue.hard==true)) end
for _,pair in ipairs({{'BASELINE',baseline},{'STRUCTURAL',structural},{'HYBRID',hybrid}}) do for key,ref in pairs(pair[2]) do
 log('FINAL_SET phase=%s DB_identity_id=%d reference_type=%s reference={%s} candidate_result_valid=%s',pair[1],key,kind(ref),describe(ref),text(pair[1]~='HYBRID' or h.resultValid))
 if pair[1]=='BASELINE' and a.scan then
  local origins={}
  for index,layers in pairs(a.scan.tracked) do for prefix,item in pairs(layers) do for _,source in ipairs(item.refs) do
   if dbEqual(source,ref) then
    local part=item.probePart or false; origins[part]=origins[part] or {}; local origin=origins[part][prefix] or {count=0,sample=index}; origins[part][prefix]=origin; origin.count=origin.count+1
   end
  end end end
  for part,layers in pairs(origins) do for prefix,origin in pairs(layers) do log('ORACLE_LAYER reference={%s} channel_sample=%s layer=%s channels_in_origin=%d source_cue={%s} source_part={%s}',describe(ref),text(origin.sample),prefix,origin.count,describe(owners[part]),describe(part)) end end
 end
end end
for _,row in ipairs(candidateRows) do if row.cue==currentCue and row.moving then
 log('ORACLE_DIRECT_MERGE reference={%s} source_cue={%s} source_part={%s} recipe={%s} retained_even_without_cooked=true',describe(row.ref),describe(row.cue),describe(row.part),describe(row.recipe))
end end
for _,name in ipairs({'STRUCTURAL','HYBRID'}) do local c=comparisons[name]
 for _,ref in pairs(c.missing) do log('DIFF phase=%s classification=MISSING_REFERENCE exact_handle={%s}',name,describe(ref)) end
 for _,ref in pairs(c.extra) do log('DIFF phase=%s classification=EXTRA_REFERENCE exact_handle={%s}',name,describe(ref)) end
 log('RESULT phase=%s classification=%s baseline_final_refs=%d candidate_final_refs=%d missing=%s extra=%s candidate_result_valid=%s identity_only=true scope_completeness_proven=false exact_match_means_current_oracle_snapshot_only=true',name,c.classification,count(baseline),name=='STRUCTURAL' and count(structural) or count(hybrid),c.candidateValid and text(count(c.missing)) or 'UNAVAILABLE',c.candidateValid and text(count(c.extra)) or 'UNAVAILABLE',text(c.candidateValid))
end
local function reduction(v,base) return h.resultValid and base>0 and (1-v/base)*100 or nil end
log('REDUCTION hybrid_records=%d baseline_records_current=%d baseline_advances_current=%d historical_records=22764 historical_advances=731 records_vs_current_percent=%s records_vs_historical_percent=%s advances_vs_current_percent=%s advances_vs_historical_percent=%s',h.records,a.records,a.advances,text(reduction(h.records,a.records)),text(reduction(h.records,22764)),text(reduction(h.advances,a.advances)),text(reduction(h.advances,731)))
log('CANDIDATE_TOTAL structural_plus_hybrid_elapsed_ms=%s baseline_elapsed_ms=%s structural_GetPresetData_calls=%d full_cooked_fallback_executed=false full_cooked_scan_only_in_oracle=true',text(b.totalMs and h.totalMs and b.totalMs+h.totalMs),text(a.totalMs),#b.reads)
Printf('[CueStructAB] END context_stable=%s output_capped=%s baseline_valid=%s structural_classification=%s hybrid_classification=%s hybrid_executed=%s hybrid_result_valid=%s scope_completeness_proven=false production_modified=false markers_drawn=false',text(stable),text(outputCapped),text(okA and not baselineBad),outputCapped and 'UNVERIFIED' or comparisons.STRUCTURAL.classification,outputCapped and 'UNVERIFIED' or comparisons.HYBRID.classification,text(h.executed),text(h.resultValid))
return {baseline=baseline,structural=structural,hybrid=hybrid,profiles=profiles,comparisons=comparisons,ambiguities=ambiguous,stable=stable,hardBlocked=hardBlocked,rows=structuralRows,footprints=footprints,reverseIndex=reverseIndex,structuralMissing=structuralMissing,outputCapped=outputCapped}
end
