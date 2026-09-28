local f=assert(io.open('tools/templates/cue_wide_recipe_native_address_probe.lua','rb'))
local source=f:read('*a'); f:close(); assert(load(source))()
local function handle(id,addr,addrNative,toaddr,desc)
 local h={id=id,addr=addr,addrNative=addrNative,toaddr=toaddr,desc=desc}
 function h:Addr() return self.addr end
 function h:AddrNative() return self.addrNative end
 function h:ToAddr() return self.toaddr end
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
-- 1. native Addr maps exact cooked key
handles[1]=handle(1,'401.1','401.1',nil,'Fixture 401.1 [#1]'); register(handles[1])
local r=run({1},{['401.1']=bucket()})
assert(r.classification=='NATIVE_HIERARCHICAL_MEMBER_KEY_PROVEN',r.classification)
assert(r.summary.roundtrip==1 and r.summary.bucket==1 and r.summary.collision==0)
assert(has('NATIVE_MEMBER_ADDRESS_SAMPLE') and has('normalized_fixture_address=401.1'))
assert(has('cooked_bucket_exists=true') and has('expected_attribute_present=true'))
assert(has('addr_roundtrip_same_handle=true'))
-- 2. nested SubFixture native address with non-bare raw form
handles[2]=handle(2,nil,'Fixture 201.1.1',nil,'Fixture 201.1.1 [#2]'); register(handles[2])
r=run({2},{['201.1.1']=bucket()})
assert(r.classification=='NATIVE_HIERARCHICAL_MEMBER_KEY_PROVEN',r.classification)
assert(has('normalized_fixture_address=201.1.1'))
-- 3. FromAddr round-trip proves same handle (asserted via summary above); wrong handle fails
byAddr['401.1']=handle(99,'401.1','401.1',nil,'other')
r=run({1},{['401.1']=bucket()})
assert(r.classification=='UNPROVEN' and r.summary.roundtrip==0)
byAddr['401.1']=handles[1]
-- 4. bucket exists but Attribute absent => member key proven, Attribute unresolved
handles[3]=handle(3,'401.4','401.4',nil,'Fixture 401.4 [#3]'); register(handles[3])
r=run({3},{['401.4']={Color={abs_preset=preset}}})
assert(r.summary.bucket==1 and r.summary.attrAbsent==1)
assert(has('classification=MEMBER_KEY_PROVEN_ATTRIBUTE_UNRESOLVED'))
assert(r.classification=='NATIVE_HIERARCHICAL_MEMBER_KEY_PROVEN')
-- 5. sf_index points to unrelated valid bucket => accidental collision, member still proven
handles[9]=handle(9,'201.1.2','201.1.2',nil,'Fixture 201.1.2 [#9]'); register(handles[9])
r=run({9},{['201.1.2']=bucket(),['9']=bucket()})
assert(r.collisions.sf>=1 and r.collisions.same==0)
assert(has('classification=SF_INDEX_ACCIDENTAL_BUCKET_COLLISION'))
assert(r.summary.collision==0)
handles[9]=nil; byAddr['9']=nil
-- 6. actual duplicate native key => collision / UNPROVEN
handles[4]=handle(4,'201.1.1','201.1.1',nil,'Fixture 201.1.1 [#4]'); register(handles[4])
byAddr['201.1.1']=handles[4]
r=run({2,4},{['201.1.1']=bucket()})
assert(r.summary.collision>0 and r.classification=='UNPROVEN')
byAddr['201.1.1']=handles[2]; handles[4]=nil
-- 7-9. cache reuse / truth isolation: no GetPresetData, views unmodified, diagnostic-only markers
local buckets={['401.1']=bucket()}
local snapshot={}; for k,v in pairs(buckets) do snapshot[k]=v end
r=run({1},buckets)
assert(calls.presetData==0)
for k,v in pairs(buckets) do assert(snapshot[k]==v) end
assert(has('diagnostic_only=true'))
assert(has('GLOBAL_NATIVE_MEMBER_KEY_ALTERNATE') and has('mapped_lanes=1'))
assert(has('OLD_SF_INDEX_COLLISION_SUMMARY') and has('classification=NO_RESIDUAL'))
_G.GetPresetData=nil
print('PASS native Addr exact key, nested address, round-trip, attribute-unresolved, sf collision, duplicate collision, cache reuse')
