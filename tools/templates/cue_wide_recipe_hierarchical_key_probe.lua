-- Diagnostic only: hierarchical Fixture address versus cooked by_fixtures keys.
function __cookedHierarchicalKeyProbe(cases,views,api)
 local function safe(f,...) local ok,v=pcall(f,...); if ok then return v end end
 local function emit(fmt,...) api.log(string.format(fmt,...)) end
 local function txt(v) return v==nil and 'nil' or tostring(v):gsub('[\r\n, ]','_'):sub(1,100) end
 local function same(a,b)
  if a==b then return true end
 local v=api.compareHandle and safe(api.compareHandle,a,b)
  if v==true then return true end
  local ia=a and safe(api.identity,a); local ib=b and safe(api.identity,b)
  return ia~=nil and ia==ib
 end
 local function valid(a) return type(a)=='string' and a:match('^%d+[%.%d]*$') and not a:find('%.%.',1,true) and not a:match('%.$') end
 local function display(h)
  local d=h and safe(api.describe,h)
  local a=type(d)=='string' and d:match('^Fixture%s+(%d+[%.%d]*)%s*%[#')
  if not a and type(d)=='string' then a=d:match('^Fixture%s+(%d+[%.%d]*)$') end
  return valid(a) and a or nil
 end
 local function property(h)
  if not h then return nil,'NONE' end
  local found={}
  for _,k in ipairs({'FixtureAddress','SubfixtureAddress','NativeAddress','Address','FixtureID','FixtureId','SubfixtureNumber','FixtureNumber','Number','Index'}) do
   local v=safe(function() return h:Get(k) end) or safe(function() return h[k] end)
   if type(v)=='string' and valid(v) then found[v]=found[v] and found[v]..'+'..k or k end
  end
  local result,n=nil,0; for v in pairs(found) do result=v; n=n+1 end
  return n==1 and result or nil,n>1 and 'AMBIGUOUS' or result and found[result] or 'UNAVAILABLE'
 end
 local function ordinal(parent,child)
  local children=safe(function() return parent:Children() end)
  if type(children)~='table' then return nil end
  local list={}; for _,h in pairs(children) do if type(h)=='table' or type(h)=='userdata' then list[#list+1]=h end end
  if #list==0 then return nil end
  local values,matched={},nil
  for _,h in ipairs(list) do
   local i=safe(function() return h:Index() end)
   if type(i)~='number' or i%1~=0 or values[i] then return nil end
   values[i]=true
   if same(h,child) then if matched then return nil end; matched=i end
  end
  if not matched then return nil end
  local zero=true; local one=true
  for i=0,#list-1 do if not values[i] then zero=false end end
  for i=1,#list do if not values[i] then one=false end end
  if zero==one then return nil end
  return zero and matched+1 or matched
 end
 local function hierarchy(h)
  local chain,seen={},{}
  while h and #chain<8 do
   if seen[h] then return nil end; seen[h]=true; table.insert(chain,1,h)
   h=safe(function() return h:Parent() end)
   if h then
    local class=safe(function() return h:GetClass() end)
    if class~='Fixture' and class~='Subfixture' and class~='SubFixture' then break end
   end
  end
  local root=chain[1]
  local fid=root and safe(function() return root.FID end)
  if type(fid)~='number' or fid%1~=0 or fid<=0 then return nil end
  local parts={tostring(fid)}
  for i=2,#chain do local n=ordinal(chain[i-1],chain[i]); if not n then return nil end; parts[#parts+1]=tostring(n) end
  return table.concat(parts,'.')
 end
 local members,shapeGroups={},{}
 for _,case in ipairs(cases or {}) do if case.sf and not members[case.sf] then
  local h=api.getSubfixture and safe(api.getSubfixture,case.sf)
  local d,p,ps=display(h),property(h)
  local a=hierarchy(h)
  local parent=h and safe(function() return h:Parent() end)
  local shape=(h and safe(function() return h:GetClass() end) or 'nil')..'/parent='..(parent and safe(function() return parent:GetClass() end) or 'nil')..'/depth='..(d and select(2,d:gsub('%.','')) or '?')
  members[case.sf]={h=h,display=d,native=p,nativeSource=ps,hierarchy=a,shape=shape,cases={}}
  shapeGroups[shape]=shapeGroups[shape] or {}
  shapeGroups[shape][#shapeGroups[shape]+1]=case.sf
 end
 if case.sf and members[case.sf] then members[case.sf].cases[#members[case.sf].cases+1]=case end end
 local summary={problematic=#(cases or {}),unique=0,display=0,native=0,hierarchy=0,fully=0,collision=0,ambiguous=0,unmapped=0}
 local residual={members=0,reasons={}}
 local alternate={mapped=0,expected=0,different=0,unresolved=0}
 local oldRules={'fid_number','fid_string','sf_number','sf_string','fid_dot_cid','fid_slash_cid','parent_fid_dot_cid','parent_fid_slash_cid'}
 local ordered={}; for sf in pairs(members) do ordered[#ordered+1]=sf end; table.sort(ordered)
 local reverse={}
 local sampleCounts={}
 for _,sf in ipairs(ordered) do
  local m=members[sf]; summary.unique=summary.unique+1
  local allDisplay,allNative,allHierarchy,allEvidence=true,true,true,true
  local anyOld,oldConflict=false,false
  for _,case in ipairs(m.cases) do
   local partKey=safe(api.identity,case.part) or case.part
   local view=views and views[partKey]; local buckets=view and view.buckets or {}
   local function evidence(key)
    local bucket=key and buckets[key]
    if type(bucket)~='table' then return false end
    for _,attr in ipairs(case.attributes or {}) do if type(bucket[attr])=='table' then return true end end
    return false
   end
   local hits={display=evidence(m.display),native=evidence(m.native),hierarchy=evidence(m.hierarchy)}
   allDisplay=allDisplay and hits.display; allNative=allNative and hits.native; allHierarchy=allHierarchy and hits.hierarchy
   allEvidence=allEvidence and (hits.display or hits.native or hits.hierarchy)
   local fid=m.h and safe(function() return m.h.FID end)
   local cid=m.h and safe(function() return m.h.CID end)
   local parent=m.h and safe(function() return m.h:Parent() end)
   local pfid=parent and safe(function() return parent.FID end)
   local old={fid_number=type(fid)=='number' and fid or nil,fid_string=fid and tostring(fid) or nil,sf_number=sf,sf_string=tostring(sf)}
   if fid and cid and cid~='None' then old.fid_dot_cid=tostring(fid)..'.'..tostring(cid); old.fid_slash_cid=tostring(fid)..'/'..tostring(cid) end
   if pfid and cid and cid~='None' then old.parent_fid_dot_cid=tostring(pfid)..'.'..tostring(cid); old.parent_fid_slash_cid=tostring(pfid)..'/'..tostring(cid) end
   for _,rule in ipairs(oldRules) do if evidence(old[rule]) then
    anyOld=true
    local reason=rule..(old[rule]==m.display and '_same_address' or '_other_bucket')
    residual.reasons[reason]=(residual.reasons[reason] or 0)+1
    if old[rule]~=m.display then oldConflict=true end
   end end
  end
  if anyOld then residual.members=residual.members+1 end
  if oldConflict then summary.ambiguous=summary.ambiguous+1 end
  if allDisplay then summary.display=summary.display+1 end
  if allNative then summary.native=summary.native+1 end
  if allHierarchy then summary.hierarchy=summary.hierarchy+1 end
  local independent=(m.native and allNative and m.native==m.display) or (m.hierarchy and allHierarchy and m.hierarchy==m.display)
  local key=allDisplay and m.display or nil
  if key then for _,case in ipairs(m.cases) do
   local token=txt(safe(api.identity,case.part) or case.part)..'/'..key
   if reverse[token] and reverse[token]~=sf then summary.collision=summary.collision+1 end
   reverse[token]=sf
  end end
  local classification=key and not oldConflict and (independent and 'HIERARCHICAL_ADDRESS_PROVEN' or 'DISPLAY_ADDRESS_MATCH_ONLY') or 'UNPROVEN'
  if key and not independent and m.native and m.hierarchy and m.native~=m.hierarchy then summary.ambiguous=summary.ambiguous+1 end
  if not key then summary.unmapped=summary.unmapped+1 end
  m.classification=classification; m.key=key
  sampleCounts[m.shape]=(sampleCounts[m.shape] or 0)+1
  if sampleCounts[m.shape]<=4 then
   local parent=m.h and safe(function() return m.h:Parent() end)
   emit('COOKED_HIERARCHICAL_ADDRESS_SAMPLE sf_index=%s subfixture=%s parent=%s fid=%s cid=%s parent_fid=%s display_address=%s native_property_address=%s native_property_source=%s hierarchy_address=%s cooked_key=%s attribute_evidence=%s candidate_status=%s classification=OBSERVATION_ONLY',
    txt(sf),txt(safe(api.describe,m.h)),txt(safe(api.describe,parent)),txt(m.h and safe(function() return m.h.FID end)),txt(m.h and safe(function() return m.h.CID end)),txt(parent and safe(function() return parent.FID end)),txt(m.display),txt(m.native),txt(m.nativeSource),txt(m.hierarchy),txt(key),tostring(allEvidence),classification)
  end
 end
 local shapes={}; for shape in pairs(shapeGroups) do shapes[#shapes+1]=shape end; table.sort(shapes)
 for _,shape in ipairs(shapes) do
  local list=shapeGroups[shape]; local d,n,h,proven=0,0,0,0
  for _,sf in ipairs(list) do local m=members[sf]; if m.key then d=d+1 end; if m.native and m.native==m.key then n=n+1 end; if m.hierarchy and m.hierarchy==m.key then h=h+1 end; if m.classification=='HIERARCHICAL_ADDRESS_PROVEN' then proven=proven+1 end end
  local class=proven==#list and summary.collision==0 and summary.ambiguous==0 and 'HIERARCHICAL_ADDRESS_PROVEN' or d==#list and summary.collision==0 and summary.ambiguous==0 and 'DISPLAY_ADDRESS_MATCH_ONLY' or 'UNPROVEN'
  emit('COOKED_HIERARCHICAL_ADDRESS_SHAPE shape=%s members=%d display_address_match=%d native_address_match=%d hierarchy_address_match=%d collision=%d ambiguous=%d classification=%s',txt(shape),#list,d,n,h,summary.collision,summary.ambiguous,class)
 end
 if summary.collision==0 and summary.ambiguous==0 then
  for _,sf in ipairs(ordered) do local m=members[sf]; if m.classification=='HIERARCHICAL_ADDRESS_PROVEN' then
   summary.fully=summary.fully+1
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
  end end
 end
 local rr={}; for rule,n in pairs(residual.reasons) do rr[#rr+1]=rule..':'..n end; table.sort(rr)
 emit('COOKED_OLD_CANDIDATE_RESIDUAL members_with_any_old_candidate_evidence=%d reason_distribution=%s diagnostic_only=true',residual.members,table.concat(rr,','))
 local classification=summary.fully==summary.unique and summary.unique>0 and summary.unmapped==0 and summary.collision==0 and summary.ambiguous==0 and 'HIERARCHICAL_ADDRESS_PROVEN' or summary.display==summary.unique and summary.unique>0 and summary.collision==0 and summary.ambiguous==0 and 'DISPLAY_ADDRESS_MATCH_ONLY' or 'UNPROVEN'
 emit('COOKED_HIERARCHICAL_ADDRESS_SUMMARY problematic_lanes=%d unique_members=%d display_matched=%d native_matched=%d hierarchy_matched=%d fully_proven=%d collision=%d ambiguous=%d unmapped=%d classification=%s diagnostic_only=true',summary.problematic,summary.unique,summary.display,summary.native,summary.hierarchy,summary.fully,summary.collision,summary.ambiguous,summary.unmapped,classification)
 if alternate.mapped>0 then emit('GLOBAL_HIERARCHICAL_KEY_ALTERNATE mapped_lanes=%d expected_preset_evidence_lanes=%d different_preset_lanes=%d attribute_capability_unresolved_lanes=%d classification=%s diagnostic_only=true',alternate.mapped,alternate.expected,alternate.different,alternate.unresolved,alternate.different>0 and 'OBSERVED_APPLICABILITY_MISMATCH' or alternate.unresolved>0 and 'INCONCLUSIVE' or 'SUPPORTED_LANES_MATCHED') end
 return {summary=summary,residual=residual,alternate=alternate,classification=classification}
end
