local factory=assert(loadfile('tools/templates/cue_wide_recipe_reference_semantics.lua'))
-- Load local factory without exporting production globals.
local src=assert(io.open('tools/templates/cue_wide_recipe_reference_semantics.lua')):read('*a')
local new=assert(load(src..'\nreturn newReferenceSemanticsAudit'))()
local function h(c) return {c=c,Get=function() return 0 end,Parent=function(s) return s.parent end,Children=function() return {} end} end
local ref,pool,row=h('Preset'),h('PresetPool'),h('Recipe'); ref.parent=pool
local calls=0
ref.GetDependencies=function() calls=calls+1; return {pool} end
local audit=new({safe=function(f,...) local ok,v=pcall(f,...); if ok then return v end end,
 class=function(v) return v and v.c or 'UNAVAILABLE' end,isObject=function(v) return type(v)=='table' and v.c~=nil end,
 desc=function(v) return v and v.c or 'UNAVAILABLE' end,metadata=function() return {} end,joined=function() return 'OPAQUE' end})
local data={featureProven=false,layerProven=false,proven=false,reasons={}}
local a=audit(ref,data,row)
assert(a.motion=='MOTION_UNPROVEN' and not a.layer and not a.feature)
assert(a.probes:find('RawValueAbs:enumerated=false,direct=nil:nil,get=number:0',1,true))
assert(a.dependencies:find('PresetPool',1,true) and calls==1)
assert(not data.layerProven and not data.proven)
data.featureProven=true; data.layerProven=true; data.proven=true; data.moving=false
assert(audit(ref,data,row).motion=='STATIC_PROVEN')
data.moving=true; assert(audit(ref,data,row).motion=='MOTION_PROVEN')
print('PASS Rev3 observation-only audit, getter defaults, dependencies, conservative classifications')
