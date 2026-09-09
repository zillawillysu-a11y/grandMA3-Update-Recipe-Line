# Parse checks for plugin Lua files and the plugin XML manifest.
# Usage: python tools/check_parse.py
import os
import sys
import xml.etree.ElementTree as ET

root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
os.chdir(root)

from lupa import LuaRuntime

failed = False
for name in ("RecipeTracking_Inspector.lua", "RecipeUpdate_Diagnostic.lua"):
    runtime = LuaRuntime()
    runtime.globals()["src"] = open(name, encoding="utf-8").read()
    try:
        runtime.execute('local fn, err = load(src, "parse-check") assert(fn, err)')
        print("LUA PARSE PASS: " + name)
    except Exception as exc:
        print("LUA PARSE FAIL: %s (%s)" % (name, exc))
        failed = True
try:
    ET.parse(os.path.join(root, "recipe_update_diagnostic.xml"))
    print("XML PARSE PASS: recipe_update_diagnostic.xml")
except Exception as exc:
    print("XML PARSE FAIL: recipe_update_diagnostic.xml (%s)" % exc)
    failed = True
sys.exit(1 if failed else 0)
