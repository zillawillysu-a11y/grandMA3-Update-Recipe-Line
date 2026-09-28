local f=assert(io.open('tools/templates/cue_wide_recipe_native_address_probe.lua','rb'))
local source=f:read('*a'); f:close(); assert(load(source))()
local function handle(id,toaddr,desc,noMethod)
 local h={id=id,toaddr=toaddr,desc=desc}
 function h:Addr() return '14.9.7.1.2.3.'..(toaddr:match('Fixture%s+(.+)$') or '?') end
 function h:AddrNative() return 'ShowData.LivePatch.Handle'..id end
 if not noMethod then function h:ToAddr() return self.toaddr end end
 return h
end
local registry={}
local function register(h) registry[h.toaddr]={h} end
local preset={id=500}; local part={id=600}
local handles={}
local logs={}
local calls={presetData=0}
local api={log=function(s) logs[#logs+1]=s end,identity=function(h) return h and 'DBI:'..h.id end,
 describe=function(h) return h and h.desc end,
 getSubfixture=function(sf) return handles[sf] end,
 compareHandle=function(a,b) return a==b end,
 objectList=function(cmd) return registry[cmd] end,
 toAddr=function(h) return h and h.toaddr end}
_G.GetPresetData=function() calls.presetData=calls.presetData+1; error('must reuse cooked cache') end
local function run(ids,buckets)
 logs={}; local cases={}
 for _,sf in ipairs(ids) do cases[#cases+1]={sf=sf,part=part,expected=preset,attributes={'Dimmer'},layer='ABS'} end
 return __nativeMemberAddressProbe(cases,{['DBI:600']={part=part,buckets=buckets}},api)
end
local function bucket() return {Dimmer={abs_preset=preset}} end
local function has(pat) for _,l in ipairs(logs) do if l:find(pat,1,true) then return true end end return false end
-- 1+2. ObjectList returns original child handle; nested address
handles[93]=handle(93,'Fixture 201.1.1','Fixture 201.1.1 [#93]'); register(handles[93])
handles[94]=handle(94,'Fixture 201.1.2','Fixture 201.1.2 [#94]'); register(handles[94])
local r=run({93,94},{['201.1.1']=bucket(),['201.1.2']=bucket()})
assert(r.classification=='NATIVE_TOADDR_OBJECTLIST_MEMBER_KEY_PROVEN',r.classification)
assert(r.summary.resolved==2 and r.summary.collision==0)
assert(has('fixture_key=201.1.1') and has('objectlist_same_handle=true'))
-- 3. exactly one same handle => proven (above); 4. zero results => unresolved
registry['Fixture 201.1.2']=nil
r=run({94},{['201.1.2']=bucket()})
assert(r.summary.unresolved==1 and r.summary.resolved==0 and r.classification=='UNPROVEN')
assert(has('classification=OBJECTLIST_UNRESOLVED'))
registry['Fixture 201.1.2']={handles[94]}
-- 5. multiple distinct handles => ambiguous
local other=handle(99,'Fixture 201.1.2','other')
registry['Fixture 201.1.2']={handles[94],other}
r=run({94},{['201.1.2']=bucket()})
assert(r.summary.ambiguous==1 and r.classification=='UNPROVEN')
assert(has('classification=OBJECTLIST_AMBIGUOUS'))
registry['Fixture 201.1.2']={handles[94]}
-- 6. wrong handle => fail closed
registry['Fixture 201.1.1']={other}
r=run({93},{['201.1.1']=bucket()})
assert(r.summary.wrong==1 and r.classification=='UNPROVEN')
assert(has('classification=OBJECTLIST_WRONG_HANDLE'))
registry['Fixture 201.1.1']={handles[93]}
-- 7. duplicate canonical ToAddr key => collision
handles[4]=handle(4,'Fixture 201.1.1','Fixture 201.1.1 [#4]')
registry['Fixture 201.1.1']={handles[93]}
r=run({93,4},{['201.1.1']=bucket()})
assert(r.summary.collision>0 and r.classification=='UNPROVEN')
handles[4]=nil
-- 8. member identity proven even when cooked bucket absent
r=run({93},{})
assert(r.summary.bucketMissing==1 and r.summary.bucketExists==0)
assert(r.classification=='NATIVE_TOADDR_OBJECTLIST_MEMBER_KEY_PROVEN',r.classification)
assert(has('TOADDR_COOKED_BUCKET_MISSING_SUMMARY') and has('classification=APPLICABILITY_OR_CAPABILITY_UNRESOLVED'))
-- 9. cooked exists + missing == unique
r=run({93,94},{['201.1.1']=bucket()})
assert(r.summary.bucketExists==1 and r.summary.bucketMissing==1 and r.summary.unique==2)
assert(r.summary.bucketExists+r.summary.bucketMissing==r.summary.unique)
-- 10. bucket missing does not become preset mismatch
assert(has('GLOBAL_OBJECTLIST_MEMBER_KEY_ALTERNATE') and has('bucket_missing_lanes=1'))
assert(has('different_preset_lanes=0'))
assert(has('mapped_bucket_lanes=1') and has('expected_preset_evidence_lanes=1'))
-- sf accidental collision preserved
handles[9]=handle(9,'Fixture 201.1.2','Fixture 201.1.2 [#9]')
registry['Fixture 201.1.2']={handles[9]}
r=run({9},{['201.1.2']=bucket(),['9']=bucket()})
assert(r.collisions.sf>=1 and r.collisions.same==0 and r.summary.collision==0)
assert(has('classification=SF_INDEX_ACCIDENTAL_BUCKET_COLLISION'))
assert(r.classification=='NATIVE_TOADDR_OBJECTLIST_MEMBER_KEY_PROVEN',r.classification)
handles[9]=nil; registry['Fixture 201.1.2']={handles[94]}
-- 11. zero additional GetPresetData; views unmodified; diagnostic-only
local buckets={['201.1.1']=bucket()}
local snapshot={}; for k,v in pairs(buckets) do snapshot[k]=v end
r=run({93},buckets)
assert(calls.presetData==0)
for k,v in pairs(buckets) do assert(snapshot[k]==v) end
assert(has('diagnostic_only=true'))
assert(has('OBJECTLIST_MEMBER_KEY_SAMPLE') and has('OBJECTLIST_MEMBER_KEY_SUMMARY'))
assert(has('OLD_SF_INDEX_COLLISION_SUMMARY') and has('classification=NO_RESIDUAL'))
_G.GetPresetData=nil
print('PASS objectlist identity, unresolved, ambiguous, wrong handle, collision, bucket-absent proof, cooked split, alternate, cache reuse')
