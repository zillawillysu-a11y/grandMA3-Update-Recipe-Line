-- Compact Track A runtime. No Cue/Part cooked history or diagnostic oracle.
local function newTrackARuntime(api)
    local function fail(reason) return {classification="INCONCLUSIVE", reason=reason, refs={}} end
    local function count(t) local n=0; for _ in pairs(t or {}) do n=n+1 end; return n end
    local function attrFG(attr)
        if api.class(attr):lower()~="attribute" then return nil end
        local feature=api.safe(function() return attr.Feature end)
        if api.class(feature):lower()~="feature" then return nil end
        local fg=api.safe(function() return feature:Parent() end)
        if api.class(fg):lower()~="featuregroup" then return nil end
        return api.identity(fg)
    end
    local function resolveHandle(value,expected)
        if api.class(value):lower()==expected then return value end
        if type(value)~="string" or not api.objectList then return nil end
        local list=api.safe(api.objectList,value)
        if type(list)=="table" and #list==1 and api.class(list[1]):lower()==expected then return list[1] end
    end
    local function memberUI(handle,cache)
        local id=handle
        if cache[id]~=nil then return cache[id] or nil end
        cache[id]=false
        local channels=api.safe(api.getUIChannels,handle,true)
        if type(channels)~="table" then return nil end
        local result={byFG={},byUI={}}
        cache.__featureGroupByUI=cache.__featureGroupByUI or {}
        local featureGroupByUI=cache.__featureGroupByUI
        local seen=0
        for _,channel in pairs(channels) do
            if type(channel)~="table" and type(channel)~="userdata" then return nil end
            local index=api.safe(function() return channel.INDEX end)
            if type(index)~="number" then index=api.safe(function() return channel:Get("INDEX") end) end
            if type(index)~="number" or index%1~=0 or index<1 then return nil end
            local ui=index-1
            if result.byUI[ui] then return nil end
            local fg=featureGroupByUI[ui]
            if fg==nil then
                local attr=api.safe(api.attributeByUI,ui)
                fg=attrFG(attr)
                if fg then featureGroupByUI[ui]=fg end
            end
            if not fg then return nil end
            result.byUI[ui]=fg; result.byFG[fg]=true; seen=seen+1
            if seen>65536 then return nil end
        end
        if seen==0 then return nil end
        cache[id]=result
        return result
    end
    local function ordinary(ref,cache)
        -- Reference metadata uses UI-channel records. Requesting the fixture
        -- view adds a by_fixtures table that this parser intentionally does
        -- not use for lane semantics.
        local raw=api.safe(api.getPresetData,ref,false,false)
        local rawKey=api.identity(ref)
        cache.__failure=cache.__failure or {}
        local function reject(reason)
            if rawKey then cache.__failure[rawKey]=reason end
            return nil
        end
        if rawKey then cache.__failure[rawKey]="ORDINARY_CHANNEL_SHAPE_UNPROVEN" end
        if rawKey then
            cache.__raw=cache.__raw or {}
            cache.__raw[rawKey]=raw or false
        end
        if type(raw)~="table" then
            if rawKey then cache.__failure[rawKey]="ORDINARY_REFERENCE_DATA_UNAVAILABLE" end
            return nil
        end
        local mode,scope,channels=nil,{},0
        local moving=false
        local knownBits=1|2|4|8|16|32|64|128|256
        for ui,p in pairs(raw) do
            if type(ui)=="number" then
                if rawKey then cache.__failure[rawKey]="ORDINARY_CHANNEL_HEADER_UNPROVEN" end
                if ui%1~=0 or type(p)~="table" then return reject("UI_RECORD_SHAPE") end
                channels=channels+1
                if channels>262144 then return reject("CHANNEL_LIMIT") end
                local pm=p.preset_store_mode or p.pm
                if p.pm~=nil and p.preset_store_mode~=nil and p.pm~=p.preset_store_mode then return reject("PRESET_MODE_FIELDS_CONFLICT") end
                if pm~=1 and pm~=2 and pm~=3 then return reject("PRESET_MODE_FIELD_SHAPE") end
                if mode and pm~=mode then return reject("PRESET_MODE_CHANNEL_CONFLICT") end
                mode=pm
                if pm==1 and p.selective~=true then return reject("SELECTIVE_FLAG_UNPROVEN") end
                if pm~=1 and p.selective==true then return reject("NONSELECTIVE_FLAG_CONFLICT") end
                if p.mask_cooked~=nil and p.mask_cooked~=0 then return reject("COOKED_MASK_ACTIVE") end
                for _,field in ipairs({"speed","phase","measure","nshot_count","fade","delay",
                    "speed_master","abs_generator","rel_generator","generator","abs_preset","rel_preset"}) do
                    local value=p[field]
                    if value~=nil and value~=false and value~=0 then return reject("ACTIVE_CHANNEL_FIELD_"..field) end
                end
                local known={attribute=true,abs_preset=true,rel_preset=true,abs_generator=true,rel_generator=true,generator=true,
                    mask_active_phaser=true,mask_active_value=true,mask_cooked=true,mask_individual=true,mask_integrated=true,
                    dict_flags=true,dict_index=true,gridposmatr=true,gridpos=true,grid=true,phase=true,speed=true,
                    measure=true,fade=true,delay=true,selective=true,preset_store_mode=true,pm=true,ui_channel_index=true,
                    grid_origin=true,grid_matrix=true,nshot_count=true,nshot_flags=true,speed_master=true}
                for k,v in pairs(p) do if type(k)=="string" and not known[k] and v~=nil and v~=false and v~=0 then return reject("UNKNOWN_CHANNEL_FIELD_"..k) end end
                if p.ui_channel_index~=nil and p.ui_channel_index~=ui then return reject("UI_CHANNEL_INDEX_MISMATCH") end
                if type(p.dict_flags)=="table" then for k,v in pairs(p.dict_flags) do
                    if not ({has_absolute=true,has_relative=true,selective=true,blocked=true,blocked_rel=true})[k]
                        and v~=nil and v~=false and v~=0 then return reject("UNKNOWN_DICT_FLAG_"..k) end
                    if (k=="blocked" or k=="blocked_rel") and v~=nil and v~=false and v~=0 then return reject("BLOCKED_DICT_FLAG_"..k) end
                end elseif p.dict_flags~=nil then return reject("DICT_FLAGS_SHAPE") end
                if type(p.dict_flags)=="table" and p.dict_flags.selective~=nil
                    and p.dict_flags.selective~=false and p.dict_flags.selective~=0 and pm~=1 then return reject("DICT_SELECTIVE_MODE_CONFLICT") end
                local phaser=p.mask_active_phaser
                local mask=p.mask_active_value
                if type(phaser)~="number" or math.type(phaser)~="integer" or phaser<0 or phaser & ~knownBits~=0 then return reject("ACTIVE_PHASER_MASK_SHAPE") end
                if type(mask)~="number" or math.type(mask)~="integer" or mask & ~(2|4)~=0 or mask==0 then return reject("ACTIVE_VALUE_MASK_SHAPE") end
                if type(p.dict_flags)=="table" then
                    for _,spec in ipairs({{"has_absolute",2,"absolute"},{"has_relative",4,"relative"}}) do
                        local flag,bit,field=table.unpack(spec)
                        local value=p.dict_flags[flag]
                        if value~=nil and value~=false and value~=0
                            and not ((value==true or value==1) and mask & bit~=0
                                and type(p[1])=="table" and type(p[1][field])=="number") then return reject("DICT_VALUE_CONFLICT_"..flag) end
                    end
                end
                if phaser & (1|2)~=0 then return reject("PHASER_PRESET_DEPENDENCY_ACTIVE") end
                local attr=p.attribute or api.safe(api.attributeByUI,ui)
                if rawKey then cache.__failure[rawKey]="ORDINARY_ATTRIBUTE_FG_UNPROVEN" end
                local fg=attrFG(attr)
                if not fg then return reject("ORDINARY_ATTRIBUTE_FG_UNPROVEN(ui="..tostring(ui)..")") end
                if rawKey then cache.__failure[rawKey]="ORDINARY_STEP_SHAPE_UNPROVEN" end
                local steps,n={},0
                for k,v in pairs(p) do if type(k)=="number" then
                    if k%1~=0 or k<1 or type(v)~="table" then
                        return reject("ORDINARY_STEP_RECORD_SHAPE_UNPROVEN(ui="..tostring(ui)
                            ..",index="..tostring(k)..",type="..type(v)..")")
                    end
                    n=n+1; steps[k]=v
                end end
                if n==0 or n>256 then return reject("ORDINARY_STEP_COUNT_UNPROVEN(ui="..tostring(ui)..",count="..tostring(n)..")") end
                local stepKnown={absolute=true,relative=true,absolute_value=true,abs_release=true,rel_release=true,
                    abs_remove=true,rel_remove=true,abs_preset=true,rel_preset=true,integrated=true,accel=true,
                    decel=true,trans=true,transition=true,width=true,channel_function=true,mask_active=true,
                    mask_individual=true,mask_integrated=true,dict_flags=true}
                for i=1,n do
                    if not steps[i] then return reject("ORDINARY_STEP_INDEX_GAP(ui="..tostring(ui)..",index="..tostring(i)..")") end
                    if steps[i].absolute_value~=nil
                        and (type(steps[i].absolute_value)~="number" or type(steps[i].absolute)~="number"
                            or mask & 2==0) then return reject("ORDINARY_ABSOLUTE_VALUE_SHAPE_UNPROVEN(ui="..tostring(ui)..")") end
                    for k,v in pairs(steps[i]) do
                        if type(k)=="string" and not stepKnown[k] and v~=nil then
                            return reject("ORDINARY_UNKNOWN_STEP_FIELD(ui="..tostring(ui)..",field="..tostring(k)..")")
                        end
                        if (k=="abs_release" or k=="rel_release" or k=="abs_remove" or k=="rel_remove"
                            or k=="abs_preset" or k=="rel_preset" or k=="integrated") and v~=nil and v~=false and v~=0 then
                            return reject("ORDINARY_ACTIVE_STEP_DEPENDENCY(ui="..tostring(ui)..",field="..tostring(k)..")")
                        end
                    end
                end
                local motionBits=4|8|16|32|128|256
                if rawKey then cache.__failure[rawKey]="ORDINARY_LANE_VALUE_UNPROVEN" end
                for _,spec in ipairs({{"ABS","absolute",2},{"REL","relative",4}}) do
                    local layer,field,bit=table.unpack(spec)
                    if mask & bit~=0 then
                        local values={}
                        for i=1,n do
                            local step=steps[i]
                            local value=step and step[field]
                            if type(value)~="number" then
                                return reject("ORDINARY_LANE_VALUE_UNPROVEN(ui="..tostring(ui)
                                    ..",layer="..layer..",type="..type(value)..",mask="..tostring(mask)..")")
                            end
                            if value~=value or math.abs(value)==math.huge then
                                return reject("ORDINARY_LANE_VALUE_NONFINITE(ui="..tostring(ui)
                                    ..",layer="..layer..",mask="..tostring(mask)..")")
                            end
                            values[tostring(value)]=true
                        end
                        local channelMoving=phaser & motionBits~=0 or count(values)>1
                        moving=moving or channelMoving
                        local lane=fg.."|"..layer
                        scope[lane]=scope[lane] or {fg=fg,layer=layer,storedUI={},moving=false}
                        if next(scope[lane].storedUI) and scope[lane].moving~=channelMoving then
                            return reject("ORDINARY_LANE_CONFLICT(ui="..tostring(ui)..",lane="..lane..")")
                        end
                        scope[lane].storedUI[ui]=true
                        scope[lane].moving=channelMoving
                    end
                end
            elseif ui=="by_fixtures" then if raw.by_fixtures~=false then return reject("BY_FIXTURES_SHAPE_UNPROVEN") end
            elseif ui~="count" then return reject("ORDINARY_TOP_LEVEL_FIELD_UNPROVEN("..tostring(ui)..")") end
        end
        if rawKey then cache.__failure[rawKey]="ORDINARY_REFERENCE_SUMMARY_UNPROVEN" end
        if channels==0 or (raw.count~=nil and raw.count~=channels) or not next(scope) then
            return reject("ORDINARY_CHANNEL_SUMMARY_UNPROVEN(channels="..tostring(channels)
                ..",count="..tostring(raw.count)..",lanes="..tostring(count(scope))..")")
        end
        -- Static ordinary references require the proven single-step, no-motion
        -- shape. Moving references require explicit motion bits or step change.
        if not moving then
            for _,p in pairs(raw) do if type(p)=="table" and type(p[1])=="table" then
                local n=0
                for k in pairs(p) do if type(k)=="number" then n=n+1 end end
                if n~=1 then return reject("ORDINARY_STATIC_STEP_COUNT_UNPROVEN(count="..tostring(n)..")") end
            end end
            for _,lane in pairs(scope) do lane.moving=false end
        else
            for laneName,lane in pairs(scope) do if not lane.moving then
                return reject("ORDINARY_MOVING_LANE_CONFLICT(lane="..tostring(laneName)..")")
            end end
        end
        if rawKey then cache.__failure[rawKey]=nil end
        return {kind="ORDINARY",mode=mode,lanes=scope,raw=raw}
    end
    local function propertyMap(node)
        local props={}; local n=api.safe(function() return node:PropertyCount() end)
        if type(n)~="number" or n<0 or n>512 then return nil end
        for i=0,n-1 do
            local name=api.safe(function() return node:PropertyName(i) end)
            if type(name)=="string" then
                local value=api.safe(function() return node[name] end)
                if value==nil then value=api.safe(function() return node:Get(name) end) end
                props[name:lower()]=value
            end
        end
        return props
    end
    local function relZero(node,raw)
        if type(raw)=="string" and raw=="None" then return "ABSENT" end
        if type(raw)=="string" and tonumber(raw) and tonumber(raw)~=0 then return "AUTHORED" end
        if type(raw)~="number" then return "UNKNOWN" end
        if raw~=0 then return "AUTHORED" end
        local direct=api.safe(function() return node.ValueRelative end)
        local getter=api.safe(function() return node:Get("ValueRelative") end)
        local role=((_G.Enums or {}).Roles or {}).Display
        local display=role and api.safe(function() return node:Get("ValueRelative",role) end)
        local function empty(x) return x==nil or type(x)=="string" and x:match("^%s*$")~=nil end
        if empty(direct) and empty(getter) and empty(display) then return "ABSENT" end
        if direct==0 and getter==0 and tonumber(display)==0 then return "AUTHORED" end
        return "UNKNOWN"
    end
    local function phaser(ref,referenceCache)
        local refKey=api.identity(ref)
        referenceCache.__failure=referenceCache.__failure or {}
        if refKey then referenceCache.__failure[refKey]="PHASER_STRUCTURE_UNPROVEN" end
        local steps,linked,features,recipes,stepCount={}, {}, {},0,0
        local mismatch=false; local unknownRel=false
        local function walk(node,step,depth)
            if depth>8 then mismatch=true; return end
            local c=api.class(node):lower()
            if c=="phaserrecipe" then recipes=recipes+1 end
            if c=="phaserrecipestep" then step=node; stepCount=stepCount+1 end
            if c=="phaserrecipevaluesource" then
                if not step then mismatch=true; return end
                local p=propertyMap(node)
                if not p then mismatch=true; return end
                local attr=resolveHandle(p.attributes or p.attribute,"attribute")
                local fg=attrFG(attr)
                if not fg then mismatch=true; return end
                features[fg]=true
                local link=p.preset and resolveHandle(p.preset,"preset")
                if p.preset~=nil and tostring(p.preset)~="" and not link then mismatch=true; return end
                if link then
                    local id=api.identity(link) or link
                    linked[id]=linked[id] or {handle=link,fgs={}}
                    linked[id].fgs[fg]=true
                end
                local function record(layer,value)
                    if type(value)~="number" or value~=value then mismatch=true; return end
                    local key=fg.."|"..layer
                    steps[key]=steps[key] or {fg=fg,layer=layer,values={},stepIds={}}
                    steps[key].values[tostring(value)]=true
                    steps[key].stepIds[step]=true
                end
                local shape=p.shape and resolveHandle(p.shape,"phaserrecipevaluesource")
                if p.shape~=nil and tostring(p.shape)~="" and not shape then mismatch=true; return end
                local inherited=shape and propertyMap(shape) or nil
                local av=p.rawvalueabs
                if (av==nil or av=="") and inherited then av=inherited.rawvalueabs end
                if (type(av)=="number" or type(av)=="string") and tonumber(av) then
                    record("ABS",tonumber(p.valueabsolute) or tonumber(av))
                elseif av~=nil and av~="" and av~="None" then mismatch=true end
                local rv=p.rawvaluerel
                if (rv==nil or rv=="") and inherited then rv=inherited.rawvaluerel end
                local rel=relZero(node,rv)
                if rel=="AUTHORED" then record("REL",tonumber(p.valuerelative) or tonumber(rv))
                elseif rel=="UNKNOWN" and rv~=nil then unknownRel=true end
            end
            for _,child in ipairs(api.children(node)) do walk(child,step,depth+1) end
        end
        walk(ref,nil,0)
        if mismatch or recipes~=1 or stepCount<1 or not next(steps) then return nil end
        local lanes={}; local provenMovingAbs=false
        for key,s in pairs(steps) do
            if count(s.stepIds)~=stepCount then return nil end
            local moving=count(s.values)>1
            lanes[key]={fg=s.fg,layer=s.layer,moving=moving}
            if s.layer=="ABS" and moving then provenMovingAbs=true end
        end
        local linkedCount=0
        if refKey then referenceCache.__failure[refKey]="PHASER_LINKED_PRESET_UNPROVEN" end
        for _,entry in pairs(linked) do
            linkedCount=linkedCount+1
            local handle=entry.handle
            local key=api.identity(handle) or handle
            local meta=referenceCache[key]
            if meta==nil then meta=ordinary(handle,referenceCache); referenceCache[key]=meta or false end
            if type(meta)~="table" or meta.kind~="ORDINARY" or meta.mode==1 then return nil end
            if meta.mode~=2 and meta.mode~=3 then return nil end
            for _,lane in pairs(meta.lanes) do if lane.moving or lane.layer~="ABS" then return nil end end
            for fg in pairs(entry.fgs) do if not meta.lanes[fg.."|ABS"] then return nil end end
        end
        if unknownRel then
            if not provenMovingAbs or count(features)~=1 or linkedCount==0 then return nil end
            if refKey then referenceCache.__failure[refKey]=nil end
            return {kind="PHASER",lanes=lanes,relBarrier=next(features)}
        end
        if refKey then referenceCache.__failure[refKey]=nil end
        return {kind="PHASER",lanes=lanes}
    end
    local function metadata(ref,cache)
        local key=api.identity(ref)
        if not key then return nil end
        if cache[key]~=nil then return cache[key] or nil end
        local c=api.class(ref):lower()
        local m
        if c=="preset" then
            local structural=false
            for _,child in ipairs(api.children(ref)) do if api.class(child):lower()=="phaserrecipe" then structural=true; break end end
            m=structural and phaser(ref,cache) or ordinary(ref,cache)
        elseif c=="random" or c=="generator" or c=="generatorrandom" then
            m={kind="GENERATOR",lanes={}}
            local channels=api.safe(function() return ref.RandomChannels end)
            if channels==nil then for _,child in ipairs(api.children(ref)) do
                if api.class(child):lower()=="randomchannels" then channels=child; break end
            end end
            for _,channel in ipairs(api.children(channels)) do
                local attr=api.safe(function() return channel.Attribute end)
                local fg=attrFG(attr)
                if not fg then m=nil; break end
                m.lanes[fg.."|ABS"]={fg=fg,layer="ABS",moving=true}
            end
            if m and not next(m.lanes) then m=nil end
        elseif c=="phaserrecipe" then m=phaser(ref,cache) end
        cache[key]=m or false
        return m
    end
    -- Preserve only scope which the reference metadata independently proves.
    -- An unknown feature or layer becomes a conservative wildcard barrier.
    local function unsafeScope(ref,cache)
        local id=api.identity(ref)
        local raw=id and cache.__raw and cache.__raw[id]
        local features,layers={},{}
        local featureKnown,layerKnown,seen=true,true,false
        if type(raw)=="table" then for ui,p in pairs(raw) do if type(ui)=="number" then
            seen=true
            if type(p)~="table" then featureKnown=false; layerKnown=false
            else
                local fg=attrFG(p.attribute or api.safe(api.attributeByUI,ui))
                if fg then features[fg]=true else featureKnown=false end
                local mask=p.mask_active_value
                if type(mask)=="number" and math.type(mask)=="integer"
                    and mask>0 and mask & ~(2|4)==0 then
                    if mask & 2~=0 then layers.ABS=true end
                    if mask & 4~=0 then layers.REL=true end
                else layerKnown=false end
            end
        end end
        else
            local function walk(node,depth)
                if depth>8 then featureKnown=false; layerKnown=false; return end
                if api.class(node):lower()=="phaserrecipevaluesource" then
                    seen=true
                    local p=propertyMap(node)
                    if not p then featureKnown=false; layerKnown=false
                    else
                        local attr=resolveHandle(p.attributes or p.attribute,"attribute")
                        local fg=attrFG(attr)
                        if fg then features[fg]=true else featureKnown=false end
                        local shape=p.shape and resolveHandle(p.shape,"phaserrecipevaluesource")
                        local inherited=shape and propertyMap(shape)
                        if p.shape~=nil and tostring(p.shape)~="" and not inherited then layerKnown=false end
                        local av=p.rawvalueabs
                        if (av==nil or av=="") and inherited then av=inherited.rawvalueabs end
                        local rv=p.rawvaluerel
                        if (rv==nil or rv=="") and inherited then rv=inherited.rawvaluerel end
                        if tonumber(av) then layers.ABS=true
                        elseif av~=nil and av~="" and av~="None" then layerKnown=false end
                        local rel=relZero(node,rv)
                        if rel=="AUTHORED" or rel=="UNKNOWN" then layers.REL=true end
                        if av==nil and rv==nil and not inherited then layerKnown=false end
                    end
                end
                for _,child in ipairs(api.children(node)) do walk(child,depth+1) end
            end
            walk(ref,0)
        end
        return seen and featureKnown and next(features) and features or nil,
            seen and layerKnown and next(layers) and layers or nil
    end
    local function run(rows,members,referenceCache,uiCache)
        local normalized={}
        for _,source in ipairs(rows) do
            local row={ref=source.ref,refId=api.identity(source.ref),group=source.group,
                members={},lanes={},superseded={}}
            if not row.refId then return fail("REFERENCE_IDENTITY_UNPROVEN") end
            for key,handle in pairs(members) do
                if source.groupMembers[key] then row.members[key]=handle end
            end
            if next(row.members) then
                local meta=metadata(source.ref,referenceCache)
                if not meta then
                    row.unsafe=true
                    row.features,row.layers=unsafeScope(source.ref,referenceCache)
                else
                    for key,handle in pairs(row.members) do
                        local ui=memberUI(handle,uiCache)
                        if not ui then return fail("MEMBER_UI_CAPABILITY_UNPROVEN") end
                        for lane,data in pairs(meta.lanes) do
                            local applicable=ui.byFG[data.fg]
                            if meta.kind=="ORDINARY" and meta.mode==1 then
                                applicable=false
                                for stored in pairs(data.storedUI) do
                                    if ui.byUI[stored]==data.fg then applicable=true; break end
                                end
                            end
                            if applicable then
                                row.lanes[key]=row.lanes[key] or {}
                                row.lanes[key][lane]=data
                            end
                        end
                    end
                    if meta.relBarrier then row.relBarrier=meta.relBarrier end
                end
                normalized[#normalized+1]=row
            end
        end
        local decided,blocked,refs,activeRefs,survivors,assignments,unsafeRows={},{},{},{},{},{},{}
        local residual={}; local laneWork=0
        local function checkpoint()
            laneWork=laneWork+1
            return laneWork<=1048576
        end
        local function barrierKeys(row)
            local keys={}
            for member in pairs(row.members) do
                if not row.features then keys[member.."\0*"]=true
                else for feature in pairs(row.features) do
                    if not row.layers then keys[member.."\0"..feature.."|*"]=true
                    else for layer in pairs(row.layers) do
                        keys[member.."\0"..feature.."|"..layer]=true
                    end end
                end end
            end
            return keys
        end
        for index,row in ipairs(normalized) do
            row.reverseIndex=index
            if row.unsafe then
                unsafeRows[#unsafeRows+1]=row
                for key in pairs(row.members) do
                    if not checkpoint() then return fail("LANE_WORK_LIMIT") end
                    blocked[key]=blocked[key] or {}
                    if not row.features then blocked[key]["*"]=blocked[key]["*"] or row
                    else for feature in pairs(row.features) do
                        if not row.layers then
                            local lane=feature.."|*"
                            blocked[key][lane]=blocked[key][lane] or row
                        else for layer in pairs(row.layers) do
                            local lane=feature.."|"..layer
                            blocked[key][lane]=blocked[key][lane] or row
                        end end
                    end end
                end
            else
                for key,lanes in pairs(row.lanes) do
                    decided[key]=decided[key] or {}
                    for lane,data in pairs(lanes) do
                        if not checkpoint() then return fail("LANE_WORK_LIMIT") end
                        local old=decided[key][lane]
                        local barrier
                        for _,candidateKey in ipairs({lane,data.fg.."|*","*"}) do
                            local candidate=(blocked[key] or {})[candidateKey]
                            if candidate and (not barrier or candidate.reverseIndex<barrier.reverseIndex) then
                                barrier=candidate
                            end
                        end
                        if old then row.superseded[#row.superseded+1]={member=key,lane=lane,newer=old}
                        elseif barrier then
                            row.superseded[#row.superseded+1]={member=key,lane=lane,newer=barrier,unsafe=true}
                        else
                            decided[key][lane]=row
                            assignments[#assignments+1]={member=key,lane=lane,fg=data.fg,row=row,
                                moving=data.moving==true}
                            activeRefs[row.refId]=row.ref
                            if data.moving then
                                refs[row.refId]=row.ref
                                survivors[row.refId]=survivors[row.refId] or {}
                                survivors[row.refId][key]=true
                            end
                        end
                    end
                    if row.relBarrier then
                        local lane=row.relBarrier.."|REL"
                        if uiCache[row.members[key]].byFG[row.relBarrier]
                            and not decided[key][lane] and not (blocked[key] or {})[lane] then
                            blocked[key]=blocked[key] or {}
                            local barrier={reverseIndex=index,relResidual=true,
                                member=key,feature=row.relBarrier,layer="REL"}
                            blocked[key][lane]=barrier
                            residual[#residual+1]=barrier
                        end
                    end
                end
            end
        end
        local decidedByKey,unresolvedByKey,victims={},{},{}
        for _,a in ipairs(assignments) do decidedByKey[a.member.."\0"..a.lane]=a.row end
        for member,lanes in pairs(blocked) do for lane,row in pairs(lanes) do
            local key=member.."\0"..lane
            if not decidedByKey[key] then unresolvedByKey[key]=row end
        end end
        for _,row in ipairs(normalized) do for _,sup in ipairs(row.superseded) do
            if sup.unsafe then victims[sup.newer]=(victims[sup.newer] or 0)+1 end
        end end
        local attribution={finalSurviving={},fullySuperseded={},unknown={}}
        for _,row in ipairs(unsafeRows) do
            local keys=barrierKeys(row)
            local total,surviving,neutralized=0,0,0
            for key in pairs(keys) do
                total=total+1
                if unresolvedByKey[key]==row then surviving=surviving+1
                else
                    local decider=decidedByKey[key]
                    local newer=unresolvedByKey[key]
                    if (decider and decider.reverseIndex<row.reverseIndex)
                        or (newer and newer.reverseIndex<row.reverseIndex) then
                        neutralized=neutralized+1
                    end
                end
            end
            if surviving>0 or (victims[row] or 0)>0 or (refs[row.refId] and total>0) then
                attribution.finalSurviving[#attribution.finalSurviving+1]=row
            elseif total>0 and neutralized==total then
                attribution.fullySuperseded[#attribution.fullySuperseded+1]=row
            else attribution.unknown[#attribution.unknown+1]=row end
        end
        if #attribution.finalSurviving>0 or #attribution.unknown>0 then
            local blockers={}
            for _,list in ipairs({attribution.finalSurviving,attribution.unknown}) do
                for _,row in ipairs(list) do
                    local id=row.refId
                    if id then blockers[id]=true end
                end
            end
            local blockerRefs={}
            for id in pairs(blockers) do blockerRefs[#blockerRefs+1]=id end
            table.sort(blockerRefs)
            local blockerDetails={}
            for _,id in ipairs(blockerRefs) do
                blockerDetails[id]=(referenceCache.__failure or {})[id] or "UNSAFE_SCOPE_OR_ATTRIBUTION"
            end
            return {classification="INCONCLUSIVE",reason="UNSAFE_LANE_ATTRIBUTION_BLOCKER",
                refs={},unsafeAttribution=attribution,unsafeRefs=blockerRefs,
                unsafeRefDetails=blockerDetails,
                laneWork=laneWork}
        end
        for _,barrier in ipairs(residual) do
            -- A residual REL barrier may also suppress an older unsafe row.
            -- Its absence from the final reference set is not evidence of safety.
            for _,older in ipairs(unsafeRows) do
                if older.reverseIndex>barrier.reverseIndex and older.members[barrier.member]
                    and (not older.features or older.features[barrier.feature])
                    and (not older.layers or older.layers[barrier.layer]) then
                    return fail("REL_BARRIER_BLOCKS_HISTORY")
                end
            end
            if (victims[barrier] or 0)>0 then return fail("REL_BARRIER_BLOCKS_HISTORY") end
        end
        local sourceGroups={}
        for _,assignment in ipairs(assignments) do
            if assignment.row.group then
                local groupId=api.identity(assignment.row.group)
                if groupId then sourceGroups[groupId]=assignment.row.group end
            end
        end
        local laneAssignments={}
        for _,assignment in ipairs(assignments) do
            laneAssignments[#laneAssignments+1]={member=assignment.member,fg=assignment.fg,
                refId=assignment.row.refId,ref=assignment.row.ref,
                group=assignment.row.group,moving=assignment.moving}
        end
        return {classification="PROVEN",refs=refs,activeRefs=activeRefs,
            laneAssignments=laneAssignments,refMembers=survivors,
            sourceGroups=sourceGroups,barriers=#residual,
            unsafeAttribution=attribution,laneWork=laneWork,remainingSemanticBlockers=0}
    end
    return {run=run,metadata=metadata,memberUI=memberUI}
end
