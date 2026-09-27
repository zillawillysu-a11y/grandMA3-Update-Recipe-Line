-- Mock-only lifecycle fixtures; no grandMA3 connection.
local count,logs,uiErrors,forbidden=0,{},0,0
local function check(v,m) assert(v,m); count=count+1 end
local function uiKind(k) return k=="Display" or k=="Container" or k=="AllPoolLayoutGrid" or k=="AllPoolButton" end
local objects={}
local function object(k,a,id)
 local h={kind=k,address=a,id=id or a,contents={},Visible=true,props={}}
 objects[#objects+1]=h
 h.GetClass=function(self) return self.kind end
 h.ToAddr=function(self) return self.address end
 h.AddrNative=function(self) return "Native."..self.address end
 h.Parent=function(self) return self.parent end
 h.Get=function(self,key) return rawget(self,key) end
 h.Children=function(self) return self.contents end
 h.Count=function(self) return #self.contents end
 h.Ptr=function(self,i) return self.contents[i] end
 local function ui(self) if not uiKind(self.kind) then uiErrors=uiErrors+1; error("non-UI call") end end
 h.UIChildren=function(self) ui(self); return self.contents end
 h.GetUIChildrenCount=function(self) ui(self); return #self.contents end
 h.GetUIChild=function(self,i) ui(self); return self.contents[i] end
 h.IsVisible=function(self) ui(self); return self.Visible end
 h.FindRecursive=function(self,_,kind)
  local function walk(n) if n.kind==kind then return n end; for _,c in ipairs(n.contents) do local r=walk(c); if r then return r end end end
  return walk(self)
 end
 return h
end
local env=setmetatable({}, {__index=_G}); env._G=env
local display,grid,pool,parent,old,new
for _,k in ipairs({"ObjectList","Cmd","CmdIndirect","GetPresetData","GetPresetDataFast","SetProgPhaser","SetProgPhaserValue","HookObjectChange"}) do env[k]=function() forbidden=forbidden+1; error("forbidden") end end
env.IsObjectValid=function(h) return type(h)=="table" and h.id~=nil and h.valid~=false end
env.IsClassDerivedFrom=function(k,base) return base=="UIObject" and uiKind(k) end
env.CompareHandle=function(a,b) return a.id==b.id end
env.BuildDetails=function() return {BigVersion="2.5.0.3"} end
env.HandleToStr=function(h) return "H#"..h.id end
env.GetDisplayByIndex=function(i) if i==3 then return display end end
env.FromAddr=function(a) if grid and a==grid.address then return grid end end
env.Printf=function(f,...) logs[#logs+1]=string.format(f,...) end
local run=assert(loadfile("diagnostics/Recall_View_Observer_2_5_0_3.lua","t",env))()
local function makeGrid(id)
 local g=object("AllPoolLayoutGrid","Display 3.5.3.1.5.1.4.4",id)
 g.PoolObject=pool; g.parent=parent
 for _,idx in ipairs({103,104}) do
  local b=object("AllPoolButton","Tile "..idx,id.."tile"..idx); b.parent=g; b.ObjectIndex=idx; g.contents[#g.contents+1]=b
 end
 return g
end
local function setup()
 env.DiDiDoRecallLifecycleObserver2503=nil; logs={}
 display=object("Display","Display 3"); parent=object("Container","Window"); parent.parent=display; display.contents={parent}
 pool=object("Generators","Generator Pool")
 local a,b=object("Random","Generator 103"),object("Random","Generator 104")
 pool.Ptr=function(_,i) return ({[103]=a,[104]=b})[i] end
 grid=makeGrid("OLD"); parent.contents={grid}; old=grid
end
setup(); local r=run()
check(r.phase=="BEFORE" and r.before.cache_accept==true,"before not saved")
check(r.before.buttons[103].target.address=="Generator 103","103 target missing")
check(table.concat(logs,"\n"):find("PAUSE manually Recall",1,true),"manual pause prompt missing")
check(forbidden==0 and uiErrors==0,"readonly/type safety failed")
old.Visible=false; grid=makeGrid("NEW"); parent.contents={grid}
r=run()
check(r.classification=="LIFECYCLE_STALE_CACHE_CONFIRMED","valid hidden old cache must confirm")
check(r.equal==false and r.old.cache_accept==true and r.new.buttons[104],"old/new comparison missing")
check(env.DiDiDoRecallLifecycleObserver2503==nil,"after state must reset")
check(table.concat(logs,"\n"):find("SAVED_TARGET_AFTER:103",1,true),"retained target revalidation missing")
setup(); run(); old.valid=false; grid=makeGrid("NEW"); parent.contents={grid}; r=run()
check(r.classification=="LIFECYCLE_NOT_REPRODUCED" and r.old.cache_accept==false,"invalid old grid must reject")
setup(); run(); old.IsActuallyVisible=function() return false end; old.Visible=false; grid=makeGrid("NEW"); parent.contents={grid}; r=run()
check(r.classification=="LIFECYCLE_NOT_REPRODUCED","actual false should rediscover")
setup(); run(); r=run()
check(r.classification=="UNVERIFIED" and r.equal==true,"unchanged grid cannot prove lifecycle replacement")
setup(); run(); parent.Visible=false; r=run()
check(r.classification=="LIFECYCLE_STALE_CACHE_CONFIRMED","hidden ancestor must demonstrate stale cache")
setup(); grid.contents[2]=nil; r=run()
check(r.classification=="UNVERIFIED" and env.DiDiDoRecallLifecycleObserver2503==nil,"missing control must not begin")
setup(); grid.IsActuallyVisible=function() return true end; r=run()
check(r.before.cache_accept==true,"actual true acceptance wrong")
run(nil,"reset"); check(env.DiDiDoRecallLifecycleObserver2503==nil,"reset must only clear observer state")
setup(); run(); old.Visible=nil; old.IsVisible=function() return nil end; grid=makeGrid("NEW"); parent.contents={grid}; r=run()
check(r.classification=="LIFECYCLE_STALE_CACHE_CONFIRMED","different unique new grid with unknown old visibility should confirm")
setup(); run(); grid=makeGrid("NEW"); parent.contents={grid}; r=run()
check(r.classification=="LIFECYCLE_STALE_CACHE_CONFIRMED" and r.old.parent_membership==false,"valid old grid removed from parent must confirm despite stale Visible=true")
setup(); grid.IsActuallyVisible=function() return "Yes" end; r=run()
check(r.before.cache_accept==true,"production Yes normalization mismatch")
setup(); run(); grid=makeGrid("NEW"); parent.contents={old,grid}; r=run()
check(r.classification=="UNVERIFIED","multiple visible grids must not invent replacement")
setup(); env.BuildDetails=function() return {BigVersion="2.5.1.0"} end
check(not pcall(run),"wrong version accepted")
check(forbidden==0 and uiErrors==0,"probe mutated Show or traversed database")
env.BuildDetails=function() return {BigVersion="2.5.0.3"} end
setup(); run(); local reloaded=assert(loadfile("diagnostics/Recall_View_Observer_2_5_0_3.lua","t",env))()
old.Visible=false; grid=makeGrid("NEW"); parent.contents={grid}; r=reloaded()
check(r.phase=="AFTER" and r.classification=="LIFECYCLE_STALE_CACHE_CONFIRMED","same diagnostic memory must survive component re-evaluation")

-- Exact reported replacement shape: NEW 211 children, controls beyond old 128 cap.
setup(); run(); old.valid=false; grid=makeGrid("NEW211"); parent.contents={grid}
local control103,control104=grid.contents[1],grid.contents[2]
grid.contents={}
for i=1,211 do
 local b=object("AllPoolButton","Extra "..i,"extra"..i); b.ObjectIndex=i+200; b.parent=grid; grid.contents[i]=b
end
grid.contents[150]=control103; grid.contents[151]=control104
r=run()
check(r.old.valid==false and r.old.cache_accept==false and r.new.ui_count==211,"native replacement fixture incorrect")
check(r.classification=="LIFECYCLE_NOT_REPRODUCED" and not r.capped,"211 children must not veto invalid OLD evidence")
check(r.new.buttons[103] and r.new.buttons[104],"controls beyond 128 must be found by ObjectIndex")
check(r.new.controlled_examined<211,"stop as soon as both controls found")
check(r.new.buttons[103].target.object==pool:Ptr(103),"saved/new database target identity lost")
-- Child position is deliberately not ObjectIndex; no fabricated Ptr offset.
check(r.new.buttons[103].object==control103 and r.new.buttons[104].object==control104,"lookup guessed positional mapping")
check(table.concat(logs,"\n"):find("cap_reasons=NONE",1,true),"cap reason metrics missing")
-- Optional sibling inventory limit must not override a rejected OLD grid.
setup(); run(); old.valid=false; grid=makeGrid("NEW_PARENT211"); parent.contents={grid}
for i=2,211 do parent.contents[i]=object("Container","Sibling "..i,"sib"..i) end
r=run()
check(r.classification=="LIFECYCLE_NOT_REPRODUCED" and r.inventory_limited and not r.capped,"noncritical sibling inventory must not force UNVERIFIED")
check(forbidden==0 and uiErrors==0,"diagnostic safety changed")
print("PASS: "..count.." Recall lifecycle assertions (MOCK ONLY)")
