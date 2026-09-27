"""Build only the independent diagnostic from current dormant production scanner."""
from pathlib import Path
import hashlib, re
root=Path(__file__).resolve().parents[1]
source=(root/'RecipeTracking_Inspector.lua').read_text(encoding='utf-8')
assert 'local ENABLE_CUE_PHASER_MARKERS = false' in source
sections=[
 ('local function callable(name)','local function presetText(object,'),
 ('local function cueNumber(cue)','local function cueRecipeCommandAddress('),
 ('local function partNumber(part)','local function findCuePart('),
 ('local function enabledFlag(object, key)','local function readSelection()'),
 ('local function normalizeFeature(name)','local function getProgPhaser('),
 ('local function isObjectReference(value)','local function readProgrammer('),
 ('commandAddress = function(object)','local function programmerValueText('),
 ('local function presetDataHasFeature(values','phaserReferences = function('),
 ('local function valuesMatchFeature(values','-- This intentionally mirrors the reference plugin'),
 ('local function trackedRecipeEffects(sequence','-- Resolve only the Recipe references'),
 ('local function cueEffectLayer(phaser','local function refreshPoolMarkers(state)'),
]
body='\n\n'.join(source[source.index(a):source.index(b)].rstrip() for a,b in sections)
# Trace hooks do not change production conditions, order, batch size or read flags.
body=body.replace('for _, part in ipairs(parts) do scan.parts[#scan.parts + 1] = part end','for _, part in ipairs(parts) do scan.parts[#scan.parts + 1] = part; tracePartOrder(scan, cue, part) end')
body=body.replace('local function effectScanLog(message)\n    if callable("Printf") then safe(Printf, "[RecipeTracking][EffectScan] " .. message) end\nend','local function effectScanLog(message)\n    traceProductionLog(message)\nend')
body=body.replace('local function scanCueEffectPart(scan, part)\n','local function scanCueEffectPart(scan, part)\n    tracePartBegin(scan, part)\n')
body=body.replace('pending.key = index','pending.key = index\n        traceRecord(scan, part, index, phaser)')
body=body.replace('index = recipeNumber(recipe, ordinal)\n','index = recipeNumber(recipe, ordinal), probeRecipe = recipe\n')
body=body.replace('local touched, moving, refs = cueEffectLayer(phaser, layer[1], layer[2])','local touched, moving, refs = cueEffectLayer(phaser, layer[1], layer[2])\n                traceRawLayer(scan, part, index, layer[1], touched, moving, refs)')
body=body.replace('layers[layer[1]] = moving and {refs = refs, fixture = fixture} or nil','layers[layer[1]] = moving and {refs = refs, fixture = fixture} or nil\n                    traceLayer(scan, part, index, layer[1], moving, refs, recoveredPoolRef, layers[layer[1]])')
body=body.replace('if recipe.featureMatches[feature] then', 'traceRecoveryCandidate(scan, part, index, feature, recipe, sfIndex)\n                            if recipe.featureMatches[feature] then')
body=body.replace('local laneKey = groupKey .. "|" .. feature','local laneKey = groupKey .. "|" .. feature\n                traceMediumLane(row, reference, feature, laneKey, decided[laneKey], activeReference)')
body=body.replace('if publish then\n                local key = commandAddress(reference)','traceMediumRow(row, reference, features, publish, groupKey)\n            if publish then\n                local key = commandAddress(reference)')
body=body.replace('if key then result[key] = {object = ref, fixtures = {}, count = 0} end','traceDirect(part, recipe, ref, key)\n                        if key then result[key] = {object = ref, fixtures = {}, count = 0} end')
for hook in ('tracePartOrder(', 'traceProductionLog(', 'tracePartBegin(', 'traceRecord(',
             'traceRawLayer(', 'traceLayer(', 'traceRecoveryCandidate(',
             'traceMediumLane(', 'traceMediumRow(', 'traceDirect('):
    assert body.count(hook) == 1, 'Production instrumentation anchor drift: '+hook
version=re.search(r'local PLUGIN_VERSION = "([^"]+)"',source).group(1)
cadence=re.search(r'local REFRESH_SECONDS = ([0-9.]+)',source).group(1)
header=f'''-- Generated independent read-only replay; production file is never executed.
-- Source version {version}, normalized-source SHA256 {hashlib.sha256(source.encode()).hexdigest()}.
return function()
local commandAddress, children, recipeNumber, generatorHasFeature
local GetPresetData, SelectedSequence, GetCurrentCue
local tracePartOrder, tracePartBegin, traceRecord, traceRawLayer, traceLayer
local traceMediumLane, traceMediumRow, traceDirect, traceProductionLog, traceRecoveryCandidate
-- Private diagnostic gate only. The production flag remains FALSE.
local ENABLE_CUE_PHASER_MARKERS = true
local MAX_CUES, MAX_RECIPES, REFRESH_SECONDS = 512, 2048, {cadence}
'''
result=header+body+'\n\n'+(root/'tools/templates/cue_wide_trace_core.lua').read_text(encoding='utf-8')
(root/'diagnostics/Cue_Wide_Trace_Timing_2_5_0_3.lua').write_text(result,encoding='utf-8')
print('Built independent Cue-wide trace; production untouched')
