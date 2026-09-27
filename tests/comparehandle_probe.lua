-- MOCK ONLY. Never connects to MA or establishes native reliability.
local count=0
local logs={}
local function check(v,msg) assert(v,msg); count=count+1 end
local objects,seq,cue,recipe,expected,alias,other,grid,mutations,tick
local function object(kind,address,id,native)
    local h={kind=kind,address=address,id=id or address,native=native or address,children={}}
    h.GetClass=function(self) return self.kind end
    h.Children=function(self) return self.children end
    h.UIChildren=h.Children
    h.Get=function(self,key) return rawget(self,key) end
    h.ToAddr=function(self) return self.address end
    h.AddrNative=function(self) return self.native end
    h.Parent=function(self) return self.parent end
    h.FindParent=function(self)
        local p=self.parent; while p do if p.kind=="DataPool" then return p end; p=p.parent end
    end
    h.CmdlineIndex=function() return 103 end
    objects[address]=h; return h
end
local env=setmetatable({}, {__index=_G}); env._G=env
env.BuildDetails=function() return {BigVersion="2.5.0.3"} end
env.Root=function() return {id="ROOT"} end
env.IsObjectValid=function(h) return type(h)=="table" and h.id~=nil and h.valid~=false end
env.CompareHandle=function(a,b) return a.id==b.id end
env.ObjectList=function(a) return objects[a] and {objects[a]} or {} end
env.HandleToStr=function(h) return "H#"..h.id end
env.SelectedSequence=function() return seq end
env.GetCurrentCue=function() return cue end
env.Time=function() tick=tick+0.00001; return tick end
env.Printf=function(fmt,...) logs[#logs+1]=string.format(fmt,...) end
env.GetDisplayByIndex=function(i) if i==1 then return object("Display","Display 1",nil,nil) end end
for _,key in ipairs({"Cmd","CmdIndirect","GetPresetData","GetPresetDataFast","SetProgPhaser","SetProgPhaserValue","HookObjectChange"}) do
    env[key]=function() mutations=mutations+1; error("forbidden API") end
end
local run=assert(loadfile("diagnostics/CompareHandle_Probe_2_5_0_3.lua","t",env))()
local function setup()
    objects={}; mutations=0; tick=0; logs={}
    local dp=object("DataPool","DataPool 1")
    seq=object("Sequence","Sequence 14"); seq.parent=dp
    cue=object("Cue","Sequence 14 Cue 1"); cue.parent=seq
    local part=object("Part","Sequence 14 Cue 1 Part 0"); part.parent=cue; cue.children={part}
    recipe=object("StandardRecipe","Recipe 1"); recipe.parent=part; part.children={recipe}; recipe.Enabled="Yes"
    expected=object("Random","Generator 103","G103","Native.Recipe.Random.103")
    alias=object("GeneratorRandom","Random 103","G103","Native.Pool.Generators.103")
    other=object("Random","Generator 104","G104"); recipe.Generator=expected
    local pool=object("Generators","Generator Pool"); pool.parent=dp; expected.parent=pool; alias.parent=pool; other.parent=pool
    pool.Ptr=function(_,idx) return ({alias,other})[idx] end
    local a=object("AllPoolButton","Tile 103"); a.ObjectIndex=1
    local b=object("AllPoolButton","Tile 104"); b.ObjectIndex=2
    local title=object("AllPoolTitleButton","Title"); title.ObjectIndex=1
    local empty=object("AllPoolButton","Empty"); empty.ObjectIndex=3
    for _,h in ipairs({a,b,empty}) do h.IsActuallyVisible=function() return true end end
    grid=object("AllPoolLayoutGrid","Generator Grid"); grid.PoolObject=pool; grid.Pooltype="GeneratorRandom"; grid.children={a,b,title,empty}
    grid.IsActuallyVisible=function() return true end
    local display=object("Display","Display 1"); display.children={grid}
    env.GetDisplayByIndex=function(i) if i==1 then return display end end
end
local function controlled()
    local r=run(nil,{expected_generator="Generator 103",other_generator="Generator 104"})
    check(mutations==0,"probe called cooked data or mutation API")
    return r
end
setup(); local r=controlled()
check(#r.refs==1 and #r.tiles==2,"must use actual UI tiles and skip title/empty slots")
check(r.pairs[1].cold==true and r.pairs[1].warm==true and r.pairs[1].reverse==true,"alias identity lost")
check(r.refs[1].metadata.address~=r.tiles[1].metadata.address and r.refs[1].metadata.native~=r.tiles[1].metadata.native,"fixture must exercise both different addresses")
check(r.pairs[2].cold==false,"different Generator wrongly matches")
check(r.status=="CONTROLLED_PAIR_PASS_NATIVE_CONFIRMATION_REQUIRED","controls should pass")
check(r.pairs[1].cold_ms~=nil and r.pairs[1].warm_ms~=nil,"timings missing")
check(r.refs[1].other_equal==false and r.refs[1].expected_equal==true,"ground truth controls missing")
setup(); recipe.Generator="Generator 103"; r=controlled()
check(r.refs[1].raw_type=="string" and r.pairs[1].cold==true,"string property not resolved")
setup(); recipe.Generator=nil; recipe.Values=expected; r=controlled()
check(r.refs[1].field=="Values","legacy Generator-in-Values path missing")
setup(); recipe.Enabled="No"; r=controlled()
check(r.refs[1].enabled=="No" and r.pairs[1].cold==true,"identity should not imply enabled/active")
setup(); r=run(nil,nil)
check(r.status=="UNVERIFIED","equality without truth must not claim pass")
setup(); grid.IsActuallyVisible=function() return false end; r=controlled()
check(#r.tiles==0 and r.status=="UNVERIFIED","hidden grid should not provide UI evidence")
setup(); grid.IsActuallyVisible=nil; r=controlled()
check(#r.tiles==0 and #r.errors>0,"unknown visibility silently accepted")
setup(); env.GetDisplayByIndex=nil
r=run(nil,{pool_addresses={"Random 103"},expected_generator="Generator 103",other_generator="Generator 104"})
check(r.tiles[1].origin:find("not UI tile evidence",1,true)~=nil,"ObjectList path mislabeled as tile")
setup(); r=run(nil,{recipe_addresses={"Recipe 1"},expected_generator="missing",other_generator="Generator 104"})
check(#r.errors>0 and r.status=="UNVERIFIED","invalid control accepted")
setup(); env.CompareHandle=function() error("comparison unavailable") end; r=controlled()
check(r.status~="CONTROLLED_PAIR_PASS_NATIVE_CONFIRMATION_REQUIRED","API failure accepted")
env.CompareHandle=function(a,b) return a.id==b.id end
setup(); alias.id="G999"; r=controlled()
check(r.status=="CONTROLLED_PAIR_FAIL","wrong target did not fail")
setup(); r=run(nil,{expected_generator="Generator 103",other_generator="Random 103"})
check(#r.errors>0,"same positive/negative identity accepted")
setup(); recipe.Generator="unresolved address"; r=controlled()
check(#r.refs==0 and #r.errors>0,"unresolved Recipe link ignored")
setup(); other.address=expected.address; other.native=expected.native; r=controlled()
check(r.pairs[2].cold==false,"same address/index text must never override distinct identity")
setup()
local firstCompare=env.CompareHandle; local calls=0
env.CompareHandle=function(a,b)
    if a.id==expected.id and b==alias then calls=calls+1; return calls==1 end
    return firstCompare(a,b)
end
r=controlled()
check(not r.pairs[1].stable and r.status=="CONTROLLED_PAIR_FAIL","unstable comparisons accepted")
env.CompareHandle=firstCompare
setup(); alias.valid=false; r=controlled()
check(#r.errors>0 and r.status=="UNVERIFIED","invalid tile handle accepted")
setup(); env.Time=nil; r=controlled()
check(r.pairs[1].cold_ms==nil,"missing timer fabricated zero")
env.Time=function() tick=tick+0.00001; return tick end
setup(); env.BuildDetails=function() return {BigVersion="2.5.1.0"} end
check(not pcall(run,nil,nil),"wrong build accepted")
env.BuildDetails=function() return {BigVersion="2.5.0.3"} end
setup(); r=controlled()
check(r.tiles[1].widget.object~=r.tiles[1].object,"widget conflated with database target")
check(r.widgets[1].metadata.class=="AllPoolButton" and r.tiles[1].metadata.class=="GeneratorRandom","widget/target metadata missing")
check(r.widgets[1].target_index==1 and r.widgets[2].target_index==2,"widget/target cross references missing")
check(r.ui_targets==2 and r.alias_status=="UI_ALIAS_EQUALITY_OBSERVED","UI alias evidence missing")
check(r.widgets[3].extraction=="NO_TARGET_HANDLE","empty/missing target must be explicit")
check(table.concat(logs,"\n"):find("UI_TILE",1,true) and table.concat(logs,"\n"):find("ui_evidence=true",1,true),"logs must distinguish widget and target")
setup(); grid.PoolObject.kind="UnexpectedPoolClass"; grid.Pooltype=nil; r=controlled()
check(#r.tiles==2,"assumed pool class must not block production extraction path")
setup(); grid.UIChildren=nil; r=controlled()
check(#r.tiles==2,"production Children fallback missing")
setup(); grid.IsActuallyVisible=function() return "Yes" end; r=controlled()
check(#r.tiles==2,"production visibility normalization missing")
setup(); grid.children[1].IsActuallyVisible=function() return false end; r=controlled()
check(r.ui_targets==1 and r.status~="CONTROLLED_PAIR_PASS_NATIVE_CONFIRMATION_REQUIRED","hidden tile accepted")
setup(); grid.children[1].IsActuallyVisible=nil; r=controlled()
check(r.widgets[1].extraction=="WIDGET_VISIBILITY_UNVERIFIED_OR_HIDDEN","unknown tile visibility accepted")
setup(); grid.PoolObject.Ptr=function() return nil end
r=run(nil,{pool_addresses={"Generator 103","Generator 104"},expected_generator="Generator 103",other_generator="Generator 104"})
check(r.ui_targets==0 and r.status=="UNVERIFIED_NO_UI_EVIDENCE","ObjectList cannot fake UI success")
check(#r.widgets==3 and r.widgets[1].extraction=="NO_TARGET_HANDLE","missing extraction not reported")
setup(); grid.children={grid.children[1]}; r=controlled()
check(r.status=="CONTROLLED_PAIR_FAIL","visible negative control required")
setup(); alias.address=expected.address; alias.native=expected.native; r=controlled()
check(r.alias_status=="NOT_OBSERVED","same-text UI test must not claim alias tested")
print("PASS: "..count.." CompareHandle probe assertions (MOCK ONLY)")
