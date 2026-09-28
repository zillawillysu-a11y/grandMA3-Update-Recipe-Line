local file=assert(io.open('tools/templates/linked_preset_applicability.lua'))
local source=file:read('*a'); file:close()
local logs,objects={},{}
local env=setmetatable({}, {__index=_G}); env._G=env
env.Printf=function(fmt,line) assert(fmt=='%s'); logs[#logs+1]=line end
env.BuildDetails=function() return {BigVersion='2.5.0.3'} end
env.ObjectList=function(path) return objects[path] and {objects[path]} or {} end
env.HandleToInt=function(h) return h.id end
env.HandleToStr=function(h) return h.path end
env.CompareHandle=function(a,b) return a==b end
local reads=0
env.GetPresetData=function(h,phasersOnly,byFixtures)
 assert(phasersOnly==false and type(byFixtures)=='boolean')
 reads=reads+1
 return byFixtures and {by_fixtures={['Fixture 130']=h.data[130]}} or h.data
end
local function node(kind,id,path)
 local h={kind=kind,id=id,path=path,children={}}
 function h:GetClass() return self.kind end
 function h:PropertyCount() return self.mode and 1 or 0 end
 function h:PropertyName() return 'PresetMode' end
 function h:PropertyType() return 'Enum' end
 function h:Get(k) return self[k] end
 function h:Children() return self.children end
 function h:Index() return self.index end
 return h
end
local outer=node('Preset',1,'Preset 25.9014')
local recipe=node('PhaserRecipe',2,'Recipe'); outer.children={recipe}
for i=1,2 do
 local step=node('PhaserRecipeStep',i+2,'Step '..i); step.index=i
 local vs=node('PhaserRecipeValueSource',i+4,'ValueSource '..i)
 step.children={vs}; recipe.children[#recipe.children+1]=step
 vs.Preset=node('Preset',i+10,'Linked '..i)
end
objects['Preset 25.9014']=outer
for _,item in ipairs({{'ShowData.DataPools.Default.PresetPools.Dimmer.100',11,'Universal'},
 {'ShowData.DataPools.Default.PresetPools.Dimmer.23',12,'Selective'},
 {'Preset 1.28',13,'Universal'},{'Preset 1.14',14,'Universal'}}) do
 local h=node('Preset',item[2],item[1]); h.mode=item[3]; h.PresetMode=item[3]
 h.data={[130]={[1]={absolute=43},preset_store_mode=item[3]=='Selective' and 1 or 3,dict_flags={selective=item[3]=='Selective',has_absolute=true},mask_active_value=2}}
 objects[item[1]]=h
end
recipe.children[1].children[1].Preset=objects['ShowData.DataPools.Default.PresetPools.Dimmer.100']
recipe.children[2].children[1].Preset=objects['ShowData.DataPools.Default.PresetPools.Dimmer.23']
local run=assert(load(source,'applicability','t',env))()
run()
local output=table.concat(logs,'\n')
assert(reads==8 and output:find('classification=PARTIAL_APPLICABILITY_PROOF',1,true))
assert(output:find('dict_flags=has_absolute=boolean:true,selective=boolean:true',1,true))
assert(output:find('linked_step_match=true',1,true))
print('PASS independent linked-Preset applicability observer read-only four-sample audit')
