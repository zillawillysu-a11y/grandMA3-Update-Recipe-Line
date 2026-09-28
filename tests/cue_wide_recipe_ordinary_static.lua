local file=assert(io.open('tools/templates/cue_wide_recipe_ordinary_static.lua','rb'))
local source=file:read('*a'); file:close()
assert(load(source))()
local static={count=1,by_fixtures=false,[1]={mask_active_value=2,mask_active_phaser=0,
 preset_store_mode=2,selective=false,dict_flags={has_absolute=true},
 [1]={absolute=50,absolute_value=50}}}
local p=__rev12OrdinaryStaticInspect(static)
assert(p.motionStaticProven and p.memberApplicabilityProven and p.channels==1 and p.activeValue==1 and p.layers.ABS)
local selective={count=1,by_fixtures=false,[1]={mask_active_value=2,mask_active_phaser=0,
 preset_store_mode=1,selective=true,dict_flags={selective=true},[1]={absolute=50}}}
p=__rev12OrdinaryStaticInspect(selective)
assert(p.motionStaticProven and not p.memberApplicabilityProven and p.memberReasons.DICTIONARY_SELECTIVE_APPLICABILITY_UNPROVEN)
local moving={count=1,by_fixtures=false,[1]={mask_active_value=2,mask_active_phaser=64,
 preset_store_mode=2,[1]={absolute=50}}}
p=__rev12OrdinaryStaticInspect(moving)
assert(p.motionStaticProven and not p.memberApplicabilityProven and p.nonGridMotion==0 and p.gridPosition==1)
moving[1].mask_active_phaser=16 -- vendor GetPhaserMask speed bit
p=__rev12OrdinaryStaticInspect(moving)
assert(not p.motionStaticProven and p.nonGridMotion==1 and p.memberApplicabilityProven)
moving[1].mask_active_phaser=512 -- no vendor mapping
assert(not __rev12OrdinaryStaticInspect(moving).motionStaticProven)
local multistep={count=1,by_fixtures=false,[1]={mask_active_value=2,mask_active_phaser=0,
 preset_store_mode=2,[1]={absolute=50},[2]={absolute=80}}}
assert(not __rev12OrdinaryStaticInspect(multistep).motionStaticProven)
local unknown={count=1,by_fixtures=false,[1]={mask_active_value=2,mask_active_phaser=0,
 preset_store_mode=2,dict_flags={mystery=true},[1]={absolute=50}}}
assert(not __rev12OrdinaryStaticInspect(unknown).motionStaticProven)
for _,field in ipairs({'mask_individual','gridpos','gridposmatr'}) do
 local ch={mask_active_value=2,mask_active_phaser=0,preset_store_mode=2,[1]={absolute=50}}
 ch[field]=field=='mask_individual' and 64 or {1}
 p=__rev12OrdinaryStaticInspect({count=1,by_fixtures=false,[1]=ch})
 assert(p.motionStaticProven and not p.memberApplicabilityProven,field..' only blocks applicability')
end
print('PASS Rev12.1 ordinary static motion and member applicability controls')
