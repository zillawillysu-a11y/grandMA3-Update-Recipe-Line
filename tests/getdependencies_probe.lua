-- Offline fixtures describe possible database graphs, NOT observations of MA.
local count=0
local function check(value,message)
    assert(value,message); count=count+1
end
local seq,cue,objects,forbidden,clock,reads
local function object(kind,addr,id)
    local h={kind=kind,addr=addr,id=id or addr,deps={},children={}}
    h.GetClass=function(self) return self.kind end
    h.Children=function(self) return self.children end
    h.GetDependencies=function(self)
        reads[self.id]=(reads[self.id] or 0)+1
        clock=clock+(reads[self.id]==1 and 0.002 or 0.001)
        if self.fail then error("dependency read failed") end
        return self.deps
    end
    h.ToAddr=function(self) return self.addr end
    h.AddrNative=function(self) return "Native."..self.id end
    h.Parent=function(self) return self.parent end
    h.FindParent=function(self,kindName)
        local parent=self.parent
        while parent do if parent.kind==kindName then return parent end; parent=parent.parent end
    end
    h.Index=function() return 1 end
    h.Get=function(self,key) return rawget(self,key) end
    objects[addr]=h
    return h
end
local env=setmetatable({}, {__index=_G})
env._G=env
env.BuildDetails=function() return {BigVersion="2.5.0.3"} end
env.Root=function() return {id="ROOT"} end
env.SelectedSequence=function() return seq end
env.GetCurrentCue=function() return cue end
env.IsObjectValid=function(h) return type(h)=="table" and h.id~=nil end
env.CompareHandle=function(a,b) return a.id==b.id end
env.HandleToStr=function(h) return "H#"..h.id end
env.ObjectList=function(addr) return objects[addr] and {objects[addr]} or {} end
env.Time=function() return clock end
env.Printf=function() end
for _,name in ipairs({"GetPresetData","GetPresetDataFast","Cmd","CmdIndirect","CmdIndirectWait",
    "SetProgPhaser","SetProgPhaserValue","SelectionNotifyObject","CreateUndo","CloseUndo","HookObjectChange"}) do
    env[name]=function() forbidden=forbidden+1; error("forbidden API "..name) end
end
local run=assert(loadfile("diagnostics/GetDependencies_Probe_2_5_0_3.lua","t",env))()
local function setup()
    objects={}; forbidden=0; clock=0; reads={}
    local dp=object("DataPool","DataPool 1")
    local pool=object("Presets","PresetPool 1"); pool.parent=dp
    seq=object("Sequence","Sequence 1"); seq.parent=dp
    cue=object("Cue","Sequence 1 Cue 2"); cue.No=2000; cue.parent=seq
    local part=object("Part","Sequence 1 Cue 2 Part 0"); part.Part=0; part.parent=cue; cue.children={part}
    local preset=object("Preset","Preset 1.1"); preset.parent=pool
    return part,preset
end
local function find(report,label)
    for _,g in ipairs(report.graphs) do if g.label==label then return g end end
    error("missing graph "..label)
end
local function expectedReport(id,expected,excluded,history)
    local report=run(nil,{id=id,history_cues=history,expectations={
        ["current:cue"]={expected=expected,excluded=excluded,exhaustive=true},
        ["current:part:0"]={expected=expected,excluded=excluded,exhaustive=true}}})
    check(forbidden==0,"probe invoked mutation or cooked API")
    check(report.conclusion=="PARTIAL ONLY","probe must not infer native suitability")
    return report,find(report,"current:part:0")
end

local part,preset=setup()
local row=object("StandardRecipe","Recipe 1"); row.parent=part; row.Values=preset; row.Enabled="Yes"
row.deps={preset}; part.children={row}; part.deps={preset}; cue.deps={preset}
local report,g=expectedReport("direct_recipe",{"Preset 1.1"},{})
check(#g.cold_checks.matches==1 and #g.cold_checks.missing==0,"direct reference lost")
check(find(report,"current:part:0:recipe:1").recipe_fields.Enabled=="Yes","recipe ingredients lost")
check(g.cold.elapsed_ms~=nil and g.warm.elapsed_ms~=nil,"timing unavailable")
check(g.cold.nodes[2].metadata.pool=="DataPool 1","pool metadata missing")

part,preset=setup()
local old=object("Cue","Sequence 1 Cue 1"); old.No=1000; old.parent=seq
local oldPart=object("Part","Sequence 1 Cue 1 Part 0"); oldPart.Part=0; oldPart.parent=old; old.children={oldPart}; oldPart.deps={preset}
report,g=expectedReport("inherited_recipe",{"Preset 1.1"},{},{"Sequence 1 Cue 1"})
check(#g.cold_checks.missing==1,"database-only graph must expose inherited omission")
check(#find(report,"history:1:part:0").cold.edges==1,"history graph unavailable")
check(#g.cold.edges==0,"history refs must never be merged into current graph")

part,preset=setup()
local static=object("Preset","Preset 1.2"); part.deps={preset,static}; cue.deps=part.deps
report,g=expectedReport("static_override",{"Preset 1.2"},{"Preset 1.1"})
check(#g.cold_checks.false_positive==1,"stale overridden dependency not detected")

part,preset=setup(); part.deps={preset}; cue.deps={preset}
report,g=expectedReport("release",{},{"Preset 1.1"})
check(#g.cold_checks.false_positive==1,"released database ref must not imply active")

part,preset=setup()
row=object("StandardRecipe","Disabled Recipe"); row.Enabled="No"; row.deps={preset}; part.children={row}; part.deps={preset}; cue.deps={preset}
report,g=expectedReport("disabled_recipe",{},{"Preset 1.1"})
check(#g.cold_checks.false_positive==1,"disabled Recipe ref must not imply active")
check(find(report,"current:part:0:recipe:1").recipe_fields.Enabled=="No","disabled ingredient lost")

part,preset=setup()
local phaser=object("PhaserRecipe","PhaserRecipe 1"); local shape=object("Shape","Shape 1")
preset.deps={phaser}; phaser.deps={shape}; part.deps={preset}; cue.deps={preset}
report,g=expectedReport("phaser_recipe",{"Preset 1.1"},{})
check(#g.cold.edges==3,"nested dependencies were flattened or lost")
check(g.cold.nodes[3].candidate_kind=="recipe_structure","PhaserRecipe conflated with Pool Preset")
check(#g.cold_checks.false_positive==0,"structural Shape falsely classified as pool candidate")

part,preset=setup()
local generator=object("Random","Generator 103","GEN103")
local alias=object("Random","Random 103","GEN103")
part.deps={alias}; cue.deps={alias}
report,g=expectedReport("generator_random",{"Generator 103"},{})
check(#g.cold_checks.matches==1,"CompareHandle must match address aliases")

part,preset=setup()
local part1=object("Part","Sequence 1 Cue 2 Part 1"); part1.Part=1; part1.parent=cue; part1.deps={preset}
cue.children={part,part1}; cue.deps={preset}
report,g=expectedReport("multi_part",{},{})
check(#g.cold.edges==0 and #find(report,"current:part:1").cold.edges==1,"Part graphs incorrectly merged")

part,preset=setup()
report,g=expectedReport("empty_part",{},{})
check(g.cold.complete and #g.cold_checks.missing==0 and #g.cold_checks.false_positive==0,"explicit empty truth failed")
local unconfigured=run(nil,"empty_part")
check(find(unconfigured,"current:part:0").cold_checks.status=="UNVERIFIED","unconfigured empty truth falsely passes")

part,preset=setup(); part.deps={preset,preset}; preset.deps={part}; cue.deps={preset}
report,g=expectedReport("duplicate_reference",{"Preset 1.1"},{})
check(#g.cold.nodes==2 and #g.cold.edges==3,"duplicate edges or cycle lost")
check(#g.cold_checks.matches==1 and g.stable,"duplicate references must deduplicate by handle")

part,preset=setup(); part.fail=true
report,g=expectedReport("api_failure",{"Preset 1.1"},{})
check(not g.cold.complete and g.cold_checks.status=="INCOMPLETE","API failure mistaken for empty graph")
part,preset=setup(); part.deps={{preset}}
report,g=expectedReport("nested_lua_table",{"Preset 1.1"},{})
check(not g.cold.complete,"unexpected nested Lua arrays silently flattened")
part,preset=setup(); part.deps={preset}
report=run(nil,{id="unresolved_truth",expectations={["current:part:0"]={expected={"missing object"}}}})
check(find(report,"current:part:0").cold_checks.status=="INVALID_GROUND_TRUTH","unresolved truth accepted")
part,preset=setup()
local originalTime=env.Time; env.Time=nil
report=run(nil,{id="no_clock"})
check(find(report,"current:part:0").cold.elapsed_ms==nil,"missing timer must not fabricate zero")
env.Time=originalTime
env.BuildDetails=function() return {BigVersion="2.5.1.0"} end
local ok=pcall(run,nil,"direct_recipe")
check(not ok,"non-target version accepted")
env.BuildDetails=function() return {BigVersion="2.5.0.3"} end
part,preset=setup()
local savedCompare=env.CompareHandle; env.CompareHandle=function() error("compare unsupported") end
report=run(nil,{id="compare_failure"})
check(not find(report,"current:part:0").cold.complete,"CompareHandle failure accepted")
env.CompareHandle=savedCompare
part,preset=setup()
part.GetDependencies=function(self)
    reads[self.id]=(reads[self.id] or 0)+1
    return reads[self.id]==1 and {preset} or {}
end
report=run(nil,{id="warm_changed"})
check(not find(report,"current:part:0").stable,"warm graph changes must invalidate stability")
part,preset=setup()
local currentReads=0
env.GetCurrentCue=function()
    currentReads=currentReads+1
    return currentReads==1 and cue or object("Cue","Another Cue")
end
report=run(nil,{id="context_changed"})
check(not report.context_stable and #report.errors>0,"Cue change must invalidate capture")
env.GetCurrentCue=function() return cue end
part,preset=setup()
local parent=part
for i=1,9 do local nextNode=object("Preset","Deep "..i); parent.deps={nextNode}; parent=nextNode end
report=run(nil,{id="depth_limit"})
check(not find(report,"current:part:0").cold.complete,"depth limit must fail closed")
part,preset=setup()
for i=1,140 do part.deps[i]=object("Preset","Many "..i) end
report=run(nil,{id="node_limit"})
check(not find(report,"current:part:0").cold.complete,"node/work limit must fail closed")
part,preset=setup()
local later=object("Cue","Sequence 1 Cue 3"); later.No=3000; later.parent=seq
check(not pcall(run,nil,{id="future_history",history_cues={later.addr}}),"future Cue admitted as history")
part,preset=setup()
local earlier=object("Cue","Sequence 2 Cue 1"); earlier.No=1000; earlier.parent=object("Sequence","Sequence 2")
check(not pcall(run,nil,{id="other_sequence",history_cues={earlier.addr}}),"history from other Sequence admitted")
local rejected=pcall(run,nil,"unknown_case")
check(not rejected,"unknown case accepted")
check(forbidden==0,"forbidden API called during failure/limit tests")
print("PASS: "..count.." dependency probe assertions (MOCK ONLY; native results pending)")
