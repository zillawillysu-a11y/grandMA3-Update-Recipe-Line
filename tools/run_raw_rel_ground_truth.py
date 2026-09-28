"""Run existing Recipe Reverse regressions and Rev8 standalone checks."""
from pathlib import Path
import subprocess
import sys
import xml.etree.ElementTree as ET
from lupa.lua54 import LuaRuntime

root = Path(__file__).resolve().parents[1]
runtime = root / "diagnostics/Raw_Rel_Ground_Truth_Control_2_5_0_3.lua"
before = runtime.read_bytes()
subprocess.run([sys.executable, str(root / "tools/build_raw_rel_ground_truth.py")], cwd=root, check=True)
assert runtime.read_bytes() == before, "Rev8 build is nondeterministic"
subprocess.run([sys.executable, str(root / "tools/run_cue_wide_recipe_reverse_ab.py")], cwd=root, check=True)
lua = LuaRuntime()
lua.execute("assert(_VERSION == 'Lua 5.4')")
lua.eval("function(s) local f,e=load(s); assert(f,e) end")(runtime.read_text(encoding="utf-8"))
lua.execute((root / "tests/raw_rel_ground_truth.lua").read_text(encoding="utf-8"))
subprocess.run([sys.executable, str(root / "tests/test_raw_rel_ground_truth_exports.py")], cwd=root, check=True)
manifest = ET.parse(root / "diagnostics/raw_rel_ground_truth_control_2_5_0_3.xml")
component = manifest.getroot().find("UserPlugin").find("ComponentLua")
assert component.attrib["FileName"] == runtime.name
assert runtime.is_file()
print("PASS Rev8 Lua 5.4, deterministic build, XML, and independent observer")
