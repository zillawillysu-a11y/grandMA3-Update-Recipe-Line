-- Diagnostic truth probe only. It consumes Rev11.1 surviving lane keys and
-- source-CuePart cooked views; it never changes resolver inputs or gates.
function __globalRecipeApplicabilityTruth(records,targets,parts,referenceRaw,api)
 local function safe(f,...) local ok,v=pcall(f,...); if ok then return v end end
 local function emit(fmt,...) api.log(string.format(fmt,...)) end
 local function name(h) return h and (safe(function() return h.Name end) or safe(function() return h:Get('Name') end)) end
 local function ordered(t) local a={}; for k in pairs(t or {}) do a[#a+1]=k end; table.sort(a); return a end
 local function count(t) local n=0; for _ in pairs(t or {}) do n=n+1 end; return n end
 local function text(v) return v==nil and 'UNAVAILABLE' or tostring(v):gsub('[\r\n]',' '):sub(1,120) end
 local byKey,refs={},{}
 for _,entry in ipairs(targets or {}) do if entry.key then
  byKey[entry.key]=entry.path; refs[entry.path]={rows=0,matched=0,mismatch=0,inconclusive=0} end end
 local selected={}
 for _,rec in ipairs(records or {}) do if rec.category=='FINAL_SURVIVING_UNSAFE' then
  local key=rec.ref and safe(api.identity,rec.ref)
  if key and byKey[key] then selected[#selected+1]={record=rec,label=byKey[key],key=key} end
 end end
 local views,partCount={},0
 local seenParts={}
 for _,part in ipairs(parts or {}) do
  local key=safe(api.identity,part) or part
  if not seenParts[key] then
   seenParts[key]=true; partCount=partCount+1
   if partCount<=64 then
    local cooked=safe(api.getPresetData,part,false,true)
    views[key]={part=part,buckets=type(cooked)=='table' and cooked.by_fixtures or nil}
   end
  end
 end
 local total={rows=0,matched=0,mismatch=0,inconclusive=0,surviving=0,supported=0,linked=0,unsupported=0,different=0,unresolved=0,layerRefined=0,layerFailed=0}
 local mismatchShown,unsupportedShown=0,0
 local refinementShown={}; local refinementCount=0
 local memberKeys={}
 for _,item in ipairs(selected) do
  local rec,label,key=item.record,item.label,item.key
  local row=rec.row
  local view=views[safe(api.identity,row.part) or row.part]
  local stats={surviving=0,supported=0,linked=0,unsupported=0,different=0,unresolved=0,layerRefined=0,layerFailed=0,members={},reasons={}}
  local attrsByLane={}
  local raw=referenceRaw[key]
  if type(raw)=='table' then for ui,p in pairs(raw) do if type(ui)=='number' and type(p)=='table' then
   local attr=p.attribute or (api.attributeByUI and safe(api.attributeByUI,ui))
   local attrName=name(attr)
   local feature=attr and safe(function() return attr.Feature end)
   local fg=feature and safe(function() return feature:Parent() end)
   local fgKey=fg and safe(api.identity,fg)
   if fgKey and type(attrName)=='string' and attrName~='' then
    for _,spec in ipairs({{'ABS','absolute'},{'REL','relative'}}) do
     local step=p[1]
     if type(step)=='table' and step[spec[2]]~=nil then
      local lane='FG:'..fgKey..'|'..spec[1]
      attrsByLane[lane]=attrsByLane[lane] or {}; attrsByLane[lane][attrName]=true
     end
    end
   end
  end end end
  for _,survivingKey in ipairs(rec.surviving or {}) do
   stats.surviving=stats.surviving+1
   local split=type(survivingKey)=='string' and survivingKey:find('\0',1,true)
   local member=split and tonumber(survivingKey:sub(1,split-1))
   local lane=split and survivingKey:sub(split+1)
   if member then stats.members[member]=true end
   local feature,layer
   if lane then feature,layer=lane:match('^(.-)|([^|]+)$') end
   local refinedLane=lane
   if layer=='*' then
    local proof=api.proofs and api.proofs[key]
    local uniqueAbs=proof and proof.motionStaticProven==true and type(proof.layers)=='table'
     and proof.layers.ABS==true and count(proof.layers)==1 and proof.channels>0
     and proof.activeValue==proof.channels and type(proof.steps)=='table'
     and proof.steps['1']==proof.channels and count(proof.steps)==1
    local concreteFeature=type(feature)=='string' and feature:match('^FG:')
     and type(row.features)=='table' and row.features[feature]==true
    if uniqueAbs and concreteFeature and attrsByLane[feature..'|ABS'] then
     refinedLane=feature..'|ABS'; layer='ABS'; stats.layerRefined=stats.layerRefined+1
    else stats.layerFailed=stats.layerFailed+1; stats.reasons.SURVIVING_LANE_LAYER_UNPROVEN=true end
    local marker=label..'|'..tostring(feature)..'|'..tostring(layer)
    if not refinementShown[marker] and refinementCount<40 then
     refinementShown[marker]=true; refinementCount=refinementCount+1
     emit('GLOBAL_RECIPE_LAYER_REFINEMENT reference=%s original_layer=* refined_layer=%s feature=%s proof=%s classification=OBSERVATION_ONLY',
      label,refinedLane~=lane and 'ABS' or 'UNPROVEN',text(feature),
      refinedLane~=lane and 'REV12_1_MOTION_STATIC_UNIQUE_SINGLE_STEP_ABS' or 'UNIQUE_ABS_OR_FEATURE_MAPPING_UNPROVEN')
    end
   end
   local attrs=refinedLane and attrsByLane[refinedLane]
   local attrNames=ordered(attrs)
   local matched,unsupported,unresolved,different=0,0,0,0
   if not member then unresolved=1; stats.reasons.MEMBER_KEY_UNPROVEN=true
   elseif layer~='ABS' and layer~='REL' or not feature or feature=='*' then
    unresolved=1; stats.reasons.SURVIVING_LANE_LAYER_UNPROVEN=true
   elseif not attrs or #attrNames==0 then
    unresolved=1; stats.reasons.REFERENCE_ATTRIBUTE_LANE_UNAVAILABLE=true
   elseif not view or type(view.buckets)~='table' or partCount>64 then
    unresolved=1; stats.reasons.COOKED_VIEW_UNAVAILABLE=true
   else
    local fixture=api.getSubfixture and safe(api.getSubfixture,member)
    local fid=fixture and safe(function() return fixture.FID end)
    local cid=fixture and safe(function() return fixture.CID end)
    local noCid=cid==nil or cid=='None' or (type(cid)=='number' and cid==0)
    local fixtureKey=fid and tostring(fid)
    if not fixtureKey or not noCid or (memberKeys[fixtureKey] and memberKeys[fixtureKey]~=member) then
     unresolved=1; stats.reasons.MEMBER_KEY_UNPROVEN=true
    else
     memberKeys[fixtureKey]=member
     for _,attribute in ipairs(attrNames) do
      local found,observed=nil,nil
      local ambiguous=false
      for _,view in ipairs({view}) do
       local buckets=view.buckets
       if type(buckets)~='table' then ambiguous=true
       else
        local bucket=buckets[fixtureKey] or buckets[tonumber(fixtureKey)]
        if bucket~=nil and type(bucket)~='table' then ambiguous=true
        elseif type(bucket)=='table' and bucket[attribute]~=nil then
         if type(bucket[attribute])~='table' or found then ambiguous=true
         else found=bucket[attribute]; observed=view.part end
        end
       end
      end
      if ambiguous then unresolved=unresolved+1; stats.reasons.COOKED_ATTRIBUTE_MAPPING_UNPROVEN=true
      elseif found then
       local link=layer=='ABS' and found.abs_preset or found.rel_preset
       local expected=safe(api.identity,rec.ref)
       local actual=link and safe(api.identity,link)
       if expected and actual==expected then matched=matched+1
       elseif not expected or (link~=nil and not actual) then unresolved=unresolved+1; stats.reasons.PRESET_LINK_IDENTITY_UNPROVEN=true
       else
        different=different+1
        if mismatchShown<16 then
         mismatchShown=mismatchShown+1
         emit('GLOBAL_RECIPE_APPLICABILITY_MISMATCH reference=%s member=%s feature=%s layer=%s attribute=%s expected_preset=%s observed_preset=%s reason=PRESET_LINK_DIFFERENT',
          label,text(member),text(lane),layer,text(attribute),text(api.describe(rec.ref)),text(link and api.describe(link) or 'NONE'))
        end
       end
      else
       local capability=api.capability and safe(api.capability,fixture,attribute)
       if capability=='UNSUPPORTED' then
        unsupported=unsupported+1
        if unsupportedShown<16 then
         unsupportedShown=unsupportedShown+1
         emit('GLOBAL_RECIPE_APPLICABILITY_UNSUPPORTED reference=%s member=%s feature=%s layer=%s attribute=%s classification=FIXTURE_ATTRIBUTE_UNSUPPORTED',
          label,text(member),text(lane),layer,text(attribute))
        end
       else unresolved=unresolved+1; stats.reasons.ATTRIBUTE_CAPABILITY_UNPROVEN=true end
      end
     end
    end
   end
   if matched+different>0 then stats.supported=stats.supported+1 end
   if unsupported>0 then stats.unsupported=stats.unsupported+1 end
   if different>0 then stats.different=stats.different+1
   elseif unresolved>0 then stats.unresolved=stats.unresolved+1
   elseif matched>0 then stats.linked=stats.linked+1
   elseif unsupported>0 then -- proven unsupported attributes are neutral
   else stats.unresolved=stats.unresolved+1 end
  end
  local class
  if stats.different>0 then class='OBSERVED_APPLICABILITY_MISMATCH'
  elseif stats.unresolved>0 or stats.surviving==0 then class='INCONCLUSIVE'
  else class='RECIPE_SCOPE_MATCHED_AFTER_COMPATIBILITY' end
  total.rows=total.rows+1
  total.surviving=total.surviving+stats.surviving; total.supported=total.supported+stats.supported
  total.linked=total.linked+stats.linked; total.unsupported=total.unsupported+stats.unsupported
  total.different=total.different+stats.different; total.unresolved=total.unresolved+stats.unresolved
  total.layerRefined=total.layerRefined+stats.layerRefined; total.layerFailed=total.layerFailed+stats.layerFailed
  local ref=refs[label]; ref.rows=ref.rows+1
  if class=='OBSERVED_APPLICABILITY_MISMATCH' then total.mismatch=total.mismatch+1; ref.mismatch=ref.mismatch+1
  elseif class=='INCONCLUSIVE' then total.inconclusive=total.inconclusive+1; ref.inconclusive=ref.inconclusive+1
  else total.matched=total.matched+1; ref.matched=ref.matched+1 end
  emit('GLOBAL_RECIPE_APPLICABILITY_ROW reference=%s source_cue=%s source_part=%s source_recipe=%s group=%s surviving_members=%d surviving_lanes=%d layer_refined_lanes=%d layer_refinement_failed_lanes=%d supported_lanes=%d expected_preset_link_lanes=%d unsupported_attribute_lanes=%d different_preset_lanes=%d unresolved_lanes=%d unresolved_reasons=%s classification=%s',
   label,text(api.describe(row.cue)),text(api.describe(row.part)),text(api.describe(row.recipe)),text(api.describe(row.group)),
   count(stats.members),stats.surviving,stats.layerRefined,stats.layerFailed,stats.supported,stats.linked,stats.unsupported,stats.different,stats.unresolved,table.concat(ordered(stats.reasons),','),class)
 end
 local summaryClass=total.rows~=15 and 'INCONCLUSIVE' or
  (total.mismatch>0 and 'OBSERVED_APPLICABILITY_MISMATCH' or
   (total.inconclusive>0 and 'INCONCLUSIVE' or 'RECIPE_SCOPE_MATCHED_AFTER_COMPATIBILITY'))
 emit('GLOBAL_RECIPE_APPLICABILITY_SUMMARY rows_expected=15 rows_checked=%d rows_matched=%d rows_mismatch=%d rows_inconclusive=%d surviving_lanes=%d layer_refined_lanes=%d layer_refinement_failed_lanes=%d supported_lanes=%d unsupported_attribute_lanes=%d different_preset_lanes=%d unresolved_lanes=%d classification=%s diagnostic_only=true cooked_part_reads=%d',
  total.rows,total.matched,total.mismatch,total.inconclusive,total.surviving,total.layerRefined,total.layerFailed,total.supported,total.unsupported,total.different,total.unresolved,summaryClass,math.min(partCount,64))
 for _,label in ipairs(ordered(refs)) do local s=refs[label]
  emit('GLOBAL_RECIPE_APPLICABILITY_REFERENCE reference=%s rows=%d matched=%d mismatch=%d inconclusive=%d',label,s.rows,s.matched,s.mismatch,s.inconclusive)
 end
 return {totals=total,classification=summaryClass,partReads=math.min(partCount,64)}
end
