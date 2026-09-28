# Offline runner for the workflow suites using bundled Lua (lupa).
# Usage: python tools/run_workflow.py
import os
import sys

root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
os.chdir(root)

from lupa import LuaRuntime

for name in ("tests/recipe_workflow.lua", "tests/show_candidate.lua"):
    runtime = LuaRuntime()
    with open(os.path.join(root, name), encoding="utf-8") as handle:
        source = handle.read()
    try:
        runtime.execute(source)
    except Exception as exc:
        print("FAIL %s: %s" % (name, exc))
        sys.exit(1)
sys.exit(0)
