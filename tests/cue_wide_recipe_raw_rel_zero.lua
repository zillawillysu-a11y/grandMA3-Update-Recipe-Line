local f=assert(io.open('tools/templates/cue_wide_recipe_raw_rel_zero.lua'))
local source=f:read('*a'); f:close()
local newAudit=assert(load(source..'\nreturn newRawRelZeroAudit'))()
local function object(kind,id,props)
 local h={kind=kind,id=id,props=props or {}}
 function h:Get(k) return self[k] end
 return h
end
local function meta(h)
 local m={}
 for _,k in ipairs(h.props) do m[k:lower()]={raw=h[k],type=type(h[k])} end
 return m
end
local audit=newAudit({safe=function(fn) local ok,v=pcall(fn); if ok then return v end end,
 isObject=function(h) return type(h)=='table' and h.kind~=nil end,
 class=function(h) return h.kind end,identity=function(h) return h.id end,
 metadata=meta,raw={},ordinary=function() error('unexpected reference read') end,
 joined=function(t) local a={} for k in pairs(t or {}) do a[#a+1]=k end return table.concat(a,',') end})
local cases={
 {'', 'REL_AMBIGUOUS'},
 {'None','REL_NOT_AUTHORED_PROVEN'},
 {0,'REL_AMBIGUOUS'},
 {10,'REL_AUTHORED_PROVEN'},
}
for i,c in ipairs(cases) do
 local h=object('PhaserRecipeValueSource','source-'..i,{'RawValueAbs','RawValueRel','ValueRelative','Layer'})
 h.RawValueAbs=100; h.RawValueRel=c[1]; h.ValueRelative=0; h.Layer='Absolute'
 assert(audit.observe(h,1,nil)==c[2],tostring(c[1]))
end
assert(#audit.patterns==4 and audit.states.REL_AMBIGUOUS==2)
assert(audit.patterns[3].relative:find('number:0',1,true) and audit.patterns[3].layer:find('Absolute',1,true))
print('PASS Rev7 raw REL zero remains ambiguous despite getter zero and opposite Layer label')
