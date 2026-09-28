"""Independent Recipe reverse diagnostic with an unchanged, last-running oracle."""
from pathlib import Path
import ast
import hashlib

root = Path(__file__).resolve().parents[1]
source = (root / 'RecipeTracking_Inspector.lua').read_text(encoding='utf-8')
assert 'local ENABLE_CUE_PHASER_MARKERS = false' in source
tree = ast.parse((root / 'tools/build_cue_wide_trace.py').read_text(encoding='utf-8'))
sections = next(ast.literal_eval(n.value) for n in tree.body if isinstance(n, ast.Assign)
                and any(isinstance(t, ast.Name) and t.id == 'sections' for t in n.targets))
body = '\n\n'.join(source[source.index(a):source.index(b)].rstrip() for a, b in sections)
header = f'''-- Independent diagnostic; production SHA256 {hashlib.sha256(source.encode()).hexdigest()}.
return function()
-- Native Printf has stricter vararg types than Lua string.format.
local nativePrintf = _G.Printf
local oracleLogSink
local function Printf(fmt, ...)
    local line = select('#', ...) == 0 and tostring(fmt) or string.format(fmt, ...)
    if oracleLogSink then oracleLogSink(line) else nativePrintf("%s", line) end
end
local commandAddress, children, recipeNumber, generatorHasFeature
local GetPresetData, SelectedSequence, GetCurrentCue
local MAX_CUES, MAX_RECIPES, REFRESH_SECONDS = 512, 2048, 0.1
local ENABLE_CUE_PHASER_MARKERS = true -- private oracle only
'''
engine = (root / 'tools/templates/cue_wide_recipe_reverse_engine.lua').read_text(encoding='utf-8')
adapter = (root / 'tools/templates/cue_wide_recipe_reverse_ab_core.lua').read_text(encoding='utf-8')
auditor = (root / 'tools/templates/cue_wide_recipe_value_source.lua').read_text(encoding='utf-8')
(root / 'diagnostics/Cue_Wide_Recipe_Reverse_Resolver_AB_2_5_0_3.lua').write_text(
    header + body + '\n' + engine + '\n' + auditor + '\n' + (root / 'tools/templates/cue_wide_recipe_reference_semantics.lua').read_text(encoding='utf-8') + '\n' + (root / 'tools/templates/cue_wide_recipe_reference_metadata.lua').read_text(encoding='utf-8') + '\n' + (root / 'tools/templates/cue_wide_recipe_metadata_bridge.lua').read_text(encoding='utf-8') + '\n' + (root / 'tools/templates/cue_wide_recipe_field_semantics.lua').read_text(encoding='utf-8') + '\n' + adapter, encoding='utf-8')
print('Built Recipe Reverse A/B Rev6 REFERENCE_FIELD_SEMANTICS_PROOF; oracle sections copied unchanged')
