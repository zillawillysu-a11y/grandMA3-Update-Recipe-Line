-- Rev12.1 observer only. Vendor 2.5 GetPhaserMask/PhaserMaskToList:
-- 1/2 Preset dependencies, 4/8/16/32/128/256 timing/motion, 64 gridpos.
function __rev12OrdinaryStaticInspect(raw)
  local motionBits=4|8|16|32|128|256
  local knownBits=1|2|motionBits|64
  local out={channels=0,activeValue=0,nonGridMotion=0,gridPosition=0,steps={},layers={},modes={},selective={},motionReasons={},memberReasons={}}
  local function motion(s) out.motionReasons[s]=true end
  local function member(s) out.memberReasons[s]=true end
  if type(raw)~='table' then
   motion('REFERENCE_DATA_UNAVAILABLE'); member('REFERENCE_DATA_UNAVAILABLE')
   out.motionStaticProven=false; out.memberApplicabilityProven=false; return out
  end
  for ui,p in pairs(raw) do
   if ui=='count' then
    if type(p)~='number' then motion('INVALID_COUNT'); member('INVALID_COUNT') end
   elseif ui=='by_fixtures' then
    if p~=false then motion('NOT_UI_CHANNEL_INDEXED'); member('NOT_UI_CHANNEL_INDEXED') end
   elseif type(ui)~='number' or type(p)~='table' then motion('UNSUPPORTED_TOP_LEVEL'); member('UNSUPPORTED_TOP_LEVEL')
   else
    out.channels=out.channels+1
    if out.channels>262144 then motion('CHANNEL_LIMIT'); member('CHANNEL_LIMIT'); break end
    local mask=p.mask_active_value
    if type(mask)~='number' or math.type(mask)~='integer' or mask & ~(2|4)~=0 or mask & (2|4)==0 then motion('ACTIVE_VALUE_MASK_UNPROVEN')
    else out.activeValue=out.activeValue+1 end
    local phaser=p.mask_active_phaser
    if type(phaser)~='number' or math.type(phaser)~='integer' or phaser<0 or phaser & ~knownBits~=0 then
     motion('PHASER_MASK_SHAPE_OR_BITS_UNPROVEN'); member('PHASER_MASK_SHAPE_OR_BITS_UNPROVEN')
    else
     if phaser & motionBits~=0 then out.nonGridMotion=out.nonGridMotion+1; motion('NON_GRID_MOTION_MASK_ACTIVE') end
     if phaser & (1|2)~=0 then motion('PHASER_PRESET_DEPENDENCY_ACTIVE') end
     if phaser & 64~=0 then out.gridPosition=out.gridPosition+1; member('ACTIVE_GRID_POSITION_APPLICABILITY_UNPROVEN') end
    end
    if p.mask_cooked~=nil and p.mask_cooked~=0 then motion('COOKED_MASK_UNPROVEN') end
    for _,k in ipairs({'speed','phase','measure','nshot_count','fade','delay','speed_master','abs_generator','rel_generator','generator','abs_preset','rel_preset'}) do
     if p[k]~=nil and p[k]~=false and p[k]~=0 then motion('MOTION_OR_DEPENDENCY_'..k) end
    end
    for k,v in pairs(p) do
     if type(k)=='string' and not ({attribute=true,abs_preset=true,rel_preset=true,abs_generator=true,rel_generator=true,generator=true,
      mask_active_phaser=true,mask_active_value=true,mask_cooked=true,mask_individual=true,mask_integrated=true,
      dict_flags=true,dict_index=true,gridposmatr=true,gridpos=true,grid=true,phase=true,speed=true,measure=true,
      fade=true,delay=true,selective=true,preset_store_mode=true,pm=true,ui_channel_index=true,
      grid_origin=true,grid_matrix=true,nshot_count=true,nshot_flags=true,speed_master=true})[k] then
      motion('UNKNOWN_PHASER_FIELD_'..tostring(k))
     end
    end
    local mode=p.preset_store_mode or p.pm
    if mode~=2 and mode~=3 then member('MEMBER_PRESET_MODE_UNPROVEN') end
    if p.pm~=nil and p.preset_store_mode~=nil and p.pm~=p.preset_store_mode then member('CONFLICTING_PRESET_MODES') end
    if p.selective==true then member('SELECTIVE_MEMBER_APPLICABILITY_UNPROVEN') end
    if p.selective~=nil and type(p.selective)~='boolean' then member('SELECTIVE_FIELD_SHAPE_UNPROVEN') end
    if p.ui_channel_index~=nil and p.ui_channel_index~=ui then motion('UI_CHANNEL_INDEX_MISMATCH'); member('UI_CHANNEL_INDEX_MISMATCH') end
    if p.mask_individual~=nil and p.mask_individual~=0 and p.mask_individual~=false then member('INDIVIDUAL_MEMBER_APPLICABILITY_UNPROVEN') end
    if p.gridpos~=nil and p.gridpos~=0 and p.gridpos~=false and not (type(p.gridpos)=='table' and next(p.gridpos)==nil) then member('GRID_POSITION_EFFECT_UNPROVEN') end
    if p.gridposmatr~=nil and (type(p.gridposmatr)~='table' or next(p.gridposmatr)~=nil) then member('GRID_MATRIX_EFFECT_UNPROVEN') end
    if p.dict_flags~=nil then
     if type(p.dict_flags)~='table' then motion('DICTIONARY_FLAGS_UNPROVEN'); member('DICTIONARY_FLAGS_UNPROVEN')
     else for k,v in pairs(p.dict_flags) do
      if k=='selective' and v~=nil and v~=false and v~=0 then member('DICTIONARY_SELECTIVE_APPLICABILITY_UNPROVEN')
      elseif (k=='blocked' or k=='blocked_rel') and v~=nil and v~=false and v~=0 then member('BLOCKED_DICTIONARY_LAYER_'..k)
      elseif not ({has_absolute=true,has_relative=true,blocked=true,blocked_rel=true,selective=true})[k]
       and v~=nil and v~=false and v~=0 then motion('UNKNOWN_ACTIVE_DICTIONARY_FLAG_'..tostring(k)) end
     end end
    end
    out.modes[tostring(mode or 'nil')]=true
    out.selective['field='..tostring(p.selective)..'/dict='..tostring(type(p.dict_flags)=='table' and p.dict_flags.selective or nil)]=true
    local steps,n,seen={},0,{}
    for k,v in pairs(p) do if type(k)=='number' then
     n=n+1; seen[k]=true
     if k<1 or k%1~=0 or type(v)~='table' then motion('INVALID_STEP_SHAPE') else steps[#steps+1]=v end
    end end
    out.steps[tostring(n)]=(out.steps[tostring(n)] or 0)+1
    if n~=1 or not seen[1] then motion('SINGLE_EFFECTIVE_STEP_UNPROVEN') end
    local step=steps[1]
    if type(step)=='table' then
     local touched=0
     for _,spec in ipairs({{'ABS','absolute',2},{'REL','relative',4}}) do
      local layer,value,bit=table.unpack(spec)
      if step[value]~=nil then
       if type(step[value])~='number' or step[value]~=step[value] or math.abs(step[value])==math.huge then motion('EFFECTIVE_'..layer..'_UNPROVEN') end
       if type(mask)~='number' or math.type(mask)~='integer' or mask & bit==0 then motion('INACTIVE_'..layer..'_VALUE') end
       touched=touched | bit; out.layers[layer]=true
      end
     end
     if type(mask)=='number' and math.type(mask)=='integer' and mask & (2|4)~=touched then motion('ACTIVE_LAYER_WITHOUT_EFFECTIVE_STEP') end
     for _,k in ipairs({'abs_release','rel_release','abs_remove','rel_remove','abs_preset','rel_preset','integrated','accel','decel','trans','transition','width'}) do
      if step[k]~=nil and step[k]~=false and step[k]~=0 then motion('STEP_EFFECT_UNPROVEN_'..k) end
     end
     for k,v in pairs(step) do
      if type(k)=='string' and not ({absolute=true,relative=true,absolute_value=true,abs_release=true,rel_release=true,
       abs_remove=true,rel_remove=true,abs_preset=true,rel_preset=true,integrated=true,accel=true,decel=true,
       trans=true,transition=true,width=true,channel_function=true,mask_active=true,mask_individual=true,
       mask_integrated=true,dict_flags=true})[k] then motion('UNKNOWN_STEP_FIELD_'..tostring(k)) end
     end
     if step.absolute_value~=nil and (type(step.absolute_value)~='number' or step.absolute==nil or type(mask)~='number' or math.type(mask)~='integer' or mask & 2==0) then
      motion('ABSOLUTE_VALUE_WITHOUT_EFFECTIVE_ABS') end
    end
   end
  end
  if out.channels==0 then motion('EMPTY_REFERENCE_DATA'); member('EMPTY_REFERENCE_DATA') end
  if raw.count~=nil and raw.count~=out.channels then motion('COUNT_MISMATCH'); member('COUNT_MISMATCH') end
  out.motionStaticProven=next(out.motionReasons)==nil
  out.memberApplicabilityProven=next(out.memberReasons)==nil
  return out
end
