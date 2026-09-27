local function module(path,name)
 local f=assert(io.open(path)); local src=f:read('*a'); f:close()
 return assert(load(src..'\nreturn '..name))()
end
local new=module('tools/templates/cue_wide_recipe_reference_metadata.lua','newReferenceMetadataCache')
local reverse=module('tools/templates/cue_wide_recipe_reverse_engine.lua','recipeReverseResolve')
local checks=0
local function check(v,m) assert(v,m); checks=checks+1 end
local function object(c,n) local h={class=c,db=n}; function h:Parent() return self.parent end; return h end
local fg1,fg2=object('FeatureGroup',101),object('FeatureGroup',102)
local f1,f2=object('Feature',201),object('Feature',202); f1.parent=fg1; f2.parent=fg2
local a1,a2=object('Attribute',301),object('Attribute',302); a1.Feature=f1; a2.Feature=f2
local move,static,relative,other,dual,bad=object('Preset',401),object('Preset',402),object('Preset',403),object('Preset',404),object('Preset',405),object('Preset',406)
local data={
 [401]={count=1,by_fixtures=false,[0]={[1]={absolute=0},[2]={absolute=100}}},
 [402]={[0]={[1]={absolute=100}}},
 [403]={[0]={[1]={relative=-10},[2]={relative=10}}},
 [404]={[1]={[1]={absolute=0},[2]={absolute=100}}},
 [405]={[0]={[1]={absolute=100,relative=-10},[2]={absolute=0,relative=10}}},
 [406]={[0]={[1]={absolute=10},unknown_layer=23}}
}
local calls,clock,readTargets=0,0,{}
local function cache(opts)
 opts=opts or {}
 return new({safe=function(fn,...) if type(fn)~='function' then return nil end; local ok,v=pcall(fn,...); if ok then return v end end,
 class=function(h) return h and h.class or '' end,isObject=function(h) return type(h)=='table' and h.class~=nil end,
 handleToInt=opts.noInt and function() return nil end or function(h) return h.db end,
 handleToStr=opts.handleToStr or function(h) return h.db and string.format('H#%X',h.db) end,
 attributeByUIChannel=function(i) return i==0 and a1 or i==1 and a2 or nil end,
 now=function() clock=clock+.001; return clock end,log=function() end,
 read=function(h,p,b) check(p==false and b==false,'all reference data in UI index mode'); calls=calls+1; readTargets[#readTargets+1]=h.class; if opts.error then error('native error') end; return data[h.db] end})
end
local c=cache(); c.register(move)
for i=1,100 do c.get(move) end
check(c.stats.calls==1 and c.stats.cache_hits==99,'100 same reference requests read once')
local alias=object('Preset',401); c.register(alias); c.get(alias)
check(c.stats.calls==1 and c.stats.distinct_references==1 and c.stats.cache_hits==100,'native integer alias identity')
local hcache=cache({noInt=true}); hcache.register(move); hcache.register(alias); hcache.get(move); hcache.get(alias)
check(hcache.stats.calls==1,'H# native identity aliases')
for _,kind in ipairs({'Cue','Part','CuePart','Sequence'}) do
 local n=c.stats.calls; local ok=pcall(c.get,object(kind,999)); check(not ok and n==c.stats.calls,'reject '..kind)
end
check(not pcall(c.get,object('Preset',499)),'unregistered preset rejected')
local missing=object('Preset',nil); local noid=cache({handleToStr=function() return 'Preset 1.1' end}); noid.register(missing)
check(noid.get(missing).completeness=='UNKNOWN' and noid.stats.calls==0,'no display/address identity fallback')
local err=cache({error=true}); err.register(move); err.get(move); err.get(alias)
check(err.stats.calls==1 and err.stats.UNKNOWN==1,'failed read cached')
for _,h in ipairs({static,relative,other,dual,bad}) do c.register(h); c.get(h) end
check(c.get(static).motion=='STATIC' and c.get(static).completeness=='COMPLETE','ordinary static metadata')
check(c.get(move).motion=='MOVING','multistep motion metadata')
check(c.get(dual).layers.ABS and c.get(dual).layers.REL,'ABS+REL metadata')
check(c.get(bad).motion=='UNSAFE' and c.get(bad).completeness=='PARTIAL','ambiguous metadata unsafe')
local function row(h,members,meta)
 local m=meta or c.get(h); local set={}; for _,member in ipairs(members) do set[member]=true end
 return {ref=h,refId=h.db,members=set,features=m.features,layers=m.layers,lanes=m.lanes,moving=m.motion=='MOVING',unsafe=m.completeness=='COMPLETE' and {} or {'METADATA_REFERENCE_UNSAFE'}}
end
local r=reverse({row(static,{2}),row(move,{1,2})})
check(r.staticRows==1 and r.refs[401].members[1] and not r.refs[401].members[2],'partial overlap static terminator')
r=reverse({row(static,{1,2}),row(move,{1,2})})
check(not next(r.refs) and r.rowsSkipped==1,'full overlapping groups terminate motion')
r=reverse({row(move,{2}),row(move,{1,2})})
check(r.refs[401].members[1] and r.refs[401].members[2] and r.movingRows==2,'re-source before identity collapse')
r=reverse({row(static,{1}),row(other,{1})})
check(r.refs[404] and r.lanesResolved==2,'different feature lanes independent')
r=reverse({row(static,{1}),row(relative,{1})})
check(r.refs[403] and r.lanesResolved==2,'ABS and REL independent')
r=reverse({row(bad,{1}),row(move,{1,2})})
check(r.refs[401].members[2] and not r.refs[401].members[1] and #r.unsafe==1,'unsafe newer partial lane blocks same member')
r=reverse({row(static,{1002}),row(move,{1001,1002,1003})})
check(r.refs[401].members[1001] and r.refs[401].members[1003] and not r.refs[401].members[1002],'fixture subfixture cell identities unchanged')
local empty=c.normalize({},static); check(empty.completeness=='UNKNOWN','empty metadata unsafe')
check(c.normalize({[5]={[1]={absolute=1}}},static).completeness~='COMPLETE','unreadable Attribute unsafe')
check(c.normalize({by_fixtures=true,[0]={[1]={absolute=1}}},static).completeness~='COMPLETE','fixture-oriented return rejected')
check(c.normalize({count=2,[0]={[1]={absolute=1}}},static).completeness~='COMPLETE','count mismatch unsafe')
check(c.normalize({[0]={[1]={absolute=1},[3]={absolute=2}}},static).completeness~='COMPLETE','sparse indices unsafe')
check(c.normalize({[0]={[1]={abs_remove=true}}},static).completeness~='COMPLETE','remove semantics remain unsafe')
check(c.normalize({[0]={[1]={abs_release=true}}},static).completeness=='COMPLETE','explicit release layer recorded')
check(c.normalize({[0]={[1]={absolute=100,abs_release=true}}},static).completeness~='COMPLETE','release with numeric default is ambiguous')
local generator=object('Generator',407); data[407]={[0]={[1]={absolute=1}}}; c.register(generator)
check(c.get(generator).motion=='GENERATOR','native generator class with complete content')
local fresh=cache(); fresh.register(move); fresh.get(move); check(fresh.stats.calls==1 and fresh.stats.cache_hits==0,'fresh cache per run')
check(c.stats.calls<=c.stats.distinct_references and #readTargets==calls,'instrumented once per distinct ref')
print('PASS Rev4 metadata cache / reverse '..checks..' checks')
