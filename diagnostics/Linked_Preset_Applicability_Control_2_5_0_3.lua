-- Independent, bounded, read-only grandMA3 2.5.0.3 applicability observer.
return function()
 local emit=_G.Printf
 local function log(fmt,...) emit('%s','[LinkedApplicability] '..string.format(fmt,...)) end
 local function safe(fn,...) if type(fn)~='function' then return nil end; local ok,v=pcall(fn,...); if ok then return v end end
 local function value(v)
  if v==nil then return 'nil:<nil>' end
  local t=type(v)
  if t=='string' then return 'string:'..(v=='' and '<empty>' or v:gsub('[\r\n]',' '):sub(1,100)) end
  if t=='number' or t=='boolean' then return t..':'..tostring(v) end
  if t=='userdata' or t=='table' then
   local c=safe(function() return v:GetClass() end)
   if c then return 'handle:'..tostring(safe(_G.HandleToInt,v))..':'..tostring(safe(_G.HandleToStr,v)) end
  end
  return t..':<opaque>'
 end
 local function ident(h) return value(h) end
 local function resolve(path)
  local list=safe(_G.ObjectList,path)
  if type(list)=='table' and #list==1 and safe(function() return list[1]:GetClass() end)=='Preset' then return list[1] end
 end
 local function props(h,tag)
  local n=safe(function() return h:PropertyCount() end)
  if type(n)~='number' or n<0 or n>512 then log('PROPERTY_AUDIT case=%s status=UNAVAILABLE',tag); return {} end
  local result={}
  for i=0,n-1 do
   local k=safe(function() return h:PropertyName(i) end)
   if type(k)=='string' then
    local low=k:lower()
    if low:find('mode',1,true) or low:find('select',1,true) or low:find('preset',1,true) or low:find('member',1,true) or low:find('idtype',1,true) or low:find('grid',1,true) or low:find('mask',1,true) or low:find('value',1,true) then
     local d=safe(function() return h[k] end); local g=safe(function() return h:Get(k) end)
     local d2=safe(function() return h[k] end); local g2=safe(function() return h:Get(k) end)
     local displayRole=((_G.Enums or {}).Roles or {}).Display
     local display=displayRole and safe(function() return h:Get(k,displayRole) end)
     result[low]={direct=d,get=g,display=display}
     log('NATIVE_PROPERTY case=%s name=%s declared=%s direct=%s Get=%s display=%s stable=%s',tag,k,tostring(safe(function() return h:PropertyType(i) end)),value(d),value(g),value(display),tostring(value(d)==value(d2) and value(g)==value(g2)))
    end
   end
  end
  for _,k in ipairs({'PresetMode','Mode','Selective','IDType'}) do
   if not result[k:lower()] then
    local d=safe(function() return h[k] end); local g=safe(function() return h:Get(k) end)
    result[k:lower()]={direct=d,get=g}
    log('NATIVE_PROPERTY case=%s name=%s enumerated=false direct=%s Get=%s',tag,k,value(d),value(g))
   end
  end
  return result
 end
 local function simple(v)
  if type(v)=='table' then
   local fields={}; for k,x in pairs(v) do if type(k)=='string' and type(x)~='table' then fields[#fields+1]=k..'='..value(x) end end
   table.sort(fields); return table.concat(fields,',')
  end
  return value(v)
 end
 local function inspectData(ref,tag)
  local data=safe(_G.GetPresetData,ref,false,false)
  if type(data)~='table' then log('PRESET_DATA case=%s status=UNAVAILABLE',tag); return nil end
  local keys={}; for k,p in pairs(data) do if type(k)=='number' and type(p)=='table' then keys[#keys+1]=k end end
  table.sort(keys)
  log('PRESET_DATA case=%s channels=%d count=%s by_fixtures=%s',tag,#keys,value(data.count),value(data.by_fixtures))
  for i=1,math.min(#keys,64) do
   local ui=keys[i]; local p=data[ui]
   log('PRESET_RECORD case=%s ui_key=%s fields=%s dict_flags=%s gridpos=%s gridposmatr=%s',tag,value(ui),simple(p),simple(p.dict_flags),simple(p.gridpos),simple(p.gridposmatr))
   local attr=p.attribute
   local feature=attr and safe(function() return attr.Feature end)
   local group=feature and safe(function() return feature:Parent() end)
   log('PRESET_ATTRIBUTE case=%s ui_key=%s Attribute=%s Feature=%s FeatureGroup=%s',tag,value(ui),value(attr),value(feature),value(group))
   local steps={}; for k,x in pairs(p) do if type(k)=='number' and type(x)=='table' then steps[#steps+1]=k end end
   table.sort(steps)
   for j=1,math.min(#steps,8) do log('PRESET_STEP case=%s ui_key=%s step=%d fields=%s',tag,value(ui),steps[j],simple(p[steps[j]])) end
  end
 if #keys>64 then log('PRESET_DATA_LIMIT case=%s omitted=%d',tag,#keys-64) end
  local byMembers=safe(_G.GetPresetData,ref,false,true)
  if type(byMembers)=='table' then
   local memberKeys={}
   for k,p in pairs(byMembers.by_fixtures or byMembers) do
    if type(p)=='table' then memberKeys[#memberKeys+1]=tostring(k) end
   end
   table.sort(memberKeys)
   log('PRESET_MEMBER_VIEW case=%s member_count=%d by_fixtures=%s keys=%s',tag,#memberKeys,value(byMembers.by_fixtures),table.concat(memberKeys,','))
  else log('PRESET_MEMBER_VIEW case=%s status=UNAVAILABLE',tag) end
  return data
 end
 local version=safe(function() return BuildDetails().BigVersion end)
 log('LINKED_PRESET_APPLICABILITY_START revision=10_LINKED_PRESET_APPLICABILITY_CONTROL version=%s readonly=true no_cue_scan=true no_markers=true no_waits=true',value(version))
 if version~='2.5.0.3' then log('LINKED_PRESET_APPLICABILITY_RESULT classification=INCONCLUSIVE evidence=VERSION_MISMATCH'); return end
 local outer=resolve('Preset 25.9014')
 if not outer then log('LINKED_PRESET_APPLICABILITY_RESULT classification=INCONCLUSIVE evidence=OUTER_CONTROL_UNAVAILABLE'); return end
 local links={}
 local function visit(h,step,depth)
  if depth>8 then return end
  local c=safe(function() return h:GetClass() end)
  if c=='PhaserRecipeStep' then step=safe(function() return h:Index() end) end
  if c=='PhaserRecipeValueSource' and (step==1 or step==2) then
   local linked=safe(function() return h.Preset end) or safe(function() return h:Get('Preset') end)
   log('CONTROL_VALUESOURCE step=%s identity=%s linked=%s attribute=%s shape=%s',tostring(step),ident(h),value(linked),value(safe(function() return h.Attributes end)),value(safe(function() return h.Shape end)))
   links[step]=linked
  end
  local children=safe(function() return h:Children() end)
  if type(children)=='table' then for _,child in ipairs(children) do visit(child,step,depth+1) end end
 end
 visit(outer,nil,0)
 local samples={
  {tag='A',path='ShowData.DataPools.Default.PresetPools.Dimmer.100',expected='UNIVERSAL_GLOBAL',linked=links[1]},
  {tag='B',path='ShowData.DataPools.Default.PresetPools.Dimmer.23',expected='SELECTIVE',linked=links[2]},
  {tag='C',path='Preset 1.28',expected='UNIVERSAL'},
  {tag='D',path='Preset 1.14',expected='UNIVERSAL'},
 }
 local found=0; local modes={}
 for _,s in ipairs(samples) do
  local ref=resolve(s.path)
  if ref then
   found=found+1
   local linked=s.linked
   if type(linked)=='string' then linked=resolve(linked) end
   local refId=safe(_G.HandleToInt,ref)
   local linkedId=linked and safe(_G.HandleToInt,linked)
   local linkedOK=not s.linked or safe(_G.CompareHandle,ref,linked)==true or (refId~=nil and linkedId~=nil and refId==linkedId)
   log('APPLICABILITY_CASE case=%s known_xml=%s identity=%s path=%s linked_step_match=%s',s.tag,s.expected,ident(ref),s.path,tostring(linkedOK))
   local p=props(ref,s.tag)
   inspectData(ref,s.tag)
   modes[s.tag]=p.presetmode and value(p.presetmode.direct or p.presetmode.get) or '<unavailable>'
  else log('APPLICABILITY_CASE case=%s known_xml=%s status=UNAVAILABLE path=%s',s.tag,s.expected,s.path) end
 end
 local classification='INCONCLUSIVE'; local evidence='NATIVE_COMPARISON_REQUIRES_REVIEW'
 if found==4 and modes.A~='<unavailable>' and modes.B~='<unavailable>' and modes.A~=modes.B then
  classification='PARTIAL_APPLICABILITY_PROOF'; evidence='PRESETMODE_DIFFERS_BETWEEN_CONTROLLED_UNIVERSAL_AND_SELECTIVE;MEMBER_MAPPING_UNPROVEN'
 end
 log('LINKED_PRESET_APPLICABILITY_RESULT classification=%s samples=%d mode_A=%s mode_B=%s mode_C=%s mode_D=%s evidence=%s',classification,found,modes.A or '<missing>',modes.B or '<missing>',modes.C or '<missing>',modes.D or '<missing>',evidence)
end
