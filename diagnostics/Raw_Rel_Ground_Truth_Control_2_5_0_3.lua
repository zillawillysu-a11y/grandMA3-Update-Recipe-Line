-- Rev8 independent read-only observer. These two addresses select controlled
-- samples supplied by the user; numbers never influence classification.
return function()
 local targets={A='Preset 25.9009',B='Preset 25.9013'}
 local nativePrintf=_G.Printf
 local function safe(fn,...)
  if type(fn)~='function' then return nil end
  local ok,value=pcall(fn,...); if ok then return value end
 end
 local function shown(v)
  if v==nil then return '<nil>' end
  if type(v)=='string' and v=='' then return '<empty>' end
  return tostring(v):gsub('[\r\n]',' '):sub(1,160)
 end
 local function cls(h) return safe(function() return h:GetClass() end) end
 local function addr(h) return shown(safe(_G.HandleToStr,h) or safe(function() return h:ToAddr() end)) end
 local function ident(h) return 'db='..shown(safe(_G.HandleToInt,h))..',path='..addr(h) end
 local function typed(v) return type(v)..':'..shown(v) end
 local function log(fmt,...) nativePrintf('%s','[RawRelGroundTruth] '..string.format(fmt,...)) end
 local function read(h,key,role)
  if role==nil then return safe(function() return h:Get(key) end) end
  return safe(function() return h:Get(key,role) end)
 end
 local roles=(_G.Enums or {}).Roles or {}
 local function property(h,key,index)
  local p={name=key,enumerated=index~=nil,
   type=index and safe(function() return h:PropertyType(index) end) or nil,
   info=index and safe(function() return h:PropertyInfo(index) end) or nil,
   direct=safe(function() return h[key] end),get=read(h,key),
   raw=roles.Raw and read(h,key,roles.Raw) or nil,
   display=roles.Display and read(h,key,roles.Display) or nil,
   stringValue=roles.String and read(h,key,roles.String) or nil}
  p.signature=table.concat({tostring(p.enumerated),shown(p.type),shown(p.info),typed(p.raw),typed(p.direct),typed(p.get),typed(p.display),typed(p.stringValue)},'|')
  return p
 end
 local function relevant(key)
  key=key:lower()
  for _,word in ipairs({'raw','value','rel','abs','layer','mask','active','mode','stor','author','flag','own'}) do if key:find(word,1,true) then return true end end
  return false
 end
 local function metadata(h)
  local n=safe(function() return h:PropertyCount() end)
  if type(n)~='number' or n<0 or n>512 then return nil,'PROPERTY_COUNT_UNAVAILABLE' end
  local indices,names,allNames={},{},{}
  for i=0,n-1 do
   local key=safe(function() return h:PropertyName(i) end)
   if type(key)=='string' then
    indices[key:lower()]={index=i,name=key}
    allNames[#allNames+1]=key:lower()
    if relevant(key) then names[#names+1]=key:lower() end
   end
  end
  if #names>96 then return nil,'RELEVANT_PROPERTY_LIMIT' end
  for _,key in ipairs({'RawValueAbs','RawValueRel','ValueAbsolute','ValueRelative','Layer','ValueLayer','Mask','Active','Mode','Storage','Relative'}) do
   if not indices[key:lower()] then names[#names+1]=key:lower(); allNames[#allNames+1]=key:lower() end
  end
  table.sort(names); table.sort(allNames)
  local values={}
  for _,key in ipairs(allNames) do
   local entry=indices[key]
   values[key]=property(h,entry and entry.name or key,entry and entry.index)
  end
  return values,names,allNames
 end
 local function parent(h) return safe(function() return h:Parent() end) end
 local function index(h) return safe(function() return h:Index() end) end
 local function link(h,key)
  local value=safe(function() return h[key] end) or read(h,key)
  return cls(value) and ident(value) or typed(value),value
 end
 local function dependencies(h)
  local values=safe(function() return h:GetDependencies() end)
  if type(values)~='table' then return '<unavailable>' end
  local list={}
  for _,value in pairs(values) do if #list<16 then list[#list+1]=cls(value) and ident(value) or typed(value) end end
  table.sort(list); return table.concat(list,';')
 end
 local function collect(root)
  local result,seen={},{}
  local function visit(h,depth,recipe,step)
   if not h or seen[h] or depth>8 or #result>64 then return end
   seen[h]=true
   local kind=cls(h)
   if kind=='PhaserRecipe' then recipe=h; step=nil end
   if kind=='PhaserRecipeStep' then step=h end
   if kind=='PhaserRecipeValueSource' then
    local key='recipe='..shown(recipe and index(recipe))..'/step='..shown(step and index(step))..'/source='..shown(index(h))
    result[#result+1]={key=key,handle=h,recipe=recipe,step=step}
   end
   local children=safe(function() return h:Children() end)
   if type(children)=='table' then for _,child in ipairs(children) do visit(child,depth+1,recipe,step) end end
  end
  visit(root,0,nil,nil)
  table.sort(result,function(a,b) return a.key<b.key end)
  return result
 end
 local function resolve(address)
  local found=safe(_G.ObjectList,address)
  if type(found)~='table' or #found~=1 or cls(found[1])~='Preset' then return nil end
  return found[1]
 end
 local function observe(caseName,item)
  local h=item.handle
  local properties,names,allNames=metadata(h)
  if not properties then return nil,names end
  local second=metadata(h)
  local stable=true
  for key,p in pairs(properties) do if not second[key] or second[key].signature~=p.signature then stable=false end end
  local attr,attrHandle=link(h,'Attributes')
  local feature=cls(attrHandle) and safe(function() return attrHandle.Feature end)
  local fg=cls(feature) and parent(feature)
  local preset=link(h,'Preset')
  local shape=link(h,'Shape')
  local known=caseName=='A' and 'REL_NEVER_AUTHORED_UI_BLANK' or 'REL_EXPLICIT_NUMERIC_ZERO'
  local raw=properties.rawvaluerel; local value=properties.valuerelative
  log('GROUND_TRUTH_CASE case=%s known_authoring=%s key=%s identity=%s native_path=%s parent_recipe=%s Step_index=%s ValueSource_index=%s RawValueRel=%s ValueRelative=%s property_evidence=raw_enum:%s;raw_type:%s;raw_role:%s;raw_direct:%s;raw_get:%s;raw_display:%s;relative_enum:%s;relative_type:%s;relative_direct:%s;relative_get:%s stable_reads=%s',
   caseName,known,item.key,ident(h),addr(h),item.recipe and ident(item.recipe) or '<nil>',shown(item.step and index(item.step)),shown(index(h)),typed(raw.get),typed(value.get),tostring(raw.enumerated),shown(raw.type),typed(raw.raw),typed(raw.direct),typed(raw.get),typed(raw.display),tostring(value.enumerated),shown(value.type),typed(value.direct),typed(value.get),tostring(stable))
  log('GROUND_TRUTH_LINKS case=%s key=%s Attribute=%s Feature=%s FeatureGroup=%s linked_Preset=%s Shape=%s dependencies=%s',caseName,item.key,attr,cls(feature) and ident(feature) or typed(feature),cls(fg) and ident(fg) or typed(fg),preset,shape,dependencies(h))
  log('GROUND_TRUTH_PROPERTY_NAMES case=%s key=%s all_count=%d focused_count=%d focused_names=%s',caseName,item.key,#allNames,#names,table.concat(names,','))
  for _,key in ipairs(names) do
   local p=properties[key]
   log('GROUND_TRUTH_PROPERTY case=%s key=%s name=%s enumerated=%s type=%s info=%s raw=%s direct=%s get=%s display=%s string=%s',caseName,item.key,key,tostring(p.enumerated),shown(p.type),shown(p.info),typed(p.raw),typed(p.direct),typed(p.get),typed(p.display),typed(p.stringValue))
  end
  return {properties=properties,stable=stable,attribute=attr,featureGroup=cls(fg) and ident(fg) or typed(fg),preset=preset,shape=shape}
 end
 local version=safe(function() return BuildDetails().BigVersion end)
 log('RAW_REL_GROUND_TRUTH_START revision=8_RAW_REL_GROUND_TRUTH_CONTROL version=%s sample_A=%s sample_B=%s raw_role_available=%s display_role_available=%s string_role_available=%s readonly=true no_markers=true no_waits=true no_cooked_scan=true no_oracle=true',shown(version),targets.A,targets.B,tostring(roles.Raw~=nil),tostring(roles.Display~=nil),tostring(roles.String~=nil))
 if version~='2.5.0.3' then
  log('RAW_REL_GROUND_TRUTH_RESULT classification=INCONCLUSIVE evidence=TARGET_VERSION_MISMATCH')
  return {classification='INCONCLUSIVE'}
 end
 local roots={A=resolve(targets.A),B=resolve(targets.B)}
 if not roots.A or not roots.B then
  log('RAW_REL_GROUND_TRUTH_RESULT classification=INCONCLUSIVE evidence=CONTROL_PRESET_UNAVAILABLE_OR_NONUNIQUE')
  return {classification='INCONCLUSIVE'}
 end
 local lists={A=collect(roots.A),B=collect(roots.B)}
 if #lists.A==0 or #lists.A~=#lists.B or #lists.A>64 then
  log('RAW_REL_GROUND_TRUTH_RESULT classification=INCONCLUSIVE evidence=VALUESOURCE_STRUCTURE_COUNT_MISMATCH A=%d B=%d',#lists.A,#lists.B)
  return {classification='INCONCLUSIVE'}
 end
 local diffs,semanticDiffs,invalid={},{},{}
 local seenKeys={}
 for i,a in ipairs(lists.A) do
  local b=lists.B[i]
  if seenKeys[a.key] then invalid[#invalid+1]='DUPLICATE_VALUESOURCE_KEY:'..a.key end
  seenKeys[a.key]=true
  if not a.recipe or not a.step or not b.recipe or not b.step
     or type(index(a.recipe))~='number' or type(index(a.step))~='number' or type(index(a.handle))~='number'
     or type(index(b.recipe))~='number' or type(index(b.step))~='number' or type(index(b.handle))~='number' then
   invalid[#invalid+1]='INCOMPLETE_VALUESOURCE_PARENT_OR_INDEX:'..a.key
  end
  if a.key~=b.key then invalid[#invalid+1]='STEP_OR_VALUESOURCE_KEY_MISMATCH:'..a.key..':'..b.key
  else
   local left,errorA=observe('A',a)
   local right,errorB=observe('B',b)
   if not left or not right then invalid[#invalid+1]='PROPERTY_AUDIT_FAILED:'..shown(errorA or errorB)
   else
    if not left.stable or not right.stable then invalid[#invalid+1]='UNSTABLE_NATIVE_READ:'..a.key end
    for _,field in ipairs({'attribute','featureGroup','preset','shape'}) do
     if left[field]~=right[field] then invalid[#invalid+1]='CONTROL_LINK_MISMATCH:'..field..':'..a.key end
    end
    local keys={}; for key in pairs(left.properties) do keys[key]=true end; for key in pairs(right.properties) do keys[key]=true end
    for key in pairs(keys) do
     local x,y=left.properties[key],right.properties[key]
     local xs=x and x.signature or '<absent>'; local ys=y and y.signature or '<absent>'
     if xs~=ys then
      diffs[#diffs+1]=a.key..':'..key
      log('GROUND_TRUTH_PROPERTY_DIFF key=%s property=%s A_enumerated=%s B_enumerated=%s A_type=%s B_type=%s A_info=%s B_info=%s A_raw=%s B_raw=%s A_direct=%s B_direct=%s A_Get=%s B_Get=%s A_display=%s B_display=%s A_string=%s B_string=%s stable_reads=%s',
       a.key,key,tostring(x and x.enumerated),tostring(y and y.enumerated),shown(x and x.type),shown(y and y.type),shown(x and x.info),shown(y and y.info),typed(x and x.raw),typed(y and y.raw),typed(x and x.direct),typed(y and y.direct),typed(x and x.get),typed(y and y.get),typed(x and x.display),typed(y and y.display),typed(x and x.stringValue),typed(y and y.stringValue),tostring(left.stable and right.stable))
      if key:find('abs',1,true) and not key:find('rel',1,true) then invalid[#invalid+1]='ABS_CONTROL_DIFFERENCE:'..a.key..':'..key end
      if relevant(key) and not (key:find('abs',1,true) and not key:find('rel',1,true)) then semanticDiffs[#semanticDiffs+1]=a.key..':'..key end
     end
    end
   end
  end
 end
 table.sort(diffs); table.sort(semanticDiffs); table.sort(invalid)
 local zero=false
 for _,item in ipairs(lists.B) do
  local m=metadata(item.handle)
  local raw=m and m.rawvaluerel
  if raw and (raw.direct==0 or raw.get==0 or raw.raw==0) then zero=true end
 end
 local classification,evidence
 if #invalid>0 then classification='INCONCLUSIVE'; evidence=table.concat(invalid,',')
 elseif not zero then classification='INCONCLUSIVE'; evidence='AUTHORED_ZERO_NOT_OBSERVED_AS_NUMERIC_RAW_ZERO'
 elseif #semanticDiffs>0 then classification='DISCRIMINATOR_PROVEN'; evidence='STABLE_MATCHED_VALUESOURCE_DIFF:'..table.concat(semanticDiffs,',')
 elseif #diffs>0 then classification='INCONCLUSIVE'; evidence='ONLY_NONSEMANTIC_PROPERTIES_DIFFER:'..table.concat(diffs,',')
 else classification='INCONCLUSIVE'; evidence='NO_NATIVE_PROPERTY_DIFF;SERIALIZATION_COMPARISON_PENDING' end
 log('RAW_REL_GROUND_TRUTH_RESULT classification=%s matched_valuesources=%d differences=%d evidence=%s',classification,#lists.A,#diffs,evidence)
 return {classification=classification,evidence=evidence,differences=diffs,matched=#lists.A}
end
