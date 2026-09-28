local file=assert(io.open('tools/templates/cue_wide_recipe_global_applicability.lua','rb'))
local source=file:read('*a'); file:close(); assert(load(source))()
local function channel()
 return {preset_store_mode=2,selective=false,mask_active_phaser=64,mask_individual=64,
  mask_active_value=2,mask_cooked=0,gridpos={x=1},gridposmatr={x=1},
  dict_flags={has_absolute=true},[1]={absolute=50}}
end
local function raw(ch) return {count=1,by_fixtures=false,[1]=ch} end
local control=raw(channel())
local static={motionStaticProven=true}
local scope={[46]=true}
local function inspect(ch,compatible) return __rev13GlobalApplicability(raw(ch),control,static,scope,compatible) end
local p=inspect(channel(),true)
assert(p.matchesNativeProvenClass and p.semanticShape=='CONTROL_SIGNATURE_SUBSET')
assert(not inspect(channel(),false).matchesNativeProvenClass)
local selective=channel(); selective.selective=true; selective.dict_flags.selective=true
p=inspect(selective,true); assert(not p.matchesNativeProvenClass and p.reasons.NOT_GLOBAL_NONSELECTIVE)
local unknown=channel(); unknown.mystery=true
p=inspect(unknown,true); assert(not p.matchesNativeProvenClass and p.reasons.UNKNOWN_ACTIVE_FIELD_mystery)
local motion=channel(); motion.mask_active_phaser=16
p=inspect(motion,true); assert(not p.matchesNativeProvenClass and p.reasons.DIFFERENT_NATIVE_CONTROL_SEMANTIC_SHAPE)
local value=channel(); value.mask_active_value=4
p=inspect(value,true); assert(not p.matchesNativeProvenClass and p.reasons.DIFFERENT_NATIVE_CONTROL_SEMANTIC_SHAPE)
-- Attribute name/count and unavailable cooked attributes do not enter the
-- metadata signature; fixture compatibility is a separate required proof.
local neutral=channel(); neutral.attribute='Different Attribute'
p=inspect(neutral,true); assert(p.matchesNativeProvenClass)
assert(not __rev13GlobalApplicability(control,control,static,nil,true).matchesNativeProvenClass)
print('PASS Rev13 Global semantic shape and independent compatibility gate')
