"""Validate independent observer, older regressions, deterministic build, and XML."""
from pathlib import Path
import subprocess
import sys
import xml.etree.ElementTree as ET
from lupa.lua54 import LuaRuntime

root = Path(__file__).resolve().parents[1]
subprocess.run([sys.executable, str(root / "tools/run_cue_wide_recipe_reverse_ab.py")], check=True)
subprocess.run([sys.executable, str(root / "tools/run_raw_rel_ground_truth.py")], check=True)
subprocess.run([sys.executable, str(root / "tools/build_linked_preset_applicability.py")], check=True)
runtime = root / "diagnostics/Linked_Preset_Applicability_Control_2_5_0_3.lua"
before = runtime.read_bytes()
subprocess.run([sys.executable, str(root / "tools/build_linked_preset_applicability.py")], check=True)
assert before == runtime.read_bytes(), "Nondeterministic observer build"
lua = LuaRuntime()
lua.execute("assert(_VERSION=='Lua 5.4')")
lua.eval("function(s) local f,e=load(s); assert(f,e) end")(before.decode())
lua.execute((root / "tests/linked_preset_applicability.lua").read_text(encoding="utf-8"))
plugin = ET.parse(root / "diagnostics/linked_preset_applicability_2_5_0_3.xml").getroot().find("UserPlugin")
assert plugin is not None and len(plugin.findall("ComponentLua")) == 1
assert plugin.find("ComponentLua").attrib["FileName"] == runtime.name
print("PASS linked-Preset observer Lua 5.4, deterministic build, XML, older regressions")
