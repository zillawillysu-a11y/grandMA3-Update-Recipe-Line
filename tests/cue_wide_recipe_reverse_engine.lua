local f=assert(io.open('tools/templates/cue_wide_recipe_reverse_engine.lua')); local src=f:read('*a'); f:close()
local resolve=assert(load(src..'\nreturn recipeReverseResolve'))()
local checks=0
local function check(v) assert(v); checks=checks+1 end
local function row(ref,members,moving,feature,layer)
 local m={}; for _,v in ipairs(members) do m[v]=true end
 return {ref=ref,refId=ref,members=m,moving=moving,features={[feature or 'Dimmer']=true},layers={[layer or 'abs']=true},unsafe={}}
end
-- Overlap: the newer static Group B terminates only its covered members.
local newer,older=row('static',{2},false),row('moving',{1,2,3},true)
local r=resolve({newer,older})
check(r.refs.moving.members[1] and r.refs.moving.members[3] and not r.refs.moving.members[2])
check(r.staticRows==1 and r.movingRows==1 and r.lanesResolved==3)
check(older.superseded[1].newer==newer and older.superseded[1].member==2)
-- Re-source preserves occurrence ownership, then deduplicates final identity.
newer,older=row('same',{1},true),row('same',{1,2},true)
r=resolve({newer,older}); check(r.refs.same.members[1] and r.refs.same.members[2])
check(r.refs.same.sources[newer] and r.refs.same.sources[older])
check(older.superseded[1].newer==newer)
-- Different feature/layer lanes do not terminate each other.
r=resolve({row('static',{1},false,'Position'),row('staticRel',{1},false,'Dimmer','rel'),row('move',{1},true)})
check(r.refs.move.members[1] and r.lanesResolved==3)
newer,older=row('static',{1,2},false),row('move',{1,2},true)
r=resolve({newer,older}); check(next(r.refs)==nil and r.rowsSkipped==1 and #r.rejected==1)
-- Unsafe newer scope blocks historical assertions; known newer assignments survive.
local unsafe=row('unknown',{2},true); unsafe.features=nil; unsafe.unsafe={'FAST_PATH_UNSAFE_FEATURE_SCOPE'}
r=resolve({row('new',{1},true),unsafe,row('old',{1,2,3},true)})
check(r.refs.new.members[1] and r.refs.old.members[3] and not r.refs.old.members[2])
check(#r.unsafe==1 and #r.unresolved==1)
unsafe=row('unknown',{1},true); unsafe.layers=nil; unsafe.unsafe={'FAST_PATH_UNSAFE_LAYER'}
r=resolve({unsafe,row('old',{1},true)}); check(next(r.refs)==nil)
unsafe.members=nil; unsafe.unsafe={'FAST_PATH_UNSAFE_SELECTION'}
r=resolve({unsafe,row('old',{1,2},true)}); check(next(r.refs)==nil and r.unknownSelectionRows==1)
-- Membership sets are expanded before reference identity collapse.
r=resolve({row('b',{2,4},true),row('a',{1,2,3},true)})
check(r.refs.a.members[1] and r.refs.a.members[3] and not r.refs.a.members[2] and r.refs.b.members[4])
local first=row('unsafe1',{1},true); first.features=nil; first.unsafe={'FAST_PATH_UNSAFE_FEATURE_SCOPE'}
local second=row('unsafe2',{1},true); second.layers=nil; second.unsafe={'FAST_PATH_UNSAFE_LAYER'}
older=row('older',{1},true)
r=resolve({first,second,older}); check(older.superseded[1].newer==first)
print('PASS Recipe reverse engine '..checks..' semantic checks')
