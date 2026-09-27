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
  local a,b=safe(HandleToStr,h),safe(HandleToStr,v)
  if a and b and a==b then return i end
 end
 identities[#identities+1]=h; return #identities
end
local phase,fastCalls,oracleCalls='FAST',0,0
GetPresetData=function(...)
 if phase=='FAST' then fastCalls=fastCalls+1; error('FAST_PATH_FORBIDDEN_GetPresetData') end
 oracleCalls=oracleCalls+1; return rawData(...)
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
log('START revision=2_VALUE_SOURCE_AUDIT target=2.5.0.3 sequence=%s cue=%s order=RECIPE_ONLY_FINALIZE_THEN_ORACLE production_flag=false no_waits=true no_markers=true',desc(sequence),desc(cue))
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
log('FAST_FINALIZED valid=%s refs=%d GetPresetData_calls=%d elapsed_ms=%s error=%s',text(ok),count(final),fastCalls,text(fastElapsed),text(err))
local function metrics()
 log('FAST_PATH_METRICS Cues=%d Parts=%d Recipe_rows=%d Stored_Groups=%d group_member_expansion=%d member_feature_lanes_resolved=%d empty_effective_rows=%d static_terminators=%d moving_contributing_rows=%d unsafe_rows=%d unresolved_symbolic_lanes=%d unknown_selection_rows=%d GetPresetData_calls=%d elapsed_ms=%s history_exhausted=%s',count(cues),stats.parts,stats.rows,stats.groups,stats.expansions,result.lanesResolved or 0,result.rowsSkipped or 0,result.staticRows or 0,result.movingRows or 0,#result.unsafe,#(result.unresolved or {}),result.unknownSelectionRows or 0,fastCalls,text(fastElapsed),text(ok))
end
metrics()
local function path(h) return desc(h)..' native='..text(h and address(h)) end
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
identityOutput('RECIPE_ONLY_FINAL',final)
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
phase='ORACLE'
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
log('RESULT classification=%s Recipe_refs=%d oracle_refs=%d missing=%s extra=%s unsafe_rows=%d oracle_calls=%d fast_GetPresetData_calls=%d oracle_error=%s identity_set_only=true safe_integration=false',joined(classifications),count(final),count(oracle),oracleOK and count(missing) or 'UNVERIFIED',oracleOK and count(extra) or 'UNVERIFIED',#result.unsafe,oracleCalls,fastCalls,text(oracleError))
log('END production_untouched=true markers=false waits=false fallback_during_fast_path=false')
return {fast=result,final=final,oracle=oracle,missing=missing,extra=extra,classifications=classifications,stats=stats,fastCalls=fastCalls,oracleCalls=oracleCalls,fastOK=ok,oracleOK=oracleOK,rows=rows,patterns=patternOrder,detailsSuppressed=detailsSuppressed,unresolvedGroups=unresolvedCount}
end
