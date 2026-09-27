-- Read-only UI topology probe. No ObjectList, cooked reads, commands or UI writes.
local TARGET="2.5.0.3"
local LIMIT={calls=24000,depth=5,nodes=160,children=48,properties=80,lines=1100}
local KNOWN_GRID="Display 3.5.3.1.5.1.4.4"
return function()
    local remaining=nil -- inspection budget begins only after all display roots checked
    local discoveryReads=0
    local lines,truncated=0,false
    local function log(fmt,...)
        if lines>=LIMIT.lines then truncated=true; return end
        lines=lines+1
        Printf("[UITopo] "..fmt,...)
    end
    local function read(fn,...)
        if remaining~=nil then
            if remaining<=0 then return nil,"READ_BUDGET" end
            remaining=remaining-1
        else discoveryReads=discoveryReads+1 end
        if type(fn)~="function" then return nil,"UNAVAILABLE" end
        local ok,v=pcall(fn,...)
        if not ok then return nil,tostring(v) end
        return v
    end
    local function method(h,k,...)
        local f,e=read(function() return h[k] end)
        if type(f)~="function" then return nil,e or "UNAVAILABLE" end
        return read(f,h,...)
    end
    local function field(h,k)
        local v,e=read(function() return h[k] end)
        if v==nil then return method(h,"Get",k) end
        return v,e
    end
    local function text(v)
        if v==nil then return "UNAVAILABLE" end
        return tostring(v):gsub("[\r\n]"," "):sub(1,180)
    end
    local function valid(h) return h~=nil and read(IsObjectValid,h)==true end
    local function kind(h) return text(method(h,"GetClass")) end
    local function isUI(h)
        if not valid(h) then return false end
        local k=kind(h)
        return k=="UIObject" or read(IsClassDerivedFrom,k,"UIObject")==true
    end
    -- Fail closed before ANY UI-only call, including visibility/grid APIs.
    local uiOnly={UIChildren=true,GetUIChildrenCount=true,GetUIChild=true,
        IsVisible=true,IsActuallyVisible=true,GridGetBase=true,GridGetData=true,GridGetScrollOffset=true}
    local rawMethod=method
    method=function(h,k,...)
        if uiOnly[k] and not isUI(h) then return nil,"NOT_UI_OBJECT" end
        if k:find("GridGet",1,true)==1 and read(IsClassDerivedFrom,kind(h),"UIGrid")~=true then
            return nil,"NOT_UI_GRID"
        end
        return rawMethod(h,k,...)
    end
    local function descriptor(h)
        if not valid(h) then return text(h) end
        return "class="..kind(h).." address="..text(method(h,"ToAddr")).." native="..text(method(h,"AddrNative")).." handle="..text(read(HandleToStr,h))
    end
    local build=read(BuildDetails)
    if type(build)~="table" or build.BigVersion~=TARGET then error("Requires grandMA3 "..TARGET) end
    log("START revision=2-ui-type-guard-direct-grid target=%s depth=%d max_nodes=%d children_per_path=%d property_limit=%d",TARGET,LIMIT.depth,LIMIT.nodes,LIMIT.children,LIMIT.properties)
    -- Merge distinct native child paths. Never assume empty UIChildren implies no children.
    local function edges(h,emit)
        local out,seen={},{}
        if not isUI(h) then
            if emit then log("NOT_UI_TRAVERSAL %s",descriptor(h)) end
            return out
        end
        local function add(v,path,index)
            if isUI(v) and not seen[v] then
                seen[v]=true; out[#out+1]={object=v,path=path,index=index}
            elseif valid(v) and not isUI(v) and emit then
                log("DATABASE_CHILD_NOT_TRAVERSED owner=%s path=%s index=%s target={%s}",text(method(h,"ToAddr")),path,text(index),descriptor(v))
            end
        end
        for _,path in ipairs({"UIChildren","Children"}) do
            local v,e=method(h,path)
            local count=0
            if type(v)=="table" then
                for k,c in pairs(v) do
                    count=count+1
                    if count<=LIMIT.children then add(c,path,k) end
                    if count>LIMIT.children then break end
                end
            end
            if emit then log("CHILD_PATH owner=%s path=%s count=%s cap=%s error=%s",text(method(h,"ToAddr")),path,type(v)=="table" and text(count) or "UNAVAILABLE",text(count>LIMIT.children),text(e)) end
        end
        for _,spec in ipairs({{"GetUIChildrenCount","GetUIChild"},{"Count","Ptr"}}) do
            local n,e=method(h,spec[1])
            if emit then log("CHILD_PATH owner=%s path=%s count=%s cap=%s error=%s",text(method(h,"ToAddr")),spec[2],text(n),text(type(n)=="number" and n>LIMIT.children),text(e)) end
            if type(n)=="number" and n>=0 then
                for i=1,math.min(math.floor(n),LIMIT.children) do add(method(h,spec[2],i),spec[2],i) end
            elseif n==nil then
                -- Bounded samples of documented indexed APIs when count is unavailable.
                if emit then log("INDEXED_SAMPLE owner=%s path=%s indices=1..8 count_unavailable=true",text(method(h,"ToAddr")),spec[2]) end
                for i=1,8 do add(method(h,spec[2],i),spec[2]..":sample",i) end
            end
        end
        return out
    end
    if type(IsClassDerivedFrom)~="function" then error("IsClassDerivedFrom required; cannot safely type UI handles") end
    local grids,gridSeen,roots={}, {}, {}
    local function addGrid(g,origin)
        if not isUI(g) or not kind(g):find("PoolLayoutGrid",1,true) then
            if valid(g) then log("GRID_REJECTED origin=%s %s",origin,descriptor(g)) end
            return
        end
        if not gridSeen[g] then gridSeen[g]=true; grids[#grids+1]=g; log("GRID_LOCATED origin=%s %s",origin,descriptor(g)) end
    end
    -- Prefer the exact previously proven native UI address. These resolvers only
    -- locate the UI GRID; no database address resolution substitutes for tiles.
    local direct,e=read(FromAddr,KNOWN_GRID)
    addGrid(direct,"known-address:FromAddr")
    if not gridSeen[direct] then
        local alternative,why=read(GetObject,KNOWN_GRID)
        addGrid(alternative,"known-address:GetObject")
        log("DIRECT_LOOKUP known=%s FromAddr_error=%s GetObject_error=%s",KNOWN_GRID,text(e),text(why))
    end
    -- Check every display root before detailed inspection. No shared discovery
    -- node/read cap can starve Display 3. Native class search is fallback only;
    -- unlike the invalid probe there is no manual whole-object-tree crawl.
    for i=1,7 do
        local display=read(GetDisplayByIndex,i)
        roots[i]=display
        log("DISPLAY_ROOT index=%d present=%s is_ui=%s %s",i,text(valid(display)),text(isUI(display)),descriptor(display))
        if valid(display) then
            addGrid(method(display,"FindRecursive","","AllPoolLayoutGrid"),"display:"..i..":FindRecursive")
        end
    end
    -- Reuse the discovered native Generator grid; do not resolve a guessed address.
    local chosen,comparison
    for _,g in ipairs(grids) do
        local pool=field(g,"PoolObject")
        local label=(kind(pool).." "..text(field(g,"Pooltype"))):lower()
        local isGenerator=label:find("generator",1,true) or label:find("random",1,true)
        local iv=method(g,"IsVisible")
        local av=method(g,"IsActuallyVisible")
        log("DISCOVERED %s pool=%s pool_type=%s IsVisible=%s IsActuallyVisible=%s",descriptor(g),descriptor(pool),text(field(g,"Pooltype")),text(iv),text(av))
        local hidden=iv==false or av==false
        if isGenerator and not hidden and (not chosen or iv==true or av==true) then chosen=g end
        if not isGenerator and not hidden and (label:find("group",1,true) or label:find("preset",1,true)) then comparison=comparison or g end
    end
    -- Locating is separate from bounded detailed neighborhood inspection.
    remaining=LIMIT.calls
    local inspected,seen=0,{}
    local function inspect(h,depth,relation,gridPool,recurse)
        if not valid(h) or remaining<=0 then return end
        if not isUI(h) then log("DATABASE_NOT_TRAVERSED relation=%s target={%s}",relation,descriptor(h)); return end
        if seen[h] then log("REVISIT depth=%d relation=%s %s",depth,relation,descriptor(h)); return end
        if inspected>=LIMIT.nodes then truncated=true; return end
        seen[h]=true; inspected=inspected+1
        local name=field(h,"Name")
        local idx=field(h,"ObjectIndex")
        local pool=field(h,"PoolObject")
        log("NODE depth=%d relation=%s %s name=%s Visible=%s IsVisible=%s IsActuallyVisible=%s UI_count=%s Count=%s ObjectIndex=%s PoolObject={%s}",depth,relation,descriptor(h),text(name),text(field(h,"Visible")),text(method(h,"IsVisible")),text(method(h,"IsActuallyVisible")),text(method(h,"GetUIChildrenCount")),text(method(h,"Count")),text(idx),descriptor(pool))
        local n,e=method(h,"PropertyCount")
        log("PROPERTIES owner=%s count=%s cap=%s error=%s",text(method(h,"ToAddr")),text(n),text(type(n)=="number" and n>LIMIT.properties),text(e))
        if type(n)=="number" then
            -- MA introspection property indices are zero-based. Report each exposed
            -- property name/type; read only names relevant to object/target/layout.
            for i=0,math.min(math.floor(n),LIMIT.properties)-1 do
                local key=method(h,"PropertyName",i)
                local ty=method(h,"PropertyType",i)
                local low=text(key):lower()
                local relevant=low:find("object",1,true) or low:find("target",1,true) or low:find("pool",1,true) or low:find("index",1,true) or low:find("visible",1,true) or low:find("cell",1,true) or low:find("scroll",1,true) or low:find("row",1,true) or low:find("column",1,true)
                local value,why
                if key and relevant then value,why=field(h,key) end
                log("PROPERTY owner=%s index=%d name=%s type=%s value=%s error=%s",text(method(h,"ToAddr")),i,text(key),text(ty),relevant and descriptor(value) or "NOT_READ",text(why))
            end
        end
        local low=kind(h):lower()
        if idx~=nil and (low:find("poolbutton",1,true) or low:find("cell",1,true)) then
            local source=valid(pool) and pool or (depth>=1 and gridPool or nil)
            local target,why
            if tonumber(idx) and valid(source) then target,why=method(source,"Ptr",tonumber(idx)) end
            log("TILE_EVIDENCE depth=%d widget={%s} index=%s matches_103_104_index_hint=%s target={%s} target_error=%s visibility=%s",depth,descriptor(h),text(idx),text(tonumber(idx)==103 or tonumber(idx)==104),descriptor(target),text(why),text(method(h,"IsVisible")))
            -- ObjectIndex alone is a hint, never proof of Generator slot identity.
        end
        if depth<LIMIT.depth and kind(h):find("Grid",1,true) then
            for _,key in ipairs({"GridGetBase","GridGetData","GridGetScrollOffset"}) do
                local v,why=method(h,key)
                log("GRID_API owner=%s api=%s result={%s} error=%s",text(method(h,"ToAddr")),key,descriptor(v),text(why))
                if isUI(v) then inspect(v,depth+1,"grid-api:"..key,gridPool,false)
                elseif valid(v) then log("DATABASE_GRID_RESULT_NOT_TRAVERSED api=%s target={%s}",key,descriptor(v)) end
            end
        end
        local children=edges(h,true)
        if recurse and depth<LIMIT.depth then
            for _,edge in ipairs(children) do inspect(edge.object,depth+1,edge.path..":"..text(edge.index),gridPool,true) end
        elseif recurse and #children>0 then log("DEPTH_LIMIT owner=%s remaining_children=%d",text(method(h,"ToAddr")),#children) end
    end
    local function neighborhood(g,label)
        -- Comparison grids may already have been logged as siblings. Reinspect
        -- their own neighborhood while retaining the shared overall node budget.
        seen={}
        log("SECTION %s grid={%s}",label,descriptor(g))
        local pool=field(g,"PoolObject")
        inspect(g,0,label..":grid",pool,true)
        local parent=method(g,"Parent")
        local grandparent=method(parent,"Parent")
        inspect(parent,-1,label..":parent",pool,false)
        inspect(grandparent,-2,label..":grandparent",pool,false)
        -- Only immediate siblings: never recurse into the entire parent subtree.
        for _,edge in ipairs(edges(parent,false)) do
            if edge.object~=g then
                if not comparison and kind(edge.object):find("PoolLayoutGrid",1,true) then
                    local labelText=(kind(field(edge.object,"PoolObject")).." "..text(field(edge.object,"Pooltype"))):lower()
                    if labelText:find("group",1,true) or labelText:find("preset",1,true) then comparison=edge.object end
                end
                inspect(edge.object,0,label..":sibling:"..edge.path,pool,false)
            end
        end
        for _,edge in ipairs(edges(grandparent,false)) do
            if edge.object~=parent then inspect(edge.object,-1,label..":parent-sibling:"..edge.path,pool,false) end
        end
    end
    if chosen then neighborhood(chosen,"GENERATOR") else log("PROBE_INVALID_RETEST_REQUIRED known_grid=%s displays_checked=7 reason=GENERATOR_NOT_LOCATED",KNOWN_GRID) end
    if comparison then neighborhood(comparison,"GROUP_OR_PRESET_COMPARISON") end
    -- No native virtualization conclusion is fabricated from empty child lists.
    Printf("[UITopo] END inspected=%d displays_checked=7 discovery_reads=%d discovered_grids=%d generator_found=%s remaining_reads=%d truncated=%s virtualization=UNVERIFIED",inspected,discoveryReads,#grids,tostring(chosen~=nil),remaining,tostring(truncated or remaining<=0))
    return {inspected=inspected,grids=#grids,truncated=truncated,remaining=remaining}
end
