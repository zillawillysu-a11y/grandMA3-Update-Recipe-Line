-- Diagnostic only: ToAddr command-address member key versus cooked
-- by_fixtures keys. Observer only, never resolver rules.
-- Addr() full internal DB paths and AddrNative() show paths are
-- observation-only and must never derive the cooked key.
-- Reuses the cooked bucket cache; performs no GetPresetData calls.
function __nativeMemberAddressProbe(cases,views,api)
 local function safe(f,...) local ok,v=pcall(f,...); if ok then return v end end
 local function emit(fmt,...) api.log(string.format(fmt,...)) end
 local function txt(v) return v==nil and 'nil' or tostring(v):gsub('[\r\n, ]','_'):sub(1,100) end
 local function raw(v)
  if v==nil then return 'nil' end
  local t=type(v)
  if t=='string' or t=='number' then return tostring(v):gsub('[\r\n]','_'):sub(1,120) end
  return 'type='..t
 end
 local function same(a,b)
  if a==b then return true end
  local v=api.compareHandle and safe(api.compareHandle,a,b)
  if v==true then return true end
  local ia=a and safe(api.identity,a); local ib=b and safe(api.identity,b)
  return ia~=nil and ia==ib
 end
 local function validKey(a) return type(a)=='string' and a:match('^%d+[%.%d]*$') and not a:find('%.%.',1,true) and not a:match('%.$') end
 -- Accept only explicit command-style Fixture address: "Fixture 201.1.1".
 local function toaddrKey(v)
  if type(v)~='string' then return nil end
  local s=v:gsub('^%s+',''):gsub('%s+$','')
  local key=s:match('^Fixture%s+(%d+[%.%d]*)$')
  return validKey(key) and key or nil
 end
 local fromAddr=api.fromAddr or safe(function() return _G.FromAddr end)
 local members={}
 for _,case in ipairs(cases or {}) do if case.sf and not members[case.sf] then
  local h=api.getSubfixture and safe(api.getSubfixture,case.sf)
  local addr=h and safe(function() return h:Addr() end)
  local addrNative=h and safe(function() return h:AddrNative() end)
  local toaddr=h and safe(function() return h:ToAddr() end)
  local globalTo=api.toAddr and safe(api.toAddr,h)
  if globalTo==nil then
   local g=safe(function() return _G.ToAddr end)
   if type(g)=='function' then globalTo=safe(g,h) end
  end
  local key=toaddrKey(toaddr)
  local keySource=key and 'method' or nil
  if key==nil then key=toaddrKey(globalTo); keySource=key and 'global' or nil end
  members[case.sf]={h=h,addr=addr,addrNative=addrNative,toaddr=toaddr,globalTo=globalTo,key=key,keySource=keySource,cases={}}
 end
 if case.sf and members[case.sf] then members[case.sf].cases[#members[case.sf].cases+1]=case end end
 local summary={problematic=#(cases or {}),unique=0,available=0,normalized=0,roundtrip=0,bucket=0,attrPresent=0,attrAbsent=0,missing=0,collision=0}
 local alternate={mapped=0,expected=0,different=0,unresolved=0}
 local collisions={sf=0,same=0}
 local ordered={}; for sf in pairs(members) do ordered[#ordered+1]=sf end; table.sort(ordered)
 local reverse={}
 local sampleN=0
 for _,sf in ipairs(ordered) do
  local m=members[sf]; summary.unique=summary.unique+1
  if m.toaddr~=nil or m.globalTo~=nil then summary.available=summary.available+1 end
  if m.key~=nil then summary.normalized=summary.normalized+1 end
  -- Every candidate round-trips independently; no fallback-on-nil logic.
  local function roundtrip(v)
   if v==nil or fromAddr==nil then return nil end
   local back=safe(fromAddr,v)
   if back==nil then return false end
   return same(back,m.h)
  end
  local rtAddr,rtNative=roundtrip(m.addr),roundtrip(m.addrNative)
  local rtToaddr=roundtrip(m.toaddr)
  local rtGlobal=roundtrip(m.globalTo)
  local command=m.key and ('Fixture '..m.key) or nil
  local rtCommand=(command and command~=m.toaddr and command~=m.globalTo) and roundtrip(command) or nil
  local canonical=rtToaddr==true or (m.keySource=='global' and rtGlobal==true)
  if canonical then summary.roundtrip=summary.roundtrip+1 end
  local bucketExists,attrPresent,linkPresent=false,false,false
  for _,case in ipairs(m.cases) do
   local partKey=safe(api.identity,case.part) or case.part
   local view=views and views[partKey]; local buckets=view and view.buckets or {}
   local bucket=m.key and buckets[m.key]
   if type(bucket)=='table' then
    bucketExists=true
    for _,attr in ipairs(case.attributes or {}) do
     local p=bucket[attr]
     if type(p)=='table' then
      attrPresent=true
      local link=case.layer=='REL' and p.rel_preset or p.abs_preset
      local expected=safe(api.identity,case.expected); local actual=link and safe(api.identity,link)
      if expected and actual==expected then linkPresent=true end
     end
    end
   end
  end
  if bucketExists then summary.bucket=summary.bucket+1 end
  if attrPresent then summary.attrPresent=summary.attrPresent+1 end
  if m.key then for _,case in ipairs(m.cases) do
   local token=txt(safe(api.identity,case.part) or case.part)..'/'..m.key
   if reverse[token] and reverse[token]~=sf then summary.collision=summary.collision+1 end
   reverse[token]=sf
  end end
  local classification
  if m.key==nil then classification='UNPROVEN'
  elseif summary.collision>0 then classification='COLLISION_UNPROVEN'
  elseif canonical~=true then classification='UNPROVEN'
  elseif not bucketExists then summary.missing=summary.missing+1; classification='BUCKET_MISSING'
  elseif not attrPresent then summary.attrAbsent=summary.attrAbsent+1; classification='MEMBER_KEY_PROVEN_ATTRIBUTE_UNRESOLVED'
  else classification='TOADDR_MEMBER_KEY_PROVEN' end
  m.classification=classification; m.canonical=canonical
  m.rtAddr,m.rtNative,m.rtToaddr,m.rtGlobal,m.rtCommand=rtAddr,rtNative,rtToaddr,rtGlobal,rtCommand
  -- Old sf_index residual: sf_string bucket versus ToAddr bucket.
  for _,case in ipairs(m.cases) do
   local partKey=safe(api.identity,case.part) or case.part
   local view=views and views[partKey]; local buckets=view and view.buckets or {}
   local sfBucket=buckets[tostring(sf)]
   if type(sfBucket)=='table' and m.key and tostring(sf)~=m.key then
    collisions.sf=collisions.sf+1
    local sameBucket=sfBucket==buckets[m.key]
    local sfRt=nil
    if fromAddr~=nil then
     local back=safe(fromAddr,tostring(sf))
     sfRt=back==nil and false or same(back,m.h)
    end
    if sameBucket then collisions.same=collisions.same+1 end
    emit('NATIVE_SF_INDEX_COLLISION_SAMPLE sf_index=%s toaddr_key=%s same_bucket=%s toaddr_roundtrip_same_handle=%s sf_index_roundtrip_same_handle=%s classification=%s',
     txt(sf),txt(m.key),tostring(sameBucket),tostring(canonical),tostring(sfRt),
     (canonical==true and sfRt~=true) and 'SF_INDEX_ACCIDENTAL_BUCKET_COLLISION' or 'UNRESOLVED')
   end
  end
  if sampleN<24 then sampleN=sampleN+1
   emit('TOADDR_MEMBER_KEY_SAMPLE sf_index=%s subfixture=%s addr_raw=%s addr_native_raw=%s toaddr_raw=%s toaddr_fixture_key=%s toaddr_roundtrip_same_handle=%s cooked_bucket_exists=%s expected_attribute_present=%s expected_preset_link_present=%s classification=%s',
    txt(sf),txt(safe(api.describe,m.h)),raw(m.addr),raw(m.addrNative),raw(m.toaddr),
    txt(m.key),tostring(canonical),tostring(bucketExists),tostring(attrPresent),tostring(linkPresent),classification)
  end
 end
 local proven=summary.unique>0 and summary.normalized==summary.unique and summary.roundtrip==summary.unique
  and summary.bucket==summary.unique and summary.collision==0
 local classification=proven and 'NATIVE_TOADDR_MEMBER_KEY_PROVEN' or 'UNPROVEN'
 emit('TOADDR_MEMBER_KEY_SUMMARY problematic_lanes=%d unique_members=%d toaddr_available=%d toaddr_normalized=%d toaddr_roundtrip_proven=%d cooked_bucket_exists=%d attribute_present=%d attribute_absent=%d bucket_missing=%d collision=%d classification=%s diagnostic_only=true',
  summary.problematic,summary.unique,summary.available,summary.normalized,summary.roundtrip,summary.bucket,summary.attrPresent,summary.attrAbsent,summary.missing,summary.collision,classification)
 emit('OLD_SF_INDEX_COLLISION_SUMMARY cases=%d accidental_other_bucket=%d same_member_roundtrip=%d classification=%s diagnostic_only=true',
  collisions.sf,collisions.sf-collisions.same,collisions.same,
  (collisions.sf>0 and collisions.same==0) and 'SF_INDEX_ACCIDENTAL_BUCKET_COLLISION' or (collisions.sf==0 and 'NO_RESIDUAL' or 'UNRESOLVED'))
 if proven then
  for _,sf in ipairs(ordered) do local m=members[sf]
   for _,case in ipairs(m.cases) do
    local view=views[safe(api.identity,case.part) or case.part]; local bucket=view and view.buckets[m.key]
    alternate.mapped=alternate.mapped+1
    local matched,different,unknown=false,false,false
    for _,attr in ipairs(case.attributes or {}) do
     local p=bucket and bucket[attr]
     if type(p)=='table' then
      local link=case.layer=='REL' and p.rel_preset or p.abs_preset
      local expected=safe(api.identity,case.expected); local actual=link and safe(api.identity,link)
      if expected and actual==expected then matched=true elseif actual then different=true else unknown=true end
     else unknown=true end
    end
    if different then alternate.different=alternate.different+1 elseif unknown or not matched then alternate.unresolved=alternate.unresolved+1 else alternate.expected=alternate.expected+1 end
   end
  end
  emit('GLOBAL_TOADDR_MEMBER_KEY_ALTERNATE mapped_lanes=%d expected_preset_evidence_lanes=%d different_preset_lanes=%d attribute_capability_unresolved_lanes=%d classification=%s diagnostic_only=true',
   alternate.mapped,alternate.expected,alternate.different,alternate.unresolved,
   alternate.different>0 and 'OBSERVED_APPLICABILITY_MISMATCH' or alternate.unresolved>0 and 'INCONCLUSIVE' or 'SUPPORTED_LANES_MATCHED')
 end
 return {summary=summary,alternate=alternate,collisions=collisions,classification=classification}
end
