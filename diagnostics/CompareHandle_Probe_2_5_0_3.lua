-- Isolated read-only Generator/Random identity probe. Target 2.5.0.3 only.
-- No commands, cooked data, playback changes, UI writes or native nested coroutines.
local TARGET="2.5.0.3"
local MAX={rows=64,refs=16,tiles=128,nodes=6000,depth=20,calls=32000}
local remaining
local function read(fn,...)
    remaining=remaining-1
    if remaining<0 then return nil,"read budget exceeded" end
    if type(fn)~="function" then return nil,"API unavailable" end
    local ok,v=pcall(fn,...)
    if not ok then return nil,tostring(v) end
    return v
end
local function method(h,key,...)
    local fn,e=read(function() return h[key] end)
    if type(fn)~="function" then return nil,e or key.." unavailable" end
    return read(fn,h,...)
end
local function field(h,key)
    local v=read(function() return h[key] end)
    if v==nil then v=method(h,"Get",key) end
    return v
end
local function valid(h) return read(IsObjectValid,h)==true end
local function text(v) return v==nil and "UNAVAILABLE" or tostring(v) end
local function class(h) return text(method(h,"GetClass")) end
local function generator(h)
    local k=class(h)
    return k=="Random" or k=="Generator" or k=="GeneratorRandom"
end
local function resolve(addr)
    local list,e=read(ObjectList,addr)
    if type(list)~="table" or #list~=1 or not valid(list[1]) then return nil,e or "address not unique/valid" end
    return list[1]
end
local function describe(h)
    local parent=method(h,"Parent")
    local pool=method(h,"FindParent","DataPool")
    return {class=class(h),address=text(method(h,"ToAddr")),
        native=text(method(h,"AddrNative")),token=text(read(HandleToStr,h)),
        parent=parent and text(method(parent,"ToAddr",false)) or "NONE",
        pool=pool and text(method(pool,"ToAddr",false)) or "UNAVAILABLE",
        index=text(method(h,"CmdlineIndex"))}
end
local function compare(a,b)
    if not valid(a) or not valid(b) then return nil,"invalid handle" end
    local v,e=read(CompareHandle,a,b)
    if type(v)~="boolean" then return nil,e or "non-boolean CompareHandle" end
    return v
end
local function timed(a,b)
    local start=read(Time)
    local v,e=compare(a,b)
    local stop=read(Time)
    return v,e,type(start)=="number" and type(stop)=="number" and stop>=start and (stop-start)*1000 or nil
end
local function list(h,ui)
    local values,e=method(h,ui and "UIChildren" or "Children")
    if ui and type(values)~="table" then values,e=method(h,"Children") end
    if type(values)~="table" then return nil,e or "non-table children" end
    if #values>MAX.nodes then return nil,"children limit exceeded" end
    return values
end
local function capture(config)
    local build=read(BuildDetails)
    if type(build)~="table" or build.BigVersion~=TARGET then error("Requires grandMA3 "..TARGET) end
    for _,key in ipairs({"CompareHandle","IsObjectValid","ObjectList","Root","SelectedSequence","GetCurrentCue"}) do
        if type(_G[key])~="function" then error(key.." required") end
    end
    local seq,cue=read(SelectedSequence),read(GetCurrentCue)
    local report={refs={},tiles={},widgets={},grids={},pairs={},errors={},target=TARGET,status="UNVERIFIED",
        sequence=valid(seq) and text(method(seq,"ToAddr",false)) or "UNAVAILABLE",
        cue=valid(cue) and text(method(cue,"ToAddr",false)) or "UNAVAILABLE"}
    local function issue(msg) report.errors[#report.errors+1]=msg end
    local rows={}
    local function addRow(h)
        if #rows>=MAX.rows then issue("Recipe row limit exceeded"); return end
        rows[#rows+1]=h
    end
    if config.recipe_addresses then
        if #config.recipe_addresses>MAX.rows then error("Recipe address limit exceeded") end
        for _,addr in ipairs(config.recipe_addresses) do
            local h,e=resolve(addr)
            if h then addRow(h) else issue(addr..": "..text(e)) end
        end
    elseif valid(cue) then
        local parts,e=list(cue)
        if not parts then issue(text(e)) end
        for _,part in ipairs(parts or {}) do
            if class(part)=="Part" then
                local children,why=list(part)
                if not children then issue(text(why)) end
                for _,h in ipairs(children or {}) do
                    local kind=class(h)
                    if kind=="Recipe" or kind=="StandardRecipe" then addRow(h) end
                end
            end
        end
    else issue("No Current Cue; specify recipe_addresses") end
    for _,row in ipairs(rows) do
        local kind=class(row)
        if kind~="StandardRecipe" and kind~="Recipe" then issue("not a StandardRecipe: "..text(method(row,"ToAddr",false)))
        else
            local raw=field(row,"Generator")
            local key="Generator"
            if raw==nil then raw=field(row,"Values"); key="Values" end
            local h,e
            if valid(raw) then h=raw
            elseif type(raw)=="string" and raw~="" then h,e=resolve(raw) end
            if h and generator(h) then
                if #report.refs>=MAX.refs then issue("reference limit exceeded"); break end
                report.refs[#report.refs+1]={object=h,recipe=text(method(row,"ToAddr",false)),field=key,
                    raw_type=type(raw),raw=text(raw),enabled=text(field(row,"Enabled"))}
            elseif raw~=nil and not h then issue("Recipe "..text(method(row,"ToAddr",false))..": unresolved reference "..text(e)) end
        end
    end
    local function addTile(h,origin,widget)
        if not valid(h) or not generator(h) then issue("invalid/non-Generator pool object at "..origin); return end
        if #report.tiles>=MAX.tiles then issue("tile limit exceeded"); return end
        report.tiles[#report.tiles+1]={object=h,origin=origin,widget=widget,is_ui=widget~=nil}
        if widget then widget.target_index=#report.tiles end
    end
    -- Copied read-only path from refreshPoolMarkers: displays -> UIChildren
    -- (Children fallback) -> visible PoolLayoutGrid -> pool buttons ->
    -- grid.PoolObject:Ptr(tonumber(button.ObjectIndex)). No ObjectList fallback.
    local function visibility(h)
        local v=method(h,"IsActuallyVisible")
        if v==nil then return nil end
        local normalized=tostring(v):lower()
        return v==true or normalized=="yes" or normalized=="true" or normalized=="1"
    end
    local seen,nodes={},0
    local function visit(h,depth)
        if not h or seen[h] then return end
        if nodes>=MAX.nodes or depth>MAX.depth then issue("UI traversal limit exceeded"); return end
        seen[h]=true; nodes=nodes+1
        local kind=class(h)
        if kind:find("PoolLayoutGrid",1,true) then
            local visible=visibility(h)
            local pool=field(h,"PoolObject")
            local poolKind=valid(pool) and class(pool) or "UNAVAILABLE"
            local gridInfo={metadata=describe(h),visible=text(visible),pool_class=poolKind,
                pool_type=text(field(h,"Pooltype")),buttons=0,targets=0}
            report.grids[#report.grids+1]=gridInfo
            if visible~=true then
                if visible==nil then issue("grid visibility unverified; skipped") end
                return
            end
            -- Production scans all Pool grids: do not gate extraction on an
            -- assumed Generators pool class or Pooltype spelling.
            local generatorGrid=poolKind:lower():find("generator",1,true)~=nil
                or gridInfo.pool_type:lower():find("generator",1,true)~=nil
                or poolKind:lower():find("random",1,true)~=nil
            local buttons,e=list(h,true)
            if not buttons then issue(text(e)); return end
            for _,button in ipairs(buttons) do
                local buttonKind=class(button):lower()
                if buttonKind:find("poolbutton",1,true) and not buttonKind:find("pooltitlebutton",1,true) then
                    gridInfo.buttons=gridInfo.buttons+1
                    local idx=tonumber(field(button,"ObjectIndex"))
                    local object,why
                    if idx then object,why=method(pool,"Ptr",idx) end
                    local isGenerator=valid(object) and generator(object)
                    if generatorGrid or isGenerator then
                        if #report.widgets>=MAX.tiles then issue("widget limit exceeded"); return end
                        local widget={object=button,metadata=describe(button),grid=gridInfo.metadata.address,
                            index=text(idx),visible=text(visibility(button)),
                            extraction="NO_TARGET_HANDLE",error=text(why),target_index=nil}
                        report.widgets[#report.widgets+1]=widget
                        if not idx then widget.extraction="OBJECT_INDEX_UNAVAILABLE"
                        elseif isGenerator then
                            -- The grid is verified visible. Log widget visibility
                            -- separately; unknown/hidden widget is not UI evidence.
                            if widget.visible=="true" then
                                widget.extraction="PoolObject:Ptr(ObjectIndex)"
                                addTile(object,"display-grid "..widget.grid.." tile "..idx,widget)
                                gridInfo.targets=gridInfo.targets+1
                            else
                                widget.extraction="WIDGET_VISIBILITY_UNVERIFIED_OR_HIDDEN"
                                widget.extracted_metadata=describe(object)
                            end
                        elseif object~=nil then
                            widget.extraction="INVALID_OR_NON_GENERATOR_TARGET"
                            if not valid(object) then issue("invalid extracted UI target at "..widget.grid.." tile "..text(idx)) end
                            widget.extracted_metadata=describe(object)
                        end
                    end
                end
            end
            return
        end
        local children,e=list(h,true)
        if not children then issue(text(e)); return end
        for _,child in ipairs(children) do visit(child,depth+1) end
    end
    if type(GetDisplayByIndex)=="function" then
        for i=1,7 do local display=read(GetDisplayByIndex,i); if display then visit(display,0) end end
    elseif type(GetFocusDisplay)=="function" then
        visit(read(GetFocusDisplay),0)
    end
    if #(config.pool_addresses or {})>MAX.tiles then error("pool address limit exceeded") end
    for _,addr in ipairs(config.pool_addresses or {}) do
        local h,e=resolve(addr)
        if h then addTile(h,"ObjectList "..addr.." (not UI tile evidence)") else issue(addr..": "..text(e)) end
    end
    local knownExpected,knownOther
    for _,key in ipairs({"expected_generator","other_generator"}) do
        if config[key] then
            local h,e=resolve(config[key])
            if not h or not generator(h) then issue("invalid "..key..": "..text(e))
            elseif key=="expected_generator" then knownExpected=h else knownOther=h end
        end
    end
    if knownExpected and knownOther and compare(knownExpected,knownOther)~=false then issue("positive/negative controls are not distinct") end
    for ri,ref in ipairs(report.refs) do
        ref.self_equal,ref.self_error=compare(ref.object,ref.object)
        if knownExpected then ref.expected_equal=compare(ref.object,knownExpected) end
        if knownOther then ref.other_equal=compare(ref.object,knownOther) end
        for ti,tile in ipairs(report.tiles) do
            local cold,ce,cm=timed(ref.object,tile.object)
            local warm,we,wm=timed(ref.object,tile.object)
            local reverse,re=compare(tile.object,ref.object)
            report.pairs[#report.pairs+1]={ref=ri,tile=ti,cold=cold,warm=warm,reverse=reverse,
                cold_ms=cm,warm_ms=wm,error=ce or we or re,
                stable=type(cold)=="boolean" and cold==warm and cold==reverse}
        end
        ref.metadata=describe(ref.object)
    end
    for _,tile in ipairs(report.tiles) do
        tile.metadata=describe(tile.object)
        if knownExpected then tile.expected_equal=compare(tile.object,knownExpected) end
        if knownOther then tile.other_equal=compare(tile.object,knownOther) end
    end
    report.ui_targets=0
    for _,tile in ipairs(report.tiles) do if tile.is_ui then report.ui_targets=report.ui_targets+1 end end
    report.ui_status=report.ui_targets>0 and "UI_TARGETS_EXTRACTED" or "NO_VISIBLE_UI_TARGET_HANDLE"
    report.alias_status="NOT_OBSERVED"
    for _,p in ipairs(report.pairs) do
        local tile=report.tiles[p.tile]
        local a,b=report.refs[p.ref].metadata,tile.metadata
        local command_diff=a.address~="UNAVAILABLE" and b.address~="UNAVAILABLE" and a.address~=b.address
        local native_diff=a.native~="UNAVAILABLE" and b.native~="UNAVAILABLE" and a.native~=b.native
        if tile.is_ui and (command_diff or native_diff) and p.cold~=false then
            if p.stable and p.cold==true then report.alias_status="UI_ALIAS_EQUALITY_OBSERVED"
            elseif report.alias_status~="UI_ALIAS_EQUALITY_OBSERVED" then report.alias_status="DIFFERENT_TEXT_PAIR_ONLY" end
        end
    end
    report.context_stable=compare(seq,read(SelectedSequence))==true and compare(cue,read(GetCurrentCue))==true
    if not report.context_stable then issue("Sequence/Cue context changed or unavailable") end
    if remaining<0 then issue("read budget exceeded") end
    if #report.refs==0 then issue("No Generator Recipe references found") end
    if #report.tiles==0 then issue("No Generator Pool targets found; open Generator Pool or supply pool_addresses") end
    -- Explicit truth is required; equality alone never proves intended identity.
    if knownExpected and knownOther and #report.errors==0 then
        local pass=true
        for ri,ref in ipairs(report.refs) do
            local matched,negative=false,false
            for _,p in ipairs(report.pairs) do
                if p.ref==ri then
                    if not p.stable or p.error then pass=false end
                    local tile=report.tiles[p.tile]
                    if tile.is_ui and tile.expected_equal==true and p.cold==true then matched=true end
                    if tile.is_ui and tile.other_equal==true then
                        if p.cold==false and p.reverse==false then negative=true else pass=false end
                    end
                end
            end
            if ref.self_equal~=true or ref.expected_equal~=true or ref.other_equal~=false or not matched or not negative then pass=false end
        end
        report.status=pass and "CONTROLLED_PAIR_PASS_NATIVE_CONFIRMATION_REQUIRED" or (report.ui_targets==0 and "UNVERIFIED_NO_UI_EVIDENCE" or "CONTROLLED_PAIR_FAIL")
    end
    return report
end
local function emit(r)
    local function log(fmt,...) if type(Printf)=="function" then Printf("[CHProbe] "..fmt,...) end end
    log("START target=%s sequence=%s cue=%s refs=%d tiles=%d status=%s",r.target,r.sequence,r.cue,#r.refs,#r.tiles,r.status)
    for i,ref in ipairs(r.refs) do
        local m=ref.metadata
        log("RECIPE ref=%d recipe=%s field=%s enabled=%s raw_type=%s raw=%s class=%s address=%s native=%s parent=%s pool=%s handle=%s self=%s expected=%s other=%s",
            i,ref.recipe,ref.field,ref.enabled,ref.raw_type,ref.raw,m.class,m.address,m.native,m.parent,m.pool,m.token,text(ref.self_equal),text(ref.expected_equal),text(ref.other_equal))
    end
    for i,g in ipairs(r.grids) do
        log("GRID grid=%d class=%s address=%s visible=%s pool_class=%s pool_type=%s buttons=%d targets=%d",i,g.metadata.class,g.metadata.address,g.visible,g.pool_class,g.pool_type,g.buttons,g.targets)
    end
    for i,w in ipairs(r.widgets) do
        local m=w.metadata
        log("UI_TILE widget=%d class=%s address=%s native=%s handle=%s grid=%s object_index=%s visible=%s extraction=%s target=%s error=%s",i,m.class,m.address,m.native,m.token,w.grid,w.index,w.visible,w.extraction,text(w.target_index),w.error)
        if w.extracted_metadata then
            local t=w.extracted_metadata
            log("UNACCEPTED_TARGET widget=%d class=%s address=%s native=%s handle=%s",i,t.class,t.address,t.native,t.token)
        end
    end
    for i,tile in ipairs(r.tiles) do
        local m=tile.metadata
        log("POOL tile=%d origin=%s class=%s address=%s native=%s parent=%s pool=%s handle=%s ui_evidence=%s expected=%s other=%s",i,tile.origin,m.class,m.address,m.native,m.parent,m.pool,m.token,text(tile.is_ui),text(tile.expected_equal),text(tile.other_equal))
    end
    for _,p in ipairs(r.pairs) do
        local a,b=r.refs[p.ref].metadata,r.tiles[p.tile].metadata
        log("PAIR ref=%d tile=%d compare_cold=%s compare_warm=%s reverse=%s stable=%s command_equal=%s native_equal=%s cold_ms=%s warm_ms=%s error=%s",
            p.ref,p.tile,text(p.cold),text(p.warm),text(p.reverse),text(p.stable),
            text(a.address~="UNAVAILABLE" and b.address~="UNAVAILABLE" and a.address==b.address),
            text(a.native~="UNAVAILABLE" and b.native~="UNAVAILABLE" and a.native==b.native),text(p.cold_ms),text(p.warm_ms),text(p.error))
    end
    for _,e in ipairs(r.errors) do log("ERROR %s",e) end
    log("END status=%s ui_status=%s ui_targets=%d alias_status=%s; identity experiment only; no production changes",r.status,r.ui_status,r.ui_targets,r.alias_status)
end
return function(_,argument)
    remaining=MAX.calls
    local config=type(argument)=="table" and argument or {}
    local ok,r=pcall(capture,config)
    remaining=nil
    if not ok then error(r) end
    emit(r)
    return r
end
