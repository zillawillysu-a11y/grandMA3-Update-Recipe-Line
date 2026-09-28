-- Rev13.1 observation only. Never feeds the Rev13 classifier or resolver.
function __rev131SignatureDelta(control,candidate)
 local fields={'preset_store_mode','pm','selective','dict_flags','dict_index','mask_active_phaser',
  'mask_individual','mask_active_value','mask_cooked','mask_integrated','effective_step_count',
  'layer','gridpos','gridposmatr','unknown_active_fields'}
 local known={attribute=true,abs_preset=true,rel_preset=true,abs_generator=true,rel_generator=true,generator=true,
  mask_active_phaser=true,mask_active_value=true,mask_cooked=true,mask_individual=true,mask_integrated=true,
  dict_flags=true,dict_index=true,gridposmatr=true,gridpos=true,grid=true,phase=true,speed=true,measure=true,
  fade=true,delay=true,selective=true,preset_store_mode=true,pm=true,ui_channel_index=true,
  grid_origin=true,grid_matrix=true,nshot_count=true,nshot_flags=true,speed_master=true}
 local function sorted(t) local a={}; for v in pairs(t) do a[#a+1]=v end; table.sort(a); return table.concat(a,',') end
 local function atom(v)
  if type(v)=='string' then return v:gsub('[\r\n,|]','_'):sub(1,48) end
  if type(v)=='number' or type(v)=='boolean' then return tostring(v) end
  return type(v)
 end
 local function describe(v,depth,neutral)
  local kind=type(v)
  if kind~='table' then return kind..':'..atom(v),0 end
  if depth>=4 then return 'table:DEPTH_LIMIT',0 end
  local parts,n={},0
  for k,child in pairs(v) do
   n=n+1
   if n>256 then return 'table:SIZE_LIMIT',n end
   local key=neutral and type(k)=='number' and '#' or type(k)..':'..atom(k)
   parts[#parts+1]=key..'='..describe(child,depth+1,neutral)
  end
  table.sort(parts)
  return 'table{'..table.concat(parts,';')..'}',n
 end
 local function typeShape(v,depth)
  if type(v)~='table' then return type(v) end
  if depth>=4 then return 'table:DEPTH_LIMIT' end
  local parts,n={},0
  for k,child in pairs(v) do
   n=n+1; if n>256 then return 'table:SIZE_LIMIT' end
   parts[#parts+1]=(type(k)=='number' and '#' or type(k)..':'..atom(k))..'='..typeShape(child,depth+1)
  end
  table.sort(parts); return 'table{'..table.concat(parts,';')..'}'
 end
 local function value(p,field)
  if field=='effective_step_count' then
   local n=0; for k in pairs(p) do if type(k)=='number' then n=n+1 end end; return n
  elseif field=='layer' then
   local step=p[1]; return (type(step)=='table' and step.absolute~=nil and 'ABS' or '')..(type(step)=='table' and step.relative~=nil and '+REL' or '')
  elseif field=='unknown_active_fields' then
   local unknown={}
   for k,v in pairs(p) do if type(k)=='string' and not known[k] and v~=nil and v~=false and v~=0 then unknown[k]=type(v) end end
   return unknown
  end
  return p[field]
 end
 local function collect(raw,field)
  local out={types={},keys={},shapes={},values={},counts={},channels=0,fieldCount=0,limited=false}
  if type(raw)~='table' then out.types['UNAVAILABLE']=true; return out end
  for k,p in pairs(raw) do if type(k)=='number' then
   out.channels=out.channels+1
   if out.channels>262144 then out.limited=true; break end
   if type(p)~='table' then out.types['INVALID_CHANNEL']=true
   else
    local v=value(p,field); local kind=type(v)
    out.types[kind]=true
    local exact,n=describe(v,0,false)
    local neutral=describe(v,0,true)
    out.keys[kind=='table' and exact:gsub('=[^;{}]*','') or kind]=true
    out.shapes[typeShape(v,0)]=true
    out.values[neutral]=true
    out.counts[tostring(n)]=true
    if kind~='nil' then out.fieldCount=out.fieldCount+1 end
    if exact:find('LIMIT',1,true) or neutral:find('LIMIT',1,true) then out.limited=true end
   end
  end end
  return out
 end
 local result={components={},different={},keyOnly={},semanticValue={},valueDifferences={},structural={}}
 local cc=collect(control,'layer'); local ca=collect(candidate,'layer')
 result.controlChannels=cc.channels; result.candidateChannels=ca.channels
 for _,field in ipairs(fields) do
  local a,b=collect(control,field),collect(candidate,field)
  local typesEqual=sorted(a.types)==sorted(b.types)
  local shapeEqual=sorted(a.shapes)==sorted(b.shapes)
  local keysEqual=sorted(a.keys)==sorted(b.keys)
  local valuesEqual=sorted(a.values)==sorted(b.values)
  local countEqual=sorted(a.counts)==sorted(b.counts)
  local status
  if a.limited or b.limited then status='UNPROVEN_LIMIT'
  elseif not typesEqual or not shapeEqual then status='STRUCTURAL'
  elseif not valuesEqual then
   status=({gridpos=true,gridposmatr=true,dict_index=true,unknown_active_fields=true})[field]
    and 'VALUE_DIFFERENCE_UNPROVEN_SEMANTICS' or 'SEMANTIC_VALUE'
  elseif not keysEqual then status='KEY_IDENTITY_ONLY'
  elseif a.channels~=b.channels or a.fieldCount~=b.fieldCount or not countEqual then status='CARDINALITY_ONLY'
  else status='SAME' end
  local detail={component=field,controlType=sorted(a.types),candidateType=sorted(b.types),
   controlCount=a.fieldCount,candidateCount=b.fieldCount,keySetsEqual=keysEqual,
   valueTypeShapeEqual=shapeEqual,status=status}
  result.components[#result.components+1]=detail
  if status~='SAME' then
   result.different[#result.different+1]=field
   if status=='KEY_IDENTITY_ONLY' then result.keyOnly[#result.keyOnly+1]=field
   elseif status=='SEMANTIC_VALUE' then result.semanticValue[#result.semanticValue+1]=field
   elseif status=='VALUE_DIFFERENCE_UNPROVEN_SEMANTICS' then result.valueDifferences[#result.valueDifferences+1]=field
   elseif status=='STRUCTURAL' then result.structural[#result.structural+1]=field end
  end
 end
 return result
end
