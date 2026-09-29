"""Count calls through current production closures; NOT a native benchmark.
Run: uv run --with lupa python tools/research_marker_call_counts.py
"""
from pathlib import Path
import os
from lupa.lua54 import LuaRuntime

ROOT = Path(__file__).resolve().parents[1]
os.chdir(ROOT)
lua = LuaRuntime()
lua.execute(r'''
assert(_VERSION == 'Lua 5.4')
local signals = {}
local main = assert(loadfile('RecipeTracking_Inspector.lua'))(nil,nil,signals,{})
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
for _,fn in pairs(signals) do collect(fn) end
local calls={}
local function hit(name) calls[name]=(calls[name] or 0)+1 end
local function report(label)
 local keys={}
 for k in pairs(calls) do keys[#keys+1]=k end
 table.sort(keys)
 local fields={label}
 for _,k in ipairs(keys) do fields[#fields+1]=k..'='..calls[k] end
 print(table.concat(fields,' '))
 calls={}
end
_G.Time=function() return 100 end
_G.IsObjectValid=function() return true end
_G.CompareHandle=function(a,b) hit('CompareHandle'); return a==b end
_G.HandleToInt=function(a) hit('HandleToInt'); return a.id end
_G.HandleToStr=function(a) hit('HandleToStr'); return tostring(a.id) end
local function object(kind,id,addr)
 return {id=id,GetClass=function() hit('GetClass'); return kind end,
 ToAddr=function() hit('ToAddr'); return addr end,
 AddrNative=function() hit('AddrNative'); return addr end,
 IsActuallyVisible=function() return true end}
end
local buttons,objects,refs={},{},{}
for i=1,200 do
 objects[i]=object('Preset',i,'Preset 25.'..i)
 buttons[i]=object('PoolButton',1000+i,'Button '..i)
 buttons[i].ObjectIndex=i
 buttons[i].W=80; buttons[i].H=60; buttons[i].Anchors={left=i,right=i,top=0,bottom=0}
 if i<=13 then refs['Preset 25.'..i]=objects[i] end
end
local pool={Ptr=function(_,i) hit('Ptr'); return objects[i] end}
local grid=object('AllPoolLayoutGrid',3000,'Grid')
grid.PoolObject=pool
grid.UIChildren=function() hit('UIChildren'); return buttons end
grid.Append=function() hit('Append'); return {} end
local state={running=true,poolBlink=true,provenEnabled=true,currentSequence={},currentCue={},
 markerReferences=refs,poolGrids={grid},poolMarkers={},poolMarkersDirty=true}
functions.refreshPoolMarkers(state)
local n=0
for button in pairs(state.poolMarkers) do n=n+1; assert(button.ObjectIndex<=13) end
assert(n==13 and (calls.CompareHandle or 0)==0)
report('PRODUCTION_INDEXED_FIRST_SCAN buttons=200 refs=13 marked=13')
functions.refreshPoolMarkers(state)
assert((calls.UIChildren or 0)==0)
report('PRODUCTION_CACHED_BEFORE_DEADLINE')
-- This forces exactly the condition render() sets on every empty-selection tick.
state.poolMarkersDirty=true
functions.refreshPoolMarkers(state)
assert((calls.CompareHandle or 0)==0)
report('PRODUCTION_INDEXED_DIRTY_BEFORE_DEADLINE')
-- An illustrative index, NOT a proposed identity implementation or replacement.
-- Native alias/collision/invalidation proof is still needed before production.
local byId={}
for _,ref in pairs(refs) do byId[HandleToInt(ref)]=ref end
local found=0
for _,button in ipairs(buttons) do
 local value=pool:Ptr(button.ObjectIndex)
 local ref=byId[HandleToInt(value)]
 if ref then assert(ref==value); found=found+1 end
end
assert(found==13)
report('INDEXED_MODEL_SAME_MARKER_SET marked=13')
local fixtures,selection,lookup={},{},{}
for i=1,1295 do
 fixtures[i]=object('SubFixture',4000+i,'Fixture 201.1.'..i)
 selection[i]={sf_index=i}
 lookup['Fixture 201.1.'..i]=fixtures[i]
end
_G.GetSubfixture=function(i) hit('GetSubfixture'); return fixtures[i] end
_G.ObjectList=function(addr) hit('ObjectList'); return lookup[addr] and {lookup[addr]} or {} end
local hookState={}
functions.recipePoolReferences(hookState)
local group=object('Group',6000,'Group 79')
group.Selection=selection
calls={}
local keys,bad=hookState.provenHooks.groupKeys(group)
assert(bad==0)
report('GROUP_KEYS_COLD members=1295')
local keys2,bad2=hookState.provenHooks.groupKeys(group)
assert(keys2==keys and bad2==0 and hookState.groupMemberCacheHits==1)
assert(calls.GetSubfixture==1295 and calls.ToAddr==1295 and not calls.ObjectList)
report('GROUP_KEYS_WARM_HIT members=1295')
print('RESULT PASS; counts only; no native latency or correctness claim')
''')
