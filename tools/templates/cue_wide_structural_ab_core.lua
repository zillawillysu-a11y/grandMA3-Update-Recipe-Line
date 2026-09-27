local rawAPI={data=_G.GetPresetData,sequence=_G.SelectedSequence,cue=_G.GetCurrentCue}
assert((safe(BuildDetails) or {}).BigVersion=='2.5.0.3','Requires grandMA3 2.5.0.3')
assert(type(rawAPI.data)=='function','GetPresetData required for oracle')
local sequence,currentCue=safe(rawAPI.sequence),safe(rawAPI.cue)
assert(sequence and currentCue and cueNumber(currentCue),'Select readable Sequence/Current Cue')
SelectedSequence=function() return sequence end; GetCurrentCue=function() return currentCue end
local function now() local n=safe(Time); return type(n)=='number' and n or nil end
local function elapsed(a,b) return a and b and b>=a and (b-a)*1000 or nil end
local function text(v) return v==nil and 'UNAVAILABLE' or tostring(v):gsub('[\r\n]',' '):sub(1,220) end
local function token(h) return h and safe(HandleToStr,h) or nil end
local function method(h,k,...) return safe(function(...) return h[k](h,...) end,...) end
local function describe(h) return 'class='..text(class(h))..' command='..text(commandAddress(h))..' native='..text(method(h,'AddrNative'))..' DB_handle='..text(token(h)) end
local function kind(h) return isRandomGenerator(h) and 'Generator' or (isPhaserRecipePreset(h) and 'Phaser' or 'Preset') end
local outputCount,outputCapped=0,false
local function log(f,...) if outputCount>=6000 then outputCapped=true; return end; outputCount=outputCount+1; Printf('[CueStructAB] '..f,...) end
local identities,identityCache,identityUnverified={},{},false
local function dbEqual(a,b)
 if a==b then return true end
 local aa,bb=token(a),token(b); if aa and bb and aa==bb then return true end
 local v=safe(CompareHandle,a,b); if type(v)=='boolean' then return v end
 identityUnverified=true; return false
end
local function id(h)
 if not isObjectReference(h) then return nil end
 if identityCache[h] then return identityCache[h] end
 for i,v in ipairs(identities) do if dbEqual(h,v) then identityCache[h]=i; return i end end
 identities[#identities+1]=h; identityCache[h]=#identities; return #identities
end
local function setFrom(result)
 local list={}; local bad=false
 for key,e in pairs(result or {}) do
  local ref=e.object; local keyId=id(ref)
  if type(key)~='string' or not keyId then bad=true end
  if keyId then list[keyId]=ref end
 end
 return list,bad
end
local function count(t) local n=0; for _ in pairs(t or {}) do n=n+1 end; return n end
local LIMIT={channels=32768,mappingWork=262144,streamBatch=128,seconds=20,
 lookups=16384,records=8192,hybridParts=8,
 reads=512,advances=8192,rows=2048}
local phase,profiles={},{}
local function profile(name)
 local p={name=name,reads={},nativeMs=0,records=0,featureRecords=0,lookups=0,advances=0,parts=0,started=now(),timingInvalid=false,dataCache={},chunks={},witnesses={},transitions={},returnedCountMs=0,stages={},partReads={}}
 profiles[name]=p; phase=p; return p
end
local function stage(p,name)
 local t=now()
 if p.stageName then
  local ms=elapsed(p.stageStarted,t)
  if ms then p.stages[p.stageName]=(p.stages[p.stageName] or 0)+ms else p.timingInvalid=true end
 end
 p.stageName=name; p.stageStarted=t
end
local function finishProfile(p)
 stage(p,nil)
 p.totalMs=elapsed(p.started,now()); if not p.totalMs then p.timingInvalid=true end
 p.processingMs=p.totalMs and math.max(0,p.totalMs-p.nativeMs) or nil
end
captureOrigin=function(part,item,scan,index,prefix,phaser,previous)
 if item then item.probePart=part end
 if phase.name~='HYBRID' or not scan then return end
 local unit=phase.units[scan.index]
 if unit.stage=='SOURCE_WITNESS' and item then for _,ref in ipairs(item.refs) do
  local rid=id(ref); phase.witnesses[rid]=phase.witnesses[rid] or {}
  phase.witnesses[rid][index]=phase.witnesses[rid][index] or {}; phase.witnesses[rid][index][prefix]=true
 end end
 if previous then for _,ref in ipairs(previous.refs) do
  local rid=id(ref); local retained=false
  if item then for _,v in ipairs(item.refs) do if dbEqual(ref,v) then retained=true; break end end end
  if not retained then
   local released=false
   for key,step in pairs(phaser) do if type(key)=='number' and type(step)=='table' and (step[prefix..'_release'] or step[prefix..'_remove']) then released=true end end
   local reason=item and 'SUPERSEDED_BY_COOKED_REFERENCE' or (released and 'COOKED_RELEASE_OR_REMOVE' or 'COOKED_STATIC_LAYER')
   phase.transitions[rid]=phase.transitions[rid] or {}; phase.transitions[rid][reason]=(phase.transitions[rid][reason] or 0)+1
  end
 end end
end
captureFeatureRecord=function()
 phase.featureRecords=phase.featureRecords+1
 if phase.name=='HYBRID' and phase.records+phase.featureRecords>LIMIT.records then error('DIAGNOSTIC_SPARSE_PLUS_FEATURE_RECORD_LIMIT') end
end
GetPresetData=function(target,phasers,fixtures)
 if phase.name=='STRUCTURAL' then error('STRUCTURAL_MUST_NOT_READ_COOKED') end
 if #phase.reads>=LIMIT.reads then error('DIAGNOSTIC_NATIVE_READ_LIMIT') end
 local cached=phase.name=='HYBRID' and phasers==false and phase.dataCache[target]
 if cached then phase.cacheReuses=(phase.cacheReuses or 0)+1; return cached end
 local a=now(); local ok,data=pcall(rawAPI.data,target,phasers,fixtures); local ms=elapsed(a,now())
 if ms then phase.nativeMs=phase.nativeMs+ms else phase.timingInvalid=true end
 local record={target=target,kind=phasers==false and 'PART_COOKED' or 'FEATURE_REFERENCE',ms=ms,ok=ok,flags=tostring(phasers)..','..tostring(fixtures)}
 phase.reads[#phase.reads+1]=record
 if phase.name=='HYBRID' and ok and type(data)=='table' and phasers==false then
  phase.dataCache[target]=data; phase.partReads[target]=record
 end
 if not ok then error(data,0) end
 return data
end
local baselineAdvance=advanceCueEffectScan
advanceCueEffectScan=function(scan)
 phase.scan=scan; local result=baselineAdvance(scan); phase.advances=scan.advanceCalls
 return result
end
local contexts,owners,order={}, {}, {}
local structural,structuralRows,ambiguous,candidateRows,firstByChannel,groupIds={}, {}, {}, {}, {}, {}
local hardBlocked=false
local function explicitFeatures(ref)
 local found,unknown,all={},false,false
 local function add(value)
  if isObjectReference(value) then value=label(value) end
  local s=tostring(value or ''):lower()
  if s=='' or s=='none' or s=='all' then all=true; return end
  for word in s:gmatch('[%w_]+') do
   local f=normalizeFeature(word)
   if RECIPE_FEATURE_SET[f] then found[f]=true else unknown=true end
  end
 end
 if isRandomGenerator(ref) then
  local channels=safe(function() return ref.RandomChannels end)
  for _,channel in ipairs(children(channels)) do add(safe(function() return channel.Attribute end)) end
 else
  local seen=0
  local function visit(node,depth)
   if not node or depth>6 or seen>=256 then unknown=true; return end
   seen=seen+1
   if class(node):lower()=='phaserrecipevaluesource' then
    local value=property(node,'Attributes') or property(node,'Attribute') or property(node,'Feature')
    if value then add(value) end
   end
   for _,child in ipairs(children(node)) do visit(child,depth+1) end
  end
  visit(ref,0)
 end
 if all or unknown or next(found)==nil then return nil end
 return found
end
local function ambiguity(reason,row,detail,hard)
 if #ambiguous>=4096 then hardBlocked=true; return end
 ambiguous[#ambiguous+1]={reason=reason,row=row,detail=detail,hard=hard}
 if hard then hardBlocked=true end
end
-- B runs before C and A: no access to oracle records/results/prior globals.
log('START target=2.5.0.3 diagnostic_revision=3_PART_FIRST_STREAMING production_version=0.7.0.17 production_flag=false execution_order=B_STRUCTURAL,C_SPARSE_HYBRID,A_ORACLE oracle_not_available_to_candidates=true sequence={%s} cue={%s}',describe(sequence),describe(currentCue))
local b=profile('STRUCTURAL')
local okB,errorB=pcall(function()
 stage(b,'Recipe_history_walk')
 local model=newCueEffectScan(sequence,currentCue)
 if #model.parts>512 then error('DIAGNOSTIC_STRUCTURAL_PART_LIMIT') end
 for i,part in ipairs(model.parts) do
  order[part]=i; owners[part]=method(part,'Parent'); contexts[i]={part=part,cue=owners[part]}
  for ordinal,recipe in ipairs(children(part)) do if isStandardRecipe(recipe) then
   if #structuralRows>=LIMIT.rows then error('DIAGNOSTIC_RECIPE_ROW_LIMIT') end
   local group,rawGroup=recipeField(recipe,'Selection'); local ref,rawRef=recipeField(recipe,'Generator'); local field='Generator'
   if not ref then ref,rawRef=recipeField(recipe,'Values'); field='Values' end
   local row={recipe=recipe,cue=owners[part],part=part,position=i,index=recipeNumber(recipe,ordinal),enabled=recipeEnabled(recipe),group=group,ref=ref,rawGroup=rawGroup,rawRef=rawRef,field=field}
   structuralRows[#structuralRows+1]=row
   if row.enabled and ref then
    row.groupId=id(group); row.refId=id(ref); row.features=recipeReferenceFeatures(ref)
    row.moving=isPhaserRecipePreset(ref) or isRandomGenerator(ref)
    row.explicitFeatures=row.moving and explicitFeatures(ref) or nil
    candidateRows[#candidateRows+1]=row
    ambiguity('RECIPE_LAYER_AND_MANUAL_OVERRIDE_NOT_STRUCTURALLY_PROVEN',row,'abs/rel/release/overlap require cooked evidence',false)
    if not row.moving then ambiguity('ORDINARY_PRESET_MOVING_OR_STATIC_UNKNOWN',row,'do not assume static terminator',false) end
   elseif row.enabled and tostring(rawRef or '')~='' and tostring(rawRef):lower()~='none' then
    ambiguity('UNRESOLVED_RECIPE_REFERENCE',row,rawRef,true)
   end
  end end
 end
 stage(b,'group_selection_membership_expansion')
 for _,row in ipairs(candidateRows) do
 local group=row.group; local rawGroup=row.rawGroup
    local selection=safe(function() return group.Selection end)
    if not row.groupId or type(selection)~='table' then ambiguity('SELECTION_MEMBERSHIP_UNAVAILABLE',row,rawGroup,true)
    else
     groupIds[row.groupId]=group
     local members={}; row.members=members
     for _,member in pairs(selection) do
      local sf=type(member)=='table' and tonumber(member.sf_index) or nil
      if not sf then ambiguity('SELECTION_MEMBER_INDEX_UNAVAILABLE',row,text(member),true)
      else members[sf]=true end
     end
    end
 end
 stage(b,'candidate_resolution')
 -- Provisional exact DB Group + feature lane decisions; layer unknown is explicit.
 table.sort(candidateRows,function(a,c) if a.position~=c.position then return a.position>c.position end; return a.index>c.index end)
 local lanes={}
 for _,row in ipairs(candidateRows) do
  for _,feature in ipairs(row.features) do
   local key=tostring(row.groupId)..'|'..feature
   row.lanes=row.lanes or {}; row.lanes[feature]=lanes[key] and 'OLDER_LANE_CANDIDATE' or 'NEWEST_STRUCTURAL_LANE'
   if not lanes[key] then
    lanes[key]=row
    if row.moving then structural[row.refId]=row.ref end
   end
  end
 end
 local direct=currentCueRecipeEffects(currentCue)
 for _,entry in pairs(direct) do structural[id(entry.object)]=entry.object end
 -- Scope all enabled Recipe rows, including older/static/overlapping candidates.
 -- Never prune solely because a newer same-Group row looks static.
 stage(b,'eligible_key_set_construction')
 local mapped,channelFeatures={},{}; local scopedCount,mappingWork=0,0; local splitNoted=false
 for _,row in ipairs(candidateRows) do
  local family=string.match(address(row.ref),'PresetPools%.([^%.]+)%.')
  local definitiveFamily=family and RECIPE_FEATURE_SET[normalizeFeature(family)] and normalizeFeature(family)
  b.familyAddressReads=(b.familyAddressReads or 0)+1
  for sf in pairs(row.members or {}) do
  row.keys=row.keys or {}
  if not mapped[sf] then mapped[sf]=safe(GetUIChannels,sf,false) end
  local channels=mapped[sf]
  if type(channels)~='table' or #channels==0 then ambiguity('GETUICHANNELS_UNAVAILABLE_OR_EMPTY',row,sf,true)
  else for _,value in ipairs(channels) do
   mappingWork=mappingWork+1; if mappingWork>LIMIT.mappingWork then error('DIAGNOSTIC_MAPPING_WORK_LIMIT') end
   local index=tonumber(value)
   if not index then ambiguity('NON_NUMERIC_UI_CHANNEL_MAPPING',row,text(value),true)
   else
    if channelFeatures[index]==nil then local attr=safe(GetAttributeByUIChannel,index); channelFeatures[index]=attr and normalizeFeature(label(attr)) or false end
    local feature=channelFeatures[index] or nil
    local keep=true
    if definitiveFamily and feature then keep=feature==definitiveFamily
    elseif row.moving and feature and row.explicitFeatures then
     keep=row.explicitFeatures[feature]==true
    end
    if not feature then ambiguity('ATTRIBUTE_MAPPING_UNKNOWN_INCLUDE_ALL',row,index,false) end
    if keep then
     row.keys[index]=true
     if firstByChannel[index]==nil then scopedCount=scopedCount+1 end
     firstByChannel[index]=math.min(firstByChannel[index] or row.position,row.position)
     if scopedCount>2048 and not splitNoted then splitNoted=true; ambiguity('CHANNEL_SCOPE_FILTERED_IN_BOUNDED_STREAMS',nil,scopedCount,false) end
     if scopedCount>LIMIT.channels then error('DIAGNOSTIC_TOTAL_CHANNEL_SCOPE_LIMIT') end
    end
   end
  end end
 end end
 ambiguity('NON_RECIPE_CHANNELS_AND_SCOPE_COMPLETENESS_UNKNOWN',nil,'no structural API proves absence of manual moving channels outside this scope',false)
end)
finishProfile(b); b.error=not okB and tostring(errorB) or nil
if not okB then hardBlocked=true end
-- C begins with Structural candidates. Current-Cue scopes plus explicit source witnesses.
local h=profile('HYBRID'); local hybrid={}; for key,ref in pairs(structural) do hybrid[key]=ref end
h.candidatesBefore=count(hybrid); h.changes={}; h.units={}; h.recipeCache={}
sparseRecipes=function(part) return h.recipeCache[part] end
rememberSparseRecipes=function(part,recipes) h.recipeCache[part]=recipes end
local selectedParts,keysByPart,planned={}, {}, {}
stage(h,'witness_Part_selection')
local directSet=setFrom(currentCueRecipeEffects(currentCue))
local historicalKeys={}
local function plan(part,stage,keys)
 local entry=planned[part] or {stage=stage,keys={}}; planned[part]=entry
 for key in pairs(keys or {}) do entry.keys[key]=true end
end
for _,row in ipairs(candidateRows) do
 local newest=false; for _,decision in pairs(row.lanes or {}) do if decision=='NEWEST_STRUCTURAL_LANE' then newest=true end end
 if row.cue~=currentCue and structural[row.refId] and not directSet[row.refId] and row.moving and newest then
  plan(row.part,'SOURCE_WITNESS',row.keys)
  for key in pairs(row.keys or {}) do historicalKeys[key]=true end
 end
end
for _,ctx in ipairs(contexts) do if ctx.cue==currentCue then
 local keys={}; for key in pairs(historicalKeys) do keys[key]=true end
 for _,row in ipairs(candidateRows) do if row.cue==currentCue and row.position<=order[ctx.part] then
  for key in pairs(row.keys or {}) do keys[key]=true end
 end end
 if next(keys) then plan(ctx.part,'CURRENT_CUE_EVIDENCE',keys) end
end end
stage(h,'chunk_plan_construction') -- Part plans only: no per-key lookup operations.
local planningError; local plannedLookups=0
for _,ctx in ipairs(contexts) do local entry=planned[ctx.part]; if entry then
 local n=count(entry.keys)
 selectedParts[#selectedParts+1]=ctx.part; keysByPart[ctx.part]=entry.keys
 plannedLookups=plannedLookups+n -- descriptive projected positions, never execution budget
 if #selectedParts>LIMIT.hybridParts then planningError='DIAGNOSTIC_SELECTED_PART_LIMIT' end
 h.units[#h.units+1]={part=ctx.part,stage=entry.stage,keys=entry.keys,eligibleCount=n}
end end
sparseNext=function(scan,part,data)
 local pending=scan.pendingPart; local unit=h.units[scan.index]
 if not unit.started then unit.started=true; h.chunks[#h.chunks+1]=unit end
 while true do
  if (h.advanceVisited or 0)>=LIMIT.streamBatch then return nil,nil,true end
  local index,record=next(data,pending.streamKey)
  if index==nil then
   unit.completed=true
   local read=h.partReads[part]; if read then read.returned=unit.inspected or 0; read.countComplete=true end
   return nil
  end
  pending.streamKey=index
  h.advanceVisited=(h.advanceVisited or 0)+1
  phase.lookups=phase.lookups+1; unit.inspected=(unit.inspected or 0)+1
  if phase.lookups>LIMIT.lookups then error('DIAGNOSTIC_ACTUAL_COOKED_RECORD_LIMIT') end
  if type(index)=='number' and unit.keys[index] then
   phase.records=phase.records+1; unit.records=(unit.records or 0)+1
   if phase.records+phase.featureRecords>LIMIT.records then error('DIAGNOSTIC_SPARSE_RECORD_LIMIT') end
   return index,record
  end
 end
end
local okH,errorH=pcall(function()
 if hardBlocked then error('AMBIGUOUS_SCOPE_REQUIRES_FULL_COOKED_NO_HYBRID_FALLBACK') end
 if planningError then error(planningError) end
 stage(h,'cooked_stream_filtering')
 local scan=newCueEffectScan(sequence,currentCue); scan.parts={}; h.scan=scan
 for _,unit in ipairs(h.units) do scan.parts[#scan.parts+1]=unit.part end
 if #scan.parts==0 then scan.done=true; scan.result={} end
 while not scan.done do
  if scan.advanceCalls>=LIMIT.advances then error('DIAGNOSTIC_ADVANCE_LIMIT') end
  if elapsed(h.started,now()) and elapsed(h.started,now())>LIMIT.seconds*1000 then error('DIAGNOSTIC_HYBRID_ELAPSED_LIMIT') end
  h.advanceVisited=0
  sparseAdvanceCueEffectScan(scan)
  if elapsed(h.started,now()) and elapsed(h.started,now())>LIMIT.seconds*1000 then error('DIAGNOSTIC_HYBRID_ELAPSED_LIMIT') end
 end
 h.advances=scan.advanceCalls
 stage(h,'candidate_resolution')
 local cooked,bad=setFrom(addCurrentCueRecipeEffects(scan.result,currentCueRecipeEffects(currentCue)))
 if bad then error('HYBRID_INVALID_NON_STRING_RESULT_KEY') end
 for rid,ref in pairs(structural) do if not cooked[rid] then
  local witnesses=h.witnesses[rid]; local seen,survives=0,false
  for index,layers in pairs(witnesses or {}) do for prefix in pairs(layers) do
   seen=seen+1; local final=(scan.tracked[index] or {})[prefix]
   if final then for _,v in ipairs(final.refs) do if dbEqual(v,ref) then survives=true end end end
  end end
  if seen>0 and not survives and h.transitions[rid] then
   hybrid[rid]=nil; h.changes[#h.changes+1]={action='REMOVED',ref=ref,reason='ALL_SCOPED_SOURCE_WITNESS_LAYERS_REPLACED_OR_CLEARED',witnessLayers=seen,reasons=h.transitions[rid]}
  else
   ambiguity('STRUCTURAL_CANDIDATE_RETAINED_WITHOUT_CONCLUSIVE_COOKED_REMOVAL',nil,commandAddress(ref),false)
   h.changes[#h.changes+1]={action='RETAINED_AMBIGUOUS',ref=ref,reason='NO_POSITIVE_SOURCE_WITNESS_OR_UNCLEARED_LAYER',witnessLayers=seen}
  end
 else
  h.changes[#h.changes+1]={action=directSet[rid] and 'RETAINED_DIRECT_MERGE' or 'RETAINED_SCOPED_COOKED',ref=ref,reason=directSet[rid] and 'EXISTING_ORACLE_CURRENT_RECIPE_MERGE' or 'SURVIVES_SELECTED_SCOPES_INTERMEDIATE_HISTORY_UNVERIFIED'}
 end end
 for rid,ref in pairs(cooked) do if not hybrid[rid] then
  hybrid[rid]=ref; h.changes[#h.changes+1]={action='ADDED',ref=ref,reason=directSet[rid] and 'ORACLE_COMPATIBLE_CURRENT_RECIPE_DIRECT_MERGE' or 'MOVING_REFERENCE_SURVIVES_SELECTED_COOKED_SCOPES'}
 end end
 if elapsed(h.started,now()) and elapsed(h.started,now())>LIMIT.seconds*1000 then error('DIAGNOSTIC_HYBRID_ELAPSED_LIMIT') end
end)
if h.scan then
 h.advances=h.scan.advanceCalls
 local completed={}
 for _,unit in ipairs(h.units) do if completed[unit.part]==nil then completed[unit.part]=true end; if not unit.completed then completed[unit.part]=false end end
 for _,allDone in pairs(completed) do if allDone then h.parts=h.parts+1 end end
end
h.executed=#h.chunks>0; h.resultValid=okH and h.executed
finishProfile(h); h.error=not okH and tostring(errorH) or nil
-- A runs LAST. Full cooked walk exists ONLY as the permitted oracle.
local a=profile('BASELINE'); local baseline={}; local baselineBad=false
local okA,errorA=pcall(function()
 local state={poolBlink=true,running=true}
 for tick=0,LIMIT.advances do
  a.tick=tick; refreshCueEffects(state,true)
  if state.effectError then error(state.effectError) end
  if not state.recipeScanPending and not state.effectScanPending and not state.effectScanner then
   baseline,baselineBad=setFrom(state.activeEffects); return
  end
 end
 error('DIAGNOSTIC_BASELINE_ADVANCE_LIMIT')
end)
if a.scan then a.parts=#a.scan.diagnostics.parts; for _,d in ipairs(a.scan.diagnostics.parts) do a.records=a.records+d.channels end end
finishProfile(a); a.error=not okA and tostring(errorA) or nil
local stable=safe(rawAPI.sequence)==sequence and safe(rawAPI.cue)==currentCue
local comparisons={}
local function compare(name,candidate,success)
 local missing,extra={},{}
 if success and okA then
  for key,ref in pairs(baseline) do if not candidate[key] then missing[key]=ref end end
  for key,ref in pairs(candidate) do if not baseline[key] then extra[key]=ref end end
 end
 local classification=name=='STRUCTURAL' and 'STRUCTURAL_EXACT_MATCH' or 'HYBRID_EXACT_MATCH'
 if not okA or baselineBad or not stable or identityUnverified then classification='UNVERIFIED'
 elseif not success then
  local e=name=='STRUCTURAL' and b.error or h.error
  classification=(hardBlocked or (e and (e:find('LIMIT') or e:find('AMBIGUOUS_SCOPE')))) and 'AMBIGUOUS_REQUIRES_FULL_COOKED' or 'UNVERIFIED'
 elseif count(missing)>0 then classification='MISSING_REFERENCE'
 elseif count(extra)>0 then classification='EXTRA_REFERENCE' end
 comparisons[name]={classification=classification,missing=missing,extra=extra,candidateValid=success and okA}
 return comparisons[name]
end
compare('STRUCTURAL',structural,okB); compare('HYBRID',hybrid,h.resultValid)
-- All output/metadata work occurs after phase timing.
log('RESULTS oracle_executed_after_candidates=true scope_channels=%d selected_cooked_Parts=%d total_history_Parts=%d',count(firstByChannel),#selectedParts,#contexts)
for _,p in ipairs({b,h,a}) do
 local cooked,featureReads=0,0
 for _,r in ipairs(p.reads) do if r.kind=='PART_COOKED' then cooked=cooked+1 else featureReads=featureReads+1 end end
 local metric=function(v) return p.timingInvalid and 'UNAVAILABLE' or text(v) end
 local waitTicks=p.name=='BASELINE' and (p.tick or 0) or p.advances
 log('METRICS phase=%s Recipe_rows_inspected_by_structural_scope=%d cooked_Parts_read=%d completed_Parts=%d cooked_records_processed=%d actual_cooked_entries_inspected=%d GetPresetData_calls=%d supplementary_feature_reads=%d GetPresetData_ms=%s Lua_processing_including_other_read_APIs_ms=%s total_elapsed_ms=%s advances=%d cadence_unchanged_seconds=%g actual_waits=false estimated_wait_ms=%g error=%s',p.name,#structuralRows,cooked,p.parts,p.records,p.lookups,#p.reads,featureReads,metric(p.nativeMs),metric(p.processingMs),metric(p.totalMs),p.advances,REFRESH_SECONDS,waitTicks*REFRESH_SECONDS*1000,text(p.error))
 for _,r in ipairs(p.reads) do log('READ phase=%s kind=%s target={%s} source_cue={%s} flags=%s elapsed_ms=%s success=%s returned_record_count=%s count_limited=%s',p.name,r.kind,describe(r.target),describe(owners[r.target]),r.flags,text(r.ms),text(r.ok),text(r.returned),text(r.countLimited==true)) end
 log('FEATURE_WORK phase=%s supplementary_feature_records_processed=%d combined_Part_and_feature_records=%d',p.name,p.featureRecords,p.records+p.featureRecords)
end
local returned,returnedKnown=0,true
for _,read in ipairs(h.reads) do if read.kind=='PART_COOKED' then if read.returned then returned=returned+read.returned else returnedKnown=false end end end
log('HYBRID_EXECUTION mode=PART_FIRST_STREAMING executed=%s result_valid=%s candidates_before=%d candidates_after=%d selected_Parts=%d Parts_started=%d stream_advances_used=%d projected_eligible_key_positions=%d actual_cooked_records_inspected=%d sparse_keys_actually_inspected=%d cooked_records_returned=%s actual_record_limit=%d total_processed_record_limit=%d stream_inspection_limit_per_advance=%d elapsed_limit_seconds=%d',text(h.executed),text(h.resultValid),h.candidatesBefore,count(hybrid),#selectedParts,#h.chunks,h.advances,plannedLookups,h.lookups,h.records,returnedKnown and text(returned) or 'UNAVAILABLE',LIMIT.lookups,LIMIT.records,LIMIT.streamBatch,LIMIT.seconds)
for _,p in ipairs({b,h}) do
 for _,name in ipairs({'Recipe_history_walk','group_selection_membership_expansion','eligible_key_set_construction','witness_Part_selection','chunk_plan_construction','candidate_resolution','cooked_stream_filtering'}) do
  log('STAGE_TIMING phase=%s stage=%s elapsed_ms=%s ran=%s exclusive=true',p.name,name,p.timingInvalid and 'UNAVAILABLE' or text(p.stages[name] or 0),text(p.stages[name]~=nil))
 end
end
log('SCOPE_WORK family_address_reads=%d projected_key_positions_are_not_lookup_plan=true',b.familyAddressReads or 0)
log('SKIPPED_HISTORY planned_history_Parts=%d selected_Parts=%d unselected_history_Parts=%d candidate_support_projection_only=true intermediate_release_override_not_globally_excluded=true',#contexts,#selectedParts,#contexts-#selectedParts)
for i,unit in ipairs(h.units) do log('PART_STREAM number=%d stage=%s cue={%s} part={%s} eligible_keys=%d actual_returned_entries_inspected=%d matching_records_processed=%d filtered_out=%d completed=%s',i,unit.stage,describe(owners[unit.part]),describe(unit.part),unit.eligibleCount,unit.inspected or 0,unit.records or 0,(unit.inspected or 0)-(unit.records or 0),text(unit.completed==true)) end
for _,change in ipairs(h.changes) do
 local reasons={}; for reason,n in pairs(change.reasons or {}) do reasons[#reasons+1]=reason..':'..n end; table.sort(reasons)
 log('CANDIDATE_CHANGE action=%s reference={%s} reason=%s witnessed_layers=%s cooked_transition_reasons=%s applies_to_completed_hybrid=%s',change.action,describe(change.ref),change.reason,text(change.witnessLayers),table.concat(reasons,','),text(h.resultValid))
end
for _,row in ipairs(structuralRows) do
 log('RECIPE source_cue={%s} source_part={%s} recipe={%s} Enabled=%s selection_raw=%s selection={%s} reference_field=%s raw_reference=%s reference={%s} DB_group_id=%s features=%s candidate_moving_type=%s layer=UNKNOWN group_overlap_possible=true',describe(row.cue),describe(row.part),describe(row.recipe),text(row.enabled),text(row.rawGroup),describe(row.group),row.field,text(row.rawRef),describe(row.ref),text(row.groupId),table.concat(row.features or {},','),text(row.moving))
 for feature,decision in pairs(row.lanes or {}) do log('LANE recipe={%s} feature=%s decision=%s status=PROVISIONAL_LAYER_UNPROVEN',describe(row.recipe),feature,decision) end
 local scoped={}; for feature in pairs(row.explicitFeatures or {}) do scoped[#scoped+1]=feature end; table.sort(scoped)
 log('SCOPE_FEATURES recipe={%s} explicit_value_source_or_generator_features=%s unknown_metadata_widens_scope=true Name_not_used_to_narrow=true',describe(row.recipe),#scoped>0 and table.concat(scoped,',') or 'UNKNOWN_OR_ALL')
end
for _,part in ipairs(selectedParts) do log('FALLBACK_SCOPE stage=%s cue={%s} part={%s} eligible_UI_keys=%d chunks=%d layers=ABS_AND_REL reason=explicit_ambiguous_current_scope_or_candidate_source_witness',planned[part].stage,describe(owners[part]),describe(part),count(keysByPart[part]),0) end
for _,issue in ipairs(ambiguous) do local row=issue.row or {}; log('AMBIGUITY reason=%s cue={%s} part={%s} recipe={%s} detail=%s blocks_hybrid=%s',issue.reason,describe(row.cue),describe(row.part),describe(row.recipe),text(issue.detail),text(issue.hard==true)) end
for _,pair in ipairs({{'BASELINE',baseline},{'STRUCTURAL',structural},{'HYBRID',hybrid}}) do for key,ref in pairs(pair[2]) do
 log('FINAL_SET phase=%s DB_identity_id=%d reference_type=%s reference={%s} candidate_result_valid=%s',pair[1],key,kind(ref),describe(ref),text(pair[1]~='HYBRID' or h.resultValid))
 if pair[1]=='BASELINE' and a.scan then
  local origins={}
  for index,layers in pairs(a.scan.tracked) do for prefix,item in pairs(layers) do for _,source in ipairs(item.refs) do
   if dbEqual(source,ref) then
    local part=item.probePart or false; origins[part]=origins[part] or {}; local origin=origins[part][prefix] or {count=0,sample=index}; origins[part][prefix]=origin; origin.count=origin.count+1
   end
  end end end
  for part,layers in pairs(origins) do for prefix,origin in pairs(layers) do log('ORACLE_LAYER reference={%s} channel_sample=%s layer=%s channels_in_origin=%d source_cue={%s} source_part={%s}',describe(ref),text(origin.sample),prefix,origin.count,describe(owners[part]),describe(part)) end end
 end
end end
for _,row in ipairs(candidateRows) do if row.cue==currentCue and row.moving then
 log('ORACLE_DIRECT_MERGE reference={%s} source_cue={%s} source_part={%s} recipe={%s} retained_even_without_cooked=true',describe(row.ref),describe(row.cue),describe(row.part),describe(row.recipe))
end end
for _,name in ipairs({'STRUCTURAL','HYBRID'}) do local c=comparisons[name]
 for _,ref in pairs(c.missing) do log('DIFF phase=%s classification=MISSING_REFERENCE exact_handle={%s}',name,describe(ref)) end
 for _,ref in pairs(c.extra) do log('DIFF phase=%s classification=EXTRA_REFERENCE exact_handle={%s}',name,describe(ref)) end
 log('RESULT phase=%s classification=%s baseline_final_refs=%d candidate_final_refs=%d missing=%s extra=%s candidate_result_valid=%s identity_only=true scope_completeness_proven=false exact_match_means_current_oracle_snapshot_only=true',name,c.classification,count(baseline),name=='STRUCTURAL' and count(structural) or count(hybrid),c.candidateValid and text(count(c.missing)) or 'UNAVAILABLE',c.candidateValid and text(count(c.extra)) or 'UNAVAILABLE',text(c.candidateValid))
end
local function reduction(v,base) return h.resultValid and base>0 and (1-v/base)*100 or nil end
log('REDUCTION hybrid_records=%d baseline_records_current=%d baseline_advances_current=%d historical_records=22764 historical_advances=731 records_vs_current_percent=%s records_vs_historical_percent=%s advances_vs_current_percent=%s advances_vs_historical_percent=%s',h.records,a.records,a.advances,text(reduction(h.records,a.records)),text(reduction(h.records,22764)),text(reduction(h.advances,a.advances)),text(reduction(h.advances,731)))
log('CANDIDATE_TOTAL structural_plus_hybrid_elapsed_ms=%s baseline_elapsed_ms=%s structural_GetPresetData_calls=%d full_cooked_fallback_executed=false full_cooked_scan_only_in_oracle=true',text(b.totalMs and h.totalMs and b.totalMs+h.totalMs),text(a.totalMs),#b.reads)
Printf('[CueStructAB] END context_stable=%s output_capped=%s baseline_valid=%s structural_classification=%s hybrid_classification=%s hybrid_executed=%s hybrid_result_valid=%s scope_completeness_proven=false production_modified=false markers_drawn=false',text(stable),text(outputCapped),text(okA and not baselineBad),outputCapped and 'UNVERIFIED' or comparisons.STRUCTURAL.classification,outputCapped and 'UNVERIFIED' or comparisons.HYBRID.classification,text(h.executed),text(h.resultValid))
return {baseline=baseline,structural=structural,hybrid=hybrid,profiles=profiles,comparisons=comparisons,ambiguities=ambiguous,stable=stable,hardBlocked=hardBlocked,rows=structuralRows,outputCapped=outputCapped}
end
