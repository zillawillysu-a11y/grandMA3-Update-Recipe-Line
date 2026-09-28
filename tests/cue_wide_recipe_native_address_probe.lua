local f=assert(io.open('tools/templates/cue_wide_recipe_native_address_probe.lua','rb'))
local source=f:read('*a'); f:close(); assert(load(source))()
local function handle(id,addr,addrNative,toaddr,desc,noMethod)
 local h={id=id,addr=addr,addrNative=addrNative,toaddr=toaddr,desc=desc}
 function h:Addr() return self.addr end
 function h:AddrNative() return self.addrNative end
 if not noMethod then function h:ToAddr() return self.toaddr end end
 return h
end
local byAddr={}
local function register(h) for _,v in pairs({h.addr,h.addrNative,h.toaddr}) do if v~=nil then byAddr[v]=h end end end
local preset={id=500}; local part={id=600}
local handles={}
local logs={}
local calls={presetData=0}
local api={log=function(s) logs[#logs+1]=s end,identity=function(h) return h and 'DBI:'..h.id end,
 describe=function(h) return h and h.desc end,
 getSubfixture=function(sf) return handles[sf] end,
 compareHandle=function(a,b) return a==b end,
 fromAddr=function(a) return byAddr[a] end,
 toAddr=function(h) return h and h.toaddr end}
_G.GetPresetData=function() calls.presetData=calls.presetData+1; error('must reuse cooked cache') end
local function run(ids,buckets)
 logs={}; local cases={}
 for _,sf in ipairs(ids) do cases[#cases+1]={sf=sf,part=part,expected=preset,attributes={'Dimmer'},layer='ABS'} end
 return __nativeMemberAddressProbe(cases,{['DBI:600']={part=part,buckets=buckets}},api)
end
local function bucket() return {Dimmer={abs_preset=preset}} end
local function has(pat) for _,l in ipairs(logs) do if l:find(pat,1,true) then return true end end return false end
-- 1. full DB Addr path + ToAddr Fixture 201.1.1 => key must be 201.1.1
handles[93]=handle(93,'14.9.7.1.2.3.201.1.1','ShowData.LivePatch.Stages.Stage 1.Fixtures.Plate.Plate_Pixel_Group_1','Fixture 201.1.1','Fixture 201.1.1 [#93]')
register(handles[93])
local r=run({93},{['201.1.1']=bucket()})
assert(r.classification=='NATIVE_TOADDR_MEMBER_KEY_PROVEN',r.classification)
assert(has('toaddr_fixture_key=201.1.1') and has('toaddr_roundtrip_same_handle=true'))
assert(has('cooked_bucket_exists=true') and has('expected_preset_link_present=true'))
-- 2. arbitrary numeric Addr must NOT override ToAddr
handles[7]=handle(7,'14.9.7.9.9.9','ShowData.Other','Fixture 5.2','Fixture 5.2 [#7]'); register(handles[7])
r=run({7},{['5.2']=bucket()})
assert(r.classification=='NATIVE_TOADDR_MEMBER_KEY_PROVEN',r.classification)
assert(has('toaddr_fixture_key=5.2'))
-- 3. AddrNative failure must NOT suppress ToAddr round-trip test
byAddr['ShowData.Other']=nil
r=run({7},{['5.2']=bucket()})
assert(r.classification=='NATIVE_TOADDR_MEMBER_KEY_PROVEN',r.classification)
assert(r.summary.roundtrip==1)
byAddr['ShowData.Other']=handles[7]
-- 4. FromAddr(ToAddr()) same handle => proven (covered above); wrong handle fails
byAddr['Fixture 5.2']=handle(99,'x','y','Fixture 5.2','other')
r=run({7},{['5.2']=bucket()})
assert(r.classification=='UNPROVEN' and r.summary.roundtrip==0)
byAddr['Fixture 5.2']=handles[7]
-- global ToAddr fallback when method unavailable
handles[8]=handle(8,'14.1.1','ShowData.G','Fixture 6.1','Fixture 6.1 [#8]',true); register(handles[8])
r=run({8},{['6.1']=bucket()})
assert(r.classification=='NATIVE_TOADDR_MEMBER_KEY_PROVEN',r.classification)
assert(has('toaddr_fixture_key=6.1'))
-- 5. cooked bucket exists / Attribute absent => member key proven, Attribute unresolved
handles[3]=handle(3,'14.9.7.1.2.3.401.4','ShowData.N','Fixture 401.4','Fixture 401.4 [#3]'); register(handles[3])
r=run({3},{['401.4']={Color={abs_preset=preset}}})
assert(r.summary.bucket==1 and r.summary.attrAbsent==1 and r.summary.missing==0)
assert(has('classification=MEMBER_KEY_PROVEN_ATTRIBUTE_UNRESOLVED'))
assert(r.classification=='NATIVE_TOADDR_MEMBER_KEY_PROVEN',r.classification)
-- bucket missing is a different problem
r=run({3},{})
assert(r.summary.missing==1 and r.summary.bucket==0)
assert(has('classification=BUCKET_MISSING'))
assert(r.classification=='UNPROVEN')
-- 6. sf_index unrelated valid bucket => accidental collision only
handles[9]=handle(9,'14.9.7.1.2.3.201.1.2','ShowData.M','Fixture 201.1.2','Fixture 201.1.2 [#9]'); register(handles[9])
r=run({9},{['201.1.2']=bucket(),['9']=bucket()})
assert(r.collisions.sf>=1 and r.collisions.same==0)
assert(has('classification=SF_INDEX_ACCIDENTAL_BUCKET_COLLISION'))
assert(r.summary.collision==0 and r.classification=='NATIVE_TOADDR_MEMBER_KEY_PROVEN')
handles[9]=nil; byAddr['Fixture 201.1.2']=nil; byAddr['9']=nil; byAddr['14.9.7.1.2.3.201.1.2']=nil; byAddr['ShowData.M']=nil
-- 7. true duplicate ToAddr key => collision / UNPROVEN
handles[4]=handle(4,'14.9.7.1.2.3.201.1.1','ShowData.D','Fixture 201.1.1','Fixture 201.1.1 [#4]'); register(handles[4])
byAddr['Fixture 201.1.1']=handles[4]
r=run({93,4},{['201.1.1']=bucket()})
assert(r.summary.collision>0 and r.classification=='UNPROVEN')
byAddr['Fixture 201.1.1']=handles[93]; handles[4]=nil
-- 8-11. cache reuse / truth isolation: no GetPresetData, views unmodified, diagnostic-only markers
local buckets={['201.1.1']=bucket()}
local snapshot={}; for k,v in pairs(buckets) do snapshot[k]=v end
r=run({93},buckets)
assert(calls.presetData==0)
for k,v in pairs(buckets) do assert(snapshot[k]==v) end
assert(has('diagnostic_only=true'))
assert(has('GLOBAL_TOADDR_MEMBER_KEY_ALTERNATE') and has('mapped_lanes=1'))
assert(has('OLD_SF_INDEX_COLLISION_SUMMARY') and has('classification=NO_RESIDUAL'))
assert(has('TOADDR_MEMBER_KEY_SAMPLE') and has('TOADDR_MEMBER_KEY_SUMMARY'))
_G.GetPresetData=nil
print('PASS toaddr primary key, numeric Addr ignored, native failure isolated, round-trip, attribute-unresolved, bucket-missing, sf collision, duplicate collision, cache reuse')
