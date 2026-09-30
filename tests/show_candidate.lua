-- Show candidate checks: canonical member identity, multi-group matcher,
-- proven resolver and marker sources. Offline only; on-console testing still
-- required. Runs after tests/recipe_workflow.lua via tools/run_workflow.py.
local signals = {}
local main = assert(loadfile("RecipeTracking_Inspector.lua"))(nil, nil, signals, {})
local functions, seen = {}, {}
local function collect(fn)
    if seen[fn] then return end
    seen[fn] = true
    for index = 1, 200 do
        local name, value = debug.getupvalue(fn, index)
        if not name then break end
        if type(value) == "function" then functions[name] = value; collect(value) end
    end
end
collect(main)
for _, fn in pairs(signals) do collect(fn) end
local count = 0
local function tableCount(value)
    local n=0
    for _ in pairs(value or {}) do n=n+1 end
    return n
end
local function check(value, message)
    assert(value, message)
    count = count + 1
end
local function swapUpvalue(fn,wanted,replacement)
 for index=1,200 do
  local name,value=debug.getupvalue(fn,index)
  if not name then break end
  if name==wanted then debug.setupvalue(fn,index,replacement); return value end
 end
 error("Missing upvalue: "..wanted)
end
local function object(kind, addr, fields, contents)
    local result = fields or {}
    result.GetClass = function() return kind end
    result.ToAddr = function() return addr end
    result.Children = function() return contents or {} end
    return setmetatable(result, { __tostring = function() return addr end })
end

local subfixtureByIndex = {
    [101] = object("SubFixture", "Fixture 101"),
    [201] = object("Fixture", "Fixture 201"),
    [202] = object("SubFixture", "Fixture 201.1"),
    [203] = object("SubFixture", "Fixture 201.1.1"),
}
_G.GetSubfixture = function(index) return subfixtureByIndex[tonumber(index)] end
_G.ObjectList = function(addr)
    local found = {}
    for _, handle in pairs(subfixtureByIndex) do
        if handle:ToAddr() == addr then found[#found + 1] = handle end
    end
    return found
end
local function selectedFixture(index)
    return { index = index, handle = subfixtureByIndex[index], grid = { x = 0, y = 0, z = 0 } }
end
local cellGroup = object("Group", "Group 3", {Name = "Cells", Selection = {{sf_index = 203}}})
local parentGroup = object("Group", "Group 4", {Name = "Parent", Selection = {{sf_index = 201}}})
local mixedGroup = object("Group", "Group 5", {Name = "Mixed", Selection = {{sf_index = 101}, {sf_index = 203}}})
local groupPool = {}
groupPool.Children = function() return { mixedGroup, parentGroup, cellGroup } end
_G.DataPool = function() return { Groups = groupPool } end
local hookState = {}
functions.recipePoolReferences(hookState)
local provenApi = hookState.provenHooks
assert(type(provenApi) == "table", "proven hook table must be attached")

-- The resolver uses bounded member slices but keeps the Sequence-wide marker
-- set atomic, avoiding one fixture batch lighting before the rest.
do
local warmedHandles={}
local warmMembers,warmSelected={},{}
for i=1,40 do
 warmMembers[i]={key="m"..i,handle="m"..i}
 warmSelected[warmMembers[i].key]=warmMembers[i].handle
end
local warmRunCalls,warmMaxBatch=0,0
local warmRuntime={
 memberUI=function(handle,cache) warmedHandles[#warmedHandles+1]=handle; cache[handle]={} end}
warmRuntime.run=function(_,selected,_,uiCache)
 warmRunCalls=warmRunCalls+1
 local refs,activeRefs={},{}
 local batch=0
 for key,handle in pairs(selected) do
  batch=batch+1
  if uiCache[handle]==nil then warmRuntime.memberUI(handle,uiCache) end
  refs["Preset "..key]=key; activeRefs["Preset "..key]=key
 end
 warmMaxBatch=math.max(warmMaxBatch,batch)
 return {classification="PROVEN",refs=refs,activeRefs=activeRefs,sourceGroups={}}
end
local warmTask={rows={},members=warmMembers,memberIndex=1,metadataIndex=1,runtime=warmRuntime,
 selectedMembers=warmSelected,stageMembers=warmSelected,targetFG=nil,memberSliceLimit=32}
local warmState={referenceMetadataCache={},memberUICache={}}
local warmResult,slices
slices=0
repeat
 warmResult=provenApi.advanceStagedResolver(warmTask,warmState)
 slices=slices+1
until warmResult.classification~="PENDING" or slices>20
check(warmResult.classification=="PROVEN" and #warmedHandles==40
 and warmState.resolverMembersWarmed==40 and warmState.resolverMembersTotal==40
 and tableCount(warmResult.refs)==40 and warmRunCalls==2 and warmMaxBatch==32 and slices==2,
 "large sequence lane resolution must preserve refs across the configured bounded member slices")
end

-- Budgeted scheduling reduces waits without enlarging the member slice or
-- publishing partial purple sets. Slow/unmeasurable steps remain single-step.
do
 local savedTime,stationTime=Time,500
 Time=function() return stationTime end
 local function build(total,cost)
  local taskState={referenceMetadataCache={},memberUICache={}}
  local task={rows={},members={},memberSliceLimit=1,selectedMembers={}}
  for i=1,total do task.members[i]={key=tostring(i),handle=i} end
  task.runtime={run=function(_,batch)
   stationTime=stationTime+cost/1000
   local refs,assignments={},{}
   for member in pairs(batch) do
    local id="Preset budget "..member; refs[id]=member
    assignments[#assignments+1]={member=member,lane="fg|ABS",fg="fg",
     refId=id,ref=member,moving=true}
   end
   return {classification="PROVEN",refs=refs,activeRefs=refs,laneAssignments=assignments}
  end}
  return task,taskState
 end
 local task,taskState=build(10,1)
 local first=provenApi.advanceStagedResolverBudgeted(task,taskState)
 check(first.classification=="PENDING" and task.memberIndex==5
  and taskState.lastResolverStepsPerTick==4 and next(first.refs)==nil,
  "cheap slices must advance four steps at most while withholding partial purple refs")
 provenApi.advanceStagedResolverBudgeted(task,taskState)
 local final=provenApi.advanceStagedResolverBudgeted(task,taskState)
 check(final.classification=="PROVEN" and tableCount(final.refs)==10
  and #final.laneAssignments==10 and taskState.lastResolverStepsPerTick==2
  and math.abs(task.engineMs-10)<0.00001,
  "budgeted merging must preserve all final member assignments and cumulative engine timing")
 task,taskState=build(10,5)
 first=provenApi.advanceStagedResolverBudgeted(task,taskState)
 check(first.classification=="PENDING" and task.memberIndex==3
  and taskState.lastResolverStepsPerTick==2,
  "the time budget must stop another step after a synchronous slice overruns it")
 task,taskState=build(10,1); taskState.resolverTickStarted=stationTime-0.020
 provenApi.advanceStagedResolverBudgeted(task,taskState)
 check(task.memberIndex==2 and taskState.lastResolverStepsPerTick==1,
  "scope/render time already spent must consume the next-step scheduling budget")
 task,taskState=build(10,1); Time=function() return nil end
 provenApi.advanceStagedResolverBudgeted(task,taskState)
 check(task.memberIndex==2 and taskState.lastResolverStepsPerTick==1,
  "an unavailable station clock must fall back to one bounded step")
 task,taskState=build(10,1); Time=nil
 provenApi.advanceStagedResolverBudgeted(task,taskState)
 check(task.memberIndex==2 and taskState.lastResolverStepsPerTick==1,
  "CPU-clock fallback alone must not authorize extra native slices")
 Time=function() return stationTime end
 task,taskState=build(10,-1)
 provenApi.advanceStagedResolverBudgeted(task,taskState)
 check(task.memberIndex==2 and taskState.lastResolverStepsPerTick==1,
  "a backwards clock must not trigger extra slices")
 task,taskState=build(10,6)
 task.runtime.run=function(_,batch)
  stationTime=stationTime+0.006
  taskState.lastResolverMetadataMs=1; taskState.lastResolverMemberUIMs=2
  return {classification="PROVEN",refs={}}
 end
 provenApi.advanceStagedResolverBudgeted(task,taskState)
 check(taskState.lastResolverStepsPerTick==2
  and taskState.lastResolverMetadataMs==2 and taskState.lastResolverMemberUIMs==4
  and math.abs(taskState.lastResolverEngineMs-6)<0.00001
  and task.metadataMs==2 and task.memberUIMs==4 and math.abs(task.engineMs-6)<0.00001,
  "multi-step metadata/UI/engine timing must accumulate deltas without double counting")
 Time=savedTime
end

-- Only real cache misses consume the metadata slice budget. A warm cache must
-- not force a Cue change through one no-op polling slice per historical row.
do
 local rows={}
 for i=1,9 do
  local ref=object("Preset","Preset metadata slice "..i)
  rows[i]={ref=ref}
 end
 local metadataReads,engineRuns=0,0
 local task={rows=rows,members={{key="m",handle="m"}},memberIndex=1,metadataIndex=1,
  stageMembers={m="m"},selectedMembers={m="m"},runtime={
   metadata=function(ref,cache) metadataReads=metadataReads+1; cache[ref:ToAddr()]={kind="TEST"} end,
   run=function() engineRuns=engineRuns+1; return {classification="PROVEN",refs={}} end,
   memberUI=function(handle,cache) cache[handle]={} end}}
 local state={referenceMetadataCache={},memberUICache={}}
 local savedTime,stationTime=Time,200
 Time=function() return stationTime end
 local pulse={running=true,poolBlink=true,poolBlinkOn=true,poolBlinkDeadline=200.2,poolMarkers={}}
 stationTime=200.1
 functions.advancePoolPulse(pulse)
 local first=provenApi.advanceStagedResolver(task,state)
 check(first.classification=="PENDING" and metadataReads==8 and engineRuns==0,
  "resolver reference metadata must be limited to eight rows per UI refresh")
 stationTime=200.2
 functions.advancePoolPulse(pulse)
 local second=provenApi.advanceStagedResolver(task,state)
 check(second.classification=="PROVEN" and metadataReads==9 and engineRuns==1
  and pulse.poolBlinkOn==true,
  "the final metadata slice must run the lane engine without another polling cycle")
 local warmRows,warmCache={},{}
 for i=1,9 do
  local ref=object("Preset","Preset warm metadata "..i)
  warmRows[i]={ref=ref}; warmCache[ref:ToAddr()]={kind="WARM"}
 end
 local warmEngineRuns=0
 local warmTask={rows=warmRows,members={{key="m",handle="m"}},memberIndex=1,metadataIndex=1,
  runtime={metadata=function() error("warm metadata must not be reread") end,
   run=function() warmEngineRuns=warmEngineRuns+1; return {classification="PROVEN",refs={}} end,
   memberUI=function(handle,cache) cache[handle]={} end}}
 local warmResult=provenApi.advanceStagedResolver(warmTask,
  {referenceMetadataCache=warmCache,memberUICache={}})
 check(warmResult.classification=="PROVEN" and warmEngineRuns==1,
  "warm reference metadata rows must be skipped in one pass without artificial pending slices")
 Time=savedTime
end

-- Empty selection must not inspect growing assignment lists; selecting an
-- already completed member on the same task still rebuilds its red projection.
do
 local inspections=0
 local members={}
 for i=1,4 do members[i]={key=tostring(i),handle=i} end
 local task={rows={},members=members,memberSliceLimit=1,selectedMembers={},
  runtime={run=function(_,batch)
   local assignments={}
   for member in pairs(batch) do
    assignments[#assignments+1]=setmetatable({lane="fg|ABS",refId="Preset "..member},
     {__index=function(_,field)
      if field=="member" then inspections=inspections+1; return member end
     end})
   end
   return {classification="PROVEN",refs={},laneAssignments=assignments}
  end}}
 local taskState={referenceMetadataCache={},memberUICache={}}
 local first=provenApi.advanceStagedResolver(task,taskState)
 local second=provenApi.advanceStagedResolver(task,taskState)
 check(first.classification=="PENDING" and second.classification=="PENDING"
  and #second.laneAssignments==0 and inspections==0,
  "empty selection must avoid every accumulated PENDING assignment inspection")
 task.selectedMembers={["1"]=true}
 local changed=provenApi.advanceStagedResolver(task,taskState)
 check(changed.classification=="PENDING" and #changed.laneAssignments==1
  and changed.laneAssignments[1].member=="1" and inspections>0,
  "selecting an already completed member must restore its projection without restarting the task")
end

-- A blocker found in a later member slice withholds the combined final source
-- set; pending results expose no partial Sequence markers.
do
 local manyMembers,manySelected={},{}
 for i=1,64 do manyMembers[i]={key="x"..i,handle="x"..i}; manySelected["x"..i]="x"..i end
 local calls=0
 local memberTask={rows={},members=manyMembers,memberIndex=1,metadataIndex=1,memberSliceLimit=32,
  selectedMembers=manySelected,stageMembers=manySelected,runtime={
   memberUI=function(handle,cache) cache[handle]={} end,
   run=function(_,members)
    calls=calls+1
    local a=object("Preset",calls==1 and "Preset clean chunk" or "Preset blocked chunk")
    local assignment={member=(calls==1 and "x1" or "x33"),lane="fg|ABS",fg="fg",
     refId=tostring(a:ToAddr()),ref=a,moving=true}
    if calls==1 then
     return {classification="PROVEN",refs={[assignment.refId]=a},activeRefs={[assignment.refId]=a},
      laneAssignments={assignment},sourceGroups={}}
    end
    return {classification="INCONCLUSIVE",reason="UNSAFE_LANE_ATTRIBUTION_BLOCKER",
     refs={},provenActiveRefs={[assignment.refId]=a},provenMovingRefs={[assignment.refId]=a},
     provenLaneAssignments={assignment},unsafeRefs={assignment.refId},sourceGroups={}}
   end}}
 local memberState={referenceMetadataCache={},memberUICache={}}
 local first=provenApi.advanceStagedResolver(memberTask,memberState)
 check(first.classification=="PENDING" and calls==1
  and next(first.provenActiveRefs)==nil and #first.laneAssignments==0,
  "a pending Sequence pass must not publish the completed member chunk's purple refs")
 local final=provenApi.advanceStagedResolver(memberTask,memberState)
 check(final.classification=="INCONCLUSIVE" and next(final.refs)==nil
  and tableCount(final.provenActiveRefs)==2 and #final.provenLaneAssignments==2,
  "a later unsafe chunk must fail closed globally while retaining only already-proven partial evidence")
end

-- A selection change during a staged Sequence pass must update the selected
-- projection and move newly selected members to the next bounded slice.
do
 local savedTime,stationTime=Time,300
 Time=function() return stationTime end
 local keys={"101"}
 for i=1001,1031 do keys[#keys+1]=tostring(i) end
 for i=1032,1038 do keys[#keys+1]=tostring(i) end
 keys[#keys+1]="201.1.1"
 local members={}
 for _,key in ipairs(keys) do members[#members+1]={key=key,handle=key} end
 local calls=0
 local task={key="same-stage-context",stageKey="stage",rows={},members=members,
  memberIndex=1,metadataIndex=1,memberSliceLimit=32,runtime={run=function(_,batch)
   stationTime=stationTime+0.009 -- One slice consumes this tick's budget.
   calls=calls+1
   local assignments,active={},{}
   for key in pairs(batch) do
    local ref=object("Preset","Preset projected "..key)
    active[ref:ToAddr()]=ref
    assignments[#assignments+1]={member=key,lane="fg|ABS",fg="fg",
     refId=ref:ToAddr(),ref=ref,moving=true}
   end
   return {classification="PROVEN",refs=active,activeRefs=active,
    laneAssignments=assignments,sourceGroups={}}
  end}}
 local state={incrementalResolver=true,resolverWorkKey=task.key,resolverTask=task,
  referenceMetadataCache={},memberUICache={}}
 local first=provenApi.sources(nil,nil,{selectedFixture(101)},{feature="Dimmer"},nil,state)
 check(first.classification=="PENDING" and first.selectedActiveRefs["Preset projected 101"]
  and next(first.provenActiveRefs)==nil and next(first.refs)==nil and task.memberIndex==33,
  "PENDING may publish the completed selection projection but must withhold Sequence-wide purple refs")
 local sameTask=state.resolverTask
 local second=provenApi.sources(nil,nil,{selectedFixture(203)},{feature="Dimmer"},nil,state)
 check(state.resolverTask==sameTask and task.members[33].key=="201.1.1"
  and second.classification=="PROVEN"
  and second.selectedActiveRefs["Preset projected 201.1.1"]~=nil and calls==2,
  "changing selection must reuse the in-flight task, prioritize the new member, then publish a complete projection")
 Time=savedTime
end

-- The staged production path must resolve purple stage refs over every
-- Recipe Group member, then projects selected frames over selected members.
do
 local allStageMembers={ ["101"]=subfixtureByIndex[101], ["201.1.1"]=subfixtureByIndex[203] }
 local selectedOnly={ ["101"]=subfixtureByIndex[101] }
 local observedMembers
 local stagedTaskState={incrementalResolver=true,resolverWorkKey="scope-test",
  referenceMetadataCache={},memberUICache={},resolverTask={key="scope-test",stageKey="scope",
   rows={},selectedMembers=selectedOnly,stageMembers=allStageMembers,
   members={{key="101",handle=subfixtureByIndex[101]},
    {key="201.1.1",handle=subfixtureByIndex[203]}},memberIndex=1,metadataIndex=1,
   runtime={memberUI=function(handle,cache) cache[handle]={} end,
    run=function(_,members)
     observedMembers=members
     local a,b=object("Preset","Preset stage A"),object("Preset","Preset stage B")
     return {classification="PROVEN",refs={"moving"},
      activeRefs={["Preset stage A"]=a,["Preset stage B"]=b},
      laneAssignments={
       {member="101",lane="fg|ABS",fg="fg",refId="Preset stage A",ref=a,moving=false},
       {member="201.1.1",lane="fg|ABS",fg="fg",refId="Preset stage B",ref=b,moving=true}
      },sourceGroups={}}
    end}}}
 local scoped=provenApi.sources(nil,nil,{selectedFixture(101)},{feature="Dimmer"},nil,stagedTaskState)
 check(tableCount(observedMembers)==2 and observedMembers["101"]==allStageMembers["101"]
  and observedMembers["201.1.1"]==allStageMembers["201.1.1"] and tableCount(scoped.activeRefs)==2,
  "staged resolver must use all Sequence Recipe members for steady stage refs")
 check(tableCount(scoped.selectedActiveRefs)==1 and scoped.selectedActiveRefs["Preset stage A"]
  and next(scoped.refs)==nil,
 "selected Recipe refs must be independently projected, including a selected static Recipe ref")
 local noSelection=provenApi.sources(nil,nil,{}, {feature="Dimmer"},nil,
  {incrementalResolver=true,resolverWorkKey="scope-test-empty",referenceMetadataCache={},memberUICache={},
   resolverTask={key="scope-test-empty",stageKey="scope-empty",rows={},selectedMembers={},
    stageMembers=allStageMembers,members={{key="101",handle=subfixtureByIndex[101]},
     {key="201.1.1",handle=subfixtureByIndex[203]}},memberIndex=1,metadataIndex=1,
    runtime=stagedTaskState.resolverTask.runtime}})
 check(tableCount(noSelection.activeRefs)==2 and tableCount(noSelection.selectedActiveRefs)==0,
  "Sequence purple refs must remain available with no fixture selection and no pulse refs")
end
do
 local ordered=provenApi.orderedStageMembers({
  ["101"]=subfixtureByIndex[101],["201.1.1"]=subfixtureByIndex[203],
  ["201.1"]=subfixtureByIndex[202]}, { ["201.1.1"]=subfixtureByIndex[203] })
 check(ordered[1].key=="201.1.1" and ordered[2].key=="101" and ordered[3].key=="201.1",
  "selected exact members must be resolved first so their Recipe frames do not wait behind the full Sequence scope")
 local partial=provenApi.selectStageResult({classification="PENDING",
  provenActiveRefs={},laneAssignments={}},
  { ["201.1.1"]=true })
 check(partial.classification=="PENDING" and next(partial.selectedActiveRefs)==nil
  and (not partial.refs or next(partial.refs)==nil),
  "PENDING Sequence scope must not expose a partial member-lane projection")
end

-- 1. canonical member keys for Fixture / SubFixture / nested Cell.
check(provenApi.canonicalMemberKey(selectedFixture(101)) == "101", "fixture key must be 101")
check(provenApi.canonicalMemberKey(selectedFixture(202)) == "201.1", "subfixture key must be 201.1")
check(provenApi.canonicalMemberKey(selectedFixture(203)) == "201.1.1", "cell key must be 201.1.1")
check(provenApi.canonicalMemberKey({ index = 1 }) == nil, "missing handle must fail closed")
check(provenApi.canonicalMemberKey(object("Group", "Group 1")) == nil, "non-Fixture address must fail closed")
check(provenApi.canonicalMemberKey(object("SubFixture", "Fixture 201.")) == nil, "trailing dot must fail closed")
local forged = object("SubFixture", "Fixture 201.1")
check(provenApi.canonicalMemberKey(forged) == nil, "address text without the native handle round-trip must fail closed")

-- 2-3. child-only and nested-cell exact matches.
check(provenApi.relation(cellGroup, { selectedFixture(203) }) == "EXACT_COMPLETE",
    "child-only Group must match exactly")
local relSel, selKeys, grpKeys = provenApi.relation(mixedGroup, { selectedFixture(101), selectedFixture(203) })
check(relSel == "EXACT_COMPLETE" and selKeys["101"] and grpKeys["201.1.1"], "mixed Group must match exactly")

-- 4-5. parent/child identities never collapse.
check(provenApi.relation(cellGroup, { selectedFixture(201) }) == "DISJOINT",
    "parent selection must not satisfy child-only Group")
check(provenApi.relation(parentGroup, { selectedFixture(203) }) == "DISJOINT",
    "child selection must not collapse to parent Group")

-- 6-9. multiple complete Groups, partial exclusion, deterministic order.
local both = provenApi.completeGroups({ selectedFixture(201), selectedFixture(203) })
check(#both == 2 and both[1] == cellGroup and both[2] == parentGroup,
    "selection containing two complete Groups must return both sorted")
local partial = provenApi.completeGroups({ selectedFixture(101) })
for _, found in ipairs(partial) do check(found ~= mixedGroup, "partial Group must not be admitted") end
check(provenApi.relation(mixedGroup, { selectedFixture(101) }) == "PARTIAL",
    "fragment of a Group is PARTIAL, not complete")

-- 10. currentGroup compatibility: matcher is pure, existing assignment untouched.
local compatState = { currentGroup = parentGroup, provenEnabled = true }
functions.recipePoolReferences(compatState)
check(compatState.currentGroup == parentGroup, "currentGroup compatibility must not be overwritten")

-- Structural Track A release fixtures. Names are display only; metadata and
-- native Attribute -> Feature -> FeatureGroup handles carry semantics.
local fgD=object("FeatureGroup","FeatureGroup 1")
local fgP=object("FeatureGroup","FeatureGroup 2")
local fgC=object("FeatureGroup","FeatureGroup 3")
local fgB=object("FeatureGroup","FeatureGroup 4")
local function feature(id,fg)
 local f=object("Feature","Feature "..id)
 f.Parent=function() return fg end
 return f
end
local function attribute(id,fg)
 local a=object("Attribute","Attribute "..id)
 a.Feature=feature(id,fg)
 return a
end
local attrs={
 [0]=attribute(1,fgD),[1]=attribute(2,fgD),
 [2]=attribute(3,fgP),[3]=attribute(4,fgC),[4]=attribute(5,fgB)
}
local selectedAttribute=attrs[0]
_G.GetSelectedAttribute=function() return selectedAttribute end
local uiByHandle={
 [subfixtureByIndex[101]]={0,2,3},
 [subfixtureByIndex[201]]={0,2,3},
 [subfixtureByIndex[202]]={1,2,3},
 [subfixtureByIndex[203]]={1,2,3,4}
}
local uiCalls,attributeByUICalls=0,0
_G.GetUIChannels=function(h)
 uiCalls=uiCalls+1
 local list={}
 for _,ui in ipairs(uiByHandle[h] or {}) do list[#list+1]={INDEX=ui+1} end
 return list
end
_G.GetAttributeByUIChannel=function(ui) attributeByUICalls=attributeByUICalls+1; return attrs[ui] end
local cacheContext={}
local uiCallsBeforeCache=uiCalls
local cacheFixtures={{handle=subfixtureByIndex[101]},{handle=subfixtureByIndex[203]}}
functions.readProgrammer(cacheFixtures,cacheContext)
local uiCallsAfterFirst=uiCalls
functions.readProgrammer(cacheFixtures,cacheContext)
check(uiCallsAfterFirst-uiCallsBeforeCache==2 and uiCalls==uiCallsAfterFirst,
 "steady selection refresh must reuse native member UI channel lists")
local referenceData,referenceReads={},{count=0,part=0,requests={}}
_G.GetPresetData=function(ref,selected,byFixtures)
 if ref:GetClass()=="Part" or ref:GetClass()=="Cue" then
  referenceReads.part=referenceReads.part+1
  error("production resolver must not read cooked Cue history")
 end
 check(selected==false and byFixtures==false,"reference metadata must request UI-channel shape without by-fixtures view")
 referenceReads.count=referenceReads.count+1
 referenceReads.requests[#referenceReads.requests+1]=tostring(ref)
 return referenceData[ref]
end
local function preset(id,ui,mode,moving)
 local p=object("Preset",id,{PresetMode=mode==1 and "Selective" or "Global"})
 local channel={attribute=attrs[ui],pm=mode,preset_store_mode=mode,selective=mode==1,
  mask_active_phaser=moving and 4 or 64,mask_active_value=2,mask_cooked=0,
  ui_channel_index=ui,[1]={absolute=10}}
 if moving then channel[2]={absolute=20} end
 referenceData[p]={[ui]=channel,count=1,by_fixtures=false}
 return p
end
local static=preset("Preset 1.1",0,2,false)
local moving=preset("Preset 1.2",0,2,true)
local selective=preset("Preset 1.3",0,1,false)
local selectiveMoving=preset("Preset 1.5",0,1,true)
local secondDimmer=preset("Preset 1.6",1,2,true)
local cellStatic=preset("Preset 1.8",1,2,false)
local linked=preset("Preset 1.4",0,2,false)
local position=preset("Preset 2.1",2,2,true)
local beam=preset("Preset 5.1",4,2,true)
local function valueSource(id,attr,abs,rel,link)
 local props={Attributes=attr,RawValueAbs=abs,ValueAbsolute=abs,
  RawValueRel=rel,ValueRelative=rel,Preset=link}
 local names={"Attributes","RawValueAbs","ValueAbsolute","RawValueRel","ValueRelative","Preset"}
 local v=object("PhaserRecipeValueSource","ValueSource "..id,props)
 v.PropertyCount=function() return #names end
 v.PropertyName=function(_,i) return names[i+1] end
 v.Get=function(_,name)
  if name=="ValueRelative" and rel==0 then return "" end
  return props[name]
 end
 return v
end
_G.Enums={Roles={Display=1}}
local function phaser(id,attr,absA,absB,relA,relB,link)
 local a=object("PhaserRecipeStep",id.." Step 1",{},
  {valueSource(id.." A",attr,absA,relA,link)})
 local b=object("PhaserRecipeStep",id.." Step 2",{},
  {valueSource(id.." B",attr,absB,relB,link)})
 return object("Preset",id,{}, {object("PhaserRecipe",id.." Recipe",{}, {a,b})})
end
local movingPhaser=phaser("Preset 25.A",attrs[2],10,20,nil,nil,nil)
local splitPhaser=phaser("Preset 25.B",attrs[0],10,20,0,0,linked)
local relPhaser=phaser("Preset 25.C",attrs[0],nil,nil,5,10,nil)
local genChannel=object("RandomChannel","Generator Channel",{Attribute=attrs[3]})
local generator=object("Generator","Generator 1",
 {RandomChannels=object("RandomChannels","Generator Channels",{}, {genChannel})})
local gOne=object("Group","Group 6",{Name="Key",Selection={{sf_index=101}}})
local gCell=object("Group","Group 7",{Name="Cell",Selection={{sf_index=203}}})
local gBoth=object("Group","Group 8",{Name="Overlapping",Selection={{sf_index=101},{sf_index=203}}})
groupPool.Children=function() return {mixedGroup,parentGroup,cellGroup,gOne,gCell,gBoth} end
local function recipe(group,ref,index)
 return object("StandardRecipe","Recipe "..index,{Index=index,Selection=group,Values=ref,Enabled="Yes"})
end
local function tree(rows)
 local part=object("Part","Part 0",{Part=0},rows)
 local cue=object("Cue","Cue 1",{No=1000},{part})
 return object("Sequence","Sequence 9",{}, {cue}),cue,part
end
local function state(seq,cue,fixtures)
 return {currentSequence=seq,currentCue=cue,lastFixtures=fixtures,
  currentGroups=provenApi.completeGroups(fixtures),lastFeature="Dimmer",provenEnabled=true}
end
local fOne={selectedFixture(101)}
local fBoth={selectedFixture(101),selectedFixture(203)}
local function result(rows,fixtures)
 local seq,cue=tree(rows)
 return provenApi.sources(seq,cue,fixtures,{feature="Dimmer"}),seq,cue
end
-- Repeated Group rows share scope preparation within one call. Overlap handle
-- precedence and exact fallback signatures remain equal to the old row loop.
do
 local rows={recipe(gBoth,moving,1),recipe(gOne,moving,2),recipe(gBoth,moving,3)}
 local seq,cue=tree(rows)
 local keyPasses,handlePasses,reads={},{},{}
 local a,b,cell={},{},{}
 local rawKeys={[gBoth]={["101"]=true,["201.1.1"]=true},[gOne]={["101"]=true}}
 local rawHandles={[gBoth]={["101"]=a,["201.1.1"]=cell},[gOne]={["101"]=b}}
 local original=swapUpvalue(provenApi.sources,"groupKeys",function(group)
  reads[group]=(reads[group] or 0)+1
  local keys=setmetatable({}, {__pairs=function()
   keyPasses[group]=(keyPasses[group] or 0)+1
   return next,rawKeys[group],nil
  end})
  local handles=setmetatable({}, {__pairs=function()
   handlePasses[group]=(handlePasses[group] or 0)+1
   return next,rawHandles[group],nil
  end})
  return keys,0,handles,group==gOne and "exact-group-signature" or nil
 end)
 local originalRuntime=swapUpvalue(provenApi.sources,"newTrackARuntime",function()
  return {metadata=function() return {} end,run=function()
   return {classification="PROVEN",refs={},activeRefs={},laneAssignments={}}
  end}
 end)
 local taskState={incrementalResolver=true,resolverWorkKey="scope-repeated",
  referenceMetadataCache={},memberUICache={}}
 local resolved=provenApi.sources(seq,cue,{},nil,nil,taskState)
 local task=taskState.resolverTask
 local readsBefore=0
 local identityAddress="FeatureGroup stage identity"
 local identityObject=object("FeatureGroup",identityAddress)
 identityObject.ToAddr=function() readsBefore=readsBefore+1; return identityAddress end
 local sameIdentity=true
 for i=1,1000 do sameIdentity=sameIdentity and task.identity(identityObject)==identityAddress end
 check(sameIdentity and readsBefore==1,
  "1000 repeated stage identity lookups must return the proved address with one native read")
 check(resolved.classification=="PROVEN" and #task.rows==3
  and task.rows[1].groupMemberCount==2 and task.rows[2].groupMemberCount==1
  and task.rows[3].groupMemberCount==2,
  "scope reuse must keep every Recipe row and its exact member count")
 check(reads[gBoth]==1 and reads[gOne]==1 and keyPasses[gBoth]==1 and keyPasses[gOne]==1
  and handlePasses[gBoth]==1 and handlePasses[gOne]==1,
  "each distinct Group scope must be counted and unioned once per call")
 check(task.stageMembers["101"]==a and task.stageMembers["201.1.1"]==cell
  and task.stageKey:find("101,201.1.1",1,true)~=nil
  and task.stageKey:find("exact-group-signature",1,true)~=nil,
  "overlapping Groups must preserve last-row handle precedence and exact signature formats")
 rawKeys[gBoth]["201.1.1"]=nil; rawHandles[gBoth]["201.1.1"]=nil
 rows[1].Selection=gOne
 local fresh={incrementalResolver=true,resolverWorkKey="scope-changed",
  referenceMetadataCache={},memberUICache={}}
 provenApi.sources(seq,cue,{},nil,nil,fresh)
 identityAddress="FeatureGroup next identity"
 check(fresh.resolverTask.identity(identityObject)==identityAddress and readsBefore==2,
  "a new stage runtime must discard old identity addresses")
 for i=1,4100 do task.identity(object("FeatureGroup","FeatureGroup bounded "..i)) end
 local overflowReads=0
 local overflowObject=object("FeatureGroup","FeatureGroup overflow")
 overflowObject.ToAddr=function() overflowReads=overflowReads+1; return "FeatureGroup overflow" end
 task.identity(overflowObject); task.identity(overflowObject)
 check(overflowReads==2,"the stage identity cache must remain bounded at 4096 entries")
 check(fresh.resolverTask.stageMembers["101"]==b
  and fresh.resolverTask.stageMembers["201.1.1"]==nil
  and fresh.resolverTask.rows[1].groupMemberCount==1
  and fresh.resolverTask.stageKey~=task.stageKey and reads[gBoth]==2 and reads[gOne]==2,
  "a new scope call must rebuild edited Group membership and last-row precedence")
 swapUpvalue(provenApi.sources,"groupKeys",original)
 swapUpvalue(provenApi.sources,"newTrackARuntime",originalRuntime)
end

-- Static ordinary reference terminates without publishing itself.
local staticResult=result({recipe(gOne,static,1)},fOne)
check(staticResult.classification=="PROVEN" and next(staticResult.refs)==nil,
 "ordinary static terminator must not become moving source")
check(staticResult.activeRefs["Preset 1.1"]==static,
 "a final tracked static Preset must remain in the steady purple stage reference set")
local movingResult=result({recipe(gOne,moving,1)},fOne)
check(movingResult.classification=="PROVEN" and movingResult.refs["Preset 1.2"]==moving,
 "ordinary structural moving reference must survive")
local attributeReadsBefore=attributeByUICalls
local sharedUiResult=result({recipe(gBoth,moving,1)},fBoth)
check(sharedUiResult.classification=="PROVEN"
 and attributeByUICalls-attributeReadsBefore==2,
 "member UI capability mapping must reuse the resolver cache and resolve only new UI indexes")
local otherMemberStatic=result({recipe(gBoth,static,1)},fOne)
check(otherMemberStatic.classification=="PROVEN"
 and otherMemberStatic.refs["Preset 1.1"]==nil
 and otherMemberStatic.activeRefs["Preset 1.1"]==static,
 "a static Preset used by another member of the current stage must remain a purple reference")
local metadataModeOnly=preset("Preset metadata mode only",0,2,true)
metadataModeOnly.PresetMode="Selective"
local metadataModeResult=result({recipe(gOne,metadataModeOnly,1)},fOne)
check(metadataModeResult.classification=="PROVEN"
 and metadataModeResult.refs["Preset metadata mode only"]==metadataModeOnly,
 "vendor-proven GetPresetData pm must determine ordinary mode without an unproven handle-property cross-check")
local malformedLane=preset("Preset malformed lane",0,2,true)
referenceData[malformedLane][0][1].absolute="10"
local malformedResult=result({recipe(gOne,malformedLane,1)},fOne)
check(malformedResult.classification=="INCONCLUSIVE"
 and string.find(malformedResult.unsafeRefDetails["Preset malformed lane"] or "",
  "ORDINARY_LANE_VALUE_UNPROVEN(ui=0,layer=ABS,type=string",1,true)~=nil,
 "unknown ABS value encoding must remain fail-closed with a bounded field-level reason")
local emptyMetadata=object("Preset","Preset empty UI metadata",{},
 {object("PresetChild","Native metadata child")})
referenceData[emptyMetadata]={count=0,by_fixtures=false}
local emptyMetadataResult=result({recipe(gOne,emptyMetadata,1)},fOne)
local emptyDetail=emptyMetadataResult.unsafeRefDetails["Preset empty UI metadata"] or ""
check(emptyMetadataResult.classification=="INCONCLUSIVE"
 and emptyDetail:find("raw_keys=2",1,true)~=nil
 and emptyDetail:find("children=1[PresetChild]",1,true)~=nil,
 "an empty native Preset summary must remain blocked while exposing only bounded key/child shape evidence")
local stopResult=result({recipe(gOne,moving,1),recipe(gOne,static,2)},fOne)
check(stopResult.classification=="PROVEN" and next(stopResult.refs)==nil,
 "newer static ABS must terminate older moving ABS")
check(stopResult.activeRefs["Preset 1.1"]==static
 and stopResult.activeRefs["Preset 1.2"]==nil,
 "only the final winning static Preset, not the killed older moving ref, remains active")
local phaseResult=result({recipe(gOne,movingPhaser,1)},fOne)
check(phaseResult.classification=="PROVEN" and phaseResult.refs["Preset 25.A"]==movingPhaser
 and phaseResult.activeRefs["Preset 25.A"]==movingPhaser,
 "a surviving moving Phaser must be both a resolver source and a steady stage marker")
check(phaseResult.sourceGroups["Group 6"]==gOne,
 "a selected fixture's active Phaser Group must be marked even when its lane differs from the selected Attribute")
local selectiveResult=result({recipe(gBoth,selective,1)},fBoth)
check(selectiveResult.classification=="PROVEN" and next(selectiveResult.refs)==nil,
 "Selective static reference must remain a terminator")
local selectiveScope=result({recipe(gBoth,secondDimmer,1),
 recipe(gBoth,selectiveMoving,2)},fBoth)
check(selectiveScope.classification=="PROVEN"
 and selectiveScope.refs["Preset 1.5"]==selectiveMoving
 and selectiveScope.refs["Preset 1.6"]==secondDimmer
 and selectiveScope.refMembers["Preset 1.5"]["101"]
 and not selectiveScope.refMembers["Preset 1.5"]["201.1.1"]
 and selectiveScope.refMembers["Preset 1.6"]["201.1.1"],
 "Selective UI ownership must include stored member and exclude nonstored member")
local globalScope=result({recipe(gBoth,moving,1)},fBoth)
check(globalScope.classification=="PROVEN" and globalScope.refMembers["Preset 1.2"]["101"]
 and globalScope.refMembers["Preset 1.2"]["201.1.1"],
 "Global capability must admit both members when they have the FeatureGroup")
local layoutPartial=result({recipe(gBoth,moving,1)},fOne)
check(layoutPartial.classification=="PROVEN" and layoutPartial.refs["Preset 1.2"]==moving
 and layoutPartial.refMembers["Preset 1.2"]["101"]
 and not layoutPartial.refMembers["Preset 1.2"]["201.1.1"],
 "Layout member may receive a partial Stored Group Recipe lane without becoming a complete Group")
local savedUI=uiByHandle[subfixtureByIndex[203]]
uiByHandle[subfixtureByIndex[203]]={2,3,4}
hookState.memberUICache={}
hookState.uiChannelCache={}
local globalExcluded=result({recipe(gBoth,moving,1)},fBoth)
check(globalExcluded.classification=="PROVEN"
 and globalExcluded.refMembers["Preset 1.2"]["101"]
 and not globalExcluded.refMembers["Preset 1.2"]["201.1.1"],
 "Global applicability must exclude a member without target FeatureGroup")
uiByHandle[subfixtureByIndex[203]]=savedUI
hookState.memberUICache={}
hookState.uiChannelCache={}
local genResult=result({recipe(gOne,generator,1)},fOne)
check(genResult.classification=="PROVEN" and genResult.refs["Generator 1"]==generator
 and genResult.activeRefs["Generator 1"]==generator,
 "a surviving Generator must be both a resolver source and a steady stage marker")
local oldCue=object("Cue","Cue 900",{No=900},{object("Part","Part 0",{},
 {recipe(parentGroup,moving,1)})})
local selectedCue=object("Cue","Cue 1000",{No=1000},{object("Part","Part 0",{},
 {recipe(gOne,static,1)})})
local sequenceWide=object("Sequence","Sequence 9",{}, {oldCue,selectedCue})
local stageWideResult=provenApi.sources(sequenceWide,selectedCue,fOne,{feature="Dimmer"})
check(stageWideResult.classification=="PROVEN"
 and stageWideResult.refs["Preset 1.2"]==nil
 and stageWideResult.activeRefs["Preset 1.1"]==static
 and stageWideResult.activeRefs["Preset 1.2"]==moving,
 "purple stage references must include surviving Recipe lanes across this Sequence while selection only filters Group blink refs")
do
 local foreignPreset=preset("Preset foreign Sequence only",0,2,true)
 local foreignCue=object("Cue","Foreign Cue 1000",{No=1000},{object("Part","Foreign Part 0",{},
  {recipe(gOne,foreignPreset,1)})})
 local foreignSequence=object("Sequence","Sequence 10",{}, {foreignCue})
 local foreignResult=provenApi.sources(foreignSequence,foreignCue,fOne,{feature="Dimmer"})
 check(foreignResult.classification=="PROVEN"
  and foreignResult.activeRefs["Preset foreign Sequence only"]~=nil
  and stageWideResult.activeRefs["Preset foreign Sequence only"]==nil,
  "Recipe references from an unselected Sequence must not affect the selected Sequence result")
end
do
 local startupState={provenEnabled=true,currentSequence=sequenceWide,currentCue=selectedCue,lastFixtures={}}
 local startupRefs=functions.recipePoolReferences(startupState)
 check(startupState.provenSources.classification=="PROVEN"
  and startupRefs["Preset 1.1"]==static and startupRefs["Preset 1.2"]==moving
  and startupRefs["Group 4"]==nil and startupRefs["Group 6"]==nil,
  "opening with a valid Sequence/Cue must scan all Recipe Groups for purple refs without requiring a fixture selection")
 startupState.lastFixtures=fOne
 local selectedStageRefs=functions.recipePoolReferences(startupState)
 check(startupState.currentGroups[1]==gOne and selectedStageRefs["Group 6"]==gOne
  and selectedStageRefs["Group 4"]==nil and selectedStageRefs["Preset 1.2"]==moving,
  "selecting a fixture must derive its active Recipe Group from cached lanes across all Attributes")
end
local splitResult=result({recipe(gOne,splitPhaser,1)},fOne)
check(splitResult.classification=="PROVEN" and splitResult.refs["Preset 25.B"]==splitPhaser
 and splitResult.barriers==1,"known ABS with noncontributing unknown REL must publish ABS")
do
 local selfLinkedPhaser=phaser("Preset self-linked Phaser",attrs[0],10,20,nil,nil,nil)
 for _,step in ipairs(selfLinkedPhaser:Children()[1]:Children()) do
  step:Children()[1].Preset=selfLinkedPhaser
 end
 referenceData[selfLinkedPhaser]={count=0,by_fixtures=false}
 local selfLinkReadsBefore=referenceReads.count
 local selfLinkedResult=result({recipe(gOne,selfLinkedPhaser,1)},fOne)
 check(selfLinkedResult.classification=="INCONCLUSIVE"
  and selfLinkedResult.unsafeRefDetails["Preset self-linked Phaser"]=="PHASER_SELF_LINK_UNPROVEN"
  and referenceReads.count==selfLinkReadsBefore,
  "an embedded PhaserRecipe self-link must remain blocked without an ordinary fallback read")
 local selfLinkedUnknownRel=phaser("Preset self-linked unknown REL",attrs[0],10,20,0,0,nil)
 for _,step in ipairs(selfLinkedUnknownRel:Children()[1]:Children()) do
  local node=step:Children()[1]
  node.Preset=selfLinkedUnknownRel
  node.ValueRelative="opaque"
 end
 referenceData[selfLinkedUnknownRel]={count=0,by_fixtures=false}
 local selfUnknownRelResult=result({recipe(gOne,selfLinkedUnknownRel,1)},fOne)
 check(selfUnknownRelResult.classification=="INCONCLUSIVE",
  "a PhaserRecipe self-link must not count as independent linked metadata to close unknown REL")
 local emptyExternalLink=object("Preset","Preset empty external link",{})
 referenceData[emptyExternalLink]={count=0,by_fixtures=false}
 local externallyLinkedPhaser=phaser("Preset externally linked to empty metadata",attrs[0],10,20,nil,nil,emptyExternalLink)
 local externalLinkReadsBefore=referenceReads.count
 local externalLinkRequestsBefore=#referenceReads.requests
 local externalLinkResult=result({recipe(gOne,externallyLinkedPhaser,1)},fOne)
 local externalLinkRequests={}
 for i=externalLinkRequestsBefore+1,#referenceReads.requests do
  externalLinkRequests[#externalLinkRequests+1]=referenceReads.requests[i]
 end
 check(externalLinkResult.classification=="INCONCLUSIVE"
  and referenceReads.count==externalLinkReadsBefore+1
  and externalLinkRequests[1]==tostring(emptyExternalLink)
  and externalLinkResult.unsafeRefDetails["Preset externally linked to empty metadata"]
   :find("PHASER_LINKED_PRESET_UNPROVEN(target=Preset empty external link,cause=ORDINARY_CHANNEL_SUMMARY_UNPROVEN",1,true)~=nil,
  "a distinct external linked Preset with empty metadata must keep the existing fail-closed bridge gate (classification="
   ..tostring(externalLinkResult.classification)..", reads="..tostring(referenceReads.count-externalLinkReadsBefore)
   ..", targets="..table.concat(externalLinkRequests,",")..")")
end
local zeroAbsent=phaser("Preset 25.E",attrs[0],10,20,0,0,linked)
for _,step in ipairs(zeroAbsent:Children()[1]:Children()) do
 local node=step:Children()[1]; node.ValueRelative=nil
end
local absentResult=result({recipe(gOne,zeroAbsent,1)},fOne)
check(absentResult.classification=="PROVEN" and absentResult.barriers==0,
 "RawValueRel zero with all ValueRelative views empty proves REL absent")
local zeroAuthored=phaser("Preset 25.F",attrs[0],10,20,0,0,linked)
for _,step in ipairs(zeroAuthored:Children()[1]:Children()) do
 local node=step:Children()[1]
 node.Get=function(_,name) if name=="ValueRelative" then return 0 end end
end
local authoredResult=result({recipe(gOne,zeroAuthored,1)},fOne)
check(authoredResult.classification=="PROVEN" and authoredResult.barriers==0
 and authoredResult.refs["Preset 25.F"]==zeroAuthored,
 "RawValueRel zero with numeric zero ValueRelative is authored REL")
local blockResult=result({recipe(gOne,relPhaser,1),recipe(gOne,splitPhaser,2)},fOne)
check(blockResult.classification=="INCONCLUSIVE" and blockResult.reason=="REL_BARRIER_BLOCKS_HISTORY",
 "unknown REL barrier that blocks older moving REL must fail closed")
check(blockResult.provenActiveRefs["Preset 25.B"]==splitPhaser
 and blockResult.provenMovingRefs["Preset 25.B"]==splitPhaser,
 "a blocking residual REL must retain the independently proven ABS source for purple publication")
do
 local blockSeq,blockCue=tree({recipe(gOne,relPhaser,1),recipe(gOne,splitPhaser,2)})
 local blockState=state(blockSeq,blockCue,fOne)
 local blockMarkerRefs=functions.recipePoolReferences(blockState)
 check(blockState.provenSources.classification=="INCONCLUSIVE"
  and blockMarkerRefs["Preset 25.B"]==splitPhaser and blockMarkerRefs["Preset 25.C"]==nil,
  "staged marker publication must keep the proven ABS ref while withholding REL-blocked history")
end
local separate=result({recipe(gOne,relPhaser,1),recipe(gOne,static,2)},fOne)
check(separate.classification=="PROVEN" and separate.refs["Preset 25.C"]==relPhaser,
 "newer static ABS must not erase older moving REL")
local badLinked=preset("Preset 1.7",0,2,true)
local badSplit=phaser("Preset 25.D",attrs[0],10,20,0,0,badLinked)
local linkedFailure=result({recipe(gOne,badSplit,1)},fOne)
check(linkedFailure.classification=="INCONCLUSIVE"
 and linkedFailure.unsafeRefDetails["Preset 25.D"]
  :find("target=Preset 1.7,cause=LINKED_LANE_NOT_STATIC_ABS",1,true)~=nil,
 "linked moving Preset metadata must fail the static bridge gate")
do
 local mixedLink=preset("Preset 1.15",0,2,false)
 local extra={}
 for key,value in pairs(referenceData[mixedLink][0]) do extra[key]=value end
 extra.attribute=attrs[1]; extra.pm=3; extra.preset_store_mode=3
 extra.selective=false; extra.ui_channel_index=1
 referenceData[mixedLink][1]=extra; referenceData[mixedLink].count=2
 local linkedPhaser=phaser("Preset 25.9003 synthetic",attrs[0],10,20,nil,nil,mixedLink)
 local linkedPhaserResult=result({recipe(gOne,linkedPhaser,1)},fOne)
 check(linkedPhaserResult.classification=="PROVEN"
  and linkedPhaserResult.refs["Preset 25.9003 synthetic"]==linkedPhaser,
  "mixed Global/Universal linked UI channels must use the proven nonselective capability path")
 local mixedSelective=preset("Preset mixed Selective and Global",0,2,false)
 local selectiveChannel={}
 for key,value in pairs(referenceData[mixedSelective][0]) do selectiveChannel[key]=value end
 selectiveChannel.attribute=attrs[1]; selectiveChannel.pm=1
 selectiveChannel.preset_store_mode=1; selectiveChannel.selective=true
 selectiveChannel.ui_channel_index=1
 referenceData[mixedSelective][1]=selectiveChannel; referenceData[mixedSelective].count=2
 local mixedSelectiveResult=result({recipe(gOne,mixedSelective,1)},fOne)
 check(mixedSelectiveResult.classification=="INCONCLUSIVE"
  and mixedSelectiveResult.unsafeRefDetails["Preset mixed Selective and Global"]
   :find("PRESET_MODE_CHANNEL_CONFLICT(2,1)",1,true)~=nil,
  "mixed Selective and Global channel modes must remain fail-closed")
end
local unknown=object("Preset","Preset X")
local unknownResult=result({recipe(gOne,unknown,1)},fOne)
check(unknownResult.classification=="INCONCLUSIVE","unknown reference metadata must fail closed")
check(unknownResult.unsafeRefs and unknownResult.unsafeRefs[1]=="Preset X",
 "failed native metadata must expose bounded reference identity in the visible panel")
-- Unsafe history is retained as a lane barrier until reverse attribution.
local unsafe=preset("Preset Unsafe",0,2,false)
referenceData[unsafe][0].unrecognized_active_field=1
local unsafeHeader=result({recipe(gOne,unsafe,1)},fOne)
check(unsafeHeader.classification=="INCONCLUSIVE"
 and unsafeHeader.unsafeRefDetails["Preset Unsafe"]=="UNKNOWN_CHANNEL_FIELD_unrecognized_active_field",
 "active native channel header rejects with the exact field reason")
local function attr(resultValue)
 return resultValue.unsafeAttribution or {finalSurviving={},fullySuperseded={},unknown={}}
end
local supersededStatic=result({recipe(gOne,unsafe,1),recipe(gOne,static,2)},fOne)
check(supersededStatic.classification=="PROVEN"
 and #attr(supersededStatic).fullySuperseded==1
 and #attr(supersededStatic).finalSurviving==0
 and supersededStatic.remainingSemanticBlockers==0,
 "newer static lane must fully supersede older unsafe history")
local supersededMoving=result({recipe(gOne,unsafe,1),recipe(gOne,moving,2)},fOne)
check(supersededMoving.classification=="PROVEN"
 and #attr(supersededMoving).fullySuperseded==1
 and supersededMoving.refs["Preset 1.2"]==moving,
 "newer moving lane must fully supersede older unsafe history")
local unsafeSurvives=result({recipe(gOne,unsafe,1)},fOne)
check(unsafeSurvives.classification=="INCONCLUSIVE"
 and #attr(unsafeSurvives).finalSurviving==1,
 "surviving unsafe lane must fail closed")
do
 local partialSafe=result({recipe(gOne,unsafe,1),recipe(gOne,position,2)},fOne)
 check(partialSafe.classification=="INCONCLUSIVE"
  and partialSafe.provenActiveRefs["Preset 2.1"]==position
  and partialSafe.provenActiveRefs["Preset Unsafe"]==nil
  and partialSafe.selectedActiveRefs["Preset 2.1"]==position
  and next(partialSafe.refs)==nil,
  "an unresolved lane must remain inconclusive while independent proven lanes stay separately available")
 local partialSeq,partialCue=tree({recipe(gOne,unsafe,1),recipe(gOne,position,2)})
 local partialState=state(partialSeq,partialCue,fOne)
 local partialMarkerRefs=functions.recipePoolReferences(partialState)
 check(partialState.provenSources.classification=="INCONCLUSIVE"
  and partialMarkerRefs["Preset 2.1"]==position
  and partialMarkerRefs["Preset Unsafe"]==nil
  and partialState.selectedRecipeReferenceKeys["Preset 2.1"]==true,
  "only independently proven refs may receive steady/pulse markers during an inconclusive scan")
end
local unsafeVictim=result({recipe(gOne,moving,1),recipe(gOne,unsafe,2)},fOne)
check(unsafeVictim.classification=="INCONCLUSIVE"
 and #attr(unsafeVictim).finalSurviving==1,
 "unsafe row blocking older moving lane must fail even without final ref")
local partialUnsafe=result({recipe(gBoth,unsafe,1),recipe(gOne,static,2)},fBoth)
check(partialUnsafe.classification=="INCONCLUSIVE"
 and #attr(partialUnsafe).finalSurviving==1
 and #attr(partialUnsafe).fullySuperseded==0,
 "one surviving member lane blocks full supersession")
local tenSelection,nineSelection,tenFixtures={},{},{}
for i=301,310 do
 local handle=object("SubFixture","Fixture "..i)
 subfixtureByIndex[i]=handle; uiByHandle[handle]={0}
 tenSelection[#tenSelection+1]={sf_index=i}
 tenFixtures[#tenFixtures+1]=selectedFixture(i)
 if i<310 then nineSelection[#nineSelection+1]={sf_index=i} end
end
local gTen=object("Group","Group 10",{Selection=tenSelection})
local gNine=object("Group","Group 11",{Selection=nineSelection})
local previousChildren=groupPool.Children
groupPool.Children=function() local all=previousChildren(); all[#all+1]=gTen; all[#all+1]=gNine; return all end
local nineOfTen=result({recipe(gTen,unsafe,1),recipe(gNine,static,2)},tenFixtures)
check(nineOfTen.classification=="INCONCLUSIVE"
 and #attr(nineOfTen).finalSurviving==1
 and #attr(nineOfTen).fullySuperseded==0,
 "nine superseded lanes plus one unresolved lane must remain unsafe")
local unknownHistory=result({recipe(gOne,unknown,1),recipe(gOne,static,2)},fOne)
check(unknownHistory.classification=="INCONCLUSIVE"
 and #attr(unknownHistory).unknown==0
 and #attr(unknownHistory).finalSurviving==1,
 "wildcard unsafe scope cannot be neutralized by one exact static lane")
local selectiveClosure=result({recipe(gOne,unsafe,1),recipe(gOne,selective,2)},fOne)
check(selectiveClosure.classification=="PROVEN"
 and #attr(selectiveClosure).fullySuperseded==1,
 "Selective static closure must still neutralize an older exact unsafe lane")
local unsafeRelative=preset("Preset Unsafe Relative",0,2,false)
referenceData[unsafeRelative][0].mask_active_value=2|4
referenceData[unsafeRelative][0][1].relative=1
referenceData[unsafeRelative][0].unrecognized_active_field=1
local residualClosure=result({recipe(gOne,unsafeRelative,1),recipe(gOne,splitPhaser,2)},fOne)
check(residualClosure.classification=="INCONCLUSIVE",
 "residual REL overlapping older unsafe history must fail closed")
local residualUnrelated=result({recipe(gCell,beam,1),recipe(gOne,splitPhaser,2)},fBoth)
check(residualUnrelated.classification=="PROVEN" and residualUnrelated.barriers==1,
 "residual REL with no older same-member lane stays noncontributing")
local staticBoth=preset("Preset Static Both",0,2,false)
referenceData[staticBoth][0].mask_active_value=2|4
referenceData[staticBoth][0][1].relative=1
local phaserHistory=result({recipe(gOne,badSplit,1),recipe(gOne,staticBoth,2)},fOne)
check(phaserHistory.classification=="PROVEN"
 and #attr(phaserHistory).fullySuperseded==1,
 "structurally scoped unsafe Phaser history can be fully superseded")
local multiResult=result({recipe(gOne,moving,1),recipe(gCell,beam,2)},fBoth)
check(multiResult.classification=="PROVEN" and multiResult.refs["Preset 1.2"]==moving
 and multiResult.refs["Preset 5.1"]==beam,"two complete Groups must retain separate moving refs")
local duplicate=result({recipe(gOne,moving,1),recipe(gBoth,moving,2)},fBoth)
local duplicateCount=0; for _ in pairs(duplicate.refs or {}) do duplicateCount=duplicateCount+1 end
check(duplicate.classification=="PROVEN" and duplicateCount==1,
 "duplicate surviving reference identities must deduplicate at final source set")
local partialGroup=result({recipe(gBoth,beam,1),recipe(gOne,moving,2)},fOne)
check(partialGroup.classification=="PROVEN" and partialGroup.refs["Preset 1.2"]==moving
 and partialGroup.refs["Preset 5.1"]==nil,"partial Stored Group must be excluded")
local finalResult,finalSeq,finalCue=result({
 recipe(gOne,unsafe,1),recipe(gOne,static,2),recipe(gOne,moving,3),
 recipe(gOne,position,4),recipe(gOne,generator,5),recipe(gCell,beam,6),
 recipe(gCell,cellStatic,7)
},fBoth)
local expected={["Preset 1.2"]=true,["Preset 2.1"]=true,
 ["Generator 1"]=true,["Preset 5.1"]=true}
local final,missing,extra=0,0,0
for key in pairs(finalResult.refs or {}) do final=final+1; if not expected[key] then extra=extra+1 end end
for key in pairs(expected) do if not (finalResult.refs or {})[key] then missing=missing+1 end end
check(finalResult.classification=="PROVEN" and final==4 and missing==0 and extra==0,
 "synthetic Cue-8-equivalent with unsafe history must have final_refs=4 missing=0 extra=0")
check(#attr(finalResult).fullySuperseded==1 and finalResult.remainingSemanticBlockers==0,
 "synthetic four-reference result must exclude fully superseded unsafe history")
check(finalResult.sourceGroups["Group 6"]==gOne and finalResult.sourceGroups["Group 7"]==gCell
 and finalResult.sourceGroups["Group 8"]==nil,
 "only Groups with surviving lanes for selected members become current Groups")
do
 local embeddedPhaserOnly=phaser("Preset 25.P",attrs[0],11,21,nil,nil,nil)
 local directPhaser=embeddedPhaserOnly:Children()[1]
 local directPhaserResult=result({recipe(gOne,directPhaser,1)},fOne)
 check(directPhaserResult.classification=="PROVEN"
  and directPhaserResult.refs["Preset 25.P Recipe"]==directPhaser,
  "a surviving direct PhaserRecipe source must remain in the published reference set")
end
local cached=state(finalSeq,finalCue,fBoth)
_G.SelectionFirst=function() return 101,0,0,0 end
_G.SelectionNext=function(index)
 if index==101 then return 203,1,0,0 end
 return nil
end
_G.SelectedSequence=function() return finalSeq end
_G.GetCurrentCue=function() return finalCue end
local panelText=functions.render(cached)
local visibleSourceCount=0
for key in pairs(expected) do if cached.markerReferences and cached.markerReferences[key] then visibleSourceCount=visibleSourceCount+1 end end
local stageActiveCount=tableCount(cached.provenSources.activeRefs)
check(panelText:find("Resolver: PROVEN | "..stageActiveCount.." refs",1,true)~=nil
 and cached.provenSourceKey~=nil and visibleSourceCount==4
 and stageActiveCount>=visibleSourceCount,
 "selection refresh must expose the complete tracked stage set while retaining all four moving compatibility refs")
check(panelText:find("Groups:\n6 Key\n7 Cell",1,true)~=nil,
 "panel must show both numbered current Groups and visible resolver status")
local first=functions.recipePoolReferences(cached)
local reads=referenceReads.count
functions.recipePoolReferences(cached)
check(referenceReads.count==reads and referenceReads.part==0,
 "steady marker pulse must reuse reference metadata and never read cooked Cue history")
local stable=state(finalSeq,finalCue,fBoth)
local beforeChildren=groupPool.Children
local groupScans=0
groupPool.Children=function(...)
 groupScans=groupScans+1
 return beforeChildren(...)
end
functions.recipePoolReferences(stable)
functions.recipePoolReferences(stable)
check(groupScans==1,"unchanged marker context must reuse complete Group matching")
groupPool.Children=beforeChildren
do
 local objectListOriginal,subfixtureAddressCalls=_G.ObjectList,0
 _G.ObjectList=function(addr)
  if addr=="Fixture 201.1.1" then subfixtureAddressCalls=subfixtureAddressCalls+1 end
  return objectListOriginal(addr)
 end
 local identityCacheState=state(finalSeq,finalCue,fBoth)
 functions.recipePoolReferences(identityCacheState)
 local firstIdentityPass=subfixtureAddressCalls
 identityCacheState.lastFixtures=fOne
 identityCacheState.provenSourceKey=nil
 functions.recipePoolReferences(identityCacheState)
 check(firstIdentityPass>0 and subfixtureAddressCalls==firstIdentityPass
  and (identityCacheState.groupMemberCacheHits or 0)>0,
  "unchanged Stored Group member identities must reuse exact canonical keys across selection changes")
 _G.ObjectList=objectListOriginal
end
do
 local historyRecipe=recipe(gOne,moving,1)
 local historySeq,historyCue=tree({historyRecipe})
 local childrenOriginal,historyScans=historySeq.Children,0
 local signature=functions.trackingStructureKey(historySeq,historyCue)
 historySeq.Children=function(self) historyScans=historyScans+1; return childrenOriginal(self) end
 local historyState=state(historySeq,historyCue,fOne)
 historyState.trackARecipeStructureKey=signature
 functions.recipePoolReferences(historyState)
 local initialScans=historyScans
 historyState.lastFixtures=fBoth; historyState.provenSourceKey=nil
 functions.recipePoolReferences(historyState)
 check(initialScans>0 and historyScans==initialScans,
  "unchanged Cue Recipe history rows must be reused when selected members change")
 historyRecipe.Values=position
 local changedSignature=functions.trackingStructureKey(historySeq,historyCue)
 if changedSignature~=historyState.trackARecipeStructureKey then
  historyState.trackARecipeStructureKey=changedSignature
  historyState.trackAHistoryRowsCache=nil
 end
 historyState.provenSourceKey=nil
 local updatedHistory=functions.recipePoolReferences(historyState)
 check(historyScans>initialScans and updatedHistory["Preset 2.1"]==position,
  "Recipe reference relink must invalidate the cached history rows")
end
local unknownSeq,unknownCue=tree({recipe(gOne,unknown,1)})
local failedState=state(unknownSeq,unknownCue,fOne)
failedState.currentGroup=parentGroup
local groupOnly=functions.recipePoolReferences(failedState)
check(groupOnly["Group 6"]==nil and groupOnly["Group 4"]==nil
 and groupOnly["Preset X"]==nil,
 "failed resolver must not publish stale Group or guessed Recipe refs")
failedState.currentGroup=gOne
local exactGroupOnly=functions.recipePoolReferences(failedState)
check(exactGroupOnly["Group 6"]==gOne and exactGroupOnly["Preset X"]==nil,
 "exact current Group may be marked independently while unsafe Recipe refs remain closed")
local partialFailed=state(unknownSeq,unknownCue,fOne)
partialFailed.currentGroup=gBoth; partialFailed.currentRecipe=recipe(gBoth,unknown,1)
local partialGroupOnly=functions.recipePoolReferences(partialFailed)
check(partialGroupOnly["Group 8"]==gBoth and partialGroupOnly["Preset X"]==nil,
 "displayed single Recipe Group may be marked for a selected member while unsafe Values stay closed")
check(first["Group 6"]==gOne and first["Group 7"]==gCell
 and first["Preset 1.2"]==moving and first["Generator 1"]==generator,
 "Group and surviving Recipe Pool marker sources must be present")
check(first["Group 8"]==nil and #cached.currentGroups==2
 and functions.groupDisplayLabel(gOne)=="6 Key"
 and functions.groupDisplayLabel(gCell)=="7 Cell",
 "overlapping noncontributing Group stays dark and current Groups retain number plus name")
local groupLines=functions.groupPanelLines(cached.currentGroups)
check(groupLines[1]=="Groups:" and groupLines[2]=="6 Key" and groupLines[3]=="7 Cell"
 and functions.groupPanelLines({gOne})[1]=="Group: 6 Key",
 "single and multiple current Groups must render number plus name")
local scanTrackingCalls,scanTrackingOriginal=0,nil
scanTrackingOriginal=swapUpvalue(functions.render,"scanTracking",function(...)
 scanTrackingCalls=scanTrackingCalls+1
 return scanTrackingOriginal(...)
end)
local originalReadSelection=swapUpvalue(functions.render,"readSelection",function() return fBoth end)
local originalReadProgrammer=swapUpvalue(functions.render,"readProgrammer",function()
 return {feature="Dimmer",preset=moving,attributes={"Dimmer"}}
end)
local scanCacheState=state(finalSeq,finalCue,fBoth)
local cacheRecipe=finalCue:Children()[1]:Children()[1]
local cacheRecipeValues=cacheRecipe.Values
functions.render(scanCacheState)
functions.render(scanCacheState)
check(scanTrackingCalls==1 and scanCacheState.lastTrackingScanMs==0,
 "unchanged Recipe structure must reuse the tracking candidate scan between pulse refreshes")
cacheRecipe.Values=position
scanCacheState.trackARecipeStructureCheckAt=0
functions.render(scanCacheState)
check(scanTrackingCalls==2,
 "Recipe reference relink must invalidate the structural tracking cache")
cacheRecipe.Values=cacheRecipeValues
scanCacheState.expanded=true
local detailOK,detailText=pcall(functions.render,scanCacheState)
check(detailOK and type(detailText)=="string" and detailText:find("Time ms: scan",1,true)~=nil,
 "expanded Detail must render resolver timings through the local formatElapsed helper")
scanCacheState.expanded=false
swapUpvalue(functions.render,"scanTracking",scanTrackingOriginal)
swapUpvalue(functions.render,"readSelection",originalReadSelection)
swapUpvalue(functions.render,"readProgrammer",originalReadProgrammer)
do
 local runtime=assert(functions.newTrackARuntime,"production resolver factory must be test-visible")
 local api={
  safe=function(fn,...) local ok,value=pcall(fn,...); if ok then return value end end,
  class=function(value) return value and value.kind or "Unknown" end,
  identity=function(value) return value and value.addr end,
  children=function(value) return value and value.children or {} end,
  getPresetData=function() return nil end,
 }
 local sparseRuntime=runtime(api)
 local memberMap,rowList,scopeMisses,scopeEnumerations={},{},0,0
 for index=1,48 do
  local member="Fixture "..index
  memberMap[member]={kind="SubFixture",addr=member}
  local groupMembers=setmetatable({[member]=true},{
   __index=function() scopeMisses=scopeMisses+1 end,
   __pairs=function(value)
    scopeEnumerations=scopeEnumerations+1
    return next,value,nil
   end,
  })
  rowList[index]={ref={kind="Preset",addr="Preset unknown "..index},groupMembers=groupMembers}
 end
 local sparseResult=sparseRuntime.run(rowList,memberMap,{}, {})
 check(sparseResult.classification=="INCONCLUSIVE" and scopeMisses==0
  and scopeEnumerations==48 and #sparseResult.unsafeAttribution.finalSurviving==48,
  "sparse single-member Recipe rows must normalize without scanning unrelated Sequence members")
 scopeEnumerations=0
 local rowsByMember,indexedRows={},{}
 for rowIndex,row in ipairs(rowList) do
  indexedRows[rowIndex]=true
  for key in pairs(row.groupMembers) do
   rowsByMember[key]=rowsByMember[key] or {}
   rowsByMember[key][#rowsByMember[key]+1]=rowIndex
  end
 end
 local indexedResult=sparseRuntime.run(rowList,memberMap,{}, {},true,rowsByMember,indexedRows)
 check(indexedResult.classification==sparseResult.classification
  and indexedResult.reason==sparseResult.reason
  and #indexedResult.unsafeAttribution.finalSurviving==#sparseResult.unsafeAttribution.finalSurviving
  and indexedResult.laneWork==sparseResult.laneWork and scopeMisses==0 and scopeEnumerations==48,
  "indexed sparse Recipe rows must preserve reverse results while avoiding per-slice Group rescans")
end
do
 local fg={kind="FeatureGroup",addr="FeatureGroup 1"}
 local featureHandle={kind="Feature",addr="Feature 1",Parent=function() return fg end}
 local attributeHandle={kind="Attribute",addr="Attribute 1",Feature=featureHandle}
 local presetData={}
 local function safeMovingPreset(addr)
  local ref={kind="Preset",addr=addr}
  presetData[ref]={[0]={attribute=attributeHandle,pm=2,preset_store_mode=2,
   selective=false,mask_active_phaser=4,mask_active_value=2,mask_cooked=0,
   ui_channel_index=0,[1]={absolute=10},[2]={absolute=20}},count=1,by_fixtures=false}
  return ref
 end
 local safeRuntime=functions.newTrackARuntime({
  safe=function(fn,...) local ok,value=pcall(fn,...); if ok then return value end end,
  class=function(value) return value and value.kind or "Unknown" end,
  identity=function(value) return value and value.addr end,
  children=function(value) return value and value.children or {} end,
  getPresetData=function(ref) return presetData[ref] end,
  getUIChannels=function() return {{INDEX=1}} end,
  attributeByUI=function() return attributeHandle end,
 })
 local f1,f2="Fixture 101","Fixture 102"
 local members={[f1]={kind="SubFixture",addr=f1},[f2]={kind="SubFixture",addr=f2}}
 local rows={
  {ref=safeMovingPreset("Preset indexed new"),groupMembers={[f1]=true,[f2]=true},groupMemberCount=2},
  {ref=safeMovingPreset("Preset indexed older 1"),groupMembers={[f1]=true},groupMemberCount=1},
  {ref=safeMovingPreset("Preset indexed older 2"),groupMembers={[f2]=true},groupMemberCount=1},
 }
 local baseline=safeRuntime.run(rows,members,{}, {},true)
 local rowsByMember={[f1]={1,2},[f2]={1,3}}
 local indexed=safeRuntime.run(rows,members,{}, {},true,rowsByMember,{[1]=true,[2]=true,[3]=true})
 local sameRefs=baseline.classification==indexed.classification and baseline.laneWork==indexed.laneWork
 for id,ref in pairs(baseline.refs or {}) do sameRefs=sameRefs and indexed.refs[id]==ref end
 for id,ref in pairs(indexed.refs or {}) do sameRefs=sameRefs and baseline.refs[id]==ref end
 local function assignmentSet(result)
  local set={}
  for _,a in ipairs(result.laneAssignments or {}) do
   set[table.concat({a.member,a.lane,a.refId,tostring(a.moving)},"\0")]=true
  end
  return set
 end
 local aSet,bSet=assignmentSet(baseline),assignmentSet(indexed)
 for key in pairs(aSet) do sameRefs=sameRefs and bSet[key]==true end
 for key in pairs(bSet) do sameRefs=sameRefs and aSet[key]==true end
 check(sameRefs and tableCount(baseline.refs)==1 and tableCount(indexed.refs)==1,
  "indexed sparse rows must preserve proven moving refs and member/lane ownership")
end
local editRecipe=recipe(gOne,moving,1)
local editSeq,editCue=tree({editRecipe})
local editState=state(editSeq,editCue,fOne)
editState.currentRecipe=editRecipe; editState.currentOldPreset=moving
check(functions.recipePoolReferences(editState)["Preset 1.2"]==moving,
 "initial Recipe source must publish")
editRecipe.Values=position
editState.currentOldPreset=position
local edited=functions.recipePoolReferences(editState)
check(edited["Preset 1.2"]==nil and edited["Preset 2.1"]==position,
 "Recipe source change must invalidate the cached final refs")
editCue:Children()[1].Children=function() return {} end
editState.currentRecipe=nil; editState.currentOldPreset=nil
local deleted=functions.recipePoolReferences(editState)
check(deleted["Preset 2.1"]==nil,
 "Recipe deletion must invalidate the source cache")
local unrelatedResult=result({recipe(gOne,object("Preset","Preset Unknown"),1),recipe(gCell,beam,2)},fBoth)
check(unrelatedResult.classification=="INCONCLUSIVE",
 "unresolved reference semantics anywhere in admitted scope must fail closed")
local expected9009=preset("Preset 25.9009",0,2,true)
local markerSeq,markerCue=tree({recipe(gOne,expected9009,1)})
local markerState=state(markerSeq,markerCue,fOne)
markerState.currentGroup=gOne; markerState.currentRecipe=markerCue:Children()[1]:Children()[1]
local immediateRefs=functions.recipePoolReferences(markerState)
check(immediateRefs["Group 6"]==gOne and immediateRefs["Preset 25.9009"]==expected9009
 and markerState.provenSourceKey~=nil,
 "one context refresh must resolve surviving Cue refs and the matched Group without an extra poll")
check(markerState.selectedRecipeReferenceKeys["Preset 25.9009"]==true
 and markerState.selectedRecipeReferenceCount==1,
 "a currently selected member's surviving Recipe ref must be marked independently of stage purple")
markerState.running=true; markerState.poolBlink=true
markerState.markerReferences=immediateRefs
check(markerState.poolMarkersDirty==true,
 "semantic recompute must request a marker refresh in the same loop")
check(markerState.markerReferences["Preset 25.9009"]==expected9009,
 "9009-style final ref must reach marker source")
check(markerState.markerProbe["Preset 25.9009"].sourceAdmitted==true,
 "final 9009-style ref must survive recipePoolReferences admission")
do
 local overlapGroup=object("Group","Group 231",{Name="Overlapping",Selection={{sf_index=101}}})
 local currentRecipe=recipe(gOne,expected9009,1)
 local overlapRecipe=recipe(overlapGroup,beam,2)
 local overlapSeq,overlapCue=tree({currentRecipe,overlapRecipe})
 local overlapState=state(overlapSeq,overlapCue,fOne)
 overlapState.currentGroup=gOne; overlapState.currentRecipe=currentRecipe
 local overlapRefs=functions.recipePoolReferences(overlapState)
 check(overlapRefs["Group 6"]==gOne and overlapRefs["Group 231"]==nil
  and #overlapState.currentGroups==1 and overlapState.currentGroups[1]==gOne,
  "the current Recipe Group alone must pulse when overlapping historical Groups also own other surviving lanes")
end
do
 local embedded=phaser("Preset 25.P2",attrs[0],11,21,nil,nil,nil)
 local phaserReference=embedded:Children()[1]
 local directPhaserSeq,directPhaserCue=tree({recipe(gOne,phaserReference,1)})
 local directPhaserState=state(directPhaserSeq,directPhaserCue,fOne)
 local directPhaserSources=functions.recipePoolReferences(directPhaserState)
 check(directPhaserSources["Preset 25.P2 Recipe"]==phaserReference,
  "a surviving PhaserRecipe object must reach the same Pool marker source pipeline")
end
local stagedSeq,stagedCue=tree({recipe(gOne,moving,1)})
local stagedState=state(stagedSeq,stagedCue,fOne); stagedState.incrementalResolver=true
local stagedRefs={}
local stagedUIBefore=uiCalls
stagedRefs=functions.recipePoolReferences(stagedState)
check(stagedState.provenSources.classification=="PROVEN"
 and stagedRefs["Preset 1.2"]==moving and uiCalls>stagedUIBefore,
 "one context refresh must resolve metadata and member lanes without polling-cycle staging")
local stagedReads=referenceReads.count
functions.recipePoolReferences(stagedState)
check(referenceReads.count==stagedReads,
 "incremental resolver steady state must reuse cached reference metadata")
stagedState.lastFixtures={fBoth[2]}
functions.recipePoolReferences(stagedState)
check(stagedState.lastResolverStageCacheHit==true
 and stagedState.provenSources.classification=="PROVEN"
 and stagedState.provenSources.refs["Preset 1.2"]==nil
 and stagedState.provenSources.activeRefs["Preset 1.2"]==moving,
 "changing selected members must reuse the stage-wide tracked reference set while filtering selected lanes")
local savedFirst,savedNext=_G.SelectionFirst,_G.SelectionNext
local savedSequence,savedCue,savedCmd=_G.SelectedSequence,_G.GetCurrentCue,_G.Cmd
local savedPluginState=_G.RecipeTrackingInspectorState
local groupCommands={}
_G.SelectionFirst=function() return 101,0,0,0 end
_G.SelectionNext=function() return nil end
_G.SelectedSequence=function() return stagedSeq end
_G.GetCurrentCue=function() return stagedCue end
_G.Cmd=function(command) groupCommands[#groupCommands+1]=command; return "OK" end
stagedState.currentGroup=gOne
stagedState.currentSequence=stagedSeq
stagedState.currentCue=stagedCue
stagedState.lastFixtures=fOne
stagedState.matchingCandidates={}
_G.RecipeTrackingInspectorState=stagedState
local readsBeforeGroupClick=referenceReads.count
assert(type(signals.SelectRecipeTrackingGroup)=="function")
signals.SelectRecipeTrackingGroup()
check(#groupCommands==2 and groupCommands[2]=="SelectFixtures Group 6"
 and stagedState.forceRefresh==true and stagedState.preserveResolverCaches==true
 and referenceReads.count==readsBeforeGroupClick,
 "SELECT GROUP must use the already-rendered target without synchronously rerunning Track A")
_G.SelectionFirst,_G.SelectionNext=savedFirst,savedNext
_G.SelectedSequence,_G.GetCurrentCue,_G.Cmd=savedSequence,savedCue,savedCmd
_G.RecipeTrackingInspectorState=savedPluginState
local tileAlias=object("Preset","Preset 25.9009")
local button=object("PoolButton","Preset tile",{ObjectIndex=1,W=80,H=80,
 Anchors={left=0,right=0,top=0,bottom=0}})
local nested=object("UIObject","Nested tile holder",{}, {button})
local pool=object("PoolLayoutGrid","Preset pool",{
 PoolObject={Ptr=function(_,i) if i==1 then return tileAlias end end},
 IsActuallyVisible=function() return true end
}, {nested})
local overlay
pool.Append=function()
 overlay={CommandDelete=function(self) self.deleted=true end}
 return overlay
end
local display=object("Display","Display 1",{}, {pool})
_G.GetDisplayByIndex=function(index) return index==1 and display or nil end
functions.refreshPoolMarkers(markerState)
check(markerState.poolMarkers[button] and overlay and overlay.Texture=="frame0"
 and overlay.Visible=="Yes" and overlay.HasHover=="No"
 and markerState.poolMarkers[button].markerKind=="selectedRecipe"
 and overlay.BackColor=="Global.AlertText",
 "a selected member's surviving Recipe tile must use the solid red theme frame")
 ;(function()
 local savedTime,stationTime=Time,300
 Time=function() return stationTime end
 local tracked=object("Preset","Preset recycle target")
 local unrelated=object("Preset","Preset not tracked")
 local recycledButton=object("PoolButton","Reusable tile",{ObjectIndex=9,W=80,H=80,
  Anchors={left=0,right=0,top=0,bottom=0}})
 local recycledPool={Ptr=function(_,index)
  if index==9 then return tracked elseif index==10 then return unrelated end
 end}
 local recycledGrid=object("PoolLayoutGrid","Recycled preset pool",{
  PoolObject=recycledPool,IsActuallyVisible=function() return true end},{recycledButton})
 local recycledOverlay
 recycledGrid.Append=function()
  recycledOverlay={CommandDelete=function(self) self.deleted=true end}
  return recycledOverlay
 end
 local recycledState={running=true,poolBlink=true,provenEnabled=true,
  currentSequence=object("Sequence","Sequence 101"),currentCue=object("Cue","Cue 1"),
  markerReferences={[tracked:ToAddr()]=tracked},poolGrids={recycledGrid},
  poolMarkers={},poolMarkersDirty=true}
 functions.refreshPoolMarkers(recycledState)
 check(recycledState.poolMarkers[recycledButton]
  and recycledState.poolMarkers[recycledButton].pool==recycledPool
  and recycledState.poolMarkers[recycledButton].poolIndex==9
  and recycledState.poolMarkers[recycledButton].reference==tracked,
  "Pool marker entries must retain the Pool/index/reference identity they were attached to")
 local oldOverlay=recycledOverlay
 recycledState.poolMarkersDirty=false
 recycledState.poolLookupDeadline=stationTime+5
 recycledButton.ObjectIndex=10
 functions.refreshPoolMarkers(recycledState)
 check(oldOverlay.deleted==true and next(recycledState.poolMarkers)==nil,
  "a recycled Pool tile must lose its stale purple frame immediately, before the normal rescan deadline")
 Time=savedTime
end)()
do
 local saved={tileAlias,overlay,Time,400}
 Time=function() return saved[4] end
 stagedSeq,stagedCue=tree({recipe(gOne,expected9009,1)})
 stagedState={running=true,poolBlink=true,incrementalResolver=true,provenEnabled=true,
  currentSequence=stagedSeq,currentCue=stagedCue,currentGroup=gOne,
  lastFixtures={selectedFixture(101)},lastFeature="Dimmer",matchingCandidates={},
  completeGroupSelectionKey="101",completeGroupCandidates={gOne},
  referenceMetadataCache={},memberUICache={},resolverWorkKey="Sequence 9:1000",
  resolverTask={key="Sequence 9:1000",stageKey="early",rows={},
   members={{key="101",handle=subfixtureByIndex[101]},
    {key="201",handle=subfixtureByIndex[201]},{key="201.1",handle=subfixtureByIndex[202]},
    {key="201.1.1",handle=subfixtureByIndex[203]},{key="900",handle=subfixtureByIndex[101]}},
    memberIndex=1,metadataIndex=1,memberSliceLimit=32,selectedMembers={["101"]=subfixtureByIndex[101]},
    runtime={memberUI=function(handle,cache) cache[handle]={} end,
    run=function(_,memberSlice)
     saved[4]=saved[4]+0.009
     local assignments={}
     for member in pairs(memberSlice) do
      assignments[#assignments+1]={member=member,lane="Dimmer|ABS",fg="Dimmer",
       refId="Preset 25.9009",ref=expected9009,group=gOne,moving=true}
      end
      return {classification="PROVEN",refs={["Preset 25.9009"]=expected9009},
      activeRefs={["Preset 25.9009"]=expected9009},laneAssignments=assignments,sourceGroups={}}
    end}},
   poolGrids={pool},poolMarkers={},poolMarkersDirty=true}
 for index=6,50 do
  table.insert(stagedState.resolverTask.members,
   {key=tostring(900+index),handle=subfixtureByIndex[101]})
 end
 tileAlias=expected9009
 stagedRefs=functions.recipePoolReferences(stagedState)
 check(stagedState.provenSources.classification=="PENDING"
  and stagedState.resolverTask.memberIndex==33
  and next(stagedState.provenSources.refs)==nil
  and stagedRefs["Preset 25.9009"]==expected9009
  and stagedState.selectedRecipeReferenceKeys["Preset 25.9009"]==true,
  "PENDING may expose the completed selected reference but must not publish partial Sequence-wide refs")
 stagedState.markerReferences=stagedRefs
 functions.refreshPoolMarkers(stagedState)
 check(stagedState.poolMarkers[button] and overlay
  and stagedState.poolMarkers[button].markerKind=="selectedRecipe"
  and overlay.Visible=="Yes" and overlay.BackColor=="Global.AlertText",
  "the first completed selected-member chunk must create its red Pool frame before the full Sequence finishes")
 tileAlias,overlay=saved[1],saved[2]
 Time=saved[3]
end
do
 local savedTime=Time
 local stationTime=100
 Time=function() return stationTime end
 local timedPulse={running=true,poolBlinkOn=true,poolBlinkDeadline=100.2,
  poolMarkers={[button]={overlay=overlay,markerKind="selectedRecipe"}}}
 local beforeColor=overlay.BackColor
 stationTime=102; functions.advancePoolPulse(timedPulse)
 check(timedPulse.poolBlinkOn==true and timedPulse.poolBlinkDeadline==100.2
  and overlay.BackColor==beforeColor,
  "the responsiveness build must not run timer-driven UI color writes")
 Time=savedTime
end
local blinkPhase=markerState.poolBlinkOn
functions.refreshPoolMarkers(markerState)
check(markerState.poolBlinkOn==blinkPhase,
 "stable frame colors must not change during another fast refresh")
local beforeSelectedPulse=overlay.BackColor
markerState.poolBlinkDeadline=functions.clockSeconds()-0.01
functions.refreshPoolMarkers(markerState)
check(markerState.poolBlinkOn==blinkPhase and overlay.BackColor==beforeSelectedPulse,
 "stable marker colors must remain unchanged when an old pulse deadline passes")
check(functions.poolPulseColor("group",true)=="Global.AlertText"
 and functions.poolPulseColor("group",false)=="Global.AlertText",
 "Stored Group marker must stay solid red in the low-load mode")
check(functions.poolPulseColor("recipe",true)=="TrackProgLayerActive.Phaser"
 and functions.poolPulseColor("recipe",false)=="TrackProgLayerActive.Phaser",
 "steady Recipe tracking markers must use the brighter stock Phaser purple")
check(functions.poolPulseColor("selectedRecipe",true)=="Global.AlertText"
 and functions.poolPulseColor("selectedRecipe",false)=="Global.AlertText",
 "selected Recipe markers must stay solid red in the low-load mode")
check(markerState.markerProbe["Preset 25.9009"].frameCreated==true,
 "9009 marker pipeline must reach FRAME_CREATED")
check(markerState.markerStatus=="1/1 overlays",
 "normal UI status must report attached marker overlays without claiming visible paint")
markerState.currentGroup=gOne
markerState.currentGroups={gOne}
markerState.currentRecipe=recipe(gOne,expected9009,2)
markerState.lastFixtures={}
markerState.currentGroup=nil
markerState.currentRecipe=nil
do
 local stageRefsWithoutSelection=functions.recipePoolReferences(markerState)
 markerState.markerReferences=stageRefsWithoutSelection
 markerState.poolMarkersDirty=true
 functions.refreshPoolMarkers(markerState)
 check(stageRefsWithoutSelection["Preset 25.9009"]==expected9009
  and stageRefsWithoutSelection["Group 6"]==nil and overlay.deleted~=true
  and markerState.poolMarkers[button]~=nil
  and markerState.poolMarkers[button].markerKind=="recipe"
  and overlay.BackColor=="TrackProgLayerActive.Phaser",
 "clearing fixture selection must remove selected frames but preserve steady purple Sequence refs")
end
markerState.currentSequence=nil
markerState.currentCue=nil
markerState.markerReferences={}
markerState.poolMarkersDirty=true
_G.SelectionFirst=function() return nil end
_G.SelectionNext=function() return nil end
functions.refreshPoolMarkers(markerState)
check(overlay.deleted and next(markerState.poolMarkers)==nil
 and #markerState.currentGroups==0 and markerState.currentGroup==nil
 and markerState.currentRecipe==nil and (not markerState.markerReferences or next(markerState.markerReferences)==nil),
 "losing the active Sequence/Cue context must remove stale Group and Recipe frames on the next refresh")
-- The native .16 failure was an all-or-nothing resolver result: one unsafe
-- lane suppressed every otherwise decided Sequence reference. Verify the
-- .17 partial-safe path through Pool identity and overlay creation, both as a
-- steady purple stage marker and as a selected-member pulse. Reuse existing
-- locals to stay below Lua's 200-local limit for this test chunk.
stagedSeq,stagedCue=tree({recipe(gOne,unsafe,1),recipe(gOne,position,2)})
stagedState=state(stagedSeq,stagedCue,{})
stagedState.running=true; stagedState.poolBlink=true
stagedState.poolGrids={pool}; stagedState.poolMarkersDirty=true
tileAlias=position
stagedRefs=functions.recipePoolReferences(stagedState)
stagedState.markerReferences=stagedRefs
check(stagedState.provenSources.classification=="INCONCLUSIVE"
 and stagedState.provenSources.provenActiveRefs["Preset 2.1"]==position
 and stagedRefs["Preset 2.1"]==position and stagedRefs["Preset Unsafe"]==nil,
 "inconclusive history must admit only the independently proven stage reference")
functions.refreshPoolMarkers(stagedState)
check(stagedState.poolMarkers[button] and overlay
 and stagedState.poolMarkers[button].markerKind=="recipe"
 and overlay.Texture=="frame0" and overlay.Visible=="Yes"
 and overlay.BackColor=="TrackProgLayerActive.Phaser",
 "a proven partial stage reference must create its steady purple Pool overlay")
stagedState.lastFixtures=fOne
stagedRefs=functions.recipePoolReferences(stagedState)
stagedState.markerReferences=stagedRefs
stagedState.poolMarkersDirty=true
functions.refreshPoolMarkers(stagedState)
check(stagedState.provenSources.classification=="INCONCLUSIVE"
 and stagedState.selectedRecipeReferenceKeys["Preset 2.1"]==true
 and stagedState.poolMarkers[button].markerKind=="selectedRecipe"
 and overlay.BackColor=="Global.AlertText",
 "a selected member's proven partial reference must enter a solid red frame")
stagedSeq,stagedCue,stagedRefs,stagedState=functions.coloredTextLayers(
 "Resolver: INCONCLUSIVE | Missing Preset 2.14 @ VISIBLE_POOL_TILE_NOT_FOUND\n"
 .."Blocked refs: Preset 25.9003\nRefs: Preset 1.1, Preset 2.14\n"
 .."Old Values: Position | Preset 2.14 \"5 Corner\"\nNew Preset: Preset 4.4")
check(stagedSeq:find("Missing Preset 2.14",1,true)~=nil
 and stagedState:find("Missing Preset",1,true)==nil
 and stagedState:find("Blocked refs",1,true)==nil
 and stagedState:find("Refs:",1,true)==nil
 and stagedState:find("Preset 2.14",1,true)~=nil
 and stagedState:find("Preset 4.4",1,true)~=nil,
 "preset color overlay must affect value rows only, never Resolver or missing-stage diagnostics")
stagedRefs=functions.sourceMarkerEvidence({
 provenSources={classification="INCONCLUSIVE",
  provenActiveRefs={["Preset 2.1"]=position},
  selectedActiveRefs={["Preset 2.1"]=position}},
 markerReferences={["Preset 2.1"]=position},
 markerProbe={["Preset 2.1"]={poolTileFound=true,poolTileVisible=true,
  identityMatch=true,frameCreated=true}}
},position)
check(stagedRefs=="Preset 2.1 | RED_STATIC_FRAME",
 "source marker diagnosis must identify a selected source whose overlay attached")
stagedRefs=functions.sourceMarkerEvidence({
 provenSources={classification="INCONCLUSIVE",
  provenActiveRefs={["Preset 2.1"]=position},
  selectedActiveRefs={["Preset 2.1"]=position}},
 markerReferences={["Preset 2.1"]=position},
 markerProbe={["Preset 2.1"]={poolTileFound=false}}
},position)
check(stagedRefs=="Preset 2.1 | POOL_TILE_NOT_FOUND",
 "source marker diagnosis must identify a missing Pool tile after resolver admission")
stagedRefs=functions.sourceMarkerEvidence({
 provenSources={classification="INCONCLUSIVE",
  provenActiveRefs={["Preset 2.1"]=position},
  selectedActiveRefs={["Preset 2.1"]=position}},
 markerReferences={["Preset 2.1"]=position},
 markerProbe={["Preset 2.1"]={poolTileFound=true,poolTileVisible=false}}
},position)
check(stagedRefs=="Preset 2.1 | POOL_TILE_HIDDEN",
 "source marker diagnosis must distinguish a hidden Pool tile")
stagedRefs=functions.sourceMarkerEvidence({
 provenSources={classification="INCONCLUSIVE",
  provenActiveRefs={["Preset 2.1"]=position},
  selectedActiveRefs={["Preset 2.1"]=position}},
 markerReferences={["Preset 2.1"]=position},
 markerProbe={["Preset 2.1"]={poolTileFound=true,poolTileVisible=true,identityMatch=false}}
},position)
check(stagedRefs=="Preset 2.1 | POOL_IDENTITY_MISMATCH",
 "source marker diagnosis must distinguish Pool identity mismatch")
stagedRefs=functions.sourceMarkerEvidence({
 provenSources={classification="INCONCLUSIVE",provenActiveRefs={}},
 markerReferences={}},position)
check(stagedRefs=="Preset 2.1 | NOT_FINAL_ASSIGNMENT",
 "source marker diagnosis must distinguish refs excluded before Pool lookup")
stagedRefs=functions.sourceMarkerEvidence({
 provenSources={classification="PENDING",provenActiveRefs={}},markerReferences={}},position)
check(stagedRefs=="Preset 2.1 | RESOLVER_PENDING",
 "a pending Sequence must not mislabel a source reference as a final non-assignment")
stagedRefs=functions.sourceMarkerEvidence({
 provenSources={classification="INCONCLUSIVE",provenActiveRefs={},
  unsafeAttribution={unknown={{refId="Preset 2.1",ref=position}}}},
 markerReferences={}},position)
check(stagedRefs=="Preset 2.1 | ATTRIBUTION_UNKNOWN",
 "source marker diagnosis must expose unresolved lane attribution")
do
 (function()
  local old=recipe(gOne,moving,1)
  local newer=recipe(gOne,static,2)
  local seq,cue,part=tree({old,newer})
  local preview=state(seq,cue,fOne)
  preview.incrementalResolver=true; preview.optimisticMarkers=true
  local reads=referenceReads.count
  local channels=uiCalls
  local refs=functions.recipePoolReferences(preview)
  check(refs["Preset 1.2"]==moving and refs["Preset 1.1"]==static
   and preview.provenSources.reason=="CANDIDATE_PREVIEW"
   and referenceReads.count==reads and uiCalls==channels,
   "candidate preview must paint before metadata/member reads, including unverified killed history")
  check(preview.selectedRecipeReferenceCount==0 and next(preview.selectedRecipeReferenceKeys)==nil,
   "candidate purple must never create guessed selected red attribution")
  for i=1,100 do
   refs=functions.recipePoolReferences(preview)
   if preview.provenSources.classification~="PENDING" then break end
  end
  check(preview.provenSources.classification=="PROVEN"
   and refs["Preset 1.2"]==nil and refs["Preset 1.1"]==static,
   "background proof must remove killed candidate and retain winner")
  part.Children=function() return {} end
  preview.trackARecipeStructureKey="deleted"; preview.provenSourceKey=nil
  preview.trackAHistoryRowsCache=nil; preview.trackAStageSourcesCache=nil
  refs=functions.recipePoolReferences(preview)
  check(next(refs)==nil,
   "Recipe deletion must rebuild preview instead of retaining stale candidate")
  local seq2,cue2=tree({recipe(gOne,unknown,1)})
  preview=state(seq2,cue2,fOne)
  preview.incrementalResolver=true; preview.optimisticMarkers=true
  functions.recipePoolReferences(preview)
  for i=1,100 do
   refs=functions.recipePoolReferences(preview)
   if preview.provenSources.classification~="PENDING" then break end
  end
  check(preview.provenSources.classification=="INCONCLUSIVE"
   and refs[tostring(unknown)]==unknown,
   "unresolved attribution is not proof of a kill and must retain candidate")
  local mixedSeq,mixedCue=tree({recipe(gOne,moving,1),recipe(gOne,static,2),recipe(gCell,unsafe,3)})
  local mixed=state(mixedSeq,mixedCue,fBoth)
  mixed.incrementalResolver=true; mixed.optimisticMarkers=true
  functions.recipePoolReferences(mixed)
  for i=1,100 do
   refs=functions.recipePoolReferences(mixed)
   if mixed.provenSources.classification~="PENDING" then break end
  end
  check(mixed.provenSources.classification=="INCONCLUSIVE"
   and refs[tostring(moving)]==nil and refs[tostring(static)]==static
   and refs[tostring(unsafe)]==unsafe,
   "certain kill must remove purple even when another member remains unresolved")
  local shared=result({recipe(gBoth,moving,1),recipe(gOne,static,2)},fBoth)
  check(shared.refExclusionVerdicts[tostring(moving)]==false,
   "one surviving occurrence must prevent reference-wide exclusion")
  local blocked=result({recipe(gOne,moving,1),recipe(gOne,unsafe,2)},fOne)
  check(blocked.refExclusionVerdicts[tostring(moving)]==false,
   "unsafe newer barrier must not count as a certain kill")
  cue.No=1001
  preview.currentSequence=seq; preview.currentCue=cue
  refs=functions.recipePoolReferences(preview)
  check(next(refs)==nil,
   "switching Cue must drop the previous Cue candidate immediately")
 end)()
end
print("PASS: show Track A candidate ("..count.." checks), final_refs=4 missing=0 extra=0")
