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
