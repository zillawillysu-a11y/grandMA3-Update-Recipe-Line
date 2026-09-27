-- Pure membership resolver. Input rows MUST be newest first, including static rows.
-- An unsafe newer row blocks older assertions rather than letting history shine through.
local function recipeReverseResolve(rows)
 local result={refs={},assignments={},unsafe={},rejected={},rowsSkipped=0,staticRows=0,movingRows=0,lanesResolved=0}
 local decided,blocked,globalBlock={},{},{}
 local work=0
 local function checkpoint() work=work+1; assert(work<=1048576,'Recipe reverse lane work limit exceeded') end
 for reverseIndex,row in ipairs(rows) do
  row.reverseIndex=reverseIndex
  row.survivors={}; row.movingSurvivors={}; row.movingEffective=false; row.staticEffective=false; row.superseded={}; row.effective=0
  local reasons=row.unsafe or {}
  if #reasons>0 then
   result.unsafe[#result.unsafe+1]=row
   if not row.members then globalBlock[#globalBlock+1]=row
   else for member in pairs(row.members) do
    checkpoint()
    blocked[member]=blocked[member] or {}
    if not row.features then blocked[member]['*']=blocked[member]['*'] or row
    else for feature in pairs(row.features) do
     if not row.layers then blocked[member][feature..'|*']=blocked[member][feature..'|*'] or row
     else for layer in pairs(row.layers) do blocked[member][feature..'|'..layer]=blocked[member][feature..'|'..layer] or row end end
    end end
   end end
  else
   local rowLanes=row.lanes or {}
   if not row.lanes then for feature in pairs(row.features) do for layer in pairs(row.layers) do rowLanes[feature..'|'..layer]={feature=feature,layer=layer,moving=row.moving} end end end
   for member in pairs(row.members) do
    decided[member]=decided[member] or {}
    for lane,laneState in pairs(rowLanes) do
     local feature,layer=laneState.feature,laneState.layer
     checkpoint()
     local old=decided[member][lane]
     local barrier=globalBlock[1]
     for _,key in ipairs({lane,feature..'|*','*'}) do
      local candidate=(blocked[member] or {})[key]
      if candidate and (not barrier or candidate.reverseIndex<barrier.reverseIndex) then barrier=candidate end
     end
     if old then row.superseded[#row.superseded+1]={member=member,lane=lane,newer=old}
     elseif barrier then
      row.superseded[#row.superseded+1]={member=member,lane=lane,newer=barrier,unsafe=true}
     else
      decided[member][lane]=row; row.effective=row.effective+1; row.survivors[member]=true
      result.lanesResolved=result.lanesResolved+1
      result.assignments[#result.assignments+1]={member=member,lane=lane,row=row}
      if laneState.moving then
       row.movingEffective=true
       row.movingSurvivors[member]=true
       local entry=result.refs[row.refId] or {ref=row.ref,members={},sources={}}
       result.refs[row.refId]=entry; entry.members[member]=true
       entry.sources[row]=true
      else row.staticEffective=true end
     end
    end
   end
   if row.effective==0 then result.rowsSkipped=result.rowsSkipped+1
   else
    if row.movingEffective then result.movingRows=result.movingRows+1 end
    if row.staticEffective then result.staticRows=result.staticRows+1 end
   end
  end
  if row.moving and #row.superseded>0 then result.rejected[#result.rejected+1]=row end
 end
 result.unresolved={}
 for member,lanes in pairs(blocked) do for lane,row in pairs(lanes) do
  if not (decided[member] or {})[lane] then result.unresolved[#result.unresolved+1]={member=member,lane=lane,row=row} end
 end end
 result.unknownSelectionRows=#globalBlock
 result.laneWork=work
 return result
end
