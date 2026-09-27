-- Rev3 is observational: none of this evidence is fed into reverse tracking.
local function newReferenceSemanticsAudit(api)
 local function repr(v)
  if api.isObject(v) then return api.class(v)..':'..api.desc(v) end
  return type(v)..':'..tostring(v)
 end
 local function inspect(h)
  local m=api.metadata(h); local keys={}; for k in pairs(m) do keys[#keys+1]=k end; table.sort(keys)
  local values,links={},{}
  for _,k in ipairs(keys) do
   local p=m[k]; local v=p.raw
   -- Enumerated property identity is retained separately from a getter result.
   values[#values+1]=p.key..'{'..tostring(p.type)..'}='..repr(v)
   if api.isObject(v) then links[#links+1]=p.key..'->'..repr(v) end
  end
  local probes={}
  for _,k in ipairs({'Layer','ValueLayer','Mode','Relative','RawValueAbs','RawValueRel','ValueAbsolute','ValueRelative','Feature','FeatureGroup','PresetPoolType','OwnDataPresent'}) do
   local direct=api.safe(function() return h[k] end)
   local get=api.safe(function() return h:Get(k) end)
   probes[#probes+1]=k..':enumerated='..tostring(m[k:lower()]~=nil)..',direct='..repr(direct)..',get='..repr(get)
  end
  return table.concat(values,';'),table.concat(links,';'),table.concat(probes,';')
 end
 return function(ref,data,recipe)
  local pool=api.safe(function() return ref:Parent() end)
  local props,links,probes=inspect(ref)
  local poolProps,poolLinks,poolProbes=inspect(pool)
  local rowProps,rowLinks,rowProbes=inspect(recipe)
  local seen,classes,attributes,steps,shapes,dependencies={}, {},{},{},{},{}
  local nodes,truncated=0,false
  local function walk(h,depth)
   if not api.isObject(h) or seen[h] then return end
   if depth>8 or nodes>=512 then truncated=true; return end
   seen[h]=true; nodes=nodes+1
   local c=api.class(h); classes[c]=(classes[c] or 0)+1
   local p,l,q=inspect(h)
   if c:lower()=='phaserrecipestep' then steps[#steps+1]=api.desc(h)..' props='..p..' probes='..q end
   local m=api.metadata(h)
   for _,v in pairs(m) do
    local a=v.raw
    if api.isObject(a) and api.class(a):lower()=='attribute' then
     local f=api.safe(function() return a.Feature end); local fg=api.safe(function() return f:Parent() end)
     attributes[#attributes+1]=v.key..'->'..repr(a)..' Feature='..repr(f)..' FeatureGroup='..repr(fg)
    end
    if api.isObject(a) and (api.class(a):lower()=='shape' or v.key:lower()=='shape') then shapes[#shapes+1]=v.key..'->'..repr(a) end
   end
   if c:lower()=='phaserrecipevaluesource' then steps[#steps+1]='ValueSource='..api.desc(h)..' parent='..repr(api.safe(function() return h:Parent() end))..' props='..p..' probes='..q end
   for _,child in ipairs(api.safe(function() return h:Children() end) or {}) do walk(child,depth+1) end
  end
  walk(ref,0)
  local deps=api.safe(function() return ref:GetDependencies() end)
  if type(deps)=='table' then for _,d in pairs(deps) do dependencies[#dependencies+1]=repr(d) end; table.sort(dependencies)
  else dependencies[1]='UNAVAILABLE:'..type(deps) end
  local motion=data.proven and (data.moving and 'MOTION_PROVEN' or 'STATIC_PROVEN') or 'MOTION_UNPROVEN'
  local classPattern={}; for c,n in pairs(classes) do classPattern[#classPattern+1]=c..':'..n end; table.sort(classPattern)
  -- Pattern includes exact evidence, so dissimilar values cannot be hidden by deduplication.
  local key=table.concat({api.class(ref),api.class(pool),props,poolProps,table.concat(classPattern,','),motion},'|')
  return {key=key,pool=pool,props=props,links=links,probes=probes,poolProps=poolProps,poolLinks=poolLinks,poolProbes=poolProbes,
   rowProps=rowProps,rowLinks=rowLinks,rowProbes=rowProbes,classes=table.concat(classPattern,','),attributes=table.concat(attributes,';'),
   steps=steps,shapes=table.concat(shapes,';'),dependencies=table.concat(dependencies,';'),truncated=truncated,
   feature=data.featureProven==true,layer=data.layerProven==true,motion=motion,
   reason=api.joined(data.reasons),stepCount=data.stepCount or 0}
 end
end
