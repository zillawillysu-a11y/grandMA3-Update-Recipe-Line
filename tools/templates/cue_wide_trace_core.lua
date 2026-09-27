-- Core template; appended after instrumented production functions by builder.
local rawAPI={data=_G.GetPresetData,sequence=_G.SelectedSequence,cue=_G.GetCurrentCue,time=_G.Time}
local build=safe(BuildDetails)
assert(type(build)=='table' and build.BigVersion=='2.5.0.3','Requires grandMA3 2.5.0.3')
assert(type(rawAPI.data)=='function' and type(rawAPI.sequence)=='function' and type(rawAPI.cue)=='function','Read-only Cue APIs required')
local sequence,currentCue=safe(rawAPI.sequence),safe(rawAPI.cue)
assert(sequence and currentCue and cueNumber(currentCue),'Select a Sequence with a readable Current Cue')
SelectedSequence=function() return sequence end
GetCurrentCue=function() return currentCue end
local clockMode=type(rawAPI.time)=='function' and 'MA_Time_SECONDS_WALL' or 'UNAVAILABLE'
local function now() local v=safe(rawAPI.time); return type(v)=='number' and v or nil end
local function delta(a,b) if a and b and b>=a then return (b-a)*1000 end end
local function text(v) return v==nil and 'UNAVAILABLE' or tostring(v):gsub('[\r\n]',' '):sub(1,190) end
local outputLines,outputLimited=0,false
local function log(f,...) if outputLines>=12000 then outputLimited=true; return end; outputLines=outputLines+1; Printf('[CueWideTrace] '..f,...) end
local function method(h,k,...) return safe(function(...) return h[k](h,...) end,...) end
local function token(h) return h and safe(HandleToStr,h) or nil end
local function describe(h)
 if not isObjectReference(h) then return 'raw='..text(h)..' type='..type(h) end
 return 'class='..text(class(h))..' address='..text(commandAddress(h))..' native='..text(method(h,'AddrNative'))..' DB_handle='..text(token(h))
end
local function refType(h)
 if isRandomGenerator(h) then return 'Generator' end
 if isPhaserRecipePreset(h) then return 'Phaser' end
 return class(h):lower()=='preset' and 'Preset' or class(h)
end
local function bool(v) local n=tostring(v):lower(); if v==true or n=='yes' or n=='true' or n=='1' then return true end; if v==false or n=='no' or n=='false' or n=='0' then return false end end
local pass; local allPasses={}; local seenRequests={}
local function event(ref,part,stage,layer,reason,recipe,channel)
 if ref==nil then return end
 local entry=pass.refs[ref]
 if not entry then
  if pass.refCount>=1024 then pass.traceLimited=true; return end
  pass.refCount=pass.refCount+1; entry={id=pass.refCount,ref=ref,events={},count=0}; pass.refs[ref]=entry
 end
 local perPart=entry.events[part or false]; if not perPart then perPart={}; entry.events[part or false]=perPart end
 local key=stage..'|'..layer..'|'..reason
 local e=perPart[key]
 if not e then
  if pass.eventCount>=8192 then pass.traceLimited=true; return end
  pass.eventCount=pass.eventCount+1; e={part=part,stage=stage,layer=layer,reason=reason,count=0,recipe=recipe,channel=channel}; perPart[key]=e
 end
 e.count=e.count+1; entry.count=entry.count+1
end
local function hook(fn)
 return function(...)
  local a=now(); fn(...); local ms=delta(a,now())
  if ms then pass.overhead=pass.overhead+ms else pass.timingInvalid=true end
 end
end
tracePartOrder=hook(function(scan,cue,part)
 pass.owners[part]=cue; pass.order[#pass.order+1]={cue=cue,part=part}
end)
tracePartBegin=hook(function(scan,part) pass.part=part; pass.scan=scan end)
traceRecord=hook(function(scan,part,index,phaser)
 local advance=pass.currentAdvance
 if advance then advance.keys[#advance.keys+1]=index; advance.records=advance.records+1 end
 pass.currentPhaser=phaser
end)
traceRawLayer=hook(function(scan,part,index,prefix,touched,moving,refs)
 pass.previous[prefix]=(scan.tracked[index] or {})[prefix]
 local included={}; for _,ref in ipairs(refs) do included[ref]=true; event(ref,part,'COOKED_RAW',prefix,moving and 'MOVING_LAYER_CANDIDATE' or 'STATIC_RELEASED_OR_UNTOUCHED_LAYER',nil,index) end
 local phaser=pass.currentPhaser
 if type(phaser)=='table' then
  local function inspect(container,key,path)
   local value=container[key]; local addressLike=type(value)=='string' and (value:lower():match('^preset%s+%d') or value:lower():match('^generator%s+%d'))
   if (isObjectReference(value) or addressLike) and not included[value] then
    event(value,part,'RAW_LINK_IGNORED',prefix,'cueEffectLayer_did_not_accept_'..path,nil,index)
    if moving and #refs==0 and addressLike then pass.ignoredLinks[value]=true end
   end
  end
  for _,key in ipairs({prefix..'_preset',prefix..'_generator'}) do inspect(phaser,key,'top.'..key) end
  if prefix=='abs' then for _,key in ipairs({'generator','integrated','value'}) do inspect(phaser,key,'top.'..key) end end
  local steps=0
  for key,step in pairs(phaser) do if type(key)=='number' and type(step)=='table' then
   steps=steps+1; if steps>64 then pass.traceLimited=true; break end
   inspect(step,prefix..'_preset','step.'..prefix..'_preset')
   if prefix=='abs' then for _,field in ipairs({'integrated','generator','value'}) do inspect(step,field,'step.'..field) end end
  end end
 end
end)
traceLayer=hook(function(scan,part,index,prefix,moving,refs,recovered,item)
 local previous=pass.previous[prefix]
 if previous then for _,ref in ipairs(previous.refs) do event(ref,previous.probePart,'TRACKING',prefix,'SUPERSEDED_BY_LATER_TOUCHED_LAYER',previous.probeRecipe,index) end end
 if item then item.probePart=part; item.probeIndex=index; item.probeLayer=prefix; item.probeRecovered=recovered end
 for _,ref in ipairs(refs) do
  local recipe
  if recovered then for _,row in ipairs((scan.pendingPart or {}).recipes or {}) do if row.ref==ref then recipe=row.probeRecipe; break end end end
  if item and recipe then item.probeRecipe=recipe end
  event(ref,part,recovered and 'RECIPE_RECOVERY' or 'COOKED_LAYER',prefix,moving and 'ACCEPTED_IN_LAYER_PENDING_TRACKING' or 'REJECTED_NOT_MOVING_OR_RELEASED',recipe,index)
 end
end)
traceRecoveryCandidate=hook(function(scan,part,index,feature,recipe,sfIndex)
 local reason=not recipe.featureMatches[feature] and 'REJECTED_FEATURE_MISMATCH' or (sfIndex~=nil and not recipe.members[sfIndex] and 'REJECTED_FIXTURE_MEMBERSHIP' or 'RECOVERY_ELIGIBLE')
 event(recipe.ref,part,'RECIPE_RECOVERY_CANDIDATE',feature,reason,recipe.probeRecipe,index)
end)
traceMediumLane=hook(function(row,ref,feature,key,decided,active)
 event(ref,row.part,'PROGRESSIVE_GROUP_FEATURE_LANE',feature,decided and 'REJECTED_ALREADY_DECIDED' or (active and 'PROVISIONAL_LANE_WIN' or 'STATIC_LANE_TERMINATOR'),row.recipe)
 pass.owners[row.part]=row.cue
end)
traceMediumRow=hook(function(row,ref,features,publish,groupKey)
 event(ref,row.part,'PROGRESSIVE',table.concat(features,','),publish and 'PROVISIONAL_PUBLISH' or 'REJECTED_NO_NEW_MOVING_LANE',row.recipe)
 if publish then pass.publications[ref]=pass.publications[ref] or {tick=pass.tick,stage='PROGRESSIVE'} end
end)
traceDirect=hook(function(part,recipe,ref,key)
 pass.owners[part]=currentCue
 event(ref,part,'CURRENT_CUE_RECIPE','direct',key and 'DIRECT_RECIPE_PUBLISH' or 'REJECTED_NO_COMMAND_ADDRESS',recipe)
 if key then pass.publications[ref]=pass.publications[ref] or {tick=pass.tick,stage='DIRECT_CURRENT_RECIPE'} end
end)
traceProductionLog=hook(function(message) pass.productionLogs[#pass.productionLogs+1]=message end)
-- Wrap source reader locally, never a native/global function.
local originalRecipeField=recipeField
recipeField=function(recipe,name)
 local o,rawValue=originalRecipeField(recipe,name)
 local extraStart=now()
 if pass and (name=='Values' or name=='Generator') and o then
  pass.rawFields[recipe]=pass.rawFields[recipe] or {}; pass.rawFields[recipe][name]=rawValue
 end
 if pass and (name=='Values' or name=='Generator') and not o then
  local v=tostring(rawValue or ''):lower()
  if v:match('^preset%s+%d') or v:match('^generator%s+%d') or v:find('showdata.',1,true) then
   pass.unresolved[recipe]=pass.unresolved[recipe] or {}; pass.unresolved[recipe][name]=rawValue
  end
 end
 local extra=delta(extraStart,now()); if pass and extra then pass.overhead=pass.overhead+extra elseif pass then pass.timingInvalid=true end
 return o,rawValue
end
GetPresetData=function(target,phasers,fixtures)
 local wrapperStart=now()
 local byArgs=seenRequests[target]; if not byArgs then byArgs={}; seenRequests[target]=byArgs end
 local signature=tostring(phasers)..':'..tostring(fixtures); local first=not byArgs[signature]; byArgs[signature]=true
 local start=now(); local ok,data=pcall(rawAPI.data,target,phasers,fixtures); local finish=now(); local ms=delta(start,finish)
 if ms then pass.nativeMs=pass.nativeMs+ms else pass.timingInvalid=true end
 local e={target=target,part=pass.part,kind=phasers==false and 'PART_COOKED' or 'FEATURE_REFERENCE',first=first,ms=ms,ok=ok,error=not ok and data or nil,returnType=type(data),cumulative=pass.nativeMs,cumulativeReplay=delta(pass.startedWall,finish)}
 pass.reads[#pass.reads+1]=e
 if e.kind=='PART_COOKED' then pass.partReads[target]=e
 elseif ok and type(data)=='table' then
  -- Supplementary feature reads may short-circuit. Count their returned table
  -- separately, track/exclude this diagnostic overhead, never reread natively.
  local a=now(); local n=0
  for _ in pairs(data) do n=n+1; if n>131072 then break end end
  if n<=131072 then e.count=n else e.countLimited=true end
  local overhead=delta(a,now()); if not overhead then pass.timingInvalid=true end
 end
 local wrapperElapsed=delta(wrapperStart,now()); if wrapperElapsed and ms then pass.overhead=pass.overhead+math.max(0,wrapperElapsed-ms) else pass.timingInvalid=true end
 if not ok then error(data,0) end
 return data
end
local originalAdvance=advanceCueEffectScan
advanceCueEffectScan=function(scan)
 if scan.done then return originalAdvance(scan) end
 local a={number=scan.advanceCalls+1,records=0,keys={},part=scan.parts[scan.index],tick=pass.tick}
 pass.advances[#pass.advances+1]=a; pass.currentAdvance=a; local start=now()
 local nativeBefore,overheadBefore=pass.nativeMs,pass.overhead
 local ok,result=pcall(originalAdvance,scan); a.ms=delta(start,now()); pass.currentAdvance=nil
 a.nativeMs=pass.nativeMs-nativeBefore; a.overhead=pass.overhead-overheadBefore
 a.processingMs=a.ms and math.max(0,a.ms-a.nativeMs-a.overhead) or nil
 if not ok then error(result,0) end
 return result
end
local function count(t) local n=0; for _ in pairs(t or {}) do n=n+1 end; return n end
local function run(label)
 pass={label=label,refs={},refCount=0,eventCount=0,owners={},order={},previous={},reads={},partReads={},advances={},productionLogs={},publications={},rawFields={},unresolved={},ignoredLinks={},nativeMs=0,overhead=0,coreMs=0,tick=0,timingInvalid=false}
 allPasses[#allPasses+1]=pass
 local state={poolBlink=true,running=true}; pass.state=state
 local start=now(); pass.startedWall=start
 for tick=0,8191 do
  pass.tick=tick; local a=now(); local ok,err=pcall(refreshCueEffects,state,true); local elapsed=delta(a,now())
  if elapsed then pass.coreMs=pass.coreMs+elapsed else pass.timingInvalid=true end
  if pass.advances[#pass.advances] then pass.advances[#pass.advances].cumulativeEstimate=pass.coreMs-pass.overhead+tick*REFRESH_SECONDS*1000 end
  if not ok then pass.error=tostring(err); break end
  if not state.recipeScanPending and not state.effectScanPending and not state.effectScanner then break end
  if tick==8191 then pass.traceLimited=true; pass.error='DIAGNOSTIC_HOST_CALL_LIMIT' end
 end
 pass.actualMs=delta(start,now()); pass.error=pass.error or state.effectError
 pass.result=state.activeEffects or {}; pass.finalOrigins={}
 for _,entry in pairs(pass.result) do pass.publications[entry.object]=pass.publications[entry.object] or {tick=pass.tick,stage='FINAL_COOKED_OR_DIRECT_MERGE'} end
 local scan=pass.scan
 if scan then
  for ordinal,d in ipairs(scan.diagnostics.parts) do
   local part=scan.parts[ordinal]; local r=pass.partReads[part]; if r then r.count=d.channels end
  end
  for index,layers in pairs(scan.tracked) do for prefix,item in pairs(layers) do
   for _,ref in ipairs(item.refs) do
    event(ref,item.probePart,'FINAL_SURVIVING_COOKED_LAYER',prefix,'SURVIVES_CHANNEL_TRACKING',item.probeRecipe,index)
    pass.finalOrigins[ref]=pass.finalOrigins[ref] or {}; pass.finalOrigins[ref][item.probePart or false]=true
   end
  end end
 end
 pass.waitMs=pass.tick*REFRESH_SECONDS*1000
 pass.correctedCore=math.max(0,pass.coreMs-pass.overhead)
 pass.processingMs=math.max(0,pass.correctedCore-pass.nativeMs)
 pass.estimate=pass.correctedCore+pass.waitMs
end
local wholeStart=now()
log('START target=2.5.0.3 scanner_source_version=0.7.0.17 production_flag=false private_replay_only=true clock=%s sequence={%s} cue={%s} batch=32 cadence_seconds=%g waits=MODEL_ONLY',clockMode,describe(sequence),describe(currentCue),REFRESH_SECONDS)
run('COLD_FIRST_OBSERVED_NOT_FLUSHED')
run('WARM_FULL_REPLAY_REPEAT_NOT_PRODUCTION_CACHE_HIT')
local warm=pass
-- Model actual scanner result-cache hit separately: it must issue no data reads.
local before=#warm.reads; local cacheStart=now(); refreshCueEffects(warm.state,true); local cacheMs=delta(cacheStart,now()); local cacheReads=#warm.reads-before
local contextStable=safe(rawAPI.sequence)==sequence and safe(rawAPI.cue)==currentCue
-- Reuse validated production grid/button/Ptr/identity path. No UI writes.
local uiUnverified=false; local derived={}
local function valid(h) return h~=nil and safe(IsObjectValid,h)==true end
local function isUI(h)
 if not valid(h) then return false end
 local k=class(h); if derived[k]==nil then derived[k]=k=='UIObject' or safe(IsClassDerivedFrom,k,'UIObject')==true end
 return derived[k]
end
local function ui(h,k,...) if not isUI(h) then uiUnverified=true; return nil end; return method(h,k,...) end
local function uiChildren(h) local list=ui(h,'UIChildren'); return type(list)=='table' and list or children(h) end
local function visible(h)
 if not isUI(h) then return nil end
 local a,b,c=bool(ui(h,'IsActuallyVisible')),bool(ui(h,'IsVisible')),bool(rawget(type(h)=='table' and h or {},'Visible') or safe(function() return h.Visible end))
 if a==false or b==false or c==false then return false end
 return a==true or b==true or c==true or nil
end
local function actual(h) if not valid(h) then return false end; local v=ui(h,'IsActuallyVisible'); return v==nil or bool(v)==true end
local production=rawget(_G,'RecipeTrackingInspectorState'); local grids={}; local needs=type(production)=='table' and production.poolGridRefreshNeeded==true
if type(production)=='table' then for _,g in ipairs(production.poolGrids or {}) do if actual(g) then grids[#grids+1]=g else needs=true end end end
if #grids==0 or needs then
 grids={}; local visited,budget={},6000
 local function visit(h,depth)
  if not h or visited[h] or depth>20 or budget<=0 then return end
  visited[h],budget=true,budget-1
  if type(production)=='table' and h==production.window then return end
  if class(h):find('PoolLayoutGrid',1,true) then if actual(h) then grids[#grids+1]=h end; return end
  for _,c in ipairs(uiChildren(h)) do visit(c,depth+1) end
 end
 if callable('GetDisplayByIndex') then for i=1,7 do visit(safe(GetDisplayByIndex,i),0) end elseif callable('GetFocusDisplay') then visit(safe(GetFocusDisplay),0) end
 if budget<=0 then uiUnverified=true end
end
local gridData={}; local tileLimited=#grids>64
for i=1,math.min(#grids,64) do
 local g=grids[i]; local p=safe(function() return g.PoolObject end); local entry={grid=g,pool=p,visible=visible(g),tiles={}}
 gridData[#gridData+1]=entry
 local display=g; for _=1,24 do if not display or class(display)=='Display' then break end; display=method(display,'Parent') end
 log('GRID grid={%s} display={%s} pool_type=%s pool={%s} visible=%s',describe(g),describe(display),text(property(g,'Pooltype')),describe(p),text(entry.visible))
 for j,b in ipairs(uiChildren(g)) do
  if j>2048 then tileLimited=true; break end
  local k=class(b):lower(); local idx=k:find('poolbutton',1,true) and not k:find('pooltitlebutton',1,true) and tonumber(property(b,'ObjectIndex')) or nil
  if idx then entry.tiles[#entry.tiles+1]={button=b,index=idx,target=safe(function() return p:Ptr(idx) end),visible=visible(b)} end
 end
end
for _,p in ipairs(allPasses) do
 pass=p; local sourceMisses=count(p.unresolved)+count(p.ignoredLinks); local anonymousMoving=0
 if p.scan then for _,d in ipairs(p.scan.diagnostics.parts) do anonymousMoving=anonymousMoving+d.emptyRefs; sourceMisses=sourceMisses+d.unresolvedRefs end end
 log('PASS label=%s raw_getpresetdata_calls=%d advances=%d host_calls=%d context_stable=%s error=%s',p.label,#p.reads,#p.advances,p.tick+1,text(contextStable),text(p.error))
 for i,o in ipairs(p.order) do log('CUE_SCAN pass=%s position=%d cue={%s} part={%s} origin=%s',p.label,i,describe(o.cue),describe(o.part),o.cue==currentCue and 'CURRENT_CUE' or 'CUE_HISTORY') end
 for i,r in ipairs(p.reads) do
  log('READ pass=%s read=%d kind=%s request_access=%s source_cue={%s} part={%s} target={%s} GetPresetData_ms=%s returned_record_count=%s return_type=%s cumulative_native_ms=%s success=%s error=%s count_limited=%s cumulative_actual_replay_ms=%s',p.label,i,r.kind,r.first and 'FIRST_OBSERVED_REQUEST' or 'REPEAT_REQUEST',describe(p.owners[r.part]),describe(r.part),describe(r.target),text(r.ms),text(r.count),r.returnType,p.timingInvalid and 'UNAVAILABLE' or text(r.cumulative),text(r.ok),text(r.error),text(r.countLimited),text(r.cumulativeReplay))
 end
 for _,a in ipairs(p.advances) do
  local keys={}; for _,k in ipairs(a.keys) do keys[#keys+1]=tostring(k) end
  log('BATCH pass=%s advance=%d host_tick=%d part={%s} records_processed=%d next_key_order=%s advance_elapsed_ms_including_native_and_trace=%s cadence_wait_before_ms=%g',p.label,a.number,a.tick,describe(a.part),a.records,table.concat(keys,','),text(a.ms),REFRESH_SECONDS*1000)
 end
 local matched,noPool,noTile,identityUnknown=0,0,0,0
 for key,e in pairs(p.result) do
  if type(key)~='string' then sourceMisses=sourceMisses+1; log('SOURCE_MISS pass=%s reason=NON_STRING_RESULT_KEY_ADDRESS_MEMO_SENTINEL_BEHAVIOR key_type=%s reference={%s} production_behavior_preserved=true',p.label,type(key),describe(e.object)) end
  local ref=e.object; local owners={}; local parent=method(ref,'Parent')
  for _=1,3 do if not valid(parent) then break end; owners[#owners+1]=parent; parent=method(parent,'Parent') end
  local pools,tiles,identity=0,0,0
  for _,g in ipairs(gridData) do
   local poolMatch=false; for _,o in ipairs(owners) do if sameReference(o,g.pool) then poolMatch=true; break end end
   for _,t in ipairs(g.tiles) do
    local targetKey=commandAddress(t.target); local productionMatch=targetKey and p.result[targetKey] or nil
    if not productionMatch and t.target then for _,candidate in pairs(p.result) do if sameReference(t.target,candidate.object) then productionMatch=candidate; break end end end
    if sameReference(t.target,ref) then
     poolMatch=true
     local identical=t.target==ref or (token(ref)~=nil and token(ref)==token(t.target))
     log('TILE pass=%s reference={%s} expected_pool_hint={%s} grid={%s} grid_visible=%s button_handle=%s ObjectIndex=%s button_visible=%s target={%s} sameReference=true DB_identity=%s production_matching_accepted=%s diagnostic_consumer_only=true',p.label,describe(ref),describe(method(ref,'Parent')),describe(g.grid),text(g.visible),text(token(t.button)),text(t.index),text(t.visible),describe(t.target),text(identical),text(productionMatch~=nil))
     if g.visible==nil or t.visible==nil then identityUnknown=identityUnknown+1 end
     if g.visible==true and t.visible==true and productionMatch then tiles=tiles+1; if identical then identity=identity+1 end end
    end
   end
   if poolMatch and g.visible==true then pools=pools+1 elseif poolMatch and g.visible==nil then identityUnknown=identityUnknown+1 end
  end
  if identity>0 then matched=matched+1 elseif tiles>0 then identityUnknown=identityUnknown+1 elseif pools==0 then noPool=noPool+1 else noTile=noTile+1 end
  log('REFERENCE_FINAL pass=%s key=%s reference={%s} accepted_reason=COOKED_RESULT_OR_DIRECT_CURRENT_RECIPE_MERGE visible_pools=%d visible_tiles=%d identity_matches=%d direct_merge_preserves_refs_even_when_absent_from_cooked=true',p.label,text(key),describe(ref),pools,tiles,identity)
  local publication=p.publications[ref]
  log('PUBLICATION pass=%s reference_type=%s reference={%s} first_publish_stage=%s first_publish_tick=%d first_publish_wait_model_ms=%g final_snapshot_tick=%d provisional_is_not_final_playback_provenance=true',p.label,refType(ref),describe(ref),publication.stage,publication.tick,publication.tick*REFRESH_SECONDS*1000,p.tick)
 end
 local refs={}; for ref,entry in pairs(p.refs) do refs[#refs+1]=entry end; table.sort(refs,function(a,b) return a.id<b.id end)
 for _,entry in ipairs(refs) do
  local finalKey=isObjectReference(entry.ref) and commandAddress(entry.ref) or nil
  local final=finalKey and p.result[finalKey]~=nil or false
  for part,events in pairs(entry.events) do for _,e in pairs(events) do
   local cue=p.owners[part]; local origin=cue==currentCue and 'DIRECT_CURRENT_CUE' or (cue and 'TRACKED_HISTORY_CANDIDATE' or 'UNKNOWN')
   local survives=p.finalOrigins[entry.ref] and p.finalOrigins[entry.ref][part] or false
   log('EXTRACT pass=%s ref_id=%d source_cue={%s} source_part={%s} recipe={%s} origin=%s layer_or_feature=%s stage=%s raw_reference=%s reference={%s} reason=%s occurrences=%d duplicates=%d survives_cooked_origin=%s included_in_final_key_set=%s channel_sample=%s',p.label,entry.id,describe(cue),describe(part),describe(e.recipe),origin,e.layer,e.stage,text(entry.ref),describe(entry.ref),e.reason,e.count,math.max(0,e.count-1),text(survives),text(final),text(e.channel))
   if e.recipe then local fields=p.rawFields[e.recipe] or {}; log('RECIPE_RAW pass=%s ref_id=%d reference_type=%s recipe={%s} raw_values=%s raw_generator=%s resolved_reference={%s}',p.label,entry.id,refType(entry.ref),describe(e.recipe),text(fields.Values),text(fields.Generator),describe(entry.ref)) end
  end end
 end
 for recipe,fields in pairs(p.unresolved) do for field,rawValue in pairs(fields) do log('SOURCE_MISS pass=%s recipe={%s} field=%s raw_reference=%s reason=recipeField_address_string_unresolved',p.label,describe(recipe),field,text(rawValue)) end end
 for _,message in ipairs(p.productionLogs) do log('PRODUCTION_COUNTERS pass=%s original_elapsed_is_os_clock_not_wall=true %s',p.label,message) end
 for _,a in ipairs(p.advances) do log('BATCH_COST pass=%s advance=%d native_ms=%s processing_excluding_native_and_trace_ms=%s trace_overhead_ms=%s cumulative_estimated_production_ms=%s',p.label,a.number,p.timingInvalid and 'UNAVAILABLE' or text(a.nativeMs),text(a.processingMs),p.timingInvalid and 'UNAVAILABLE' or text(a.overhead),p.timingInvalid and 'UNAVAILABLE' or text(a.cumulativeEstimate)) end
 local records=0; for _,a in ipairs(p.advances) do records=records+a.records end
 log('SCAN_TOTAL pass=%s parts_planned=%d parts_completed=%d records_generated_and_processed=%d reference_records_final=%d',p.label,#p.order,p.scan and #p.scan.diagnostics.parts or 0,records,count(p.result))
 local function metric(v) return not p.timingInvalid and text(v) or 'UNAVAILABLE' end
 local functional='CUE_WIDE_REFERENCE_PATH_COMPLETE'
 if not contextStable or p.traceLimited or uiUnverified or tileLimited or identityUnknown>0 or outputLimited then functional='UNVERIFIED'
 elseif p.error then functional=(p.error:lower():find('limit') or p.error:find('exceeds')) and 'UNVERIFIED' or 'CUE_WIDE_SOURCE_MISS'
 elseif sourceMisses>0 then functional='CUE_WIDE_SOURCE_MISS'
 elseif noPool+noTile>0 then functional='CUE_WIDE_TILE_MISS' end
 local performance='UNVERIFIED'; local dominant='UNAVAILABLE'; local share
 if not p.timingInvalid and not p.traceLimited and not outputLimited and clockMode=='MA_Time_SECONDS_WALL' and not p.error and contextStable then
  local value=p.nativeMs; dominant='NATIVE_GETPRESETDATA'; performance='CUE_WIDE_PERFORMANCE_BOTTLENECK_NATIVE_READ'
  if p.waitMs>value then value=p.waitMs; dominant='BATCH_CADENCE_WAIT_MODEL'; performance='CUE_WIDE_PERFORMANCE_BOTTLENECK_BATCH_WAIT' end
  if p.processingMs>value then value=p.processingMs; dominant='REFERENCE_PROCESSING_INCLUDING_OTHER_READ_APIS'; performance='CUE_WIDE_PERFORMANCE_BOTTLENECK_PROCESSING' end
  share=p.estimate>0 and value/p.estimate*100 or 0
  if p.estimate<=300 then performance='CUE_WIDE_REFERENCE_PATH_COMPLETE' end
 end
 log('SUMMARY pass=%s functional_classification=%s performance_classification=%s total_native_GetPresetData_ms=%s Lua_reference_processing_including_other_read_APIs_ms=%s estimated_loop_wait_ms=%g corrected_scanner_replay_ms=%s raw_scanner_replay_ms=%s actual_pass_ms=%s diagnostic_hook_counting_overhead_ms=%s estimated_cue_to_final_ms=%s dominant_component=%s dominant_share_percent=%s references_discovered=%d references_matched_visible=%d no_visible_pool=%d no_visible_tile=%d identity_unverified=%d source_resolution_misses=%d anonymous_moving_empty_refs=%d advances=%d first_ref_advance=%s initial_defer_wait_ms=%g scanner_internal_wait_ms=%g other_production_render_work=NOT_MEASURED purple_render_bridge=ABSENT_FROM_CURRENT_MARKER_CONSUMER',p.label,functional,performance,metric(p.nativeMs),metric(p.processingMs),p.waitMs,metric(p.correctedCore),metric(p.coreMs),text(p.actualMs),metric(p.overhead),metric(p.estimate),dominant,text(share),count(p.result),matched,noPool,noTile,identityUnknown,sourceMisses,anonymousMoving,#p.advances,text(p.scan and p.scan.diagnostics.firstRefAdvance),math.min(p.tick,1)*REFRESH_SECONDS*1000,math.max(p.tick-1,0)*REFRESH_SECONDS*1000)
 p.functional=functional; p.performance=performance; p.matched=matched; p.noPool=noPool; p.noTile=noTile
end
log('CACHE_MODEL unchanged_cue_refresh_ms=%s GetPresetData_reads=%d completed_snapshot_reused=%s warm_full_replay_above_is_not_cache_hit=true',text(cacheMs),cacheReads,text(cacheReads==0))
if outputLimited then for _,p in ipairs(allPasses) do p.functional='UNVERIFIED'; p.performance='UNVERIFIED' end end
Printf('[CueWideTrace] END passes=%d total_probe_elapsed_ms=%s context_stable=%s output_capped=%s overall_evidence=%s production_modified=false markers_drawn=false no_actual_cadence_waits=true',#allPasses,text(delta(wholeStart,now())),text(contextStable),text(outputLimited),outputLimited and 'UNVERIFIED' or 'SEE_PASS_SUMMARIES')
return {passes=allPasses,cache_reads=cacheReads,contextStable=contextStable,outputLimited=outputLimited}
end
