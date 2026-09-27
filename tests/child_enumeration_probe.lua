-- Mock-only child paths: no native connection or production change.
local assertions,logs,uiErrors,forbidden=0,{},0,0
local function check(v,msg) assert(v,msg); assertions=assertions+1 end
local function object(k,a)
 local h={kind=k,address=a,contents={},Visible=true}
 h.GetClass=function(self) return self.kind end
 h.ToAddr=function(self) return self.address end
 h.AddrNative=function(self) return "Native."..self.address end
 h.Parent=function(self) return self.parent end
 h.Get=function(self,key) return rawget(self,key) end
 h.Children=function(self) return self.contents end
 h.Count=function(self) return #self.contents end
 h.Ptr=function(self,i) return self.contents[i] end
 local function ui(self) if not self.kind:find("AllPool",1,true) and self.kind~="Display" and self.kind~="Container" then uiErrors=uiErrors+1; error("non-UI handle") end end
 h.UIChildren=function(self) ui(self); return self.contents end
 h.GetUIChildrenCount=function(self) ui(self); return #self.contents end
 h.GetUIChild=function(self,i) ui(self); return self.contents[i] end
 h.IsVisible=function(self) ui(self); return self.Visible end
 h.FindRecursive=function(self,_,wanted)
  local function walk(n) if n.kind==wanted then return n end; for _,c in ipairs(n.contents) do local r=walk(c); if r then return r end end end
  return walk(self)
 end
 return h
end
local env=setmetatable({}, {__index=_G}); env._G=env
local grid,root
for _,key in ipairs({"Cmd","CmdIndirect","GetPresetData","GetPresetDataFast","CompareHandle","ObjectList","SetProgPhaser","SetProgPhaserValue","HookObjectChange"}) do env[key]=function() forbidden=forbidden+1; error("forbidden") end end
env.BuildDetails=function() return {BigVersion="2.5.0.3"} end
env.IsObjectValid=function(h) return type(h)=="table" and h.kind~=nil and h.valid~=false end
env.HandleToStr=function(h) return "H#"..h.address end
env.IsClassDerivedFrom=function(k,base)
 if base=="UIObject" then return k:find("AllPool",1,true)~=nil or k=="Display" or k=="Container" end
 return base=="AllPoolButton" and (k=="AllPoolButton" or k=="AllPoolTitleButton")
end
env.GetDisplayByIndex=function(i) if i==3 then return root end end
env.FromAddr=function() return grid end
env.Printf=function(f,...) logs[#logs+1]=string.format(f,...) end
local run=assert(loadfile("diagnostics/Child_Enumeration_Probe_2_5_0_3.lua","t",env))()
local function setup(poolKind)
 logs={}
 root=object("Display","Display 3")
 grid=object("AllPoolLayoutGrid","Grid"); grid.parent=root; root.contents={grid}
 grid.Pooltype=poolKind or "GeneratorRandom"; grid.PoolObject=object(poolKind or "Generators","Pool")
 local a=object("AllPoolButton","Tile A"); a.ObjectIndex=103; a.parent=grid
 local b=object("AllPoolButton","Tile B"); b.ObjectIndex=104; b.parent=grid
 local title=object("AllPoolTitleButton","Title"); title.ObjectIndex=1; title.parent=grid
 grid.contents={title,a,b}
end
setup(); local r=run()[1]
check(r.classification=="CHILD_PATHS_AGREE" and r.production_miss==false,"equivalent paths must agree")
check(r.paths[1].usable==2,"title must not be a usable button")
check(r.paths[1].count==3 and r.paths[3].count==3,"raw child counts missing")
setup(); grid.UIChildren=function() return {} end; r=run()[1]
check(r.classification=="EMPTY_UICHILDREN_FALLBACK_NEEDED" and r.production_miss==true,"empty UIChildren native-shaped risk missing")
check(r.production_path=="UIChildren" and r.paths[1].usable==0,"production incorrectly fell back on empty table")
setup(); grid.UIChildren=function(self) return {self.contents[2]} end; r=run()[1]
check(r.classification=="CHILD_PATH_MISMATCH" and r.production_miss==true,"material missing button not detected")
setup(); grid.Children=function(self) return {self.contents[1],self.contents[2]} end; r=run()[1]
check(r.classification=="CHILD_PATH_MISMATCH" and r.production_miss==false,"production already has all usable UI buttons")
setup(); grid.UIChildren=nil; r=run()[1]
check(r.classification=="UNVERIFIED" and r.production_path=="Children","unavailable UIChildren must emulate production fallback")
setup(); grid.GetUIChildrenCount=nil; r=run()[1]
check(r.classification=="UNVERIFIED","unknown path must not claim all paths agree")
setup(); grid.contents={}; r=run()[1]
check(r.classification=="UNVERIFIED","empty grid cannot establish usable equivalence")
setup(); grid.Visible=false
check(#run()==0 and table.concat(logs,"\n"):find("NOT_CONFIRMED_VISIBLE",1,true),"hidden grid must not be evaluated as visible")
setup(); root.Visible=false
check(#run()==0,"hidden ancestor must exclude grid")
for _,k in ipairs({"Groups","Presets","CustomPhaserPresets"}) do
 setup(k); r=run()[1]
 check(r.classification=="CHILD_PATHS_AGREE","probe must not filter Generator-only grids")
end
setup(); for i=4,214 do local b=object("AllPoolButton","More "..i); b.ObjectIndex=i; b.parent=grid; grid.contents[i]=b end; r=run()[1]
check(r.classification=="CHILD_PATHS_AGREE" and r.paths[1].count==214,"211+ children must be supported")
setup(); local db=object("Database","DB child"); grid.contents[4]=db; r=run()[1]
check(r.classification=="CHILD_PATHS_AGREE" and uiErrors==0,"database child must never receive UI APIs")
setup(); grid.GetUIChild=function(self,i) if i==2 then return nil end; return self.contents[i] end; r=run()[1]
check(r.classification=="UNVERIFIED","incomplete indexed path must not claim agreement")
setup(); grid.GetUIChildrenCount=function() return 1000 end; r=run()[1]
check(r.classification=="UNVERIFIED" and not r.paths[3].complete,"path cap must fail closed for agreement")
setup(); env.BuildDetails=function() return {BigVersion="2.5.1.0"} end
check(not pcall(run),"wrong build accepted")
check(forbidden==0 and uiErrors==0,"probe called forbidden/non-UI API")
print("PASS: "..assertions.." Child Enumeration assertions (MOCK ONLY)")
