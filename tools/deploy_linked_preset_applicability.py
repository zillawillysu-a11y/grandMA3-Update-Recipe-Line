"""Deploy only the independent observer and verify production is unchanged."""
from pathlib import Path
import hashlib
import shutil
import subprocess
import xml.etree.ElementTree as ET
from lupa.lua54 import LuaRuntime

root = Path(__file__).resolve().parents[1]
base = Path(r"C:\ProgramData\MALightingTechnology\gma3_library\datapools\plugins")
target = base / "Linked Preset Applicability Control 2.5.0.3"
production = base / "Update Plugin"
names = ("linked_preset_applicability_2_5_0_3.xml", "Linked_Preset_Applicability_Control_2_5_0_3.lua")
assert target.resolve().parent == base.resolve() and target != production

def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()

def snapshot(directory):
    return {str(p.relative_to(directory)): sha(p) for p in directory.rglob("*") if p.is_file()}

for name in ("RecipeTracking_Inspector.lua", "RecipeUpdate_Diagnostic.lua", "recipe_update_diagnostic.xml"):
    assert subprocess.check_output(["git", "hash-object", name], cwd=root).strip() == subprocess.check_output(["git", "rev-parse", "HEAD:" + name], cwd=root).strip()
before = snapshot(production)
assert before
plugin = ET.parse(root / "diagnostics" / names[0]).getroot().find("UserPlugin")
assert plugin is not None and plugin.find("ComponentLua").attrib["FileName"] == names[1]
LuaRuntime().eval("function(s) local f,e=load(s); assert(f,e) end")((root / "diagnostics" / names[1]).read_text(encoding="utf-8"))
target.mkdir(parents=True, exist_ok=True)
for name in names:
    shutil.copyfile(root / "diagnostics" / name, target / name)
    assert sha(root / "diagnostics" / name) == sha(target / name)
    print(name + " SHA256=" + sha(target / name) + " MATCH")
assert before == snapshot(production)
print("PASS independent observer deployed; production unchanged")
