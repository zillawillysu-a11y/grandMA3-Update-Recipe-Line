-- Diagnostic only: Preset 9008-style phaser partial-lane split proof.
-- Observer only, never resolver rules. The remaining final-surviving blocker
-- (derived, never hard-coded) is replaced in cloned alternate rows ONLY by a
-- safe known ABS moving row plus an unsafe REL-only barrier. No new
-- GetPresetData calls. No RawValueRel semantics invented. Rev7 source rows,
-- original attribution, and oracle inputs are untouched.
function __phaser9008SplitProbe(ctx,api)
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
 local function refLabel(ref) return txt(safe(api.describe,ref)) end
 -- Remaining blocker derived from attribution: final-surviving rows whose
 -- reference is neither proven Global nor proven Selective.
 local selProven={}
 for label,R in pairs(ctx.selectiveRefs or {}) do
  if type(R)=='table' and (R.unproven or 0)==0 and (R.different or 0)==0 and (R.rows or 0)>0 then selProven[label]=true end
 end
 local globalSet={}; for _,p in ipairs(ctx.globalPaths or {}) do globalSet[p]=true end
 local remaining={} -- identity key -> {label, recs}
 for _,rec in ipairs(ctx.attributionRows or {}) do if rec.category=='FINAL_SURVIVING_UNSAFE' then
  local rk=rec.ref and safe(api.identity,rec.ref)
  local label=refLabel(rec.ref)
  if rk and not globalSet[rk] and not selProven[label] then
   local e=remaining[rk]
   if not e then e={label=label,recs={}}; remaining[rk]=e end
   e.recs[#e.recs+1]=rec
  end
 end end
 local remKeys=ordered(remaining)
 local target=remKeys[1] and remaining[remKeys[1]] or nil
 local proofLine={reference=target and target.label or '-',members=0,feature='-',linked='-'}
 if #remKeys~=1 then
  emit('PHASER_9008_SPLIT_PROOF reference=%s members=0 feature=- known_layers=- unresolved_layers=- motion=- linked_presets=- classification=INCONCLUSIVE diagnostic_only=true',proofLine.reference)
  return {classification='INCONCLUSIVE',target=nil}
 end
 local tkey=remKeys[1]
 -- Structural ABS proof from bridge metadata + linked preset caches.
 local info=ctx.bridgeInfo and ctx.bridgeInfo[tkey]
 local fgList={}
 if type(info)=='table' and type(info.features)=='table' then for f in pairs(info.features) do fgList[#fgList+1]=f end end
 table.sort(fgList)
 local fg=#fgList==1 and fgList[1] or nil
 -- Aggregate info.motion stays UNSAFE on native data because unresolved REL /
 -- linked-metadata reasons remain; it must not override the explicit
 -- structural motion proof. Motion authority is the moving ABS lane itself.
 local absLane=type(info)=='table' and type(info.lanes)=='table' and fg~=nil and info.lanes[fg..'|ABS'] or nil
 local absOK=type(info)=='table' and info.phaserStructure==true
  and info.motionProof=='MOTION_PROVEN_EFFECTIVE_STEP_DIFFERENCE'
  and fg~=nil and type(info.layers)=='table' and info.layers.ABS==true
  and type(absLane)=='table' and absLane.moving==true
  and info.completeness~='UNKNOWN'
 local mismatchFound=false
 if absOK and type(info)=='table' and type(info.evidence)=='table' then
  for reason in pairs(info.evidence) do if type(reason)=='string' and reason:find('MISMATCH',1,true) then absOK=false; mismatchFound=true end end
 end
 -- Linked presets from original structural audits; every one must be cached,
 -- static, ABS-exposing, and member-proven. No new reads.
 local linked,linkedOK,linkedLabels={},{},{}
 if absOK then
  for _,r in ipairs(ctx.rawRows or {}) do
   local rk=r.ref and safe(api.identity,r.ref)
   if rk==tkey then
    for _,a in ipairs((r.structural or {}).audits or {}) do
     local lh=a and a.presetHandle
     local lk=lh and safe(api.identity,lh)
     if lk and not linked[lk] then linked[lk]=lh end
    end
   end
  end
  if count(linked)==0 then linkedOK=false
  else
   linkedOK=true
   for lk,lh in pairs(linked) do
    linkedLabels[#linkedLabels+1]=refLabel(lh)
    -- bridgeInfo only proves cached ordinary metadata exists on the expected
    -- path; the later native-proven Rev12 ordinary proof is semantic authority.
    local li=ctx.bridgeInfo and ctx.bridgeInfo[lk]
    local lp=lk and ctx.ordinaryProofs and ctx.ordinaryProofs[lk]
    if not (type(li)=='table' and li.source=='ORDINARY_GETPRESETDATA'
     and type(lp)=='table' and lp.motionStaticProven==true and lp.memberApplicabilityProven==true
     and type(lp.layers)=='table' and lp.layers.ABS==true and lp.layers.REL~=true
     and type(lp.channels)=='number' and lp.channels>0 and lp.activeValue==lp.channels) then linkedOK=false end
   end
   table.sort(linkedLabels)
  end
 else linkedOK=false end
 proofLine.members=0; proofLine.feature=fg or '-'; proofLine.linked=table.concat(linkedLabels,','):sub(1,120)
 if proofLine.linked=='' then proofLine.linked='-' end
 -- Count target members from Rev7 history rows.
 local targetRows={}
 for _,row in ipairs(ctx.rev7Rows or {}) do
  local rk=row.ref and safe(api.identity,row.ref)
  if rk==tkey then targetRows[#targetRows+1]=row end
 end
 local memberSet={}
 for _,row in ipairs(targetRows) do if type(row.members)=='table' then for m in pairs(row.members) do memberSet[m]=true end end end
 proofLine.members=count(memberSet)
 local absProven=absOK and linkedOK and #targetRows>0
 emit('PHASER_9008_SPLIT_PROOF reference=%s members=%d feature=%s known_layers=%s unresolved_layers=REL motion=%s linked_presets=%s classification=%s diagnostic_only=true',
  target.label,proofLine.members,proofLine.feature,absProven and 'ABS' or '-',absProven and 'MOTION_PROVEN' or '-',
  proofLine.linked,absProven and 'ABS_STRUCTURE_PROVEN' or 'INCONCLUSIVE')
 if not absProven then
  emit('PHASER_9008_ABS_GATE phaser_structure=%s motion_proof=%s abs_lane_present=%s abs_lane_moving=%s feature_count=%d abs_layer_present=%s completeness=%s mismatch_evidence=%s linked_gate=%s classification=%s diagnostic_only=true',
   tostring(type(info)=='table' and info.phaserStructure),tostring(type(info)=='table' and info.motionProof),
   tostring(absLane~=nil),tostring(absLane and absLane.moving),#fgList,
   tostring(type(info)=='table' and type(info.layers)=='table' and info.layers.ABS),
   tostring(type(info)=='table' and info.completeness),tostring(mismatchFound),
   absOK and (linkedOK and 'PASS' or 'FAIL') or 'NOT_EVALUATED','STRUCTURAL_ABS_UNPROVEN')
  return {classification='INCONCLUSIVE',target=target}
 end
 -- Build cloned alternate: replace target rows by safe ABS + REL barrier.
 local absLaneKey=fg..'|ABS'; local relLaneKey=fg..'|REL'
 local altRows,relBarriers={},{}
 for _,row in ipairs(ctx.rev7Rows or {}) do
  local rk=row.ref and safe(api.identity,row.ref)
  if rk~=tkey then altRows[#altRows+1]=row
  else
   local absClone={recipe=row.recipe,part=row.part,cue=row.cue,group=row.group,ref=row.ref,refId=row.refId,members=row.members,
    features={[fg]=true},layers={ABS=true},lanes={[absLaneKey]={feature=fg,layer='ABS',moving=true}},moving=true,unsafe={},evidence='PHASER_9008_KNOWN_ABS_SPLIT'}
   local relBarrier={recipe=row.recipe,part=row.part,cue=row.cue,group=row.group,ref=row.ref,refId=row.refId,members=row.members,
    features={[fg]=true},layers={REL=true},lanes={[relLaneKey]={feature=fg,layer='REL',moving=false}},moving=false,
    unsafe={'PHASER_REL_LAYER_ENCODING_UNPROVEN'},evidence='PHASER_9008_RESIDUAL_REL_BARRIER'}
   altRows[#altRows+1]=absClone
   altRows[#altRows+1]=relBarrier
   relBarriers[relBarrier]=true
  end
 end
 local splitOK,splitResult=pcall(api.reverseResolve,altRows)
 if not splitOK then
  emit('PHASER_9008_SPLIT_ALTERNATE error=%s diagnostic_only=true',txt(splitResult))
  return {classification='INCONCLUSIVE',target=target}
 end
 local splitFinal={}; for rid,entry in pairs(splitResult.refs or {}) do splitFinal[rid]=entry.ref end
 local missing,extra=0,0
 if ctx.oracleOK then
  for rid in pairs(ctx.oracle or {}) do if not splitFinal[rid] then missing=missing+1 end end
  for rid in pairs(splitFinal) do if not (ctx.oracle or {})[rid] then extra=extra+1 end end
 end
 local attOK,att=pcall(api.attributor,altRows,splitResult,splitFinal)
 if not attOK then
  emit('PHASER_9008_SPLIT_ATTRIBUTION_ERROR error=%s diagnostic_only=true',txt(att))
 end
 local splitSurviving=-1
 if attOK and type(att)=='table' and type(att.rows)=='table' then
  splitSurviving=0
  for _,rec in ipairs(att.rows) do if rec.category=='FINAL_SURVIVING_UNSAFE' then splitSurviving=splitSurviving+1 end end
 end
 emit('PHASER_9008_SPLIT_ALTERNATE final_refs=%d oracle_refs=%d missing=%s extra=%s unsafe_rows=%d final_surviving_unsafe=%d static_terminators=%d moving_rows=%d classification=%s diagnostic_only=true',
  count(splitFinal),count(ctx.oracle or {}),ctx.oracleOK and tostring(missing) or 'UNVERIFIED',ctx.oracleOK and tostring(extra) or 'UNVERIFIED',
  #(splitResult.unsafe or {}),splitSurviving,splitResult.staticRows or 0,splitResult.movingRows or 0,
  (ctx.oracleOK and missing==0 and extra==0 and splitSurviving>=0) and 'ORACLE_EXACT_MATCH' or 'INCONCLUSIVE')
 -- Residual REL barrier analysis on the alternate result.
 local decided,unres={},{}
 for _,a in ipairs(splitResult.assignments or {}) do decided[tostring(a.member)..'\0'..tostring(a.lane)]=a.row end
 for _,u in ipairs(splitResult.unresolved or {}) do unres[tostring(u.member)..'\0'..tostring(u.lane)]=u.row end
 local relMembers,relLanes,superseded,finalUnres,blockedRefs,blockedLanes=0,{},0,0,{},0
 local relMemberSet={}
 for barrier in pairs(relBarriers) do
  if type(barrier.members)=='table' then for m in pairs(barrier.members) do
   relMemberSet[m]=true
   relLanes[tostring(m)..'\0'..relLaneKey]=true
  end end
 end
 for m in pairs(relMemberSet) do relMembers=relMembers+1 end
 for k in pairs(relLanes) do
  if decided[k] then superseded=superseded+1
  else
   for barrier in pairs(relBarriers) do if unres[k]==barrier then finalUnres=finalUnres+1; break end end
  end
 end
 for _,row in ipairs(altRows) do
  for _,sup in ipairs(row.superseded or {}) do
   if sup.unsafe==true and relBarriers[sup.newer]==true and tostring(sup.lane)==relLaneKey then
    blockedLanes=blockedLanes+1
    if row.ref then blockedRefs[refLabel(row.ref)]=true end
   end
  end
 end
 local blockedList={}; for k in pairs(blockedRefs) do blockedList[#blockedList+1]=k end; table.sort(blockedList)
 local relLaneCount=count(relLanes)
 local barrierClass=(finalUnres==0 and superseded==relLaneCount) and 'REL_FULLY_SUPERSEDED' or ((blockedLanes==0 and #blockedList==0) and 'REL_NONCONTRIBUTING' or 'REL_BLOCKS_HISTORY')
 emit('PHASER_9008_REL_BARRIER_SUMMARY members=%d rel_barrier_lanes=%d fully_superseded_lanes=%d final_unresolved_lanes=%d blocked_older_candidate_lanes=%d blocked_references=%s classification=%s diagnostic_only=true',
  relMembers,count(relLanes),superseded,finalUnres,blockedLanes,table.concat(blockedList,',')~='' and table.concat(blockedList,',') or '-',barrierClass)
 local classification
 if splitSurviving<0 then classification='PHASER_9008_REL_SEMANTICS_STILL_REQUIRED'
 elseif ctx.oracleOK and missing==0 and extra==0 and finalUnres==0 and superseded==relLaneCount then classification='PHASER_9008_PARTIAL_SCOPE_PROVEN_REL_SUPERSEDED'
 elseif ctx.oracleOK and missing==0 and extra==0 and blockedLanes==0 and #blockedList==0 then classification='PHASER_9008_PARTIAL_SCOPE_PROVEN_REL_NONCONTRIBUTING'
 else classification='PHASER_9008_REL_SEMANTICS_STILL_REQUIRED' end
 -- Source Part cooked cross-check only (never drives promotion). Scope is the
 -- attribution-derived FINAL_SURVIVING_UNSAFE source row(s) for the target
 -- reference only; historical superseded occurrences must not multiply members.
 local cooked={members=0,applicable=0,absExp=0,absDiff=0,absMiss=0,relExp=0,relOther=0,relAbsent=0,noBucket=0}
 local sourceRows={}
 do
  local seenRows={} -- deduplicate repeated row tables
  for _,rec in ipairs(ctx.attributionRows or {}) do
   local rk=rec.ref and safe(api.identity,rec.ref)
   if rec.category=='FINAL_SURVIVING_UNSAFE' and rk==tkey and type(rec.row)=='table' and not seenRows[rec.row] then
    seenRows[rec.row]=true
    sourceRows[#sourceRows+1]=rec.row
   end
  end
 end
 for _,row in ipairs(sourceRows) do
  local partKey=safe(api.identity,row.part) or row.part
  local view=ctx.views and ctx.views[partKey]
  local buckets=view and view.buckets
  if type(row.members)=='table' then for m in pairs(row.members) do
   cooked.members=cooked.members+1
   local h=api.getSubfixture and safe(api.getSubfixture,m)
   local key2=h and toaddrKey(safe(function() return h:ToAddr() end))
   local bucket=key2 and type(buckets)=='table' and buckets[key2]
   local dimmer=type(bucket)=='table' and bucket['Dimmer']
   if type(bucket)~='table' then cooked.noBucket=cooked.noBucket+1
   else
    -- Native FG capability: complete enum with an attribute in target FG.
    local cap,capFG=false,false
    local channels=api.getUIChannels and safe(api.getUIChannels,h,true)
    if type(channels)=='table' then
     cap=true
     for _,u in pairs(channels) do
      if type(u)=='table' or type(u)=='userdata' then
       local i=safe(function() return u.INDEX end)
       if type(i)~='number' then i=safe(function() return u:Get('INDEX') end) end
       local a=type(i)=='number' and api.attributeByUI and safe(api.attributeByUI,i-1)
       local f=a and safe(function() return a.Feature end)
       local g=f and safe(function() return f:Parent() end)
       local gid=g and safe(api.identity,g)
       if gid and gid==fg:match('^FG:(.+)$') then capFG=true end
       if type(i)~='number' or not a then cap=false end
      end
     end
    end
    if cap and capFG then cooked.applicable=cooked.applicable+1 end
    if type(dimmer)=='table' then
     local alink=dimmer.abs_preset; local actual=alink and safe(api.identity,alink)
     local expected=safe(api.identity,row.ref)
     if expected and actual==expected then cooked.absExp=cooked.absExp+1
     elseif actual then cooked.absDiff=cooked.absDiff+1 else cooked.absMiss=cooked.absMiss+1 end
     local rlink=dimmer.rel_preset; local ractual=rlink and safe(api.identity,rlink)
     if expected and ractual==expected then cooked.relExp=cooked.relExp+1
     elseif ractual then cooked.relOther=cooked.relOther+1 else cooked.relAbsent=cooked.relAbsent+1 end
    else cooked.absMiss=cooked.absMiss+1; cooked.relAbsent=cooked.relAbsent+1 end
   end
  end end
 end
 emit('9008_SOURCE_COOKED_SUMMARY members=%d applicable_members=%d abs_expected_9008=%d abs_different=%d abs_missing=%d rel_9008=%d rel_other=%d rel_absent=%d bucket_missing=%d diagnostic_only=true',
  cooked.members,cooked.applicable,cooked.absExp,cooked.absDiff,cooked.absMiss,cooked.relExp,cooked.relOther,cooked.relAbsent,cooked.noBucket)
 if classification=='PHASER_9008_PARTIAL_SCOPE_PROVEN_REL_SUPERSEDED' or classification=='PHASER_9008_PARTIAL_SCOPE_PROVEN_REL_NONCONTRIBUTING' then
  local rem={} -- derived remaining blockers from split attribution
  if attOK and type(att)=='table' and type(att.rows)=='table' then
   for _,rec in ipairs(att.rows) do
    if rec.category=='FINAL_SURVIVING_UNSAFE' and rec.ref then
     -- Path B only: the synthetic residual REL barrier is closed by
     -- blockedLanes==0 even though attribution still lists it. Exclude by
     -- object identity from relBarriers, never by Preset name.
     local isResidual=relBarriers[rec.row]==true
     if not (isResidual and classification=='PHASER_9008_PARTIAL_SCOPE_PROVEN_REL_NONCONTRIBUTING') then
      rem[refLabel(rec.ref)]=true
     end
    end
   end
  end
  local remList={}; for k in pairs(rem) do remList[#remList+1]=k end; table.sort(remList)
  local trackClass=#remList==0 and 'TRACK_A_SEMANTICS_PROVEN' or 'TRACK_A_SEMANTICS_INCOMPLETE'
  emit('TRACK_A_RESOLVER_CHECKPOINT member_identity=PROVEN global_ordinary=PROVEN selective=PROVEN phaser_9008_known_abs=PROVEN phaser_9008_unknown_rel=%s remaining_semantic_blockers=%s final_refs=%d oracle_refs=%d missing=%d extra=%d classification=%s diagnostic_only=true',
   finalUnres==0 and 'SAFE_SUPERSEDED' or 'SAFE_NONCONTRIBUTING',
   table.concat(remList,',')~='' and table.concat(remList,',') or '-',
   count(splitFinal),count(ctx.oracle or {}),ctx.oracleOK and missing or -1,ctx.oracleOK and extra or -1,trackClass)
 end
 return {classification=classification,target=target,missing=missing,extra=extra}
end
