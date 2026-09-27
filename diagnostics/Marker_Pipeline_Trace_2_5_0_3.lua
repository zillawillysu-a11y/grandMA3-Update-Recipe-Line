-- Standalone read-only selected-group marker trace, target 2.5.0.3.
-- Production helpers copied verbatim from v0.7.0.17; no production execution.
return function()
local commandAddress, children, recipeNumber
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

local function isPhaserRecipePreset(values)
    if not isObjectReference(values) then return false end
    if string.find(string.lower(address(values)), "presetpools.phaser", 1, true) then return true end
    for _, child in ipairs(children(values)) do
        if string.lower(class(child)) == "phaserrecipe" then return true end
    end
    return false
end

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

local MAX_CUES, MAX_RECIPES = 512, 2048
local lines,outputLimited=0,false
 local function log(f,...) if lines>=1800 then outputLimited=true; return end; lines=lines+1; Printf('[MarkerTrace] '..f,...) end
 local function text(v) return v==nil and 'UNAVAILABLE' or tostring(v):gsub('[\r\n]',' '):sub(1,180) end
 local function method(h,k,...) return safe(function(...) return h[k](h,...) end,...) end
 local function raw(h,k) local v=safe(function() return h[k] end); if v==nil then v=method(h,'Get',k) end; return v end
 local function identity(h) return h and safe(HandleToStr,h) or nil end
 local function describe(h) return string.format('class=%s address=%s native=%s DB_handle=%s',text(class(h)),text(commandAddress(h)),text(method(h,'AddrNative')),text(identity(h))) end
 local function equal(a,b) return a~=nil and b~=nil and safe(function() return a==b end)==true end
 local function bool(v) local n=tostring(v):lower(); if v==true or n=='yes' or n=='true' or n=='1' then return true end; if v==false or n=='no' or n=='false' or n=='0' then return false end end
 local build=safe(BuildDetails); assert(type(build)=='table' and build.BigVersion=='2.5.0.3','Requires grandMA3 2.5.0.3')
 assert(callable('IsClassDerivedFrom') and callable('IsObjectValid') and callable('HandleToStr'),'Native UI type/identity APIs required')
 local original=rawget(_G,'RecipeTrackingInspectorState')
 if type(original)~='table' or original.version~='0.7.0.17' or not original.currentGroup then
  log('END classification=UNVERIFIED reason=PRODUCTION_SELECTED_GROUP_SNAPSHOT_UNAVAILABLE_OR_VERSION_MISMATCH required_version=0.7.0.17'); return {classification='UNVERIFIED'}
 end
 -- Copy only tables we read; all assignments below affect diagnostic locals.
 local state={}
 for _,k in ipairs({'version','currentGroup','currentRecipe','currentSequence','currentCue','currentSourceCue','currentSourceIsCurrent','currentPart','groupPoolReferenceKey','poolGridRefreshNeeded','window','running','poolBlink','poolBlinkTicks','poolMarkersDirty'}) do state[k]=original[k] end
 for _,k in ipairs({'matchingCandidates','groupPoolReferences','poolGrids','poolMarkers'}) do
  state[k]={}; for index,v in pairs(original[k] or {}) do state[k][index]=v end
 end
 local unsafe,incomplete,sourceError=false,false,nil
 local nativeReads=0; local unboundedSafe=safe
 safe=function(fn,...) nativeReads=nativeReads+1; if nativeReads>150000 then incomplete=true; return nil end; return unboundedSafe(fn,...) end
 local typed={}
 local function valid(h) if h==nil then return false end; local v=safe(IsObjectValid,h); return v~=nil and v~=false end
 local function isUI(h)
  if not valid(h) then return false end
  local k=class(h); if typed[k]==nil then typed[k]=k=='UIObject' or safe(IsClassDerivedFrom,k,'UIObject')==true end
  return typed[k]
 end
 local function ui(h,k,...) if not isUI(h) then unsafe=true; return nil end; return method(h,k,...) end
 local function actual(h)
  if not valid(h) then return false end
  local v=ui(h,'IsActuallyVisible'); if v==nil then return true end
  return bool(v)==true
 end
 local function uiChildren(h)
  local result=ui(h,'UIChildren'); return type(result)=='table' and result or children(h)
 end
 local records={}; local FIELDS={'Selection','Values','MAtricks','Filter','World','Generator'}
 local function referenceType(o)
  if isRandomGenerator(o) then return 'Generator' end
  if isPhaserRecipePreset(o) then return 'Phaser' end
  local k=class(o):lower(); if k=='group' then return 'Group' end
  if k:find('preset',1,true) or address(o):find('PresetPools.',1,true) then return 'Preset' end
  return class(o)~='' and class(o) or 'UNRESOLVED'
 end
 local function meaningful(rawValue)
  local s=tostring(rawValue or ''):lower():match('^%s*(.-)%s*$')
  return s~='' and s~='none' and s~='nil' and s~='no preset'
 end
 local function addRecord(ctx,fieldName,object,rawValue,origin,rejection)
  if not object and not meaningful(rawValue) then return end
  if #records>=160 then incomplete=true; return end
  local r={id=#records+1,ctx=ctx,field=fieldName,object=object,raw=rawValue,origin=origin,rejection=rejection,type=object and referenceType(object) or 'UNRESOLVED'}
  records[#records+1]=r
 end
 local function fields(ctx,origin,rejection,into)
  if #records>=160 then incomplete=true; return end
  for _,name in ipairs(FIELDS) do
   local o,t=recipeField(ctx.recipe,name); addRecord(ctx,name,o,t,origin,rejection)
   local key=commandAddress(o); if into and key then into[key]=o end
  end
 end
 local function context(cue,part,recipe,index)
  local selection=recipe and recipeField(recipe,'Selection') or nil
  local status='UNKNOWN'; local sourceNo,currentNo=cueNumber(cue),cueNumber(state.currentCue)
  if cue and equal(cue,state.currentCue) then status='DIRECT_CURRENT_CUE'
  elseif sourceNo and currentNo then
   if sourceNo<currentNo then status='EARLIER_RECIPE_STRUCTURAL_TRACKING'
   elseif sourceNo==currentNo then status='SAME_CUE_NUMBER_IDENTITY_UNVERIFIED'
   else status='FUTURE_SOURCE_CONTEXT' end
  end
  return {selection=selection,groupMatch=selection and sameReference(selection,state.currentGroup) or nil,cue=cue,part=part,recipe=recipe,index=index,direct=status}
 end
 log('START target=2.5.0.3 production_version=%s scope=SELECTED_GROUP_MARKER_PIPELINE_ONLY rendering=NOT_EXECUTED selected_group={%s} sequence={%s} current_cue={%s}',state.version,describe(state.currentGroup),describe(state.currentSequence),describe(state.currentCue))
 -- Independent source recomputation: same trackedGroupRecipeReferences sort,
 -- enabled/group/lane winner rules. Trace rejected rows without making them active.
 local function freshScoped()
  local result,rows={},{}; local number=cueNumber(state.currentCue)
  if not state.currentSequence or not number then return result end
  local cueCount,recipeCount,entries,rejectSamples=0,0,0,0
  local function rejected(row,origin,reason)
   if rejectSamples>=8 then return end; rejectSamples=rejectSamples+1
   for _,name in ipairs({'Values','Generator'}) do local o,t=recipeField(row.recipe,name); addRecord(row,name,o,t,origin,reason) end
  end
  for _,cue in ipairs(children(state.currentSequence)) do
   local n=cueNumber(cue)
   if class(cue):lower()=='cue' and n and n<=number then
    cueCount=cueCount+1; if cueCount>512 then error('Group Recipe scan exceeds 512 Cues') end
    for _,part in ipairs(children(cue)) do if class(part):lower()=='part' then
     for ordinal,recipe in ipairs(children(part)) do
      entries=entries+1; if entries>4096 then incomplete=true; error('Diagnostic source entry bound 4096') end
      if isStandardRecipe(recipe) then
       local enabled=recipeEnabled(recipe)
       if enabled then recipeCount=recipeCount+1; if recipeCount>2048 then error('Group Recipe scan exceeds 2048 Recipes') end end
       local group=recipeField(recipe,'Selection')
       if sameReference(group,state.currentGroup) then
        local row=context(cue,part,recipe,recipeNumber(recipe,ordinal) or ordinal)
        if enabled then rows[#rows+1]=row else rejected(row,'DISABLED_SOURCE_CANDIDATE','recipeEnabled:Enabled_false') end
       end
      end
     end
    end end
   end
  end
  table.sort(rows,function(a,b) local ac,bc=cueNumber(a.cue),cueNumber(b.cue); if ac~=bc then return ac>bc end; local ap,bp=partNumber(a.part),partNumber(b.part); if ap~=bp then return ap>bp end; return a.index>b.index end)
  local decided={}
  for rowOrdinal,row in ipairs(rows) do
   local ref=recipeField(row.recipe,'Generator'); if not ref then ref=recipeField(row.recipe,'Values') end
   local wins=false; local features={}
   if isObjectReference(ref) then
    features=recipeReferenceFeatures(ref)
    for _,feature in ipairs(features) do if not decided[feature] then decided[feature],wins=true,true end end
   end
   if rowOrdinal<=32 then log('SOURCE_ROW recipe={%s} cue={%s} part={%s} enabled=true selected_group_match=true features=%s wins=%s basis=STRUCTURAL_RECIPE_LANES_NOT_PLAYBACK_PROVENANCE',describe(row.recipe),describe(row.cue),describe(row.part),table.concat(features,','),text(wins)) end
   if wins then fields(row,'FRESH_SCOPED_WIN',nil,result)
   else rejected(row,'SCOPED_REJECTED',isObjectReference(ref) and 'trackedGroupRecipeReferences:feature_lane_already_decided' or 'trackedGroupRecipeReferences:Values_or_Generator_unresolved') end
  end
  log('SOURCE_SCAN qualified_rows=%d enabled_recipe_count=%d cues=%d rejected_row_samples=%d source_row_detail_limit=32',#rows,recipeCount,cueCount,rejectSamples)
  return result
 end
 local references={}
 if state.currentRecipe then
  fields(context(state.currentSourceCue,state.currentPart,state.currentRecipe,recipeNumber(state.currentRecipe)), 'CURRENT_RECIPE',nil,references)
 else
  for _,item in ipairs(state.matchingCandidates) do fields(context(item.cue,item.part,item.recipe,item.recipeIndex),'MATCHING_CANDIDATE',nil,references) end
 end
 addRecord(context(nil,nil,nil),'SelectedGroup',state.currentGroup,tostring(state.currentGroup),'SELECTED_GROUP')
 local groupKey=commandAddress(state.currentGroup); if groupKey then references[groupKey]=state.currentGroup end
 local referenceKey=(commandAddress(state.currentSequence) or address(state.currentSequence))..':'..tostring(cueNumber(state.currentCue) or '')..':'..(commandAddress(state.currentGroup) or address(state.currentGroup))
 local recompute=state.groupPoolReferenceKey~=referenceKey
 local ok,fresh=pcall(freshScoped); if not ok then sourceError=tostring(fresh); fresh={} end
 local scoped=recompute and fresh or state.groupPoolReferences
 if recompute then state.poolGridRefreshNeeded=true end
 for _,object in pairs(scoped) do
  local key=commandAddress(object); if key then references[key]=object end
  local explained=false
  for _,r in ipairs(records) do if r.object and sameReference(r.object,object) then explained=true; break end end
  if not explained then addRecord(context(nil,nil,nil),'CachedScopedReference',object,tostring(object),'CACHED_SOURCE_UNKNOWN') end
 end
 log('SOURCE_SET production_branch=%s stored_key=%s computed_key=%s source_scan_error=%s snapshot_only=true',recompute and 'RECOMPUTE_SCOPED' or 'REUSE_SCOPED_CACHE',text(state.groupPoolReferenceKey),referenceKey,text(sourceError))
 -- Exact production cache/discovery branch. No broad independent UI inventory.
 local grids,needsDiscovery={},state.poolGridRefreshNeeded==true
 for _,g in ipairs(state.poolGrids) do if actual(g) then grids[#grids+1]=g else needsDiscovery=true end end
 local nodes=0; local discovery= #grids==0 or needsDiscovery
 if discovery then
  grids={}; local visited,budget={},6000
  local function visit(node,depth)
   if not node or visited[node] or depth>20 or budget<=0 then return end
   visited[node],budget=true,budget-1; nodes=nodes+1
   if node==state.window then return end
   if class(node):find('PoolLayoutGrid',1,true) then if actual(node) then grids[#grids+1]=node end; return end
   for _,child in ipairs(uiChildren(node)) do visit(child,depth+1) end
  end
  if callable('GetDisplayByIndex') then for index=1,7 do visit(safe(GetDisplayByIndex,index),0) end
  elseif callable('GetFocusDisplay') then visit(safe(GetFocusDisplay),0) end
 end
 if #grids>64 then incomplete=true end
 local function visibility(h)
  if not isUI(h) then return nil,'UNAVAILABLE','UNAVAILABLE','UNAVAILABLE',nil end
  local a,b,c=ui(h,'IsActuallyVisible'),ui(h,'IsVisible'),raw(h,'Visible')
  local visible=bool(a)==true or bool(b)==true or bool(c)==true
  local p=h; local seen={}; local display
  for _=1,24 do
   if not isUI(p) or seen[p] then break end; seen[p]=true
   if bool(ui(p,'IsActuallyVisible'))==false or bool(ui(p,'IsVisible'))==false or bool(raw(p,'Visible'))==false then return false,a,b,c,display end
   local addr=commandAddress(p) or ''; display=display or tonumber(addr:match('^Display%s+(%d+)'))
   p=method(p,'Parent')
  end
  return visible and true or nil,a,b,c,display
 end
 local gridData={}
 for index=1,math.min(#grids,64) do
  local grid=grids[index]; local visible,a,b,c,display=visibility(grid)
  local g={id=index,grid=grid,pool=safe(function() return grid.PoolObject end),visible=visible,display=display,tiles={},complete=true,buttonCount=0,missingIndex=0,missingTarget=0}
  gridData[#gridData+1]=g
  local list=uiChildren(grid)
  for i,button in ipairs(list) do
   if i>2048 then g.complete=false; incomplete=true; break end
   local k=class(button):lower()
   local accepted=k:find('poolbutton',1,true)~=nil and k:find('pooltitlebutton',1,true)==nil
   local rawIndex=tonumber(property(button,'ObjectIndex'))
   if accepted then g.buttonCount=g.buttonCount+1; if not rawIndex then g.missingIndex=g.missingIndex+1 end end
   local idx=accepted and rawIndex or nil
   local target=idx and safe(function() return g.pool:Ptr(idx) end) or nil
   if idx and not target then g.missingTarget=g.missingTarget+1 end
   local key=commandAddress(target); local matched=key and references[key] or nil; local matchPath=matched and 'commandAddress_key' or nil
   if not matched and target then for _,ref in pairs(references) do if sameReference(target,ref) then matched=ref; matchPath='sameReference_fallback'; break end end end
   local diagnosticTarget=target or (not accepted and rawIndex and safe(function() return g.pool:Ptr(rawIndex) end) or nil)
   g.tiles[#g.tiles+1]={button=button,index=rawIndex,target=diagnosticTarget,productionTarget=target,accepted=accepted,matched=matched,matchPath=matchPath}
  end
  log('GRID grid=%d handle=%s address=%s native=%s display=%s pool_type=%s pool={%s} production_accepted=true current_visible=%s actual=%s IsVisible=%s Visible=%s children_inspected=%d complete=%s',index,text(identity(grid)),text(commandAddress(grid)),text(method(grid,'AddrNative')),text(display),text(raw(grid,'Pooltype')),describe(g.pool),text(visible),text(a),text(b),text(c),#g.tiles,text(g.complete))
 end
 log('POOL_SET branch=%s grids=%d nodes=%d budget_exhausted=%s',discovery and 'DISCOVERY' or 'REUSE_CACHE',#grids,nodes,text(nodes>=6000))
 local outputCounts={}; local results={}
 for _,r in ipairs(records) do
  local o=r.object; local key=commandAddress(o); local accepted=key and references[key]~=nil or false
  local parent=o and method(o,'Parent') or nil
  local owners,ownerSeen={},{}; local owner=parent
  for _=1,3 do if not valid(owner) or ownerSeen[owner] then break end; ownerSeen[owner]=true; owners[#owners+1]=owner; owner=method(owner,'Parent') end
  local expected= r.type=='Generator' and 'Generators/GeneratorRandom' or ((r.type=='Preset' or r.type=='Phaser') and 'Preset pool (Phaser is a preset source)' or r.type)
  local hintIndex=o and (tonumber(property(o,'Index') or property(o,'No')) or tonumber((commandAddress(o) or ''):match('(%d+)$'))) or nil
  log('SOURCE ref=%d selected_group={%s} sequence={%s} cue={%s} part={%s} recipe={%s} status=%s source_selection={%s} source_group_match=%s reference_type=%s field=%s origin=%s raw_reference=%s reference={%s} source_object_valid=%s expected_pool=%s parent_pool_hint={%s} expected_index_hint=%s',r.id,describe(state.currentGroup),describe(state.currentSequence),describe(r.ctx.cue),describe(r.ctx.part),describe(r.ctx.recipe),r.ctx.direct,describe(r.ctx.selection),text(r.ctx.groupMatch),r.type,r.field,r.origin,text(r.raw),describe(o),text(o and valid(o)),expected,describe(parent),text(hintIndex))
  local poolFound,tileFound,unknownVisibility,completeGrid=false,false,false,true
  local currentVisibleMatches,visibleIdentityMatches=0,0; local markerMatch=false; local rejectedButton=false; local targetMissing=false
  for _,g in ipairs(gridData) do
   local poolMatch=false
   for _,ancestor in ipairs(owners) do if sameReference(ancestor,g.pool) then poolMatch=true; break end end
   local matches={}; local targetMatch=false
   for _,t in ipairs(g.tiles) do
    local identityMatch=o and equal(t.target,o) or false
    local semanticMatch=o and sameReference(t.target,o) or false
    if semanticMatch then targetMatch=true end
    if semanticMatch or (poolMatch and hintIndex and t.index==hintIndex) then
     matches[#matches+1]=t
     local bv=visibility(t.button)
     local markerForRef=t.matched and o and sameReference(t.matched,o) or false
     local entry=state.poolMarkers[t.button]; local overlay=entry and entry.overlay
     local insertion=not t.matched and 'NOT_ACCEPTED_BY_scanGrid' or (overlay and valid(overlay) and 'REUSE_VALID_MARKER_ENTRY' or 'CONDITIONAL_APPEND_AND_CONFIGURATION_NOT_EXECUTED')
     log('TILE ref=%d grid=%d UI_button_handle=%s UI_button_class=%s button_visible=%s ObjectIndex=%s target={%s} handle_equal=%s handle_text_equal=%s command_equal=%s native_equal=%s sameReference=%s production_button_accepted=%s production_target_extraction_performed=%s production_match=%s match_path=%s would_insert_found_set=%s marker_set_decision=%s existing_overlay_handle=%s existing_overlay_valid=%s existing_overlay_Visible=%s button_W=%s button_H=%s overlay_W=%s overlay_H=%s',r.id,g.id,text(identity(t.button)),class(t.button),text(bv),text(t.index),describe(t.target),text(identityMatch),text(o and identity(o)~=nil and identity(o)==identity(t.target)),text(o and commandAddress(o)~=nil and commandAddress(o)==commandAddress(t.target)),text(o and method(o,'AddrNative')~=nil and method(o,'AddrNative')==method(t.target,'AddrNative')),text(semanticMatch),text(t.accepted),text(t.accepted and t.index~=nil),text(markerForRef),text(t.matchPath),text(t.matched~=nil),insertion,text(identity(overlay)),text(overlay and valid(overlay)),text(overlay and raw(overlay,'Visible')),text(raw(t.button,'W')),text(raw(t.button,'H')),text(overlay and raw(overlay,'W')),text(overlay and raw(overlay,'H')))
     if semanticMatch then
      tileFound=true
      if not t.accepted then rejectedButton=true end
      if markerForRef then markerMatch=true end
      if g.visible==true and bv==true and markerForRef then
       currentVisibleMatches=currentVisibleMatches+1
       if identityMatch or (identity(o)~=nil and identity(o)==identity(t.target)) then visibleIdentityMatches=visibleIdentityMatches+1 end
      end
      if bv==nil then unknownVisibility=true end
     elseif poolMatch and hintIndex and t.index==hintIndex and not t.target then targetMissing=true
     end
    end
   end
   if poolMatch or targetMatch then
    if g.visible==true then poolFound=true elseif g.visible==nil then unknownVisibility=true end
    if not g.complete then completeGrid=false end
    log('POOL_DISCOVERY ref=%d grid=%d expected_pool_match=%s tile_identity_or_text_match=%s current_visible=%s matching_buttons=%d production_button_count=%d non_numeric_ObjectIndex=%d unresolved_targets=%d grid_handle=%s grid_address=%s display=%s',r.id,g.id,text(poolMatch),text(targetMatch),text(g.visible),#matches,g.buttonCount,g.missingIndex,g.missingTarget,text(identity(g.grid)),text(commandAddress(g.grid)),text(g.display))
   end
  end
  local classification,reason
  if unsafe or incomplete or sourceError or outputLimited then classification='UNVERIFIED'; reason=sourceError or 'DIAGNOSTIC_BOUND_OR_NON_UI_GUARD'
  elseif not o then
   local value=tostring(r.raw or ''):lower()
   local addressLike=value:match('^preset%s+%d') or value:match('^generator%s+%d') or value:match('^random%s+%d') or value:match('^group%s+%d') or value:match('^matricks%s+%d') or value:match('^filter%s+%d') or value:match('^world%s+%d') or value:find('showdata.',1,true)
   classification=addressLike and 'SOURCE_RESOLUTION_MISS' or 'UNVERIFIED'; reason=addressLike and 'recipeField/resolveObjectReference:raw_reference_address_unresolved' or 'recipeField:readable_value_not_verified_as_object_link_may_be_display_metadata'
  elseif not valid(o) then classification='SOURCE_RESOLUTION_MISS'; reason='IsObjectValid:source_DB_handle_invalid'
  elseif not accepted then
   if not key then classification='MARKER_DECISION_REJECTED'; reason='recipePoolReferences.add:commandAddress_unavailable'
   elseif r.origin=='FRESH_SCOPED_WIN' and not recompute then classification='SOURCE_RESOLUTION_MISS'; reason='recipePoolReferences:unchanged_context_key_reuses_cache_missing_fresh_reference'
   else classification='MARKER_DECISION_REJECTED'; reason=r.rejection or 'recipePoolReferences:reference_not_in_final_set' end
  elseif state.poolBlink==false or not state.running then classification='MARKER_DECISION_REJECTED'; reason='refreshPoolMarkers:poolBlink_false_or_running_false'
  elseif visibleIdentityMatches>0 then classification='MARKER_PATH_COMPLETE'; reason='scanGrid:matched_found_button_and_DB_identity;overlay_creation_and_paint_not_tested'
  elseif currentVisibleMatches>0 then classification='UNVERIFIED'; reason='scanGrid:textual_match_accepted_but_source_target_DB_identity_not_verified'
  elseif unknownVisibility or not completeGrid then classification='UNVERIFIED'; reason='VISIBLE_POOL_OR_BUTTON_EVIDENCE_INSUFFICIENT'
  elseif not poolFound and #owners==0 then classification='UNVERIFIED'; reason='SOURCE_POOL_ASSOCIATION_UNAVAILABLE'
  elseif not poolFound then classification='POOL_DISCOVERY_MISS'; reason='refreshPoolMarkers:grid_set_has_no_confirmed_visible_source_pool'
  elseif not tileFound then classification='TILE_MATCH_MISS'; reason=targetMissing and 'scanGrid:PoolObject_Ptr_ObjectIndex_unresolved' or 'scanGrid:no_AllPoolButton_target_sameReference_for_source'
  elseif not markerMatch then classification='MARKER_DECISION_REJECTED'; reason=rejectedButton and 'scanGrid:isPoolItemButton_false' or 'scanGrid:final_reference_set_does_not_match_resolved_target'
  else classification='UNVERIFIED'; reason='scanGrid:production_match_accepted_but_button_hidden;render_visibility_not_proven' end
  local nextTick=(tonumber(state.poolBlinkTicks) or 0)+1
  log('DECISION ref=%d reference_accepted=%s visible_pool_found=%s tile_match_found=%s production_matched=%s visible_matched_buttons=%d visible_identity_matches=%d running=%s poolBlink=%s next_tick_lookup_skipped=%s replay=NEXT_ELIGIBLE_LOOKUP classification=%s rejection_function_reason=%s',r.id,text(accepted),text(poolFound),text(tileFound),text(markerMatch),currentVisibleMatches,visibleIdentityMatches,text(state.running),text(state.poolBlink),text(nextTick%2~=0 and not state.poolMarkersDirty),classification,reason)
  outputCounts[classification]=(outputCounts[classification] or 0)+1; results[#results+1]={classification=classification,reason=reason,record=r,accepted=accepted,markerMatch=markerMatch}
 end
 if #records==0 then log('SUMMARY classification=UNVERIFIED reason=NO_EXPECTED_REFERENCE_RECORDS') end
 for k,n in pairs(outputCounts) do log('SUMMARY classification=%s references=%d',k,n) end
 Printf('[MarkerTrace] END references=%d production_grids=%d source_recomputed_for_diagnostic=true production_state_unchanged=true drawing=NOT_EXECUTED source_error=%s bounded=%s UI_guard_deviation=%s protected_reads=%d output_capped=%s',#records,#grids,text(sourceError),text(incomplete),text(unsafe),nativeReads,text(outputLimited))
 return {records=results,classification=(#records==0 or incomplete or unsafe or sourceError or outputLimited) and 'UNVERIFIED' or 'PER_REFERENCE',references=references}
end
