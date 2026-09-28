local file=assert(io.open('tools/templates/global_grid_ab.lua','rb'))
local source=file:read('*a'); file:close()
local probe=assert(load(source))('TEST')
local function obj(kind,id)
 local h={kind=kind,id=id}
 function h:GetClass() return self.kind end
 function h:Parent() return self.parent end
 function h:Children() return self.children end
 function h:Get(k) return self[k] end
 return h
end
local preset=obj('Preset',1)
local groupA,groupB=obj('Group',2),obj('Group',3)
local partA,partB=obj('Part',4),obj('Part',5)
local cueA,cueB=obj('Cue',7),obj('Cue',8)
cueA.children={partA}; cueB.children={partB}
local attr=obj('Attribute',6); attr.Name='Dimmer'
local f1,f2=obj('Subfixture',11),obj('Subfixture',12)
f1.FID=1; f2.FID=2
local g1={sf_index=11,grid={x=0,y=0,z=0}}
local g2={sf_index=12,grid={x=1,y=0,z=0}}
local g3={sf_index=11,grid={x=0,y=0,z=0}}
local g4={sf_index=12,grid={x=5,y=0,z=0}}
groupA.Selection={g1,g2}; groupB.Selection={g3,g4}
partA.children={{kind='StandardRecipe',Selection=groupA,Values=preset}}
partB.children={{kind='StandardRecipe',Selection=groupB,Values=preset}}
partA.children[1].GetClass=function(self) return self.kind end
partB.children[1].GetClass=function(self) return self.kind end
local cfg={preset='Preset 4.4',groupA='Group 85',groupB='Group 86',cueA='Sequence 3858 Cue 1',cueB='Sequence 3858 Cue 2'}
local paths={[cfg.preset]=preset,[cfg.groupA]=groupA,[cfg.groupB]=groupB,[cfg.cueA]=cueA,[cfg.cueB]=cueB}
local cookedA,cookedB
local logs={}
local api={
 log=function(s) logs[#logs+1]=s end,
 time=function() return 1 end,
 objectList=function(path) return paths[path] and {paths[path]} or {} end,
 toInt=function(h) return h.id end,
 compare=function(a,b) return a==b end,
 getSubfixture=function(i) return i==11 and f1 or (i==12 and f2 or nil) end,
 attributeByUI=function() return attr end,
 getPresetData=function(h)
  if h==preset then return {[1]={attribute=attr,preset_store_mode=2,selective=false,mask_individual=64,mask_active_phaser=64,gridpos={x=1},gridposmatr={x=1}}} end
  if h==partA then return {by_fixtures=cookedA} end
  if h==partB then return {by_fixtures=cookedB} end
 end,
}
local function bucket(link)
 return {Dimmer={[1]={absolute=50},abs_preset=link}}
end
local function reset()
 cookedA={['1']=bucket(preset),['2']=bucket(preset)}
 cookedB={['1']=bucket(preset),['2']=bucket(preset)}
 groupB.Selection={g3,g4}; logs={}
end
reset()
local r=probe(api,cfg)
assert(r.precheck and r.sameMembers and r.gridChanged and r.classification=='GRID_NO_OBSERVED_MEMBER_EFFECT')
assert(table.concat(logs,'\n'):find('GLOBAL_AB_GROUP_MEMBER side=A',1,true))
assert(table.concat(logs,'\n'):find('GLOBAL_AB_PRECHECK pass=true',1,true))
for _,case in ipairs({
 {label='nil',raw=nil,accepted=true},
 {label='numeric_zero',raw=0,accepted=true},
 {label='native_none',raw='None',accepted=true},
 {label='numeric_one',raw=1,accepted=false},
 {label='unexpected_string',raw='unexpected',accepted=false},
}) do
 reset(); f1.CID=case.raw
 r=probe(api,cfg)
 assert(r.precheck==case.accepted,case.label..' CID acceptance')
 assert(r.classification==(case.accepted and 'GRID_NO_OBSERVED_MEMBER_EFFECT' or 'INCONCLUSIVE'),case.label..' CID classification')
 assert((r.reasons.COOKED_SUBFIXTURE_KEY_UNPROVEN==true)==not case.accepted,case.label..' CID failure reason')
 if case.label=='native_none' then assert(table.concat(logs,'\n'):find('cid_raw=None cid_normalized=NO_CID',1,true)) end
end
f1.CID=nil
reset(); cookedB['2']={}
r=probe(api,cfg)
assert(r.precheck and r.classification=='GRID_OBSERVED_MEMBER_EFFECT' and not r.presenceSame)
reset(); groupB.Selection={g3,{sf_index=12,grid={x=1,y=0,z=0}}}
r=probe(api,cfg)
assert(not r.precheck and r.classification=='INCONCLUSIVE' and r.reasons.GROUP_GRID_NOT_PROVEN_DIFFERENT)
reset(); groupB.Selection={g3,{sf_index=13,grid={x=5,y=0,z=0}}}
r=probe(api,cfg)
assert(not r.precheck and r.classification=='INCONCLUSIVE')
reset(); local missing={preset=cfg.preset,groupA=cfg.groupA,groupB=cfg.groupB,cueA='',cueB=''}
r=probe(api,missing)
assert(not r.precheck and r.classification=='INCONCLUSIVE' and table.concat(logs,'\n'):find('GLOBAL_AB_PROBE_CONFIGURATION_REQUIRED',1,true))
reset(); cueB.children={partB,obj('Part',9)}
cueB.children[2].children={{kind='StandardRecipe'}}
cueB.children[2].children[1].GetClass=function(self) return self.kind end
r=probe(api,cfg)
assert(not r.precheck and r.classification=='INCONCLUSIVE' and r.reasons.CUE_PART_B_UNIQUE_RECIPE_PART_UNPROVEN)
cueB.children={partB}
reset(); local old=api.getPresetData
api.getPresetData=function(h,...)
 local data=old(h,...)
 if h==preset then data[1].selective=true end
 return data
end
r=probe(api,cfg)
assert(not r.precheck and r.classification=='INCONCLUSIVE' and r.reasons.PRESET_NOT_GLOBAL_NONSELECTIVE)
api.getPresetData=old
print('PASS Global Grid A/B same members, changed grid, cooked same/changed, precheck failures')
