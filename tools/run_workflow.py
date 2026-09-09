# Offline runner for tests/recipe_workflow.lua using bundled Lua (lupa).
# Usage: python tools/run_workflow.py
import os
import sys

root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
os.chdir(root)

from lupa import LuaRuntime

runtime = LuaRuntime()
with open(os.path.join(root, "tests", "recipe_workflow.lua"), encoding="utf-8") as handle:
    source = handle.read()
try:
    runtime.execute(source)
except Exception as exc:
    print("FAIL: %s" % exc)
    sys.exit(1)
sys.exit(0)
