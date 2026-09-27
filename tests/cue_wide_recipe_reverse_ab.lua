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
 return h
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
env.Printf=function(f,...) logs[#logs+1]=string.format(f,...) end
env.GetPresetData=function(target,p,f)
 assert(table.concat(logs,'\n'):find('FAST_FINALIZED',1,true),'Oracle ran before fast finalization')
 calls=calls+1; return data[target] or {}
end
env.GetUIChannel=function(i) return {rt_index=i} end
local fixture=obj('Subfixture','Fixture 1'); fixture.SubfixtureIndex=1
env.GetRTChannel=function() return {fixture=fixture,subfixture=fixture} end
env.GetAttributeByUIChannel=function() local a=obj('Attribute','Attribute Dimmer'); a.Name='Dimmer'; return a end
env.ObjectList=function() return {} end
local checks=0
local function check(v,m) assert(v,m); checks=checks+1 end
local function setup()
 seq=obj('Sequence','Sequence 7'); cue=add(seq,obj('Cue','Sequence 7 Cue 1')); cue.No=1000
 logs={}; data={}; calls=0; clock=10
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
 for i=1,steps or 2 do
  local s=add(recipe,obj('PhaserRecipeStep','Step '..no..'.'..i))
  local vs=add(s,obj('PhaserRecipeValueSource','Source '..no..'.'..i))
  vs.props={'Attributes','Layer'}; vs.Attributes=feature or 'Dimmer'; vs.Layer=layer
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
data[p]={[1]={abs_preset=a,[1]={absolute=10},[2]={absolute=20}}}
local r=run()
check(r.fastCalls==0 and r.oracleCalls>0,'zero fast calls')
check(r.classifications.RECIPE_REVERSE_EXACT_MATCH and next(r.final),'independent exact match')
check(r.stats.groups==1 and r.stats.expansions==1,'group metrics')
check(has('SOURCE') and has('surviving_member_count=1'),'trace')
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
check(has('UNRESOLVED member=1') and r.fastCalls==0,'unsafe member trace')
-- User object names never supply missing feature scope.
p=setup(); a=phaser(95,'Absolute','UnknownAttribute'); a.Name='Dimmer Strobe Speed'; row(p,g,a); r=run()
check(r.classifications.FAST_PATH_UNSAFE_FEATURE_SCOPE and next(r.final)==nil,'no name guessing')
-- Opaque ordinary preset is not guessed static; oracle cannot repair fast set.
p=setup(); a=obj('Preset','Preset 1.17'); row(p,g,a)
data[p]={[1]={abs_preset=a,[1]={absolute=10},[2]={absolute=20}}}
r=run(); check(r.classifications.UNVERIFIED and r.classifications.RECIPE_REVERSE_MISSING_REFERENCE,'opaque moving ordinary preset')
check(next(r.final)==nil and has('DIFF_SOURCE'),'final immutable and mismatch attribution')
-- Advertised Recipe layer can scope an otherwise unreadable source layer.
p=setup(); a=phaser(96,nil); local rr=row(p,g,a); rr.props={'Layer'}; rr.Layer='Relative'; r=run()
check(next(r.final) and not r.classifications.FAST_PATH_UNSAFE_LAYER,'Recipe layer evidence')
-- Disabled rows are inspected but cannot block/resolve members.
p=setup(); a=phaser(97,'Absolute'); row(p,g,a); rr=row(p,g,obj('Preset','Preset 1.18'),2); rr.Enabled='No'; r=run()
check(next(r.final) and r.stats.rows==2 and #r.fast.unsafe==0,'disabled rows')
-- Non-group selection is unsupported under the formal authoring contract.
p=setup(); row(p,obj('Selection','Selection 1'),phaser(98,'Absolute')); r=run()
check(r.classifications.FAST_PATH_UNSAFE_SELECTION and next(r.final)==nil,'Stored Group required')
check(forbidden==0,'no mutation, channel expansion, UI, programmer or marker APIs')
print('PASS Recipe reverse A/B '..checks..' integration checks')
