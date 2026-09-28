"""Embed the compact production Track A runtime into the existing candidate."""
from pathlib import Path
import argparse

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
parser = argparse.ArgumentParser()
parser.add_argument("--check", action="store_true")
if parser.parse_args().check:
    assert source == generated, "Show candidate generation is stale"
else:
    source_path.write_text(generated, encoding="utf-8", newline="\n")
