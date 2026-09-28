local function module(path,name)
 local f=assert(io.open(path)); local src=f:read('*a'); f:close()
 return assert(load(src..'\nreturn '..name))()
end
local newPolicy=module('tools/templates/cue_wide_recipe_field_semantics.lua','newReferenceFieldSemantics')
local newBridge=module('tools/templates/cue_wide_recipe_metadata_bridge.lua','newReferenceMetadataBridge')
local resolve=module('tools/templates/cue_wide_recipe_reverse_engine.lua','recipeReverseResolve')
local checks=0; local function check(v,m) assert(v,m); checks=checks+1 end
local function o(c,n) local t={c=c,n=n}; function t:Children() return self.children or {} end; function t:Parent() return self.parent end; return t end
local fg=o('FeatureGroup',1); local feature=o('Feature',2); feature.parent=fg
local attr=o('Attribute',3); attr.Feature=feature
local function safe(fn,...) if type(fn)~='function' then return nil end; local ok,v=pcall(fn,...); if ok then return v end end
local function class(h) return h and h.c or 'UNAVAILABLE' end
local function metadata(h) local m={}; for _,k in ipairs(h.props or {}) do m[k:lower()]={key=k,raw=h[k]} end; return m end
local identity=function(h) return h.n and 'DBI:'..h.n end
local policy=newPolicy({identity=identity})
local api={safe=safe,class=class,isObject=function(h) return type(h)=='table' and h.c~=nil end,
 identity=identity,attributeByUIChannel=function() return attr end,metadata=metadata}
local rev5=newBridge(api)
api.fieldSemantics=policy; local rev6=newBridge(api)
local preset=o('Preset',100)
local channel={[1]={absolute=100,absolute_value=65535},mask_active_value=2,mask_active_phaser=0,
 mask_cooked=0,mask_individual=0,pm=2,ui_channel_index=7,dict_flags={has_absolute=true,has_relative=false},gridposmatr={}}
local raw={[7]=channel,count=1,by_fixtures=false}
policy.observe(preset,raw)
local baseline=rev5.ordinary(raw)
local ordinary=rev6.ordinary(raw)
check(baseline.completeness=='PARTIAL','Rev5 baseline unchanged')
check(ordinary.completeness=='COMPLETE' and ordinary.motion=='STATIC','corroborated ordinary static becomes complete')
check(ordinary.layerAbsence.REL==true and ordinary.layers.ABS,'ABS owned and REL absent by active mask, steps and flags')
check(policy.summary().fields.pm.channels==1 and policy.summary().fields.absolute_value.channels==1,'bounded field audit')
check(policy.summary().classifications.pm[1]=='SEMANTIC_PROVEN','vendor-backed pm classification')
local bad={[7]={[1]={absolute=100,absolute_value=65535},mask_active_value=2,mask_active_phaser=0,
 pm=1,selective=true,dict_flags={has_absolute=true},gridposmatr={}}}
check(rev6.ordinary(bad).completeness~='COMPLETE','selective member applicability is unsafe')
channel.pm=2; channel.ui_channel_index=8
check(rev6.ordinary(raw).completeness~='COMPLETE','UI channel identity mismatch unsafe')
channel.ui_channel_index=7; channel.dict_flags.has_relative=true
check(rev6.ordinary(raw).completeness~='COMPLETE','uncorroborated relative flag unsafe')
channel.dict_flags.has_relative=false
channel.gridposmatr={1,2}
check(rev6.ordinary(raw).completeness~='COMPLETE','nonempty grid matrix remains unsafe')
channel.gridposmatr={}
channel.mask_active_phaser=64
check(rev6.ordinary(raw).completeness~='COMPLETE','active grid position without applicability proof remains unsafe')
channel.mask_active_phaser=0
local ph=o('Preset',200); local recipe=o('PhaserRecipe',201); local s1,s2=o('PhaserRecipeStep',202),o('PhaserRecipeStep',203)
local v1,v2=o('PhaserRecipeValueSource',204),o('PhaserRecipeValueSource',205)
ph.children={recipe}; recipe.children={s1,s2}; s1.children={v1}; s2.children={v2}
for i,v in ipairs({v1,v2}) do
 v.props={'Attributes','RawValueAbs','RawValueRel','ValueAbsolute','ValueRelative','Preset','Layer'}
 v.Attributes=attr; v.RawValueAbs=i==1 and 100 or 0; v.RawValueRel=''
 v.ValueAbsolute=v.RawValueAbs; v.ValueRelative=0; v.Preset=preset; v.Layer='Absolute'
end
local audits={{node=v1,presetHandle=preset},{node=v2,presetHandle=preset}}
local reads=0; local dependencyCache={}
local function dependency(h)
 if not dependencyCache[identity(h)] then reads=reads+1; dependencyCache[identity(h)]=rev6.ordinary(raw) end
 return dependencyCache[identity(h)]
end
local motion=rev6.phaser(ph,{audits=audits},dependency)
check(reads==1,'linked dependency normalized once by stable identity')
check(motion.phaserStructure and motion.motionProof=='MOTION_PROVEN_EFFECTIVE_STEP_DIFFERENCE','structural and effective motion evidence preserved')
check(motion.completeness=='COMPLETE' and motion.motion=='MOVING','empty relative raw plus complete linked Preset proves moving')
v2.RawValueRel=0
check(rev6.phaser(ph,{audits=audits},dependency).completeness~='COMPLETE','raw relative zero remains ambiguous even with apparent explicit layer')
check(policy.summary().rawStates.REL_AMBIGUOUS>0,'numeric relative zero audited as ambiguous')
v2.Layer=nil; v2.props={'Attributes','RawValueAbs','RawValueRel','ValueAbsolute','ValueRelative','Preset'}
check(rev6.phaser(ph,{audits=audits},dependency).completeness~='COMPLETE','raw relative zero without explicit layer remains ambiguous')
local rows={{members={[1]=true},ref=preset,refId=100,features=ordinary.features,layers=ordinary.layers,lanes=ordinary.lanes,unsafe={}},
 {members={[1]=true,[2]=true},ref=ph,refId=200,features=motion.features,layers=motion.layers,lanes=motion.lanes,unsafe={}}}
local resolved=resolve(rows)
check(resolved.staticRows==1 and resolved.refs[200].members[2] and not resolved.refs[200].members[1],'static terminates partial overlap')
rows[1]=rows[2]; resolved=resolve(rows)
check(resolved.refs[200].members[1] and resolved.refs[200].members[2],'same moving reference can be re-sourced')
print('PASS Rev6 field semantics '..checks..' checks')
