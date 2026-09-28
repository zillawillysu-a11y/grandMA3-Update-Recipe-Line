local file=assert(io.open('tools/templates/cue_wide_recipe_semantic_normalization.lua','rb'))
local source=file:read('*a'); file:close(); assert(load(source))()
local function channel(index,mask,layer)
 local step=layer=='REL' and {relative=10} or {absolute=50}
 return {preset_store_mode=2,selective=false,dict_flags={has_absolute=true},
  mask_active_phaser=mask or 64,mask_individual=64,mask_active_value=2,
  mask_cooked=0,dict_index=index,gridpos={[index]=3},[1]=step}
end
local control={[1]=channel(1),[2]=channel(2)}
local candidate={[11]=channel(11),[12]=channel(12),[13]=channel(13)}
local function identity(h) return h and h.db and 'DBI:'..h.db or nil end
local r=__rev132SemanticNormalize(candidate,control,identity)
assert(r.semanticCoreMatch and r.channelCount==3 and r.controlChannelCount==2)
assert(r.uiChannelKeyRelation=='DIFFERENT_NUMERIC_KEYS')
assert(r.dictAudit.classification=='IDENTITY_LIKE_ONLY' and r.dictAudit.relationUI=='EXACT_UI_KEY')
local shifted={[11]=channel(11),[12]=channel(12)}
r=__rev132SemanticNormalize(shifted,control,identity)
assert(r.semanticCoreMatch and r.dictAudit.classification=='IDENTITY_LIKE_ONLY')
shifted[11].mask_active_phaser=16
r=__rev132SemanticNormalize(shifted,control,identity)
assert(not r.semanticCoreMatch and r.blockers.SEMANTIC_CORE_DIFFERENCE)
shifted[11].mask_active_phaser=64; shifted[11][1]={relative=10}
r=__rev132SemanticNormalize(shifted,control,identity)
assert(not r.semanticCoreMatch)
shifted[11][1]={absolute=50}; shifted[11].dict_index=99; shifted[12].dict_index=99
r=__rev132SemanticNormalize(shifted,control,identity)
assert(r.semanticCoreMatch and r.dictAudit.classification=='UNPROVEN' and r.blockers.DICT_INDEX_MEANING_UNPROVEN)
print('PASS Rev13.2 semantic core cardinality, keys, mask, layer and dict index audit')
