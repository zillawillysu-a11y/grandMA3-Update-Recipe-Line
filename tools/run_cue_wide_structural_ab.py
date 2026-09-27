from pathlib import Path
import os, subprocess, sys, ast, hashlib
from lupa import LuaRuntime
root=Path(__file__).resolve().parents[1]; os.chdir(root)
probe=root/'diagnostics/Cue_Wide_Structural_Resolver_AB_2_5_0_3.lua'
before=probe.read_bytes()
subprocess.run([sys.executable,'tools/build_cue_wide_structural_ab.py'],check=True)
assert probe.read_bytes()==before, 'Generated diagnostic drift'
source=(root/'RecipeTracking_Inspector.lua').read_text(encoding='utf-8')
assert 'local ENABLE_CUE_PHASER_MARKERS = false' in source
assert hashlib.sha256(source.encode()).hexdigest() in before.decode('utf-8')
tree=ast.parse((root/'tools/build_cue_wide_trace.py').read_text(encoding='utf-8'))
sections=next(ast.literal_eval(n.value) for n in tree.body if isinstance(n,ast.Assign) and any(isinstance(t,ast.Name) and t.id=='sections' for t in n.targets))
untraced=before.decode('utf-8').replace('\r\n','\n').replace('\n                    captureOrigin(part, layers[layer[1]])','').replace('\n        captureFeatureRecord()','')
for a,b in sections:
    assert source[source.index(a):source.index(b)].strip() in untraced, 'Baseline source drift: '+a
LuaRuntime().execute((root/'tests/cue_wide_structural_ab.lua').read_text(encoding='utf-8'))
print('PASS eleven original sections, deterministic generation, source SHA, disabled flag')
