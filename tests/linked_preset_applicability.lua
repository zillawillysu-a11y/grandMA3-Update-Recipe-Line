local file=assert(io.open('tools/templates/linked_preset_applicability.lua'))
local source=file:read('*a'); file:close()
local logs,objects,requested={},{},{}
local env=setmetatable({}, {__index=_G}); env._G=env
env.Printf=function(fmt,line) assert(fmt=='%s'); logs[#logs+1]=line end
env.BuildDetails=function() return {BigVersion='2.5.0.3'} end
env.ObjectList=function(path) requested[#requested+1]=path; return objects[path] and {objects[path]} or {} end
env.HandleToInt=function(h) return h.id end
env.HandleToStr=function(h) return h.path end
env.CompareHandle=function(a,b) return a==b end
local reads=0
env.GetPresetData=function(h,phasersOnly,byFixtures)
 assert(phasersOnly==false and type(byFixtures)=='boolean')
 reads=reads+1
 if not byFixtures then return h.data end
 local members={}
 for k,p in pairs(h.data) do if type(k)=='number' then members['Fixture '..k]=p end end
 return {by_fixtures=members}
end
local function node(kind,id,path)
 local h={kind=kind,id=id,path=path,children={},parent=nil,deps={}}
 function h:GetClass() return self.kind end
 function h:PropertyCount() if self.vs or self.mode then return 1 end; return 0 end
 function h:PropertyName() if self.vs then return 'Preset' end; return 'PresetMode' end
 function h:PropertyType() if self.vs then return self.propType end; return 'Enum' end
 function h:Get(k) return self[k] end
 function h:ToAddr() return self.path end
 function h:Parent() return self.parent end
 function h:GetDependencies() return self.deps end
 function h:Children() return self.children end
 function h:Index() return self.index end
 return h
end
local function record(abs,storeMode,selective,ui)
 return {[1]={absolute=abs},preset_store_mode=storeMode,dict_flags={selective=selective,has_absolute=true},mask_active_value=2,ui_channel_index=ui}
end
local pool=node('PresetPool',100,'PresetPool Dimmer'); pool.Name='Dimmer'
local linkedA=node('Preset',11,'Preset 1.100'); linkedA.Name='Dimmer 100'
linkedA.mode='Universal'; linkedA.PresetMode='Universal'; linkedA.parent=pool
linkedA.data={[130]=record(30,3,false,130)}
local selectiveB=node('Preset',12,'Preset 1.23'); selectiveB.Name='Dimmer 23'
selectiveB.mode='Selective'; selectiveB.PresetMode='Selective'; selectiveB.parent=pool
selectiveB.data={}
for k=130,147 do selectiveB.data[k]=record(43,1,true,k) end
local proxyB=node('PresetLink',21,'Linked B'); proxyB.Name='Step 2 link'
proxyB.parent=selectiveB; proxyB.deps={selectiveB}
local outer=node('Preset',1,'Preset 25.9014')
local recipe=node('PhaserRecipe',2,'Recipe'); outer.children={recipe}
for i=1,2 do
 local step=node('PhaserRecipeStep',i+2,'Step '..i); step.index=i
 local vs=node('PhaserRecipeValueSource',i+4,'ValueSource '..i)
 vs.vs=true; vs.propType='Object'
 step.children={vs}; recipe.children[#recipe.children+1]=step
end
recipe.children[1].children[1].Preset=linkedA
recipe.children[2].children[1].Preset=proxyB
objects['Preset 25.9014']=outer
objects['Preset 1.100']=linkedA
objects['Preset 1.23']=selectiveB
for _,item in ipairs({{'Preset 1.28',13,'Universal',30},{'Preset 1.14',14,'Universal',40}}) do
 local h=node('Preset',item[2],item[1]); h.Name=item[1]; h.mode=item[3]; h.PresetMode=item[3]
 h.data={[130]=record(item[4],3,false,130)}
 objects[item[1]]=h
end
local run=assert(load(source,'applicability','t',env))()
run()
local output=table.concat(logs,'\n')
assert(reads==8 and output:find('classification=PARTIAL_APPLICABILITY_PROOF',1,true))
assert(#requested==5)
for _,p in ipairs(requested) do assert(not p:find('ShowData',1,true),p) end
assert(output:find('LINKED_HANDLE case=A linked=handle:11:Preset 1.100 class=Preset',1,true))
assert(output:find('LINKED_HANDLE case=B linked=handle:21:Linked B class=PresetLink',1,true))
assert(output:find('LINK_PARENT case=B depth=1 class=Preset',1,true))
assert(output:find('LINK_DEPENDENCY case=B slot=1 class=Preset',1,true))
assert(output:find('LINK_RESOLUTION case=A method=DIRECT',1,true))
assert(output:find('LINK_RESOLUTION case=B method=PARENT_CHAIN',1,true))
assert(output:find('LINK_VALIDATION case=A label=Preset 1.100 pool_found=true match=true',1,true))
assert(output:find('LINK_VALIDATION case=B label=Preset 1.23 pool_found=true match=true',1,true))
assert(output:find('preset_prop_type=string:Object',1,true))
assert(output:find('dict_flags=has_absolute=boolean:true,selective=boolean:true',1,true))
assert(output:find('ui_channel_index=number:147',1,true))
assert(output:find('PRESET_MEMBER_VIEW case=B member_count=18',1,true))
assert(output:find('Fixture 130',1,true) and output:find('Fixture 147',1,true))
assert(output:find('source=DIRECT',1,true) and output:find('source=PARENT_CHAIN',1,true))
print('PASS Rev10.1 linked-Preset A/B acquired from native handles without ShowData paths')
