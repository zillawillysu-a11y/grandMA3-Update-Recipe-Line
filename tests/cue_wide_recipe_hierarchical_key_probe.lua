local f=assert(io.open('tools/templates/cue_wide_recipe_hierarchical_key_probe.lua','rb'))
local source=f:read('*a'); f:close(); assert(load(source))()
local function obj(id,address,fid,parent,index)
 local h={id=id,address=address,FID=fid,parent=parent,index=index}
 function h:GetClass() return 'Fixture' end
 function h:Parent() return self.parent end
 function h:Children() return self.children end
 function h:Index() return self.index end
 function h:Get(k) if k=='FixtureAddress' then return self.native end end
 return h
end
local root=obj(1,'201',201,nil,nil)
local child=obj(2,'201.1',nil,root,1); root.children={child}
local nested=obj(3,'201.1.3',nil,child,3)
local sibling1=obj(4,'201.1.1',nil,child,1)
local sibling2=obj(5,'201.1.2',nil,child,2)
child.children={[7]=nested,[2]=sibling1,[9]=sibling2}
local preset={id=500}; local part={id=600}
local handles={[1]=root,[2]=child,[3]=nested,[4]=sibling1,[5]=sibling2}
local logs={}
local api={log=function(s) logs[#logs+1]=s end,identity=function(h) return h and 'DBI:'..h.id end,
 describe=function(h) return h and 'Fixture '..h.address..' [#'..h.id..']' end,
 getSubfixture=function(sf) return handles[sf] end}
local function run(ids,buckets)
 logs={}; local cases={}
 for _,sf in ipairs(ids) do cases[#cases+1]={sf=sf,part=part,expected=preset,attributes={'Dimmer'},layer='ABS'} end
 return __cookedHierarchicalKeyProbe(cases,{['DBI:600']={part=part,buckets=buckets}},api)
end
local function bucket() return {Dimmer={abs_preset=preset}} end
root.native='201'; child.native='201.1'; nested.native='201.1.3'
local r=run({1,2,3},{['201']=bucket(),['201.1']=bucket(),['201.1.3']=bucket()})
assert(r.classification=='HIERARCHICAL_ADDRESS_PROVEN' and r.summary.fully==3 and r.alternate.expected==3)
assert(r.summary.hierarchy==3 and r.summary.native==3)
r=run({4,5},{['201.1.1']=bucket(),['201.1.2']=bucket()})
assert(r.classification=='HIERARCHICAL_ADDRESS_PROVEN' and r.summary.collision==0)
child.children={[1]=sibling1,[2]=sibling2,[3]=nested}
sibling2.address='201.1.1'; sibling2.native='201.1.1'
r=run({4,5},{['201.1.1']=bucket()})
assert(r.classification=='UNPROVEN' and r.summary.collision>0 and r.alternate.mapped==0)
sibling2.address='201.1.2'; sibling2.native=nil
child.children=nil
r=run({5},{['201.1.2']=bucket()})
assert(r.classification=='DISPLAY_ADDRESS_MATCH_ONLY' and r.alternate.mapped==0)
child.children={[1]=sibling1,[2]=sibling2,[3]=nested}
r=run({5},{['201.1.2']=bucket()})
assert(r.classification=='HIERARCHICAL_ADDRESS_PROVEN' and r.alternate.expected==1)
r=run({5},{})
assert(r.classification=='UNPROVEN' and r.summary.unmapped==1)
assert(r.residual.members==0)
handles[9]=sibling2
r=run({9},{['201.1.2']=bucket(),['9']=bucket()})
assert(r.classification=='UNPROVEN' and r.summary.ambiguous==1 and r.residual.members==1)
assert(r.residual.reasons.sf_string_other_bucket==1)
handles[9]=nil
print('PASS hierarchical fixture address root, child, nested, siblings, collision, display-only, native proof')
