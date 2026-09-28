-- Diagnostic only: native Attribute capability intersection per surviving
-- Global ordinary member-feature-layer lane. Observer only, never resolver rules.
-- Member capability comes from GetUIChannels/GetAttributeByUIChannel with a
-- proven index convention (fail closed when ambiguous), cached once per
-- canonical member handle. Reference sets reuse the cached reference metadata.
-- Cooked data is compared ONLY for intersecting supported Attributes.
-- Performs no GetPresetData calls and no selection/Cmd.
function __nativeAttributeCapabilityProbe(ctx,api)
 local function safe(f,...) local ok,v=pcall(f,...); if ok then return v end end
 local function emit(fmt,...) api.log(string.format(fmt,...)) end
 local function txt(v) return v==nil and 'nil' or tostring(v):gsub('[\r\n, ]','_'):sub(1,80) end
 local function name(h) return h and (safe(function() return h.Name end) or safe(function() return h:Get('Name') end)) end
 local function ordered(t) local a={}; for k in pairs(t or {}) do a[#a+1]=k end; table.sort(a); return a end
 local function count(t) local n=0; for _ in pairs(t or {}) do n=n+1 end; return n end
 local function same(a,b)
  if a==b then return true end
  local v=api.compareHandle and safe(api.compareHandle,a,b)
  if v==true then return true end
  local ia=a and safe(api.identity,a); local ib=b and safe(api.identity,b)
  return ia~=nil and ia==ib
 end
 local function validKey(a) return type(a)=='string' and a:match('^%d+[%.%d]*$') and not a:find('%.%.',1,true) and not a:match('%.$') end
 local function toaddrKey(v)
  if type(v)~='string' then return nil end
  local key=v:gsub('^%s+',''):gsub('%s+$',''):match('^Fixture%s+(%d+[%.%d]*)$')
  return validKey(key) and key or nil
 end
 local function isAttr(h)
  if not h then return false end
  if api.classHandle then
   local c=safe(api.classHandle,h)
   if type(c)=='string' then return c:lower()=='attribute' end
  end
  return name(h)~=nil
 end
 -- Capability cache: once per canonical member handle identity.
 local capCache,capReads={},{reads=0}
 local function memberCapability(h)
  local id=safe(api.identity,h) or h
  if capCache[id] then return capCache[id],true end
  capReads.reads=capReads.reads+1
  local result={complete=false,attrs={},names={}}
  local channels=api.getUIChannels and safe(api.getUIChannels,h,true)
  if type(channels)~='table' then capCache[id]=result; return result,false end
  local list={}; for _,u in pairs(channels) do
   if type(u)=='table' or type(u)=='userdata' then list[#list+1]=u end end
  if #list==0 then capCache[id]=result; return result,false end
  local idx,direct={},{}
  for _,u in ipairs(list) do
   local i=safe(function() return u.INDEX end)
   if type(i)~='number' then i=safe(function() return u:Get('INDEX') end) end
   if type(i)~='number' or i%1~=0 then capCache[id]=result; return result,false end
   idx[#idx+1]=i
   local d=safe(function() return u.Attribute end) or safe(function() return u:Get('Attribute') end)
   direct[#direct+1]=(d==nil or isAttr(d)) and d or false
   if direct[#direct]==false then capCache[id]=result; return result,false end
  end
  -- Prove the INDEX convention against direct Attribute evidence when present.
  local attrByUI=api.attributeByUI
  if type(attrByUI)~='function' then capCache[id]=result; return result,false end
  local hasDirect=false; for _,d in ipairs(direct) do if d~=nil then hasDirect=true end end
  local chosen=nil
  for _,c in ipairs({0,-1}) do
   local set,ok={},true
   for n,i in ipairs(idx) do
    local a=safe(attrByUI,i+c)
    if not isAttr(a) then ok=false; break end
    if hasDirect and direct[n]~=nil and not same(a,direct[n]) then ok=false; break end
    set[safe(api.identity,a) or a]={handle=a,name=name(a)}
   end
   if ok then
    if chosen then chosen=false; break end
    chosen={offset=c,set=set}
   end
  end
  if type(chosen)~='table' then capCache[id]=result; return result,false end
  result.complete=true; result.convention=chosen.offset; result.attrs=chosen.set
  for k,v in pairs(chosen.set) do result.names[k]=v.name end
  capCache[id]=result; return result,false
 end
 -- Reference Attribute handle sets per exact FeatureGroup+lane (read-only mirror).
 local byKey={}; for _,entry in ipairs(ctx.targets or {}) do if entry.key then byKey[entry.key]=entry.path end end
 local refSets={} -- refSets[label][lane][attrId]={handle,name}
 for _,entry in ipairs(ctx.targets or {}) do if entry.key then
  local raw=ctx.referenceRaw and ctx.referenceRaw[entry.key]
  if type(raw)=='table' then for ui,p in pairs(raw) do if type(ui)=='number' and type(p)=='table' then
   local attr=p.attribute or (api.attributeByUI and safe(api.attributeByUI,ui))
   if isAttr(attr) then
    local feature=attr and safe(function() return attr.Feature end)
    local fg=feature and safe(function() return feature:Parent() end)
    local fgId=fg and safe(api.identity,fg)
    local attrName=name(attr)
    if fgId and type(attrName)=='string' and attrName~='' then
     for _,spec in ipairs({{'ABS','absolute'},{'REL','relative'}}) do
      local step=p[1]
      if type(step)=='table' and step[spec[2]]~=nil then
       local lane='FG:'..fgId..'|'..spec[1]
       refSets[entry.path]=refSets[entry.path] or {}
       refSets[entry.path][lane]=refSets[entry.path][lane] or {}
       refSets[entry.path][lane][safe(api.identity,attr) or attr]={handle=attr,name=attrName}
      end
     end
    end
   end
  end end
 end end end
 local summary={lanes=0,applicable=0,notApplicable=0,unproven=0,expected=0,different=0,attrMissing=0,supportedMissing=0,explained=0}
 local alternate={total=0,mapped=0,missing=0,expected=0,different=0,unresolved=0}
 local refs={} -- per reference label
 local sampleN=0
 for _,rec in ipairs(ctx.records or {}) do if rec.category=='FINAL_SURVIVING_UNSAFE' then
  local key=rec.ref and safe(api.identity,rec.ref)
  local label=key and byKey[key]
  if label then
   local row=rec.row or {}
   for _,survivingKey in ipairs(rec.surviving or {}) do
    local split=type(survivingKey)=='string' and survivingKey:find('\0',1,true)
    local member=split and tonumber(survivingKey:sub(1,split-1))
    local lane=split and survivingKey:sub(split+1)
    local feature,layer
    if lane then feature,layer=lane:match('^(.-)|([^|]+)$') end
    local refinedLane=lane
    if layer=='*' then
     local proof=ctx.proofs and ctx.proofs[key]
     local uniqueAbs=proof and proof.motionStaticProven==true and type(proof.layers)=='table'
      and proof.layers.ABS==true and count(proof.layers)==1 and proof.channels>0
      and proof.activeValue==proof.channels and type(proof.steps)=='table'
      and proof.steps['1']==proof.channels and count(proof.steps)==1
     local concreteFeature=type(feature)=='string' and feature:match('^FG:')
      and type(row.features)=='table' and row.features[feature]==true
     local laneAttrs=refSets[label] and refSets[label][feature..'|ABS']
     if uniqueAbs and concreteFeature and laneAttrs then refinedLane=feature..'|ABS'; layer='ABS' end
    end
    local R=refs[label]
    if not R then R={lanes=0,applicable=0,notApplicable=0,unproven=0,expected=0,different=0,attrMissing=0}; refs[label]=R end
    local laneClass='ATTRIBUTE_CAPABILITY_UNPROVEN'
    local h=member and api.getSubfixture and safe(api.getSubfixture,member)
    local refLane=refinedLane and refSets[label] and refSets[label][refinedLane]
    local inter,interNames={},{}; local natCount,refCount=0,0
    local bucketExists,cached=false,false
    if member and h and (layer=='ABS' or layer=='REL') and feature and refLane then
     local cap,hit=memberCapability(h); cached=hit
     natCount=cap.complete and count(cap.attrs) or 0; refCount=count(refLane)
     if cap.complete and refCount>0 then
      for id,v in pairs(cap.attrs) do if refLane[id] then inter[id]=v; interNames[#interNames+1]=v.name end end
      table.sort(interNames)
      if #interNames>0 then
       laneClass='ATTRIBUTE_CAPABILITY_APPLICABLE'
       -- Cooked validation ONLY for intersecting Attributes, via ToAddr key.
       local key2=toaddrKey(h and safe(function() return h:ToAddr() end))
       local partKey=safe(api.identity,row.part) or row.part
       local view=ctx.views and ctx.views[partKey]
       local bucket=key2 and view and type(view.buckets)=='table' and view.buckets[key2]
       bucketExists=type(bucket)=='table'
       if not bucketExists then summary.supportedMissing=summary.supportedMissing+1; laneClass='SUPPORTED_ATTRIBUTE_BUT_COOKED_BUCKET_MISSING'
       else
        local matched,different,missing=false,false,false
        for _,n in ipairs(interNames) do
         local p=bucket[n]
         if type(p)~='table' then missing=true
         else
          local link=layer=='REL' and p.rel_preset or p.abs_preset
          local expected=safe(api.identity,rec.ref); local actual=link and safe(api.identity,link)
          if expected and actual==expected then matched=true elseif actual then different=true else missing=true end
         end
        end
        if different then summary.different=summary.different+1; R.different=R.different+1; laneClass='DIFFERENT_PRESET_LINK'
        elseif missing or not matched then summary.attrMissing=summary.attrMissing+1; R.attrMissing=R.attrMissing+1; laneClass='COOKED_ATTRIBUTE_MISSING'
        else summary.expected=summary.expected+1; R.expected=R.expected+1; laneClass='EXPECTED_PRESET_LINK' end
       end
      else
       laneClass='ATTRIBUTE_CAPABILITY_NOT_APPLICABLE'
       local key2=toaddrKey(h and safe(function() return h:ToAddr() end))
       local partKey=safe(api.identity,row.part) or row.part
       local view=ctx.views and ctx.views[partKey]
       local bucket=key2 and view and type(view.buckets)=='table' and view.buckets[key2]
       bucketExists=type(bucket)=='table'
       if not bucketExists then summary.explained=summary.explained+1; laneClass='BUCKET_ABSENCE_EXPLAINED_BY_NO_COMPATIBLE_ATTRIBUTE' end
      end
     end
    end
    summary.lanes=summary.lanes+1; R.lanes=R.lanes+1
    alternate.total=alternate.total+1
    if laneClass=='EXPECTED_PRESET_LINK' or laneClass=='COOKED_ATTRIBUTE_MISSING' or laneClass=='DIFFERENT_PRESET_LINK' then
     alternate.mapped=alternate.mapped+1
     if laneClass=='EXPECTED_PRESET_LINK' then alternate.expected=alternate.expected+1
     elseif laneClass=='DIFFERENT_PRESET_LINK' then alternate.different=alternate.different+1
     else alternate.unresolved=alternate.unresolved+1 end
    elseif laneClass=='SUPPORTED_ATTRIBUTE_BUT_COOKED_BUCKET_MISSING' or laneClass=='BUCKET_ABSENCE_EXPLAINED_BY_NO_COMPATIBLE_ATTRIBUTE' then
     alternate.missing=alternate.missing+1; alternate.unresolved=alternate.unresolved+1
    else alternate.unresolved=alternate.unresolved+1 end
    if laneClass=='ATTRIBUTE_CAPABILITY_NOT_APPLICABLE' or laneClass=='BUCKET_ABSENCE_EXPLAINED_BY_NO_COMPATIBLE_ATTRIBUTE' then
     summary.notApplicable=summary.notApplicable+1; R.notApplicable=R.notApplicable+1
    elseif laneClass=='EXPECTED_PRESET_LINK' or laneClass=='COOKED_ATTRIBUTE_MISSING' or laneClass=='SUPPORTED_ATTRIBUTE_BUT_COOKED_BUCKET_MISSING' or laneClass=='DIFFERENT_PRESET_LINK' then
     summary.applicable=summary.applicable+1; R.applicable=R.applicable+1
    else summary.unproven=summary.unproven+1; R.unproven=R.unproven+1 end
    if sampleN<24 then sampleN=sampleN+1
     local inames=table.concat(interNames,','):sub(1,80)
     if inames=='' then inames='-' end
     emit('NATIVE_ATTRIBUTE_CAPABILITY_SAMPLE reference=%s member=%s fixture_key=%s feature=%s layer=%s ui_channels=%s native_attribute_count=%d reference_attribute_count=%d intersection_count=%d intersection_attributes=%s cooked_bucket_exists=%s classification=%s',
      txt(label),txt(member),txt(h and toaddrKey(safe(function() return h:ToAddr() end))),txt(feature),txt(layer),
      txt(cached and 'cached' or 'enumerated'),natCount,refCount,#interNames,inames,tostring(bucketExists),laneClass)
    end
   end
  end
 end end
 for _,label in ipairs(ordered(refs)) do local R=refs[label]
  local class=R.unproven>0 and 'INCONCLUSIVE' or R.different>0 and 'OBSERVED_APPLICABILITY_MISMATCH' or 'CONSISTENT'
  emit('NATIVE_ATTRIBUTE_CAPABILITY_REFERENCE reference=%s surviving_lanes=%d applicable_lanes=%d not_applicable_lanes=%d unproven_lanes=%d expected_preset_link_lanes=%d different_preset_lanes=%d cooked_attribute_missing_lanes=%d classification=%s',
   txt(label),R.lanes,R.applicable,R.notApplicable,R.unproven,R.expected,R.different,R.attrMissing,class)
 end
 local classification=(summary.lanes>0 and summary.unproven==0 and summary.different==0 and summary.supportedMissing==0)
  and 'GLOBAL_ORDINARY_APPLICABILITY_PROVEN' or 'INCONCLUSIVE'
 emit('NATIVE_ATTRIBUTE_CAPABILITY_SUMMARY surviving_global_lanes=%d capability_applicable=%d capability_not_applicable=%d capability_unproven=%d expected_preset_link_lanes=%d different_preset_lanes=%d supported_but_bucket_missing=%d bucket_absence_explained=%d classification=%s diagnostic_only=true',
  summary.lanes,summary.applicable,summary.notApplicable,summary.unproven,summary.expected,summary.different,summary.supportedMissing,summary.explained,classification)
 emit('GLOBAL_OBJECTLIST_MEMBER_KEY_ALTERNATE total_lanes=%d mapped_bucket_lanes=%d bucket_missing_lanes=%d expected_preset_evidence_lanes=%d different_preset_lanes=%d attribute_unresolved_lanes=%d classification=%s diagnostic_only=true',
  alternate.total,alternate.mapped,alternate.missing,alternate.expected,alternate.different,alternate.unresolved,
  alternate.different>0 and 'OBSERVED_APPLICABILITY_MISMATCH' or alternate.unresolved>0 and 'INCONCLUSIVE' or 'SUPPORTED_LANES_MATCHED')
 return {summary=summary,refs=refs,capReads=capReads.reads,classification=classification}
end
