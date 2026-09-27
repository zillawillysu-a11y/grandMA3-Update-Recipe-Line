local rawData=_G.GetPresetData
assert((safe(BuildDetails) or {}).BigVersion=='2.5.0.3','Requires grandMA3 2.5.0.3')
local sequence,cue=safe(_G.SelectedSequence),safe(_G.GetCurrentCue)
assert(sequence and cue and cueNumber(cue),'Select Sequence and Current Cue')
SelectedSequence=function() return sequence end
GetCurrentCue=function() return cue end
local function count(t) local n=0; for _ in pairs(t or {}) do n=n+1 end; return n end
local function text(v) return tostring(v or 'UNAVAILABLE'):gsub('[\r\n]',' '):sub(1,500) end
local function desc(h) return text(commandAddress(h))..' ['..text(safe(HandleToStr,h))..']' end
local function log(fmt,...) Printf('[CueRecipeReverseAB] '..fmt,...) end
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
-- Enumerate native advertised properties: never invent a readable property.
local function metadata(h)
 local result={}; local n=safe(function() return h:PropertyCount() end)
 if type(n)~='number' or n>512 then return result end
 for i=0,n-1 do
  local key=safe(function() return h:PropertyName(i) end)
  if type(key)=='string' then result[key:lower()]=property(h,key) end
 end
 return result
end
local function joined(t) local a={}; for k in pairs(t or {}) do a[#a+1]=tostring(k) end; table.sort(a); return table.concat(a,',') end
-- Pool numbers are structural. Attribute names below are enum/Attribute identifiers,
-- never the user-authored name of a Preset, Phaser, Generator, Group or Recipe.
local attributeFamilies={dimmer='Dimmer',pan='Position',tilt='Position',color='Color',colour='Color',gobo='Gobo',beam='Beam',focus='Focus',control='Control',shapers='Shapers'}
local function structure(ref)
 local features,layers={},{}; local badFeature,badLayer=false,false
 local pool=tonumber((commandAddress(ref) or ''):match('^Preset%s+(%d+)%.'))
 if NUMBERED_PRESET_FEATURES[pool] then features[NUMBERED_PRESET_FEATURES[pool]]=true end
 local visited,steps,sources,recipeCount=0,0,0,0
 local evidence={}
 local function attributes(value)
  if not value or value=='' then badFeature=true; return end
  local found=false
  for word in value:lower():gmatch('[%w_]+') do
   local f=attributeFamilies[word]
   if not f then for _,family in ipairs(RECIPE_FEATURES) do if family:lower()==word then f=family end end end
   if f then features[f]=true; found=true else badFeature=true end
  end
  if not found then badFeature=true end
 end
 local function visit(node,depth)
  if depth>8 or visited>=512 then badFeature=true; badLayer=true; return end
  visited=visited+1
  local k=class(node):lower(); local props=metadata(node)
  if k=='phaserrecipe' then recipeCount=recipeCount+1 end
  if k=='phaserrecipestep' then steps=steps+1 end
  if k=='phaserrecipevaluesource' or k=='randomchannel' or k=='generatorchannel' then
   sources=sources+1
   attributes(props.attributes or props.attribute or props.feature)
   -- Only an explicitly advertised Layer enum is accepted. No default absolute.
   local layer=(props.layer or ''):lower()
   if layer=='absolute' or layer=='abs' then layers.abs=true
   elseif layer=='relative' or layer=='rel' then layers.rel=true
   else badLayer=true end
   local fields={}; for key,value in pairs(props) do fields[#fields+1]=key..'='..text(value) end; table.sort(fields)
   evidence[#evidence+1]=k..'{'..table.concat(fields,';')..'}'
  end
  for _,child in ipairs(children(node)) do visit(child,depth+1) end
 end
 visit(ref,0)
 -- A feature pool is sufficient family evidence for an ordinary Preset;
 -- no exposed value source means its layer and motion state remain opaque.
 local moving
 if isRandomGenerator(ref) then moving=true
 elseif recipeCount==1 and steps>1 then moving=true
 elseif recipeCount==1 and sources>0 and steps==1 then moving=false end
 if sources==0 then badLayer=true end
 -- A Cartesian product would guess source-specific feature/layer association.
 if count(features)>1 and count(layers)>1 then badLayer=true end
 return next(features) and not badFeature and features or nil,
        next(layers) and not badLayer and layers or nil,moving,table.concat(evidence,' ')
end
log('START target=2.5.0.3 sequence=%s cue=%s order=RECIPE_ONLY_FINALIZE_THEN_ORACLE production_flag=false no_waits=true no_markers=true',desc(sequence),desc(cue))
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
     row.features,row.layers,row.moving,row.evidence=structure(ref)
     local recipeProps=metadata(r)
     local advertisedLayer=(recipeProps.layer or ''):lower()
     if advertisedLayer=='absolute' or advertisedLayer=='abs' then row.layers={abs=true}
     elseif advertisedLayer=='relative' or advertisedLayer=='rel' then row.layers={rel=true} end
     if not row.features then row.unsafe[#row.unsafe+1]='FAST_PATH_UNSAFE_FEATURE_SCOPE' end
     if not row.layers then row.unsafe[#row.unsafe+1]='FAST_PATH_UNSAFE_LAYER' end
     if row.moving==nil then row.unsafe[#row.unsafe+1]='UNVERIFIED'; row.motionReason='ORDINARY_PRESET_OR_PHASER_MOTION_NOT_EXPOSED' end
    else
     row.unsafe[#row.unsafe+1]='UNVERIFIED'; row.evidence='Unresolved '..field..'='..text(rawRef)..' Selection='..text(rawGroup)
    end
    rows[#rows+1]=row
   end
  end
 end
 result=recipeReverseResolve(rows)
end)
local fastElapsed=ms(start,now())
result=result or {refs={},unsafe={},rejected={},assignments={}}
-- Immutable snapshot finalized before the oracle is even constructed.
local final={}; for rid,entry in pairs(result.refs) do final[rid]=entry.ref end
log('FAST_FINALIZED valid=%s refs=%d GetPresetData_calls=%d elapsed_ms=%s error=%s',text(ok),count(final),fastCalls,text(fastElapsed),text(err))
log('METRICS Cues=%d Parts=%d Recipe_rows=%d Stored_Groups=%d group_member_expansion=%d member_feature_lanes_resolved=%d empty_effective_rows=%d static_terminators=%d moving_contributing_rows=%d unsafe_rows=%d unresolved_symbolic_lanes=%d unknown_selection_rows=%d history_exhausted=%s',count(cues),stats.parts,stats.rows,stats.groups,stats.expansions,result.lanesResolved or 0,result.rowsSkipped or 0,result.staticRows or 0,result.movingRows or 0,#result.unsafe,#(result.unresolved or {}),result.unknownSelectionRows or 0,text(ok))
local function trace(row,tag)
 log('%s ref=%s Cue=%s Part=%s Recipe=%s Group=%s features=%s layers=%s surviving_member_count=%d surviving_members=%s group_members=%s unsafe=%s motion_reason=%s evidence=%s',tag,desc(row.ref),desc(row.cue),desc(row.part),desc(row.recipe),desc(row.group),joined(row.features),joined(row.layers),count(row.survivors),joined(row.survivors),joined(row.members),table.concat(row.unsafe or {},','),text(row.motionReason),text(row.evidence))
end
for rid,entry in pairs(result.refs) do
 log('ACTIVE ref=%s surviving_member_count=%d surviving_members=%s',desc(entry.ref),count(entry.members),joined(entry.members))
 for row in pairs(entry.sources) do trace(row,'SOURCE') end
end
for _,row in ipairs(result.unsafe) do trace(row,'UNSAFE') end
for _,lane in ipairs(result.unresolved or {}) do log('UNRESOLVED member=%s feature_layer=%s Recipe=%s Group=%s',text(lane.member),lane.lane,desc(lane.row.recipe),desc(lane.row.group)) end
for _,row in ipairs(result.rejected) do
 trace(row,'OLDER_REJECTED_OVERLAP')
 local losses={}
 for _,loss in ipairs(row.superseded) do
  losses[loss.newer]=losses[loss.newer] or {}
  local bucket=losses[loss.newer][loss.lane] or {sample=loss.member,n=0,unsafe=loss.unsafe}; losses[loss.newer][loss.lane]=bucket; bucket.n=bucket.n+1
 end
 for newer,lanes in pairs(losses) do for lane,bucket in pairs(lanes) do
  log('FIRST_NEWER member=%s overlapping_member_count=%d lane=%s older_Recipe=%s newer_Cue=%s newer_Part=%s newer_Recipe=%s newer_Group=%s unsafe_barrier=%s',text(bucket.sample),bucket.n,lane,desc(row.recipe),desc(newer.cue),desc(newer.part),desc(newer.recipe),desc(newer.group),text(bucket.unsafe==true))
 end end
end
phase='ORACLE'
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
if oracleOK then
 for rid,ref in pairs(oracle) do if not final[rid] then missing[rid]=ref end end
 for rid,ref in pairs(final) do if not oracle[rid] then extra[rid]=ref end end
end
local classifications={}
for _,row in ipairs(result.unsafe) do for _,reason in ipairs(row.unsafe) do classifications[reason]=true end end
-- Recipe-only authoring is the supported product contract. A reference with no
-- Recipe source is unsupported/unsafe, never grounds for a production fallback.
local stable=safe(_G.SelectedSequence)==sequence and safe(_G.GetCurrentCue)==cue
if not ok or not oracleOK or not stable then classifications.UNVERIFIED=true
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
 log('DIFF_%s ref=%s',tag,desc(ref))
 local found=false
 for _,row in ipairs(rows) do if row.refId==rid then found=true; trace(row,'DIFF_SOURCE'); for _,loss in ipairs(row.superseded or {}) do log('DIFF_LANE member=%s feature_layer=%s newer_Recipe=%s newer_Group=%s',text(loss.member),loss.lane,desc(loss.newer.recipe),desc(loss.newer.group)) end end end
 if not found then log('DIFF_SOURCE ref=%s Group/member/feature/layer=UNVERIFIED no_Recipe_source=true',desc(ref)) end
end end
log('RESULT classification=%s Recipe_refs=%d oracle_refs=%d missing=%s extra=%s unsafe_rows=%d oracle_calls=%d fast_GetPresetData_calls=%d oracle_error=%s identity_set_only=true safe_integration=false',joined(classifications),count(final),count(oracle),oracleOK and count(missing) or 'UNVERIFIED',oracleOK and count(extra) or 'UNVERIFIED',#result.unsafe,oracleCalls,fastCalls,text(oracleError))
log('END production_untouched=true markers=false waits=false fallback_during_fast_path=false')
return {fast=result,final=final,oracle=oracle,missing=missing,extra=extra,classifications=classifications,stats=stats,fastCalls=fastCalls,oracleCalls=oracleCalls,fastOK=ok,oracleOK=oracleOK,rows=rows}
end
