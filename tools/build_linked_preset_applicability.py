"""Build the independent read-only linked-Preset applicability observer."""
from pathlib import Path
import re

root = Path(__file__).resolve().parents[1]
source = (root / "tools/templates/linked_preset_applicability.lua").read_text(encoding="utf-8")
assert "10_1_LINKED_PRESET_APPLICABILITY_ACQUISITION" in source
assert not re.search(r"\b(?:Cmd|SetProgPhaser|GetProgPhaser|SetProperty)\s*\(", source)
(root / "diagnostics/Linked_Preset_Applicability_Control_2_5_0_3.lua").write_text(source, encoding="utf-8")
print("Built independent linked-Preset applicability observer")
