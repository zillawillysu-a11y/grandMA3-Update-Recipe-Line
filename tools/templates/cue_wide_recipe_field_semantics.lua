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
 local function rawLayer(layer,v,linked,fg,effective,props)
  local scope=props and props.layer and props.layer.raw
  -- No 2.5 reference defines ValueSource Layer property or raw zero encoding.
  -- Even an apparently opposite Layer label is only an audit clue.
  local state='AMBIGUOUS'
  rawStates[layer..'_'..state]=rawStates[layer..'_'..state]+1
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
 return {accept=accept,ordinary=ordinary,rawLayer=rawLayer,observe=observe,summary=summary}
end
