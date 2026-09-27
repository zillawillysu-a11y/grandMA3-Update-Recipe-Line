-- Read-only direct Pool child-path comparison. No lifecycle/identity/cooked scan.
local TARGET="2.5.0.3"
local MAX_CHILDREN=512
return function()
    local remaining=12000
    local function read(fn,...)
        if remaining<=0 then return nil,"READ_LIMIT" end
        remaining=remaining-1
        if type(fn)~="function" then return nil,"UNAVAILABLE" end
        local ok,v=pcall(fn,...); if not ok then return nil,tostring(v) end; return v
    end
    local function method(h,k,...)
        local f,e=read(function() return h[k] end)
        if type(f)~="function" then return nil,e or "UNAVAILABLE" end
        return read(f,h,...)
    end
    local function field(h,k)
        local v=read(function() return h[k] end)
        if v==nil then v=method(h,"Get",k) end
        return v
    end
    local function text(v) return v==nil and "UNAVAILABLE" or tostring(v):gsub("[\r\n]"," "):sub(1,160) end
    local function valid(h) return h~=nil and read(IsObjectValid,h)==true end
    local function kind(h) return text(method(h,"GetClass")) end
    local derivation={}
    local function derived(k,base)
        local key=k..":"..base
        if derivation[key]==nil then derivation[key]=k==base or read(IsClassDerivedFrom,k,base)==true end
        return derivation[key]
    end
    local function isUI(h) return valid(h) and derived(kind(h),"UIObject") end
    local function ui(h,k,...)
        if not isUI(h) then return nil,"NOT_UI_OBJECT" end
        return method(h,k,...)
    end
    local function boolean(v)
        if v==nil then return nil end
        local s=tostring(v):lower()
        if v==true or s=="yes" or s=="true" or s=="1" then return true end
        if v==false or s=="no" or s=="false" or s=="0" then return false end
    end
    local function visibility(h)
        local a=ui(h,"IsActuallyVisible"); local b=ui(h,"IsVisible"); local c=field(h,"Visible")
        local aa,bb,cc=boolean(a),boolean(b),boolean(c)
        local visible
        if aa==false or bb==false or cc==false then visible=false
        elseif aa==true or bb==true or cc==true then visible=true end
        local p=method(h,"Parent"); local seen={}
        for _=1,10 do
            if not isUI(p) or seen[p] then break end
            seen[p]=true
            if boolean(ui(p,"IsActuallyVisible"))==false or boolean(ui(p,"IsVisible"))==false or boolean(field(p,"Visible"))==false then visible=false; break end
            p=method(p,"Parent")
        end
        return visible,a,b,c
    end
    local function log(fmt,...) Printf("[ChildEnum] "..fmt,...) end
    local build=read(BuildDetails)
    if type(build)~="table" or build.BigVersion~=TARGET then error("Requires grandMA3 "..TARGET) end
    for _,k in ipairs({"IsClassDerivedFrom","IsObjectValid","HandleToStr","GetDisplayByIndex"}) do if type(_G[k])~="function" then error(k.." required") end end
    log("START target=%s revision=1 scope=GENERIC_POOL_DIRECT_CHILD_PATHS",TARGET)
    -- Reuse the established direct-grid/class locator; do not study discovery
    -- budgets or infer absent windows. Inventory only located visible grids.
    local roots={}
    for i=1,7 do roots[i]=read(GetDisplayByIndex,i) end
    local grids,seen={},{}
    local function add(h,origin)
        if #grids>=16 or not isUI(h) or not kind(h):find("PoolLayoutGrid",1,true) or seen[h] then return end
        seen[h]=true; grids[#grids+1]={object=h,origin=origin}
    end
    add(read(FromAddr,"Display 3.5.3.1.5.1.4.4"),"known-grid-address")
    for i=1,7 do
        if valid(roots[i]) then
            local first=method(roots[i],"FindRecursive","","AllPoolLayoutGrid")
            add(first,"display:"..i)
            local p=first
            for depth=1,3 do
                p=method(p,"Parent")
                if not isUI(p) then break end
                local siblings=ui(p,"UIChildren")
                if type(siblings)~="table" then siblings=method(p,"Children") end
                if type(siblings)=="table" then
                    local n=0
                    for _,s in pairs(siblings) do
                        n=n+1; if n>32 then break end
                        if isUI(s) then add(s,"near-grid:"..i); add(method(s,"FindRecursive","","AllPoolLayoutGrid"),"near-window:"..i) end
                    end
                end
            end
        end
    end
    local function path(h,name,countMethod)
        local r={name=name,success=false,complete=true,count=nil,examined=0,buttons={},samples={},classes={},usable=0}
        local function inspect(child)
            r.examined=r.examined+1
            if not valid(child) then r.complete=false; return end
            local k=kind(child)
            if #r.classes<6 then r.classes[#r.classes+1]=k end
            if not derived(k,"UIObject") or not derived(k,"AllPoolButton") or k:lower():find("pooltitlebutton",1,true) then return end
            local idx=tonumber(field(child,"ObjectIndex"))
            if not idx or idx<=0 then return end
            local token=read(HandleToStr,child)
            if type(token)~="string" or token=="" then r.complete=false; return end
            -- Compare widget-token + ObjectIndex sets within ONE grid. No
            -- CompareHandle/database target resolution is part of this probe.
            local key=token..":"..idx
            if not r.buttons[key] then
                r.buttons[key]=idx; r.usable=r.usable+1
                if #r.samples<8 then r.samples[#r.samples+1]=tostring(idx) end
            end
        end
        if not countMethod then
            local list,e
            if name=="UIChildren" then list,e=ui(h,name) else list,e=method(h,name) end
            r.error=e
            if type(list)~="table" then r.complete=false; return r end
            r.success=true; r.count=0
            for _,child in pairs(list) do
                r.count=r.count+1
                if r.count<=MAX_CHILDREN then inspect(child) else r.complete=false end
            end
        else
            local n,e
            if countMethod=="GetUIChildrenCount" then n,e=ui(h,countMethod) else n,e=method(h,countMethod) end
            r.error=e; r.count=n
            if type(n)~="number" or n<0 or n%1~=0 then r.complete=false; return r end
            r.success=true
            if n>MAX_CHILDREN then r.complete=false end
            for i=1,math.min(n,MAX_CHILDREN) do
                local child,why
                if name=="GetUIChild" then child,why=ui(h,name,i) else child,why=method(h,name,i) end
                if why then r.error=r.error or why end
                inspect(child)
            end
        end
        if remaining<=0 then r.complete=false; r.error="READ_LIMIT" end
        return r
    end
    local function difference(a,b)
        local n=0
        for k in pairs(a.buttons) do if not b.buttons[k] then n=n+1 end end
        for k in pairs(b.buttons) do if not a.buttons[k] then n=n+1 end end
        return n
    end
    local reports={}
    for index,item in ipairs(grids) do
        remaining=22000 -- independent per-grid read bound, no truncation verdict about discovery
        local h=item.object
        local visible,a,b,c=visibility(h)
        local pool=field(h,"PoolObject")
        log("GRID grid=%d origin=%s handle=%s class=%s address=%s native=%s pool_type=%s pool_class=%s pool_name=%s visible=%s actual=%s IsVisible=%s Visible=%s",index,item.origin,text(read(HandleToStr,h)),kind(h),text(method(h,"ToAddr")),text(method(h,"AddrNative")),text(field(h,"Pooltype")),valid(pool) and kind(pool) or "UNAVAILABLE",text(field(pool,"Name")),text(visible),text(a),text(b),text(c))
        if visible~=true then log("RESULT grid=%d classification=UNVERIFIED reason=NOT_CONFIRMED_VISIBLE",index)
        else
            local paths={path(h,"UIChildren"),path(h,"Children"),path(h,"GetUIChild","GetUIChildrenCount"),path(h,"Ptr","Count")}
            local u=paths[1]; local classification="UNVERIFIED"
            local allComplete=true; local mismatch=false; local alternativePositive=false
            for i,p in ipairs(paths) do
                if not p.success or not p.complete then allComplete=false end
                if i>1 then
                    if p.usable>0 then alternativePositive=true end
                    if u.success and u.complete and p.success and p.complete and difference(u,p)>0 then mismatch=true end
                end
                log("PATH grid=%d path=%s count=%s enumerated=%d AllPoolButtons=%d success=%s complete=%s first_classes=%s ObjectIndex_samples=%s error=%s",index,p.name,text(p.count),p.examined,p.usable,text(p.success),text(p.complete),table.concat(p.classes,","),table.concat(p.samples,","),text(p.error))
            end
            if u.success and u.complete and u.count==0 and alternativePositive then classification="EMPTY_UICHILDREN_FALLBACK_NEEDED"
            elseif mismatch then classification="CHILD_PATH_MISMATCH"
            elseif allComplete and u.usable>0 then classification="CHILD_PATHS_AGREE" end
            local chosen=u.success and u or paths[2]
            local missing={}
            for _,p in ipairs(paths) do for key in pairs(p.buttons) do if not chosen.buttons[key] then missing[key]=true end end end
            local missCount=0; for _ in pairs(missing) do missCount=missCount+1 end
            local productionMiss
            if chosen.success and chosen.complete then
                if missCount>0 then productionMiss=true elseif allComplete then productionMiss=false end
            end
            log("RESULT grid=%d classification=%s paths_disagree=%s production_path=%s production_buttons=%d production_would_miss=%s known_missing_buttons=%d remaining_reads=%d",index,classification,text(mismatch or classification=="EMPTY_UICHILDREN_FALLBACK_NEEDED"),chosen.name,chosen.usable,text(productionMiss),missCount,remaining)
            reports[#reports+1]={classification=classification,paths=paths,production_miss=productionMiss,production_path=chosen.name}
        end
    end
    log("END located_grids=%d visible_grids_tested=%d max_children_per_path=%d scope=CHILD_ENUMERATION_ONLY",#grids,#reports,MAX_CHILDREN)
    return reports
end
