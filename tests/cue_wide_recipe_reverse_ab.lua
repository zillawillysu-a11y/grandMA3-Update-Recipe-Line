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
check(n==1 and #logs<35 and has('member_count=8000'),'bounded aggregate native output')
check(logs[1]:find('START',1,true) and logs[#logs]:find('END',1,true) and has('RESULT classification='),'summary survives large member count')
-- Detail floods are capped independently from mandatory summaries.
p=setup(); g=group(1,{1})
for i=1,600 do local v=phaser(2000+i,nil); row(p,g,v,i) end
r=run(); check(r.detailsSuppressed>0 and #logs<1200 and has('FAST_PATH_METRICS') and logs[#logs]:find('END',1,true),'detail cap reserves summary')
check(forbidden==0,'no mutation, channel expansion, UI, programmer or marker APIs')
print('PASS Recipe reverse A/B '..checks..' integration checks')
