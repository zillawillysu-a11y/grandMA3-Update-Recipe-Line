"""Deploy only the independent diagnostic; verify deployed bytes and production snapshot."""
from pathlib import Path
import hashlib
import shutil
import subprocess
import sys
import xml.etree.ElementTree as ET
from lupa.lua54 import LuaRuntime

root = Path(__file__).resolve().parents[1]
base = Path(r'C:\ProgramData\MALightingTechnology\gma3_library\datapools\plugins')
target = base / 'Global Grid Applicability AB 2.5.0.3'
production = base / 'Update Plugin'
names = ('global_grid_applicability_ab_2_5_0_3.xml', 'Global_Grid_Applicability_AB_2_5_0_3.lua')

def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()

def snapshot(directory):
    return {str(p.relative_to(directory)): sha(p) for p in directory.rglob('*') if p.is_file()}

assert target.resolve().parent == base.resolve() and target != production
source_before = {}
for name in ('RecipeTracking_Inspector.lua', 'RecipeUpdate_Diagnostic.lua', 'recipe_update_diagnostic.xml'):
    source_before[name] = sha(root / name)
    assert subprocess.check_output(['git', 'hash-object', name], cwd=root).strip() == subprocess.check_output(['git', 'rev-parse', 'HEAD:' + name], cwd=root).strip()
production_before = snapshot(production)
assert production_before
subprocess.run([sys.executable, str(root / 'tools/run_global_grid_ab.py')], check=True)
plugin = ET.parse(root / 'diagnostics' / names[0]).getroot().find('UserPlugin')
assert plugin.attrib['Name'] == 'Global Grid Applicability AB 2.5.0.3'
target.mkdir(parents=True, exist_ok=True)
for name in names:
    shutil.copyfile(root / 'diagnostics' / name, target / name)
    assert sha(root / 'diagnostics' / name) == sha(target / name)
    print(name + ' SHA256=' + sha(target / name) + ' MATCH')
assert source_before == {name: sha(root / name) for name in source_before}
assert production_before == snapshot(production)
LuaRuntime().eval('function(s) local f,e=load(s); assert(f,e) end')((target / names[1]).read_text(encoding='utf-8'))
print('PASS diagnostic deployed; production source/folder unchanged')
print('DEPLOYED ' + str(target))
