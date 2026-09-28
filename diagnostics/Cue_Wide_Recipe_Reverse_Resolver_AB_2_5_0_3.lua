-- Independent diagnostic; production SHA256 a6e15338449ef365fa152ef6400fe849d084f20a32d363b5bc8d6159314230b6.
return function()
-- Native Printf has stricter vararg types than Lua string.format.
local nativePrintf = _G.Printf
local oracleLogSink
local function Printf(fmt, ...)
    local line = select('#', ...) == 0 and tostring(fmt) or string.format(fmt, ...)
    if oracleLogSink then oracleLogSink(line) else nativePrintf("%s", line) end
end
local commandAddress, children, recipeNumber, generatorHasFeature
local GetPresetData, SelectedSequence, GetCurrentCue
local MAX_CUES, MAX_RECIPES, REFRESH_SECONDS = 512, 2048, 0.1
local ENABLE_CUE_PHASER_MARKERS = true -- private oracle only
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
-- Pure membership resolver. Input rows MUST be newest first, including static rows.
-- An unsafe newer row blocks older assertions rather than letting history shine through.
local function recipeReverseResolve(rows)
 local result={refs={},assignments={},unsafe={},rejected={},rowsSkipped=0,staticRows=0,movingRows=0,lanesResolved=0}
 local decided,blocked,globalBlock={},{},{}
 local work=0
 local function checkpoint() work=work+1; assert(work<=1048576,'Recipe reverse lane work limit exceeded') end
 for reverseIndex,row in ipairs(rows) do
  row.reverseIndex=reverseIndex
  row.survivors={}; row.movingSurvivors={}; row.movingEffective=false; row.staticEffective=false; row.superseded={}; row.effective=0
  local reasons=row.unsafe or {}
  if #reasons>0 then
   result.unsafe[#result.unsafe+1]=row
   if not row.members then globalBlock[#globalBlock+1]=row
   else for member in pairs(row.members) do
    checkpoint()
    blocked[member]=blocked[member] or {}
    if not row.features then blocked[member]['*']=blocked[member]['*'] or row
    else for feature in pairs(row.features) do
     if not row.layers then blocked[member][feature..'|*']=blocked[member][feature..'|*'] or row
     else for layer in pairs(row.layers) do blocked[member][feature..'|'..layer]=blocked[member][feature..'|'..layer] or row end end
    end end
   end end
  else
   local rowLanes=row.lanes or {}
   if not row.lanes then for feature in pairs(row.features) do for layer in pairs(row.layers) do rowLanes[feature..'|'..layer]={feature=feature,layer=layer,moving=row.moving} end end end
   for member in pairs(row.members) do
    decided[member]=decided[member] or {}
    for lane,laneState in pairs(rowLanes) do
     local feature,layer=laneState.feature,laneState.layer
     checkpoint()
     local old=decided[member][lane]
     local barrier=globalBlock[1]
     for _,key in ipairs({lane,feature..'|*','*'}) do
      local candidate=(blocked[member] or {})[key]
      if candidate and (not barrier or candidate.reverseIndex<barrier.reverseIndex) then barrier=candidate end
     end
     if old then row.superseded[#row.superseded+1]={member=member,lane=lane,newer=old}
     elseif barrier then
      row.superseded[#row.superseded+1]={member=member,lane=lane,newer=barrier,unsafe=true}
     else
      decided[member][lane]=row; row.effective=row.effective+1; row.survivors[member]=true
      result.lanesResolved=result.lanesResolved+1
      result.assignments[#result.assignments+1]={member=member,lane=lane,row=row}
      if laneState.moving then
       row.movingEffective=true
       row.movingSurvivors[member]=true
       local entry=result.refs[row.refId] or {ref=row.ref,members={},sources={}}
       result.refs[row.refId]=entry; entry.members[member]=true
       entry.sources[row]=true
      else row.staticEffective=true end
     end
    end
   end
   if row.effective==0 then result.rowsSkipped=result.rowsSkipped+1
   else
    if row.movingEffective then result.movingRows=result.movingRows+1 end
    if row.staticEffective then result.staticRows=result.staticRows+1 end
   end
  end
  if row.moving and #row.superseded>0 then result.rejected[#result.rejected+1]=row end
 end
 result.unresolved={}
 for member,lanes in pairs(blocked) do for lane,row in pairs(lanes) do
  if not (decided[member] or {})[lane] then result.unresolved[#result.unresolved+1]={member=member,lane=lane,row=row} end
 end end
 result.unknownSelectionRows=#globalBlock
 result.laneWork=work
 return result
end

-- Rev2: proof gates are documented in docs/cue-wide-recipe-value-source-rev2.md.
-- Native handles are retained. Labels, preset/attribute numbers and Shape presence
-- never classify features or motion. Raw layer mapping is from MA's 2.5 keypad.
local function newRecipeValueSourceAuditor(api)
 local function read(h,key)
  local v=api.safe(function() return h[key] end)
  if v==nil then v=api.safe(function() return h:Get(key) end) end
  return v
 end
 local function trim(v) return v~=nil and tostring(v):match('^%s*(.-)%s*$') or '' end
 local function empty(v) local s=trim(v):lower(); return s=='' or s=='empty' end
 local function meta(h)
  local m={}; local n=api.safe(function() return h:PropertyCount() end)
  if type(n)~='number' or n<0 or n>512 then return m end
  for i=0,n-1 do
   local key=api.safe(function() return h:PropertyName(i) end)
   if type(key)=='string' then
    m[key:lower()]={key=key,raw=read(h,key),type=api.safe(function() return h:PropertyType(i) end),info=api.safe(function() return h:PropertyInfo(i) end)}
   end
  end
  return m
 end
 local function raw(m,k) return m[k] and m[k].raw end
 local function resolve(v,expected)
  if api.isObject(v) then
   if not expected or api.class(v):lower()==expected then return v,'DIRECT_HANDLE' end
   return nil,'WRONG_CLASS_'..api.class(v)
  end
  if empty(v) then return nil,'EMPTY' end
  local s=trim(v)
  -- Exact command identities only, and exactly one class-checked result.
  if not s:match('^Attribute%s+[%d%.]+$') and not s:match('^Preset%s+[%d%.]+$')
     and not s:match('^Shape%s+[%d%.]+$') then return nil,'UNRESOLVED_PROPERTY_TYPE_'..type(v) end
  local list=api.safe(api.objectList,s)
  if type(list)=='table' and #list==1 and api.isObject(list[1]) and (not expected or api.class(list[1]):lower()==expected) then return list[1],'EXACT_OBJECTLIST' end
  return nil,'OBJECTLIST_NOT_UNIQUE_OR_WRONG_CLASS'
 end
 local function attrEvidence(v)
  local a,route=resolve(v,'attribute')
  if not a then return nil,nil,nil,route end
  -- Vendor system_test_ui_misc.lua uses Attribute.Feature:Parent() for FG.
  local feature=read(a,'Feature')
  if not api.isObject(feature) or api.class(feature):lower()~='feature' then return a,nil,nil,'ATTRIBUTE_FEATURE_HANDLE_UNAVAILABLE' end
  local fg=api.safe(function() return feature:Parent() end)
  if not api.isObject(fg) or api.class(fg):lower()~='featuregroup' then return a,feature,nil,'FEATUREGROUP_PARENT_UNAVAILABLE' end
  return a,feature,fg,'PROVEN_ATTRIBUTE_FEATURE_PARENT_'..route
 end
 local specials={none=true,release=true,remove=true,default=true,channelfunctiondefault=true,highlight=true,lowlight=true,zero=true,full=true}
 local function valueKind(v)
  if empty(v) then return 'EMPTY' end
  local s=trim(v):lower()
  if specials[s] then return s=='none' and 'NONE' or 'UNSUPPORTED_SPECIAL_'..s end
  local n=tonumber(s)
  local enum=api.enums and api.enums.PhaserRecipeValueSpecialsRaw
  if n and type(enum)=='table' then for name,value in pairs(enum) do
   if n==value then return name:lower()=='none' and 'NONE' or 'UNSUPPORTED_SPECIAL_'..name:lower() end
  end end
  -- Raw specials are encoded integers in the native API enum dump.
  if n and n==n and math.abs(n)<1000000 and n~=264 then return 'NUMERIC' end
  return 'UNSUPPORTED_RAW_ENCODING'
 end
 local function patternValue(v) local k=valueKind(v); return k=='NUMERIC' and 'NUMERIC' or k..':'..trim(v) end
 local function selectedMetadata(m)
  local out={}
  for key,p in pairs(m) do
   if key:find('layer',1,true) or key:find('value',1,true) or key:find('step',1,true)
      or key:find('motion',1,true) or key:find('multi',1,true) or key:find('phaser',1,true)
      or key:find('absolute',1,true) or key:find('relative',1,true) or key:find('data',1,true)
      or key:find('reference',1,true) or key=='enabled' or key=='preset' or key=='shape'
      or key=='feature' or key=='featuregroup' then
    out[#out+1]=p.key..'='..trim(p.raw)..'<'..tostring(p.type or '?')..'>'
   end
  end
  table.sort(out); return table.concat(out,';')
 end
 local function inspect(ref)
  local data={features={},layers={},lanes={},audits={},classes={},reasons={},sourceCount=0,stepCount=0,recipeCount=0,refMeta=selectedMetadata(meta(ref))}
  local complete=true; local featureComplete,layerComplete=true,true; local visited={}; local visitedCount=0
  local buckets={}; local hasOpaqueDependency=false
  local function reason(s) data.reasons[s]=true end
  local function source(node,recipe,step)
   local m=meta(node); local av=raw(m,'attributes') or raw(m,'attribute')
   local a,f,fg,attributeProof=attrEvidence(av)
   local fields={attribute=av,attributeProperty=m.attributes and m.attributes.key or (m.attribute and m.attribute.key),attributeHandle=a,feature=f,featureGroup=fg,attributeProof=attributeProof,
    abs=raw(m,'rawvalueabs'),rel=raw(m,'rawvaluerel'),shape=raw(m,'shape'),preset=raw(m,'preset'),layer=raw(m,'layer'),
    valueAbsolute=raw(m,'valueabsolute'),valueRelative=raw(m,'valuerelative'),node=node,sourceClass=api.class(node),metadata=selectedMetadata(m)}
   local inherited={}; local chain={}; local current=node; local cm=m
   -- Official popup selects Shape as a ValueSource handle. Follow that precise
   -- node only; never import all sibling lanes or use its parent step count.
   for depth=1,8 do
    local sv=raw(cm,'shape')
    if empty(sv) then break end
    local link,route=resolve(sv,'phaserrecipevaluesource')
    if not link or chain[link] or link==node then reason('SHAPE_VALUESOURCE_LINK_UNVERIFIED_'..route); complete=false; featureComplete=false; layerComplete=false; break end
    fields.shapeHandle=fields.shapeHandle or link
    chain[link]=true; inherited[#inherited+1]=api.desc(link)
    local lm=meta(link)
    if not empty(raw(lm,'preset')) then hasOpaqueDependency=true; reason('SHAPE_PRESET_DEPENDENCY_UNPROVEN'); complete=false; layerComplete=false end
    if empty(av) then av=raw(lm,'attributes') or raw(lm,'attribute'); a,f,fg,attributeProof=attrEvidence(av); attributeProof=attributeProof..'_SHAPE_VALUESOURCE_INHERITED' end
    for _,key in ipairs({'rawvalueabs','rawvaluerel'}) do
     if empty(raw(m,key)) and lm[key] then m[key]=lm[key] end
    end
    if depth==8 and not empty(raw(lm,'shape')) then reason('SHAPE_CHAIN_LIMIT'); complete=false; featureComplete=false; layerComplete=false end
    current=link; cm=lm
   end
   fields.attributeHandle,fields.feature,fields.featureGroup,fields.attributeProof=a,f,fg,attributeProof
   fields.effectiveAttribute=av
   fields.shapeChain=table.concat(inherited,' -> ')
   if not fg then reason('ATTRIBUTE_FEATUREGROUP_UNPROVEN_'..attributeProof); complete=false; featureComplete=false end
   local preset,presetRoute=resolve(fields.preset)
   fields.presetHandle=preset; fields.presetProof=presetRoute
   fields.presetMetadata=preset and selectedMetadata(meta(preset)) or ''
   local presetPresent=not empty(fields.preset)
   local presetValid=preset and (api.class(preset):lower()=='preset' or api.class(preset):lower()=='phaserrecipe')
   if presetPresent then hasOpaqueDependency=true end
   local laneReasons={}; local layerSet={}
   for _,spec in ipairs({{'rawvalueabs','abs','valueabsolute'},{'rawvaluerel','rel','valuerelative'}}) do
    local k,layer,virtual=spec[1],spec[2],spec[3]
    local kind=valueKind(raw(m,k))
    if kind=='NUMERIC' then
     -- A referenced Preset may replace the authored cell. Require the exposed
     -- effective ValueAbsolute/Relative numeric property too; raw alone is not
     -- proof of the Preset's applicable layer.
     if presetPresent and (not presetValid or valueKind(raw(m,virtual))~='NUMERIC') then
      laneReasons[#laneReasons+1]='PRESET_EFFECTIVE_'..layer..'_UNPROVEN'; complete=false
     else layerSet[layer]=true end
    elseif kind~='EMPTY' and kind~='NONE' then
     laneReasons[#laneReasons+1]=layer..'_'..kind; complete=false
    end
   end
   if next(layerSet)==nil then laneReasons[#laneReasons+1]='NO_PROVEN_AUTHORED_LAYER'; complete=false end
   if #laneReasons>0 then layerComplete=false end
   fields.layerProof=#laneReasons==0 and 'PROVEN_MA25_KEYPAD_RAW_LAYER_MAPPING' or table.concat(laneReasons,',')
   fields.effectiveAbs,fields.effectiveRel=raw(m,'rawvalueabs'),raw(m,'rawvaluerel')
   fields.proposed='feature='..(fg and api.desc(fg) or 'UNPROVEN')..' layers='..api.joined(layerSet)
   if fg then
    local featureKey='FG:'..tostring(api.id(fg)); data.features[featureKey]=true
    for layer in pairs(layerSet) do
     local key=featureKey..'|'..layer
     buckets[key]=buckets[key] or {attributes={},feature=featureKey,layer=layer}
     if a and step and recipe then
      local aid=api.id(a); buckets[key].attributes[aid]=buckets[key].attributes[aid] or {}
      buckets[key].attributes[aid][step]=recipe
     end
     data.layers[layer]=true
    end
   end
   for _,r in ipairs(laneReasons) do reason(r) end
   data.sourceCount=data.sourceCount+1; data.audits[#data.audits+1]=fields
  end
  local function visit(node,depth,recipe,step)
   if depth>8 or visitedCount>=512 or visited[node] then complete=false; featureComplete=false; layerComplete=false; reason('TREE_LIMIT_OR_CYCLE'); return end
   visited[node]=true; visitedCount=visitedCount+1
   local kind=api.class(node):lower(); data.classes[api.class(node)]=true
   if kind=='phaserrecipe' then recipe=node; step=nil; data.recipeCount=data.recipeCount+1 end
   if kind=='phaserrecipestep' then step=node; data.stepCount=data.stepCount+1 end
   if kind=='phaserrecipevaluesource' then source(node,recipe,step) end
   if kind=='randomchannel' or kind=='generatorchannel' then
    -- Generator attribute metadata is audited, but the channel layer semantics
    -- have no demonstrated raw-value mapping. No absolute default.
    local m=meta(node); local av=raw(m,'attribute') or raw(m,'attributes')
    local a,f,fg,proof=attrEvidence(av)
    data.audits[#data.audits+1]={node=node,sourceClass=api.class(node),attribute=av,attributeProperty=m.attribute and m.attribute.key or (m.attributes and m.attributes.key),attributeHandle=a,feature=f,featureGroup=fg,attributeProof=proof,layer=raw(m,'layer'),proposed='GENERATOR_LAYER_UNPROVEN',layerProof='GENERATOR_LAYER_UNPROVEN',metadata=selectedMetadata(m)}
    if fg then data.features['FG:'..tostring(api.id(fg))]=true else featureComplete=false end
    complete=false; layerComplete=false; reason('GENERATOR_LAYER_UNPROVEN')
   end
   local childList=api.safe(function() return node:Children() end)
   if type(childList)~='table' then complete=false; featureComplete=false; layerComplete=false; reason('TREE_CHILDREN_UNREADABLE'); return end
   for _,child in ipairs(childList) do visit(child,depth+1,recipe,step) end
  end
  visit(ref,0)
  if next(data.features)==nil then reason('NO_PROVEN_FEATURE_SCOPE') end
  if next(data.layers)==nil then reason('NO_PROVEN_LAYER_SCOPE') end
  if data.sourceCount==0 then complete=false; reason('OPAQUE_REFERENCE_NO_VALUESOURCES') end
  local anyMoving=false
  for key,bucket in pairs(buckets) do
   local moving
   local first=true
   for _,steps in pairs(bucket.attributes) do
    local n=api.count(steps); local attributeMoving
    if data.recipeCount==1 and n>1 then attributeMoving=true
    elseif data.recipeCount==1 and n==1 and not hasOpaqueDependency then attributeMoving=false end
    if first then moving=attributeMoving; first=false
    elseif attributeMoving~=moving then complete=false; featureComplete=false; moving=nil; reason('MIXED_ATTRIBUTE_MOTION_WITHIN_FEATUREGROUP'); break end
   end
   if moving==nil then complete=false; reason('MOTION_UNPROVEN_EFFECTIVE_STEPS_OR_PRESET_DEPENDENCY')
   else data.lanes[key]={feature=bucket.feature,layer=bucket.layer,moving=moving}; if moving then anyMoving=true end end
  end
  data.motionReason='PROVEN_PER_LANE_AUTHORED_STEP_COUNT'
  if not complete then data.motionReason='UNSAFE:'..api.joined(data.reasons) end
  if api.isGenerator(ref) then data.motionReason='GENERATOR_CLASS_PROVEN_LAYER_UNPROVEN' end
  data.proven=complete and next(data.lanes)~=nil
  data.featureProven=featureComplete and next(data.features)~=nil
  data.layerProven=layerComplete and next(data.layers)~=nil
  data.moving=data.proven and anyMoving or nil
  -- Preserve a proven static false rather than Lua's and/or false-to-nil idiom.
  if data.proven then data.moving=anyMoving end
  for _,a in ipairs(data.audits) do
   a.confidence=data.proven and 'PROVEN_SUPPORTED_SUBSET' or 'UNSAFE'
   a.reason=api.joined(data.reasons)
   a.motionReason=data.motionReason
   a.proposed=(a.proposed or '')..' recipes='..tostring(data.recipeCount)..' steps='..tostring(data.stepCount)..' lanes='..api.joined(data.lanes)
   a.pattern=table.concat({a.sourceClass,api.class(a.attributeHandle),api.desc(a.featureGroup),
    patternValue(a.abs),patternValue(a.rel),api.class(a.shapeHandle),api.class(a.presetHandle),a.layerProof or '',
    tostring(data.recipeCount),tostring(data.stepCount),a.confidence,a.reason},'|')
  end
  if #data.audits==0 then
   data.audits[1]={sourceClass='NONE',proposed='OPAQUE_REFERENCE',confidence='UNSAFE',reason=api.joined(data.reasons),motionReason=data.motionReason,pattern=api.class(ref)..'|OPAQUE|'..data.refMeta}
  end
  return data
 end
 return {inspect=inspect,metadata=meta,selectedMetadata=selectedMetadata}
end

-- Rev3 is observational: none of this evidence is fed into reverse tracking.
local function newReferenceSemanticsAudit(api)
 local function repr(v)
  if api.isObject(v) then return api.class(v)..':'..api.desc(v) end
  return type(v)..':'..tostring(v)
 end
 local function inspect(h)
  local m=api.metadata(h); local keys={}; for k in pairs(m) do keys[#keys+1]=k end; table.sort(keys)
  local values,links={},{}
  for _,k in ipairs(keys) do
   local p=m[k]; local v=p.raw
   -- Enumerated property identity is retained separately from a getter result.
   values[#values+1]=p.key..'{'..tostring(p.type)..'}='..repr(v)
   if api.isObject(v) then links[#links+1]=p.key..'->'..repr(v) end
  end
  local probes={}
  for _,k in ipairs({'Layer','ValueLayer','Mode','Relative','RawValueAbs','RawValueRel','ValueAbsolute','ValueRelative','Feature','FeatureGroup','PresetPoolType','OwnDataPresent'}) do
   local direct=api.safe(function() return h[k] end)
   local get=api.safe(function() return h:Get(k) end)
   probes[#probes+1]=k..':enumerated='..tostring(m[k:lower()]~=nil)..',direct='..repr(direct)..',get='..repr(get)
  end
  return table.concat(values,';'),table.concat(links,';'),table.concat(probes,';')
 end
 return function(ref,data,recipe)
  local pool=api.safe(function() return ref:Parent() end)
  local props,links,probes=inspect(ref)
  local poolProps,poolLinks,poolProbes=inspect(pool)
  local rowProps,rowLinks,rowProbes=inspect(recipe)
  local seen,classes,attributes,steps,shapes,dependencies={}, {},{},{},{},{}
  local nodes,truncated=0,false
  local function walk(h,depth)
   if not api.isObject(h) or seen[h] then return end
   if depth>8 or nodes>=512 then truncated=true; return end
   seen[h]=true; nodes=nodes+1
   local c=api.class(h); classes[c]=(classes[c] or 0)+1
   local p,l,q=inspect(h)
   if c:lower()=='phaserrecipestep' then steps[#steps+1]=api.desc(h)..' props='..p..' probes='..q end
   local m=api.metadata(h)
   for _,v in pairs(m) do
    local a=v.raw
    if api.isObject(a) and api.class(a):lower()=='attribute' then
     local f=api.safe(function() return a.Feature end); local fg=api.safe(function() return f:Parent() end)
     attributes[#attributes+1]=v.key..'->'..repr(a)..' Feature='..repr(f)..' FeatureGroup='..repr(fg)
    end
    if api.isObject(a) and (api.class(a):lower()=='shape' or v.key:lower()=='shape') then shapes[#shapes+1]=v.key..'->'..repr(a) end
   end
   if c:lower()=='phaserrecipevaluesource' then steps[#steps+1]='ValueSource='..api.desc(h)..' parent='..repr(api.safe(function() return h:Parent() end))..' props='..p..' probes='..q end
   for _,child in ipairs(api.safe(function() return h:Children() end) or {}) do walk(child,depth+1) end
  end
  walk(ref,0)
  local deps=api.safe(function() return ref:GetDependencies() end)
  if type(deps)=='table' then for _,d in pairs(deps) do dependencies[#dependencies+1]=repr(d) end; table.sort(dependencies)
  else dependencies[1]='UNAVAILABLE:'..type(deps) end
  local motion=data.proven and (data.moving and 'MOTION_PROVEN' or 'STATIC_PROVEN') or 'MOTION_UNPROVEN'
  local classPattern={}; for c,n in pairs(classes) do classPattern[#classPattern+1]=c..':'..n end; table.sort(classPattern)
  -- Pattern includes exact evidence, so dissimilar values cannot be hidden by deduplication.
  local key=table.concat({api.class(ref),api.class(pool),props,poolProps,table.concat(classPattern,','),motion},'|')
  return {key=key,pool=pool,props=props,links=links,probes=probes,poolProps=poolProps,poolLinks=poolLinks,poolProbes=poolProbes,
   rowProps=rowProps,rowLinks=rowLinks,rowProbes=rowProbes,classes=table.concat(classPattern,','),attributes=table.concat(attributes,';'),
   steps=steps,shapes=table.concat(shapes,';'),dependencies=table.concat(dependencies,';'),truncated=truncated,
   feature=data.featureProven==true,layer=data.layerProven==true,motion=motion,
   reason=api.joined(data.reasons),stepCount=data.stepCount or 0}
 end
end

-- Rev4 reference-only, run-local cache. No Cue/Part readers and no oracle input.
local function newReferenceMetadataCache(api)
 local cache,rawCache,timings,allowed,unidentified={},{},{},{},{}
 local stats={distinct_references=0,calls=0,cache_hits=0,COMPLETE=0,PARTIAL=0,UNKNOWN=0,native_ms=0,max_ms=0,normalization_ms=0,timing_valid=true}
 local function elapsed(a) local b=api.now(); if type(a)~='number' or type(b)~='number' or b<a then stats.timing_valid=false; return 0 end; return (b-a)*1000 end
 local function identity(h)
  if not api.isObject(h) then return nil end
  local n=api.safe(api.handleToInt,h)
  if type(n)=='number' and math.type(n)=='integer' and n~=0 then return 'DBI:'..tostring(n) end
  local s=api.safe(api.handleToStr,h)
  if type(s)=='string' and s:match('^H#[%x]+$') then return 'DBH:'..s end
  return nil
 end
 local function unknown(reason) return {features={},layers={},lanes={},motion='UNSAFE',completeness='UNKNOWN',evidence=reason} end
 local function normalize(raw,ref)
  local m=unknown('UNRECOGNIZED_REFERENCE_DATA'); local reasons={}
  local records,good,bad,totalSteps=0,0,0,0
  local function fail(reason) bad=bad+1; reasons[reason]=true end
  m.featureScopeKnown=true; m.layerScopeKnown=true; m.attributeEvidence={}; m.layerEvidence={}
  local function feature(index,record)
   local attr=record.attribute
   if attr==nil then attr=api.safe(api.attributeByUIChannel,index) end
   if not api.isObject(attr) or api.class(attr):lower()~='attribute' then return nil end
   local f=api.safe(function() return attr.Feature end)
   if not api.isObject(f) or api.class(f):lower()~='feature' then return nil end
   local fg=api.safe(function() return f:Parent() end)
   if not api.isObject(fg) or api.class(fg):lower()~='featuregroup' then return nil end
   local key=identity(fg); if not key then return nil end
   if #m.attributeEvidence<8 then
    local function handleEvidence(h) return api.desc and api.desc(h) or identity(h) or 'NATIVE_HANDLE_ID_UNAVAILABLE' end
    m.attributeEvidence[#m.attributeEvidence+1]='UI='..index..' Attribute='..handleEvidence(attr)..' Feature='..handleEvidence(f)..' FeatureGroup='..handleEvidence(fg)
   end
   return 'FG:'..key
  end
  if type(raw)~='table' then return unknown('RETURN_TYPE_'..type(raw)) end
  local phaserFields={abs_preset=true,rel_preset=true,abs_generator=true,rel_generator=true,generator=true,
   speed=true,phase=true,measure=true,fade=true,delay=true,grid=true,grid_origin=true,grid_matrix=true,gridpos=true,attribute=true,
   mask_active=true,mask_individual=true,mask_integrated=true}
  local stepFields={absolute=true,relative=true,abs_release=true,rel_release=true,abs_remove=true,rel_remove=true,
   abs_preset=true,rel_preset=true,integrated=true,accel=true,decel=true,transition=true,trans=true,width=true,channel_function=true,
   mask_active=true,mask_individual=true,mask_integrated=true}
  local shape={}; for k,v in pairs(raw) do if #shape<12 then shape[#shape+1]=type(k)..':'..tostring(k)..'='..type(v) end end; table.sort(shape)
  m.raw_shape=table.concat(shape,',')
  for index,p in pairs(raw) do
   if index=='count' then
    if type(p)~='number' or p<0 or p%1~=0 then fail('INVALID_COUNT_HEADER') end
   elseif index=='by_fixtures' then
    if p~=false then fail('EXPECTED_UI_CHANNEL_DATA') end
   elseif type(index)~='number' or index<0 or index%1~=0 or type(p)~='table' then fail('UNSUPPORTED_TOP_LEVEL_FIELD_'..tostring(index)); m.featureScopeKnown=false
   else
    records=records+1; if records>262144 then fail('REFERENCE_RECORD_LIMIT'); break end
    local fg=feature(index,p)
    if not fg then fail('ATTRIBUTE_FEATUREGROUP_UNRESOLVED'); m.featureScopeKnown=false else m.features[fg]=true end
    for k in pairs(p) do if type(k)~='number' and not phaserFields[k] then fail('UNKNOWN_PHASER_FIELD_'..tostring(k)); m.featureScopeKnown=false; m.layerScopeKnown=false end end
    local n={ABS=0,REL=0}; local release={}; local indices={}; local steps=0
    for stepIndex,step in pairs(p) do
     if type(stepIndex)=='number' then
      if stepIndex<1 or stepIndex%1~=0 or type(step)~='table' then fail('INVALID_STEP')
      else
       steps=steps+1; totalSteps=totalSteps+1; if totalSteps>262144 then fail('REFERENCE_STEP_LIMIT'); break end; indices[stepIndex]=true
       for k in pairs(step) do if not stepFields[k] then fail('UNKNOWN_STEP_FIELD_'..tostring(k)); m.layerScopeKnown=false end end
       for _,lane in ipairs({{'ABS','absolute','abs'},{'REL','relative','rel'}}) do
        local layer,valueKey,prefix=table.unpack(lane); local v=step[valueKey]
        if v~=nil then
         if type(v)=='number' and v==v and math.abs(v)<math.huge then n[layer]=n[layer]+1
         else fail('NON_NUMERIC_'..valueKey) end
        end
        local r=step[prefix..'_release']; local remove=step[prefix..'_remove']
        if r~=nil and type(r)~='boolean' then fail('INVALID_RELEASE_FLAG') end
        if remove~=nil and remove~=false then fail('REMOVE_SEMANTICS_UNPROVEN') end
        if r==true and v~=nil then fail('RELEASE_WITH_NUMERIC_VALUE_UNPROVEN') end
        if r==true then release[layer]=true; if v==nil then n[layer]=n[layer]+1 end end
        if (step[prefix..'_preset']~=nil or (prefix=='abs' and step.integrated~=nil)) and v==nil and r~=true then fail('OPAQUE_STEP_DEPENDENCY') end
       end
      end
     end
    end
    for i=1,steps do if not indices[i] then fail('SPARSE_STEP_INDICES'); break end end
    if steps==0 then fail('NO_EFFECTIVE_STEPS') end
    local touched=false
    for _,layer in ipairs({'ABS','REL'}) do
     local prefix=layer=='ABS' and 'abs' or 'rel'
     if n[layer]==0 and (p[prefix..'_preset']~=nil or p[prefix..'_generator']~=nil or (layer=='ABS' and p.generator~=nil)) then fail('OPAQUE_LAYER_DEPENDENCY') end
     if n[layer]>0 then
      touched=true; m.layers[layer]=true
      if n[layer]~=steps then fail('INCOMPLETE_LAYER_STEPS') end
      if release[layer] and (n[layer]>1 or steps>1) then fail('MIXED_RELEASE_STEPS') end
      local moving=n[layer]>1 and not release[layer]
      if #m.layerEvidence<16 then m.layerEvidence[#m.layerEvidence+1]='UI='..index..':'..layer..' effective_steps='..n[layer]..' release='..tostring(release[layer]==true) end
      local generator=p[prefix..'_generator']; if layer=='ABS' and generator==nil then generator=p.generator end
      if generator~=nil then
       if api.isObject(generator) and ({generator=true,randomgenerator=true})[api.class(generator):lower()] then moving=true
       else fail('GENERATOR_CLASS_UNPROVEN') end
      end
      if fg then
       local key=fg..'|'..layer; local old=m.lanes[key]
       if old and old.moving~=moving then fail('MIXED_MOTION_WITHIN_FEATURE_LAYER') end
       m.lanes[key]={feature=fg,layer=layer,moving=moving,release=release[layer]==true}
       good=good+1
      end
     end
    end
    if not touched then fail('NO_PROVEN_LAYER'); m.layerScopeKnown=false end
   end
  end
  if raw.count~=nil and raw.count~=records then fail('COUNT_HEADER_MISMATCH') end
  m.records=records
  if records==0 then fail('EMPTY_REFERENCE_DATA') end
  local a={}; for reason in pairs(reasons) do a[#a+1]=reason end; table.sort(a)
  m.evidence='UI_CHANNEL_RECORDS='..records..'; EFFECTIVE_STEPS='..totalSteps..'; '..table.concat(a,',')
  if good>0 and bad==0 then
   m.completeness='COMPLETE'; m.motion='STATIC'
   for _,lane in pairs(m.lanes) do if lane.moving then m.motion='MOVING' end end
   if ({generator=true,randomgenerator=true})[api.class(ref):lower()] then
    m.motion='GENERATOR'; for _,lane in pairs(m.lanes) do lane.moving=true end
   end
  elseif good>0 then m.completeness='PARTIAL' end
  return m
 end
 local function admit(ref)
  local c=api.class(ref):lower()
  assert(c~='cue' and c~='part' and c~='cuepart' and c~='sequence','METADATA_FORBIDDEN_TARGET_'..c)
  if not ({preset=true,generator=true,randomgenerator=true})[c] then return nil,'UNSUPPORTED_REFERENCE_CLASS_'..c end
  local key=identity(ref); if not key then return nil,'STABLE_DB_IDENTITY_UNAVAILABLE' end
  return key
 end
 local function register(ref)
  local key,reason=admit(ref)
  if key then
   if not allowed[key] then stats.distinct_references=stats.distinct_references+1; allowed[key]=true end
  elseif not unidentified[ref] then
   unidentified[ref]=unknown(reason); stats.distinct_references=stats.distinct_references+1; stats.UNKNOWN=stats.UNKNOWN+1
  end
  return key,reason
 end
 local function get(ref)
  local key,reason=admit(ref)
  if not key then return unidentified[ref] or unknown(reason) end
  assert(allowed[key],'METADATA_TARGET_NOT_RECIPE_REFERENCE')
  if cache[key] then stats.cache_hits=stats.cache_hits+1; return cache[key] end
  -- Cache even failed reads: at most one actual call per stable DB identity.
  cache[key]=unknown('READ_PENDING')
  assert(allowed[key],'METADATA_TARGET_NOT_RECIPE_REFERENCE')
  if api.validateTarget then api.validateTarget(ref,key) end
  api.log('REFERENCE_METADATA_GETPRESETDATA target_class=%s identity=%s',api.class(ref),key)
  local start=api.now(); stats.calls=stats.calls+1
  local ok,raw=pcall(api.read,ref,false,false)
  local native=elapsed(start); stats.native_ms=stats.native_ms+native; stats.max_ms=math.max(stats.max_ms,native)
  local ns=api.now(); local normOK,m=pcall(normalize,ok and raw or nil,ref)
  if not normOK then m=unknown('NORMALIZATION_ERROR_'..tostring(m)) end
  if not ok then m=unknown('REFERENCE_READ_ERROR_'..tostring(raw)) end
  local normalized=elapsed(ns)
  stats.normalization_ms=stats.normalization_ms+normalized
  timings[key]={read_ms=native,normalization_ms=normalized}
  if ok and type(raw)=='table' then rawCache[key]=raw end
  cache[key]=m; stats[m.completeness]=stats[m.completeness]+1
  return m
 end
 return {get=get,register=register,registerDependency=register,identity=identity,stats=stats,cache=cache,raw=rawCache,timings=timings,normalize=normalize}
end

-- Rev5 candidate. Rev4 normalize/cache result is immutable before this module runs.
local function newReferenceMetadataBridge(api)
 local proof=api.fieldSemantics -- nil for the immutable Rev5 baseline
 local function fields(t,sample)
  local a={}
  for k,v in pairs(t or {}) do
   local value
   if type(v)=='table' then
    local nested={}; local n=0
    for sk,sv in pairs(v) do
     n=n+1
     if n<=6 then nested[#nested+1]=tostring(sk)..':'..type(sv)..(sample and '='..tostring(sv) or '') end
    end
    table.sort(nested); value='{count='..n..';'..table.concat(nested,',')..'}'
   elseif sample or type(v)=='boolean' or (type(k)=='string' and k:find('mask',1,true)) then value=tostring(v)
   else value=type(v) end
   a[#a+1]=tostring(k)..':'..type(v)..'='..value
  end
  table.sort(a); return table.concat(a,',')
 end
 local function result(source)
  return {source=source,features={},layers={},lanes={},featureScopeKnown=true,layerScopeKnown=true,motion='UNSAFE',completeness='UNKNOWN',evidence={},observations={},patterns={},examples={},channels=0,
   structuralSteps=0,valueSources=0,shapes=0,dependencies=0,samples={},phaserStructure=false,motionProof='MOTION_UNPROVEN'}
 end
 local function reason(m,r)
  m.evidence[r]=true
  if r:find('UNSUPPORTED_TOP_LEVEL',1,true) or r:find('UNKNOWN_PHASER_FIELD',1,true)
     or r:find('ATTRIBUTE_FEATURE_UNPROVEN',1,true) or r:find('VALUESOURCE_ATTRIBUTE_FEATURE_UNPROVEN',1,true)
     or r:find('DICT_INDEX_SHAPE',1,true) then m.featureScopeKnown=false end
  if r:find('UNSUPPORTED_TOP_LEVEL',1,true) or r:find('UNKNOWN_',1,true)
     or r:find('LAYER',1,true) or r:find('MASK',1,true) or r:find('GRID_MATRIX',1,true)
     or r:find('DICT_',1,true) or r:find('DICTIONARY_',1,true)
     or r:find('LINKED_PRESET',1,true) or r:find('POSSIBLE_MOTION',1,true) then m.layerScopeKnown=false end
 end
 local function feature(attr)
  if not api.isObject(attr) or api.class(attr):lower()~='attribute' then return nil end
  local f=api.safe(function() return attr.Feature end)
  if not api.isObject(f) or api.class(f):lower()~='feature' then return nil end
  local fg=api.safe(function() return f:Parent() end)
  if not api.isObject(fg) or api.class(fg):lower()~='featuregroup' then return nil end
  local id=api.identity(fg); if not id then return nil end
  return 'FG:'..id
 end
 local function finite(v)
  if type(v)~='number' and type(v)~='string' then return false end
  local n=tonumber(v); return n~=nil and n==n and math.abs(n)<math.huge
 end
 -- Rev11: Universal/Global linked Presets need no fixture-specific membership
 -- proof. Only member-applicability evidence is excused; every other reason,
 -- and the independent Attribute/Feature/Layer checks, still blocks.
 local memberApplicabilityEvidence={SELECTIVE_MEMBER_APPLICABILITY_UNPROVEN=true,INDIVIDUAL_MEMBER_APPLICABILITY_UNPROVEN=true,GRID_POSITION_EFFECT_UNPROVEN=true,GRID_MATRIX_EFFECT_UNPROVEN=true,ACTIVE_GRID_POSITION_APPLICABILITY_UNPROVEN=true}
 local function onlyMemberApplicabilityEvidence(m)
  if type(m)~='table' or type(m.evidence)~='table' then return false end
  local any=false
  for k in pairs(m.evidence) do if not memberApplicabilityEvidence[k] then return false end; any=true end
  return any
 end
 local function linkedPresetMode(linked)
  local mode=api.safe(function() return linked.PresetMode end)
  if mode==nil then mode=api.safe(function() return linked:Get('PresetMode') end) end
  return mode
 end
 local function finish(m)
  local has=false; for _ in pairs(m.lanes) do has=true end
  if has and not next(m.evidence) then
   m.completeness='COMPLETE'; m.motion='STATIC'
   if m.source=='ORDINARY_GETPRESETDATA' then m.motionProof='STATIC_PROVEN_ALL_EFFECTIVE_CHANNELS' end
   for _,lane in pairs(m.lanes) do if lane.moving then m.motion='MOVING' end end
  elseif has then m.completeness='PARTIAL' end
  return m
 end
 local function ordinary(raw)
  local m=result('ORDINARY_GETPRESETDATA')
  if type(raw)~='table' then reason(m,'REFERENCE_DATA_UNAVAILABLE'); return m end
  for ui,p in pairs(raw) do
   if ui=='count' then if type(p)~='number' then reason(m,'INVALID_COUNT') end
   elseif ui=='by_fixtures' then if p~=false then reason(m,'NOT_UI_CHANNEL_INDEXED') end
   elseif type(ui)~='number' or type(p)~='table' then reason(m,'UNSUPPORTED_TOP_LEVEL_'..tostring(ui))
   else
    m.channels=m.channels+1
    if m.channels>262144 then reason(m,'CHANNEL_LIMIT'); break end
    local attr=p.attribute or api.safe(api.attributeByUIChannel,ui)
    local fg=feature(attr)
    if not fg then reason(m,'ATTRIBUTE_FEATURE_UNPROVEN') else m.features[fg]=true end
    local pattern=fields(p); m.patterns[pattern]=(m.patterns[pattern] or 0)+1
    if not m.examples[pattern] then m.examples[pattern]=fields(p,true) end
    local known={attribute=true,abs_preset=true,rel_preset=true,abs_generator=true,rel_generator=true,generator=true,
      mask_active_phaser=true,mask_active_value=true,mask_cooked=true,mask_individual=true,mask_integrated=true,
      dict_flags=true,dict_index=true,gridposmatr=true,gridpos=true,grid=true,phase=true,speed=true,
      measure=true,fade=true,delay=true,selective=true,preset_store_mode=true,grid_origin=true,grid_matrix=true,
      nshot_count=true,nshot_flags=true,speed_master=true}
    for k,v in pairs(p) do
     if type(k)~='number' and not known[k] and not (proof and proof.accept('channel',k,v,p,ui)) then reason(m,'UNKNOWN_PHASER_FIELD_'..tostring(k)) end
     if type(k)=='string' and ({speed=true,phase=true,measure=true,nshot_count=true,abs_generator=true,rel_generator=true,generator=true})[k]
        and v~=nil and v~=0 and v~=false then reason(m,'POSSIBLE_MOTION_FIELD_'..k) end
    end
    -- Vendor 2.5 tests define these masks as active phaser/value flags; they
    -- are checked, never discarded merely because another numeric step exists.
    if p.mask_active_phaser~=nil and (type(p.mask_active_phaser)~='number' or p.mask_active_phaser~=0 and p.mask_active_phaser~=64) then reason(m,'ACTIVE_PHASER_MASK_UNPROVEN') end
    if p.mask_cooked~=nil and (type(p.mask_cooked)~='number' or p.mask_cooked~=0) then reason(m,'COOKED_MASK_SEMANTICS_UNPROVEN') end
    if p.dict_flags~=nil then
     if type(p.dict_flags)~='table' then reason(m,'DICTIONARY_FLAGS_UNPROVEN')
     else for k,v in pairs(p.dict_flags) do if ({blocked=true,blocked_rel=true})[k] then
       if v~=false and v~=0 then reason(m,'BLOCKED_DICTIONARY_LAYER_'..k) end
      elseif v~=false and v~=0 and v~=nil and not (proof and proof.accept('dict_flags',k,v,p,ui)) then reason(m,'UNKNOWN_ACTIVE_DICTIONARY_FLAG_'..tostring(k)) end end end
    end
    if type(p.mask_active_value)=='number' and p.mask_active_value & (1|8|16|32|64)~=0 then reason(m,'ACTIVE_VALUE_SHAPE_MASK_UNPROVEN') end
    if p.dict_index~=nil and not (type(p.dict_index)=='number' and p.dict_index>=0 and p.dict_index%1==0) then reason(m,'DICT_INDEX_SHAPE_UNPROVEN') end
    if p.gridposmatr~=nil and (type(p.gridposmatr)~='table' or next(p.gridposmatr)~=nil) then reason(m,'GRID_MATRIX_EFFECT_UNPROVEN') end
    local steps,seen={},{}; local touchedMask=0
    for k,v in pairs(p) do
     if type(k)=='number' then
      if k<1 or k%1~=0 or type(v)~='table' then reason(m,'INVALID_STEP_SHAPE') else steps[#steps+1]=v; seen[k]=true end
     end
    end
    if #steps==0 then reason(m,'NO_STEP') end
    if #steps>1 then reason(m,'MULTISTEP_NOT_STATIC') end
    for k=1,#steps do if not seen[k] then reason(m,'SPARSE_STEPS') end end
    for _,step in ipairs(steps) do
     local stepKnown={absolute=true,relative=true,abs_release=true,rel_release=true,abs_remove=true,rel_remove=true,
      abs_preset=true,rel_preset=true,integrated=true,accel=true,decel=true,trans=true,transition=true,width=true,
      channel_function=true,mask_active=true,mask_individual=true,mask_integrated=true,dict_flags=true}
     for k,v in pairs(step) do if not stepKnown[k] and v~=nil and not (proof and proof.accept('step',k,v,p,ui,step)) then reason(m,'UNKNOWN_STEP_FIELD_'..tostring(k)) end end
     for _,spec in ipairs({{'ABS','absolute','abs',2},{'REL','relative','rel',4}}) do
      local layer,value,prefix,bit=table.unpack(spec); local v=step[value]; local release=step[prefix..'_release']
      if v~=nil or release==true then
       touchedMask=touchedMask | bit
       if v~=nil and not finite(v) then reason(m,'NON_NUMERIC_'..layer) end
       if release==true and v~=nil then reason(m,'RELEASE_WITH_VALUE_'..layer) end
       if step[prefix..'_remove']==true then reason(m,'REMOVE_SEMANTICS_'..layer) end
       if p.mask_active_value~=nil and (type(p.mask_active_value)~='number' or p.mask_active_value & bit==0) then reason(m,'INACTIVE_VALUE_MASK_'..layer) end
       if fg then
        local lane=fg..'|'..layer; m.layers[layer]=true
        if m.lanes[lane] and m.lanes[lane].release~=(release==true) then reason(m,'MIXED_RELEASE_SAME_FEATURE_LAYER') end
        m.lanes[lane]={feature=fg,layer=layer,moving=false,release=release==true}
       end
      end
     end
     if step.abs_preset or step.rel_preset or step.integrated then reason(m,'OPAQUE_STEP_DEPENDENCY') end
    end
    if type(p.mask_active_value)=='number' and p.mask_active_value & (2|4) & (~touchedMask)~=0 then reason(m,'ACTIVE_LAYER_WITHOUT_EFFECTIVE_STEP') end
    if p.abs_preset or p.rel_preset then reason(m,'OPAQUE_PHASER_DEPENDENCY') end
   end
  end
  if m.channels==0 then reason(m,'EMPTY_REFERENCE_DATA') end
  if raw.count~=nil and raw.count~=m.channels then reason(m,'COUNT_MISMATCH') end
  m=finish(m)
  if proof then proof.ordinary(raw,m) end
  return m
 end
 local function phaser(ref,structural,dependency)
  local m=result('PHASER_NATIVE_BRIDGE'); local seen={}; local stepValues={}; local recipeCount=0
  local sourceAudits={}
  for _,a in ipairs(structural.audits or {}) do if a.node then sourceAudits[api.identity(a.node) or a.node]=a end end
  local function visit(h,recipe,step,depth)
   if depth>8 or m.valueSources>512 or seen[h] then reason(m,'TREE_LIMIT_OR_CYCLE'); return end
   seen[h]=true; local c=api.class(h):lower()
   if c=='phaserrecipe' then recipe=h; step=nil; recipeCount=recipeCount+1; m.phaserStructure=true end
   if c=='phaserrecipestep' then step=h; m.structuralSteps=m.structuralSteps+1 end
   if c=='phaserrecipevaluesource' then
    m.valueSources=m.valueSources+1
    local props=api.metadata(h); local a=sourceAudits[api.identity(h) or h]
    local deps=api.safe(function() return h:GetDependencies() end)
    local dependencyEvidence={}
    if type(deps)=='table' then for _,d in pairs(deps) do if #dependencyEvidence<8 and api.isObject(d) then dependencyEvidence[#dependencyEvidence+1]=api.class(d)..':'..tostring(api.identity(d)) end end end
    local av=props.attributes or props.attribute
    local attr=av and av.raw
    if not api.isObject(attr) then attr=a and a.attributeHandle end
    local fg=feature(attr)
    if fg then m.features[fg]=true else reason(m,'VALUESOURCE_ATTRIBUTE_FEATURE_UNPROVEN') end
    if not recipe or not step then reason(m,'VALUESOURCE_PARENT_CHAIN_UNPROVEN') end
    local linked=a and a.presetHandle or (props.preset and props.preset.raw)
    local linkedMeta
    if props.preset and props.preset.raw~=nil and tostring(props.preset.raw)~='' then
     if api.isObject(linked) and api.class(linked):lower()=='preset' then
      m.dependencies=m.dependencies+1; m.source='MIXED'; linkedMeta=dependency(linked)
      -- Rev10.1 native note: validation-only pool labels may not
      -- CompareHandle-match; the DIRECT linked handle stays authoritative.
      local presetMode=linkedPresetMode(linked)
      if presetMode=='Universal' then
       m.observations['LINKED_PRESET_MODE_UNIVERSAL']=true
       if linkedMeta.completeness~='COMPLETE' and not onlyMemberApplicabilityEvidence(linkedMeta) then reason(m,'LINKED_PRESET_METADATA_UNSAFE') end
      elseif presetMode=='Selective' then
       m.observations['LINKED_PRESET_MODE_SELECTIVE']=true
       reason(m,'SELECTIVE_MEMBER_MAPPING_UNPROVEN')
       if linkedMeta.completeness~='COMPLETE' then reason(m,'LINKED_PRESET_METADATA_UNSAFE') end
      else
       m.observations['LINKED_PRESET_MODE_UNPROVEN']=true
       if linkedMeta.completeness~='COMPLETE' then reason(m,'LINKED_PRESET_METADATA_UNSAFE') end
      end
      if fg and not linkedMeta.features[fg] then reason(m,'LINKED_PRESET_FEATURE_MISMATCH') end
     else reason(m,'LINKED_PRESET_HANDLE_UNRESOLVED') end
    end
    if props.shape and props.shape.raw~=nil and tostring(props.shape.raw)~='' then m.shapes=m.shapes+1 end
    local admitted=0
    local function evidenceIdentity(h) return h and api.identity(h) or nil end
    if #m.samples<8 then
     local si=step and api.safe(function() return step:Index() end)
     m.samples[#m.samples+1]='ValueSource='..tostring(api.desc and api.desc(h) or api.identity(h))..' parent_recipe='..tostring(evidenceIdentity(recipe))..' Step_index='..tostring(si)..' Attribute='..tostring(evidenceIdentity(attr))..' FeatureGroup='..tostring(fg)..' linked_preset='..tostring(evidenceIdentity(linked))..' Shape='..tostring(props.shape and props.shape.raw)..' RawValueAbs_enumerated='..tostring(props.rawvalueabs~=nil)..' RawValueAbs='..tostring(props.rawvalueabs and props.rawvalueabs.raw)..' RawValueAbs_type='..type(props.rawvalueabs and props.rawvalueabs.raw)..' RawValueRel_enumerated='..tostring(props.rawvaluerel~=nil)..' RawValueRel='..tostring(props.rawvaluerel and props.rawvaluerel.raw)..' RawValueRel_type='..type(props.rawvaluerel and props.rawvaluerel.raw)..' ValueAbsolute='..tostring(props.valueabsolute and props.valueabsolute.raw)..' ValueRelative='..tostring(props.valuerelative and props.valuerelative.raw)..' dependencies='..table.concat(dependencyEvidence,',')
    end
    for _,spec in ipairs({{'ABS','rawvalueabs','valueabsolute'},{'REL','rawvaluerel','valuerelative'}}) do
     local layer,rawKey,effectiveKey=table.unpack(spec)
     local p=props[rawKey]; local v=p and p.raw; local effective=props[effectiveKey] and props[effectiveKey].raw
     local depLane=linkedMeta and linkedMeta.layers[layer]
     if a and (v==nil or tostring(v)=='') and a.shapeHandle and api.class(a.shapeHandle):lower()=='phaserrecipevaluesource' then
      local inherited=api.metadata(a.shapeHandle)[rawKey]
      if inherited and finite(inherited.raw) then p=inherited; v=inherited.raw; m.observations['SHAPE_VALUESOURCE_INHERITANCE_'..layer]=true end
     end
     if p and finite(v) then
      local verdict=tonumber(v)==0 and not depLane and proof and proof.rawLayer(layer,v,linkedMeta,fg,effective,props,h) or nil
      if verdict=='ABSENT' then
       m.observations['RAW_'..layer..'_ZERO_NOT_AUTHORED_PROVEN']=true
      elseif verdict=='AUTHORED' and fg then
       m.observations['RAW_'..layer..'_ZERO_AUTHORED_PROVEN']=true
       admitted=admitted+1; m.layers[layer]=true; local key=fg..'|'..layer
       stepValues[key]=stepValues[key] or {}; stepValues[key][step]=stepValues[key][step] or {}
       stepValues[key][step][#stepValues[key][step]+1]=finite(effective) and effective or v
      elseif tonumber(v)==0 and not depLane then reason(m,'ZERO_RAW_LAYER_AMBIGUOUS_'..layer)
      elseif linkedMeta and not depLane then reason(m,'LINKED_PRESET_LAYER_MISMATCH_'..layer)
      elseif not finite(effective) and not depLane then reason(m,'EFFECTIVE_LAYER_UNPROVEN_'..layer)
      elseif fg then
       admitted=admitted+1; m.layers[layer]=true; local key=fg..'|'..layer
       stepValues[key]=stepValues[key] or {}; stepValues[key][step]=stepValues[key][step] or {}
       stepValues[key][step][#stepValues[key][step]+1]=finite(effective) and effective or v
      end
     elseif p and v~=nil and tostring(v)~='' then reason(m,'RAW_LAYER_ENCODING_UNPROVEN_'..layer)
     end
    end
    if admitted==0 then reason(m,'NO_PROVEN_VALUESOURCE_LAYER') end
    local scope=props.layer and props.layer.raw
    if scope~=nil and scope~='' then
     if scope=='Absolute' or scope=='ABS' or scope=='Relative' or scope=='REL' then m.observations['EXPLICIT_LAYER='..tostring(scope)]=true
     else reason(m,'EXPLICIT_LAYER_SEMANTICS_UNVERIFIED') end
    end
    for _,k in ipairs({'phase','speed','transition','width','measure'}) do
     if props[k] and props[k].raw~=nil and props[k].raw~='' then m.observations['DYNAMIC_PROPERTY_'..k..'='..type(props[k].raw)]=true end
    end
   end
   local children=api.safe(function() return h:Children() end)
   if type(children)~='table' then reason(m,'UNREADABLE_CHILDREN'); return end
   for _,child in ipairs(children) do visit(child,recipe,step,depth+1) end
  end
  visit(ref,nil,nil,0)
  if recipeCount~=1 then reason(m,'RECIPE_COUNT_UNPROVEN') end
  if m.valueSources==0 then reason(m,'NO_VALUESOURCES') end
  for key,steps in pairs(stepValues) do
   local count,values=0,{}
   for _,step in pairs(steps) do count=count+1; for _,v in ipairs(step) do values[tostring(v)]=true end end
   local different=0; for _ in pairs(values) do different=different+1 end
   local fg,layer=key:match('^(.-)|([^|]+)$')
   if count>1 and different>1 then m.motionProof='MOTION_PROVEN_EFFECTIVE_STEP_DIFFERENCE'; m.lanes[key]={feature=fg,layer=layer,moving=true}
   elseif count==1 and m.structuralSteps==1 and m.dependencies==0 then m.motionProof='STATIC_PROVEN_SINGLE_STEP'; m.lanes[key]={feature=fg,layer=layer,moving=false}
   else reason(m,'MOTION_UNPROVEN_STEP_OR_EFFECTIVE_VALUES') end
  end
  if m.phaserStructure then m.observations.PHASER_STRUCTURE_PROVEN=true end
  return finish(m)
 end
 return {ordinary=ordinary,phaser=phaser,fields=fields}
end

-- Rev6 evidence policy. The Rev5 bridge calls this only in a separate candidate.
-- Evidence: installed MA3 2.5 systemtests/help/system_test_helping_functions_db.lua
-- lines 182-264 (mask bits), 322-335 and 640-671 (selective / pm),
-- 577-578 (absolute_value). The shared 2.5.0.3 API index gives only the
-- GetPresetData signature, not a dictionary schema.
local function newReferenceFieldSemantics(api)
 local focus={'dict_flags.has_absolute','dict_flags.has_relative','pm','ui_channel_index',
  'absolute_value','absolute','gridpos','gridposmatr','mask_active_phaser',
  'mask_active_value','mask_cooked','mask_individual','preset_store_mode','selective'}
 local distributions,patterns,observed={},{},{}
 for _,field in ipairs(focus) do distributions[field]={types={},samples={},sampleCount=0,channels=0,refs={},refValues={}} end
 local classifications={
  ['dict_flags.has_absolute']={'SEMANTIC_UNKNOWN','no vendor definition; conditionally nonblocking only with independent active-value ABS bit 2 and effective absolute step'},
  ['dict_flags.has_relative']={'SEMANTIC_UNKNOWN','no vendor definition; conditionally nonblocking only with independent active-value REL bit 4 and effective relative step'},
  pm={'SEMANTIC_PROVEN','vendor 2.5 CheckPhaserDataInternal verifies pm 1=selective,2=global,3=universal; selective applicability remains unsafe'},
  ui_channel_index={'NON_BLOCKING_METADATA_PROVEN','vendor UI-channel lookup and equality to record key; mismatch remains unsafe'},
  absolute_value={'NON_BLOCKING_METADATA_PROVEN','vendor 2.5 compares encoded step value independently; active ABS mask and effective absolute step still required'},
  absolute={'SEMANTIC_PROVEN','vendor 2.5 CheckPhaserDataInternal tests step absolute as effective value'},
  gridpos={'SEMANTIC_UNKNOWN','grid position may change member or matrix applicability'},
  gridposmatr={'SEMANTIC_UNKNOWN','matrix transform may change member applicability'},
  mask_active_phaser={'SEMANTIC_PROVEN','vendor GetPhaserMask bit map; non-grid motion bits block static proof'},
  mask_active_value={'SEMANTIC_PROVEN','vendor PhaserValueMaskToList ABS=2 REL=4; other active bits block static proof'},
  mask_cooked={'SEMANTIC_UNKNOWN','vendor distinguishes cooked mask; nonzero effect unresolved'},
  mask_individual={'SEMANTIC_UNKNOWN','individual mask may change member applicability'},
  preset_store_mode={'SEMANTIC_PROVEN','vendor enum distinguishes selective/global/universal; selective applicability remains unsafe'},
  selective={'SEMANTIC_PROVEN','vendor 2.5 preset recipe test checks selective=true per fixture; selective applicability remains unsafe'},
 }
 local function scalar(v)
  if type(v)=='table' then
   local a,n={},0; for k,x in pairs(v) do n=n+1; if #a<3 then a[#a+1]=tostring(k)..'='..tostring(x):sub(1,24) end end
   table.sort(a); return '{'..n..':'..table.concat(a,',')..'}'
  end
  return tostring(v):sub(1,48)
 end
 local function record(field,v,refKey)
  local d=distributions[field]; if not d then return end
  d.channels=d.channels+1; d.types[type(v)]=true; d.refs[refKey]=true
  d.refValues[refKey]=d.refValues[refKey] or {}; d.refValues[refKey][scalar(v)]=true
  local s=scalar(v)
  if d.samples[s] then d.samples[s]=d.samples[s]+1
  elseif d.sampleCount<8 then d.sampleCount=d.sampleCount+1; d.samples[s]=1 end
 end
 local function observe(ref,raw)
  local key=api.identity(ref); if not key or observed[key] then return end
  observed[key]=true
  if type(raw)~='table' then return end
  for ui,p in pairs(raw) do if type(ui)=='number' and type(p)=='table' then
   local shape={}
   for _,field in ipairs(focus) do
    local v
    if field:sub(1,11)=='dict_flags.' then v=type(p.dict_flags)=='table' and p.dict_flags[field:sub(12)] or nil
    elseif field=='absolute_value' or field=='absolute' then v=type(p[1])=='table' and p[1][field] or nil
    else v=p[field] end
    if v~=nil then record(field,v,key); shape[#shape+1]=field..':'..type(v) end
   end
   table.sort(shape); local signature=table.concat(shape,',')
   local pat=patterns[signature] or {channels=0,refs={}}; patterns[signature]=pat
   pat.channels=pat.channels+1; pat.refs[key]=true
  end end
 end
 local function hasEffective(p,layer)
  local bit=layer=='ABS' and 2 or 4
  local step=p[1]
  return type(p.mask_active_value)=='number' and p.mask_active_value & bit~=0
   and type(step)=='table' and type(step[layer=='ABS' and 'absolute' or 'relative'])=='number'
 end
 local function accept(where,k,v,p,ui,step)
  if where=='channel' then
   if k=='ui_channel_index' then return type(v)=='number' and v==ui end
   if k=='pm' or k=='preset_store_mode' then return (v==2 or v==3) and p.selective~=true end
   -- Selective values and matrix positions can change which Group members receive data.
   return false
  elseif where=='dict_flags' then
   if k=='has_absolute' then return (v==true or v==1) and hasEffective(p,'ABS') end
   if k=='has_relative' then return (v==true or v==1) and hasEffective(p,'REL') end
   return false
  elseif where=='step' then
   if k=='absolute_value' then
    return type(v)=='number' and hasEffective(p,'ABS') and type(step.absolute)=='number'
   end
   return false
  end
  return false
 end
 local function ordinary(raw,m)
  local absent={ABS=true,REL=true}; local any=false
  for ui,p in pairs(raw or {}) do if type(ui)=='number' and type(p)=='table' then
   any=true
   for _,layer in ipairs({'ABS','REL'}) do
    local bit=layer=='ABS' and 2 or 4
    local value=layer=='ABS' and 'absolute' or 'relative'
    local flag=layer=='ABS' and 'has_absolute' or 'has_relative'
    local mask=p.mask_active_value
    if type(mask)~='number' or mask & bit~=0 or (p[1] and p[1][value]~=nil)
      or type(p.dict_flags)~='table' or (p.dict_flags[flag]~=false and p.dict_flags[flag]~=0 and p.dict_flags[flag]~=nil)
    then absent[layer]=false end
   end
   if p.selective==true or p.pm==1 or p.preset_store_mode==1 then
    m.evidence.SELECTIVE_MEMBER_APPLICABILITY_UNPROVEN=true
   end
   if p.mask_individual~=nil and p.mask_individual~=0 and p.mask_individual~=false then
    m.evidence.INDIVIDUAL_MEMBER_APPLICABILITY_UNPROVEN=true
   end
   if p.gridpos~=nil and p.gridpos~=0 and p.gridpos~=false and not (type(p.gridpos)=='table' and next(p.gridpos)==nil) then
    m.evidence.GRID_POSITION_EFFECT_UNPROVEN=true
   end
   if type(p.mask_active_phaser)=='number' and p.mask_active_phaser & 64~=0 then
    m.evidence.ACTIVE_GRID_POSITION_APPLICABILITY_UNPROVEN=true
   end
  end end
  m.layerAbsence={}
  if any and m.completeness=='COMPLETE' and not next(m.evidence) then
   for layer,v in pairs(absent) do if v then m.layerAbsence[layer]=true end end
  end
  if next(m.evidence) then m.completeness='PARTIAL'; m.motion='UNSAFE'; m.layerScopeKnown=false end
 end
 local rawStates={REL_AUTHORED_PROVEN=0,REL_NOT_AUTHORED_PROVEN=0,REL_AMBIGUOUS=0,ABS_AUTHORED_PROVEN=0,ABS_NOT_AUTHORED_PROVEN=0,ABS_AMBIGUOUS=0}
 local function emptyText(x) return x==nil or (type(x)=='string' and x:match('^%s*$')~=nil) end
 local function rawLayer(layer,v,linked,fg,effective,props,node)
  local scope=props and props.layer and props.layer.raw
  -- No 2.5 reference defines ValueSource Layer property or raw zero encoding.
  -- Even an apparently opposite Layer label is only an audit clue.
  -- Rev11: the proven Rev8.1 native rule classifies REL numeric zero from the
  -- ValueRelative direct/Get/display triple. ABS zero stays unpromoted.
  local state='AMBIGUOUS'
  local reader=api.safe
  if layer=='REL' and type(v)=='number' and v==0 and node~=nil and type(reader)=='function' then
   local direct=reader(function() return node.ValueRelative end)
   local getter=reader(function() return node:Get('ValueRelative') end)
   local displayRole=((_G.Enums or {}).Roles or {}).Display
   local display=displayRole and reader(function() return node:Get('ValueRelative',displayRole) end)
   if emptyText(direct) and emptyText(getter) and emptyText(display) then state='NOT_AUTHORED_PROVEN'
   elseif direct==0 and getter==0 and tonumber(display)==0 then state='AUTHORED_PROVEN' end
  end
  rawStates[layer..'_'..state]=rawStates[layer..'_'..state]+1
  if state=='NOT_AUTHORED_PROVEN' then return 'ABSENT' end
  if state=='AUTHORED_PROVEN' then return 'AUTHORED' end
  return nil
 end
 local function summary()
  for _,d in pairs(distributions) do
   local global,within={},false
   for _,values in pairs(d.refValues) do
    local n=0; for value in pairs(values) do n=n+1; global[value]=true end
    if n>1 then within=true end
   end
   d.variesWithinPreset=within
   local n=0; for _ in pairs(global) do n=n+1 end
   local refs=0; for _ in pairs(d.refs) do refs=refs+1 end
   d.variesAcrossPresets=n>1 and refs>1
  end
  return {fields=distributions,patterns=patterns,classifications=classifications,rawStates=rawStates,referenceCount=observed}
 end
 local function attributeUnsafe(input)
 local rows=input.rows or {}
 local result=input.result or {}
 local final=input.final or {}
 local infoByKey=input.infoByKey or {}
 local identify=input.identity or function() return nil end
 local desc,joined,sample,count,text,log= input.desc,input.joined,input.sample,input.count,input.text,input.log
 local emit=input.detail or log
 local now,ms=input.now,input.ms
 local t0=now()
 local function key(member,lane) return tostring(member)..'\0'..tostring(lane) end
 local function barrierKeys(row)
  local keys={}
  if row.members then
   for member in pairs(row.members) do
    if not row.features then
     keys[key(member,'*')]=true
    else
     for feature in pairs(row.features) do
      if not row.layers then
       keys[key(member,feature..'|*')]=true
      else
       for layer in pairs(row.layers) do keys[key(member,feature..'|'..layer)]=true end
      end
     end
    end
   end
  end
  return keys
 end
 local decidedByKey={}
 for _,a in ipairs(result.assignments or {}) do
  local k=key(a.member,a.lane)
  if decidedByKey[k]==nil then decidedByKey[k]=a.row end
 end
 local unresolvedByKey={}
 for _,u in ipairs(result.unresolved or {}) do
  local k=key(u.member,u.lane)
  if unresolvedByKey[k]==nil then unresolvedByKey[k]=u.row end
 end
 local victims={}
 for _,row in ipairs(rows) do
  for _,sup in ipairs(row.superseded or {}) do
   if sup.unsafe==true and type(sup.newer)=='table' then
    local list=victims[sup.newer] or {}; victims[sup.newer]=list
    list[#list+1]={victim=row,member=sup.member,lane=sup.lane}
   end
  end
 end
 local function motionOf(row)
  local info=row.ref and infoByKey[identify(row.ref)]
  if type(info)=='table' and info.motion~=nil then return tostring(info.motion) end
  if row.moving then return 'moving' end
  return 'UNKNOWN'
 end
 local function refOf(row) return row.refId~=nil and row.refId or nil end
 local records={}
 local reasonCounts={}
 local refStats={}
 for _,row in ipairs(result.unsafe or {}) do
  local reasons={}
  for _,r in ipairs(row.unsafe or {}) do reasons[#reasons+1]=tostring(r); reasonCounts[tostring(r)]=(reasonCounts[tostring(r)] or 0)+1 end
  table.sort(reasons)
  local keys=barrierKeys(row)
  local nKeys=0; for _ in pairs(keys) do nKeys=nKeys+1 end
  local surviving,neutralized,resolvers={},{},{}
  for k in pairs(keys) do
   if unresolvedByKey[k]==row then surviving[#surviving+1]=k
   else
    local decider=decidedByKey[k]
    if decider~=nil and (decider.reverseIndex or 1e9)<(row.reverseIndex or 1e9) then
     neutralized[#neutralized+1]=k; resolvers[decider]=true
    elseif unresolvedByKey[k]~=nil then neutralized[#neutralized+1]=k; resolvers[unresolvedByKey[k]]=true
    end
   end
  end
  local blocked=victims[row] or {}
  local refId=refOf(row)
  local inFinal=refId~=nil and final[refId]~=nil
  local category
  if #surviving>0 or #blocked>0 or (inFinal and nKeys>0) then category='FINAL_SURVIVING_UNSAFE'
  elseif nKeys==0 then category='NON_CONTRIBUTING_UNSAFE'
  elseif #surviving==0 and #neutralized==nKeys then category='FULLY_SUPERSEDED_UNSAFE'
  else category='ATTRIBUTION_UNKNOWN' end
  local rec={row=row,ref=row.ref,refId=refId,inFinal=inFinal,reasons=reasons,motion=motionOf(row),
   members=row.members and count(row.members) or 0,sample=row.members and sample(row.members) or '<none>',
   features=joined(row.features),layers=joined(row.layers),nKeys=nKeys,
   surviving=surviving,neutralized=neutralized,resolvers=resolvers,blocked=blocked,category=category}
  records[#records+1]=rec
  if refId~=nil then
   local label=text(desc(row.ref))
   local st=refStats[label] or {total=0,final_surviving=0,fully_superseded=0,non_contributing=0,unknown=0}
   refStats[label]=st; st.total=st.total+1
   if category=='FINAL_SURVIVING_UNSAFE' then st.final_surviving=st.final_surviving+1
   elseif category=='FULLY_SUPERSEDED_UNSAFE' then st.fully_superseded=st.fully_superseded+1
   elseif category=='NON_CONTRIBUTING_UNSAFE' then st.non_contributing=st.non_contributing+1
   else st.unknown=st.unknown+1 end
  end
 end
 local totals={total=0,final_surviving=0,fully_superseded=0,non_contributing=0,unknown=0}
 for _,rec in ipairs(records) do
  totals.total=totals.total+1
  if rec.category=='FINAL_SURVIVING_UNSAFE' then totals.final_surviving=totals.final_surviving+1
  elseif rec.category=='FULLY_SUPERSEDED_UNSAFE' then totals.fully_superseded=totals.fully_superseded+1
  elseif rec.category=='NON_CONTRIBUTING_UNSAFE' then totals.non_contributing=totals.non_contributing+1
  else totals.unknown=totals.unknown+1 end
 end
 local function rowLine(tag,rec)
  local resolverRefs={}
  for r in pairs(rec.resolvers) do resolverRefs[#resolverRefs+1]=text(desc(r.ref)) end
  table.sort(resolverRefs)
  local victimRefs={}
  for _,v in ipairs(rec.blocked) do victimRefs[#victimRefs+1]=text(desc(v.victim.ref)) end
  table.sort(victimRefs)
  emit(tag..' ref=%s cue=%s part=%s recipe=%s group=%s features=%s layers=%s reasons=%s members=%d sample=%s motion=%s ref_in_final=%s surviving_lanes=%d neutralized_lanes=%d blocked_victims=%d resolvers=%s victims=%s',
   text(desc(rec.ref)),text(desc(rec.row.cue)),text(desc(rec.row.part)),text(desc(rec.row.recipe)),text(desc(rec.row.group)),
   text(rec.features),text(rec.layers),table.concat(rec.reasons,','),rec.members,rec.sample,rec.motion,
   tostring(rec.inFinal),#rec.surviving,#rec.neutralized,#rec.blocked,table.concat(resolverRefs,';'),table.concat(victimRefs,';'))
 end
 log('UNSAFE_ATTRIBUTION_SUMMARY total_unsafe_rows=%d final_surviving=%d fully_superseded=%d non_contributing=%d unknown=%d attribution_ms=%s reverse_ms=%s total_rev7_path_ms=%s',
  totals.total,totals.final_surviving,totals.fully_superseded,totals.non_contributing,totals.unknown,
  text(ms(t0,now())),text(input.reverseMs),text(input.totalMs))
 local orderedReasons={}; for reason in pairs(reasonCounts) do orderedReasons[#orderedReasons+1]=reason end; table.sort(orderedReasons)
 for _,reason in ipairs(orderedReasons) do log('UNSAFE_REASON_SUMMARY reason=%s rows=%d',reason,reasonCounts[reason]) end
 local orderedRefs={}; for label in pairs(refStats) do orderedRefs[#orderedRefs+1]=label end; table.sort(orderedRefs)
 local shownRefs=0
 for _,label in ipairs(orderedRefs) do local st=refStats[label]
  if shownRefs<16 then shownRefs=shownRefs+1
   log('UNSAFE_REFERENCE_SUMMARY reference=%s total_rows=%d final_surviving=%d fully_superseded=%d non_contributing=%d unknown=%d',
    label,st.total,st.final_surviving,st.fully_superseded,st.non_contributing,st.unknown) end
 end
 local omittedRefs=#orderedRefs-shownRefs
 local shownA,shownB,shownD=0,0,0
 for _,rec in ipairs(records) do
  if rec.category=='FINAL_SURVIVING_UNSAFE' and shownA<24 then shownA=shownA+1; rowLine('FINAL_SURVIVING_UNSAFE_ROW',rec) end
  if rec.category=='ATTRIBUTION_UNKNOWN' and shownD<24 then shownD=shownD+1; rowLine('ATTRIBUTION_UNKNOWN_ROW',rec) end
 end
 for _,rec in ipairs(records) do
  if rec.category=='FULLY_SUPERSEDED_UNSAFE' and shownB<5 then shownB=shownB+1; rowLine('FULLY_SUPERSEDED_SAMPLE_ROW',rec) end
 end
 local omittedA,omittedB,omittedD=totals.final_surviving-shownA,totals.fully_superseded-shownB,totals.unknown-shownD
 if omittedA>0 or omittedB>0 or omittedD>0 or omittedRefs>0 then
  log('UNSAFE_ATTRIBUTION_OMITTED final_surviving=%d fully_superseded_sample=%d unknown=%d references=%d',omittedA,omittedB,omittedD,omittedRefs) end
 return {ok=true,elapsedMs=ms(t0,now()),total=totals.total,finalSurviving=totals.final_surviving,
  fullySuperseded=totals.fully_superseded,nonContributing=totals.non_contributing,unknown=totals.unknown,rows=records}
end

 return {accept=accept,ordinary=ordinary,rawLayer=rawLayer,observe=observe,summary=summary,attributeUnsafe=attributeUnsafe}
end

-- Rev12.1 observer only. Vendor 2.5 GetPhaserMask/PhaserMaskToList:
-- 1/2 Preset dependencies, 4/8/16/32/128/256 timing/motion, 64 gridpos.
function __rev12OrdinaryStaticInspect(raw)
  local motionBits=4|8|16|32|128|256
  local knownBits=1|2|motionBits|64
  local out={channels=0,activeValue=0,nonGridMotion=0,gridPosition=0,steps={},layers={},modes={},selective={},motionReasons={},memberReasons={}}
  local function motion(s) out.motionReasons[s]=true end
  local function member(s) out.memberReasons[s]=true end
  if type(raw)~='table' then
   motion('REFERENCE_DATA_UNAVAILABLE'); member('REFERENCE_DATA_UNAVAILABLE')
   out.motionStaticProven=false; out.memberApplicabilityProven=false; return out
  end
  for ui,p in pairs(raw) do
   if ui=='count' then
    if type(p)~='number' then motion('INVALID_COUNT'); member('INVALID_COUNT') end
   elseif ui=='by_fixtures' then
    if p~=false then motion('NOT_UI_CHANNEL_INDEXED'); member('NOT_UI_CHANNEL_INDEXED') end
   elseif type(ui)~='number' or type(p)~='table' then motion('UNSUPPORTED_TOP_LEVEL'); member('UNSUPPORTED_TOP_LEVEL')
   else
    out.channels=out.channels+1
    if out.channels>262144 then motion('CHANNEL_LIMIT'); member('CHANNEL_LIMIT'); break end
    local mask=p.mask_active_value
    if type(mask)~='number' or math.type(mask)~='integer' or mask & ~(2|4)~=0 or mask & (2|4)==0 then motion('ACTIVE_VALUE_MASK_UNPROVEN')
    else out.activeValue=out.activeValue+1 end
    local phaser=p.mask_active_phaser
    if type(phaser)~='number' or math.type(phaser)~='integer' or phaser<0 or phaser & ~knownBits~=0 then
     motion('PHASER_MASK_SHAPE_OR_BITS_UNPROVEN'); member('PHASER_MASK_SHAPE_OR_BITS_UNPROVEN')
    else
     if phaser & motionBits~=0 then out.nonGridMotion=out.nonGridMotion+1; motion('NON_GRID_MOTION_MASK_ACTIVE') end
     if phaser & (1|2)~=0 then motion('PHASER_PRESET_DEPENDENCY_ACTIVE') end
     if phaser & 64~=0 then out.gridPosition=out.gridPosition+1; member('ACTIVE_GRID_POSITION_APPLICABILITY_UNPROVEN') end
    end
    if p.mask_cooked~=nil and p.mask_cooked~=0 then motion('COOKED_MASK_UNPROVEN') end
    for _,k in ipairs({'speed','phase','measure','nshot_count','fade','delay','speed_master','abs_generator','rel_generator','generator','abs_preset','rel_preset'}) do
     if p[k]~=nil and p[k]~=false and p[k]~=0 then motion('MOTION_OR_DEPENDENCY_'..k) end
    end
    for k,v in pairs(p) do
     if type(k)=='string' and not ({attribute=true,abs_preset=true,rel_preset=true,abs_generator=true,rel_generator=true,generator=true,
      mask_active_phaser=true,mask_active_value=true,mask_cooked=true,mask_individual=true,mask_integrated=true,
      dict_flags=true,dict_index=true,gridposmatr=true,gridpos=true,grid=true,phase=true,speed=true,measure=true,
      fade=true,delay=true,selective=true,preset_store_mode=true,pm=true,ui_channel_index=true,
      grid_origin=true,grid_matrix=true,nshot_count=true,nshot_flags=true,speed_master=true})[k] then
      motion('UNKNOWN_PHASER_FIELD_'..tostring(k))
     end
    end
    local mode=p.preset_store_mode or p.pm
    if mode~=2 and mode~=3 then member('MEMBER_PRESET_MODE_UNPROVEN') end
    if p.pm~=nil and p.preset_store_mode~=nil and p.pm~=p.preset_store_mode then member('CONFLICTING_PRESET_MODES') end
    if p.selective==true then member('SELECTIVE_MEMBER_APPLICABILITY_UNPROVEN') end
    if p.selective~=nil and type(p.selective)~='boolean' then member('SELECTIVE_FIELD_SHAPE_UNPROVEN') end
    if p.ui_channel_index~=nil and p.ui_channel_index~=ui then motion('UI_CHANNEL_INDEX_MISMATCH'); member('UI_CHANNEL_INDEX_MISMATCH') end
    if p.mask_individual~=nil and p.mask_individual~=0 and p.mask_individual~=false then member('INDIVIDUAL_MEMBER_APPLICABILITY_UNPROVEN') end
    if p.gridpos~=nil and p.gridpos~=0 and p.gridpos~=false and not (type(p.gridpos)=='table' and next(p.gridpos)==nil) then member('GRID_POSITION_EFFECT_UNPROVEN') end
    if p.gridposmatr~=nil and (type(p.gridposmatr)~='table' or next(p.gridposmatr)~=nil) then member('GRID_MATRIX_EFFECT_UNPROVEN') end
    if p.dict_flags~=nil then
     if type(p.dict_flags)~='table' then motion('DICTIONARY_FLAGS_UNPROVEN'); member('DICTIONARY_FLAGS_UNPROVEN')
     else for k,v in pairs(p.dict_flags) do
      if k=='selective' and v~=nil and v~=false and v~=0 then member('DICTIONARY_SELECTIVE_APPLICABILITY_UNPROVEN')
      elseif (k=='blocked' or k=='blocked_rel') and v~=nil and v~=false and v~=0 then member('BLOCKED_DICTIONARY_LAYER_'..k)
      elseif not ({has_absolute=true,has_relative=true,blocked=true,blocked_rel=true,selective=true})[k]
       and v~=nil and v~=false and v~=0 then motion('UNKNOWN_ACTIVE_DICTIONARY_FLAG_'..tostring(k)) end
     end end
    end
    out.modes[tostring(mode or 'nil')]=true
    out.selective['field='..tostring(p.selective)..'/dict='..tostring(type(p.dict_flags)=='table' and p.dict_flags.selective or nil)]=true
    local steps,n,seen={},0,{}
    for k,v in pairs(p) do if type(k)=='number' then
     n=n+1; seen[k]=true
     if k<1 or k%1~=0 or type(v)~='table' then motion('INVALID_STEP_SHAPE') else steps[#steps+1]=v end
    end end
    out.steps[tostring(n)]=(out.steps[tostring(n)] or 0)+1
    if n~=1 or not seen[1] then motion('SINGLE_EFFECTIVE_STEP_UNPROVEN') end
    local step=steps[1]
    if type(step)=='table' then
     local touched=0
     for _,spec in ipairs({{'ABS','absolute',2},{'REL','relative',4}}) do
      local layer,value,bit=table.unpack(spec)
      if step[value]~=nil then
       if type(step[value])~='number' or step[value]~=step[value] or math.abs(step[value])==math.huge then motion('EFFECTIVE_'..layer..'_UNPROVEN') end
       if type(mask)~='number' or math.type(mask)~='integer' or mask & bit==0 then motion('INACTIVE_'..layer..'_VALUE') end
       touched=touched | bit; out.layers[layer]=true
      end
     end
     if type(mask)=='number' and math.type(mask)=='integer' and mask & (2|4)~=touched then motion('ACTIVE_LAYER_WITHOUT_EFFECTIVE_STEP') end
     for _,k in ipairs({'abs_release','rel_release','abs_remove','rel_remove','abs_preset','rel_preset','integrated','accel','decel','trans','transition','width'}) do
      if step[k]~=nil and step[k]~=false and step[k]~=0 then motion('STEP_EFFECT_UNPROVEN_'..k) end
     end
     for k,v in pairs(step) do
      if type(k)=='string' and not ({absolute=true,relative=true,absolute_value=true,abs_release=true,rel_release=true,
       abs_remove=true,rel_remove=true,abs_preset=true,rel_preset=true,integrated=true,accel=true,decel=true,
       trans=true,transition=true,width=true,channel_function=true,mask_active=true,mask_individual=true,
       mask_integrated=true,dict_flags=true})[k] then motion('UNKNOWN_STEP_FIELD_'..tostring(k)) end
     end
     if step.absolute_value~=nil and (type(step.absolute_value)~='number' or step.absolute==nil or type(mask)~='number' or math.type(mask)~='integer' or mask & 2==0) then
      motion('ABSOLUTE_VALUE_WITHOUT_EFFECTIVE_ABS') end
    end
   end
  end
  if out.channels==0 then motion('EMPTY_REFERENCE_DATA'); member('EMPTY_REFERENCE_DATA') end
  if raw.count~=nil and raw.count~=out.channels then motion('COUNT_MISMATCH'); member('COUNT_MISMATCH') end
  out.motionStaticProven=next(out.motionReasons)==nil
  out.memberApplicabilityProven=next(out.memberReasons)==nil
  return out
end

-- Rev13 diagnostic only. The Preset 4.4 A/B observation is a controlled
-- fixture/attribute case; matching metadata alone does not transfer that proof.
function __rev13GlobalApplicability(raw, control, staticProof, groupScope, compatibilityProven)
 local out={reasons={},signatures={},modes={},selective={},gridMasks={},individualMasks={},valueMasks={},steps={},layers={}}
 local function block(reason) out.reasons[reason]=true end
 local function shape(x)
  if x==nil then return 'nil' end
  if type(x)~='table' then return type(x)..':'..tostring(x) end
  local keys={}
  for k,v in pairs(x) do keys[#keys+1]=type(k)..':'..tostring(k)..'='..type(v) end
  table.sort(keys)
  return 'table{'..table.concat(keys,',')..'}'
 end
 local known={attribute=true,abs_preset=true,rel_preset=true,abs_generator=true,rel_generator=true,generator=true,
  mask_active_phaser=true,mask_active_value=true,mask_cooked=true,mask_individual=true,mask_integrated=true,
  dict_flags=true,dict_index=true,gridposmatr=true,gridpos=true,grid=true,phase=true,speed=true,measure=true,
  fade=true,delay=true,selective=true,preset_store_mode=true,pm=true,ui_channel_index=true,
  grid_origin=true,grid_matrix=true,nshot_count=true,nshot_flags=true,speed_master=true}
 local function signatures(data, target)
  local set={}
  if type(data)~='table' then block('REFERENCE_DATA_UNAVAILABLE'); return set end
  for ui,p in pairs(data) do
   if type(ui)=='number' then
    if type(p)~='table' then block('CHANNEL_SHAPE_UNPROVEN') else
     local mode=p.preset_store_mode or p.pm
     target.modes[tostring(mode)]=true
     target.selective[tostring(p.selective)..'/'..tostring(type(p.dict_flags)=='table' and p.dict_flags.selective or nil)]=true
     target.gridMasks[tostring(p.mask_active_phaser)]=true
     target.individualMasks[tostring(p.mask_individual)]=true
     target.valueMasks[tostring(p.mask_active_value)]=true
     local n,step=0,nil
     for k,v in pairs(p) do
      if type(k)=='number' then n=n+1; if k==1 then step=v end
      elseif type(k)=='string' and not known[k] and v~=nil and v~=false and v~=0 then block('UNKNOWN_ACTIVE_FIELD_'..k) end
     end
     target.steps[tostring(n)]=true
     local layer=(type(step)=='table' and step.absolute~=nil and 'ABS' or '')..(type(step)=='table' and step.relative~=nil and '+REL' or '')
     target.layers[layer]=true
     if mode~=2 or p.selective~=false or (type(p.dict_flags)=='table' and p.dict_flags.selective~=nil and p.dict_flags.selective~=false and p.dict_flags.selective~=0) then block('NOT_GLOBAL_NONSELECTIVE') end
     if p.pm~=nil and p.preset_store_mode~=nil and p.pm~=p.preset_store_mode then block('CONFLICTING_STORE_MODE') end
     local signature=table.concat({tostring(mode),tostring(p.selective),tostring(type(p.dict_flags)=='table' and p.dict_flags.selective or nil),
      tostring(p.mask_active_phaser),tostring(p.mask_individual),tostring(p.mask_active_value),tostring(p.mask_cooked),
      shape(p.dict_flags),shape(p.dict_index),tostring(p.mask_integrated),
      tostring(n),layer,shape(p.gridpos),shape(p.gridposmatr)},'|')
     set[signature]=true
    end
   elseif ui~='count' and ui~='by_fixtures' then block('UNKNOWN_TOP_LEVEL_FIELD') end
  end
  if not next(set) then block('EMPTY_CHANNEL_SHAPE') end
  return set
 end
 local controlOut={modes={},selective={},gridMasks={},individualMasks={},valueMasks={},steps={},layers={}}
 local controlSet=signatures(control,controlOut)
 local candidateSet=signatures(raw,out)
 local sameShape=true
 for signature in pairs(candidateSet) do if not controlSet[signature] then sameShape=false; block('DIFFERENT_NATIVE_CONTROL_SEMANTIC_SHAPE') end end
 if not staticProof or not staticProof.motionStaticProven then block('MOTION_STATIC_UNPROVEN') end
 if type(groupScope)~='table' or not next(groupScope) then block('RECIPE_GROUP_MEMBER_SCOPE_UNPROVEN') end
 if not compatibilityProven then block('FIXTURE_ATTRIBUTE_COMPATIBILITY_UNPROVEN') end
 out.matchesNativeProvenClass=next(out.reasons)==nil
 out.semanticShape=next(candidateSet) and (sameShape and 'CONTROL_SIGNATURE_SUBSET' or 'DIFFERENT_FROM_CONTROL') or 'UNPROVEN'
 return out
end

-- Resolve the configured pool addresses to native handles, then compare only
-- stable reference identities. Display descriptions are never identity keys.
function __rev13SelectGlobalTargets(paths, objectList, identity, class, records)
 local out={entries={},found=0,missing={},duplicates={}}
 local owners={}
 for _,path in ipairs(paths) do
  local ok,list=pcall(objectList,path)
  local entry={path=path,rows={}}
  out.entries[#out.entries+1]=entry
  if not ok or type(list)~='table' or #list~=1 then out.missing[#out.missing+1]=path
  else
   local ref=list[1]
   local key=identity(ref)
   if class(ref)~='Preset' or not key then out.missing[#out.missing+1]=path
   elseif owners[key] then out.duplicates[#out.duplicates+1]=path
   else entry.key=key; entry.ref=ref; owners[key]=entry end
  end
 end
 for _,rec in ipairs(records or {}) do
  if rec.category=='FINAL_SURVIVING_UNSAFE' then
   local key=rec.ref and identity(rec.ref)
   local entry=key and owners[key]
   if entry then entry.rows[#entry.rows+1]=rec.row end
  end
 end
 for _,entry in ipairs(out.entries) do
  if entry.key and #entry.rows>0 then out.found=out.found+1
  elseif entry.key then out.missing[#out.missing+1]=entry.path end
 end
 out.pass=out.found==#paths and #out.missing==0 and #out.duplicates==0
 return out
end

-- Rev13.1 observation only. Never feeds the Rev13 classifier or resolver.
function __rev131SignatureDelta(control,candidate)
 local fields={'preset_store_mode','pm','selective','dict_flags','dict_index','mask_active_phaser',
  'mask_individual','mask_active_value','mask_cooked','mask_integrated','effective_step_count',
  'layer','gridpos','gridposmatr','unknown_active_fields'}
 local known={attribute=true,abs_preset=true,rel_preset=true,abs_generator=true,rel_generator=true,generator=true,
  mask_active_phaser=true,mask_active_value=true,mask_cooked=true,mask_individual=true,mask_integrated=true,
  dict_flags=true,dict_index=true,gridposmatr=true,gridpos=true,grid=true,phase=true,speed=true,measure=true,
  fade=true,delay=true,selective=true,preset_store_mode=true,pm=true,ui_channel_index=true,
  grid_origin=true,grid_matrix=true,nshot_count=true,nshot_flags=true,speed_master=true}
 local function sorted(t) local a={}; for v in pairs(t) do a[#a+1]=v end; table.sort(a); return table.concat(a,',') end
 local function atom(v)
  if type(v)=='string' then return v:gsub('[\r\n,|]','_'):sub(1,48) end
  if type(v)=='number' or type(v)=='boolean' then return tostring(v) end
  return type(v)
 end
 local function describe(v,depth,neutral)
  local kind=type(v)
  if kind~='table' then return kind..':'..atom(v),0 end
  if depth>=4 then return 'table:DEPTH_LIMIT',0 end
  local parts,n={},0
  for k,child in pairs(v) do
   n=n+1
   if n>256 then return 'table:SIZE_LIMIT',n end
   local key=neutral and type(k)=='number' and '#' or type(k)..':'..atom(k)
   parts[#parts+1]=key..'='..describe(child,depth+1,neutral)
  end
  table.sort(parts)
  return 'table{'..table.concat(parts,';')..'}',n
 end
 local function typeShape(v,depth)
  if type(v)~='table' then return type(v) end
  if depth>=4 then return 'table:DEPTH_LIMIT' end
  local parts,n={},0
  for k,child in pairs(v) do
   n=n+1; if n>256 then return 'table:SIZE_LIMIT' end
   parts[#parts+1]=(type(k)=='number' and '#' or type(k)..':'..atom(k))..'='..typeShape(child,depth+1)
  end
  table.sort(parts); return 'table{'..table.concat(parts,';')..'}'
 end
 local function value(p,field)
  if field=='effective_step_count' then
   local n=0; for k in pairs(p) do if type(k)=='number' then n=n+1 end end; return n
  elseif field=='layer' then
   local step=p[1]; return (type(step)=='table' and step.absolute~=nil and 'ABS' or '')..(type(step)=='table' and step.relative~=nil and '+REL' or '')
  elseif field=='unknown_active_fields' then
   local unknown={}
   for k,v in pairs(p) do if type(k)=='string' and not known[k] and v~=nil and v~=false and v~=0 then unknown[k]=type(v) end end
   return unknown
  end
  return p[field]
 end
 local function collect(raw,field)
  local out={types={},keys={},shapes={},values={},counts={},channels=0,fieldCount=0,limited=false}
  if type(raw)~='table' then out.types['UNAVAILABLE']=true; return out end
  for k,p in pairs(raw) do if type(k)=='number' then
   out.channels=out.channels+1
   if out.channels>262144 then out.limited=true; break end
   if type(p)~='table' then out.types['INVALID_CHANNEL']=true
   else
    local v=value(p,field); local kind=type(v)
    out.types[kind]=true
    local exact,n=describe(v,0,false)
    local neutral=describe(v,0,true)
    out.keys[kind=='table' and exact:gsub('=[^;{}]*','') or kind]=true
    out.shapes[typeShape(v,0)]=true
    out.values[neutral]=true
    out.counts[tostring(n)]=true
    if kind~='nil' then out.fieldCount=out.fieldCount+1 end
    if exact:find('LIMIT',1,true) or neutral:find('LIMIT',1,true) then out.limited=true end
   end
  end end
  return out
 end
 local result={components={},different={},keyOnly={},semanticValue={},valueDifferences={},structural={}}
 local cc=collect(control,'layer'); local ca=collect(candidate,'layer')
 result.controlChannels=cc.channels; result.candidateChannels=ca.channels
 for _,field in ipairs(fields) do
  local a,b=collect(control,field),collect(candidate,field)
  local typesEqual=sorted(a.types)==sorted(b.types)
  local shapeEqual=sorted(a.shapes)==sorted(b.shapes)
  local keysEqual=sorted(a.keys)==sorted(b.keys)
  local valuesEqual=sorted(a.values)==sorted(b.values)
  local countEqual=sorted(a.counts)==sorted(b.counts)
  local status
  if a.limited or b.limited then status='UNPROVEN_LIMIT'
  elseif not typesEqual or not shapeEqual then status='STRUCTURAL'
  elseif not valuesEqual then
   status=({gridpos=true,gridposmatr=true,dict_index=true,unknown_active_fields=true})[field]
    and 'VALUE_DIFFERENCE_UNPROVEN_SEMANTICS' or 'SEMANTIC_VALUE'
  elseif not keysEqual then status='KEY_IDENTITY_ONLY'
  elseif a.channels~=b.channels or a.fieldCount~=b.fieldCount or not countEqual then status='CARDINALITY_ONLY'
  else status='SAME' end
  local detail={component=field,controlType=sorted(a.types),candidateType=sorted(b.types),
   controlCount=a.fieldCount,candidateCount=b.fieldCount,keySetsEqual=keysEqual,
   valueTypeShapeEqual=shapeEqual,status=status}
  result.components[#result.components+1]=detail
  if status~='SAME' then
   result.different[#result.different+1]=field
   if status=='KEY_IDENTITY_ONLY' then result.keyOnly[#result.keyOnly+1]=field
   elseif status=='SEMANTIC_VALUE' then result.semanticValue[#result.semanticValue+1]=field
   elseif status=='VALUE_DIFFERENCE_UNPROVEN_SEMANTICS' then result.valueDifferences[#result.valueDifferences+1]=field
   elseif status=='STRUCTURAL' then result.structural[#result.structural+1]=field end
  end
 end
 return result
end

-- Rev13.2 cached-metadata observer only. No result feeds resolver gates.
function __rev132SemanticNormalize(raw,control,identity)
 local function atom(v)
  local t=type(v)
  if t=='number' or t=='boolean' or t=='string' then return t..':'..tostring(v):gsub('[,|\r\n]','_'):sub(1,48) end
  return t
 end
 local function sorted(set)
  local a={}; for k in pairs(set) do a[#a+1]=k end; table.sort(a); return table.concat(a,',')
 end
 local function number(t) local n=0; for _ in pairs(t) do n=n+1 end; return n end
 local function tableValue(t,depth)
  if type(t)~='table' then return atom(t) end
  if depth>3 then return 'DEPTH_UNPROVEN' end
  local a,n={},0
  for k,v in pairs(t) do
   n=n+1; if n>256 then return 'SIZE_UNPROVEN' end
   local key=type(k)=='number' and '#' or atom(k)
   a[#a+1]=key..'='..tableValue(v,depth+1)
  end
  table.sort(a); return '{'..table.concat(a,';')..'}'
 end
 local known={attribute=true,abs_preset=true,rel_preset=true,abs_generator=true,rel_generator=true,generator=true,
  mask_active_phaser=true,mask_active_value=true,mask_cooked=true,mask_individual=true,mask_integrated=true,
  dict_flags=true,dict_index=true,gridposmatr=true,gridpos=true,grid=true,phase=true,speed=true,measure=true,
  fade=true,delay=true,selective=true,preset_store_mode=true,pm=true,ui_channel_index=true,
  grid_origin=true,grid_matrix=true,nshot_count=true,nshot_flags=true,speed_master=true}
 local stepKnown={absolute=true,relative=true,absolute_value=true,abs_release=true,rel_release=true,
  abs_remove=true,rel_remove=true,abs_preset=true,rel_preset=true,integrated=true,accel=true,decel=true,
  trans=true,transition=true,width=true,channel_function=true,mask_active=true,mask_individual=true,
  mask_integrated=true,dict_flags=true}
 local function core(p)
  local parts={}
  for _,field in ipairs({'preset_store_mode','pm','selective','mask_active_phaser','mask_individual',
   'mask_active_value','mask_cooked','mask_integrated'}) do parts[#parts+1]=field..'='..atom(p[field]) end
  local flags=p.dict_flags
  for _,field in ipairs({'has_absolute','has_relative','blocked','blocked_rel','selective'}) do
   parts[#parts+1]='dict_flags.'..field..'='..atom(type(flags)=='table' and flags[field] or nil)
  end
  if flags~=nil and type(flags)~='table' then parts[#parts+1]='dict_flags_type='..type(flags) end
  if type(flags)=='table' then for k,v in pairs(flags) do
   if not ({has_absolute=true,has_relative=true,blocked=true,blocked_rel=true,selective=true})[k]
    and v~=nil and v~=false and v~=0 then parts[#parts+1]='unknown_dict_flag='..atom(k)..'/'..tableValue(v,0) end
  end end
  local steps,first=0,nil
  for k,v in pairs(p) do
   if type(k)=='number' then steps=steps+1; if k==1 then first=v end
   elseif type(k)=='string' and not known[k] and v~=nil and v~=false and v~=0 then
    parts[#parts+1]='unknown_field='..k..'/'..tableValue(v,0) end
  end
  parts[#parts+1]='step_count='..steps
  if type(first)=='table' then
   parts[#parts+1]='ABS='..tostring(first.absolute~=nil)
   parts[#parts+1]='REL='..tostring(first.relative~=nil)
   for k,v in pairs(first) do if type(k)=='string' and not stepKnown[k] and v~=nil and v~=false and v~=0 then
    parts[#parts+1]='unknown_step='..k..'/'..tableValue(v,0) end end
   for _,field in ipairs({'abs_release','rel_release','abs_remove','rel_remove','abs_preset','rel_preset','integrated','accel','decel','trans','transition','width'}) do
    if first[field]~=nil and first[field]~=false and first[field]~=0 then parts[#parts+1]='step_effect='..field..'/'..tableValue(first[field],0) end
   end
  else parts[#parts+1]='step_type='..type(first) end
  table.sort(parts)
  return table.concat(parts,'|')
 end
 local function channels(data)
  local items,signatures={},{}
  if type(data)~='table' then return items,signatures,false end
  for ui,p in pairs(data) do if type(ui)=='number' then
   if type(p)~='table' or #items>=262144 then return items,signatures,false end
   items[#items+1]={ui=ui,p=p}; signatures[core(p)]=true
  end end
  return items,signatures,true
 end
 local items,candidateCore,candidateOK=channels(raw)
 local controlItems,controlCore,controlOK=channels(control)
 local function uiKeys(entries)
  local a={}; for _,entry in ipairs(entries) do a[#a+1]=tostring(entry.ui) end
  table.sort(a); return table.concat(a,',')
 end
 local out={semanticCoreMatch=candidateOK and controlOK and #items>0 and #controlItems>0 and sorted(candidateCore)==sorted(controlCore),
  channelCount=#items,controlChannelCount=#controlItems,blockers={},dictAudit={}}
 out.uiChannelKeyRelation=uiKeys(items)==uiKeys(controlItems) and 'SAME_NUMERIC_KEYS' or 'DIFFERENT_NUMERIC_KEYS'
  if not candidateOK or not controlOK then out.blockers.METADATA_SHAPE_UNPROVEN=true end
  if not out.semanticCoreMatch then out.blockers.SEMANTIC_CORE_DIFFERENCE=true end
  local indexes,types,uiExact,uiFieldExact,uiOffset={}, {},true,true,nil
  local attrToIndex,indexToAttr,gridToIndex,indexToGrid={},{},{},{}
  local attrsKnown,gridsKnown=true,true
  local function relate(left,right,m1,m2)
   if m1[left] and m1[left]~=right then return false end
   if m2[right] and m2[right]~=left then return false end
   m1[left]=right; m2[right]=left; return true
  end
  local attrBijection,gridBijection=true,true
  for _,item in ipairs(items) do
   local p,ui=item.p,item.ui; local di=p.dict_index
   local token=atom(di); indexes[token]=(indexes[token] or 0)+1; types[type(di)]=true
   if type(di)~='number' or math.type(di)~='integer' or di~=ui then uiExact=false end
   if p.ui_channel_index==nil or di~=p.ui_channel_index then uiFieldExact=false end
   if type(di)=='number' and type(ui)=='number' then
    local offset=di-ui; if uiOffset==nil then uiOffset=offset elseif uiOffset~=offset then uiOffset=false end
   else uiOffset=false end
   local attr=p.attribute and identity and identity(p.attribute)
   if not attr then attrsKnown=false else
    if not relate(attr,token,attrToIndex,indexToAttr) then attrBijection=false end end
   if p.gridpos==nil then gridsKnown=false else
    local grid=tableValue(p.gridpos,0)
    if grid:find('UNPROVEN',1,true) then gridsKnown=false end
    if not relate(grid,token,gridToIndex,indexToGrid) then gridBijection=false end
   end
  end
  local unique=number(indexes); local distribution={}
  for token,n in pairs(indexes) do distribution[#distribution+1]=token..':'..n end
  table.sort(distribution)
  out.dictAudit.channelCount=#items; out.dictAudit.uniqueCount=unique
  out.dictAudit.distribution='types='..sorted(types)..'/unique='..unique..'/sample='..table.concat(distribution,',',1,math.min(6,#distribution))
  out.dictAudit.relationUI=uiExact and 'EXACT_UI_KEY' or (uiFieldExact and 'EXACT_UI_CHANNEL_FIELD' or (uiOffset~=false and uiOffset~=nil and 'CONSTANT_OFFSET_'..tostring(uiOffset) or 'UNPROVEN'))
  out.dictAudit.relationAttribute=attrsKnown and attrBijection and 'BIJECTION_OBSERVED' or (attrsKnown and 'NOT_BIJECTIVE' or 'UNAVAILABLE')
  out.dictAudit.relationGrid=gridsKnown and gridBijection and 'BIJECTION_OBSERVED' or (gridsKnown and 'NOT_BIJECTIVE' or 'UNAVAILABLE')
  if #items==0 or number(types)~=1 or not types.number then
   out.dictAudit.classification='UNPROVEN'; out.dictAudit.reasons='DICT_INDEX_SHAPE_OR_CHANNELS_UNPROVEN'
  elseif uiExact or uiFieldExact then
   out.dictAudit.classification='IDENTITY_LIKE_ONLY'; out.dictAudit.reasons='EXACT_UI_IDENTITY_RELATION'
  elseif unique==#items and #items~=#controlItems then
   out.dictAudit.classification='CARDINALITY_DEPENDENT'; out.dictAudit.reasons='UNIQUE_PER_CHANNEL_WITH_DIFFERENT_CHANNEL_COUNT;SEMANTICS_UNPROVEN'
  else out.dictAudit.classification='UNPROVEN'; out.dictAudit.reasons='NO_PROVEN_IDENTITY_RELATION' end
  if out.dictAudit.classification~='IDENTITY_LIKE_ONLY' then out.blockers.DICT_INDEX_MEANING_UNPROVEN=true end
  return out
end

-- Diagnostic truth probe only. It consumes Rev11.1 surviving lane keys and
-- current-Cue cooked Part views; it never changes resolver inputs or gates.
function __globalRecipeApplicabilityTruth(records,targets,parts,referenceRaw,api)
 local function safe(f,...) local ok,v=pcall(f,...); if ok then return v end end
 local function emit(fmt,...) api.log(string.format(fmt,...)) end
 local function name(h) return h and (safe(function() return h.Name end) or safe(function() return h:Get('Name') end)) end
 local function ordered(t) local a={}; for k in pairs(t or {}) do a[#a+1]=k end; table.sort(a); return a end
 local function count(t) local n=0; for _ in pairs(t or {}) do n=n+1 end; return n end
 local function text(v) return v==nil and 'UNAVAILABLE' or tostring(v):gsub('[\r\n]',' '):sub(1,120) end
 local byKey,refs={},{}
 for _,entry in ipairs(targets or {}) do if entry.key then
  byKey[entry.key]=entry.path; refs[entry.path]={rows=0,matched=0,mismatch=0,inconclusive=0} end end
 local selected={}
 for _,rec in ipairs(records or {}) do if rec.category=='FINAL_SURVIVING_UNSAFE' then
  local key=rec.ref and safe(api.identity,rec.ref)
  if key and byKey[key] then selected[#selected+1]={record=rec,label=byKey[key],key=key} end
 end end
 local views,partCount={},0
 local seenParts={}
 for _,part in ipairs(parts or {}) do
  local key=safe(api.identity,part) or part
  if not seenParts[key] then
   seenParts[key]=true; partCount=partCount+1
   if partCount<=64 then
    local cooked=safe(api.getPresetData,part,false,true)
    views[key]={part=part,buckets=type(cooked)=='table' and cooked.by_fixtures or nil}
   end
  end
 end
 local total={rows=0,matched=0,mismatch=0,inconclusive=0,surviving=0,supported=0,linked=0,unsupported=0,different=0,unresolved=0}
 local mismatchShown,unsupportedShown=0,0
 local memberKeys={}
 for _,item in ipairs(selected) do
  local rec,label,key=item.record,item.label,item.key
  local row=rec.row
  local view=views[safe(api.identity,row.part) or row.part]
  local stats={surviving=0,supported=0,linked=0,unsupported=0,different=0,unresolved=0,members={},reasons={}}
  local attrsByLane={}
  local raw=referenceRaw[key]
  if type(raw)=='table' then for ui,p in pairs(raw) do if type(ui)=='number' and type(p)=='table' then
   local attr=p.attribute or (api.attributeByUI and safe(api.attributeByUI,ui))
   local attrName=name(attr)
   local feature=attr and safe(function() return attr.Feature end)
   local fg=feature and safe(function() return feature:Parent() end)
   local fgKey=fg and safe(api.identity,fg)
   if fgKey and type(attrName)=='string' and attrName~='' then
    for _,spec in ipairs({{'ABS','absolute'},{'REL','relative'}}) do
     local step=p[1]
     if type(step)=='table' and step[spec[2]]~=nil then
      local lane='FG:'..fgKey..'|'..spec[1]
      attrsByLane[lane]=attrsByLane[lane] or {}; attrsByLane[lane][attrName]=true
     end
    end
   end
  end end end
  for _,survivingKey in ipairs(rec.surviving or {}) do
   stats.surviving=stats.surviving+1
   local split=type(survivingKey)=='string' and survivingKey:find('\0',1,true)
   local member=split and tonumber(survivingKey:sub(1,split-1))
   local lane=split and survivingKey:sub(split+1)
   if member then stats.members[member]=true end
   local attrs=lane and attrsByLane[lane]
   local layer=lane and lane:match('|([^|]+)$')
   local attrNames=ordered(attrs)
   local matched,unsupported,unresolved,different=0,0,0,0
   if not member or not attrs or #attrNames==0 or (layer~='ABS' and layer~='REL') or not view or partCount>64 then
    unresolved=1; stats.reasons.LANE_OR_COOKED_VIEW_UNPROVEN=true
   else
    local fixture=api.getSubfixture and safe(api.getSubfixture,member)
    local fid=fixture and safe(function() return fixture.FID end)
    local cid=fixture and safe(function() return fixture.CID end)
    local noCid=cid==nil or cid=='None' or (type(cid)=='number' and cid==0)
    local fixtureKey=fid and tostring(fid)
    if not fixtureKey or not noCid or (memberKeys[fixtureKey] and memberKeys[fixtureKey]~=member) then
     unresolved=1; stats.reasons.MEMBER_KEY_UNPROVEN=true
    else
     memberKeys[fixtureKey]=member
     for _,attribute in ipairs(attrNames) do
      local found,observed=nil,nil
      local ambiguous=false
      for _,view in ipairs({view}) do
       local buckets=view.buckets
       if type(buckets)~='table' then ambiguous=true
       else
        local bucket=buckets[fixtureKey] or buckets[tonumber(fixtureKey)]
        if bucket~=nil and type(bucket)~='table' then ambiguous=true
        elseif type(bucket)=='table' and bucket[attribute]~=nil then
         if type(bucket[attribute])~='table' or found then ambiguous=true
         else found=bucket[attribute]; observed=view.part end
        end
       end
      end
      if ambiguous then unresolved=unresolved+1; stats.reasons.COOKED_ATTRIBUTE_MAPPING_UNPROVEN=true
      elseif found then
       local link=layer=='ABS' and found.abs_preset or found.rel_preset
       local expected=safe(api.identity,rec.ref)
       local actual=link and safe(api.identity,link)
       if expected and actual==expected then matched=matched+1
       elseif not expected or (link~=nil and not actual) then unresolved=unresolved+1; stats.reasons.PRESET_LINK_IDENTITY_UNPROVEN=true
       else
        different=different+1
        if mismatchShown<16 then
         mismatchShown=mismatchShown+1
         emit('GLOBAL_RECIPE_APPLICABILITY_MISMATCH reference=%s member=%s feature=%s layer=%s attribute=%s expected_preset=%s observed_preset=%s reason=PRESET_LINK_DIFFERENT',
          label,text(member),text(lane),layer,text(attribute),text(api.describe(rec.ref)),text(link and api.describe(link) or 'NONE'))
        end
       end
      else
       local capability=api.capability and safe(api.capability,fixture,attribute)
       if capability=='UNSUPPORTED' then
        unsupported=unsupported+1
        if unsupportedShown<16 then
         unsupportedShown=unsupportedShown+1
         emit('GLOBAL_RECIPE_APPLICABILITY_UNSUPPORTED reference=%s member=%s feature=%s layer=%s attribute=%s classification=FIXTURE_ATTRIBUTE_UNSUPPORTED',
          label,text(member),text(lane),layer,text(attribute))
        end
       else unresolved=unresolved+1; stats.reasons.ATTRIBUTE_CAPABILITY_UNPROVEN=true end
      end
     end
    end
   end
   if matched+different>0 then stats.supported=stats.supported+1 end
   if unsupported>0 then stats.unsupported=stats.unsupported+1 end
   if different>0 then stats.different=stats.different+1
   elseif unresolved>0 then stats.unresolved=stats.unresolved+1
   elseif matched>0 then stats.linked=stats.linked+1
   elseif unsupported>0 then -- proven unsupported attributes are neutral
   else stats.unresolved=stats.unresolved+1 end
  end
  local class
  if stats.different>0 then class='OBSERVED_APPLICABILITY_MISMATCH'
  elseif stats.unresolved>0 or stats.surviving==0 then class='INCONCLUSIVE'
  else class='RECIPE_SCOPE_MATCHED_AFTER_COMPATIBILITY' end
  total.rows=total.rows+1
  total.surviving=total.surviving+stats.surviving; total.supported=total.supported+stats.supported
  total.linked=total.linked+stats.linked; total.unsupported=total.unsupported+stats.unsupported
  total.different=total.different+stats.different; total.unresolved=total.unresolved+stats.unresolved
  local ref=refs[label]; ref.rows=ref.rows+1
  if class=='OBSERVED_APPLICABILITY_MISMATCH' then total.mismatch=total.mismatch+1; ref.mismatch=ref.mismatch+1
  elseif class=='INCONCLUSIVE' then total.inconclusive=total.inconclusive+1; ref.inconclusive=ref.inconclusive+1
  else total.matched=total.matched+1; ref.matched=ref.matched+1 end
  emit('GLOBAL_RECIPE_APPLICABILITY_ROW reference=%s source_cue=%s source_part=%s source_recipe=%s group=%s surviving_members=%d surviving_lanes=%d supported_lanes=%d expected_preset_link_lanes=%d unsupported_attribute_lanes=%d different_preset_lanes=%d unresolved_lanes=%d unresolved_reasons=%s classification=%s',
   label,text(api.describe(row.cue)),text(api.describe(row.part)),text(api.describe(row.recipe)),text(api.describe(row.group)),
   count(stats.members),stats.surviving,stats.supported,stats.linked,stats.unsupported,stats.different,stats.unresolved,table.concat(ordered(stats.reasons),','),class)
 end
 local summaryClass=total.rows~=15 and 'INCONCLUSIVE' or
  (total.mismatch>0 and 'OBSERVED_APPLICABILITY_MISMATCH' or
   (total.inconclusive>0 and 'INCONCLUSIVE' or 'RECIPE_SCOPE_MATCHED_AFTER_COMPATIBILITY'))
 emit('GLOBAL_RECIPE_APPLICABILITY_SUMMARY rows_expected=15 rows_checked=%d rows_matched=%d rows_mismatch=%d rows_inconclusive=%d surviving_lanes=%d supported_lanes=%d unsupported_attribute_lanes=%d different_preset_lanes=%d unresolved_lanes=%d classification=%s diagnostic_only=true cooked_part_reads=%d',
  total.rows,total.matched,total.mismatch,total.inconclusive,total.surviving,total.supported,total.unsupported,total.different,total.unresolved,summaryClass,math.min(partCount,64))
 for _,label in ipairs(ordered(refs)) do local s=refs[label]
  emit('GLOBAL_RECIPE_APPLICABILITY_REFERENCE reference=%s rows=%d matched=%d mismatch=%d inconclusive=%d',label,s.rows,s.matched,s.mismatch,s.inconclusive)
 end
 return {totals=total,classification=summaryClass,partReads=math.min(partCount,64)}
end

-- Rev7 observation only. No value-zero inference enters the candidate.
local function newRawRelZeroAudit(api)
 local patterns,order,states,linkedCache={},{},{REL_AUTHORED_PROVEN=0,REL_NOT_AUTHORED_PROVEN=0,REL_AMBIGUOUS=0},{}
 local function shown(v)
  if v==nil then return '<nil>' end
  if type(v)=='string' and v=='' then return '<empty>' end
  return tostring(v):gsub('[\r\n|]',' '):sub(1,80)
 end
 local function patternValue(v)
  if type(v)=='number' and v~=0 then return '<nonzero-number>' end
  return shown(v)
 end
 local function probe(h,key)
  local direct=api.safe(function() return h[key] end)
  local getter=api.safe(function() return h:Get(key) end)
  return 'direct='..type(direct)..':'..shown(direct)..',get='..type(getter)..':'..shown(getter)
 end
 local function linkedEvidence(h)
  if not api.isObject(h) or api.class(h):lower()~='preset' then return '<none>','<none>','<none>','<none>' end
  local id=api.identity(h)
  if id and linkedCache[id] then return table.unpack(linkedCache[id]) end
  local raw=id and api.raw[id]
  local info=type(raw)=='table' and api.ordinary(raw) or nil
  local masks,effective={},{}
  if type(raw)=='table' then for ui,p in pairs(raw) do if type(ui)=='number' and type(p)=='table' then
   masks[tostring(p.mask_active_value)]=true
   local step=p[1]
   if type(step)=='table' then effective['ABS:'..type(step.absolute)..'/REL:'..type(step.relative)]=true end
  end end end
  local result={info and api.joined(info.layers) or '<unknown>',api.joined(masks),api.joined(effective),info and info.completeness or 'UNKNOWN'}
  if id then linkedCache[id]=result end
  return table.unpack(result)
 end
 local function observe(node,step,linked)
  local m=api.metadata(node)
  local r=m.rawvaluerel; local v=r and r.raw
  local a=m.rawvalueabs; local av=a and a.raw
  local layer=m.layer or m.valuelayer
  local relProbe,absProbe=probe(node,'ValueRelative'),probe(node,'ValueAbsolute')
  local shape=m.shape and m.shape.raw~=nil and shown(m.shape.raw)~='<empty>'
  local attr=(m.attributes or m.attribute) and (m.attributes or m.attribute).raw
  local feature=api.isObject(attr) and api.safe(function() return attr.Feature end)
  local fg=api.isObject(feature) and api.safe(function() return feature:Parent() end)
  local linkedLayers,mask,effective,complete=linkedEvidence(linked)
  local classification,evidence='REL_AMBIGUOUS','RawValueRel zero encoding has no independent active-lane discriminator'
  if type(v)=='number' and v~=0 then
   classification='REL_AUTHORED_PROVEN'; evidence='vendor keypad maps ValueRelative to RawValueRel; nonzero raw numeric value'
  elseif type(v)=='string' and v:lower()=='none' then
   classification='REL_NOT_AUTHORED_PROVEN'; evidence='explicit None special suppresses this raw lane'
  elseif type(v)=='string' and v=='' then
   evidence='empty getter/raw display observed; native storage versus getter fallback unproven'
  end
  -- Numeric zero is deliberately never promoted by Layer labels, getter zero,
  -- a linked Preset mask, or a complete linked Preset with no REL lane.
  local signature=table.concat({type(v),patternValue(v),type(av),patternValue(av),relProbe,absProbe,shown(layer and layer.raw),linkedLayers,mask,effective,complete,tostring(shape),classification},'|')
  local p=patterns[signature]
  if not p then
   p={count=0,identity=api.identity(node),step=step,attribute=shown(attr),featureGroup=api.isObject(fg) and api.identity(fg) or '<unknown>',
    rawType=type(v),rawValue=shown(v),rawEnumerated=r~=nil,absType=type(av),absValue=shown(av),absEnumerated=a~=nil,
    relative=relProbe,absolute=absProbe,
    layer='Layer{enumerated='..tostring(m.layer~=nil)..',type='..tostring(m.layer and m.layer.type)..',info='..shown(m.layer and m.layer.info)..',raw='..shown(m.layer and m.layer.raw)..','..probe(node,'Layer')..'};ValueLayer{enumerated='..tostring(m.valuelayer~=nil)..',type='..tostring(m.valuelayer and m.valuelayer.type)..',info='..shown(m.valuelayer and m.valuelayer.info)..',raw='..shown(m.valuelayer and m.valuelayer.raw)..','..probe(node,'ValueLayer')..'}',
    linked=linked and api.identity(linked) or '<none>',linkedLayers=linkedLayers,mask=mask,effective=effective,linkedComplete=complete,
    shape=shape,classification=classification,evidence=evidence}
   patterns[signature]=p; order[#order+1]=p
  end
  p.count=p.count+1; states[classification]=states[classification]+1
  return classification
 end
 return {observe=observe,patterns=order,states=states}
end

local rawData=_G.GetPresetData
assert((safe(BuildDetails) or {}).BigVersion=='2.5.0.3','Requires grandMA3 2.5.0.3')
local sequence,cue=safe(_G.SelectedSequence),safe(_G.GetCurrentCue)
assert(sequence and cue and cueNumber(cue),'Select Sequence and Current Cue')
SelectedSequence=function() return sequence end
GetCurrentCue=function() return cue end
local function count(t) local n=0; for _ in pairs(t or {}) do n=n+1 end; return n end
local function text(v) return (v==nil and 'UNAVAILABLE' or tostring(v)):gsub('[\r\n]',' '):sub(1,240) end
local function desc(h) return text(commandAddress(h))..' ['..text(safe(HandleToStr,h))..']' end
local function log(fmt,...) nativePrintf('%s','[CueRecipeReverseAB] '..string.format(fmt,...)) end
local detailCount,diffDetailCount,detailsSuppressed=0,0,0
local function detail(fmt,...)
 local label=fmt:match('^([%w_]+)') or select(1,...)
 if type(label)=='string' and label:sub(1,4)=='DIFF' then
  if diffDetailCount>=150 then detailsSuppressed=detailsSuppressed+1; return end
  diffDetailCount=diffDetailCount+1
 else
  if detailCount>=500 then detailsSuppressed=detailsSuppressed+1; return end
  detailCount=detailCount+1
 end
 log(fmt,...)
end
local function now() return safe(Time) end
local function ms(a,b) return type(a)=='number' and type(b)=='number' and b>=a and (b-a)*1000 or 'UNVERIFIED' end
local identities={}
local function id(h)
 if not isObjectReference(h) then return nil end
 for i,v in ipairs(identities) do
  if h==v or safe(CompareHandle,h,v)==true then return i end
  local hi,vi=safe(_G.HandleToInt,h),safe(_G.HandleToInt,v)
  if type(hi)=='number' and math.type(hi)=='integer' and type(vi)=='number' and math.type(vi)=='integer' and hi~=0 and hi==vi then return i end
  local a,b=safe(HandleToStr,h),safe(HandleToStr,v)
  if a and b and a==b then return i end
 end
 identities[#identities+1]=h; return #identities
end
local phase,fastCalls,oracleCalls='FAST',0,0
GetPresetData=function(...)
 if phase=='FAST' then fastCalls=fastCalls+1; error('FAST_PATH_FORBIDDEN_GetPresetData') end
 assert(phase=='ORACLE','GETPRESETDATA_OUTSIDE_ORACLE'); oracleCalls=oracleCalls+1; return rawData(...)
end
local function joined(t) local a={}; for k in pairs(t or {}) do a[#a+1]=tostring(k) end; table.sort(a); return table.concat(a,',') end
local function sample(members)
 local ids={}; for member in pairs(members or {}) do ids[#ids+1]=member end; table.sort(ids)
 local a={}; for i=1,math.min(5,#ids) do a[#a+1]=tostring(ids[i]) end; return table.concat(a,',')
end
local auditor=newRecipeValueSourceAuditor({safe=safe,class=class,isObject=isObjectReference,
 objectList=_G.ObjectList,id=id,desc=desc,count=count,joined=joined,isGenerator=isRandomGenerator,enums=_G.Enums})
local patterns,patternOrder={},{}
local function retainAudit(row,data)
 for _,a in ipairs(data.audits) do
  local key=a.pattern
  local p=patterns[key]
  if not p then p={row=row,audit=a,data=data,count=0,recipes={}}; patterns[key]=p; patternOrder[#patternOrder+1]=p end
  p.count=p.count+1; p.recipes[row.recipe]=true
 end
end
log('START revision=7_RAW_REL_ZERO_SEMANTICS_PROOF target=2.5.0.3 sequence=%s cue=%s order=NATIVE_ONLY_THEN_REV4_BASELINE_THEN_REV5_BRIDGE_THEN_REV6_SEMANTICS_THEN_REV7_RAW_REL_PROOF_THEN_REV7_REVERSE_THEN_ORACLE production_flag=false no_waits=true no_markers=true',desc(sequence),desc(cue))
local start=now()
local rows,groups,cues={},{},{}
local stats={parts=0,rows=0,expansions=0,groups=0}
local result
local ok,err=pcall(function()
 local model=newCueEffectScan(sequence,cue) -- object tree only; no cooked calls
 for _,historyCue in ipairs(children(sequence)) do
  local n=cueNumber(historyCue)
  if class(historyCue):lower()=='cue' and n and n>0 and n<=cueNumber(cue) then cues[id(historyCue)]=true end
 end
 for i=#model.parts,1,-1 do
  local part=model.parts[i]; local owner=safe(function() return part:Parent() end)
  cues[id(owner) or desc(owner)]=true; stats.parts=stats.parts+1
  local recipes={}
  for ordinal,r in ipairs(children(part)) do if isStandardRecipe(r) then recipes[#recipes+1]={r=r,n=recipeNumber(r,ordinal),ordinal=ordinal} end end
  table.sort(recipes,function(a,b) if a.n==b.n then return a.ordinal>b.ordinal end; return a.n>b.n end)
  for _,item in ipairs(recipes) do
   stats.rows=stats.rows+1; assert(stats.rows<=2048,'Recipe row limit exceeded')
   local r=item.r
   if recipeEnabled(r) then
    local group,rawGroup=recipeField(r,'Selection')
    local ref,rawRef=recipeField(r,'Generator'); local field='Generator'
    if not ref then ref,rawRef=recipeField(r,'Values'); field='Values' end
    local row={recipe=r,part=part,cue=owner,group=group,ref=ref,refId=id(ref),unsafe={},field=field}
    local gid=id(group)
    if gid and class(group):lower()=='group' then
     if not groups[gid] then
      local selection=safe(function() return group.Selection end)
      local members,valid={},type(selection)=='table'
      if valid then for _,member in pairs(selection) do
       stats.expansions=stats.expansions+1; assert(stats.expansions<=262144,'Membership limit exceeded')
       local sf=type(member)=='table' and tonumber(member.sf_index)
       if sf and sf>=0 and sf%1==0 then members[sf]=true else valid=false end
      end end
      groups[gid]={members=valid and members or nil}; if valid then stats.groups=stats.groups+1 end
     end
     row.members=groups[gid].members
    end
    if not row.members then row.unsafe[#row.unsafe+1]='FAST_PATH_UNSAFE_SELECTION' end
    if ref then
     local data=auditor.inspect(ref); row.structural=data
     row.features=data.featureProven and data.features or nil
     row.layers=data.layerProven and data.layers or nil
     row.lanes=data.proven and data.lanes or nil
     row.moving=data.moving; row.motionReason=data.motionReason
     row.evidence=joined(data.reasons)
     retainAudit(row,data)
     local recipeMeta=auditor.metadata(r)
     row.recipeLayer=recipeMeta.layer and recipeMeta.layer.raw
     if not row.features then row.unsafe[#row.unsafe+1]='FAST_PATH_UNSAFE_FEATURE_SCOPE' end
     if not row.layers then row.unsafe[#row.unsafe+1]='FAST_PATH_UNSAFE_LAYER' end
     if not data.proven then row.unsafe[#row.unsafe+1]='UNVERIFIED' end
    else
     row.unsafe[#row.unsafe+1]='UNVERIFIED'; row.evidence='Unresolved '..field..'='..text(rawRef)..' Selection='..text(rawGroup)
    end
    rows[#rows+1]=row
   end
  end
 end
 result=recipeReverseResolve(rows)
 assert(fastCalls==0,'FAST_PATH_FORBIDDEN_GetPresetData_CALLS')
end)
local fastElapsed=ms(start,now())
result=result or {refs={},unsafe={},rejected={},assignments={}}
-- Immutable snapshot finalized before the oracle is even constructed.
local final={}; for rid,entry in pairs(result.refs) do final[rid]=entry.ref end
log('NATIVE_ONLY_FINALIZED valid=%s refs=%d GetPresetData_calls=%d',text(ok),count(final),fastCalls)
log('FAST_FINALIZED valid=%s refs=%d GetPresetData_calls=%d elapsed_ms=%s error=%s',text(ok),count(final),fastCalls,text(fastElapsed),text(err))
local function metrics()
 log('FAST_PATH_METRICS Cues=%d Parts=%d Recipe_rows=%d Stored_Groups=%d group_member_expansion=%d member_feature_lanes_resolved=%d empty_effective_rows=%d static_terminators=%d moving_contributing_rows=%d unsafe_rows=%d unresolved_symbolic_lanes=%d unknown_selection_rows=%d GetPresetData_calls=%d elapsed_ms=%s history_exhausted=%s',count(cues),stats.parts,stats.rows,stats.groups,stats.expansions,result.lanesResolved or 0,result.rowsSkipped or 0,result.staticRows or 0,result.movingRows or 0,#result.unsafe,#(result.unresolved or {}),result.unknownSelectionRows or 0,fastCalls,text(fastElapsed),text(ok))
end
metrics()
local function path(h) return desc(h)..' native='..text(h and address(h)) end
-- Separate native-only observation; immutable final and row proof gates stay unchanged.
local semanticsAudit=newReferenceSemanticsAudit({safe=safe,class=class,isObject=isObjectReference,
 desc=desc,metadata=auditor.metadata,joined=joined})
local semanticsSeen,semanticsPatterns={},{}
local semanticsStats={references=0,ordinary=0,moving=0,feature=0,layer=0,motion=0,static=0,unresolved=0}
local function auditText(v) return tostring(v):gsub('[\r\n]',' '):sub(1,6000) end
for _,row in ipairs(rows) do
 if row.refId and row.structural and not semanticsSeen[row.refId] then
  semanticsSeen[row.refId]=true
  local a=semanticsAudit(row.ref,row.structural,row.recipe)
  semanticsStats.references=semanticsStats.references+1
  if row.structural.sourceCount==0 and class(row.ref):lower()=='preset' then semanticsStats.ordinary=semanticsStats.ordinary+1 end
  if row.structural.sourceCount>0 then semanticsStats.moving=semanticsStats.moving+1 end
  if a.feature then semanticsStats.feature=semanticsStats.feature+1 end
  if a.layer then semanticsStats.layer=semanticsStats.layer+1 end
  if a.motion=='MOTION_PROVEN' then semanticsStats.motion=semanticsStats.motion+1
  elseif a.motion=='STATIC_PROVEN' then semanticsStats.static=semanticsStats.static+1 end
  if not a.feature or not a.layer or a.motion=='MOTION_UNPROVEN' then semanticsStats.unresolved=semanticsStats.unresolved+1 end
  if not semanticsPatterns[a.key] then
   semanticsPatterns[a.key]=true
   if count(semanticsPatterns)<=80 then
   log('REFERENCE_SEMANTICS_AUDIT reference=%s Recipe=%s Group=%s pool=%s pool_class=%s classes=%s native_feature_proven=%s native_layer_proven=%s motion=%s step_count=%d truncated=%s unresolved=%s interpretation=OBSERVATION_ONLY_POOL_LINKS_NOT_COMPLETE_CONTENT_PROOF',desc(row.ref),desc(row.recipe),desc(row.group),desc(a.pool),class(a.pool),a.classes,text(a.feature),text(a.layer),a.motion,a.stepCount,text(a.truncated),text(a.reason))
   log('REFERENCE_SEMANTICS_AUDIT_PROPERTIES reference=%s reference_properties=%s reference_links=%s probes=%s pool_properties=%s pool_links=%s pool_probes=%s',desc(row.ref),auditText(a.props),auditText(a.links),auditText(a.probes),auditText(a.poolProps),auditText(a.poolLinks),auditText(a.poolProbes))
   log('REFERENCE_SEMANTICS_AUDIT_STRUCTURE reference=%s Attributes=%s Shape=%s dependencies=%s Recipe_properties=%s Recipe_probes=%s',desc(row.ref),auditText(a.attributes),auditText(a.shapes),auditText(a.dependencies),auditText(a.rowProps),auditText(a.rowProbes))
   for i=1,math.min(8,#a.steps) do log('REFERENCE_SEMANTICS_AUDIT_STEP reference=%s evidence=%s',desc(row.ref),auditText(a.steps[i])) end
   if #a.steps>8 then log('REFERENCE_SEMANTICS_AUDIT_STEP_LIMIT reference=%s omitted=%d',desc(row.ref),#a.steps-8) end
   end
  end
 end
end
log('REFERENCE_SEMANTICS_SUMMARY distinct_references=%d distinct_patterns=%d native_only_Feature_proof=%d native_only_Layer_proof=%d MOTION_PROVEN=%d STATIC_PROVEN=%d unresolved_references=%d distinct_ordinary_Presets=%d distinct_ValueSource_references=%d metadata_GetPresetData_count=0 metadata_ms=0 metadata_comparison=NOT_RUN',semanticsStats.references,count(semanticsPatterns),semanticsStats.feature,semanticsStats.layer,semanticsStats.motion,semanticsStats.static,semanticsStats.unresolved,semanticsStats.ordinary,semanticsStats.moving)

for i,p in ipairs(patternOrder) do
 if i<=120 then
  local a,row,data=p.audit,p.row,p.data
  detail('VALUE_SOURCE_AUDIT pattern=%d occurrences=%d Recipe=%s Group=%s reference=%s native_classes=%s ValueSource=%s ValueSource_class=%s Attributes_property=%s Attributes_raw=%s Attributes_type=%s Attributes_handle_path=%s Feature=%s FeatureGroup=%s RawValueAbs=%s RawValueRel=%s effective_abs=%s effective_rel=%s Shape=%s Shape_handle=%s Shape_chain=%s Preset=%s Preset_handle=%s Layer=%s Recipe_Layer=%s proposed=%s confidence=%s attribute_proof=%s layer_proof=%s motion=%s unsafe_reason=%s reference_metadata=%s preset_metadata=%s source_metadata=%s',
   i,p.count,desc(row.recipe),desc(row.group),desc(row.ref),joined(data.classes),desc(a.node),text(a.sourceClass),text(a.attributeProperty),text(a.attribute),type(a.attribute),path(a.attributeHandle),path(a.feature),path(a.featureGroup),text(a.abs),text(a.rel),text(a.effectiveAbs),text(a.effectiveRel),text(a.shape),path(a.shapeHandle),text(a.shapeChain),text(a.preset),path(a.presetHandle),text(a.layer),text(row.recipeLayer),text(a.proposed),text(a.confidence),text(a.attributeProof),text(a.layerProof),text(a.motionReason),text(a.reason),text(data.refMeta),text(a.presetMetadata),text(a.metadata))
 end
end
log('VALUE_SOURCE_AUDIT_SUMMARY distinct_patterns=%d shown=%d suppressed=%d',#patternOrder,math.min(120,#patternOrder),math.max(0,#patternOrder-120))
local function trace(row,tag)
 local survivors=tag=='SOURCE' and row.movingSurvivors or row.survivors
 detail('%s ref=%s Cue=%s Part=%s Recipe=%s Group=%s features=%s layers=%s surviving_member_count=%d surviving_sample=%s group_member_count=%d member_sample=%s unsafe=%s motion_reason=%s evidence=%s',tag,desc(row.ref),desc(row.cue),desc(row.part),desc(row.recipe),desc(row.group),joined(row.features),joined(row.layers),count(survivors),sample(survivors),count(row.members),sample(row.members),table.concat(row.unsafe or {},','),text(row.motionReason),text(row.evidence))
end
local function identityOutput(tag,set,limit)
 limit=limit or 128
 log('%s count=%d',tag,count(set))
 local refs={}; for _,ref in pairs(set) do refs[#refs+1]=ref end
 table.sort(refs,function(a,b) return desc(a)<desc(b) end)
 for i=1,math.min(limit,#refs) do log('%s_REF reference=%s',tag,desc(refs[i])) end
 if #refs>limit then log('%s_DETAIL_LIMIT suppressed=%d exact_set_preserved_in_comparison=true',tag,#refs-limit) end
end
identityOutput('NATIVE_ONLY_FINAL',final)
log('RECIPE_ONLY_FINAL count=%d alias=NATIVE_ONLY_FINAL',count(final))
for rid,entry in pairs(result.refs) do
 detail('ACTIVE ref=%s surviving_member_count=%d surviving_sample=%s',desc(entry.ref),count(entry.members),sample(entry.members))
 for row in pairs(entry.sources) do trace(row,'SOURCE') end
end
for _,row in ipairs(result.unsafe) do trace(row,'UNSAFE') end
local unresolved,unresolvedCount={},0
for _,lane in ipairs(result.unresolved or {}) do
 local row=lane.row; unresolved[row]=unresolved[row] or {}
 local bucket=unresolved[row][lane.lane] or {}; unresolved[row][lane.lane]=bucket; bucket[lane.member]=true
end
for row,lanes in pairs(unresolved) do for lane,members in pairs(lanes) do
 unresolvedCount=unresolvedCount+1
 detail('UNRESOLVED Recipe=%s Group=%s feature_layer=%s member_count=%d member_sample=%s',desc(row.recipe),desc(row.group),lane,count(members),sample(members))
end end
log('UNSAFE_UNRESOLVED_SUMMARY unsafe_rows=%d unresolved_groups=%d symbolic_member_lanes=%d unknown_selection_rows=%d',#result.unsafe,unresolvedCount,#(result.unresolved or {}),result.unknownSelectionRows or 0)
for _,row in ipairs(result.rejected) do
 trace(row,'OLDER_REJECTED_OVERLAP')
 local losses={}
 for _,loss in ipairs(row.superseded) do
  losses[loss.newer]=losses[loss.newer] or {}
  local bucket=losses[loss.newer][loss.lane] or {sample=loss.member,n=0,unsafe=loss.unsafe}; losses[loss.newer][loss.lane]=bucket; bucket.n=bucket.n+1
 end
 for newer,lanes in pairs(losses) do for lane,bucket in pairs(lanes) do
  detail('FIRST_NEWER member=%s overlapping_member_count=%d lane=%s older_Recipe=%s newer_Cue=%s newer_Part=%s newer_Recipe=%s newer_Group=%s unsafe_barrier=%s',text(bucket.sample),bucket.n,lane,desc(row.recipe),desc(newer.cue),desc(newer.part),desc(newer.recipe),desc(newer.group),text(bucket.unsafe==true))
 end end
end
-- New run-local path starts after audit logging; audit overhead is excluded.
phase='METADATA'
local metadataStart=now()
local recipeTargets,dependencyTargets={},{}
local metadataCache
metadataCache=newReferenceMetadataCache({safe=safe,class=class,isObject=isObjectReference,
 handleToInt=_G.HandleToInt,handleToStr=_G.HandleToStr,attributeByUIChannel=_G.GetAttributeByUIChannel,
 now=now,log=log,desc=path,validateTarget=function(target,key)
  assert(phase=='METADATA' or phase=='BRIDGE','METADATA_READ_PHASE_VIOLATION')
  local c=class(target):lower()
  assert(c~='cue' and c~='part' and c~='cuepart' and c~='sequence','METADATA_FORBIDDEN_TARGET_'..c)
  assert(key==metadataCache.identity(target) and (recipeTargets[key] or (phase=='BRIDGE' and dependencyTargets[key])),'METADATA_TARGET_NOT_REGISTERED_REFERENCE')
 end,read=function(target,phasersOnly,byFixtures)
  assert(phase=='METADATA' or phase=='BRIDGE','METADATA_READ_PHASE_VIOLATION')
  return rawData(target,phasersOnly,byFixtures)
 end})
local metadataRows,metadataResult,metadataFinal={},{},{}
local metadataOK,metadataError=pcall(function()
 for _,row in ipairs(rows) do if row.ref then
  local key=metadataCache.register(row.ref); if key then recipeTargets[key]=true end
 end end
 -- Requests for reused references prove cache hits instead of re-reading.
 for _,row in ipairs(rows) do
  local m=row.ref and metadataCache.get(row.ref) or {completeness='UNKNOWN',motion='UNSAFE',evidence='RECIPE_REFERENCE_UNRESOLVED'}
  local copy={recipe=row.recipe,part=row.part,cue=row.cue,group=row.group,members=row.members,ref=row.ref,
   refId=row.refId,features=m.features,layers=m.layers,lanes=m.lanes,moving=m.motion=='MOVING' or m.motion=='GENERATOR',
   evidence=m.evidence,metadata=m,unsafe={}}
  if not copy.members then copy.unsafe[#copy.unsafe+1]='FAST_PATH_UNSAFE_SELECTION' end
  if m.completeness~='COMPLETE' or m.motion=='UNSAFE' then
   copy.unsafe[#copy.unsafe+1]='METADATA_REFERENCE_UNSAFE'
   -- Unknown scope blocks all lanes for these members. Partial scope is known.
   if not m.featureScopeKnown or not next(m.features or {}) then copy.features=nil end
   if not m.layerScopeKnown or not next(m.layers or {}) then copy.layers=nil end
  end
  metadataRows[#metadataRows+1]=copy
 end
end)
local cacheElapsed=ms(metadataStart,now())
local reverseStart=now()
if metadataOK then metadataOK,metadataError=pcall(function() metadataResult=recipeReverseResolve(metadataRows) end) end
local reverseElapsed=ms(reverseStart,now())
metadataResult=metadataResult or {refs={},unsafe={}}
for rid,entry in pairs(metadataResult.refs) do metadataFinal[rid]=entry.ref end
local totalMetadataElapsed=ms(metadataStart,now())
log('METADATA_REVERSE_FINALIZED valid=%s refs=%d error=%s',text(metadataOK),count(metadataFinal),text(metadataError))
local cs={}; for k,v in pairs(metadataCache.stats) do cs[k]=v end
log('BASELINE_METADATA_FINALIZED revision=4_REFERENCE_METADATA_CACHE refs=%d COMPLETE=%d PARTIAL=%d UNKNOWN=%d',count(metadataFinal),cs.COMPLETE,cs.PARTIAL,cs.UNKNOWN)
local function metadataMetrics()
 log('REFERENCE_METADATA_CACHE distinct_references=%d metadata_GetPresetData_calls=%d cache_hits=%d COMPLETE=%d PARTIAL=%d UNKNOWN=%d total_GetPresetData_native_ms=%s average_GetPresetData_ms=%s max_GetPresetData_ms=%s metadata_normalization_ms=%s cache_build_elapsed_ms=%s lifetime=SINGLE_RUN',cs.distinct_references,cs.calls,cs.cache_hits,cs.COMPLETE,cs.PARTIAL,cs.UNKNOWN,text(cs.timing_valid and cs.native_ms or 'UNVERIFIED'),text(cs.timing_valid and (cs.calls>0 and cs.native_ms/cs.calls or 0) or 'UNVERIFIED'),text(cs.timing_valid and cs.max_ms or 'UNVERIFIED'),text(cs.timing_valid and cs.normalization_ms or 'UNVERIFIED'),text(cacheElapsed))
 log('METADATA_REVERSE Recipe_rows_inspected=%d Stored_Groups=%d group_member_expansion=%d member_feature_lanes_resolved=%d rows_skipped_empty=%d static_terminators=%d moving_contributing_rows=%d unsafe_rows=%d final_refs=%d reverse_elapsed_ms=%s',#metadataRows,stats.groups,stats.expansions,metadataResult.lanesResolved or 0,metadataResult.rowsSkipped or 0,metadataResult.staticRows or 0,metadataResult.movingRows or 0,#metadataResult.unsafe,count(metadataFinal),text(reverseElapsed))
 log('TOTAL_METADATA_PATH_ELAPSED_MS value=%s excludes_Rev3_audit=true',text(totalMetadataElapsed))
end
metadataMetrics()
identityOutput('METADATA_REVERSE_FINAL',metadataFinal)
local metadataDetails=0
local function metadataDetail(fmt,...)
 if metadataDetails>=80 then detailsSuppressed=detailsSuppressed+1; return end
 metadataDetails=metadataDetails+1; log(fmt,...)
end
local printedMetadata={}
for _,row in ipairs(metadataRows) do
 local key=row.ref and metadataCache.identity(row.ref)
 if not printedMetadata[key or row.refId or row] then
  printedMetadata[key or row.refId or row]=true
  metadataDetail('REFERENCE_METADATA_NORMALIZED reference=%s identity=%s completeness=%s motion=%s features=%s layers=%s evidence=%s raw_shape=%s Attribute_chain=%s layer_evidence=%s',desc(row.ref),text(key),text(row.metadata.completeness),text(row.metadata.motion),joined(row.features),joined(row.layers),text(row.evidence),text(row.metadata.raw_shape),text(table.concat(row.metadata.attributeEvidence or {},';')),text(table.concat(row.metadata.layerEvidence or {},';')))
 end
end
for _,entry in pairs(metadataResult.refs) do
 metadataDetail('METADATA_ACTIVE reference=%s surviving_member_count=%d member_sample=%s',desc(entry.ref),count(entry.members),sample(entry.members))
 for row in pairs(entry.sources) do metadataDetail('METADATA_SOURCE reference=%s Cue=%s Part=%s Recipe=%s Group=%s features=%s layers=%s surviving_member_count=%d member_sample=%s',desc(row.ref),desc(row.cue),desc(row.part),desc(row.recipe),desc(row.group),joined(row.features),joined(row.layers),count(row.movingSurvivors),sample(row.movingSurvivors)) end
end
phase='BRIDGE'
local bridgeStart=now()
local bridge=newReferenceMetadataBridge({safe=safe,class=class,isObject=isObjectReference,identity=metadataCache.identity,
 metadata=auditor.metadata,desc=path,attributeByUIChannel=_G.GetAttributeByUIChannel})
local bridgeStats={direct=0,dependencies=0,dependencyHits=0,ordinary=0,phasers=0,complete=0,partial=0,unknown=0,static=0,moving=0,
 ordinaryMs=0,dependencyMs=0,phaserMs=0,normalizationMs=0}
local bridgedByIdentity,bridgeRows,bridgeResult,bridgeFinal={},{},{},{}
local bridgeOK,bridgeError=pcall(function()
 local refs={}
 for _,row in ipairs(rows) do if row.ref then local key=metadataCache.identity(row.ref); if key and not refs[key] then refs[key]=row end end end
 bridgeStats.direct=count(refs)
 local dependencies={}
 local function ordinaryFor(ref,isDependency)
  local key=metadataCache.identity(ref); if not key then return {features={},layers={},lanes={},motion='UNSAFE',completeness='UNKNOWN',evidence={STABLE_IDENTITY_UNAVAILABLE=true},source='ORDINARY_GETPRESETDATA'} end
  if isDependency then
   local valid=metadataCache.registerDependency(ref); if valid then dependencyTargets[valid]=true; dependencies[valid]=true end
  end
  local existed=metadataCache.timings[key]~=nil
  metadataCache.get(ref)
  local timing=metadataCache.timings[key]
  if timing and not existed then
   local elapsed=timing.read_ms+timing.normalization_ms
   if isDependency then bridgeStats.dependencyMs=bridgeStats.dependencyMs+elapsed else bridgeStats.ordinaryMs=bridgeStats.ordinaryMs+elapsed end
  elseif timing and not isDependency then bridgeStats.ordinaryMs=bridgeStats.ordinaryMs+timing.read_ms+timing.normalization_ms end
  local n=now(); local info=bridge.ordinary(metadataCache.raw[key]); local nm=ms(n,now())
  if type(nm)=='number' then bridgeStats.normalizationMs=bridgeStats.normalizationMs+nm end
  if isDependency then log('LINKED_PRESET_EVIDENCE reference=%s completeness=%s features=%s layers=%s reasons=%s',desc(ref),info.completeness,joined(info.features),joined(info.layers),joined(info.evidence)) end
  return info
 end
 local dependencyCache={}
 local function dependency(ref)
  local key=metadataCache.identity(ref)
  if not key then return ordinaryFor(ref,true) end
  if not dependencyCache[key] then dependencyCache[key]=ordinaryFor(ref,true) else bridgeStats.dependencyHits=bridgeStats.dependencyHits+1 end
  return dependencyCache[key]
 end
 for key,row in pairs(refs) do
  local direct=metadataCache.raw[key]
  local start=now(); local dependencyBefore=bridgeStats.dependencyMs; local normalizationBefore=bridgeStats.normalizationMs; local info
  if type(direct)=='table' and next(direct)~=nil and (row.structural or {}).sourceCount==0 then
   info=ordinaryFor(row.ref,false); bridgeStats.ordinary=bridgeStats.ordinary+1
  elseif row.structural and row.structural.recipeCount>0 then
   info=bridge.phaser(row.ref,row.structural,dependency); bridgeStats.phasers=bridgeStats.phasers+1
   local elapsed=ms(start,now()); if type(elapsed)=='number' then bridgeStats.phaserMs=bridgeStats.phaserMs+math.max(0,elapsed-(bridgeStats.dependencyMs-dependencyBefore)-(bridgeStats.normalizationMs-normalizationBefore)) end
  else
   info=ordinaryFor(row.ref,false); bridgeStats.ordinary=bridgeStats.ordinary+1
  end
  bridgedByIdentity[key]=info
  bridgeStats[info.completeness:lower()]=bridgeStats[info.completeness:lower()]+1
  if info.motion=='STATIC' then bridgeStats.static=bridgeStats.static+1 end
  if info.motion=='MOVING' then bridgeStats.moving=bridgeStats.moving+1 end
  local reasons=joined(info.evidence)
  log('BRIDGED_METADATA_REFERENCE reference=%s source=%s completeness=%s motion=%s motion_proof=%s phaser_structure=%s features=%s layers=%s channels=%d structural_steps=%d value_sources=%d shapes=%d dependencies=%d reasons=%s observations=%s',desc(row.ref),text(info.source),info.completeness,info.motion,text(info.motionProof),text(info.phaserStructure),joined(info.features),joined(info.layers),info.channels or 0,info.structuralSteps or 0,info.valueSources or 0,info.shapes or 0,info.dependencies or 0,text(reasons),text(joined(info.observations)))
  for i=1,math.min(8,#info.samples) do log('PHASER_BRIDGE_SOURCE_AUDIT reference=%s source_index=%d evidence=%s',desc(row.ref),i,auditText(info.samples[i])) end
  local patternList={}; for pattern,n in pairs(info.patterns) do patternList[#patternList+1]={pattern=pattern,n=n} end
  table.sort(patternList,function(a,b) return a.n>b.n end)
  for i=1,math.min(3,#patternList) do log('ORDINARY_REFERENCE_PATTERN reference=%s rank=%d occurrences=%d fields=%s example=%s',desc(row.ref),i,patternList[i].n,auditText(patternList[i].pattern),auditText(info.examples[patternList[i].pattern])) end
 end
 bridgeStats.dependencies=count(dependencies)
 for _,row in ipairs(rows) do
  local key=row.ref and metadataCache.identity(row.ref); local info=key and bridgedByIdentity[key]
  if not info then info={features={},layers={},lanes={},motion='UNSAFE',completeness='UNKNOWN',evidence={REFERENCE_UNAVAILABLE=true}} end
  local copy={recipe=row.recipe,part=row.part,cue=row.cue,group=row.group,ref=row.ref,refId=row.refId,members=row.members,
   features=info.features,layers=info.layers,lanes=info.lanes,moving=info.motion=='MOVING' or info.motion=='GENERATOR',unsafe={},evidence=joined(info.evidence)}
  if not copy.members then copy.unsafe[#copy.unsafe+1]='FAST_PATH_UNSAFE_SELECTION' end
  if info.completeness~='COMPLETE' then copy.unsafe[#copy.unsafe+1]='BRIDGED_REFERENCE_UNSAFE'
   if not info.featureScopeKnown or not next(info.features or {}) then copy.features=nil end
   if not info.layerScopeKnown or not next(info.layers or {}) then copy.layers=nil end
  end
  bridgeRows[#bridgeRows+1]=copy
 end
end)
local bridgeCacheElapsed=ms(bridgeStart,now())
local bridgedReverseStart=now()
if bridgeOK then bridgeOK,bridgeError=pcall(function() bridgeResult=recipeReverseResolve(bridgeRows) end) end
local bridgedReverseElapsed=ms(bridgedReverseStart,now())
bridgeResult=bridgeResult or {refs={},unsafe={}}
for rid,entry in pairs(bridgeResult.refs) do bridgeFinal[rid]=entry.ref end
local totalBridgedElapsed=(type(cacheElapsed)=='number' and type(bridgeCacheElapsed)=='number' and type(bridgedReverseElapsed)=='number') and (cacheElapsed+bridgeCacheElapsed+bridgedReverseElapsed) or 'UNVERIFIED'
log('BRIDGED_REVERSE_FINALIZED valid=%s refs=%d error=%s',text(bridgeOK),count(bridgeFinal),text(bridgeError))
log('ORDINARY_REFERENCE_SEMANTICS_SUMMARY references=%d static_proven=%d ordinary_metadata_cache_ms=%s',bridgeStats.ordinary,bridgeStats.static,text(bridgeStats.ordinaryMs))
log('PHASER_BRIDGE_SUMMARY references=%d moving_proven=%d native_bridge_ms=%s',bridgeStats.phasers,bridgeStats.moving,text(bridgeStats.phaserMs))
log('LINKED_PRESET_CACHE_SUMMARY recipe_reference_reads=%d dependency_reference_reads=%d linked_dependency_references=%d unique_reference_reads=%d cache_hits=%d dependency_normalized_cache_hits=%d native_GetPresetData_ms=%s dependency_cache_ms=%s',cs.calls,metadataCache.stats.calls-cs.calls,bridgeStats.dependencies,metadataCache.stats.calls,metadataCache.stats.cache_hits+bridgeStats.dependencyHits,bridgeStats.dependencyHits,text(metadataCache.stats.native_ms),text(bridgeStats.dependencyMs))
log('BRIDGED_METADATA_SUMMARY direct_Recipe_references=%d linked_dependency_references=%d COMPLETE=%d PARTIAL=%d UNKNOWN=%d normalization_ms=%s cache_build_elapsed_ms=%s',bridgeStats.direct,bridgeStats.dependencies,bridgeStats.complete,bridgeStats.partial,bridgeStats.unknown,text(bridgeStats.normalizationMs),text(bridgeCacheElapsed))
log('BRIDGED_REVERSE Recipe_rows_inspected=%d member_feature_lanes_resolved=%d rows_skipped_empty=%d static_terminators=%d moving_contributing_rows=%d unsafe_rows=%d reverse_elapsed_ms=%s',#bridgeRows,bridgeResult.lanesResolved or 0,bridgeResult.rowsSkipped or 0,bridgeResult.staticRows or 0,bridgeResult.movingRows or 0,#bridgeResult.unsafe,text(bridgedReverseElapsed))
log('TOTAL_BRIDGED_PATH_MS value=%s',text(totalBridgedElapsed))
identityOutput('BRIDGED_REVERSE_FINAL',bridgeFinal)
for _,entry in pairs(bridgeResult.refs) do log('BRIDGED_ACTIVE reference=%s surviving_member_count=%d',desc(entry.ref),count(entry.members)) end
local bridgeRejectedShown=0
for _,older in ipairs(bridgeResult.rejected or {}) do
 local buckets={}
 for _,loss in ipairs(older.superseded or {}) do
  local newer=loss.newer; buckets[newer]=buckets[newer] or {}
  local lane=buckets[newer][loss.lane] or {members={}}; buckets[newer][loss.lane]=lane
  lane.members[loss.member]=true
 end
 for newer,lanes in pairs(buckets) do for lane,bucket in pairs(lanes) do
  if bridgeRejectedShown<48 then
   bridgeRejectedShown=bridgeRejectedShown+1
   log('BRIDGED_REJECTED_OVERLAP older_ref=%s older_Recipe=%s older_Group=%s first_newer_Recipe=%s newer_Group=%s feature_layer=%s overlapping_member_count=%d sample=%s unsafe=%s',desc(older.ref),desc(older.recipe),desc(older.group),desc(newer.recipe),desc(newer.group),lane,count(bucket.members),sample(bucket.members),table.concat(newer.unsafe or {},','))
  end
 end end
end
log('BRIDGED_REJECTED_SUMMARY moving_rows_with_supersession=%d shown_overlap_groups=%d',#(bridgeResult.rejected or {}),bridgeRejectedShown)
log('REV5_BRIDGE_BASELINE finalized=true refs=%d COMPLETE=%d PARTIAL=%d UNKNOWN=%d',count(bridgeFinal),bridgeStats.complete,bridgeStats.partial,bridgeStats.unknown)
phase='SEMANTICS'
local semanticsStart=now()
local proof=newReferenceFieldSemantics({identity=metadataCache.identity,safe=safe})
local rev6Bridge=newReferenceMetadataBridge({safe=safe,class=class,isObject=isObjectReference,identity=metadataCache.identity,
 metadata=auditor.metadata,desc=path,attributeByUIChannel=_G.GetAttributeByUIChannel,fieldSemantics=proof})
local rev6ByIdentity,rev6Rows,rev6Result,rev6Final={},{},{},{}
local rev6Stats={ordinary=0,linked=0,phaser=0,complete=0,partial=0,unknown=0,static=0,ordinaryStatic=0,linkedStatic=0,moving=0}
local rev6OK,rev6Error=pcall(function()
 local refs={}
 for _,row in ipairs(rows) do if row.ref then local key=metadataCache.identity(row.ref); if key and not refs[key] then refs[key]=row end end end
 local dependencyCache={}
 local function ordinary(ref,linked)
  local key=metadataCache.identity(ref)
  if not key then return {features={},layers={},lanes={},motion='UNSAFE',completeness='UNKNOWN',evidence={STABLE_IDENTITY_UNAVAILABLE=true}} end
  local raw=metadataCache.raw[key]
  if raw==nil then return {features={},layers={},lanes={},motion='UNSAFE',completeness='UNKNOWN',evidence={REFERENCE_CACHE_MISS=true}} end
  proof.observe(ref,raw)
  local m=rev6Bridge.ordinary(raw)
  if linked then
   rev6Stats.linked=rev6Stats.linked+1
   if m.completeness=='COMPLETE' and m.motion=='STATIC' then rev6Stats.linkedStatic=rev6Stats.linkedStatic+1 end
  else
   rev6Stats.ordinary=rev6Stats.ordinary+1
   if m.completeness=='COMPLETE' and m.motion=='STATIC' then rev6Stats.ordinaryStatic=rev6Stats.ordinaryStatic+1 end
  end
  return m
 end
 local function dependency(ref)
  local key=metadataCache.identity(ref)
  if not key then return ordinary(ref,true) end
  if not dependencyCache[key] then dependencyCache[key]=ordinary(ref,true) end
  return dependencyCache[key]
 end
 for key,row in pairs(refs) do
  local raw=metadataCache.raw[key]; local info
  if type(raw)=='table' and next(raw)~=nil and (row.structural or {}).sourceCount==0 then info=ordinary(row.ref,false)
  elseif row.structural and row.structural.recipeCount>0 then
   info=rev6Bridge.phaser(row.ref,row.structural,dependency); rev6Stats.phaser=rev6Stats.phaser+1
  else info=ordinary(row.ref,false) end
  rev6ByIdentity[key]=info
  rev6Stats[info.completeness:lower()]=rev6Stats[info.completeness:lower()]+1
  if info.motion=='STATIC' then rev6Stats.static=rev6Stats.static+1 end
  if info.motion=='MOVING' then rev6Stats.moving=rev6Stats.moving+1 end
 end
 for _,row in ipairs(rows) do
  local key=row.ref and metadataCache.identity(row.ref)
  local info=key and rev6ByIdentity[key] or {features={},layers={},lanes={},motion='UNSAFE',completeness='UNKNOWN',evidence={REFERENCE_UNAVAILABLE=true}}
  local copy={recipe=row.recipe,part=row.part,cue=row.cue,group=row.group,ref=row.ref,refId=row.refId,members=row.members,
   features=info.features,layers=info.layers,lanes=info.lanes,moving=info.motion=='MOVING' or info.motion=='GENERATOR',unsafe={},evidence=joined(info.evidence)}
  if not copy.members then copy.unsafe[#copy.unsafe+1]='FAST_PATH_UNSAFE_SELECTION' end
  if info.completeness~='COMPLETE' then
   copy.unsafe[#copy.unsafe+1]='REV6_REFERENCE_UNSAFE'
   if not info.featureScopeKnown or not next(info.features or {}) then copy.features=nil end
   if not info.layerScopeKnown or not next(info.layers or {}) then copy.layers=nil end
  end
  rev6Rows[#rev6Rows+1]=copy
 end
end)
local semanticsElapsed=ms(semanticsStart,now())
local rev6ReverseStart=now()
if rev6OK then rev6OK,rev6Error=pcall(function() rev6Result=recipeReverseResolve(rev6Rows) end) end
local rev6ReverseElapsed=ms(rev6ReverseStart,now())
rev6Result=rev6Result or {refs={},unsafe={}}
for rid,entry in pairs(rev6Result.refs) do rev6Final[rid]=entry.ref end
local rev6Audit=proof.summary()
local fieldCount,patternCount=0,0
for _ in pairs(rev6Audit.fields) do fieldCount=fieldCount+1 end
for _ in pairs(rev6Audit.patterns) do patternCount=patternCount+1 end
log('REFERENCE_FIELD_SEMANTICS_SUMMARY fields=%d record_patterns=%d ordinary_references=%d linked_references=%d',fieldCount,patternCount,rev6Stats.ordinary,rev6Stats.linked)
for field,d in pairs(rev6Audit.fields) do
 local c=rev6Audit.classifications[field]
 local samples={}; for value,n in pairs(d.samples) do samples[#samples+1]=value..':'..n end; table.sort(samples)
 log('FIELD_SEMANTICS field=%s classification=%s channels=%d presets=%d varies_channels=%s varies_presets=%s types=%s values=%s evidence=%s',field,c[1],d.channels,count(d.refs),text(d.variesWithinPreset),text(d.variesAcrossPresets),joined(d.types),text(table.concat(samples,',')),text(c[2]))
end
local rawStateList={}; for state,n in pairs(rev6Audit.rawStates) do rawStateList[#rawStateList+1]=state..':'..n end; table.sort(rawStateList)
log('RAW_LAYER_SEMANTICS_SUMMARY states=%s raw_zero_encoding_unproven=true',table.concat(rawStateList,','))
log('ORDINARY_STATIC_PROOF_SUMMARY ordinary=%d static_proven=%d',rev6Stats.ordinary,rev6Stats.ordinaryStatic)
log('LINKED_PRESET_COMPLETENESS_SUMMARY linked_normalized=%d linked_static_complete=%d unique_native_reference_reads=%d extra_GetPresetData_calls=0',rev6Stats.linked,rev6Stats.linkedStatic,metadataCache.stats.calls)
log('PHASER_MOTION_PROOF_SUMMARY phaser_references=%d motion_proven=%d',rev6Stats.phaser,rev6Stats.moving)
log('REV6_BRIDGED_METADATA_SUMMARY COMPLETE=%d PARTIAL=%d UNKNOWN=%d semantics_ms=%s cache_reused=true',rev6Stats.complete,rev6Stats.partial,rev6Stats.unknown,text(semanticsElapsed))
log('REV6_BRIDGED_REVERSE_FINALIZED valid=%s refs=%d error=%s rows=%d lanes=%d static_terminators=%d moving_rows=%d unsafe_rows=%d reverse_ms=%s',text(rev6OK),count(rev6Final),text(rev6Error),#rev6Rows,rev6Result.lanesResolved or 0,rev6Result.staticRows or 0,rev6Result.movingRows or 0,#rev6Result.unsafe,text(rev6ReverseElapsed))
identityOutput('REV6_BRIDGED_REVERSE_FINAL',rev6Final)
for _,entry in pairs(rev6Result.refs) do log('REV6_ACTIVE reference=%s surviving_member_count=%d',desc(entry.ref),count(entry.members)) end
rev6Result.rev7=(function()
phase='RAW_REL_AUDIT'
local rev7PathStart=now()
local rawRelAuditStart=now()
local rawRelAudit=newRawRelZeroAudit({safe=safe,isObject=isObjectReference,class=class,identity=metadataCache.identity,
 metadata=auditor.metadata,raw=metadataCache.raw,ordinary=rev6Bridge.ordinary,joined=joined})
local seenSource={}
for _,row in ipairs(rows) do for _,a in ipairs((row.structural or {}).audits or {}) do
 local h=a.node; local key=h and metadataCache.identity(h)
 if key and not seenSource[key] and class(h):lower()=='phaserrecipevaluesource' then
  seenSource[key]=true
  local step=safe(function() return h:Parent():Index() end)
  rawRelAudit.observe(h,step,a.presetHandle)
 end
end end
local rawRelAuditElapsed=ms(rawRelAuditStart,now())
log('RAW_REL_ZERO_PATTERN_SUMMARY patterns=%d observations=%d shown=%d omitted=%d zero_encoding_proven=false',#rawRelAudit.patterns,count(seenSource),math.min(80,#rawRelAudit.patterns),math.max(0,#rawRelAudit.patterns-80))
for i,p in ipairs(rawRelAudit.patterns) do if i<=80 then
 log('RAW_REL_ZERO_PATTERN occurrences=%d ValueSource=%s Step=%s Attribute=%s FeatureGroup=%s RawValueAbs_enumerated=%s RawValueAbs_type=%s RawValueAbs=%s RawValueRel_enumerated=%s raw_type=%s raw_value=%s value_absolute=%s value_relative=%s layer_property=%s linked_preset=%s linked_layers=%s active_value_mask=%s linked_effective=%s linked_complete=%s Shape=%s classification=%s evidence=%s',
  p.count,text(p.identity),text(p.step),text(p.attribute),text(p.featureGroup),text(p.absEnumerated),p.absType,p.absValue,text(p.rawEnumerated),p.rawType,p.rawValue,text(p.absolute),text(p.relative),text(p.layer),text(p.linked),text(p.linkedLayers),text(p.mask),text(p.effective),p.linkedComplete,text(p.shape),p.classification,p.evidence)
end end
log('RAW_REL_ZERO_PROOF_SUMMARY REL_AUTHORED_PROVEN=%d REL_NOT_AUTHORED_PROVEN=%d REL_AMBIGUOUS=%d zero_promotions=0 additional_GetPresetData_calls=0 raw_rel_audit_ms=%s',rawRelAudit.states.REL_AUTHORED_PROVEN,rawRelAudit.states.REL_NOT_AUTHORED_PROVEN,rawRelAudit.states.REL_AMBIGUOUS,text(rawRelAuditElapsed))
-- Rev11: the proven Rev8.1 ValueRelative triple rule classifies REL zero as
-- authored or not-authored inside the Rev6 bridge; ABS zero stays unpromoted.
local rev7MetadataStart=now()
local rev7Rows={}
for _,row in ipairs(rows) do
 local key=row.ref and metadataCache.identity(row.ref)
 local info=key and rev6ByIdentity[key] or {features={},layers={},lanes={},motion='UNSAFE',completeness='UNKNOWN',evidence={REFERENCE_UNAVAILABLE=true}}
 local copy={recipe=row.recipe,part=row.part,cue=row.cue,group=row.group,ref=row.ref,refId=row.refId,members=row.members,
  features=info.features,layers=info.layers,lanes=info.lanes,moving=info.motion=='MOVING' or info.motion=='GENERATOR',unsafe={},evidence=joined(info.evidence)}
 if not copy.members then copy.unsafe[#copy.unsafe+1]='FAST_PATH_UNSAFE_SELECTION' end
 if info.completeness~='COMPLETE' then
  copy.unsafe[#copy.unsafe+1]='REV7_REFERENCE_UNSAFE'
  if not info.featureScopeKnown or not next(info.features or {}) then copy.features=nil end
  if not info.layerScopeKnown or not next(info.layers or {}) then copy.layers=nil end
 end
 rev7Rows[#rev7Rows+1]=copy
end
local rev7MetadataElapsed=ms(rev7MetadataStart,now())
local rev7ReverseStart=now()
local rev7OK,rev7Result=pcall(recipeReverseResolve,rev7Rows)
local rev7ReverseElapsed=ms(rev7ReverseStart,now())
local rev7Error
if not rev7OK then rev7Error=rev7Result; rev7Result=nil end
rev7Result=rev7Result or {refs={},unsafe={}}
local rev7Final={}; for rid,entry in pairs(rev7Result.refs) do rev7Final[rid]=entry.ref end
log('REV7_PHASER_MOTION_SUMMARY phaser_references=%d motion_proven=%d zero_promotions=0',rev6Stats.phaser,rev6Stats.moving)
log('REV7_BRIDGED_METADATA_SUMMARY COMPLETE=%d PARTIAL=%d UNKNOWN=%d metadata_ms=%s cache_reused=true additional_GetPresetData_calls=0',rev6Stats.complete,rev6Stats.partial,rev6Stats.unknown,text(rev7MetadataElapsed))
log('REV7_BRIDGED_REVERSE_FINALIZED valid=%s refs=%d error=%s rows=%d lanes=%d static_terminators=%d moving_rows=%d unsafe_rows=%d final_refs=%d reverse_ms=%s total_rev7_path_ms=%s',text(rev7OK),count(rev7Final),text(rev7Error),#rev7Rows,rev7Result.lanesResolved or 0,rev7Result.staticRows or 0,rev7Result.movingRows or 0,#rev7Result.unsafe,count(rev7Final),text(rev7ReverseElapsed),text(ms(rev7PathStart,now())))
identityOutput('REV7_BRIDGED_REVERSE_FINAL',rev7Final)
return {audit=rawRelAudit,rows=rev7Rows,result=rev7Result,final=rev7Final,ok=rev7OK}
end)()
phase='ORACLE'
log('ORACLE_START native_finalized=true metadata_finalized=true rev5_bridge_finalized=true rev6_finalized=true rev7_finalized=true')
local oracleLogs=0
oracleLogSink=function(line)
 oracleLogs=oracleLogs+1
 if oracleLogs<=40 then nativePrintf('%s','[CueRecipeReverseAB] ORACLE_TRACE '..line) end
end
local oracle,missing,extra={},{},{}
local oracleOK,oracleError=pcall(function()
 assert(type(rawData)=='function','Oracle GetPresetData unavailable')
 local state={poolBlink=true,running=true}
 -- Replay the same existing oracle used by Structural A/B, including its
 -- current-Cue merge and Recipe recovery. No native coroutines or waits.
 local completed=false
 for tick=0,131072 do
  refreshCueEffects(state,true)
  if state.effectError then error(state.effectError) end
  if not state.recipeScanPending and not state.effectScanPending and not state.effectScanner then completed=true; break end
 end
 assert(completed,'Oracle advance limit exceeded')
 for _,entry in pairs(state.activeEffects or {}) do local rid=id(entry.object); assert(rid,'Oracle identity unavailable'); oracle[rid]=entry.object end
end)
oracleLogSink=nil
identityOutput('ORACLE_FINAL',oracle)
if oracleOK then
 for rid,ref in pairs(oracle) do if not final[rid] then missing[rid]=ref end end
 for rid,ref in pairs(final) do if not oracle[rid] then extra[rid]=ref end end
end
local classifications={}
for _,row in ipairs(result.unsafe) do for _,reason in ipairs(row.unsafe) do classifications[reason]=true end end
-- Recipe-only authoring is the supported product contract. A reference with no
-- Recipe source is unsupported/unsafe, never grounds for a production fallback.
local stable=safe(_G.SelectedSequence)==sequence and safe(_G.GetCurrentCue)==cue
if not ok or not oracleOK or not stable or fastCalls~=0 then classifications.UNVERIFIED=true
elseif next(missing)==nil and next(extra)==nil then classifications.RECIPE_REVERSE_EXACT_MATCH=true
else
 if next(missing) then classifications.RECIPE_REVERSE_MISSING_REFERENCE=true end
 if next(extra) then classifications.RECIPE_REVERSE_EXTRA_REFERENCE=true end
 for rid in pairs(missing) do
  local found=false; for _,row in ipairs(rows) do if row.refId==rid then found=true end end
  if not found then classifications.FAST_PATH_UNSAFE_NON_RECIPE_DATA=true end
 end
end
for tag,set in pairs({MISSING=missing,EXTRA=extra}) do for rid,ref in pairs(set) do
 detail('DIFF_%s ref=%s',tag,desc(ref))
 local found=false
 for _,row in ipairs(rows) do if row.refId==rid then
  found=true; trace(row,'DIFF_SOURCE')
  local buckets={}
  for _,loss in ipairs(row.superseded or {}) do
   buckets[loss.newer]=buckets[loss.newer] or {}; local lane=buckets[loss.newer][loss.lane] or {}; buckets[loss.newer][loss.lane]=lane; lane[loss.member]=true
  end
  for newer,lanes in pairs(buckets) do for lane,members in pairs(lanes) do detail('DIFF_LANE feature_layer=%s member_count=%d member_sample=%s older_Recipe=%s newer_Recipe=%s newer_Group=%s',lane,count(members),sample(members),desc(row.recipe),desc(newer.recipe),desc(newer.group)) end end
 end end
 if not found then detail('DIFF_SOURCE ref=%s Group/member/feature/layer=UNVERIFIED no_Recipe_source=true',desc(ref)) end
end end
identityOutput('DIFF_MISSING',missing); identityOutput('DIFF_EXTRA',extra)
log('DIFF missing=%s extra=%s oracle_valid=%s details_suppressed=%d oracle_trace_suppressed=%d',oracleOK and count(missing) or 'UNVERIFIED',oracleOK and count(extra) or 'UNVERIFIED',text(oracleOK),detailsSuppressed,math.max(0,oracleLogs-40))
metrics()
local metadataMissing,metadataExtra,metadataClassifications={},{},{}
if not ok or fastCalls~=0 or not metadataOK or not oracleOK or not stable then metadataClassifications.UNVERIFIED=true
else
 for rid,ref in pairs(oracle) do if not metadataFinal[rid] then metadataMissing[rid]=ref end end
 for rid,ref in pairs(metadataFinal) do if not oracle[rid] then metadataExtra[rid]=ref end end
 if not next(metadataMissing) and not next(metadataExtra) then metadataClassifications.METADATA_REVERSE_EXACT_MATCH=true end
 if next(metadataMissing) then metadataClassifications.METADATA_REVERSE_MISSING_REFERENCE=true end
 if next(metadataExtra) then metadataClassifications.METADATA_REVERSE_EXTRA_REFERENCE=true end
end
if #metadataResult.unsafe>0 or cs.PARTIAL>0 or cs.UNKNOWN>0 then metadataClassifications.METADATA_REFERENCE_UNSAFE=true end
identityOutput('METADATA_DIFF_MISSING',metadataMissing); identityOutput('METADATA_DIFF_EXTRA',metadataExtra)
for _,row in ipairs(metadataRows) do
 if metadataMissing[row.refId] or metadataExtra[row.refId] then
  detail('DIFF_METADATA_SOURCE reference=%s Recipe=%s Group=%s member_count=%d member_sample=%s features=%s layers=%s completeness=%s evidence=%s',desc(row.ref),desc(row.recipe),desc(row.group),count(row.members),sample(row.members),joined(row.features),joined(row.layers),text(row.metadata.completeness),text(row.evidence))
  local losses={}
  for _,loss in ipairs(row.superseded or {}) do
   losses[loss.newer]=losses[loss.newer] or {}; local members=losses[loss.newer][loss.lane] or {}; losses[loss.newer][loss.lane]=members; members[loss.member]=true
  end
  for newer,lanes in pairs(losses) do for lane,members in pairs(lanes) do detail('DIFF_METADATA_LANE older_Recipe=%s newer_Recipe=%s newer_Group=%s feature_layer=%s member_count=%d member_sample=%s unsafe=%s',desc(row.recipe),desc(newer.recipe),desc(newer.group),lane,count(members),sample(members),table.concat(newer.unsafe,',')) end end
 end
end
metadataMetrics()
log('METADATA_DIFF missing=%s extra=%s classification=%s',oracleOK and count(metadataMissing) or 'UNVERIFIED',oracleOK and count(metadataExtra) or 'UNVERIFIED',joined(metadataClassifications))
log('METADATA_RESULT classification=%s native_refs=%d metadata_refs=%d oracle_refs=%d unsafe_rows=%d completeness_COMPLETE=%d completeness_PARTIAL=%d completeness_UNKNOWN=%d safe_integration=false',joined(metadataClassifications),count(final),count(metadataFinal),count(oracle),#metadataResult.unsafe,cs.COMPLETE,cs.PARTIAL,cs.UNKNOWN)
local bridgedMissing,bridgedExtra,bridgedClassifications={},{},{}
if not bridgeOK or not oracleOK or not stable then bridgedClassifications.UNVERIFIED=true
else
 for rid,ref in pairs(oracle) do if not bridgeFinal[rid] then bridgedMissing[rid]=ref end end
 for rid,ref in pairs(bridgeFinal) do if not oracle[rid] then bridgedExtra[rid]=ref end end
 if not next(bridgedMissing) and not next(bridgedExtra) then bridgedClassifications.BRIDGED_REVERSE_EXACT_MATCH=true end
 if next(bridgedMissing) then bridgedClassifications.BRIDGED_REVERSE_MISSING_REFERENCE=true end
 if next(bridgedExtra) then bridgedClassifications.BRIDGED_REVERSE_EXTRA_REFERENCE=true end
end
if #bridgeResult.unsafe>0 or bridgeStats.partial>0 or bridgeStats.unknown>0 then bridgedClassifications.BRIDGED_REFERENCE_UNSAFE=true end
identityOutput('BRIDGED_DIFF_MISSING',bridgedMissing,16); identityOutput('BRIDGED_DIFF_EXTRA',bridgedExtra,16)
local bridgedDiffShown=0
for _,row in ipairs(bridgeRows) do if (bridgedMissing[row.refId] or bridgedExtra[row.refId]) and bridgedDiffShown<25 then
 bridgedDiffShown=bridgedDiffShown+1
 detail('BRIDGED_DIFF_SOURCE reference=%s Cue=%s Part=%s Recipe=%s Group=%s feature=%s layer=%s members=%d sample=%s reasons=%s',desc(row.ref),desc(row.cue),desc(row.part),desc(row.recipe),desc(row.group),joined(row.features),joined(row.layers),count(row.members),sample(row.members),text(row.evidence))
end end
log('BRIDGED_DIFF missing=%s extra=%s classification=%s',oracleOK and count(bridgedMissing) or 'UNVERIFIED',oracleOK and count(bridgedExtra) or 'UNVERIFIED',joined(bridgedClassifications))
log('BRIDGED_RESULT classification=%s refs=%d oracle_refs=%d unsafe_rows=%d safe_integration=false',joined(bridgedClassifications),count(bridgeFinal),count(oracle),#bridgeResult.unsafe)
local rev6Missing,rev6Extra,rev6Classes={},{},{}
if not rev6OK or not oracleOK or not stable then rev6Classes.UNVERIFIED=true
else
 for rid,ref in pairs(oracle) do if not rev6Final[rid] then rev6Missing[rid]=ref end end
 for rid,ref in pairs(rev6Final) do if not oracle[rid] then rev6Extra[rid]=ref end end
 if not next(rev6Missing) and not next(rev6Extra) then rev6Classes.REV6_BRIDGED_EXACT_MATCH=true end
 if next(rev6Missing) then rev6Classes.REV6_BRIDGED_MISSING_REFERENCE=true end
 if next(rev6Extra) then rev6Classes.REV6_BRIDGED_EXTRA_REFERENCE=true end
end
if #rev6Result.unsafe>0 or rev6Stats.partial>0 or rev6Stats.unknown>0 then rev6Classes.REV6_REFERENCE_UNSAFE=true end
identityOutput('REV6_BRIDGED_DIFF_MISSING',rev6Missing,16)
identityOutput('REV6_BRIDGED_DIFF_EXTRA',rev6Extra,16)
local rev6DiffShown=0
for _,row in ipairs(rev6Rows) do if (rev6Missing[row.refId] or rev6Extra[row.refId]) and rev6DiffShown<25 then
 rev6DiffShown=rev6DiffShown+1
 detail('REV6_BRIDGED_DIFF_SOURCE reference=%s Cue=%s Part=%s Recipe=%s Group=%s feature=%s layer=%s members=%d sample=%s reasons=%s',desc(row.ref),desc(row.cue),desc(row.part),desc(row.recipe),desc(row.group),joined(row.features),joined(row.layers),count(row.members),sample(row.members),text(row.evidence))
end end
log('REV6_BRIDGED_DIFF missing=%s extra=%s classification=%s',oracleOK and count(rev6Missing) or 'UNVERIFIED',oracleOK and count(rev6Extra) or 'UNVERIFIED',joined(rev6Classes))
log('REV6_RESULT classification=%s refs=%d oracle_refs=%d unsafe_rows=%d safe_integration=false',joined(rev6Classes),count(rev6Final),count(oracle),#rev6Result.unsafe)
rev6Result.rev7Diff=(function()
local rev7Missing,rev7Extra,rev7Classes={},{},{}
if not rev6Result.rev7.ok or not oracleOK or not stable then rev7Classes.UNVERIFIED=true
else
 for rid,ref in pairs(oracle) do if not rev6Result.rev7.final[rid] then rev7Missing[rid]=ref end end
 for rid,ref in pairs(rev6Result.rev7.final) do if not oracle[rid] then rev7Extra[rid]=ref end end
 if not next(rev7Missing) and not next(rev7Extra) then rev7Classes.REV7_BRIDGED_EXACT_MATCH=true end
 if next(rev7Missing) then rev7Classes.REV7_BRIDGED_MISSING_REFERENCE=true end
 if next(rev7Extra) then rev7Classes.REV7_BRIDGED_EXTRA_REFERENCE=true end
end
if #rev6Result.rev7.result.unsafe>0 or rev6Stats.partial>0 or rev6Stats.unknown>0 then rev7Classes.REV7_REFERENCE_UNSAFE=true end
identityOutput('REV7_BRIDGED_DIFF_MISSING',rev7Missing,16)
identityOutput('REV7_BRIDGED_DIFF_EXTRA',rev7Extra,16)
log('REV7_BRIDGED_DIFF missing=%s extra=%s classification=%s',oracleOK and count(rev7Missing) or 'UNVERIFIED',oracleOK and count(rev7Extra) or 'UNVERIFIED',joined(rev7Classes))
log('REV7_RESULT classification=%s refs=%d oracle_refs=%d moving_rows=%d static_terminators=%d unsafe_rows=%d final_refs=%d safe_integration=false',joined(rev7Classes),count(rev6Result.rev7.final),count(oracle),rev6Result.rev7.result.movingRows or 0,rev6Result.rev7.result.staticRows or 0,#rev6Result.rev7.result.unsafe,count(rev6Result.rev7.final))
return {missing=rev7Missing,extra=rev7Extra,classes=rev7Classes}
end)()
-- Rev11.1 observation only: attribute Rev7 unsafe rows without touching gates,
-- refs, lanes, motion, or classifications. Isolated so an attribution failure
-- can never change resolver output.
local attributionStart=now()
local attributionOK,attribution=pcall(proof.attributeUnsafe,{rows=rev7Rows,result=rev6Result.rev7.result,final=rev6Result.rev7.final,infoByKey=rev6ByIdentity,identity=metadataCache.identity,desc=desc,joined=joined,sample=sample,count=count,text=text,log=log,detail=detail,now=now,ms=ms,reverseMs=rev7ReverseElapsed,totalMs=ms(rev7PathStart,now())})
if not attributionOK then log('UNSAFE_ATTRIBUTION_ERROR error=%s',text(attribution)); attribution={ok=false} end
-- Rev12: read cached ordinary reference data only. This observer never edits
-- Rev7 rows, classifications, final refs, or resolver gates.
attribution.ordinaryProofOK,attribution.ordinaryProof=pcall(function()
 local ordinaryProofStart=now()
 local seen,proofs,eligible={},{},{}
 local totals={ordinary=0,motionProven=0,motionUnproven=0,memberProven=0,memberUnproven=0,eligibleRows=0}
 for _,row in ipairs(rev6Result.rev7.rows or {}) do
  local key=row.ref and metadataCache.identity(row.ref)
  local info=key and rev6ByIdentity[key]
  if key and info and info.source=='ORDINARY_GETPRESETDATA' and not seen[key] then
   seen[key]=true
   local p=__rev12OrdinaryStaticInspect(metadataCache.raw[key]); proofs[key]=p
   totals.ordinary=totals.ordinary+1
   if p.motionStaticProven then totals.motionProven=totals.motionProven+1 else totals.motionUnproven=totals.motionUnproven+1 end
   if p.memberApplicabilityProven then totals.memberProven=totals.memberProven+1 else totals.memberUnproven=totals.memberUnproven+1 end
   local stepCounts={}; for n,c in pairs(p.steps) do stepCounts[#stepCounts+1]=n..':'..c end; table.sort(stepCounts)
   log('ORDINARY_STATIC_PROOF reference=%s channels=%d active_value_channels=%d non_grid_motion_channels=%d grid_position_channels=%d effective_step_counts=%s layer=%s store_mode=%s selective=%s motion_static_proven=%s member_applicability_proven=%s motion_blocking_reasons=%s member_blocking_reasons=%s',
    text(desc(row.ref)),p.channels,p.activeValue,p.nonGridMotion,p.gridPosition,table.concat(stepCounts,','),joined(p.layers),joined(p.modes),joined(p.selective),
    text(p.motionStaticProven),text(p.memberApplicabilityProven),joined(p.motionReasons),joined(p.memberReasons))
  end
 end
 for _,rec in ipairs(attribution.rows or {}) do
  if rec.category=='FINAL_SURVIVING_UNSAFE' then
   local key=rec.ref and metadataCache.identity(rec.ref)
   local p=key and proofs[key]
   local info=key and rev6ByIdentity[key]
   -- Static motion and member applicability must both be independently proven.
   if p and p.motionStaticProven and p.memberApplicabilityProven and info and info.featureScopeKnown and next(info.features or {})
      and next(info.layers or {}) and rec.row.members then totals.eligibleRows=totals.eligibleRows+1; eligible[rec.row]=true end
  end
 end
 local projected=attribution.finalSurviving or 0
 local alternate
 if totals.eligibleRows>0 then
  local alternateStart=now()
  local alternateRows={}
  for _,row in ipairs(rev6Result.rev7.rows or {}) do
   local copy={recipe=row.recipe,part=row.part,cue=row.cue,group=row.group,ref=row.ref,refId=row.refId,
    members=row.members,features=row.features,layers=row.layers,lanes=row.lanes,moving=row.moving,
    unsafe=row.unsafe,evidence=row.evidence}
   if eligible[row] then
    local info=rev6ByIdentity[metadataCache.identity(row.ref)]
    copy.features=info.features; copy.layers=info.layers; copy.lanes=info.lanes
    copy.moving=false; copy.unsafe={}
   end
   alternateRows[#alternateRows+1]=copy
  end
  local alternateResult=recipeReverseResolve(alternateRows)
  local alternateFinal={}; for rid,entry in pairs(alternateResult.refs) do alternateFinal[rid]=entry.ref end
  local silent=function() end
  local altAttribution=proof.attributeUnsafe({rows=alternateRows,result=alternateResult,final=alternateFinal,
   infoByKey=rev6ByIdentity,identity=metadataCache.identity,desc=desc,joined=joined,sample=sample,count=count,text=text,
   log=silent,detail=silent,now=now,ms=ms})
  projected=altAttribution.finalSurviving
  local missing,extra=0,0
  for rid in pairs(oracle) do if not alternateFinal[rid] then missing=missing+1 end end
  for rid in pairs(alternateFinal) do if not oracle[rid] then extra=extra+1 end end
  log('ORDINARY_STATIC_ALTERNATE refs=%d oracle_refs=%d missing=%s extra=%s unsafe_rows=%d final_surviving_unsafe=%d static_terminators=%d alternate_ms=%s diagnostic_only=true',
   count(alternateFinal),count(oracle),oracleOK and tostring(missing) or 'UNVERIFIED',oracleOK and tostring(extra) or 'UNVERIFIED',
   #alternateResult.unsafe,projected,alternateResult.staticRows or 0,text(ms(alternateStart,now())))
  alternate={final=alternateFinal,result=alternateResult,attribution=altAttribution,missing=missing,extra=extra}
 end
 log('ORDINARY_STATIC_PROOF_SUMMARY ordinary_refs=%d motion_static_proven=%d motion_static_unproven=%d member_applicability_proven=%d member_applicability_unproven=%d final_surviving_rows_before=%d projected_eligible_rows=%d projected_final_surviving_rows_after=%d extra_GetPresetData_calls=0 observer_ms=%s',
  totals.ordinary,totals.motionProven,totals.motionUnproven,totals.memberProven,totals.memberUnproven,
  attribution.finalSurviving or 0,totals.eligibleRows,projected,text(ms(ordinaryProofStart,now())))
 return {totals=totals,proofs=proofs,alternate=alternate}
end)
if not attribution.ordinaryProofOK then log('ORDINARY_STATIC_PROOF_ERROR error=%s',text(attribution.ordinaryProof)); attribution.ordinaryProof={ok=false} end
-- Rev13 diagnostic alternate: cached reference metadata only. The Preset 4.4
-- grid A/B observation covers its tested fixture/attribute class, not Cue 8.
local rev13OK,rev13=pcall(function()
 local start=now()
 local paths={'Preset 4.1','Preset 4.4','Preset 4.23','Preset 6.10','Preset 21.5'}
 local selected=__rev13SelectGlobalTargets(paths,_G.ObjectList,metadataCache.identity,class,attribution.rows)
 local control
 for _,entry in ipairs(selected.entries) do if entry.path=='Preset 4.4' and entry.key then control=metadataCache.raw[entry.key] end end
 local eligible,eligibleCount={},0
 local classified=0
 for _,entry in ipairs(selected.entries) do
  local label,key=entry.path,entry.key
  local raw=key and metadataCache.raw[key]
  local static=key and attribution.ordinaryProof and attribution.ordinaryProof.proofs and attribution.ordinaryProof.proofs[key]
  local scope=true
  for _,row in ipairs(entry.rows) do if not row.members or not next(row.members) then scope=false end end
  -- The reference cache has no cooked fixture/attribute compatibility evidence
  -- for these Cue 8 rows. Do not transfer the A/B result by shape alone.
  local p=__rev13GlobalApplicability(raw,control,static,scope and entry.rows[1] and entry.rows[1].members or nil,false)
  if not key or #entry.rows==0 then p.reasons.TARGET_MISSING_OR_NOT_FINAL_SURVIVING=true end
  local info=key and rev6ByIdentity[key]
  if not info or not info.featureScopeKnown or not next(info.features or {}) or not next(info.layers or {}) then p.reasons.FEATURE_OR_LAYER_SCOPE_UNPROVEN=true end
  local allowed=selected.pass and next(p.reasons)==nil
  if allowed then for _,row in ipairs(entry.rows) do eligible[row]=true; eligibleCount=eligibleCount+1 end end
  if key and #entry.rows>0 then classified=classified+1 end
  log('GLOBAL_APPLICABILITY_CLASS reference=%s rows=%d store_mode=%s selective=%s motion_static_proven=%s grid_mask_shape=%s individual_mask_shape=%s value_mask_shape=%s effective_step_shape=%s layer=%s semantic_shape=%s matches_native_proven_class=%s remaining_reasons=%s',
   label,#entry.rows,joined(p.modes),joined(p.selective),text(static and static.motionStaticProven),joined(p.gridMasks),joined(p.individualMasks),joined(p.valueMasks),joined(p.steps),joined(p.layers),p.semanticShape,text(allowed),joined(p.reasons))
  if selected.pass and label~='Preset 4.4' then
   local deltaOK,delta=pcall(__rev131SignatureDelta,control,raw)
   if deltaOK then
    log('GLOBAL_SIGNATURE_DELTA reference=%s different_components=%s key_identity_only_components=%s semantic_value_components=%s value_difference_components=%s structural_components=%s control_channel_count=%d candidate_channel_count=%d classification=OBSERVATION_ONLY',
     label,table.concat(delta.different,','),table.concat(delta.keyOnly,','),table.concat(delta.semanticValue,','),table.concat(delta.valueDifferences,','),table.concat(delta.structural,','),delta.controlChannels,delta.candidateChannels)
    for _,component in ipairs(delta.components) do
     log('GLOBAL_SIGNATURE_COMPONENT reference=%s component=%s control_type=%s candidate_type=%s control_count=%d candidate_count=%d key_sets_equal=%s value_type_shape_equal=%s semantic_status=%s',
      label,component.component,component.controlType,component.candidateType,component.controlCount,component.candidateCount,
      text(component.keySetsEqual),text(component.valueTypeShapeEqual),component.status)
    end
   else log('GLOBAL_SIGNATURE_DELTA_ERROR reference=%s error=%s',label,text(delta)) end
  end
  if selected.pass then
   local observationOK,observation=pcall(function()
    local normalized=__rev132SemanticNormalize(raw,control,metadataCache.identity)
    local delta=__rev131SignatureDelta(control,raw)
    local cardinality,grid={},{}
    for _,component in ipairs(delta.components) do
     if component.status=='CARDINALITY_ONLY' then cardinality[#cardinality+1]=component.component end
     if (component.component=='gridpos' or component.component=='gridposmatr')
      and component.status~='SAME' and component.status~='CARDINALITY_ONLY' then grid[#grid+1]=component.component end
    end
    if #grid>0 then normalized.blockers.GRID_VALUE_EFFECT_UNPROVEN=true end
    local audit=normalized.dictAudit
    log('GLOBAL_DICT_INDEX_AUDIT reference=%s channel_count=%d unique_dict_index_count=%d dict_index_distribution=%s relation_to_ui_channel=%s relation_to_attribute=%s relation_to_grid=%s relation_to_storage_source=UNAVAILABLE_FROM_REFERENCE_CHANNELS classification=%s reasons=%s',
     label,audit.channelCount,audit.uniqueCount,audit.distribution,audit.relationUI,audit.relationAttribute,audit.relationGrid,audit.classification,audit.reasons)
    log('GLOBAL_NORMALIZED_SEMANTIC_CLASS reference=%s semantic_core_match=%s ui_channel_key_relation=%s cardinality_only_differences=%s grid_value_differences=%s dict_index_class=%s remaining_semantic_blockers=%s observation_only=true',
     label,text(normalized.semanticCoreMatch),normalized.uiChannelKeyRelation,table.concat(cardinality,','),table.concat(grid,','),audit.classification,joined(normalized.blockers))
   end)
   if not observationOK then log('GLOBAL_NORMALIZED_SEMANTIC_ERROR reference=%s error=%s',label,text(observation)) end
  end
 end
 local targetPass=selected.pass and classified==#paths
 log('REV13_GLOBAL_TARGET_SUMMARY expected=%d found=%d classified=%d missing_targets=%s duplicate_targets=%s pass=%s',
  #paths,selected.found,classified,table.concat(selected.missing,','),table.concat(selected.duplicates,','),text(targetPass))
 local alternateRows={}
 for _,row in ipairs(rev6Result.rev7.rows or {}) do
  local copy={recipe=row.recipe,part=row.part,cue=row.cue,group=row.group,ref=row.ref,refId=row.refId,
   members=row.members,features=row.features,layers=row.layers,lanes=row.lanes,moving=row.moving,
   unsafe=row.unsafe,evidence=row.evidence}
  if eligible[row] then
   local info=rev6ByIdentity[metadataCache.identity(row.ref)]
   copy.features=info.features; copy.layers=info.layers; copy.lanes=info.lanes
   copy.moving=false; copy.unsafe={}
  end
  alternateRows[#alternateRows+1]=copy
 end
 local result=recipeReverseResolve(alternateRows)
 local final={}; for rid,entry in pairs(result.refs) do final[rid]=entry.ref end
 local silent=function() end
 local alt=proof.attributeUnsafe({rows=alternateRows,result=result,final=final,
  infoByKey=rev6ByIdentity,identity=metadataCache.identity,desc=desc,joined=joined,sample=sample,count=count,text=text,
  log=silent,detail=silent,now=now,ms=ms})
 local missing,extra=0,0
 for rid in pairs(oracle) do if not final[rid] then missing=missing+1 end end
 for rid in pairs(final) do if not oracle[rid] then extra=extra+1 end end
 log('REV13_GLOBAL_ALTERNATE refs=%d oracle_refs=%d missing=%s extra=%s unsafe_rows=%d final_surviving_unsafe=%d static_terminators=%d eligible_global_rows=%d classification=%s diagnostic_only=true alternate_ms=%s',
  count(final),count(oracle),oracleOK and tostring(missing) or 'UNVERIFIED',oracleOK and tostring(extra) or 'UNVERIFIED',
  #result.unsafe,alt.finalSurviving or 0,result.staticRows or 0,eligibleCount,
  targetPass and oracleOK and missing==0 and extra==0 and 'EXACT_MATCH' or 'INCONCLUSIVE',text(ms(start,now())))
 local remaining={}
 for _,rec in ipairs(alt.rows or {}) do if rec.category=='FINAL_SURVIVING_UNSAFE' then
  local label=desc(rec.ref); remaining[label]=(remaining[label] or 0)+1 end end
 local names={}; for label in pairs(remaining) do names[#names+1]=label end; table.sort(names)
 for _,label in ipairs(names) do log('REV13_GLOBAL_REMAINING reference=%s rows=%d',label,remaining[label]) end
 return {result=result,final=final,attribution=alt,eligible=eligibleCount}
end)
if not rev13OK then log('REV13_GLOBAL_ALTERNATE_ERROR error=%s',text(rev13)) end
-- Independent cooked truth observation for the 15 final-surviving Global
-- ordinary rows. It reads each row's source CuePart once after the oracle.
local truthStart=now()
local truthOK,truth=pcall(function()
 local paths={'Preset 4.1','Preset 4.4','Preset 4.23','Preset 6.10','Preset 21.5'}
 local selected=__rev13SelectGlobalTargets(paths,_G.ObjectList,metadataCache.identity,class,attribution.rows)
 if not selected.pass then return {partReads=0,classification='INCONCLUSIVE',targetPass=false} end
 local sourceParts={}
 for _,entry in ipairs(selected.entries) do for _,row in ipairs(entry.rows) do
  if row.part then sourceParts[#sourceParts+1]=row.part end
 end end
 local observation=__globalRecipeApplicabilityTruth(attribution.rows,selected.entries,sourceParts,metadataCache.raw,{
  log=function(s) log('%s',s) end,identity=metadataCache.identity,describe=desc,
  getPresetData=rawData,getSubfixture=_G.GetSubfixture,attributeByUI=_G.GetAttributeByUIChannel,
  -- No established native fixture-capability source: absence remains unknown.
  capability=function() return 'UNKNOWN' end})
 log('GLOBAL_RECIPE_APPLICABILITY_TIMING cooked_part_reads=%d observer_ms=%s target_pass=%s',
  observation.partReads,text(ms(truthStart,now())),text(selected.pass))
 return observation
end)
if not truthOK then log('GLOBAL_RECIPE_APPLICABILITY_ERROR error=%s',text(truth)) end
log('RESULT classification=%s Recipe_refs=%d oracle_refs=%d missing=%s extra=%s unsafe_rows=%d oracle_calls=%d fast_GetPresetData_calls=%d oracle_error=%s identity_set_only=true safe_integration=false bridged_refs=%d bridged_classification=%s',joined(classifications)..';'..joined(metadataClassifications),count(final),count(oracle),oracleOK and count(missing) or 'UNVERIFIED',oracleOK and count(extra) or 'UNVERIFIED',#result.unsafe,oracleCalls,fastCalls,text(oracleError),count(bridgeFinal),joined(bridgedClassifications))
log('END production_untouched=true markers=false waits=false metadata_targets=REFERENCE_ONLY cooked_history_fallback=false oracle_last=true')
return {rev7=rev6Result.rev7.result,rev7Final=rev6Result.rev7.final,rev7Rows=rev6Result.rev7.rows,rev7Missing=rev6Result.rev7Diff.missing,rev7Extra=rev6Result.rev7Diff.extra,rev7Classes=rev6Result.rev7Diff.classes,rev7OK=rev6Result.rev7.ok,attribution=attribution,attributionOK=attributionOK,rawRelAudit=rev6Result.rev7.audit,rev6=rev6Result,rev6Final=rev6Final,rev6Rows=rev6Rows,rev6Stats=rev6Stats,rev6Missing=rev6Missing,rev6Extra=rev6Extra,rev6Classes=rev6Classes,rev6OK=rev6OK,bridge=bridgeResult,bridgeFinal=bridgeFinal,bridgeRows=bridgeRows,bridgeStats=bridgeStats,bridgedMissing=bridgedMissing,bridgedExtra=bridgedExtra,bridgedClassifications=bridgedClassifications,bridgeOK=bridgeOK,metadata=metadataResult,metadataFinal=metadataFinal,metadataRows=metadataRows,metadataStats=cs,metadataMissing=metadataMissing,metadataExtra=metadataExtra,metadataClassifications=metadataClassifications,metadataOK=metadataOK,fast=result,final=final,oracle=oracle,missing=missing,extra=extra,classifications=classifications,stats=stats,fastCalls=fastCalls,oracleOK=oracleOK,oracleCalls=oracleCalls,fastOK=ok,rows=rows,patterns=patternOrder,detailsSuppressed=detailsSuppressed,unresolvedGroups=unresolvedCount}
end
