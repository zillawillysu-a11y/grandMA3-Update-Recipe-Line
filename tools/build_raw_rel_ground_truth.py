"""Deterministically build only the standalone Rev8 observer."""
from pathlib import Path
import re

root = Path(__file__).resolve().parents[1]
template = root / "tools/templates/raw_rel_ground_truth.lua"
output = root / "diagnostics/Raw_Rel_Ground_Truth_Control_2_5_0_3.lua"
source = template.read_text(encoding="utf-8")
assert "8_RAW_REL_GROUND_TRUTH_CONTROL" in source
assert not re.search(r"\b(?:Cmd|GetPresetData|SetProgPhaser|GetProgPhaser)\s*\(", source)
output.write_text(source, encoding="utf-8")
print("Built Rev8 RAW_REL_GROUND_TRUTH_CONTROL observer")
