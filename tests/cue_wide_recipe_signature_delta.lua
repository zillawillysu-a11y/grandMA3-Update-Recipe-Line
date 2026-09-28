local file=assert(io.open('tools/templates/cue_wide_recipe_signature_delta.lua','rb'))
local source=file:read('*a'); file:close(); assert(load(source))()
local function raw(grid,mask) return {[1]={preset_store_mode=2,selective=false,
 mask_active_phaser=mask or 64,mask_individual=64,mask_active_value=2,
 gridpos=grid,[1]={absolute=50}}} end
local control=raw({[1]=10},64)
local function component(result,name)
 for _,item in ipairs(result.components) do if item.component==name then return item end end
 error('missing component '..name)
end
local delta=__rev131SignatureDelta(control,raw({[99]=10},64))
assert(component(delta,'gridpos').status=='KEY_IDENTITY_ONLY')
assert(component(delta,'gridpos').keySetsEqual==false and component(delta,'gridpos').valueTypeShapeEqual)
delta=__rev131SignatureDelta(control,raw({[1]=10},16))
assert(component(delta,'mask_active_phaser').status=='SEMANTIC_VALUE')
delta=__rev131SignatureDelta(control,raw('different type',64))
assert(component(delta,'gridpos').status=='STRUCTURAL')
delta=__rev131SignatureDelta(control,raw({[1]=10},64))
assert(component(delta,'gridpos').status=='SAME')
print('PASS Rev13.1 signature delta key, value, structure, same controls')
