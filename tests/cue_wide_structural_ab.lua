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
for _,k in ipairs({'Cmd','CmdIndirect','SetProgPhaser','SetProgPhaserValue','GetProgPhaser','HookObjectChange','Recall'}) do
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
env.CompareHandle=function(a,b) return a==b end
local mappedChannels
local function run()
 env.GetUIChannels=function(sf,handles) check(handles==false,'index mapping requested'); return type(mappedChannels)=='function' and mappedChannels(sf) or mappedChannels or {1} end
 return assert(loadfile('diagnostics/Cue_Wide_Structural_Resolver_AB_2_5_0_3.lua','t',env))()()
end
local function addRecipe(ref)
 recipe=append(part,object('StandardRecipe','Sequence 1 Cue 1 Part 0.1')); recipe.Index=1; recipe.Selection=group; recipe.Values=ref; recipe.Enabled='Yes'
 return recipe
end
local function size(t) local n=0; for _ in pairs(t) do n=n+1 end; return n end
local function has(s) return table.concat(logs,'\n'):find(s,1,true)~=nil end
local function phaser()
 preset.native='ShowData.DataPools.Default.PresetPools.Phaser.1'
 local p=append(preset,object('PhaserRecipe','Phaser Recipe')); local vs=append(p,object('PhaserRecipeValueSource','Value Source')); vs.Attributes='Dimmer'
end
setup(1); addRecipe(preset); local r=run()
check(#r.profiles.STRUCTURAL.reads==0,'B no cooked reads')
check(r.comparisons.HYBRID.classification=='HYBRID_EXACT_MATCH','ordinary moving Preset recovered in hybrid')
check(r.comparisons.STRUCTURAL.classification=='MISSING_REFERENCE','ordinary Preset not guessed structurally moving')
check(r.profiles.HYBRID.records==1 and r.profiles.BASELINE.records==1,'record counters')
check(has('source_part={class=Part') and has('ORACLE_LAYER'),'oracle source metadata')
check(has('NON_RECIPE_CHANNELS_AND_SCOPE_COMPLETENESS_UNKNOWN'),'no claim manual absence proven')
check(next(env.RecipeTrackingInspectorState.poolMarkers)==nil,'production state unchanged')
setup(1); phaser(); addRecipe(preset); r=run()
check(r.comparisons.STRUCTURAL.classification=='STRUCTURAL_EXACT_MATCH','direct Phaser matches oracle')
check(r.comparisons.HYBRID.classification=='HYBRID_EXACT_MATCH','Phaser sparse exact')
setup(1); local generatorPool=object('Generators','Generators'); local gen=append(generatorPool,object('Random','Generator 103'))
gen.RandomChannels=object('RandomChannels','RandomChannels'); local gc=append(gen.RandomChannels,object('RandomChannel','Channel')); gc.Attribute='Dimmer'
addRecipe(preset); recipe.Values=nil; recipe.Generator=gen; r=run()
check(r.comparisons.HYBRID.classification=='HYBRID_EXACT_MATCH' and has('reference_type=Generator'),'Generator recovery/identity set')
local duplicate=append(part,object('StandardRecipe','Duplicate Recipe')); duplicate.Index=2; duplicate.Selection=group; duplicate.Generator=gen; duplicate.Enabled='Yes'
r=run(); check(size(r.structural)==1 and size(r.hybrid)==1,'duplicate Generator rows deduplicate by identity')
setup(1); phaser(); addRecipe(preset)
local previous=cue; cue=append(seq,object('Cue','Sequence 1 Cue 2')); cue.No=2000
local later=append(cue,object('Part','Sequence 1 Cue 2 Part 0')); later.Part=0; data[later]={[1]={[1]={abs_release=true}}}
r=run()
check(r.comparisons.STRUCTURAL.classification=='EXTRA_REFERENCE','structural cannot infer release')
check(r.comparisons.HYBRID.classification=='HYBRID_EXACT_MATCH' and size(r.hybrid)==0,'hybrid follows later release')
check(r.profiles.HYBRID.parts==2,'later non-Recipe Part inspected for override')
data[later]={[1]={[1]={absolute=40}}}; r=run()
check(r.comparisons.HYBRID.classification=='HYBRID_EXACT_MATCH' and size(r.hybrid)==0,'static termination')
data[later]={}; r=run()
check(size(r.hybrid)==1 and r.comparisons.HYBRID.classification=='HYBRID_EXACT_MATCH','tracking-only empty Part retained')
setup(1); phaser(); addRecipe(preset); local oldPart=part
cue=append(seq,object('Cue','Sequence 1 Cue 2')); cue.No=2000; part=append(cue,object('Part','Sequence 1 Cue 2 Part 0')); part.Part=0
local rows={}; for i=1,4476 do rows[i]={[1]={absolute=50}} end; data[part]=rows
r=run()
check(r.profiles.BASELINE.records==4477 and r.profiles.BASELINE.advances==141,'large static baseline costs original advances')
check(r.profiles.HYBRID.records==2 and r.profiles.HYBRID.advances==2,'sparse handles same scope in two records, cadence unchanged')
check(r.comparisons.HYBRID.classification=='HYBRID_EXACT_MATCH','large static pruning still correct')
setup(1); addRecipe(preset); local other=append(pool,object('Preset','Preset 1.2')); other.Name='Same label'; preset.Name='Same label'
local priorRT=env.GetRTChannel; local outside=object('Subfixture','Fixture 2'); outside.SubfixtureIndex=2
env.GetRTChannel=function(i) if i==2 then return {fixture=outside,subfixture=outside} end; return priorRT(i) end
data[part][2]={abs_preset=other,[1]={absolute=5},[2]={absolute=10}}; r=run()
check(r.comparisons.HYBRID.classification=='MISSING_REFERENCE','manual reference outside Recipe scope exposes missing')
check(size(r.comparisons.HYBRID.missing)==1 and has('exact_handle={class=Preset command=Preset 1.2'),'exact missing DB identity')
env.GetRTChannel=priorRT
setup(1); phaser(); addRecipe(preset); group.Selection=nil; r=run()
check(r.hardBlocked and #r.profiles.HYBRID.reads==0,'unknown selection fails closed no full fallback')
check(r.comparisons.HYBRID.classification=='AMBIGUOUS_REQUIRES_FULL_COOKED','hard ambiguity explicit')
setup(1); addRecipe(preset); mappedChannels={}; r=run()
check(r.hardBlocked and #r.profiles.HYBRID.reads==0,'empty mapping not assumed complete'); mappedChannels=nil
setup(2050); addRecipe(preset); mappedChannels={}; for i=1,2050 do mappedChannels[i]=i end
r=run(); check(not r.hardBlocked and #r.profiles.HYBRID.reads==1,'2050 keys executes one native Part read');
check(#r.profiles.HYBRID.chunks==5 and r.profiles.HYBRID.lookups==2050,'2050 keys split into five bounded chunks')
check(r.profiles.HYBRID.parts==1 and r.profiles.HYBRID.cacheReuses==4,'chunk cache prevents native rereads')
check(r.comparisons.HYBRID.classification=='HYBRID_EXACT_MATCH','chunked sparse correctness'); mappedChannels=nil
setup(1); addRecipe(preset); readSeconds=.2; r=run()
check(near(r.profiles.HYBRID.nativeMs,200) and near(r.profiles.HYBRID.processingMs,0),'native timing split')
setup(1); addRecipe(preset); processingSeconds=.01; r=run()
check(r.profiles.HYBRID.processingMs>9.99,'other MA reads stay in processing residual')
setup(1); env.Time=false; addRecipe(preset); r=run()
check(r.profiles.HYBRID.timingInvalid and has('GetPresetData_ms=UNAVAILABLE'),'missing wall timer not fabricated')
setup(1); addRecipe(preset); data[part]='ERROR'; r=run()
check(r.comparisons.HYBRID.classification=='UNVERIFIED','failed oracle invalidates all equality claims')
setup(1); addRecipe(preset); preset.ToAddr=function() return nil end; r=run()
check(r.comparisons.HYBRID.classification=='UNVERIFIED','non-string oracle key invalid')
-- Native-shaped regression: 807 / 999 / 2049 current-Cue key scopes, seeded extra.
setup(1); phaser(); addRecipe(preset); group.Selection={{sf_index=11}}
local historicalRef=preset; local sourcePart=part
cue=append(seq,object('Cue','Sequence 1 Cue 8')); cue.No=8000
local currentParts={}; local refs={}; local groups={}
for i=1,3 do
 currentParts[i]=append(cue,object('Part','Sequence 1 Cue 8 Part '..(i-1))); currentParts[i].Part=i-1
 groups[i]=object('Group','Controlled Group '..i); groups[i].Selection={{sf_index=i+10}}
 data[currentParts[i]]={}
end
for i=1,4 do
 local ref=append(pool,object('Preset','Preset 25.'..(1000+i),'ShowData.DataPools.Default.PresetPools.Phaser.'..i)); ref.Name='Dimmer FX '..i
 refs[i]=ref; local pr=append(ref,object('PhaserRecipe','Recipe')); local vs=append(pr,object('PhaserRecipeValueSource','Value')); vs.Attributes='Dimmer'
 local pi=math.min(i,3); local rr=append(currentParts[pi],object('StandardRecipe','Controlled Recipe '..i)); rr.Index=i; rr.Enabled='Yes'; rr.Selection=groups[pi]; rr.Values=ref
end
for i=1,4476 do data[currentParts[1]][i]={[1]={absolute=50}} end
local ranges={[11]={1,807},[12]={808,999},[13]={1000,2049}}
mappedChannels=function(sf) local out={}; local range=ranges[sf]; for i=range[1],range[2] do out[#out+1]=i end; return out end
r=run(); local hp=r.profiles.HYBRID
check(r.comparisons.STRUCTURAL.classification=='EXTRA_REFERENCE' and size(r.structural)==5,'Structural behavior unchanged with one extra')
check(r.comparisons.HYBRID.classification=='HYBRID_EXACT_MATCH' and size(r.hybrid)==4,'seeded extra removed with positive cooked witness')
check(hp.executed and hp.resultValid and hp.parts==4,'3 current Parts plus explicit source witness only')
check(#hp.reads==4 and hp.lookups==4662 and #hp.chunks==11,'bounded native-shaped plan executes all chunks')
check(hp.units[#hp.units].last==2049 and #hp.units[#hp.units].keys==1,'2049th key processed, not truncated')
check(hp.records==808 and hp.reads[2].returned==4476,'returned full table separate from sparse processing')
local removed=0; for _,change in ipairs(hp.changes) do if change.action=='REMOVED' then removed=removed+1; check(change.ref==historicalRef and change.reasons.COOKED_STATIC_LAYER,'removal exact DB handle and reason') end end
check(removed==1 and has('CANDIDATE_CHANGE action=REMOVED'),'auditable removal rather than oracle copy')
check(hp.dataCache[sourcePart]==data[sourcePart] and data[sourcePart][1].abs_preset==historicalRef,'native returned table is read-only')
mappedChannels=nil
-- No source witness: never remove a candidate merely because current scope lacks it.
setup(0); phaser(); addRecipe(preset); local oldRef=preset
cue=append(seq,object('Cue','Sequence 1 Cue 2')); cue.No=2000
local emptyWitnessCurrent=append(cue,object('Part','Sequence 1 Cue 2 Part 0')); emptyWitnessCurrent.Part=0; data[emptyWitnessCurrent]={[1]={[1]={absolute=10}}}
r=run(); check(size(r.hybrid)==1 and r.comparisons.HYBRID.classification=='EXTRA_REFERENCE','unsupported seeded candidate retained, not guessed absent')
check(has('RETAINED_AMBIGUOUS'),'missing positive witness logged')
-- Relative witness survives an absolute-only static override.
setup(1); phaser(); addRecipe(preset)
data[part][1].rel_preset=preset; data[part][1][1].relative=1; data[part][1][2].relative=2
cue=append(seq,object('Cue','Sequence 1 Cue 2')); cue.No=2000
local absOnly=append(cue,object('Part','Sequence 1 Cue 2 Part 0')); absOnly.Part=0; data[absOnly]={[1]={[1]={absolute=10}}}
r=run(); check(size(r.hybrid)==1 and r.comparisons.HYBRID.classification=='HYBRID_EXACT_MATCH','relative tracking preserved')
-- Genuine safety limits still block, with no false zero-ref comparison.
setup(9000); addRecipe(preset); mappedChannels={}; for i=1,9000 do mappedChannels[i]=i end
r=run(); check(not r.profiles.HYBRID.executed and #r.profiles.HYBRID.reads==0,'per-Part safety bound retained')
check(not r.comparisons.HYBRID.candidateValid and has('missing=UNAVAILABLE'),'unexecuted Hybrid not evaluated as empty correctness result'); mappedChannels=nil
setup(1); env.BuildDetails=function() return {BigVersion='2.5.1.0'} end
check(not pcall(run),'version target strict')
check(forbidden==0,'no Show/Programmer/commands/UI mutation')
print('PASS: '..checks..' structural A/B assertions (mock only)')
