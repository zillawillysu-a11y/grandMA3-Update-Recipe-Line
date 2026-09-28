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
