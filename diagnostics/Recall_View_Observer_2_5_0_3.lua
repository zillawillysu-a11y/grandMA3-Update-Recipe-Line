-- Track B only. Writes diagnostic memory, never Show/UI/Programmer/playback.
local TARGET="2.5.0.3"
local STATE="DiDiDoRecallLifecycleObserver2503"
local KNOWN="Display 3.5.3.1.5.1.4.4"
return function(_,argument)
    local capped=false
    local capReasons={}
    local inventoryLimited=false
    local controlledLimited=false
    local budget=24000
    local lines=0
    local function log(fmt,...)
        if lines>=400 then
            capped=true; capReasons.OUTPUT_LINES=true
            if fmt:find("END",1,true)==1 then Printf("[RecallLife] "..fmt,...) end
            return
        end
        lines=lines+1; Printf("[RecallLife] "..fmt,...)
    end
    local function read(fn,...)
        if budget<=0 then capped=true; capReasons.READ_LIMIT=true; return nil,"READ_LIMIT" end
        budget=budget-1
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
    local function text(v) return v==nil and "UNAVAILABLE" or tostring(v):gsub("[\r\n]"," "):sub(1,180) end
    local function valid(h) if h==nil then return false end; return read(IsObjectValid,h) end
    local classCache={}
    local function isUI(h)
        if valid(h)~=true then return false end
        local k=method(h,"GetClass")
        if not k then return false end
        if classCache[k]==nil then classCache[k]=k=="UIObject" or read(IsClassDerivedFrom,k,"UIObject")==true end
        return classCache[k]
    end
    local function ui(h,k,...)
        if not isUI(h) then return nil,"NOT_UI_OBJECT" end
        return method(h,k,...)
    end
    local function normal(v)
        if v==nil then return nil end
        local s=tostring(v):lower()
        if v==true or s=="yes" or s=="true" or s=="1" then return true end
        if v==false or s=="no" or s=="false" or s=="0" then return false end
        return nil
    end
    local function same(a,b)
        if valid(a)~=true or valid(b)~=true then return nil end
        local v=read(CompareHandle,a,b)
        if type(v)=="boolean" then return v end
        return nil
    end
    local function metadata(h)
        local v=valid(h)
        return {object=h,valid=v,class=v==true and text(method(h,"GetClass")) or "UNAVAILABLE",
            address=v==true and text(method(h,"ToAddr")) or "UNAVAILABLE",
            native=v==true and text(method(h,"AddrNative")) or "UNAVAILABLE",
            handle=v==true and text(read(HandleToStr,h)) or "UNAVAILABLE"}
    end
    local function visibility(h)
        local m=metadata(h)
        if not isUI(h) then return m end
        m.actual,m.actual_error=ui(h,"IsActuallyVisible")
        m.isvisible=ui(h,"IsVisible"); m.visible=field(h,"Visible")
        local a,b,c=normal(m.actual),normal(m.isvisible),normal(m.visible)
        if a==false or b==false or c==false then m.signal=false
        elseif a==true or b==true or c==true then m.signal=true end
        return m
    end
    local build=read(BuildDetails)
    if type(build)~="table" or build.BigVersion~=TARGET then error("Requires grandMA3 "..TARGET) end
    for _,k in ipairs({"IsClassDerivedFrom","IsObjectValid","CompareHandle","GetDisplayByIndex"}) do
        if type(_G[k])~="function" then error(k.." required") end
    end
    if argument=="reset" then _G[STATE]=nil; log("RESET diagnostic memory only"); return end
    local saved=_G[STATE]
    local phase=saved and "AFTER" or "BEFORE"
    log("START phase=%s target=%s revision=2-controlled-lookup scope=GENERIC_POOL_UI_LIFECYCLE fixture=Generator103_104",phase,TARGET)
    -- Get every display root before any bounded local search.
    local roots={}
    for i=1,7 do roots[i]=read(GetDisplayByIndex,i); log("DISPLAY index=%d valid=%s",i,text(valid(roots[i]))) end
    local function attached(h)
        local seen={}
        for depth=0,20 do
            if valid(h)~=true or seen[h] then return nil end
            seen[h]=true
            for i=1,7 do if roots[i] and same(h,roots[i])==true then return true end end
            h=method(h,"Parent")
            if h==nil then return false end
        end
        return nil
    end
    local function children(h)
        local out,seen={},{}
        if not isUI(h) then return out end
        local function add(v)
            if isUI(v) and not seen[v] then seen[v]=true; out[#out+1]=v end
        end
        -- Inventory only; these paths never determine lifecycle classification.
        for _,path in ipairs({"UIChildren","Children"}) do
            local t=path=="UIChildren" and ui(h,path) or method(h,path)
            if type(t)=="table" then
                local n=0
                for _,v in pairs(t) do n=n+1; if n>128 then inventoryLimited=true; break end; add(v) end
            end
        end
        local n=ui(h,"GetUIChildrenCount")
        if type(n)=="number" then
            if n>128 then inventoryLimited=true end
            for i=1,math.min(n,128) do add(ui(h,"GetUIChild",i)) end
        end
        local count=method(h,"Count")
        if type(count)=="number" then
            if count>128 then inventoryLimited=true end
            for i=1,math.min(count,128) do add(method(h,"Ptr",i)) end
        end
        return out
    end
    local function parentMembership(h,p)
        if not isUI(p) then return nil end
        local complete=true
        local found=false
        for _,path in ipairs({"UIChildren","Children"}) do
            local values
            if path=="UIChildren" then values=ui(p,path) else values=method(p,path) end
            if type(values)~="table" then complete=false
            else
                local n=0
                for _,v in pairs(values) do
                    n=n+1; if n>128 then complete=false; break end
                    if same(v,h)==true then found=true end
                end
            end
        end
        for _,spec in ipairs({{"GetUIChildrenCount","GetUIChild"},{"Count","Ptr"}}) do
            local n=spec[1]=="GetUIChildrenCount" and ui(p,spec[1]) or method(p,spec[1])
            if type(n)~="number" or n<0 or n>128 then complete=false
            else
                for i=1,n do
                    local v
                    if spec[2]=="GetUIChild" then v=ui(p,spec[2],i) else v=method(p,spec[2],i) end
                    if same(v,h)==true then found=true end
                    if v==nil then complete=false end
                end
            end
        end
        if found then return true end
        if complete then return false end
        return nil
    end
    -- Lookup only controlled ObjectIndex values in direct native child lists.
    -- Never assume child position equals ObjectIndex or invent a cell offset.
    local function controlledButtons(h,pool)
        local found={}
        local inspected=0
        local function done() return found[103]~=nil and found[104]~=nil end
        local function inspect(button,path)
            inspected=inspected+1
            local idx=tonumber(field(button,"ObjectIndex"))
            if (idx==103 or idx==104) and not found[idx] and isUI(button)
                and method(button,"GetClass")=="AllPoolButton" then
                local item=visibility(button); item.index=idx; item.lookup_path=path
                item.target=metadata(valid(pool)==true and method(pool,"Ptr",idx) or nil)
                found[idx]=item
            end
        end
        local function scanList(list,path)
            if type(list)~="table" then return end
            local n=0
            for _,button in pairs(list) do
                if done() then return end
                n=n+1
                if n>512 then controlledLimited=true; return end
                inspect(button,path)
            end
        end
        scanList(ui(h,"UIChildren"),"UIChildren")
        if not done() then scanList(method(h,"Children"),"Children") end
        if not done() then
            for _,spec in ipairs({{"GetUIChildrenCount","GetUIChild"},{"Count","Ptr"}}) do
                if done() then break end
                local n
                if spec[1]=="GetUIChildrenCount" then n=ui(h,spec[1]) else n=method(h,spec[1]) end
                if type(n)=="number" and n>=0 then
                    for i=1,math.min(n,512) do
                        if done() then break end
                        local button
                        if spec[2]=="GetUIChild" then button=ui(h,spec[2],i) else button=method(h,spec[2],i) end
                        inspect(button,spec[2])
                    end
                    if n>512 and not done() then controlledLimited=true end
                end
            end
        end
        return found,inspected
    end
    local function snapshot(h)
        local s=visibility(h); s.buttons={}; s.attached=attached(h)
        if not isUI(h) then
            if s.valid==false then s.cache_accept=false end
            return s
        end
        -- EXACT production actuallyVisible predicate (v0.7.0.17, 1648-1653).
        s.cache_accept=s.valid~=nil and s.valid~=false and
            (s.actual==nil or s.actual==true or tostring(s.actual):lower()=="yes" or tostring(s.actual):lower()=="true" or tostring(s.actual):lower()=="1")
        local p=method(h,"Parent"); s.parent=visibility(p); s.grandparent=visibility(method(p,"Parent"))
        s.parent_membership=parentMembership(h,p)
        s.current=s.signal
        if s.parent.signal==false or s.grandparent.signal==false or s.attached==false or s.parent_membership==false then s.current=false end
        if s.attached~=true and s.current~=false then s.current=nil end
        local t=ui(h,"UIChildren"); s.ui_count=type(t)=="table" and #t or nil
        local pool=field(h,"PoolObject"); s.pool=metadata(pool)
        s.buttons,s.controlled_examined=controlledButtons(h,pool)
        return s
    end
    local function printObject(label,m)
        m=m or {}
        log("OBJECT role=%s handle=%s class=%s address=%s native=%s valid=%s actual=%s IsVisible=%s Visible=%s signal=%s",label,text(m.handle),text(m.class),text(m.address),text(m.native),text(m.valid),text(m.actual),text(m.isvisible),text(m.visible),text(m.signal))
    end
    local function emit(label,s)
        printObject(label..":GRID",s)
        printObject(label..":PARENT",s.parent); printObject(label..":GRANDPARENT",s.grandparent)
        log("GRID role=%s attached_to_active_display=%s current_visible=%s production_cache_accept=%s UIChildren_count=%s parent_contains_grid=%s",label,text(s.attached),text(s.current),text(s.cache_accept),text(s.ui_count),text(s.parent_membership))
        log("CONTROLLED_LOOKUP role=%s examined=%s",label,text(s.controlled_examined))
        for _,idx in ipairs({103,104}) do
            local b=s.buttons[idx]
            log("BUTTON role=%s ObjectIndex=%d exists=%s lookup_path=%s",label,idx,text(b~=nil),text(b and b.lookup_path))
            if b then printObject(label..":BUTTON:"..idx,b); printObject(label..":TARGET:"..idx,b.target) end
        end
    end
    local function generator(h)
        if not isUI(h) or method(h,"GetClass")~="AllPoolLayoutGrid" then return false end
        local p=field(h,"PoolObject")
        return valid(p)==true and method(p,"GetClass")=="Generators"
    end
    local candidates,seen={},{}
    local function candidate(h,origin)
        if generator(h) and not seen[h] then
            seen[h]=true; local s=snapshot(h); s.origin=origin; candidates[#candidates+1]=s
            log("CANDIDATE origin=%s handle=%s current_visible=%s",origin,s.handle,text(s.current))
        end
    end
    local address=saved and saved.before.address or KNOWN
    candidate(read(FromAddr,address),"saved-or-known-address")
    -- Native first-grid search plus only local immediate siblings. No global
    -- manual UI sweep or child fallback/budget root-cause claims.
    for i=1,7 do
        local root=roots[i]
        if valid(root)==true then
            local first=method(root,"FindRecursive","","AllPoolLayoutGrid")
            candidate(first,"display:"..i..":first-grid")
            if isUI(first) then
                for _,sib in ipairs(children(method(first,"Parent"))) do candidate(sib,"display:"..i..":sibling") end
            end
        end
    end
    local visible={}
    for _,c in ipairs(candidates) do if c.current==true then visible[#visible+1]=c end end
    local new=#visible==1 and visible[1] or nil
    if not saved then
        if not new or not new.buttons[103] or not new.buttons[104] or new.buttons[103].signal~=true or new.buttons[104].signal~=true or new.buttons[103].target.valid~=true or new.buttons[104].target.valid~=true or capped then
            log("END phase=BEFORE classification=UNVERIFIED reason=NEED_UNIQUE_VISIBLE_GRID_AND_103_104 visible_candidates=%d capped=%s",#visible,text(capped)); return {classification="UNVERIFIED"}
        end
        emit("BEFORE",new)
        _G[STATE]={before=new}
        log("PAUSE manually Recall a View that replaces/switches the Pool window, then press this SAME diagnostic Plugin once. No automatic Recall.")
        log("END phase=BEFORE classification=UNVERIFIED waiting_for_manual_recall=true")
        return {phase="BEFORE",before=new,classification="UNVERIFIED"}
    end
    local old=snapshot(saved.before.object); emit("OLD_AFTER",old)
    if new then emit("NEW_AFTER",new) else log("NEW_GRID_UNVERIFIED visible_candidates=%d",#visible) end
    local eq
    if new then eq=same(old.object,new.object) end
    local result="UNVERIFIED"
    if not capped and saved.before.current==true then
        if old.valid==true and old.cache_accept==true and old.current==false then
            result="LIFECYCLE_STALE_CACHE_CONFIRMED"
        elseif old.valid==true and old.cache_accept==true and new and eq==false and old.current~=true then
            result="LIFECYCLE_STALE_CACHE_CONFIRMED"
        elseif old.cache_accept==false and (old.valid==false or old.current==false or normal(old.actual)==false) then
            result="LIFECYCLE_NOT_REPRODUCED"
        end
    end
    log("COMPARE old_equals_new=%s OLD_valid=%s OLD_production_cache_accept=%s OLD_current_visible=%s NEW_found=%s NEW_103=%s NEW_104=%s address_unchanged=%s native_unchanged=%s",text(eq),text(old.valid),text(old.cache_accept),text(old.current),text(new~=nil),text(new and new.buttons[103]~=nil),text(new and new.buttons[104]~=nil),text(old.valid==true and old.address==saved.before.address),text(old.valid==true and old.native==saved.before.native))
    for _,idx in ipairs({103,104}) do
        local b=saved.before.buttons[idx]; local o=old.buttons[idx]; local n=new and new.buttons[idx]
        printObject("SAVED_BUTTON_AFTER:"..idx,visibility(b.object)); printObject("SAVED_TARGET_AFTER:"..idx,metadata(b.target.object))
        log("COMPARE_BUTTON index=%d old_contains_saved=%s old_contains_current=%s saved_target_equals_new=%s",idx,text(o and same(o.object,b.object)),text(o and n and same(o.object,n.object)),text(n and same(b.target.object,n.target.object)))
    end
    _G[STATE]=nil
    if capped then result="UNVERIFIED" end
    local reasons={}
    for k in pairs(capReasons) do reasons[#reasons+1]=k end
    table.sort(reasons)
    log("END phase=AFTER classification=%s capped=%s cap_reasons=%s inventory_limited=%s controlled_lookup_limited=%s remaining_reads=%d lines=%d next_run=BEFORE",result,text(capped),#reasons>0 and table.concat(reasons,",") or "NONE",text(inventoryLimited),text(controlledLimited),budget,lines)
    return {phase="AFTER",classification=result,old=old,new=new,equal=eq,capped=capped,inventory_limited=inventoryLimited,controlled_limited=controlledLimited}
end
