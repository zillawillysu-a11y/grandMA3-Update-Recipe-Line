local f=assert(io.open('tools/templates/cue_wide_recipe_attribute_capability_probe.lua','rb'))
local source=f:read('*a'); f:close(); assert(load(source))()
local nid=0; local function handle(kind,label,extra)
 nid=nid+1; local h={id=nid,kind=kind,label=label}; for k,v in pairs(extra or {}) do h[k]=v end; return h
end
local ref=handle('Preset','Preset 4.4'); local part=handle('Part','Part 3')
local fg1=handle('FeatureGroup','FG1'); local fg2=handle('FeatureGroup','FG2')
local function feature(fg) local f=handle('Feature','F'); function f:Parent() return fg end; return f end
local f1,f2=feature(fg1),feature(fg2)
local function attr(label,feat) local a=handle('Attribute',label); a.Name=label; a.Feature=feat; return a end
local dimmer,color,pan,tilt=attr('Dimmer',f1),attr('Color',f1),attr('Pan',f2),attr('Tilt',f2)
local dimmer2=attr('Dimmer',f2) -- same display name, different identity
local uiMap={[0]=dimmer,[1]=color,[2]=pan,[3]=tilt,[4]=dimmer2}
local function channel(index,a) return {INDEX=index,Attribute=a,SUBATTRIBUTE='sub'..index} end
local members={}
local function member(toaddrAttrs,channels)
 local h=handle('Subfixture',toaddrAttrs); h.channels=channels
 function h:ToAddr() return self.label end
 members[#members+1]=h; return h
end
local mFull=member('Fixture 201.1.1',{channel(1,dimmer),channel(2,color)})
local mDim=member('Fixture 201.1.2',{channel(1,dimmer)})
local mNone=member('Fixture 201.1.3',{channel(3,tilt)})
local mDup=member('Fixture 201.1.4',{channel(5,dimmer2)})
local refKey,partKey='DBI:'..ref.id,'DBI:'..part.id
local referenceRaw={[refKey]={[0]={attribute=dimmer,[1]={absolute=50}},[1]={attribute=color,[1]={absolute=60}},[2]={attribute=pan,[1]={absolute=70}}}}
local rows={}
local function row(m,lane,fg)
 fg=fg or fg1
 rows[#rows+1]={category='FINAL_SURVIVING_UNSAFE',ref=ref,row={part=part,features={['FG:DBI:'..fg1.id]=true,['FG:DBI:'..fg2.id]=true}},surviving={m..'\0FG:DBI:'..fg.id..'|'..lane}}
end
local logs={}; local calls={presetData=0,ui=0}
local api={log=function(s) logs[#logs+1]=s end,identity=function(h) return h and 'DBI:'..h.id end,
 describe=function(h) return h and h.label end,
 getSubfixture=function(sf) for _,m in ipairs({mFull,mDim,mNone,mDup}) do if m._sf==sf then return m end end end,
 compareHandle=function(a,b) return a==b end,
 getUIChannels=function(h) calls.ui=calls.ui+1; return h.channels end,
 attributeByUI=function(i) return uiMap[i] end}
_G.GetPresetData=function() calls.presetData=calls.presetData+1; error('must reuse caches') end
mFull._sf=101; mDim._sf=102; mNone._sf=103; mDup._sf=104
local targets={{key=refKey,path='Preset 4.4'}}
local function run(sfs,buckets)
 logs={}; rows={}; calls.ui=0
 for _,spec in ipairs(sfs) do row(spec[1],spec[2]) end
 local ctx={records=rows,targets=targets,views={[partKey]={part=part,buckets=buckets}},referenceRaw=referenceRaw,proofs={}}
 return __nativeAttributeCapabilityProbe(ctx,api)
end
local function has(pat) for _,l in ipairs(logs) do if l:find(pat,1,true) then return true end end return false end
local function cookedBucket() return {Dimmer={abs_preset=ref},Color={abs_preset=ref}} end
-- 1+4+6. supports one of many ref attrs, exact identity, expected link
local r=run({{101,'ABS'}},{['201.1.1']=cookedBucket()})
assert(r.classification=='GLOBAL_ORDINARY_APPLICABILITY_PROVEN',r.classification)
assert(r.summary.expected==1 and has('intersection_count=2'))
assert(has('classification=EXPECTED_PRESET_LINK'))
-- 3. unrelated attrs present in ref but only intersection compared
r=run({{102,'ABS'}},{['201.1.2']={Dimmer={abs_preset=ref}}})
assert(r.summary.expected==1 and has('intersection_count=1'))
-- 7. different link => mismatch
r=run({{102,'ABS'}},{['201.1.2']={Dimmer={abs_preset=handle('Preset','other')}}})
assert(r.summary.different==1 and has('classification=DIFFERENT_PRESET_LINK'))
-- 2+9. supports none, complete enum => NOT_APPLICABLE; bucket missing explained
r=run({{103,'ABS'}},{})
assert(r.summary.notApplicable==1 and r.summary.explained==1)
assert(has('classification=BUCKET_ABSENCE_EXPLAINED_BY_NO_COMPATIBLE_ATTRIBUTE'))
-- 5. same display name, different identity => no match
r=run({{104,'ABS'}},{['201.1.4']={Dimmer={abs_preset=ref}}})
assert(r.summary.notApplicable==1)
-- 8. applicable but bucket missing => unresolved contradiction
r=run({{101,'ABS'}},{})
assert(r.summary.supportedMissing==1 and has('classification=SUPPORTED_ATTRIBUTE_BUT_COOKED_BUCKET_MISSING'))
assert(r.classification=='INCONCLUSIVE')
-- 10+11. FeatureGroups and ABS/REL separated
referenceRaw[refKey][3]={attribute=tilt,[1]={relative=10}}
rows={}; logs={}
row(101,'ABS'); row(101,'REL',fg2)
local ctx={records=rows,targets=targets,views={[partKey]={part=part,buckets={['201.1.1']=cookedBucket()}}},referenceRaw=referenceRaw,proofs={}}
r=__nativeAttributeCapabilityProbe(ctx,api)
assert(r.summary.applicable==1 and r.summary.notApplicable==1)
-- REL lane has no Tilt support on mFull (Dimmer/Color only) while ref REL has Tilt
-- 12. capability cached once per member
assert(r.capReads==1)
-- 13. no new GetPresetData
assert(calls.presetData==0)
assert(has('diagnostic_only=true') and has('GLOBAL_OBJECTLIST_MEMBER_KEY_ALTERNATE'))
-- ambiguous convention fails closed
local mAmb=member('Fixture 201.1.9',{channel(1,dimmer)})
mAmb._sf=109
local oldUI=api.getSubfixture
api.getSubfixture=function(sf) if sf==109 then return mAmb end return oldUI(sf) end
uiMap[-0]=nil
local saveMap={}; for k,v in pairs(uiMap) do saveMap[k]=v end
for k in pairs(uiMap) do uiMap[k]=nil end
uiMap[0]=dimmer; uiMap[1]=dimmer -- both conventions resolve everywhere
r=run({{109,'ABS'}},{['201.1.9']=cookedBucket()})
assert(r.summary.unproven==1 and r.summary.applicable==0)
for k in pairs(uiMap) do uiMap[k]=nil end
for k,v in pairs(saveMap) do uiMap[k]=v end
api.getSubfixture=oldUI
_G.GetPresetData=nil
print('PASS capability intersection, identity, separation, cooked split, cache once, fail closed, no new reads')
