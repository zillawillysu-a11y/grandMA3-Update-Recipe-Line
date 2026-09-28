-- Read-only observer. Candidate relations are evidence, never resolver rules.
function __cookedMemberKeyProbe(cases,views,api)
 local function safe(f,...) local ok,v=pcall(f,...); if ok then return v end end
 local function text(v) return v==nil and 'nil' or tostring(v):gsub('[\r\n, ]','_'):sub(1,80) end
 local function emit(fmt,...) api.log(string.format(fmt,...)) end
 local function count(t) local n=0; for _ in pairs(t or {}) do n=n+1 end; return n end
 local function ordered(t) local a={}; for k in pairs(t or {}) do a[#a+1]=k end; table.sort(a); return a end
 local members,shapes={},{}
 for _,case in ipairs(cases or {}) do
  local sf=case.sf
  local m=sf and members[sf]
  if sf and not m then
   local h=api.getSubfixture and safe(api.getSubfixture,sf)
   local parent=h and safe(function() return h:Parent() end)
   local ancestor=parent and safe(function() return parent:Parent() end)
   local fid=h and safe(function() return h.FID end)
   local cid=h and safe(function() return h.CID end)
   local pfid=parent and safe(function() return parent.FID end)
   local pcid=parent and safe(function() return parent.CID end)
   m={sf=sf,handle=h,parent=parent,ancestor=ancestor,fid=fid,cid=cid,pfid=pfid,pcid=pcid,
    class=h and safe(function() return h:GetClass() end),name=h and (safe(function() return h.Name end) or safe(function() return h:Get('Name') end)),
    parentClass=parent and safe(function() return parent:GetClass() end),
    ancestorClass=ancestor and safe(function() return ancestor:GetClass() end),
    ancestorFID=ancestor and safe(function() return ancestor.FID end),
    ancestorCID=ancestor and safe(function() return ancestor.CID end),cases={}}
   m.shape='FID_'..type(fid)..'/CID_'..type(cid)..':'..(cid=='None' and 'None' or 'other')..'/PARENT_'..text(m.parentClass)..'/PFID_'..type(pfid)..'/PCID_'..type(pcid)
   members[sf]=m; shapes[m.shape]=shapes[m.shape] or {members={},cases={}}
   shapes[m.shape].members[sf]=m
  end
  if m then
   m.cases[#m.cases+1]=case
   shapes[m.shape].cases[#shapes[m.shape].cases+1]={member=m,case=case}
  end
 end
 local partKeys={}
 for key,view in pairs(views or {}) do
  local buckets=type(view)=='table' and view.buckets
  local typeCounts,bucketTypes,samples={}, {},{}
  if type(buckets)=='table' then for k,v in pairs(buckets) do
   typeCounts[type(k)]=(typeCounts[type(k)] or 0)+1
   bucketTypes[type(v)]=(bucketTypes[type(v)] or 0)+1
   if #samples<8 then samples[#samples+1]=type(k)..':'..text(k) end
  end end
  table.sort(samples)
  local function distribution(t) local a={}; for k,v in pairs(t) do a[#a+1]=k..':'..v end; table.sort(a); return table.concat(a,',') end
  emit('COOKED_PART_KEY_SHAPE source_part=%s total_key_count=%d key_types=%s bucket_value_types=%s key_samples=%s',
   text(safe(api.describe,view.part)),count(buckets),distribution(typeCounts),distribution(bucketTypes),table.concat(samples,';'))
  partKeys[key]=buckets
 end
 local function candidates(m)
  local out={}
  if type(m.fid)=='number' then out.fid_number=m.fid end
  if m.fid~=nil then out.fid_string=tostring(m.fid) end
  out.sf_number=m.sf; out.sf_string=tostring(m.sf)
  if m.fid~=nil and m.cid~=nil and m.cid~='None' then
   out.fid_dot_cid=tostring(m.fid)..'.'..tostring(m.cid)
   out.fid_slash_cid=tostring(m.fid)..'/'..tostring(m.cid)
  end
  if m.pfid~=nil and m.cid~=nil and m.cid~='None' then
   out.parent_fid_dot_cid=tostring(m.pfid)..'.'..tostring(m.cid)
   out.parent_fid_slash_cid=tostring(m.pfid)..'/'..tostring(m.cid)
  end
  return out
 end
 local summary={problematic=#(cases or {}),unique=count(members),mapped=0,collision=0,ambiguous=0,unmapped=0,provenShapes=0,unprovenShapes=0}
 local alternate={mapped=0,expected=0,different=0,unresolved=0}
 for _,shape in ipairs(ordered(shapes)) do
  local group=shapes[shape]
  local rules,anyEvidence,caseEvidence={}, {},{}
  for _,item in ipairs(group.cases) do
   local m,case=item.member,item.case
   local partKey=safe(api.identity,case.part) or case.part
   local buckets=partKeys[partKey]
   local found={}
   for rule,key in pairs(candidates(m)) do
    local bucket=type(buckets)=='table' and buckets[key]
    if type(bucket)=='table' then
     local evidence=false
     for _,attr in ipairs(case.attributes or {}) do if type(bucket[attr])=='table' then evidence=true; break end end
     if evidence then found[rule]={key=key,bucket=bucket}; rules[rule]=(rules[rule] or 0)+1 end
    end
   end
   caseEvidence[item]=found
   if next(found) then anyEvidence[m.sf]=true end
  end
  local complete={}
  for rule,n in pairs(rules) do if n==#group.cases then complete[#complete+1]=rule end end
  table.sort(complete)
  local provenRule=#complete==1 and complete[1] or nil
  local collisions=0
  if provenRule then
   local reverse={}
   for _,item in ipairs(group.cases) do
    local key=caseEvidence[item][provenRule].key
    local partKey=safe(api.identity,item.case.part) or item.case.part
    local token=tostring(partKey)..'/'..type(key)..':'..tostring(key)
    if reverse[token] and reverse[token]~=item.member.sf then collisions=collisions+1 end
    reverse[token]=item.member.sf
   end
  end
  if collisions>0 then provenRule=nil end
  local classification=provenRule and 'PROVEN' or 'UNPROVEN'
  if provenRule then summary.provenShapes=summary.provenShapes+1; summary.mapped=summary.mapped+count(group.members)
  else summary.unprovenShapes=summary.unprovenShapes+1 end
  summary.collision=summary.collision+collisions
  for sf,m in pairs(group.members) do
   if not anyEvidence[sf] then summary.unmapped=summary.unmapped+1 end
   if #complete>1 then summary.ambiguous=summary.ambiguous+1 end
  end
  emit('COOKED_MEMBER_KEY_SHAPE shape=%s members=%d fid_shape=%s cid_shape=%s parent_shape=%s candidate_rules=%s classification=%s',
   shape,count(group.members),type(next(group.members) and group.members[next(group.members)].fid),
   type(next(group.members) and group.members[next(group.members)].cid),text(next(group.members) and group.members[next(group.members)].parentClass),
   table.concat(complete,','),classification)
  local samples=0
  for _,sf in ipairs(ordered(group.members)) do
   if samples<4 then
    samples=samples+1; local m=group.members[sf]
    local possible={}; for rule,key in pairs(candidates(m)) do possible[#possible+1]=rule..':'..type(key)..':'..text(key) end; table.sort(possible)
    local observedSet={}
    for _,item in ipairs(group.cases) do if item.member.sf==sf then
     for _,hit in pairs(caseEvidence[item]) do observedSet[type(hit.key)..':'..text(hit.key)]=true end
    end end
    local observed=ordered(observedSet)
    while #observed>4 do observed[#observed]=nil end
    emit('COOKED_MEMBER_KEY_SAMPLE sf_index=%s subfixture=%s class=%s name=%s fid=%s fid_type=%s cid=%s cid_type=%s parent=%s parent_class=%s parent_fid=%s parent_cid=%s ancestor=%s ancestor_class=%s ancestor_fid=%s ancestor_cid=%s candidate_keys=%s observed_bucket_key=%s mapping_status=%s',
     text(sf),text(safe(api.describe,m.handle)),text(m.class),text(m.name),text(m.fid),type(m.fid),text(m.cid),type(m.cid),
     text(safe(api.describe,m.parent)),text(m.parentClass),text(m.pfid),text(m.pcid),text(safe(api.describe,m.ancestor)),
     text(m.ancestorClass),text(m.ancestorFID),text(m.ancestorCID),
     table.concat(possible,';'),#observed>0 and table.concat(observed,';') or 'nil',classification)
   end
  end
  if provenRule then for _,item in ipairs(group.cases) do
   local bucket=caseEvidence[item][provenRule].bucket
   alternate.mapped=alternate.mapped+1
   local expected=safe(api.identity,item.case.expected)
   local match,different,unknown=false,false,false
   for _,attr in ipairs(item.case.attributes or {}) do
    local p=bucket[attr]
    if type(p)=='table' then
     local link=item.case.layer=='REL' and p.rel_preset or p.abs_preset
     local observed=link and safe(api.identity,link)
     if expected and observed==expected then match=true
     elseif observed or link==nil then different=true
     else unknown=true end
    else unknown=true end
   end
   if different then alternate.different=alternate.different+1
   elseif unknown then alternate.unresolved=alternate.unresolved+1
   elseif match then alternate.expected=alternate.expected+1
   else alternate.unresolved=alternate.unresolved+1 end
  end end
 end
 -- Missing sf_index cannot enter an identity shape or establish a mapping.
 for _,case in ipairs(cases or {}) do if not case.sf then summary.unmapped=summary.unmapped+1 end end
 local class=summary.provenShapes>0 and summary.unprovenShapes==0 and summary.unmapped==0 and summary.ambiguous==0 and summary.collision==0 and 'PROVEN_FOR_TESTED_SHAPES' or 'UNPROVEN'
 emit('COOKED_MEMBER_KEY_SUMMARY problematic_lanes=%d unique_members=%d mapped_unique=%d collision=%d ambiguous=%d unmapped=%d proven_shapes=%d unproven_shapes=%d classification=%s diagnostic_only=true',
  summary.problematic,summary.unique,summary.mapped,summary.collision,summary.ambiguous,summary.unmapped,summary.provenShapes,summary.unprovenShapes,class)
 if summary.provenShapes>0 then
  local altClass=alternate.different>0 and 'OBSERVED_APPLICABILITY_MISMATCH' or
   (alternate.unresolved>0 and 'INCONCLUSIVE' or 'SUPPORTED_LANES_MATCHED')
  emit('GLOBAL_MEMBER_KEY_ALTERNATE mapped_lanes=%d expected_preset_evidence_lanes=%d different_preset_lanes=%d attribute_capability_unresolved_lanes=%d classification=%s diagnostic_only=true',
   alternate.mapped,alternate.expected,alternate.different,alternate.unresolved,altClass)
 end
 return {summary=summary,classification=class,alternate=alternate}
end
