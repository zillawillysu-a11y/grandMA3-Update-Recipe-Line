"""Build only the independent read-only Global Grid A/B Plugin."""
from pathlib import Path

root = Path(__file__).resolve().parents[1]
source = root / 'tools/templates/global_grid_ab.lua'
target = root / 'diagnostics/Global_Grid_Applicability_AB_2_5_0_3.lua'
target.write_bytes(source.read_bytes())
print('Built Global Grid Applicability AB 2.5.0.3')
