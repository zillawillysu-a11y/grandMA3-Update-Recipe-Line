-- Standalone, read-only grandMA3 2.5.0.3 database dependency probe.
-- Load from an external file. Never import this as a production replacement.
-- Only read APIs and Printf are used. No native calls in nested coroutines.

local TARGET = "2.5.0.3"
local CASES = {
    direct_recipe = {}, inherited_recipe = {}, static_override = {},
    release = {}, disabled_recipe = {}, phaser_recipe = {},
    generator_random = {}, multi_part = {}, empty_part = {}, duplicate_reference = {}
}
-- Configure ONLY these diagnostic entries for an already prepared test Show.
-- Example shape (addresses must be supplied by the operator):
-- CASES.inherited_recipe = {
--   history_cues = {"Sequence <n> Cue <earlier>"},
--   expectations = {
--     ["current:cue"] = {expected={"Preset <pool>.<slot>"}, excluded={}, exhaustive=true},
--     ["current:part:0"] = {expected={"Preset <pool>.<slot>"}, excluded={}, exhaustive=true}
--   }
-- }
-- Empty/unconfigured expectations are UNVERIFIED, never a successful empty set.

local LIMITS = {nodes=128, edges=256, depth=6, roots=24, children=128, work=8000, api=25000}
local apiRemaining
local function read(fn, ...)
    if apiRemaining then
        apiRemaining=apiRemaining-1
        if apiRemaining<0 then return nil, "API budget exceeded" end
    end
    if type(fn) ~= "function" then return nil, "API unavailable" end
    local ok, value = pcall(fn, ...)
    if not ok then return nil, tostring(value) end
    return value
end
local function method(h, name, ...)
    local fn, err = read(function() return h[name] end)
    if type(fn) ~= "function" then return nil, err or (name .. " unavailable") end
    return read(fn, h, ...)
end
local function field(h, name)
    local v = read(function() return h[name] end)
    if v == nil then v = method(h, "Get", name) end
    return v
end
local function text(v) return v == nil and "UNAVAILABLE" or tostring(v) end
local function klass(h) return text(method(h, "GetClass")) end
local function same(a, b)
    if a == nil or b == nil then return nil, "nil handle" end
    local equal, err = read(CompareHandle, a, b)
    if type(equal) ~= "boolean" then return nil, err or "CompareHandle returned non-boolean" end
    return equal
end
local function resolve(address)
    if type(address) ~= "string" or address == "" then return nil, "empty address" end
    local list, err = read(ObjectList, address)
    if type(list) ~= "table" or #list ~= 1 then return nil, err or "address must resolve uniquely" end
    if not read(IsObjectValid, list[1]) then return nil, "invalid resolved handle" end
    return list[1]
end
local function descriptor(h)
    local parent = method(h, "Parent")
    local pool = method(h, "FindParent", "DataPool")
    return {class=klass(h), address=text(method(h, "ToAddr", false)),
        native_address=text(method(h, "AddrNative", read(Root))),
        handle=text(read(HandleToStr, h)), index=text(method(h, "Index")),
        parent=parent and text(method(parent, "ToAddr", false)) or "NONE",
        parent_class=parent and klass(parent) or "NONE",
        pool=pool and text(method(pool, "ToAddr", false)) or "UNAVAILABLE",
        compare_self=same(h, h)}
end
local function candidateKind(kind)
    if kind == "Preset" then return "pool_preset" end
    if kind == "Random" or kind == "Generator" or kind == "GeneratorRandom" then return "pool_generator" end
    if kind == "PhaserRecipe" then return "recipe_structure" end
    return "other_dependency"
end
local function clock() return read(Time) end
local function delta(a, b)
    if type(a) == "number" and type(b) == "number" and b >= a then return (b-a)*1000 end
    return nil
end

-- One graph per explicit root; no merging historical / Part / Recipe graphs.
-- Edges preserve the exact API return slot, duplicates, cycles and shared nodes.
local function graph(root)
    local g = {nodes={}, edges={}, reads={}, errors={}, complete=true, work=0}
    local function fail(message)
        g.complete=false; g.errors[#g.errors+1]=message
    end
    local function work()
        g.work=g.work+1
        if g.work>LIMITS.work then error("work limit exceeded") end
    end
    local function intern(h)
        work()
        if not read(IsObjectValid, h) then fail("invalid dependency handle"); return nil end
        local selfEqual,selfError=same(h,h)
        if selfEqual~=true then fail(selfError or "CompareHandle self equality failed"); return nil end
        for i,node in ipairs(g.nodes) do
            work()
            local equal, err = same(h,node.object)
            if equal == nil then fail(err); return nil end
            if equal then return i end
        end
        if #g.nodes>=LIMITS.nodes then fail("node limit exceeded"); return nil end
        local id=#g.nodes+1
        g.nodes[id]={id=id,object=h,class=klass(h)}
        return id
    end
    local function visit(id,depth)
        work()
        local node=g.nodes[id]
        if node.visited then return end
        if depth>LIMITS.depth then fail("depth limit exceeded at node "..id); return end
        node.visited=true
        local started=clock()
        local deps,err=method(node.object,"GetDependencies")
        local elapsed=delta(started,clock())
        g.reads[#g.reads+1]={node=id,elapsed_ms=elapsed}
        if type(deps)~="table" then fail(err or "GetDependencies returned non-table"); return end
        -- The documented table is handles, not nested Lua arrays. Unexpected
        -- entries fail validation rather than being silently flattened.
        local count=0
        for slot,h in pairs(deps) do
            work(); count=count+1
            if count>LIMITS.edges or #g.edges>=LIMITS.edges then fail("edge limit exceeded"); return end
            local target=intern(h)
            if target then
                g.edges[#g.edges+1]={from=id,to=target,slot=text(slot),kind="dependency"}
                visit(target,depth+1)
            end
        end
    end
    local started=clock()
    local ok,err=pcall(function()
        local id=intern(root)
        if id then visit(id,0) end
    end)
    g.elapsed_ms=delta(started,clock())
    if not ok then fail(tostring(err)) end
    return g
end

local function checks(g,spec)
    local result={status="UNVERIFIED", matches={}, missing={}, false_positive={}, unknown={}, errors={}}
    if not spec then return result end
    if #(spec.expected or {})>64 or #(spec.excluded or {})>64 then
        result.status="INVALID_GROUND_TRUTH"; result.errors[1]="expectation limit exceeded"; return result
    end
    local expected,excluded={},{ }
    for _,entry in ipairs({{spec.expected or {},expected},{spec.excluded or {},excluded}}) do
        for _,addr in ipairs(entry[1]) do
            local h,err=resolve(addr)
            if h then entry[2][#entry[2]+1]={address=addr,object=h}
            else result.errors[#result.errors+1]=addr..": "..text(err) end
        end
    end
    if #result.errors>0 then result.status="INVALID_GROUND_TRUTH"; return result end
    local present={}
    -- Only objects reached by a dependency edge count, not the graph root.
    for _,edge in ipairs(g.edges) do present[edge.to]=true end
    for _,known in ipairs(expected) do
        local hit=false
        for id in pairs(present) do
            local equal,err=same(g.nodes[id].object,known.object)
            if equal==nil then result.errors[#result.errors+1]=text(err) end
            if equal then hit=true; result.matches[#result.matches+1]={address=known.address,node=id}; break end
        end
        if not hit then result.missing[#result.missing+1]=known.address end
    end
    for id in pairs(present) do
        local node=g.nodes[id]
        local excludedHit=false
        for _,known in ipairs(excluded) do
            local equal,err=same(node.object,known.object)
            if equal==nil then result.errors[#result.errors+1]=text(err) end
            if equal then excludedHit=true; break end
        end
        local expectedHit=false
        for _,known in ipairs(expected) do
            local equal,err=same(node.object,known.object)
            if equal==nil then result.errors[#result.errors+1]=text(err) end
            if equal then expectedHit=true; break end
        end
        if excludedHit then result.false_positive[#result.false_positive+1]=id
        elseif not expectedHit and candidateKind(node.class):match("^pool_") then
            local bucket=spec.exhaustive==true and result.false_positive or result.unknown
            bucket[#bucket+1]=id
        end
    end
    result.status=(g.complete and #result.errors==0) and "CHECKED" or "INCOMPLETE"
    return result
end

local function stability(a,b)
    if not a.complete or not b.complete then return false end
    -- Edge multisets must agree by handle identity, including duplicate slots.
    if #a.edges~=#b.edges then return false end
    local used={}
    for _,x in ipairs(a.edges) do
        local hit=false
        for j,y in ipairs(b.edges) do
            if not used[j] and x.slot==y.slot and same(a.nodes[x.from].object,b.nodes[y.from].object)
                and same(a.nodes[x.to].object,b.nodes[y.to].object) then used[j]=true; hit=true; break end
        end
        if not hit then return false end
    end
    return true
end

local function capture(config)
    apiRemaining=LIMITS.api
    local build,err=read(BuildDetails)
    if type(build)~="table" or build.BigVersion~=TARGET then
        error("Target must be "..TARGET.."; BuildDetails.BigVersion="..text(build and build.BigVersion).." "..text(err))
    end
    for _,fn in ipairs({"CompareHandle","IsObjectValid","SelectedSequence","GetCurrentCue","ObjectList","Root"}) do
        if type(_G[fn])~="function" then error(fn.." required") end
    end
    local sequence=read(SelectedSequence)
    local cue=read(GetCurrentCue)
    if not sequence or not cue or not read(IsObjectValid,cue) then error("Current Cue unavailable") end
    local report={case=config.id or "custom",version=TARGET,graphs={},relationships={},errors={},
        sequence=descriptor(sequence),cue=descriptor(cue),context_stable=true,
        conclusion="PARTIAL ONLY",native_verification="GROUND_TRUTH_REQUIRED"}
    local roots={}
    local function add(h,label,context,parentLabel,cueHandle,partHandle)
        if #roots>=LIMITS.roots then error("root limit exceeded") end
        roots[#roots+1]={object=h,label=label,context=context,parent=parentLabel,
            cue=cueHandle,part=partHandle}
        if parentLabel then report.relationships[#report.relationships+1]={from=parentLabel,to=label,kind="containment"} end
    end
    local function children(h)
        local list,e=method(h,"Children")
        if type(list)~="table" then error(e or "Children returned non-table") end
        if #list>LIMITS.children then error("child limit exceeded") end
        return list
    end
    local function cueRoots(h,prefix)
        add(h,prefix..":cue",prefix,nil,h)
        for _,part in ipairs(children(h)) do
            if klass(part)=="Part" then
                local partNo=field(part,"Part")
                if partNo==nil then error("Part number unavailable") end
                local partLabel=prefix..":part:"..text(partNo)
                add(part,partLabel,prefix,prefix..":cue",h,part)
                for ordinal,row in ipairs(children(part)) do
                    local kind=klass(row)
                    if kind=="StandardRecipe" or kind=="Recipe" or kind=="PhaserRecipe" then
                        add(row,partLabel..":recipe:"..ordinal,prefix,partLabel,h,part)
                    end
                end
            end
        end
    end
    cueRoots(cue,"current")
    if #(config.history_cues or {})>8 then error("history Cue limit exceeded") end
    for i,addr in ipairs(config.history_cues or {}) do
        local h,e=resolve(addr)
        if not h or klass(h)~="Cue" then error("history Cue invalid: "..addr.." "..text(e)) end
        if not same(method(h,"Parent"),sequence) then error("history Cue must belong to selected Sequence") end
        local earlier,current=tonumber(field(h,"No")),tonumber(field(cue,"No"))
        if not earlier or not current or earlier>=current then error("history Cue must precede Current Cue") end
        cueRoots(h,"history:"..i)
    end
    for _,root in ipairs(roots) do
        local cold=graph(root.object)
        local warm=graph(root.object)
        local entry={label=root.label,context=root.context,parent=root.parent,
            cold=cold,warm=warm,stable=stability(cold,warm),
            cold_checks=checks(cold,(config.expectations or {})[root.label]),
            warm_checks=checks(warm,(config.expectations or {})[root.label])}
        -- Metadata and ground-truth resolution are outside measured reads.
        entry.root=descriptor(root.object)
        entry.cue_address=text(method(root.cue,"ToAddr",false))
        entry.part_address=root.part and text(method(root.part,"ToAddr",false)) or "CUE_SCOPE"
        entry.recipe_fields={}
        if root.parent and root.label:find(":recipe:",1,true) then
            for _,key in ipairs({"Selection","Values","Generator","MAtricks","Enabled"}) do
                local value=field(root.object,key)
                entry.recipe_fields[key]=text(value)
            end
        end
        for _,g in ipairs({cold,warm}) do
            for _,node in ipairs(g.nodes) do node.metadata=descriptor(node.object); node.candidate_kind=candidateKind(node.class) end
        end
        report.graphs[#report.graphs+1]=entry
    end
    report.context_stable=same(cue,read(GetCurrentCue))==true and same(sequence,read(SelectedSequence))==true
    if not report.context_stable then report.errors[#report.errors+1]="Sequence/Cue changed during capture; discard result" end
    report.api_remaining=apiRemaining
    if apiRemaining<0 then report.errors[#report.errors+1]="API budget exceeded; discard result" end
    -- Never infer activity from successful graph extraction or mock fixtures.
    return report
end

local function emit(report)
    local function log(fmt,...) if type(Printf)=="function" then Printf("[GDProbe] "..fmt,...) end end
    log("CASE=%s target=%s current=%s sequence=%s context_stable=%s conclusion=%s",
        report.case,report.version,report.cue.address,report.sequence.address,text(report.context_stable),report.conclusion)
    log("TIME_SOURCE=Time seconds (MA vendor usage); cold=first probe read, native cache coldness UNVERIFIED")
    for _,edge in ipairs(report.relationships) do log("CONTAINMENT %s -> %s",edge.from,edge.to) end
    for _,entry in ipairs(report.graphs) do
        log("ROOT=%s cue=%s part=%s address=%s class=%s stable=%s",
            entry.label,entry.cue_address,entry.part_address,entry.root.address,entry.root.class,text(entry.stable))
        for key,value in pairs(entry.recipe_fields) do log("INGREDIENT root=%s field=%s value=%s",entry.label,key,value) end
        for _,pair in ipairs({{"cold",entry.cold,entry.cold_checks},{"warm",entry.warm,entry.warm_checks}}) do
            local phase,g,c=pair[1],pair[2],pair[3]
            log("GRAPH root=%s phase=%s complete=%s time_ms=%s nodes=%d edges=%d check=%s",
                entry.label,phase,text(g.complete),text(g.elapsed_ms),#g.nodes,#g.edges,c.status)
            log("CHECK root=%s phase=%s matches=%s missing=%s false_positive=%s",
                entry.label,phase,text(c.status=="CHECKED" and #c.matches or nil),
                text(c.status=="CHECKED" and #c.missing or nil),text(c.status=="CHECKED" and #c.false_positive or nil))
            for _,node in ipairs(g.nodes) do
                local m=node.metadata
                local matched="UNVERIFIED"
                if c.status=="CHECKED" then
                    matched="false"
                    for _,hit in ipairs(c.matches) do if hit.node==node.id then matched="true"; break end end
                end
                log("NODE root=%s phase=%s id=%d class=%s kind=%s address=%s native=%s parent=%s parent_class=%s pool=%s handle=%s compare_self=%s known_reference_match=%s",
                    entry.label,phase,node.id,m.class,node.candidate_kind,m.address,m.native_address,m.parent,m.parent_class,m.pool,m.handle,text(m.compare_self),matched)
            end
            for _,edge in ipairs(g.edges) do log("EDGE root=%s phase=%s from=%d to=%d slot=%s",entry.label,phase,edge.from,edge.to,edge.slot) end
            for _,r in ipairs(g.reads) do log("READ root=%s phase=%s node=%d time_ms=%s",entry.label,phase,r.node,text(r.elapsed_ms)) end
            for _,v in ipairs(c.matches) do log("MATCH root=%s phase=%s expected=%s node=%d CompareHandle=true",entry.label,phase,v.address,v.node) end
            for _,v in ipairs(c.missing) do log("MISSING root=%s phase=%s check=%s address=%s",entry.label,phase,c.status,v) end
            for _,v in ipairs(c.false_positive) do log("FALSE_POSITIVE root=%s phase=%s check=%s node=%d (against supplied active ground truth)",entry.label,phase,c.status,v) end
            for _,v in ipairs(c.unknown) do log("UNCLASSIFIED root=%s phase=%s node=%d",entry.label,phase,v) end
            for _,v in ipairs(g.errors) do log("ERROR root=%s phase=%s %s",entry.label,phase,v) end
            for _,v in ipairs(c.errors) do log("CHECK_ERROR root=%s phase=%s %s",entry.label,phase,v) end
        end
    end
    for _,v in ipairs(report.errors) do log("ERROR %s",v) end
    log("END case=%s; database graph only; active playback suitability NOT PROVEN",report.case)
end

return function(_,argument)
    local config
    if type(argument)=="table" then config=argument
    else
        local id=type(argument)=="string" and argument or "direct_recipe"
        if not CASES[id] then error("Unknown case id: "..text(id)) end
        config=CASES[id]; config.id=id
    end
    local ok,report=pcall(capture,config)
    apiRemaining=nil
    if not ok then error(report) end
    emit(report)
    return report
end
