local rawData=_G.GetPresetData
assert((safe(BuildDetails) or {}).BigVersion=='2.5.0.3','Requires grandMA3 2.5.0.3')
local sequence,cue=safe(_G.SelectedSequence),safe(_G.GetCurrentCue)
assert(sequence and cue and cueNumber(cue),'Select Sequence and Current Cue')
SelectedSequence=function() return sequence end
GetCurrentCue=function() return cue end
local function count(t) local n=0; for _ in pairs(t or {}) do n=n+1 end; return n end
local function text(v) return (v==nil and 'UNAVAILABLE' or tostring(v)):gsub('[\r\n]',' '):sub(1,240) end
local function desc(h) return text(commandAddress(h))..' ['..text(safe(HandleToStr,h))..']' end
local function log(fmt,...) nativePrintf('%s','[CueRecipeReverseAB] '..string.format(fmt,...)) end
local detailCount,diffDetailCount,detailsSuppressed=0,0,0
local function detail(fmt,...)
 local label=fmt:match('^([%w_]+)') or select(1,...)
 if type(label)=='string' and label:sub(1,4)=='DIFF' then
  if diffDetailCount>=150 then detailsSuppressed=detailsSuppressed+1; return end
  diffDetailCount=diffDetailCount+1
 else
  if detailCount>=500 then detailsSuppressed=detailsSuppressed+1; return end
  detailCount=detailCount+1
 end
 log(fmt,...)
end
local function now() return safe(Time) end
local function ms(a,b) return type(a)=='number' and type(b)=='number' and b>=a and (b-a)*1000 or 'UNVERIFIED' end
local identities={}
local function id(h)
 if not isObjectReference(h) then return nil end
 for i,v in ipairs(identities) do
  if h==v or safe(CompareHandle,h,v)==true then return i end
  local hi,vi=safe(_G.HandleToInt,h),safe(_G.HandleToInt,v)
  if type(hi)=='number' and math.type(hi)=='integer' and type(vi)=='number' and math.type(vi)=='integer' and hi~=0 and hi==vi then return i end
  local a,b=safe(HandleToStr,h),safe(HandleToStr,v)
  if a and b and a==b then return i end
 end
 identities[#identities+1]=h; return #identities
end
local phase,fastCalls,oracleCalls='FAST',0,0
GetPresetData=function(...)
 if phase=='FAST' then fastCalls=fastCalls+1; error('FAST_PATH_FORBIDDEN_GetPresetData') end
 assert(phase=='ORACLE','GETPRESETDATA_OUTSIDE_ORACLE'); oracleCalls=oracleCalls+1; return rawData(...)
end
local function joined(t) local a={}; for k in pairs(t or {}) do a[#a+1]=tostring(k) end; table.sort(a); return table.concat(a,',') end
local function sample(members)
 local ids={}; for member in pairs(members or {}) do ids[#ids+1]=member end; table.sort(ids)
 local a={}; for i=1,math.min(5,#ids) do a[#a+1]=tostring(ids[i]) end; return table.concat(a,',')
end
local auditor=newRecipeValueSourceAuditor({safe=safe,class=class,isObject=isObjectReference,
 objectList=_G.ObjectList,id=id,desc=desc,count=count,joined=joined,isGenerator=isRandomGenerator,enums=_G.Enums})
local patterns,patternOrder={},{}
local function retainAudit(row,data)
 for _,a in ipairs(data.audits) do
  local key=a.pattern
  local p=patterns[key]
  if not p then p={row=row,audit=a,data=data,count=0,recipes={}}; patterns[key]=p; patternOrder[#patternOrder+1]=p end
  p.count=p.count+1; p.recipes[row.recipe]=true
 end
end
log('START revision=4_REFERENCE_METADATA_CACHE target=2.5.0.3 sequence=%s cue=%s order=NATIVE_ONLY_THEN_REFERENCE_METADATA_REVERSE_THEN_ORACLE production_flag=false no_waits=true no_markers=true',desc(sequence),desc(cue))
local start=now()
local rows,groups,cues={},{},{}
local stats={parts=0,rows=0,expansions=0,groups=0}
local result
local ok,err=pcall(function()
 local model=newCueEffectScan(sequence,cue) -- object tree only; no cooked calls
 for _,historyCue in ipairs(children(sequence)) do
  local n=cueNumber(historyCue)
  if class(historyCue):lower()=='cue' and n and n>0 and n<=cueNumber(cue) then cues[id(historyCue)]=true end
 end
 for i=#model.parts,1,-1 do
  local part=model.parts[i]; local owner=safe(function() return part:Parent() end)
  cues[id(owner) or desc(owner)]=true; stats.parts=stats.parts+1
  local recipes={}
  for ordinal,r in ipairs(children(part)) do if isStandardRecipe(r) then recipes[#recipes+1]={r=r,n=recipeNumber(r,ordinal),ordinal=ordinal} end end
  table.sort(recipes,function(a,b) if a.n==b.n then return a.ordinal>b.ordinal end; return a.n>b.n end)
  for _,item in ipairs(recipes) do
   stats.rows=stats.rows+1; assert(stats.rows<=2048,'Recipe row limit exceeded')
   local r=item.r
   if recipeEnabled(r) then
    local group,rawGroup=recipeField(r,'Selection')
    local ref,rawRef=recipeField(r,'Generator'); local field='Generator'
    if not ref then ref,rawRef=recipeField(r,'Values'); field='Values' end
    local row={recipe=r,part=part,cue=owner,group=group,ref=ref,refId=id(ref),unsafe={},field=field}
    local gid=id(group)
    if gid and class(group):lower()=='group' then
     if not groups[gid] then
      local selection=safe(function() return group.Selection end)
      local members,valid={},type(selection)=='table'
      if valid then for _,member in pairs(selection) do
       stats.expansions=stats.expansions+1; assert(stats.expansions<=262144,'Membership limit exceeded')
       local sf=type(member)=='table' and tonumber(member.sf_index)
       if sf and sf>=0 and sf%1==0 then members[sf]=true else valid=false end
      end end
      groups[gid]={members=valid and members or nil}; if valid then stats.groups=stats.groups+1 end
     end
     row.members=groups[gid].members
    end
    if not row.members then row.unsafe[#row.unsafe+1]='FAST_PATH_UNSAFE_SELECTION' end
    if ref then
     local data=auditor.inspect(ref); row.structural=data
     row.features=data.featureProven and data.features or nil
     row.layers=data.layerProven and data.layers or nil
     row.lanes=data.proven and data.lanes or nil
     row.moving=data.moving; row.motionReason=data.motionReason
     row.evidence=joined(data.reasons)
     retainAudit(row,data)
     local recipeMeta=auditor.metadata(r)
     row.recipeLayer=recipeMeta.layer and recipeMeta.layer.raw
     if not row.features then row.unsafe[#row.unsafe+1]='FAST_PATH_UNSAFE_FEATURE_SCOPE' end
     if not row.layers then row.unsafe[#row.unsafe+1]='FAST_PATH_UNSAFE_LAYER' end
     if not data.proven then row.unsafe[#row.unsafe+1]='UNVERIFIED' end
    else
     row.unsafe[#row.unsafe+1]='UNVERIFIED'; row.evidence='Unresolved '..field..'='..text(rawRef)..' Selection='..text(rawGroup)
    end
    rows[#rows+1]=row
   end
  end
 end
 result=recipeReverseResolve(rows)
 assert(fastCalls==0,'FAST_PATH_FORBIDDEN_GetPresetData_CALLS')
end)
local fastElapsed=ms(start,now())
result=result or {refs={},unsafe={},rejected={},assignments={}}
-- Immutable snapshot finalized before the oracle is even constructed.
local final={}; for rid,entry in pairs(result.refs) do final[rid]=entry.ref end
log('NATIVE_ONLY_FINALIZED valid=%s refs=%d GetPresetData_calls=%d',text(ok),count(final),fastCalls)
log('FAST_FINALIZED valid=%s refs=%d GetPresetData_calls=%d elapsed_ms=%s error=%s',text(ok),count(final),fastCalls,text(fastElapsed),text(err))
local function metrics()
 log('FAST_PATH_METRICS Cues=%d Parts=%d Recipe_rows=%d Stored_Groups=%d group_member_expansion=%d member_feature_lanes_resolved=%d empty_effective_rows=%d static_terminators=%d moving_contributing_rows=%d unsafe_rows=%d unresolved_symbolic_lanes=%d unknown_selection_rows=%d GetPresetData_calls=%d elapsed_ms=%s history_exhausted=%s',count(cues),stats.parts,stats.rows,stats.groups,stats.expansions,result.lanesResolved or 0,result.rowsSkipped or 0,result.staticRows or 0,result.movingRows or 0,#result.unsafe,#(result.unresolved or {}),result.unknownSelectionRows or 0,fastCalls,text(fastElapsed),text(ok))
end
metrics()
local function path(h) return desc(h)..' native='..text(h and address(h)) end
-- Separate native-only observation; immutable final and row proof gates stay unchanged.
local semanticsAudit=newReferenceSemanticsAudit({safe=safe,class=class,isObject=isObjectReference,
 desc=desc,metadata=auditor.metadata,joined=joined})
local semanticsSeen,semanticsPatterns={},{}
local semanticsStats={references=0,ordinary=0,moving=0,feature=0,layer=0,motion=0,static=0,unresolved=0}
local function auditText(v) return tostring(v):gsub('[\r\n]',' '):sub(1,6000) end
for _,row in ipairs(rows) do
 if row.refId and row.structural and not semanticsSeen[row.refId] then
  semanticsSeen[row.refId]=true
  local a=semanticsAudit(row.ref,row.structural,row.recipe)
  semanticsStats.references=semanticsStats.references+1
  if row.structural.sourceCount==0 and class(row.ref):lower()=='preset' then semanticsStats.ordinary=semanticsStats.ordinary+1 end
  if row.structural.sourceCount>0 then semanticsStats.moving=semanticsStats.moving+1 end
  if a.feature then semanticsStats.feature=semanticsStats.feature+1 end
  if a.layer then semanticsStats.layer=semanticsStats.layer+1 end
  if a.motion=='MOTION_PROVEN' then semanticsStats.motion=semanticsStats.motion+1
  elseif a.motion=='STATIC_PROVEN' then semanticsStats.static=semanticsStats.static+1 end
  if not a.feature or not a.layer or a.motion=='MOTION_UNPROVEN' then semanticsStats.unresolved=semanticsStats.unresolved+1 end
  if not semanticsPatterns[a.key] then
   semanticsPatterns[a.key]=true
   if count(semanticsPatterns)<=80 then
   log('REFERENCE_SEMANTICS_AUDIT reference=%s Recipe=%s Group=%s pool=%s pool_class=%s classes=%s native_feature_proven=%s native_layer_proven=%s motion=%s step_count=%d truncated=%s unresolved=%s interpretation=OBSERVATION_ONLY_POOL_LINKS_NOT_COMPLETE_CONTENT_PROOF',desc(row.ref),desc(row.recipe),desc(row.group),desc(a.pool),class(a.pool),a.classes,text(a.feature),text(a.layer),a.motion,a.stepCount,text(a.truncated),text(a.reason))
   log('REFERENCE_SEMANTICS_AUDIT_PROPERTIES reference=%s reference_properties=%s reference_links=%s probes=%s pool_properties=%s pool_links=%s pool_probes=%s',desc(row.ref),auditText(a.props),auditText(a.links),auditText(a.probes),auditText(a.poolProps),auditText(a.poolLinks),auditText(a.poolProbes))
   log('REFERENCE_SEMANTICS_AUDIT_STRUCTURE reference=%s Attributes=%s Shape=%s dependencies=%s Recipe_properties=%s Recipe_probes=%s',desc(row.ref),auditText(a.attributes),auditText(a.shapes),auditText(a.dependencies),auditText(a.rowProps),auditText(a.rowProbes))
   for i=1,math.min(8,#a.steps) do log('REFERENCE_SEMANTICS_AUDIT_STEP reference=%s evidence=%s',desc(row.ref),auditText(a.steps[i])) end
   if #a.steps>8 then log('REFERENCE_SEMANTICS_AUDIT_STEP_LIMIT reference=%s omitted=%d',desc(row.ref),#a.steps-8) end
   end
  end
 end
end
log('REFERENCE_SEMANTICS_SUMMARY distinct_references=%d distinct_patterns=%d native_only_Feature_proof=%d native_only_Layer_proof=%d MOTION_PROVEN=%d STATIC_PROVEN=%d unresolved_references=%d distinct_ordinary_Presets=%d distinct_ValueSource_references=%d metadata_GetPresetData_count=0 metadata_ms=0 metadata_comparison=NOT_RUN',semanticsStats.references,count(semanticsPatterns),semanticsStats.feature,semanticsStats.layer,semanticsStats.motion,semanticsStats.static,semanticsStats.unresolved,semanticsStats.ordinary,semanticsStats.moving)

for i,p in ipairs(patternOrder) do
 if i<=120 then
  local a,row,data=p.audit,p.row,p.data
  detail('VALUE_SOURCE_AUDIT pattern=%d occurrences=%d Recipe=%s Group=%s reference=%s native_classes=%s ValueSource=%s ValueSource_class=%s Attributes_property=%s Attributes_raw=%s Attributes_type=%s Attributes_handle_path=%s Feature=%s FeatureGroup=%s RawValueAbs=%s RawValueRel=%s effective_abs=%s effective_rel=%s Shape=%s Shape_handle=%s Shape_chain=%s Preset=%s Preset_handle=%s Layer=%s Recipe_Layer=%s proposed=%s confidence=%s attribute_proof=%s layer_proof=%s motion=%s unsafe_reason=%s reference_metadata=%s preset_metadata=%s source_metadata=%s',
   i,p.count,desc(row.recipe),desc(row.group),desc(row.ref),joined(data.classes),desc(a.node),text(a.sourceClass),text(a.attributeProperty),text(a.attribute),type(a.attribute),path(a.attributeHandle),path(a.feature),path(a.featureGroup),text(a.abs),text(a.rel),text(a.effectiveAbs),text(a.effectiveRel),text(a.shape),path(a.shapeHandle),text(a.shapeChain),text(a.preset),path(a.presetHandle),text(a.layer),text(row.recipeLayer),text(a.proposed),text(a.confidence),text(a.attributeProof),text(a.layerProof),text(a.motionReason),text(a.reason),text(data.refMeta),text(a.presetMetadata),text(a.metadata))
 end
end
log('VALUE_SOURCE_AUDIT_SUMMARY distinct_patterns=%d shown=%d suppressed=%d',#patternOrder,math.min(120,#patternOrder),math.max(0,#patternOrder-120))
local function trace(row,tag)
 local survivors=tag=='SOURCE' and row.movingSurvivors or row.survivors
 detail('%s ref=%s Cue=%s Part=%s Recipe=%s Group=%s features=%s layers=%s surviving_member_count=%d surviving_sample=%s group_member_count=%d member_sample=%s unsafe=%s motion_reason=%s evidence=%s',tag,desc(row.ref),desc(row.cue),desc(row.part),desc(row.recipe),desc(row.group),joined(row.features),joined(row.layers),count(survivors),sample(survivors),count(row.members),sample(row.members),table.concat(row.unsafe or {},','),text(row.motionReason),text(row.evidence))
end
local function identityOutput(tag,set)
 log('%s count=%d',tag,count(set))
 local refs={}; for _,ref in pairs(set) do refs[#refs+1]=ref end
 table.sort(refs,function(a,b) return desc(a)<desc(b) end)
 for i=1,math.min(128,#refs) do log('%s_REF reference=%s',tag,desc(refs[i])) end
 if #refs>128 then log('%s_DETAIL_LIMIT suppressed=%d exact_set_preserved_in_comparison=true',tag,#refs-128) end
end
identityOutput('NATIVE_ONLY_FINAL',final)
log('RECIPE_ONLY_FINAL count=%d alias=NATIVE_ONLY_FINAL',count(final))
for rid,entry in pairs(result.refs) do
 detail('ACTIVE ref=%s surviving_member_count=%d surviving_sample=%s',desc(entry.ref),count(entry.members),sample(entry.members))
 for row in pairs(entry.sources) do trace(row,'SOURCE') end
end
for _,row in ipairs(result.unsafe) do trace(row,'UNSAFE') end
local unresolved,unresolvedCount={},0
for _,lane in ipairs(result.unresolved or {}) do
 local row=lane.row; unresolved[row]=unresolved[row] or {}
 local bucket=unresolved[row][lane.lane] or {}; unresolved[row][lane.lane]=bucket; bucket[lane.member]=true
end
for row,lanes in pairs(unresolved) do for lane,members in pairs(lanes) do
 unresolvedCount=unresolvedCount+1
 detail('UNRESOLVED Recipe=%s Group=%s feature_layer=%s member_count=%d member_sample=%s',desc(row.recipe),desc(row.group),lane,count(members),sample(members))
end end
log('UNSAFE_UNRESOLVED_SUMMARY unsafe_rows=%d unresolved_groups=%d symbolic_member_lanes=%d unknown_selection_rows=%d',#result.unsafe,unresolvedCount,#(result.unresolved or {}),result.unknownSelectionRows or 0)
for _,row in ipairs(result.rejected) do
 trace(row,'OLDER_REJECTED_OVERLAP')
 local losses={}
 for _,loss in ipairs(row.superseded) do
  losses[loss.newer]=losses[loss.newer] or {}
  local bucket=losses[loss.newer][loss.lane] or {sample=loss.member,n=0,unsafe=loss.unsafe}; losses[loss.newer][loss.lane]=bucket; bucket.n=bucket.n+1
 end
 for newer,lanes in pairs(losses) do for lane,bucket in pairs(lanes) do
  detail('FIRST_NEWER member=%s overlapping_member_count=%d lane=%s older_Recipe=%s newer_Cue=%s newer_Part=%s newer_Recipe=%s newer_Group=%s unsafe_barrier=%s',text(bucket.sample),bucket.n,lane,desc(row.recipe),desc(newer.cue),desc(newer.part),desc(newer.recipe),desc(newer.group),text(bucket.unsafe==true))
 end end
end
-- New run-local path starts after audit logging; audit overhead is excluded.
phase='METADATA'
local metadataStart=now()
local recipeTargets={}
local metadataCache
metadataCache=newReferenceMetadataCache({safe=safe,class=class,isObject=isObjectReference,
 handleToInt=_G.HandleToInt,handleToStr=_G.HandleToStr,attributeByUIChannel=_G.GetAttributeByUIChannel,
 now=now,log=log,desc=path,validateTarget=function(target,key)
  assert(phase=='METADATA','METADATA_READ_PHASE_VIOLATION')
  local c=class(target):lower()
  assert(c~='cue' and c~='part' and c~='cuepart' and c~='sequence','METADATA_FORBIDDEN_TARGET_'..c)
  assert(key==metadataCache.identity(target) and recipeTargets[key],'METADATA_TARGET_NOT_RECIPE_REFERENCE')
 end,read=function(target,phasersOnly,byFixtures)
  assert(phase=='METADATA','METADATA_READ_PHASE_VIOLATION')
  return rawData(target,phasersOnly,byFixtures)
 end})
local metadataRows,metadataResult,metadataFinal={},{},{}
local metadataOK,metadataError=pcall(function()
 for _,row in ipairs(rows) do if row.ref then
  local key=metadataCache.register(row.ref); if key then recipeTargets[key]=true end
 end end
 -- Requests for reused references prove cache hits instead of re-reading.
 for _,row in ipairs(rows) do
  local m=row.ref and metadataCache.get(row.ref) or {completeness='UNKNOWN',motion='UNSAFE',evidence='RECIPE_REFERENCE_UNRESOLVED'}
  local copy={recipe=row.recipe,part=row.part,cue=row.cue,group=row.group,members=row.members,ref=row.ref,
   refId=row.refId,features=m.features,layers=m.layers,lanes=m.lanes,moving=m.motion=='MOVING' or m.motion=='GENERATOR',
   evidence=m.evidence,metadata=m,unsafe={}}
  if not copy.members then copy.unsafe[#copy.unsafe+1]='FAST_PATH_UNSAFE_SELECTION' end
  if m.completeness~='COMPLETE' or m.motion=='UNSAFE' then
   copy.unsafe[#copy.unsafe+1]='METADATA_REFERENCE_UNSAFE'
   -- Unknown scope blocks all lanes for these members. Partial scope is known.
   if not m.featureScopeKnown or not next(m.features or {}) then copy.features=nil end
   if not m.layerScopeKnown or not next(m.layers or {}) then copy.layers=nil end
  end
  metadataRows[#metadataRows+1]=copy
 end
end)
local cacheElapsed=ms(metadataStart,now())
local reverseStart=now()
if metadataOK then metadataOK,metadataError=pcall(function() metadataResult=recipeReverseResolve(metadataRows) end) end
local reverseElapsed=ms(reverseStart,now())
metadataResult=metadataResult or {refs={},unsafe={}}
for rid,entry in pairs(metadataResult.refs) do metadataFinal[rid]=entry.ref end
local totalMetadataElapsed=ms(metadataStart,now())
log('METADATA_REVERSE_FINALIZED valid=%s refs=%d error=%s',text(metadataOK),count(metadataFinal),text(metadataError))
local cs=metadataCache.stats
local function metadataMetrics()
 log('REFERENCE_METADATA_CACHE distinct_references=%d metadata_GetPresetData_calls=%d cache_hits=%d COMPLETE=%d PARTIAL=%d UNKNOWN=%d total_GetPresetData_native_ms=%s average_GetPresetData_ms=%s max_GetPresetData_ms=%s metadata_normalization_ms=%s cache_build_elapsed_ms=%s lifetime=SINGLE_RUN',cs.distinct_references,cs.calls,cs.cache_hits,cs.COMPLETE,cs.PARTIAL,cs.UNKNOWN,text(cs.timing_valid and cs.native_ms or 'UNVERIFIED'),text(cs.timing_valid and (cs.calls>0 and cs.native_ms/cs.calls or 0) or 'UNVERIFIED'),text(cs.timing_valid and cs.max_ms or 'UNVERIFIED'),text(cs.timing_valid and cs.normalization_ms or 'UNVERIFIED'),text(cacheElapsed))
 log('METADATA_REVERSE Recipe_rows_inspected=%d Stored_Groups=%d group_member_expansion=%d member_feature_lanes_resolved=%d rows_skipped_empty=%d static_terminators=%d moving_contributing_rows=%d unsafe_rows=%d final_refs=%d reverse_elapsed_ms=%s',#metadataRows,stats.groups,stats.expansions,metadataResult.lanesResolved or 0,metadataResult.rowsSkipped or 0,metadataResult.staticRows or 0,metadataResult.movingRows or 0,#metadataResult.unsafe,count(metadataFinal),text(reverseElapsed))
 log('TOTAL_METADATA_PATH_ELAPSED_MS value=%s excludes_Rev3_audit=true',text(totalMetadataElapsed))
end
metadataMetrics()
identityOutput('METADATA_REVERSE_FINAL',metadataFinal)
local metadataDetails=0
local function metadataDetail(fmt,...)
 if metadataDetails>=80 then detailsSuppressed=detailsSuppressed+1; return end
 metadataDetails=metadataDetails+1; log(fmt,...)
end
local printedMetadata={}
for _,row in ipairs(metadataRows) do
 local key=row.ref and metadataCache.identity(row.ref)
 if not printedMetadata[key or row.refId or row] then
  printedMetadata[key or row.refId or row]=true
  metadataDetail('REFERENCE_METADATA_NORMALIZED reference=%s identity=%s completeness=%s motion=%s features=%s layers=%s evidence=%s raw_shape=%s Attribute_chain=%s layer_evidence=%s',desc(row.ref),text(key),text(row.metadata.completeness),text(row.metadata.motion),joined(row.features),joined(row.layers),text(row.evidence),text(row.metadata.raw_shape),text(table.concat(row.metadata.attributeEvidence or {},';')),text(table.concat(row.metadata.layerEvidence or {},';')))
 end
end
for _,entry in pairs(metadataResult.refs) do
 metadataDetail('METADATA_ACTIVE reference=%s surviving_member_count=%d member_sample=%s',desc(entry.ref),count(entry.members),sample(entry.members))
 for row in pairs(entry.sources) do metadataDetail('METADATA_SOURCE reference=%s Cue=%s Part=%s Recipe=%s Group=%s features=%s layers=%s surviving_member_count=%d member_sample=%s',desc(row.ref),desc(row.cue),desc(row.part),desc(row.recipe),desc(row.group),joined(row.features),joined(row.layers),count(row.movingSurvivors),sample(row.movingSurvivors)) end
end
phase='ORACLE'
log('ORACLE_START native_finalized=true metadata_finalized=true')
local oracleLogs=0
oracleLogSink=function(line)
 oracleLogs=oracleLogs+1
 if oracleLogs<=40 then nativePrintf('%s','[CueRecipeReverseAB] ORACLE_TRACE '..line) end
end
local oracle,missing,extra={},{},{}
local oracleOK,oracleError=pcall(function()
 assert(type(rawData)=='function','Oracle GetPresetData unavailable')
 local state={poolBlink=true,running=true}
 -- Replay the same existing oracle used by Structural A/B, including its
 -- current-Cue merge and Recipe recovery. No native coroutines or waits.
 local completed=false
 for tick=0,131072 do
  refreshCueEffects(state,true)
  if state.effectError then error(state.effectError) end
  if not state.recipeScanPending and not state.effectScanPending and not state.effectScanner then completed=true; break end
 end
 assert(completed,'Oracle advance limit exceeded')
 for _,entry in pairs(state.activeEffects or {}) do local rid=id(entry.object); assert(rid,'Oracle identity unavailable'); oracle[rid]=entry.object end
end)
oracleLogSink=nil
identityOutput('ORACLE_FINAL',oracle)
if oracleOK then
 for rid,ref in pairs(oracle) do if not final[rid] then missing[rid]=ref end end
 for rid,ref in pairs(final) do if not oracle[rid] then extra[rid]=ref end end
end
local classifications={}
for _,row in ipairs(result.unsafe) do for _,reason in ipairs(row.unsafe) do classifications[reason]=true end end
-- Recipe-only authoring is the supported product contract. A reference with no
-- Recipe source is unsupported/unsafe, never grounds for a production fallback.
local stable=safe(_G.SelectedSequence)==sequence and safe(_G.GetCurrentCue)==cue
if not ok or not oracleOK or not stable or fastCalls~=0 then classifications.UNVERIFIED=true
elseif next(missing)==nil and next(extra)==nil then classifications.RECIPE_REVERSE_EXACT_MATCH=true
else
 if next(missing) then classifications.RECIPE_REVERSE_MISSING_REFERENCE=true end
 if next(extra) then classifications.RECIPE_REVERSE_EXTRA_REFERENCE=true end
 for rid in pairs(missing) do
  local found=false; for _,row in ipairs(rows) do if row.refId==rid then found=true end end
  if not found then classifications.FAST_PATH_UNSAFE_NON_RECIPE_DATA=true end
 end
end
for tag,set in pairs({MISSING=missing,EXTRA=extra}) do for rid,ref in pairs(set) do
 detail('DIFF_%s ref=%s',tag,desc(ref))
 local found=false
 for _,row in ipairs(rows) do if row.refId==rid then
  found=true; trace(row,'DIFF_SOURCE')
  local buckets={}
  for _,loss in ipairs(row.superseded or {}) do
   buckets[loss.newer]=buckets[loss.newer] or {}; local lane=buckets[loss.newer][loss.lane] or {}; buckets[loss.newer][loss.lane]=lane; lane[loss.member]=true
  end
  for newer,lanes in pairs(buckets) do for lane,members in pairs(lanes) do detail('DIFF_LANE feature_layer=%s member_count=%d member_sample=%s older_Recipe=%s newer_Recipe=%s newer_Group=%s',lane,count(members),sample(members),desc(row.recipe),desc(newer.recipe),desc(newer.group)) end end
 end end
 if not found then detail('DIFF_SOURCE ref=%s Group/member/feature/layer=UNVERIFIED no_Recipe_source=true',desc(ref)) end
end end
identityOutput('DIFF_MISSING',missing); identityOutput('DIFF_EXTRA',extra)
log('DIFF missing=%s extra=%s oracle_valid=%s details_suppressed=%d oracle_trace_suppressed=%d',oracleOK and count(missing) or 'UNVERIFIED',oracleOK and count(extra) or 'UNVERIFIED',text(oracleOK),detailsSuppressed,math.max(0,oracleLogs-40))
metrics()
local metadataMissing,metadataExtra,metadataClassifications={},{},{}
if not ok or fastCalls~=0 or not metadataOK or not oracleOK or not stable then metadataClassifications.UNVERIFIED=true
else
 for rid,ref in pairs(oracle) do if not metadataFinal[rid] then metadataMissing[rid]=ref end end
 for rid,ref in pairs(metadataFinal) do if not oracle[rid] then metadataExtra[rid]=ref end end
 if not next(metadataMissing) and not next(metadataExtra) then metadataClassifications.METADATA_REVERSE_EXACT_MATCH=true end
 if next(metadataMissing) then metadataClassifications.METADATA_REVERSE_MISSING_REFERENCE=true end
 if next(metadataExtra) then metadataClassifications.METADATA_REVERSE_EXTRA_REFERENCE=true end
end
if #metadataResult.unsafe>0 or cs.PARTIAL>0 or cs.UNKNOWN>0 then metadataClassifications.METADATA_REFERENCE_UNSAFE=true end
identityOutput('METADATA_DIFF_MISSING',metadataMissing); identityOutput('METADATA_DIFF_EXTRA',metadataExtra)
for _,row in ipairs(metadataRows) do
 if metadataMissing[row.refId] or metadataExtra[row.refId] then
  detail('DIFF_METADATA_SOURCE reference=%s Recipe=%s Group=%s member_count=%d member_sample=%s features=%s layers=%s completeness=%s evidence=%s',desc(row.ref),desc(row.recipe),desc(row.group),count(row.members),sample(row.members),joined(row.features),joined(row.layers),text(row.metadata.completeness),text(row.evidence))
  local losses={}
  for _,loss in ipairs(row.superseded or {}) do
   losses[loss.newer]=losses[loss.newer] or {}; local members=losses[loss.newer][loss.lane] or {}; losses[loss.newer][loss.lane]=members; members[loss.member]=true
  end
  for newer,lanes in pairs(losses) do for lane,members in pairs(lanes) do detail('DIFF_METADATA_LANE older_Recipe=%s newer_Recipe=%s newer_Group=%s feature_layer=%s member_count=%d member_sample=%s unsafe=%s',desc(row.recipe),desc(newer.recipe),desc(newer.group),lane,count(members),sample(members),table.concat(newer.unsafe,',')) end end
 end
end
metadataMetrics()
log('METADATA_DIFF missing=%s extra=%s classification=%s',oracleOK and count(metadataMissing) or 'UNVERIFIED',oracleOK and count(metadataExtra) or 'UNVERIFIED',joined(metadataClassifications))
log('METADATA_RESULT classification=%s native_refs=%d metadata_refs=%d oracle_refs=%d unsafe_rows=%d completeness_COMPLETE=%d completeness_PARTIAL=%d completeness_UNKNOWN=%d safe_integration=false',joined(metadataClassifications),count(final),count(metadataFinal),count(oracle),#metadataResult.unsafe,cs.COMPLETE,cs.PARTIAL,cs.UNKNOWN)
log('RESULT classification=%s Recipe_refs=%d oracle_refs=%d missing=%s extra=%s unsafe_rows=%d oracle_calls=%d fast_GetPresetData_calls=%d oracle_error=%s identity_set_only=true safe_integration=false',joined(classifications)..';'..joined(metadataClassifications),count(final),count(oracle),oracleOK and count(missing) or 'UNVERIFIED',oracleOK and count(extra) or 'UNVERIFIED',#result.unsafe,oracleCalls,fastCalls,text(oracleError))
log('END production_untouched=true markers=false waits=false fallback_during_fast_path=false')
return {metadata=metadataResult,metadataFinal=metadataFinal,metadataRows=metadataRows,metadataStats=cs,metadataMissing=metadataMissing,metadataExtra=metadataExtra,metadataClassifications=metadataClassifications,metadataOK=metadataOK,fast=result,final=final,oracle=oracle,missing=missing,extra=extra,classifications=classifications,stats=stats,fastCalls=fastCalls,oracleCalls=oracleCalls,fastOK=ok,oracleOK=oracleOK,rows=rows,patterns=patternOrder,detailsSuppressed=detailsSuppressed,unresolvedGroups=unresolvedCount}
end
