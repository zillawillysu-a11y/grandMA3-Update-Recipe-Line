-- Independent, bounded, read-only grandMA3 2.5.0.3 applicability observer.
-- Rev10.1: acquire A/B directly from ValueSource linked handles; no ShowData paths.
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
 local function classOf(h) return safe(function() return h:GetClass() end) end
 local function nameOf(h) return safe(function() return h.Name end) or safe(function() return h:Get('Name') end) end
 local function indexOf(h) return safe(function() return h:Index() end) end
 local function addrOf(h) return safe(function() return h:ToAddr() end) end
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
 local function presetPropType(h)
  local n=safe(function() return h:PropertyCount() end)
  if type(n)~='number' or n<0 or n>512 then return nil end
  for i=0,n-1 do
   local k=safe(function() return h:PropertyName(i) end)
   if type(k)=='string' and k:lower()=='preset' then return safe(function() return h:PropertyType(i) end) end
  end
 end
 local function acquire(linked,tag)
  local lc=classOf(linked)
  log('LINKED_HANDLE case=%s linked=%s class=%s name=%s index=%s toaddr=%s',tag,value(linked),tostring(lc),value(nameOf(linked)),value(indexOf(linked)),value(addrOf(linked)))
  if lc==nil then log('LINK_RESOLUTION case=%s method=FAILED reason=NO_LINKED_HANDLE',tag); return nil,'FAILED' end
  local chain={}; local cur=linked
  for depth=1,6 do
   local p=safe(function() return cur:Parent() end)
   if classOf(p)==nil then break end
   chain[#chain+1]=p
   log('LINK_PARENT case=%s depth=%d class=%s identity=%s name=%s index=%s',tag,depth,tostring(classOf(p)),value(p),value(nameOf(p)),value(indexOf(p)))
   cur=p
  end
  local depList={}
  local ds=safe(function() return linked:GetDependencies() end)
  if type(ds)=='table' then
   for i=1,math.min(#ds,32) do
    local d=ds[i]
    if classOf(d)~=nil then
     depList[#depList+1]=d
     log('LINK_DEPENDENCY case=%s slot=%d class=%s identity=%s name=%s',tag,i,tostring(classOf(d)),value(d),value(nameOf(d)))
    end
   end
  else log('LINK_DEPENDENCY case=%s status=UNAVAILABLE',tag) end
  local ref,method=nil,'FAILED'
  if lc=='Preset' then ref,method=linked,'DIRECT' end
  if not ref then for _,p in ipairs(chain) do if classOf(p)=='Preset' then ref,method=p,'PARENT_CHAIN' break end end end
  if not ref then for _,d in ipairs(depList) do if classOf(d)=='Preset' then ref,method=d,'DEPENDENCY' break end end end
  if not ref then
   local kids=safe(function() return linked:Children() end)
   if type(kids)=='table' then for i=1,math.min(#kids,64) do local k=kids[i] if classOf(k)=='Preset' then ref,method=k,'CHILD' break end end end
  end
  log('LINK_RESOLUTION case=%s method=%s resolved=%s linked_class=%s',tag,method,value(ref),tostring(lc))
  return ref,method
 end
 local function poolMatch(ref,poolRef)
  if not ref or not poolRef then return 'unavailable' end
  local refId=safe(_G.HandleToInt,ref); local poolId=safe(_G.HandleToInt,poolRef)
  return tostring(safe(_G.CompareHandle,ref,poolRef)==true or (refId~=nil and poolId~=nil and refId==poolId))
 end
 local version=safe(function() return BuildDetails().BigVersion end)
 log('LINKED_PRESET_APPLICABILITY_START revision=10_1_LINKED_PRESET_APPLICABILITY_ACQUISITION version=%s readonly=true no_cue_scan=true no_markers=true no_waits=true',value(version))
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
   log('CONTROL_VALUESOURCE step=%s identity=%s linked=%s preset_prop_type=%s attribute=%s shape=%s',tostring(step),ident(h),value(linked),value(presetPropType(h)),value(safe(function() return h.Attributes end)),value(safe(function() return h.Shape end)))
   links[step]=linked
  end
  local children=safe(function() return h:Children() end)
  if type(children)=='table' then for _,child in ipairs(children) do visit(child,step,depth+1) end end
 end
 visit(outer,nil,0)
 local samples={
  {tag='A',expected='UNIVERSAL_GLOBAL',linked=links[1],pool='Preset 1.100'},
  {tag='B',expected='SELECTIVE',linked=links[2],pool='Preset 1.23'},
  {tag='C',path='Preset 1.28',expected='UNIVERSAL'},
  {tag='D',path='Preset 1.14',expected='UNIVERSAL'},
 }
 local found=0; local modes={}; local failedAcq={}
 for _,s in ipairs(samples) do
  local ref,method
  if s.pool then
   ref,method=acquire(s.linked,s.tag)
   local poolRef=resolve(s.pool)
   log('LINK_VALIDATION case=%s label=%s pool_found=%s match=%s validation_only=true',s.tag,s.pool,tostring(poolRef~=nil),poolMatch(ref,poolRef))
   if not ref then failedAcq[#failedAcq+1]=s.tag end
  else
   ref=resolve(s.path); method='PATH'
  end
  if ref then
   found=found+1
   log('APPLICABILITY_CASE case=%s known_xml=%s identity=%s source=%s pool=%s',s.tag,s.expected,ident(ref),tostring(method),s.pool or s.path)
   local p=props(ref,s.tag)
   inspectData(ref,s.tag)
   modes[s.tag]=p.presetmode and value(p.presetmode.direct or p.presetmode.get) or '<unavailable>'
  else log('APPLICABILITY_CASE case=%s known_xml=%s status=UNAVAILABLE source=%s',s.tag,s.expected,tostring(method)) end
 end
 local classification='INCONCLUSIVE'; local evidence='NATIVE_COMPARISON_REQUIRES_REVIEW'
 if #failedAcq>0 then evidence='LINKED_ACQUISITION_FAILED:'..table.concat(failedAcq,',') end
 if #failedAcq==0 and found==4 and modes.A~='<unavailable>' and modes.B~='<unavailable>' and modes.A~=modes.B then
  classification='PARTIAL_APPLICABILITY_PROOF'; evidence='PRESETMODE_DIFFERS_BETWEEN_CONTROLLED_UNIVERSAL_AND_SELECTIVE;MEMBER_MAPPING_UNPROVEN'
 end
 log('LINKED_PRESET_APPLICABILITY_RESULT classification=%s samples=%d mode_A=%s mode_B=%s mode_C=%s mode_D=%s evidence=%s',classification,found,modes.A or '<missing>',modes.B or '<missing>',modes.C or '<missing>',modes.D or '<missing>',evidence)
end
