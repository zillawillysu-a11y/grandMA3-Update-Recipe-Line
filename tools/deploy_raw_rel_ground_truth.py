"""Deploy only the read-only Rev8 observer; verify production unchanged."""
from pathlib import Path
import hashlib
import shutil
import subprocess
import xml.etree.ElementTree as ET
from lupa.lua54 import LuaRuntime

root = Path(__file__).resolve().parents[1]
base = Path(r"C:\ProgramData\MALightingTechnology\gma3_library\datapools\plugins")
target = base / "Raw REL Ground Truth Control 2.5.0.3"
production = base / "Update Plugin"
assert target.resolve().parent == base.resolve() and target != production
names = ("raw_rel_ground_truth_control_2_5_0_3.xml", "Raw_Rel_Ground_Truth_Control_2_5_0_3.lua")


def sha(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def snapshot(directory: Path) -> dict[str, str]:
    return {str(path.relative_to(directory)): sha(path) for path in directory.rglob("*") if path.is_file()}


def validate(directory: Path) -> None:
    plugin = ET.parse(directory / names[0]).getroot().find("UserPlugin")
    assert plugin is not None and plugin.attrib["Name"] == "Raw REL Ground Truth Control 2.5.0.3"
    components = plugin.findall("ComponentLua")
    assert len(components) == 1 and components[0].attrib["FileName"] == names[1]
    LuaRuntime().eval("function(s) local f,e=load(s); assert(f,e) end")((directory / names[1]).read_text(encoding="utf-8-sig"))


production_names = ("RecipeTracking_Inspector.lua", "RecipeUpdate_Diagnostic.lua", "recipe_update_diagnostic.xml")
source_before = {name: sha(root / name) for name in production_names}
for name in production_names:
    actual = subprocess.check_output(["git", "hash-object", name], cwd=root).strip()
    expected = subprocess.check_output(["git", "rev-parse", "HEAD:" + name], cwd=root).strip()
    assert actual == expected, "Production source changed: " + name
assert "local ENABLE_CUE_PHASER_MARKERS = false" in (root / production_names[0]).read_text(encoding="utf-8")
before = snapshot(production)
assert before, "Production snapshot required"
validate(root / "diagnostics")
target.mkdir(parents=True, exist_ok=True)
for name in names:
    shutil.copyfile(root / "diagnostics" / name, target / name)
validate(target)
for name in names:
    assert sha(root / "diagnostics" / name) == sha(target / name)
    print(name + " SHA256=" + sha(target / name) + " MATCH")
assert source_before == {name: sha(root / name) for name in production_names}
assert before == snapshot(production), "Production deployment changed"
print("PASS Rev8 source/deployed XML and Lua 5.4; production source/folder unchanged")
print("DEPLOYED " + str(target))
