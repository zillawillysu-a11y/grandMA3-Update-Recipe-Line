-- Mock-only discovery budget scenarios.
local checks,logs,forbidden=0,{},0
local function check(v,m) assert(v,m); checks=checks+1 end
local function obj(k,a)
 local h={kind=k,address=a,contents={},Visible=true}
 h.GetClass=function(s) return s.kind end
 h.ToAddr=function(s) return s.address end
 h.AddrNative=function(s) return 'Native.'..s.address end
 h.Get=function(s,k) return rawget(s,k) end
 h.Parent=function(s) return s.parent end
 h.UIChildren=function(s) return s.contents end
 h.Children=h.UIChildren
 h.GetUIChildrenCount=function(s) return #s.contents end
 h.GetUIChild=function(s,i) return s.contents[i] end
 h.Count=h.GetUIChildrenCount; h.Ptr=h.GetUIChild
 h.IsVisible=function(s) return s.Visible end
 return h
end
local function append(p,h) p.contents[#p.contents+1]=h; h.parent=p; return h end
local env=setmetatable({}, {__index=_G}); env._G=env
local roots={}
env.BuildDetails=function() return {BigVersion='2.5.0.3'} end
env.IsObjectValid=function(h) return type(h)=='table' and h.kind~=nil and h.valid~=false end
env.IsClassDerivedFrom=function(k,b) return b=='UIObject' and (k=='Display' or k=='Container' or k=='AllPoolLayoutGrid') end
env.HandleToStr=function(h) return h.address end
env.GetDisplayByIndex=function(i) return roots[i] end
env.Printf=function(f,...) logs[#logs+1]=string.format(f,...) end
for _,k in ipairs({'Cmd','CmdIndirect','GetPresetData','GetPresetDataFast','CompareHandle','ObjectList','HookObjectChange'}) do env[k]=function() forbidden=forbidden+1; error('forbidden') end end
local run=assert(loadfile('diagnostics/Discovery_Budget_Probe_2_5_0_3.lua','t',env))()
local function setup()
 logs={}; roots={}; env.RecipeTrackingInspectorState=nil
 roots[1]=obj('Display','Display 1'); roots[3]=obj('Display','Display 3')
 local g=append(roots[3],obj('AllPoolLayoutGrid','Grid 3')); g.Pooltype='GeneratorRandom'; g.PoolObject=obj('Database','Generators'); return g
end
local g=setup(); local r=run()
check(r.classification=='DISCOVERY_BUDGET_OK','small inventory agreement')
check(r.total==3 and r.per_display[1]==1 and r.per_display[3]==2,'display counts')
check(r.replay[g]~=nil and r.truth[g].visible==true,'visible target agreement')
-- Broad branches avoid the independent per-node child cap.
g=setup()
for i=1,10 do local p=append(roots[1],obj('Container','Branch '..i)); for j=1,700 do append(p,obj('Container','Leaf '..i..'.'..j)) end end
r=run()
check(r.classification=='DISCOVERY_BUDGET_MISS_CONFIRMED','later display budget miss')
check(r.total==6000 and r.budget_misses==1 and r.logic_misses==0,'budget causality count')
check(r.per_display[3]==0 and r.truth[g].visible==true,'later display starved')
check(table.concat(logs,'\n'):find('display=3 root_available=true production_nodes=0',1,true),'per-display starvation log')
check(table.concat(logs,'\n'):find('missed_reason=SHARED_6000_BUDGET',1,true),'grid causality log')
g=setup(); roots[3].UIChildren=function() return {} end; r=run()
check(r.classification=='DISCOVERY_LOGIC_MISMATCH' and r.logic_misses==1 and r.total<6000,'non-budget miss classified separately')
g=setup(); g.IsActuallyVisible=function() return false end; g.IsVisible=function() return true end; g.Visible=true; r=run()
check(r.classification=='UNVERIFIED','contradictory/hidden grid is not visible evidence')
g=setup(); local p=roots[3]; p.contents={}; for i=1,22 do p=append(p,obj('Container','Deep '..i)) end; append(p,g); r=run()
check(r.classification=='DISCOVERY_LOGIC_MISMATCH' and r.logic_misses==1,'production depth stop distinct from budget')
g=setup(); env.RecipeTrackingInspectorState={window=g,poolGrids={},poolGridRefreshNeeded=false}; r=run()
check(r.classification=='DISCOVERY_LOGIC_MISMATCH','production window exclusion preserved')
g=setup(); env.RecipeTrackingInspectorState={poolGrids={g},poolGridRefreshNeeded=false}; r=run()
check(r.cache_discover==false and r.classification=='DISCOVERY_BUDGET_OK','warm cache branch logged; replay stays cold')
env.RecipeTrackingInspectorState.poolGridRefreshNeeded=true; r=run()
check(r.cache_discover==true,'explicit rediscovery flag')
g=setup(); env.RecipeTrackingInspectorState={poolGrids={obj('Container','Invalid')}}; env.RecipeTrackingInspectorState.poolGrids[1].valid=false; r=run()
check(r.cache_discover==true,'invalid cache triggers discovery')
g=setup(); for i=1,1025 do append(roots[1],obj('Container','Wide '..i)) end; r=run()
check(r.classification=='UNVERIFIED','ground truth child cap fails closed')
g=setup(); g.Visible=nil; g.IsVisible=nil; r=run()
check(r.classification=='UNVERIFIED','unknown native visibility')
g=setup(); append(roots[1],obj('Database','DB')); r=run()
check(r.classification=='UNVERIFIED','UI API guard deviation invalidates exact replay')
g=setup(); local title=append(g,obj('Container','Tile children')); r=run()
check(r.total==3,'grid subtree stop preserves production node counting')
g=setup(); local focus=roots[1]; roots[1]=nil; env.GetFocusDisplay=function() return focus end; r=run()
check(r.total==2 and r.per_display[1]==0,'nil indexed display must not trigger focus fallback')
env.BuildDetails=function() return {BigVersion='2.5.1.0'} end
check(not pcall(run),'target version lock')
check(forbidden==0,'no forbidden API calls')
print('PASS: '..checks..' Discovery Budget assertions (MOCK ONLY)')
