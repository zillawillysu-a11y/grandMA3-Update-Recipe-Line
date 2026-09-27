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
 local cache,allowed,unidentified={},{},{}
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
  stats.normalization_ms=stats.normalization_ms+elapsed(ns)
  cache[key]=m; stats[m.completeness]=stats[m.completeness]+1
  return m
 end
 return {get=get,register=register,identity=identity,stats=stats,cache=cache,normalize=normalize}
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
log('START revision=4_REFERENCE_METADATA_CACHE target=2.5.0.3 sequence=%s cue=%s order=NATIVE_ONLY_THEN_REFERENCE_METADATA_REVERSE_THEN_ORACLE production_flag=false no_waits=true no_markers=true',desc(sequence),desc(cue))
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
local function identityOutput(tag,set)
 log('%s count=%d',tag,count(set))
 local refs={}; for _,ref in pairs(set) do refs[#refs+1]=ref end
 table.sort(refs,function(a,b) return desc(a)<desc(b) end)
 for i=1,math.min(128,#refs) do log('%s_REF reference=%s',tag,desc(refs[i])) end
 if #refs>128 then log('%s_DETAIL_LIMIT suppressed=%d exact_set_preserved_in_comparison=true',tag,#refs-128) end
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
local recipeTargets={}
local metadataCache
metadataCache=newReferenceMetadataCache({safe=safe,class=class,isObject=isObjectReference,
 handleToInt=_G.HandleToInt,handleToStr=_G.HandleToStr,attributeByUIChannel=_G.GetAttributeByUIChannel,
 now=now,log=log,desc=path,validateTarget=function(target,key)
  assert(phase=='METADATA','METADATA_READ_PHASE_VIOLATION')
  local c=class(target):lower()
  assert(c~='cue' and c~='part' and c~='cuepart' and c~='sequence','METADATA_FORBIDDEN_TARGET_'..c)
  assert(key==metadataCache.identity(target) and recipeTargets[key],'METADATA_TARGET_NOT_RECIPE_REFERENCE')
 end,read=function(target,phasersOnly,byFixtures)
  assert(phase=='METADATA','METADATA_READ_PHASE_VIOLATION')
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
local cs=metadataCache.stats
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
phase='ORACLE'
log('ORACLE_START native_finalized=true metadata_finalized=true')
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
log('RESULT classification=%s Recipe_refs=%d oracle_refs=%d missing=%s extra=%s unsafe_rows=%d oracle_calls=%d fast_GetPresetData_calls=%d oracle_error=%s identity_set_only=true safe_integration=false',joined(classifications)..';'..joined(metadataClassifications),count(final),count(oracle),oracleOK and count(missing) or 'UNVERIFIED',oracleOK and count(extra) or 'UNVERIFIED',#result.unsafe,oracleCalls,fastCalls,text(oracleError))
log('END production_untouched=true markers=false waits=false fallback_during_fast_path=false')
return {metadata=metadataResult,metadataFinal=metadataFinal,metadataRows=metadataRows,metadataStats=cs,metadataMissing=metadataMissing,metadataExtra=metadataExtra,metadataClassifications=metadataClassifications,metadataOK=metadataOK,fast=result,final=final,oracle=oracle,missing=missing,extra=extra,classifications=classifications,stats=stats,fastCalls=fastCalls,oracleCalls=oracleCalls,fastOK=ok,oracleOK=oracleOK,rows=rows,patterns=patternOrder,detailsSuppressed=detailsSuppressed,unresolvedGroups=unresolvedCount}
end
