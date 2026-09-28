-- Rev13 diagnostic only. The Preset 4.4 A/B observation is a controlled
-- fixture/attribute case; matching metadata alone does not transfer that proof.
function __rev13GlobalApplicability(raw, control, staticProof, groupScope, compatibilityProven)
 local out={reasons={},signatures={},modes={},selective={},gridMasks={},individualMasks={},valueMasks={},steps={},layers={}}
 local function block(reason) out.reasons[reason]=true end
 local function shape(x)
  if x==nil then return 'nil' end
  if type(x)~='table' then return type(x)..':'..tostring(x) end
  local keys={}
  for k,v in pairs(x) do keys[#keys+1]=type(k)..':'..tostring(k)..'='..type(v) end
  table.sort(keys)
  return 'table{'..table.concat(keys,',')..'}'
 end
 local known={attribute=true,abs_preset=true,rel_preset=true,abs_generator=true,rel_generator=true,generator=true,
  mask_active_phaser=true,mask_active_value=true,mask_cooked=true,mask_individual=true,mask_integrated=true,
  dict_flags=true,dict_index=true,gridposmatr=true,gridpos=true,grid=true,phase=true,speed=true,measure=true,
  fade=true,delay=true,selective=true,preset_store_mode=true,pm=true,ui_channel_index=true,
  grid_origin=true,grid_matrix=true,nshot_count=true,nshot_flags=true,speed_master=true}
 local function signatures(data, target)
  local set={}
  if type(data)~='table' then block('REFERENCE_DATA_UNAVAILABLE'); return set end
  for ui,p in pairs(data) do
   if type(ui)=='number' then
    if type(p)~='table' then block('CHANNEL_SHAPE_UNPROVEN') else
     local mode=p.preset_store_mode or p.pm
     target.modes[tostring(mode)]=true
     target.selective[tostring(p.selective)..'/'..tostring(type(p.dict_flags)=='table' and p.dict_flags.selective or nil)]=true
     target.gridMasks[tostring(p.mask_active_phaser)]=true
     target.individualMasks[tostring(p.mask_individual)]=true
     target.valueMasks[tostring(p.mask_active_value)]=true
     local n,step=0,nil
     for k,v in pairs(p) do
      if type(k)=='number' then n=n+1; if k==1 then step=v end
      elseif type(k)=='string' and not known[k] and v~=nil and v~=false and v~=0 then block('UNKNOWN_ACTIVE_FIELD_'..k) end
     end
     target.steps[tostring(n)]=true
     local layer=(type(step)=='table' and step.absolute~=nil and 'ABS' or '')..(type(step)=='table' and step.relative~=nil and '+REL' or '')
     target.layers[layer]=true
     if mode~=2 or p.selective~=false or (type(p.dict_flags)=='table' and p.dict_flags.selective~=nil and p.dict_flags.selective~=false and p.dict_flags.selective~=0) then block('NOT_GLOBAL_NONSELECTIVE') end
     if p.pm~=nil and p.preset_store_mode~=nil and p.pm~=p.preset_store_mode then block('CONFLICTING_STORE_MODE') end
     local signature=table.concat({tostring(mode),tostring(p.selective),tostring(type(p.dict_flags)=='table' and p.dict_flags.selective or nil),
      tostring(p.mask_active_phaser),tostring(p.mask_individual),tostring(p.mask_active_value),tostring(p.mask_cooked),
      shape(p.dict_flags),shape(p.dict_index),tostring(p.mask_integrated),
      tostring(n),layer,shape(p.gridpos),shape(p.gridposmatr)},'|')
     set[signature]=true
    end
   elseif ui~='count' and ui~='by_fixtures' then block('UNKNOWN_TOP_LEVEL_FIELD') end
  end
  if not next(set) then block('EMPTY_CHANNEL_SHAPE') end
  return set
 end
 local controlOut={modes={},selective={},gridMasks={},individualMasks={},valueMasks={},steps={},layers={}}
 local controlSet=signatures(control,controlOut)
 local candidateSet=signatures(raw,out)
 local sameShape=true
 for signature in pairs(candidateSet) do if not controlSet[signature] then sameShape=false; block('DIFFERENT_NATIVE_CONTROL_SEMANTIC_SHAPE') end end
 if not staticProof or not staticProof.motionStaticProven then block('MOTION_STATIC_UNPROVEN') end
 if type(groupScope)~='table' or not next(groupScope) then block('RECIPE_GROUP_MEMBER_SCOPE_UNPROVEN') end
 if not compatibilityProven then block('FIXTURE_ATTRIBUTE_COMPATIBILITY_UNPROVEN') end
 out.matchesNativeProvenClass=next(out.reasons)==nil
 out.semanticShape=next(candidateSet) and (sameShape and 'CONTROL_SIGNATURE_SUBSET' or 'DIFFERENT_FROM_CONTROL') or 'UNPROVEN'
 return out
end

-- Resolve the configured pool addresses to native handles, then compare only
-- stable reference identities. Display descriptions are never identity keys.
function __rev13SelectGlobalTargets(paths, objectList, identity, class, records)
 local out={entries={},found=0,missing={},duplicates={}}
 local owners={}
 for _,path in ipairs(paths) do
  local ok,list=pcall(objectList,path)
  local entry={path=path,rows={}}
  out.entries[#out.entries+1]=entry
  if not ok or type(list)~='table' or #list~=1 then out.missing[#out.missing+1]=path
  else
   local ref=list[1]
   local key=identity(ref)
   if class(ref)~='Preset' or not key then out.missing[#out.missing+1]=path
   elseif owners[key] then out.duplicates[#out.duplicates+1]=path
   else entry.key=key; entry.ref=ref; owners[key]=entry end
  end
 end
 for _,rec in ipairs(records or {}) do
  if rec.category=='FINAL_SURVIVING_UNSAFE' then
   local key=rec.ref and identity(rec.ref)
   local entry=key and owners[key]
   if entry then entry.rows[#entry.rows+1]=rec.row end
  end
 end
 for _,entry in ipairs(out.entries) do
  if entry.key and #entry.rows>0 then out.found=out.found+1
  elseif entry.key then out.missing[#out.missing+1]=entry.path end
 end
 out.pass=out.found==#paths and #out.missing==0 and #out.duplicates==0
 return out
end
