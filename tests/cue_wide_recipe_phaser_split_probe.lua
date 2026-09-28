local f=assert(io.open('tools/templates/cue_wide_recipe_phaser_split_probe.lua','rb'))
local source=f:read('*a'); f:close(); assert(load(source))()
local nid=0; local function handle(kind,label)
 nid=nid+1; local h={id=nid,kind=kind,label=label}; return h
end
local r9008=handle('Preset','Preset 25.9008'); local linkedA=handle('Preset','Preset 1.11'); local linkedB=handle('Preset','Preset 1.1')
local olderA=handle('Preset','older ABS'); local olderR=handle('Preset','older REL'); local newerA=handle('Preset','newer ABS'); local newerR=handle('Preset','newer REL')
local part=handle('Part','Sequence 3841.7000.2')
local fg1=handle('FeatureGroup','FG1')
local function feature(fg) local x=handle('Feature','F'); function x:Parent() return fg end; return x end
local f1=feature(fg1)
local function attr(label) local a=handle('Attribute',label); a.Name=label; a.Feature=f1; return a end
local dimmer=attr('Dimmer')
local FG='FG:DBI:'..fg1.id
local uiMap={[0]=dimmer,[1]=dimmer}
local function member(toaddr)
 local h=handle('Subfixture',toaddr); h.channels={{INDEX=1,SUBATTRIBUTE='s'},{INDEX=2,SUBATTRIBUTE='s'}}
 function h:ToAddr() return self.label end
 return h
end
local mA,mB=member('Fixture 201.1.1'),member('Fixture 201.1.2')
local bySf={[11]=mA,[12]=mB}
local key9008='DBI:'..r9008.id
-- Native bridge shape: aggregate motion stays UNSAFE while the structural
-- ABS motion proof is explicit and the ABS lane moves.
local bridgeBase={source='MIXED',completeness='PARTIAL',motion='UNSAFE',motionProof='MOTION_PROVEN_EFFECTIVE_STEP_DIFFERENCE',
 phaserStructure=true,features={[FG]=true},layers={ABS=true},lanes={[FG..'|ABS']={feature=FG,layer='ABS',moving=true}},
 evidence={LINKED_PRESET_METADATA_UNSAFE=true,RAW_LAYER_ENCODING_UNPROVEN_REL=true}}
-- Native shape: older generic normalizer left PARTIAL/UNSAFE; Rev12 ordinary
-- proof is the semantic authority for linked presets.
local bridgeInfo={[key9008]=bridgeBase,
 ['DBI:'..linkedA.id]={source='ORDINARY_GETPRESETDATA',completeness='PARTIAL',motion='UNSAFE',layers={ABS=true}},
 ['DBI:'..linkedB.id]={source='ORDINARY_GETPRESETDATA',completeness='PARTIAL',motion='UNSAFE',layers={ABS=true}}}
local function linkedProof() return {motionStaticProven=true,memberApplicabilityProven=true,layers={ABS=true},channels=58,activeValue=58} end
local proofs={['DBI:'..linkedA.id]=linkedProof(),['DBI:'..linkedB.id]=linkedProof()}
local rawRows={{ref=r9008,structural={audits={{presetHandle=linkedA},{presetHandle=linkedB}}}}}
local function mkrow(ref,refId,members,extra)
 local r={recipe=handle('Recipe','R'),part=part,cue=handle('Cue','C'),group=handle('Group','Group 232'),ref=ref,refId=refId,members=members,
  features={[FG]=true},layers={ABS=true},lanes={[FG..'|ABS']={feature=FG,layer='ABS',moving=false}},moving=false,unsafe={},evidence=''}
 for k,v in pairs(extra or {}) do r[k]=v end
 return r
end
-- Mini newest-first resolver mirroring engine blocking semantics.
local captured=nil
local function stubResolve(rows)
 captured=rows
 local res={refs={},assignments={},unresolved={},unsafe={},staticRows=0,movingRows=0}
 local decided,blocked={},{}
 for idx,row in ipairs(rows) do
  row.reverseIndex=idx; row.superseded={}; row.effective=0
  local reasons=row.unsafe or {}
  if #reasons>0 then
   res.unsafe[#res.unsafe+1]=row
   if row.members then for m in pairs(row.members) do
    blocked[m]=blocked[m] or {}
    if not row.layers then blocked[m]['*']=blocked[m]['*'] or row
    else for layer in pairs(row.layers) do
     if not row.features then blocked[m]['*']=blocked[m]['*'] or row
     else for feat in pairs(row.features) do blocked[m][feat..'|'..layer]=blocked[m][feat..'|'..layer] or row end end
    end end
   end end
  else
   local lanes=row.lanes or {}
   if not row.lanes then for feat in pairs(row.features or {}) do for layer in pairs(row.layers or {}) do lanes[feat..'|'..layer]={feature=feat,layer=layer,moving=row.moving} end end end
   for m in pairs(row.members or {}) do
    decided[m]=decided[m] or {}
    for lane,ls in pairs(lanes) do
     local barrier=nil
     for _,k in ipairs({lane,(ls.feature or '')..'|*','*'}) do
      local c=(blocked[m] or {})[k]
      if c and (not barrier or c.reverseIndex<barrier.reverseIndex) then barrier=c end
     end
     if decided[m][lane] then row.superseded[#row.superseded+1]={member=m,lane=lane,newer=decided[m][lane]}
     elseif barrier then row.superseded[#row.superseded+1]={member=m,lane=lane,newer=barrier,unsafe=true}
     else decided[m][lane]=row; row.effective=(row.effective or 0)+1
      res.assignments[#res.assignments+1]={member=m,lane=lane,row=row}
      if ls.moving then local e=res.refs[row.refId] or {ref=row.ref,members={}}; res.refs[row.refId]=e; e.members[m]=true end
     end
    end
   end
   if (row.effective or 0)>0 then if row.moving then res.movingRows=res.movingRows+1 else res.staticRows=res.staticRows+1 end end
  end
 end
 for m,lanes in pairs(blocked) do for lane,row in pairs(lanes) do
  if not (decided[m] or {})[lane] then res.unresolved[#res.unresolved+1]={member=m,lane=lane,row=row} end
 end end
 return res
end
local attRows={}
local function stubAttributor(rows,result,final)
 if type(attRows)=='table' and attRows.auto then
  local out={}
  for _,row in ipairs(rows) do
   if row.evidence=='PHASER_9008_RESIDUAL_REL_BARRIER' then out[#out+1]={category='FINAL_SURVIVING_UNSAFE',ref=row.ref,row=row} end
  end
  for _,e in ipairs(attRows.extra or {}) do out[#out+1]=e end
  return {rows=out}
 end
 return {rows=attRows}
end
local logs={}; local calls={presetData=0}
local api={log=function(s) logs[#logs+1]=s end,identity=function(h) return h and 'DBI:'..h.id end,
 describe=function(h) return h and h.label end,
 text=function(v) return tostring(v) end,
 getSubfixture=function(sf) return bySf[sf] end,
 toAddr=function(h) return h and h:ToAddr() end,
 getUIChannels=function(h) return h.channels end,
 attributeByUI=function(i) return uiMap[i] end,
 reverseResolve=stubResolve,attributor=stubAttributor}
_G.GetPresetData=function() calls.presetData=calls.presetData+1; error('must reuse caches') end
local partKey='DBI:'..part.id
local function cooked(absRef,relRef)
 local d={}
 if absRef then d.abs_preset=absRef end
 if relRef~=nil then d.rel_preset=relRef end
 return {['201.1.1']={Dimmer=d},['201.1.2']={Dimmer=d}}
end
local function run(revRows,attRecs,buckets,oracle)
 logs={}
 local ctx={rev7Rows=revRows,rawRows=rawRows,attributionRows=attRecs,globalPaths={},selectiveRefs={},
  bridgeInfo=bridgeInfo,ordinaryProofs=proofs,views={[partKey]={part=part,buckets=buckets}},
  oracle=oracle or {[10]=r9008},oracleOK=true}
 return __phaser9008SplitProbe(ctx,api)
end
local function has(pat) for _,l in ipairs(logs) do if l:find(pat,1,true) then return true end end return false end
local r9008row=mkrow(r9008,10,{[11]=true,[12]=true})
local att9008={category='FINAL_SURVIVING_UNSAFE',ref=r9008,row=r9008row,surviving={'11\0*'}}
-- 10+11. empty REL string / explicit None never drive semantics; barrier always present
local r=run({r9008row},{att9008},cooked(r9008,false))
assert(has('classification=ABS_STRUCTURE_PROVEN'))
assert(has('PHASER_9008_REL_BARRIER_SUMMARY'))
-- 7. aggregate motion=UNSAFE must NOT block structural ABS (native shape above)
assert(bridgeBase.motion=='UNSAFE')
-- 2. motionProof missing/wrong => reject
bridgeBase.motionProof='MOTION_UNPROVEN'
r=run({r9008row},{att9008},cooked(r9008,false))
assert(not has('classification=ABS_STRUCTURE_PROVEN') and has('PHASER_9008_ABS_GATE'))
bridgeBase.motionProof='MOTION_PROVEN_EFFECTIVE_STEP_DIFFERENCE'
-- 3. ABS lane moving=false => reject
bridgeBase.lanes[FG..'|ABS'].moving=false
r=run({r9008row},{att9008},cooked(r9008,false))
assert(not has('classification=ABS_STRUCTURE_PROVEN'))
bridgeBase.lanes[FG..'|ABS'].moving=true
-- 4. phaserStructure=false => reject
bridgeBase.phaserStructure=false
r=run({r9008row},{att9008},cooked(r9008,false))
assert(not has('classification=ABS_STRUCTURE_PROVEN'))
bridgeBase.phaserStructure=true
-- 5. MISMATCH evidence => reject
bridgeBase.evidence={SOME_MISMATCH_REASON=true}
r=run({r9008row},{att9008},cooked(r9008,false))
assert(not has('classification=ABS_STRUCTURE_PROVEN'))
bridgeBase.evidence={LINKED_PRESET_METADATA_UNSAFE=true,RAW_LAYER_ENCODING_UNPROVEN_REL=true}
-- 1-4. split shapes: original gone, safe ABS moving, REL unsafe REL-only
local foundOrig,absClone,relBarrier=false,nil,nil
for _,row in ipairs(captured) do
 if row==r9008row then foundOrig=true end
 if row.evidence=='PHASER_9008_KNOWN_ABS_SPLIT' then absClone=row end
 if row.evidence=='PHASER_9008_RESIDUAL_REL_BARRIER' then relBarrier=row end
end
assert(not foundOrig and absClone and relBarrier)
assert(absClone.moving==true and absClone.lanes[FG..'|ABS'].moving==true and #(absClone.unsafe or {})==0)
assert(relBarrier.moving==false and relBarrier.layers.REL==true and relBarrier.layers.ABS==nil)
assert(#(relBarrier.unsafe or {})==1)
-- 5+8. unrelated ABS decided; REL barrier noncontributing => PATH B
local olderABS=mkrow(olderA,20,{[11]=true,[12]=true})
r=run({r9008row,olderABS},{att9008},cooked(r9008,false),{[10]=r9008})
assert(r.classification=='PHASER_9008_PARTIAL_SCOPE_PROVEN_REL_NONCONTRIBUTING',r.classification)
assert(has('blocked_references=-'))
assert(has('TRACK_A_RESOLVER_CHECKPOINT') and has('classification=TRACK_A_SEMANTICS_PROVEN'))
-- 6+7. later ABS/REL rows decide first; REL fully superseded => PATH A
local newerABSRow=mkrow(newerA,30,{[11]=true,[12]=true},{moving=true,lanes={[FG..'|ABS']={feature=FG,layer='ABS',moving=true}}})
local newerRELRow=mkrow(newerR,31,{[11]=true,[12]=true},{layers={REL=true},lanes={[FG..'|REL']={feature=FG,layer='REL',moving=true}},moving=true})
r=run({newerRELRow,r9008row,olderABS},{att9008},cooked(r9008,false),{[10]=r9008,[31]=newerR})
assert(r.classification=='PHASER_9008_PARTIAL_SCOPE_PROVEN_REL_SUPERSEDED',r.classification)
-- 6. later ABS row supersedes safe 9008 ABS through normal mechanics
r=run({newerABSRow,r9008row},{att9008},cooked(r9008,false),{[10]=r9008,[30]=newerA})
local absEff=0
for _,row in ipairs(captured) do if row.evidence=='PHASER_9008_KNOWN_ABS_SPLIT' then absEff=row.effective or 0 end end
assert(newerABSRow.effective==2 and absEff==0)
-- 9. older REL candidate blocked by barrier => STILL_REQUIRED
local olderREL=mkrow(olderR,40,{[11]=true},{layers={REL=true},lanes={[FG..'|REL']={feature=FG,layer='REL',moving=false}}})
r=run({r9008row,olderREL},{att9008},cooked(r9008,false),{[10]=r9008})
assert(r.classification=='PHASER_9008_REL_SEMANTICS_STILL_REQUIRED',r.classification)
assert(has('blocked_references=older_REL') or has('older REL'))
-- 4. STILL_REQUIRED emits no proven checkpoint
assert(not has('TRACK_A_RESOLVER_CHECKPOINT'))
-- 6. final_surviving_unsafe is attribution row count, not ref count
attRows={{category='FINAL_SURVIVING_UNSAFE',ref=r9008},{category='FINAL_SURVIVING_UNSAFE',ref=olderA},{category='OTHER'}}
r=run({r9008row,olderABS},{att9008},cooked(r9008,false),{[10]=r9008})
assert(has('final_surviving_unsafe=2'))
attRows={}
-- 7. blocked row with ref=nil must NOT pass Path B
local olderRELNoRef=mkrow(nil,41,{[11]=true},{layers={REL=true},lanes={[FG..'|REL']={feature=FG,layer='REL',moving=false}}})
r=run({r9008row,olderRELNoRef},{att9008},cooked(r9008,false),{[10]=r9008})
assert(r.classification=='PHASER_9008_REL_SEMANTICS_STILL_REQUIRED',r.classification)
assert(has('blocked_older_candidate_lanes=1'))
-- 8. Path A requires balanced supersession accounting
r=run({newerRELRow,r9008row,olderABS},{att9008},cooked(r9008,false),{[10]=r9008,[31]=newerR})
assert(has('rel_barrier_lanes=2 fully_superseded_lanes=2 final_unresolved_lanes=0'))
-- 1. Path B: surviving synthetic barrier excluded by identity => PROVEN, empty
attRows={auto=true}
r=run({r9008row,olderABS},{att9008},cooked(r9008,false),{[10]=r9008})
assert(r.classification=='PHASER_9008_PARTIAL_SCOPE_PROVEN_REL_NONCONTRIBUTING',r.classification)
assert(has('remaining_semantic_blockers=-') and has('classification=TRACK_A_SEMANTICS_PROVEN'))
-- 2. Path B plus unrelated surviving row => INCOMPLETE with that blocker
attRows={auto=true,extra={{category='FINAL_SURVIVING_UNSAFE',ref=olderA}}}
r=run({r9008row,olderABS},{att9008},cooked(r9008,false),{[10]=r9008})
assert(has('remaining_semantic_blockers=older_ABS') and has('classification=TRACK_A_SEMANTICS_INCOMPLETE'))
attRows={}
-- 1. PARTIAL/UNSAFE bridge + ordinary-proven ABS => linked accepted
assert(has('linked_presets=Preset_1.1,Preset_1.11'))
-- 2. motionStaticProven=false => reject
proofs['DBI:'..linkedB.id].motionStaticProven=false
r=run({r9008row},{att9008},cooked(r9008,false))
assert(not has('classification=ABS_STRUCTURE_PROVEN'))
proofs['DBI:'..linkedB.id].motionStaticProven=true
-- 3. memberApplicabilityProven=false => reject
proofs['DBI:'..linkedB.id].memberApplicabilityProven=false
r=run({r9008row},{att9008},cooked(r9008,false))
assert(not has('classification=ABS_STRUCTURE_PROVEN'))
proofs['DBI:'..linkedB.id].memberApplicabilityProven=true
-- 4. REL layer in linked proof => reject for this narrow rule
proofs['DBI:'..linkedB.id].layers={ABS=true,REL=true}
r=run({r9008row},{att9008},cooked(r9008,false))
assert(not has('classification=ABS_STRUCTURE_PROVEN'))
proofs['DBI:'..linkedB.id].layers={ABS=true}
-- 5. activeValue != channels => reject
proofs['DBI:'..linkedB.id].activeValue=57
r=run({r9008row},{att9008},cooked(r9008,false))
assert(not has('classification=ABS_STRUCTURE_PROVEN'))
proofs['DBI:'..linkedB.id].activeValue=58
-- 12. bridge source path still required
bridgeInfo['DBI:'..linkedB.id]={source='OTHER',completeness='PARTIAL',motion='UNSAFE',layers={ABS=true}}
r=run({r9008row},{att9008},cooked(r9008,false))
assert(has('classification=INCONCLUSIVE'))
bridgeInfo['DBI:'..linkedB.id]={source='ORDINARY_GETPRESETDATA',completeness='PARTIAL',motion='UNSAFE',layers={ABS=true}}
-- 13. cooked contradiction does not block structural promotion
r=run({r9008row},{att9008},cooked(olderA,r9008))
assert(has('classification=ABS_STRUCTURE_PROVEN'))
assert(has('abs_different=2') and has('rel_9008=2'))
-- 14. zero new GetPresetData
assert(calls.presetData==0)
assert(has('diagnostic_only=true'))
_G.GetPresetData=nil
print('PASS 9008 split shapes, supersession paths, fail-closed REL, linked gates, cooked cross-check, no new reads')
