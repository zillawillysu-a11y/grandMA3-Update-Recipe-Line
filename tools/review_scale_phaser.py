from pathlib import Path
import os
from lupa import LuaRuntime

os.chdir(Path(__file__).resolve().parents[1])
runtime = LuaRuntime()
print('OFFLINE ONLY: synthetic rows/members; no native latency measurement')
runtime.execute(r'''
local main=assert(loadfile('RecipeTracking_Inspector.lua'))(nil,nil,{}, {})
local functions,seen={},{}
local function collect(fn)
 if seen[fn] then return end
 seen[fn]=true
 for i=1,200 do
  local name,value=debug.getupvalue(fn,i)
  if not name then break end
  if type(value)=='function' then functions[name]=value; collect(value) end
 end
end
collect(main)
local state={}
functions.recipePoolReferences(state)
local advance=assert(state.provenHooks.advanceStagedResolver)
local function buildTask(total,selected)
 local task={rows={},members={},memberSliceLimit=250,selectedMembers=selected or {}}
 for i=1,total do task.members[i]={key=tostring(i),handle=i} end
 local visits=0
 task.runtime={run=function(_,batch)
  local assignments={}
  for key in pairs(batch) do
   assignments[#assignments+1]=setmetatable({lane='fg|ABS',refId='Preset '..key},
    {__index=function(_,field) if field=='member' then visits=visits+1; return key end end})
  end
  return {classification='PROVEN',refs={},activeRefs={},laneAssignments=assignments}
 end}
 return task,function() return visits end
end
for _,total in ipairs({1265,12650}) do
 local task,visits=buildTask(total)
 local taskState={referenceMetadataCache={},memberUICache={}}
 local ticks,result=0
 repeat result=advance(task,taskState); ticks=ticks+1 until result.classification~='PENDING'
 print(string.format('members=%d ticks=%d inter_slice_yield_ms=%d pending_assignment_visits=%d',
  total,ticks,(ticks-1)*10,visits()))
 assert(ticks==math.ceil(total/250))
end
local task=buildTask(1000,{['1']=true})
local taskState={referenceMetadataCache={},memberUICache={}}
local first=advance(task,taskState)
assert(first.classification=='PENDING' and #first.laneAssignments==1
 and first.laneAssignments[1].member=='1')
task.selectedMembers={['251']=true}
local second=advance(task,taskState)
assert(second.classification=='PENDING' and #second.laneAssignments==1
 and second.laneAssignments[1].member=='251')
print('selection change on SAME task: selected assignment 1 -> 251; old assignment removed')
''')

# Execute the established fixtures, then extend that scope in memory to probe
# exactly the same raw multi-step record with and without a timing field.
source = Path('tests/show_candidate.lua').read_text(encoding='utf-8')
runtime = LuaRuntime()
probe = r'''
reviewChannel=referenceData[moving][0]
reviewRuntime=functions.newTrackARuntime({safe=functions.safe,class=functions.class,
 children=functions.children,identity=functions.commandAddress,getPresetData=_G.GetPresetData,
 attributeByUI=_G.GetAttributeByUIChannel,objectList=_G.ObjectList})
reviewClean=reviewRuntime.metadata(moving,{})
assert(reviewClean and reviewClean.kind=='ORDINARY'
 and select(2,next(reviewClean.lanes)).moving)
reviewChannel.measure=1
reviewFailureCache={}
reviewBlocked=reviewRuntime.metadata(moving,reviewFailureCache)
assert(reviewBlocked==nil
 and reviewFailureCache.__failure['Preset 1.2']=='ACTIVE_CHANNEL_FIELD_measure')
reviewChannel.measure=nil
reviewRestored=reviewRuntime.metadata(moving,{})
assert(reviewRestored and reviewRestored.kind=='ORDINARY'
 and select(2,next(reviewRestored.lanes)).moving)
print('raw two-step preset WITHOUT PhaserRecipe: admitted -> measure=1 blocked -> restored admitted')
'''
marker = 'local attributeReadsBefore=attributeByUICalls'
assert source.count(marker) == 1
runtime.execute(source.replace(marker, probe + '\n' + marker))
