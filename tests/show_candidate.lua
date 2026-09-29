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

-- A large selection must complete its bounded native member pass in one
-- refresh instead of waiting one polling cycle per member.
local warmedHandles={}
local warmMembers,warmSelected={},{}
for i=1,40 do
 warmMembers[i]={key="m"..i,handle="m"..i}
 warmSelected[warmMembers[i].key]=warmMembers[i].handle
end
local warmTask={rows={},members=warmMembers,memberIndex=1,metadataIndex=1,runtime={
 memberUI=function(handle,cache) warmedHandles[#warmedHandles+1]=handle; cache[handle]={} end,
 run=function(_,selected)
  local refs={}; for key in pairs(selected) do refs["Preset "..key]=key end
  return {classification="PROVEN",refs=refs,sourceGroups={}}
 end},selectedMembers=warmSelected,targetFG=nil}
local warmState={referenceMetadataCache={},memberUICache={}}
local warmResult=provenApi.advanceStagedResolver(warmTask,warmState)
check(warmResult.classification=="PROVEN" and #warmedHandles==40
 and warmState.resolverMembersWarmed==40 and warmState.resolverMembersTotal==40
 and tableCount(warmResult.refs)==40,
 "the current selection must finish one bounded member pass without per-poll warmup delays")

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
local referenceData,referenceReads={},{count=0,part=0}
_G.GetPresetData=function(ref,selected,byFixtures)
 if ref:GetClass()=="Part" or ref:GetClass()=="Cue" then
  referenceReads.part=referenceReads.part+1
  error("production resolver must not read cooked Cue history")
 end
 check(selected==false and byFixtures==false,"reference metadata must request UI-channel shape without by-fixtures view")
 referenceReads.count=referenceReads.count+1
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
 "a selected fixture's active Phaser Group must pulse even when its lane differs from the selected Attribute")
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
local separate=result({recipe(gOne,relPhaser,1),recipe(gOne,static,2)},fOne)
check(separate.classification=="PROVEN" and separate.refs["Preset 25.C"]==relPhaser,
 "newer static ABS must not erase older moving REL")
local badLinked=preset("Preset 1.7",0,2,true)
local badSplit=phaser("Preset 25.D",attrs[0],10,20,0,0,badLinked)
local linkedFailure=result({recipe(gOne,badSplit,1)},fOne)
check(linkedFailure.classification=="INCONCLUSIVE",
 "linked moving Preset metadata must fail the static bridge gate")
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
functions.render(scanCacheState)
check(scanTrackingCalls==2,
 "Recipe reference relink must invalidate the structural tracking cache")
cacheRecipe.Values=cacheRecipeValues
swapUpvalue(functions.render,"scanTracking",scanTrackingOriginal)
swapUpvalue(functions.render,"readSelection",originalReadSelection)
swapUpvalue(functions.render,"readProgrammer",originalReadProgrammer)
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
local unrelated=object("Preset","Preset Unknown")
local unrelatedResult=result({recipe(gOne,unrelated,1),recipe(gCell,beam,2)},fBoth)
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
markerState.running=true; markerState.poolBlink=true
markerState.markerReferences=immediateRefs
check(markerState.poolMarkersDirty==true,
 "semantic recompute must request a marker refresh in the same loop")
check(markerState.markerReferences["Preset 25.9009"]==expected9009,
 "9009-style final ref must reach marker source")
check(markerState.markerProbe["Preset 25.9009"].sourceAdmitted==true,
 "final 9009-style ref must survive recipePoolReferences admission")
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
 and overlay.BackColor=="RecipeEditing.PhaserRecipe",
 "nested Recipe Pool tile must receive the native Phaser-color frame0 marker")
local blinkPhase=markerState.poolBlinkOn
functions.refreshPoolMarkers(markerState)
check(markerState.poolBlinkOn==blinkPhase,
 "pool pulse phase must not advance just because another fast refresh loop ran")
markerState.poolBlinkDeadline=functions.clockSeconds()-0.01
functions.refreshPoolMarkers(markerState)
check(markerState.poolBlinkOn~=blinkPhase
 and overlay.BackColor=="RecipeEditing.PhaserRecipe",
 "Cue Recipe source marker must stay steadily purple while Group markers pulse")
check(functions.poolPulseColor("group",true)=="Global.SuccessText"
 and functions.poolPulseColor("group",false)=="Global.Selected",
 "Stored Group marker pulse must preserve its existing theme colors")
check(functions.poolPulseColor("recipe",true)=="RecipeEditing.PhaserRecipe"
 and functions.poolPulseColor("recipe",false)=="RecipeEditing.PhaserRecipe",
 "Cue Recipe source marker must remain purple in both Group pulse phases")
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
  and markerState.poolMarkers[button]~=nil,
  "clearing fixture selection must stop Group pulses but preserve purple refs tracked by the valid Sequence/Cue")
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
print("PASS: show Track A candidate ("..count.." checks), final_refs=4 missing=0 extra=0")
