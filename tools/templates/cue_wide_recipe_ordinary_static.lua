-- Rev12 observer only. Static motion evidence is independent of member mapping.
function __rev12OrdinaryStaticInspect(raw)
  local out={channels=0,activeValue=0,activePhaser=0,steps={},layers={},modes={},selective={},reasons={}}
  local function block(s) out.reasons[s]=true end
  if type(raw)~='table' then block('REFERENCE_DATA_UNAVAILABLE'); return out end
  for ui,p in pairs(raw) do
   if ui=='count' then
    if type(p)~='number' then block('INVALID_COUNT') end
   elseif ui=='by_fixtures' then
    if p~=false then block('NOT_UI_CHANNEL_INDEXED') end
   elseif type(ui)~='number' or type(p)~='table' then block('UNSUPPORTED_TOP_LEVEL')
   else
    out.channels=out.channels+1
    if out.channels>262144 then block('CHANNEL_LIMIT'); break end
    local mask=p.mask_active_value
    if type(mask)~='number' or math.type(mask)~='integer' or mask & ~(2|4)~=0 or mask & (2|4)==0 then block('ACTIVE_VALUE_MASK_UNPROVEN')
    else out.activeValue=out.activeValue+1 end
    if p.mask_active_phaser~=0 then out.activePhaser=out.activePhaser+1; block('ACTIVE_PHASER_MASK_NOT_ZERO') end
    if p.mask_cooked~=nil and p.mask_cooked~=0 then block('COOKED_MASK_UNPROVEN') end
    for _,k in ipairs({'speed','phase','measure','nshot_count','fade','delay','speed_master','abs_generator','rel_generator','generator','abs_preset','rel_preset'}) do
     if p[k]~=nil and p[k]~=false and p[k]~=0 then block('MOTION_OR_DEPENDENCY_'..k) end
    end
    for k,v in pairs(p) do
     if type(k)=='string' and not ({attribute=true,abs_preset=true,rel_preset=true,abs_generator=true,rel_generator=true,generator=true,
      mask_active_phaser=true,mask_active_value=true,mask_cooked=true,mask_individual=true,mask_integrated=true,
      dict_flags=true,dict_index=true,gridposmatr=true,gridpos=true,grid=true,phase=true,speed=true,measure=true,
      fade=true,delay=true,selective=true,preset_store_mode=true,pm=true,ui_channel_index=true,
      grid_origin=true,grid_matrix=true,nshot_count=true,nshot_flags=true,speed_master=true})[k] then
      block('UNKNOWN_PHASER_FIELD_'..tostring(k))
     end
    end
    if p.pm~=nil and p.pm~=1 and p.pm~=2 and p.pm~=3 then block('UNKNOWN_PRESET_MODE') end
    if p.preset_store_mode~=nil and p.preset_store_mode~=1 and p.preset_store_mode~=2 and p.preset_store_mode~=3 then block('UNKNOWN_STORE_MODE') end
    if p.ui_channel_index~=nil and p.ui_channel_index~=ui then block('UI_CHANNEL_INDEX_MISMATCH') end
    if p.dict_flags~=nil then
     if type(p.dict_flags)~='table' then block('DICTIONARY_FLAGS_UNPROVEN')
     else for k,v in pairs(p.dict_flags) do
      if not ({has_absolute=true,has_relative=true,blocked=true,blocked_rel=true})[k]
       and v~=nil and v~=false and v~=0 then block('UNKNOWN_ACTIVE_DICTIONARY_FLAG_'..tostring(k)) end
     end end
    end
    out.modes[tostring(p.preset_store_mode or p.pm or 'nil')]=true
    out.selective[tostring(p.selective)]=true
    local steps,n,seen={},0,{}
    for k,v in pairs(p) do if type(k)=='number' then
     n=n+1; seen[k]=true
     if k<1 or k%1~=0 or type(v)~='table' then block('INVALID_STEP_SHAPE') else steps[#steps+1]=v end
    end end
    out.steps[tostring(n)]=(out.steps[tostring(n)] or 0)+1
    if n~=1 or not seen[1] then block('SINGLE_EFFECTIVE_STEP_UNPROVEN') end
    local step=steps[1]
    if type(step)=='table' then
     local touched=0
     for _,spec in ipairs({{'ABS','absolute',2},{'REL','relative',4}}) do
      local layer,value,bit=table.unpack(spec)
      if step[value]~=nil then
       if type(step[value])~='number' or step[value]~=step[value] or math.abs(step[value])==math.huge then block('EFFECTIVE_'..layer..'_UNPROVEN') end
       if type(mask)~='number' or math.type(mask)~='integer' or mask & bit==0 then block('INACTIVE_'..layer..'_VALUE') end
       touched=touched | bit; out.layers[layer]=true
      end
     end
     if type(mask)=='number' and math.type(mask)=='integer' and mask & (2|4)~=touched then block('ACTIVE_LAYER_WITHOUT_EFFECTIVE_STEP') end
     for _,k in ipairs({'abs_release','rel_release','abs_remove','rel_remove','abs_preset','rel_preset','integrated','accel','decel','trans','transition','width'}) do
      if step[k]~=nil and step[k]~=false and step[k]~=0 then block('STEP_EFFECT_UNPROVEN_'..k) end
     end
     for k,v in pairs(step) do
      if type(k)=='string' and not ({absolute=true,relative=true,absolute_value=true,abs_release=true,rel_release=true,
       abs_remove=true,rel_remove=true,abs_preset=true,rel_preset=true,integrated=true,accel=true,decel=true,
       trans=true,transition=true,width=true,channel_function=true,mask_active=true,mask_individual=true,
       mask_integrated=true,dict_flags=true})[k] then block('UNKNOWN_STEP_FIELD_'..tostring(k)) end
     end
     if step.absolute_value~=nil and (type(step.absolute_value)~='number' or step.absolute==nil or type(mask)~='number' or math.type(mask)~='integer' or mask & 2==0) then
      block('ABSOLUTE_VALUE_WITHOUT_EFFECTIVE_ABS') end
    end
   end
  end
  if out.channels==0 then block('EMPTY_REFERENCE_DATA') end
  if raw.count~=nil and raw.count~=out.channels then block('COUNT_MISMATCH') end
  out.staticProven=next(out.reasons)==nil
  return out
end
