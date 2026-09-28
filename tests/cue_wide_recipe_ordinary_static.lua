local file=assert(io.open('tools/templates/cue_wide_recipe_ordinary_static.lua','rb'))
local source=file:read('*a'); file:close()
assert(load(source))()
local static={count=1,by_fixtures=false,[1]={mask_active_value=2,mask_active_phaser=0,
 preset_store_mode=2,selective=false,gridposmatr={1},dict_flags={has_absolute=true},
 [1]={absolute=50,absolute_value=50}}}
local p=__rev12OrdinaryStaticInspect(static)
assert(p.staticProven and p.channels==1 and p.activeValue==1 and p.activePhaser==0 and p.layers.ABS)
local selective={count=1,by_fixtures=false,[1]={mask_active_value=2,mask_active_phaser=0,
 preset_store_mode=1,selective=true,gridpos={1},[1]={absolute=50}}}
assert(__rev12OrdinaryStaticInspect(selective).staticProven,'motion may be static while selective membership is unknown')
local moving={count=1,by_fixtures=false,[1]={mask_active_value=2,mask_active_phaser=64,
 preset_store_mode=2,[1]={absolute=50}}}
assert(not __rev12OrdinaryStaticInspect(moving).staticProven)
local multistep={count=1,by_fixtures=false,[1]={mask_active_value=2,mask_active_phaser=0,
 preset_store_mode=2,[1]={absolute=50},[2]={absolute=80}}}
assert(not __rev12OrdinaryStaticInspect(multistep).staticProven)
local unknown={count=1,by_fixtures=false,[1]={mask_active_value=2,mask_active_phaser=0,
 preset_store_mode=2,dict_flags={mystery=true},[1]={absolute=50}}}
assert(not __rev12OrdinaryStaticInspect(unknown).staticProven)
print('PASS Rev12 ordinary static observer positive, moving, multistep, selective, unknown flag')
