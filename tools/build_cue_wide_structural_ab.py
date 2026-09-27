"""Copy the dormant scanner verbatim; create a separate sparse-key variant."""
from pathlib import Path
import ast, hashlib, re
root=Path(__file__).resolve().parents[1]
source=(root/'RecipeTracking_Inspector.lua').read_text(encoding='utf-8')
assert 'local ENABLE_CUE_PHASER_MARKERS = false' in source
tree=ast.parse((root/'tools/build_cue_wide_trace.py').read_text(encoding='utf-8'))
sections=next(ast.literal_eval(n.value) for n in tree.body if isinstance(n,ast.Assign)
              and any(isinstance(t,ast.Name) and t.id=='sections' for t in n.targets))
body='\n\n'.join(source[source.index(a):source.index(b)].rstrip() for a,b in sections)
origin_anchor='layers[layer[1]] = moving and {refs = refs, fixture = fixture} or nil'
assert body.count(origin_anchor)==1
body=body.replace(origin_anchor,origin_anchor+'\n                    captureOrigin(part, layers[layer[1]])')
feature_anchor='for uiIndex in pairs(data) do'
assert body.count(feature_anchor)==1
body=body.replace(feature_anchor,feature_anchor+'\n        captureFeatureRecord()')
start=source.index('local function scanCueEffectPart(scan, part)')
end=source.index('local function finishCueEffectScan(scan)',start)
sparse=source[start:end].replace('local function scanCueEffectPart(', 'local function sparseScanCueEffectPart(',1)
assert sparse.count('next(data, pending.key)')==1
sparse=sparse.replace('next(data, pending.key)','sparseNext(scan, part, data)')
sparse=sparse.replace('local recipes = pending.recipes or {}','pending.recipes = pending.recipes or sparseRecipes(part)\n    local recipes = pending.recipes or {}')
sparse=sparse.replace('pending.recipes = recipes','pending.recipes = recipes\n    rememberSparseRecipes(part, recipes)')
sparse=sparse.replace(origin_anchor,'local probePrevious = layers[layer[1]]\n                    '+origin_anchor+'\n                    captureOrigin(part, layers[layer[1]], scan, index, layer[1], phaser, probePrevious)')
start=source.index('local function advanceCueEffectScan(scan)')
end=source.index('-- A Phaser Recipe or Generator stored directly',start)
sparse+=source[start:end].replace('local function advanceCueEffectScan(', 'local function sparseAdvanceCueEffectScan(',1).replace('scanCueEffectPart(scan, part)','sparseScanCueEffectPart(scan, part)')
version=re.search(r'local PLUGIN_VERSION = "([^"]+)"',source).group(1)
cadence=re.search(r'local REFRESH_SECONDS = ([0-9.]+)',source).group(1)
header=f'''-- Independent read-only structural/sparse vs exact dormant scanner oracle.
-- Production {version}; normalized-source SHA256 {hashlib.sha256(source.encode()).hexdigest()}.
return function()
local commandAddress, children, recipeNumber, generatorHasFeature
local GetPresetData, SelectedSequence, GetCurrentCue, sparseNext, sparseRecipes, rememberSparseRecipes, captureOrigin, captureFeatureRecord
local MAX_CUES, MAX_RECIPES, REFRESH_SECONDS = 512, 2048, {cadence}
local ENABLE_CUE_PHASER_MARKERS = true -- private copy only; production stays false
'''
out=header+body+'\n'+sparse+'\n'+(root/'tools/templates/cue_wide_structural_ab_core.lua').read_text(encoding='utf-8')
(root/'diagnostics/Cue_Wide_Structural_Resolver_AB_2_5_0_3.lua').write_text(out,encoding='utf-8')
print('Built standalone structural A/B; baseline copied verbatim, sparse differs only at key iterator')
