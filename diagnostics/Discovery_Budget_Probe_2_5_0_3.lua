-- Read-only production discovery replay and independent typed UI inventory.
return function()
 local function safe(f,...) if type(f)~='function' then return nil end; local ok,v=pcall(f,...); if ok then return v end end
 local function method(h,k,...) return safe(function(...) return h[k](h,...) end,...) end
 local function field(h,k) local v=safe(function() return h[k] end); if v==nil then v=method(h,'Get',k) end; return v end
 local function text(v) return v==nil and 'UNAVAILABLE' or tostring(v):gsub('[\r\n]',' '):sub(1,160) end
 local function class(h) return h and (method(h,'GetClass') or '') or '' end
 local function valid(h) return h~=nil and safe(IsObjectValid,h)==true end
 local derived={}
 local function isUI(h)
  if not valid(h) then return false end
  local k=class(h); if derived[k]==nil then derived[k]=k=='UIObject' or safe(IsClassDerivedFrom,k,'UIObject')==true end
  return derived[k]
 end
 local unsafe=false
 local function ui(h,k,...) if not isUI(h) then unsafe=true; return nil end; return method(h,k,...) end
 local function log(f,...) Printf('[DiscoveryBudget] '..f,...) end
 local build=safe(BuildDetails); assert(type(build)=='table' and build.BigVersion=='2.5.0.3','Requires grandMA3 2.5.0.3')
 assert(type(IsClassDerivedFrom)=='function' and type(IsObjectValid)=='function' and type(HandleToStr)=='function','UI type/identity APIs required')
 local roots={}; local mode=type(GetDisplayByIndex)=='function' and 'DISPLAY_1_TO_7' or 'FOCUS_ONLY'
 if mode=='DISPLAY_1_TO_7' then for i=1,7 do roots[i]=safe(GetDisplayByIndex,i) end else roots[1]=safe(GetFocusDisplay) end
 local state=rawget(_G,'RecipeTrackingInspectorState')
 local window=type(state)=='table' and state.window or nil
 local function actual(h)
  if h==nil then return false end
  if type(IsObjectValid)=='function' then local v=safe(IsObjectValid,h); if v==nil or v==false then return false end end
  local v=ui(h,'IsActuallyVisible'); if v==nil then return true end
  local n=tostring(v):lower(); return v==true or n=='yes' or n=='true' or n=='1'
 end
 local cacheAccepted=0; local refresh=type(state)=='table' and state.poolGridRefreshNeeded==true or false
 if type(state)=='table' then for _,g in ipairs(state.poolGrids or {}) do if actual(g) then cacheAccepted=cacheAccepted+1 else refresh=true end end end
 local cacheDiscover=cacheAccepted==0 or refresh
 log('START target=2.5.0.3 revision=1 mode=%s production_budget=6000 cache_state_available=%s cache_accepted=%d cache_refresh_needed=%s production_cache_would_discover=%s replay=COLD_DISCOVERY window_available=%s',mode,text(type(state)=='table'),cacheAccepted,text(refresh),text(cacheDiscover),text(window~=nil))
 local function prodChildren(h)
  local v=ui(h,'UIChildren'); if type(v)=='table' then return v end
  v=method(h,'Children'); return type(v)=='table' and v or {}
 end
 local replay,shadow,truth={},{},{}
 local per,shadowPer={},{}
 local total,position=0,0; local exhaustion; local seen={}; local shadowCapped=false
 -- One faithful DFS prefix plus bounded same-algorithm continuation: the
 -- continuation proves whether a missed grid is reachable solely beyond 6000.
 local function visit(h,depth,display)
  if not h or seen[h] or depth>20 then return end
  if shadowPer[display]>=20000 then shadowCapped=true; return end
  seen[h]=true; position=position+1; shadowPer[display]=shadowPer[display]+1
  local admitted=position<=6000
  if admitted then total=total+1; per[display]=per[display]+1; if total==6000 then exhaustion={display=display,address=text(method(h,'ToAddr')),position=position} end end
  if h==window then return end
  if class(h):find('PoolLayoutGrid',1,true) then
   local r={handle=h,display=display,position=position,nodes=position,accepted=actual(h)}
   shadow[h]=r; if admitted and r.accepted then replay[h]=r end
   return
  end
  for _,c in ipairs(prodChildren(h)) do visit(c,depth+1,display) end
 end
 for i=1,7 do per[i]=0; shadowPer[i]=0; visit(roots[i],0,i) end
 local function boolean(v) local n=tostring(v):lower(); if v==true or n=='true' or n=='yes' or n=='1' then return true end; if v==false or n=='false' or n=='no' or n=='0' then return false end end
 local function visible(h)
  local a,b,c=ui(h,'IsActuallyVisible'),ui(h,'IsVisible'),field(h,'Visible')
  local signal=boolean(a)==true or boolean(b)==true or boolean(c)==true
  local p=h; local visited={}; local attached=false
  for _=1,32 do
   if not isUI(p) or visited[p] then break end; visited[p]=true
   if boolean(ui(p,'IsActuallyVisible'))==false or boolean(ui(p,'IsVisible'))==false or boolean(field(p,'Visible'))==false then return false,a,b,c end
   for i=1,7 do if p==roots[i] then attached=true end end
   if attached then break end; p=method(p,'Parent')
  end
  return signal and attached or nil,a,b,c
 end
 local gtCapped,gtUnknown=false,false; local gtPer={}; local gtPosition=0; local gtSeen={}
 local function edges(h)
  local out,used={},{}; local any=false
  local function add(c) if isUI(c) and not used[c] then used[c]=true; out[#out+1]=c end end
  for _,k in ipairs({'UIChildren','Children'}) do
   local list=k=='UIChildren' and ui(h,k) or method(h,k)
   if type(list)=='table' then any=true; local n=0; for _,c in pairs(list) do n=n+1; if n<=1024 then add(c) else gtCapped=true end end end
  end
  for _,spec in ipairs({{'GetUIChildrenCount','GetUIChild'},{'Count','Ptr'}}) do
   local n=spec[1]=='GetUIChildrenCount' and ui(h,spec[1]) or method(h,spec[1])
   if type(n)=='number' and n>=0 and n%1==0 then
    any=true; if n>1024 then gtCapped=true end
    for i=1,math.min(n,1024) do add(spec[2]=='GetUIChild' and ui(h,spec[2],i) or method(h,spec[2],i)) end
   end
  end
  if not any then gtUnknown=true end
  return out
 end
 local function inventory(h,depth,d)
  if not isUI(h) or gtSeen[h] then return end
  if depth>30 or gtPer[d]>=20000 then gtCapped=true; return end
  gtSeen[h]=true; gtPer[d]=gtPer[d]+1; gtPosition=gtPosition+1
  if class(h):find('PoolLayoutGrid',1,true) then
   local v,a,b,c=visible(h)
   truth[h]={handle=h,display=d,position=gtPosition,nodes=gtPer[d],visible=v,a=a,b=b,c=c}
   if v==nil then gtUnknown=true end
   return -- no Pool tile enumeration or target investigation
  end
  for _,c in ipairs(edges(h)) do inventory(c,depth+1,d) end
 end
 for i=1,7 do gtPer[i]=0; inventory(roots[i],0,i) end
 local union={}; for h in pairs(shadow) do union[h]=true end; for h in pairs(truth) do union[h]=true end
 local visibleCount,missBudget,missLogic=0,0,0; local records={}
 for h in pairs(union) do
  local r,g=shadow[h],truth[h]; local vis=g and g.visible
  local reason='NONE'
  if vis==true then
   visibleCount=visibleCount+1
   if not replay[h] then
    if r and r.accepted and r.position>6000 then missBudget=missBudget+1; reason='SHARED_6000_BUDGET'
    else missLogic=missLogic+1; reason=r and 'GRID_FILTER' or 'NOT_REACHED_BY_PRODUCTION_ALGORITHM' end
   end
  end
  local pool=field(h,'PoolObject')
  local record={display=g and g.display or r.display,position=r and r.position or 999999,h=h,r=r,g=g,reason=reason}
  records[#records+1]=record
  record.pool=pool
 end
 table.sort(records,function(a,b) if a.display~=b.display then return a.display<b.display end; return a.position<b.position end)
 local outputCapped=#records>200
 for i=1,math.min(#records,200) do
  local x=records[i]; local r,g=x.r,x.g
  log('GRID display=%d handle=%s class=%s address=%s native=%s pool_type=%s pool_class=%s pool_name=%s replay_position=%s replay_nodes=%s continuation_position=%s replay_found=%s shadow_found=%s ground_truth_found=%s ground_truth_position=%s ground_truth_nodes=%s visible=%s actual=%s IsVisible=%s Visible=%s missed_reason=%s',x.display,text(safe(HandleToStr,x.h)),text(class(x.h)),text(method(x.h,'ToAddr')),text(method(x.h,'AddrNative')),text(field(x.h,'Pooltype')),text(class(x.pool)),text(field(x.pool,'Name')),text(replay[x.h] and r.position),text(replay[x.h] and r.position),text(r and r.position),text(replay[x.h]~=nil),text(r~=nil),text(g~=nil),text(g and g.position),text(g and g.nodes),text(g and g.visible),text(g and g.a),text(g and g.b),text(g and g.c),x.reason)
 end
 for i=1,7 do log('DISPLAY display=%d root_available=%s production_nodes=%d continuation_nodes=%d ground_truth_nodes=%d starved=%s',i,text(roots[i]~=nil),per[i],shadowPer[i],gtPer[i],text(per[i]==0 and shadowPer[i]>0 and exhaustion~=nil)) end
 local classification='UNVERIFIED'
 if not unsafe and not gtCapped and not gtUnknown and not shadowCapped and not outputCapped and visibleCount>0 then
  if missBudget>0 then classification='DISCOVERY_BUDGET_MISS_CONFIRMED'
  elseif missLogic>0 then classification='DISCOVERY_LOGIC_MISMATCH'
  else classification='DISCOVERY_BUDGET_OK' end
 end
 log('END classification=%s global_production_nodes=%d continuation_nodes=%d exhausted=%s exhausted_display=%s exhausted_address=%s visible_ground_truth=%d budget_misses=%d logic_misses=%d ground_truth_capped=%s ground_truth_unknown=%s continuation_capped=%s unsafe_guard=%s output_capped=%s actual_cache_would_discover=%s',classification,total,position,text(exhaustion~=nil),text(exhaustion and exhaustion.display),text(exhaustion and exhaustion.address),visibleCount,missBudget,missLogic,text(gtCapped),text(gtUnknown),text(shadowCapped),text(unsafe),text(outputCapped),text(cacheDiscover))
 return {classification=classification,total=total,budget_misses=missBudget,logic_misses=missLogic,per_display=per,truth=truth,replay=replay,cache_discover=cacheDiscover}
end
