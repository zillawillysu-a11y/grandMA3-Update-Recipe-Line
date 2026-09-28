from pathlib import Path
import ast
import hashlib
import subprocess
import sys
import xml.etree.ElementTree as ET
from lupa.lua54 import LuaRuntime

root = Path(__file__).resolve().parents[1]
probe = root / 'diagnostics/Cue_Wide_Recipe_Reverse_Resolver_AB_2_5_0_3.lua'
before = probe.read_bytes()
subprocess.run([sys.executable, str(root / 'tools/build_cue_wide_recipe_reverse_ab.py')], check=True)
assert probe.read_bytes() == before, 'Nondeterministic generation'
source = (root / 'RecipeTracking_Inspector.lua').read_text(encoding='utf-8')
assert 'local ENABLE_CUE_PHASER_MARKERS = false' in source
assert hashlib.sha256(source.encode()).hexdigest() in before.decode()
tree = ast.parse((root / 'tools/build_cue_wide_trace.py').read_text(encoding='utf-8'))
sections = next(ast.literal_eval(n.value) for n in tree.body if isinstance(n, ast.Assign)
                and any(isinstance(t, ast.Name) and t.id == 'sections' for t in n.targets))
for a, b in sections:
    assert source[source.index(a):source.index(b)].strip() in before.decode().replace('\r\n', '\n'), a
lua = LuaRuntime()
lua.execute("assert(_VERSION=='Lua 5.4')")
lua.eval('function(s) local f,e=load(s); assert(f,e) end')(before.decode())
for test in ('cue_wide_recipe_ordinary_static.lua', 'cue_wide_recipe_global_applicability.lua', 'cue_wide_recipe_signature_delta.lua', 'cue_wide_recipe_reverse_engine.lua', 'cue_wide_recipe_reverse_ab.lua', 'cue_wide_recipe_reference_semantics.lua', 'cue_wide_recipe_reference_metadata.lua', 'cue_wide_recipe_metadata_bridge.lua', 'cue_wide_recipe_field_semantics.lua', 'cue_wide_recipe_raw_rel_zero.lua'):
    lua.execute((root / 'tests' / test).read_text(encoding='utf-8'))
print('PASS Lua 5.4, deterministic generation, unchanged oracle fidelity, production disabled')

manifest = ET.parse(root / 'diagnostics/cue_wide_recipe_reverse_resolver_ab_2_5_0_3.xml')
for component in manifest.getroot().find('UserPlugin').findall('ComponentLua'):
    assert (root / 'diagnostics' / component.attrib['FileName']).is_file()
print('PASS XML manifest and all referenced runtime files')
