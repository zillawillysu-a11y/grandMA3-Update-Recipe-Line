local function obj(kind,addr)
 local h={kind=kind,addr=addr,contents={},props={}}
 function h:GetClass() return self.kind end
 function h:ToAddr() return self.addr end
 function h:AddrNative() return 'Native.'..self.addr end
 function h:Get(k) return self[k] end
 function h:Children() return self.contents end
 function h:Parent() return self.parent end
 function h:PropertyCount() return #self.props end
 function h:PropertyName(i) return self.props[i+1] end
 return setmetatable(h,{__tostring=function(s) return s.addr end})
end
local function add(p,h) p.contents[#p.contents+1]=h; h.parent=p; return h end
local env=setmetatable({}, {__index=_G}); env._G=env
local seq,cue,data,logs,calls,clock
local forbidden=0
for _,key in ipairs({'Cmd','CmdIndirect','GetUIChannels','SetProgPhaser','GetProgPhaser','HookObjectChange','GetDisplayByIndex'}) do env[key]=function() forbidden=forbidden+1; error('Forbidden '..key) end end
env.IsObjectValid=function(h) return type(h)=='table' and h.kind~=nil end
env.HandleToStr=function(h) return h.addr end
env.CompareHandle=function(a,b) return a==b end
env.BuildDetails=function() return {BigVersion='2.5.0.3'} end
env.SelectedSequence=function() return seq end
env.GetCurrentCue=function() return cue end
env.Time=function() clock=clock+.00001; return clock end
env.Printf=function(f,...)
 assert(f=='%s','Native Printf must receive one preformatted string')
 for _,v in ipairs({...}) do assert(type(v)=='string','Native Printf rejects numeric varargs') end
 logs[#logs+1]=string.format(f,...)
end
env.GetPresetData=function(target,p,f)
 assert(table.concat(logs,'\n'):find('FAST_FINALIZED',1,true),'Oracle ran before fast finalization')
 calls=calls+1; return data[target] or {}
end
env.GetUIChannel=function(i) return {rt_index=i} end
local fixture=obj('Subfixture','Fixture 1'); fixture.SubfixtureIndex=1
env.GetRTChannel=function() return {fixture=fixture,subfixture=fixture} end
env.GetAttributeByUIChannel=function() local a=obj('Attribute','Attribute Dimmer'); a.Name='Dimmer'; return a end
local registry={}
env.ObjectList=function(s) return registry[s] and {registry[s]} or {} end
local checks=0
local function check(v,m) assert(v,m); checks=checks+1 end
local function setup()
 seq=obj('Sequence','Sequence 7'); cue=add(seq,obj('Cue','Sequence 7 Cue 1')); cue.No=1000
 logs={}; data={}; calls=0; clock=10
 registry={}
 return add(cue,obj('Part','Sequence 7 Cue 1 Part 0'))
end
local function group(no,members)
 local g=obj('Group','Group '..no); g.Selection={}
 for _,sf in ipairs(members) do g.Selection[#g.Selection+1]={sf_index=sf} end
 return g
end
local function phaser(no,layer,feature,steps)
 local p=obj('Preset','Preset 25.'..no)
 local recipe=add(p,obj('PhaserRecipe','Phaser '..no))
 local fg=registry['FeatureGroup '..(feature or 'Dimmer')]
 if not fg then fg=obj('FeatureGroup','FeatureGroup '..(feature or 'Dimmer')); registry[fg.addr]=fg end
 local f=add(fg,obj('Feature','Feature '..(feature or 'Dimmer')))
 local attr=obj('Attribute','Attribute '..no); attr.Feature=f
 registry[attr.addr]=attr
 for i=1,steps or 2 do
  local s=add(recipe,obj('PhaserRecipeStep','Step '..no..'.'..i))
  local vs=add(s,obj('PhaserRecipeValueSource','Source '..no..'.'..i))
  vs.props={'Attributes','RawValueAbs','RawValueRel','ValueAbsolute','ValueRelative','Layer'}
  vs.Attributes=feature=='UnknownAttribute' and feature or attr; vs.Layer=layer
  if layer=='Absolute' then vs.RawValueAbs=i==1 and 100 or 0; vs.RawValueRel=''; vs.ValueAbsolute=vs.RawValueAbs
  elseif layer=='Relative' then vs.RawValueRel=i==1 and 10 or -10; vs.RawValueAbs=''; vs.ValueRelative=vs.RawValueRel end
 end
 return p
end
local function row(part,g,ref,no)
 local r=add(part,obj('StandardRecipe',part.addr..'.'..(no or 1)))
 r.Index=no or 1; r.Selection=g; r.Values=ref; r.Enabled='Yes'; return r
end
local function run() return assert(loadfile('diagnostics/Cue_Wide_Recipe_Reverse_Resolver_AB_2_5_0_3.lua','t',env))()() end
local function has(s) return table.concat(logs,'\n'):find(s,1,true)~=nil end
local p=setup(); local g=group(1,{1}); local a=phaser(91,'Absolute'); row(p,g,a)
cue.Name='Native 50% Cue'
data[p]={[1]={abs_preset=a,[1]={absolute=10},[2]={absolute=20}}}
local r=run()
check(r.fastCalls==0 and r.oracleCalls>0,'zero fast calls')
check(r.classifications.RECIPE_REVERSE_EXACT_MATCH and next(r.final),'independent exact match')
check(r.stats.groups==1 and r.stats.expansions==1,'group metrics')
check(has('SOURCE') and has('surviving_member_count=1'),'trace')
check(has('50% Cue'),'literal percent text survives copied oracle logging')
-- New static row in overlapping Group terminates one subfixture only.
p=setup(); a=phaser(92,'Absolute'); row(p,group(2,{1,2}),a)
local prev=cue; cue=add(seq,obj('Cue','Sequence 7 Cue 2')); cue.No=2000
local p2=add(cue,obj('Part','Sequence 7 Cue 2 Part 0'))
local static=phaser(93,'Absolute','Dimmer',1); row(p2,group(3,{2}),static)
r=run(); local active=next(r.fast.refs) and select(2,next(r.fast.refs))
check(active and active.members[1] and not active.members[2],'subfixture overlap static termination')
check(r.fast.staticRows==1 and has('FIRST_NEWER member=2'),'static and superseder trace')
check(r.stats.parts==2 and r.stats.rows==2,'all history metrics')
-- Unknown layer blocks older same-member assertions; no cooked assistance.
p=setup(); a=phaser(94,nil); row(p,g,a); r=run()
check(next(r.final)==nil and r.classifications.FAST_PATH_UNSAFE_LAYER,'no absolute default')
check(has('UNRESOLVED Recipe=') and has('member_count=1 member_sample=1') and r.fastCalls==0,'aggregated unsafe member trace')
-- User object names never supply missing feature scope.
p=setup(); a=phaser(95,'Absolute','UnknownAttribute'); a.Name='Dimmer Strobe Speed'; row(p,g,a); r=run()
check(r.classifications.FAST_PATH_UNSAFE_FEATURE_SCOPE and next(r.final)==nil,'no name guessing')
-- Opaque ordinary preset is not guessed static; oracle cannot repair fast set.
p=setup(); a=obj('Preset','Preset 1.17'); row(p,g,a)
data[p]={[1]={abs_preset=a,[1]={absolute=10},[2]={absolute=20}}}
r=run(); check(r.classifications.UNVERIFIED and r.classifications.RECIPE_REVERSE_MISSING_REFERENCE,'opaque moving ordinary preset')
check(next(r.final)==nil and has('DIFF_SOURCE'),'final immutable and mismatch attribution')
-- An advertised Recipe Layer has no verified semantics in this native class.
p=setup(); a=phaser(96,nil); local rr=row(p,g,a); rr.props={'Layer'}; rr.Layer='Relative'; r=run()
check(next(r.final)==nil and r.classifications.FAST_PATH_UNSAFE_LAYER,'Recipe Layer is audit-only until proven')
-- Disabled rows are inspected but cannot block/resolve members.
p=setup(); a=phaser(97,'Absolute'); row(p,g,a); rr=row(p,g,obj('Preset','Preset 1.18'),2); rr.Enabled='No'; r=run()
check(next(r.final) and r.stats.rows==2 and #r.fast.unsafe==0,'disabled rows')
-- Non-group selection is unsupported under the formal authoring contract.
p=setup(); row(p,obj('Selection','Selection 1'),phaser(98,'Absolute')); r=run()
check(r.classifications.FAST_PATH_UNSAFE_SELECTION and next(r.final)==nil,'Stored Group required')
-- Raw Attribute number is an identity query, never a feature number lookup.
p=setup(); a=phaser(111,'Absolute','Position'); g=group(1,{1}); row(p,g,a)
for _,step in ipairs(a.contents[1].contents) do step.contents[1].Attributes='Attribute 111' end
r=run(); check(next(r.final) and r.rows[1].structural.audits[1].featureGroup==registry['FeatureGroup Position'],'Attribute ObjectList resolves actual metadata')
check(has('EXACT_OBJECTLIST') and has('FeatureGroup Position'),'attribute identity audit')
-- Special values including numeric raw enum encodings never look like numbers.
p=setup(); a=phaser(112,'Absolute'); row(p,g,a); a.contents[1].contents[1].contents[1].RawValueAbs='Release'; r=run()
check(next(r.final)==nil and has('UNSUPPORTED_SPECIAL_release'),'release audit, no guessed termination')
p=setup(); a=phaser(113,'Absolute'); row(p,g,a); a.contents[1].contents[1].contents[1].RawValueAbs=1124073472; r=run()
check(next(r.final)==nil and has('UNSUPPORTED_RAW_ENCODING'),'raw special integer unsafe')
env.Enums={PhaserRecipeValueSpecialsRaw={None=1124073479,Release=1124073472}}
p=setup(); a=phaser(118,'Absolute'); row(p,g,a)
for _,step in ipairs(a.contents[1].contents) do step.contents[1].RawValueRel=env.Enums.PhaserRecipeValueSpecialsRaw.None end
r=run(); check(next(r.final) and not r.classifications.FAST_PATH_UNSAFE_LAYER,'native enum None proves no relative lane')
env.Enums=nil
-- A Shape field alone is insufficient to classify the reference as moving.
p=setup(); a=phaser(114,'Absolute',nil,1); row(p,g,a)
local vs=a.contents[1].contents[1].contents[1]; vs.props[#vs.props+1]='Shape'; vs.Shape=obj('Shape','Shape 71')
r=run(); check(next(r.final)==nil and has('SHAPE_VALUESOURCE_LINK_UNVERIFIED'),'Shape class presence cannot prove motion')
-- Proven exact ValueSource link may fill empty layer cells, never import siblings.
p=setup(); a=phaser(115,nil); row(p,g,a)
for i,step in ipairs(a.contents[1].contents) do
 local v=step.contents[1]; local linked=obj('PhaserRecipeValueSource','Shape 72.'..i)
 linked.props={'RawValueAbs','RawValueRel'}; linked.RawValueAbs=i==1 and 100 or 0; linked.RawValueRel=''
 v.props[#v.props+1]='Shape'; v.Shape=linked
end
r=run(); check(next(r.final) and has('Shape_chain=Shape 72'),'exact source-link layer inheritance')
-- An opaque Preset dependency requires effective layer metadata and cannot prove static motion.
p=setup(); a=phaser(116,'Absolute'); row(p,g,a)
for _,step in ipairs(a.contents[1].contents) do local v=step.contents[1]; v.props[#v.props+1]='Preset'; v.Preset=obj('Preset','Preset 1.11'); v.ValueAbsolute=nil end
r=run(); check(next(r.final)==nil and has('PRESET_EFFECTIVE_abs_UNPROVEN'),'raw abs plus opaque Preset is not sufficient')
for _,step in ipairs(a.contents[1].contents) do local v=step.contents[1]; v.ValueAbsolute=v.RawValueAbs end
r=run(); check(next(r.final) and r.fastCalls==0,'effective layer and multiple authored steps prove supported subset')
-- Mixed source layers retain exact associations rather than applying each
-- feature to every layer on the whole reference.
p=setup(); a=phaser(119,'Absolute'); row(p,g,a)
local fg=obj('FeatureGroup','FeatureGroup Other'); local f=add(fg,obj('Feature','Feature Other')); local attr=obj('Attribute','Attribute 120'); attr.Feature=f
for i,step in ipairs(a.contents[1].contents) do
 local v=add(step,obj('PhaserRecipeValueSource','Extra Source '..i))
 v.props={'Attributes','RawValueAbs','RawValueRel'}; v.Attributes=attr; v.RawValueAbs=''; v.RawValueRel=i==1 and 10 or -10
end
r=run(); local lanes=0; for _ in pairs(r.rows[1].lanes or {}) do lanes=lanes+1 end
check(next(r.final) and lanes==2 and r.fast.lanesResolved==2,'per-source feature/layer pairing')
-- Shape cycles remain unsafe and bounded.
p=setup(); a=phaser(121,'Absolute'); row(p,g,a)
local v=a.contents[1].contents[1].contents[1]; v.props[#v.props+1]='Shape'; v.Shape=v
r=run(); check(next(r.final)==nil and has('SHAPE_VALUESOURCE_LINK_UNVERIFIED'),'shape cycle guarded')
-- Large member sets emit one unresolved bucket, not thousands of member lines.
p=setup(); local members={}; for i=1,8000 do members[i]=i end
row(p,group(90,members),phaser(117,nil)); r=run()
local n=0; for _,line in ipairs(logs) do if line:find('UNRESOLVED Recipe=',1,true) then n=n+1 end end
check(n==1 and #logs<120 and has('member_count=8000'),'bounded aggregate native output')
check(logs[1]:find('START',1,true) and logs[#logs]:find('END',1,true) and has('RESULT classification='),'summary survives large member count')
-- Detail floods are capped independently from mandatory summaries.
p=setup(); g=group(1,{1})
for i=1,600 do local v=phaser(2000+i,nil); row(p,g,v,i) end
r=run(); check(r.detailsSuppressed>0 and #logs<1800 and has('FAST_PATH_METRICS') and logs[#logs]:find('END',1,true),'detail cap reserves summary: '..#logs)
-- Rev4 end-to-end: opaque native Presets become readable only in metadata phase.
local oldRead,oldAttribute,oldCompare=env.GetPresetData,env.GetAttributeByUIChannel,env.CompareHandle
local metadataReads,oracleReads=0,0
local references={}
local metaFG=obj('FeatureGroup','FeatureGroup native'); metaFG.db=90001
local metaF=add(metaFG,obj('Feature','Feature native'))
local metaA=obj('Attribute','Attribute native'); metaA.Feature=metaF
local intFunction=function(h) return h.db end
env.HandleToInt=intFunction
env.CompareHandle=function(x,y) return x==y or (x.db~=nil and x.db==y.db) end
env.GetAttributeByUIChannel=function() return metaA end
env.GetPresetData=function(target,phasersOnly,byFixtures)
 if target.kind=='Preset' and not has('ORACLE_START') then
  check(has('NATIVE_ONLY_FINALIZED') and not has('BRIDGED_REVERSE_FINALIZED'),'reference reads only between native and bridge finalization')
  check(phasersOnly==false and byFixtures==false,'reference call flags')
  metadataReads=metadataReads+1; return references[target.db]
 end
 check(has('METADATA_REVERSE_FINALIZED') and has('BRIDGED_REVERSE_FINALIZED') and has('REV6_BRIDGED_REVERSE_FINALIZED') and has('REV7_BRIDGED_REVERSE_FINALIZED') and has('ORACLE_START'),'oracle unavailable until Rev7 finalized')
 oracleReads=oracleReads+1; calls=calls+1; return data[target] or {}
end
p=setup(); g=group(701,{11,12}); a=obj('Preset','Preset arbitrary'); a.db=91001
references[a.db]={[1]={[1]={absolute=0},[2]={absolute=100}}}
for i=1,100 do row(p,g,a,i) end
data[p]={[1]={abs_preset=a,[1]={absolute=0},[2]={absolute=100}}}
r=run()
check(metadataReads==1 and r.metadataStats.calls==1 and r.metadataStats.cache_hits==99,'100 Recipe rows one metadata native read')
check(next(r.final)==nil and next(r.metadataFinal)~=nil,'native final immutable and independent from metadata')
check(r.metadataClassifications.METADATA_REVERSE_EXACT_MATCH,'metadata reverse exact oracle validation')
check(r.metadataStats.COMPLETE==1 and r.metadata.staticRows==0 and r.metadata.movingRows==1,'complete moving cached result')
check(oracleReads>0 and r.oracleCalls==oracleReads,'oracle counters exclude metadata')
local joinedLogs=table.concat(logs,'\n')
local nativePos=assert(joinedLogs:find('NATIVE_ONLY_FINALIZED',1,true))
local cachePos=assert(joinedLogs:find('REFERENCE_METADATA_GETPRESETDATA',1,true))
local finalizedPos=assert(joinedLogs:find('METADATA_REVERSE_FINALIZED',1,true))
local oraclePos=assert(joinedLogs:find('ORACLE_START',1,true))
check(nativePos<cachePos and cachePos<finalizedPos and finalizedPos<oraclePos,'strict three-path finalization order')
local rev5Pos=assert(joinedLogs:find('REV5_BRIDGE_BASELINE',1,true))
local rev6Pos=assert(joinedLogs:find('REV6_BRIDGED_REVERSE_FINALIZED',1,true))
local rev7Pos=assert(joinedLogs:find('REV7_BRIDGED_REVERSE_FINALIZED',1,true))
check(finalizedPos<rev5Pos and rev5Pos<rev6Pos and rev6Pos<rev7Pos and rev7Pos<oraclePos,'Rev7 finalizes after Rev6 and before oracle')
check(r.rev6OK and r.rev6Final~=nil and r.fastCalls==0,'Rev6 candidate never sees oracle or cooked history')
check(r.rev7OK and r.rev7Final~=nil and r.rev7Final~=r.rev6Final and metadataReads==1 and has('RAW_REL_ZERO_PROOF_SUMMARY'),'Rev7 independent candidate reuses Rev6 reference reads')
-- Aliases across Cues read once, resolve memberships before ref identity collapse.
p=setup(); metadataReads=0; oracleReads=0
row(p,group(702,{11,12}),a)
cue=add(seq,obj('Cue','Sequence 7 Cue 2')); cue.No=2000
local secondPart=add(cue,obj('Part','Sequence 7 Cue 2 Part 0'))
local alias=obj('Preset','Preset alias'); alias.db=a.db
row(secondPart,group(703,{12}),alias)
r=run(); local entry=select(2,next(r.metadata.refs))
check(metadataReads==1 and r.metadataStats.distinct_references==1,'DB aliases across Cues share cache')
check(entry.members[11] and entry.members[12] and r.metadata.movingRows==2,'same reference reused / re-source retains older uncovered member')
-- Static opaque reference terminates only its overlapping subfixture.
local stop=obj('Preset','Preset static'); stop.db=91002
references[stop.db]={[1]={[1]={absolute=100}}}
row(secondPart,group(704,{12}),stop,2)
metadataReads=0; oracleReads=0; logs={}; calls=0; r=run(); entry=select(2,next(r.metadata.refs))
check(entry and entry.members[11] and not entry.members[12] and r.metadata.staticRows==1,'ordinary static metadata terminates partial overlap')
check(r.fastCalls==0 and logs[1]:find('revision=7_RAW_REL_ZERO_SEMANTICS_PROOF',1,true) and has('BASELINE_METADATA_FINALIZED revision=4_REFERENCE_METADATA_CACHE'),'native remains zero GetPresetData')
-- A second run must issue a new metadata read for each distinct reference.
metadataReads=0; oracleReads=0; logs={}; calls=0; r=run()
check(metadataReads==2 and r.metadataStats.calls==2,'run-local cache lifetime')
-- Incomplete metadata stays unsafe; oracle cannot repair either finalized set.
p=setup(); metadataReads=0; oracleReads=0
local unreadable=obj('Preset','Preset unreadable'); unreadable.db=91003
references[unreadable.db]={future_container={steps={1,2}}}; row(p,group(705,{11}),unreadable)
data[p]={[1]={abs_preset=unreadable,[1]={absolute=1},[2]={absolute=2}}}
r=run()
check(r.metadataStats.UNKNOWN==1 and #r.metadata.unsafe==1 and next(r.metadataFinal)==nil,'incomplete metadata does not produce an active ref')
check(r.metadataClassifications.METADATA_REFERENCE_UNSAFE and r.metadataClassifications.METADATA_REVERSE_MISSING_REFERENCE,'unsafe and missing classifications remain separate')
check(metadataReads==1 and r.fastCalls==0 and next(r.final)==nil,'oracle never repairs metadata or native snapshots')
data[p]={}; logs={}; calls=0; metadataReads=0; oracleReads=0; r=run()
check(r.metadataClassifications.METADATA_REVERSE_EXACT_MATCH and r.metadataClassifications.METADATA_REFERENCE_UNSAFE,'exact identity match does not hide unknown completeness')
references[unreadable.db]={[1]={[1]={absolute=0},[2]={absolute=100}}}
logs={}; calls=0; metadataReads=0; oracleReads=0; r=run()
check(r.metadataClassifications.METADATA_REVERSE_EXTRA_REFERENCE and next(r.metadataExtra)~=nil,'extra metadata refs compared after oracle independently')
-- Rev5: direct Phaser reference is empty, yet native ValueSources bridge
-- through one shared linked-Preset read before the unchanged oracle starts.
p=setup(); metadataReads=0; oracleReads=0
local moving=phaser(370,'Absolute','Dimmer',2); moving.db=91005
registry['FeatureGroup Dimmer'].db=metaFG.db
local linked=obj('Preset','Preset linked'); linked.db=91006
references[moving.db]={}
references[linked.db]={[1]={[1]={absolute=50},mask_active_value=2,mask_active_phaser=0}}
for _,step in ipairs(moving.contents[1].contents) do
 local source=step.contents[1]; source.Preset=linked; source.props[#source.props+1]='Preset'
end
row(p,group(706,{11,12}),moving)
data[p]={[1]={abs_preset=moving,[1]={absolute=100},[2]={absolute=0}}}
r=run()
check(r.metadataStats.calls==1 and r.metadataStats.UNKNOWN==1 and not next(r.metadataFinal),'Rev4 baseline remains empty for direct-empty Phaser')
check(metadataReads==2 and r.bridgeStats.dependencies==1 and r.bridgeStats.phasers==1,'one direct and one linked read shared by two sources')
check(r.bridgeOK and r.bridgeStats.moving==1 and next(r.bridgeFinal)~=nil,'native linked bridge contributes moving reference')
check(r.bridgedClassifications.BRIDGED_REVERSE_EXACT_MATCH,'bridged reverse matches oracle identity set in mock')
check(has('ORDINARY_REFERENCE_SEMANTICS_SUMMARY') and has('PHASER_BRIDGE_SUMMARY') and has('BRIDGED_DIFF'),'required compact bridge summaries')
joinedLogs=table.concat(logs,'\n')
check(assert(joinedLogs:find('BASELINE_METADATA_FINALIZED',1,true))<assert(joinedLogs:find('BRIDGED_REVERSE_FINALIZED',1,true)) and assert(joinedLogs:find('BRIDGED_REVERSE_FINALIZED',1,true))<assert(joinedLogs:find('ORACLE_START',1,true)),'baseline then bridge finalized before oracle')
-- Rev11: linked Universal preset needs no fixture-specific membership proof.
-- Controlled 25.9006/Dimmer 1.28 shape: PARTIAL only from member-level evidence.
p=setup(); metadataReads=0; oracleReads=0
local uni=phaser(371,'Absolute','Dimmer',2); uni.db=91011
registry['FeatureGroup Dimmer'].db=metaFG.db
local uniLinked=obj('Preset','Preset linked universal'); uniLinked.db=91012; uniLinked.PresetMode='Universal'
references[uni.db]={}
references[uniLinked.db]={[1]={[1]={absolute=50},mask_active_value=2,mask_active_phaser=0,gridposmatr={1}}}
for _,step in ipairs(uni.contents[1].contents) do
 local source=step.contents[1]; source.Preset=uniLinked; source.props[#source.props+1]='Preset'
end
row(p,group(707,{11,12}),uni)
data[p]={[1]={abs_preset=uni,[1]={absolute=100},[2]={absolute=0}}}
r=run()
check(has('LINKED_PRESET_MODE_UNIVERSAL') and not has('LINKED_PRESET_METADATA_UNSAFE'),'universal linked preset needs no member mapping proof')
check(r.bridgedClassifications.BRIDGED_REVERSE_EXACT_MATCH,'universal bridge matches oracle')
check(r.rev6Classes.REV6_BRIDGED_EXACT_MATCH and not r.rev6Classes.REV6_REFERENCE_UNSAFE,'universal rev6 resolves')
check(r.rev7Classes.REV7_BRIDGED_EXACT_MATCH and not r.rev7Classes.REV7_REFERENCE_UNSAFE,'universal rev7 resolves')
-- Rev11: Selective mode is recognized but member mapping stays blocked.
p=setup(); metadataReads=0; oracleReads=0
local sel=phaser(374,'Absolute','Dimmer',2); sel.db=91015
registry['FeatureGroup Dimmer'].db=metaFG.db
local selLinked=obj('Preset','Preset linked selective'); selLinked.db=91016; selLinked.PresetMode='Selective'
references[sel.db]={}
references[selLinked.db]={[1]={[1]={absolute=50},mask_active_value=2,mask_active_phaser=0}}
for _,step in ipairs(sel.contents[1].contents) do
 local source=step.contents[1]; source.Preset=selLinked; source.props[#source.props+1]='Preset'
end
row(p,group(710,{11,12}),sel)
data[p]={[1]={abs_preset=sel,[1]={absolute=100},[2]={absolute=0}}}
r=run()
check(has('LINKED_PRESET_MODE_SELECTIVE') and has('SELECTIVE_MEMBER_MAPPING_UNPROVEN'),'selective mode recognized, members unresolved')
check(next(r.bridgeFinal)==nil,'selective member mapping stays out of the active set')
check(r.rev6Classes.REV6_BRIDGED_MISSING_REFERENCE and next(r.rev6Final)==nil,'selective rev6 stays missing')
check(r.rev7Classes.REV7_BRIDGED_MISSING_REFERENCE and next(r.rev7Final)==nil,'selective rev7 stays missing')
-- Rev11: un-authored REL zero is absent, not ambiguous (25.9009 shape).
p=setup(); metadataReads=0; oracleReads=0
local relBlank=phaser(372,'Absolute','Dimmer',2); relBlank.db=91013
registry['FeatureGroup Dimmer'].db=metaFG.db
local blankAbs=0
for _,step in ipairs(relBlank.contents[1].contents) do
 blankAbs=blankAbs+1; local source=step.contents[1]
 source.RawValueAbs=blankAbs==1 and 100 or 50; source.ValueAbsolute=source.RawValueAbs
 source.RawValueRel=0; source.ValueRelative=''
end
references[relBlank.db]={}
row(p,group(708,{11,12}),relBlank)
data[p]={[1]={abs_preset=relBlank,[1]={absolute=100},[2]={absolute=0}}}
r=run()
check(has('REL_NOT_AUTHORED_PROVEN:2'),'blank relative zero classified not-authored')
check(r.rev6Classes.REV6_BRIDGED_EXACT_MATCH and not r.rev6Classes.REV6_REFERENCE_UNSAFE,'blank-rel rev6 resolves')
check(r.rev7Classes.REV7_BRIDGED_EXACT_MATCH and not r.rev7Classes.REV7_REFERENCE_UNSAFE,'blank-rel rev7 resolves')
-- Rev11: authored REL zero is admitted, not ambiguous (25.9010 shape).
p=setup(); metadataReads=0; oracleReads=0
local relAuth=phaser(373,'Absolute','Dimmer',2); relAuth.db=91014
registry['FeatureGroup Dimmer'].db=metaFG.db
env.Enums={Roles={Display='display'}}
local stepNo=0
for _,step in ipairs(relAuth.contents[1].contents) do
 stepNo=stepNo+1; local source=step.contents[1]
 source.RawValueAbs=stepNo==1 and 100 or 50; source.ValueAbsolute=source.RawValueAbs
 source.RawValueRel=stepNo==1 and 0 or 10; source.ValueRelative=stepNo==1 and 0 or 10
 source.Get=function(s,k,role) if role~=nil then return '0.00' end; return rawget(s,k) end
end
references[relAuth.db]={}
row(p,group(709,{11,12}),relAuth)
data[p]={[1]={abs_preset=relAuth,[1]={absolute=100},[2]={absolute=0}}}
r=run()
env.Enums=nil
check(has('REL_AUTHORED_PROVEN:1'),'authored relative zero classified authored')
check(r.rev6Classes.REV6_BRIDGED_EXACT_MATCH and not r.rev6Classes.REV6_REFERENCE_UNSAFE,'authored-rel rev6 resolves')
check(r.rev7Classes.REV7_BRIDGED_EXACT_MATCH and not r.rev7Classes.REV7_REFERENCE_UNSAFE,'authored-rel rev7 resolves')
-- Rev11.1 A: unsafe row with surviving barrier lanes is final-surviving.
p=setup(); metadataReads=0; oracleReads=0
local surv=phaser(375,'Absolute','Dimmer',2); surv.db=91021
registry['FeatureGroup Dimmer'].db=metaFG.db
local survLinked=obj('Preset','Preset linked surviving'); survLinked.db=91022; survLinked.PresetMode='Selective'
references[surv.db]={}
references[survLinked.db]={[1]={[1]={absolute=50},mask_active_value=2,mask_active_phaser=0}}
for _,step in ipairs(surv.contents[1].contents) do
 local source=step.contents[1]; source.Preset=survLinked; source.props[#source.props+1]='Preset'
end
row(p,group(711,{11,12}),surv)
data[p]={}
r=run()
check(r.attributionOK and r.attribution.total==1 and r.attribution.finalSurviving==1,'unsafe row with surviving lanes is final-surviving')
check(r.attribution.unknown==0 and has('FINAL_SURVIVING_UNSAFE_ROW'),'surviving row logged')
check(has('UNSAFE_ATTRIBUTION_SUMMARY total_unsafe_rows=1 final_surviving=1'),'attribution summary')
check(not has('UNSAFE_ATTRIBUTION_ERROR'),'attribution never breaks the resolver')
-- Rev11.1 B: unsafe older row neutralized by newer decisions is superseded.
p=setup(); metadataReads=0; oracleReads=0
local older=phaser(376,'Absolute','Dimmer',2); older.db=91024
registry['FeatureGroup Dimmer'].db=metaFG.db
local olderLinked=obj('Preset','Preset linked older'); olderLinked.db=91025; olderLinked.PresetMode='Selective'
references[older.db]={}
references[olderLinked.db]={[1]={[1]={absolute=50},mask_active_value=2,mask_active_phaser=0}}
for _,step in ipairs(older.contents[1].contents) do
 local source=step.contents[1]; source.Preset=olderLinked; source.props[#source.props+1]='Preset'
end
row(p,group(713,{11,12}),older)
cue=add(seq,obj('Cue','Sequence 7 Cue 2')); cue.No=2000
local newerPart=add(cue,obj('Part','Sequence 7 Cue 2 Part 0'))
local newerStatic=obj('Preset','Preset newer static'); newerStatic.db=91023
references[newerStatic.db]={[1]={[1]={absolute=100},mask_active_value=2,mask_active_phaser=0}}
row(newerPart,group(712,{11,12}),newerStatic)
data[p]={}
data[newerPart]={[1]={abs_preset=newerStatic,[1]={absolute=100}}}
r=run()
check(r.attributionOK and r.attribution.total==1 and r.attribution.fullySuperseded==1,'older unsafe row neutralized by newer decisions')
check(r.attribution.unknown==0 and has('FULLY_SUPERSEDED_SAMPLE_ROW'),'superseded sample logged')
-- Rev11.1 C: unsafe row with no lanes contributes nothing.
p=setup(); metadataReads=0; oracleReads=0
local opaque=obj('Preset','Preset opaque lanes'); opaque.db=91026
references[opaque.db]={future_container={steps={1,2}}}
row(p,group(715,{}),opaque)
data[p]={}
r=run()
check(r.attributionOK and r.attribution.total==1 and r.attribution.nonContributing==1,'laneless unsafe row is non-contributing')
check(r.attribution.unknown==0,'fail-closed unknown stays empty here')
-- Rev12 uses the cached ordinary reference without changing Rev7's final set.
p=setup(); metadataReads=0; oracleReads=0
local ordinary=obj('Preset','Preset ordinary static'); ordinary.db=91027
references[ordinary.db]={[1]={[1]={absolute=50,absolute_value=50},mask_active_value=2,
 mask_active_phaser=0,preset_store_mode=2,selective=false,dict_flags={has_absolute=true}}}
row(p,group(716,{11,12}),ordinary)
data[p]={}
r=run()
check(r.attribution.ordinaryProofOK and r.attribution.ordinaryProof.totals.motionProven==1 and r.attribution.ordinaryProof.totals.memberProven==1,'ordinary static and membership separately proven')
check(has('ORDINARY_STATIC_PROOF reference=Preset ordinary static') and has('projected_eligible_rows=0'),'already safe ordinary reference needs no promotion')
check(r.attribution.ordinaryProof.alternate==nil,'no alternate when no eligible unsafe row exists')
check(r.rev7Final and next(r.rev7Final)==nil,'Rev7 final reference set unchanged by observer')
check(has('REV13_GLOBAL_ALTERNATE refs=0') and has('eligible_global_rows=0'),'Rev13 alternate does not alter baseline refs')
-- Rev13 target identity survives the native description's [#...] suffix.
p=setup(); metadataReads=0; oracleReads=0
for i,path in ipairs({'Preset 4.1','Preset 4.4','Preset 4.23','Preset 6.10','Preset 21.5'}) do
 local ref=obj('Preset',path); ref.db=92000+i; registry[path]=ref
 references[ref.db]={[1]={[1]={absolute=50},mask_active_value=2,mask_active_phaser=64,
  mask_individual=64,preset_store_mode=2,selective=false}}
 row(p,group(800+i,{100+i}),ref,i)
end
data[p]={}
r=run()
local classCount=0
for _,line in ipairs(logs) do if line:find('GLOBAL_APPLICABILITY_CLASS reference=',1,true) then classCount=classCount+1 end end
check(classCount==5 and has('REV13_GLOBAL_TARGET_SUMMARY expected=5 found=5 classified=5'),'all five canonical targets classified despite description suffix')
local deltaCount=0
for _,line in ipairs(logs) do if line:find('GLOBAL_SIGNATURE_DELTA reference=',1,true) then deltaCount=deltaCount+1 end end
check(deltaCount==4 and has('GLOBAL_SIGNATURE_COMPONENT reference=Preset 4.1'),'Rev13.1 observes four targets without changing classification')
local normalizedCount=0
for _,line in ipairs(logs) do if line:find('GLOBAL_NORMALIZED_SEMANTIC_CLASS reference=',1,true) then normalizedCount=normalizedCount+1 end end
check(normalizedCount==5 and has('GLOBAL_DICT_INDEX_AUDIT reference=Preset 4.4'),'Rev13.2 observes all five cached references')
check(has('GLOBAL_RECIPE_APPLICABILITY_SUMMARY rows_expected=15') and has('diagnostic_only=true cooked_part_reads=1'),'truth observer reads current Cue Part once')
check(has('COOKED_MEMBER_KEY_SUMMARY problematic_lanes=') and has('COOKED_MEMBER_KEY_TIMING observer_ms=') and has('extra_GetPresetData_calls=0'),'member key probe reuses cooked Part cache')
check(has('REV13_GLOBAL_ALTERNATE refs=0') and has('eligible_global_rows=0'),'Rev13 alternate unchanged by signature observer')
check(has('duplicate_targets= pass=true'),'Rev13 target sanity passes')
check(next(r.rev7Final)==nil,'Rev7 baseline final refs unchanged by target selection')
registry['Preset 4.23']=nil
r=run()
check(has('REV13_GLOBAL_TARGET_SUMMARY expected=5 found=4 classified=4') and has('classification=INCONCLUSIVE diagnostic_only=true'),'missing target fails Rev13 alternate closed')
registry['Preset 4.23']=registry['Preset 4.4']
r=run()
check(has('duplicate_targets=Preset 4.23 pass=false') and has('classification=INCONCLUSIVE diagnostic_only=true'),'duplicate target fails Rev13 alternate closed')
p=setup(); metadataReads=0; oracleReads=0
local selectiveOrdinary=obj('Preset','Preset selective ordinary'); selectiveOrdinary.db=91028
references[selectiveOrdinary.db]={[1]={[1]={absolute=50},mask_active_value=2,
 mask_active_phaser=64,preset_store_mode=1,selective=true,dict_flags={selective=true}}}
row(p,group(717,{11,12}),selectiveOrdinary)
data[p]={}
r=run()
check(r.attribution.ordinaryProofOK and r.attribution.ordinaryProof.totals.motionProven==1 and r.attribution.ordinaryProof.totals.memberUnproven==1,'selective grid ordinary static motion proven, membership blocked')
check(has('projected_eligible_rows=0') and r.attribution.finalSurviving==1,'selective member applicability stays unsafe')
check(next(r.rev7Final)==nil,'selective cannot change Rev7 final set')
env.GetPresetData,env.GetAttributeByUIChannel,env.CompareHandle=oldRead,oldAttribute,oldCompare
env.HandleToInt=nil
check(forbidden==0,'no mutation, channel expansion, UI, programmer or marker APIs')
print('PASS Recipe reverse A/B '..checks..' integration checks')
