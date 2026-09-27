-- Independent mock only. No MA connection, no mutation APIs available.
local checks=0
local function check(v,m) assert(v,m); checks=checks+1 end
local function near(a,b) return math.abs(a-b)<0.0001 end
local function object(k,a,n)
 local h={kind=k,addr=a,native=n or 'Native.'..a,contents={},valid=true}
 h.GetClass=function(s) return s.kind end
 h.ToAddr=function(s) return s.addr end
 h.AddrNative=function(s) return s.native end
 h.Get=function(s,key) return rawget(s,key) end
 h.Children=function(s) return s.contents end
 h.Parent=function(s) return s.parent end
 h.Ptr=function(s,i) return s.targets and s.targets[i] end
 return h
end
local function append(p,h) p.contents[#p.contents+1]=h; h.parent=p; return h end
local uiKinds={Display=true,AllPoolLayoutGrid=true,AllPoolButton=true}
local function widget(k,a)
 local h=object(k,a); h.Visible=true
 h.UIChildren=function(s) assert(uiKinds[s.kind],'UI API on DB object'); return s.contents end
 h.IsVisible=function(s) assert(uiKinds[s.kind]); return s.Visible end
 return h
end
local env=setmetatable({}, {__index=_G}); env._G=env
local logs,clock,calls,seq,cue,part,preset,pool,grid,root,fixture,attribute,group,recipe,data,readSeconds,processingSeconds
local forbidden=0
for _,k in ipairs({'Cmd','CmdIndirect','SetProgPhaser','SetProgPhaserValue','GetProgPhaser','CompareHandle','HookObjectChange','Recall'}) do
 env[k]=function() forbidden=forbidden+1; error('forbidden '..k) end
end
env.BuildDetails=function() return {BigVersion='2.5.0.3'} end
env.IsObjectValid=function(h) return type(h)=='table' and h.kind~=nil and h.valid end
env.HandleToStr=function(h) return tostring(h) end
env.IsClassDerivedFrom=function(k,b) return b=='UIObject' and uiKinds[k]==true end
env.GetDisplayByIndex=function(i) if i==1 then return root end end
env.SelectedSequence=function() return seq end
env.GetCurrentCue=function() return cue end
env.GetUIChannel=function(i) clock=clock+processingSeconds; return {rt_index=i} end
env.GetRTChannel=function() return {fixture=fixture,subfixture=fixture} end
env.GetAttributeByUIChannel=function() return attribute end
env.ObjectList=function(a) if a==preset.addr then return {preset} end; return {} end
env.Printf=function(f,...) logs[#logs+1]=string.format(f,...) end
env.ErrEcho=function(m) logs[#logs+1]='ERROR '..m end
env.GetPresetData=function(target,phasers,byFixture)
 check(byFixture==false,'by-fixtures flag must stay false')
 calls[#calls+1]={target=target,phasers=phasers}; clock=clock+readSeconds
 local result=data[target]; if result=='ERROR' then error('native read failure') end
 return result
end
local function setup(n)
 logs={}; clock=10; calls={}; readSeconds=.001; processingSeconds=0
 env.Time=function() return clock end
 seq=object('Sequence','Sequence 1'); cue=append(seq,object('Cue','Sequence 1 Cue 1')); cue.No=1000
 part=append(cue,object('Part','Sequence 1 Cue 1 Part 0')); part.Part=0
 pool=object('Presets','PresetPool 1'); preset=append(pool,object('Preset','Preset 1.1','ShowData.DataPools.Default.PresetPools.Dimmer.1'))
 fixture=object('Subfixture','Fixture 1'); fixture.SubfixtureIndex=1
 attribute=object('Attribute','Attribute Dimmer'); attribute.Name='Dimmer'
 local groupPool=object('Groups','Groups'); group=append(groupPool,object('Group','Group 1')); group.Selection={{sf_index=1}}
 root=widget('Display','Display 1'); grid=append(root,widget('AllPoolLayoutGrid','Display 1.1')); grid.PoolObject=pool; pool.targets={[1]=preset}
 local button=append(grid,widget('AllPoolButton','Display 1.1.1')); button.ObjectIndex=1
 data={[part]={}}
 for i=1,n or 1 do data[part][i]={abs_preset=preset,[1]={absolute=10},[2]={absolute=20}} end
 env.RecipeTrackingInspectorState={poolGrids={grid},poolMarkers={}}
 recipe=nil
end
local function run()
 return assert(loadfile('diagnostics/Cue_Wide_Trace_Timing_2_5_0_3.lua','t',env))()()
end
local function has(s) return table.concat(logs,'\n'):find(s,1,true)~=nil end
local function addRecipe(ref)
 recipe=append(part,object('StandardRecipe','Sequence 1 Cue 1 Part 0.1')); recipe.Index=1; recipe.Selection=group; recipe.Values=ref; recipe.Enabled='Yes'
 return recipe
end
setup(1); local r=run(); local p=r.passes[1]
check(p.functional=='CUE_WIDE_REFERENCE_PATH_COMPLETE','baseline complete')
check(#p.reads==1 and #p.advances==1 and p.advances[1].records==1,'one cooked read, one advance')
check(near(p.nativeMs,1) and near(p.waitMs,100) and near(p.processingMs,0),'native/wait separation')
check(p.matched==1 and r.cache_reads==0,'tile matched, actual result-cache hit has no reads')
check(p.reads[1].count==1 and p.reads[1].first and not r.passes[2].reads[1].first,'cold/warm counts')
check(env.RecipeTrackingInspectorState.poolMarkers and next(env.RecipeTrackingInspectorState.poolMarkers)==nil,'no markers or production mutation')
check(has('first_publish_stage=FINAL_COOKED_OR_DIRECT_MERGE'),'cooked availability distinct from progressive')
setup(32); r=run(); p=r.passes[1]
check(#p.advances==2 and p.advances[1].records==32 and p.advances[2].records==0,'exact batch requires EOF advance')
check(#p.reads==1 and near(p.waitMs,200),'no native reread per batch')
setup(64); r=run(); p=r.passes[1]
check(#p.advances==3 and near(p.waitMs,300),'64 rows require three advances')
check(p.performance=='CUE_WIDE_PERFORMANCE_BOTTLENECK_BATCH_WAIT','batch wait dominant')
setup(1); readSeconds=.5; r=run(); p=r.passes[1]
check(p.performance=='CUE_WIDE_PERFORMANCE_BOTTLENECK_NATIVE_READ' and near(p.nativeMs,500),'native bottleneck')
setup(1); processingSeconds=1; r=run(); p=r.passes[1]
check(p.performance=='CUE_WIDE_PERFORMANCE_BOTTLENECK_PROCESSING' and near(p.processingMs,1000),'processing includes other read APIs')
setup(1); local previous=cue; cue=append(seq,object('Cue','Sequence 1 Cue 2')); cue.No=2000
local empty=append(cue,object('Part','Sequence 1 Cue 2 Part 0')); empty.Part=0; data[empty]={}; r=run(); p=r.passes[1]
check(p.result['Preset 1.1']~=nil and #p.order==2,'untouched tracking retained')
check(p.reads[1].count==1 and p.reads[2].count==0,'per-Part count mapped to actual order')
check(has('origin=TRACKED_HISTORY_CANDIDATE') and has('survives_cooked_origin=true'),'history provenance')
data[empty]={[1]={abs_preset=preset,[1]={absolute=80}}}; r=run()
check(next(r.passes[1].result)==nil,'static override terminates absolute moving layer')
data[empty]={[1]={[1]={abs_release=true}}}; r=run()
check(next(r.passes[1].result)==nil,'release terminates layer')
data[part][1].rel_preset=preset; data[part][1][1].relative=10; data[part][1][2].relative=20
r=run(); check(r.passes[1].result['Preset 1.1']~=nil,'relative independent from released absolute')
setup(1); addRecipe(preset); r=run(); p=r.passes[1]
check(has('RECIPE_RECOVERY') and p.finalOrigins[preset][part],'enabled Recipe exact fixture feature recovery')
recipe.Enabled='No'; r=run(); check(r.passes[1].result['Preset 1.1']~=nil,'disabled Recipe does not remove direct cooked reference')
setup(0); preset.native='ShowData.DataPools.Default.PresetPools.Phaser.1'
local ph=append(preset,object('PhaserRecipe','Phaser Recipe')); local value=append(ph,object('PhaserRecipeValueSource','Value Source')); value.Attributes='Dimmer'
addRecipe(preset); r=run(); p=r.passes[1]
check(p.result['Preset 1.1']~=nil and p.publications[preset].tick==0,'direct Phaser merges despite empty cooked data')
check(has('reference_type=Phaser') and has('direct_merge_preserves_refs_even_when_absent_from_cooked=true'),'direct structural merge explicitly labelled')
setup(0); local gp=object('Generators','Generators'); local gen=append(gp,object('Random','Generator 103')); gen.RandomChannels=object('RandomChannels','RandomChannels')
local channel=append(gen.RandomChannels,object('RandomChannel','Channel')); channel.Attribute='Dimmer'; addRecipe(gen)
r=run(); check(r.passes[1].result['Generator 103']~=nil and has('reference_type=Generator'),'Generator direct reference')
setup(1); preset.addr='Preset 9.1'; preset.native='ShowData.DataPools.Default.PresetPools.Unnamed.1'; addRecipe(preset); data[preset]={[1]={}}
r=run(); local featureReads=0; for _,read in ipairs(r.passes[1].reads) do if read.kind=='FEATURE_REFERENCE' then featureReads=featureReads+1; check(read.count==1,'feature read count') end end
check(featureReads>0 and has('kind=FEATURE_REFERENCE'),'supplementary native feature reads counted separately')
setup(1); data[part][1].abs_preset='Preset 1.1'; r=run()
check(r.passes[1].functional=='CUE_WIDE_SOURCE_MISS','raw address string ignored by exact scanner is exposed')
setup(1); data[part][1].abs_preset=nil; r=run()
check(r.passes[1].functional=='CUE_WIDE_REFERENCE_PATH_COMPLETE','anonymous raw moving phaser is not invented Pool reference')
setup(1); preset.ToAddr=function() return nil end; r=run()
check(r.passes[1].functional=='CUE_WIDE_SOURCE_MISS' and has('ADDRESS_MEMO_SENTINEL'),'preserve and disclose non-string memo sentinel behavior')
setup(1); data[part]='ERROR'; r=run()
check(r.passes[1].functional=='CUE_WIDE_SOURCE_MISS' and r.passes[1].performance=='UNVERIFIED','native read error does not establish latency')
setup(1); env.Time=false; r=run()
check(r.passes[1].performance=='UNVERIFIED' and has('total_native_GetPresetData_ms=UNAVAILABLE'),'no fake wall-clock timing')
setup(1); root.contents={}; env.RecipeTrackingInspectorState.poolGrids={}; r=run()
check(r.passes[1].functional=='CUE_WIDE_TILE_MISS' and r.passes[1].noPool==1,'no visible pool distinguished')
setup(1); pool.targets={}; r=run()
check(r.passes[1].functional=='CUE_WIDE_TILE_MISS' and r.passes[1].noTile==1,'pool found, target missing distinguished')
setup(1); grid.Visible=nil; r=run()
check(r.passes[1].functional=='UNVERIFIED','unknown visibility cannot prove tile miss')
setup(1); local later=append(seq,object('Cue','Sequence 1 Cue 3')); later.No=3000
local original=env.GetPresetData; local didChange=false
env.GetPresetData=function(...) if not didChange then cue=later; didChange=true end; return original(...) end
r=run(); check(not r.contextStable and r.passes[1].functional=='UNVERIFIED','changing context invalidates conclusion')
env.GetPresetData=original
setup(1); env.BuildDetails=function() return {BigVersion='2.5.1.0'} end
check(not pcall(run),'strict target version')
check(forbidden==0,'no commands, Programmer access, mutation, hooks or CompareHandle')
print('PASS: '..checks..' Cue-wide trace mock assertions')
