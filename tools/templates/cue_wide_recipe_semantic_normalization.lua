-- Rev13.2 cached-metadata observer only. No result feeds resolver gates.
function __rev132SemanticNormalize(raw,control,identity)
 local function atom(v)
  local t=type(v)
  if t=='number' or t=='boolean' or t=='string' then return t..':'..tostring(v):gsub('[,|\r\n]','_'):sub(1,48) end
  return t
 end
 local function sorted(set)
  local a={}; for k in pairs(set) do a[#a+1]=k end; table.sort(a); return table.concat(a,',')
 end
 local function number(t) local n=0; for _ in pairs(t) do n=n+1 end; return n end
 local function tableValue(t,depth)
  if type(t)~='table' then return atom(t) end
  if depth>3 then return 'DEPTH_UNPROVEN' end
  local a,n={},0
  for k,v in pairs(t) do
   n=n+1; if n>256 then return 'SIZE_UNPROVEN' end
   local key=type(k)=='number' and '#' or atom(k)
   a[#a+1]=key..'='..tableValue(v,depth+1)
  end
  table.sort(a); return '{'..table.concat(a,';')..'}'
 end
 local known={attribute=true,abs_preset=true,rel_preset=true,abs_generator=true,rel_generator=true,generator=true,
  mask_active_phaser=true,mask_active_value=true,mask_cooked=true,mask_individual=true,mask_integrated=true,
  dict_flags=true,dict_index=true,gridposmatr=true,gridpos=true,grid=true,phase=true,speed=true,measure=true,
  fade=true,delay=true,selective=true,preset_store_mode=true,pm=true,ui_channel_index=true,
  grid_origin=true,grid_matrix=true,nshot_count=true,nshot_flags=true,speed_master=true}
 local stepKnown={absolute=true,relative=true,absolute_value=true,abs_release=true,rel_release=true,
  abs_remove=true,rel_remove=true,abs_preset=true,rel_preset=true,integrated=true,accel=true,decel=true,
  trans=true,transition=true,width=true,channel_function=true,mask_active=true,mask_individual=true,
  mask_integrated=true,dict_flags=true}
 local function core(p)
  local parts={}
  for _,field in ipairs({'preset_store_mode','pm','selective','mask_active_phaser','mask_individual',
   'mask_active_value','mask_cooked','mask_integrated'}) do parts[#parts+1]=field..'='..atom(p[field]) end
  local flags=p.dict_flags
  for _,field in ipairs({'has_absolute','has_relative','blocked','blocked_rel','selective'}) do
   parts[#parts+1]='dict_flags.'..field..'='..atom(type(flags)=='table' and flags[field] or nil)
  end
  if flags~=nil and type(flags)~='table' then parts[#parts+1]='dict_flags_type='..type(flags) end
  if type(flags)=='table' then for k,v in pairs(flags) do
   if not ({has_absolute=true,has_relative=true,blocked=true,blocked_rel=true,selective=true})[k]
    and v~=nil and v~=false and v~=0 then parts[#parts+1]='unknown_dict_flag='..atom(k)..'/'..tableValue(v,0) end
  end end
  local steps,first=0,nil
  for k,v in pairs(p) do
   if type(k)=='number' then steps=steps+1; if k==1 then first=v end
   elseif type(k)=='string' and not known[k] and v~=nil and v~=false and v~=0 then
    parts[#parts+1]='unknown_field='..k..'/'..tableValue(v,0) end
  end
  parts[#parts+1]='step_count='..steps
  if type(first)=='table' then
   parts[#parts+1]='ABS='..tostring(first.absolute~=nil)
   parts[#parts+1]='REL='..tostring(first.relative~=nil)
   for k,v in pairs(first) do if type(k)=='string' and not stepKnown[k] and v~=nil and v~=false and v~=0 then
    parts[#parts+1]='unknown_step='..k..'/'..tableValue(v,0) end end
   for _,field in ipairs({'abs_release','rel_release','abs_remove','rel_remove','abs_preset','rel_preset','integrated','accel','decel','trans','transition','width'}) do
    if first[field]~=nil and first[field]~=false and first[field]~=0 then parts[#parts+1]='step_effect='..field..'/'..tableValue(first[field],0) end
   end
  else parts[#parts+1]='step_type='..type(first) end
  table.sort(parts)
  return table.concat(parts,'|')
 end
 local function channels(data)
  local items,signatures={},{}
  if type(data)~='table' then return items,signatures,false end
  for ui,p in pairs(data) do if type(ui)=='number' then
   if type(p)~='table' or #items>=262144 then return items,signatures,false end
   items[#items+1]={ui=ui,p=p}; signatures[core(p)]=true
  end end
  return items,signatures,true
 end
 local items,candidateCore,candidateOK=channels(raw)
 local controlItems,controlCore,controlOK=channels(control)
 local function uiKeys(entries)
  local a={}; for _,entry in ipairs(entries) do a[#a+1]=tostring(entry.ui) end
  table.sort(a); return table.concat(a,',')
 end
 local out={semanticCoreMatch=candidateOK and controlOK and #items>0 and #controlItems>0 and sorted(candidateCore)==sorted(controlCore),
  channelCount=#items,controlChannelCount=#controlItems,blockers={},dictAudit={}}
 out.uiChannelKeyRelation=uiKeys(items)==uiKeys(controlItems) and 'SAME_NUMERIC_KEYS' or 'DIFFERENT_NUMERIC_KEYS'
  if not candidateOK or not controlOK then out.blockers.METADATA_SHAPE_UNPROVEN=true end
  if not out.semanticCoreMatch then out.blockers.SEMANTIC_CORE_DIFFERENCE=true end
  local indexes,types,uiExact,uiFieldExact,uiOffset={}, {},true,true,nil
  local attrToIndex,indexToAttr,gridToIndex,indexToGrid={},{},{},{}
  local attrsKnown,gridsKnown=true,true
  local function relate(left,right,m1,m2)
   if m1[left] and m1[left]~=right then return false end
   if m2[right] and m2[right]~=left then return false end
   m1[left]=right; m2[right]=left; return true
  end
  local attrBijection,gridBijection=true,true
  for _,item in ipairs(items) do
   local p,ui=item.p,item.ui; local di=p.dict_index
   local token=atom(di); indexes[token]=(indexes[token] or 0)+1; types[type(di)]=true
   if type(di)~='number' or math.type(di)~='integer' or di~=ui then uiExact=false end
   if p.ui_channel_index==nil or di~=p.ui_channel_index then uiFieldExact=false end
   if type(di)=='number' and type(ui)=='number' then
    local offset=di-ui; if uiOffset==nil then uiOffset=offset elseif uiOffset~=offset then uiOffset=false end
   else uiOffset=false end
   local attr=p.attribute and identity and identity(p.attribute)
   if not attr then attrsKnown=false else
    if not relate(attr,token,attrToIndex,indexToAttr) then attrBijection=false end end
   if p.gridpos==nil then gridsKnown=false else
    local grid=tableValue(p.gridpos,0)
    if grid:find('UNPROVEN',1,true) then gridsKnown=false end
    if not relate(grid,token,gridToIndex,indexToGrid) then gridBijection=false end
   end
  end
  local unique=number(indexes); local distribution={}
  for token,n in pairs(indexes) do distribution[#distribution+1]=token..':'..n end
  table.sort(distribution)
  out.dictAudit.channelCount=#items; out.dictAudit.uniqueCount=unique
  out.dictAudit.distribution='types='..sorted(types)..'/unique='..unique..'/sample='..table.concat(distribution,',',1,math.min(6,#distribution))
  out.dictAudit.relationUI=uiExact and 'EXACT_UI_KEY' or (uiFieldExact and 'EXACT_UI_CHANNEL_FIELD' or (uiOffset~=false and uiOffset~=nil and 'CONSTANT_OFFSET_'..tostring(uiOffset) or 'UNPROVEN'))
  out.dictAudit.relationAttribute=attrsKnown and attrBijection and 'BIJECTION_OBSERVED' or (attrsKnown and 'NOT_BIJECTIVE' or 'UNAVAILABLE')
  out.dictAudit.relationGrid=gridsKnown and gridBijection and 'BIJECTION_OBSERVED' or (gridsKnown and 'NOT_BIJECTIVE' or 'UNAVAILABLE')
  if #items==0 or number(types)~=1 or not types.number then
   out.dictAudit.classification='UNPROVEN'; out.dictAudit.reasons='DICT_INDEX_SHAPE_OR_CHANNELS_UNPROVEN'
  elseif uiExact or uiFieldExact then
   out.dictAudit.classification='IDENTITY_LIKE_ONLY'; out.dictAudit.reasons='EXACT_UI_IDENTITY_RELATION'
  elseif unique==#items and #items~=#controlItems then
   out.dictAudit.classification='CARDINALITY_DEPENDENT'; out.dictAudit.reasons='UNIQUE_PER_CHANNEL_WITH_DIFFERENT_CHANNEL_COUNT;SEMANTICS_UNPROVEN'
  else out.dictAudit.classification='UNPROVEN'; out.dictAudit.reasons='NO_PROVEN_IDENTITY_RELATION' end
  if out.dictAudit.classification~='IDENTITY_LIKE_ONLY' then out.blockers.DICT_INDEX_MEANING_UNPROVEN=true end
  return out
end
