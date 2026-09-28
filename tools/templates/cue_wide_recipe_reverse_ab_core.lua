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
log('START revision=7_RAW_REL_ZERO_SEMANTICS_PROOF target=2.5.0.3 sequence=%s cue=%s order=NATIVE_ONLY_THEN_REV4_BASELINE_THEN_REV5_BRIDGE_THEN_REV6_SEMANTICS_THEN_REV7_RAW_REL_PROOF_THEN_REV7_REVERSE_THEN_ORACLE production_flag=false no_waits=true no_markers=true',desc(sequence),desc(cue))
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
local function identityOutput(tag,set,limit)
 limit=limit or 128
 log('%s count=%d',tag,count(set))
 local refs={}; for _,ref in pairs(set) do refs[#refs+1]=ref end
 table.sort(refs,function(a,b) return desc(a)<desc(b) end)
 for i=1,math.min(limit,#refs) do log('%s_REF reference=%s',tag,desc(refs[i])) end
 if #refs>limit then log('%s_DETAIL_LIMIT suppressed=%d exact_set_preserved_in_comparison=true',tag,#refs-limit) end
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
local recipeTargets,dependencyTargets={},{}
local metadataCache
metadataCache=newReferenceMetadataCache({safe=safe,class=class,isObject=isObjectReference,
 handleToInt=_G.HandleToInt,handleToStr=_G.HandleToStr,attributeByUIChannel=_G.GetAttributeByUIChannel,
 now=now,log=log,desc=path,validateTarget=function(target,key)
  assert(phase=='METADATA' or phase=='BRIDGE','METADATA_READ_PHASE_VIOLATION')
  local c=class(target):lower()
  assert(c~='cue' and c~='part' and c~='cuepart' and c~='sequence','METADATA_FORBIDDEN_TARGET_'..c)
  assert(key==metadataCache.identity(target) and (recipeTargets[key] or (phase=='BRIDGE' and dependencyTargets[key])),'METADATA_TARGET_NOT_REGISTERED_REFERENCE')
 end,read=function(target,phasersOnly,byFixtures)
  assert(phase=='METADATA' or phase=='BRIDGE','METADATA_READ_PHASE_VIOLATION')
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
local cs={}; for k,v in pairs(metadataCache.stats) do cs[k]=v end
log('BASELINE_METADATA_FINALIZED revision=4_REFERENCE_METADATA_CACHE refs=%d COMPLETE=%d PARTIAL=%d UNKNOWN=%d',count(metadataFinal),cs.COMPLETE,cs.PARTIAL,cs.UNKNOWN)
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
phase='BRIDGE'
local bridgeStart=now()
local bridge=newReferenceMetadataBridge({safe=safe,class=class,isObject=isObjectReference,identity=metadataCache.identity,
 metadata=auditor.metadata,desc=path,attributeByUIChannel=_G.GetAttributeByUIChannel})
local bridgeStats={direct=0,dependencies=0,dependencyHits=0,ordinary=0,phasers=0,complete=0,partial=0,unknown=0,static=0,moving=0,
 ordinaryMs=0,dependencyMs=0,phaserMs=0,normalizationMs=0}
local bridgedByIdentity,bridgeRows,bridgeResult,bridgeFinal={},{},{},{}
local bridgeOK,bridgeError=pcall(function()
 local refs={}
 for _,row in ipairs(rows) do if row.ref then local key=metadataCache.identity(row.ref); if key and not refs[key] then refs[key]=row end end end
 bridgeStats.direct=count(refs)
 local dependencies={}
 local function ordinaryFor(ref,isDependency)
  local key=metadataCache.identity(ref); if not key then return {features={},layers={},lanes={},motion='UNSAFE',completeness='UNKNOWN',evidence={STABLE_IDENTITY_UNAVAILABLE=true},source='ORDINARY_GETPRESETDATA'} end
  if isDependency then
   local valid=metadataCache.registerDependency(ref); if valid then dependencyTargets[valid]=true; dependencies[valid]=true end
  end
  local existed=metadataCache.timings[key]~=nil
  metadataCache.get(ref)
  local timing=metadataCache.timings[key]
  if timing and not existed then
   local elapsed=timing.read_ms+timing.normalization_ms
   if isDependency then bridgeStats.dependencyMs=bridgeStats.dependencyMs+elapsed else bridgeStats.ordinaryMs=bridgeStats.ordinaryMs+elapsed end
  elseif timing and not isDependency then bridgeStats.ordinaryMs=bridgeStats.ordinaryMs+timing.read_ms+timing.normalization_ms end
  local n=now(); local info=bridge.ordinary(metadataCache.raw[key]); local nm=ms(n,now())
  if type(nm)=='number' then bridgeStats.normalizationMs=bridgeStats.normalizationMs+nm end
  if isDependency then log('LINKED_PRESET_EVIDENCE reference=%s completeness=%s features=%s layers=%s reasons=%s',desc(ref),info.completeness,joined(info.features),joined(info.layers),joined(info.evidence)) end
  return info
 end
 local dependencyCache={}
 local function dependency(ref)
  local key=metadataCache.identity(ref)
  if not key then return ordinaryFor(ref,true) end
  if not dependencyCache[key] then dependencyCache[key]=ordinaryFor(ref,true) else bridgeStats.dependencyHits=bridgeStats.dependencyHits+1 end
  return dependencyCache[key]
 end
 for key,row in pairs(refs) do
  local direct=metadataCache.raw[key]
  local start=now(); local dependencyBefore=bridgeStats.dependencyMs; local normalizationBefore=bridgeStats.normalizationMs; local info
  if type(direct)=='table' and next(direct)~=nil and (row.structural or {}).sourceCount==0 then
   info=ordinaryFor(row.ref,false); bridgeStats.ordinary=bridgeStats.ordinary+1
  elseif row.structural and row.structural.recipeCount>0 then
   info=bridge.phaser(row.ref,row.structural,dependency); bridgeStats.phasers=bridgeStats.phasers+1
   local elapsed=ms(start,now()); if type(elapsed)=='number' then bridgeStats.phaserMs=bridgeStats.phaserMs+math.max(0,elapsed-(bridgeStats.dependencyMs-dependencyBefore)-(bridgeStats.normalizationMs-normalizationBefore)) end
  else
   info=ordinaryFor(row.ref,false); bridgeStats.ordinary=bridgeStats.ordinary+1
  end
  bridgedByIdentity[key]=info
  bridgeStats[info.completeness:lower()]=bridgeStats[info.completeness:lower()]+1
  if info.motion=='STATIC' then bridgeStats.static=bridgeStats.static+1 end
  if info.motion=='MOVING' then bridgeStats.moving=bridgeStats.moving+1 end
  local reasons=joined(info.evidence)
  log('BRIDGED_METADATA_REFERENCE reference=%s source=%s completeness=%s motion=%s motion_proof=%s phaser_structure=%s features=%s layers=%s channels=%d structural_steps=%d value_sources=%d shapes=%d dependencies=%d reasons=%s observations=%s',desc(row.ref),text(info.source),info.completeness,info.motion,text(info.motionProof),text(info.phaserStructure),joined(info.features),joined(info.layers),info.channels or 0,info.structuralSteps or 0,info.valueSources or 0,info.shapes or 0,info.dependencies or 0,text(reasons),text(joined(info.observations)))
  for i=1,math.min(8,#info.samples) do log('PHASER_BRIDGE_SOURCE_AUDIT reference=%s source_index=%d evidence=%s',desc(row.ref),i,auditText(info.samples[i])) end
  local patternList={}; for pattern,n in pairs(info.patterns) do patternList[#patternList+1]={pattern=pattern,n=n} end
  table.sort(patternList,function(a,b) return a.n>b.n end)
  for i=1,math.min(3,#patternList) do log('ORDINARY_REFERENCE_PATTERN reference=%s rank=%d occurrences=%d fields=%s example=%s',desc(row.ref),i,patternList[i].n,auditText(patternList[i].pattern),auditText(info.examples[patternList[i].pattern])) end
 end
 bridgeStats.dependencies=count(dependencies)
 for _,row in ipairs(rows) do
  local key=row.ref and metadataCache.identity(row.ref); local info=key and bridgedByIdentity[key]
  if not info then info={features={},layers={},lanes={},motion='UNSAFE',completeness='UNKNOWN',evidence={REFERENCE_UNAVAILABLE=true}} end
  local copy={recipe=row.recipe,part=row.part,cue=row.cue,group=row.group,ref=row.ref,refId=row.refId,members=row.members,
   features=info.features,layers=info.layers,lanes=info.lanes,moving=info.motion=='MOVING' or info.motion=='GENERATOR',unsafe={},evidence=joined(info.evidence)}
  if not copy.members then copy.unsafe[#copy.unsafe+1]='FAST_PATH_UNSAFE_SELECTION' end
  if info.completeness~='COMPLETE' then copy.unsafe[#copy.unsafe+1]='BRIDGED_REFERENCE_UNSAFE'
   if not info.featureScopeKnown or not next(info.features or {}) then copy.features=nil end
   if not info.layerScopeKnown or not next(info.layers or {}) then copy.layers=nil end
  end
  bridgeRows[#bridgeRows+1]=copy
 end
end)
local bridgeCacheElapsed=ms(bridgeStart,now())
local bridgedReverseStart=now()
if bridgeOK then bridgeOK,bridgeError=pcall(function() bridgeResult=recipeReverseResolve(bridgeRows) end) end
local bridgedReverseElapsed=ms(bridgedReverseStart,now())
bridgeResult=bridgeResult or {refs={},unsafe={}}
for rid,entry in pairs(bridgeResult.refs) do bridgeFinal[rid]=entry.ref end
local totalBridgedElapsed=(type(cacheElapsed)=='number' and type(bridgeCacheElapsed)=='number' and type(bridgedReverseElapsed)=='number') and (cacheElapsed+bridgeCacheElapsed+bridgedReverseElapsed) or 'UNVERIFIED'
log('BRIDGED_REVERSE_FINALIZED valid=%s refs=%d error=%s',text(bridgeOK),count(bridgeFinal),text(bridgeError))
log('ORDINARY_REFERENCE_SEMANTICS_SUMMARY references=%d static_proven=%d ordinary_metadata_cache_ms=%s',bridgeStats.ordinary,bridgeStats.static,text(bridgeStats.ordinaryMs))
log('PHASER_BRIDGE_SUMMARY references=%d moving_proven=%d native_bridge_ms=%s',bridgeStats.phasers,bridgeStats.moving,text(bridgeStats.phaserMs))
log('LINKED_PRESET_CACHE_SUMMARY recipe_reference_reads=%d dependency_reference_reads=%d linked_dependency_references=%d unique_reference_reads=%d cache_hits=%d dependency_normalized_cache_hits=%d native_GetPresetData_ms=%s dependency_cache_ms=%s',cs.calls,metadataCache.stats.calls-cs.calls,bridgeStats.dependencies,metadataCache.stats.calls,metadataCache.stats.cache_hits+bridgeStats.dependencyHits,bridgeStats.dependencyHits,text(metadataCache.stats.native_ms),text(bridgeStats.dependencyMs))
log('BRIDGED_METADATA_SUMMARY direct_Recipe_references=%d linked_dependency_references=%d COMPLETE=%d PARTIAL=%d UNKNOWN=%d normalization_ms=%s cache_build_elapsed_ms=%s',bridgeStats.direct,bridgeStats.dependencies,bridgeStats.complete,bridgeStats.partial,bridgeStats.unknown,text(bridgeStats.normalizationMs),text(bridgeCacheElapsed))
log('BRIDGED_REVERSE Recipe_rows_inspected=%d member_feature_lanes_resolved=%d rows_skipped_empty=%d static_terminators=%d moving_contributing_rows=%d unsafe_rows=%d reverse_elapsed_ms=%s',#bridgeRows,bridgeResult.lanesResolved or 0,bridgeResult.rowsSkipped or 0,bridgeResult.staticRows or 0,bridgeResult.movingRows or 0,#bridgeResult.unsafe,text(bridgedReverseElapsed))
log('TOTAL_BRIDGED_PATH_MS value=%s',text(totalBridgedElapsed))
identityOutput('BRIDGED_REVERSE_FINAL',bridgeFinal)
for _,entry in pairs(bridgeResult.refs) do log('BRIDGED_ACTIVE reference=%s surviving_member_count=%d',desc(entry.ref),count(entry.members)) end
local bridgeRejectedShown=0
for _,older in ipairs(bridgeResult.rejected or {}) do
 local buckets={}
 for _,loss in ipairs(older.superseded or {}) do
  local newer=loss.newer; buckets[newer]=buckets[newer] or {}
  local lane=buckets[newer][loss.lane] or {members={}}; buckets[newer][loss.lane]=lane
  lane.members[loss.member]=true
 end
 for newer,lanes in pairs(buckets) do for lane,bucket in pairs(lanes) do
  if bridgeRejectedShown<48 then
   bridgeRejectedShown=bridgeRejectedShown+1
   log('BRIDGED_REJECTED_OVERLAP older_ref=%s older_Recipe=%s older_Group=%s first_newer_Recipe=%s newer_Group=%s feature_layer=%s overlapping_member_count=%d sample=%s unsafe=%s',desc(older.ref),desc(older.recipe),desc(older.group),desc(newer.recipe),desc(newer.group),lane,count(bucket.members),sample(bucket.members),table.concat(newer.unsafe or {},','))
  end
 end end
end
log('BRIDGED_REJECTED_SUMMARY moving_rows_with_supersession=%d shown_overlap_groups=%d',#(bridgeResult.rejected or {}),bridgeRejectedShown)
log('REV5_BRIDGE_BASELINE finalized=true refs=%d COMPLETE=%d PARTIAL=%d UNKNOWN=%d',count(bridgeFinal),bridgeStats.complete,bridgeStats.partial,bridgeStats.unknown)
phase='SEMANTICS'
local semanticsStart=now()
local proof=newReferenceFieldSemantics({identity=metadataCache.identity,safe=safe})
local rev6Bridge=newReferenceMetadataBridge({safe=safe,class=class,isObject=isObjectReference,identity=metadataCache.identity,
 metadata=auditor.metadata,desc=path,attributeByUIChannel=_G.GetAttributeByUIChannel,fieldSemantics=proof})
local rev6ByIdentity,rev6Rows,rev6Result,rev6Final={},{},{},{}
local rev6Stats={ordinary=0,linked=0,phaser=0,complete=0,partial=0,unknown=0,static=0,ordinaryStatic=0,linkedStatic=0,moving=0}
local rev6OK,rev6Error=pcall(function()
 local refs={}
 for _,row in ipairs(rows) do if row.ref then local key=metadataCache.identity(row.ref); if key and not refs[key] then refs[key]=row end end end
 local dependencyCache={}
 local function ordinary(ref,linked)
  local key=metadataCache.identity(ref)
  if not key then return {features={},layers={},lanes={},motion='UNSAFE',completeness='UNKNOWN',evidence={STABLE_IDENTITY_UNAVAILABLE=true}} end
  local raw=metadataCache.raw[key]
  if raw==nil then return {features={},layers={},lanes={},motion='UNSAFE',completeness='UNKNOWN',evidence={REFERENCE_CACHE_MISS=true}} end
  proof.observe(ref,raw)
  local m=rev6Bridge.ordinary(raw)
  if linked then
   rev6Stats.linked=rev6Stats.linked+1
   if m.completeness=='COMPLETE' and m.motion=='STATIC' then rev6Stats.linkedStatic=rev6Stats.linkedStatic+1 end
  else
   rev6Stats.ordinary=rev6Stats.ordinary+1
   if m.completeness=='COMPLETE' and m.motion=='STATIC' then rev6Stats.ordinaryStatic=rev6Stats.ordinaryStatic+1 end
  end
  return m
 end
 local function dependency(ref)
  local key=metadataCache.identity(ref)
  if not key then return ordinary(ref,true) end
  if not dependencyCache[key] then dependencyCache[key]=ordinary(ref,true) end
  return dependencyCache[key]
 end
 for key,row in pairs(refs) do
  local raw=metadataCache.raw[key]; local info
  if type(raw)=='table' and next(raw)~=nil and (row.structural or {}).sourceCount==0 then info=ordinary(row.ref,false)
  elseif row.structural and row.structural.recipeCount>0 then
   info=rev6Bridge.phaser(row.ref,row.structural,dependency); rev6Stats.phaser=rev6Stats.phaser+1
  else info=ordinary(row.ref,false) end
  rev6ByIdentity[key]=info
  rev6Stats[info.completeness:lower()]=rev6Stats[info.completeness:lower()]+1
  if info.motion=='STATIC' then rev6Stats.static=rev6Stats.static+1 end
  if info.motion=='MOVING' then rev6Stats.moving=rev6Stats.moving+1 end
 end
 for _,row in ipairs(rows) do
  local key=row.ref and metadataCache.identity(row.ref)
  local info=key and rev6ByIdentity[key] or {features={},layers={},lanes={},motion='UNSAFE',completeness='UNKNOWN',evidence={REFERENCE_UNAVAILABLE=true}}
  local copy={recipe=row.recipe,part=row.part,cue=row.cue,group=row.group,ref=row.ref,refId=row.refId,members=row.members,
   features=info.features,layers=info.layers,lanes=info.lanes,moving=info.motion=='MOVING' or info.motion=='GENERATOR',unsafe={},evidence=joined(info.evidence)}
  if not copy.members then copy.unsafe[#copy.unsafe+1]='FAST_PATH_UNSAFE_SELECTION' end
  if info.completeness~='COMPLETE' then
   copy.unsafe[#copy.unsafe+1]='REV6_REFERENCE_UNSAFE'
   if not info.featureScopeKnown or not next(info.features or {}) then copy.features=nil end
   if not info.layerScopeKnown or not next(info.layers or {}) then copy.layers=nil end
  end
  rev6Rows[#rev6Rows+1]=copy
 end
end)
local semanticsElapsed=ms(semanticsStart,now())
local rev6ReverseStart=now()
if rev6OK then rev6OK,rev6Error=pcall(function() rev6Result=recipeReverseResolve(rev6Rows) end) end
local rev6ReverseElapsed=ms(rev6ReverseStart,now())
rev6Result=rev6Result or {refs={},unsafe={}}
for rid,entry in pairs(rev6Result.refs) do rev6Final[rid]=entry.ref end
local rev6Audit=proof.summary()
local fieldCount,patternCount=0,0
for _ in pairs(rev6Audit.fields) do fieldCount=fieldCount+1 end
for _ in pairs(rev6Audit.patterns) do patternCount=patternCount+1 end
log('REFERENCE_FIELD_SEMANTICS_SUMMARY fields=%d record_patterns=%d ordinary_references=%d linked_references=%d',fieldCount,patternCount,rev6Stats.ordinary,rev6Stats.linked)
for field,d in pairs(rev6Audit.fields) do
 local c=rev6Audit.classifications[field]
 local samples={}; for value,n in pairs(d.samples) do samples[#samples+1]=value..':'..n end; table.sort(samples)
 log('FIELD_SEMANTICS field=%s classification=%s channels=%d presets=%d varies_channels=%s varies_presets=%s types=%s values=%s evidence=%s',field,c[1],d.channels,count(d.refs),text(d.variesWithinPreset),text(d.variesAcrossPresets),joined(d.types),text(table.concat(samples,',')),text(c[2]))
end
local rawStateList={}; for state,n in pairs(rev6Audit.rawStates) do rawStateList[#rawStateList+1]=state..':'..n end; table.sort(rawStateList)
log('RAW_LAYER_SEMANTICS_SUMMARY states=%s raw_zero_encoding_unproven=true',table.concat(rawStateList,','))
log('ORDINARY_STATIC_PROOF_SUMMARY ordinary=%d static_proven=%d',rev6Stats.ordinary,rev6Stats.ordinaryStatic)
log('LINKED_PRESET_COMPLETENESS_SUMMARY linked_normalized=%d linked_static_complete=%d unique_native_reference_reads=%d extra_GetPresetData_calls=0',rev6Stats.linked,rev6Stats.linkedStatic,metadataCache.stats.calls)
log('PHASER_MOTION_PROOF_SUMMARY phaser_references=%d motion_proven=%d',rev6Stats.phaser,rev6Stats.moving)
log('REV6_BRIDGED_METADATA_SUMMARY COMPLETE=%d PARTIAL=%d UNKNOWN=%d semantics_ms=%s cache_reused=true',rev6Stats.complete,rev6Stats.partial,rev6Stats.unknown,text(semanticsElapsed))
log('REV6_BRIDGED_REVERSE_FINALIZED valid=%s refs=%d error=%s rows=%d lanes=%d static_terminators=%d moving_rows=%d unsafe_rows=%d reverse_ms=%s',text(rev6OK),count(rev6Final),text(rev6Error),#rev6Rows,rev6Result.lanesResolved or 0,rev6Result.staticRows or 0,rev6Result.movingRows or 0,#rev6Result.unsafe,text(rev6ReverseElapsed))
identityOutput('REV6_BRIDGED_REVERSE_FINAL',rev6Final)
for _,entry in pairs(rev6Result.refs) do log('REV6_ACTIVE reference=%s surviving_member_count=%d',desc(entry.ref),count(entry.members)) end
rev6Result.rev7=(function()
phase='RAW_REL_AUDIT'
local rev7PathStart=now()
local rawRelAuditStart=now()
local rawRelAudit=newRawRelZeroAudit({safe=safe,isObject=isObjectReference,class=class,identity=metadataCache.identity,
 metadata=auditor.metadata,raw=metadataCache.raw,ordinary=rev6Bridge.ordinary,joined=joined})
local seenSource={}
for _,row in ipairs(rows) do for _,a in ipairs((row.structural or {}).audits or {}) do
 local h=a.node; local key=h and metadataCache.identity(h)
 if key and not seenSource[key] and class(h):lower()=='phaserrecipevaluesource' then
  seenSource[key]=true
  local step=safe(function() return h:Parent():Index() end)
  rawRelAudit.observe(h,step,a.presetHandle)
 end
end end
local rawRelAuditElapsed=ms(rawRelAuditStart,now())
log('RAW_REL_ZERO_PATTERN_SUMMARY patterns=%d observations=%d shown=%d omitted=%d zero_encoding_proven=false',#rawRelAudit.patterns,count(seenSource),math.min(80,#rawRelAudit.patterns),math.max(0,#rawRelAudit.patterns-80))
for i,p in ipairs(rawRelAudit.patterns) do if i<=80 then
 log('RAW_REL_ZERO_PATTERN occurrences=%d ValueSource=%s Step=%s Attribute=%s FeatureGroup=%s RawValueAbs_enumerated=%s RawValueAbs_type=%s RawValueAbs=%s RawValueRel_enumerated=%s raw_type=%s raw_value=%s value_absolute=%s value_relative=%s layer_property=%s linked_preset=%s linked_layers=%s active_value_mask=%s linked_effective=%s linked_complete=%s Shape=%s classification=%s evidence=%s',
  p.count,text(p.identity),text(p.step),text(p.attribute),text(p.featureGroup),text(p.absEnumerated),p.absType,p.absValue,text(p.rawEnumerated),p.rawType,p.rawValue,text(p.absolute),text(p.relative),text(p.layer),text(p.linked),text(p.linkedLayers),text(p.mask),text(p.effective),p.linkedComplete,text(p.shape),p.classification,p.evidence)
end end
log('RAW_REL_ZERO_PROOF_SUMMARY REL_AUTHORED_PROVEN=%d REL_NOT_AUTHORED_PROVEN=%d REL_AMBIGUOUS=%d zero_promotions=0 additional_GetPresetData_calls=0 raw_rel_audit_ms=%s',rawRelAudit.states.REL_AUTHORED_PROVEN,rawRelAudit.states.REL_NOT_AUTHORED_PROVEN,rawRelAudit.states.REL_AMBIGUOUS,text(rawRelAuditElapsed))
-- Rev11: the proven Rev8.1 ValueRelative triple rule classifies REL zero as
-- authored or not-authored inside the Rev6 bridge; ABS zero stays unpromoted.
local rev7MetadataStart=now()
local rev7Rows={}
for _,row in ipairs(rows) do
 local key=row.ref and metadataCache.identity(row.ref)
 local info=key and rev6ByIdentity[key] or {features={},layers={},lanes={},motion='UNSAFE',completeness='UNKNOWN',evidence={REFERENCE_UNAVAILABLE=true}}
 local copy={recipe=row.recipe,part=row.part,cue=row.cue,group=row.group,ref=row.ref,refId=row.refId,members=row.members,
  features=info.features,layers=info.layers,lanes=info.lanes,moving=info.motion=='MOVING' or info.motion=='GENERATOR',unsafe={},evidence=joined(info.evidence)}
 if not copy.members then copy.unsafe[#copy.unsafe+1]='FAST_PATH_UNSAFE_SELECTION' end
 if info.completeness~='COMPLETE' then
  copy.unsafe[#copy.unsafe+1]='REV7_REFERENCE_UNSAFE'
  if not info.featureScopeKnown or not next(info.features or {}) then copy.features=nil end
  if not info.layerScopeKnown or not next(info.layers or {}) then copy.layers=nil end
 end
 rev7Rows[#rev7Rows+1]=copy
end
local rev7MetadataElapsed=ms(rev7MetadataStart,now())
local rev7ReverseStart=now()
local rev7OK,rev7Result=pcall(recipeReverseResolve,rev7Rows)
local rev7ReverseElapsed=ms(rev7ReverseStart,now())
local rev7Error
if not rev7OK then rev7Error=rev7Result; rev7Result=nil end
rev7Result=rev7Result or {refs={},unsafe={}}
local rev7Final={}; for rid,entry in pairs(rev7Result.refs) do rev7Final[rid]=entry.ref end
log('REV7_PHASER_MOTION_SUMMARY phaser_references=%d motion_proven=%d zero_promotions=0',rev6Stats.phaser,rev6Stats.moving)
log('REV7_BRIDGED_METADATA_SUMMARY COMPLETE=%d PARTIAL=%d UNKNOWN=%d metadata_ms=%s cache_reused=true additional_GetPresetData_calls=0',rev6Stats.complete,rev6Stats.partial,rev6Stats.unknown,text(rev7MetadataElapsed))
log('REV7_BRIDGED_REVERSE_FINALIZED valid=%s refs=%d error=%s rows=%d lanes=%d static_terminators=%d moving_rows=%d unsafe_rows=%d final_refs=%d reverse_ms=%s total_rev7_path_ms=%s',text(rev7OK),count(rev7Final),text(rev7Error),#rev7Rows,rev7Result.lanesResolved or 0,rev7Result.staticRows or 0,rev7Result.movingRows or 0,#rev7Result.unsafe,count(rev7Final),text(rev7ReverseElapsed),text(ms(rev7PathStart,now())))
identityOutput('REV7_BRIDGED_REVERSE_FINAL',rev7Final)
return {audit=rawRelAudit,rows=rev7Rows,result=rev7Result,final=rev7Final,ok=rev7OK}
end)()
phase='ORACLE'
log('ORACLE_START native_finalized=true metadata_finalized=true rev5_bridge_finalized=true rev6_finalized=true rev7_finalized=true')
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
local bridgedMissing,bridgedExtra,bridgedClassifications={},{},{}
if not bridgeOK or not oracleOK or not stable then bridgedClassifications.UNVERIFIED=true
else
 for rid,ref in pairs(oracle) do if not bridgeFinal[rid] then bridgedMissing[rid]=ref end end
 for rid,ref in pairs(bridgeFinal) do if not oracle[rid] then bridgedExtra[rid]=ref end end
 if not next(bridgedMissing) and not next(bridgedExtra) then bridgedClassifications.BRIDGED_REVERSE_EXACT_MATCH=true end
 if next(bridgedMissing) then bridgedClassifications.BRIDGED_REVERSE_MISSING_REFERENCE=true end
 if next(bridgedExtra) then bridgedClassifications.BRIDGED_REVERSE_EXTRA_REFERENCE=true end
end
if #bridgeResult.unsafe>0 or bridgeStats.partial>0 or bridgeStats.unknown>0 then bridgedClassifications.BRIDGED_REFERENCE_UNSAFE=true end
identityOutput('BRIDGED_DIFF_MISSING',bridgedMissing,16); identityOutput('BRIDGED_DIFF_EXTRA',bridgedExtra,16)
local bridgedDiffShown=0
for _,row in ipairs(bridgeRows) do if (bridgedMissing[row.refId] or bridgedExtra[row.refId]) and bridgedDiffShown<25 then
 bridgedDiffShown=bridgedDiffShown+1
 detail('BRIDGED_DIFF_SOURCE reference=%s Cue=%s Part=%s Recipe=%s Group=%s feature=%s layer=%s members=%d sample=%s reasons=%s',desc(row.ref),desc(row.cue),desc(row.part),desc(row.recipe),desc(row.group),joined(row.features),joined(row.layers),count(row.members),sample(row.members),text(row.evidence))
end end
log('BRIDGED_DIFF missing=%s extra=%s classification=%s',oracleOK and count(bridgedMissing) or 'UNVERIFIED',oracleOK and count(bridgedExtra) or 'UNVERIFIED',joined(bridgedClassifications))
log('BRIDGED_RESULT classification=%s refs=%d oracle_refs=%d unsafe_rows=%d safe_integration=false',joined(bridgedClassifications),count(bridgeFinal),count(oracle),#bridgeResult.unsafe)
local rev6Missing,rev6Extra,rev6Classes={},{},{}
if not rev6OK or not oracleOK or not stable then rev6Classes.UNVERIFIED=true
else
 for rid,ref in pairs(oracle) do if not rev6Final[rid] then rev6Missing[rid]=ref end end
 for rid,ref in pairs(rev6Final) do if not oracle[rid] then rev6Extra[rid]=ref end end
 if not next(rev6Missing) and not next(rev6Extra) then rev6Classes.REV6_BRIDGED_EXACT_MATCH=true end
 if next(rev6Missing) then rev6Classes.REV6_BRIDGED_MISSING_REFERENCE=true end
 if next(rev6Extra) then rev6Classes.REV6_BRIDGED_EXTRA_REFERENCE=true end
end
if #rev6Result.unsafe>0 or rev6Stats.partial>0 or rev6Stats.unknown>0 then rev6Classes.REV6_REFERENCE_UNSAFE=true end
identityOutput('REV6_BRIDGED_DIFF_MISSING',rev6Missing,16)
identityOutput('REV6_BRIDGED_DIFF_EXTRA',rev6Extra,16)
local rev6DiffShown=0
for _,row in ipairs(rev6Rows) do if (rev6Missing[row.refId] or rev6Extra[row.refId]) and rev6DiffShown<25 then
 rev6DiffShown=rev6DiffShown+1
 detail('REV6_BRIDGED_DIFF_SOURCE reference=%s Cue=%s Part=%s Recipe=%s Group=%s feature=%s layer=%s members=%d sample=%s reasons=%s',desc(row.ref),desc(row.cue),desc(row.part),desc(row.recipe),desc(row.group),joined(row.features),joined(row.layers),count(row.members),sample(row.members),text(row.evidence))
end end
log('REV6_BRIDGED_DIFF missing=%s extra=%s classification=%s',oracleOK and count(rev6Missing) or 'UNVERIFIED',oracleOK and count(rev6Extra) or 'UNVERIFIED',joined(rev6Classes))
log('REV6_RESULT classification=%s refs=%d oracle_refs=%d unsafe_rows=%d safe_integration=false',joined(rev6Classes),count(rev6Final),count(oracle),#rev6Result.unsafe)
rev6Result.rev7Diff=(function()
local rev7Missing,rev7Extra,rev7Classes={},{},{}
if not rev6Result.rev7.ok or not oracleOK or not stable then rev7Classes.UNVERIFIED=true
else
 for rid,ref in pairs(oracle) do if not rev6Result.rev7.final[rid] then rev7Missing[rid]=ref end end
 for rid,ref in pairs(rev6Result.rev7.final) do if not oracle[rid] then rev7Extra[rid]=ref end end
 if not next(rev7Missing) and not next(rev7Extra) then rev7Classes.REV7_BRIDGED_EXACT_MATCH=true end
 if next(rev7Missing) then rev7Classes.REV7_BRIDGED_MISSING_REFERENCE=true end
 if next(rev7Extra) then rev7Classes.REV7_BRIDGED_EXTRA_REFERENCE=true end
end
if #rev6Result.rev7.result.unsafe>0 or rev6Stats.partial>0 or rev6Stats.unknown>0 then rev7Classes.REV7_REFERENCE_UNSAFE=true end
identityOutput('REV7_BRIDGED_DIFF_MISSING',rev7Missing,16)
identityOutput('REV7_BRIDGED_DIFF_EXTRA',rev7Extra,16)
log('REV7_BRIDGED_DIFF missing=%s extra=%s classification=%s',oracleOK and count(rev7Missing) or 'UNVERIFIED',oracleOK and count(rev7Extra) or 'UNVERIFIED',joined(rev7Classes))
log('REV7_RESULT classification=%s refs=%d oracle_refs=%d moving_rows=%d static_terminators=%d unsafe_rows=%d final_refs=%d safe_integration=false',joined(rev7Classes),count(rev6Result.rev7.final),count(oracle),rev6Result.rev7.result.movingRows or 0,rev6Result.rev7.result.staticRows or 0,#rev6Result.rev7.result.unsafe,count(rev6Result.rev7.final))
return {missing=rev7Missing,extra=rev7Extra,classes=rev7Classes}
end)()
-- Rev11.1 observation only: attribute Rev7 unsafe rows without touching gates,
-- refs, lanes, motion, or classifications. Isolated so an attribution failure
-- can never change resolver output.
local attributionStart=now()
local attributionOK,attribution=pcall(proof.attributeUnsafe,{rows=rev7Rows,result=rev6Result.rev7.result,final=rev6Result.rev7.final,infoByKey=rev6ByIdentity,identity=metadataCache.identity,desc=desc,joined=joined,sample=sample,count=count,text=text,log=log,detail=detail,now=now,ms=ms,reverseMs=rev7ReverseElapsed,totalMs=ms(rev7PathStart,now())})
if not attributionOK then log('UNSAFE_ATTRIBUTION_ERROR error=%s',text(attribution)); attribution={ok=false} end
-- Rev12: read cached ordinary reference data only. This observer never edits
-- Rev7 rows, classifications, final refs, or resolver gates.
attribution.ordinaryProofOK,attribution.ordinaryProof=pcall(function()
 local ordinaryProofStart=now()
 local seen,proofs,eligible={},{},{}
 local totals={ordinary=0,motionProven=0,motionUnproven=0,memberProven=0,memberUnproven=0,eligibleRows=0}
 for _,row in ipairs(rev6Result.rev7.rows or {}) do
  local key=row.ref and metadataCache.identity(row.ref)
  local info=key and rev6ByIdentity[key]
  if key and info and info.source=='ORDINARY_GETPRESETDATA' and not seen[key] then
   seen[key]=true
   local p=__rev12OrdinaryStaticInspect(metadataCache.raw[key]); proofs[key]=p
   totals.ordinary=totals.ordinary+1
   if p.motionStaticProven then totals.motionProven=totals.motionProven+1 else totals.motionUnproven=totals.motionUnproven+1 end
   if p.memberApplicabilityProven then totals.memberProven=totals.memberProven+1 else totals.memberUnproven=totals.memberUnproven+1 end
   local stepCounts={}; for n,c in pairs(p.steps) do stepCounts[#stepCounts+1]=n..':'..c end; table.sort(stepCounts)
   log('ORDINARY_STATIC_PROOF reference=%s channels=%d active_value_channels=%d non_grid_motion_channels=%d grid_position_channels=%d effective_step_counts=%s layer=%s store_mode=%s selective=%s motion_static_proven=%s member_applicability_proven=%s motion_blocking_reasons=%s member_blocking_reasons=%s',
    text(desc(row.ref)),p.channels,p.activeValue,p.nonGridMotion,p.gridPosition,table.concat(stepCounts,','),joined(p.layers),joined(p.modes),joined(p.selective),
    text(p.motionStaticProven),text(p.memberApplicabilityProven),joined(p.motionReasons),joined(p.memberReasons))
  end
 end
 for _,rec in ipairs(attribution.rows or {}) do
  if rec.category=='FINAL_SURVIVING_UNSAFE' then
   local key=rec.ref and metadataCache.identity(rec.ref)
   local p=key and proofs[key]
   local info=key and rev6ByIdentity[key]
   -- Static motion and member applicability must both be independently proven.
   if p and p.motionStaticProven and p.memberApplicabilityProven and info and info.featureScopeKnown and next(info.features or {})
      and next(info.layers or {}) and rec.row.members then totals.eligibleRows=totals.eligibleRows+1; eligible[rec.row]=true end
  end
 end
 local projected=attribution.finalSurviving or 0
 local alternate
 if totals.eligibleRows>0 then
  local alternateStart=now()
  local alternateRows={}
  for _,row in ipairs(rev6Result.rev7.rows or {}) do
   local copy={recipe=row.recipe,part=row.part,cue=row.cue,group=row.group,ref=row.ref,refId=row.refId,
    members=row.members,features=row.features,layers=row.layers,lanes=row.lanes,moving=row.moving,
    unsafe=row.unsafe,evidence=row.evidence}
   if eligible[row] then
    local info=rev6ByIdentity[metadataCache.identity(row.ref)]
    copy.features=info.features; copy.layers=info.layers; copy.lanes=info.lanes
    copy.moving=false; copy.unsafe={}
   end
   alternateRows[#alternateRows+1]=copy
  end
  local alternateResult=recipeReverseResolve(alternateRows)
  local alternateFinal={}; for rid,entry in pairs(alternateResult.refs) do alternateFinal[rid]=entry.ref end
  local silent=function() end
  local altAttribution=proof.attributeUnsafe({rows=alternateRows,result=alternateResult,final=alternateFinal,
   infoByKey=rev6ByIdentity,identity=metadataCache.identity,desc=desc,joined=joined,sample=sample,count=count,text=text,
   log=silent,detail=silent,now=now,ms=ms})
  projected=altAttribution.finalSurviving
  local missing,extra=0,0
  for rid in pairs(oracle) do if not alternateFinal[rid] then missing=missing+1 end end
  for rid in pairs(alternateFinal) do if not oracle[rid] then extra=extra+1 end end
  log('ORDINARY_STATIC_ALTERNATE refs=%d oracle_refs=%d missing=%s extra=%s unsafe_rows=%d final_surviving_unsafe=%d static_terminators=%d alternate_ms=%s diagnostic_only=true',
   count(alternateFinal),count(oracle),oracleOK and tostring(missing) or 'UNVERIFIED',oracleOK and tostring(extra) or 'UNVERIFIED',
   #alternateResult.unsafe,projected,alternateResult.staticRows or 0,text(ms(alternateStart,now())))
  alternate={final=alternateFinal,result=alternateResult,attribution=altAttribution,missing=missing,extra=extra}
 end
 log('ORDINARY_STATIC_PROOF_SUMMARY ordinary_refs=%d motion_static_proven=%d motion_static_unproven=%d member_applicability_proven=%d member_applicability_unproven=%d final_surviving_rows_before=%d projected_eligible_rows=%d projected_final_surviving_rows_after=%d extra_GetPresetData_calls=0 observer_ms=%s',
  totals.ordinary,totals.motionProven,totals.motionUnproven,totals.memberProven,totals.memberUnproven,
  attribution.finalSurviving or 0,totals.eligibleRows,projected,text(ms(ordinaryProofStart,now())))
 return {totals=totals,proofs=proofs,alternate=alternate}
end)
if not attribution.ordinaryProofOK then log('ORDINARY_STATIC_PROOF_ERROR error=%s',text(attribution.ordinaryProof)); attribution.ordinaryProof={ok=false} end
-- Rev13 diagnostic alternate: cached reference metadata only. The Preset 4.4
-- grid A/B observation covers its tested fixture/attribute class, not Cue 8.
local rev13OK,rev13=pcall(function()
 local start=now()
 local paths={'Preset 4.1','Preset 4.4','Preset 4.23','Preset 6.10','Preset 21.5'}
 local selected=__rev13SelectGlobalTargets(paths,_G.ObjectList,metadataCache.identity,class,attribution.rows)
 local control
 for _,entry in ipairs(selected.entries) do if entry.path=='Preset 4.4' and entry.key then control=metadataCache.raw[entry.key] end end
 local eligible,eligibleCount={},0
 local classified=0
 for _,entry in ipairs(selected.entries) do
  local label,key=entry.path,entry.key
  local raw=key and metadataCache.raw[key]
  local static=key and attribution.ordinaryProof and attribution.ordinaryProof.proofs and attribution.ordinaryProof.proofs[key]
  local scope=true
  for _,row in ipairs(entry.rows) do if not row.members or not next(row.members) then scope=false end end
  -- The reference cache has no cooked fixture/attribute compatibility evidence
  -- for these Cue 8 rows. Do not transfer the A/B result by shape alone.
  local p=__rev13GlobalApplicability(raw,control,static,scope and entry.rows[1] and entry.rows[1].members or nil,false)
  if not key or #entry.rows==0 then p.reasons.TARGET_MISSING_OR_NOT_FINAL_SURVIVING=true end
  local info=key and rev6ByIdentity[key]
  if not info or not info.featureScopeKnown or not next(info.features or {}) or not next(info.layers or {}) then p.reasons.FEATURE_OR_LAYER_SCOPE_UNPROVEN=true end
  local allowed=selected.pass and next(p.reasons)==nil
  if allowed then for _,row in ipairs(entry.rows) do eligible[row]=true; eligibleCount=eligibleCount+1 end end
  if key and #entry.rows>0 then classified=classified+1 end
  log('GLOBAL_APPLICABILITY_CLASS reference=%s rows=%d store_mode=%s selective=%s motion_static_proven=%s grid_mask_shape=%s individual_mask_shape=%s value_mask_shape=%s effective_step_shape=%s layer=%s semantic_shape=%s matches_native_proven_class=%s remaining_reasons=%s',
   label,#entry.rows,joined(p.modes),joined(p.selective),text(static and static.motionStaticProven),joined(p.gridMasks),joined(p.individualMasks),joined(p.valueMasks),joined(p.steps),joined(p.layers),p.semanticShape,text(allowed),joined(p.reasons))
  if selected.pass and label~='Preset 4.4' then
   local deltaOK,delta=pcall(__rev131SignatureDelta,control,raw)
   if deltaOK then
    log('GLOBAL_SIGNATURE_DELTA reference=%s different_components=%s key_identity_only_components=%s semantic_value_components=%s value_difference_components=%s structural_components=%s control_channel_count=%d candidate_channel_count=%d classification=OBSERVATION_ONLY',
     label,table.concat(delta.different,','),table.concat(delta.keyOnly,','),table.concat(delta.semanticValue,','),table.concat(delta.valueDifferences,','),table.concat(delta.structural,','),delta.controlChannels,delta.candidateChannels)
    for _,component in ipairs(delta.components) do
     log('GLOBAL_SIGNATURE_COMPONENT reference=%s component=%s control_type=%s candidate_type=%s control_count=%d candidate_count=%d key_sets_equal=%s value_type_shape_equal=%s semantic_status=%s',
      label,component.component,component.controlType,component.candidateType,component.controlCount,component.candidateCount,
      text(component.keySetsEqual),text(component.valueTypeShapeEqual),component.status)
    end
   else log('GLOBAL_SIGNATURE_DELTA_ERROR reference=%s error=%s',label,text(delta)) end
  end
  if selected.pass then
   local observationOK,observation=pcall(function()
    local normalized=__rev132SemanticNormalize(raw,control,metadataCache.identity)
    local delta=__rev131SignatureDelta(control,raw)
    local cardinality,grid={},{}
    for _,component in ipairs(delta.components) do
     if component.status=='CARDINALITY_ONLY' then cardinality[#cardinality+1]=component.component end
     if (component.component=='gridpos' or component.component=='gridposmatr')
      and component.status~='SAME' and component.status~='CARDINALITY_ONLY' then grid[#grid+1]=component.component end
    end
    if #grid>0 then normalized.blockers.GRID_VALUE_EFFECT_UNPROVEN=true end
    local audit=normalized.dictAudit
    log('GLOBAL_DICT_INDEX_AUDIT reference=%s channel_count=%d unique_dict_index_count=%d dict_index_distribution=%s relation_to_ui_channel=%s relation_to_attribute=%s relation_to_grid=%s relation_to_storage_source=UNAVAILABLE_FROM_REFERENCE_CHANNELS classification=%s reasons=%s',
     label,audit.channelCount,audit.uniqueCount,audit.distribution,audit.relationUI,audit.relationAttribute,audit.relationGrid,audit.classification,audit.reasons)
    log('GLOBAL_NORMALIZED_SEMANTIC_CLASS reference=%s semantic_core_match=%s ui_channel_key_relation=%s cardinality_only_differences=%s grid_value_differences=%s dict_index_class=%s remaining_semantic_blockers=%s observation_only=true',
     label,text(normalized.semanticCoreMatch),normalized.uiChannelKeyRelation,table.concat(cardinality,','),table.concat(grid,','),audit.classification,joined(normalized.blockers))
   end)
   if not observationOK then log('GLOBAL_NORMALIZED_SEMANTIC_ERROR reference=%s error=%s',label,text(observation)) end
  end
 end
 local targetPass=selected.pass and classified==#paths
 log('REV13_GLOBAL_TARGET_SUMMARY expected=%d found=%d classified=%d missing_targets=%s duplicate_targets=%s pass=%s',
  #paths,selected.found,classified,table.concat(selected.missing,','),table.concat(selected.duplicates,','),text(targetPass))
 local alternateRows={}
 for _,row in ipairs(rev6Result.rev7.rows or {}) do
  local copy={recipe=row.recipe,part=row.part,cue=row.cue,group=row.group,ref=row.ref,refId=row.refId,
   members=row.members,features=row.features,layers=row.layers,lanes=row.lanes,moving=row.moving,
   unsafe=row.unsafe,evidence=row.evidence}
  if eligible[row] then
   local info=rev6ByIdentity[metadataCache.identity(row.ref)]
   copy.features=info.features; copy.layers=info.layers; copy.lanes=info.lanes
   copy.moving=false; copy.unsafe={}
  end
  alternateRows[#alternateRows+1]=copy
 end
 local result=recipeReverseResolve(alternateRows)
 local final={}; for rid,entry in pairs(result.refs) do final[rid]=entry.ref end
 local silent=function() end
 local alt=proof.attributeUnsafe({rows=alternateRows,result=result,final=final,
  infoByKey=rev6ByIdentity,identity=metadataCache.identity,desc=desc,joined=joined,sample=sample,count=count,text=text,
  log=silent,detail=silent,now=now,ms=ms})
 local missing,extra=0,0
 for rid in pairs(oracle) do if not final[rid] then missing=missing+1 end end
 for rid in pairs(final) do if not oracle[rid] then extra=extra+1 end end
 log('REV13_GLOBAL_ALTERNATE refs=%d oracle_refs=%d missing=%s extra=%s unsafe_rows=%d final_surviving_unsafe=%d static_terminators=%d eligible_global_rows=%d classification=%s diagnostic_only=true alternate_ms=%s',
  count(final),count(oracle),oracleOK and tostring(missing) or 'UNVERIFIED',oracleOK and tostring(extra) or 'UNVERIFIED',
  #result.unsafe,alt.finalSurviving or 0,result.staticRows or 0,eligibleCount,
  targetPass and oracleOK and missing==0 and extra==0 and 'EXACT_MATCH' or 'INCONCLUSIVE',text(ms(start,now())))
 local remaining={}
 for _,rec in ipairs(alt.rows or {}) do if rec.category=='FINAL_SURVIVING_UNSAFE' then
  local label=desc(rec.ref); remaining[label]=(remaining[label] or 0)+1 end end
 local names={}; for label in pairs(remaining) do names[#names+1]=label end; table.sort(names)
 for _,label in ipairs(names) do log('REV13_GLOBAL_REMAINING reference=%s rows=%d',label,remaining[label]) end
 return {result=result,final=final,attribution=alt,eligible=eligibleCount}
end)
if not rev13OK then log('REV13_GLOBAL_ALTERNATE_ERROR error=%s',text(rev13)) end
-- Independent cooked truth observation for the 15 final-surviving Global
-- ordinary rows. It reads each row's source CuePart once after the oracle.
local truthStart=now()
local truthOK,truth=pcall(function()
 local paths={'Preset 4.1','Preset 4.4','Preset 4.23','Preset 6.10','Preset 21.5'}
 local selected=__rev13SelectGlobalTargets(paths,_G.ObjectList,metadataCache.identity,class,attribution.rows)
 if not selected.pass then return {partReads=0,classification='INCONCLUSIVE',targetPass=false} end
 local sourceParts={}
 for _,entry in ipairs(selected.entries) do for _,row in ipairs(entry.rows) do
  if row.part then sourceParts[#sourceParts+1]=row.part end
 end end
 local observation=__globalRecipeApplicabilityTruth(attribution.rows,selected.entries,sourceParts,metadataCache.raw,{
  log=function(s) log('%s',s) end,identity=metadataCache.identity,describe=desc,
  getPresetData=rawData,getSubfixture=_G.GetSubfixture,attributeByUI=_G.GetAttributeByUIChannel,
  proofs=attribution.ordinaryProof and attribution.ordinaryProof.proofs,
  -- No established native fixture-capability source: absence remains unknown.
  capability=function() return 'UNKNOWN' end})
 local keyStart=now()
 local keyOK,keyResult=pcall(__cookedMemberKeyProbe,observation.problematic,observation.views,{
  log=function(s) log('%s',s) end,identity=metadataCache.identity,describe=desc,getSubfixture=_G.GetSubfixture})
 if keyOK then log('COOKED_MEMBER_KEY_TIMING observer_ms=%s extra_GetPresetData_calls=0',text(ms(keyStart,now())))
 else log('COOKED_MEMBER_KEY_PROBE_ERROR error=%s',text(keyResult)) end
 local hierarchyStart=now()
 local hierarchyOK,hierarchyResult=pcall(__cookedHierarchicalKeyProbe,observation.problematic,observation.views,{
  log=function(s) log('%s',s) end,identity=metadataCache.identity,describe=desc,
  getSubfixture=_G.GetSubfixture,compareHandle=_G.CompareHandle})
 if hierarchyOK then log('COOKED_HIERARCHICAL_ADDRESS_TIMING observer_ms=%s extra_GetPresetData_calls=0',text(ms(hierarchyStart,now())))
 else log('COOKED_HIERARCHICAL_ADDRESS_ERROR error=%s',text(hierarchyResult)) end
 local nativeStart=now()
 local nativeOK,nativeResult=pcall(__nativeMemberAddressProbe,observation.problematic,observation.views,{
  log=function(s) log('%s',s) end,identity=metadataCache.identity,describe=desc,
  getSubfixture=_G.GetSubfixture,compareHandle=_G.CompareHandle,fromAddr=_G.FromAddr,toAddr=_G.ToAddr,objectList=_G.ObjectList})
 if nativeOK then log('NATIVE_MEMBER_ADDRESS_TIMING observer_ms=%s extra_GetPresetData_calls=0',text(ms(nativeStart,now())))
 else log('NATIVE_MEMBER_ADDRESS_ERROR error=%s',text(nativeResult)) end
 log('GLOBAL_RECIPE_APPLICABILITY_TIMING cooked_part_reads=%d observer_ms=%s target_pass=%s',
  observation.partReads,text(ms(truthStart,now())),text(selected.pass))
 return observation
end)
if not truthOK then log('GLOBAL_RECIPE_APPLICABILITY_ERROR error=%s',text(truth)) end
log('RESULT classification=%s Recipe_refs=%d oracle_refs=%d missing=%s extra=%s unsafe_rows=%d oracle_calls=%d fast_GetPresetData_calls=%d oracle_error=%s identity_set_only=true safe_integration=false bridged_refs=%d bridged_classification=%s',joined(classifications)..';'..joined(metadataClassifications),count(final),count(oracle),oracleOK and count(missing) or 'UNVERIFIED',oracleOK and count(extra) or 'UNVERIFIED',#result.unsafe,oracleCalls,fastCalls,text(oracleError),count(bridgeFinal),joined(bridgedClassifications))
log('END production_untouched=true markers=false waits=false metadata_targets=REFERENCE_ONLY cooked_history_fallback=false oracle_last=true')
return {rev7=rev6Result.rev7.result,rev7Final=rev6Result.rev7.final,rev7Rows=rev6Result.rev7.rows,rev7Missing=rev6Result.rev7Diff.missing,rev7Extra=rev6Result.rev7Diff.extra,rev7Classes=rev6Result.rev7Diff.classes,rev7OK=rev6Result.rev7.ok,attribution=attribution,attributionOK=attributionOK,rawRelAudit=rev6Result.rev7.audit,rev6=rev6Result,rev6Final=rev6Final,rev6Rows=rev6Rows,rev6Stats=rev6Stats,rev6Missing=rev6Missing,rev6Extra=rev6Extra,rev6Classes=rev6Classes,rev6OK=rev6OK,bridge=bridgeResult,bridgeFinal=bridgeFinal,bridgeRows=bridgeRows,bridgeStats=bridgeStats,bridgedMissing=bridgedMissing,bridgedExtra=bridgedExtra,bridgedClassifications=bridgedClassifications,bridgeOK=bridgeOK,metadata=metadataResult,metadataFinal=metadataFinal,metadataRows=metadataRows,metadataStats=cs,metadataMissing=metadataMissing,metadataExtra=metadataExtra,metadataClassifications=metadataClassifications,metadataOK=metadataOK,fast=result,final=final,oracle=oracle,missing=missing,extra=extra,classifications=classifications,stats=stats,fastCalls=fastCalls,oracleOK=oracleOK,oracleCalls=oracleCalls,fastOK=ok,rows=rows,patterns=patternOrder,detailsSuppressed=detailsSuppressed,unresolvedGroups=unresolvedCount}
end
