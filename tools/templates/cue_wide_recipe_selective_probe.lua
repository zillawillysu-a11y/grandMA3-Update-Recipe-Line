-- Diagnostic only: Selective Preset member applicability through native
-- UI-channel ownership intersection. Observer only, never resolver rules.
-- Member UI indexes come from GetUIChannels(h,true) with the proven INDEX-1
-- contract; reference UI records reuse the cached Selective raw data.
-- No new GetPresetData calls. No selection/Cmd. Fully-superseded rows are
-- never active targets.
function __selectiveMemberApplicabilityProbe(ctx,api)
 local function safe(f,...) local ok,v=pcall(f,...); if ok then return v end end
 local function emit(fmt,...) api.log(string.format(fmt,...)) end
 local function txt(v) return v==nil and 'nil' or tostring(v):gsub('[\r\n, ]','_'):sub(1,80) end
 local function name(h) return h and (safe(function() return h.Name end) or safe(function() return h:Get('Name') end)) end
 local function ordered(t) local a={}; for k in pairs(t or {}) do a[#a+1]=k end; table.sort(a); return a end
 local function count(t) local n=0; for _ in pairs(t or {}) do n=n+1 end; return n end
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
 local function attrFG(attr)
  local feature=attr and safe(function() return attr.Feature end)
  local fg=feature and safe(function() return feature:Parent() end)
  return fg and safe(api.identity,fg) or nil
 end
 -- Native member UI enumeration with FG attribution, cached per member.
 local uiCache,uiReads={},{reads=0}
 local function memberUI(h)
  local id=safe(api.identity,h) or h
  if uiCache[id] then return uiCache[id],true end
  uiReads.reads=uiReads.reads+1
  local result={complete=false,byUI={},byFG={}}
  local channels=api.getUIChannels and safe(api.getUIChannels,h,true)
  if type(channels)~='table' then uiCache[id]=result; return result,false end
  local list={}; for _,u in pairs(channels) do
   if type(u)=='table' or type(u)=='userdata' then list[#list+1]=u end end
  if #list==0 then uiCache[id]=result; return result,false end
  local attrByUI=api.attributeByUI
  if type(attrByUI)~='function' then uiCache[id]=result; return result,false end
  for _,u in ipairs(list) do
   local i=safe(function() return u.INDEX end)
   if type(i)~='number' then i=safe(function() return u:Get('INDEX') end) end
   if type(i)~='number' or i%1~=0 or i<1 then uiCache[id]=result; return result,false end
   local a=safe(attrByUI,i-1)
   if not isAttr(a) then uiCache[id]=result; return result,false end
   local fg=attrFG(a)
   if not fg then uiCache[id]=result; return result,false end
   local ui=i-1; local aid=safe(api.identity,a) or a
   result.byUI[ui]={attr=a,attrId=aid,attrName=name(a),fg=fg}
   result.byFG[fg]=result.byFG[fg] or {}
   result.byFG[fg][ui]={attr=a,attrId=aid,attrName=name(a)}
  end
  result.complete=true
  uiCache[id]=result; return result,false
 end
 -- Reference stored UI sets per exact FG+ABS from cached raw records.
 local function refStored(raw)
  local stored,byFG,bad={},{},{}
  if type(raw)~='table' then return stored,byFG,bad end
  for key,p in pairs(raw) do if type(key)=='number' and type(p)=='table' then
   local step=p[1]
   if type(step)=='table' and step.absolute~=nil then
    if p.ui_channel_index~=nil and p.ui_channel_index~=key then bad[key]={reason='UI_CHANNEL_INDEX_MISMATCH',declared=p.ui_channel_index}
    else
     local a=p.attribute or (api.attributeByUI and safe(api.attributeByUI,key))
     local fg=a and attrFG(a)
     if not a or not isAttr(a) or not fg then bad[key]={reason='ATTRIBUTE_FG_UNPROVEN'}
     else
      local aid=safe(api.identity,a) or a
      stored[key]={attr=a,attrId=aid,attrName=name(a),fg=fg}
      byFG[fg]=byFG[fg] or {}
      byFG[fg][key]={attr=a,attrId=aid,attrName=name(a)}
     end
    end
   end
  end end
  return stored,byFG,bad
 end
 local function isSelectiveProof(p)
  if type(p)~='table' or p.motionStaticProven~=true then return false end
  if type(p.selective)~='table' then return false end
  for k in pairs(p.selective) do
   if type(k)=='string' and k:match('^field=true') then return true end
  end
  return false
 end
 local summary={expected=3,checked=0,proven=0,lanes=0,stored=0,notStored=0,unproven=0,expectedLink=0,different=0,attrMissing=0,bucketMissing=0}
 local refs={} -- per reference label
 local sampleUI,sampleLane=0,0
 for _,rec in ipairs(ctx.records or {}) do if rec.category=='FINAL_SURVIVING_UNSAFE' then
  local key=rec.ref and safe(api.identity,rec.ref)
  local proof=key and ctx.proofs and ctx.proofs[key]
  if key and isSelectiveProof(proof) then
   local row=rec.row or {}
   local label=txt(safe(api.describe,rec.ref))
   summary.checked=summary.checked+1
   local R=refs[label]
   if not R then R={rows=0,lanes=0,stored=0,notStored=0,unproven=0,expectedLink=0,different=0}; refs[label]=R end
   R.rows=R.rows+1
   local raw=ctx.referenceRaw and ctx.referenceRaw[key]
   local stored,storedByFG,bad=refStored(raw)
   -- Owner map within this row's candidate members for collision detection.
   local members={}
   for _,skey in ipairs(rec.surviving or {}) do
    local split=type(skey)=='string' and skey:find('\0',1,true)
    local m=split and tonumber(skey:sub(1,split-1))
    if m and not members[m] then
     local h=api.getSubfixture and safe(api.getSubfixture,m)
     members[m]=h
    end
   end
   local owner={} -- ui -> list of member sf
   local memberEnum={} -- sf -> enum result
   for sf,h in pairs(members) do
    local en=h and memberUI(h) or {complete=false}
    memberEnum[sf]=en
    if en.complete then for ui in pairs(en.byUI) do
     owner[ui]=owner[ui] or {}
     owner[ui][#owner[ui]+1]=sf
    end end
   end
   -- Bounded raw-vs-member index samples.
   local rawKeys={}; for k in pairs(stored) do rawKeys[#rawKeys+1]=k end; table.sort(rawKeys)
   for _,k in ipairs(rawKeys) do
    if sampleUI>=16 then break end
    sampleUI=sampleUI+1
    local e=stored[k]; local owners=owner[k] or {}
    local oSf=#owners==1 and owners[1] or nil
    local oH=oSf and members[oSf]
    emit('SELECTIVE_UI_INDEX_SAMPLE reference=%s member=%s fixture_key=%s raw_ui_index=%s member_ui_index=%s attribute=%s attribute_identity=%s feature_group=%s layer=ABS classification=%s',
     label,txt(oSf),txt(oH and toaddrKey(safe(function() return oH:ToAddr() end))),tostring(k),
     oSf and tostring(k) or '-',txt(e.attrName),txt(e.attrId),txt(e.fg),
     #owners>1 and 'COLLIDING_INDEX' or (oSf and 'STORED_INDEX' or 'UNOWNED_INDEX'))
   end
   for k,b in pairs(bad) do
    if sampleUI>=20 then break end
    sampleUI=sampleUI+1
    emit('SELECTIVE_UI_INDEX_SAMPLE reference=%s member=- fixture_key=- raw_ui_index=%s member_ui_index=- attribute=- attribute_identity=- feature_group=- layer=ABS classification=BAD_INDEX_RECORD_%s',
     label,tostring(k),txt(b.reason))
   end
   local rowStat={lanes=0,stored=0,notStored=0,unproven=0,expectedLink=0,different=0,attrMissing=0,bucketMissing=0}
   for _,skey in ipairs(rec.surviving or {}) do
    local split=type(skey)=='string' and skey:find('\0',1,true)
    local sf=split and tonumber(skey:sub(1,split-1))
    local lane=split and skey:sub(split+1)
    local feature,layer
    if lane then feature,layer=lane:match('^(.-)|([^|]+)$') end
    if layer=='*' then
     local concreteFeature=type(feature)=='string' and feature:match('^FG:')
      and type(row.features)=='table' and row.features[feature]==true
     if concreteFeature and proof.layers and proof.layers.ABS==true then lane=feature..'|ABS'; layer='ABS' end
    end
    local h=sf and members[sf]
    local laneClass='SELECTIVE_MEMBER_MAPPING_UNPROVEN'
    local fkey=feature and feature:match('^FG:(.+)$')
    local en=sf and memberEnum[sf]
    local bucketExists=false; local interNames={}; local interCount=0
    if sf and h and layer=='ABS' and fkey and en and en.complete then
     local memberSet=en.byFG[fkey] or {}
     local presetSet=storedByFG[fkey] or {}
     -- Bad-record and owner-collision fail-closed checks.
     local blocked=false
     for ui in pairs(memberSet) do
      if bad[ui] then blocked=true end
      if owner[ui] and #owner[ui]>1 then blocked=true end
     end
     if not blocked then
      for ui,v in pairs(memberSet) do if presetSet[ui] then interCount=interCount+1; interNames[#interNames+1]=v.attrName end end
      table.sort(interNames)
      if interCount>0 then
       local key2=toaddrKey(h and safe(function() return h:ToAddr() end))
       local partKey=safe(api.identity,row.part) or row.part
       local view=ctx.views and ctx.views[partKey]
       local bucket=key2 and view and type(view.buckets)=='table' and view.buckets[key2]
       bucketExists=type(bucket)=='table'
       if not bucketExists then laneClass='SELECTIVE_COOKED_BUCKET_MISSING'
       else
        local matched,different,missing=false,false,false
        for _,n in ipairs(interNames) do
         local p=bucket[n]
         if type(p)~='table' then missing=true
         else
          local link=p.abs_preset
          local expected=safe(api.identity,rec.ref); local actual=link and safe(api.identity,link)
          if expected and actual==expected then matched=true elseif actual then different=true else missing=true end
         end
        end
        if different then laneClass='SELECTIVE_DIFFERENT_PRESET_LINK'
        elseif missing or not matched then laneClass='SELECTIVE_COOKED_ATTRIBUTE_MISSING'
        else laneClass='SELECTIVE_EXPECTED_PRESET_LINK' end
       end
      else laneClass='SELECTIVE_MEMBER_NOT_STORED'
      end
     end
    end
    rowStat.lanes=rowStat.lanes+1
    if laneClass=='SELECTIVE_EXPECTED_PRESET_LINK' then rowStat.stored=rowStat.stored+1; rowStat.expectedLink=rowStat.expectedLink+1
    elseif laneClass=='SELECTIVE_MEMBER_NOT_STORED' then rowStat.notStored=rowStat.notStored+1
    elseif laneClass=='SELECTIVE_DIFFERENT_PRESET_LINK' then rowStat.stored=rowStat.stored+1
    elseif laneClass=='SELECTIVE_COOKED_ATTRIBUTE_MISSING' or laneClass=='SELECTIVE_COOKED_BUCKET_MISSING' then rowStat.stored=rowStat.stored+1
    else rowStat.unproven=rowStat.unproven+1 end
    if laneClass=='SELECTIVE_DIFFERENT_PRESET_LINK' then rowStat.different=rowStat.different+1 end
    if laneClass=='SELECTIVE_COOKED_ATTRIBUTE_MISSING' then rowStat.attrMissing=rowStat.attrMissing+1 end
    if laneClass=='SELECTIVE_COOKED_BUCKET_MISSING' then rowStat.bucketMissing=rowStat.bucketMissing+1 end
    if sampleLane<24 then sampleLane=sampleLane+1
     local stored_list=table.concat(interNames,','):sub(1,60)
     if stored_list=='' then stored_list='-' end
     local memberSet=en and en.complete and en.byFG[fkey] or {}
     emit('SELECTIVE_MEMBER_SAMPLE reference=%s source_cue=%s source_part=%s source_recipe=%s group=%s member=%s fixture_key=%s candidate_feature=%s layer=%s member_feature_ui_count=%d preset_intersection_count=%d stored_attributes=%s cooked_bucket_exists=%s classification=%s',
      label,txt(safe(api.describe,row.cue)),txt(safe(api.describe,row.part)),txt(safe(api.describe,row.recipe)),txt(safe(api.describe,row.group)),
      txt(sf),txt(h and toaddrKey(safe(function() return h:ToAddr() end))),txt(feature),txt(layer),
      count(memberSet),interCount,stored_list,tostring(bucketExists),laneClass)
    end
   end
   local rowClass=(rowStat.lanes>0 and rowStat.unproven==0 and rowStat.different==0 and rowStat.attrMissing==0 and rowStat.bucketMissing==0)
    and 'SELECTIVE_ROW_PROVEN' or 'INCONCLUSIVE'
   if rowClass=='SELECTIVE_ROW_PROVEN' then summary.proven=summary.proven+1 end
   emit('SELECTIVE_MEMBER_MAPPING_ROW reference=%s group=%s candidate_surviving_lanes=%d stored_lanes=%d not_stored_lanes=%d unproven_lanes=%d expected_preset_link_lanes=%d different_preset_lanes=%d cooked_attribute_missing_lanes=%d cooked_bucket_missing_lanes=%d classification=%s',
    label,txt(safe(api.describe,row.group)),rowStat.lanes,rowStat.stored,rowStat.notStored,rowStat.unproven,
    rowStat.expectedLink,rowStat.different,rowStat.attrMissing,rowStat.bucketMissing,rowClass)
   R.lanes=R.lanes+rowStat.lanes; R.stored=R.stored+rowStat.stored; R.notStored=R.notStored+rowStat.notStored
   R.unproven=R.unproven+rowStat.unproven; R.expectedLink=R.expectedLink+rowStat.expectedLink; R.different=R.different+rowStat.different
   summary.lanes=summary.lanes+rowStat.lanes; summary.stored=summary.stored+rowStat.stored; summary.notStored=summary.notStored+rowStat.notStored
   summary.unproven=summary.unproven+rowStat.unproven; summary.expectedLink=summary.expectedLink+rowStat.expectedLink; summary.different=summary.different+rowStat.different
   summary.attrMissing=summary.attrMissing+rowStat.attrMissing; summary.bucketMissing=summary.bucketMissing+rowStat.bucketMissing
  end
 end end
 for _,label in ipairs(ordered(refs)) do local R=refs[label]
  local class=R.unproven>0 and 'INCONCLUSIVE' or R.different>0 and 'OBSERVED_APPLICABILITY_MISMATCH' or 'CONSISTENT'
  emit('SELECTIVE_MEMBER_MAPPING_REFERENCE reference=%s final_surviving_rows=%d stored_lanes=%d not_stored_lanes=%d unproven_lanes=%d expected_preset_link_lanes=%d different_preset_lanes=%d classification=%s',
   label,R.rows,R.stored,R.notStored,R.unproven,R.expectedLink,R.different,class)
 end
 local classification=(summary.checked==summary.expected and summary.proven==summary.expected and summary.unproven==0
  and summary.different==0 and summary.attrMissing==0 and summary.bucketMissing==0) and 'SELECTIVE_MEMBER_APPLICABILITY_PROVEN' or 'INCONCLUSIVE'
 emit('SELECTIVE_MEMBER_MAPPING_SUMMARY rows_expected=%d rows_checked=%d rows_proven=%d candidate_surviving_lanes=%d stored_lanes=%d not_stored_lanes=%d mapping_unproven_lanes=%d expected_preset_link_lanes=%d different_preset_lanes=%d cooked_attribute_missing_lanes=%d cooked_bucket_missing_lanes=%d classification=%s diagnostic_only=true',
  summary.expected,summary.checked,summary.proven,summary.lanes,summary.stored,summary.notStored,summary.unproven,
  summary.expectedLink,summary.different,summary.attrMissing,summary.bucketMissing,classification)
 if classification=='SELECTIVE_MEMBER_APPLICABILITY_PROVEN' then
  local remaining,globalCount={},{}
  for _,rec in ipairs(ctx.records or {}) do if rec.category=='FINAL_SURVIVING_UNSAFE' then
   local rk=rec.ref and safe(api.identity,rec.ref)
   local provenSel=rk and refs[txt(safe(api.describe,rec.ref))]
   local isGlobal=false
   for _,p in ipairs(ctx.globalPaths or {}) do if p==rk then isGlobal=true end end
   if not provenSel and not isGlobal then remaining[txt(safe(api.describe,rec.ref))]=true end
  end end
  for _,p in ipairs(ctx.globalPaths or {}) do globalCount[p]=true end
  local rem={}; for k in pairs(remaining) do rem[#rem+1]=k end; table.sort(rem)
  emit('SELECTIVE_RESOLVER_ALTERNATE global_ordinary_rows_proven=%d selective_rows_proven=%d remaining_final_surviving_unsafe_rows=%d remaining_references=%s classification=%s diagnostic_only=true',
   count(globalCount),summary.proven,#rem,table.concat(rem,',')~='' and table.concat(rem,',') or '-',#rem==0 and 'ALL_RESOLVED' or 'OPEN_REFERENCES_REMAIN')
 end
 return {summary=summary,refs=refs,uiReads=uiReads.reads,classification=classification}
end
