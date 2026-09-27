-- Mock only: no grandMA3 connection.
local count,logs,objects=0,{},{}
local function check(v,msg) assert(v,msg); count=count+1 end
local function obj(kind,addr)
 local h={kind=kind,addr=addr,children={},props={"ObjectIndex","TargetObject","Visible"}}
 objects[#objects+1]=h
 h.GetClass=function(self) return self.kind end
 h.ToAddr=function(self) return self.addr end
 h.AddrNative=function(self) return "Native."..self.addr end
 h.Get=function(self,k) return rawget(self,k) end
 h.Parent=function(self) return self.parent end
 h.Children=function(self) return self.children end
 h.UIChildren=function() return {} end
 h.Count=function(self) return #self.children end
 h.Ptr=function(self,i) return self.children[i] end
 h.GetUIChildrenCount=function(self) return #self.children end
 h.GetUIChild=function(self,i) return self.children[i] end
 h.PropertyCount=function(self) return #self.props end
 h.PropertyName=function(self,i) return self.props[i+1] end
 h.PropertyType=function() return "string" end
 return h
end
local root=obj("Display","Display 1")
local gp=obj("Window","Window 1"); gp.parent=root; root.children={gp}
local parent=obj("Container","Container 1"); parent.parent=gp; gp.children={parent}
local grid=obj("AllPoolLayoutGrid","Generator Grid"); grid.parent=parent; parent.children={grid}
local pool=obj("Generators","Generators"); grid.PoolObject=pool; grid.Pooltype="GeneratorRandom"
grid.IsVisible=function() return true end
local a=obj("AllPoolButton","Tile 103"); a.ObjectIndex=103; a.parent=grid; a.IsVisible=function() return true end
local b=obj("AllPoolButton","Tile 104"); b.ObjectIndex=104; b.parent=grid; b.IsVisible=a.IsVisible
grid.children={a,b}
local g103=obj("Random","Generator 103"); local g104=obj("Random","Generator 104")
pool.Ptr=function(_,i) return ({[103]=g103,[104]=g104})[i] end
a.TargetObject=g103
local group=obj("AllPoolLayoutGrid","Group Grid"); group.parent=parent; group.PoolObject=obj("Groups","Groups"); group.IsVisible=function() return true end
parent.children={grid,group}
local env=setmetatable({}, {__index=_G}); env._G=env
local forbidden=0
for _,k in ipairs({"ObjectList","Cmd","GetPresetData","GetPresetDataFast","SetProgPhaser","SetProgPhaserValue","HookObjectChange"}) do env[k]=function() forbidden=forbidden+1; error("forbidden") end end
env.BuildDetails=function() return {BigVersion="2.5.0.3"} end
env.IsObjectValid=function(h) return type(h)=="table" and h.kind~=nil end
env.HandleToStr=function(h) return "H#"..h.addr end
env.GetDisplayByIndex=function(i) if i==1 then return root end end
env.Printf=function(f,...) logs[#logs+1]=string.format(f,...) end
local run=assert(loadfile("diagnostics/UI_Topology_Probe_2_5_0_3.lua","t",env))()
local r=run(); local text=table.concat(logs,"\n")
check(forbidden==0,"called forbidden API")
check(text:find("IsActuallyVisible=UNAVAILABLE",1,true),"unavailable must be explicit")
check(text:find("Tile 103",1,true) and text:find("Tile 104",1,true),"Ptr/GetUIChild tiles missing with empty UIChildren")
check(text:find("address=Generator 103",1,true),"actual tile target missing")
check(text:find("relation=GENERATOR:parent",1,true) and text:find("relation=GENERATOR:grandparent",1,true),"ancestors missing")
check(text:find("GROUP_OR_PRESET_COMPARISON",1,true),"comparison grid missing")
check(text:find("name=TargetObject",1,true),"introspection metadata missing")
check(text:find("virtualization=UNVERIFIED",1,true),"invented virtualization")
check(r.inspected<=160 and #logs<=1101,"output unbounded")
-- Recursive topology and property/line caps.
local chain=a
for i=1,20 do local n=obj("Container","Deep "..i); chain.children={n}; n.parent=chain; chain=n end
logs={}; run(); text=table.concat(logs,"\n")
check(not text:find("class=Container address=Deep 6 ",1,true),"depth cap exceeded")
check(text:find("DEPTH_LIMIT",1,true),"depth cap not reported")
logs={}; pool.Ptr=function() return nil end; run(); text=table.concat(logs,"\n")
check(text:find("target={UNAVAILABLE}",1,true),"missing target must be explicit")
logs={}; grid.Count=nil; grid.GetUIChildrenCount=nil; grid.Children=function() return {} end; run(); text=table.concat(logs,"\n")
check(text:find("INDEXED_SAMPLE",1,true) and text:find("Tile 104",1,true),"count-unavailable Ptr sample missing")
env.BuildDetails=function() return {BigVersion="2.5.1.0"} end
check(not pcall(run),"wrong build accepted")
check(forbidden==0,"read-only requirement failed")
print("PASS: "..count.." UI topology assertions (MOCK ONLY)")
