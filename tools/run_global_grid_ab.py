"""Focused Lua 5.4, deterministic build, and XML checks."""
from pathlib import Path
import subprocess
import sys
import xml.etree.ElementTree as ET
from lupa.lua54 import LuaRuntime

root = Path(__file__).resolve().parents[1]
source = root / 'tools/templates/global_grid_ab.lua'
target = root / 'diagnostics/Global_Grid_Applicability_AB_2_5_0_3.lua'
subprocess.run([sys.executable, str(root / 'tools/build_global_grid_ab.py')], check=True)
before = target.read_bytes()
subprocess.run([sys.executable, str(root / 'tools/build_global_grid_ab.py')], check=True)
assert target.read_bytes() == before == source.read_bytes(), 'Nondeterministic build'
lua = LuaRuntime()
lua.execute("assert(_VERSION=='Lua 5.4')")
lua.eval('function(s) local f,e=load(s); assert(f,e) end')(before.decode('utf-8'))
lua.execute((root / 'tests/global_grid_ab.lua').read_text(encoding='utf-8'))
plugin = ET.parse(root / 'diagnostics/global_grid_applicability_ab_2_5_0_3.xml').getroot().find('UserPlugin')
assert plugin.attrib['Name'] == 'Global Grid Applicability AB 2.5.0.3'
components = plugin.findall('ComponentLua')
assert len(components) == 1 and (root / 'diagnostics' / components[0].attrib['FileName']).is_file()
print('PASS Global Grid A/B Lua 5.4, deterministic build, XML, focused controls')
