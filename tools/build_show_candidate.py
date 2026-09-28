"""Embed the compact production Track A runtime into the existing candidate."""
from pathlib import Path
import argparse
import re
import xml.etree.ElementTree as ET

root = Path(__file__).resolve().parents[1]
source_path = root / "RecipeTracking_Inspector.lua"
runtime_path = root / "tools/templates/show_track_a_runtime.lua"
begin = "-- BEGIN GENERATED TRACK A RUNTIME\n"
end = "-- END GENERATED TRACK A RUNTIME"
source = source_path.read_text(encoding="utf-8")
assert source.count(begin) == 1 and source.count(end) == 1
prefix, tail = source.split(begin, 1)
_, suffix = tail.split(end, 1)
runtime = runtime_path.read_text(encoding="utf-8").rstrip() + "\n"
generated = prefix + begin + runtime + end + suffix
lua_versions = re.findall(r'local PLUGIN_VERSION = "([^"]+)"', generated)
assert len(lua_versions) == 1, "Expected exactly one Lua plugin version"
lua_version = lua_versions[0]
plugin = ET.parse(root / "recipe_update_diagnostic.xml").getroot().find("UserPlugin")
assert plugin is not None, "Missing UserPlugin manifest"
xml_version = plugin.get("Version")
name_suffix = re.search(r" v([0-9]+(?:\.[0-9]+){3})$", plugin.get("Name", ""))
assert xml_version == lua_version == (name_suffix.group(1) if name_suffix else None), (
    "Lua/XML/name version mismatch"
)
assert generated.count('"Cue Recipe Update Tool v" .. PLUGIN_VERSION') == 1, (
    "Visible title must use PLUGIN_VERSION exactly once"
)
assert generated.count('"[RecipeTracking] START v" .. PLUGIN_VERSION') == 1, (
    "Startup log must use PLUGIN_VERSION exactly once"
)
parser = argparse.ArgumentParser()
parser.add_argument("--check", action="store_true")
if parser.parse_args().check:
    assert source == generated, "Show candidate generation is stale"
else:
    source_path.write_text(generated, encoding="utf-8", newline="\n")
