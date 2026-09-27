"""Deploy only the standalone diagnostic; protect and hash production files."""
from pathlib import Path
import hashlib, shutil, subprocess, xml.etree.ElementTree as ET
from lupa import LuaRuntime

root = Path(__file__).resolve().parents[1]
base = Path(r'C:\ProgramData\MALightingTechnology\gma3_library\datapools\plugins')
target = base/'Cue-wide Marker Trace Timing 2.5.0.3'
production = base/'Update Plugin'
assert target.resolve().parent == base.resolve() and target != production
def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()
def snapshot():
    return {str(p.relative_to(production)): sha(p) for p in production.rglob('*') if p.is_file()}
def assert_source_unchanged():
    for name in ('RecipeTracking_Inspector.lua', 'RecipeUpdate_Diagnostic.lua', 'recipe_update_diagnostic.xml'):
        actual = subprocess.check_output(['git','hash-object',name],cwd=root).strip()
        expected = subprocess.check_output(['git','rev-parse','HEAD:'+name],cwd=root).strip()
        assert actual == expected, 'Production source changed: '+name
def parse_xml(directory):
    xml = directory/'cue_wide_trace_timing_2_5_0_3.xml'
    plugin = ET.parse(xml).getroot().find('UserPlugin')
    assert plugin is not None and plugin.attrib['Name'] == target.name
    components = plugin.findall('ComponentLua')
    assert len(components) == 1
    filename = components[0].attrib['FileName']
    assert filename == 'Cue_Wide_Trace_Timing_2_5_0_3.lua'
    lua_file = directory/filename
    assert lua_file.is_file()
    check = LuaRuntime().eval('function(s) local f,e=load(s); assert(f,e); return true end')
    assert check(lua_file.read_text(encoding='utf-8-sig'))
    return (xml, lua_file)

assert_source_unchanged()
before = snapshot()
assert before, 'Production folder must exist for protection snapshot'
sources = parse_xml(root/'diagnostics')
target.mkdir(parents=True,exist_ok=True)
for source in sources:
    shutil.copyfile(source,target/source.name)
parse_xml(target)
for source in sources:
    deployed = target/source.name
    assert sha(source) == sha(deployed), 'Deployed hash mismatch'
    print(source.name+' SHA256='+sha(source)+' MATCH')
assert_source_unchanged()
assert snapshot() == before, 'Production deployment changed'
print('PASS XML/Lua parse source+deployed; production source/folder unchanged')
print('DEPLOYED '+str(target))
