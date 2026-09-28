local file=assert(io.open('tools/templates/cue_wide_recipe_member_key_probe.lua','rb'))
local source=file:read('*a'); file:close(); assert(load(source))()
local function obj(kind,id,fid,cid,parent)
 local h={kind=kind,id=id,FID=fid,CID=cid,parent=parent,Name=kind..id}
 function h:GetClass() return self.kind end
 function h:Parent() return self.parent end
 function h:Get(k) return self[k] end
 return h
end
local preset=obj('Preset',500); local part=obj('Part',600)
local parent=obj('Fixture',700,100,nil)
local fixtures={}
local logs={}
local api={log=function(s) logs[#logs+1]=s end,
 identity=function(h) return h and 'DBI:'..h.id end,
 describe=function(h) return h and h.kind..h.id end,
 getSubfixture=function(sf) return fixtures[sf] end}
local function probe(members,buckets)
 fixtures=members; logs={}
 local cases={}
 for sf in pairs(members) do cases[#cases+1]={sf=sf,part=part,expected=preset,attributes={'Dimmer'},feature='FG:1',layer='ABS'} end
 table.sort(cases,function(a,b) return a.sf<b.sf end)
 return __cookedMemberKeyProbe(cases,{['DBI:600']={part=part,buckets=buckets}},api)
end
local r=probe({[11]=obj('Subfixture',11,101,'None')},{['101']={Dimmer={abs_preset=preset}}})
assert(r.classification=='PROVEN_FOR_TESTED_SHAPES' and r.summary.mapped==1 and r.alternate.expected==1)
local child=obj('Subfixture',21,101,1,parent)
r=probe({[21]=child},{['100.1']={Dimmer={abs_preset=preset}}})
assert(r.classification=='PROVEN_FOR_TESTED_SHAPES' and r.summary.provenShapes==1)
r=probe({[21]=child,[22]=obj('Subfixture',22,101,2,parent)},
 {['100.1']={Dimmer={abs_preset=preset}},['100.2']={Dimmer={abs_preset=preset}}})
assert(r.classification=='PROVEN_FOR_TESTED_SHAPES' and r.summary.mapped==2 and r.summary.collision==0)
r=probe({[21]=child,[22]=obj('Subfixture',22,101,2,parent)},
 {['101']={Dimmer={abs_preset=preset}}})
assert(r.classification=='UNPROVEN' and r.summary.collision>0)
r=probe({[101]=obj('Subfixture',101,101,'None')},{[101]={Dimmer={abs_preset=preset}}})
assert(r.classification=='UNPROVEN' and r.summary.ambiguous>0)
r=probe({[11]=obj('Subfixture',11,101,'None')},{})
assert(r.classification=='UNPROVEN' and r.summary.unmapped==1)
print('PASS cooked member key unique, child composite, duplicate FID, collision, ambiguity, unmapped')
