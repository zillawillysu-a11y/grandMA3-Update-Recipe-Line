local f=assert(io.open('tools/templates/cue_wide_recipe_selective_probe.lua','rb'))
local source=f:read('*a'); f:close(); assert(load(source))()
local nid=0; local function handle(kind,label)
 nid=nid+1; return {id=nid,kind=kind,label=label}
end
local ref=handle('Preset','Preset 2.14'); local other=handle('Preset','other')
local part=handle('Part','Part 1'); local cue=handle('Cue','Cue 1'); local recipe=handle('Recipe','R1'); local group=handle('Group','G1')
local fg1=handle('FeatureGroup','FG1'); local fg2=handle('FeatureGroup','FG2')
local function feature(fg) local f=handle('Feature','F'); function f:Parent() return fg end; return f end
local f1,f2=feature(fg1),feature(fg2)
local function attr(label,feat) local a=handle('Attribute',label); a.Name=label; a.Feature=feat; return a end
local dimmer,color,tilt=attr('Dimmer',f1),attr('Color',f1),attr('Tilt',f2)
local uiMap={[0]=dimmer,[1]=color,[2]=dimmer,[3]=tilt,[5]=dimmer}
local function channel(index) return {INDEX=index,SUBATTRIBUTE='sub'..index} end
local function member(toaddr,channels)
 local h=handle('Subfixture',toaddr); h.channels=channels
 function h:ToAddr() return self.label end
 return h
end
local mA=member('Fixture 201.1.1',{channel(1),channel(2)}) -- ui 0,1
local mB=member('Fixture 201.1.2',{channel(4)}) -- ui 3
local mC=member('Fixture 201.1.3',{channel(6)}) -- ui 5
local bySf={[11]=mA,[12]=mB,[13]=mC}
local refKey,partKey='DBI:'..ref.id,'DBI:'..part.id
local function rawRec(a,abs,extra)
 local r={[1]={absolute=abs},selective=true,preset_store_mode=1,attribute=a}
 for k,v in pairs(extra or {}) do r[k]=v end
 return r
end
local selRaw={[0]=rawRec(dimmer,50,{ui_channel_index=0}),[1]=rawRec(color,60,{ui_channel_index=1})}
local proofs={[refKey]={motionStaticProven=true,memberApplicabilityProven=false,selective={['field=true/dict=nil']=true},layers={ABS=true}}}
local function mkrec(cat,sfs,fg,lane,refH)
 fg=fg or fg1; lane=lane or 'ABS'
 local surviving={}
 for _,sf in ipairs(sfs) do surviving[#surviving+1]=sf..'\0FG:DBI:'..fg.id..'|'..lane end
 return {category=cat,ref=refH or ref,row={part=part,cue=cue,recipe=recipe,group=group,features={['FG:DBI:'..fg1.id]=true}},surviving=surviving}
end
local logs={}; local calls={presetData=0}
local api={log=function(s) logs[#logs+1]=s end,identity=function(h) return h and 'DBI:'..h.id end,
 describe=function(h) return h and h.label end,
 getSubfixture=function(sf) return bySf[sf] end,
 compareHandle=function(a,b) return a==b end,
 getUIChannels=function(h) return h.channels end,
 attributeByUI=function(i) return uiMap[i] end}
_G.GetPresetData=function() calls.presetData=calls.presetData+1; error('must reuse caches') end
local function run(recs,buckets,raw,pr)
 logs={}
 local ctx={records=recs,views={[partKey]={part=part,buckets=buckets}},referenceRaw={[refKey]=raw or selRaw},proofs=pr or proofs,globalPaths={}}
 return __selectiveMemberApplicabilityProbe(ctx,api)
end
local function has(pat) for _,l in ipairs(logs) do if l:find(pat,1,true) then return true end end return false end
local function cooked() return {['201.1.1']={Dimmer={abs_preset=ref},Color={abs_preset=ref}},['201.1.2']={Tilt={abs_preset=ref}}} end
-- 1+10. stored + expected cooked link
local r=run({mkrec('FINAL_SURVIVING_UNSAFE',{11})},cooked())
assert(r.classification=='INCONCLUSIVE')
assert(r.summary.stored==1 and r.summary.expectedLink==1)
assert(has('classification=SELECTIVE_EXPECTED_PRESET_LINK'))
-- rows_expected=3 but only 1 row here
assert(has('rows_expected=3') and has('rows_checked=1'))
-- 2+14. none belongs => NOT_STORED; cooked bucket presence does not gate
r=run({mkrec('FINAL_SURVIVING_UNSAFE',{12})},cooked())
assert(r.summary.notStored==1 and r.summary.stored==0)
assert(has('classification=SELECTIVE_MEMBER_NOT_STORED'))
-- 3+4. one FG attr stored => STORED; other FG lane separate
r=run({mkrec('FINAL_SURVIVING_UNSAFE',{11,12})},cooked())
assert(r.summary.stored==1 and r.summary.notStored==1)
-- 5. REL record does not satisfy ABS lane
local relRaw={[3]=rawRec(tilt,nil,{})}
relRaw[3][1]={relative=10}
r=run({mkrec('FINAL_SURVIVING_UNSAFE',{12})},{},relRaw)
assert(r.summary.notStored==1 and r.summary.stored==0)
-- 6. exact zero-based ownership (ui 5 via INDEX 6)
local raw6={[5]=rawRec(dimmer,70,{ui_channel_index=5})}
r=run({mkrec('FINAL_SURVIVING_UNSAFE',{13})},{['201.1.3']={Dimmer={abs_preset=ref}}},raw6)
assert(r.summary.stored==1 and r.summary.expectedLink==1)
-- 7. same attr on another member does not imply membership
r=run({mkrec('FINAL_SURVIVING_UNSAFE',{13})},cooked(),selRaw)
assert(r.summary.notStored==1)
-- 8. raw UI collision between two members => UNPROVEN
local mD=member('Fixture 201.1.4',{channel(1)})
bySf[14]=mD
r=run({mkrec('FINAL_SURVIVING_UNSAFE',{11,14})},cooked())
assert(r.summary.unproven==2)
bySf[14]=nil
-- 9. numeric key / explicit index disagreement => fail closed
local badRaw={[7]=rawRec(dimmer,70,{ui_channel_index=8})}
local mE=member('Fixture 201.1.5',{channel(8)})
bySf[15]=mE
uiMap[7]=dimmer
r=run({mkrec('FINAL_SURVIVING_UNSAFE',{15})},{},badRaw)
assert(r.summary.unproven==1 and has('BAD_INDEX_RECORD'))
bySf[15]=nil; uiMap[7]=nil
-- 11. different cooked link => MISMATCH
r=run({mkrec('FINAL_SURVIVING_UNSAFE',{11})},{['201.1.1']={Dimmer={abs_preset=other},Color={abs_preset=ref}}})
assert(r.summary.different==1 and has('classification=SELECTIVE_DIFFERENT_PRESET_LINK'))
-- 12+13. cooked attr / bucket missing => unresolved
r=run({mkrec('FINAL_SURVIVING_UNSAFE',{11})},{['201.1.1']={Color={abs_preset=ref}}})
assert(has('classification=SELECTIVE_COOKED_ATTRIBUTE_MISSING'))
r=run({mkrec('FINAL_SURVIVING_UNSAFE',{11})},{})
assert(has('classification=SELECTIVE_COOKED_BUCKET_MISSING'))
-- success path: 3 proven rows => PROVEN + alternate
r=run({mkrec('FINAL_SURVIVING_UNSAFE',{11}),mkrec('FINAL_SURVIVING_UNSAFE',{12}),mkrec('FINAL_SURVIVING_UNSAFE',{11,12})},cooked())
assert(r.summary.checked==3 and r.summary.proven==3, r.summary.checked..'/'..r.summary.proven)
assert(r.classification=='SELECTIVE_MEMBER_APPLICABILITY_PROVEN',r.classification)
assert(has('SELECTIVE_RESOLVER_ALTERNATE') and has('selective_rows_proven=3'))
-- 15. superseded + non-selective rows are not active targets
local nonSelRef=handle('Preset','Preset 9.9')
local pr2={[refKey]=proofs[refKey],['DBI:'..nonSelRef.id]={motionStaticProven=true,memberApplicabilityProven=true,selective={},layers={ABS=true}}}
local recs={mkrec('FINAL_SURVIVING_UNSAFE',{11}),mkrec('FULLY_SUPERSEDED_UNSAFE',{12}),{category='FINAL_SURVIVING_UNSAFE',ref=nonSelRef,row={part=part,cue=cue,recipe=recipe,group=group,features={}},surviving={'12\0FG:DBI:'..fg1.id..'|ABS'}}}
logs={}
local ctx={records=recs,views={[partKey]={part=part,buckets=cooked()}},referenceRaw={[refKey]=selRaw},proofs=pr2,globalPaths={}}
r=__selectiveMemberApplicabilityProbe(ctx,api)
assert(r.summary.checked==1)
-- 16. zero new GetPresetData
assert(calls.presetData==0)
assert(has('diagnostic_only=true'))
_G.GetPresetData=nil
print('PASS selective UI ownership, separation, fail-closed, cooked split, superseded exclusion, no new reads')
