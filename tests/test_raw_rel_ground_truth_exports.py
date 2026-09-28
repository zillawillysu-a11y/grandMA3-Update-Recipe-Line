from pathlib import Path
from tempfile import TemporaryDirectory
import sys

sys.dont_write_bytecode = True
sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from tools.compare_raw_rel_ground_truth_exports import compare


def xml(value: str | None) -> str:
    rel = "" if value is None else f' RawValueRel="{value}"'
    return f'<GMA3><Preset><PhaserRecipe><PhaserRecipeSteps><PhaserRecipeStep><PhaserRecipeValueSource RawValueAbs="100"{rel}/></PhaserRecipeStep><PhaserRecipeStep><PhaserRecipeValueSource RawValueAbs="0"{rel}/></PhaserRecipeStep></PhaserRecipeSteps></PhaserRecipe></Preset></GMA3>'


with TemporaryDirectory() as directory:
    root = Path(directory)
    a, b, a2, b2 = (root / f"{name}.xml" for name in ("a", "b", "a2", "b2"))
    a.write_text(xml(None), encoding="utf-8")
    b.write_text(xml("0"), encoding="utf-8")
    a2.write_text(xml(None), encoding="utf-8")
    b2.write_text(xml("0"), encoding="utf-8")
    assert compare(a, b)[0] == "INCONCLUSIVE"
    result, evidence = compare(a, b, a2, b2)
    assert result == "DISCRIMINATOR_PROVEN" and "RawValueRel" in evidence
    a.write_text(xml("0"), encoding="utf-8")
    a2.write_text(xml("0"), encoding="utf-8")
    assert compare(a, b, a2, b2)[0] == "INCONCLUSIVE"
print("PASS Rev8 existing-export all-Step differential and repeat-export gate")
