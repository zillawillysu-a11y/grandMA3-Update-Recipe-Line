"""Read-only export summary and production-fixture probes; no native timing claim."""
from pathlib import Path
from collections import Counter
import argparse
import hashlib
import json
import os
import xml.etree.ElementTree as ET
from lupa import LuaRuntime

root = Path(__file__).resolve().parents[1]
parser = argparse.ArgumentParser()
parser.add_argument("--preset", type=Path)
parser.add_argument("--sequence", type=Path)
args = parser.parse_args()
for path in (args.preset, args.sequence):
    if path is None:
        continue
    tree = ET.parse(path).getroot()
    print(json.dumps({"file": path.name, "bytes": path.stat().st_size,
        "sha256": hashlib.sha256(path.read_bytes()).hexdigest(),
        "tags": dict(Counter(node.tag for node in tree.iter()))}, ensure_ascii=False))
    if path == args.preset:
        presets = tree.findall("Preset")
        channels = [c for p in presets for c in p.findall("./PresetData/Phaser")]
        print(json.dumps({"direct_presets": len(presets), "direct_channels": len(channels),
            "measure_counts": dict(Counter(c.get("Measure", "absent") for c in channels)),
            "step_counts": dict(Counter(len(c.findall("Step")) for c in channels)),
            "integrated_steps": sum("Integrated" in s.attrib for c in channels for s in c.findall("Step"))}))
    else:
        seq = tree.find("Sequence")
        if seq is not None:
            print(json.dumps({"sequence": seq.get("Name"), "cues": len(seq.findall("Cue")),
                "direct_recipe_rows": sum(n.tag in ("Recipe", "StandardRecipe") for c in seq.findall("Cue") for p in c.findall("Part") for n in p)}, ensure_ascii=False))

os.chdir(root)
source = (root / "tests/show_candidate.lua").read_text(encoding="utf-8")
marker = "local attributeReadsBefore=attributeByUICalls"
assert source.count(marker) == 1
probe = r'''
do
 (function()
  local h=hookState.provenHooks
  local savedSubfixture,savedObjectList=GetSubfixture,ObjectList
  local getCount,listCount=0,0
  GetSubfixture=function(...) getCount=getCount+1; return savedSubfixture(...) end
  ObjectList=function(...) listCount=listCount+1; return savedObjectList(...) end
  h.completeGroups(fOne)
  getCount,listCount=0,0
  h.completeGroups(fOne)
  print("RESEARCH warm completeGroups native stubs: GetSubfixture="..getCount.." ObjectList="..listCount)
  assert(getCount>0 and listCount>0, "warm Group identity cache still rebuilds signatures and selected identity")
  GetSubfixture=savedSubfixture; ObjectList=savedObjectList
  local r=functions.newTrackARuntime({safe=functions.safe,class=functions.class,
   children=functions.children,identity=functions.commandAddress,getPresetData=GetPresetData,
   attributeByUI=GetAttributeByUIChannel,objectList=ObjectList})
  local channel=referenceData[moving][0]
  local savedMeasure,savedMask=channel.measure,channel.mask_active_value
  assert(r.metadata(moving,{}), "raw multi-step without timing is already supported")
  channel.measure=1
  local cache={}
  assert(r.metadata(moving,cache)==nil and cache.__failure[tostring(moving)]=="ACTIVE_CHANNEL_FIELD_measure")
  channel.measure=nil; channel.mask_active_value=channel.mask_active_value | 8
  cache={}
  assert(r.metadata(moving,cache)==nil and cache.__failure[tostring(moving)]=="ACTIVE_VALUE_MASK_SHAPE")
  channel.measure=savedMeasure; channel.mask_active_value=savedMask
  print("RESEARCH raw two-step: admitted baseline; rejected measure=1; rejected mask with extra bit")
 end)()
end
'''
print("OFFLINE ONLY: stub counts and synthetic blocker reproduction, not native latency or mask encoding proof")
LuaRuntime().execute(source.replace(marker, probe + "\n" + marker))
