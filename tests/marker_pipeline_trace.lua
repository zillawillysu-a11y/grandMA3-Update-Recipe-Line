-- Offline tests only; no native connection.
local checks,logs,forbidden,uiErrors=0,{},0,0
local function check(v,m) assert(v,m); checks=checks+1 end
local function obj(k,a,n)
 local h={kind=k,addr=a,native=n or 'Native.'..a,contents={}}
 h.GetClass=function(s) return s.kind end
 h.ToAddr=function(s) return s.addr end
 h.AddrNative=function(s) return s.native end
 h.Get=function(s,key) return rawget(s,key) or rawget(s,key:sub(1,1)..key:sub(2):lower()) end
 h.Parent=function(s) return s.parent end
 h.Children=function(s) return s.contents end
 h.Ptr=function(s,i) return s.targets and s.targets[i] end
 h.Append=function() forbidden=forbidden+1; error('UI write') end
 return h
end
local function append(p,h) p.contents[#p.contents+1]=h; h.parent=p; return h end
local uiKinds={Display=true,AllPoolLayoutGrid=true,AllPoolButton=true,OtherWidget=true,UIObject=true}
local function uiObj(k,a)
 local h=obj(k,a); h.Visible=true
 h.UIChildren=function(s) if not uiKinds[s.kind] then uiErrors=uiErrors+1; error('DB UI traversal') end; return s.contents end
 h.IsVisible=function(s) if not uiKinds[s.kind] then uiErrors=uiErrors+1; error('DB visibility') end; return s.Visible end
 return h
end
local env=setmetatable({}, {__index=_G}); env._G=env
local state,root,group,preset,recipe,cue,part,seq,presetPool,groupPool,presetGrid,groupGrid,presetButton,groupButton
local function controlFailure() forbidden=forbidden+1; error('forbidden native API') end
for _,k in ipairs({'Cmd','CmdIndirect','GetPresetData','GetPresetDataFast','CompareHandle','HookObjectChange','SetProgPhaser','SetProgPhaserValue'}) do env[k]=controlFailure end
env.BuildDetails=function() return {BigVersion='2.5.0.3'} end
env.IsObjectValid=function(h) return type(h)=='table' and h.kind~=nil and h.valid~=false end
env.HandleToStr=function(h) return tostring(h) end
env.IsClassDerivedFrom=function(k,b) return b=='UIObject' and uiKinds[k]==true end
env.GetDisplayByIndex=function(i) if i==1 then return root end end
env.Printf=function(f,...) logs[#logs+1]=string.format(f,...) end
env.ObjectList=function(address) if address=='Preset 4.1' then return {preset} end; return {} end
local run=assert(loadfile('diagnostics/Marker_Pipeline_Trace_2_5_0_3.lua','t',env))()
local function setup()
 logs={}; root=uiObj('Display','Display 1')
 seq=obj('Sequence','Sequence 1'); cue=append(seq,obj('Cue','Sequence 1 Cue 1')); cue.No=1000
 part=append(cue,obj('Part','Sequence 1 Cue 1 Part 0')); part.Part=0
 groupPool=obj('Groups','Groups'); group=append(groupPool,obj('Group','Group 1')); group.Index=1
 presetPool=obj('Presets','PresetPool 4'); preset=append(presetPool,obj('Preset','Preset 4.1','ShowData.DataPools.Default.PresetPools.Color.1')); preset.Index=1
 recipe=append(part,obj('StandardRecipe','Sequence 1 Cue 1 Part 0.1')); recipe.Index=1; recipe.Selection=group; recipe.Values=preset; recipe.Enabled='Yes'
 presetGrid=append(root,uiObj('AllPoolLayoutGrid','Display 1.1')); presetGrid.PoolObject=presetPool; presetGrid.Pooltype='Presets'; presetPool.targets={[1]=preset}
 groupGrid=append(root,uiObj('AllPoolLayoutGrid','Display 1.2')); groupGrid.PoolObject=groupPool; groupGrid.Pooltype='Groups'; groupPool.targets={[1]=group}
 presetButton=append(presetGrid,uiObj('AllPoolButton','Display 1.1.1')); presetButton.ObjectIndex=1
 groupButton=append(groupGrid,uiObj('AllPoolButton','Display 1.2.1')); groupButton.ObjectIndex=1
 state={version='0.7.0.17',running=true,currentGroup=group,currentRecipe=recipe,currentSequence=seq,currentCue=cue,currentSourceCue=cue,currentPart=part,poolGrids={presetGrid,groupGrid},poolMarkers={},matchingCandidates={},groupPoolReferences={}}
 env.RecipeTrackingInspectorState=state
end
local function referenceResults(result,object)
 local out={}; for _,r in ipairs(result.records or {}) do if r.record.object==object then out[#out+1]=r end end; return out
end
local function classified(result,object,wanted)
 local refs=referenceResults(result,object); for _,r in ipairs(refs) do if r.classification==wanted then return true end end; return false
end
setup(); local result=run()
check(classified(result,preset,'MARKER_PATH_COMPLETE'),'Preset path complete')
check(classified(result,group,'MARKER_PATH_COMPLETE'),'Group path complete')
check(table.concat(logs,'\n'):find('CONDITIONAL_APPEND_AND_CONFIGURATION_NOT_EXECUTED',1,true),'creation must stay conditional')
check(state.groupPoolReferenceKey==nil and state.poolGridRefreshNeeded==nil and next(state.groupPoolReferences)==nil,'source cache snapshot mutated')
check(#state.poolGrids==2 and next(state.poolMarkers)==nil,'grid/marker state mutated')
setup(); recipe.Values='Preset 4.1'; result=run()
check(classified(result,preset,'MARKER_PATH_COMPLETE'),'raw address resolution faithful')
setup(); recipe.Values='Preset 4.999'; result=run()
local unresolved=false; for _,r in ipairs(result.records) do if r.record.field=='Values' and r.classification=='SOURCE_RESOLUTION_MISS' then unresolved=true end end
check(unresolved,'unresolved expected address SOURCE_RESOLUTION_MISS')
setup(); preset.ToAddr=function() return nil end; result=run()
check(classified(result,preset,'MARKER_DECISION_REJECTED'),'missing command key cannot be silently accepted')
setup(); root.contents={groupGrid}; state.poolGrids={groupGrid}; result=run()
check(classified(result,preset,'POOL_DISCOVERY_MISS'),'missing visible source pool')
setup(); presetPool.targets[1]=obj('Preset','Preset 4.2','ShowData.DataPools.Default.PresetPools.Color.2'); result=run()
check(classified(result,preset,'TILE_MATCH_MISS'),'wrong target tile')
setup(); presetPool.targets={}; result=run()
check(classified(result,preset,'TILE_MATCH_MISS'),'unresolved PoolObject Ptr target')
check(table.concat(logs,'\n'):find('PoolObject_Ptr_ObjectIndex_unresolved',1,true),'Ptr failure reason')
setup(); presetButton.kind='OtherWidget'; result=run()
check(classified(result,preset,'MARKER_DECISION_REJECTED'),'production button class gate')
check(table.concat(logs,'\n'):find('scanGrid:isPoolItemButton_false',1,true),'class gate reason')
setup(); presetGrid.Visible=false; result=run()
check(classified(result,preset,'POOL_DISCOVERY_MISS'),'hidden accepted grid not visible path proof')
setup(); presetButton.Visible=false; result=run()
check(classified(result,preset,'UNVERIFIED'),'hidden matched button cannot be production rejection')
setup(); state.running=false; result=run()
check(classified(result,preset,'MARKER_DECISION_REJECTED'),'production running gate')
setup(); state.poolBlink=false; result=run()
check(classified(result,preset,'MARKER_DECISION_REJECTED'),'production poolBlink gate')
setup(); state.currentRecipe=nil; state.matchingCandidates={}; state.groupPoolReferenceKey='Sequence 1:1000:Group 1'; state.groupPoolReferences={}; result=run()
check(classified(result,preset,'SOURCE_RESOLUTION_MISS'),'retained cache key suppresses fresh expected source')
check(state.groupPoolReferenceKey=='Sequence 1:1000:Group 1' and next(state.groupPoolReferences)==nil,'warm cache unchanged')
setup(); local previous=cue; previous.No=1000; cue=append(seq,obj('Cue','Sequence 1 Cue 2')); cue.No=2000; state.currentCue=cue; state.currentSourceCue=previous; result=run()
check(classified(result,preset,'MARKER_PATH_COMPLETE'),'earlier structural recipe reference traced')
check(table.concat(logs,'\n'):find('EARLIER_RECIPE_STRUCTURAL_TRACKING',1,true),'tracking metadata not playback claim')
setup(); recipe.Enabled='No'; state.currentRecipe=nil; state.matchingCandidates={}; result=run()
check(classified(result,preset,'MARKER_DECISION_REJECTED'),'disabled scoped Recipe rejected')
setup(); recipe.Enabled='No'; result=run()
check(classified(result,preset,'MARKER_PATH_COMPLETE'),'currentRecipe branch has no Enabled gate; retain actual behavior')
setup(); local genPool=obj('Generators','Generators'); local gen=append(genPool,obj('Random','Generator 103','ShowData.DataPools.Default.GeneratorTypes.Generators.103')); gen.Index=103
local channels=obj('RandomChannels','Channels'); local ch=append(channels,obj('RandomChannel','Channel')); ch.Attribute='Color'; gen.RandomChannels=channels
recipe.Generator=gen; recipe.Values=nil
local grid=append(root,uiObj('AllPoolLayoutGrid','Display 1.3')); grid.PoolObject=genPool; grid.Pooltype='GeneratorRandom'; genPool.targets={[103]=gen}
local button=append(grid,uiObj('AllPoolButton','Display 1.3.1')); button.ObjectIndex=103; result=run()
check(classified(result,gen,'MARKER_PATH_COMPLETE'),'Generator path generic target extraction')
check(table.concat(logs,'\n'):find('reference_type=Generator',1,true),'Generator source log')
setup(); preset.native='ShowData.DataPools.Default.PresetPools.Phaser.1'; local pr=append(preset,obj('PhaserRecipe','Phaser Recipe')); local vs=append(pr,obj('PhaserRecipeValueSource','Value Source')); vs.Attributes='Color'; result=run()
check(classified(result,preset,'MARKER_PATH_COMPLETE'),'Phaser reference path')
check(table.concat(logs,'\n'):find('reference_type=Phaser',1,true),'Phaser source log')
setup(); local overlay=uiObj('UIObject','Existing overlay'); state.poolMarkers[presetButton]={overlay=overlay}; result=run()
check(table.concat(logs,'\n'):find('REUSE_VALID_MARKER_ENTRY',1,true),'existing entry read only')
check(state.poolMarkers[presetButton].overlay==overlay,'existing marker untouched')
setup(); recipe.Values='Generator display label'; result=run()
local metadataSafe=false; for _,r in ipairs(result.records) do if r.record.field=='Values' and r.record.raw=='Generator display label' and r.classification=='UNVERIFIED' then metadataSafe=true end end
check(metadataSafe,'display text must not be invented as a missing reference')
setup(); presetPool.targets[1]=obj('Preset','Preset 4.1',preset.native); result=run()
check(classified(result,preset,'UNVERIFIED'),'textual equal addresses do not prove DB handle identity')
setup(); state.currentRecipe=nil; state.matchingCandidates={}; recipe.Values=preset
local earlier=cue; earlier.No=1000; local newer=append(seq,obj('Cue','Sequence 1 Cue 2')); newer.No=2000
local newerPart=append(newer,obj('Part','Sequence 1 Cue 2 Part 0')); newerPart.Part=0
local override=append(newerPart,obj('StandardRecipe','Sequence 1 Cue 2 Part 0.1')); override.Index=1; override.Selection=group; override.Values=obj('Preset','Preset 4.2','ShowData.DataPools.Default.PresetPools.Color.2'); override.Enabled='Yes'; state.currentCue=newer
result=run(); check(classified(result,preset,'MARKER_DECISION_REJECTED'),'earlier same feature lane override')
setup(); state.poolGrids={presetGrid,groupGrid}; state.groupPoolReferenceKey='Sequence 1:1000:Group 1'; state.groupPoolReferences={['Preset 4.1']=preset}; result=run()
check(table.concat(logs,'\n'):find('POOL_SET branch=REUSE_CACHE',1,true),'warm grid discovery branch retained')
setup(); for i=2,164 do local rec=append(part,obj('StandardRecipe','Recipe '..i)); rec.Index=i; rec.Selection=group; rec.Values=preset; rec.Enabled='Yes' end
result=run(); check(result.classification=='PER_REFERENCE','optional rejected row samples must not exhaust active source records')
setup(); preset.valid=false; result=run(); check(classified(result,preset,'SOURCE_RESOLUTION_MISS'),'invalid source handle must not be path complete')
setup(); state.currentSourceCue=obj('Cue','Unknown cue number'); result=run(); local unknownStatus=false
for _,r in ipairs(result.records) do if r.record.origin=='CURRENT_RECIPE' and r.record.ctx.direct=='UNKNOWN' then unknownStatus=true end end
check(unknownStatus,'unreadable source cue number is not invented as tracked')
setup(); env.RecipeTrackingInspectorState=nil; result=run(); check(result.classification=='UNVERIFIED','missing selected group snapshot')
setup(); state.version='unknown'; result=run(); check(result.classification=='UNVERIFIED','production version mismatch')
setup(); env.BuildDetails=function() return {BigVersion='2.5.1.0'} end; check(not pcall(run),'native target locked')
check(forbidden==0 and uiErrors==0,'no UI writes/cooked/CompareHandle or non-UI calls')
print('PASS: '..checks..' Marker Pipeline Trace assertions (MOCK ONLY)')
