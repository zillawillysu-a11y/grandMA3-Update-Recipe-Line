-- Independent grandMA3 2.5.0.3 read-only observer. Exact native paths.
local CONFIG = {
 preset = 'Preset 4.4',
 groupA = 'Group 85', -- Test G1
 groupB = 'Group 86', -- Test G2
 cueA = 'Sequence 3858 Cue 1',
 cueB = 'Sequence 3858 Cue 2',
}

local function probe(api, config)
 config=config or CONFIG
 local t0=api.time and api.time()
 local function emit(fmt,...)
  api.log('GLOBAL_AB_'..string.format(fmt,...))
 end
 local function val(x) return x==nil and 'UNAVAILABLE' or tostring(x):gsub('[\r\n]',' '):sub(1,160) end
 local function normalizeCid(raw)
  if raw==nil or (type(raw)=='number' and raw==0) or raw=='None' then return 'NO_CID' end
  return 'UNPROVEN'
 end
 local function safe(f,...) local ok,v=pcall(f,...); if ok then return v end end
 local function class(h) return h and safe(function() return h:GetClass() end) end
 local function ident(h)
  if not h then return nil end
  local n=api.toInt and safe(api.toInt,h)
  if type(n)=='number' and n~=0 then return 'DBI:'..tostring(n) end
  local s=api.toStr and safe(api.toStr,h)
  if type(s)=='string' and s:match('^H#[%x]+$') then return 'DBH:'..s end
 end
 local function same(a,b)
  if not a or not b then return false end
  if a==b then return true end
  if api.compare and safe(api.compare,a,b)==true then return true end
  local x,y=ident(a),ident(b); return x~=nil and x==y
 end
 local function count(t) local n=0; for _ in pairs(t or {}) do n=n+1 end; return n end
 local function ordered(t) local a={}; for k in pairs(t or {}) do a[#a+1]=k end; table.sort(a); return a end
 local function hash(s)
  local h=1; for i=1,#s do h=(h*33+s:byte(i))%4294967291 end
  return string.format('%08x',h)
 end
 local reasons={}
 local function fail(s) reasons[s]=true end
 local function resolve(path,expected,label)
  if type(path)~='string' or path=='' then fail(label..'_PATH_REQUIRED'); return nil end
  local list=api.objectList and safe(api.objectList,path)
  if type(list)~='table' or #list~=1 or class(list[1])~=expected then fail(label..'_RESOLUTION_UNPROVEN'); return nil end
  return list[1]
 end
 local function resolvePart(path,label)
  if type(path)~='string' or path=='' then fail(label..'_PATH_REQUIRED'); return nil end
  local list=api.objectList and safe(api.objectList,path)
  if type(list)~='table' or #list~=1 then fail(label..'_RESOLUTION_UNPROVEN'); return nil end
  local h=list[1]
  if class(h)=='Part' then return h end
  if class(h)~='Cue' then fail(label..'_NOT_CUE_OR_PART'); return nil end
  local children=safe(function() return h:Children() end)
  local candidates={}
  if type(children)=='table' then for _,part in pairs(children) do if class(part)=='Part' then
   local recipes=safe(function() return part:Children() end)
   local n=0
   if type(recipes)=='table' then for _,r in pairs(recipes) do if class(r)=='StandardRecipe' or class(r)=='Recipe' then n=n+1 end end end
   if n>0 then candidates[#candidates+1]=part end
  end end end
  if #candidates~=1 then fail(label..'_UNIQUE_RECIPE_PART_UNPROVEN'); return nil end
  return candidates[1]
 end
 local preset=resolve(config.preset,'Preset','PRESET')
 local ga=resolve(config.groupA,'Group','GROUP_A')
 local gb=resolve(config.groupB,'Group','GROUP_B')
 local ca=resolvePart(config.cueA,'CUE_PART_A')
 local cb=resolvePart(config.cueB,'CUE_PART_B')
 if not ga or not gb or not ca or not cb then
  emit('PROBE_CONFIGURATION_REQUIRED groupA=%s groupB=%s cueA=%s cueB=%s requirement=EXACT_GROUP_AND_CUE_PART_PATHS',val(config.groupA),val(config.groupB),val(config.cueA),val(config.cueB))
 end
 local function group(g,side)
  if not g then return nil end
  local selection=safe(function() return g.Selection end)
  if type(selection)~='table' then fail('GROUP_'..side..'_SELECTION_UNAVAILABLE'); return nil end
  local members={}
  for _,item in pairs(selection) do
   if type(item)~='table' then fail('GROUP_'..side..'_MEMBER_SHAPE_UNPROVEN'); break end
   local sf=tonumber(item.sf_index)
   if not sf or sf<0 or sf%1~=0 or members[sf] then fail('GROUP_'..side..'_MEMBER_ID_UNPROVEN'); break end
   local grid=item.grid
   if type(grid)~='table' or tonumber(grid.x)==nil or tonumber(grid.y)==nil or tonumber(grid.z)==nil then
    fail('GRID_REPRESENTATION_UNPROVEN'); break
   end
   local h=api.getSubfixture and safe(api.getSubfixture,sf)
   local fid=h and safe(function() return h.FID end)
   local cid=h and safe(function() return h.CID end)
   local cidNormalized=normalizeCid(cid)
   local parent=h and safe(function() return h:Parent() end)
   if not h or not ident(h) or fid==nil then fail('GROUP_'..side..'_SUBFIXTURE_MAPPING_UNPROVEN'); break end
   members[sf]={sf=sf,handle=h,fid=fid,cid=cid,cidNormalized=cidNormalized,parent=parent,grid={x=tonumber(grid.x),y=tonumber(grid.y),z=tonumber(grid.z)}}
  end
  local ids=ordered(members)
  if #ids==0 or #ids>256 then fail('GROUP_'..side..'_MEMBER_COUNT_UNSUPPORTED') end
  local ms,gs,distinct={},{},{}
  for _,sf in ipairs(ids) do
   local m=members[sf]; local xyz=table.concat({m.grid.x,m.grid.y,m.grid.z},'/')
   ms[#ms+1]=tostring(sf); gs[#gs+1]=tostring(sf)..':'..xyz; distinct[xyz]=true
   if #ms<=32 then emit('GROUP_MEMBER side=%s member=%s parent=%s subfixture=%s fid=%s cid_raw=%s cid_normalized=%s grid_x=%s grid_y=%s grid_z=%s',side,val(sf),val(ident(m.parent)),val(ident(m.handle)),val(m.fid),val(m.cid),m.cidNormalized,val(m.grid.x),val(m.grid.y),val(m.grid.z)) end
  end
  local memberHash,gridHash=hash(table.concat(ms,',')),hash(table.concat(gs,','))
  emit('GROUP side=%s group=%s member_count=%d member_set_hash=%s grid_hash=%s grid_distinct_positions=%d member_sample_shown=%d',side,val(config['group'..side]),#ids,memberHash,gridHash,count(distinct),math.min(#ids,32))
  return {members=members,ids=ids,memberHash=memberHash,gridHash=gridHash}
 end
 local a,b=group(ga,'A'),group(gb,'B')
 local sameMembers=a and b and #a.ids==#b.ids and a.memberHash==b.memberHash
 if sameMembers then for _,sf in ipairs(a.ids) do if not b.members[sf] or not same(a.members[sf].handle,b.members[sf].handle) then sameMembers=false; break end end end
 if not sameMembers then fail('GROUP_MEMBER_SET_DIFFERENT_OR_UNPROVEN') end
 local gridChanged=sameMembers and a.gridHash~=b.gridHash
 if not gridChanged then fail('GROUP_GRID_NOT_PROVEN_DIFFERENT') end
 local function recipe(part,g,side)
  if not part then return end
  local children=safe(function() return part:Children() end)
  local found={}
  if type(children)=='table' then for _,r in pairs(children) do if class(r)=='StandardRecipe' or class(r)=='Recipe' then found[#found+1]=r end end end
  if #found~=1 then fail('CUE_'..side..'_SINGLE_RECIPE_UNPROVEN'); return end
  local r=found[1]
  local enabled=safe(function() return r.Enabled end)
  if enabled==nil then enabled=safe(function() return r:Get('Enabled') end) end
  if enabled==false or tostring(enabled):lower()=='no' or tostring(enabled):lower()=='false' or tostring(enabled)=='0' then fail('CUE_'..side..'_RECIPE_DISABLED') end
  local function linked(name)
   local direct=safe(function() return r[name] end)
   if class(direct) then return direct end
   local raw=safe(function() return r:Get(name) end)
   if raw==nil then raw=safe(function() return r:Get(name:upper()) end) end
   if class(raw) then return raw end
   local path=type(raw)=='string' and raw or (type(direct)=='string' and direct or nil)
   local list=path and api.objectList and safe(api.objectList,path)
   return type(list)=='table' and #list==1 and list[1] or nil
  end
  if not same(linked('Selection'),g) then fail('CUE_'..side..'_RECIPE_GROUP_MISMATCH') end
  if not same(linked('Values'),preset) then fail('CUE_'..side..'_RECIPE_PRESET_MISMATCH') end
 end
 recipe(ca,ga,'A'); recipe(cb,gb,'B')
 local raw=preset and api.getPresetData and safe(api.getPresetData,preset,false,false)
 local storedView=preset and api.getPresetData and safe(api.getPresetData,preset,false,true)
 local attrs,dist={},{mask={},phaser={},grid={},matrix={},mode={},selective={}}
 local function shape(x)
  if type(x)~='table' then return type(x)..':'..val(x) end
  local keys={}; for k in pairs(x) do keys[#keys+1]=tostring(k) end; table.sort(keys)
  return 'table:'..#keys..':'..table.concat(keys,','):sub(1,80)
 end
 if type(raw)~='table' then fail('PRESET_DATA_UNAVAILABLE')
 else for ui,p in pairs(raw) do if type(ui)=='number' and type(p)=='table' then
  local h=p.attribute or (api.attributeByUI and safe(api.attributeByUI,ui))
  local name=h and (safe(function() return h.Name end) or safe(function() return h:Get('Name') end))
  if type(name)~='string' or name=='' then fail('PRESET_ATTRIBUTE_NAME_UNPROVEN') else attrs[name]=true end
  for _,pair in ipairs({{'mask',p.mask_individual},{'phaser',p.mask_active_phaser},{'grid',shape(p.gridpos)},{'matrix',shape(p.gridposmatr)},{'mode',p.preset_store_mode or p.pm},{'selective',p.selective}}) do
   local d=dist[pair[1]]; local key=val(pair[2]); d[key]=(d[key] or 0)+1
  end
  if (p.preset_store_mode or p.pm)~=2 or p.selective~=false or (type(p.dict_flags)=='table' and p.dict_flags.selective==true) then fail('PRESET_NOT_GLOBAL_NONSELECTIVE') end
 end end end
 local function distribution(d) local entries={}; for k,v in pairs(d) do entries[#entries+1]=k..':'..v end; table.sort(entries); return table.concat(entries,',') end
 local storedCount=type(storedView)=='table' and storedView.count or nil
 emit('PRESET reference=%s store_mode=%s selective=%s channels=%d stored_fixture_view_count=%s mask_individual_distribution=%s mask_active_phaser_distribution=%s gridpos_shape=%s gridposmatr_shape=%s attributes=%s metadata_only=true',val(config.preset),distribution(dist.mode),distribution(dist.selective),count(attrs),val(storedCount),distribution(dist.mask),distribution(dist.phaser),distribution(dist.grid),distribution(dist.matrix),table.concat(ordered(attrs),','))
 if count(attrs)==0 then fail('PRESET_ATTRIBUTES_UNPROVEN') end
 local function cooked(part,side,g)
  local result={}
  if not part or not g then return result end
  local data=api.getPresetData and safe(api.getPresetData,part,false,true)
  local buckets=type(data)=='table' and data.by_fixtures
  if type(buckets)~='table' then fail('CUE_'..side..'_COOKED_VIEW_UNAVAILABLE'); return result end
  local fixtureKeys={}
  for _,sf in ipairs(g.ids) do
   local m=g.members[sf]; local key=tostring(m.fid)
   if m.cidNormalized~='NO_CID' then fail('COOKED_SUBFIXTURE_KEY_UNPROVEN') end
   if fixtureKeys[key] then fail('COOKED_MEMBER_KEY_COLLISION') else fixtureKeys[key]=true end
   local bucket=buckets[key]
   if bucket~=nil and type(bucket)~='table' then fail('COOKED_MEMBER_SHAPE_UNPROVEN') end
   result[sf]={}
   for _,attr in ipairs(ordered(attrs)) do
    local p=type(bucket)=='table' and bucket[attr] or nil
    local present=type(p)=='table'
    local link=present and p.abs_preset or nil
    local matches=present and same(link,preset) or false
    local absolute=present and type(p[1])=='table' and p[1].absolute or nil
    result[sf][attr]={present=present,link=link,matches=matches}
    emit('COOKED_MEMBER side=%s member=%s attribute=%s present=%s absolute=%s abs_preset=%s abs_preset_matches=%s rel_preset=%s',side,val(sf),val(attr),tostring(present),val(absolute),val(ident(link) or link),tostring(matches),val(present and (ident(p.rel_preset) or p.rel_preset)))
   end
  end
  return result
 end
 local cookedA,cookedB=cooked(ca,'A',a),cooked(cb,'B',b)
 local presenceSame,mappingSame,changed=true,true,{}
 if sameMembers then for _,sf in ipairs(a.ids) do for _,attr in ipairs(ordered(attrs)) do
  local x,y=cookedA[sf] and cookedA[sf][attr],cookedB[sf] and cookedB[sf][attr]
  if not x or not y then fail('COOKED_MAPPING_UNPROVEN')
  else
   if x.present~=y.present then presenceSame=false; changed[sf]=true end
   if x.matches~=y.matches then mappingSame=false; changed[sf]=true end
   if x.present and y.present and not x.matches and not y.matches then fail('COOKED_PRESET_LINK_UNPROVEN') end
   if not x.present and not y.present then fail('COOKED_ATTRIBUTE_ABSENT_BOTH') end
  end
 end end end
 local passed=next(reasons)==nil
 local names=ordered(reasons)
 emit('PRECHECK pass=%s preset=%s group_a=%s group_b=%s cue_part_a=%s cue_part_b=%s same_members=%s grid_changed=%s reasons=%s',tostring(passed),tostring(preset~=nil),tostring(ga~=nil),tostring(gb~=nil),tostring(ca~=nil),tostring(cb~=nil),tostring(sameMembers==true),tostring(gridChanged==true),table.concat(names,','))
 local classification='INCONCLUSIVE'
 if passed then
  if presenceSame and mappingSame then classification='GRID_NO_OBSERVED_MEMBER_EFFECT'
  else classification='GRID_OBSERVED_MEMBER_EFFECT' end
  emit('RESULT classification=%s preset=%s scope=CONTROLLED_PRESET_AND_FIXTURE_TYPE_ONLY',classification,val(config.preset))
 end
 emit('DIFF same_members=%s grid_changed=%s cooked_member_presence_same=%s abs_preset_mapping_same=%s changed_members=%s classification=%s',tostring(sameMembers==true),tostring(gridChanged==true),tostring(presenceSame),tostring(mappingSame),table.concat(ordered(changed),','),classification)
 local finish=api.time and api.time()
 emit('TIMING total_ms=%s',type(t0)=='number' and type(finish)=='number' and finish>=t0 and tostring((finish-t0)*1000) or 'UNVERIFIED')
 return {classification=classification,precheck=passed,sameMembers=sameMembers,gridChanged=gridChanged,presenceSame=presenceSame,mappingSame=mappingSame,reasons=reasons}
end

if ... == 'TEST' then return probe end
return function()
 local api={time=Time,log=function(s) Printf('%s',s) end,objectList=ObjectList,toInt=HandleToInt,toStr=HandleToStr,compare=CompareHandle,
  getSubfixture=GetSubfixture,getPresetData=GetPresetData,attributeByUI=GetAttributeByUIChannel}
 local version=BuildDetails and BuildDetails().BigVersion
 if version~='2.5.0.3' then
  Printf('%s','GLOBAL_AB_PRECHECK pass=false reasons=VERSION_MISMATCH')
  Printf('%s','GLOBAL_AB_DIFF classification=INCONCLUSIVE')
  Printf('%s','GLOBAL_AB_TIMING total_ms=UNVERIFIED')
  return
 end
 local ok,err=pcall(probe,api,CONFIG)
 if not ok then
  Printf('%s','GLOBAL_AB_PRECHECK pass=false reasons=OBSERVER_ERROR error='..tostring(err):gsub('[\r\n]',' '):sub(1,200))
  Printf('%s','GLOBAL_AB_DIFF classification=INCONCLUSIVE')
  Printf('%s','GLOBAL_AB_TIMING total_ms=UNVERIFIED')
 end
end
