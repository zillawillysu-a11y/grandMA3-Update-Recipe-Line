-- Rev5 candidate. Rev4 normalize/cache result is immutable before this module runs.
local function newReferenceMetadataBridge(api)
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
     if type(k)~='number' and not known[k] then reason(m,'UNKNOWN_PHASER_FIELD_'..tostring(k)) end
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
      elseif v~=false and v~=0 and v~=nil then reason(m,'UNKNOWN_ACTIVE_DICTIONARY_FLAG_'..tostring(k)) end end end
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
     for k,v in pairs(step) do if not stepKnown[k] and v~=nil then reason(m,'UNKNOWN_STEP_FIELD_'..tostring(k)) end end
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
  return finish(m)
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
      if linkedMeta.completeness~='COMPLETE' then reason(m,'LINKED_PRESET_METADATA_UNSAFE') end
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
      if tonumber(v)==0 and not depLane then reason(m,'ZERO_RAW_LAYER_AMBIGUOUS_'..layer)
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
