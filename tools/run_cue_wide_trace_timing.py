"""Offline safety, scanner semantics and timer accounting; no native connection."""
from pathlib import Path
import os, subprocess, sys, hashlib
from lupa import LuaRuntime
root = Path(__file__).resolve().parents[1]
os.chdir(root)
probe = root/'diagnostics/Cue_Wide_Trace_Timing_2_5_0_3.lua'
before = probe.read_bytes()
subprocess.run([sys.executable, 'tools/build_cue_wide_trace.py'], check=True)
assert probe.read_bytes() == before, 'Generated diagnostic drift'
source = (root/'RecipeTracking_Inspector.lua').read_text(encoding='utf-8')
assert hashlib.sha256(source.encode()).hexdigest() in before.decode('utf-8')
assert 'local ENABLE_CUE_PHASER_MARKERS = false' in source
lua = LuaRuntime()
lua.execute((root/'tests/cue_wide_trace_timing.lua').read_text(encoding='utf-8'))
print('PASS: deterministic generation, current production SHA and disabled flag')
