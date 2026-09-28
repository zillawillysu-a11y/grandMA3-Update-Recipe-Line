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
local dimmer,color,pan,tilt,big=attr('Dimmer',f1),attr('Color',f1),attr('Pan',f2),attr('Tilt',f2),attr('Big',f1)
local dimmer2=attr('Dimmer',f2) -- same display name, different identity
local uiMap={[0]=dimmer,[1]=color,[2]=pan,[3]=tilt,[4]=dimmer2,[41]=big}
local calledIdx={}
local function channel(index,a) return {INDEX=index,Attribute=a,SUBATTRIBUTE='sub'..tostring(index)} end
local function member(toaddrAttrs,channels)
 local h=handle('Subfixture',toaddrAttrs); h.channels=channels
 function h:ToAddr() return self.label end
 return h
end
local mFull=member('Fixture 201.1.1',{channel(1,dimmer),channel(2,color)})
local mDim=member('Fixture 201.1.2',{channel(1,dimmer)})
local mNone=member('Fixture 201.1.3',{channel(4,tilt)})
local mDup=member('Fixture 201.1.4',{channel(5,dimmer2)})
local mBig=member('Fixture 201.1.5',{channel(42,big)})
local mBadIdx=member('Fixture 201.1.6',{{SUBATTRIBUTE='x'}})
local mZero=member('Fixture 201.1.7',{{INDEX=0,SUBATTRIBUTE='x'}})
local mNilAttr=member('Fixture 201.1.8',{channel(9,dimmer)})
local mEmpty=member('Fixture 201.1.9 confirm',{ })
mEmpty.label='Fixture 201.1.9'
local bySf={[101]=mFull,[102]=mDim,[103]=mNone,[104]=mDup,[105]=mBig,[106]=mBadIdx,[107]=mZero,[108]=mNilAttr,[109]=mEmpty}
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
 getSubfixture=function(sf) return bySf[sf] end,
 compareHandle=function(a,b) return a==b end,
 getUIChannels=function(h) calls.ui=calls.ui+1; return h.channels end,
 attributeByUI=function(i) calledIdx[#calledIdx+1]=i; return uiMap[i] end}
_G.GetPresetData=function() calls.presetData=calls.presetData+1; error('must reuse caches') end
local targets={{key=refKey,path='Preset 4.4'}}
local function run(sfs,buckets)
 logs={}; rows={}; calls.ui=0; calledIdx={}
 for _,spec in ipairs(sfs) do row(spec[1],spec[2],spec[3]) end
 local ctx={records=rows,targets=targets,views={[partKey]={part=part,buckets=buckets}},referenceRaw=referenceRaw,proofs={}}
 return __nativeAttributeCapabilityProbe(ctx,api)
end
local function has(pat) for _,l in ipairs(logs) do if l:find(pat,1,true) then return true end end return false end
local function calledSet() local s={}; for _,i in ipairs(calledIdx) do s[i]=true end; return s end
local function cookedBucket() return {Dimmer={abs_preset=ref},Color={abs_preset=ref}} end
-- 1+2+3. INDEX-1 contract, no competing candidate
local r=run({{101,'ABS'}},{['201.1.1']=cookedBucket()})
assert(r.classification=='GLOBAL_ORDINARY_APPLICABILITY_PROVEN',r.classification)
local cs=calledSet()
assert(cs[0] and cs[1] and not cs[2],'INDEX=1,2 must query 0,1 only')
assert(has('derived_ui_index=0') and has('classification=CHANNEL_RESOLVED'))
r=run({{105,'ABS'}},{['201.1.5']={Big={abs_preset=ref}}})
assert(cs~=nil and calledSet()[41] and not calledSet()[42],'INDEX=42 must query 41 only')
-- 4. invalid/nil INDEX => UNPROVEN
r=run({{106,'ABS'},{107,'ABS'}},{})
assert(r.summary.unproven==2 and r.summary.applicable==0)
assert(has('NATIVE_ATTRIBUTE_ENUMERATION_SUMMARY') and has('invalid_index=2'))
-- 5. lookup nil => UNPROVEN (INDEX=9 derives 8, unmapped)
r=run({{108,'ABS'}},{})
assert(r.summary.unproven==1)
-- empty channels => UNPROVEN, not complete
r=run({{109,'ABS'}},{})
assert(r.summary.unproven==1 and has('empty_channel_members=1'))
-- 6+7. all resolve => complete set; one supported ref attr => APPLICABLE
r=run({{102,'ABS'}},{['201.1.2']={Dimmer={abs_preset=ref}}})
assert(r.summary.expected==1 and has('intersection_count=1'))
assert(has('classification=EXPECTED_PRESET_LINK'))
-- different link => MISMATCH
r=run({{102,'ABS'}},{['201.1.2']={Dimmer={abs_preset=handle('Preset','other')}}})
assert(r.summary.different==1 and has('classification=DIFFERENT_PRESET_LINK'))
-- 8+13. none supported, complete => NOT_APPLICABLE; bucket missing explained
r=run({{103,'ABS'}},{})
assert(r.summary.notApplicable==1 and r.summary.explained==1)
assert(has('classification=BUCKET_ABSENCE_EXPLAINED_BY_NO_COMPATIBLE_ATTRIBUTE'))
-- 9+10. unrelated attrs ignored; same name different identity does not match
r=run({{104,'ABS'}},{['201.1.4']={Dimmer={abs_preset=ref}}})
assert(r.summary.notApplicable==1)
-- 14. applicable but bucket missing => contradiction
r=run({{101,'ABS'}},{})
assert(r.summary.supportedMissing==1 and has('classification=SUPPORTED_ATTRIBUTE_BUT_COOKED_BUCKET_MISSING'))
assert(r.classification=='INCONCLUSIVE')
-- 11+12. FeatureGroups and ABS/REL separated; cache once per member
referenceRaw[refKey][3]={attribute=tilt,[1]={relative=10}}
rows={}; logs={}; calledIdx={}
row(101,'ABS'); row(101,'REL',fg2)
local ctx={records=rows,targets=targets,views={[partKey]={part=part,buckets={['201.1.1']=cookedBucket()}}},referenceRaw=referenceRaw,proofs={}}
r=__nativeAttributeCapabilityProbe(ctx,api)
assert(r.summary.applicable==1 and r.summary.notApplicable==1)
assert(r.capReads==1)
-- 15-19. cache reuse / checkpoints: no GetPresetData, diagnostic-only
local buckets={['201.1.1']=cookedBucket()}
local snapshot={}; for k,v in pairs(buckets) do snapshot[k]=v end
r=run({{101,'ABS'}},buckets)
assert(calls.presetData==0)
for k,v in pairs(buckets) do assert(snapshot[k]==v) end
assert(has('diagnostic_only=true'))
assert(has('GLOBAL_OBJECTLIST_MEMBER_KEY_ALTERNATE'))
_G.GetPresetData=nil
print('PASS INDEX-1 contract, invalid/empty/nil fail closed, intersection, separation, cooked split, cache once, no new reads')
