local f=assert(io.open('tools/templates/cue_wide_recipe_selective_probe.lua','rb'))
local source=f:read('*a'); f:close(); assert(load(source))()
local nid=0; local function handle(kind,label)
 nid=nid+1; return {id=nid,kind=kind,label=label}
end
local ref=handle('Preset','Preset 2.14'); local refB=handle('Preset','Preset 2.4'); local other=handle('Preset','other')
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
local mA=member('Fixture 201.1.1',{channel(1),channel(2)}) -- ui 0,1 FG1
local mB=member('Fixture 201.1.2',{channel(4)}) -- ui 3 FG2
local mC=member('Fixture 201.1.3',{channel(6)}) -- ui 5 FG1
local bySf={[11]=mA,[12]=mB,[13]=mC}
local refKey,partKey='DBI:'..ref.id,'DBI:'..part.id
local function rawRec(a,abs,extra)
 local r={[1]={absolute=abs},selective=true,preset_store_mode=1,attribute=a}
 for k,v in pairs(extra or {}) do r[k]=v end
 return r
end
local selRaw={[0]=rawRec(dimmer,50,{ui_channel_index=0}),[1]=rawRec(color,60,{ui_channel_index=1})}
local proofs={[refKey]={motionStaticProven=true,memberApplicabilityProven=false,selective={['field=true/dict=nil']=true},layers={ABS=true}}}
-- REAL native shape: wildcard barrier suffix, member identity only.
local function mkrec(cat,sfs,refH)
 local surviving={}
 for _,sf in ipairs(sfs) do surviving[#surviving+1]=sf..'\0*' end
 return {category=cat,ref=refH or ref,row={part=part,cue=cue,recipe=recipe,group=group,features={},layers={}},surviving=surviving}
end
local logs={}; local calls={presetData=0}
local api={log=function(s) logs[#logs+1]=s end,identity=function(h) return h and 'DBI:'..h.id end,
 describe=function(h) return h and h.label end,
 getSubfixture=function(sf) return bySf[sf] end,
 compareHandle=function(a,b) return a==b end,
 getUIChannels=function(h) return h.channels end,
 attributeByUI=function(i) return uiMap[i] end}
_G.GetPresetData=function() calls.presetData=calls.presetData+1; error('must reuse caches') end
local function run(recs,buckets,raw,pr,rawMap)
 logs={}
 local ctx={records=recs,views={[partKey]={part=part,buckets=buckets}},referenceRaw=rawMap or {[refKey]=raw or selRaw},proofs=pr or proofs,globalPaths={}}
 return __selectiveMemberApplicabilityProbe(ctx,api)
end
local function has(pat) for _,l in ipairs(logs) do if l:find(pat,1,true) then return true end end return false end
local function cooked() return {['201.1.1']={Dimmer={abs_preset=ref},Color={abs_preset=ref}},['201.1.2']={Tilt={abs_preset=ref}}} end
-- 1+5+8. wildcard member + reference FG ABS => concrete lane, STORED + expected link
local r=run({mkrec('FINAL_SURVIVING_UNSAFE',{11})},cooked())
assert(r.classification=='INCONCLUSIVE')
assert(r.summary.stored==1 and r.summary.expectedLink==1)
assert(has('candidate_feature=FG:DBI:') and has('layer=ABS'))
assert(has('classification=SELECTIVE_EXPECTED_PRESET_LINK'))
assert(has('SELECTIVE_SCOPE_REFERENCE') and has('classification=SELECTIVE_SCOPE_PROVEN'))
-- 6. member with no matching UI => NOT_STORED
r=run({mkrec('FINAL_SURVIVING_UNSAFE',{12})},cooked())
assert(r.summary.notStored==1 and r.summary.stored==0)
assert(has('classification=SELECTIVE_MEMBER_NOT_STORED'))
-- 2. multiple reference FGs => multiple concrete observer lanes
local twoFG={[0]=rawRec(dimmer,50,{ui_channel_index=0}),[3]=rawRec(tilt,55,{ui_channel_index=3})}
r=run({mkrec('FINAL_SURVIVING_UNSAFE',{11})},cooked(),twoFG)
assert(r.summary.stored==1 and r.summary.notStored==1)
assert(has('feature_groups=2'))
-- 3. invalid raw ABS scope => fail closed
local badRaw={[0]=rawRec(dimmer,50,{ui_channel_index=0}),[9]=rawRec(color,60,{ui_channel_index=77})}
r=run({mkrec('FINAL_SURVIVING_UNSAFE',{11})},cooked(),badRaw)
assert(r.summary.unproven==1 and has('classification=SELECTIVE_SCOPE_INCOMPLETE'))
-- 4. no valid ABS scope => UNPROVEN
local relOnly={[3]=rawRec(tilt,nil,{})}
relOnly[3][1]={relative=10}
r=run({mkrec('FINAL_SURVIVING_UNSAFE',{12})},{},relOnly)
assert(r.summary.unproven==1 and has('classification=SELECTIVE_SCOPE_EMPTY'))
-- 7. same Attribute on another member does not imply stored
r=run({mkrec('FINAL_SURVIVING_UNSAFE',{13})},cooked(),selRaw)
assert(r.summary.notStored==1)
-- 9. different cooked link => MISMATCH
r=run({mkrec('FINAL_SURVIVING_UNSAFE',{11})},{['201.1.1']={Dimmer={abs_preset=other},Color={abs_preset=ref}}})
assert(r.summary.different==1 and has('classification=SELECTIVE_DIFFERENT_PRESET_LINK'))
-- 10+11. missing cooked Attribute / bucket => unresolved
r=run({mkrec('FINAL_SURVIVING_UNSAFE',{11})},{['201.1.1']={Color={abs_preset=ref}}})
assert(has('classification=SELECTIVE_COOKED_ATTRIBUTE_MISSING'))
r=run({mkrec('FINAL_SURVIVING_UNSAFE',{11})},{})
assert(has('classification=SELECTIVE_COOKED_BUCKET_MISSING'))
-- success path: 3 proven wildcard rows => PROVEN + alternate with row counts
r=run({mkrec('FINAL_SURVIVING_UNSAFE',{11}),mkrec('FINAL_SURVIVING_UNSAFE',{12}),mkrec('FINAL_SURVIVING_UNSAFE',{11,12})},cooked())
assert(r.summary.checked==3 and r.summary.proven==3, r.summary.checked..'/'..r.summary.proven)
assert(r.classification=='SELECTIVE_MEMBER_APPLICABILITY_PROVEN',r.classification)
assert(has('SELECTIVE_RESOLVER_ALTERNATE') and has('selective_rows_proven=3'))
assert(has('remaining_final_surviving_unsafe_rows=0'))
-- 12. fully superseded 2.28-style row excluded
local pr2={[refKey]=proofs[refKey]}
local recs={mkrec('FINAL_SURVIVING_UNSAFE',{11}),mkrec('FULLY_SUPERSEDED_UNSAFE',{12})}
logs={}
local ctx={records=recs,views={[partKey]={part=part,buckets=cooked()}},referenceRaw={[refKey]=selRaw},proofs=pr2,globalPaths={}}
r=__selectiveMemberApplicabilityProbe(ctx,api)
assert(r.summary.checked==1)
-- 13. zero new GetPresetData
assert(calls.presetData==0)
assert(has('diagnostic_only=true'))
_G.GetPresetData=nil
print('PASS wildcard barriers, FG expansion, scope fail-closed, stored/not-stored, cooked split, alternate counts, no new reads')
