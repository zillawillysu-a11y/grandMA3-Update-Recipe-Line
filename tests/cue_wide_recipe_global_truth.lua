local file=assert(io.open('tools/templates/cue_wide_recipe_global_truth.lua','rb'))
local source=file:read('*a'); file:close(); assert(load(source))()
local function obj(kind,id,name)
 local h={kind=kind,id=id,Name=name}
 function h:Get(k) return self[k] end
 function h:Parent() return self.parent end
 return h
end
local fg=obj('FeatureGroup',300); local feature=obj('Feature',301); feature.parent=fg
local attr=obj('Attribute',302,'ColorRGB_R'); attr.Feature=feature
local preset=obj('Preset',400); local other=obj('Preset',401)
local part=obj('Part',500); local fixture=obj('Subfixture',600); fixture.FID=101; fixture.CID='None'
local key='11\0FG:DBI:300|ABS'
local record={category='FINAL_SURVIVING_UNSAFE',ref=preset,row={cue=obj('Cue',700),part=part,recipe=obj('Recipe',701),group=obj('Group',702),features={['FG:DBI:300']=true}},
 surviving={key},neutralized={'12\0FG:DBI:300|ABS'}}
local raw={['DBI:400']={[1]={attribute=attr,[1]={absolute=50}}}}
local cooked,cookedPart2,reads,logs,capability
local part2=obj('Part',501)
local api={
 log=function(s) logs[#logs+1]=s end,
 identity=function(h) return h and 'DBI:'..h.id end,
 describe=function(h) return h and h.kind..' '..h.id end,
 getPresetData=function(h,phasersOnly,byFixtures)
  assert((h==part or h==part2) and phasersOnly==false and byFixtures==true)
  reads=reads+1; return {by_fixtures=h==part and cooked or cookedPart2}
 end,
 getSubfixture=function(sf) return sf==11 and fixture or nil end,
 capability=function() return capability end,
 proofs={['DBI:400']={motionStaticProven=true,layers={ABS=true},channels=1,activeValue=1,steps={['1']=1}}},
}
local targets={{path='Preset 4.4',key='DBI:400'}}
local function run(rows,parts)
 reads=0; logs={}
 return __globalRecipeApplicabilityTruth(rows or {record},targets,parts or {part,part},raw,api)
end
cooked={['101']={ColorRGB_R={abs_preset=preset}}}; capability='UNKNOWN'
local r=run()
assert(r.totals.matched==1 and r.totals.surviving==1 and r.totals.linked==1 and reads==1)
assert(table.concat(logs,'\n'):find('GLOBAL_RECIPE_APPLICABILITY_ROW reference=Preset 4.4',1,true))
assert(r.totals.layerRefined==0 and r.totals.layerFailed==0)
record.surviving={'11\0FG:DBI:300|*'}
r=run()
assert(r.totals.matched==1 and r.totals.layerRefined==1 and r.totals.linked==1 and reads==1)
assert(record.surviving[1]=='11\0FG:DBI:300|*')
assert(table.concat(logs,'\n'):find('GLOBAL_RECIPE_LAYER_REFINEMENT reference=Preset 4.4',1,true))
api.proofs['DBI:400'].layers.REL=true
r=run()
assert(r.totals.inconclusive==1 and r.totals.layerFailed==1 and r.totals.unresolved==1)
assert(table.concat(logs,'\n'):find('SURVIVING_LANE_LAYER_UNPROVEN',1,true))
api.proofs['DBI:400'].layers.REL=nil
record.surviving={key}
cooked={['101']={}}; capability='UNSUPPORTED'
r=run(); assert(r.totals.matched==1 and r.totals.unsupported==1 and r.totals.different==0)
cooked={['101']={ColorRGB_R={abs_preset=other}}}; capability='UNKNOWN'
r=run(); assert(r.totals.mismatch==1 and r.totals.different==1)
cooked={['101']={}}
r=run(); assert(r.totals.inconclusive==1 and r.totals.unresolved==1)
local originalRaw=raw['DBI:400']
raw['DBI:400']={}
r=run(); assert(table.concat(logs,'\n'):find('REFERENCE_ATTRIBUTE_LANE_UNAVAILABLE',1,true))
raw['DBI:400']=originalRaw
local originalRead=api.getPresetData
api.getPresetData=function() reads=reads+1; return {} end
r=run(); assert(table.concat(logs,'\n'):find('COOKED_VIEW_UNAVAILABLE',1,true) and reads==1)
api.getPresetData=originalRead
fixture.FID=nil
r=run(); assert(table.concat(logs,'\n'):find('MEMBER_KEY_UNPROVEN',1,true))
fixture.FID=101
-- The neutralized member is absent from surviving keys and never probed.
assert(r.totals.surviving==1)
cooked={['101']={ColorRGB_R={abs_preset=preset}}}
r=run({record,record}); assert(reads==1 and r.totals.rows==2)
local row2={category='FINAL_SURVIVING_UNSAFE',ref=preset,row={cue=record.row.cue,part=part2,
 recipe=obj('Recipe',703),group=record.row.group},surviving={key}}
cookedPart2={['101']={ColorRGB_R={abs_preset=other}}}
r=run({record,row2},{part,part2,part2})
assert(reads==2 and r.totals.matched==1 and r.totals.mismatch==1)
local keySource=assert(io.open('tools/templates/cue_wide_recipe_member_key_probe.lua','rb'))
assert(load(keySource:read('*a')))(); keySource:close()
fixture.CID=1; cooked={['101']={ColorRGB_R={abs_preset=preset}}}
r=run()
local before=r.totals.unresolved
assert(before==1 and #r.problematic==1)
__cookedMemberKeyProbe(r.problematic,r.views,{log=api.log,identity=api.identity,describe=api.describe,getSubfixture=api.getSubfixture})
assert(r.totals.unresolved==before and reads==1,'key observer leaves truth result and Part cache unchanged')
fixture.CID='None'
print('PASS Global Recipe cooked truth matched, unsupported, mismatch, unknown, surviving-only, Part cache')
