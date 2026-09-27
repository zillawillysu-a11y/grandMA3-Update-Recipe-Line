from pathlib import Path
import os
from lupa import LuaRuntime
root=Path(__file__).resolve().parents[1]
os.chdir(root)
production=(root/'RecipeTracking_Inspector.lua').read_text(encoding='utf-8')
probe=(root/'diagnostics/Marker_Pipeline_Trace_2_5_0_3.lua').read_text(encoding='utf-8-sig')
anchors=[
 ('local function callable(name)','local function presetText(object,'),
 ('local function cueNumber(cue)','local function cueRecipeCommandAddress('),
 ('local function partNumber(part)','local function findCuePart('),
 ('local function enabledFlag(object, key)','local function readSelection()'),
 ('local function normalizeFeature(name)','local function getProgPhaser('),
 ('local function isObjectReference(value)','local function readProgrammer('),
 ('commandAddress = function(object)','local function programmerValueText('),
 ('local function isPhaserRecipePreset(values)','local function phaserRecipeHasFeature('),
 ('local RECIPE_FEATURES =','-- This intentionally mirrors the reference plugin'),
]
for a,b in anchors:
 assert production[production.index(a):production.index(b)].strip() in probe, 'Production helper drift: '+a
print('PASS: 9 copied production helper sections match current source')
LuaRuntime().execute((root/'tests/marker_pipeline_trace.lua').read_text(encoding='utf-8'))
