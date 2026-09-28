-- Rev7 observation only. No value-zero inference enters the candidate.
local function newRawRelZeroAudit(api)
 local patterns,order,states,linkedCache={},{},{REL_AUTHORED_PROVEN=0,REL_NOT_AUTHORED_PROVEN=0,REL_AMBIGUOUS=0},{}
 local function shown(v)
  if v==nil then return '<nil>' end
  if type(v)=='string' and v=='' then return '<empty>' end
  return tostring(v):gsub('[\r\n|]',' '):sub(1,80)
 end
 local function patternValue(v)
  if type(v)=='number' and v~=0 then return '<nonzero-number>' end
  return shown(v)
 end
 local function probe(h,key)
  local direct=api.safe(function() return h[key] end)
  local getter=api.safe(function() return h:Get(key) end)
  return 'direct='..type(direct)..':'..shown(direct)..',get='..type(getter)..':'..shown(getter)
 end
 local function linkedEvidence(h)
  if not api.isObject(h) or api.class(h):lower()~='preset' then return '<none>','<none>','<none>','<none>' end
  local id=api.identity(h)
  if id and linkedCache[id] then return table.unpack(linkedCache[id]) end
  local raw=id and api.raw[id]
  local info=type(raw)=='table' and api.ordinary(raw) or nil
  local masks,effective={},{}
  if type(raw)=='table' then for ui,p in pairs(raw) do if type(ui)=='number' and type(p)=='table' then
   masks[tostring(p.mask_active_value)]=true
   local step=p[1]
   if type(step)=='table' then effective['ABS:'..type(step.absolute)..'/REL:'..type(step.relative)]=true end
  end end end
  local result={info and api.joined(info.layers) or '<unknown>',api.joined(masks),api.joined(effective),info and info.completeness or 'UNKNOWN'}
  if id then linkedCache[id]=result end
  return table.unpack(result)
 end
 local function observe(node,step,linked)
  local m=api.metadata(node)
  local r=m.rawvaluerel; local v=r and r.raw
  local a=m.rawvalueabs; local av=a and a.raw
  local layer=m.layer or m.valuelayer
  local relProbe,absProbe=probe(node,'ValueRelative'),probe(node,'ValueAbsolute')
  local shape=m.shape and m.shape.raw~=nil and shown(m.shape.raw)~='<empty>'
  local attr=(m.attributes or m.attribute) and (m.attributes or m.attribute).raw
  local feature=api.isObject(attr) and api.safe(function() return attr.Feature end)
  local fg=api.isObject(feature) and api.safe(function() return feature:Parent() end)
  local linkedLayers,mask,effective,complete=linkedEvidence(linked)
  local classification,evidence='REL_AMBIGUOUS','RawValueRel zero encoding has no independent active-lane discriminator'
  if type(v)=='number' and v~=0 then
   classification='REL_AUTHORED_PROVEN'; evidence='vendor keypad maps ValueRelative to RawValueRel; nonzero raw numeric value'
  elseif type(v)=='string' and v:lower()=='none' then
   classification='REL_NOT_AUTHORED_PROVEN'; evidence='explicit None special suppresses this raw lane'
  elseif type(v)=='string' and v=='' then
   evidence='empty getter/raw display observed; native storage versus getter fallback unproven'
  end
  -- Numeric zero is deliberately never promoted by Layer labels, getter zero,
  -- a linked Preset mask, or a complete linked Preset with no REL lane.
  local signature=table.concat({type(v),patternValue(v),type(av),patternValue(av),relProbe,absProbe,shown(layer and layer.raw),linkedLayers,mask,effective,complete,tostring(shape),classification},'|')
  local p=patterns[signature]
  if not p then
   p={count=0,identity=api.identity(node),step=step,attribute=shown(attr),featureGroup=api.isObject(fg) and api.identity(fg) or '<unknown>',
    rawType=type(v),rawValue=shown(v),rawEnumerated=r~=nil,absType=type(av),absValue=shown(av),absEnumerated=a~=nil,
    relative=relProbe,absolute=absProbe,
    layer='Layer{enumerated='..tostring(m.layer~=nil)..',type='..tostring(m.layer and m.layer.type)..',info='..shown(m.layer and m.layer.info)..',raw='..shown(m.layer and m.layer.raw)..','..probe(node,'Layer')..'};ValueLayer{enumerated='..tostring(m.valuelayer~=nil)..',type='..tostring(m.valuelayer and m.valuelayer.type)..',info='..shown(m.valuelayer and m.valuelayer.info)..',raw='..shown(m.valuelayer and m.valuelayer.raw)..','..probe(node,'ValueLayer')..'}',
    linked=linked and api.identity(linked) or '<none>',linkedLayers=linkedLayers,mask=mask,effective=effective,linkedComplete=complete,
    shape=shape,classification=classification,evidence=evidence}
   patterns[signature]=p; order[#order+1]=p
  end
  p.count=p.count+1; states[classification]=states[classification]+1
  return classification
 end
 return {observe=observe,patterns=order,states=states}
end
