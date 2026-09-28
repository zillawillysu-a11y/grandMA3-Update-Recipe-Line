local file=assert(io.open('tools/templates/raw_rel_ground_truth.lua'))
local source=file:read('*a'); file:close()
local logs,objects={},{},{}
local env=setmetatable({}, {__index=_G}); env._G=env
env.Enums={Roles={Raw=1,Display=2,String=3}}
env.BuildDetails=function() return {BigVersion='2.5.0.3'} end
env.Printf=function(fmt,value) assert(fmt=='%s' and type(value)=='string'); logs[#logs+1]=value end
env.ObjectList=function(address) return objects[address] and {objects[address]} or {} end
env.HandleToInt=function(h) return h.id end
env.HandleToStr=function(h) return h.path end
local run=assert(load(source,'rev8','t',env))()
local function node(kind,id,index,parent)
 local h={kind=kind,id=id,index=index,parent=parent,path='Object '..id,children={},props={}}
 if parent then parent.children[#parent.children+1]=h end
 function h:GetClass() return self.kind end
 function h:Parent() return self.parent end
 function h:Index() return self.index end
 function h:ToAddr() return self.path end
 function h:Children() return self.children end
 function h:PropertyCount() return #self.props end
 function h:PropertyName(i) return self.props[i+1] end
 function h:PropertyType() return 'String' end
 function h:PropertyInfo() return 'native-info' end
 function h:Get(key,role)
  local value=self[key]
  if role==2 or role==3 then return value==nil and '' or tostring(value) end
  return value
 end
 function h:GetDependencies() return {} end
 return h
end
local function setup(stateA,stateB)
 logs={}; objects={}
 for caseName,state in pairs({A=stateA,B=stateB}) do
  local id=caseName=='A' and 100 or 200
  local preset=node('Preset',id,1)
  local recipe=node('PhaserRecipe',id+1,1,preset)
  local steps=node('PhaserRecipeSteps',id+2,1,recipe)
  for stepNumber=1,2 do
   local step=node('PhaserRecipeStep',id+stepNumber*10,stepNumber,steps)
   local sourceNode=node('PhaserRecipeValueSource',id+stepNumber*10+1,1,step)
   sourceNode.props={'RawValueAbs','RawValueRel','ValueAbsolute','ValueRelative','RelativeStorage','Name'}
   sourceNode.RawValueAbs=stepNumber==1 and 100 or 0
   sourceNode.RawValueRel=0
   sourceNode.ValueAbsolute=sourceNode.RawValueAbs
   sourceNode.ValueRelative=''
   sourceNode.RelativeStorage=state
   sourceNode.Name=caseName
  end
  objects[caseName=='A' and 'Preset 25.9009' or 'Preset 25.9013']=preset
 end
end
setup('inactive','authored-zero')
local result=run()
assert(result.classification=='DISCRIMINATOR_PROVEN' and result.matched==2)
local output=table.concat(logs,'\n')
assert(output:find('property=relativestorage',1,true) and output:find('property=name',1,true))
assert(output:find('Step_index=2',1,true))
setup('same','same')
result=run()
assert(result.classification=='INCONCLUSIVE' and result.matched==2)
objects['Preset 25.9013'].children[1].children[1].children[2]=nil
result=run()
assert(result.classification=='INCONCLUSIVE')
print('PASS Rev8 two-Preset all-Step differential, hidden-property capture, and structure gate')
