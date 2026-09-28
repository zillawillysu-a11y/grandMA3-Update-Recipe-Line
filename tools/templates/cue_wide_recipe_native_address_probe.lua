-- Diagnostic only: ToAddr command-address member identity proven through
-- ObjectList(ToAddr()), versus cooked by_fixtures state observed separately.
-- Observer only, never resolver rules. ObjectList only; never selection/Cmd.
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
 local objectList=api.objectList or safe(function() return _G.ObjectList end)
 local members={}
 for _,case in ipairs(cases or {}) do if case.sf and not members[case.sf] then
  local h=api.getSubfixture and safe(api.getSubfixture,case.sf)
  local toaddr=h and safe(function() return h:ToAddr() end)
  local globalTo=api.toAddr and safe(api.toAddr,h)
  if globalTo==nil then
   local g=safe(function() return _G.ToAddr end)
   if type(g)=='function' then globalTo=safe(g,h) end
  end
  local key=toaddrKey(toaddr)
  if key==nil then key=toaddrKey(globalTo) end
  local rawCmd=toaddr
  if rawCmd==nil or toaddrKey(rawCmd)==nil then rawCmd=globalTo end
  members[case.sf]={h=h,toaddr=toaddr,globalTo=globalTo,rawCmd=rawCmd,key=key,cases={}}
 end
 if case.sf and members[case.sf] then members[case.sf].cases[#members[case.sf].cases+1]=case end end
 local summary={problematic=#(cases or {}),unique=0,available=0,normalized=0,resolved=0,unresolved=0,ambiguous=0,wrong=0,collision=0,
  bucketExists=0,bucketMissing=0,attrPresent=0,attrMissingWithBucket=0}
 local alternate={total=0,mapped=0,missing=0,expected=0,different=0,unresolved=0}
 local missingGroups={}
 local collisions={sf=0,same=0}
 local ordered={}; for sf in pairs(members) do ordered[#ordered+1]=sf end; table.sort(ordered)
 local reverse={}
 local sampleN=0
 for _,sf in ipairs(ordered) do
  local m=members[sf]; summary.unique=summary.unique+1
  if m.toaddr~=nil or m.globalTo~=nil then summary.available=summary.available+1 end
  if m.key~=nil then summary.normalized=summary.normalized+1 end
  -- Canonical proof: ObjectList(ToAddr()) resolves uniquely to original h.
  local count,sameHandle,distinct=0,false,{}
  if m.rawCmd~=nil and type(objectList)=='function' then
   local result=safe(objectList,m.rawCmd)
   if type(result)=='table' then
    for _,h in pairs(result) do
     if type(h)=='table' or type(h)=='userdata' then
      count=count+1
      local id=safe(api.identity,h) or tostring(h)
      if distinct[id]==nil then distinct[id]={h=h,same=same(h,m.h)} end
      if same(h,m.h) then sameHandle=true end
     end
    end
   end
  end
  local nDistinct=0; local onlySame=true
  for _,e in pairs(distinct) do nDistinct=nDistinct+1; if not e.same then onlySame=false end end
  local proof
  if count==0 or nDistinct==0 then proof='OBJECTLIST_UNRESOLVED'; summary.unresolved=summary.unresolved+1
  elseif nDistinct>1 or not onlySame then
   if sameHandle then proof='OBJECTLIST_AMBIGUOUS' else proof='OBJECTLIST_WRONG_HANDLE' end
   if proof=='OBJECTLIST_AMBIGUOUS' then summary.ambiguous=summary.ambiguous+1 else summary.wrong=summary.wrong+1 end
  elseif sameHandle then proof='OBJECTLIST_SAME_HANDLE'; summary.resolved=summary.resolved+1
  else proof='OBJECTLIST_WRONG_HANDLE'; summary.wrong=summary.wrong+1 end
  -- Cooked state counted independently for every member.
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
  if bucketExists then summary.bucketExists=summary.bucketExists+1
  else
   summary.bucketMissing=summary.bucketMissing+1
   for _,case in ipairs(m.cases) do
    local ref=txt(safe(api.identity,case.expected) or case.expected)
    local sp=txt(safe(api.identity,case.part) or case.part)
    local gk=ref..'|'..sp
    local g=missingGroups[gk]
    if not g then g={ref=ref,part=sp,members=0,keys={}}; missingGroups[gk]=g end
    g.members=g.members+1
    if m.key and #g.keys<8 then g.keys[#g.keys+1]=m.key end
   end
  end
  if bucketExists and not attrPresent then summary.attrMissingWithBucket=summary.attrMissingWithBucket+1 end
  if attrPresent then summary.attrPresent=summary.attrPresent+1 end
  if m.key then for _,case in ipairs(m.cases) do
   local token=txt(safe(api.identity,case.part) or case.part)..'/'..m.key
   if reverse[token] and reverse[token]~=sf then summary.collision=summary.collision+1 end
   reverse[token]=sf
  end end
  local classification
  if m.key==nil or proof~='OBJECTLIST_SAME_HANDLE' or summary.collision>0 then classification=proof
  else classification='OBJECTLIST_MEMBER_KEY_PROVEN' end
  m.classification=classification; m.proof=proof
  -- Old sf_index residual: sf_string bucket versus ToAddr bucket.
  for _,case in ipairs(m.cases) do
   local partKey=safe(api.identity,case.part) or case.part
   local view=views and views[partKey]; local buckets=view and view.buckets or {}
   local sfBucket=buckets[tostring(sf)]
   if type(sfBucket)=='table' and m.key and tostring(sf)~=m.key then
    collisions.sf=collisions.sf+1
    if sfBucket==buckets[m.key] then collisions.same=collisions.same+1 end
    emit('NATIVE_SF_INDEX_COLLISION_SAMPLE sf_index=%s toaddr_key=%s same_bucket=%s member_proof=%s classification=%s',
     txt(sf),txt(m.key),tostring(sfBucket==buckets[m.key]),proof,
     (proof=='OBJECTLIST_SAME_HANDLE') and 'SF_INDEX_ACCIDENTAL_BUCKET_COLLISION' or 'UNRESOLVED')
   end
  end
  if sampleN<24 then sampleN=sampleN+1
   emit('OBJECTLIST_MEMBER_KEY_SAMPLE sf_index=%s subfixture=%s toaddr_raw=%s fixture_key=%s objectlist_count=%s objectlist_same_handle=%s cooked_bucket_exists=%s expected_attribute_present=%s expected_preset_link_present=%s classification=%s',
    txt(sf),txt(safe(api.describe,m.h)),raw(m.rawCmd),txt(m.key),tostring(count),tostring(sameHandle),
    tostring(bucketExists),tostring(attrPresent),tostring(linkPresent),classification)
  end
 end
 local proven=summary.unique>0 and summary.normalized==summary.unique and summary.resolved==summary.unique and summary.collision==0
 local classification=proven and 'NATIVE_TOADDR_OBJECTLIST_MEMBER_KEY_PROVEN' or 'UNPROVEN'
 emit('OBJECTLIST_MEMBER_KEY_SUMMARY problematic_lanes=%d unique_members=%d toaddr_available=%d toaddr_normalized=%d objectlist_resolved_unique=%d objectlist_unresolved=%d objectlist_ambiguous=%d objectlist_wrong_handle=%d canonical_key_collision=%d cooked_bucket_exists=%d cooked_bucket_missing=%d attribute_present=%d attribute_missing_with_bucket=%d classification=%s diagnostic_only=true',
  summary.problematic,summary.unique,summary.available,summary.normalized,summary.resolved,summary.unresolved,summary.ambiguous,summary.wrong,summary.collision,
  summary.bucketExists,summary.bucketMissing,summary.attrPresent,summary.attrMissingWithBucket,classification)
 local gks={}; for gk in pairs(missingGroups) do gks[#gks+1]=gk end; table.sort(gks)
 for _,gk in ipairs(gks) do local g=missingGroups[gk]
  emit('TOADDR_COOKED_BUCKET_MISSING_SUMMARY reference=%s source_part=%s group=%s members=%d sample_keys=%s classification=APPLICABILITY_OR_CAPABILITY_UNRESOLVED diagnostic_only=true',
   g.ref,g.part,'UNAVAILABLE',g.members,table.concat(g.keys,','))
 end
 emit('OLD_SF_INDEX_COLLISION_SUMMARY cases=%d accidental_other_bucket=%d same_member_roundtrip=%d classification=%s diagnostic_only=true',
  collisions.sf,collisions.sf-collisions.same,collisions.same,
  (collisions.sf>0 and collisions.same==0) and 'SF_INDEX_ACCIDENTAL_BUCKET_COLLISION' or (collisions.sf==0 and 'NO_RESIDUAL' or 'UNRESOLVED'))
 if proven then
  for _,sf in ipairs(ordered) do local m=members[sf]
   for _,case in ipairs(m.cases) do
    alternate.total=alternate.total+1
    local view=views[safe(api.identity,case.part) or case.part]; local bucket=view and view.buckets[m.key]
    if type(bucket)~='table' then alternate.missing=alternate.missing+1; alternate.unresolved=alternate.unresolved+1
    else
     alternate.mapped=alternate.mapped+1
     local matched,different,unknown=false,false,false
     for _,attr in ipairs(case.attributes or {}) do
      local p=bucket[attr]
      if type(p)=='table' then
       local link=case.layer=='REL' and p.rel_preset or p.abs_preset
       local expected=safe(api.identity,case.expected); local actual=link and safe(api.identity,link)
       if expected and actual==expected then matched=true elseif actual then different=true else unknown=true end
      else unknown=true end
     end
     if different then alternate.different=alternate.different+1 elseif unknown or not matched then alternate.unresolved=alternate.unresolved+1 else alternate.expected=alternate.expected+1 end
    end
   end
  end
  emit('GLOBAL_OBJECTLIST_MEMBER_KEY_ALTERNATE total_lanes=%d mapped_bucket_lanes=%d bucket_missing_lanes=%d expected_preset_evidence_lanes=%d different_preset_lanes=%d attribute_unresolved_lanes=%d classification=%s diagnostic_only=true',
   alternate.total,alternate.mapped,alternate.missing,alternate.expected,alternate.different,alternate.unresolved,
   alternate.different>0 and 'OBSERVED_APPLICABILITY_MISMATCH' or 'INCONCLUSIVE')
 end
 return {summary=summary,alternate=alternate,collisions=collisions,classification=classification}
end
