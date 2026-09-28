local function module(path,name)
 local f=assert(io.open(path)); local src=f:read('*a'); f:close()
 return assert(load(src..'\nreturn '..name))()
end
local new=module('tools/templates/cue_wide_recipe_metadata_bridge.lua','newReferenceMetadataBridge')
local resolve=module('tools/templates/cue_wide_recipe_reverse_engine.lua','recipeReverseResolve')
local checks=0; local function check(v,m) assert(v,m); checks=checks+1 end
local function o(c,n) local t={c=c,n=n}; function t:Children() return self.children or {} end; function t:Parent() return self.parent end; return t end
local fg=o('FeatureGroup',1); local f=o('Feature',2); f.parent=fg
local attr=o('Attribute',3); attr.Feature=f
local function safe(fn,...) if type(fn)~='function' then return nil end; local ok,v=pcall(fn,...); if ok then return v end end
local function class(h) return h and h.c or 'UNAVAILABLE' end
local function metadata(h)
 local m={}; for _,k in ipairs(h.props or {}) do m[k:lower()]={key=k,raw=h[k]} end; return m
end
local bridge=new({safe=safe,class=class,isObject=function(h) return type(h)=='table' and h.c~=nil end,
 identity=function(h) return h.n and 'DBI:'..h.n end,attributeByUIChannel=function() return attr end,metadata=metadata})
local ordinary=o('Preset',101)
local staticRaw={[0]={[1]={absolute=100},mask_active_value=2,mask_active_phaser=0,mask_cooked=0,
 dict_index=12,dict_flags={blocked=false,blocked_rel=false,extra=false},gridposmatr={}}}
local m=bridge.ordinary(staticRaw)
check(m.completeness=='COMPLETE' and m.motion=='STATIC' and m.source=='ORDINARY_GETPRESETDATA','native metadata fields proven static')
check(m.layers.ABS and m.features['FG:DBI:1'],'feature/layer from native Attribute chain')
local unknown={[0]={[1]={absolute=100},mask_active_value=2,mystery_effect=true}}
check(bridge.ordinary(unknown).completeness=='PARTIAL','unknown result-affecting field stays unsafe')
local blocked={[0]={[1]={absolute=100},mask_active_value=2,dict_flags={blocked=true}}}
check(bridge.ordinary(blocked).completeness=='PARTIAL','blocked dict flag changes semantics')
local cooked={[0]={[1]={absolute=100},mask_active_value=2,mask_cooked=511}}
check(bridge.ordinary(cooked).completeness=='PARTIAL','nonzero cooked mask not ignored')
local matrix={[0]={[1]={absolute=100},mask_active_value=2,gridposmatr={1,2}}}
check(bridge.ordinary(matrix).completeness=='PARTIAL','nonempty matrix not guessed')
local ph=o('Preset',201); local recipe=o('PhaserRecipe',202); local s1,s2=o('PhaserRecipeStep',203),o('PhaserRecipeStep',204)
local v1,v2=o('PhaserRecipeValueSource',205),o('PhaserRecipeValueSource',206)
ph.children={recipe}; recipe.children={s1,s2}; s1.children={v1}; s2.children={v2}
for i,v in ipairs({v1,v2}) do v.props={'Attributes','RawValueAbs','RawValueRel','ValueAbsolute','Preset'}; v.Attributes=attr; v.RawValueAbs=i==1 and 100 or 0; v.RawValueRel=''; v.ValueAbsolute=v.RawValueAbs; v.Preset=ordinary end
local audits={{node=v1,presetHandle=ordinary},{node=v2,presetHandle=ordinary}}
local deps=0
local pm=bridge.phaser(ph,{audits=audits},function(h) deps=deps+1; check(h==ordinary,'linked dependency identity'); return m end)
check(pm.phaserStructure and pm.structuralSteps==2 and pm.valueSources==2,'phaser structure separately proven')
check(pm.motion=='MOVING' and pm.completeness=='COMPLETE' and pm.motionProof:find('MOTION_PROVEN',1,true),'two distinct effective steps prove motion')
check(deps==2,'both ValueSources inspected; outer cache deduplicates actual read')
local rm=resolve({{members={[1]=true},ref=ordinary,refId=101,features=m.features,layers=m.layers,lanes=m.lanes,unsafe={}},
 {members={[1]=true,[2]=true},ref=ph,refId=201,features=pm.features,layers=pm.layers,lanes=pm.lanes,unsafe={}}})
check(rm.staticRows==1 and rm.refs[201].members[2] and not rm.refs[201].members[1],'static termination and partial overlap')
rm=resolve({{members={[2]=true},ref=ph,refId=201,features=pm.features,layers=pm.layers,lanes=pm.lanes,unsafe={}},
 {members={[1]=true,[2]=true},ref=ph,refId=201,features=pm.features,layers=pm.layers,lanes=pm.lanes,unsafe={}}})
check(rm.refs[201].members[1] and rm.refs[201].members[2] and rm.movingRows==2,'re-source before identity collapse')
v2.Preset=nil; v2.props={'Attributes','RawValueAbs','RawValueRel','ValueAbsolute'}
local ambiguous=bridge.phaser(ph,{audits={{node=v1,presetHandle=ordinary},{node=v2}}},function() return m end)
check(ambiguous.completeness~='COMPLETE' and ambiguous.evidence.ZERO_RAW_LAYER_AMBIGUOUS_ABS,'zero raw abs without linked proof unsafe')
v2.RawValueRel=0; ambiguous=bridge.phaser(ph,{audits={{node=v1,presetHandle=ordinary},{node=v2}}},function() return m end)
check(ambiguous.completeness~='COMPLETE' and ambiguous.evidence.ZERO_RAW_LAYER_AMBIGUOUS_REL,'raw rel zero alone unsafe')
local noVS=o('Preset',301); check(bridge.phaser(noVS,{audits={}},function() end).motionProof=='MOTION_UNPROVEN','class alone does not prove motion')
print('PASS Rev5 metadata bridge '..checks..' checks')
