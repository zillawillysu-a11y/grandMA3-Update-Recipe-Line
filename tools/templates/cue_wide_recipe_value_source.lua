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
